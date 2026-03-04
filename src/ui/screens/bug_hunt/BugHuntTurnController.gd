extends Control

## Bug Hunt Campaign Turn Controller
## Manages the 3-stage turn flow: Special Assignments → Mission → Post-Battle
## Each stage has a dedicated panel displayed in the main area.

const BugHuntPhaseManagerScript := preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const SpecialAssignmentsScript := preload("res://src/ui/screens/bug_hunt/panels/SpecialAssignmentsPanel.gd")
const MissionPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const PostBattlePanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")

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


func _ready() -> void:
	_load_campaign()
	_build_layout()
	_create_phase_manager()
	_create_panels()
	_connect_signals()

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
			gs_mgr.set_temp_data("bug_hunt_mission", null)
	elif campaign:
		# Normal startup — start or resume turn
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 0
		if turn <= 0:
			phase_manager.start_new_turn()
		else:
			# Resume — start at Special Assignments (phases aren't saved)
			phase_manager.turn_number = turn
			phase_manager.campaign_turn_started.emit(turn)
			phase_manager.go_to_phase(BugHuntPhaseManagerScript.Phase.SPECIAL_ASSIGNMENTS)


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
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT)
	top_bar.add_child(_turn_label)

	# Phase progress indicators
	var phase_box := HBoxContainer.new()
	phase_box.add_theme_constant_override("separation", 8)
	phase_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(phase_box)

	var phase_names := ["Special Assignments", "Mission", "Post-Battle"]
	for i in range(3):
		var indicator := Label.new()
		indicator.text = "%d. %s" % [i + 1, phase_names[i]]
		indicator.add_theme_font_size_override("font_size", 14)
		indicator.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		phase_box.add_child(indicator)
		_phase_indicators.append(indicator)

	_reputation_label = Label.new()
	_reputation_label.add_theme_font_size_override("font_size", 14)
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
	_phase_label.add_theme_font_size_override("font_size", 24)
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
	_advance_button.custom_minimum_size = Vector2(200, 48)
	_advance_button.pressed.connect(_on_advance_pressed)
	nav.add_child(_advance_button)


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
	if not campaign:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		var result: Dictionary = gs.save_campaign(campaign)
		if result.get("success", false):
			_save_button.text = "Saved!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_save_button):
					_save_button.text = "Save"
			)
	elif campaign.has_method("save_to_file") and campaign.has_method("get_campaign_id"):
		# Fallback: direct save if GameState unavailable
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		var err: int = campaign.save_to_file(path)
		if err == OK:
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

	# Pass battle results to the post-battle panel BEFORE triggering phase change,
	# because _go_to_phase() synchronously fires phase_changed → refresh().
	if panels.size() > 2:
		var post_battle_panel: Control = panels[2]
		if post_battle_panel.has_method("set_battle_results"):
			post_battle_panel.set_battle_results(result)

	# Jump directly to POST_BATTLE phase (refresh will now see real battle data)
	phase_manager.go_to_phase(BugHuntPhaseManagerScript.Phase.POST_BATTLE)
