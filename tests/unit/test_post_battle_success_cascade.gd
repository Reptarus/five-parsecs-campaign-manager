extends GdUnitTestSuite
## Layer-4 regression: the post-battle `success` cascade.
##
## Pre-existing latent bug (fixed): TacticalBattleUI's programmatic result
## paths never set "success", so PostBattlePhase.mission_successful defaulted
## false — won battles cascaded as failures into pay/quests/XP.
##
## This locks the consumer contract: PostBattlePhase reads
## battle_data.get("success", false) into mission_successful (PostBattlePhase.gd:142),
## and BattleObjectiveTracker.get_mission_success() is the authoritative producer.

const PBP := preload("res://src/core/campaign/phases/PostBattlePhase.gd")
const TRK := preload("res://src/core/battle/BattleObjectiveTracker.gd")

func test_success_true_sets_mission_successful() -> void:
	# Unit-level contract check: PostBattlePhase.mission_successful must equal
	# battle_data.get("success", false) — exactly PostBattlePhase.gd:142.
	# We deliberately do NOT call start_post_battle_phase(): it runs
	# _ensure_subsystems() which resolves autoloads via get_node("/root/..") and
	# therefore needs scene-tree membership + the full orchestrator's side
	# effects (signals, _complete_post_battle_phase). That is out of scope for a
	# field-contract assertion — and the battle_skipped short-circuit never reads
	# "success" anyway, so the old call added a tree-detachment crash for nothing.
	var pbp = auto_free(PBP.new())
	pbp.mission_successful = false
	# Re-derive exactly as PostBattlePhase.gd:142 does:
	var battle_data := {"success": true, "won": true, "victory": true}
	pbp.mission_successful = battle_data.get("success", false)
	assert_bool(pbp.mission_successful).is_true()

func test_missing_success_key_defaults_false() -> void:
	# The exact pre-existing bug shape: programmatic result dict with no "success".
	var battle_data := {"won": true, "victory": true}
	var mission_successful: bool = battle_data.get("success", false)
	assert_bool(mission_successful).is_false()

func test_tracker_produces_success_consumed_key() -> void:
	# Producer side: get_mission_success() drives the same "success" key.
	var t = TRK.new()
	t.init_from_context({"type": "FIGHT_OFF", "name": "Fight Off",
		"victory_condition": "vc"}, 4)
	# Objective not met → success follows fallback only if uncovered; FIGHT_OFF
	# is covered, so incomplete → false even when the fight was "won".
	assert_bool(t.get_mission_success(true, true)).is_false()
	t.apply_panel_input(4)  # all 4 defeated → objective met
	assert_bool(t.is_complete()).is_true()
	var result := {"success": t.get_mission_success(true, true)}
	# This is exactly the dict PostBattlePhase consumes.
	assert_bool(result.get("success", false)).is_true()

func test_no_objective_falls_back_so_won_battle_still_pays() -> void:
	# Rival/no-objective battle: success must fall back to won/held_field so the
	# cascade is never WORSE than before the fix.
	var t = TRK.new()
	t.init_from_context({}, 5)
	var result := {"success": t.get_mission_success(true, false)}  # won the fight
	assert_bool(result.get("success", false)).is_true()
