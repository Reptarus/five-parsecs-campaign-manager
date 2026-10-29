extends GdUnitTestSuite
## Crew-task Rumors and purchases reach the campaign (Core Rules pp.80-81).
##
## _apply_rumor() appended to campaign.rumors, a field FiveParsecsCampaignCore does
## not have, so every Rumor a Trade or Explore result granted was dropped, and
## Information broker (p.81) charged 2 credits a Rumor for nothing. The purchase
## handlers ignored remove_credits()' refusal and granted the goods anyway, the
## picker never capped by credits, and the p.80 Precursor "roll 1D6, on a 5+ a
## second Rumor" was a string in the data that nothing rolled. Every case reads
## the campaign afterwards: the Rumor count, the credits, the stash.

const CrewTaskScene = preload("res://src/ui/screens/world/components/CrewTaskComponent.tscn")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _dm: Node
var _snap: Dictionary = {}
var _prev_campaign = null
var _campaign = null


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_dm = get_node("/root/DiceManager")
	_dm.clear_forced_results()
	_prev_campaign = get_node("/root/GameState").current_campaign


func after_test() -> void:
	_dm.clear_forced_results()
	get_node("/root/GameState").current_campaign = _prev_campaign
	SaveDirGuard.restore(_snap)


func _crew_task(credits: int) -> Node:
	var crew: Array = []
	for i in 6:
		crew.append({"character_name": "Crew %d" % i, "species_id": "human",
			"character_class": "soldier", "savvy": 0})
	_campaign = CampaignCore.new()
	_campaign.crew_data = {"members": crew}
	_campaign.credits = credits
	_campaign.quest_rumors = 0
	get_node("/root/GameState").current_campaign = _campaign
	var tasks: Node = auto_free(CrewTaskScene.instantiate())
	add_child(tasks)
	return tasks


func _member(species: String) -> Dictionary:
	return {"character_name": "Ana", "species_id": species, "character_class": "soldier",
		"savvy": 0}


func _event(type: int, extra: Dictionary = {}) -> Dictionary:
	var ev := {"type": type, "crew_id": "", "crew_name": "Ana", "crew_member": _member("human"),
		"task_type": "Explore", "event_name": "Test", "effect_text": "", "table_result": {}}
	ev.merge(extra, true)
	return ev


func _stash_size() -> int:
	var stash: Variant = _campaign.equipment_data.get("equipment", [])
	return (stash as Array).size() if stash is Array else 0


func test_a_rumor_from_a_crew_task_reaches_the_campaign() -> void:
	# p.81 54-57 "Overheard some talk: Gain a Rumor."
	var tasks := _crew_task(0)
	tasks._on_event_completed({}, _event(CrewTaskEventDialog.EventType.GAIN_RUMOR))
	assert_int(int(_campaign.quest_rumors)).is_equal(1)


func test_information_broker_gives_the_rumors_it_charges_for() -> void:
	# p.81 65-68 "Buy up to 3 Rumors for 2 credits each."
	var tasks := _crew_task(10)
	tasks._on_event_completed({"quantity": 3, "total_cost": 6},
		_event(CrewTaskEventDialog.EventType.BUY_RUMORS, {"cost_each": 2, "max_quantity": 3}))
	assert_int(int(_campaign.quest_rumors)).is_equal(3)
	assert_int(int(_campaign.credits)).is_equal(4)


func test_a_purchase_the_crew_cannot_pay_for_gives_nothing() -> void:
	var tasks := _crew_task(3)
	tasks._on_event_completed({"quantity": 3, "total_cost": 6},
		_event(CrewTaskEventDialog.EventType.BUY_RUMORS, {"cost_each": 2, "max_quantity": 3}))
	assert_int(int(_campaign.quest_rumors)).is_equal(0)
	assert_int(int(_campaign.credits)).is_equal(3)
	var before := _stash_size()
	tasks._on_event_completed({"quantity": 2, "total_cost": 6},
		_event(CrewTaskEventDialog.EventType.BUY_WEAPONS, {"cost_each": 3, "max_quantity": 0}))
	assert_int(_stash_size()).is_equal(before)
	assert_int(int(_campaign.credits)).is_equal(3)


