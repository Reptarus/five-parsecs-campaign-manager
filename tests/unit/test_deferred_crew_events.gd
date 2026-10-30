extends GdUnitTestSuite
## The Trade and Explore results that pay off later (Core Rules pp.79-81) reach the hook
## their wording names, inside the window it gives.
##
## Measured on 2026-10-29 before the fix:
##   - twelve rows were cached in progress_data["pending_events"] and nothing spent them.
##     A turn-start popup showed the NEXT_TURN ones on the first turn of a session only,
##     applied numbers that were all 0, and then deleted them;
##   - Explore 1-3 ("I know a good deal") copied six fields of the Trade row it reached,
##     dropping its trigger, so those rows were not even held;
##   - Starship repair parts never rolled its 1D6, because a held row returns before the
##     roll is offered;
##   - every XP a Trade or Explore row granted was handed the table row as the character,
##     found no id on it, and was lost.

const Events = preload("res://src/core/campaign/DeferredCrewEvents.gd")
const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CTCScript = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const UPKEEP_SCENE := "res://src/ui/screens/world/components/UpkeepPhaseComponent.tscn"
const RUMORS_SCENE := "res://src/ui/screens/world/components/ResolveRumorsComponent.tscn"
const PaymentScript = preload("res://src/core/campaign/phases/post_battle/PaymentProcessor.gd")
const ContextScript = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const WPCScript = preload("res://src/ui/screens/world/WorldPhaseController.gd")
const EventDialogScript = preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

## Completed turns in the fixture campaign.
const TP := 3

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "deferred_crew_events_suite"})
	campaign.progress_data["turns_played"] = TP
	GameState.current_campaign = campaign


func after_test() -> void:
	for key: String in ["Explore Follow-up", "Trade Follow-up", "Trade Table",
			"Exploration Table", "Crew Task"]:
		DiceManager.clear_forced_results(key)
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _pd() -> Dictionary:
	return GameState.current_campaign.progress_data


## Hold a row as the crew-task cache would, found after `found_after` completed turns.
func _hold(event_name: String, found_after: int = TP, extra: Dictionary = {}) -> Dictionary:
	var e := {"id": "%s_%d" % [event_name, randi()], "event_name": event_name,
		"trigger_type": "", "crew_id": "", "effect": {}, "consumed": false}
	e.merge(extra, true)
	Events.stamp(e, found_after)
	if not _pd().has(Events.KEY):
		_pd()[Events.KEY] = []
	_pd()[Events.KEY].append(e)
	return e


func _held(event_name: String, at: int = TP) -> int:
	return Events.live(_pd(), event_name, at).size()


func _ctc():
	var c = auto_free(CTCScript.new())
	add_child(c)
	return c


func _upkeep() -> Node:
	var u: Node = auto_free((load(UPKEEP_SCENE) as PackedScene).instantiate())
	add_child(u)
	return u


## Line endings differ per file in this repo; compare in LF space.
func _upkeep_source() -> String:
	var src: String = FileAccess.get_file_as_string(UPKEEP_SCENE.replace(".tscn", ".gd"))
	assert_int(src.length()).is_greater(1000)
	return src.replace("\r", "")


func _task_result() -> Dictionary:
	return {"details": "", "reward": "", "penalty": "", "success": false,
		"roll": 0, "modified_roll": 0}


func test_each_row_is_live_only_in_its_printed_window() -> void:
	# Live during: the turn it was found, the next, the one after.
	var expect := {
		"Promising lead": [true, false, false],
		"Offered a small job": [true, false, false],
		"Insider information": [false, true, false],
		"You make a useful contact": [false, true, false],
		"Basic supplies": [false, true, true],
		"Trade goods": [true, true, true],
	}
	for row: String in expect:
		var e := {"event_name": row}
		Events.stamp(e, TP)
		for i in 3:
			assert_bool(Events.is_live(e, TP + i)).override_failure_message(
				"%s, %d turn(s) after it was found" % [row, i]).is_equal(expect[row][i])
	# Saved before windows existed: a turn-bound row has had its turn, a held item has not.
	assert_bool(Events.is_live({"event_name": "Insider information"}, TP)).is_false()
	assert_bool(Events.is_live({"event_name": "Trade goods"}, TP)).is_true()


