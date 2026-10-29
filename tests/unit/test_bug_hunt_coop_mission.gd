extends GdUnitTestSuite

## The Bug Hunt co-op MISSION, Compendium p.211, through the real mission panel.
##
## "Each player may attack one sector of their choice ... Set up the mission as normal,
## using the Priority level from the sector map." And p.210: Vital or Critical Objectives
## "will increase this as normal (see p.187), but only for the duration of that specific
## mission."
##
## Every case builds its map with BugHuntCampaignCore.start_coop_campaign() under forced
## dice (the real producer), drives BugHuntMissionPanel, and asserts what reaches the
## STAMP and the battle -- the payload the post-battle record reads -- not only a label.
##
## The forced map (2 players x 3 sectors, grid 3 x 2):
##   S1 Ambush zone P3 | S2 Sheltered P4    | S3 Inaccessible P2
##   S4 Swarming P5    | S5 Obstructed P1   | S6 Hot zone P5, stash 4
## S2 is Sheltered with no cleared neighbour, so nobody may attack it yet.
##
## gdUnit4 v6.0.3. The rules module reaches /root/DiceManager, so the forced queue is
## cleared after every case; the panel persists at launch, so SaveDirGuard and the
## GameState campaign are restored too.

const MissionPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const CoopRef = preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
const CoopView = preload("res://src/ui/screens/bug_hunt/BugHuntCoopView.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const PRIORITY_1 := "Bug Hunt Co-op Priority: die 1"
const PRIORITY_2 := "Bug Hunt Co-op Priority: die 2"
const FACTOR := "Bug Hunt Co-op Sector Factor"
const STASH := "Bug Hunt Co-op Resource Stash"
const ENEMY_MOVE := "Bug Hunt Co-op Enemy Move"
const WASTAGE := "Bug Hunt Co-op Wastage"
const MAP_DIE_1 := [3, 4, 2, 6, 1, 5]
const MAP_DIE_2 := [5, 4, 6, 5, 3, 6]
const MAP_FACTORS := [1, 31, 81, 51, 66, 95]  # ambush, sheltered, inaccessible, swarming, obstructed, hot zone

var _dm: Node = null
var _user_state: Dictionary
var _saved_campaign: Variant = null
var _saved_context: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	assert_object(_dm).override_failure_message(
		"/root/DiceManager did not resolve, so no die below can be forced").is_not_null()
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


func _coop_core() -> Resource:
	var core = CoreScript.new()
	core.campaign_name = "Coop Mission T"
	core.difficulty = "mess_me_up"
	core.main_characters = [
		{"id": "a", "name": "Alpha", "equipment": ["service_pistol", "trooper_armor"]},
		{"id": "b", "name": "Bravo", "equipment": ["service_pistol", "trooper_armor"]}]
	for v in MAP_DIE_1:
		_dm.queue_forced_result(PRIORITY_1, v)
	for v in MAP_DIE_2:
		_dm.queue_forced_result(PRIORITY_2, v)
	for v in MAP_FACTORS:
		_dm.queue_forced_result(FACTOR, v)
	_dm.queue_forced_result(STASH, 4)
	var receipt: Dictionary = core.start_coop_campaign(["Ash", "Bryn"], 3)
	# Instrument the premise: the map below is the forced one, not whatever the RNG gave.
	assert_bool(bool(receipt.get("ok", false))).is_true()
	assert_dict(_dm.get_forced_results()).override_failure_message(
		"the forced map dice were not all consumed").is_empty()
	assert_str(str(CoopView.sector(core.coop, "S2").get("factors", [""])[0])).is_equal("sheltered")
	assert_int(int(CoopView.sector(core.coop, "S4").get("priority", 0))).is_equal(5)
	return core


func _panel(core: Resource) -> Control:
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	return panel


## Three different objective dice, so no Objective is Vital or Critical (p.185).
func _force_plain_objectives() -> void:
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), i + 1)


func _sector_cards(panel: Node) -> Dictionary:
	var out: Dictionary = {}
	for n in panel._coop_container.find_children("*", "PanelContainer", true, false):
		if n.has_meta("sector_id"):
			out[str(n.get_meta("sector_id"))] = n
	return out


func _labels(root: Node) -> String:
	var text := ""
	for n in root.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	for n in root.find_children("*", "Button", true, false):
		text += (n as Button).text + "\n"
	return text


