extends GdUnitTestSuite
## Regression: GameState.advance_turn() must increment turns_played MONOTONICALLY,
## NOT derive it from _turn_number. The old `turns_played = _turn_number - 1`
## created a self-referential fixed point that FROZE loaded campaigns at turn 2:
## on a loaded save _turn_number restores STALE (from the save's top-level
## "turn_number", often absent) while CampaignPhaseManager.turn_number restores
## from turns_played, so turns_played=1 <-> cpm.turn_number=2 -> turns_played =
## 2-1 = 1 never advanced. Found in the Jul 5 2026 tablet playthrough (dashboard
## + World Phase both read turns_played + 1 as the current turn). See
## GameState.advance_turn().
##
## advance_turn() touches only current_campaign / _turn_number / a signal emit —
## no tree access — so a DETACHED .new() instance exercises it without _ready()
## side effects.

const GameStateScript = preload("res://src/core/state/GameState.gd")

## Minimal stand-in: advance_turn() only needs `"progress_data" in campaign` to
## be true and progress_data to be a mutable Dictionary.
class _StubCampaign extends Resource:
	var progress_data: Dictionary = {}

var _gs: Node

func before_test() -> void:
	_gs = auto_free(GameStateScript.new())  # detached — do NOT add_child

func test_advance_turn_increments_turns_played_monotonically() -> void:
	var camp := _StubCampaign.new()
	camp.progress_data["turns_played"] = 0
	_gs.current_campaign = camp
	_gs.advance_turn()
	assert_int(int(camp.progress_data["turns_played"])).is_equal(1)
	_gs.advance_turn()
	assert_int(int(camp.progress_data["turns_played"])).is_equal(2)
	_gs.advance_turn()
	assert_int(int(camp.progress_data["turns_played"])).is_equal(3)

func test_advance_turn_breaks_stale_turn_number_freeze() -> void:
	# Simulate a loaded save: turns_played=2 (display "Turn 3") but _turn_number
	# restored STALE to 2 (the old fixed point). Monotonic advance MUST still move
	# forward, not re-derive turns_played = _turn_number - 1 = 1 (the freeze).
	var camp := _StubCampaign.new()
	camp.progress_data["turns_played"] = 2
	_gs.current_campaign = camp
	_gs._turn_number = 2  # stale, as after a load with absent top-level turn_number
	_gs.advance_turn()
	assert_int(int(camp.progress_data["turns_played"])).is_equal(3)  # advanced, NOT frozen
	assert_int(_gs._turn_number).is_equal(4)  # kept in sync as turns_played + 1

func test_advance_turn_syncs_turn_number_to_turns_played_plus_one() -> void:
	var camp := _StubCampaign.new()
	camp.progress_data["turns_played"] = 5
	_gs.current_campaign = camp
	_gs.advance_turn()
	assert_int(int(camp.progress_data["turns_played"])).is_equal(6)
	assert_int(_gs._turn_number).is_equal(7)

func test_advance_turn_without_campaign_falls_back_to_turn_number() -> void:
	_gs.current_campaign = null
	_gs._turn_number = 3
	_gs.advance_turn()
	assert_int(_gs._turn_number).is_equal(4)
