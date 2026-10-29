extends GdUnitTestSuite

## The Bug Hunt co-op result and the shared map, Compendium pp.210-211, through the real
## post-battle panel, the real map panel and the real dashboard.
##
## p.211: "If the mission is a victory (2+ Objectives completed), clear the sector from
## the map, and claim 1 Support point worth of resources ... If the mission failed, the
## sector remains under enemy control." p.211: "At the end of each operational turn, the
## enemy will carry out their actions. Each player rolls on the table and applies the
## results to the map."
##
## ⚠ Every assertion on a rendered receipt reads a RESULT LINE, never a heading: a heading
## renders for a step that did nothing (the Bug Hunt Phase 7 Court Martial detector
## returned the same answer in both arms because of exactly that).
##
## The forced map, 2 players x 3 sectors (grid 3 x 2):
##   S1 Ambush zone P3 | S2 Sheltered P4    | S3 Inaccessible P2
##   S4 Swarming P5    | S5 Obstructed P1   | S6 Hot zone P5, stash 4
##
## gdUnit4 v6.0.3. Forced queue cleared, saves and GameState restored after every case.

const MissionPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const PostBattlePanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
const MapPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntCoopMapPanel.gd")
const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const CharGen = preload("res://src/core/character/BugHuntCharacterGeneration.gd")
const CoopRef = preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
const CoopView = preload("res://src/ui/screens/bug_hunt/BugHuntCoopView.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const DASHBOARD_SCENE := "res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn"

const PRIORITY_1 := "Bug Hunt Co-op Priority: die 1"
const PRIORITY_2 := "Bug Hunt Co-op Priority: die 2"
const FACTOR := "Bug Hunt Co-op Sector Factor"
const STASH := "Bug Hunt Co-op Resource Stash"
const ENEMY_MOVE := "Bug Hunt Co-op Enemy Move"
const MAP_DIE_1 := [3, 4, 2, 6, 1, 5]
const MAP_DIE_2 := [5, 4, 6, 5, 3, 6]
const MAP_FACTORS := [1, 31, 81, 51, 66, 95]

const RAW_RESULT := {"victory": true, "won": true, "held_field": true, "rounds_fought": 5,
	"crew_casualties": 0, "crew_casualties_data": [], "crew_injuries": 0,
	"crew_injuries_data": [], "enemies_defeated_count": 4, "auto_resolved": false}

var _dm: Node = null
var _user_state: Dictionary
var _saved_campaign: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	assert_object(_dm).override_failure_message(
		"/root/DiceManager did not resolve, so no die below can be forced").is_not_null()
	_dm.clear_forced_results()
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs: Node = get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _coop_core() -> Resource:
	var core = CoreScript.new()
	core.campaign_name = "Coop Map T"
	core.difficulty = "mess_me_up"
	core.main_characters = CharGen.new().generate_squad([], 3).get("main_characters", [])
	core.start_campaign()
	for v in MAP_DIE_1:
		_dm.queue_forced_result(PRIORITY_1, v)
	for v in MAP_DIE_2:
		_dm.queue_forced_result(PRIORITY_2, v)
	for v in MAP_FACTORS:
		_dm.queue_forced_result(FACTOR, v)
	_dm.queue_forced_result(STASH, 4)
	var receipt: Dictionary = core.start_coop_campaign(["Ash", "Bryn"], 3)
	assert_bool(bool(receipt.get("ok", false))).is_true()
	assert_dict(_dm.get_forced_results()).override_failure_message(
		"the forced map dice were not all consumed").is_empty()
	assert_int(int(CoopView.sector(core.coop, "S6").get("stash", 0))).is_equal(4)
	return core


## Ash's mission against `sector_id`, generated and stamped exactly as Launch stamps it.
func _stamp_mission(core: Resource, sector_id: String) -> void:
	var mp: Control = MissionPanel.new()
	add_child(mp)
	auto_free(mp)
	mp.set_campaign(core)
	mp.refresh()
	mp._select_coop_player("Ash")
	mp._select_coop_sector(sector_id)
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), i + 1)
	mp._generate_mission()
	assert_str(str((mp._mission_context.get("coop", {}) as Dictionary).get("sector_id", ""))) \
		.is_equal(sector_id)
	mp._mission_context["participant_ids"] = mp._participant_ids.duplicate()
	mp._persist_stamped_mission()


## The post-battle panel with `ticked` of the three (normal) Objectives completed.
func _post_battle(core: Resource, ticked: int) -> Control:
	var pb: Control = PostBattlePanel.new()
	add_child(pb)
	auto_free(pb)
	pb.set_campaign(core)
	pb.set_battle_results(RAW_RESULT.duplicate(true))
	pb.refresh()
	for i in ticked:
		(pb._debrief_objective_checks[i] as CheckBox).button_pressed = true
	pb._process_post_battle()
	return pb


func _labels(root: Node) -> String:
	var text := ""
	for n in root.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	for n in root.find_children("*", "Button", true, false):
		text += (n as Button).text + "\n"
	return text


