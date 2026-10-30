extends GdUnitTestSuite
## Sprint 7b BS4: the Reaction Roll counts its dice the way the battle's book does.
##
## THE DEFECT THIS PINS. Every figure on the battle screen rolled its own Reaction die in
## every mode. Bug Hunt rolls one die per main character and one per combat team, and all
## of a team's grunts act on that die (pp.173, 198); the core's combat_teams field was
## serialized and never written. Planetfall rolls one die per character and one per grunt
## fireteam, plus an extra die per scientist with the excess discarded (pp.29-30), and its
## Lock and Load step reported the mission's fireteam LIMIT rather than the teams picked.

const Pool := preload("res://src/core/battle/ReactionRollPool.gd")
const MissionPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const CoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const LockAndLoad := preload("res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const TBUIScript := preload("res://src/ui/screens/battle/TacticalBattleUI.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _dm: Node
var _saved_campaign: Variant
var _saved_context: Variant


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	if _dm != null:
		_dm.clear_forced_results()
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	var gsm: Node = get_tree().root.get_node_or_null("/root/GameStateManager")
	_saved_context = gsm.get_temp_data("bug_hunt_battle_context") if gsm else null


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gsm: Node = get_tree().root.get_node_or_null("/root/GameStateManager")
	if gsm:
		gsm.set_temp_data("bug_hunt_battle_context", _saved_context)
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


# ── the pool, per book ─────────────────────────────────────────────────────────

func test_bug_hunt_rolls_one_die_per_main_character_and_per_team() -> void:
	var members: Array = [
		{"id": "a", "reactions": 2}, {"id": "b", "reactions": 2},
		{"id": "g1", "reactions": 1, "team": 1}, {"id": "g2", "reactions": 1, "team": 1},
		{"id": "g3", "reactions": 1, "team": 1}, {"id": "g4", "reactions": 1, "team": 2},
		{"id": "g5", "reactions": 1, "team": 2}]
	var plan: Dictionary = Pool.build_figures(members)
	assert_int(int(plan.dice)).override_failure_message(
		"p.198: 2 main characters and 2 combat teams roll 4 dice").is_equal(4)
	assert_str(str(plan.figure_of.g1)).is_equal(str(plan.figure_of.g3))
	assert_str(str(plan.figure_of.g4)).is_not_equal(str(plan.figure_of.g1))


func test_planetfall_adds_fireteams_and_a_die_per_scientist() -> void:
	var members: Array = [
		{"id": "s", "reactions": 1, "is_scientist": true}, {"id": "t", "reactions": 2},
		{"id": "c", "reactions": 1}]
	var fireteams: Array = [{"id": "fireteam_1", "name": "Fireteam 1", "reactions": 2, "size": 4},
		{"id": "fireteam_2", "name": "Fireteam 2", "reactions": 2, "size": 2}]
	var plan: Dictionary = Pool.build_figures(members, fireteams)
	assert_int((plan.figures as Array).size()).is_equal(5)
	assert_int(int(plan.dice)).override_failure_message(
		"p.29: one extra die for the scientist, the excess discarded").is_equal(6)
	var assignment: Dictionary = Pool.auto_assign([1, 1, 2, 2, 6, 6], plan.figures)
	assert_int(assignment.size()).override_failure_message(
		"each figure takes exactly one die").is_equal(5)


# ── Bug Hunt: the deploy step and the stamp ────────────────────────────────────

func test_the_legal_team_splits_are_two_to_four_grunts() -> void:
	assert_array(MissionPanel.combat_team_counts(4)).contains_exactly([1, 2])
	assert_array(MissionPanel.combat_team_counts(5)).contains_exactly([2])
	assert_array(MissionPanel.combat_team_counts(8)).contains_exactly([2, 3, 4])
	assert_array(MissionPanel.combat_team_counts(1)).contains_exactly([1])
	assert_array(MissionPanel.combat_team_counts(0)).is_empty()
	var teams: Array = MissionPanel.deal_combat_teams(["a", "b", "c", "d", "e"], 2)
	assert_array(teams).contains_exactly([["a", "b", "c"], ["d", "e"]])


## A core with two main characters and `n` grunts, and a panel whose mission is generated
## with three different objective dice (no Vital, p.185), the shape
## test_bug_hunt_mission_setup.gd uses.
func _panel_with_grunts(n: int, saved_teams: Array = []) -> Control:
	assert_object(_dm).override_failure_message("premise: DiceManager").is_not_null()
	var core = CoreScript.new()
	core.campaign_name = "T"
	core.main_characters = [
		{"id": "a", "name": "Alpha", "equipment": ["service_pistol", "trooper_armor"]},
		{"id": "b", "name": "Bravo", "equipment": ["service_pistol", "trooper_armor"]}]
	var grunts: Array = []
	for i in n:
		grunts.append({"id": "g%d" % i, "name": "Grunt %d" % i, "is_grunt": true,
			"reactions": 1})
	core.grunts = grunts
	core.combat_teams = saved_teams
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), i + 1)
	_dm.queue_forced_result("Bug Hunt Priority: die 1", 3)
	_dm.queue_forced_result("Bug Hunt Priority: die 2", 6)
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel._generate_mission()
	return panel


func _team_picker(panel: Node) -> OptionButton:
	for n in panel.find_children("*", "OptionButton", true, false):
		var opt := n as OptionButton
		if opt.item_count == 0:
			continue
		var first: String = opt.get_item_text(0)
		if first.ends_with(" team") or first.ends_with(" teams"):
			return opt
	return null


