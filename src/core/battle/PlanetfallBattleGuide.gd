extends RefCounted

## What a Planetfall battle puts on the table: the opposition the colony faces, the
## Contact rules (pp.41-42) and the Lifeform encounter roll (p.146).
##
## ⚠ Before 2026-10-27 a Planetfall battle showed the 5PFH Battle Card. The turn
## controller handed the battle one literal "Lifeform" copied from the first filled
## encounter entry, one Tactical Enemy figure with no weapons, and literal Slyn and
## Sleeper stat lines while their profile files had no reader. The p.146 encounter roll
## happened nowhere: get_lifeform_for_roll() (since deleted) had zero callers, so the
## Campaign Lifeform Encounters table never filled during play. A slyn_check mission
## fielded Slyn even when the aggression check said they stayed away.
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
const CalamityScript := preload("res://src/core/systems/PlanetfallCalamitySystem.gd")
const ArmoryScript := preload("res://src/core/systems/PlanetfallArmorySystem.gd")
const ResearchScript := preload("res://src/core/systems/PlanetfallResearchSystem.gd")
const GridScript := preload("res://src/core/battle/BattlefieldGrid.gd")

const CONTACT_DATA := "res://data/planetfall/contact_system.json"
const REVEAL_DIE := "Planetfall Contact Reveal"
const ENCOUNTER_DIE := "Planetfall Lifeform Encounter"
const TOUGHER_DIE := "Planetfall Tougher Specimens"
const SLYN_SIZE_DIE := "Planetfall Slyn Encounter Size"
const SLYN_AGGRESSION_DIE := "Planetfall Slyn Aggression"
const SKIRMISH_DIE := "Planetfall Skirmish Objective"
const SKIRMISH_PLACEMENT_DIE := "Planetfall Skirmish Placement"
const SLEEPER_WEAPON_DIE := "Planetfall Sleeper Weapon"
const DELVE_HAZARD_DIE := "Planetfall Delve Hazard"
const DELVE_TRAP_DIE := "Planetfall Delve Trap"
const ENVIRONMENT_DIE := "Planetfall Environmental Hazard"
const DELVE_DEVICE_DIE := "Planetfall Delve Device"
const DELVE_ARTIFACT_DIE := "Planetfall Delve Artifact Site"
const DISCOVERY_DIE := "Planetfall Discovery Marker"
const UNCERTAIN_DIE := "Planetfall Uncertain Feature"
const UNCERTAIN_DATA := "res://data/planetfall/uncertain_terrain.json"
const UNCERTAIN_CONDITION := "uncertain_terrain_features"
const DELVE_DATA := "res://data/planetfall/delve_system.json"
const TABLE_SETUP_DATA := "res://data/planetfall/battlefield_setup.json"
const MISSION_DATA := "res://data/planetfall/mission_types.json"
## Where each mission's objectives go: one placement key per objective type in
## mission_types.json (Discovery markers, colonists, the downed scout, Delve devices).
const PLACEMENT_KEYS := ["marker_placement", "colonist_placement", "scout_placement",
	"device_placement"]
const GROUND_DIE := "Planetfall Ground Type"
const CLUSTER_COUNT_DIE := "Planetfall Cluster Count"
const CLUSTER_TYPE_DIE := "Planetfall Cluster Type"
const CLUSTER_FEATURE_DIE := "Planetfall Cluster Sub-feature"
## p.130 Delve Devices and p.115 Discovery markers: one "in the center of each table
## quarter".
const QUARTER_MARKERS := 4
## p.131 Sleepers!: "Randomly place 2 Sleepers within 6" of the Hazard."
const SLEEPERS_TRAP_COUNT := 2

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
	["hazard_movement", "Hazard movement"],
]

static var _cache: Dictionary = {}