func _button(root: Node, node_name: String) -> Button:
	for n in root.find_children(node_name, "Button", true, false):
		return n
	return null


# ── The post-battle record ───────────────────────────────────────────────────────

func test_complete_records_a_victory_on_the_map_exactly_once() -> void:
	var core := _coop_core()
	_stamp_mission(core, "S6")  # Hot zone, stash 4
	var pb := _post_battle(core, 2)
	pb.complete()
	var s6: Dictionary = CoopView.sector(core.coop, "S6")
	assert_bool(bool(s6.get("cleared", false))).is_true()
	assert_int(int(core.coop.support_pool)).is_equal(1 + 4)
	assert_array(core.coop.attacked_this_turn).is_equal(["Ash"])
	var stored: Variant = core.current_mission.get("coop_receipt", null)
	assert_bool(stored is Dictionary and bool((stored as Dictionary).get("ok", false))).is_true()
	# The RESULT line reached the screen.
	assert_str(_labels(pb)).contains("plus the resource stash of 4")

	# Once per mission: the same panel again, a fresh panel on the same stamp (a reload),
	# and the record function itself all leave the map where it is.
	pb.complete()
	var again := _post_battle(core, 2)
	again.complete()
	again._record_coop_battle()
	assert_int(int(core.coop.support_pool)).is_equal(1 + 4)
	assert_array(core.coop.attacked_this_turn).is_equal(["Ash"])
	# The map alone cannot show the guard: the core already refuses a second attack by the
	# same player, so the pool and tally stay put either way. What the guard decides is
	# what the reloaded debrief SAYS -- the victory it recorded, not that refusal.
	var kept: Variant = core.current_mission.get("coop_receipt", null)
	assert_bool(kept is Dictionary and bool((kept as Dictionary).get("ok", false))) \
		.override_failure_message("a second record overwrote the stored receipt").is_true()
	assert_str(_labels(again)).contains("plus the resource stash of 4")


func test_a_failed_mission_leaves_the_sector_under_enemy_control() -> void:
	var core := _coop_core()
	_stamp_mission(core, "S4")
	var pb := _post_battle(core, 1)
	pb.complete()
	assert_bool(bool(CoopView.sector(core.coop, "S4").get("cleared", true))).is_false()
	assert_int(int(core.coop.support_pool)).is_equal(0)
	assert_str(_labels(pb)).contains("remains under enemy control")


## p.210: "each player will carry out a mission, followed by a roll for Enemy Moves." The
## end phase is not offered while Bryn still has a sector to attack.
func test_the_end_of_turn_waits_for_every_player() -> void:
	var core := _coop_core()
	_stamp_mission(core, "S1")
	var pb := _post_battle(core, 2)
	pb.complete()
	assert_object(_button(pb, "EndOperationalTurn")).is_null()
	assert_str(_labels(pb)).contains("Still to fight this operational turn: Bryn")
	# And nothing is left live on a co-op panel that cannot end the turn (the lock holds).
	for n in pb._content_container.find_children("*", "BaseButton", true, false):
		assert_bool((n as BaseButton).disabled).is_true()


func test_the_last_player_ends_the_turn_and_sees_the_enemy_moves() -> void:
	var core := _coop_core()
	core.record_coop_battle("Bryn", "S3", {"objectives_completed": 0})  # elsewhere
	_stamp_mission(core, "S1")
	var pb := _post_battle(core, 2)
	pb.complete()
	var end_btn := _button(pb, "EndOperationalTurn")
	assert_object(end_btn).override_failure_message(
		"every player has fought, so the end of the turn should be offered").is_not_null()
	assert_bool(end_btn.disabled).override_failure_message(
		"the End control was locked with the rest of the debrief").is_false()
	_dm.queue_forced_result(ENEMY_MOVE, 40)  # Ash: Enemy sabotage!
	_dm.queue_forced_result(ENEMY_MOVE, 40)  # Bryn: Enemy sabotage!
	end_btn.pressed.emit()
	assert_int(int(core.coop.op_turn)).is_equal(2)
	assert_int(int(core.coop.support_penalty)).is_equal(2)
	assert_bool(end_btn.disabled).is_true()
	var text: String = _labels(pb)
	assert_str(text).contains("Ash rolled 40: Enemy sabotage!")
	assert_str(text).contains("Bryn rolled 40: Enemy sabotage!")


# ── The map panel ────────────────────────────────────────────────────────────────

func _map(core: Resource) -> Control:
	var panel: Control = MapPanel.new()
	panel.set_campaign(core)
	add_child(panel)
	auto_free(panel)
	return panel


func _map_cards(panel: Node) -> Dictionary:
	var out: Dictionary = {}
	for n in panel.find_children("*", "PanelContainer", true, false):
		if n.has_meta("sector_id"):
			out[str(n.get_meta("sector_id"))] = n
	return out


