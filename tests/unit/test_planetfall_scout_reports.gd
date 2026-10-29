extends GdUnitTestSuite

## Planetfall Step 3, Scout Reports (pp.59-61): one Scout Explore on a sector the rules
## allow, an optional D100 Scout Discovery, then Process Enemy Information. Every part
## is resolved by the phase manager, recorded the moment it happens, and shown on the map.
##
## ⚠ Until 2026-10-28 the Scout Reports screen rolled its own dice, showed no map, told
## the player to "mark these values on your colony map" and wrote nothing, and it carried
## its own copy of the Discovery table whose results were never applied. No suite
## touched Step 3, so none of that was visible.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const PanelScript = preload("res://src/ui/screens/planetfall/panels/PlanetfallScoutReportsPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

## Phone portrait in design px (CLAUDE.md: the square-1080 base gives a 393 dp phone a
## 338.79 px column).
const PHONE_DESIGN_WIDTH := 338.0

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


## A 6 x 6 map with the colony at R3 C3 and no Investigation Sites, so nothing on it is
## random, and one scout on the roster.
func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.roster = [{"id": "s1", "name": "Vex", "class": "scout", "xp": 0},
		{"id": "t1", "name": "Ash", "class": "trooper", "xp": 0}]
	MapScript.generate(core, 6, 6, [2, 2], 0)
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _force(context: String, values: Array) -> void:
	assert_object(_dm).is_not_null()
	for v in values:
		_dm.queue_forced_result(context, int(v))


## Explore Resource rolls 3 and 5 (lowest 3), Hazard 4 and 2 (lowest 2). No doubles, so
## no Ancient Sign.
func _force_explore() -> void:
	_force(MapScript.EXPLORE_RESOURCE_DIE, [3, 5])
	_force(MapScript.EXPLORE_HAZARD_DIE, [4, 2])


func _add_enemy(core: Resource, at: String, info: int) -> void:
	core.tactical_enemies.append({"name": "Raiders"})
	MapScript.occupy(core, core.tactical_enemies.size() - 1, at)
	if info > 0:
		core.increment_enemy_info(core.tactical_enemies.size() - 1, info)


# ── 1. Scout Explore (p.60) ──────────────────────────────────────────────────────

func test_explore_writes_the_sector_onto_the_map() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	var s: Dictionary = MapScript.sector(core.map_data, "0,0")
	assert_str(MapScript.status(core.map_data, "0,0")).is_equal("explored")
	assert_int(int(s.get("resource", -1))).is_equal(3)
	assert_int(int(s.get("hazard", -1))).is_equal(2)


func test_one_scout_explore_per_turn() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force_explore()
	pm.scout_explore("0,1")
	assert_str(MapScript.status(core.map_data, "0,1")).is_equal("unexplored")
	assert_str(str(pm.scout_receipt().get("explore", {}).get("sector", ""))).is_equal("0,0")


func test_an_enemy_held_sector_cannot_be_explored() -> void:
	var core := _core()
	_add_enemy(core, "1,1", 0)
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("1,1")
	assert_str(MapScript.status(core.map_data, "1,1")).is_equal("unexplored")
	assert_bool(pm.scout_receipt().has("explore")).is_false()
	# The refusal spends nothing: the turn's explore is still available elsewhere.
	pm.scout_explore("0,0")
	assert_str(MapScript.status(core.map_data, "0,0")).is_equal("explored")


# ── 2. Scout Discovery (p.59) ────────────────────────────────────────────────────

func test_good_practice_pays_the_assigned_scout() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.DISCOVERY_DIE, [15])
	var record: Dictionary = pm.scout_discovery_roll("s1")
	assert_str(str(record.get("choice", "x"))).is_equal("")
	pm.scout_discovery_apply()
	assert_int(int(core.get_roster_character_by_id("s1").get("xp", 0))).is_equal(2)


func test_discovery_rolls_once_and_a_resume_keeps_the_roll() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.DISCOVERY_DIE, [15])
	pm.scout_discovery_roll("s1")
	# A second press, then a relaunch: the same roll comes back and no die is spent.
	_force(MapScript.DISCOVERY_DIE, [5])
	pm.scout_discovery_roll("s1")
	var copy = CoreScript.new()
	copy.from_dictionary(core.to_dictionary())
	var pm2 := _pm(copy)
	pm2.restore_from_campaign()
	var entry: Dictionary = pm2.scout_receipt().get("discovery", {}).get("entry", {})
	assert_int(int(entry.get("roll", 0))).is_equal(15)
	pm2.scout_discovery_roll("s1")
	var left: Array = _dm.get_forced_results().get(MapScript.DISCOVERY_DIE.to_lower(), [])
	assert_int(left.size()).is_equal(1)


