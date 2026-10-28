extends RefCounted

## What a Planetfall battle puts on the table: the opposition the colony faces, the
## Contact rules (pp.41-42) and the Lifeform encounter roll (p.146).
##
## ⚠ Before 2026-10-27 a Planetfall battle showed the 5PFH Battle Card. The turn
## controller handed the battle one literal "Lifeform" copied from the first filled
## encounter entry, one Tactical Enemy figure with no weapons, and literal Slyn and
## Sleeper stat lines while their profile files had no reader. The p.146 encounter roll
## happened nowhere: get_lifeform_for_roll() had zero callers, so the Campaign Lifeform
## Encounters table never filled during play. A slyn_check mission fielded Slyn even
## when the aggression check said they stayed away.
##
## Two things ROLL here, because only the app holds the state they read or write:
##   build_force()  once at launch: Tactical Enemy numbers and weapons are "generated for
##                  each battle" (p.151), the Slyn encounter size (p.153).
##   reveal_contact() / encounter_lifeform(): a blank encounter entry becomes a new
##                  creature recorded on the colony's table (p.146).
## Everything else (Contact movement, detection) is TEXT for physical dice, read from
## data/planetfall/contact_system.json so a rule printed here is the rule in the data.

const LifeformScript := preload("res://src/core/systems/PlanetfallLifeformGenerator.gd")
const EnemyGenScript := preload("res://src/core/systems/PlanetfallTacticalEnemyGenerator.gd")
const MissionSetupScript := preload("res://src/core/systems/PlanetfallMissionSetup.gd")

const CONTACT_DATA := "res://data/planetfall/contact_system.json"
const REVEAL_DIE := "Planetfall Contact Reveal"
const ENCOUNTER_DIE := "Planetfall Lifeform Encounter"
const TOUGHER_DIE := "Planetfall Tougher Specimens"
const SLYN_SIZE_DIE := "Planetfall Slyn Encounter Size"
const SLYN_AGGRESSION_DIE := "Planetfall Slyn Aggression"
const SLYN_DATA := "res://data/planetfall/slyn_profile.json"

## The mission's own opposition text (mission_types.json), in the order a player needs it.
const OPPOSITION_TEXT := [
	["contact_setup", "Contacts at the start"],
	["contact_reinforcement", "New Contacts"],
	["contact_special", "Contact rule"],
	["first_contact_rule", "First Contact"],
	["lifeform_contact_rule", "Lifeform Contacts"],
	["scout_identification", "Identifying the Lifeform"],
	["slyn_deployment", "Slyn deployment"],
	["enemy_deployment", "Enemy deployment"],
	["deployment", "Enemy deployment"],
	["force_description", "Enemy force"],
	["boss_present", "Boss"],
	["patrol_variant", "In response to a patrol"],
	["tactical_note", "If no Slyn"],
	["readiness", "Readiness"],
	["hazard_placement", "Hazards"],
	["hazard_reinforcement", "New Hazards"],
]

static var _cache: Dictionary = {}


## The opposition a mission actually fields. Only a "slyn_check" mission rolls:
## "After deploying, roll 2D6. If the roll is 2-4, you are attacked by the Slyn ... On any
## other result, the threat is from wildlife, and the Contact system is used" (p.117;
## p.121 Patrol, p.125 Scout Down! with 2-3 and Tactical Enemies). Called at launch,
## after Lock and Load, which is as close to "after deploying" as the app gets.
## {type, slyn_attacking, roll, line}.
static func resolve_opposition(mission: Dictionary) -> Dictionary:
	var opposition: Dictionary = mission.get("opposition", {})
	var raw: String = str(opposition.get("type", "lifeforms"))
	if raw != "slyn_check":
		return {"type": raw, "slyn_attacking": false, "roll": 0, "line": ""}
	var roll: int = _2d6(SLYN_AGGRESSION_DIE)
	var attacking: bool = MissionSetupScript.new().check_slyn_aggression(
			str(mission.get("id", "")), roll)
	var fallback: String = "tactical" if opposition.get("tactical_fallback", false) \
			else "lifeforms"
	var aggro: Dictionary = opposition.get("slyn_aggression", {})
	var band: String = "%d-%d" % [int(aggro.get("slyn_range_min", 2)),
		int(aggro.get("slyn_range_max", 4))]
	var line: String = "Slyn check, 2D6 %d (Slyn on %s): %s." % [roll, band,
		"the Slyn attack" if attacking else ("no Slyn. Tactical Enemies"
			if fallback == "tactical" else "no Slyn. Wildlife, using the Contact system")]
	return {"type": "slyn" if attacking else fallback, "slyn_attacking": attacking,
		"roll": roll, "line": line}


