extends RefCounted

## Planetfall character backgrounds (pp.21-23): every founding character rolls a
## Motivation; the four the player defines as experienced also roll Prior Experience and
## a Notable Event. Tables from data/planetfall/character_backgrounds.json, every die
## through DiceManager under a context the QA seam can force.
##
## A record (what the coordinator stores per character id) carries the keys
## PlanetfallCreationCoordinator.build_campaign() applies (motivation, prior_experience,
## notable_event, bonus_stat/bonus_value, bonus_xp, bonus_loyalty, bonus_kp,
## bonus_story_point) plus what the screen shows: the dice, the notes, and the optional
## flavour rolls. Until 2026-10-28 the Backgrounds step rolled raw randi(), made the
## first four on the list experienced instead of letting the player choose (p.21 "select
## which characters to define as experienced"), and showed the player no result.

const TABLES_PATH := "res://data/planetfall/character_backgrounds.json"

const MOTIVATION_DIE := "Planetfall Motivation"
const PRIOR_EXPERIENCE_DIE := "Planetfall Prior Experience"
const NOTABLE_EVENT_DIE := "Planetfall Notable Event"

## p.22: "you can roll up to three times" on the Notable Event table.
const MAX_NOTABLE_EVENTS := 3

static var _tables: Dictionary = {}