func test_the_map_shows_every_sector_in_the_datas_words() -> void:
	var core := _coop_core()
	var panel := _map(core)
	var cards: Dictionary = _map_cards(panel)
	assert_int(cards.size()).is_equal(6)
	assert_str(_labels(cards["S6"])).contains("Resource stash: 4 Support points")
	assert_str(_labels(cards["S2"])).contains(
		str(CoopRef.factor_row("sheltered").get("effect", "<missing>")))
	assert_str(_labels(cards["S2"])).contains("Adjacent: Sector 1, Sector 3, Sector 5")
	assert_str(_labels(cards["S4"])).contains("Enemy-held, Priority 5")
	assert_str(_labels(panel)).contains("Common Support pool: 0 points")


func test_the_map_records_a_mission_played_elsewhere_and_ends_the_turn() -> void:
	var core := _coop_core()
	var panel := _map(core)
	var receipt: Dictionary = panel.record_elsewhere("Bryn", "S6", 2, 0)
	assert_bool(bool(receipt.get("victory", false))).is_true()
	assert_int(int(core.coop.support_pool)).is_equal(5)
	assert_str(_labels(panel)).contains("plus the resource stash of 4")
	# Ash has not fought: no End control, and the reason is on the page.
	assert_object(_button(panel, "EndOperationalTurn")).is_null()
	assert_str(_labels(panel)).contains("Still to fight this operational turn: Ash")
	# Ash reports a failed mission that drew 2 points from the pool.
	panel.record_elsewhere("Ash", "S4", 1, 2)
	assert_int(int(core.coop.support_pool)).is_equal(3)
	var end_btn := _button(panel, "EndOperationalTurn")
	assert_object(end_btn).is_not_null()
	_dm.queue_forced_result(ENEMY_MOVE, 40)
	_dm.queue_forced_result(ENEMY_MOVE, 40)
	end_btn.pressed.emit()
	assert_int(int(core.coop.op_turn)).is_equal(2)
	assert_str(_labels(panel)).contains("Ash rolled 40: Enemy sabotage!")


func test_the_in_flight_player_is_not_offered_on_the_record_form() -> void:
	var core := _coop_core()
	_stamp_mission(core, "S1")  # Ash's mission launched here, not yet debriefed
	assert_str(CoopView.in_flight_player(core)).is_equal("Ash")
	var panel := _map(core)
	var picker: OptionButton = panel._record_player
	assert_object(picker).is_not_null()
	var offered: Array = []
	for i in picker.item_count:
		offered.append(picker.get_item_text(i))
	assert_array(offered).is_equal(["Bryn"])


func test_the_map_page_lets_a_drag_reach_its_scroll() -> void:
	var core := _coop_core()
	var panel := _map(core)
	for _i in range(3):
		await get_tree().process_frame
	# get_children() without internals, as test_touch_scroll_sweep walks: an OptionButton's
	# own PopupMenu and a ScrollContainer's own scroll bars are the engine's, not the page's.
	var stops: Array[String] = []
	_collect_stops(panel, panel, stops)
	assert_array(stops).is_empty()
	# The premise: the walk reached the populated page (a sector card per sector).
	assert_int(panel.find_children("*", "PanelContainer", true, false).filter(
		func(n: Node) -> bool: return n.has_meta("sector_id")).size()).is_equal(6)


func _collect_stops(root: Node, n: Node, out: Array[String]) -> void:
	for child in n.get_children():
		if child is Control:
			var c := child as Control
			if c.mouse_filter == Control.MOUSE_FILTER_STOP \
					and not preload("res://src/ui/components/common/TouchScrollOpener.gd") \
					.keeps_its_gesture(c):
				out.append("%s @ %s" % [c.get_class(), root.get_path_to(c)])
		_collect_stops(root, child, out)


# ── The dashboard ────────────────────────────────────────────────────────────────

func test_the_dashboard_opens_the_map_only_for_a_coop_campaign() -> void:
	var gs: Node = get_tree().root.get_node("/root/GameState")
	var core := _coop_core()
	gs.current_campaign = core
	var dash: Node = (load(DASHBOARD_SCENE) as PackedScene).instantiate()
	add_child(dash)
	auto_free(dash)
	for _i in range(4):
		await get_tree().process_frame
	var cards: Array = dash.find_children("CoopMapCard", "", true, false)
	assert_int(cards.size()).is_equal(1)
	assert_str(_labels(cards[0])).contains("0 of 6 sectors cleared")
	cards[0].card_pressed.emit()
	assert_int(dash.find_children("CoopMapPanel", "", true, false).size()).is_equal(1)

	# The control: the same dashboard on a campaign that is not co-op has no such card.
	var plain = CoreScript.new()
	plain.campaign_name = "Plain T"
	plain.main_characters = core.main_characters.duplicate(true)
	gs.current_campaign = plain
	var dash2: Node = (load(DASHBOARD_SCENE) as PackedScene).instantiate()
	add_child(dash2)
	auto_free(dash2)
	for _i in range(4):
		await get_tree().process_frame
	assert_int(dash2.find_children("CoopMapCard", "", true, false).size()).is_equal(0)