## What one mission remembers between reveals: how many Lifeforms have been met (p.146,
## the 6th is a pack leader) and the Unique Ability each Dramatic transformations
## creature rolled for this battle (p.159).
static func new_encounter_state() -> Dictionary:
	return {"encountered": 0, "battle_abilities": {}}


## ── The force, rolled once at launch ────────────────────────────────────────────

## {enemies: [figure dicts for the battle screen], rows: [{head, detail}], enemy_type}.
## `opp_type` is the RESOLVED opposition ("slyn" only when the aggression check said so).
static func build_force(campaign: Resource, opp_type: String, opposition: Dictionary,
		te_index: int) -> Dictionary:
	match opp_type:
		"tactical":
			return tactical_force(campaign, te_index, opposition)
		"slyn":
			return slyn_force()
		"delve_hazards":
			var sleeper: Dictionary = MissionSetupScript.new().get_sleeper_profile()
			var prof: Dictionary = sleeper.get("profile", {})
			return {"enemies": [], "enemy_type": "Sleepers", "rows": [{
				"head": "Sleepers (Planetfall pp.154-155)",
				"detail": profile_line(prof)}]}
		_:
			return {"enemies": [], "enemy_type": "Lifeforms", "rows": [{
				"head": "Lifeforms (Planetfall pp.41-42)",
				"detail": "No creature is known until a Contact is revealed."}]}


## pp.148-151. Number from the type's formula, then the mission's modifiers; one figure
## is always a specialist, 6 or more brings one leader (one of the figures, not an extra),
## the rest are grunts. Weapons are rolled per force, per battle (p.151).
static func tactical_force(campaign: Resource, te_index: int, opposition: Dictionary) -> Dictionary:
	var result: Dictionary = {"enemies": [], "rows": [], "enemy_type": ""}
	var teg := EnemyGenScript.new()
	var te: Dictionary = {}
	if campaign != null and "tactical_enemies" in campaign and te_index >= 0 \
			and te_index < campaign.tactical_enemies.size():
		te = campaign.tactical_enemies[te_index]
	var type: Dictionary
	if te.is_empty():
		# p.125 Scout Down!: "In the event you do not have any Tactical Enemies on the
		# game map, randomly pick an encounter from the Tactical Enemies list (see page
		# 149). This does not add that enemy to your map."
		type = teg.roll_enemy_type()
		result.rows.append({"head": "No Tactical Enemy on your map",
			"detail": "Rolled on the Tactical Enemies table for this battle only. It is "
				+ "not added to your map (p.125)."})
	else:
		var stored: Dictionary = te.get("type", {})
		type = teg.type_by_id(str(stored.get("id", "")))
		if type.is_empty():
			type = stored
	if type.is_empty():
		return result
	var tname: String = str(type.get("name", "Tactical Enemy"))
	result.enemy_type = tname
	var mods: Array = opposition.get("force_number_modifiers", [0])
	for f in range(mods.size()):
		var count: int
		var how: String
		if bool(opposition.get("max_encounter", false)):
			count = teg.max_of_formula(str(type.get("number", "1D6+3")))
			how = "maximum of %s" % str(type.get("number", ""))
		else:
			var rolled: int = teg.get_enemy_count_for_battle(type)
			count = maxi(1, rolled + int(mods[f]) + int(opposition.get("extra_enemies", 0)))
			how = "%s rolled %d" % [str(type.get("number", "")), rolled]
			if int(mods[f]) != 0 or int(opposition.get("extra_enemies", 0)) != 0:
				how += ", %+d for the mission" % (int(mods[f]) + int(opposition.get("extra_enemies", 0)))
		var weapons: Dictionary = teg.assign_battle_weapons(type)
		var figures: Array = _compose(type, count, weapons, teg)
		figures.append_array(_assault_extras(type, weapons, teg, opposition))
		result.enemies.append_array(figures)
		var label: String = tname if mods.size() == 1 else "%s, force %d" % [tname, f + 1]
		result.rows.append({"head": "%s: %d figures (%s)" % [label, figures.size(), how],
			"detail": _force_summary(figures)})
	if opposition.has("boss_present") and bool(te.get("boss_located", false)):
		var boss: Dictionary = _figure(type, "boss", teg.assign_battle_weapons(type))
		var bs: Dictionary = teg.get_boss_stats(type)
		boss["kp"] = int(bs.kp)
		boss["combat_skill"] = int(boss.combat_skill) + int(bs.combat_bonus)
		boss["toughness"] = int(boss.toughness) + int(bs.toughness_bonus)
		result.enemies.append(boss)
		result.rows.append({"head": "Boss, in addition to the force (p.149)",
			"detail": _figure_line(boss)})
	if str(type.get("special_rule_description", "")) != "":
		result.rows.append({"head": "%s rule" % tname,
			"detail": str(type.special_rule_description)})
	return result


