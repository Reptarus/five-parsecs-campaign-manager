extends GdUnitTestSuite

## Step 6 picks the mission AND the sector its Map Location names (pp.64-65, 115-130).
##
## ⚠ Until 2026-10-28 the screen offered every mission with no map. Delve, Rescue, Scout
## Down! and the Pitched Battle were always offered; the three it did grey out said why
## only in a tooltip a phone cannot show; and no sector was ever stamped, so
## PlanetfallMap.apply_mission_factors() got none at Step 12 and every mission's map
## effect did nothing. PlanetfallMap.mission_sites() had no caller at all.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const MissionPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallMissionPanel.gd")
const Normalizer = preload("res://src/core/battle/PlanetfallBattleResultNormalizer.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _missions: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/planetfall/mission_types.json"))
	for m in data.missions:
		_missions[str(m.id)] = m


func after_test() -> void:
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 1
	core.roster = [{"id": "s1", "name": "Vex", "class": "scout", "xp": 0}]
	# Four Investigation Sites, so an Investigation has a choice to make.
	MapScript.generate(core, 6, 6, [2, 2], 4)
	return core


func _investigation_sites(core: Resource) -> Array:
	return MapScript.all_keys(core.map_data).filter(func(k: String) -> bool:
		return bool(MapScript.sector(core.map_data, k).get("investigation", false)))


func _panel(core: Resource) -> Control:
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	return panel


func _text(root: Node) -> String:
	var out: String = ""
	for lbl in root.find_children("*", "Label", true, false):
		out += (lbl as Label).text + "\n"
	return out


func _button(panel: Control, text: String) -> Button:
	for b in panel._list_container.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


## The rule: a mission with no sector its Map Location allows is not offered, and says why.
func test_availability_follows_the_map_location() -> void:
	var core := _core()
	assert_bool(_investigation_sites(core).is_empty()).override_failure_message(
		"premise: the generated map has Investigation Sites").is_false()
	assert_bool(MapScript.mission_availability(core, _missions.investigation).available).is_true()
	var delve: Dictionary = MapScript.mission_availability(core, _missions.delve)
	assert_bool(delve.available).is_false()
	assert_str(str(delve.reason)).is_equal("No Ancient Site has been located (p.130).")
	assert_str(str(MapScript.mission_availability(core, _missions.rescue).reason)) \
		.contains("Scout Discovery")
	assert_str(str(MapScript.mission_availability(core, _missions.skirmish).reason)) \
		.contains("No Tactical Enemy holds a sector")
	assert_bool(MapScript.mission_availability(core, _missions.pitched_battle).available) \
		.override_failure_message("no Attack, no Pitched Battle").is_false()


## p.62 Attack: "Play the Pitched Battle mission this campaign turn."
func test_an_attack_leaves_only_the_pitched_battle() -> void:
	var core := _core()
	core.tactical_enemies = [{"type": {"name": "Krorg Raiders"},
		"occupied_sectors": [MapScript.key(0, 0)]}]
	core.offer_mission("pitched_battle", {"enemy_index": 0, "forced": true})
	var pitched: Dictionary = MapScript.mission_availability(core, _missions.pitched_battle)
	assert_bool(pitched.available).is_true()
	assert_str(str(pitched.sites[0].key)).is_equal(MapScript.home_key(core.map_data))
	var other: Dictionary = MapScript.mission_availability(core, _missions.investigation)
	assert_bool(other.available).is_false()
	assert_str(str(other.reason)).contains("Krorg Raiders").contains("(p.62)")


## A phone has no hover: a greyed mission says why in text, and every mission says what
## it is before it is tapped.
func test_the_list_explains_each_mission() -> void:
	var panel := _panel(_core())
	var delve: Button = _button(panel, "Delve Mission")
	assert_bool(delve.disabled).is_true()
	var text := _text(panel._list_container)
	assert_str(text).contains("No Ancient Site has been located (p.130).")
	assert_str(text).contains(MissionPanel._summary(_missions.scouting))


## An Investigation has several sites: the footer waits for one, and the pick is stamped.
func test_a_mission_with_several_sectors_waits_for_one_and_stamps_it() -> void:
	var core := _core()
	var sites := _investigation_sites(core)
	assert_int(sites.size()).override_failure_message("premise: several sites") \
		.is_greater(1)
	var panel := _panel(core)
	_button(panel, "Investigation Mission").pressed.emit()
	assert_bool(panel.step_status().ready).is_false()
	assert_str(str(panel.step_status().reason)).contains("sector")
	assert_object(panel._site_grid).override_failure_message("no map to pick on").is_not_null()
	panel._site_grid.sector_selected.emit(str(sites[1]))
	assert_bool(panel.step_status().ready).is_true()
	var emitted: Array = []
	panel.phase_completed.connect(func(d: Dictionary) -> void: emitted.append(d))
	panel.complete()
	assert_str(str(emitted[0].selected_mission.sector)).is_equal(str(sites[1]))


## The colony is the Pitched Battle's only sector, so it is picked without asking.
func test_a_mission_with_one_sector_picks_it() -> void:
	var core := _core()
	core.tactical_enemies = [{"type": {"name": "Krorg Raiders"},
		"occupied_sectors": [MapScript.key(0, 0)]}]
	core.offer_mission("pitched_battle", {"enemy_index": 0, "forced": true})
	var panel := _panel(core)
	_button(panel, "Pitched Battle").pressed.emit()
	assert_bool(panel.step_status().ready).is_true()
	var emitted: Array = []
	panel.phase_completed.connect(func(d: Dictionary) -> void: emitted.append(d))
	panel.complete()
	assert_str(str(emitted[0].selected_mission.sector)) \
		.is_equal(MapScript.home_key(core.map_data))
	assert_int(int(emitted[0].selected_mission.site_enemy_index)).is_equal(0)


## The stamped sector reaches Step 12: a won Investigation clears its site (p.116).
func test_the_sector_reaches_the_step_12_map_effects() -> void:
	var core := _core()
	var k: String = str(_investigation_sites(core)[0])
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm.stamp_mission({"id": "investigation", "sector": k})
	pm.set_battle_result({"won": true, "objectives_completed": 1})
	assert_str(str(pm.get_battle_result().get("sector", ""))).is_equal(k)
	pm.resolve_intel_step()
	assert_bool(bool(MapScript.sector(core.map_data, k).get("investigation", false))) \
		.override_failure_message("the won Investigation left its site on the map").is_false()
