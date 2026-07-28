extends GdUnitTestSuite
## CampaignPhaseManager is an AUTOLOAD, so its turn/phase state survives a campaign
## switch unless something explicitly rebinds it.
##
## THE BUG THIS EXISTS TO PREVENT
## The only resets were setup() — which CampaignTurnController guards behind
## `if not campaign_phase_manager.game_state`, true exactly ONCE per session — and
## set_campaign(), called only from new-campaign finalization.
## GameState.load_campaign() never touched the manager at all.
##
## So loading a SECOND campaign in one session inherited the first one's turn
## number, and it was PERSISTED: _on_campaign_turn_started() writes
## progress_data["turns_played"] = max(current, turn_number - 1) and the phase
## completion handler autosaves. The max() exists to stop a stale value LOWERING the
## count, which is precisely why a stale HIGH value silently RAISES it. Play A to
## turn 20, load B at turn 1, and B is turn 19 on disk forever — moving Red Zone
## eligibility (10+ turns), story-point earning (every 3rd turn) and Galactic War
## progression.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _saved_turn: int = 0
var _saved_bound: String = ""


func _cpm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/CampaignPhaseManager")


func before_test() -> void:
	var cpm := _cpm()
	if cpm:
		_saved_turn = int(cpm.turn_number)
		_saved_bound = str(cpm.get("_bound_campaign_id"))


func after_test() -> void:
	## Restore in a lifecycle hook. This is a live autoload; leaving a test campaign
	## bound to it would corrupt every later suite in the same process.
	var cpm := _cpm()
	if cpm:
		cpm.turn_number = _saved_turn
		cpm.set("_bound_campaign_id", _saved_bound)


func _campaign(id: String) -> Object:
	var c = CampaignCore.new()
	c.campaign_id = id
	return c


# --- identity change must reset -----------------------------------------------

func test_switching_campaigns_resets_the_turn_number() -> void:
	var cpm := _cpm()
	if cpm == null:
		return  # no autoload in this context; nothing to assert
	assert_bool(cpm.has_method("bind_campaign")).override_failure_message(
		"CampaignPhaseManager.bind_campaign() is missing. Without it nothing rebinds " +
		"turn/phase state on a campaign switch — do NOT skip, this is the defect."
	).is_true()
	cpm.bind_campaign(_campaign("campaign_a"))
	cpm.turn_number = 20              # A played to turn 20

	cpm.bind_campaign(_campaign("campaign_b"))

	assert_int(int(cpm.turn_number)).override_failure_message(
		"campaign B inherited A's turn number; the next turn-start writes it into " +
		"B's progress_data via max() and autosaves it"
	).is_equal(0)


func test_switching_campaigns_clears_the_phase() -> void:
	var cpm := _cpm()
	if cpm == null:
		return  # no autoload in this context; nothing to assert
	assert_bool(cpm.has_method("bind_campaign")).override_failure_message(
		"CampaignPhaseManager.bind_campaign() is missing. Without it nothing rebinds " +
		"turn/phase state on a campaign switch — do NOT skip, this is the defect."
	).is_true()
	cpm.bind_campaign(_campaign("campaign_a"))
	cpm.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRADING

	cpm.bind_campaign(_campaign("campaign_b"))

	assert_int(int(cpm.current_phase)).override_failure_message(
		"campaign B resumed into A's phase, so the turn controller skipped " +
		"start_new_campaign_turn() and opened the wrong phase UI"
	).is_equal(int(GlobalEnums.FiveParsecsCampaignPhase.NONE))


# --- same identity must NOT reset ---------------------------------------------

func test_rebinding_the_same_campaign_preserves_in_flight_state() -> void:
	# Re-entering the turn controller mid-campaign (e.g. back from a battle) must
	# not wipe the turn. A reset-always fix would be worse than the bug.
	var cpm := _cpm()
	if cpm == null:
		return  # no autoload in this context; nothing to assert
	assert_bool(cpm.has_method("bind_campaign")).override_failure_message(
		"CampaignPhaseManager.bind_campaign() is missing. Without it nothing rebinds " +
		"turn/phase state on a campaign switch — do NOT skip, this is the defect."
	).is_true()
	cpm.bind_campaign(_campaign("campaign_a"))
	cpm.turn_number = 7
	cpm.current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRADING

	cpm.bind_campaign(_campaign("campaign_a"))   # same id, different instance

	assert_int(int(cpm.turn_number)).override_failure_message(
		"re-entering the same campaign wiped its in-flight turn"
	).is_equal(7)
	assert_int(int(cpm.current_phase)).is_equal(
		int(GlobalEnums.FiveParsecsCampaignPhase.TRADING))


func test_binding_null_is_a_no_op() -> void:
	var cpm := _cpm()
	if cpm == null:
		return  # no autoload in this context; nothing to assert
	assert_bool(cpm.has_method("bind_campaign")).override_failure_message(
		"CampaignPhaseManager.bind_campaign() is missing. Without it nothing rebinds " +
		"turn/phase state on a campaign switch — do NOT skip, this is the defect."
	).is_true()
	cpm.bind_campaign(_campaign("campaign_a"))
	cpm.turn_number = 4
	cpm.bind_campaign(null)
	assert_int(int(cpm.turn_number)).is_equal(4)