## The opposition a mission actually fields. Only a "slyn_check" mission rolls:
## "After deploying, roll 2D6. If the roll is 2-4, you are attacked by the Slyn ... On any
## other result, the threat is from wildlife, and the Contact system is used" (p.117;
## p.121 Patrol, p.125 Scout Down! with 2-3 and Tactical Enemies). Called at launch,
## after Lock and Load, which is as close to "after deploying" as the app gets.
## {type, slyn_attacking, roll, line}. `slyn_departed`: the Slyn left the colony alone
## (p.157) and "will no longer attack for the rest of this campaign", so nothing rolls.
static func resolve_opposition(mission: Dictionary, slyn_departed: bool = false,
		slyn_assault: bool = false) -> Dictionary:
	# p.167: an infested sector, or the colony the Swarm has reached, is fought against the
	# Swarm, whatever the mission's own opposition.
	if bool(mission.get("swarm", false)):
		return {"type": "swarm", "slyn_attacking": false, "roll": 0,
			"line": "The Swarm (Planetfall pp.167-168)."}
	var opposition: Dictionary = mission.get("opposition", {})
	var raw: String = str(opposition.get("type", "lifeforms"))
	if raw != "slyn_check":
		return {"type": raw, "slyn_attacking": false, "roll": 0, "line": ""}
	var fallback: String = "tactical" if opposition.get("tactical_fallback", false) \
			else "lifeforms"
	if slyn_departed:
		return {"type": fallback, "slyn_attacking": false, "roll": 0,
			"line": "No Slyn check: the Slyn left the colony alone (p.157). %s." % (
				"Tactical Enemies" if fallback == "tactical"
				else "Wildlife, using the Contact system")}
	var setup := MissionSetupScript.new()
	var mid: String = str(mission.get("id", ""))
	var roll: int = _2d6(SLYN_AGGRESSION_DIE)
	var attacking: bool = setup.check_slyn_aggression(mid, roll)
	var aggro: Dictionary = opposition.get("slyn_aggression", {})
	var band: String = "%d-%d" % [int(aggro.get("slyn_range_min", 2)),
		int(aggro.get("slyn_range_max", 4))]
	var none: String = "no Slyn. Tactical Enemies" if fallback == "tactical" \
			else "no Slyn. Wildlife, using the Contact system"
	if not slyn_assault:
		return {"type": "slyn" if attacking else fallback, "slyn_attacking": attacking,
			"roll": roll, "slyn_eight": false, "line": "Slyn check, 2D6 %d (Slyn on %s): %s."
				% [roll, band, "the Slyn attack" if attacking else none]}
	# p.167 Slyn assault: "you must roll twice to see if they interfere. If both rolls
	# indicate interference, you will automatically encounter 8 Slyn."
	var roll2: int = _2d6(SLYN_AGGRESSION_DIE)
	var second: bool = setup.check_slyn_aggression(mid, roll2)
	var eight: bool = attacking and second
	var any: bool = attacking or second
	return {"type": "slyn" if any else fallback, "slyn_attacking": any, "roll": roll,
		"slyn_eight": eight, "line": "Slyn assault (p.167), two Slyn checks, 2D6 %d and %d "
			% [roll, roll2] + "(Slyn on %s): %s." % [band, "both attack, 8 Slyn" if eight
			else ("the Slyn attack" if any else none)]}


## What one mission remembers between reveals: how many Lifeforms have been met (p.146,
## the 6th is a pack leader) and the Unique Ability each Dramatic transformations
## creature rolled for this battle (p.159).
static func new_encounter_state() -> Dictionary:
	return {"encountered": 0, "battle_abilities": {}}


## ── The force, rolled once at launch ────────────────────────────────────────────

## {enemies: [figure dicts for the battle screen], rows: [{head, detail}], enemy_type}.
## `opp_type` is the RESOLVED opposition ("slyn" only when the aggression check said so).
static func build_force(campaign: Resource, opp_type: String, opposition: Dictionary,
		te_index: int, slyn_eight: bool = false) -> Dictionary:
	match opp_type:
		"tactical":
			return tactical_force(campaign, te_index, opposition)
		"slyn":
			return slyn_force(8 if slyn_eight else 0)
		"swarm":
			return swarm_force()
		"delve_hazards":
			return {"enemies": [], "enemy_type": "Sleepers",
				"rows": delve_rows() + sleeper_rows()}
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
	var trait_rules: String = _trait_lines(result.enemies, teg)
	if trait_rules != "":
		result.rows.append({"head": "Weapon traits (p.151)", "detail": trait_rules})
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
	var traits: Array = []
	for w in weapons.get(weapon_key, []):
		if w is Dictionary and not (w as Dictionary).is_empty():
			names.append(_weapon_text(w))
			for t in (w as Dictionary).get("traits", []):
				if not traits.has(str(t)):
					traits.append(str(t))
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
		"weapon_traits": traits,
	}


static func _split(v: Variant) -> Array:
	if v is Array and not (v as Array).is_empty():
		return v
	return [v if v != null else 0]


## p.153: Slyn come "6 or 8 individuals formed into 3 or 4 pairs".
## `fixed_count` > 0 is p.167's Slyn assault: both checks attacked, "8 Slyn".
static func slyn_force(fixed_count: int = 0) -> Dictionary:
	var setup := MissionSetupScript.new()
	var count: int = fixed_count if fixed_count > 0 \
			else setup.get_slyn_encounter_size(_d6(SLYN_SIZE_DIE))
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
	var rows: Array = [{"head": "Slyn: %d, in %d pairs (Planetfall %s)" % [count, count / 2,
		"pp.153, 167" if fixed_count > 0 else "p.153"], "detail": profile_line(prof)}]
	# One reader of slyn_profile.json: PlanetfallMissionSetup loads it once.
	var data: Dictionary = setup.get_slyn_profile()
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
	var traits: Array = []
	for t in w.get("traits", []):
		traits.append(str(t).capitalize())
	var trait_text: String = ("; " + ", ".join(traits)) if not traits.is_empty() else ""
	if int(w.get("range", 0)) > 0:
		text += " (%s\", Shots %s, Damage %+d%s)" % [str(w.get("range", "")),
			str(w.get("shots", "")), int(w.get("damage", 0)), trait_text]
	elif w.has("damage"):
		text += " (Brawling, Damage %+d%s)" % [int(w.get("damage", 0)), trait_text]
	elif not traits.is_empty():
		text += " (%s)" % ", ".join(traits)
	return text


