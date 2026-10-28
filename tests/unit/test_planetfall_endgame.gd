extends GdUnitTestSuite

## Planetfall pp.160-164, The End Game (C12).
##
## The End Game is not a screen that replaces the campaign: Colony Security needs a
## destroyed Strongpoint (two for Loyalty) and the final milestone costs BP and RP, both
## earned in campaign turns. Before 2026-10-27 the turn controller sent every turn start
## to the End Game panel, Security re-enabled its own button on the next line, the stage
## and the Summit lived on the panel, Loyalty looked the 2D6 SUM up in a 1-6 table, and
## Independence, Ascension and Isolation stopped short of their own rules.
##
## The panel saves through GameState, so the user:// guard is mandatory here.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const EndGamePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallEndGamePanel.gd")
const EndGameSystem = preload("res://src/core/systems/PlanetfallEndGameSystem.gd")
const TurnScene = preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

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
	var router := get_tree().root.get_node_or_null("/root/GameStateManager")
	if router and router.has_method("set_temp_data"):
		router.set_temp_data("planetfall_battle_result", null)
	SaveDirGuard.restore(_user_state)


func _core(roster: Array = []) -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "endgame"
	core.campaign_turn = 5
	core.roster = roster if not roster.is_empty() else [
		{"id": "c1", "name": "Ash", "class": "trooper"},
		{"id": "c2", "name": "Kip", "class": "scientist"},
	]
	core.buildings_data = {"current_bp": 0}
	core.research_data = {"current_rp": 0}
	core.tactical_enemies = [{"name": "Raiders", "type": {"id": "raiders"}},
		{"name": "Swarm", "type": {"id": "swarm"}}]
	return core


func _panel(core: Resource, stage: String = "", path: String = "") -> Control:
	if stage != "":
		core.endgame_state = {"stage": stage}
	if path != "":
		core.endgame_path = path
	var panel: Control = EndGamePanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	return panel


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _text(node: Node) -> String:
	var shown := ""
	for n in node.find_children("*", "Label", true, false):
		shown += (n as Label).text + "\n"
	return shown


# ── Colony Security (pp.160-161) ──────────────────────────────────────────────────

func test_colony_security_holds_until_a_strongpoint_falls() -> void:
	var core := _core()
	var panel := _panel(core, "security_check", "independence")
	assert_bool(panel._action_btn.disabled) \
		.override_failure_message("p.160: no Strongpoint destroyed, so no security yet") \
		.is_true()
	assert_bool(panel._turn_btn.visible) \
		.override_failure_message("the colony must be able to go and destroy one") \
		.is_true()
	panel._on_action()
	assert_int(panel._current_stage).is_equal(panel.Stage.SECURITY_CHECK)
	core.mark_enemy_defeated(0)
	panel.refresh()
	assert_bool(panel._action_btn.disabled).is_false()
	panel._on_action()
	assert_int(panel._current_stage).is_equal(panel.Stage.FINAL_CONSTRUCTION)


func test_loyalty_needs_two_strongpoints() -> void:
	var core := _core()
	core.mark_enemy_defeated(0)
	var panel := _panel(core, "security_check", "loyalty")
	assert_bool(panel._action_btn.disabled) \
		.override_failure_message("p.161: \"Loyalty requires defeating two of them\"") \
		.is_true()
	core.mark_enemy_defeated(1)
	panel.refresh()
	assert_bool(panel._action_btn.disabled).is_false()


# ── The final milestone's price (pp.161-162) ──────────────────────────────────────

func test_the_final_milestone_charges_the_price_it_checked_and_only_once() -> void:
	var core := _core()
	core.final_breakthrough = "ancient_factory"
	core.buildings_data.current_bp = 4
	core.research_data.current_rp = 5
	var panel := _panel(core, "final_construction", "loyalty")
	assert_bool(panel._action_btn.disabled) \
		.override_failure_message("p.162 Ancient Factory: 5 BP, and the colony has 4") \
		.is_true()
	panel._on_action()
	assert_int(int(core.buildings_data.current_bp)) \
		.override_failure_message("a refused construction charges nothing").is_equal(4)
	core.buildings_data.current_bp = 5
	panel.refresh()
	panel._on_action()
	assert_int(int(core.buildings_data.current_bp)).is_equal(0)
	assert_int(int(core.research_data.current_rp)).is_equal(0)
	assert_int(panel._current_stage).is_equal(panel.Stage.RESOLUTION)
	var again := _panel(core)
	assert_int(again._current_stage) \
		.override_failure_message("a relaunch reopens on Resolution, not on the charge") \
		.is_equal(again.Stage.RESOLUTION)


