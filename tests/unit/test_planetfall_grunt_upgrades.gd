extends GdUnitTestSuite
## Planetfall Grunt upgrades (p.79): the six rows in the book's words, each available once
## its prerequisite stands, shown in the Armory (with what a locked one needs), carried into
## the battle briefing and Lock and Load, and the Bolstered survival kit applied at Step 9.
##
## ⚠ Before 2026-10-28 the Armory never listed them, no battle screen named them, and the
## kit's one consumer (PlanetfallColonyCrisis.resolve_injury_step) had no test. Two of the
## data descriptions also dropped a clause the table needs (Ammo packs, Sergeant weaponry).

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const ArmoryScript = preload("res://src/core/systems/PlanetfallArmorySystem.gd")
const ResearchScript = preload("res://src/core/systems/PlanetfallResearchSystem.gd")
const Guide = preload("res://src/core/battle/PlanetfallBattleGuide.gd")
const EquipmentPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallEquipmentPanel.gd")
const LockAndLoad = preload("res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const ARMORY := "res://data/planetfall/armory.json"
const GRUNT_DIE := "Planetfall Grunt Casualty"

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


func _core(buildings: Array = [], applications: Array = []) -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 3
	core.grunts = 10
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0}]
	core.buildings_data = {"constructed": buildings.duplicate()}
	core.research_data = {"unlocked_applications": applications.duplicate()}
	return core


func _status(core: Resource) -> Dictionary:
	var out: Dictionary = {}
	for u in ArmoryScript.new().grunt_upgrade_status(core, ResearchScript.new()):
		out[str(u.id)] = u
	return out


func _labels(node: Node) -> String:
	var out: Array[String] = []
	for n in node.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return "\n".join(out)


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


## p.79 prints six upgrades; the two clauses a player needs mid-battle are kept.
func test_the_six_upgrades_carry_the_book_text() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARMORY))
	var by_id: Dictionary = {}
	for u in data.grunt_upgrades:
		by_id[str(u.id)] = u
	assert_int(by_id.size()).is_equal(6)
	assert_str(str(by_id.ammo_packs.description)).contains(
			"The bonus die must be used in the same battle round")
	assert_str(str(by_id.sergeant_weaponry.description)).contains(
			"in addition to their other weapons")
	assert_str(str(by_id.bolstered_survival_kit.description)).contains(
			"only a roll of a 1 is counted as a permanent casualty")


## "become available when their listed prerequisites ... are met" (p.79).
func test_an_upgrade_is_available_only_once_its_prerequisite_stands() -> void:
	var none := _status(_core())
	for id in none:
		assert_bool(bool(none[id].available)).override_failure_message(
			"%s with nothing built or researched" % id).is_false()
	var some := _status(_core(["military_barracks"], ["carver_blade"]))
	assert_bool(bool(some.ammo_packs.available)).is_true()
	assert_bool(bool(some.sergeant_weaponry.available)).is_true()
	assert_bool(bool(some.side_arms.available)).is_false()
	assert_bool(bool(some.adapted_armor.available)).is_false()


func test_the_armory_names_what_a_locked_upgrade_needs() -> void:
	var panel: Control = auto_free(EquipmentPanel.new())
	add_child(panel)
	panel.set_campaign(_core(["early_warning_system"]))
	panel.refresh()
	var shown := _labels(panel)
	assert_str(shown).contains("GRUNT UPGRADES (p.79)")
	assert_str(shown).contains("Sharpshooter Sight: available to every fireteam")
	assert_str(shown).contains("LOCKED: Needs the Military Barracks")
	assert_str(shown).contains(
			"LOCKED: Needs the Immune System Bio-Delineation application")


func test_the_briefing_carries_the_upgrades_when_grunts_deploy() -> void:
	var core := _core(["military_barracks"])
	var heads: Array = Guide.briefing_rows({"grunts_deployed": 4,
			"opposition_type": "tactical"}, core).map(
			func(r: Dictionary) -> String: return str(r.head) + " " + str(r.detail))
	assert_str("\n".join(heads)).contains("Grunt upgrade: Ammo Packs (Planetfall p.79)")
	assert_str("\n".join(heads)).contains("same battle round")
	var without: Array = Guide.briefing_rows({"grunts_deployed": 0,
			"opposition_type": "tactical"}, core).map(
			func(r: Dictionary) -> String: return str(r.head))
	assert_str("\n".join(without)).override_failure_message(
		"no grunts on the table, no grunt upgrades in the briefing").not_contains("Grunt upgrade")


func test_lock_and_load_lists_what_the_fireteams_carry() -> void:
	var panel: Control = auto_free(LockAndLoad.new())
	add_child(panel)
	panel.set_campaign(_core(["locally_adapted_food_production_site"]))
	panel.set_force_limits({"max_characters": 6, "max_grunts": 8, "grunt_fireteams": 2})
	panel.refresh()
	assert_str(_labels(panel)).contains("All grunts receive a 6+ Saving Throw.")


# ── Step 9: the Bolstered survival kit (p.79 against p.66's 1-2) ──────────────────

func _step9(core: Resource, rolls: Array) -> Dictionary:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.stamp_mission({"id": "patrol", "mission_name": "Patrol Mission",
		"opposition_type": "tactical", "enemy_type": "Raiders", "tactical_enemy_index": 0,
		"grunts_deployed": 2, "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": true, "victory": true, "mission_type": "patrol",
		"crew_participants": [core.roster[0].duplicate()], "crew_injuries_data": [],
		"crew_casualties_data": []})
	pm.apply_battle_debrief({"grunt_casualties": rolls.size()})
	_force(GRUNT_DIE, rolls)
	return pm.resolve_injury_step()


func test_the_bolstered_kit_saves_a_grunt_on_a_2_but_not_a_1() -> void:
	var core := _core([], ["immune_bio_delineation"])
	var receipt := _step9(core, [2, 1])
	assert_int(core.grunts).override_failure_message(
		"p.79: only a 1 is a permanent casualty with the kit").is_equal(9)
	assert_str("\n".join(PackedStringArray(receipt.lines))).contains(
			"Bolstered survival kit (p.79)")


func test_without_the_kit_a_2_is_a_lost_grunt() -> void:
	var core := _core()
	_step9(core, [2, 1])
	assert_int(core.grunts).override_failure_message("p.66: a 1-2 is lost").is_equal(8)