func test_local_maps_lasts_this_world_and_the_next() -> void:
	_hold("Local maps")
	assert_int(_held("Local maps")).is_equal(1)
	Events.on_arrival(_pd())
	assert_int(_held("Local maps")).override_failure_message(
		"the following world still counts (p.79)").is_equal(1)
	Events.on_arrival(_pd())
	assert_int(_held("Local maps")).is_equal(0)


func test_a_bonus_is_spent_only_where_it_changes_the_roll() -> void:
	# task, roll, thresholds, contact, trinket, insider -> roll, contact, trinket, insider
	var rows := [
		["recruit", 5, [6], true, false, false, 6, true, false, false],
		["recruit", 6, [6], true, true, false, 6, false, false, false],
		["recruit", 3, [6], true, false, false, 3, false, false, false],
		["recruit", 4, [6], true, true, false, 6, false, true, false],
		["recruit", 3, [6], true, true, false, 6, true, true, false],
		["recruit", 5, [6], true, true, false, 6, true, false, false],
		["track", 5, [6], false, true, false, 5, false, false, false],
		["track", 5, [6], true, false, false, 6, true, false, false],
		["find_patron", 4, [5, 6], true, false, true, 5, false, false, true],
		["find_patron", 5, [5, 6], true, false, false, 6, true, false, false],
		["find_patron", 2, [5, 6], false, false, true, 5, false, false, true],
		["find_patron", 6, [5, 6], true, false, true, 6, false, false, false],
	]
	for r: Array in rows:
		var plan: Dictionary = Events.plan_roll_bonus(r[0], r[1], r[2], r[3], r[4], r[5])
		var got := [int(plan.roll), bool(plan.contact), bool(plan.trinket), bool(plan.insider)]
		assert_array(got).override_failure_message("%s -> %s" % [str(r), str(got)]) \
			.is_equal([r[6], r[7], r[8], r[9]])


func test_a_patron_roll_spends_insider_information_from_last_turn_only() -> void:
	var comp = _ctc()
	var task := {"id": "find_patron", "name": "Find a Patron", "dice_target": 5,
		"success_reward": "", "failure_penalty": ""}
	_hold("Insider information", TP)
	DiceManager.queue_forced_result("Crew Task", 1)
	var r: Dictionary = comp._resolve_dice_task(_task_result(), task, "find_patron", {})
	assert_bool(bool(r.success)).override_failure_message(
		"found this turn, it is for NEXT campaign turn (p.80)").is_false()
	assert_int(_held("Insider information", TP + 1)).is_equal(1)

	_pd()[Events.KEY] = []
	_hold("Insider information", TP - 1)
	DiceManager.queue_forced_result("Crew Task", 1)
	r = comp._resolve_dice_task(_task_result(), task, "find_patron", {})
	assert_bool(bool(r.success)).is_true()
	assert_str(str(r.reward)).contains("1 job offer")
	assert_int(_held("Insider information")).is_equal(0)


func test_a_trade_roll_holds_the_trinket_unless_a_swift_found_it() -> void:
	var comp = _ctc()
	DiceManager.queue_forced_result("Trade Table", 27)
	comp._resolve_table_task(_task_result(), {"id": "trade"},
		{"character_id": "c1", "species_id": "human"})
	var held: Array = Events.live(_pd(), "Luxury trinket", TP)
	assert_int(held.size()).is_equal(1)
	assert_str(str(held[0].get("crew_id", ""))).is_equal("c1")

	_pd()[Events.KEY] = []
	DiceManager.queue_forced_result("Trade Table", 27)
	var r: Dictionary = comp._resolve_table_task(_task_result(), {"id": "trade"},
		{"character_id": "c2", "species_id": "swift"})
	assert_int(_held("Luxury trinket")).override_failure_message(
		"a Swift keeps it for themselves (p.79)").is_equal(0)
	assert_int(int(r.table_result.get("xp", 0))).is_equal(2)


func test_a_good_deal_keeps_the_whole_trade_row() -> void:
	var comp = _ctc()
	DiceManager.queue_forced_result("Exploration Table", 2)
	DiceManager.queue_forced_result("Trade Table", 70)
	var r: Dictionary = comp._resolve_table_task(_task_result(), {"id": "explore"},
		{"character_id": "c1"})
	assert_str(str(r.table_result.get("name", ""))).is_equal("Insider information")
	assert_int(_held("Insider information", TP + 1)).override_failure_message(
		"a Trade row reached from Explore 1-3 is held like any other").is_equal(1)


