extends GdUnitTestSuite
## The Tactics turn's DATA PATH — the wiring, not the rules.
##
## Before 2026-09-07 a Tactics turn passed no data at all. Three panels emitted
## `phase_completed.emit(<phase>, {})` and TacticsTurnController._connect_signals()
## wired them with `func(_p, _d): phase_manager.complete_current_phase()`, discarding
## even that. Because every branch of the six `_apply_*` consumers in
## TacticsPhaseManager is keyed on `data.has(...)`, all of them were permanently false:
## orders, intel, scenario, deployed_units, story_event, skills_acquired, cp_spent,
## roster_changes, operational_map_update and pbp_spent had a correct consumer and no
## producer that could reach it. `play_another` went the same way, which made
## MAX_BATTLES_PER_TURN unreachable.
##
## ⭐ These cases assert CAMPAIGN STATE after the fact, never that a signal fired. A
## signal-spy suite passes happily while the payload is dropped, because the signal IS
## emitted — it is the argument that goes missing.
##
## Detection proof, one arm at a time:
##   * restore the three `func(_p, _d): ... complete_current_phase()` lambdas ->
##     test_the_controller_forwards_the_panel_payload must FAIL
##   * restore `phase_completed.emit(7, {})` in TacticsOperationalMapPanel ->
##     test_the_operational_map_panel_emits_a_real_payload must FAIL
## Both halves are required; fixing either alone changes nothing a player can see.

const PhaseManager = preload("res://src/core/campaign/TacticsPhaseManager.gd")
const TurnController = preload("res://src/ui/screens/tactics/TacticsTurnController.gd")
const OpMapPanel = preload(
	"res://src/ui/screens/tactics/panels/TacticsOperationalMapPanel.gd")
const TacticsCore = preload("res://src/game/campaign/TacticsCampaignCore.gd")


func _campaign() -> Resource:
	var c = TacticsCore.new()
	c.operational_map = {
		"player_cohesion": 5,
		"enemy_cohesion": 5,
		"player_battle_points": 0,
		"operational_turn": 0,
		"focus_zone_id": "z1",
		"regions": [{"id": "r1", "name": "North", "zones": ["z1"], "is_focus": true}],
		"zones": [{
			"id": "z1", "region_id": "r1", "name": "North Pass", "status": 0,
			"player_army_strength": 4, "enemy_army_strength": 4,
		}],
		"orders_history": [],
	}
	return c


func _manager(campaign: Resource):
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(campaign)
	return pm


# MARK: - THE KEYSTONE: the controller must forward what the panel emitted

func test_the_controller_forwards_the_panel_payload() -> void:
	## Drives the REAL TacticsTurnController wiring. `campaign` is set directly so the
	## test does not need a loaded GameState, but every line that matters —
	## _create_phase_manager, _create_panels, _connect_signals — is the production one.
	var campaign := _campaign()
	var ctrl = TurnController.new()
	add_child(ctrl)
	auto_free(ctrl)
	await await_idle_frame()

	ctrl.campaign = campaign
	ctrl.PhaseManagerScript = PhaseManager
	ctrl.BattleSetupScript = load(
		"res://src/ui/screens/tactics/panels/TacticsBattleSetupPanel.gd")
	ctrl.PostBattleScript = load(
		"res://src/ui/screens/tactics/panels/TacticsPostBattlePanel.gd")
	ctrl.OpMapScript = OpMapPanel
	ctrl._build_layout()
	ctrl._create_phase_manager()
	ctrl._create_panels()
	ctrl._connect_signals()
	await await_idle_frame()

	ctrl.phase_manager.go_to_phase(PhaseManager.Phase.STRATEGIC)

	# The panel emits; the controller's lambda is the only thing between it and the
	# consumer. A dropped payload leaves the zone untouched.
	ctrl._op_map.phase_completed.emit(7, {
		"operational_map_update": {
			"zones": [{"id": "z1", "enemy_army_strength": 1}],
			"player_cohesion": 5,
			"enemy_cohesion": 4,
			"focus_zone_id": "z1",
		},
		"pbp_spent": 0,
	})
	await await_idle_frame()

	var zones: Array = campaign.operational_map.get("zones", [])
	assert_int(zones.size()) \
		.override_failure_message(
			"the operational map was not written back at all — the controller lambda "
			+ "dropped the panel's payload, which is the defect this suite exists for") \
		.is_equal(1)
	assert_int(int((zones[0] as Dictionary).get("enemy_army_strength", -1))) \
		.override_failure_message(
			"zones arrived but the damaged Army Strength did not") \
		.is_equal(1)
	assert_int(int(campaign.operational_map.get("enemy_cohesion", -1))).is_equal(4)