func test_an_exploration_report_explores_the_picked_sector() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.DISCOVERY_DIE, [45])
	var record: Dictionary = pm.scout_discovery_roll("")
	assert_str(str(record.get("choice", ""))).is_equal("sector")
	_force_explore()
	pm.scout_discovery_apply({"sector": "5,5"})
	assert_str(MapScript.status(core.map_data, "5,5")).is_equal("explored")


# ── 3. Process Enemy Information (pp.60-61) ──────────────────────────────────────

func test_a_roll_at_or_under_the_count_tracks_the_boss() -> void:
	var core := _core()
	_add_enemy(core, "4,4", 3)
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.ENEMY_INFO_DIE, [3])
	pm.scout_enemy_information()
	var e: Dictionary = core.tactical_enemies[0]
	assert_bool(bool(e.get("boss_located", false))).is_true()
	assert_str(str(e.get("boss_sector", ""))).is_equal("4,4")


func test_a_roll_over_the_count_does_not_track_the_boss() -> void:
	var core := _core()
	_add_enemy(core, "4,4", 3)
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.ENEMY_INFO_DIE, [4])
	pm.scout_enemy_information()
	assert_bool(bool(core.tactical_enemies[0].get("boss_located", false))).is_false()


func test_a_discovery_left_unanswered_is_applied_before_enemy_information() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.DISCOVERY_DIE, [45])
	pm.scout_discovery_roll("")
	_force_explore()
	pm.scout_enemy_information()
	assert_bool(bool(pm.scout_receipt().get("discovery", {}).get("applied", false))).is_true()


# ── The screen ───────────────────────────────────────────────────────────────────

func _panel(core: Resource, pm: Node) -> Control:
	var panel: Control = PanelScript.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.refresh()
	return panel


func _buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return not b.is_queued_for_deletion())


func test_tapping_a_sector_and_explore_writes_the_map() -> void:
	var core := _core()
	var pm := _pm(core)
	var panel := _panel(core, pm)
	var cell: Button = null
	for b in _buttons(panel):
		if (b as Button).tooltip_text.begins_with("R1 C1:"):
			cell = b
	assert_object(cell).is_not_null()
	cell.pressed.emit()
	var explore: Button = null
	for b in _buttons(panel):
		if (b as Button).text == "Explore R1 C1":
			explore = b
	assert_object(explore).is_not_null()
	_force_explore()
	explore.pressed.emit()
	assert_str(MapScript.status(core.map_data, "0,0")).is_equal("explored")


func test_the_page_fits_a_phone_with_the_longest_choice_on_screen() -> void:
	var core := _core()
	var pm := _pm(core)
	_force_explore()
	pm.scout_explore("0,0")
	_force(MapScript.DISCOVERY_DIE, [28])
	assert_str(str(pm.scout_discovery_roll("s1").get("choice", ""))).is_equal("scout_down")
	var panel := _panel(core, pm)
	# A theme override refreshes the minimum-size cache a frame later (CLAUDE.md).
	await get_tree().process_frame
	await get_tree().process_frame
	var page: Control = (panel.get_child(0) as ScrollContainer).get_child(0)
	var found: bool = false
	for b in _buttons(panel):
		if (b as Button).text.begins_with("Escape on foot"):
			found = true
	assert_bool(found).is_true()
	assert_float(page.get_combined_minimum_size().x).is_less_equal(PHONE_DESIGN_WIDTH)


## p.52 allows a 10 x 10 map, ~454 px of cells against a ~340 px phone column. The map
## scrolls sideways inside its own width instead of widening the page.
func test_a_ten_by_ten_map_does_not_widen_the_page() -> void:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	MapScript.generate(core, 10, 10, [4, 4], 0)
	var pm := _pm(core)
	var panel := _panel(core, pm)
	await get_tree().process_frame
	await get_tree().process_frame
	var page: Control = (panel.get_child(0) as ScrollContainer).get_child(0)
	assert_float(page.get_combined_minimum_size().x).is_less_equal(PHONE_DESIGN_WIDTH)
