class_name FPCM_StoryMarkerInvestigation
extends Resource

## Story Track Event 5 "Kidnap" marker investigation — Core Rules p.157.
##
## This is a COMPANION-APP tracker, not a simulator. The player places the six
## markers on their physical table and tells the app which one the crew just
## approached; the app rolls, prints the instruction, and keeps the tally. That
## matches how every other battle system here works — text instructions out, no
## attempt to model movement.
##
## The evidence this produces is the ONLY input to the p.157 search that unlocks
## Event 6. Before this existed, `StoryTrackSystem.add_evidence()` had zero
## callers, so the only evidence a crew could ever accrue was the automatic +1
## per failed search — the entire marker mechanic was unimplemented.
##
## Book text, verbatim (p.157):
##   "Place 6 markers, spread evenly around the table [...] When you approach
##    within 4" of a marker, roll 1D6 on the table below:
##      1     Evidence!  Signs of the attackers. Record the Evidence.
##      2-3   Nothing    Nothing here.
##      4     Body       The corpse of someone who worked here. If you move into
##                       contact, roll 1D6. On a 5-6, you uncover Evidence.
##      5-6   War Bot!   A concealed War Bot. [...]
##    At the end of Round 3 and each round thereafter, roll 1D6 for every
##    remaining marker. On a 1, the marker is removed.
##    If you move into contact with the location where it was discovered, roll
##    1D6. On a 6, you uncover Evidence.
##    The mission ends once all markers have been revealed or removed. If your
##    crew all become casualties, remove any remaining markers."

# ── Marker states ───────────────────────────────────────────────────
const STATE_HIDDEN := "hidden"
const STATE_EVIDENCE := "evidence"
const STATE_NOTHING := "nothing"
const STATE_BODY := "body"                    # revealed, not yet searched
const STATE_BODY_SEARCHED := "body_searched"
const STATE_WAR_BOT := "war_bot"
const STATE_REMOVED := "removed"              # decayed, location still searchable
const STATE_REMOVED_SEARCHED := "removed_searched"

## Round the removal check begins (p.157: "At the end of Round 3").
const REMOVAL_START_ROUND := 3

var dice_manager: Node = null

## One entry per marker: {index, state, evidence_yielded}
var markers: Array[Dictionary] = []
## Total Evidence uncovered this battle. Feeds StoryTrackSystem.add_evidence().
var evidence_found: int = 0
## War Bots revealed so far — the player must place each one on the table.
var war_bots_revealed: int = 0
## Cached from the event JSON so nothing is hardcoded here.
var reveal_distance_inches: int = 4
var war_bot_stats: Dictionary = {}
var _marker_table: Array = []


func set_dice_manager(dm: Node) -> void:
	dice_manager = dm


## Build from a StoryEvent (event 5). Falls back to the book defaults only if a
## field is absent from the JSON — no invented values.
func init_from_event(event: Variant) -> void:
	var count: int = 6
	if event != null and "deployment" in event and event.deployment is Dictionary:
		var marker_cfg: Dictionary = event.deployment.get("markers", {})
		count = int(marker_cfg.get("count", 6))
		reveal_distance_inches = int(
			marker_cfg.get("reveal_distance_inches", 4))
	if event != null and "enemies" in event and event.enemies is Dictionary:
		_marker_table = event.enemies.get("marker_table", [])
		war_bot_stats = event.enemies.get("war_bot_stats", {})

	markers.clear()
	for i: int in range(count):
		markers.append({
			"index": i,
			"state": STATE_HIDDEN,
			"evidence_yielded": false,
		})
	evidence_found = 0
	war_bots_revealed = 0


