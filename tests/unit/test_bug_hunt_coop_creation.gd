extends GdUnitTestSuite

## Creating a Bug Hunt co-op campaign, Compendium pp.209-210, through the real wizard.
##
## p.210: "As a guideline, try 3 sectors per player for a shorter campaign, up to 5 for a
## longer campaign." The wizard collects the players and the sectors per player; the
## coordinator hands them to BugHuntCampaignCore.start_coop_campaign() at Launch, which
## rolls the map. A non-co-op campaign must come out of the same coordinator untouched.
##
## gdUnit4 v6.0.3. build_campaign() registers the campaign with GameState and the map
## rolls through /root/DiceManager, so both are restored after every case.

const ConfigPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntConfigPanel.gd")
const ReviewPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntReviewPanel.gd")
const Coordinator = preload("res://src/ui/screens/bug_hunt/BugHuntCreationCoordinator.gd")
const CoopView = preload("res://src/ui/screens/bug_hunt/BugHuntCoopView.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const CREATION_SCENE := "res://src/ui/screens/bug_hunt/BugHuntCreationUI.tscn"
const DATA_PATH := "res://data/bug_hunt/bug_hunt_coop_campaign.json"

var _dm: Node = null
var _user_state: Dictionary
var _saved_campaign: Variant = null
var _saved_contexts: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	if _dm:
		_dm.clear_forced_results()
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	var router: Node = get_tree().root.get_node_or_null("/root/SceneRouter")
	_saved_contexts = (router.scene_contexts as Dictionary).duplicate(true) if router else {}


func after_test() -> void:
	if _dm:
		_dm.clear_forced_results()
	var router: Node = get_tree().root.get_node_or_null("/root/SceneRouter")
	if router:
		router.scene_contexts = _saved_contexts
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _per_player_range() -> Vector2i:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var per: Dictionary = data.get("sectors_per_player", {})
	return Vector2i(int(per.get("shorter", -1)), int(per.get("longer", -1)))


func _config(players: Array, per: int) -> Dictionary:
	return {"campaign_name": "Coop C", "regiment_name": "", "uniform_color": "",
		"difficulty": "mess_me_up", "use_campaign_escalation": false,
		"coop_enabled": true, "coop_players": players, "coop_sectors_per_player": per}


func _squad() -> Dictionary:
	return preload("res://src/core/character/BugHuntCharacterGeneration.gd").new() \
		.generate_squad([], 3)


# ── The config step ──────────────────────────────────────────────────────────────

func test_the_config_step_offers_the_books_sector_range() -> void:
	var span := _per_player_range()
	assert_int(span.x).override_failure_message("the data has no shorter count").is_equal(3)
	assert_int(span.y).is_equal(5)
	var panel: Control = ConfigPanel.new()
	add_child(panel)
	auto_free(panel)
	var updates: Array = []
	panel.config_updated.connect(func(d: Dictionary) -> void: updates.append(d))
	assert_bool(panel._coop_body.visible).is_false()
	panel._coop_check.button_pressed = true
	assert_bool(panel._coop_body.visible).is_true()
	var ids: Array = []
	for i in panel._coop_per_option.item_count:
		ids.append(panel._coop_per_option.get_item_id(i))
	assert_array(ids).is_equal([span.x, span.x + 1, span.y])
	# Co-op takes every Priority from the map (p.211), so escalation is switched off.
	assert_bool(panel._escalation_check.disabled).is_true()
	var last: Dictionary = updates.back()
	assert_bool(bool(last.get("coop_enabled", false))).is_true()
	assert_int(int(last.get("coop_sectors_per_player", 0))).is_equal(span.x)


func test_coop_config_errors_name_the_problem() -> void:
	assert_str(CoopView.coop_config_error({"coop_enabled": false})).is_empty()
	assert_str(CoopView.coop_config_error(_config([], 3))).contains("at least one player")
	assert_str(CoopView.coop_config_error(_config(["Ash", "  "], 3))).contains("blank")
	assert_str(CoopView.coop_config_error(_config(["Ash", "ash"], 3))).contains("both named")
	assert_str(CoopView.coop_config_error(_config(["Ash"], 2))).contains("3-5")
	assert_str(CoopView.coop_config_error(_config(["Ash"], 6))).contains("3-5")
	assert_str(CoopView.coop_config_error(_config(["Ash", "Bryn"], 4))).is_empty()


func test_a_half_filled_coop_setup_holds_the_config_step() -> void:
	var coord: Node = Coordinator.new()
	add_child(coord)
	auto_free(coord)
	var nav: Array = []
	coord.navigation_updated.connect(func(b: bool, f: bool, fin: bool) -> void:
		nav.append([b, f, fin])
	)
	coord.update_config(_config(["Ash", ""], 3))
	assert_bool(bool(nav.back()[1])).override_failure_message(
		"Next was offered with a blank player row").is_false()
	coord.update_config(_config(["Ash", "Bryn"], 3))
	assert_bool(bool(nav.back()[1])).is_true()
	# The control: a campaign that is not co-op advances on its name alone, as before.
	coord.update_config({"coop_enabled": false, "coop_players": ["", ""]})
	assert_bool(bool(nav.back()[1])).is_true()


# ── Launch ───────────────────────────────────────────────────────────────────────

func test_launch_rolls_the_map_through_the_core_once() -> void:
	var coord: Node = Coordinator.new()
	add_child(coord)
	auto_free(coord)
	var campaign = coord.build_campaign({"config": _config([" Ash ", "Bryn"], 4),
		"squad": _squad(), "equipment": {}})
	assert_bool(campaign.is_coop()).is_true()
	assert_array(campaign.coop.players).is_equal(["Ash", "Bryn"])
	assert_int((campaign.coop.sectors as Array).size()).is_equal(8)
	assert_bool(bool(coord.coop_setup_receipt.get("ok", false))).is_true()
	# One Priority pair and at least one Factor roll per sector, from the one generation.
	var priority_rolls := 0
	for r in coord.coop_setup_receipt.get("rolls", []):
		if str(r.get("context", "")).contains("Co-op Priority: die 1"):
			priority_rolls += 1
	assert_int(priority_rolls).is_equal(8)
	assert_str(campaign.game_phase).is_equal("active")


func test_a_campaign_that_is_not_coop_gets_no_map() -> void:
	var coord: Node = Coordinator.new()
	add_child(coord)
	auto_free(coord)
	var config: Dictionary = _config(["Ash"], 3)
	config["coop_enabled"] = false
	var campaign = coord.build_campaign({"config": config, "squad": _squad(), "equipment": {}})
	assert_bool(campaign.is_coop()).is_false()
	assert_dict(campaign.coop).is_empty()
	assert_dict(coord.coop_setup_receipt).is_empty()


# ── The review step and the main-menu route in ───────────────────────────────────

func test_the_review_step_shows_the_coop_setup() -> void:
	var coord: Node = Coordinator.new()
	add_child(coord)
	auto_free(coord)
	coord.update_config(_config(["Ash", "Bryn"], 5))
	var review: Control = ReviewPanel.new()
	add_child(review)
	auto_free(review)
	review.set_coordinator(coord)
	review.refresh()
	var text := ""
	for n in review.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	assert_str(text).contains("Ash, Bryn")
	assert_str(text).contains("10 sectors (5 per player)")


func test_the_router_context_preselects_coop_and_is_spent() -> void:
	var router: Node = get_tree().root.get_node("/root/SceneRouter")
	router.scene_contexts["bug_hunt_creation"] = {"coop": true}
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	add_child(ui)
	auto_free(ui)
	await get_tree().process_frame
	assert_bool(bool(ui.panels[0]._config_data.get("coop_enabled", false))).is_true()
	assert_bool(ui.panels[0]._coop_check.button_pressed).is_true()
	assert_dict(router.get_scene_context("bug_hunt_creation")).override_failure_message(
		"the co-op context survived, so the next plain New Bug Hunt opens in co-op").is_empty()
	# The control: a second wizard with no context opens solo.
	var plain: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	add_child(plain)
	auto_free(plain)
	await get_tree().process_frame
	assert_bool(bool(plain.panels[0]._config_data.get("coop_enabled", false))).is_false()
