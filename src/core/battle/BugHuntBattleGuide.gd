class_name BugHuntBattleGuide
extends RefCounted

## What a Bug Hunt battle asks the players to do at the table: Compendium pp.190-199.
##
## ⚠ Before 2026-10-27 the battle screen read none of the mission it was handed.
## BugHuntBattleSetup built the Contact markers, Tactical Locations, Signals, Spawn
## Points and the Contact, movement and detection rules, and TacticalBattleUI showed the
## 5PFH Battle Card and the 5PFH end-of-round checklist instead. The book's round
## procedure (the "Beep... Sir?" spawning, the Spawn Point countdowns, Living
## Nightmare's top-up) reached nobody.
##
## This is a companion app: everything here is TEXT for the players, built from the
## same data the setup read, so a number printed here is the number the rule uses.
## Pure and static: the battle screen passes the flat mission payload and renders the
## rows. Nothing here rolls or mutates.

const CITE_CONTACTS := "Compendium p.190"
const CITE_DETECTION := "Compendium p.192"
const CITE_CONTACT_TABLE := "Compendium p.193"
const CITE_NUMBERS := "Compendium p.194"
const CITE_TAC_LOCS := "Compendium p.191"
const CITE_SIGNALS := "Compendium p.208"
const CITE_SPAWN := "Compendium p.199"
const CITE_DIFFICULTY := "Compendium p.186"
const CITE_LOADOUT := "Compendium p.187"
const CITE_SUPPORT := "Compendium pp.188-189"
const CITE_EVAC := "Compendium p.201"


