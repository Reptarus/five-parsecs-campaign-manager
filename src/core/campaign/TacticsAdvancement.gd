class_name TacticsAdvancement
extends RefCounted

## What a Campaign Point purchase DOES — Five Parsecs: Tactics **pp.107-108**, with the
## veteran categories from **p.148** and the skill lists from **pp.150-153**.
##
## `TacticsCampaignCore.CP_PURCHASES` owns what each purchase COSTS. This file owns
## who may buy it, what can be chosen, and how it lands on the campaign. It is pure:
## the Advancement panel asks it for targets and choices, and `TacticsPhaseManager`
## is the only caller of `apply_purchase()`.
##
## ⚠ Before 2026-10-27 the panel charged the CP and applied NOTHING. Its own comment
## said why — an entry with no unit picker would match no unit — so every purchase
## the book prices at 1-4 CP bought the player nothing at all.
##
## A purchase is `{id, unit_id, choice}`. `choice` is a String for every purchase
## except a Unit Refit, whose `choice` is the full Array of option names the unit
## keeps (p.108: "You can make multiple changes such as adding, removing, or swapping
## out options").

const SKILLS_PATH := "res://data/tactics/tactics_veteran_skills.json"
const WEAPONS_PATH := "res://data/tactics/tactics_weapons_master.json"
const SPECIES_PATH := "res://data/tactics/species/%s.json"
const UnitRecordRef = preload("res://src/data/tactics/TacticsCampaignUnit.gd")
const LoaderRef = preload("res://src/data/tactics/TacticsSpeciesBookLoader.gd")

## The p.148 bullet list. A squad holds one squad skill AND one sergeant skill.
const LISTS_BY_KIND: Dictionary = {
	"squad": ["squad_skills", "sergeant_skills"],
	"gun_crew": ["gun_crew_skills"],
	"individual": ["individual_skills"],
	"vehicle": ["vehicle_skills"],
}

const LIST_LABELS: Dictionary = {
	"squad_skills": "Squad",
	"sergeant_skills": "Sergeant",
	"gun_crew_skills": "Gun Crew",
	"individual_skills": "Individual",
	"vehicle_skills": "Vehicle",
}

## Purchases with no unit attached (p.107: battle advantages "can be used with any
## force"; p.108 Roster Addition adds a unit rather than changing one).
const NO_TARGET: PackedStringArray = [
	"roster_addition", "battle_support", "battle_finesse", "battle_luck",
	"battle_initiative",
]

static var _skills: Dictionary = {}
static var _species_cache: Dictionary = {}
static var _weapons: Dictionary = {}


# ── Book lookups ────────────────────────────────────────────────────────────

static func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return null
	return j.data


static func skill_table() -> Dictionary:
	if _skills.is_empty():
		var d: Variant = _json(SKILLS_PATH)
		_skills = d if d is Dictionary else {}
	return _skills


static func species_data(species_id: String) -> Dictionary:
	if not _species_cache.has(species_id):
		var d: Variant = _json(SPECIES_PATH % species_id)
		_species_cache[species_id] = d if d is Dictionary else {}
	return _species_cache[species_id]


## Every Army Builder unit this species can field (pp.133-139) and every vehicle
## (p.141: "any of the factions may use any of the vehicles listed"), composed exactly
## as the creation wizard composes them.
static func species_units(species_id: String) -> Array:
	var sd: Dictionary = species_data(species_id)
	if sd.is_empty():
		return []
	var out: Array = LoaderRef.compose_army_builder_units(sd)
	out.append_array(LoaderRef.compose_vehicle_units(str(sd.get("unit_id_prefix", ""))))
	return out


## p.147, Heavy Combat Bots: "Bots cannot obtain veteran skills."
static func is_combat_bot(base: Dictionary) -> bool:
	return str(base.get("vehicle_type", "")) == "combat_bot"


static func base_unit(record: Dictionary, species_id: String) -> Dictionary:
	var sid: String = str(record.get("species_id", species_id))
	for u in species_units(sid if not sid.is_empty() else species_id):
		if u is Dictionary and str(u.get("id", "")) == str(record.get("base_unit_id", "")):
			return u
	return {}


## p.148 categories. A Fire Section is a multi-figure specialist team, so it takes the
## squad lists; a single-figure specialist is an individual.
static func unit_kind(base: Dictionary) -> String:
	match str(base.get("type", "")):
		"character":
			return "individual"
		"weapon_team":
			return "gun_crew"
		"vehicle":
			return "vehicle"
		"specialist":
			return "squad" if int(base.get("models", 1)) > 1 else "individual"
		"":
			return ""
		_:
			return "squad"


