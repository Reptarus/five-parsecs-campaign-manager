extends GdUnitTestSuite
## T9-02 (Aug 9 2026): the start_new_turn() once-per-turn guard, driven through the
## PRODUCTION turns_played wiring rather than a hand-set premise.
##
## Why this suite exists. The first guard (Aug 8) keyed a persisted marker on
## progress_data["turns_played"]. test_tablet_qa_aug08_fixes.gd asserted it by
## HAND-SETTING turns_played between calls — a premise, not the live path. The live
## writer is CampaignTurnController._on_campaign_turn_started() (:638), a listener on
## the signal start_new_turn() emits at its BOTTOM, so the key is written downstream
## of its own read. Wiring that listener for real exposed two defects at once:
##   1. turn 2 of EVERY campaign had its whole rollover swallowed (key lag), and
##   2. the SECOND spurious re-entry got through anyway (the listener ratchets the key
##      off turn_number, which the spurious call itself bumps).
## Both were measured, not reasoned: 6-turn trace + "21 -> 22" interest.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const CampaignCoreScript := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PhaseManagerScript := preload("res://src/core/campaign/CampaignPhaseManager.gd")
const GameStateScript := preload("res://src/core/state/GameState.gd")


func _campaign(debt: int, turns_played: int) -> Resource:
	var c: Resource = CampaignCoreScript.new()
	c.ship_debt = debt
	if "ship_data" in c and c.ship_data is Dictionary:
		c.ship_data["debt"] = debt
	if "has_ship" in c:
		c.has_ship = true
	c.progress_data["turns_played"] = turns_played
	return c


func _manager_on(campaign: Resource) -> Node:
	var gs: Node = auto_free(GameStateScript.new())
	add_child(gs)
	gs.current_campaign = campaign
	var cpm: Node = auto_free(PhaseManagerScript.new())
	add_child(cpm)
	cpm.game_state = gs
	return cpm


## Reproduces CampaignTurnController._on_campaign_turn_started (:626-638) verbatim:
## the ONLY live writer of turns_played on the 5PFH path. Without this the suite
## tests a world that does not exist.
func _wire_production_turn_counter(cpm: Node, campaign: Resource) -> void:
	cpm.campaign_turn_started.connect(
		func(turn_number: int) -> void:
			var derived: int = turn_number - 1
			var current: int = int(campaign.progress_data.get("turns_played", 0))
			campaign.progress_data["turns_played"] = max(current, derived)
	)


func test_every_consecutive_turn_gets_its_rollover_under_the_real_wiring() -> void:
	# DETECTION-CRITICAL. A swallowed rollover is silent and costs a turn's worth of
	# RULES RESETS, not just interest: _clear_upkeep_lockouts() (p.76) leaves a
	# locked-out crew member locked out an extra turn, and the pp.73-74 per-turn
	# spend caps stay consumed. The Aug 8 key-based guard swallowed turn 2 of every
	# campaign; this trace is what caught it.
	var c := _campaign(20, 0)
	var cpm := _manager_on(c)
	_wire_production_turn_counter(cpm, c)

	var trace: Array[String] = []
	var skipped: int = 0
	for i in range(6):
		var before: int = int(c.ship_debt)
		cpm.start_new_turn()
		var ran: bool = int(c.ship_debt) != before
		if not ran:
			skipped += 1
		trace.append("turn %d: tn=%d turns_played=%d -> %s" % [
			i + 1, int(cpm.turn_number),
			int(c.progress_data.get("turns_played", 0)),
			"RAN" if ran else "SKIPPED"])
		cpm.complete_current_turn()   # a real turn ENDS; that is what releases the latch

	assert_int(skipped).override_failure_message(
		"the guard swallowed %d of 6 consecutive completed turns. Trace:\n  " % skipped +
		"\n  ".join(trace)).is_equal(0)


func test_a_spurious_re_entry_within_one_turn_is_blocked_every_time() -> void:
	# The bug the guard exists for: T8-02's dashboard bounce re-entered
	# start_new_turn() inside one campaign turn and double-charged p.76 interest
	# (ship_debt 43 -> 45 on an unchanged turn). The Aug 8 guard blocked the first
	# repeat and let the second through — hence "every time" in the name.
	var c := _campaign(20, 0)
	var cpm := _manager_on(c)
	_wire_production_turn_counter(cpm, c)

	cpm.start_new_turn()                       # the legitimate turn start
	var after_legit: int = int(c.ship_debt)
	var turn_after_legit: int = int(cpm.turn_number)
	for _i in range(3):
		cpm.start_new_turn()                   # dashboard bounces, no turn completed

	assert_int(int(c.ship_debt)).override_failure_message(
		"spurious re-entry re-applied p.76 interest: %d -> %d" % [
			after_legit, int(c.ship_debt)]).is_equal(after_legit)
	assert_int(int(cpm.turn_number)).override_failure_message(
		"a blocked re-entry still advanced turn_number %d -> %d, so it ran code below " % [
			turn_after_legit, int(cpm.turn_number)] +
		"the guard — including the Story Track / Intro Campaign per-turn hooks (T9-01)"
	).is_equal(turn_after_legit)


