extends GdUnitTestSuite

## Full-screen overlays laid over another screen: the Planetfall dashboard's six detail
## panels, and the transfer pages of three modes (Muster Out, Import, Commission).
##
## ⚠ Until 2026-10-28 no capture, sweep or layout check had ever rendered one. The first
## render showed four of the six Planetfall overlays with NO background, drawn straight
## over the dashboard; all of them flush against the left edge and running past the right
## of a phone; and their titles under the Settings buttons. The five transfer pages set
## margin_left/right on a ScrollContainer, a type with no theme constants at all, so the
## gutter they asked for never existed. Every case here measures where the page LANDS on
## a phone-sized and a tablet-sized screen, never what a builder was asked to do.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const DashboardScene = preload("res://src/ui/screens/planetfall/PlanetfallDashboard.tscn")
const PlanetfallImport = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd")
const BugHuntTransfer = preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")
const TacticsImport = preload("res://src/ui/screens/tactics/panels/TacticsVeteranImportPanel.gd")
const EndGamePanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallEndGamePanel.gd")
const EnemyGenerator = preload("res://src/core/systems/PlanetfallTacticalEnemyGenerator.gd")
const AugmentationPanel = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallAugmentationPanel.gd")
const DisplayTextRef = preload("res://src/ui/components/common/DisplayText.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const PHONE := Vector2i(338, 734)
const TABLET := Vector2i(1728, 1080)
const OVERLAYS := ["colony_status", "equipment", "enemy_tracker", "augmentation",
		"milestones", "calamities"]

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


func _core(milestones: int = 0) -> Resource:
	var core = CoreScript.new()
	core.campaign_name = "Haven"
	core.colony_name = "Haven"
	core.game_phase = "active"
	core.campaign_turn = 2
	core.milestones_completed = milestones
	MapScript.generate(core, 6, 6, [2, 2], 0)
	core.roster = [{"id": "a", "name": "Ada Voss", "class": "scientist", "reactions": 1,
		"speed": 4, "combat_skill": 0, "toughness": 3, "savvy": 1, "xp": 0, "kp": 0,
		"loyalty": "committed"}]
	return core


func _viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	auto_free(sv)
	return sv


func _frames(n: int = 3) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _dashboard(size: Vector2i, core: Resource) -> Control:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var dash: Control = DashboardScene.instantiate()
	_viewport(size).add_child(dash)
	await _frames(3)
	return dash


## The band the Settings and bug-report buttons need, or the gutter when they are absent.
func _top_floor() -> float:
	var so := get_tree().root.get_node_or_null("/root/SettingsOverlay")
	var band: float = so.get_reserved_bottom() if so and so.has_method("get_reserved_bottom") \
		else 0.0
	return maxf(band, float(ScreenChrome.OVERLAY_GUTTER)) - 0.5


## What is wrong with a page that should fill `width` with a gutter each side.
func _faults(where: String, host: Control, column: Control, width: float) -> Array[String]:
	var out: Array[String] = []
	var bg := host.get_node_or_null(NodePath(ScreenChrome.BACKGROUND_NAME))
	if not (bg is ColorRect) or (bg as ColorRect).color.a < 0.999:
		out.append("%s: no opaque page behind it" % where)
	var rect: Rect2 = column.get_global_rect()
	var gutter: float = float(ScreenChrome.OVERLAY_GUTTER) - 0.5
	if rect.position.x < gutter:
		out.append("%s: starts at x=%.0f, inside the %d px gutter"
			% [where, rect.position.x, ScreenChrome.OVERLAY_GUTTER])
	if rect.end.x > width - gutter:
		out.append("%s: ends at x=%.0f on a %.0f px screen" % [where, rect.end.x, width])
	out.append_array(_edge_faults(where, host, width))
	return out


## ⚠ Measure every scroll against the SCREEN edge: a scroll whose horizontal axis is
## disabled grows to its page's minimum, so "page fits its scroll" is always true.
func _edge_faults(where: String, host: Control, width: float) -> Array[String]:
	var out: Array[String] = []
	for s in host.find_children("*", "ScrollContainer", true, false):
		if (s as Control).is_visible_in_tree() \
				and (s as Control).get_global_rect().end.x > width + 0.5:
			out.append("%s: a scroll runs to x=%.0f; widest leaf %s"
				% [where, (s as Control).get_global_rect().end.x, _widest_leaf(s)])
		if (s as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			out.append("%s: the page scrolls sideways" % where)
	return out


## Walk the min-width spine down to a leaf, so a failure names its cause: an overflow
## figure only names the outermost consequence.
func _widest_leaf(from: Node) -> String:
	var node: Node = from
	var path: Array[String] = []
	while node != null:
		var widest: Control = null
		for c in node.get_children():
			if c is Control and (c as Control).visible and (widest == null
					or (c as Control).get_combined_minimum_size().x
					> widest.get_combined_minimum_size().x):
				widest = c
		if widest == null:
			break
		path.append("%s %.0f" % [widest.get_class(), widest.get_combined_minimum_size().x])
		node = widest
	var leaf_text: String = str(node.get("text")).substr(0, 40) if node and "text" in node \
		else ""
	return "%s '%s'" % [" > ".join(path), leaf_text]


## Every dashboard overlay on a phone and a tablet: the page colour behind it, a gutter
## each side, a top below the Settings buttons, and nothing past the screen edge.
func test_every_dashboard_overlay_is_framed() -> void:
	var faults: Array[String] = []
	for size: Vector2i in [PHONE, TABLET]:
		var dash: Control = await _dashboard(size, _core(7))
		assert_object(dash._overlay_frame).override_failure_message(
			"premise: the dashboard built its overlay frame").is_not_null()
		for overlay: String in OVERLAYS:
			dash._show_overlay_panel(overlay)
			await _frames(3)
			assert_int(dash._overlay_frame.get_child_count()).override_failure_message(
				"premise: %s mounted" % overlay).is_equal(1)
			var panel: Control = dash._overlay_frame.get_child(0)
			var where := "%s at %dx%d" % [overlay, size.x, size.y]
			faults.append_array(_faults(where, dash._overlay_container, panel, size.x))
			if panel.get_global_rect().position.y < _top_floor():
				faults.append("%s: its top (y=%.0f) is under the Settings buttons"
					% [where, panel.get_global_rect().position.y])
	assert_array(faults).override_failure_message("\n".join(faults)).is_empty()


## The Armory card prints the profile the way Lock and Load does, and its traits get the
## card's width (they wrapped one letter per line beside two other columns).
func test_the_armory_card_reads_like_lock_and_load() -> void:
	var dash: Control = await _dashboard(PHONE, _core())
	dash._show_overlay_panel("equipment")
	await _frames(3)
	var texts: Array[String] = []
	var traits: Label = null
	for lbl in dash._overlay_frame.find_children("*", "Label", true, false):
		texts.append((lbl as Label).text)
		if (lbl as Label).text == "Civilian, Pistol":
			traits = lbl
	assert_bool(texts.has("6\" · 1 shot · Dmg +0")).override_failure_message(
		"the Handgun's profile line is missing: %s" % str(texts.slice(0, 8))).is_true()
	assert_bool(texts.any(func(t: String) -> bool: return t.contains("R:") \
		or t.contains(".0 "))).override_failure_message("a raw float profile is back") \
		.is_false()
	assert_object(traits).override_failure_message("premise: the Handgun's traits line") \
		.is_not_null()
	assert_float(traits.size.x).override_failure_message(
		"the traits line is %.0f px wide" % traits.size.x).is_greater(150.0)


## The milestone bar fills a share of ITSELF: at 7/7 it is exactly full, on any width.
func test_the_milestone_bar_fills_a_share_of_the_bar() -> void:
	for size: Vector2i in [PHONE, TABLET]:
		var dash: Control = await _dashboard(size, _core(7))
		dash._show_overlay_panel("colony_status")
		await _frames(3)
		var fills: Array = dash._overlay_frame.find_children("*", "ColorRect", true, false) \
			.filter(func(c: Node) -> bool: return c.get_parent() is ColorRect)
		assert_int(fills.size()).override_failure_message("premise: one bar fill") \
			.is_equal(1)
		var fill: ColorRect = fills[0]
		var bar: ColorRect = fill.get_parent()
		assert_float(fill.size.x).override_failure_message(
			"7/7 fills %.0f of a %.0f px bar at %dx%d" % [fill.size.x, bar.size.x, size.x, size.y]) \
			.is_equal_approx(bar.size.x, 0.5)


## The Planetfall Muster Out page and the three import/transfer panels, on a phone.
##
## ⚠ Each page is measured FILLED. Until 2026-10-28 this case built the panels and never
## loaded a source, so Step 1 was never drawn and the case was green while the first
## render showed the Planetfall Import page running off the right of a phone: its title,
## its explanation header and its "No eligible veterans" line did not wrap. A fresh device
## has no veterans, so the EMPTY Step 1 is the state most players see first.
func test_every_transfer_page_is_framed_on_a_phone() -> void:
	var faults: Array[String] = []
	var dash: Control = await _dashboard(PHONE, _core())
	# Built before it is in the tree, as the dashboard builds it.
	var muster: Control = dash._build_muster_out_overlay(dash._campaign.roster)
	dash.get_parent().add_child(muster)
	await _frames(3)
	faults.append_array(_page_faults("Planetfall Muster Out", muster,
		muster.find_children("*", "VBoxContainer", true, false)[0]))

	var veteran := {"id": "v1", "character_id": "v1", "status": "ACTIVE",
		"name": "Commander Anastasia Featherstonehaugh-Vance",
		"character_name": "Commander Anastasia Featherstonehaugh-Vance",
		"reaction": 1, "speed": 4, "combat": 1, "toughness": 3, "savvy": 0, "luck": 1,
		"_source_mode": "five_parsecs", "_source_path": "user://saves/none.save"}
	for entry in [["Planetfall Import", PlanetfallImport], ["Bug Hunt transfer", BugHuntTransfer],
			["Tactics Commission", TacticsImport]]:
		var panel: Control = (entry[1] as GDScript).new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_viewport(PHONE).add_child(panel)
		var states: Array = [["empty Step 1", []], ["Step 1", [veteran.duplicate(true)]]]
		for state in states:
			if panel.has_method("load_characters_from_array"):
				panel.load_characters_from_array(state[1])
			else:
				panel._source_characters = state[1]
				panel._show_step_1()
			await _frames(3)
			assert_int(panel._step_container.get_child_count()).override_failure_message(
				"premise: %s drew its %s" % [entry[0], state[0]]).is_greater(1)
			faults.append_array(_page_faults("%s, %s" % [entry[0], state[0]], panel,
				panel._content))
		panel._show_step_2(veteran.duplicate(true))
		await _frames(3)
		faults.append_array(_page_faults("%s, Step 2" % entry[0], panel, panel._content))
	assert_array(faults).override_failure_message("\n".join(faults)).is_empty()


## The End Game on a phone, at the two stages whose buttons carry book text (pp.160-163):
## all four paths with their costs and an unmet security note, and Loyalty's two dice when
## one is a rolled 2, "Staging ground for continued colonization missions". The path
## buttons ran past a phone and dragged the whole stage off-centre (`pf_port14`).
## The End Game replaces the turn's step panels rather than lying over a screen, so only
## the screen edge is checked, not a page colour or gutter of its own.
func test_the_end_game_fits_a_phone() -> void:
	var panel: Control = EndGamePanelScript.new()
	panel.set_campaign(_core(7))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport(PHONE).add_child(panel)
	await _frames(2)
	var faults: Array[String] = []
	panel._summit_results = {"votes": {}, "individual_votes": [],
		"available_paths": ["independence", "ascension", "loyalty", "isolation"]}
	panel._go_to(EndGamePanelScript.Stage.PATH_SELECTION)
	await _frames(3)
	assert_int(panel._content.find_children("*", "Button", true, false).size()) \
		.override_failure_message("premise: four path buttons").is_equal(4)
	faults.append_array(_edge_faults("End Game paths", panel, PHONE.x))
	panel._selected_path = "loyalty"
	panel._colony_future_dice = [2, 5]
	panel._go_to(EndGamePanelScript.Stage.RESOLUTION)
	await _frames(3)
	assert_bool(panel._content.find_children("*", "Button", true, false).any(
		func(b: Node) -> bool: return (b as Button).text.begins_with("2: Staging ground"))) \
		.override_failure_message("premise: the rolled 2 is offered").is_true()
	faults.append_array(_edge_faults("End Game Loyalty dice", panel, PHONE.x))
	assert_array(faults).override_failure_message("\n".join(faults)).is_empty()


## Every dashboard overlay can be left the moment it opens. Four put Close at the foot of
## their content, so a phone had to scroll the eight Augmentation cards to the end before
## it could leave, and Muster Out's Cancel sat below the whole roster.
func test_every_overlay_can_be_closed_without_scrolling() -> void:
	var faults: Array[String] = []
	var roster: Array = []
	for i in range(12):
		roster.append({"id": "c%d" % i, "name": "Colonist %d" % i})
	for size: Vector2i in [PHONE, TABLET]:
		# Three Tactical Enemies from the real generator (p.50: one at each of Milestones
		# 1-3), so the tracker is as tall as a mid-campaign colony's.
		var core := _core(7)
		var generator = EnemyGenerator.new()
		for _i in range(3):
			core.add_tactical_enemy(generator.create_full_enemy(core))
		var dash: Control = await _dashboard(size, core)
		for overlay: String in OVERLAYS:
			dash._show_overlay_panel(overlay)
			await _frames(3)
			faults.append_array(_exit_faults("%s at %dx%d" % [overlay, size.x, size.y],
				dash._overlay_frame, "Close", size))
		dash._overlay_container.visible = false
		var muster: Control = dash._build_muster_out_overlay(roster)
		dash.get_parent().add_child(muster)
		await _frames(3)
		faults.append_array(_exit_faults("Muster Out at %dx%d" % [size.x, size.y], muster,
			"Cancel", size))
		muster.queue_free()
	assert_array(faults).override_failure_message("\n".join(faults)).is_empty()
	# As a turn step the same button is the step's Continue, and that stays last.
	var step: Control = AugmentationPanel.new()
	_viewport(PHONE).add_child(step)
	await _frames(2)
	var box: Node = step._close_btn.get_parent()
	assert_int(step._close_btn.get_index()).override_failure_message(
		"the turn step's Continue moved off the end").is_equal(box.get_child_count() - 1)


## An exit that is on screen, below the Settings buttons, without scrolling.
func _exit_faults(where: String, host: Node, text: String, size: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var exits: Array = host.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).text == text and (b as Button).is_visible_in_tree())
	if exits.is_empty():
		return ["%s: no %s button" % [where, text]]
	var r: Rect2 = (exits[0] as Button).get_global_rect()
	if r.end.y > size.y or r.position.y < _top_floor():
		out.append("%s: %s is at y=%.0f-%.0f on a %d px screen" % [where, text,
			r.position.y, r.end.y, size.y])
	return out


## A transfer page's faults on a phone, including a top under the Settings buttons.
func _page_faults(where: String, host: Control, column: Control) -> Array[String]:
	var out := _faults(where, host, column, PHONE.x)
	if column.get_global_rect().position.y < _top_floor():
		out.append("%s: its top (y=%.0f) is under the Settings buttons"
			% [where, column.get_global_rect().position.y])
	return out


## The Milestones checklist names each source as its data spells it (p.156), and colours
## a row by ITS state: owning one source used to turn every row green.
func test_the_milestone_checklist_reads_names_and_colours_each_row() -> void:
	var core := _core()
	core.buildings_data["constructed"] = ["orbital_facility"]
	var dash: Control = await _dashboard(PHONE, core)
	dash._show_overlay_panel("milestones")
	await _frames(3)
	var rows: Dictionary = {}
	for lbl in dash._overlay_frame.find_children("*", "Label", true, false):
		var t: String = (lbl as Label).text
		if t.begins_with("[x]") or t.begins_with("[ ]"):
			rows[t] = (lbl as Label).get_theme_color("font_color")
	assert_bool(rows.has("[x]  Orbital Facility (Building)")).override_failure_message(
		"premise: the owned building's row: %s" % str(rows.keys())).is_true()
	assert_bool(rows.has("[ ]  Integrated Post-Organic Demarcation (Research Application)")) \
		.override_failure_message("the application is not named as its data spells it: %s"
		% str(rows.keys())).is_true()
	assert_object(rows["[x]  Orbital Facility (Building)"]).is_equal(UIColors.COLOR_EMERALD)
	assert_object(rows["[ ]  Galactic Comms Relay (Building)"]) \
		.override_failure_message("an unowned row is green").is_not_equal(UIColors.COLOR_EMERALD)


## The one weapon line three screens share.
func test_weapon_profile_prints_whole_numbers_and_words() -> void:
	assert_str(DisplayTextRef.weapon_profile({"range": 6.0, "shots": 1.0, "damage": 0.0})) \
		.is_equal("6\" · 1 shot · Dmg +0")
	assert_str(DisplayTextRef.weapon_profile({"range": 18, "shots": 2, "damage": 1})) \
		.is_equal("18\" · 2 shots · Dmg +1")
