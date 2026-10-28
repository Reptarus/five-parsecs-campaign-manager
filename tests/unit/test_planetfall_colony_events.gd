extends GdUnitTestSuite

## Planetfall pp.63-64, Step 5 Colony Events.
##
## Before 2026-10-27 half the table printed its outcome and applied none of it: Colonists
## find recorded no Ancient Sign, Scientific dead end wasted no Research Points, Animal
## migrations and Changing climate conditions erased no entry, the Public relations demand
## kept nobody out, Experimental medicine shortened no recovery, Hostile wildlife never
## charged its Morale, every "select a character" went to roster[0], and the Supply ship
## always took Research Points. Hostile virus charged its Morale -2 twice and re-spread
## from every infected character each round.
##
## The phase manager saves at the end of a turn, so the user:// guard is mandatory.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const ColonyEvents = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallColonyEventsPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.colony_morale = 0
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0},
		{"id": "c2", "name": "Kip", "class": "scientist", "xp": 0}]
	return core


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


## The panel with the event on `roll` rolled and on screen.
func _rolled(core: Resource, roll: int) -> Control:
	var panel: Control = ColonyEvents.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	_force("Planetfall Colony Event", [roll])
	panel.complete()
	return panel


func _press(panel: Control, text: String) -> void:
	for b in panel.find_children("*", "Button", true, false):
		if (b as Button).text == text and not (b as Button).disabled:
			(b as Button).pressed.emit()
			return
	fail("no enabled button '%s'" % text)


func _pick(panel: Control, character_id: String) -> void:
	var pick: OptionButton = panel._choice_pick
	for i in range(pick.item_count):
		if str(pick.get_item_metadata(i)) == character_id:
			pick.select(i)
			return
	fail("%s is not offered" % character_id)


func _offered(panel: Control) -> Array:
	var ids: Array = []
	var pick: OptionButton = panel._choice_pick
	for i in range(pick.item_count):
		if pick.get_item_metadata(i) != null:
			ids.append(str(pick.get_item_metadata(i)))
	return ids


func _xp(core: Resource, id: String) -> int:
	return int(core.get_roster_character_by_id(id).get("xp", 0))


# ── Automatic outcomes ───────────────────────────────────────────────────────────

func test_colonists_find_records_an_ancient_sign() -> void:
	var core := _core()
	_rolled(core, 43)
	assert_int(core.ancient_signs.size()).is_equal(1)


func test_a_scientific_dead_end_wastes_the_next_three_points_from_any_source() -> void:
	var core := _core()
	_rolled(core, 28)
	assert_int(core.research_points_wasted).is_equal(3)
	assert_int(core.earn_research_points(2)).override_failure_message(
		"the first two points earned are wasted").is_equal(0)
	core.research_points_per_turn = 2
	var receipt: Dictionary = core.claim_turn_income("rp")
	assert_int(int(receipt.net)).is_equal(1)
	assert_int(int(receipt.wasted)).is_equal(1)
	assert_int(int(core.research_data.current_rp)).is_equal(1)
	assert_int(core.research_points_wasted).is_equal(0)
	assert_int(core.earn_research_points(2)).override_failure_message(
		"only the next THREE are wasted").is_equal(2)


func test_animal_migrations_erases_a_filled_lifeform_entry() -> void:
	var core := _core()
	core.lifeform_table = [{}, {"name": "A"}, {"name": "B"}, {}, {}, {}, {}, {}, {}, {}]
	_force("Planetfall Erase Lifeform", [1, 3])  # entry 1 is blank: rerolled
	_rolled(core, 73)
	assert_dict(core.lifeform_table[2]).is_empty()
	assert_str(str(core.lifeform_table[1].get("name", ""))).is_equal("A")


func test_changing_climate_erases_a_filled_condition_entry() -> void:
	var core := _core()
	core.condition_table = [{"name": "Fog"}, {}, {}, {}, {"name": "Heat"}, {}, {}, {}, {}, {}]
	_force("Planetfall Erase Condition", [5])
	_rolled(core, 83)
	assert_dict(core.condition_table[4]).is_empty()
	assert_str(str(core.condition_table[0].get("name", ""))).is_equal("Fog")


func test_hostile_virus_charges_morale_once_and_each_victim_spreads_once() -> void:
	var core := _core()
	core.roster.append({"id": "c3", "name": "Vey", "class": "scout"})
	# Initial rolls c1 c2 c3 (only c1 caught), then c1 spreads (1: caught), then the NEW
	# victim spreads to the last one (1: caught). A chain of three only completes if a
	# newly infected character spreads in turn.
	_force("Planetfall Virus Infection", [1, 6, 6, 1, 1])
	_force("Planetfall Virus Recovery", [2, 3, 1])
	_rolled(core, 78)
	assert_int(core.colony_morale).override_failure_message(
		"p.64: Adjust Colony Morale by -2, once").is_equal(-2)
	assert_int(core.sick_bay.size()).override_failure_message(
		"Continue until no more natural 1s are rolled").is_equal(3)
	assert_bool(core.sick_bay.has("c1")).is_true()


# ── Choices go to the character the player picks ─────────────────────────────────