## Rows for the Bug Hunt Battle Card: [{head, detail}].
static func briefing_rows(md: Dictionary) -> Array:
	var rows: Array = []

	for obj in _as_array(md.get("objectives", [])):
		if obj is not Dictionary:
			continue
		var t: Dictionary = obj.get("type", {}) if obj.get("type", {}) is Dictionary else {}
		var rating: String = str(obj.get("rating", "normal"))
		var tag: String = "" if rating == "normal" else " [%s, counts as %d]" % [
			rating.to_upper(), int(obj.get("weight", 1))]
		rows.append({"head": "◆ Objective %d%s: %s" % [
				int(obj.get("die_value", 0)), tag, str(t.get("name", "Objective"))],
			"detail": str(t.get("achieved_when", ""))})

	var kit: Array[String] = []
	var loadout: Dictionary = md.get("loadout", {}) if md.get("loadout", {}) is Dictionary else {}
	for char_id in loadout:
		var pick: Dictionary = loadout[char_id] if loadout[char_id] is Dictionary else {}
		var line: String = "%s: %s" % [str(pick.get("name", char_id)),
			_weapon_name(md, str(pick.get("weapon", "")))]
		if bool(pick.get("hand_cannon", false)):
			line += ", %s in place of the %s" % [_weapon_name(md, "hand_cannon"),
				_weapon_name(md, "service_pistol")]
		kit.append(line)
	if not kit.is_empty():
		rows.append({"head": "Loadout for this mission (%s)" % CITE_LOADOUT,
			"detail": "\n".join(kit)})

	var arrived: Array[String] = []
	for s in _as_array(md.get("support", [])):
		if s is not Dictionary:
			continue
		if bool(s.get("approved", false)):
			arrived.append("✓ %s: %s" % [str(s.get("name", "")), str(s.get("contents", ""))])
		else:
			arrived.append("✗ %s denied (rolled %d, needed %d+)" % [str(s.get("name", "")),
				int(s.get("roll", 0)), int(s.get("target", 0))])
	if not arrived.is_empty():
		rows.append({"head": "Support requested (%s)" % CITE_SUPPORT,
			"detail": "\n".join(arrived)})

	var contacts: int = _as_array(md.get("contact_markers", [])).size()
	var detection: Dictionary = _rules(md, "contact_rules").get("detection", {})
	rows.append({"head": "Contacts: %d marker(s) (%s)" % [contacts, CITE_CONTACTS],
		"detail": "One on each Objective, the rest in the centre of the table. Detected "
			+ "within %s; within %s if in cover or out of sight. %s (%s)" % [
				_strip_detected(str(detection.get("in_sight_no_cover", "6\""))),
				_strip_detected(str(detection.get("in_cover_or_no_sight", "3\""))),
				str(detection.get("note", "")), CITE_DETECTION]})

	var movement: Dictionary = _rules(md, "contact_rules").get("movement", {})
	if not movement.is_empty():
		var move_lines: Array[String] = [str(movement.get("aggression_die", "")),
			str(movement.get("chance_die", "")), str(movement.get("equal", ""))]
		var patrolled: Dictionary = _coop_rule(md, "aggression_die_bonus")
		if not patrolled.is_empty():
			move_lines.insert(1, _coop_words(patrolled))
		rows.append({"head": "Contact movement (Enemy Action phase)",
			"detail": "\n".join(move_lines)})

	var reveal: Array[String] = []
	for row in _as_array(_rules(md, "contact_rules").get("contact_table", [])):
		if row is Dictionary:
			reveal.append("%s %s: %s" % [_d6_label(row), str(row.get("name", "")),
				str(row.get("effect", ""))])
	reveal.append(numbers_line(md))
	rows.append({"head": "Detecting a Contact: roll 1D6 (%s)" % CITE_CONTACT_TABLE,
		"detail": "\n".join(reveal)})

	var locs: Array[String] = []
	for loc in _as_array(md.get("tactical_locations", [])):
		if loc is Dictionary:
			locs.append("%s: %s" % [str(loc.get("name", "")), str(loc.get("effect", ""))])
	if not locs.is_empty():
		rows.append({"head": "Tactical Locations: %d (%s)" % [locs.size(), CITE_TAC_LOCS],
			"detail": "\n".join(locs)})

	var signals: int = _as_array(md.get("signals", [])).size()
	if signals > 0:
		rows.append({"head": "Signals: %d (%s)" % [signals, CITE_SIGNALS],
			"detail": "Placed in or next to terrain. With 4 or more, investigate at least 2 "
				+ "or lose an Objective."})

	var rating: int = int(md.get("spawn_rating", 0))
	if rating > 0:
		var closing: Dictionary = _rules(md, "spawn_point_rules").get("closing_down", {})
		rows.append({"head": "Spawn Rating %d: %d Spawn Point(s), one revealed each round (%s)"
				% [rating, rating, CITE_SPAWN],
			"detail": " ".join([str(closing.get("description", "")),
				str(closing.get("roll", "")), str(closing.get("assist", ""))]).strip_edges()})

	var special: String = str(_difficulty(md).get("special_rule", ""))
	if special != "" and special != "<null>":
		rows.append({"head": "%s (%s)" % [str(_difficulty(md).get("name", "Difficulty")),
			CITE_DIFFICULTY], "detail": special})

	var evac: Dictionary = evac_rules()
	if not evac.is_empty():
		# A co-op sector's Hot zone (no loitering) and Obstructed (no covering fire)
		# replace the lines they overrule, rather than sitting beside them.
		var no_loiter: Dictionary = _coop_rule(md, "evac_can_loiter")
		var no_cover: Dictionary = _coop_rule(md, "evac_covering_fire")
		rows.append({"head": "Evac: request it from Round %d (%s)" % [
				int(evac.get("available_from_round", 0)), CITE_EVAC],
			"detail": "\n".join([str(evac.get("description", "")), _evac_roll_line(evac),
				str(evac.get("arrival", "")),
				_coop_words(no_loiter) if not no_loiter.is_empty()
					else "If %d rounds pass, the drop ship leaves and you must call again."
						% int(evac.get("loiter_rounds", 0)),
				str(evac.get("priority_increase", "")),
				_coop_words(no_cover) if not no_cover.is_empty()
					else str(evac.get("supporting_fire", ""))])})
	return rows


## p.201 "We're leaving!". ⚠ Until 2026-10-28 nothing read it: the census counted the
## dashboard's Movie Magic literal ["evac", "Evac"] as its reader, and when that list
## moved to data the rule was left with none. No Bug Hunt screen told the players when
## they could call the drop ship, what to roll, or what happens when it arrives.
static func evac_rules() -> Dictionary:
	return _as_dict(_load_json(MISSIONS_PATH).get("evac", {}))


static func _evac_roll_line(evac: Dictionary) -> String:
	return "Roll %s. %s. On %d+ it comes; %s" % [str(evac.get("roll", "")),
		str(evac.get("savvy_bonus", "")), int(evac.get("success_threshold", 0)),
		str(evac.get("retry", "")).to_lower()]


