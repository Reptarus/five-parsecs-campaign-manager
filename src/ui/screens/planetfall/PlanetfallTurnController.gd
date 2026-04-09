extends PlanetfallScreenBase

## Planetfall Campaign Turn Controller — 18-step campaign turn.
## Manages the phase flow from Recovery (Step 1) through Update Tracking (Step 18).
## Each step has a panel displayed in the main area (placeholder panels for Sprint 1).
## Follows the same architecture as BugHuntTurnController.
## Source: Planetfall pp.58-70

const PlanetfallPhaseManagerScript := preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const PlaceholderPanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallPlaceholderPanel.gd")

var phase_manager: PlanetfallPhaseManagerScript
var campaign: Resource  # PlanetfallCampaignCore
var panels: Array[Control] = []
var current_panel: Control

var _turn_label: Label
var _phase_label: Label
var _stat_strip: HBoxContainer
var _advance_button: Button
var _save_button: Button
var _panel_container: Control
var _phase_scroll: ScrollContainer
var _phase_indicator_box: HBoxContainer
var _phase_indicators: Array[Label] = []

## Stat labels for the colony stat bar
var _stat_labels: Dictionary = {}


## ============================================================================
## LIFECYCLE
## ============================================================================

func _setup_screen() -> void:
	# Defer initialization — scene may not be fully in tree when
	# instantiated via TransitionManager.fade_to_scene()
	call_deferred("_initialize")


func _initialize() -> void:
	_load_campaign()
	if not campaign:
		return
	_build_layout()
	_create_phase_manager()
	_create_panels()
	_connect_signals()

	# Check if returning from battle
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	var battle_result = null
	if gs_mgr and gs_mgr.has_method("get_temp_data"):
		battle_result = gs_mgr.get_temp_data("planetfall_battle_result")

	if battle_result is Dictionary and not battle_result.is_empty():
		_resume_after_battle(battle_result)
		if gs_mgr.has_method("set_temp_data"):
			gs_mgr.set_temp_data("planetfall_battle_result", null)
			gs_mgr.set_temp_data("planetfall_mission", null)
	elif campaign:
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 0
		if turn <= 0:
			phase_manager.start_new_turn()
		else:
			phase_manager.turn_number = turn
			phase_manager.campaign_turn_started.emit(turn)
			phase_manager.go_to_phase(PlanetfallPhaseManagerScript.Phase.RECOVERY)


func _load_campaign() -> void:
	campaign = _get_planetfall_campaign()

	# Validate this is a PlanetfallCampaignCore (has roster property)
	if campaign and not "roster" in campaign:
		push_warning("PlanetfallTurnController: Campaign missing 'roster'. Routing to main menu.")
		campaign = null
		_navigate("main_menu")


## ============================================================================
## LAYOUT
## ============================================================================

func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SPACING_MD)
	margin.add_theme_constant_override("margin_top", SPACING_SM)
	margin.add_theme_constant_override("margin_right", SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", SPACING_SM)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	margin.add_child(vbox)

	# Top row: Turn label + Save button
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(top_row)

	_turn_label = Label.new()
	_turn_label.text = "TURN 1"
	_turn_label.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_turn_label)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(80, 36)
	_save_button.pressed.connect(_on_save_pressed)
	top_row.add_child(_save_button)

	var back_btn := Button.new()
	back_btn.text = "Dashboard"
	back_btn.custom_minimum_size = Vector2(100, 36)
	back_btn.pressed.connect(func(): _navigate("planetfall_dashboard"))
	top_row.add_child(back_btn)

	# Colony stat strip
	_stat_strip = HBoxContainer.new()
	_stat_strip.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_stat_strip)
	_build_stat_strip()

	# Phase indicator strip (scrollable for 18 items)
	_phase_scroll = ScrollContainer.new()
	_phase_scroll.custom_minimum_size.y = 32
	_phase_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_phase_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_phase_scroll)

	_phase_indicator_box = HBoxContainer.new()
	_phase_indicator_box.add_theme_constant_override("separation", SPACING_XS)
	_phase_scroll.add_child(_phase_indicator_box)
	_build_phase_indicators()

	# Current phase title
	_phase_label = Label.new()
	_phase_label.text = "RECOVERY"
	_phase_label.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	_phase_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_label)

	# Panel container — holds all 18 panels, only one visible
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Bottom navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", SPACING_MD)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_advance_button = Button.new()
	_advance_button.text = "Complete Phase"
	_advance_button.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	_advance_button.pressed.connect(_on_advance_pressed)
	nav.add_child(_advance_button)


func _build_stat_strip() -> void:
	var stat_keys: Array[String] = ["MORALE", "INTEGRITY", "SP", "RM", "GRUNTS", "MILESTONES"]
	for key in stat_keys:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color", COLOR_CYAN)
		_stat_strip.add_child(lbl)
		_stat_labels[key] = lbl
	_refresh_stat_strip()


func _refresh_stat_strip() -> void:
	if not campaign:
		return
	var morale: int = campaign.colony_morale if "colony_morale" in campaign else 0
	var integrity: int = campaign.colony_integrity if "colony_integrity" in campaign else 0
	var sp: int = campaign.story_points if "story_points" in campaign else 0
	var rm: int = campaign.raw_materials if "raw_materials" in campaign else 0
	var grunts: int = campaign.grunts if "grunts" in campaign else 0
	var milestones: int = campaign.milestones_completed if "milestones_completed" in campaign else 0

	if _stat_labels.has("MORALE"):
		_stat_labels["MORALE"].text = "Morale: %d" % morale
	if _stat_labels.has("INTEGRITY"):
		_stat_labels["INTEGRITY"].text = "Integrity: %d" % integrity
	if _stat_labels.has("SP"):
		_stat_labels["SP"].text = "SP: %d" % sp
	if _stat_labels.has("RM"):
		_stat_labels["RM"].text = "RM: %d" % rm
	if _stat_labels.has("GRUNTS"):
		_stat_labels["GRUNTS"].text = "Grunts: %d" % grunts
	if _stat_labels.has("MILESTONES"):
		_stat_labels["MILESTONES"].text = "Milestones: %d/7" % milestones


