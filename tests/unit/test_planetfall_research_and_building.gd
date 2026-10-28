extends GdUnitTestSuite

## Planetfall Steps 14-15: Research (pp.91-96) and Building (pp.97-104).
##
## ⚠ Until 2026-10-28: a completed THEORY opened every Building in its field, Milestone
## Buildings included, although p.93 says the (Building) APPLICATION allows it and p.98
## lists "prerequisite research applications". BP could go to several Buildings in a turn
## (p.97: one), Raw Materials converted three per PRESS (p.98: three per round), reclaiming
## (p.98) was offered nowhere and kept the Building's standing benefits, the Application
## pick was a raw randi_range, and neither screen said why something was locked.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const BuildingSys = preload("res://src/core/systems/PlanetfallBuildingSystem.gd")
const ResearchSys = preload("res://src/core/systems/PlanetfallResearchSystem.gd")
const PANELS := "res://src/ui/screens/planetfall/panels/"
const BuildingPanel = preload(PANELS + "PlanetfallBuildingPanel.gd")
const ResearchPanel = preload(PANELS + "PlanetfallResearchPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

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
	core.campaign_turn = 3
	core.research_data = {"current_rp": 0, "completed_theories": [],
		"unlocked_applications": [], "theory_progress": {}}
	core.buildings_data = {"current_bp": 0, "constructed": [], "in_progress": {}}
	return core


func _available_ids(core: Resource) -> Array:
	var ids: Array = []
	for b in BuildingSys.new().get_available_buildings(core, ResearchSys.new()):
		ids.append(str(b.get("id", "")))
	return ids


func _texts(root: Node) -> String:
	var out: Array[String] = []
	for n in root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(str(n.text))
	return "\n".join(out)


# ── the rules ─────────────────────────────────────────────────────────────────────

## p.93 "(Building) allows a new building to be constructed": the Theory alone opens
## nothing; its Application opens that one Building.
func test_a_completed_theory_alone_opens_no_building() -> void:
	var core := _core()
	core.research_data.completed_theories = ["advanced_manufacturing"]
	var ids := _available_ids(core)
	assert_bool("damage_containment_centre" in ids).override_failure_message(
		"a completed Theory opened its Building without the Application").is_false()
	assert_bool("orbital_facility" in ids).override_failure_message(
		"a completed Theory opened a Milestone Building without the Application").is_false()
	assert_bool("civilian_market" in ids).override_failure_message(
		"premise: a Building with no prerequisite is offered").is_true()
	core.research_data.unlocked_applications = ["damage_containment_centre"]
	ids = _available_ids(core)
	assert_bool("damage_containment_centre" in ids).is_true()
	assert_bool("orbital_facility" in ids).is_false()


## p.100: the High-tech plant needs "Completed Advanced Manufacturing Plant", and p.93
## lists it as an Advanced Manufacturing Application. Both.
func test_the_high_tech_plant_needs_its_application_and_the_plant() -> void:
	var core := _core()
	core.research_data.completed_theories = ["advanced_manufacturing"]
	core.research_data.unlocked_applications = ["high_tech_manufacturing"]
	assert_bool("high_tech_manufacturing_plant" in _available_ids(core)).is_false()
	core.buildings_data.constructed = ["advanced_manufacturing_plant"]
	assert_bool("high_tech_manufacturing_plant" in _available_ids(core)).is_true()
	core.research_data.unlocked_applications = []
	assert_bool("high_tech_manufacturing_plant" in _available_ids(core)).override_failure_message(
		"the plant alone opened it without the Application").is_false()


## p.97: "You can only put BP towards a single Building per campaign turn."
func test_bp_go_to_one_building_per_turn() -> void:
	var core := _core()
	core.buildings_data.current_bp = 8
	var sys := BuildingSys.new()
	assert_bool(sys.invest_bp(core, "civilian_market", 2).success).is_true()
	assert_bool(sys.invest_bp(core, "civilian_market", 1).success).override_failure_message(
		"more BP into the SAME Building was refused").is_true()
	var second: Dictionary = sys.invest_bp(core, "patrol_base", 2)
	assert_bool(second.success).override_failure_message(
		"BP went to a second Building in one turn").is_false()
	assert_str(str(second.error)).contains("p.97")
	core.campaign_turn += 1
	assert_bool(sys.invest_bp(core, "patrol_base", 2).success).is_true()


## p.98: "up to 3 units converted per round" -- per turn, however many presses.
func test_three_raw_materials_convert_per_turn() -> void:
	var core := _core()
	core.raw_materials = 10
	var sys := BuildingSys.new()
	assert_int(sys.convert_rm_to_bp(core, 2)).is_equal(2)
	assert_int(sys.convert_rm_to_bp(core, 3)).override_failure_message(
		"a second press converted past three this turn").is_equal(1)
	assert_int(sys.convertible_this_turn(core)).is_equal(0)
	assert_int(core.raw_materials).is_equal(7)
	core.campaign_turn += 1
	assert_int(sys.convertible_this_turn(core)).is_equal(3)


## p.98: reclaim "a single building" for half its BP cost, rounded down, in Raw
## Materials. "The building is destroyed": its standing benefit goes with it.
func test_reclaim_once_per_turn_takes_the_standing_benefit() -> void:
	var core := _core()
	core.buildings_data.constructed = ["heavy_construction_site", "patrol_base"]
	core.build_points_per_turn = 2
	var sys := BuildingSys.new()
	var rm_before: int = core.raw_materials
	var result: Dictionary = sys.reclaim_building(core, "heavy_construction_site")
	assert_bool(result.success).is_true()
	assert_int(core.raw_materials - rm_before).is_equal(4)
	assert_int(core.build_points_per_turn).override_failure_message(
		"the destroyed Heavy Construction Site kept paying +1 BP").is_equal(1)
	assert_bool(sys.is_constructed(core, "heavy_construction_site")).is_false()
	assert_bool(sys.reclaim_building(core, "patrol_base").success).override_failure_message(
		"a second Building was reclaimed in one turn").is_false()


## p.93: the Application is picked at random through a die the QA seam can force. Three
## chained picks (D6 of 5, D6 of 4, D3 of 3), so an unforced pick matches by chance 1 in 60.
func test_an_application_is_picked_through_the_forceable_die() -> void:
	var core := _core()
	core.research_data.completed_theories = ["advanced_manufacturing"]
	core.research_data.current_rp = 9
	var sys := ResearchSys.new()
	assert_int(sys.get_available_applications(core, "advanced_manufacturing").size()) \
		.override_failure_message("premise: five Applications").is_equal(5)
	for forced in [2, 4, 1]:
		var pool: Array = sys.get_available_applications(core, "advanced_manufacturing")
		_dm.queue_forced_result(ResearchSys.APPLICATION_DIE, forced)
		var result: Dictionary = sys.research_application(core, "advanced_manufacturing")
		assert_bool(result.success).is_true()
		assert_str(str(result.application.id)).override_failure_message(
			"a forced %d did not pick Application %d of %d" % [forced, forced, pool.size()]) \
			.is_equal(str(pool[forced - 1].id))


# ── the screens ───────────────────────────────────────────────────────────────────

func _mount(script: GDScript, core: Resource) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	return panel


## A locked Building is listed with what it waits for; it used to be absent.
func test_a_locked_building_says_what_it_needs() -> void:
	var panel := _mount(BuildingPanel, _core())
	var text := _texts(panel)
	assert_str(text).contains("LOCKED (")
	assert_str(text).contains(
		"Needs the Damage Containment Centre Application (Advanced Manufacturing research")
	assert_str(text).contains("Needs the High Tech Manufacturing Plant Application")


## The Building step's conversion row wraps on a phone (as an HBox its button ran off the
## edge), its ceiling is what is left this turn, and Reclaim asks twice.
func test_the_building_screen_converts_and_reclaims_within_the_rules() -> void:
	var core := _core()
	core.raw_materials = 5
	core.buildings_data.constructed = ["heavy_construction_site"]
	var panel := _mount(BuildingPanel, core)
	assert_object(panel._convert_btn.get_parent()).is_instanceof(HFlowContainer)
	assert_float(panel._rm_spinner.max_value).is_equal(3.0)
	panel._rm_spinner.value = 2
	panel._on_convert_pressed()
	assert_float(panel._rm_spinner.max_value).override_failure_message(
		"the spinner offered three again after two were converted").is_equal(1.0)
	panel._on_building_selected("heavy_construction_site")
	panel._on_reclaim_pressed("heavy_construction_site")
	assert_bool(BuildingSys.new().is_constructed(core, "heavy_construction_site")) \
		.override_failure_message("one press destroyed the Building").is_true()
	assert_str(_texts(panel._detail_container)).contains("Confirm: destroy")
	panel._on_reclaim_pressed("heavy_construction_site")
	assert_bool(BuildingSys.new().is_constructed(core, "heavy_construction_site")).is_false()


## A locked Theory names its prerequisite (p.92); it read "[LOCKED]".
func test_a_locked_theory_names_its_prerequisite() -> void:
	var panel := _mount(ResearchPanel, _core())
	assert_str(_texts(panel)).contains("Research Infantry Equipment first (p.92).")


## An Application's effect is the entry's own effect, in p.93's words.
func test_an_application_shows_what_it_does() -> void:
	var panel := _mount(ResearchPanel, _core())
	assert_str(panel.application_effect_text({"type": "bonus",
		"effect": {"colony_integrity": 1}})).is_equal("+1 to Colony Integrity.")
	assert_str(panel.application_effect_text({"type": "bonus",
		"effect": {"research_points_per_turn": 1}})) \
		.is_equal("Increase per campaign turn RP by +1.")
	assert_str(panel.application_effect_text({"type": "milestone"})) \
		.is_equal("Grants a Milestone (p.156).")
	assert_str(panel.application_effect_text({"type": "weapon",
		"unlocks_weapon": "handgun"})).contains("6\" · 1 shot · Dmg +0")


## The detail pane says what it is for before anything is picked; it opened empty.
func test_the_detail_pane_says_what_to_pick() -> void:
	assert_str(_texts(_mount(BuildingPanel, _core())._detail_container)) \
		.contains("Pick a Building")
	assert_str(_texts(_mount(ResearchPanel, _core())._detail_container)) \
		.contains("Pick a Theory")


## Both screens stack their list over the detail on a phone and re-fit on rotation.
func test_both_screens_stack_on_a_phone() -> void:
	var rm: Node = get_tree().root.get_node_or_null("/root/ResponsiveManager")
	var narrow: bool = rm.should_collapse_to_single_column()
	for script in [BuildingPanel, ResearchPanel]:
		var panel := _mount(script, _core())
		assert_bool(panel._columns.vertical).override_failure_message(
			"%s did not follow the layout class" % script.resource_path).is_equal(narrow)
		panel._columns.vertical = not narrow
		rm.emit_current_layout_class()
		assert_bool(panel._columns.vertical).override_failure_message(
			"%s ignored a layout change" % script.resource_path).is_equal(narrow)