## p.108 Unit Replacement: "a different unit of the same general type (squad,
## vehicle, specialist, individual)". ⚠ A weapon team is none of the four by name, so
## it is matched only to other weapon teams — the conservative reading.
static func general_type(base: Dictionary) -> String:
	match str(base.get("type", "")):
		"character":
			return "individual"
		"specialist":
			return "specialist"
		"vehicle":
			return "vehicle"
		"weapon_team":
			return "weapon_team"
		"":
			return ""
		_:
			return "squad"


## p.148: "Beast and Synthetic units cannot become Veterans unless a rule specifically
## states otherwise." The Soulless carry that exception (p.158: they "may acquire
## veteran skills as normal"); the Converted do not (p.146).
static func can_be_veteran(species_id: String) -> bool:
	# ⚠ The rules sit under `species.traits`; the file's top level has no rule list, so
	# a top-level read finds nothing and lets every species through.
	var sp: Variant = species_data(species_id).get("species", {})
	var rules: Variant = (sp as Dictionary).get("traits", []) if sp is Dictionary else []
	var barred := false
	var exception := false
	if rules is Array:
		for r in rules:
			if not (r is Dictionary):
				continue
			var nm: String = str(r.get("name", ""))
			var desc: String = str(r.get("description", "")).to_lower()
			if nm == "Synthetic" or nm == "Beast":
				barred = true
			if "may acquire veteran skills" in desc:
				exception = true
	return exception or not barred


static func owned_skills(campaign, unit_id: String) -> Array:
	if campaign == null or not ("veteran_skills" in campaign):
		return []
	var v: Variant = campaign.veteran_skills.get(unit_id, [])
	return v if v is Array else []


static func _list_of(skill: Variant) -> String:
	return str((skill as Dictionary).get("list", "")) if skill is Dictionary else ""


## The skills a unit may still take: one from each of its p.148 lists that it does
## not already hold one from.
static func open_skills(base: Dictionary, owned: Array) -> Array:
	var held: PackedStringArray = PackedStringArray()
	for s in owned:
		held.append(_list_of(s))
	var out: Array = []
	for list_key in LISTS_BY_KIND.get(unit_kind(base), []):
		if held.has(list_key):
			continue
		for s in skill_table().get(list_key, []):
			if s is Dictionary:
				var row: Dictionary = (s as Dictionary).duplicate()
				row["list"] = list_key
				out.append(row)
	return out


static func _weapon_ids() -> PackedStringArray:
	if _weapons.is_empty():
		var d: Variant = _json(WEAPONS_PATH)
		_weapons = d if d is Dictionary else {}
	var w: Variant = _weapons.get("weapons", {})
	var ids: PackedStringArray = PackedStringArray()
	if w is Dictionary:
		for k in (w as Dictionary).keys():
			ids.append(str(k))
	elif w is Array:
		for row in w:
			if row is Dictionary:
				ids.append(str((row as Dictionary).get("id", "")))
	ids.sort()
	return ids