## p.151 Enemy Weapon Traits: each trait the fielded figures carry, once, with its rule
## read from the generator's table, so the card and the data cannot drift apart.
static func _trait_lines(figures: Array, teg) -> String:
	var seen: Array = []
	for f in figures:
		for t in (f as Dictionary).get("weapon_traits", []):
			if not seen.has(str(t)):
				seen.append(str(t))
	var lines: Array = []
	for t in seen:
		var rule: String = str(teg.get_weapon_trait_description(str(t)))
		lines.append(str(t).capitalize() if rule == "" \
			else "%s: %s" % [str(t).capitalize(), rule])
	return "\n".join(lines)


## ── The Battle Card ─────────────────────────────────────────────────────────────

## Rows for the Planetfall Battle Card: [{head, detail}]. `md` is the mission payload the
## turn controller stamped at launch.
static func briefing_rows(md: Dictionary, campaign: Resource) -> Array:
	var rows: Array = []
	for row in md.get("opposition_force_rows", []):
		if row is Dictionary:
			rows.append(row)
	# The mission's own objective tables (pp.115, 123), stamped at launch.
	for row in md.get("objective_rows", []):
		if row is Dictionary:
			rows.append(row)
	rows.append_array(condition_rows(md))
	var opposition: Dictionary = md.get("opposition", {})
	for pair in OPPOSITION_TEXT:
		var text: String = str(opposition.get(pair[0], ""))
		if text != "":
			rows.append({"head": str(pair[1]), "detail": text})
	# p.79: the Grunt upgrades the colony has earned go with every fireteam it fields.
	if int(md.get("grunts_deployed", 0)) > 0:
		rows.append_array(grunt_upgrade_rows(campaign))
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


## The pre-battle checklist for a Planetfall battle, in the order every mission briefing
## prints its setup: Table Setup, Player Forces, Opposition (pp.114-133). Until 2026-10-28
## a Planetfall battle got the Core Rules checklist, which had the player roll for a
## deployment condition and a Notable Sight (Core Rules pp.88-89) and roll to Seize the
## Initiative, while "Planetfall does not have a Seize the Initiative roll" (printed p.27).
## Every hint is the mission's own text (mission_types.json) or p.114's.
static func setup_checklist(md: Dictionary) -> Array[Dictionary]:
	var mission: Dictionary = MissionSetupScript.new().get_mission_briefing(
		str(md.get("type", "")))
	var rules: Variant = _json(MISSION_DATA).get("briefing_rules", {})
	if not rules is Dictionary:
		rules = {}
	var cite: String = "Planetfall p.%d" % int(mission.page) if mission.has("page") \
			else "Planetfall pp.114-133"
	var size: String = str(mission.get("table_size", ""))
	if size == "":
		var ft: String = String.num(float(md.get("table_size_ft", 3.0)))
		size = "%sx%s" % [ft, ft]
	var out: Array[Dictionary] = []
	out.append(_checklist_step("pf_table", "Table Setup",
		"Use a %s-foot table populated with terrain. %s (%s; p.114)"
		% [size, str(rules.get("terrain_placement", "")), cite]))
	var objectives: Variant = mission.get("objectives", {})
	if objectives is Dictionary:
		for key in PLACEMENT_KEYS:
			var where: String = str((objectives as Dictionary).get(key, ""))
			if where != "":
				out.append(_checklist_step("pf_objectives", "Objectives",
					"%s (%s)" % [where, cite]))
				break
	var uncertain: String = uncertain_feature_text(md)
	if uncertain != "":
		out.append(_checklist_step("pf_uncertain", "Uncertain features (optional rule)",
			"Uncertain terrain features: %s. The Battle Card says how they are revealed. "
			% uncertain + "(pp.137-138)"))
	var cond: Variant = md.get("active_condition", {})
	var cond_hint: String = "There are no Battlefield Conditions. (%s)" % cite
	if bool(md.get("battlefield_conditions", false)):
		cond_hint = "Roll once for Battlefield Conditions. (pp.110-113)"
		if cond is Dictionary and not (cond as Dictionary).is_empty():
			cond_hint = "%s: the Battle Card has the rule. (pp.110-113)" \
					% str((cond as Dictionary).get("name", ""))
	out.append(_checklist_step("pf_conditions", "Battlefield Conditions", cond_hint))
	var deploy: String = str(mission.get("deployment", ""))
	if deploy != "":
		out.append(_checklist_step("pf_player", "Player Forces", "%s (%s)" % [deploy, cite]))
	out.append(_checklist_step("pf_opposition", "Opposition",
		"%s The Battle Card gives where this mission's enemies start. %s (p.114)"
		% [str(rules.get("enemy_deployment", "")), str(rules.get("arrivals", ""))]))
	return out


static func _checklist_step(id: String, label: String, hint: String) -> Dictionary:
	return {"id": id, "label": label, "hint": hint, "tier": 0}