func test_starship_repair_parts_rolls_its_d6() -> void:
	var comp = _ctc()
	var row: Dictionary = comp._get_trade_table_result(97)
	assert_str(str(row.get("name", ""))).is_equal("Starship repair parts")
	var events: Array = comp._classify_result({}, row, {})
	assert_int(int(events[0].get("type", -1))) \
		.is_equal(EventDialogScript.EventType.ROLL_FOR_CREDITS)


func test_table_xp_lands_on_the_crew_member() -> void:
	var comp = _ctc()
	var campaign = GameState.current_campaign
	campaign.add_crew_member({"id": "c1", "character_id": "c1",
		"character_name": "Ana", "experience": 0})
	comp._on_event_completed({}, {
		"type": EventDialogScript.EventType.GAIN_XP, "xp": 2, "crew_id": "c1",
		"crew_member": {"id": "c1", "character_id": "c1"},
		"event_name": "Found a trainer", "table_result": {"name": "Found a trainer"}})
	var member: Variant = campaign.get_crew_member_by_id("c1")
	var xp: int = int(member.get("experience", 0)) if member is Dictionary \
		else int(member.experience)
	assert_int(xp).override_failure_message("p.81 Found a trainer: +2 XP").is_equal(2)
	# The same row resolved without the dialog (auto-resolve) pays the same character.
	campaign.add_crew_member({"id": "c2", "character_id": "c2",
		"character_name": "Bo", "experience": 0})
	comp._auto_resolve_event({
		"type": EventDialogScript.EventType.GAIN_XP, "xp": 2, "crew_id": "c2",
		"crew_member": {"id": "c2", "character_id": "c2"},
		"event_name": "Found a trainer", "table_result": {"name": "Found a trainer"}})
	member = campaign.get_crew_member_by_id("c2")
	xp = int(member.get("experience", 0)) if member is Dictionary else int(member.experience)
	assert_int(xp).override_failure_message("auto-resolved XP").is_equal(2)


func test_basic_supplies_skip_one_upkeep_bill() -> void:
	var up: Node = _upkeep()
	_hold("Basic supplies", TP - 1)
	var bill: Dictionary = up.calculate_upkeep_costs()
	assert_str(str(bill.get("zone_waiver", ""))).contains("Basic supplies")
	assert_int(_held("Basic supplies")).override_failure_message(
		"showing the bill must not spend the supplies").is_equal(1)
	assert_bool(up.apply_upkeep_costs(bill)).is_true()
	assert_int(_held("Basic supplies")).is_equal(0)
	assert_str(str(up.calculate_upkeep_costs().get("zone_waiver", ""))).is_empty()


func test_a_held_fuel_cell_makes_the_jump_free_and_unlocks_travel() -> void:
	var up: Node = _upkeep()
	assert_int(up._apply_fuel_cell(5)).is_equal(5)
	_hold("Military fuel cell")
	up._travel_button = auto_free(Button.new())
	up.has_ship = true
	up._update_travel_button_text(0, 4)
	assert_bool(up._travel_button.disabled).override_failure_message(
		"a crew with no credits and a fuel cell can still jump (p.80)").is_false()
	assert_int(up._apply_fuel_cell(5)).is_equal(0)
	assert_int(up._fuel_cell_covered_last_trip).is_equal(5)
	assert_int(up._apply_fuel_cell(5)).override_failure_message("single-use").is_equal(5)
	up._update_travel_button_text(0, 4)
	assert_bool(up._travel_button.disabled).is_true()
	# The press spends it before the Fuel offset.
	assert_bool(_upkeep_source().contains(
		"\ttravel_cost = _apply_fuel_cell(travel_cost)\n"
		+ "\ttravel_cost = _apply_fuel_credits(travel_cost)\n")).is_true()


func test_a_package_pays_on_arrival_if_the_courier_is_still_aboard() -> void:
	var up: Node = _upkeep()
	var campaign = GameState.current_campaign
	campaign.add_crew_member({"id": "c1", "character_id": "c1", "character_name": "Ana"})
	_hold("Package delivered", TP, {"crew_id": "c1"})
	_hold("Package delivered", TP, {"crew_id": "gone"})
	var credits0: int = GameStateManager.get_credits()
	var rivals0: int = GameStateManager.get_rivals().size()
	var sp0: int = int(campaign.story_points)
	DiceManager.queue_forced_result("Explore Follow-up", 2)
	var lines: Array = up._settle_package_deliveries(_pd(), TP, "")
	assert_int(GameStateManager.get_credits()).override_failure_message(
		"+3 for the courier still aboard, nothing for the one who left").is_equal(credits0 + 3)
	assert_int(GameStateManager.get_rivals().size()).is_equal(rivals0 + 1)
	assert_int(int(campaign.story_points)).is_equal(sp0 + 1)
	assert_int(_held("Package delivered")).is_equal(0)
	assert_str(str(lines)).contains("lapsed")
	# The arrival settles it.
	assert_bool(_upkeep_source().contains("\t_check_personal_trinkets(campaign)\n"
		+ "\t_settle_held_arrival_events(_current_planet_id_for_events())\n")).is_true()