static func listed_options(base: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for g in base.get("upgrade_groups", []):
		if g is Dictionary:
			for o in (g as Dictionary).get("options", []):
				if o is Dictionary:
					var nm: String = str((o as Dictionary).get("name", ""))
					if not nm.is_empty() and not out.has(nm):
						out.append(nm)
	return out


static func _has_option(record: Dictionary, option_name: String) -> bool:
	for o in record.get("selected_upgrades", []):
		if str(o) == option_name:
			return true
	return false


# ── What the panel renders ──────────────────────────────────────────────────

static func needs_target(purchase_id: String) -> bool:
	return not NO_TARGET.has(purchase_id)


static func is_battle_advantage(purchase_id: String) -> bool:
	return purchase_id.begins_with("battle_")


## The units a purchase may be applied to: [{unit_id, label}].
static func targets(campaign, purchase_id: String) -> Array:
	var out: Array = []
	if campaign == null or not needs_target(purchase_id):
		return out
	var sid: String = str(campaign.species_id) if "species_id" in campaign else ""
	for rec in campaign.campaign_units:
		if not (rec is Dictionary):
			continue
		var r: Dictionary = rec
		var uid: String = str(r.get("unit_id", ""))
		var base: Dictionary = base_unit(r, sid)
		var lost: bool = bool(r.get("is_destroyed", false))
		var ok := false
		match purchase_id:
			"veteran_skill":
				ok = not lost and not base.is_empty() and not is_combat_bot(base) \
					and can_be_veteran(str(r.get("species_id", sid))) and not open_skills(
						base, owned_skills(campaign, uid)).is_empty()
			"retrain_unit":
				ok = not lost and not owned_skills(campaign, uid).is_empty()
			"hero_trait":
				ok = not lost and unit_kind(base) == "individual" and not _has_option(r, "Hero")
			"leader_trait":
				ok = not lost and unit_kind(base) == "individual" and not _has_option(r, "Leader")
			"unit_refit":
				ok = not lost and not listed_options(base).is_empty()
			"unit_customization", "unit_replacement":
				ok = not lost and not base.is_empty()
			"replace_destroyed":
				ok = lost and not base.is_empty()
		if ok:
			out.append({"unit_id": uid, "label": UnitRecordRef.display_name(r)})
	return out


## The choices for one target: [{value, label}]. A Unit Refit returns one row per
## listed option with `checked` set to whether the unit holds it now.
static func choices(campaign, purchase_id: String, unit_id: String) -> Array:
	var out: Array = []
	var sid: String = str(campaign.species_id) if campaign and "species_id" in campaign else ""
	var rec: Dictionary = _record(campaign, unit_id)
	var base: Dictionary = base_unit(rec, sid) if not rec.is_empty() else {}
	match purchase_id:
		"veteran_skill":
			for s in open_skills(base, owned_skills(campaign, unit_id)):
				out.append({"value": "%s:%s" % [s.list, s.id],
					"label": "%s — %s: %s" % [LIST_LABELS.get(s.list, s.list),
						str(s.get("name", "")), str(s.get("description", ""))]})
		"retrain_unit":
			var owned: Array = owned_skills(campaign, unit_id)
			var held: PackedStringArray = PackedStringArray()
			for s in owned:
				held.append(str((s as Dictionary).get("id", "")))
			for s in owned:
				var lk: String = _list_of(s)
				for alt in skill_table().get(lk, []):
					if alt is Dictionary and not held.has(str(alt.get("id", ""))):
						out.append({"value": "%s>%s:%s" % [str(s.get("id", "")), lk,
								str(alt.get("id", ""))],
							"label": "%s → %s" % [str(s.get("name", "")),
								str(alt.get("name", ""))]})
		"hero_trait":
			out.append({"value": "Hero", "label": "Hero"})
		"leader_trait":
			out.append({"value": "Leader", "label": "Leader"})
		"unit_refit":
			for nm in listed_options(base):
				out.append({"value": nm, "label": nm, "checked": _has_option(rec, nm)})
		"unit_customization":
			var have: PackedStringArray = PackedStringArray()
			for w in base.get("weapons", []):
				have.append(str(w))
			for ch in rec.get("weapon_changes", []):
				if ch is Dictionary:
					var w: String = str(ch.get("weapon", ""))
					if str(ch.get("op", "")) == "add":
						have.append(w)
					elif have.has(w):
						have.remove_at(have.find(w))
			for w in have:
				out.append({"value": "remove:" + w, "label": "Remove " + w})
			for w in _weapon_ids():
				if not have.has(w):
					out.append({"value": "add:" + w, "label": "Add " + w})
		"unit_replacement":
			var gt: String = general_type(base)
			for u in species_units(str(rec.get("species_id", sid))):
				if u is Dictionary and general_type(u) == gt \
						and str(u.get("id", "")) != str(rec.get("base_unit_id", "")):
					out.append({"value": str(u.get("id", "")), "label": str(u.get("name", ""))})
		"replace_destroyed":
			out.append({"value": str(rec.get("base_unit_id", "")),
				"label": "New %s (no veteran skills)" % str(base.get("name", "unit"))})
		"roster_addition":
			for u in species_units(sid):
				if u is Dictionary:
					out.append({"value": str(u.get("id", "")),
						"label": "%s (%d figures)" % [str(u.get("name", "")),
							int(u.get("models", 0))]})
	return out


static func _record(campaign, unit_id: String) -> Dictionary:
	if campaign == null or unit_id.is_empty():
		return {}
	for rec in campaign.campaign_units:
		if rec is Dictionary and str(rec.get("unit_id", "")) == unit_id:
			return rec
	return {}


# ── Applying a purchase (TacticsPhaseManager is the only caller) ────────────

## Apply one purchase. Returns a line for the receipt, or "" if nothing could be
## applied (an unknown target or a stale choice — never a silent partial change).
static func apply_purchase(campaign, p: Dictionary) -> String:
	if campaign == null:
		return ""
	var pid: String = str(p.get("id", ""))
	var uid: String = str(p.get("unit_id", ""))
	var choice: Variant = p.get("choice", "")
	var sid: String = str(campaign.species_id) if "species_id" in campaign else ""
	var rec: Dictionary = _record(campaign, uid)
	if needs_target(pid) and rec.is_empty():
		return ""
	match pid:
		"veteran_skill":
			var parts: PackedStringArray = str(choice).split(":")
			if parts.size() != 2:
				return ""
			for s in open_skills(base_unit(rec, sid), owned_skills(campaign, uid)):
				if s.list == parts[0] and str(s.get("id", "")) == parts[1]:
					var row: Dictionary = {"id": s.id, "name": s.get("name", ""),
						"list": s.list, "description": s.get("description", "")}
					if not campaign.veteran_skills.has(uid):
						campaign.veteran_skills[uid] = []
					campaign.veteran_skills[uid].append(row)
					return "%s gains the %s skill %s." % [UnitRecordRef.display_name(rec),
						LIST_LABELS.get(s.list, ""), row.name]
			return ""
		"retrain_unit":
			var halves: PackedStringArray = str(choice).split(">")
			if halves.size() != 2:
				return ""
			var target: PackedStringArray = halves[1].split(":")
			var owned: Array = owned_skills(campaign, uid)
			for i in range(owned.size()):
				var s: Dictionary = owned[i]
				if str(s.get("id", "")) != halves[0] or target.size() != 2 \
						or _list_of(s) != target[0]:
					continue
				for alt in skill_table().get(target[0], []):
					if alt is Dictionary and str(alt.get("id", "")) == target[1]:
						owned[i] = {"id": alt.id, "name": alt.get("name", ""),
							"list": target[0], "description": alt.get("description", "")}
						return "%s retrains %s into %s." % [UnitRecordRef.display_name(rec),
							str(s.get("name", "")), str(alt.get("name", ""))]
			return ""
		"hero_trait", "leader_trait":
			var trait_name: String = "Hero" if pid == "hero_trait" else "Leader"
			if _has_option(rec, trait_name):
				return ""
			var ups: Array = rec.get("selected_upgrades", [])
			ups.append(trait_name)
			rec["selected_upgrades"] = ups
			return "%s gains the %s trait." % [UnitRecordRef.display_name(rec), trait_name]
		"unit_refit":
			if not (choice is Array):
				return ""
			var allowed: PackedStringArray = listed_options(base_unit(rec, sid))
			var kept: Array = []
			for nm in choice:
				if allowed.has(str(nm)):
					kept.append(str(nm))
			# Hero and Leader bought with CP are not "weapon options" a refit removes.
			for o in rec.get("selected_upgrades", []):
				if (str(o) == "Hero" or str(o) == "Leader") and not kept.has(str(o)):
					kept.append(str(o))
			rec["selected_upgrades"] = kept
			return "%s refitted: %s." % [UnitRecordRef.display_name(rec),
				", ".join(PackedStringArray(kept)) if not kept.is_empty() else "no options"]
		"unit_customization":
			var op_w: PackedStringArray = str(choice).split(":")
			if op_w.size() != 2 or not (op_w[0] == "add" or op_w[0] == "remove"):
				return ""
			var changes: Array = rec.get("weapon_changes", [])
			changes.append({"op": op_w[0], "weapon": op_w[1]})
			rec["weapon_changes"] = changes
			return "%s: %s %s." % [UnitRecordRef.display_name(rec),
				"added" if op_w[0] == "add" else "removed", op_w[1]]
		"unit_replacement", "replace_destroyed":
			var new_base: Dictionary = {}
			for u in species_units(str(rec.get("species_id", sid))):
				if u is Dictionary and str(u.get("id", "")) == str(choice):
					new_base = u
			if new_base.is_empty():
				return ""
			# p.108: upgrades, modifications and penalties are lost with the unit; a
			# replacement for a destroyed unit "enters with no veteran skills".
			var fresh: Dictionary = UnitRecordRef.new_unit(str(new_base.id),
				str(rec.get("species_id", sid)), "", int(new_base.get("models", 5)))
			var idx: int = campaign.campaign_units.find(rec)
			campaign.campaign_units[idx] = fresh
			campaign.veteran_skills.erase(uid)
			return "%s replaced by a new %s." % [UnitRecordRef.display_name(rec),
				str(new_base.get("name", "unit"))]
		"roster_addition":
			for u in species_units(sid):
				if u is Dictionary and str(u.get("id", "")) == str(choice):
					campaign.campaign_units.append(UnitRecordRef.new_unit(str(u.id), sid,
						"", int(u.get("models", 5))))
					return "Added a %s to the roster (it must fit an existing platoon, " \
						% str(u.get("name", "")) + "p.108)."
			return ""
		_:
			if is_battle_advantage(pid) and campaign.has_method("add_battle_advantage"):
				var entry: Dictionary = TacticsCampaignCore.cp_purchase(pid)
				if entry.is_empty():
					return ""
				campaign.add_battle_advantage(entry)
				return "Banked a battle advantage: %s." % str(entry.get("name", ""))
	return ""