static func _compose(type: Dictionary, count: int, weapons: Dictionary, teg) -> Array:
	var figures: Array = []
	var has_leader: bool = count >= int(teg.get_leader_threshold())
	figures.append(_figure(type, "specialist", weapons))
	if has_leader:
		var leader: Dictionary = _figure(type, "leader", weapons)
		leader["kp"] = int(teg.get_leader_kp(type))
		figures.append(leader)
	for _i in range(maxi(0, count - figures.size())):
		figures.append(_figure(type, "grunt", weapons))
	return figures


## p.129 Assault: "add 2 additional regular enemies, 2 additional specialists, and 1
## additional leader. The additional leader receives +1 KP."
static func _assault_extras(type: Dictionary, weapons: Dictionary, teg,
		opposition: Dictionary) -> Array:
	var extras: Array = []
	for _i in range(int(opposition.get("extra_regular", 0))):
		extras.append(_figure(type, "grunt", weapons))
	for _i in range(int(opposition.get("extra_specialists", 0))):
		extras.append(_figure(type, "specialist", weapons))
	for _i in range(int(opposition.get("extra_leaders", 0))):
		var leader: Dictionary = _figure(type, "leader", weapons)
		leader["kp"] = int(teg.get_leader_kp(type)) + int(opposition.get("extra_leader_kp", 0))
		extras.append(leader)
	return extras


## p.149: a split Combat Skill's second value is for leaders AND specialists; a split
## Toughness's second value is for the leader only.
static func _figure(type: Dictionary, role: String, weapons: Dictionary) -> Dictionary:
	var cs: Array = _split(type.get("combat_skill", 0))
	var tg: Array = _split(type.get("toughness", 3))
	var elite: bool = role != "grunt"
	var weapon_key: String = {"grunt": "grunt_weapons", "specialist": "specialist_weapons",
		"leader": "leader_weapons", "boss": "leader_weapons"}[role]
	var names: Array = []
	for w in weapons.get(weapon_key, []):
		if w is Dictionary and not (w as Dictionary).is_empty():
			names.append(_weapon_text(w))
	return {
		"name": "%s %s" % [str(type.get("name", "Enemy")), role],
		"type": "tactical_enemy",
		"role": role,
		"is_leader": role == "leader" or role == "boss",
		"is_specialist": role == "specialist",
		"speed": int(type.get("speed", 4)),
		"combat_skill": int(cs[1] if elite and cs.size() > 1 else cs[0]),
		"toughness": int(tg[1] if (role == "leader" or role == "boss") and tg.size() > 1 else tg[0]),
		"kp": 0,
		"panic": str(type.get("panic", "")),
		"weapons": names,
	}


