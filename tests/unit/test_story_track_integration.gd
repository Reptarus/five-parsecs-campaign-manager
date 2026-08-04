extends GdUnitTestSuite

## Story Track wiring tests — Core Rules Appendix V (pp.153-160).
##
## REPLACES a suite that tested nothing. Every one of the previous 8 behavioural
## tests sat behind `has_method()` guards on four methods with ZERO definitions
## repo-wide (_check_for_story_mission, _load_story_mission_offer,
## inject_story_mission, _process_story_mission_outcome), so each body was
## skipped and the file reported green while the Story Clock had not ticked in
## any campaign since commit e4373e137 (Apr 8 2026). It also asserted against
## event ids from an abandoned design ("hunt_begins", "first_contact") that
## exist in no JSON.
##
## These tests drive the REAL system with an injected deterministic die, so a
## regression fails instead of skipping.
##
## Max 13 tests per file (runner stability constraint).

const StoryTrackClass = preload("res://src/core/story/StoryTrackSystem.gd")
const MarkerClass = preload("res://src/core/story/StoryMarkerInvestigation.gd")
const NormalizerClass = preload("res://src/core/battle/BattleResultNormalizer.gd")

var _track: Resource = null
var _dice: Node = null


## Scripted die: returns queued values in order, then falls back to `default`.
class ScriptedDice extends Node:
	# Untyped on purpose: `Array[int]` rejects a plain `[1, 2]` literal assignment
	# from the test bodies ("Invalid assignment ... of type 'Array'").
	var queue: Array = []
	var default_value: int = 3
	func roll_dice(_context: String = "", _type: String = "D6") -> int:
		if queue.is_empty():
			return default_value
		return queue.pop_front()
	func roll_d6(_context: String = "") -> int:
		return roll_dice(_context, "D6")


func before_test() -> void:
	_dice = ScriptedDice.new()
	add_child(_dice)
	_track = StoryTrackClass.new()
	_track.set_dice_manager(_dice)


func after_test() -> void:
	if _dice and is_instance_valid(_dice):
		_dice.queue_free()
	_dice = null
	_track = null


func _start() -> void:
	_track.start_story_track()


# ── Story Clock (p.153) ─────────────────────────────────────────────

## p.153: "if you Won the mission that campaign turn, the Clock counts down 1 Tick."
func test_clock_counts_down_one_on_a_win() -> void:
	_start()
	assert_int(_track.story_clock_ticks).is_equal(5)
	var res: Dictionary = _track.advance_clock_end_of_turn(true)
	assert_int(res["ticks_reduced"]).is_equal(1)
	assert_int(_track.story_clock_ticks).is_equal(4)


## p.153 loss table: 1 = no countdown, 2-5 = 1 Tick, 6 = 2 Ticks.
func test_clock_loss_table_matches_the_book() -> void:
	_start()
	_dice.queue = [1]
	assert_int(_track.advance_clock_end_of_turn(false)["ticks_reduced"]).is_equal(0)
	_dice.queue = [4]
	assert_int(_track.advance_clock_end_of_turn(false)["ticks_reduced"]).is_equal(1)
	_dice.queue = [6]
	assert_int(_track.advance_clock_end_of_turn(false)["ticks_reduced"]).is_equal(2)


## p.153: "The Clock does NOT count down during a campaign turn where a Story
## Event takes place." Regression guard for the if/else in StoryTrackProcessor —
## calling both advance paths in sequence would violate this.
func test_clock_does_not_tick_on_a_story_event_turn() -> void:
	_start()
	_track.is_story_event_turn = true
	var before: int = _track.story_clock_ticks
	var res: Dictionary = _track.advance_clock_end_of_turn(true)
	assert_bool(res.get("advanced", true)).is_false()
	assert_str(str(res.get("reason", ""))).is_equal("story_event_turn")
	assert_int(_track.story_clock_ticks).is_equal(before)


## Clock hitting zero flags the next turn as a Story Event turn.
func test_clock_reaching_zero_queues_the_event() -> void:
	_start()
	_track.story_clock_ticks = 1
	var res: Dictionary = _track.advance_clock_end_of_turn(true)
	assert_bool(res["event_triggered"]).is_true()
	assert_bool(_track.pending_story_event).is_true()


# ── Event progression ───────────────────────────────────────────────

## apply_post_battle() completes the event, banks its id and sets the next clock.
func test_apply_post_battle_advances_the_event() -> void:
	_start()
	_track.is_story_event_turn = true
	var first_id: String = _track.get_current_event().event_id
	var effects: Dictionary = _track.apply_post_battle(true)
	assert_str(str(effects.get("event_id", ""))).is_equal(first_id)
	assert_int(_track.current_event_index).is_equal(1)
	assert_bool(first_id in _track.completed_event_ids).is_true()
	assert_bool(_track.is_story_event_turn).is_false()
	# event_01_foiled.json -> next_clock_ticks: 3
	assert_int(_track.story_clock_ticks).is_equal(3)


## Event 2 (p.154): capturing the mercenary is persistent state Event 3 reads
## back for its Seize the Initiative bonus. Nothing wrote it before.
func test_event_2_capture_is_recorded() -> void:
	_start()
	_track.current_event_index = 1
	_track.is_story_event_turn = true
	assert_bool(_track.mercenary_captured).is_false()
	_track.apply_post_battle(true, {"mercenary_captured": true})
	assert_bool(_track.mercenary_captured).is_true()


