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
		rows.append({"head": "Contact movement (Enemy Action phase)",
			"detail": "\n".join([str(movement.get("aggression_die", "")),
				str(movement.get("chance_die", "")), str(movement.get("equal", ""))])})

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
	return rows


## The p.194 Numbers line, with the difficulty's adjustment applied in words.
static func numbers_line(md: Dictionary) -> String:
	var mod: int = int(_difficulty(md).get("numbers_modifier", 0))
	var adj: String = ""
	if mod != 0:
		adj = " %s%d per marker on %s" % ["+" if mod > 0 else "−", absi(mod),
			str(_difficulty(md).get("name", "this difficulty"))]
	return ("CONTACT! numbers: roll the Numbers column of the Enemy table%s. Every enemy "
		+ "in a mission is the same type (%s).") % [adj, CITE_NUMBERS]


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
	return prompts


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
