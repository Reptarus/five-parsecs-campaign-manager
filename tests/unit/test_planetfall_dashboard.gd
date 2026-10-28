extends GdUnitTestSuite

## The Planetfall Dashboard shows the colony as the Colony Tracking Sheet records it (p.24).
##
## ⚠ Until 2026-10-28 it was a self-declared "TODO": no Raw Materials, Build, Research or
## Augmentation Points, no colony map, an enemy card that only counted enemies, roster
## cards reading "R:1 Spd:5 CS:0" with no hint why a score was raised, and every card
## stretched edge to edge across a tablet in a single column with no side margin.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const DashboardScene = preload("res://src/ui/screens/planetfall/PlanetfallDashboard.tscn")
const DashboardScript = preload("res://src/ui/screens/planetfall/PlanetfallDashboard.gd")
const ScreenBase = preload("res://src/ui/screens/planetfall/PlanetfallScreenBase.gd")
const SectorGridScript = preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const HubCardScript = preload("res://src/ui/components/common/HubFeatureCard.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _saved_campaign: Variant


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


## A colony with every pool non-zero and distinct, one enemy on the map, and a Scientist
## whose Explorer career raised Speed 4 to 5 (pp.18, 22).
func _core() -> Resource:
	var core = CoreScript.new()
	core.campaign_name = "Haven"
	core.colony_name = "Haven"
	core.game_phase = "active"
	core.campaign_turn = 2
	core.raw_materials = 3
	core.buildings_data["current_bp"] = 4
	core.research_data["current_rp"] = 5
	core.augmentation_points = 6
	MapScript.generate(core, 6, 6, [2, 2], 0)
	core.tactical_enemies = [{"type": {"name": "Krorg Raiders"},
		"occupied_sectors": [MapScript.key(0, 0)]}]
	core.enemy_info = {"0": 2}
	core.roster = [{"id": "a", "name": "Ada Voss", "class": "scientist", "reactions": 1,
		"speed": 5, "combat_skill": 0, "toughness": 3, "savvy": 1, "xp": 0, "kp": 0,
		"loyalty": "committed", "motivation": "Loyalty", "prior_experience": "Explorer",
		"notable_event": "Went missing"}]
	return core


func _screen(core: Resource) -> Control:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var dash: Control = DashboardScene.instantiate()
	add_child(dash)
	auto_free(dash)
	await get_tree().process_frame
	await get_tree().process_frame
	return dash


func _text(root: Node) -> String:
	var out: String = ""
	for lbl in root.find_children("*", "Label", true, false):
		if (lbl as Label).is_visible_in_tree():
			out += (lbl as Label).text + "\n"
	return out


## One reader for the colony's numbers; the turn strip and the dashboard both use it.
func test_colony_stats_reads_every_pool() -> void:
	var stats: Dictionary = ScreenBase.colony_stats(_core())
	assert_int(int(stats.RM[2])).is_equal(3)
	assert_int(int(stats.BP[2])).is_equal(4)
	assert_int(int(stats.RP[2])).is_equal(5)
	assert_int(int(stats.AP[2])).is_equal(6)
	for key in ScreenBase.COLONY_STAT_ORDER:
		assert_bool(stats.has(key)).override_failure_message("missing %s" % key).is_true()


func test_the_dashboard_shows_every_colony_number() -> void:
	var dash: Control = await _screen(_core())
	var text: String = _text(dash).to_lower()
	for name in ["raw materials", "build points", "research points", "augmentation points",
			"story points", "colony morale", "colony integrity"]:
		assert_str(text).override_failure_message("no %s on the dashboard" % name) \
			.contains(name)


func test_the_dashboard_shows_the_map_and_each_enemy() -> void:
	var dash: Control = await _screen(_core())
	var grids: Array = dash.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.get_script() == SectorGridScript)
	assert_int(grids.size()).override_failure_message("no colony map").is_equal(1)
	assert_str(_text(dash)).contains(
		"Krorg Raiders: holds 1 sector, Enemy Information 2.")