func test_a_public_relations_demand_keeps_the_chosen_character_out_this_turn() -> void:
	var core := _core()
	core.add_to_sick_bay("c1", 2)
	var panel := _rolled(core, 18)
	assert_array(_offered(panel)).override_failure_message(
		"only a Sick Bay character with one turn left may be chosen").is_equal(["c2"])
	_pick(panel, "c2")
	_press(panel, "Keep them out this turn")
	assert_str(core.deployment_block_reason("c2", "pitched_battle")) \
		.override_failure_message("no Pitched Battle exception on p.63").is_equal("PUBLIC RELATIONS")
	assert_int(core.colony_morale).is_equal(0)
	core.sick_bay.clear()
	core.add_to_sick_bay("c1", 1)
	var again := _rolled(core, 18)
	assert_array(_offered(again)).contains(["c1", "c2"])


func test_specialist_training_adds_a_character_or_grants_xp_to_the_one_picked() -> void:
	var core := _core()
	var panel := _rolled(core, 23)
	panel._choice_class.select(2)  # scout
	_press(panel, "Add a new character")
	assert_int(core.roster.size()).is_equal(3)
	assert_str(str(core.roster[2]["class"])).is_equal("scout")
	var xp_panel := _rolled(core, 23)
	_pick(xp_panel, "c2")
	_press(xp_panel, "+3 XP to the selected character")
	assert_int(_xp(core, "c2")).is_equal(3)
	assert_int(_xp(core, "c1")).override_failure_message("it went to roster[0]").is_equal(0)


func test_experimental_medicine_shortens_the_chosen_recovery() -> void:
	var core := _core()
	core.add_to_sick_bay("c2", 3)
	var panel := _rolled(core, 58)
	assert_array(_offered(panel)).is_equal(["c2"])
	_pick(panel, "c2")
	_press(panel, "Apply")
	assert_int(int(core.sick_bay["c2"])).is_equal(1)
	assert_int(core.colony_morale).is_equal(1)
	core.sick_bay["c2"] = 2
	var cured := _rolled(core, 58)
	_pick(cured, "c2")
	_press(cured, "Apply")
	assert_bool(core.sick_bay.has("c2")).override_failure_message(
		"completely recovered: acts normally this turn").is_false()


func test_a_report_on_progress_awards_the_picked_character() -> void:
	var core := _core()
	var panel := _rolled(core, 68)
	_pick(panel, "c2")
	_force("Planetfall Report XP", [4])
	_press(panel, "Award the XP")
	assert_int(_xp(core, "c2")).is_equal(4)
	assert_int(_xp(core, "c1")).is_equal(0)
	assert_int(core.colony_morale).is_equal(1)


func test_the_supply_ship_pays_the_chosen_priority_the_highest_die() -> void:
	var core := _core()
	var grunts: int = core.grunts
	var panel := _rolled(core, 93)
	_force("Planetfall Supply Ship", [2, 5])
	_press(panel, "Build Points priority")
	assert_int(int(core.buildings_data.get("current_bp", 0))).is_equal(5)
	assert_int(int(core.research_data.get("current_rp", 0))).is_equal(2)
	assert_int(core.grunts).is_equal(grunts + 1)


# ── Hostile wildlife is paid at Mission Determination ────────────────────────────

func test_hostile_wildlife_costs_morale_unless_the_mission_is_a_patrol() -> void:
	var core := _core()
	var panel := _rolled(core, 48)
	_press(panel, "Commit to a Patrol Mission")
	assert_int(core.patrol_required_turn).is_equal(int(core.campaign_turn))
	assert_int(core.colony_morale).is_equal(0)

	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.start_new_turn()
	while pm.current_phase != Phase.MISSION_DETERMINATION:
		pm.complete_current_phase({})
	core.patrol_required_turn = int(core.campaign_turn)
	var morale: int = core.colony_morale
	pm.complete_current_phase({"selected_mission": {"id": "hunt"}})
	assert_int(core.colony_morale).is_equal(morale - 2)
	assert_str(str(pm.get_step_receipt("mission_determination").get("lines", [""])[0])) \
		.contains("Colony Morale -2")
	assert_int(core.patrol_required_turn).is_equal(-1)


func test_a_patrol_mission_settles_hostile_wildlife_for_free() -> void:
	var core := _core()
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.start_new_turn()
	while pm.current_phase != Phase.MISSION_DETERMINATION:
		pm.complete_current_phase({})
	core.patrol_required_turn = int(core.campaign_turn)
	var morale: int = core.colony_morale
	pm.complete_current_phase({"selected_mission": {"id": "patrol"}})
	assert_int(core.colony_morale).is_equal(morale)


func test_the_new_colony_event_state_survives_a_save() -> void:
	var core := _core()
	core.research_points_wasted = 2
	core.patrol_required_turn = 4
	core.assign_event_sitout("c2")
	var loaded = CoreScript.new()
	loaded.from_dictionary(core.to_dictionary())
	assert_int(loaded.research_points_wasted).is_equal(2)
	assert_int(loaded.patrol_required_turn).is_equal(4)
	assert_str(str(loaded.event_sitout.get("character_id", ""))).is_equal("c2")
