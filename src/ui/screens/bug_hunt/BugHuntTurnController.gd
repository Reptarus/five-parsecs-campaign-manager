extends "res://src/ui/screens/bug_hunt/BugHuntScreenBase.gd"

## Bug Hunt Campaign Turn Controller
## Manages the 3-stage turn flow: Special Assignments → Mission → Post-Battle
## Each stage has a dedicated panel displayed in the main area.

const BugHuntPhaseManagerScript := preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const SpecialAssignmentsScript := preload("res://src/ui/screens/bug_hunt/panels/SpecialAssignmentsPanel.gd")
const MissionPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const PostBattlePanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
## The Bug Hunt post-battle chokepoint. The battle return is where the stamp and
## the battle facts first meet, so the result is normalized HERE rather than being
## handed to the panel raw -- the panel calls the same function again once the
## player has made the debrief, and the normalizer is add-only so the two compose.
const BugHuntResultNormalizer = preload("res://src/core/battle/BugHuntBattleResultNormalizer.gd")

## COLOR_BASE / COLOR_ELEVATED / COLOR_ACCENT / COLOR_BORDER / COLOR_SUCCESS are
## NOT redeclared here: CampaignScreenBase already defines all five from this same
## UIColors source, and a const that shadows a base const is a PARSE error, not a
## shadow warning -- which would take this whole screen down. Only the two local
## aliases the base has no name for are kept.
const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY

var phase_manager: BugHuntPhaseManagerScript
var campaign: Resource  # BugHuntCampaignCore
var panels: Array[Control] = []
var current_panel: Control

var _turn_label: Label
var _phase_label: Label
var _reputation_label: Label
var _advance_button: Button
var _save_button: Button
var _panel_container: Control
var _phase_indicators: Array[Label] = []

# Responsive top-bar wiring (portrait-collapse support)
var _phase_strip_scroll: ScrollContainer
var _phase_box: HBoxContainer


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	## super FIRST, or this screen loses every responsive signal the base wires
	## (the regression CampaignScreenBase._ready() documents at :100-102).
	super._ready()
	# Defer initialization — scene may not be in tree yet when
	# instantiated by TransitionManager.fade_to_scene()
	#
	# ⚠ The base ALSO queues a deferred touch sweep, and it queues it before this
	# line runs, so that one sweeps a tree _initialize() has not built yet. The
	# sweeps that matter are the explicit ones below, after each build.
	call_deferred("_initialize")


func _initialize() -> void:
	# Deferred from _ready(), so it lands a frame later and this controller may
	# already have left the tree. The /root campaign lookups below ERROR from a
	# detached node rather than returning null, and the turn would initialise
	# against no campaign at all. Same guard as the other deferred entry points.
	if not is_inside_tree():
		return
	_load_campaign()
	if not campaign:
		return  # _load_campaign already navigated to main_menu
	_build_layout()
	_create_phase_manager()
	_create_panels()
	_connect_signals()
	_setup_responsive_topbar()
	_fix_touch_scroll_filters()

	# Check if returning from battle
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	var battle_result = null
	if gs_mgr and gs_mgr.has_method("get_temp_data"):
		battle_result = gs_mgr.get_temp_data("bug_hunt_battle_result")

	if battle_result is Dictionary and not battle_result.is_empty():
		# Returning from battle — fast-forward to post-battle
		_resume_after_battle(battle_result)
		# Clear temp data so we don't re-trigger
		if gs_mgr.has_method("set_temp_data"):
			gs_mgr.set_temp_data("bug_hunt_battle_result", null)
	elif campaign:
		_resume_turn()


