extends GdUnitTestSuite
## Tests for BattleObjectiveTracker — the pipe between MissionObjectiveSystem,
## VictoryProgressPanel, and the post-battle `success` signal.
##
## Focus: correct delegation, the objective-type coverage matrix, and the
## fallback guarantee (never worse than the old won/held_field heuristic).

const Tracker := preload("res://src/core/battle/BattleObjectiveTracker.gd")

func _obj(type: String) -> Dictionary:
	return {"type": type, "name": type.capitalize(),
		"victory_condition": "test vc"}

# --- FIGHT_OFF: player-driven enemy-defeated counter ------------------------

func test_fight_off_incomplete_until_all_defeated():
	var t = Tracker.new()
	t.init_from_context(_obj("FIGHT_OFF"), 5)
	assert_bool(t.is_complete()).is_false()
	t.apply_panel_input(4)  # player reports 4 of 5 defeated
	assert_bool(t.is_complete()).is_false()
	t.apply_panel_input(5)
	assert_bool(t.is_complete()).is_true()

func test_fight_off_on_enemy_casualty_path():
	var t = Tracker.new()
	t.init_from_context(_obj("FIGHT_OFF"), 3)
	t.on_enemy_casualty(3)
	assert_bool(t.is_complete()).is_true()
	assert_bool(t.is_auto_derivable()).is_true()

func test_fight_off_panel_row_is_interactive_counter():
	var t = Tracker.new()
	t.init_from_context(_obj("FIGHT_OFF"), 6)
	var rows: Array = t.get_panel_conditions()
	assert_int(rows.size()).is_equal(1)
	assert_bool(rows[0]["interactive"]).is_true()
	assert_str(rows[0]["input_kind"]).is_equal("counter")
	assert_int(rows[0]["input_max"]).is_equal(6)

# --- DEFEND: survival + objective_intact failure ----------------------------

func test_defend_completes_after_six_rounds():
	var t = Tracker.new()
	t.init_from_context(_obj("DEFEND"), 4)
	assert_bool(t.is_complete()).is_false()
	t.on_round_advanced(6)
	assert_bool(t.is_complete()).is_true()

func test_defend_turns_remaining_counts_down():
	var t = Tracker.new()
	t.init_from_context(_obj("DEFEND"), 4)
	assert_int(t.get_turns_remaining()).is_equal(6)
	t.on_round_advanced(4)
	assert_int(t.get_turns_remaining()).is_equal(2)
	t.on_round_advanced(6)
	assert_int(t.get_turns_remaining()).is_equal(0)

func test_defend_fails_when_objective_lost():
	var t = Tracker.new()
	t.init_from_context(_obj("DEFEND"), 4)
	t.on_round_advanced(6)
	t.set_objective_intact(false)
	assert_bool(t.is_complete()).is_false()
	assert_bool(t.is_failed()).is_true()

# --- INVASION_SURVIVE: not in registry, mapped to survival ------------------

func test_invasion_survive_maps_to_survival():
	var t = Tracker.new()
	t.init_from_context(_obj("INVASION_SURVIVE"), 8)
	assert_bool(t.is_complete()).is_false()
	assert_bool(t.is_auto_derivable()).is_true()
	t.on_round_advanced(6)
	assert_bool(t.is_complete()).is_true()
	assert_bool(t.get_mission_success(false, false)).is_true()

# --- PATROL: spatial counter ------------------------------------------------

func test_patrol_counter_completes_at_threshold():
	var t = Tracker.new()
	t.init_from_context(_obj("PATROL"), 4)
	t.apply_panel_input(2)
	assert_bool(t.is_complete()).is_false()
	var rows: Array = t.get_panel_conditions()
	assert_that(rows[0]["progress"]).is_equal(0.5)
	t.apply_panel_input(4)
	assert_bool(t.is_complete()).is_true()

# --- Uncovered types: NO fabricated completion math -------------------------

func test_uncovered_types_have_no_auto_completion():
	for type in ["ACCESS", "ELIMINATE", "SECURE"]:
		var t = Tracker.new()
		t.init_from_context(_obj(type), 5)
		assert_bool(t.is_auto_derivable()).is_false()
		# No rounds/casualties can ever auto-complete an uncovered objective.
		t.on_round_advanced(10)
		t.on_enemy_casualty(5)
		assert_bool(t.is_complete()).is_false()
		# Only the player's manual mark completes it.
		t.apply_panel_input(true)
		assert_bool(t.is_complete()).is_true()

func test_uncovered_row_exposes_manual_toggle():
	var t = Tracker.new()
	t.init_from_context(_obj("ACCESS"), 5)
	var rows: Array = t.get_panel_conditions()
	assert_bool(rows[0]["interactive"]).is_true()
	assert_str(rows[0]["input_kind"]).is_equal("bool")

# --- Fallback guarantee: never worse than won/held_field --------------------

func test_no_objective_falls_back_to_heuristic():
	var t = Tracker.new()
	t.init_from_context({}, 5)
	assert_bool(t.has_objective()).is_false()
	assert_bool(t.get_mission_success(true, false)).is_true()
	assert_bool(t.get_mission_success(false, true)).is_true()
	assert_bool(t.get_mission_success(false, false)).is_false()

func test_uncovered_unmarked_uses_fallback_then_player_wins():
	var t = Tracker.new()
	t.init_from_context(_obj("ELIMINATE"), 5)
	# Not manually marked → defer to the caller's heuristic.
	assert_bool(t.get_mission_success(true, false)).is_true()
	assert_bool(t.get_mission_success(false, false)).is_false()
	# Player marks it met → authoritative regardless of fallback.
	t.apply_panel_input(true)
	assert_bool(t.get_mission_success(false, false)).is_true()

func test_covered_success_is_objective_accurate_not_just_won():
	var t = Tracker.new()
	t.init_from_context(_obj("DEFEND"), 4)
	# Won the fight (true) but objective not yet met → success is FALSE.
	assert_bool(t.get_mission_success(true, true)).is_false()
	t.on_round_advanced(6)
	assert_bool(t.get_mission_success(false, false)).is_true()

# --- Result prefill shape ---------------------------------------------------

func test_result_prefill_shape():
	var t = Tracker.new()
	t.init_from_context(_obj("FIGHT_OFF"), 5)
	t.apply_panel_input(3)
	var pf: Dictionary = t.get_result_prefill()
	assert_bool(pf.has("victory")).is_true()
	assert_bool(pf.has("enemies_defeated")).is_true()
	assert_int(pf["enemies_defeated"]).is_equal(3)