func test_the_picker_caps_a_purchase_by_the_credits_held() -> void:
	# Information broker: up to 3 at 2 each. 5 credits buys 2.
	assert_int(CrewTaskEventDialog.buy_cap(3, 2, 5)).is_equal(2)
	assert_int(CrewTaskEventDialog.buy_cap(3, 2, 40)).is_equal(3)
	# p.81 Arms dealer, "any number" at 3 each: the credits are the only cap.
	assert_int(CrewTaskEventDialog.buy_cap(0, 3, 10)).is_equal(3)
	assert_int(CrewTaskEventDialog.buy_cap(0, 3, 2)).is_equal(0)
	# A caller that did not say leaves the printed cap alone.
	assert_int(CrewTaskEventDialog.buy_cap(3, 2, -1)).is_equal(3)


func test_the_picker_opens_with_the_cap_the_crew_can_pay() -> void:
	# The component hands the balance to the dialog as it opens; assert the cap the
	# player is offered, not only the helper.
	var tasks := _crew_task(5)
	# _event_queue is a typed array, so it is filled in place, not assigned.
	tasks._event_queue.clear()
	tasks._event_queue.append(_event(CrewTaskEventDialog.EventType.BUY_RUMORS,
		{"cost_each": 2, "max_quantity": 3}))
	tasks._show_next_event_dialog()
	var dialog: Variant = tasks._current_event_dialog
	assert_object(dialog).is_not_null()
	assert_int(int(dialog._buy_max)).is_equal(2)
	dialog.queue_free()


func test_the_arms_dealer_has_no_printed_cap() -> void:
	# p.81 69-71: "Purchase any number of rolls on the Military Weapons Table (p.28)
	# for 3 credits each." The row said "up to 3".
	var tasks := _crew_task(0)
	var tr: Dictionary = tasks._get_exploration_table_result(70)
	assert_str(str(tr.get("name"))).is_equal("Arms dealer")
	var events: Array = tasks._classify_result({"crew_member": _member("human"),
		"table_result": tr}, tr, _member("human"))
	assert_int(events.size()).is_greater(0)
	assert_int(int(events[0].get("type"))).is_equal(CrewTaskEventDialog.EventType.BUY_WEAPONS)
	assert_int(int(events[0].get("max_quantity"))).is_equal(0)


func test_a_precursor_rolls_for_a_second_rumor() -> void:
	# p.80 9-11 "Meet someone interesting: Gain a Quest Rumor. A Precursor character
	# may roll 1D6, and on a 5+ receives a second Rumor."
	var tasks := _crew_task(0)
	var explore: Dictionary = {}
	for t: Dictionary in tasks.available_crew_tasks:
		if t["id"] == "explore":
			explore = t
	assert_dict(explore).is_not_empty()
	var base := {"details": "", "roll": 0, "modified_roll": 0, "success": false, "reward": ""}
	_dm.queue_forced_result("Exploration Table", 10)
	_dm.queue_forced_result("Explore Follow-up", 5)
	var won: Dictionary = tasks._resolve_table_task(base.duplicate(), explore, _member("precursor"))
	assert_str(str(won.table_result.get("name"))).is_equal("Meet someone interesting")
	assert_int(int(won.table_result.get("rumor_count", 1))).is_equal(2)
	assert_str(str(won.table_result.get("effect"))).contains("Precursor rolled 5")
	_dm.queue_forced_result("Exploration Table", 10)
	_dm.queue_forced_result("Explore Follow-up", 4)
	var lost: Dictionary = tasks._resolve_table_task(base.duplicate(), explore, _member("precursor"))
	assert_int(int(lost.table_result.get("rumor_count", 1))).is_equal(1)
	assert_str(str(lost.table_result.get("effect"))).contains("no second Rumor")
	# The two Rumors reach the campaign through the event the result builds.
	var events: Array = tasks._classify_result({"crew_member": _member("precursor"),
		"table_result": won.table_result}, won.table_result, _member("precursor"))
	tasks._on_event_completed({}, events[0])
	assert_int(int(_campaign.quest_rumors)).is_equal(2)


func test_only_a_precursor_rolls_for_the_second_rumor() -> void:
	var tasks := _crew_task(0)
	var explore: Dictionary = {}
	for t: Dictionary in tasks.available_crew_tasks:
		if t["id"] == "explore":
			explore = t
	_dm.queue_forced_result("Exploration Table", 10)
	var base := {"details": "", "roll": 0, "modified_roll": 0, "success": false, "reward": ""}
	var human: Dictionary = tasks._resolve_table_task(base, explore, _member("human"))
	assert_bool(human.table_result.has("rumor_count")).is_false()
	assert_str(str(human.table_result.get("effect"))).not_contains("Precursor rolled")