## pp.110-113: the Battlefield Condition rolled at Mission Determination is a rule of the
## battle, so the card prints it the way Lock and Load does. Until 2026-10-28 it stopped
## at Lock and Load: the turn controller kept only the selected mission.
## pp.137-138: the Uncertain features the briefing places, and how they are revealed.
static func condition_rows(md: Dictionary) -> Array:
	var rows: Array = []
	var cond: Variant = md.get("active_condition", {})
	if cond is Dictionary and not (cond as Dictionary).is_empty():
		var detail: String = str(cond.get("description", ""))
		var sub: Variant = cond.get("resolved_sub_roll", {})
		if sub is Dictionary and str((sub as Dictionary).get("description", "")) != "":
			detail += "\n" + str((sub as Dictionary).description)
		rows.append({"head": "Battlefield Condition: %s (pp.110-113)" % str(cond.get("name", "")),
			"detail": detail})
	var uncertain: String = uncertain_feature_text(md)
	if uncertain != "":
		var data: Dictionary = _json(UNCERTAIN_DATA)
		rows.append({"head": "Uncertain terrain features: %s (optional rule, pp.137-138)"
				% uncertain,
			"detail": ("Each is a %d\" circle. It cannot be fired across, and enemies cross it "
				+ "as open ground until it is revealed. At the end of each battle round, reveal "
				+ "any within %d\" of a crew member, or within %d\" and in Line of Sight.") % [
				int(data.get("marker_diameter", 0)), int(data.get("reveal_range_close", 0)),
				int(data.get("reveal_range_los", 0))]})
	return rows


## How many Uncertain features the briefing places (p.114 Mission Briefings, verbatim when
## it is a phrase such as "1 per table quarter"), plus the one the Uncertain terrain
## features condition adds. "" when the mission places none and no condition adds one.
static func uncertain_feature_text(md: Dictionary) -> String:
	var v: Variant = md.get("uncertain_features", false)
	var text: String = ""
	if v is String:
		text = str(v)
	elif (v is int or v is float) and int(v) > 0:
		text = str(int(v))
	var cond: Variant = md.get("active_condition", {})
	if cond is Dictionary and str((cond as Dictionary).get("id", "")) == UNCERTAIN_CONDITION:
		var extra: int = int((cond as Dictionary).get("additional_uncertain_features", 0))
		text = "%s, +%d for the Uncertain terrain features condition" % [text, extra] \
				if text != "" else "%d, from the Uncertain terrain features condition" % extra
	return text


## pp.137-138: "roll D100 on the table below. Replace the marker with a suitable terrain
## piece and treat it as the listed terrain thereafter."
static func reveal_uncertain_feature() -> Dictionary:
	var entries: Array = _json(UNCERTAIN_DATA).get("entries", [])
	var roll: int = _d100(UNCERTAIN_DIE)
	var e: Dictionary = _table_entry(entries, roll)
	return {"lines": ["Uncertain feature D100 %d: %s. %s (pp.137-138)." % [roll,
			str(e.get("name", "")), str(e.get("description", ""))]]}


## ── Random Table Setup (pp.143-145, optional rules) ───────────────────────────────────
## ⚠ Until 2026-10-28 a Planetfall battle had no table setup of its own. It counts as a
## standalone battle, so the battle screen rolled the 5PFH COMPENDIUM terrain generator
## (Compendium pp.94-98): the wrong book, with its industrial and wilderness themes, while
## battlefield_setup.json had no reader at all. This rolls the book's four steps up front,
## which is the book's own "Method 3: Roll multiple features up front and then arrange them
## in clusters" (p.144). It returns a battlefield contract in the same shape as
## CampaignPhaseManager._blank_table_contract(): sixteen labelled EMPTY sectors, so the map
## stays a plain grid and never shows a piece the dice did not call for. The rolled result
## is text, and the player lays it out.
static func table_setup_contract(table_size_ft: float, deployment_condition: Dictionary = {},
		rng_seed: int = 0) -> Dictionary:
	var size_ft: float = GridScript.sanitize_table_size(table_size_ft)
	var sectors: Array = []
	for quarter in ["NW", "NE", "SW", "SE"]:
		for n in range(1, 5):
			sectors.append({"label": "%s%d" % [quarter, n], "features": []})
	var notes: Array = []
	var condition_name: String = str(deployment_condition.get("name",
			deployment_condition.get("condition_id", "")))
	if condition_name != "":
		notes.append("Deployment condition in effect: %s" % condition_name)
	var setup: Dictionary = roll_table_setup(size_ft)
	return {
		"theme": "planetfall_table_setup",
		"theme_name": "Random Table Setup (Planetfall pp.143-145)",
		"sectors": sectors,
		"summary": "Optional rules: the dice are rolled up front and you place each cluster "
				+ "yourself (Method 3, p.144). A few rerolls to suit your terrain collection "
				+ "are fine (p.143).",
		"seed": rng_seed,
		"notable_count": 0,
		"feature_count": 0,
		"table_size_ft": size_ft,
		"combat_notes": notes,
		"player_defined_terrain": true,
		"planetfall_table_setup": setup,
		"table_setup_lines": setup.get("lines", []),
	}