## The p.194 Numbers line, with the difficulty's adjustment applied in words.
static func numbers_line(md: Dictionary) -> String:
	var mod: int = int(_difficulty(md).get("numbers_modifier", 0))
	var adj: String = ""
	if mod != 0:
		adj = " %s%d per marker on %s" % ["+" if mod > 0 else "−", absi(mod),
			str(_difficulty(md).get("name", "this difficulty"))]
	var swarming: Dictionary = _coop_rule(md, "enemies_per_contact_bonus")
	if not swarming.is_empty():
		adj += ". " + _coop_words(swarming).trim_suffix(".")
	return ("CONTACT! numbers: roll the Numbers column of the Enemy table%s. Every enemy "
		+ "in a mission is the same type (%s).") % [adj, CITE_NUMBERS]


## Co-op (Compendium p.210): a sector's Factors and enemy conditions change rules this
## card states, so the line they change is rewritten in the data row's own words instead
## of leaving a separate row the players must reconcile with it. md["coop"] is
## BugHuntMissionPanel's stamp; its `modifiers` are BugHuntCoopCampaign.battle_modifiers(),
## whose entries carry their own `battle` keys. {} outside co-op or without that key.
static func _coop_rule(md: Dictionary, battle_key: String) -> Dictionary:
	var mods: Dictionary = _as_dict(_as_dict(md.get("coop", {})).get("modifiers", {}))
	for entry in _as_array(mods.get("factors", [])) + _as_array(mods.get("conditions", [])):
		if entry is Dictionary and _as_dict(entry.get("battle", {})).has(battle_key):
			return entry
	return {}


static func _coop_words(entry: Dictionary) -> String:
	return "%s: %s" % [str(entry.get("name", "")), str(entry.get("effect", ""))]


## End-of-round prompts in TacticalBattleUI's {text, roll} shape. `round_number` is the
## round just ending, so the "Beep... Sir?" roll is for the round about to start.
static func round_end_prompts(round_number: int, md: Dictionary) -> Array:
	var prompts: Array = []
	if round_number <= 0:
		return prompts

	var rating: int = int(md.get("spawn_rating", 0))
	if rating > 0:
		var phases: Dictionary = _rules(md, "spawn_point_rules").get("phases", {})
		var lines: Array[String] = []
		if round_number <= rating:
			lines.append("Reveal Spawn Point %d of %d: %s" % [round_number, rating,
				str(phases.get("step_1_reveal", ""))])
		lines.append(str(phases.get("step_2_increment", "")))
		lines.append(str(phases.get("step_3_place_countdown", "")))
		prompts.append({"text": "Spawn Points (%s): %s" % [CITE_SPAWN, " ".join(lines)],
			"roll": "1D6 per Spawn Point"})

	var diff: Dictionary = _difficulty(md)
	var special: String = str(diff.get("special_rule", ""))
	if special != "" and special != "<null>":
		prompts.append({"text": "%s (%s): %s" % [str(diff.get("name", "")),
			CITE_DIFFICULTY, special], "roll": "a random edge"})

	var priority: int = maxi(int(md.get("priority", 0)), 0)
	if priority > 0:
		var per_six: bool = bool(diff.get("reinforcement_contact_per_six", false))
		prompts.append({"text": ("Start of Round %d, \"Beep... Sir?\" (%s): roll %dD6 "
				+ "(the mission Priority). %s Place each at the battlefield edge a random "
				+ "direction die from the centre points to, then check for Detection: if "
				+ "it is Detected, every figure within 12\" may fire at the revealed "
				+ "enemies as a bonus action.") % [round_number + 1, CITE_CONTACT_TABLE,
				priority, "Each 6 places one new Contact marker (Living Nightmare)."
					if per_six else "If any die is a 6, place one new Contact marker."],
			"roll": "%dD6" % priority})

	# p.201: Evac opens at a set round, and a failed call is rolled again at the end of
	# every round until the drop ship comes.
	var evac: Dictionary = evac_rules()
	var opens: int = int(evac.get("available_from_round", 0))
	if opens > 0 and round_number == opens - 1:
		prompts.append({"text": "From Round %d you can request Evac (%s): %s" % [opens,
			CITE_EVAC, _evac_roll_line(evac)], "roll": str(evac.get("roll", ""))})
	elif opens > 0 and round_number >= opens:
		prompts.append({"text": "Evac called and not yet here? (%s) %s" % [CITE_EVAC,
			_evac_roll_line(evac)], "roll": str(evac.get("roll", ""))})
	return prompts