func _build_phase_indicators() -> void:
	_phase_indicators.clear()
	for i in range(PlanetfallPhaseManagerScript.PHASE_COUNT):
		var indicator := Label.new()
		var short_name: String = PlanetfallPhaseManagerScript.PHASE_NAMES.get(i, "?")
		indicator.text = "%d" % (i + 1)
		indicator.tooltip_text = "%d. %s" % [i + 1, short_name]
		indicator.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XS))
		indicator.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		indicator.custom_minimum_size = Vector2(24, 24)
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_phase_indicator_box.add_child(indicator)
		_phase_indicators.append(indicator)


## ============================================================================
## PHASE MANAGER SETUP
## ============================================================================

func _create_phase_manager() -> void:
	phase_manager = PlanetfallPhaseManagerScript.new()
	phase_manager.name = "PlanetfallPhaseManager"
	add_child(phase_manager)
	phase_manager.setup(campaign)


func _create_panels() -> void:
	panels.clear()

	for i in range(PlanetfallPhaseManagerScript.PHASE_COUNT):
		var panel: Control = PlaceholderPanelScript.new()
		var phase_name: String = PlanetfallPhaseManagerScript.PHASE_NAMES.get(i, "Step %d" % (i + 1))
		panel.configure(phase_name, i)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel_container.add_child(panel)
		panel.hide()

		if panel.has_method("set_campaign"):
			panel.set_campaign(campaign)
		if panel.has_method("set_phase_manager"):
			panel.set_phase_manager(phase_manager)

		panels.append(panel)


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


## ============================================================================
## SIGNAL HANDLERS
## ============================================================================

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	_show_panel(new_phase)
	_update_phase_display(new_phase)
	_refresh_stat_strip()

	# Refresh the new panel
	if new_phase >= 0 and new_phase < panels.size():
		var panel: Control = panels[new_phase]
		if panel.has_method("refresh"):
			panel.refresh()

	# Scroll phase indicator into view
	_scroll_indicator_into_view(new_phase)


func _on_phase_completed(_phase: int) -> void:
	_update_phase_indicators()
	_refresh_stat_strip()


func _on_turn_started(turn: int) -> void:
	_turn_label.text = "TURN %d" % turn
	_refresh_stat_strip()


func _on_turn_completed(_turn: int) -> void:
	_advance_button.text = "Start Next Turn"
	_advance_button.disabled = false
	_phase_label.text = "TURN COMPLETE"
	_refresh_stat_strip()


func _on_panel_phase_completed(result_data: Dictionary) -> void:
	phase_manager.complete_current_phase(result_data)


func _on_advance_pressed() -> void:
	if phase_manager.current_phase == PlanetfallPhaseManagerScript.Phase.NONE:
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
			phase_manager.complete_current_phase({})


func _on_navigation_updated(_can_back: bool, can_forward: bool) -> void:
	_advance_button.disabled = not can_forward


func _on_save_pressed() -> void:
	if not campaign:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		var result: Dictionary = gs.save_campaign(campaign)
		if result.get("success", false):
			_save_button.text = "Saved!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_save_button):
					_save_button.text = "Save"
			)
	elif campaign.has_method("save_to_file") and campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		var err: int = campaign.save_to_file(path)
		if err == OK:
			_save_button.text = "Saved!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_save_button):
					_save_button.text = "Save"
			)


## ============================================================================
## PANEL DISPLAY
## ============================================================================

func _show_panel(phase_idx: int) -> void:
	if current_panel:
		current_panel.hide()
	if phase_idx >= 0 and phase_idx < panels.size():
		current_panel = panels[phase_idx]
		current_panel.show()


func _update_phase_display(phase: int) -> void:
	var phase_name: String = phase_manager.get_phase_name(phase)
	var category: String = phase_manager.get_phase_category(phase)
	_phase_label.text = "%s — %s" % [category, phase_name.to_upper()]
	_advance_button.text = "Complete Phase"
	_update_phase_indicators()


func _update_phase_indicators() -> void:
	for i in range(_phase_indicators.size()):
		var indicator: Label = _phase_indicators[i]
		if i < phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif i == phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		else:
			indicator.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)


func _scroll_indicator_into_view(phase_idx: int) -> void:
	## Scroll the phase indicator strip so the current phase is visible.
	if phase_idx < 0 or phase_idx >= _phase_indicators.size():
		return
	var indicator: Label = _phase_indicators[phase_idx]
	# Ensure the indicator is in view within the scroll container
	var target_x: float = indicator.position.x - _phase_scroll.size.x / 2.0 + indicator.size.x / 2.0
	_phase_scroll.scroll_horizontal = int(max(0.0, target_x))


## ============================================================================
## BATTLE DELEGATION
## ============================================================================

func _resume_after_battle(result: Dictionary) -> void:
	## Fast-forward to INJURIES phase after returning from TacticalBattleUI.
	if campaign:
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 1
		phase_manager.turn_number = turn
		_turn_label.text = "TURN %d" % turn

	_refresh_stat_strip()

	# TODO: Pass battle results to post-battle panel BEFORE triggering phase change
	# (Sprint 3 will implement the real PostBattlePanel)

	# Jump directly to INJURIES phase
	phase_manager.go_to_phase(PlanetfallPhaseManagerScript.Phase.INJURIES)