## Event 6 (p.159): "your old comrade will offer to join for the final battle,
## if they survived" — gates Event 7's companion roll. Also never written before.
func test_event_6_win_records_the_rescue() -> void:
	_start()
	_track.current_event_index = 5
	_track.is_story_event_turn = true
	assert_bool(_track.companion_rescued).is_false()
	_track.apply_post_battle(true, {"captive_survived": true})
	assert_bool(_track.companion_rescued).is_true()


# ── Event 7 delay (p.159) ───────────────────────────────────────────

## The clock reaching zero on the final event OPENS the delay window; it does not
## force the fight. "You may delay this battle for up to 3 campaign turns."
func test_event_7_opens_a_delay_window_instead_of_firing() -> void:
	_start()
	_track.current_event_index = 6
	_track.pending_story_event = true
	var event = _track.begin_campaign_turn()
	assert_object(event).is_null()
	assert_bool(_track.event_7_available).is_true()
	assert_int(_track.delay_turns_remaining).is_equal(3)
	assert_bool(_track.is_story_event_turn).is_false()


## p.159: "If you wait longer than that, the chance is missed, and you must
## consult the 'Losing the Story' section." Letting the window lapse LOSES the
## story — the old code handed the player the battle anyway.
func test_letting_the_window_lapse_loses_the_story() -> void:
	_start()
	_track.current_event_index = 6
	_track.pending_story_event = true
	_track.begin_campaign_turn()          # opens window, 3 turns
	for _i in range(3):
		_track.begin_campaign_turn()      # burns the delay
	var final_call = _track.begin_campaign_turn()
	assert_object(final_call).is_null()
	assert_bool(_track.is_story_track_active).is_false()
	assert_str(_track.story_outcome).is_equal("lost")
	assert_bool(_track.pending_completion_effects.get(
		"missed_the_chance", false)).is_true()


## The player may still jump in during the window.
func test_player_can_trigger_event_7_during_the_window() -> void:
	_start()
	_track.current_event_index = 6
	_track.pending_story_event = true
	_track.begin_campaign_turn()
	var event = _track.trigger_event_7_now()
	assert_object(event).is_not_null()
	assert_bool(_track.is_story_event_turn).is_true()


# ── Event 5 markers (p.157) ─────────────────────────────────────────

## The p.157 marker table: 1 Evidence / 2-3 Nothing / 4 Body / 5-6 War Bot.
func test_marker_table_matches_the_book() -> void:
	var m: Resource = MarkerClass.new()
	m.set_dice_manager(_dice)
	m.init_from_event(null)
	_dice.queue = [1, 2, 4, 5]
	assert_str(m.investigate(0)["outcome"]).is_equal(MarkerClass.STATE_EVIDENCE)
	assert_str(m.investigate(1)["outcome"]).is_equal(MarkerClass.STATE_NOTHING)
	assert_str(m.investigate(2)["outcome"]).is_equal(MarkerClass.STATE_BODY)
	assert_str(m.investigate(3)["outcome"]).is_equal(MarkerClass.STATE_WAR_BOT)
	assert_int(m.evidence_found).is_equal(1)


## All three Evidence sources (p.157): the marker roll of 1, the body search on
## 5-6, and the removed-marker location on a 6.
func test_all_three_evidence_sources_count() -> void:
	var m: Resource = MarkerClass.new()
	m.set_dice_manager(_dice)
	m.init_from_event(null)
	_dice.queue = [1]                 # marker 0 -> Evidence
	m.investigate(0)
	_dice.queue = [4, 5]              # marker 1 -> Body, search -> 5 = Evidence
	m.investigate(1)
	m.search_body(1)
	_dice.queue = [1]                 # round-3 decay removes marker 2
	m.markers[2]["state"] = MarkerClass.STATE_HIDDEN
	for i in range(3, m.markers.size()):
		m.markers[i]["state"] = MarkerClass.STATE_NOTHING
	m.end_of_round(3)
	_dice.queue = [6]                 # search the spot -> 6 = Evidence
	m.search_removed_location(2)
	assert_int(m.evidence_found).is_equal(3)


## p.157: decay starts at the END of Round 3, not before. And the mission ends
## only once no marker is still hidden.
func test_marker_decay_starts_at_round_three_and_resolution() -> void:
	var m: Resource = MarkerClass.new()
	m.set_dice_manager(_dice)
	m.init_from_event(null)
	_dice.default_value = 1                      # every decay roll would remove
	assert_int(m.end_of_round(2).size()).is_equal(0)   # too early
	assert_bool(m.all_resolved()).is_false()
	assert_int(m.end_of_round(3).size()).is_equal(6)   # all six decay
	assert_bool(m.all_resolved()).is_true()


## The normalizer is the one chokepoint every battle path crosses. If the story
## keys are not in its passthrough they are dropped before post-battle, which is
## exactly how PostBattleCompletion's is_story_battle branch stayed dead.
func test_normalizer_carries_the_story_keys() -> void:
	var mission: Dictionary = {
		"is_story_battle": true,
		"story_event_id": "kidnap",
		"story_event_number": 5,
		"story_evidence_found": 2,
		"mercenary_captured": true,
	}
	var results: Dictionary = NormalizerClass.normalize(
		{"success": true}, mission, 4)
	assert_bool(results.get("is_story_battle", false)).is_true()
	assert_str(str(results.get("story_event_id", ""))).is_equal("kidnap")
	assert_int(int(results.get("story_event_number", 0))).is_equal(5)
	assert_int(int(results.get("story_evidence_found", 0))).is_equal(2)
	assert_bool(results.get("mercenary_captured", false)).is_true()
