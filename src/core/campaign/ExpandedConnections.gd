class_name ExpandedConnections
extends RefCounted
## Expanded Connections — Compendium pp.80-86.
##
## WHAT WAS THERE BEFORE. Same shape as Expanded Quests: the data was complete
## and correct and nothing called it. `data/compendium/missions_expanded.json`
## carries the 5-row D6 main table and all five 6-row subtables — 30 scenarios,
## each with the book's `*` decline marker faithfully recorded as
## `decline_allowed` — and `compendium_missions_expanded.gd` exposed
## `check_for_connection()`, `roll_connection_type()` and
## `roll_connection_subtable()` behind a correct EXPANDED_CONNECTIONS gate.
##
## All three had zero callers.
##
## (`src/core/character/connections/CharacterConnections.gd` is a DIFFERENT
## system — creation-time starting contacts, patrons and rivals. The chapter
## trace conflated the two; they share only the word.)
##
## THE BOOK, verbatim.
##
## The check (p.80):
##   "Check for Connections any time you determine that you will be playing an
##    Opportunity mission. While establishing the objectives and parameters, roll
##    1D6 with a 5 or 6 indicating that the mission has a Connection. Connections
##    do not occur during Quest, Rival or Patron missions."
##
## The first game (p.81):
##   "If you are playing your first game since purchasing this expansion, have a
##    Connection happen automatically this campaign turn."
##
## The no-roll variation (p.81):
##   "If you prefer to reduce dice-rolling, a Connection occurs any time you play
##    an Opportunity mission AND the prior Opportunity mission did not have a
##    Connection (in other words, every other time)."
##
## The variety swap (p.81 designer note):
##   "If you prefer to maintain variety, swap a result you have already had this
##    campaign for the first new result in the same subtable."
##
## Declining (p.81):
##   "Some events may allow you to turn the job down. If so, fight a random
##    Opportunity mission without generating a Connection for it. These events
##    are marked with an * on the subtables below."
##
## Expiry (p.81):
##   "Seize any opportunity immediately next campaign turn, or the option
##    disappears."
##
## Both variations are player PREFERENCES the book leaves open, so they are real
## settings (SettingsManager `gameplay/connections_no_roll` and
## `gameplay/connections_variety`), defaulting off — the book's main line is the
## 1D6 roll with repeats allowed.
##
## STATE lives at `campaign.progress_data["expanded_connections"]`, which is
## already serialized. It has to persist: the variety swap is scoped to "this
## campaign", the no-roll option needs to remember the PRIOR Opportunity mission,
## and the offer expires one campaign turn after it is made.

const FLAG := "EXPANDED_CONNECTIONS"
const STATE_KEY := "expanded_connections"

## "roll 1D6 with a 5 or 6 indicating that the mission has a Connection."
const TRIGGER_THRESHOLD := 5

const MissionsExpandedRef = preload("res://src/data/compendium_missions_expanded.gd")


## ============================================================================
## GATING
## ============================================================================

static func _dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func is_enabled() -> bool:
	var dlc := _dlc_manager()
	if not dlc:
		return false
	var flag_value: int = dlc.ContentFlag.get(FLAG, -1)
	if flag_value < 0:
		return false
	return dlc.is_feature_enabled(flag_value)


static func _settings() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager")


static func no_roll_option_active() -> bool:
	var sm := _settings()
	if sm and sm.has_method("use_connections_no_roll"):
		return bool(sm.use_connections_no_roll())
	return false


static func variety_swap_active() -> bool:
	var sm := _settings()
	if sm and sm.has_method("use_connections_variety"):
		return bool(sm.use_connections_variety())
	return false


## ============================================================================
## STATE
## ============================================================================

static func _blank_state() -> Dictionary:
	return {
		# Result ids already seen THIS campaign — the variety swap's memory.
		"seen": [],
		# Did the previous Opportunity mission have a Connection? The no-roll
		# option is "every other time", which is a question about the last one.
		"last_had_connection": false,
		# p.81's automatic first Connection, spent once.
		"first_game_done": false,
		# The offer awaiting play, and the turn it was made. {} when none.
		"pending": {},
	}


static func get_state(campaign: Variant) -> Dictionary:
	if campaign == null or not ("progress_data" in campaign):
		return _blank_state()
	var raw: Variant = campaign.progress_data.get(STATE_KEY, null)
	if raw is Dictionary:
		var state: Dictionary = _blank_state()
		state.merge(raw, true)
		return state
	return _blank_state()