static func _split(v: Variant) -> Array:
	if v is Array and not (v as Array).is_empty():
		return v
	return [v if v != null else 0]


## p.153: Slyn come "6 or 8 individuals formed into 3 or 4 pairs".
static func slyn_force() -> Dictionary:
	var setup := MissionSetupScript.new()
	var count: int = setup.get_slyn_encounter_size(_d6(SLYN_SIZE_DIE))
	var prof: Dictionary = setup.get_slyn_combat_profile()
	var enemies: Array = []
	for _i in range(count):
		var fig: Dictionary = prof.duplicate(true)
		fig["name"] = "Slyn"
		fig["type"] = "slyn"
		# The profile is JSON, whose numbers are floats; the battle screen prints them.
		for key in ["speed", "combat_skill", "toughness"]:
			fig[key] = int(fig.get(key, 0))
		enemies.append(fig)
	var rows: Array = [{"head": "Slyn: %d, in %d pairs (Planetfall p.153)" % [count, count / 2],
		"detail": profile_line(prof)}]
	var data: Dictionary = _json(SLYN_DATA)
	var pairs: Dictionary = data.get("pair_mechanics", {})
	if not pairs.is_empty():
		rows.append({"head": "Slyn pairs", "detail": " ".join([str(pairs.get("deployment", "")),
			str(pairs.get("movement", "")), str(pairs.get("targeting", "")),
			str(pairs.get("damage_tracking", ""))])})
	var srd: Dictionary = data.get("short_range_distortion", {})
	if not srd.is_empty():
		rows.append({"head": "Short-range distortion: %s" % str(srd.get("timing", "")),
			"detail": " ".join([str(srd.get("mechanic", "")), str(srd.get("off_table", "")),
				str(srd.get("post_teleport", "")), str(srd.get("brawl_on_emerge", ""))])})
	var withdraw: Dictionary = data.get("withdrawal", {})
	if str(withdraw.get("rule", "")) != "":
		rows.append({"head": "Withdrawal", "detail": str(withdraw.rule)})
	return {"enemies": enemies, "enemy_type": "Slyn", "rows": rows}


static func _force_summary(figures: Array) -> String:
	var parts: Array = []
	for role in ["boss", "leader", "specialist", "grunt"]:
		var of_role: Array = figures.filter(func(f): return str(f.get("role", "")) == role)
		if of_role.is_empty():
			continue
		parts.append("%d %s: %s" % [of_role.size(), role if of_role.size() == 1 else role + "s",
			_figure_line(of_role[0])])
	return "\n".join(parts)


static func _figure_line(f: Dictionary) -> String:
	var line: String = "Speed %d\", Combat Skill %+d, Toughness %d" % [int(f.get("speed", 0)),
		int(f.get("combat_skill", 0)), int(f.get("toughness", 0))]
	if int(f.get("kp", 0)) > 0:
		line += ", %d KP" % int(f.kp)
	var weapons: Array = f.get("weapons", [])
	if not weapons.is_empty():
		line += "; " + " + ".join(weapons)
	return line


static func _weapon_text(w: Dictionary) -> String:
	var text: String = str(w.get("name", w.get("id", "?")))
	if int(w.get("range", 0)) > 0:
		text += " (%s\", Shots %s, Damage %+d)" % [str(w.get("range", "")),
			str(w.get("shots", "")), int(w.get("damage", 0))]
	elif w.has("damage"):
		text += " (Brawling, Damage %+d)" % int(w.get("damage", 0))
	return text


## ── The Battle Card ─────────────────────────────────────────────────────────────