func test_the_launch_stamps_each_grunts_team_and_keeps_the_split() -> void:
	var panel := _panel_with_grunts(4)
	var opt := _team_picker(panel)
	assert_object(opt).override_failure_message(
		"the deploy step offers the p.173 combat teams").is_not_null()
	opt.select(1)
	opt.item_selected.emit(1)
	var root := get_tree().root
	var held: Array = []
	for n in ["SceneRouter", "NotificationManager"]:
		var node: Node = root.get_node_or_null(n)
		if node:
			root.remove_child(node)
			held.append(node)
	panel._launch_mission()
	for node in held:
		root.add_child(node)
	var ctx: Variant = root.get_node("/root/GameStateManager").get_temp_data(
		"bug_hunt_battle_context")
	assert_bool(ctx is Dictionary).override_failure_message("the launch stored no battle") \
		.is_true()
	var by_team: Array = []
	for m: Dictionary in (ctx as Dictionary).crew:
		if bool(m.get("is_grunt", false)):
			by_team.append(int(m.get("combat_team", 0)))
	assert_array(by_team).contains_exactly([1, 1, 2, 2])
	assert_int((panel._campaign.combat_teams as Array).size()).override_failure_message(
		"the split becomes the next mission's default").is_equal(2)


func test_the_picker_starts_on_the_split_last_fielded() -> void:
	var panel := _panel_with_grunts(4, [["g0", "g1"], ["g2", "g3"]])
	var opt := _team_picker(panel)
	assert_object(opt).is_not_null()
	assert_str(opt.get_item_text(opt.selected)).is_equal("2 teams")


# ── Planetfall: the fireteams picked ───────────────────────────────────────────

func test_lock_and_load_reports_the_fireteams_picked_not_the_limit() -> void:
	var panel: Control = auto_free(LockAndLoad.new())
	add_child(panel)
	panel._grunt_fireteams = 2
	panel._on_grunt_fireteam_toggled(true, 0, 4)
	var seen: Array = []
	panel.phase_completed.connect(func(d: Dictionary) -> void: seen.append(d))
	panel._on_confirm_pressed()
	assert_int(int(seen[0].grunt_fireteams)).is_equal(1)
	assert_int(int(seen[0].grunts_deployed)).is_equal(4)


# ── the battle screen ──────────────────────────────────────────────────────────

func _screen(mode: String, crew: Array, md: Dictionary = {}) -> Control:
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._is_bug_hunt_mode = mode == "bug_hunt"
	ui._is_planetfall_mode = mode == "planetfall"
	ui._stored_mission_data = md
	var units: Array = []
	for c: Dictionary in crew:
		var u = TBUIScript.TacticalUnit.new()
		u.initialize_from_crew_member(c)
		u.reactions = int(c.reactions)
		units.append(u)
	ui.crew_units.assign(units)
	return ui


func test_a_bug_hunt_team_acts_on_one_die() -> void:
	assert_object(_dm).override_failure_message("premise: DiceManager").is_not_null()
	var ui: Control = await _screen("bug_hunt", [
		{"id": "a", "name": "Alpha", "reactions": 2},
		{"id": "g1", "name": "G1", "reactions": 1, "is_grunt": true, "combat_team": 1},
		{"id": "g2", "name": "G2", "reactions": 1, "is_grunt": true, "combat_team": 1}])
	for v in [1, 6, 6, 6]:
		_dm.queue_forced_result("Reaction Roll", v)
	ui._assign_crew_reaction_slots()
	var g1 = ui.crew_units[1]
	var g2 = ui.crew_units[2]
	assert_int(int(g1.initiative_roll)).override_failure_message(
		"the team's Reactions-1 figure takes the 1 rolled for it").is_equal(1)
	assert_int(int(g1.initiative_roll)).is_equal(int(g2.initiative_roll))
	assert_int(int(g1.react_slot)).is_equal(int(g2.react_slot))
	assert_int(_dm.get_forced_results().get("reaction roll", []).size()).override_failure_message(
		"p.198: one main character and one team roll 2 dice, not 3").is_equal(2)


func test_planetfall_rolls_for_fireteams_and_scientists() -> void:
	var ui: Control = await _screen("planetfall", [
		{"id": "s", "name": "Sci", "reactions": 1, "class": "scientist"},
		{"id": "t", "name": "Trooper", "reactions": 2, "class": "trooper"}],
		{"grunts_deployed": 6, "grunt_fireteams": 2})
	# The scientist (Reactions 1) takes a 1 and a Reactions-2 figure the other; the two
	# left take a 3, so at least one fireteam is one over its score.
	for v in [1, 1, 3, 3, 3, 6, 6]:
		_dm.queue_forced_result("Reaction Roll", v)
	ui._assign_crew_reaction_slots()
	assert_int(_dm.get_forced_results().get("reaction roll", []).size()).override_failure_message(
		"2 characters + 2 fireteams + 1 scientist die = 5 dice of the 7 queued").is_equal(2)
	var feed: String = str(ui.unified_log._live_feed.get_parsed_text()) \
		if ui.unified_log else ""
	assert_str(feed).contains("Fireteam 1").contains("Fireteam 2") \
		.contains("Quick if in formation, Planetfall p.30")