func _resume_turn() -> void:
	## Pick up where the save left off.
	##
	## BugHuntCampaignCore.current_turn_phase is written on EVERY transition by
	## BugHuntPhaseManager._persist_phase(), so unlike the pre-field behaviour this no
	## longer drops the player back at Special Assignments on every reload.
	var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 0
	if turn <= 0:
		phase_manager.start_new_turn()
		return

	var stored: int = BugHuntCampaignCore.PHASE_UNRECORDED
	if "current_turn_phase" in campaign:
		stored = int(campaign.current_turn_phase)

	## campaign_turn increments at turn START (BugHuntCampaignCore.advance_turn), so the
	## stored number already identifies the turn IN PROGRESS. Do NOT copy 5PFH's "-1" on
	## restore (T11-20): there turns_played counts COMPLETED turns, a different quantity.
	phase_manager.turn_number = turn
	phase_manager.campaign_turn_started.emit(turn)

	match stored:
		BugHuntPhaseManagerScript.Phase.NONE:
			## The turn ENDED before the save. Restore the between-turns footer rather
			## than reopening a phase -- pressing Start Next Turn opens turn N+1. The
			## panel area stays blank on purpose: re-showing the post-battle panel would
			## run its refresh() against a battle result this save does not carry, and
			## its fallback INVENTS casualties when it has none.
			phase_manager.current_phase = BugHuntPhaseManagerScript.Phase.NONE
			_on_turn_completed(turn)
		BugHuntPhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS:
			phase_manager.go_to_phase(stored)
		BugHuntPhaseManagerScript.Phase.MISSION:
			phase_manager.go_to_phase(stored)
		BugHuntPhaseManagerScript.Phase.POST_BATTLE:
			## The scored battle result rides on campaign.current_mission (written by
			## BugHuntPostBattlePanel._persist_battle_result), so the debrief can be
			## resumed. Without one there is nothing to debrief -- and the panel no
			## longer invents casualties to fill the gap -- so fall back to Mission.
			if _has_persisted_battle_result():
				phase_manager.go_to_phase(BugHuntPhaseManagerScript.Phase.POST_BATTLE)
			else:
				phase_manager.go_to_phase(BugHuntPhaseManagerScript.Phase.MISSION)
		_:
			## PHASE_UNRECORDED (a save written before the field existed), or a value
			## from a newer build. Keep the pre-field behaviour: replay from the top of
			## the turn once, and be correct from the next transition onwards.
			phase_manager.go_to_phase(BugHuntPhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS)


func _has_persisted_battle_result() -> bool:
	if campaign == null or not ("current_mission" in campaign):
		return false
	var cm: Variant = campaign.current_mission
	if not (cm is Dictionary):
		return false
	var stored: Variant = (cm as Dictionary).get("battle_result", null)
	return stored is Dictionary and not (stored as Dictionary).is_empty()


func _load_campaign() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		campaign = gs.get_current_campaign() if gs.has_method("get_current_campaign") else null
		if not campaign and "current_campaign" in gs:
			campaign = gs.current_campaign

	# Validate campaign is BugHuntCampaignCore (has main_characters property)
	if campaign and not "main_characters" in campaign:
		push_warning("BugHuntTurnController: Campaign is not BugHuntCampaignCore (missing main_characters). Routing to main menu.")
		campaign = null
		var router = get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("main_menu")


func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Top bar: turn info + phase indicators + save
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	vbox.add_child(top_bar)

	_turn_label = Label.new()
	_turn_label.text = "TURN 1"
	_turn_label.add_theme_font_size_override("font_size", _scaled_font(22))
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT)
	top_bar.add_child(_turn_label)

	# Phase progress indicators — wrapped in a ScrollContainer so the strip can
	# shrink and scroll horizontally on narrow (portrait) viewports instead of
	# forcing the top bar wider than the screen.
	_phase_strip_scroll = ScrollContainer.new()
	_phase_strip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_phase_strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_bar.add_child(_phase_strip_scroll)

	var phase_box := HBoxContainer.new()
	phase_box.add_theme_constant_override("separation", 8)
	phase_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_box = phase_box
	_phase_strip_scroll.add_child(phase_box)

	var phase_names := ["Special Assignments", "Mission", "Post-Battle"]
	for i in range(3):
		var indicator := Label.new()
		indicator.text = "%d. %s" % [i + 1, phase_names[i]]
		indicator.add_theme_font_size_override("font_size", _scaled_font(14))
		indicator.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		phase_box.add_child(indicator)
		_phase_indicators.append(indicator)

	_reputation_label = Label.new()
	_reputation_label.add_theme_font_size_override("font_size", _scaled_font(14))
	_reputation_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_update_reputation_display()
	top_bar.add_child(_reputation_label)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(80, 36)
	_save_button.pressed.connect(_on_save_pressed)
	top_bar.add_child(_save_button)

	# Current phase label
	_phase_label = Label.new()
	_phase_label.text = "SPECIAL ASSIGNMENTS"
	_phase_label.add_theme_font_size_override("font_size", _scaled_font(24))
	_phase_label.add_theme_color_override("font_color", COLOR_TEXT)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_label)

	# Panel container
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Bottom navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_advance_button = Button.new()
	_advance_button.text = "Complete Phase"
	_advance_button.custom_minimum_size = Vector2(0, 48)
	_advance_button.pressed.connect(_on_advance_pressed)
	nav.add_child(_advance_button)


## Connect to the ResponsiveManager so the top bar collapses on portrait phones,
## then apply the current layout once for a correct baseline (the signal is not
## emitted at autoload boot). Landscape/desktop behavior is unchanged.
func _setup_responsive_topbar() -> void:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		if not rm.layout_class_changed.is_connected(_on_topbar_layout_class_changed):
			rm.layout_class_changed.connect(_on_topbar_layout_class_changed)
	_apply_topbar_responsive()


## Deliberately NOT named _on_layout_class_changed: that is CampaignScreenBase's
## own handler (:463), and an override with the same signature would REPLACE the
## base relayout rather than add to it. Two distinct callables, two connections,
## each doing its own job.
func _on_topbar_layout_class_changed(_effective_columns: int) -> void:
	_apply_topbar_responsive()


