extends GdUnitTestSuite

## Colony Integrity, repairs and Colony Damage (Planetfall pp.59, 62, 87, 89):
## T2a, T2b/c, and the damage half of Step 11 Morale.
##
## ⚠ Before 2026-10-27:
##   - p.87 repairs restore Integrity up to its MAXIMUM, which buildings raise. No
##     maximum was recorded (every bonus went through adjust_integrity), so repairs
##     stopped at 0 and a colony that had built Integrity could never repair;
##   - the Repairs dialog spent its Raw Materials AND reported them to the phase
##     manager, which spent them again;
##   - a raid applied its damage inside the dialog and reported nothing, so Step 11
##     never charged Morale for it (p.89: -1 per point of Colony Damage).

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const SimpleDialog = preload("res://src/ui/screens/planetfall/panels/PlanetfallSimpleDialog.gd")
const AutoResolve = preload("res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const BuildingSystem = preload("res://src/core/systems/PlanetfallBuildingSystem.gd")
const ColonyEvents = preload("res://src/ui/screens/planetfall/panels/PlanetfallColonyEventsPanel.gd")
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
	return core


func _pm_at(core: Resource, phase: int) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.start_new_turn()
	while pm.current_phase != phase:
		pm.complete_current_phase({})
	return pm


func _panel(script: GDScript, core: Resource, pm: Node, step: String) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.configure(step, pm.current_phase)
	panel.phase_completed.connect(pm.complete_current_phase)
	panel.refresh()
	return panel


## p.87: a bonus raises both the maximum and the current score; a repair stops at
## the maximum. Driven through the building system, the producer a player reaches.
func test_a_built_integrity_bonus_sets_the_score_repairs_return_to() -> void:
	var core := _core()
	BuildingSystem.new()._apply_building_effect(core, {"colony_integrity": 3})
	assert_int(core.max_colony_integrity).is_equal(3)
	core.take_colony_damage(5, false)
	assert_int(core.integrity_damage()).is_equal(5)
	assert_int(core.repair_colony(10)).is_equal(5)
	assert_int(core.colony_integrity).is_equal(3)


func test_the_repairs_step_restores_to_the_maximum_and_charges_raw_materials_once() -> void:
	var core := _core()
	core.raise_integrity(5)
	core.take_colony_damage(3, false)
	core.raw_materials = 5
	core.repair_capacity = 1
	var pm := _pm_at(core, Phase.REPAIRS)
	var dlg := _panel(SimpleDialog, core, pm, "repairs")
	assert_object(dlg._rm_spinner).override_failure_message(
		"premise: Integrity 2 of 5 is damage, so the spinner is offered").is_not_null()
	assert_int(int(dlg._rm_spinner.max_value)) \
		.override_failure_message("3 damage, 1 from the base rate: only 2 units can help") \
		.is_equal(2)
	dlg._rm_spinner.value = 2
	dlg.complete()
	dlg.complete()
	assert_int(core.colony_integrity).is_equal(5)
	assert_int(core.raw_materials) \
		.override_failure_message("two units spent, once") .is_equal(3)


func test_a_raid_costs_morale_when_it_is_taken() -> void:
	var core := _core()
	core.tactical_enemies = [{"name": "Probe Enemy", "occupied_sectors": []}]
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	var morale_before: int = core.colony_morale
	var dlg := _panel(AutoResolve, core, pm, "enemy_activity")
	_dm.queue_forced_result("Planetfall Enemy Activity", 95)
	dlg.complete()
	dlg.complete()
	assert_int(core.colony_integrity) \
		.override_failure_message("p.62 Raid: sectors occupied + 1 = 1 damage") .is_equal(-1)
	assert_int(core.colony_morale - morale_before) \
		.override_failure_message("p.87: Morale drops by the Integrity lost, when it is lost") \
		.is_equal(-1)
	assert_dict(pm.get_morale_inputs()) \
		.override_failure_message("the turn's damage is still recorded for the receipt") \
		.is_equal({"casualties": 0, "colony_damage": 1})


## p.63 Catastrophic malfunction: "1 Colony Damage that cannot be mitigated. Adjust
## Colony Morale by -1." The flag must survive from the event panel to the phase
## manager, and both Morale costs apply: the printed -1 and p.87's -1 for the damage.
func test_an_unmitigable_colony_event_gets_past_the_shield() -> void:
	var core := _core()
	core.colony_damage_mitigation = 1
	var pm := _pm_at(core, Phase.COLONY_EVENTS)
	var morale_before: int = core.colony_morale
	var panel: Control = ColonyEvents.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.phase_completed.connect(pm.complete_current_phase)
	panel.refresh()
	_dm.queue_forced_result("Planetfall Colony Event", 6)
	panel.complete()
	panel.complete()
	assert_int(core.colony_integrity) \
		.override_failure_message("the shield must not stop it").is_equal(-1)
	assert_int(core.colony_morale - morale_before).is_equal(-2)


## p.87: "Reduce the amount of Colony Damage you would have taken by the amount of
## mitigation ... Damage that is mitigated ... does not affect Morale." The Colony
## Shield Network's effect key had no reader, so the building did nothing.
func test_a_shield_network_mitigates_each_instance_and_spares_its_morale() -> void:
	var core := _core()
	BuildingSystem.new()._apply_building_effect(core, {"mitigate_colony_damage": 1})
	var res: Dictionary = core.take_colony_damage(3)
	assert_dict(res).is_equal({"taken": 2, "mitigated": 1})
	assert_int(core.colony_integrity).is_equal(-2)
	assert_int(core.colony_morale) \
		.override_failure_message("only the 2 taken cost Morale").is_equal(-2)
	res = core.take_colony_damage(2, false)
	assert_dict(res) \
		.override_failure_message("\"cannot be mitigated\" bypasses the building") \
		.is_equal({"taken": 2, "mitigated": 0})