## p.157: the crew approached within 4" of a marker — roll 1D6 and reveal it.
func investigate(index: int) -> Dictionary:
	var marker: Dictionary = _marker(index)
	if marker.is_empty():
		return {"ok": false, "reason": "No such marker."}
	if marker["state"] != STATE_HIDDEN:
		return {"ok": false, "reason": "Marker %d is already revealed." % (index + 1)}

	var roll: int = _roll_d6("Marker %d investigation" % (index + 1))
	var outcome: String = _outcome_for_roll(roll)
	marker["state"] = outcome

	var result: Dictionary = {
		"ok": true,
		"index": index,
		"roll": roll,
		"outcome": outcome,
		"evidence_gained": 0,
		"instruction": "",
	}

	match outcome:
		STATE_EVIDENCE:
			evidence_found += 1
			marker["evidence_yielded"] = true
			result["evidence_gained"] = 1
			result["instruction"] = "Evidence! Signs of the attackers. " \
				+ "Record the Evidence for use in the next Event."
		STATE_NOTHING:
			result["instruction"] = "Nothing here."
		STATE_BODY:
			result["instruction"] = "The corpse of someone who worked here. " \
				+ "Move a figure into contact to search it."
		STATE_WAR_BOT:
			war_bots_revealed += 1
			result["instruction"] = "A concealed War Bot! " + _war_bot_line()

	result["all_resolved"] = all_resolved()
	return result


## p.157: "If you move into contact, roll 1D6. On a 5-6, you uncover Evidence."
func search_body(index: int) -> Dictionary:
	var marker: Dictionary = _marker(index)
	if marker.is_empty() or marker["state"] != STATE_BODY:
		return {"ok": false, "reason": "No unsearched body at marker %d." % (index + 1)}

	var roll: int = _roll_d6("Body search at marker %d" % (index + 1))
	marker["state"] = STATE_BODY_SEARCHED
	var gained: int = 1 if roll >= 5 else 0
	if gained > 0:
		evidence_found += 1
		marker["evidence_yielded"] = true
	return {
		"ok": true,
		"index": index,
		"roll": roll,
		"evidence_gained": gained,
		"instruction": ("You uncover Evidence." if gained > 0
			else "Nothing useful on the body."),
		"all_resolved": all_resolved(),
	}


## p.157: a marker that decayed can still be searched where it stood —
## "roll 1D6. On a 6, you uncover Evidence."
func search_removed_location(index: int) -> Dictionary:
	var marker: Dictionary = _marker(index)
	if marker.is_empty() or marker["state"] != STATE_REMOVED:
		return {"ok": false, "reason": "Nothing to search at marker %d." % (index + 1)}

	var roll: int = _roll_d6("Search removed marker %d" % (index + 1))
	marker["state"] = STATE_REMOVED_SEARCHED
	var gained: int = 1 if roll >= 6 else 0
	if gained > 0:
		evidence_found += 1
		marker["evidence_yielded"] = true
	return {
		"ok": true,
		"index": index,
		"roll": roll,
		"evidence_gained": gained,
		"instruction": ("You uncover Evidence." if gained > 0
			else "The trail here has gone cold."),
		"all_resolved": all_resolved(),
	}


## p.157: "At the end of Round 3 and each round thereafter, roll 1D6 for every
## remaining marker. On a 1, the marker is removed."
func end_of_round(round_number: int) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if round_number < REMOVAL_START_ROUND:
		return removed
	for marker: Dictionary in markers:
		if marker["state"] != STATE_HIDDEN:
			continue
		var roll: int = _roll_d6(
			"Marker %d decay check" % (int(marker["index"]) + 1))
		if roll == 1:
			marker["state"] = STATE_REMOVED
			removed.append({
				"index": marker["index"],
				"roll": roll,
				"instruction": "Marker %d is removed. Move into contact with "
					% (int(marker["index"]) + 1)
					+ "where it stood and roll 1D6 — on a 6 you still "
					+ "uncover Evidence.",
			})
	return removed