static func _write_state(campaign: Variant, state: Dictionary) -> void:
	if campaign == null or not ("progress_data" in campaign):
		return
	campaign.progress_data[STATE_KEY] = state


## ============================================================================
## THE TABLES
## ============================================================================

static func main_table_entry(roll: int) -> Dictionary:
	for row: Variant in MissionsExpandedRef.CONNECTION_MAIN_TABLE:
		if not (row is Dictionary):
			continue
		if roll >= int(row.get("roll_min", 0)) and roll <= int(row.get("roll_max", 0)):
			return (row as Dictionary).duplicate(true)
	return {}


static func subtable(number: int) -> Array:
	match number:
		1: return MissionsExpandedRef.CONNECTION_SUBTABLE_1
		2: return MissionsExpandedRef.CONNECTION_SUBTABLE_2
		3: return MissionsExpandedRef.CONNECTION_SUBTABLE_3
		4: return MissionsExpandedRef.CONNECTION_SUBTABLE_4
		5: return MissionsExpandedRef.CONNECTION_SUBTABLE_5
		_: return []


## The book's designer note, implemented exactly as written: "swap a result you
## have already had this campaign for THE FIRST NEW RESULT IN THE SAME SUBTABLE."
## Not a re-roll — a deterministic walk down the same subtable, which is why the
## rows are read in printed order. Falls back to the rolled row when every entry
## in the subtable has been seen, because the book gives no further instruction
## and refusing to produce a Connection would be worse than repeating one.
static func subtable_entry(number: int, roll: int, seen: Array = []) -> Dictionary:
	var rows: Array = subtable(number)
	var rolled: Dictionary = {}
	for row: Variant in rows:
		if row is Dictionary and int(row.get("roll", 0)) == roll:
			rolled = (row as Dictionary).duplicate(true)
			break
	if rolled.is_empty():
		return {}
	if not variety_swap_active() or not (str(rolled.get("id", "")) in seen):
		return rolled
	for row: Variant in rows:
		if row is Dictionary and not (str(row.get("id", "")) in seen):
			var swapped: Dictionary = (row as Dictionary).duplicate(true)
			swapped["variety_swapped_from"] = str(rolled.get("id", ""))
			return swapped
	return rolled


## ============================================================================
## THE p.80 CHECK
## ============================================================================

## Whether this mission gets a Connection at all.
##
## `mission_source` is read rather than inferred: "Connections do not occur
## during Quest, Rival or Patron missions" is a rule about what the mission IS,
## and the mission has carried that identity since the battle-funnel sweep.
##
## Returns {applies, triggered, roll, reason} — `applies` false means the
## question was never asked (chapter off, or not an Opportunity mission), which
## is different from asking and rolling low.
static func check(campaign: Variant, mission_source: String, d6: int = -1) -> Dictionary:
	var result: Dictionary = {
		"applies": false, "triggered": false, "roll": 0, "reason": "",
	}
	if not is_enabled() or campaign == null:
		return result
	if mission_source.strip_edges().to_lower() != "opportunity":
		result["reason"] = "Connections do not occur during Quest, Rival or Patron missions."
		return result

	result["applies"] = true
	var state: Dictionary = get_state(campaign)

	if not bool(state.get("first_game_done", false)):
		state["first_game_done"] = true
		result["triggered"] = true
		result["reason"] = "First game since unlocking the expansion — an automatic Connection."
		_write_state(campaign, state)
		return result

	if no_roll_option_active():
		result["triggered"] = not bool(state.get("last_had_connection", false))
		result["reason"] = ("No-roll option: a Connection every other Opportunity mission."
			if result["triggered"]
			else "No-roll option: the previous Opportunity mission had a Connection.")
		return result

	var roll: int = d6 if d6 > 0 else randi_range(1, 6)
	result["roll"] = roll
	result["triggered"] = roll >= TRIGGER_THRESHOLD
	result["reason"] = "1D6 = %d (5 or 6 gives a Connection)." % roll
	return result