## Steps 1-4 (pp.143-144), every die through DiceManager. Step 2 tallies the 12" clusters
## that fit ("If in doubt, you can make the clusters 12" square, fitting 9 of them in a 3x3
## foot table") and then applies the optional "roll 1D6-3. If the result is negative, reduce
## the total number of clusters by this amount", because rolling the table is the
## randomize-every-aspect path. Step 4 is rolled for every cluster and the closing line says
## which clusters skip it: only the table in front of the player shows whether a cluster
## still has open space.
static func roll_table_setup(size_ft: float) -> Dictionary:
	var data: Dictionary = _json(TABLE_SETUP_DATA)
	var org: Dictionary = data.get("step_2_cluster_organization", {})
	var cluster_in: int = maxi(int(org.get("default_cluster_size", 12)), 1)
	var per_side: int = int(floor(size_ft * 12.0 / float(cluster_in)))
	var fit: int = per_side * per_side
	var reduction: int = _d6(CLUSTER_COUNT_DIE) - 3
	var count: int = fit + mini(reduction, 0)
	var randomize_count: Dictionary = org.get("randomize_count", {})
	var formula: String = str(randomize_count.get("formula", ""))
	var ground: Dictionary = _d100_entry(_table_rows(data, "step_1_ground_type"), GROUND_DIE)
	var g: Dictionary = ground.get("entry", {})
	var lines: Array = ["Ground (D100 %d): %s." % [int(ground.get("roll", 0)),
			str(g.get("name", ""))]]
	var outcome: String = ("use %d" % count) if reduction < 0 \
			else ("no reduction, use %d" % count)
	lines.append("Clusters: %d of %d\" fit a %.1f ft table; optional %s = %d, so %s (p.144). "
			% [fit, cluster_in, size_ft, formula, reduction, outcome]
			+ "Table space outside a cluster is empty.")
	var types: Array = _table_rows(data, "step_3_cluster_type")
	var subs: Array = _table_rows(data, "step_4_cluster_sub_feature")
	var clusters: Array = []
	for i in range(count):
		var t: Dictionary = _d100_entry(types, CLUSTER_TYPE_DIE)
		var s: Dictionary = _d100_entry(subs, CLUSTER_FEATURE_DIE)
		var te: Dictionary = t.get("entry", {})
		var se: Dictionary = s.get("entry", {})
		clusters.append({"type": str(te.get("id", "")), "type_roll": int(t.get("roll", 0)),
				"sub_feature": str(se.get("id", "")),
				"sub_feature_roll": int(s.get("roll", 0))})
		lines.append("Cluster %d: %s (D100 %d). %s Sub-feature (D100 %d): %s. %s" % [i + 1,
				str(te.get("name", "")), int(t.get("roll", 0)), str(te.get("description", "")),
				int(s.get("roll", 0)), str(se.get("name", "")), str(se.get("description", ""))])
	var step4: Dictionary = data.get("step_4_cluster_sub_feature", {})
	lines.append("Sub-features (p.144): %s" % str(step4.get("_note", "")))
	var review: Dictionary = data.get("make_adjustments", {})
	lines.append("Make Adjustments (pp.144-145): %s" % str(review.get("description", "")))
	var adjust: Dictionary = data.get("map_adjustments", {})
	lines.append("Map Adjustments (p.145): %s" % str(adjust.get("description", "")))
	return {"ground": str(g.get("id", "")), "ground_roll": int(ground.get("roll", 0)),
			"clusters_fit": fit, "cluster_count_roll": reduction, "clusters": clusters,
			"lines": lines}


static func _table_rows(data: Dictionary, key: String) -> Array:
	var table: Variant = data.get(key, {})
	return (table as Dictionary).get("entries", []) if table is Dictionary else []


## p.123 Skirmish: "Roll 1D6 twice on the Skirmish Objective table below to determine what
## you are here to do. Each objective is placed randomly 1D6+1" from the center of the
## table." A table-setup roll, so the turn controller makes it once, at launch, and stamps
## it on the mission; any other mission rolls nothing. Until 2026-10-28 the table was read
## only by PlanetfallMissionSetup.resolve_mission_objective(), which nothing called, while
## the mission screen told the player to roll it.
static func roll_skirmish_objectives(mission: Dictionary) -> Array:
	var rolled: Array = []
	var entries: Array = _objective_table(mission, "skirmish_objective_table")
	if entries.is_empty():
		return rolled
	for _i in range(2):
		var roll: int = _d6(SKIRMISH_DIE)
		var entry: Dictionary = _table_entry(entries, roll)
		rolled.append({"roll": roll, "id": str(entry.get("id", "")),
			"name": str(entry.get("name", "")),
			"description": str(entry.get("description", "")),
			"distance": _d6(SKIRMISH_PLACEMENT_DIE) + 1})
	return rolled


