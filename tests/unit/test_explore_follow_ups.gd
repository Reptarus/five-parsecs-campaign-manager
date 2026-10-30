extends GdUnitTestSuite
## The Exploration and Trade rows that need the crew member (Core Rules pp.79-81) do what
## their printed text says.
##
## Measured on 2026-10-29 before the fix:
##   - Completely lost rolled a bare 1D6 for its text, rolled again in the dialog with
##     Savvy, and on a failure wrote `misses_battle`, which nothing reads, so the character
##     still fought. The "roll again on this table" never happened;
##   - Tech fanatic told the player a random undamaged item was damaged (picked with a raw
##     randi()), rolled the repair with another, and applied neither. Its Engineer branch
##     tested the class, and the Core Rules have no Engineer class (p.16 species only);
##   - Gambling offered only the character's own gear, where p.81 allows the crew Stash;
##   - a Luxury trinket could not be sold.

const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CTCScript = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const EventDialogScript = preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")
const Events = preload("res://src/core/campaign/DeferredCrewEvents.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "explore_follow_ups_suite"})
	campaign.progress_data["turns_played"] = 3
	campaign.equipment_data = {"equipment": []}
	GameState.current_campaign = campaign


func after_test() -> void:
	for key: String in ["Explore Follow-up", "Trade Table", "Exploration Table"]:
		DiceManager.clear_forced_results(key)
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _ctc(crew: Array = []):
	var c = auto_free(CTCScript.new())
	add_child(c)
	c.crew_data = crew
	return c


func _member(extra: Dictionary = {}) -> Dictionary:
	var m := {"id": "c1", "character_id": "c1", "character_name": "Ana", "savvy": 0,
		"species_id": "human", "origin": "HUMAN", "equipment": [], "status_effects": []}
	m.merge(extra, true)
	return m


func _resolve(comp, task_id: String, member: Dictionary) -> Dictionary:
	var r := {"details": "", "reward": "", "penalty": "", "success": false,
		"roll": 0, "modified_roll": 0}
	return comp._resolve_table_task(r, {"id": task_id}, member)


func _events_for(comp, tr: Dictionary, member: Dictionary) -> Array:
	var base := {"crew_id": "c1", "crew_name": "Ana", "crew_member": member,
		"task_type": "Explore", "event_name": tr.get("name", ""),
		"effect_text": tr.get("effect", ""), "table_result": tr}
	return comp._classify_result(base, tr, member)


func _stash() -> Array:
	return GameState.current_campaign.equipment_data["equipment"]


func test_completely_lost_adds_savvy_misses_the_battle_and_rolls_again() -> void:
	var member := _member({"savvy": 1})
	var comp = _ctc([member])
	DiceManager.queue_forced_result("Exploration Table", 38)
	DiceManager.queue_forced_result("Explore Follow-up", 2)
	DiceManager.queue_forced_result("Exploration Table", 61)
	var r: Dictionary = _resolve(comp, "explore", member)
	var tr: Dictionary = r.table_result
	assert_str(str(tr.name)).is_equal("Completely lost")
	assert_int(int(tr.get("lost_total", 0))).override_failure_message(
		"1D6+Savvy (p.81)").is_equal(3)
	assert_array(GameStateManager.filter_deployable([member])).override_failure_message(
		"a total under 4 keeps them out of this turn's battle").is_empty()
	var wander: Dictionary = tr.get("wandering_result", {})
	assert_str(str(wander.get("name", ""))).override_failure_message(
		"either way, roll again on this table").is_equal("Found a trainer")
	# The re-rolled row is queued as a result of its own.
	comp.completed_tasks = [{"table_result": tr, "crew_id": "c1", "crew_name": "Ana",
		"task_name": "Explore"}]
	comp._build_event_queue()
	var names: Array = []
	for e: Dictionary in comp._event_queue:
		names.append(str(e.get("event_name", "")))
	assert_array(names).contains(["Completely lost", "Found a trainer"])

	var back := _member({"id": "c2", "character_id": "c2", "savvy": 1})
	DiceManager.queue_forced_result("Exploration Table", 38)
	DiceManager.queue_forced_result("Explore Follow-up", 3)
	DiceManager.queue_forced_result("Exploration Table", 1)
	_resolve(comp, "explore", back)
	assert_array(GameStateManager.filter_deployable([back])).override_failure_message(
		"3 + 1 Savvy = 4: back in time").has_size(1)


func test_tech_fanatic_fixes_a_picked_damaged_item_on_a_5_or_6() -> void:
	var member := _member({"status_effects": [
		{"type": "item_damaged", "damaged_item": "Blade"}]})
	_stash().append({"name": "Colony Rifle", "damaged": true})
	var comp = _ctc([member])
	DiceManager.queue_forced_result("Exploration Table", 45)
	DiceManager.queue_forced_result("Explore Follow-up", 5)
	var tr: Dictionary = _resolve(comp, "explore", member).table_result
	assert_bool(bool(tr.get("repair_success", false))).is_true()
	var events: Array = _events_for(comp, tr, member)
	assert_int(int(events[0].type)).is_equal(EventDialogScript.EventType.TECH_FANATIC)
	assert_int((events[0].repair_choices as Array).size()).is_equal(2)
	comp._on_event_completed({"repair_choice": "Colony Rifle (Stash)"}, events[0])
	assert_bool(bool(_stash()[0].get("damaged", true))).override_failure_message(
		"the picked item is fixed").is_false()
	assert_int((member.status_effects as Array).size()).override_failure_message(
		"the one not picked stays damaged").is_equal(1)

	# A 4 fixes nothing and destroys nothing.
	DiceManager.queue_forced_result("Exploration Table", 45)
	DiceManager.queue_forced_result("Explore Follow-up", 4)
	tr = _resolve(comp, "explore", member).table_result
	assert_bool(bool(tr.get("repair_success", true))).is_false()
	comp._apply_tech_fanatic_repair({"table_result": tr}, "")
	assert_int((member.status_effects as Array).size()).is_equal(1)
	assert_int(_stash().size()).is_equal(1)


func test_an_engineer_talks_shop_for_two_xp() -> void:
	var engineer := _member({"species_id": "engineer", "origin": "ENGINEER"})
	var comp = _ctc([engineer])
	DiceManager.queue_forced_result("Exploration Table", 45)
	var tr: Dictionary = _resolve(comp, "explore", engineer).table_result
	var events: Array = _events_for(comp, tr, engineer)
	assert_int(int(events[0].type)).override_failure_message(
		"Engineer is the p.16 species: +2 XP instead").is_equal(
		EventDialogScript.EventType.GAIN_XP)
	assert_int(int(events[0].xp)).is_equal(2)

	var soldier := _member({"id": "c2", "character_id": "c2", "character_class": "ENGINEER"})
	DiceManager.queue_forced_result("Exploration Table", 45)
	tr = _resolve(comp, "explore", soldier).table_result
	assert_bool(bool(tr.get("tech_engineer", false))).override_failure_message(
		"a class value is not the species").is_false()


func test_gambling_can_discard_from_the_stash() -> void:
	var member := _member({"equipment": ["Blade"]})
	_stash().append({"name": "Med-patch"})
	var comp = _ctc([member])
	DiceManager.queue_forced_result("Exploration Table", 51)
	var tr: Dictionary = _resolve(comp, "explore", member).table_result
	var events: Array = _events_for(comp, tr, member)
	assert_int(int(events[0].type)).is_equal(EventDialogScript.EventType.DISCARD_ITEM)
	assert_array(events[0].equipment).contains(["Blade", "Med-patch (Stash)"])
	comp._on_event_completed({"discarded_item": "Med-patch (Stash)"}, events[0])
	assert_int(_stash().size()).is_equal(0)
	assert_array(member.equipment).contains_exactly(["Blade"])


func test_a_luxury_trinket_sells_for_the_better_of_two_trade_rolls() -> void:
	var member := _member()
	var comp = _ctc([member])
	DiceManager.queue_forced_result("Trade Table", 27)
	var tr: Dictionary = _resolve(comp, "trade", member).table_result
	var pd: Dictionary = GameState.current_campaign.progress_data
	assert_int(Events.live(pd, "Luxury trinket", 3).size()).is_equal(1)
	var events: Array = _events_for(comp, tr, member)
	assert_int(int(events[0].type)).is_equal(EventDialogScript.EventType.TRINKET_SALE)

	DiceManager.queue_forced_result("Trade Table", 15)
	DiceManager.queue_forced_result("Trade Table", 23)
	comp._event_queue.clear()
	comp._on_event_completed({"sell": true}, events[0])
	assert_int(Events.live(pd, "Luxury trinket", 3).size()).override_failure_message(
		"selling spends the trinket").is_equal(0)
	var choice: Dictionary = comp._event_queue[0]
	assert_int(int(choice.type)).is_equal(EventDialogScript.EventType.CHOICE_ITEM)
	assert_array(choice.choice_options).contains_exactly(
		["Roll 15: Bits of scrap", "Roll 23: Worthless trinket"])
	comp._event_queue.pop_front()
	comp._on_event_completed({"item_name": "Roll 15: Bits of scrap"}, choice)
	assert_str(str(comp._event_queue[0].get("event_name", ""))).override_failure_message(
		"the chosen row resolves like any Trade result").is_equal("Bits of scrap")

	# Keeping it leaves it held for a Recruit roll.
	DiceManager.queue_forced_result("Trade Table", 27)
	tr = _resolve(comp, "trade", member).table_result
	comp._on_event_completed({"sell": false}, _events_for(comp, tr, member)[0])
	assert_int(Events.live(pd, "Luxury trinket", 3).size()).is_equal(1)


func test_the_dialog_offers_the_sale_and_the_repair_pick() -> void:
	var dialog = auto_free(EventDialogScript.new())
	add_child(dialog)
	dialog.show_event({"type": EventDialogScript.EventType.TRINKET_SALE,
		"event_name": "Luxury trinket", "effect_text": "", "crew_name": "Ana"})
	var labels: Array = []
	for b: Node in dialog.find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	assert_array(labels).contains(["Keep it (+2 to a Recruit roll)",
		"Sell it (roll twice on the Trade Table)"])
	dialog._on_trinket_choice(true)
	assert_bool(bool(dialog._outcome.get("sell", false))).is_true()

	var pick = auto_free(EventDialogScript.new())
	add_child(pick)
	pick.show_event({"type": EventDialogScript.EventType.TECH_FANATIC,
		"event_name": "Tech fanatic", "effect_text": "", "crew_name": "Ana",
		"repair_success": true, "repair_choices": ["Blade (Ana)", "Colony Rifle (Stash)"]})
	labels.clear()
	for b: Node in pick.find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	assert_array(labels).contains(["Blade (Ana)", "Colony Rifle (Stash)"])