# ── The stage and the Summit survive a relaunch ───────────────────────────────────

func test_a_relaunch_reopens_on_the_summit_it_held() -> void:
	var core := _core()
	var panel := _panel(core)
	_force("Planetfall Summit", [3, 3, 6])
	panel._on_action()
	assert_array(panel._summit_results.available_paths).contains_exactly(["loyalty"])
	var again := _panel(core)
	assert_int(again._current_stage).is_equal(again.Stage.PATH_SELECTION)
	assert_array(again._summit_results.available_paths) \
		.override_failure_message("the votes were held on the panel and re-rolled") \
		.contains_exactly(["loyalty"])


# ── Path resolution (pp.161-163) ──────────────────────────────────────────────────

func test_loyalty_resolves_the_die_the_player_picked() -> void:
	var core := _core()
	_force("Planetfall Colony Future", [5, 2])
	var panel := _panel(core, "resolution", "loyalty")
	assert_array(panel._colony_future_dice).contains_exactly([5, 2])
	assert_bool(panel._action_btn.disabled) \
		.override_failure_message("p.162: \"pick either result\" before resolving").is_true()
	panel._on_loyalty_pick(5)
	panel._on_action()
	assert_str(str(panel._result.outcome)) \
		.override_failure_message("the 2D6 SUM was looked up in a 1-6 table") \
		.contains("Unity naval base")
	assert_str(core.get_planetfall_ending()).is_equal("loyalty")


func test_independence_negotiates_then_goes_to_war_and_arrests_who_fails_to_escape() -> void:
	var core := _core()
	var sys = EndGameSystem.new()
	_force("Planetfall Unity Response", [4, 5, 4, 4])
	_force("Planetfall War Colony", [1, 1, 1])
	_force("Planetfall War Unity", [6, 6, 6])
	_force("Planetfall End Game Character", [6, 2])
	var r: Dictionary = sys.resolve_path(core, "independence", {})
	assert_array(r.unity_response_rolls) \
		.override_failure_message("p.161: 9 drags on, and the re-roll's 8 is War") \
		.contains_exactly([9, 8])
	assert_str(str(r.ending_id)).is_equal("independence_lost")
	assert_bool(bool(core.get_roster_character_by_id("c2").get("arrested", false))) \
		.override_failure_message("p.161: escape on 5+ or be arrested").is_true()
	assert_array(core.get_musterable_roster().map(func(c): return c.id)) \
		.override_failure_message("p.164: only characters that escaped captivity go on") \
		.contains_exactly(["c1"])
	assert_str(core.get_planetfall_ending()).is_equal("independence_lost")


func test_defense_network_adds_one_unless_the_dice_are_doubles() -> void:
	var core := _core()
	core.final_breakthrough = "defense_network"
	var sys = EndGameSystem.new()
	_force("Planetfall Unity Response", [4, 6])
	var won: Dictionary = sys.resolve_path(core, "independence", {})
	assert_str(str(won.ending_id)) \
		.override_failure_message("10 +1 = 11, Recognized status").is_equal("independence_won")
	var core2 := _core()
	core2.final_breakthrough = "defense_network"
	_force("Planetfall Unity Response", [5, 5, 6, 6])
	var doubled: Dictionary = sys.resolve_path(core2, "independence", {})
	assert_int(int(doubled.unity_response_rolls[0])) \
		.override_failure_message("doubles take no +1, so 10 negotiates").is_equal(10)


func test_a_war_draw_kills_and_warzone_wears_unity_down() -> void:
	var core := _core([{"id": "c1", "name": "Ash", "class": "trooper"},
		{"id": "c2", "name": "Kip", "class": "scientist"},
		{"id": "c3", "name": "Rue", "class": "scout"},
		{"id": "c4", "name": "Oz", "class": "trooper"}])
	core.final_breakthrough = "warzone"
	var sys = EndGameSystem.new()
	_force("Planetfall Unity Response", [2, 3])
	# Three draws, then rounds the colony loses: only Warzone's Fatigue on a draw wins it.
	_force("Planetfall War Colony", [3, 3, 3, 1, 1, 1])
	_force("Planetfall War Unity", [3, 3, 3, 6, 6, 6])
	var r: Dictionary = sys.resolve_path(core, "independence", {})
	assert_str(str(r.ending_id)) \
		.override_failure_message("three draws: three Fatigue for Unity under Warzone") \
		.is_equal("independence_won")
	assert_int(core.roster.size()) \
		.override_failure_message("each draw kills one random character").is_equal(1)