## Battle Card rows for a mission's own objective tables: the Skirmish objectives rolled at
## launch (p.123), and the D6 an Investigation rolls "immediately" whenever a Discovery
## marker is investigated (p.115), printed from the data the mission is built from.
static func objective_rows(mission: Dictionary, skirmish: Array) -> Array:
	var rows: Array = []
	for i in range(skirmish.size()):
		var o: Dictionary = skirmish[i]
		rows.append({"head": "Skirmish Objective %d: %s (D6 %d, Planetfall p.123)"
				% [i + 1, str(o.get("name", "")), int(o.get("roll", 0))],
			"detail": "%s Place it %d\" from the center of the table, in a random direction."
				% [str(o.get("description", "")), int(o.get("distance", 0))]})
	var objectives: Dictionary = mission.get("objectives", {}) \
			if mission.get("objectives") is Dictionary else {}
	if not skirmish.is_empty() and str(objectives.get("carry_items", "")) != "":
		rows.append({"head": "Carrying items (Planetfall p.123)",
			"detail": str(objectives.get("carry_items", ""))})
	var discovery: Array = _objective_table(mission, "investigation_table")
	if discovery.is_empty():
		return rows
	rows.append({"head": "Discovery markers (Planetfall p.115)",
		"detail": "Move within %d\" of a marker to investigate it: remove it and roll 1D6 "
			% int(objectives.get("investigate_range", 2)) + "at once."})
	for e in discovery:
		if e is Dictionary:
			rows.append({"head": "Discovery %s: %s" % [_range_label(e),
					str(e.get("id", "")).capitalize()],
				"detail": str(e.get("result", ""))})
	# A 1 places a Sleeper (p.115), armed by its own die (p.154).
	rows.append_array(sleeper_rows())
	return rows


static func _objective_table(mission: Dictionary, key: String) -> Array:
	var objectives: Variant = mission.get("objectives", {})
	if not objectives is Dictionary:
		return []
	var table: Variant = (objectives as Dictionary).get(key, {})
	return (table as Dictionary).get("entries", []) if table is Dictionary else []


static func _table_entry(entries: Array, roll: int) -> Dictionary:
	for e in entries:
		if e is Dictionary and roll >= int(e.get("min", 0)) and roll <= int(e.get("max", 0)):
			return e
	return {}


static func _range_label(e: Dictionary) -> String:
	var lo: int = int(e.get("min", 0))
	var hi: int = int(e.get("max", 0))
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]


## ── Sleepers, Delve markers and Discovery markers during play (pp.115, 130-133, 154) ──
## The app rolls these when the player says a marker was revealed or a Sleeper placed,
## the way it rolls a Contact Reveal. ⚠ Until 2026-10-28 delve_system.json had no reader:
## a Delve showed one Sleeper stat line, and none of its four tables, the Sleeper's weapon
## die or an Investigation's Discovery table was rolled or printed anywhere in the app.

static func new_mission_tools_state() -> Dictionary:
	return {"devices": [], "activated": 0, "artifact_placed": false, "discoveries": 0}


## The missions whose markers roll tables of their own during the battle.
static func has_mission_tools(mission_id: String) -> bool:
	return mission_id in ["delve", "investigation"]


## p.154: "When each Sleeper is placed on the table, roll 1D6 to determine what weapon it
## is carrying."
static func place_sleeper() -> Dictionary:
	var sleeper: Dictionary = MissionSetupScript.new().get_sleeper_profile()
	var roll: int = _d6(SLEEPER_WEAPON_DIE)
	var w: Dictionary = _table_entry(_entries(sleeper, "weapons"), roll)
	return {"lines": ["Sleeper placed. Weapon D6 %d: %s (p.154)." % [roll, _weapon_stats(w)]]}


## p.130: "Delve Hazards are revealed if at any point a crew member is within 3" and Line
## of Sight. Roll 1D6 immediately": 1-2 a Sleeper, 3-4 the Delve Trap table (p.131), 5-6
## the Environmental Hazard table (p.132).
static func reveal_delve_hazard() -> Dictionary:
	var data: Dictionary = _json(DELVE_DATA)
	var roll: int = _d6(DELVE_HAZARD_DIE)
	var hazard: Dictionary = _table_entry(_entries(data, "hazard_reveal"), roll)
	var lines: Array = []
	match str(hazard.get("id", "")):
		"enemy":
			lines.append("Delve Hazard D6 %d: %s. %s (p.130)." % [roll,
					str(hazard.get("name", "")), str(hazard.get("description", ""))])
			lines.append_array(place_sleeper().lines)
		"trap":
			lines.append("Delve Hazard D6 %d: %s (p.130)." % [roll, str(hazard.get("name", ""))])
			var trap: Dictionary = _d100_entry(_entries(data, "traps"), DELVE_TRAP_DIE)
			lines.append("Delve Trap D100 %d: %s. %s (p.131)." % [int(trap.roll),
					str(trap.entry.get("name", "")), str(trap.entry.get("description", ""))])
			if str(trap.entry.get("id", "")) == "sleepers":
				for _i in range(SLEEPERS_TRAP_COUNT):
					lines.append_array(place_sleeper().lines)
		"environmental_hazard":
			lines.append("Delve Hazard D6 %d: %s (p.130)." % [roll, str(hazard.get("name", ""))])
			var env: Dictionary = _d100_entry(_entries(data, "environmental_hazards"),
					ENVIRONMENT_DIE)
			lines.append("Environmental Hazard D100 %d: %s. %s (p.132)." % [int(env.roll),
					str(env.entry.get("name", "")), str(env.entry.get("description", ""))])
	return {"lines": lines}