## Rows for the Planetfall Battle Card: [{head, detail}]. `md` is the mission payload the
## turn controller stamped at launch.
static func briefing_rows(md: Dictionary, campaign: Resource) -> Array:
	var rows: Array = []
	for row in md.get("opposition_force_rows", []):
		if row is Dictionary:
			rows.append(row)
	var opposition: Dictionary = md.get("opposition", {})
	for pair in OPPOSITION_TEXT:
		var text: String = str(opposition.get(pair[0], ""))
		if text != "":
			rows.append({"head": str(pair[1]), "detail": text})
	# Contacts and the encounter table belong to a wildlife battle only: "On any other
	# result, the threat is from wildlife, and the Contact system is used" (p.117).
	if str(md.get("opposition_type", "")) != "lifeforms":
		return rows
	var known: Array = known_lifeforms(campaign)
	rows.append({"head": "Lifeform encounters: %d of 10 entries known (Planetfall p.146)"
			% known.size(),
		"detail": "A revealed Contact rolls on your Campaign Lifeform Encounters table. A "
			+ "blank entry becomes a new creature, kept for the rest of the campaign."})
	for lf in known:
		rows.append({"head": entry_name(lf), "detail": profile_line(lf)})
	rows.append_array(contact_rule_rows())
	return rows


static func contact_rule_rows() -> Array:
	var data: Dictionary = _contact_data()
	var rows: Array = []
	var move: Dictionary = data.get("contact_movement", {})
	if not move.is_empty():
		rows.append({"head": "Contacts move at the end of the Enemy Phase (Planetfall p.41)",
			"detail": "%s Aggression higher: %s. Random higher: %s. Equal: %s %s" % [
				str(move.get("description", "")), str(move.get("aggression_wins", "")),
				str(move.get("random_wins", "")), str(move.get("tied", "")),
				str(move.get("edge_behavior", ""))]})
	var detect: Dictionary = data.get("contact_detection", {})
	if not detect.is_empty():
		var test: Dictionary = detect.get("obscured_test", {})
		rows.append({"head": "Detection (Planetfall p.42)",
			"detail": "%s %s, a Contact in sight but partly obscured is detected on a %s of %d+. %s" % [
				str(detect.get("automatic", "")), str(test.get("timing", "")),
				str(test.get("die", "D6")), int(test.get("success", 4)), str(test.get("note", ""))]})
	var reveal: Array = (data.get("contact_reveal_table", {}) as Dictionary).get("entries", [])
	if not reveal.is_empty():
		var parts: Array = []
		for e in reveal:
			if e is Dictionary:
				parts.append("%s %s" % [_roll_label(e.get("roll", [])), str(e.get("result", ""))])
		rows.append({"head": "Contact Reveal, D6 (Planetfall p.42)",
			"detail": "; ".join(parts) + ". %s %s" % [str(data.get("placement", "")),
				str(data.get("revealed_enemy_timing", ""))]})
	return rows


static func _roll_label(roll: Variant) -> String:
	var r: Array = roll if roll is Array else [roll]
	if r.size() > 1:
		return "%d-%d:" % [int(r[0]), int(r[r.size() - 1])]
	return "%d:" % int(r[0]) if not r.is_empty() else ""


## ── The encounter roll ──────────────────────────────────────────────────────────

## p.42 Contact Reveal. {roll, new_contacts, lines, lifeforms: [encounter receipts]}.
## `chosen_slot` is the Hunt scout's pick, passed on to the encounter roll.
static func reveal_contact(campaign: Resource, state: Dictionary,
		chosen_slot: int = -1) -> Dictionary:
	var roll: int = _d6(REVEAL_DIE)
	var r: Dictionary = {"roll": roll, "new_contacts": 0, "lines": [], "lifeforms": []}
	var row: Dictionary = {}
	for e in (_contact_data().get("contact_reveal_table", {}) as Dictionary).get("entries", []):
		# JSON numbers are floats, and Array.has(4) never matches 4.0.
		if e is Dictionary and (e.get("roll", []) as Array).any(
				func(v: Variant) -> bool: return int(v) == roll):
			row = e
	r.lines.append("Contact Reveal D6 %d: %s." % [roll, str(row.get("result", "?"))])
	r.new_contacts = int(row.get("new_contacts", 0))
	for _i in range(int(row.get("spawns", 0))):
		var enc: Dictionary = encounter_lifeform(campaign, state, chosen_slot)
		r.lifeforms.append(enc)
		r.lines.append_array(enc.lines)
	return r