func test_ascension_counts_energy_and_reads_the_same_die_for_fate() -> void:
	var core := _core([{"id": "c1", "name": "Ash", "class": "trooper"}])
	core.final_breakthrough = "signs_of_genetic_modification"
	var sys = EndGameSystem.new()
	_force("Planetfall Ascension", [6])
	_force("Planetfall Fate of Ascension", [2])
	var r: Dictionary = sys.resolve_path(core, "ascension", {})
	assert_int(int(r.ascension_energy)) \
		.override_failure_message("1 earned, +2 for Signs of Genetic Modification") \
		.is_equal(3)
	assert_str(str(r.outcome)).contains("hivemind")


func test_moved_in_time_lets_one_character_roll_a_six() -> void:
	var core := _core([{"id": "c1", "name": "Ash", "class": "trooper"}])
	core.final_breakthrough = "moved_in_time_or_space"
	var sys = EndGameSystem.new()
	# A 1 waits on the die: it is read only if the chosen character is NOT given the 6.
	_force("Planetfall Ascension", [1])
	_force("Planetfall Fate of Ascension", [6])
	var r: Dictionary = sys.resolve_path(core, "ascension",
			{"moved_in_time_character": "c1"})
	assert_int(int(r.character_results[0].roll)).is_equal(6)
	assert_object(core.get_roster_character_by_id("c1")).is_not_null()


func test_isolation_ends_at_three_wisdom_and_a_second_hardship_kills() -> void:
	var core := _core([{"id": "c1", "name": "Ash", "class": "trooper"}])
	var sys = EndGameSystem.new()
	# hardship, Wisdom, hardship again, then two more Wisdom a survivor would reach.
	_force("Planetfall Nomad Struggles", [2, 3, 6, 6, 2, 2, 6, 6, 6, 6])
	var r: Dictionary = sys.resolve_path(core, "isolation", {})
	assert_object(core.get_roster_character_by_id("c1")) \
		.override_failure_message("p.163: the same character's second hardship kills") \
		.is_null()
	assert_str(str(r.outcome)).contains("perished")
	var core2 := _core([{"id": "c1", "name": "Ash", "class": "trooper"}])
	_force("Planetfall Nomad Struggles", [4, 4, 6, 6, 5, 5])
	var r2: Dictionary = sys.resolve_path(core2, "isolation", {})
	assert_str(str(r2.outcome)).contains("founded a new tribe")


func test_no_ending_before_the_end_game_is_resolved() -> void:
	var core := _core()
	# Loyalty, not Independence: the fallback already maps "independence" to "" (its
	# ending depends on the war), so only a path the fallback WOULD return can tell a
	# chosen path from a resolved one.
	core.endgame_path = "loyalty"
	assert_str(core.get_planetfall_ending()) \
		.override_failure_message("a chosen path is not an ending (p.164 bonuses)") \
		.is_equal("")


# ── The turn controller hands back to a campaign turn ─────────────────────────────

func test_between_turns_the_end_game_opens_and_hands_back_to_a_turn() -> void:
	var core := _core()
	core.endgame_state = {"stage": "security_check"}
	core.endgame_path = "independence"
	core.record_turn_phase(Phase.NONE, {})
	get_tree().root.get_node_or_null("/root/GameState").current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(tc._endgame_panel) \
		.override_failure_message("p.160: between turns the End Game panel opens") \
		.is_not_null()
	tc._endgame_panel._on_play_turn()
	assert_object(tc._endgame_panel).is_null()
	assert_int(tc.phase_manager.current_phase) \
		.override_failure_message("Security is unmet, so the colony plays another turn") \
		.is_equal(Phase.RECOVERY)


func test_a_turn_under_way_resumes_instead_of_opening_the_end_game() -> void:
	var core := _core()
	core.record_turn_phase(Phase.RESEARCH, {})
	get_tree().root.get_node_or_null("/root/GameState").current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(tc._endgame_panel).is_null()
	assert_int(tc.phase_manager.current_phase) \
		.override_failure_message("the End Game used to swallow every relaunch") \
		.is_equal(Phase.RESEARCH)