func test_an_enemy_line_names_a_located_strongpoint_and_a_defeat() -> void:
	var core := _core()
	core.tactical_enemies[0]["strongpoint_located"] = true
	core.tactical_enemies[0]["strongpoint_sector"] = MapScript.key(0, 0)
	assert_str(DashboardScript.enemy_summary(core, 0)) \
		.contains("Strongpoint located at %s" % MapScript.label(MapScript.key(0, 0)))
	core.tactical_enemies[0]["defeated"] = true
	assert_str(DashboardScript.enemy_summary(core, 0)).is_equal("Krorg Raiders: defeated.")


## The Enemy Tracker reads the same stores the dashboard line does. It printed the whole
## `type` Dictionary as the enemy's name, read the per-enemy `enemy_info` field nothing
## writes (so "Enemy Information: 0 / 6" for ever), only counted the sectors held, and
## said enemies arrive at "Milestones 1, 2, and 5" where p.50 and the table say 1-3.
func test_the_enemy_tracker_reads_the_live_stores() -> void:
	var core := _core()
	core.tactical_enemies[0]["enemy_info"] = 0
	core.tactical_enemies[0]["boss_located"] = true
	core.tactical_enemies[0]["boss_sector"] = MapScript.key(0, 0)
	var panel: Control = load(
		"res://src/ui/screens/planetfall/panels/PlanetfallEnemyTrackerPanel.gd").new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	var text: String = _text(panel)
	for rt in panel.find_children("*", "RichTextLabel", true, false):
		text += (rt as RichTextLabel).text + "\n"
	var at: String = MapScript.label(MapScript.key(0, 0))
	assert_str(text).contains("Enemy 1: Krorg Raiders\n")
	assert_str(text).override_failure_message("read the dead per-enemy field") \
		.contains("Enemy Information: 2 / 6")
	assert_str(text).contains("Holds 1 sector: %s" % at)
	assert_str(text).contains("Boss: tracked down in %s" % at)
	assert_str(text).contains("Strongpoint: not located")
	assert_str(text).override_failure_message("arrivals are not the table's") \
		.contains("Milestones 1, 2 and 3 (p.50)")


## The raised Speed explains itself, and the profile is the full one, not "Spd:5".
func test_a_roster_card_names_the_bonus_behind_a_raised_score() -> void:
	var text: String = _text(await _screen(_core()))
	assert_str(text).contains("Reactions 1 · Speed 5\" · Combat +0 · Toughness 3 · Savvy +1")
	assert_str(text).contains("Prior Experience: Explorer (+1 Speed)")


func test_continue_says_where_the_turn_was_left() -> void:
	var core := _core()
	core.record_turn_phase(Phase.RESEARCH, {})
	assert_str(_text(await _screen(core))).contains("Resume turn 2 at Step 14")


## A colony founded but never played says so, instead of "Campaign turn 0".
func test_a_fresh_colony_does_not_read_turn_zero() -> void:
	var core := _core()
	core.campaign_turn = 0
	var text: String = _text(await _screen(core))
	assert_str(text).not_contains("Campaign turn 0")
	assert_str(text).contains("no turn played yet")


## The stat tiles share the column instead of clumping at their minimum on the left.
func test_the_stat_tiles_fill_the_column() -> void:
	var dash: Control = await _screen(_core())
	var grids: Array = dash.find_children("*", "GridContainer", true, false).filter(
		func(g: Node) -> bool: return _text(g).contains("RAW MATERIALS"))
	assert_int(grids.size()).override_failure_message("premise: the stats grid").is_equal(1)
	for tile in (grids[0] as Node).get_children():
		assert_int((tile as Control).size_flags_horizontal & Control.SIZE_EXPAND) \
			.override_failure_message("a stat tile does not expand").is_not_equal(0)


## A centred column with a gutter, and a card grid that is one column only on a phone.
func test_the_page_has_a_gutter_and_columns_on_a_tablet() -> void:
	var dash: Control = await _screen(_core())
	assert_int(dash._scroll_margin.get_theme_constant("margin_left")) \
		.is_greater_equal(ScreenBase.SPACING_MD)
	var hubs: Array = dash.find_children("*", "GridContainer", true, false).filter(
		func(g: Node) -> bool: return g.get_child_count() > 0 \
				and g.get_child(0).get_script() == HubCardScript)
	assert_int(hubs.size()).override_failure_message("premise: the hub grid").is_equal(1)
	assert_int((hubs[0] as GridContainer).columns).is_equal(1 if dash._is_narrow() else 3)