## p.157: "If your crew all become casualties, remove any remaining markers."
func abandon_remaining() -> int:
	var count: int = 0
	for marker: Dictionary in markers:
		if marker["state"] == STATE_HIDDEN:
			marker["state"] = STATE_REMOVED_SEARCHED
			count += 1
	return count


## p.157: "The mission ends once all markers have been revealed or removed."
## A revealed Body or a decayed marker still offers one search, but neither
## keeps the mission open — only a still-hidden marker does.
func all_resolved() -> bool:
	for marker: Dictionary in markers:
		if marker["state"] == STATE_HIDDEN:
			return false
	return true


func get_hidden_count() -> int:
	var n: int = 0
	for marker: Dictionary in markers:
		if marker["state"] == STATE_HIDDEN:
			n += 1
	return n


func get_pending_searches() -> Array[int]:
	## Markers that still offer an Evidence roll (unsearched body / decayed spot).
	var out: Array[int] = []
	for marker: Dictionary in markers:
		if marker["state"] in [STATE_BODY, STATE_REMOVED]:
			out.append(int(marker["index"]))
	return out


func get_summary() -> Dictionary:
	return {
		"evidence_found": evidence_found,
		"war_bots_revealed": war_bots_revealed,
		"markers_hidden": get_hidden_count(),
		"markers_total": markers.size(),
		"all_resolved": all_resolved(),
	}


# ── Internals ───────────────────────────────────────────────────────

func _marker(index: int) -> Dictionary:
	for marker: Dictionary in markers:
		if int(marker["index"]) == index:
			return marker
	return {}


func _outcome_for_roll(roll: int) -> String:
	## Prefer the JSON table so the book data stays the single source of truth;
	## the hardcoded ranges below are the same p.157 values and only run if the
	## event JSON is missing (e.g. a unit test constructing the system bare).
	for row: Variant in _marker_table:
		if not (row is Dictionary):
			continue
		var spec: Variant = row.get("roll", null)
		var hit: bool = false
		if spec is int and int(spec) == roll:
			hit = true
		elif spec is Array:
			for v: Variant in spec:
				if int(v) == roll:
					hit = true
					break
		if hit:
			match str(row.get("result", "")):
				"evidence": return STATE_EVIDENCE
				"nothing": return STATE_NOTHING
				"body": return STATE_BODY
				"war_bot": return STATE_WAR_BOT
	if roll <= 1:
		return STATE_EVIDENCE
	if roll <= 3:
		return STATE_NOTHING
	if roll == 4:
		return STATE_BODY
	return STATE_WAR_BOT


func _war_bot_line() -> String:
	if war_bot_stats.is_empty():
		return "Place a War Bot at the marker."
	var stats: Dictionary = war_bot_stats.get("stats", {})
	return ("Place a War Bot: Speed %d\" / Combat +%d / Toughness %d, "
		+ "%s AI, %s Armor Save, no Morale checks, %s.") % [
			int(stats.get("speed_inches", 3)),
			int(stats.get("combat_skill", 0)),
			int(stats.get("toughness", 5)),
			str(war_bot_stats.get("ai", "defensive")).capitalize(),
			str(war_bot_stats.get("armor_save", "6+")),
			", ".join(war_bot_stats.get("weapons", ["Hand Laser"])),
		]


func _roll_d6(context: String) -> int:
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, "D6")
	return randi_range(1, 6)


# ── Serialization ───────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"markers": markers.duplicate(true),
		"evidence_found": evidence_found,
		"war_bots_revealed": war_bots_revealed,
		"reveal_distance_inches": reveal_distance_inches,
	}


func deserialize(data: Dictionary) -> void:
	markers.clear()
	for entry: Variant in data.get("markers", []):
		if entry is Dictionary:
			markers.append(entry.duplicate(true))
	evidence_found = int(data.get("evidence_found", 0))
	war_bots_revealed = int(data.get("war_bots_revealed", 0))
	reveal_distance_inches = int(data.get("reveal_distance_inches", 4))