## p.133: "Roll 1D6 on the table below. If you roll a result you have already had, take the
## first result you have not." There are four Devices, one per table quarter (p.130).
static func roll_delve_device(state: Dictionary) -> Dictionary:
	var had: Array = state.get("devices", [])
	if had.size() >= QUARTER_MARKERS:
		return {"lines": ["All four Delve Devices have been rolled (p.130)."]}
	var entries: Array = _entries(_json(DELVE_DATA), "device_activation")
	var roll: int = _d6(DELVE_DEVICE_DIE)
	var e: Dictionary = _table_entry(entries, roll)
	var note: String = ""
	if str(e.get("id", "")) in had:
		for candidate in entries:
			if candidate is Dictionary and str(candidate.get("id", "")) not in had:
				e = candidate
				note = ", already had: the first result not yet had is"
				break
	had.append(str(e.get("id", "")))
	state["devices"] = had
	return {"lines": ["Delve Device D6 %d%s %s. %s (p.133)." % [roll, note,
			str(e.get("name", "")), str(e.get("description", ""))]]}


## p.133: "When you have performed 3 activations (not counting an "Unusable" result on the
## table), you unlock the location of the Artifact. It is placed 2D6" randomly from the
## center of the table." An activation needs a Device whose method has been rolled.
static func record_device_activation(state: Dictionary) -> Dictionary:
	var needed: int = int((_json(DELVE_DATA).get("device_activation", {}) as Dictionary)
			.get("activations_required", 3))
	if bool(state.get("artifact_placed", false)):
		return {"lines": ["The Artifact's location is already unlocked (p.133)."]}
	var usable: int = 0
	for id in state.get("devices", []):
		if str(id) != "unusable":
			usable += 1
	var done: int = int(state.get("activated", 0))
	if done >= usable:
		return {"lines": ["No rolled Delve Device is waiting to be activated; an Unusable "
				+ "one never counts (p.133)."]}
	done += 1
	state["activated"] = done
	if done < needed:
		return {"lines": ["Delve Device activated: %d of %d (p.133)." % [done, needed]]}
	state["artifact_placed"] = true
	return {"lines": ["Delve Device activated: %d of %d. The Artifact's location is unlocked: "
			% [done, needed] + "place it %d\" from the center of the table, in a random "
			% _2d6(DELVE_ARTIFACT_DIE) + "direction. Any character can pick it up by moving "
			+ "into base contact (p.133)."]}


## p.115: a Discovery marker "is removed, and you immediately roll 1D6 on the table below".
## Read from the mission's own briefing; four markers, one per table quarter.
static func investigate_discovery(mission_id: String, state: Dictionary) -> Dictionary:
	var entries: Array = _objective_table(
			MissionSetupScript.new().get_mission_briefing(mission_id), "investigation_table")
	if entries.is_empty():
		return {"lines": []}
	var done: int = int(state.get("discoveries", 0))
	if done >= QUARTER_MARKERS:
		return {"lines": ["All four Discovery markers have been investigated (p.115)."]}
	state["discoveries"] = done + 1
	var roll: int = _d6(DISCOVERY_DIE)
	var e: Dictionary = _table_entry(entries, roll)
	var lines: Array = ["Discovery marker %d, D6 %d: %s. %s (p.115)." % [done + 1, roll,
			str(e.get("id", "")).capitalize(), str(e.get("result", ""))]]
	if str(e.get("id", "")) == "enemy":
		lines.append_array(place_sleeper().lines)
	return {"lines": lines}


## The Delve's own tables on the Battle Card (pp.130, 133), from delve_system.json.
static func delve_rows() -> Array:
	var data: Dictionary = _json(DELVE_DATA)
	var rows: Array = []
	var reveal: Array = []
	for e in _entries(data, "hazard_reveal"):
		if e is Dictionary:
			reveal.append("%s %s" % [_range_label(e), str(e.get("name", ""))])
	if not reveal.is_empty():
		rows.append({"head": "Delve Hazard, 1D6 as each is revealed (Planetfall p.130)",
			"detail": "; ".join(reveal) + ". The app rolls the Trap (p.131) and "
				+ "Environmental Hazard (p.132) tables."})
	var device: Dictionary = data.get("device_activation", {}) \
			if data.get("device_activation") is Dictionary else {}
	var methods: Array = []
	for e in _entries(data, "device_activation"):
		if e is Dictionary:
			methods.append("%s %s: %s" % [_range_label(e), str(e.get("name", "")),
					str(e.get("description", ""))])
	if not methods.is_empty():
		rows.append({"head": "Delve Device, 1D6 on base contact and an action (Planetfall p.133)",
			"detail": "; ".join(methods) + ". A repeated result takes the first result not "
				+ "yet had. " + str(device.get("_note", ""))})
	return rows