func test_the_latch_is_session_scoped_and_cannot_stall_a_campaign() -> void:
	# The latch must NEVER be persisted. A turn that ends abnormally (app killed at
	# the Cycle Summary) would otherwise leave it true on disk and silently stop
	# EVERY future rollover — far worse than the double-charge it prevents. A fresh
	# manager (= a new app session) must always be willing to start a turn.
	var c := _campaign(20, 4)
	var cpm := _manager_on(c)
	_wire_production_turn_counter(cpm, c)
	cpm.start_new_turn()          # turn starts, latch set, never completed
	var mid: int = int(c.ship_debt)
	cpm.start_new_turn()          # blocked
	assert_int(int(c.ship_debt)).is_equal(mid)

	assert_bool("rollover_applied_for_turn" in c.progress_data).override_failure_message(
		"the rejected key-based marker is being written again — see the note at " +
		"CampaignPhaseManager.start_new_turn()").is_false()

	# Same campaign, brand new session — and no persisted phase, i.e. the turn had
	# completed. It must be willing to start the next one.
	c.progress_data.erase("current_turn_phase")
	var cpm2 := _manager_on(c)
	_wire_production_turn_counter(cpm2, c)
	var before: int = int(c.ship_debt)
	cpm2.start_new_turn()
	assert_int(int(c.ship_debt)).override_failure_message(
		"a new app session refused to start a turn — the latch leaked across sessions"
	).is_not_equal(before)


# ------------------------------------------------------------------- T9-04
# The turn phase is now persisted, so relaunching mid-turn resumes instead of
# replaying the turn's rollover. Measured before the fix on the tablet: opening the
# app mid-turn charged another round of p.76 interest (ship_debt 45 -> 47).

# GameEnums.FiveParcsecsCampaignPhase.UPKEEP. The enum is NONE, SETUP, STORY, TRAVEL,
# PRE_MISSION, MISSION, BATTLE_SETUP, BATTLE_RESOLUTION, POST_MISSION, UPKEEP, ... so
# UPKEEP is 9 — do not assume the turn-order position (it is the 1st phase played).
const PHASE_UPKEEP := 9


func test_starting_a_phase_records_it_on_the_campaign() -> void:
	var c := _campaign(20, 4)
	var cpm := _manager_on(c)
	cpm.start_phase(PHASE_UPKEEP)
	assert_int(int(c.progress_data.get("current_turn_phase", -1))).override_failure_message(
		"start_phase() did not persist the phase, so a relaunch cannot know the turn " +
		"was already underway").is_equal(PHASE_UPKEEP)


func test_finishing_a_turn_clears_the_recorded_phase() -> void:
	# NONE is the between-turns state and is what lets the NEXT launch correctly start
	# a new turn. If completion left a real phase behind, the campaign would resume a
	# turn that had already ended and never roll over again.
	var c := _campaign(20, 4)
	var cpm := _manager_on(c)
	cpm.start_phase(PHASE_UPKEEP)
	cpm.complete_current_turn()
	assert_int(int(c.progress_data.get("current_turn_phase", -1))).is_equal(0)


func test_relaunching_mid_turn_resumes_instead_of_replaying_the_rollover() -> void:
	# DETECTION-CRITICAL. This is the measured device bug: every app launch on a
	# mid-turn save re-ran the whole rollover — another p.76 interest charge, a p.76
	# upkeep lockout cleared, the pp.73-74 spend caps reset.
	var c := _campaign(20, 4)
	c.campaign_id = "resume_test"
	c.progress_data["current_turn_phase"] = PHASE_UPKEEP   # saved mid-turn

	var cpm := _manager_on(c)                              # fresh session
	_wire_production_turn_counter(cpm, c)
	cpm.bind_campaign(c)                                   # what the turn controller does first

	assert_int(int(cpm.current_phase)).override_failure_message(
		"the saved phase was not restored, so CampaignTurnController.gd:122 still sees " +
		"NONE and starts a fresh turn").is_equal(PHASE_UPKEEP)

	var before: int = int(c.ship_debt)
	cpm.start_new_turn()   # the spurious launch-time call the controller would make
	assert_int(int(c.ship_debt)).override_failure_message(
		"relaunching mid-turn charged p.76 interest again: %d -> %d" % [
			before, int(c.ship_debt)]).is_equal(before)


func test_a_save_written_between_turns_still_starts_the_next_one() -> void:
	# The other half: a campaign whose previous turn COMPLETED must not be stuck.
	var c := _campaign(20, 4)
	c.campaign_id = "between_turns"
	c.progress_data["current_turn_phase"] = 0   # NONE — turn finished

	var cpm := _manager_on(c)
	_wire_production_turn_counter(cpm, c)
	cpm.bind_campaign(c)
	var before: int = int(c.ship_debt)
	cpm.start_new_turn()
	assert_int(int(c.ship_debt)).override_failure_message(
		"a completed-turn save refused to start the next turn — the campaign is stuck"
	).is_not_equal(before)


func test_a_legacy_save_with_no_recorded_phase_behaves_as_before() -> void:
	# Pre-Aug-9 saves carry no key. They must keep the old behaviour (one turn start on
	# first load) rather than silently freezing, and are self-healing from then on.
	var c := _campaign(20, 4)
	c.campaign_id = "legacy_no_phase"
	c.progress_data.erase("current_turn_phase")
	var cpm := _manager_on(c)
	_wire_production_turn_counter(cpm, c)
	cpm.bind_campaign(c)
	var before: int = int(c.ship_debt)
	cpm.start_new_turn()
	assert_int(int(c.ship_debt)).is_not_equal(before)