const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"
const TACTICAL_LOCATIONS_PATH := "res://data/bug_hunt/bug_hunt_tactical_locations.json"


## The pre-battle checklist for a Bug Hunt battle: the steps of p.184's Mission
## Generation the players carry out at the table. Steps 3-7 (difficulty, Priority,
## Spawn Rating, load-out, force strength) were done before launch, and the Battle Card
## above the checklist shows what they produced, so the list keeps the book's numbering
## and the gap says so.
##
## ⚠ Before 2026-10-28 a Bug Hunt battle got the Core Rules checklist: roll the p.88
## Deployment Conditions and p.89 Notable Sight tables, Seize the Initiative, run the
## 5PFH Enemy Generation Wizard, and deploy "within your deployment zone". Bug Hunt has
## none of them. Its troops land within 3" of a random edge (p.190), and each round opens
## with Reaction dice, not an initiative roll (p.198).
static func setup_checklist(md: Dictionary) -> Array[Dictionary]:
	var m: Dictionary = _load_json(MISSIONS_PATH)
	var names: Array = _as_array(m.get("setup_steps", []))
	var area: Dictionary = _as_dict(m.get("battle_area", {}))
	var obj: Dictionary = _as_dict(m.get("objectives", {}))
	var contacts: Dictionary = _as_dict(m.get("initial_contacts", {}))
	var deploy: Dictionary = _as_dict(m.get("deployment", {}))
	var locations: Dictionary = _as_dict(_load_json(TACTICAL_LOCATIONS_PATH).get(
		"tactical_locations", {}))
	var objectives_kept: int = _as_array(md.get("objectives", [])).size()
	var out: Array[Dictionary] = []
	out.append(_step("bh_battle_area", names, 1,
		"%s (Compendium p.184)" % str(area.get("description", ""))))
	# The 3D6 that decides which dice stay was rolled before launch: say so, rather than
	# print the data's "Roll 3D6" sentence and have the players roll it again.
	out.append(_step("bh_objectives", names, 2,
		"Place six dice showing 1 to 6. %s Keep the %d the Battle Card names as Objectives "
		% [str(obj.get("placement_rule", "")), objectives_kept]
		+ "and remove the rest. (Compendium p.185)"))
	out.append(_step("bh_markers", names, 8, "%s %s The Battle Card gives the counts. (Compendium p.190)"
		% [str(locations.get("placement", "")), str(contacts.get("description", ""))]))
	out.append(_step("bh_troops", names, 9, "%s %s (Compendium p.190)" % [
		str(deploy.get("description", "")), str(deploy.get("objective_distance", ""))]))
	return out


static func _step(id: String, names: Array, number: int, hint: String) -> Dictionary:
	var name: String = str(names[number - 1]) if names.size() >= number else ""
	return {"id": id, "label": "Step %d: %s" % [number, name], "hint": hint, "tier": 0}


static func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func _difficulty(md: Dictionary) -> Dictionary:
	var d: Variant = md.get("difficulty_rules", {})
	return d if d is Dictionary else {}


static func _rules(md: Dictionary, key: String) -> Dictionary:
	var d: Variant = md.get(key, {})
	return d if d is Dictionary else {}


static func _as_array(v: Variant) -> Array:
	return v if v is Array else []


## A weapon's book name from the payload's own weapons table, so the card cannot
## name a weapon the data does not.
static func _weapon_name(md: Dictionary, weapon_id: String) -> String:
	for w in _as_array(md.get("weapons_table", [])):
		if w is Dictionary and str(w.get("id", "")) == weapon_id:
			return str(w.get("name", weapon_id))
	return weapon_id


static func _d6_label(row: Dictionary) -> String:
	if row.has("d6_range") and row.d6_range is Array and (row.d6_range as Array).size() >= 2:
		return "%d-%d" % [int(row.d6_range[0]), int(row.d6_range[1])]
	return str(int(row.get("d6_value", 0)))


static func _strip_detected(text: String) -> String:
	return text.replace("Detected within ", "").trim_suffix(".")
