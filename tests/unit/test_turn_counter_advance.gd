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


# ============================================================================
# T11-20 — the turn counter froze after a reload
# ============================================================================
#
# THE FINDING (device, deploy #19). A full cycle was completed, "Continue to Next
# Cycle" pressed, and the pulled save still read turns_played 8.
#
# ⚠ THE DOCBLOCK AT THE TOP OF THIS SUITE ALREADY ASSUMED THE FIX. It says
# "CampaignPhaseManager.turn_number restores from turns_played" — and until this
# sprint nothing did that. bind_campaign() set `turn_number = 0` on a new campaign
# identity (correct: carrying campaign A's turn into B used to raise B's count
# permanently) and restored the PHASE but never the turn.
#
# That reset meets CampaignTurnController._on_campaign_turn_started(), which writes
#     progress_data["turns_played"] = max(current, turn_number - 1)
# The max() exists so a stale LOW value cannot lower a real count — and that is
# exactly what freezes it. After a reload turn_number restarts at 0, so the write is
# max(8, -1) = 8, then max(8, 0) = 8 ... and turns_played cannot move again until
# turn_number has climbed past 9. Measured before the fix: turn_number 0 -> 1 -> 2
# while turns_played sat at 8 throughout.
#
# NEITHER HALF IS WRONG ALONE, which is why it survived: the reset is right, the
# max() is right, and together they lose the count. The missing piece was the
# restore.

const PhaseManagerScript := preload(
	"res://src/core/campaign/CampaignPhaseManager.gd")
const CampaignCoreScript := preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _campaign_at(turns_played: int, stored_phase: int) -> Resource:
	var c = CampaignCoreScript.new()
	c.from_dictionary({"campaign_id": "t1120_%d_%d" % [turns_played, stored_phase]})
	c.progress_data["turns_played"] = turns_played
	if stored_phase > 0:
		c.progress_data["current_turn_phase"] = stored_phase
	return c


## The exact line CampaignTurnController._on_campaign_turn_started() runs. Mirrored
## rather than driven, because the controller is a full screen — but mirrored
## EXACTLY, so a change there that breaks this is a change worth noticing.
func _persisted(campaign: Resource, turn_number: int) -> int:
	var current: int = int(campaign.progress_data.get("turns_played", 0))
	campaign.progress_data["turns_played"] = max(current, turn_number - 1)
	return int(campaign.progress_data["turns_played"])


func test_a_reloaded_campaign_restores_its_turn_number() -> void:
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	var campaign := _campaign_at(8, 0)   # 8 turns completed, none in flight
	pm.bind_campaign(campaign)

	assert_int(pm.turn_number).override_failure_message(
		"turn_number came back as %d instead of 8. It resets to 0 on bind and "
		% pm.turn_number + "nothing put it back, so the persisted counter could "
		+ "never be raised again."
	).is_equal(8)


## A save written MID-turn has that turn still in flight, so its turn_number is one
## ahead of the completed count. Getting this wrong in either direction either skips
## a turn on every load or repeats one.
func test_a_mid_turn_save_restores_the_turn_in_flight() -> void:
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	# 3 = a real phase, so _restore_phase_from_campaign marks the turn in flight.
	var campaign := _campaign_at(8, 3)
	pm.bind_campaign(campaign)

	assert_int(pm.turn_number).override_failure_message(
		"A save written during turn 9 restored turn_number %d." % pm.turn_number
	).is_equal(9)


## The whole point: the persisted counter must move again.
func test_the_persisted_counter_advances_after_a_reload() -> void:
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	var campaign := _campaign_at(8, 0)
	pm.bind_campaign(campaign)

	pm.start_new_turn()                       # now playing turn 9
	assert_int(_persisted(campaign, pm.turn_number)).is_equal(8)
	pm.complete_current_turn()
	pm.start_new_turn()                       # now playing turn 10
	assert_int(_persisted(campaign, pm.turn_number)).override_failure_message(
		"After completing a cycle the campaign still reports %d turns played."
		% int(campaign.progress_data["turns_played"])
	).is_equal(9)


## The reset that bind_campaign does is still needed and must not be undone: a fresh
## campaign starts at zero, and campaign A's turn must never reach campaign B.
func test_a_fresh_campaign_still_starts_at_zero() -> void:
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	pm.bind_campaign(_campaign_at(0, 0))
	assert_int(pm.turn_number).is_equal(0)


func test_a_second_campaign_does_not_inherit_the_first_ones_turn() -> void:
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	pm.bind_campaign(_campaign_at(20, 0))
	assert_int(pm.turn_number).is_equal(20)
	pm.bind_campaign(_campaign_at(1, 0))
	assert_int(pm.turn_number).override_failure_message(
		"Campaign A's turn 20 leaked into campaign B, which is the defect "
		+ "bind_campaign's reset exists to prevent."
	).is_equal(1)