## p.146: "When you have a Lifeform encounter, roll D100 on the Campaign Lifeform
## Encounters table"; a filled entry is that creature, a blank one is generated now and
## recorded. The missions say WHEN: "The first time a Contact is revealed to be hostile
## Lifeforms, roll on your Campaign Lifeform Encounters table to determine what you
## encounter" (p.117 and the other Contact missions). So the first reveal fixes the
## creature for the mission and every later one is more of it, which is also what makes
## "the 6th one encountered during the mission" a pack leader of that kind.
## `chosen_slot` >= 0 is the Hunt scout's pick (1D6+Savvy 5+, "choose which Lifeform"),
## used only for that first determination.
static func encounter_lifeform(campaign: Resource, state: Dictionary,
		chosen_slot: int = -1) -> Dictionary:
	var gen := LifeformScript.new()
	var roll: int = 0
	var slot: int = int(state.get("mission_slot", -1))
	var first: bool = slot < 0
	if first:
		if chosen_slot >= 0:
			slot = chosen_slot
		else:
			roll = _d100(ENCOUNTER_DIE)
			slot = gen.get_encounter_table_slot(roll)
		state["mission_slot"] = slot
	var has_table: bool = campaign != null and "lifeform_table" in campaign
	var was_known: bool = has_table and slot >= 0 and slot < campaign.lifeform_table.size() \
			and LifeformScript.is_slot_filled(campaign.lifeform_table[slot])
	var lf: Dictionary
	if was_known:
		lf = (campaign.lifeform_table[slot] as Dictionary).duplicate(true)
	elif has_table and slot >= 0:
		lf = gen.fill_encounter_slot(campaign, slot)
	else:
		lf = gen.generate_lifeform()
	lf["slot_index"] = slot
	state["encountered"] = int(state.get("encountered", 0)) + 1
	var n: int = int(state.encountered)
	var evos: Array = LifeformScript.evolutions_on(lf)
	var bonus: int = 0
	var notes: Array = []
	var bigger: Dictionary = gen.evolution_entry("bigger_leaders") if "bigger_leaders" in evos else {}
	if n == gen.pack_leader_threshold():
		bonus += int(bigger.get("pack_leader_kp", gen.pack_leader_bonus_kp()))
		notes.append("the pack leader, +%d KP" % bonus)
	elif not bigger.is_empty() and n == int(bigger.get("secondary_leader_threshold", 4)):
		bonus += int(bigger.get("secondary_leader_kp", 1))
		notes.append("a secondary leader, +%d KP (Bigger Leaders)" % bonus)
	if "tougher_specimens" in evos:
		var tough: Dictionary = gen.evolution_entry("tougher_specimens")
		var d6: int = _d6(TOUGHER_DIE)
		if d6 >= int(tough.get("tough_roll_min", 5)):
			bonus += int(tough.get("tough_kp_bonus", 1))
			notes.append("Tougher Specimens D6 %d: +%d KP" % [d6, int(tough.get("tough_kp_bonus", 1))])
	if bool(lf.get("unique_ability_each_battle", false)):
		var abilities: Dictionary = state.get("battle_abilities", {})
		if not abilities.has(slot):
			abilities[slot] = gen.roll_unique_ability()
		state["battle_abilities"] = abilities
		lf["unique_ability"] = abilities[slot]
	var kp: int = int(lf.get("kp", 0)) + bonus
	var lines: Array = []
	if first:
		var how: String = "the scout's choice" if roll == 0 else "Lifeform Encounters D100 %d" % roll
		lines.append("This mission's Lifeforms (%s): %s%s." % [how, entry_name(lf),
			"" if was_known else ", a new creature now recorded on your encounter table"])
	lines.append("Lifeform %d of this mission: %s. %s" % [n, entry_name(lf), profile_line(lf, kp)])
	if not notes.is_empty():
		lines.append("This one is " + "; ".join(notes) + ".")
	return {"roll": roll, "slot": slot, "new": not was_known, "lifeform": lf, "kp": kp,
		"lines": lines}


