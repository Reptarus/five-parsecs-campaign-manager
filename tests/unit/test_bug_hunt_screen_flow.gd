extends GdUnitTestSuite
## What the Bug Hunt screens SAY and where they lead (Sprint U screen pass, 2026-10-28).
## test_bug_hunt_screen_fit.gd holds the geometry; this suite holds the content and the
## flow, which a fit check cannot see: a wrapped Core Rules step fits a phone perfectly.

const DashboardScript := preload("res://src/ui/screens/bug_hunt/BugHuntDashboard.gd")
const TransferPanelScript := preload(
	"res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")
const EquipmentPanelScript := preload(
	"res://src/ui/screens/bug_hunt/panels/BugHuntEquipmentPanel.gd")
const RefText := preload("res://src/ui/screens/bug_hunt/BugHuntReferenceText.gd")
const PhaseManagerRef := preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const ChecklistScript := preload("res://src/ui/components/battle/PreBattleChecklist.gd")
const GuideScript := preload("res://src/core/battle/BugHuntBattleGuide.gd")
const DisplayTextRef := preload("res://src/ui/components/common/DisplayText.gd")
const Populator := preload("res://tests/tools/screen_populator.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const TURN_SCENE := "res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn"
const DASHBOARD_SCENE := "res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn"
const PHONE := Vector2i(393, 851)
const TABLET := Vector2i(2560, 1600)

var _user_state: Dictionary
var _saved_campaign: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gsm := get_tree().root.get_node_or_null("/root/GameStateManager")
	if gsm:
		gsm.set_temp_data("bug_hunt_battle_result", null)
		gsm.set_temp_data("bug_hunt_battle_context", null)
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _settle() -> void:
	await get_tree().create_timer(0.3).timeout
	for _i in range(3):
		await get_tree().process_frame


func _mount(size: Vector2i, node: Node) -> Node:
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	auto_free(sv)
	sv.add_child(node)
	await _settle()
	return node


func _texts(root: Node, kind: String) -> PackedStringArray:
	var out := PackedStringArray()
	for n in root.find_children("*", kind, true, false):
		if (n as Control).is_visible_in_tree():
			out.append(str(n.get("text")))
	return out


## The Continue card said "Start the next campaign turn" in every state, including
## halfway through a turn. It now names where BugHuntTurnController._resume_turn() lands.
func test_continue_names_where_the_turn_resumes() -> void:
	var c := BugHuntCampaignCore.new()
	assert_str(DashboardScript.continue_text(c)).is_equal("Start turn 1")
	c.campaign_turn = 2
	c.current_turn_phase = PhaseManagerRef.Phase.NONE
	assert_str(DashboardScript.continue_text(c)).is_equal("Start turn 3")
	c.current_turn_phase = PhaseManagerRef.Phase.MISSION
	assert_str(DashboardScript.continue_text(c)).is_equal("Resume turn 2: Mission")
	c.current_turn_phase = BugHuntCampaignCore.PHASE_UNRECORDED
	assert_str(DashboardScript.continue_text(c)).is_equal(
		"Resume turn 2: Special Assignments")
	# Post-Battle with nothing to debrief resumes at the Mission, as _resume_turn() does.
	c.current_turn_phase = PhaseManagerRef.Phase.POST_BATTLE
	assert_str(DashboardScript.continue_text(c)).is_equal("Resume turn 2: Mission")
	c.current_mission = {"battle_result": {"won": true}}
	assert_str(DashboardScript.continue_text(c)).is_equal("Resume turn 2: Post-Battle")


## p.179 prints melee as "Brawl / – / 0". A Boarding Sword printed `0" · 0 shots`.
func test_a_melee_weapon_prints_as_brawl() -> void:
	var sword: Dictionary = RefText.weapon("boarding_sword")
	assert_bool(sword.is_empty()).override_failure_message(
		"no boarding_sword in bug_hunt_weapons.json").is_false()
	assert_str(DisplayTextRef.weapon_profile(sword)).is_equal("Brawl · Dmg +0")
	assert_str(RefText.profile(sword)).starts_with("Brawl · Dmg +0")
	assert_str(DisplayTextRef.weapon_profile(RefText.weapon("service_pistol"))) \
		.is_equal("14\" · 1 shot · Dmg +0")


## The Equipment step printed five profiles as literals beside the Mission step's
## data-driven copy. Every profile on it is now the data's.
func test_the_equipment_step_prints_the_data_profiles() -> void:
	var panel: Node = await _mount(PHONE, EquipmentPanelScript.new())
	var labels := _texts(panel, "Label")
	for wid in ["service_pistol", "combat_rifle", "shotgun", "boarding_sword", "hand_cannon"]:
		var line: String = RefText.profile(RefText.weapon(wid))
		assert_bool(line in labels).override_failure_message(
			"the Equipment step does not print %s as the data does: '%s'" % [wid, line]) \
			.is_true()
	var armor: Array = RefText.standard_armor()
	assert_bool(not armor.is_empty() and RefText.armor_line(armor[0]) in labels).is_true()


## Both dashboard callers call set_direction() BEFORE add_child(), when the panel has
## no step container. With no Five Parsecs save nothing redrew it: a blank page with no
## way back. Built here exactly as BugHuntDashboard._on_enlist_pressed() builds it.
func test_enlisting_with_no_save_shows_a_way_back() -> void:
	var panel: Node = TransferPanelScript.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_direction("enlist")
	var closed := [false]
	panel.transfer_closed.connect(func() -> void: closed[0] = true)
	await _mount(PHONE, panel)
	var buttons: Array = []
	for n in panel.find_children("*", "Button", true, false):
		if (n as Button).is_visible_in_tree():
			buttons.append(n)
	assert_bool(buttons.is_empty()).override_failure_message(
		"the enlist page is blank: no control on it").is_false()
	var cancel: Button = buttons[0]
	assert_str(cancel.text).is_equal("Cancel")
	var title_y: float = INF
	for n in panel.find_children("*", "Label", true, false):
		if (n as Label).text == "ENLIST INTO BUG HUNT":
			title_y = (n as Label).get_global_rect().position.y
	assert_float(cancel.get_global_rect().position.y).is_less(title_y)
	assert_bool(TransferPanelScript.empty_text("enlist", true)
		in _texts(panel, "Label")).is_true()
	cancel.pressed.emit()
	assert_bool(closed[0]).is_true()


## A source with nobody eligible ended at a bare "SELECT CHARACTER" header.
func test_a_squad_with_nobody_to_muster_out_says_so() -> void:
	var panel: Node = TransferPanelScript.new()
	panel.set_direction("muster_out")
	await _mount(PHONE, panel)
	panel.load_characters_from_array([{"name": "Grunt", "game_mode": "bug_hunt",
		"is_grunt": true}])
	await _settle()
	assert_bool(TransferPanelScript.empty_text("muster_out", false)
		in _texts(panel, "Label")).is_true()


## A Bug Hunt battle got the Core Rules checklist: the p.88 and p.89 tables and a Seize
## the Initiative roll that Bug Hunt does not have. It now gets p.184's own steps.
func test_a_bug_hunt_battle_sets_up_by_its_own_steps() -> void:
	var md := {"battle_mode": "bug_hunt", "objectives": [{}, {}, {}]}
	var bh: Node = ChecklistScript.new()
	bh.set_setup_steps(GuideScript.setup_checklist(md))
	await _mount(PHONE, bh)
	bh.set_tier(1)
	var steps := _texts(bh, "CheckBox")
	assert_array(Array(steps)).contains(["Step 1: Set up battle area",
		"Step 9: Set up your troops"])
	for core in ["Roll deployment conditions", "Check for Notable Sighting",
			"Seize Initiative roll"]:
		assert_bool(core in steps).override_failure_message(
			"a Bug Hunt battle still lists the Core Rules step '%s'" % core).is_false()
	var hints := "\n".join(_texts(bh, "Label"))
	var missions: Dictionary = GuideScript._load_json(GuideScript.MISSIONS_PATH)
	assert_str(hints).contains(str(missions.deployment.description))
	assert_str(hints).contains(str(missions.battle_area.description))
	assert_str(hints).contains("Keep the 3")


## The Alpha-1 arm: a 5PFH battle keeps the Core Rules list.
func test_a_five_parsecs_battle_keeps_the_core_rules_steps() -> void:
	var core: Node = ChecklistScript.new()
	await _mount(PHONE, core)
	core.set_tier(1)
	var steps := _texts(core, "CheckBox")
	assert_bool("Roll deployment conditions" in steps).is_true()
	assert_bool("Seize Initiative roll" in steps).is_true()


## Called after _ready(), the swap replaces only the step rows: a reminder appended
## later (add_species_reminders() and its siblings) survives, and the new steps land
## where the old ones were.
func test_swapping_steps_after_ready_keeps_appended_rows() -> void:
	var cl: Node = ChecklistScript.new()
	await _mount(PHONE, cl)
	var reminder := Label.new()
	reminder.name = "AppendedReminder"
	cl._vbox.add_child(reminder)
	var first_step_at: int = cl._vbox.get_node("Item_setup_terrain").get_index()
	cl.set_setup_steps(GuideScript.setup_checklist({}))
	await get_tree().process_frame
	assert_object(cl._vbox.get_node_or_null("AppendedReminder")).is_not_null()
	assert_object(cl._vbox.get_node_or_null("Item_setup_terrain")).is_null()
	assert_int(cl._vbox.get_node("Item_bh_battle_area").get_index()).is_equal(first_step_at)


## The debrief stays on screen as the turn's record once completed; a box ticked now
## would change nothing, so every control locks.
func test_post_battle_locks_once_completed() -> void:
	Populator.new(get_tree().root)._pre_bug_hunt()
	var tc: Node = await _mount(PHONE, (load(TURN_SCENE) as PackedScene).instantiate())
	for _i in range(8):
		await get_tree().process_frame
	tc.panels[0].complete()
	await _settle()
	var mp: Node = tc.panels[1]
	mp._generate_mission()
	await _settle()
	mp._mission_context["participant_ids"] = mp._participant_ids.duplicate()
	mp._persist_stamped_mission()
	tc._resume_after_battle({"victory": true, "won": true, "held_field": true,
		"rounds_fought": 5, "crew_casualties": 0, "crew_casualties_data": [],
		"crew_injuries": 0, "crew_injuries_data": [], "enemies_defeated_count": 4,
		"auto_resolved": false})
	await _settle()
	var pb: Node = tc.panels[2]
	pb._process_post_battle()
	await _settle()
	pb.complete()
	await _settle()
	var live := PackedStringArray()
	for n in pb._content_container.find_children("*", "BaseButton", true, false):
		if not (n as BaseButton).disabled:
			live.append(str(n.get("text")))
	assert_array(Array(live)).override_failure_message(
		"still pressable after the turn ended: %s" % ", ".join(live)).is_empty()
	assert_str(pb._complete_btn.text).is_equal("Post-Battle complete")


## On a tablet the turn stages ran 2560 px wide; the dashboard did too. Both now sit in
## a centred column no wider than MAX_FORM_WIDTH.
func test_a_tablet_gets_a_centred_column() -> void:
	Populator.new(get_tree().root)._pre_bug_hunt()
	var tc: Node = await _mount(TABLET, (load(TURN_SCENE) as PackedScene).instantiate())
	for _i in range(8):
		await get_tree().process_frame
	var sa: Control = tc.panels[0]
	var r: Rect2 = sa.get_global_rect()
	assert_float(r.size.x).is_less_equal(800.5)
	assert_float(absf(r.get_center().x - TABLET.x / 2.0)).is_less(2.0)
	var dash: Node = await _mount(TABLET,
		(load(DASHBOARD_SCENE) as PackedScene).instantiate())
	var title: Label = null
	for n in dash.find_children("*", "Label", true, false):
		if (n as Label).text == "Sweep fixture":
			title = n
	assert_object(title).is_not_null()
	assert_float(title.get_global_rect().size.x).is_less_equal(800.5)


## The dashboard as a player reads it: the Continue line names where the turn resumes,
## the ten Movie Magic cards and the grunt profile are the data's, and the stat tiles
## are words. Rendered on screen, not only computed: the Continue subtitle was a literal
## beside a correct helper would still pass a static-only case.
func test_the_dashboard_reads_its_lines_from_the_campaign_and_the_data() -> void:
	Populator.new(get_tree().root)._pre_bug_hunt()
	var gs := get_tree().root.get_node("/root/GameState")
	# A grunt pool from the real generator, so the Grunt Pool card draws its profile row
	# (an empty pool says "No grunts in pool" instead).
	var gen = load("res://src/core/character/BugHuntCharacterGeneration.gd").new()
	gs.current_campaign.grunts.append_array(gen.generate_fire_team(4))
	var dash: Node = await _mount(PHONE, (load(DASHBOARD_SCENE) as PackedScene).instantiate())
	var labels := _texts(dash, "Label")
	var expected: String = DashboardScript.continue_text(gs.current_campaign)
	assert_bool(expected in labels).override_failure_message(
		"the Continue card does not say '%s'" % expected).is_true()
	for row in BugHuntCampaignCore.movie_magic_abilities():
		assert_bool(str(row.name) in labels).override_failure_message(
			"Movie Magic '%s' is not the data's name" % str(row.name)).is_true()
	assert_bool(RefText.grunt_profile_line() in labels).override_failure_message(
		"the grunt profile is not the data's: '%s'" % RefText.grunt_profile_line()).is_true()
	assert_str(RefText.grunt_profile_line()).is_equal(
		"React 1 · Spd 4\" · CS +0 · Tough 4 · Savvy +0")
	for tile in ["SQUAD", "MOVIE MAGIC", "REPUTATION"]:
		assert_bool(tile in labels).override_failure_message(
			"no '%s' stat tile" % tile).is_true()


## p.201 Evac reached no screen: the census had counted a Movie Magic literal as its
## reader. It is now on the Battle Card and in the end-of-round prompts, from data.
func test_evac_is_on_the_card_and_in_the_round_prompts() -> void:
	var evac: Dictionary = GuideScript.evac_rules()
	assert_bool(evac.is_empty()).override_failure_message("no evac block in the data") \
		.is_false()
	var opens: int = int(evac.available_from_round)
	var card: Array = GuideScript.briefing_rows({})
	var row: Dictionary = {}
	for r in card:
		if str(r.head).begins_with("Evac"):
			row = r
	assert_str(str(row.get("head", ""))).contains("Round %d" % opens)
	assert_str(str(row.get("detail", ""))).contains("%d+" % int(evac.success_threshold))
	assert_str(str(row.get("detail", ""))).contains(str(evac.supporting_fire))
	var texts := func(n: int) -> String:
		var out := PackedStringArray()
		for p in GuideScript.round_end_prompts(n, {}):
			out.append(str(p.text))
		return "\n".join(out)
	assert_str(texts.call(opens - 2)).not_contains("Evac")
	assert_str(texts.call(opens - 1)).contains("From Round %d you can request Evac" % opens)
	assert_str(texts.call(opens + 1)).contains("Evac called and not yet here?")