func _tap(control: Control) -> void:
	var at := control.size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	control.gui_input.emit(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	control.gui_input.emit(release)


# ── The picker ───────────────────────────────────────────────────────────────────

func test_the_picker_offers_only_attackable_sectors_and_says_why_not() -> void:
	var core := _coop_core()
	var panel := _panel(core)
	var cards: Dictionary = _sector_cards(panel)
	assert_int(cards.size()).is_equal(6)
	var offered: Array = []
	for sid: String in cards:
		if bool(cards[sid].get_meta("attackable")):
			offered.append(sid)
	offered.sort()
	assert_array(offered).is_equal(["S1", "S3", "S4", "S5", "S6"])
	# The refused card carries the rules module's own reason, not a UI paraphrase.
	var reason: String = str(CoopRef.can_attack(core.coop, "S2", "Ash").get("reason", ""))
	assert_str(reason).contains("adjacent sector has been cleared")
	assert_str(_labels(cards["S2"])).contains(reason)
	# Nothing to generate against until a sector is chosen.
	assert_bool(panel._generate_button.disabled).is_true()


func test_tapping_a_sector_takes_the_mission_priority_from_the_map() -> void:
	var core := _coop_core()
	var panel := _panel(core)
	for _i in range(3):
		await get_tree().process_frame
	var card: Control = _sector_cards(panel)["S4"]
	assert_bool(card.size.x > 0.0 and card.size.y > 0.0).override_failure_message(
		"the card has no size, so a tap cannot land inside it").is_true()
	_tap(card)
	assert_str(panel._coop_sector_id).is_equal("S4")
	assert_bool(panel._generate_button.disabled).is_false()
	# A p.187 Priority roll that the co-op mission must NOT make: if it is consumed, the
	# mission rolled its Priority instead of reading the sector's.
	_dm.queue_forced_result("Bug Hunt Priority: die 1", 1)
	_dm.queue_forced_result("Bug Hunt Priority: die 2", 1)
	_force_plain_objectives()
	panel._generate_mission()
	assert_bool(panel._mission_generated).is_true()
	assert_int(int(panel._mission_context.get("priority", -1))).is_equal(5)
	assert_bool(_dm.get_forced_results().has("bug hunt priority: die 1")).override_failure_message(
		"the co-op mission rolled the p.187 Priority dice").is_true()
	var stamp: Dictionary = panel._mission_context.get("coop", {})
	assert_str(str(stamp.get("player", ""))).is_equal("Ash")
	assert_str(str(stamp.get("sector_id", ""))).is_equal("S4")
	assert_int(int(stamp.get("op_turn", 0))).is_equal(1)
	var factors: Array = (stamp.get("modifiers", {}) as Dictionary).get("factors", [])
	assert_str(str((factors[0] as Dictionary).get("id", ""))).is_equal("swarming")


## p.210: a Vital Objective raises the Priority "as normal ... but only for the duration
## of that specific mission" -- the sector keeps its own.
func test_a_vital_objective_raises_this_mission_only() -> void:
	var core := _coop_core()
	var panel := _panel(core)
	panel._select_coop_sector("S1")  # Priority 3
	_dm.queue_forced_result("Bug Hunt Objective: die 1", 2)
	_dm.queue_forced_result("Bug Hunt Objective: die 2", 2)
	_dm.queue_forced_result("Bug Hunt Objective: die 3", 5)
	panel._generate_mission()
	assert_bool(bool(panel._mission_context.get("has_vital", false))).is_true()
	assert_int(int(panel._mission_context.get("priority", -1))).is_equal(4)
	assert_int(int(CoopView.sector(core.coop, "S1").get("priority", 0))).is_equal(3)


func test_a_refused_sector_generates_nothing() -> void:
	var core := _coop_core()
	var panel := _panel(core)
	panel._coop_sector_id = "S2"  # Sheltered, past the picker
	_force_plain_objectives()
	panel._generate_mission()
	assert_bool(panel._mission_generated).is_false()
	assert_bool(_dm.get_forced_results().has("bug hunt objective: die 1")).override_failure_message(
		"a refused attack still rolled the mission").is_true()
	assert_str(_labels(panel._coop_container)).contains("adjacent sector has been cleared")


# ── The stamp and the battle ─────────────────────────────────────────────────────

## p.211: the common pool adds to the mission's Support, drawn once at launch, and the
## sector, its Factors and the draw ride the stamp AND the battle context.
func test_launch_stamps_the_sector_and_draws_the_pool_once() -> void:
	var core := _coop_core()
	# Bryn's victory elsewhere clears S1 and pays 1 into the pool (p.211).
	var won: Dictionary = core.record_coop_battle("Bryn", "S1", {"objectives_completed": 2})
	assert_bool(bool(won.get("victory", false))).is_true()
	assert_int(int(core.coop.support_pool)).is_equal(1)
	var panel := _panel(core)
	assert_str(panel._coop_player).is_equal("Ash")  # Bryn has fought
	panel._select_coop_sector("S5")
	_force_plain_objectives()
	panel._generate_mission()
	var before: int = panel._support_points_total()
	panel._on_coop_pool_draw(1)
	assert_int(panel._support_points_total()).is_equal(before + 1)
	panel._on_coop_pool_draw(1)  # the pool holds only 1
	assert_int(panel._coop_pool_draw).is_equal(1)

	var root := get_tree().root
	var held: Array = []
	for n in ["SceneRouter", "NotificationManager"]:
		var node: Node = root.get_node_or_null(n)
		if node:
			root.remove_child(node)
			held.append(node)
	panel._launch_mission()
	panel._launch_mission()  # a retried launch must not draw again
	for node in held:
		root.add_child(node)

	assert_int(int(core.coop.support_pool)).is_equal(0)
	var stamped: Dictionary = core.current_mission.get("coop", {})
	assert_str(str(stamped.get("sector_id", ""))).is_equal("S5")
	assert_int(int(stamped.get("pool_drawn", -1))).is_equal(1)
	var ctx: Variant = root.get_node("/root/GameStateManager").get_temp_data(
		"bug_hunt_battle_context")
	assert_bool(ctx is Dictionary).is_true()
	var md_coop: Dictionary = ((ctx as Dictionary).get("mission_data", {}) as Dictionary).get(
		"coop", {})
	assert_str(str(md_coop.get("sector_id", ""))).is_equal("S5")
	assert_int(int(md_coop.get("pool_drawn", -1))).is_equal(1)


## p.210 Inaccessible: "Only a single support roll can be made." The cap binds with
## points still left over, so it is the Factor that stops the second request.
func test_inaccessible_allows_a_single_support_roll() -> void:
	var core := _coop_core()
	var panel := _panel(core)
	panel._select_coop_sector("S3")  # Inaccessible, Priority 2
	_force_plain_objectives()
	panel._generate_mission()
	assert_int(panel._coop_max_support_rolls()).is_equal(1)
	assert_int(panel._support_points_remaining()).is_greater_equal(2)
	var buttons: Array = panel._support_buttons
	assert_bool(buttons.size() >= 2).is_true()
	_dm.queue_forced_result("Bug Hunt Support die 1", 6)
	_dm.queue_forced_result("Bug Hunt Support die 2", 6)
	(buttons[0] as Button).pressed.emit()
	assert_int(panel._support_points_remaining()).is_greater_equal(1)
	assert_int(panel._support_requests_left()).is_equal(0)
	for b in buttons:
		assert_bool((b as Button).disabled).is_true()
	(buttons[1] as Button).pressed.emit()
	assert_int(panel._support_requests_made).is_equal(1)


## p.211 Enemy sabotage!: "During the next operational turn, all battles are fought with
## -1 Support point." Produced by a real end phase, consumed by the next mission.
func test_sabotage_takes_a_point_off_the_next_turns_battles() -> void:
	var core := _coop_core()
	core.record_coop_battle("Bryn", "S1", {"objectives_completed": 2})
	core.record_coop_battle("Ash", "S5", {"objectives_completed": 0})
	_dm.queue_forced_result(ENEMY_MOVE, 40)  # Ash: Enemy sabotage!
	_dm.queue_forced_result(ENEMY_MOVE, 74)  # Bryn: Wastage
	_dm.queue_forced_result(WASTAGE, 1)
	var end: Dictionary = CoopView.end_turn(core)
	assert_bool(bool(end.get("ok", false))).is_true()
	assert_int(int(core.coop.support_penalty)).is_equal(1)
	var panel := _panel(core)
	panel._select_coop_sector("S4")  # Priority 5
	_force_plain_objectives()
	panel._generate_mission()
	var rules: Dictionary = panel._mission_context.get("difficulty_rules", {})
	var expected: int = 5 + int(rules.get("extra_support_points", 0)) - 1
	assert_int(panel._support_points_total()).is_equal(expected)
	assert_str(panel._support_points_lbl.text).contains(CoopView.sabotage_name())


# ── The battle card ──────────────────────────────────────────────────────────────

func test_the_battle_card_shows_the_sector_factor_in_the_datas_words() -> void:
	var core := _coop_core()
	var panel := _panel(core)
	panel._select_coop_sector("S4")
	_force_plain_objectives()
	panel._generate_mission()
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	var md: Dictionary = preload("res://src/core/battle/BugHuntBattleSetup.gd").new() \
		.generate_battle_context(panel._mission_context, core)
	md["coop"] = (panel._mission_context["coop"] as Dictionary).duplicate(true)
	ui._stored_mission_data = md
	var card: Control = ui._build_battle_card()
	auto_free(card)
	var text: String = _labels(card)
	assert_str(text).contains("BUG HUNT BATTLE CARD")
	assert_str(text).contains("Co-op: Sector 4")
	assert_str(text).contains(str(CoopRef.factor_row("swarming").get("effect", "<missing>")))
	# The control: a mission with no co-op block shows none of it.
	md.erase("coop")
	ui._stored_mission_data = md
	var plain: Control = ui._build_battle_card()
	auto_free(plain)
	assert_str(_labels(plain)).not_contains("Co-op:")