## p.154 The Sleepers: the profile and force screen, the weapon die "when each Sleeper is
## placed", Rapid Fire, and Stun and Panic, from sleeper_profile.json.
static func sleeper_rows() -> Array:
	var s: Dictionary = MissionSetupScript.new().get_sleeper_profile()
	if s.is_empty():
		return []
	var prof: Dictionary = s.get("profile", {}) if s.get("profile") is Dictionary else {}
	var screen: Dictionary = prof.get("force_screen", {}) \
			if prof.get("force_screen") is Dictionary else {}
	var rows: Array = [{"head": "Sleepers (Planetfall p.154)",
		"detail": "%s. %s" % [profile_line(prof), str(screen.get("description", ""))]}]
	var weapons: Array = []
	for w in _entries(s, "weapons"):
		if w is Dictionary:
			weapons.append("%s %s" % [_range_label(w), _weapon_stats(w)])
	if not weapons.is_empty():
		rows.append({"head": "Sleeper weapon, 1D6 as each is placed (Planetfall p.154)",
			"detail": "; ".join(weapons) + "."})
	var rf: Dictionary = s.get("rapid_fire", {}) if s.get("rapid_fire") is Dictionary else {}
	if not rf.is_empty():
		rows.append({"head": "Rapid Fire (Planetfall p.154)", "detail": " ".join([
			str(rf.get("trigger", "")), str(rf.get("effect", "")),
			str(rf.get("exit_condition", "")), str(rf.get("persist", ""))])})
	if bool(s.get("cannot_be_stunned", false)) and bool(s.get("fearless", false)):
		rows.append({"head": "Sleepers cannot be Stunned and are Fearless, immune to Panic "
				+ "(Planetfall p.154)", "detail": ""})
	return rows


static func _weapon_stats(w: Dictionary) -> String:
	return "%s, Range %d\", Shots %d, Damage %d" % [str(w.get("name", "")),
			int(w.get("range", 0)), int(w.get("shots", 0)), int(w.get("damage", 0))]


static func _entries(data: Dictionary, key: String) -> Array:
	var table: Variant = data.get(key, {})
	return (table as Dictionary).get("entries", []) if table is Dictionary else []


static func _d100_entry(entries: Array, die: String) -> Dictionary:
	var roll: int = _d100(die)
	return {"roll": roll, "entry": _table_entry(entries, roll)}


## p.79 Grunt upgrades "benefit your grunt fireteams and become available when their
## listed prerequisites ... are met". One row each, in the book's words, from the same
## check Step 9's survival roll uses (PlanetfallPhaseManager.grunt_upgrade_ids).
static func grunt_upgrade_rows(campaign: Resource) -> Array:
	var rows: Array = []
	if campaign == null:
		return rows
	for u in ArmoryScript.new().get_available_grunt_upgrades(campaign, ResearchScript.new()):
		rows.append({"head": "Grunt upgrade: %s (Planetfall p.79)" % str(u.get("name", "")),
			"detail": str(u.get("description", ""))})
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


## p.168: "Roll 2D6+4 for the number of Swarm encountered", every one on the Swarm profile.
## Fought in a Skirmish in an infested sector (p.167), or in the Pitched Battle the Swarm
## forces when it reaches the colony.
static func swarm_force() -> Dictionary:
	var prof: Dictionary = CalamityScript.new().swarm_profile()
	var count: int = _2d6(CalamityScript.SWARM_NUMBER_DIE) + CalamityScript.SWARM_NUMBER_BONUS
	var claws: String = "Brawling: %s" % str(prof.get("brawling", ""))
	var enemies: Array = []
	for _i in range(count):
		enemies.append({"name": "Swarm", "type": "swarm", "role": "swarm",
				"speed": int(prof.get("speed", 0)), "combat_skill": int(prof.get("combat_skill", 0)),
				"toughness": int(prof.get("toughness", 0)), "kp": 0, "weapons": [claws]})
	return {"enemies": enemies, "enemy_type": "Swarm", "rows": [{
		"head": "The Swarm: 2D6+%d = %d (Planetfall p.168)"
				% [CalamityScript.SWARM_NUMBER_BONUS, count],
		"detail": "Speed %d\", Combat Skill %+d, Toughness %d. %s. Ranged attack: %s." % [
				int(prof.get("speed", 0)), int(prof.get("combat_skill", 0)),
				int(prof.get("toughness", 0)), claws, str(prof.get("ranged", "none"))]}]}


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
	# p.92: a Bio-Analysis benefit "is applied whenever you do combat with the specific
	# Lifeform in the future".
	var bio: Variant = p.get("bio_analysis", {})
	if bio is Dictionary and str(bio.get("name", "")) != "":
		extras.append("Bio-Analysis, %s: %s" % [str(bio.name), str(bio.get("description", ""))])
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