## Portrait phones: hide the wide centered phase label (the scrollable phase strip
## already shows the current stage) and bump the Save button to a full 48px touch
## target. Landscape/tablet/desktop: restore the exact original layout.
func _apply_topbar_responsive() -> void:
	var rm := get_node_or_null("/root/ResponsiveManager")
	var portrait := false
	if rm and rm.has_method("should_collapse_to_single_column"):
		portrait = rm.should_collapse_to_single_column()

	if is_instance_valid(_phase_label):
		# Keep the big centered phase label only when there's room for it.
		_phase_label.visible = not portrait

	if is_instance_valid(_save_button):
		# The touch target is DEVICE-keyed, not orientation-keyed: the thumb does not
		# get smaller when the phone is turned sideways (SOP responsive-adaptive-ui
		# gotcha 6). This used to drop to 36px in landscape, under the 48dp floor, on
		# the only button in the bar. The 80px WIDTH floor goes with it — a width
		# floor stops the button shrinking with its container and propagates upward.
		_save_button.custom_minimum_size = Vector2(0, 48)

	# The phase strip stays visible in both modes; its ScrollContainer already
	# allows it to shrink/scroll horizontally when the bar is too narrow.


func _create_phase_manager() -> void:
	phase_manager = BugHuntPhaseManagerScript.new()
	phase_manager.name = "BugHuntPhaseManager"
	add_child(phase_manager)
	phase_manager.setup(campaign)


func _create_panels() -> void:
	var assignments_panel: Control = SpecialAssignmentsScript.new()
	var mission_panel: Control = MissionPanelScript.new()
	var post_battle_panel: Control = PostBattlePanelScript.new()

	panels = [assignments_panel, mission_panel, post_battle_panel]

	for panel in panels:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel_container.add_child(panel)
		panel.hide()

		if panel.has_method("set_campaign"):
			panel.set_campaign(campaign)
		if panel.has_method("set_phase_manager"):
			panel.set_phase_manager(phase_manager)


func _connect_signals() -> void:
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.phase_completed.connect(_on_phase_completed)
	phase_manager.campaign_turn_started.connect(_on_turn_started)
	phase_manager.campaign_turn_completed.connect(_on_turn_completed)
	phase_manager.navigation_updated.connect(_on_navigation_updated)

	# Panel completion signals
	for panel in panels:
		if panel.has_signal("phase_completed"):
			panel.phase_completed.connect(_on_panel_phase_completed)


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	_show_panel(new_phase)
	_update_phase_display(new_phase)

	# Refresh the new panel
	if new_phase >= 0 and new_phase < panels.size():
		var panel: Control = panels[new_phase]
		if panel.has_method("refresh"):
			panel.refresh()

	## §2 sweep, AFTER the panel has rebuilt its children. Every surface under a
	## finger is MOUSE_FILTER_STOP by construction, and Viewport::_gui_call_input
	## stops touch drags there, so without this a finger cannot scroll a panel.
	## It runs per phase change because refresh() replaces the panel's subtree --
	## a sweep that ran before those children exist does silently nothing.
	_fix_touch_scroll_filters()


func _on_phase_completed(_phase: int) -> void:
	_update_phase_indicators()


func _on_turn_started(turn: int) -> void:
	_turn_label.text = "TURN %d" % turn
	_update_reputation_display()


func _on_turn_completed(_turn: int) -> void:
	# Show "Start Next Turn" instead of "Complete Phase"
	_advance_button.text = "Start Next Turn"
	_advance_button.disabled = false
	_phase_label.text = "TURN COMPLETE"


func _on_panel_phase_completed(result_data: Dictionary) -> void:
	phase_manager.complete_current_phase(result_data)


func _on_advance_pressed() -> void:
	if phase_manager.current_phase == BugHuntPhaseManagerScript.Phase.NONE:
		# Between turns — start new turn
		phase_manager.start_new_turn()
		_advance_button.text = "Complete Phase"
		return

	# Let the panel handle its own completion
	var panel_idx: int = phase_manager.current_phase
	if panel_idx >= 0 and panel_idx < panels.size():
		var panel: Control = panels[panel_idx]
		if panel.has_method("complete"):
			panel.complete()
		else:
			# Panel doesn't have completion logic, just advance
			phase_manager.complete_current_phase({})


func _on_save_pressed() -> void:
	## One save path. This function and BugHuntPhaseManager._complete_turn() each had
	## their own GameState-then-direct-file pair; BugHuntCampaignCore.persist() is now
	## the single owner of that choice, so the two cannot drift over which one updates
	## last_campaign (the key the main menu's Continue button reads).
	if not campaign or not campaign.has_method("persist"):
		return
	if campaign.persist() != OK:
		return
	_save_button.text = "Saved!"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(_save_button):
			_save_button.text = "Save"
	)


