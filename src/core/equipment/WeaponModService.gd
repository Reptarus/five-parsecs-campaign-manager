class_name WeaponModService
extends RefCounted

## Gun Mods and Gun Sights — Core Rules p.53.
##
## THE GAP THIS CLOSES (audit row 99). All 13 attachments shipped in
## `data/equipment_database.json` with byte-accurate p.53 effects, and all 13 are
## rollable off the p.131 Loot Table (`gun_mods` 1-20, `gun_sights` 21-40 of the
## Gear subtable — a fifth of all gear loot). Nothing could FIT one to a weapon,
## so looting a Unity Battle Sight produced an inventory line and no effect ever.
##
## The battle maths was already waiting: `BattleCalculations.calculate_hit_
## modifier()` implements the Bipod clause verbatim at line 191 and reads
## `modifiers.has_bipod` — a key NO caller anywhere set. A correct rule, a
## correct reader, and a permanently-false input.
##
## THE FITTING RULES, verbatim p.53:
##   Gun Mods:   "Items from this list must be fitted to a weapon, and cannot be
##                removed or reversed. A weapon can have only one mod."
##   Gun Sights: "must be fitted to a weapon. Sights can be fitted to a weapon or
##                moved to a new one when equipment is being assigned during the
##                campaign turn. During battle, Sights cannot be attached or
##                removed. If the weapon is damaged, any Sight attached also
##                becomes damaged. A weapon can have only one Sight at a time."
##
## Storage: `weapon["gun_mod"]` and `weapon["gun_sight"]` hold attachment ids.
## Two separate keys because the two lists have different rules — one permanent,
## one movable — and a single "attachments" array would lose that distinction the
## moment someone fitted two mods.

const DATA_PATH := "res://data/equipment_database.json"

const MOD_KEY := "gun_mod"
const SIGHT_KEY := "gun_sight"

static var _attachments: Array = []
static var _loaded: bool = false