## Roll the D6 main table and its subtable, and store the result as the pending
## offer. `main_d6` / `sub_d6` are injectable for DiceManager routing and tests.
##
## Returns the full connection record, or {} when the chapter is off.
static func roll_connection(
	campaign: Variant, turn_number: int = 0, main_d6: int = -1, sub_d6: int = -1
) -> Dictionary:
	if not is_enabled() or campaign == null:
		return {}
	var main_roll: int = main_d6 if main_d6 > 0 else randi_range(1, 6)
	var main_entry: Dictionary = main_table_entry(main_roll)
	if main_entry.is_empty():
		return {}
	var number: int = int(main_entry.get("subtable", 0))
	var sub_roll: int = sub_d6 if sub_d6 > 0 else randi_range(1, 6)

	var state: Dictionary = get_state(campaign)
	var seen: Array = state.get("seen", [])
	var entry: Dictionary = subtable_entry(number, sub_roll, seen)
	if entry.is_empty():
		return {}

	var record: Dictionary = {
		"id": str(entry.get("id", "")),
		"category": str(main_entry.get("id", "")),
		"subtable": number,
		"main_roll": main_roll,
		"sub_roll": sub_roll,
		"decline_allowed": bool(entry.get("decline_allowed", false)),
		"instruction": str(entry.get("instruction", "")),
		"category_instruction": str(main_entry.get("instruction", "")),
		"offered_on_turn": turn_number,
	}
	if entry.has("variety_swapped_from"):
		record["variety_swapped_from"] = str(entry["variety_swapped_from"])

	var id: String = record["id"]
	if not (id in seen):
		seen.append(id)
	state["seen"] = seen
	state["pending"] = record
	state["last_had_connection"] = true
	_write_state(campaign, state)
	return record


## Record that an Opportunity mission was played WITHOUT a Connection, so the
## no-roll option's "every other time" alternates. Called on the same path as
## roll_connection(), on the other branch.
static func note_no_connection(campaign: Variant) -> void:
	if not is_enabled() or campaign == null:
		return
	var state: Dictionary = get_state(campaign)
	state["last_had_connection"] = false
	_write_state(campaign, state)


## ============================================================================
## THE PENDING OFFER
## ============================================================================

static func get_pending(campaign: Variant) -> Dictionary:
	var pending: Variant = get_state(campaign).get("pending", {})
	return pending if pending is Dictionary else {}


## p.81: "Seize any opportunity immediately next campaign turn, or the option
## disappears." An offer made on turn N is playable on turn N and turn N+1;
## anything later is gone. Returns the record that lapsed, or {}.
static func expire_stale(campaign: Variant, current_turn: int) -> Dictionary:
	if campaign == null:
		return {}
	var state: Dictionary = get_state(campaign)
	var pending: Variant = state.get("pending", {})
	if not (pending is Dictionary) or (pending as Dictionary).is_empty():
		return {}
	if current_turn - int((pending as Dictionary).get("offered_on_turn", current_turn)) <= 1:
		return {}
	state["pending"] = {}
	_write_state(campaign, state)
	return pending


## The offer was taken (or declined, or played out). Clears it either way — a
## declined Connection is spent: "fight a random Opportunity mission WITHOUT
## generating a Connection for it."
static func resolve_pending(campaign: Variant, declined: bool = false) -> Dictionary:
	var state: Dictionary = get_state(campaign)
	var pending: Variant = state.get("pending", {})
	if not (pending is Dictionary) or (pending as Dictionary).is_empty():
		return {}
	var record: Dictionary = pending
	if declined and not bool(record.get("decline_allowed", false)):
		# Not an * event — the book gives no way out of this one.
		return {}
	state["pending"] = {}
	_write_state(campaign, state)
	record = record.duplicate(true)
	record["declined"] = declined
	return record


## Everything a Connection mission carries into the battle, so the pre-battle
## screen and the post-battle side read a stamped mission rather than re-deriving
## it. Empty when nothing is pending.
static func mission_stamp(campaign: Variant) -> Dictionary:
	var record: Dictionary = get_pending(campaign)
	if record.is_empty():
		return {}
	return {
		"connection_id": str(record.get("id", "")),
		"connection_category": str(record.get("category", "")),
		"connection_subtable": int(record.get("subtable", 0)),
		"connection_instruction": str(record.get("instruction", "")),
		"connection_decline_allowed": bool(record.get("decline_allowed", false)),
	}


## Called when a campaign ends or a new one starts on the same save slot.
static func clear(campaign: Variant) -> void:
	if campaign == null or not ("progress_data" in campaign):
		return
	campaign.progress_data.erase(STATE_KEY)