# MARK: - The producer half: the panel must emit something to forward

func test_the_operational_map_panel_emits_a_real_payload() -> void:
	var campaign := _campaign()
	var panel = OpMapPanel.new()
	add_child(panel)
	auto_free(panel)
	await await_idle_frame()

	panel.setup(null, campaign)
	panel.show_phase(7)
	await await_idle_frame()

	var captured: Array = []
	panel.phase_completed.connect(func(p: int, d: Dictionary) -> void:
		captured.append({"phase": p, "data": d}))
	panel._on_complete()

	assert_int(captured.size()).is_equal(1)
	var data: Dictionary = captured[0]["data"]
	assert_bool(data.has("operational_map_update")) \
		.override_failure_message(
			"the panel emitted an empty payload; TacticsPhaseManager"
			+ "._apply_strategic_results() is keyed entirely on data.has(...) so an "
			+ "empty dict makes every branch permanently false") \
		.is_true()
	assert_bool(data.has("pbp_spent")).is_true()
	# ⚠ The spend must NOT also ride inside operational_map_update: the consumer
	# derives PBP from `pbp_spent`, so carrying both would double-count it.
	var update: Dictionary = data["operational_map_update"]
	assert_bool(update.has("player_battle_points")) \
		.override_failure_message(
			"operational_map_update must not carry player_battle_points — the "
			+ "consumer already deducts pbp_spent, and both would double-count") \
		.is_false()


# MARK: - Each restored channel, asserted on campaign state

func test_orders_intel_scenario_and_deployment_reach_the_campaign() -> void:
	var campaign := _campaign()
	var pm = _manager(campaign)
	campaign.current_battle = {}

	pm.go_to_phase(PhaseManager.Phase.ORDERS)
	pm.complete_current_phase({"orders": "flank_left"})
	assert_str(str(campaign.current_battle.get("orders", ""))).is_equal("flank_left")

	pm.go_to_phase(PhaseManager.Phase.RECON)
	pm.complete_current_phase({"intel": {"enemy_units": 3}})
	assert_bool(campaign.current_battle.has("intel")).is_true()

	pm.go_to_phase(PhaseManager.Phase.BATTLE_PREP)
	pm.complete_current_phase({"scenario": "hold_the_line"})
	assert_str(str(campaign.current_battle.get("scenario", ""))).is_equal(
		"hold_the_line")

	pm.go_to_phase(PhaseManager.Phase.DEPLOYMENT)
	pm.complete_current_phase({"deployed_units": ["u1", "u2"]})
	assert_int((campaign.current_battle.get("deployed_units", []) as Array).size()) \
		.is_equal(2)


func test_a_story_event_reaches_the_campaign() -> void:
	var campaign := _campaign()
	var pm = _manager(campaign)
	var before: int = (campaign.story_events as Array).size()
	pm.go_to_phase(PhaseManager.Phase.POST_BATTLE)
	pm.complete_current_phase({"story_event": {"id": "ambushed"}})
	assert_int((campaign.story_events as Array).size()).is_equal(before + 1)


func test_cp_spending_reaches_the_campaign() -> void:
	## CP is a derived balance (earned - spent), not a single field — spend_cp() is the
	## mutation API, and _apply_advancement_results() routes through it.
	var campaign := _campaign()
	campaign.earn_cp(10)
	var pm = _manager(campaign)
	pm.go_to_phase(PhaseManager.Phase.ADVANCEMENT)
	pm.complete_current_phase({"cp_spent": 4})
	assert_int(campaign.get_available_cp()).is_equal(6)