## ── Text ────────────────────────────────────────────────────────────────────────

static func known_lifeforms(campaign: Resource) -> Array:
	var known: Array = []
	if campaign == null or not ("lifeform_table" in campaign):
		return known
	for i in range(campaign.lifeform_table.size()):
		var entry: Variant = campaign.lifeform_table[i]
		if LifeformScript.is_slot_filled(entry):
			var lf: Dictionary = (entry as Dictionary).duplicate()
			lf["slot_index"] = i
			known.append(lf)
	return known


static func entry_name(lf: Dictionary) -> String:
	var slot: int = int(lf.get("slot_index", -1))
	var named: String = str(lf.get("name", ""))
	if named != "":
		return named
	return "Encounter entry %d" % (slot + 1) if slot >= 0 else "Lifeform"


## One line a player can play a creature or enemy from. `kp_override` >= 0 prints that KP.
static func profile_line(p: Dictionary, kp_override: int = -1) -> String:
	var gen := LifeformScript.new()
	var parts: Array = ["Speed %d\"" % int(p.get("speed", 0))]
	if bool(p.get("partially_airborne", false)):
		parts[0] += " (Partially Airborne)"
	parts.append("Combat Skill %+d" % int(p.get("combat_skill", 0)))
	parts.append("Toughness %d" % int(p.get("toughness", 0)))
	if p.has("strike_damage"):
		parts.append("Melee Damage %+d" % int(p.get("strike_damage", 0)))
	var kp: int = kp_override if kp_override >= 0 else int(p.get("kp", 0))
	if kp > 0:
		parts.append("%d KP" % kp)
	var extras: Array = []
	# A creature with no extra defence stores null, and str(null) would match a null row.
	var code: Variant = p.get("defense_additional", null)
	if code is String and code != "":
		var defense: String = gen.defense_description(code)
		if defense != "":
			extras.append(defense)
	for sa in p.get("special_attacks", []):
		if sa is Dictionary:
			extras.append("%s: %s" % [str(sa.get("name", "")), str(sa.get("description", ""))])
	var ua: Variant = p.get("unique_ability", {})
	if ua is Dictionary and not (ua as Dictionary).is_empty() and str(ua.get("id", "")) != "none":
		extras.append("%s: %s" % [str(ua.get("name", "")), str(ua.get("description", ""))])
	for evo_id in p.get("evolutions_applied", []):
		var evo: Dictionary = gen.evolution_entry(str(evo_id))
		if not evo.is_empty():
			extras.append("%s: %s" % [str(evo.get("name", "")), str(evo.get("description", ""))])
	for key in ["brawling", "ranged"]:
		var w: Variant = p.get(key, {})
		if w is Dictionary and not (w as Dictionary).is_empty():
			extras.append(_weapon_text(w))
	var screen: Variant = p.get("force_screen", {})
	if screen is Dictionary and str(screen.get("description", "")) != "":
		extras.append(str(screen.description))
	var line: String = ", ".join(parts)
	if not extras.is_empty():
		line += ". " + " ".join(extras.map(func(x): return str(x).strip_edges().trim_suffix(".") + "."))
	return line


## ── Data and dice ───────────────────────────────────────────────────────────────

static func _contact_data() -> Dictionary:
	return _json(CONTACT_DATA)


static func _json(path: String) -> Dictionary:
	if not _cache.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) \
				if FileAccess.file_exists(path) else null
		_cache[path] = parsed if parsed is Dictionary else {}
	return _cache[path]


static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


static func _d6(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d6(context)) if dm else randi_range(1, 6)


static func _2d6(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_2d6(context)) if dm else randi_range(1, 6) + randi_range(1, 6)


static func _d100(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)