func test_trade_goods_perish_on_a_1_and_sell_at_the_roll() -> void:
	var up: Node = _upkeep()
	_hold("Trade goods")
	DiceManager.queue_forced_result("Trade Follow-up", 1)
	assert_int(up._roll_trade_goods_price(0)).is_equal(1)
	assert_int(_held("Trade goods")).is_equal(0)

	_hold("Trade goods")
	DiceManager.queue_forced_result("Trade Follow-up", 4)
	var credits0: int = GameStateManager.get_credits()
	assert_int(up._roll_trade_goods_price(0)).is_equal(4)
	assert_int(_held("Trade goods")).override_failure_message(
		"rolling shows the price; the player may still wait (p.79)").is_equal(1)
	assert_int(GameStateManager.get_credits()).is_equal(credits0)
	up._sell_trade_goods(0, 4)
	assert_int(GameStateManager.get_credits()).is_equal(credits0 + 4)
	assert_int(_held("Trade goods")).is_equal(0)


func test_local_maps_add_a_rumor_to_a_new_quest() -> void:
	var rr: Node = auto_free((load(RUMORS_SCENE) as PackedScene).instantiate())
	add_child(rr)
	rr.rumors = ["r1", "r2"]
	_hold("Local maps")
	rr._generate_quest_from_rumors()
	assert_int(int(GameState.current_campaign.quest_rumors)).override_failure_message(
		"Local maps: +1 Rumor on receiving a Quest (p.79)").is_equal(1)
	assert_int(_held("Local maps")).is_equal(0)


func test_a_promising_lead_pays_on_an_opportunity_mission_only() -> void:
	var pay = PaymentScript.new()
	var ctx = ContextScript.new()
	ctx.campaign = GameState.current_campaign
	ctx.game_state_manager = GameStateManager
	_hold("Promising lead")
	ctx.battle_result = {"mission_source": "patron"}
	assert_int(pay.process_promising_lead(ctx)).is_equal(0)
	ctx.battle_result = {"mission_source": "opportunity", "is_invasion": true}
	assert_int(pay.process_promising_lead(ctx)).is_equal(0)
	# A Quest battle with no source of its own normalizes to "opportunity"; its
	# quest_id (or finale flag) is what says it is not one.
	ctx.battle_result = {"mission_source": "opportunity", "quest_id": "q1"}
	assert_int(pay.process_promising_lead(ctx)).is_equal(0)
	ctx.battle_result = {"mission_source": "opportunity", "is_quest_finale": true}
	assert_int(pay.process_promising_lead(ctx)).is_equal(0)
	assert_int(_held("Promising lead")).is_equal(1)
	var credits0: int = GameStateManager.get_credits()
	ctx.battle_result = {"mission_source": "opportunity"}
	assert_int(pay.process_promising_lead(ctx)).is_equal(3)
	assert_int(GameStateManager.get_credits()).is_equal(credits0 + 3)
	assert_int(_held("Promising lead")).is_equal(0)
	# The call site: Step 4 of the post-battle sequence pays it.
	# Line endings differ per file in this repo; compare in "\n" space.
	var src: String = FileAccess.get_file_as_string(
		"res://src/core/campaign/phases/PostBattlePhase.gd").replace("\r", "")
	assert_int(src.length()).is_greater(1000)
	assert_bool(src.contains("\t\t_payment.process_promising_lead(_ctx)\n")).is_true()


func test_the_world_phase_no_longer_spends_held_events_at_turn_start() -> void:
	var names: Array = []
	var script: Script = WPCScript
	for m: Dictionary in script.get_script_method_list():
		names.append(str(m.get("name", "")))
	assert_bool("check_deferred_events" in names).is_false()
	assert_bool("_apply_deferred_event_effects" in names).is_false()