# MARK: - Data

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		push_warning("WeaponModService: %s not found" % DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("WeaponModService: failed to parse %s" % DATA_PATH)
		return
	if json.data is Dictionary:
		_attachments = (json.data as Dictionary).get("attachments", [])


static func all() -> Array:
	_load()
	return _attachments


static func definition(attachment_id: String) -> Dictionary:
	for entry in all():
		if entry is Dictionary and str(entry.get("id", "")) == attachment_id:
			return entry
	return {}


## Loot and the Stash carry display names ("Cyber-configurable Nano-Sludge");
## the database is keyed by id ("nano_sludge"). Resolves either, or "" when the
## item is not an attachment at all.
static func normalize_id(name_or_id: String) -> String:
	var raw: String = name_or_id.strip_edges()
	if not definition(raw).is_empty():
		return raw
	var slug: String = raw.to_lower().replace(" ", "_").replace("-", "_")
	if not definition(slug).is_empty():
		return slug
	# Two ids in the database deliberately do not slugify from their book name.
	match slug:
		"cyber_configurable_nano_sludge", "nano_sludge":
			return "nano_sludge"
		"stabilizer":
			return "stabilizer_mod"
		_:
			return ""


static func is_mod(attachment_id: String) -> bool:
	return str(definition(attachment_id).get("type", "")) == "Gun Mod"


static func is_sight(attachment_id: String) -> bool:
	return str(definition(attachment_id).get("type", "")) == "Gun Sight"


static func is_attachment(name_or_id: String) -> bool:
	return not normalize_id(name_or_id).is_empty()


# MARK: - Fitting

static func fitted_mod(weapon: Variant) -> String:
	return str(weapon.get(MOD_KEY, "")) if weapon is Dictionary else ""


static func fitted_sight(weapon: Variant) -> String:
	return str(weapon.get(SIGHT_KEY, "")) if weapon is Dictionary else ""


static func _traits_lower(weapon: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = weapon.get("traits", [])
	if raw is Array:
		for t in raw:
			out.append(str(t).to_lower())
	return out


static func is_pistol(weapon: Dictionary) -> bool:
	return "pistol" in _traits_lower(weapon)


## Can this attachment be fitted to this weapon? Returns {ok, reason}.
##
## Every restriction in the p.53 table is enforced here rather than at the UI, so
## the rule holds no matter which screen calls it.
static func can_fit(weapon: Variant, name_or_id: String) -> Dictionary:
	if not (weapon is Dictionary):
		return {"ok": false, "reason": "No weapon selected."}
	var w: Dictionary = weapon
	var aid: String = normalize_id(name_or_id)
	if aid.is_empty():
		return {"ok": false, "reason": "That item is not a Gun Mod or Gun Sight."}
	var def: Dictionary = definition(aid)

	# "A weapon can have only one mod." / "only one Sight at a time."
	if is_mod(aid) and not fitted_mod(w).is_empty():
		return {"ok": false, "reason":
			"%s already has a Gun Mod fitted, and mods cannot be removed (p.53)."
			% str(w.get("name", "This weapon"))}
	if is_sight(aid) and not fitted_sight(w).is_empty():
		# Not an error — a Sight may be replaced, because it is movable.
		pass

	var restrictions: Array = def.get("restrictions", []) if def.get(
		"restrictions", []) is Array else []
	for raw_restriction in restrictions:
		var restriction: String = str(raw_restriction)
		if restriction == "Non-Pistol only":
			if is_pistol(w):
				return {"ok": false, "reason":
					"%s is Non-Pistol only (p.53)." % str(def.get("name", aid))}
			continue
		if restriction == "Pistol only":
			if not is_pistol(w):
				return {"ok": false, "reason":
					"%s is Pistol only (p.53)." % str(def.get("name", aid))}
			continue
		# Hot shot pack names the four weapons it works on, so the restriction
		# list holds weapon names rather than a category.
		if aid == "hot_shot_pack":
			continue

	if aid == "hot_shot_pack" and not _hot_shot_allows(w, restrictions):
		return {"ok": false, "reason":
			"Hot Shot Pack fits only a Blast Pistol, Blast Rifle, Hand Laser or"
			+ " Infantry Laser (p.53)."}

	return {"ok": true, "reason": ""}


static func _hot_shot_allows(weapon: Dictionary, allowed: Array) -> bool:
	var wname: String = str(weapon.get("name", "")).strip_edges().to_lower()
	for entry in allowed:
		if str(entry).strip_edges().to_lower() == wname:
			return true
	return false


## Fit an attachment. Returns {ok, reason, replaced} — `replaced` names the Sight
## that was displaced, which the caller must return to the Stash (a Sight is a
## physical item and the one-item-one-home invariant still applies).
static func fit(weapon: Variant, name_or_id: String) -> Dictionary:
	var check: Dictionary = can_fit(weapon, name_or_id)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": str(check.get("reason", "")), "replaced": ""}
	var w: Dictionary = weapon
	var aid: String = normalize_id(name_or_id)
	var replaced: String = ""
	if is_mod(aid):
		w[MOD_KEY] = aid
	else:
		replaced = fitted_sight(w)
		w[SIGHT_KEY] = aid
	return {"ok": true, "reason": "", "replaced": replaced}


## Remove a Sight. Mods "cannot be removed or reversed" (p.53), so there is
## deliberately no remove_mod() — adding one would be inventing a rule.
## Returns the id removed, or "".
static func remove_sight(weapon: Variant) -> String:
	if not (weapon is Dictionary):
		return ""
	var w: Dictionary = weapon
	var current: String = fitted_sight(w)
	if current.is_empty():
		return ""
	w.erase(SIGHT_KEY)
	return current


## "If the weapon is damaged, any Sight attached also becomes damaged." (p.53)
## Called wherever a weapon is marked damaged.
static func propagate_damage_to_sight(weapon: Variant) -> void:
	if not (weapon is Dictionary):
		return
	var w: Dictionary = weapon
	if fitted_sight(w).is_empty():
		return
	w["gun_sight_damaged"] = true


static func sight_is_damaged(weapon: Variant) -> bool:
	if not (weapon is Dictionary):
		return false
	return bool((weapon as Dictionary).get("gun_sight_damaged", false))


# MARK: - Derived weapon profile

## The weapon as it should be played, with its fitted attachments applied.
##
## A damaged Sight contributes nothing (p.53 damages it with the weapon), which
## is why the sight branch is gated rather than unconditional.
##
## Returns a COPY: the caller renders it, the stored weapon keeps the base
## numbers, and re-applying can never compound (+2" twice from one Upgrade Kit is
## exactly the bug this shape prevents).
static func effective_weapon(weapon: Variant) -> Dictionary:
	if not (weapon is Dictionary):
		return {}
	var w: Dictionary = (weapon as Dictionary).duplicate(true)
	var traits: Array = w.get("traits", []) if w.get("traits", []) is Array else []
	var notes: Array[String] = []

	var mod_id: String = fitted_mod(w)
	match mod_id:
		"assault_blade":
			# "The weapon gains the Melee trait. Damage +1, and wins combat on a Draw."
			if not _has_trait(traits, "melee"):
				traits.append("Melee")
			w["damage"] = int(w.get("damage", 0)) + 1
			notes.append("Assault Blade: Melee, Damage +1, wins Brawl on a Draw.")
		"beam_light":
			notes.append("Beam Light: +3\" visibility in reduced visibility.")
		"bipod":
			notes.append("Bipod: +1 to Hit over 8\" when Aiming or in Cover.")
		"hot_shot_pack":
			w["damage"] = int(w.get("damage", 0)) + 1
			notes.append("Hot Shot Pack: Damage +1. A natural 6 on the shooting"
				+ " dice overheats the weapon — inoperable for the rest of the fight.")
		"nano_sludge":
			notes.append("Cyber-configurable Nano-Sludge: +1 to Hit (permanent).")
		"stabilizer_mod":
			# "Weapon may ignore Heavy trait" — so the trait comes off the profile
			# the player reads, which is also what removes the -1 moved penalty.
			for i in range(traits.size() - 1, -1, -1):
				if str(traits[i]).to_lower() == "heavy":
					traits.remove_at(i)
			notes.append("Stabilizer: ignores the Heavy trait.")
		"shock_attachment":
			if not _has_trait(traits, "stun"):
				traits.append("Stun")
			notes.append("Shock Attachment: Stun trait against targets within 8\".")
		"upgrade_kit":
			w["range"] = int(w.get("range", 0)) + 2
			notes.append("Upgrade Kit: +2\" Range.")

	var sight_id: String = fitted_sight(w)
	if not sight_id.is_empty() and not sight_is_damaged(w):
		match sight_id:
			"laser_sight":
				if not _has_trait(traits, "snap shot"):
					traits.append("Snap Shot")
				notes.append("Laser Sight: Snap Shot trait.")
			"quality_sight":
				w["range"] = int(w.get("range", 0)) + 2
				notes.append("Quality Sight: +2\" Range. Reroll 1s when firing"
					+ " only 1 shot.")
			"seeker_sight":
				notes.append("Seeker Sight: +1 to Hit if the shooter did not Move"
					+ " this round.")
			"tracker_sight":
				notes.append("Tracker Sight: +1 to Hit if you fired at the same"
					+ " target during your previous round.")
			"unity_battle_sight":
				notes.append("Unity Battle Sight: +1 to all Hit rolls.")
	elif not sight_id.is_empty():
		notes.append("Sight DAMAGED — it grants nothing until repaired (p.53).")

	w["traits"] = traits
	w["attachment_notes"] = notes
	return w


static func _has_trait(traits: Array, needle: String) -> bool:
	for t in traits:
		if str(t).to_lower() == needle:
			return true
	return false


# MARK: - Battle inputs

## The `modifiers` bag `BattleCalculations.calculate_hit_threshold()` expects,
## built from what is actually bolted to the weapon.
##
## `has_bipod` is the key the battle maths has read since it was written and that
## nothing ever produced. The two unconditional +1s (Nano-sludge, Unity Battle
## Sight) are returned as `flat_hit_bonus`, and the two conditional ones (Seeker,
## Tracker) as flags the caller answers from battle state — the app cannot know
## whether the shooter moved or shot the same target last round, so it asks.
static func hit_inputs(weapon: Variant) -> Dictionary:
	var out: Dictionary = {
		"has_bipod": false, "flat_hit_bonus": 0,
		"seeker_sight": false, "tracker_sight": false,
		"overheats_on_natural_6": false, "reroll_ones_single_shot": false,
	}
	if not (weapon is Dictionary):
		return out
	var w: Dictionary = weapon
	var mod_id: String = fitted_mod(w)
	if mod_id == "bipod":
		out["has_bipod"] = true
	elif mod_id == "nano_sludge":
		out["flat_hit_bonus"] = int(out["flat_hit_bonus"]) + 1
	elif mod_id == "hot_shot_pack":
		out["overheats_on_natural_6"] = true

	var sight_id: String = fitted_sight(w)
	if sight_id.is_empty() or sight_is_damaged(w):
		return out
	match sight_id:
		"unity_battle_sight":
			out["flat_hit_bonus"] = int(out["flat_hit_bonus"]) + 1
		"seeker_sight":
			out["seeker_sight"] = true
		"tracker_sight":
			out["tracker_sight"] = true
		"quality_sight":
			out["reroll_ones_single_shot"] = true
	return out


## Short "[Bipod +1]" style tag for weapon lines in list UIs.
static func summary_tag(weapon: Variant) -> String:
	var parts: Array[String] = []
	var mod_id: String = fitted_mod(weapon)
	if not mod_id.is_empty():
		parts.append(str(definition(mod_id).get("name", mod_id)))
	var sight_id: String = fitted_sight(weapon)
	if not sight_id.is_empty():
		var label: String = str(definition(sight_id).get("name", sight_id))
		parts.append(label + (" (damaged)" if sight_is_damaged(weapon) else ""))
	return "" if parts.is_empty() else " [%s]" % ", ".join(parts)