func test_pbp_spent_is_deducted_and_never_goes_negative() -> void:
	var campaign := _campaign()
	campaign.operational_map["player_battle_points"] = 2
	var pm = _manager(campaign)
	pm.go_to_phase(PhaseManager.Phase.STRATEGIC)
	pm.complete_current_phase({"pbp_spent": 5})
	assert_int(int(campaign.operational_map.get("player_battle_points", -1))) \
		.override_failure_message(
			"a payload is untrusted input; over-spending must clamp at 0") \
		.is_equal(0)


# MARK: - play_another (p.96) — the multi-battle loop that could never run

func test_play_another_loops_back_to_battle_prep() -> void:
	var campaign := _campaign()
	var pm = _manager(campaign)
	pm.start_new_turn()
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}, "play_another": true})
	assert_int(pm.current_phase) \
		.override_failure_message(
			"with play_another the turn should loop back to BATTLE_PREP; dropping the "
			+ "payload made MAX_BATTLES_PER_TURN unreachable") \
		.is_equal(PhaseManager.Phase.BATTLE_PREP)


func test_without_play_another_the_turn_advances_normally() -> void:
	var campaign := _campaign()
	var pm = _manager(campaign)
	pm.start_new_turn()
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}})
	assert_int(pm.current_phase).is_equal(PhaseManager.Phase.POST_BATTLE)


# MARK: - Step 2 (p.96) — PBP had no producer at all

func test_a_tabletop_victory_earns_a_battle_point() -> void:
	var campaign := _campaign()
	var pm = _manager(campaign)
	pm.start_new_turn()
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}})
	assert_int(int(campaign.operational_map.get("player_battle_points", -1))) \
		.override_failure_message(
			"p.96: 'Award 1 Player Battle Point (1 PBP) for every tabletop battle "
			+ "victory'. Nothing incremented this field before 2026-09-07.") \
		.is_equal(1)


func test_a_defeat_earns_nothing_and_cancels_a_previous_win() -> void:
	## p.96: both sides' points cancel 1-for-1 in the same Zone. A loss is the enemy's
	## victory, so win-then-lose nets zero.
	var campaign := _campaign()
	var pm = _manager(campaign)
	pm.start_new_turn()
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}})
	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": false}})
	assert_int(int(campaign.operational_map.get("player_battle_points", -1))).is_equal(0)


func test_three_wins_in_one_turn_still_only_earn_two() -> void:
	## "a specific army cannot gain more than 2 PBP in a single operational turn"
	var campaign := _campaign()
	var pm = _manager(campaign)
	pm.start_new_turn()
	for _i in range(3):
		pm.go_to_phase(PhaseManager.Phase.BATTLE)
		pm.complete_current_phase({"battle_result": {"won": true}})
	assert_int(int(campaign.operational_map.get("player_battle_points", -1))).is_equal(2)


# MARK: - Step 9 (p.99) — the campaign end condition that had no caller

func test_zero_enemy_cohesion_ends_the_campaign_as_a_player_win() -> void:
	var campaign := _campaign()
	campaign.operational_map["enemy_cohesion"] = 1
	var pm = _manager(campaign)
	var seen: Array = []
	pm.campaign_ended.connect(func(r: String) -> void: seen.append(r))

	pm.go_to_phase(PhaseManager.Phase.STRATEGIC)
	pm.complete_current_phase({"enemy_regions_lost": 1})

	assert_int(int(campaign.operational_map.get("enemy_cohesion", -1))).is_equal(0)
	assert_array(seen) \
		.override_failure_message(
			"p.99 Step 9 is the campaign's end condition. is_player_victory() existed "
			+ "and was correct with ZERO callers, so Cohesion could hit 0 unnoticed.") \
		.contains(["player"])


func test_no_region_lost_costs_nobody_cohesion() -> void:
	## The common case: a strategic phase where no region changed hands must not
	## quietly drain Cohesion. An absent key is not a zero-region loss to be applied.
	var campaign := _campaign()
	var pm = _manager(campaign)
	pm.go_to_phase(PhaseManager.Phase.STRATEGIC)
	pm.complete_current_phase({})
	assert_int(int(campaign.operational_map.get("player_cohesion", -1))).is_equal(5)
	assert_int(int(campaign.operational_map.get("enemy_cohesion", -1))).is_equal(5)
