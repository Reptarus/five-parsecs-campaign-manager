extends GdUnitTestSuite
## Planetfall Step 4, Enemy Activity (p.62), on the map. The D100 row is resolved by the
## step; what it DOES to the campaign is PlanetfallMap.apply_enemy_activity(), reached
## through PlanetfallPhaseManager.resolve_enemy_activity().
##
## ⚠ Before 2026-10-28 Step 4 applied a Raid alone, from its own copy of the p.62 damage
## rule, and Patrol, Relocate, Occupy, Rapid Expansion and Attack changed nothing: the
## map's handler was complete and had no caller. So no Patrol ever offered its Strike, no
## enemy ever spread across the map, and no Attack ever forced the Pitched Battle.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const AutoResolve = preload("res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase
const MISSIONS := "res://data/planetfall/mission_types.json"
const ACTIVITY_DIE := "Planetfall Enemy Activity"
const CORNER := "0,0"

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


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 3
	core.grunts = 10
	core.colony_morale = 0
	core.colony_damage_mitigation = 0
	core.turn_damage_mitigation = 0
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0}]
	MapScript.generate(core, 6, 6, [2, 2], 4)
	core.tactical_enemies = [{"type": {"name": "Krorg Raiders"},
			"occupied_sectors": [CORNER]}]
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _mission(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS))
	for m in data.get("missions", []):
		if m is Dictionary and str(m.get("id", "")) == id:
			return (m as Dictionary).duplicate(true)
	return {}


## The step as the turn runs it: the D100 forced, Resolve, then the footer's Continue.
func _step_4(core: Resource, roll: int) -> Node:
	var pm := _pm(core)
	pm.start_new_turn()
	while pm.current_phase != Phase.ENEMY_ACTIVITY:
		pm.complete_current_phase({})
	var dlg: Control = auto_free(AutoResolve.new())
	add_child(dlg)
	dlg.set_campaign(core)
	dlg.set_phase_manager(pm)
	dlg.configure("enemy_activity", pm.current_phase)
	dlg.phase_completed.connect(pm.complete_current_phase)
	dlg.refresh()
	_dm.queue_forced_result(ACTIVITY_DIE, roll)
	dlg.complete()
	dlg.complete()
	return pm


## p.62 01-25 Patrol: "You may play a Strike Mission this turn" against that enemy.
func test_a_patrol_offers_this_turns_strike_from_the_step() -> void:
	var core := _core()
	_step_4(core, 10)
	assert_int(int(core.get_mission_offer("strike").get("enemy_index", -1))) \
		.override_failure_message("Step 4's Patrol offered no Strike").is_equal(0)


## p.62 36-65 Occupy: "The enemy expands into a random adjacent sector".
func test_occupy_takes_an_adjacent_sector() -> void:
	var core := _core()
	_step_4(core, 50)
	var held: Array = MapScript.held_by(core, 0)
	assert_int(held.size()).is_equal(2)
	assert_bool(held.has(CORNER)).is_true()


## p.62 66-75 Rapid Expansion: "two adjacent sectors are occupied".
func test_rapid_expansion_takes_two() -> void:
	var core := _core()
	_pm(core).resolve_enemy_activity(0, "rapid_expansion")
	assert_int(MapScript.held_by(core, 0).size()).is_equal(3)


## p.62 26-35 Relocate: "They move to a random adjacent unoccupied sector."
func test_relocate_moves_the_enemy_off_its_sector() -> void:
	var core := _core()
	_pm(core).resolve_enemy_activity(0, "relocate")
	var held: Array = MapScript.held_by(core, 0)
	assert_int(held.size()).is_equal(1)
	assert_bool(held.has(CORNER)).override_failure_message("the enemy did not move") \
		.is_false()


## p.62 76-90 Attack: "Play the Pitched Battle mission this turn."
func test_an_attack_forces_the_pitched_battle() -> void:
	var core := _core()
	_step_4(core, 80)
	var patrol: Dictionary = MapScript.mission_availability(core, _mission("patrol"))
	assert_bool(bool(patrol.available)).is_false()
	assert_str(str(patrol.reason)).contains("is attacking the colony")
	assert_bool(bool(MapScript.mission_availability(core,
			_mission("pitched_battle")).available)).is_true()


## p.62 Raid: "Colony Damage equal to the number of map sectors this enemy occupies +1
## ... Every die rolling a 4+ negates a point of damage."
func test_a_raid_is_priced_by_the_map_less_defenses() -> void:
	var core := _core()
	core.colony_defenses = 2
	_dm.queue_forced_result("Planetfall Colony Defenses", 4)
	_dm.queue_forced_result("Planetfall Colony Defenses", 1)
	var r: Dictionary = _pm(core).resolve_enemy_activity(0, "raid")
	assert_int(int(r.colony_damage)).is_equal(1)
	assert_str("\n".join(PackedStringArray(r.lines))).contains("1 mitigated by defenses")