static func tables() -> Dictionary:
	if _tables.is_empty():
		var file := FileAccess.open(TABLES_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_tables = parsed
	return _tables


## p.21: "four experienced characters".
static func experienced_count() -> int:
	return int(tables().get("experienced_count", 4))


static func _row(table_key: String, roll: int) -> Dictionary:
	for e in tables().get(table_key, {}).get("entries", []):
		if e is Dictionary and roll >= int(e.get("min", 0)) and roll <= int(e.get("max", 0)):
			return e
	return {}


static func _d100(context: String) -> int:
	var loop := Engine.get_main_loop()
	var dm: Node = (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
			if loop is SceneTree else null
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


## One character's backgrounds (p.21). `experienced` adds Prior Experience and a Notable
## Event; "Inexperienced characters do not receive any bonuses from this table" (p.21),
## so they roll neither.
static func roll_character(experienced: bool) -> Dictionary:
	var record: Dictionary = {"experienced": experienced}
	var m_roll: int = _d100(MOTIVATION_DIE)
	var m: Dictionary = _row("motivation_table", m_roll)
	record["motivation"] = str(m.get("motivation", ""))
	record["motivation_roll"] = m_roll
	record["motivation_notes"] = str(m.get("notes", ""))
	if not experienced:
		return record
	var p_roll: int = _d100(PRIOR_EXPERIENCE_DIE)
	var p: Dictionary = _row("prior_experience_table", p_roll)
	record["prior_experience"] = str(p.get("experience", ""))
	record["prior_roll"] = p_roll
	record["prior_notes"] = str(p.get("notes", ""))
	record.merge(_bonus_keys(p))
	var n_roll: int = _d100(NOTABLE_EVENT_DIE)
	var n: Dictionary = _row("notable_event_table", n_roll)
	record["notable_event"] = str(n.get("event", ""))
	record["notable_roll"] = n_roll
	record["notable_notes"] = str(n.get("notes", ""))
	record["extra_events"] = []
	return record


## p.22, optional flavour: "you can roll up to three times, with events occurring in the
## order you rolled them". "Rolls on this table do not affect gameplay." Returns the
## updated record, unchanged once it holds three events.
static func roll_extra_event(record: Dictionary) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	if not bool(out.get("experienced", false)):
		return out
	var extra: Array = out.get("extra_events", [])
	if 1 + extra.size() >= MAX_NOTABLE_EVENTS:
		return out
	var roll: int = _d100(NOTABLE_EVENT_DIE)
	var n: Dictionary = _row("notable_event_table", roll)
	extra.append({"event": str(n.get("event", "")), "roll": roll,
			"notes": str(n.get("notes", ""))})
	out["extra_events"] = extra
	return out


## p.21, optional: "If you want a more detailed story, roll twice, treating the first
## roll as history just after adulthood and the second roll as history just prior to
## being recruited. Claim the bonus for the second roll only." The roll the record already
## holds is the second, so this one is the earlier career and carries no bonus.
static func roll_earlier_career() -> Dictionary:
	var roll: int = _d100(PRIOR_EXPERIENCE_DIE)
	return {"experience": str(_row("prior_experience_table", roll).get("experience", "")),
			"roll": roll}


## `character` as the colony will be founded with it: the background record's results and
## its Prior Experience bonus applied (pp.21-22). A Story Point bonus belongs to the
## colony, not the character, so the coordinator adds that to the campaign. The founding
## and the Review screen both call this, so the review shows the profile the colony
## gets; it used to show the profile before the bonus.
static func apply_to(character: Dictionary, record: Dictionary) -> Dictionary:
	var out: Dictionary = character.duplicate(true)
	if record.is_empty():
		return out
	out["motivation"] = str(record.get("motivation", ""))
	out["prior_experience"] = str(record.get("prior_experience", ""))
	out["notable_event"] = str(record.get("notable_event", ""))
	if record.has("bonus_stat"):
		var stat: String = str(record.bonus_stat)
		out[stat] = int(out.get(stat, 0)) + int(record.get("bonus_value", 0))
	if record.has("bonus_xp"):
		out["xp"] = int(out.get("xp", 0)) + int(record.bonus_xp)
	if record.has("bonus_loyalty"):
		out["loyalty"] = record.bonus_loyalty
	if record.has("bonus_kp"):
		out["kp"] = int(out.get("kp", 0)) + int(record.bonus_kp)
	return out


## The p.22 bonus of the Prior Experience named `experience` ("Explorer" -> "+1 Speed"),
## or "". A founded character keeps the name only, and the bonus is already in its
## profile, so a screen that wants to say why a score is raised looks it up here.
static func bonus_text_for(experience: String) -> String:
	if experience == "":
		return ""
	for p in tables().get("prior_experience_table", {}).get("entries", []):
		if p is Dictionary and str(p.get("experience", "")) == experience:
			return bonus_text(_bonus_keys(p))
	return ""


## A Prior Experience row's bonus as record keys (bonus_stat/bonus_value, bonus_xp,
## bonus_loyalty, bonus_kp or bonus_story_point), the one place the table's bonus_type
## is read.
static func _bonus_keys(p: Dictionary) -> Dictionary:
	match str(p.get("bonus_type", "")):
		"stat":
			return {"bonus_stat": str(p.get("bonus_stat", "")),
					"bonus_value": int(p.get("bonus_value", 0))}
		"xp":
			return {"bonus_xp": int(p.get("bonus_value", 0))}
		"loyalty":
			return {"bonus_loyalty": str(p.get("bonus_value", "loyal"))}
		"kp":
			return {"bonus_kp": int(p.get("bonus_value", 0))}
		"story_point":
			return {"bonus_story_point": int(p.get("bonus_value", 0))}
	return {}


## The Prior Experience bonus as the book prints it (p.22), from the record's keys.
static func bonus_text(record: Dictionary) -> String:
	if record.has("bonus_stat"):
		return "+%d %s" % [int(record.bonus_value), str(record.bonus_stat).capitalize()]
	if record.has("bonus_xp"):
		return "+%d XP" % int(record.bonus_xp)
	if record.has("bonus_loyalty"):
		return "Loyalty begins as %s" % str(record.bonus_loyalty).capitalize()
	if record.has("bonus_kp"):
		return "+%d KP" % int(record.bonus_kp)
	if record.has("bonus_story_point"):
		return "+%d Story Point" % int(record.bonus_story_point)
	return ""


## Done when every character on `roster` has a Motivation and exactly
## experienced_count() of them (or every character, on a smaller roster) have their
## Prior Experience and Notable Event (p.21).
static func backgrounds_complete(roster: Array, data: Dictionary) -> bool:
	if roster.is_empty():
		return false
	var experienced: int = 0
	for c in roster:
		var record: Dictionary = data.get(str(c.get("id", "")), {})
		if str(record.get("motivation", "")) == "":
			return false
		if bool(record.get("experienced", false)):
			if str(record.get("prior_experience", "")) == "" \
					or str(record.get("notable_event", "")) == "":
				return false
			experienced += 1
	return experienced == mini(experienced_count(), roster.size())