func _show_panel(phase_idx: int) -> void:
	if current_panel:
		current_panel.hide()
	if phase_idx >= 0 and phase_idx < panels.size():
		current_panel = panels[phase_idx]
		current_panel.show()


func _update_phase_display(phase: int) -> void:
	_phase_label.text = phase_manager.get_phase_name(phase).to_upper()
	_advance_button.text = "Complete Phase"
	_update_phase_indicators()


func _on_navigation_updated(_can_back: bool, can_forward: bool) -> void:
	_advance_button.disabled = not can_forward


func _update_phase_indicators() -> void:
	for i in range(_phase_indicators.size()):
		var indicator: Label = _phase_indicators[i]
		if i < phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif i == phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_TEXT)
		else:
			indicator.add_theme_color_override("font_color", COLOR_TEXT_SEC)


func _update_reputation_display() -> void:
	if campaign and "reputation" in campaign:
		_reputation_label.text = "Rep: %d" % campaign.reputation
	else:
		_reputation_label.text = "Rep: --"


func _resume_after_battle(result: Dictionary) -> void:
	## Fast-forward to POST_BATTLE phase after returning from TacticalBattleUI.
	if campaign:
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 1
		phase_manager.turn_number = turn
		_turn_label.text = "TURN %d" % turn

	_update_reputation_display()

	## Everything the post-battle sequence reads goes through the normalizer first:
	## participant_ids and casualty_ids derived from what the battle screen
	## recorded, and priority/spawn_rating/objectives carried across from the
	## stamp. The debrief is empty here on purpose -- the player has not made it
	## yet -- and the normalizer is add-only, so the panel calling it again with
	## the debrief adds to this rather than replacing it.
	var stamp: Dictionary = _stamped_mission()
	result = BugHuntResultNormalizer.normalize(result, stamp, {})
	_persist_battle_result(result)

	# Pass battle results to the post-battle panel BEFORE triggering phase change,
	# because _go_to_phase() synchronously fires phase_changed → refresh().
	if panels.size() > 2:
		var post_battle_panel: Control = panels[2]
		if post_battle_panel.has_method("set_battle_results"):
			post_battle_panel.set_battle_results(result)

	## Complete MISSION exactly ONCE, here, on the battle return.
	##
	## This used to jump straight to POST_BATTLE, which skipped MISSION's
	## completion entirely: _phase_complete[MISSION] stayed false, phase_completed
	## never fired, the journal never logged the mission, and
	## BugHuntPhaseManager._apply_battle_results never ran. The only paths that
	## ever completed MISSION were the two fabricated launch-failure fallbacks,
	## and those are gone -- so without this call nothing would complete it at all.
	##
	## complete_current_phase() advances by itself (MISSION -> POST_BATTLE), so
	## there is no go_to_phase() after it; a second transition would re-persist the
	## phase and fire phase_changed twice, rebuilding the panel under itself.
	## A battle result IS the Mission phase's result, so MISSION is what completes
	## here -- whatever phase a freshly-built manager happens to hold.
	##
	## Testing `current_phase == MISSION` first looks safer and is WRONG: the
	## controller is REBUILT on the way back from TacticalBattleUI, so the manager
	## is new and `current_phase` is its default Phase.NONE. The test is false on
	## every real return, and complete_current_phase() returns immediately on NONE
	## (:72-73), so the phase would silently never complete -- the same defect this
	## call exists to fix, just one layer further in.
	##
	## Assigning the field directly is this file's own idiom (_resume_turn's NONE
	## branch does the same): it must NOT go through _go_to_phase, which would emit
	## phase_changed and build the Mission panel for a mission already fought.
	## complete_current_phase() then advances to POST_BATTLE and persists it.
	if phase_manager.current_phase == BugHuntPhaseManagerScript.Phase.POST_BATTLE:
		## Already past MISSION (a re-entry). Completing it again would re-run
		## _apply_phase_results and re-log the mission.
		pass
	else:
		phase_manager.current_phase = BugHuntPhaseManagerScript.Phase.MISSION
		phase_manager.complete_current_phase({"battle_result": result})


func _stamped_mission() -> Dictionary:
	if campaign == null or not ("current_mission" in campaign):
		return {}
	var cm: Variant = campaign.current_mission
	return cm if cm is Dictionary else {}


func _persist_battle_result(result: Dictionary) -> void:
	if campaign == null or not ("current_mission" in campaign):
		return
	var cm: Variant = campaign.current_mission
	if not (cm is Dictionary):
		return
	var stamp: Dictionary = cm
	stamp["battle_result"] = result.duplicate(true)
	campaign.current_mission = stamp
	if campaign.has_method("persist"):
		campaign.persist()
