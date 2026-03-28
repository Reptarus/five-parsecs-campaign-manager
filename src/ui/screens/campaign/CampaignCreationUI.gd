extends Control

const CampaignCreationCoordinatorScript = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")

@onready var panels: Array[Control] = [
	$MarginContainer/VBoxContainer/StepPanels/ExpandedConfigPanel,
	$MarginContainer/VBoxContainer/StepPanels/CaptainPanel,
	$MarginContainer/VBoxContainer/StepPanels/CrewPanel,
	$MarginContainer/VBoxContainer/StepPanels/EquipmentPanel,
	$MarginContainer/VBoxContainer/StepPanels/ShipPanel,
	$MarginContainer/VBoxContainer/StepPanels/WorldInfoPanel,
	$MarginContainer/VBoxContainer/StepPanels/FinalPanel,
]

@onready var next_button = $MarginContainer/VBoxContainer/Navigation/NextButton
@onready var back_button = $MarginContainer/VBoxContainer/Navigation/BackButton
@onready var finish_button = $MarginContainer/VBoxContainer/Navigation/FinishButton
@onready var step_label = $MarginContainer/VBoxContainer/Header/StepLabel

var coordinator: CampaignCreationCoordinatorScript
var current_panel: Control

func _ready() -> void:
	coordinator = CampaignCreationCoordinatorScript.new()
	add_child(coordinator)

	_connect_coordinator_signals()
	_connect_navigation_signals()
	_connect_panel_signals()
	_set_coordinator_on_panels()

	# Hide all panels, then show the first one
	for panel in panels:
		panel.hide()
	_show_panel(0)
	_update_step_label()

	# Initial navigation state — back button always visible (Cancel on Step 1)
	back_button.visible = true
	back_button.text = "Cancel"
	finish_button.visible = false
	next_button.visible = true
	next_button.disabled = false

	# UX-060/UX-070 FIX: Style navigation buttons with Deep Space theme
	_style_navigation_buttons()

	# QA-FIX: Connect StepPanels resize to keep panels bounded
	$MarginContainer/VBoxContainer/StepPanels.resized.connect(_on_step_panels_resized)

func _exit_tree() -> void:
	# Disconnect coordinator signals (defensive cleanup)
	if coordinator and is_instance_valid(coordinator):
		if coordinator.navigation_updated.is_connected(_on_navigation_updated):
			coordinator.navigation_updated.disconnect(_on_navigation_updated)
		if coordinator.step_changed.is_connected(_on_step_changed):
			coordinator.step_changed.disconnect(_on_step_changed)
	# Note: Lambda panel-to-coordinator connections are cleaned up automatically
	# because both panels and coordinator are children of this Control.

func _connect_coordinator_signals() -> void:
	coordinator.navigation_updated.connect(_on_navigation_updated)
	coordinator.step_changed.connect(_on_step_changed)

func _connect_navigation_signals() -> void:
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	finish_button.pressed.connect(_on_finish_pressed)
	# ISSUE-057: TweenFX press feedback on navigation buttons
	var tweenfx := get_node_or_null("/root/TweenFX")
	if tweenfx and tweenfx.has_method("press"):
		for btn: Button in [next_button, back_button, finish_button]:
			btn.pressed.connect(func():
				btn.pivot_offset = btn.size / 2
				tweenfx.press(btn, 0.2)
			)

func _connect_panel_signals() -> void:
	var config_panel = panels[0]
	var captain_panel = panels[1]
	var crew_panel = panels[2]
	var equipment_panel = panels[3]
	var ship_panel = panels[4]
	var world_panel = panels[5]
	var final_panel = panels[6]

	# ExpandedConfigPanel (extends FiveParsecsCampaignPanel)
	if config_panel.has_signal("campaign_config_updated"):
		config_panel.campaign_config_updated.connect(func(config: Dictionary):
			coordinator.update_campaign_config_state(config)
		)
	if config_panel.has_signal("campaign_config_data_complete"):
		config_panel.campaign_config_data_complete.connect(func(data: Dictionary):
			coordinator.update_campaign_config_state(data)
		)
	if config_panel.has_signal("campaign_config_data_changed"):
		config_panel.campaign_config_data_changed.connect(func(data: Dictionary):
			coordinator.update_campaign_config_state(data)
		)
	if config_panel.has_signal("victory_conditions_changed"):
		config_panel.victory_conditions_changed.connect(func(conditions: Dictionary):
			coordinator.update_campaign_config_state({"victory_conditions": conditions})
		)

	# CaptainPanel (extends Control) — wrap into dict
	if captain_panel.has_signal("captain_updated"):
		captain_panel.captain_updated.connect(func(captain):
			coordinator.update_captain_state({
				"captain": captain,
				"captain_character": captain,
				"is_complete": captain != null
			})
		)

	# CrewPanel (extends Control) — wrap into dict
	# Per Five Parsecs rules, crew of 4-6 INCLUDES captain. CrewPanel creates non-captain members only.
	if crew_panel.has_signal("crew_updated"):
		crew_panel.crew_updated.connect(func(crew: Array):
			var total_size: int = crew.size() + 1
			if crew_panel.has_method("get_selected_total_size"):
				total_size = crew_panel.get_selected_total_size()
			coordinator.update_crew_state({
				"members": crew,
				"crew_size": total_size,
				"is_complete": crew_panel.is_valid()
			})
		)

	# EquipmentPanel (extends FiveParsecsCampaignPanel)
	if equipment_panel.has_signal("equipment_generated"):
		equipment_panel.equipment_generated.connect(func(equipment: Array):
			coordinator.update_equipment_state({
				"equipment": equipment,
				"is_complete": equipment.size() > 0
			})
		)
	if equipment_panel.has_signal("equipment_data_complete"):
		equipment_panel.equipment_data_complete.connect(func(data: Dictionary):
			coordinator.update_equipment_state(data)
		)

	# ShipPanel (extends FiveParsecsCampaignPanel)
	if ship_panel.has_signal("ship_updated"):
		ship_panel.ship_updated.connect(func(ship_data: Dictionary):
			coordinator.update_ship_state(ship_data)
		)
	if ship_panel.has_signal("ship_data_complete"):
		ship_panel.ship_data_complete.connect(func(data: Dictionary):
			coordinator.update_ship_state(data)
		)

	# WorldInfoPanel (extends FiveParsecsCampaignPanel)
	if world_panel.has_signal("world_generated"):
		world_panel.world_generated.connect(func(world_data: Dictionary):
			coordinator.update_world_state(world_data)
		)
	if world_panel.has_signal("world_updated"):
		world_panel.world_updated.connect(func(world_data: Dictionary):
			coordinator.update_world_state(world_data)
		)
	if world_panel.has_signal("world_created"):
		world_panel.world_created.connect(func(world_data: Dictionary):
			coordinator.update_world_state(world_data)
		)

	# FinalPanel (extends FiveParsecsCampaignPanel)
	if final_panel.has_signal("campaign_finalization_complete"):
		final_panel.campaign_finalization_complete.connect(_on_campaign_finalized)

func _set_coordinator_on_panels() -> void:
	for panel in panels:
		if panel.has_method("set_coordinator"):
			panel.set_coordinator(coordinator)

func _on_navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool) -> void:
	# Always show back button — on Step 1 it acts as Cancel (return to MainMenu)
	back_button.visible = true
	back_button.text = "Cancel" if coordinator.current_step == 0 else "Back"
	next_button.visible = can_go_forward and not can_finish
	finish_button.visible = can_finish
	next_button.disabled = not can_go_forward
	finish_button.disabled = not can_finish

func _on_step_changed(step: int, _total_steps: int) -> void:
	_show_panel(step)
	_update_step_label()
	# Provide initial state to FiveParsecsCampaignPanel types
	if current_panel and current_panel.has_method("set_coordinator"):
		coordinator.provide_initial_state_to_panel(current_panel)
	# Force navigation refresh after step change — the deferred nav update from
	# advance_to_next_phase() may have already fired with stale phase data
	call_deferred("_force_navigation_refresh")

func _show_panel(step: int) -> void:
	if current_panel:
		current_panel.hide()
	if step >= 0 and step < panels.size():
		current_panel = panels[step]
		current_panel.modulate.a = 0.0
		current_panel.show()
		# ISSUE-057: Smooth panel transition
		var tweenfx := get_node_or_null("/root/TweenFX")
		if tweenfx and tweenfx.has_method("fade_in"):
			tweenfx.fade_in(current_panel, 0.2)
		else:
			current_panel.modulate.a = 1.0
		# QA-FIX: Force panel to fit within StepPanels bounds. PanelContainer
		# (BaseCampaignPanel root) enforces minimum size from children, which can
		# overflow StepPanels and push Navigation off-screen. Anchors (0,0,1,1)
		# constrain the panel; call_deferred lets layout resolve first.
		call_deferred("_fit_panel_to_step_bounds")

func _fit_panel_to_step_bounds() -> void:
	if current_panel:
		var step_panels := $MarginContainer/VBoxContainer/StepPanels
		# Reset position and anchors so panel fills StepPanels exactly
		current_panel.position = Vector2.ZERO
		current_panel.anchor_left = 0.0
		current_panel.anchor_top = 0.0
		current_panel.anchor_right = 1.0
		current_panel.anchor_bottom = 1.0
		current_panel.offset_left = 0
		current_panel.offset_top = 0
		current_panel.offset_right = 0
		current_panel.offset_bottom = 0
		# Override minimum size to allow shrinking below content height
		current_panel.custom_minimum_size = Vector2.ZERO
		# Anchors (0,0,1,1) with zero offsets handle sizing — do NOT set
		# current_panel.size explicitly as it conflicts with anchor layout
		# and prevents internal ScrollContainers from activating.

func _on_step_panels_resized() -> void:
	_fit_panel_to_step_bounds()

func _update_step_label() -> void:
	var phase_name = coordinator.get_current_phase_name()
	var step_num = coordinator.current_step + 1
	step_label.text = "Step %d of %d: %s" % [step_num, coordinator.total_steps, phase_name]
	# ISSUE-057: Subtle punch animation on step change
	var tweenfx := get_node_or_null("/root/TweenFX")
	if tweenfx and tweenfx.has_method("punch_in"):
		step_label.pivot_offset = step_label.size / 2
		tweenfx.punch_in(step_label, 0.15, 0.15)

func _on_next_pressed() -> void:
	coordinator.advance_to_next_phase()

func _on_back_pressed() -> void:
	if coordinator.current_step == 0:
		# On Step 1, Cancel returns to MainMenu
		var router = get_node_or_null("/root/SceneRouter")
		if router:
			router.navigate_back()
		return
	coordinator.go_back_to_previous_phase()

func _on_finish_pressed() -> void:
	# Delegate to FinalPanel which handles validation + CampaignFinalizationService
	var final_panel = panels[6]
	if final_panel and final_panel.has_method("_on_create_campaign_pressed"):
		final_panel._on_create_campaign_pressed()
	else:
		push_error("CampaignCreationUI: FinalPanel not available for finalization")

func _on_campaign_finalized(data: Dictionary) -> void:
	# data = {"campaign": Resource, "save_path": "...", "raw_data": {...}}
	var campaign = data.get("campaign")
	if campaign == null:
		push_error("CampaignCreationUI: Finalization returned no campaign resource")
		return

	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_current_campaign"):
		gs.set_current_campaign(campaign)

	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("campaign_turn_controller")
	else:
		push_error("CampaignCreationUI: SceneRouter not found")

func _force_navigation_refresh() -> void:
	# Bypass debounce — directly recalculate and emit navigation state
	var can_back: bool = coordinator.can_go_back_to_previous_phase()
	var can_fwd: bool = coordinator.can_advance_to_next_phase()
	var can_fin: bool = coordinator.can_finish_campaign_creation()
	_on_navigation_updated(can_back, can_fwd, can_fin)

func get_current_panel() -> Control:
	return current_panel

## UX-060/UX-070 FIX: Apply consistent Deep Space theme styling to nav buttons
func _style_navigation_buttons() -> void:
	for btn in [back_button, next_button, finish_button]:
		if not btn:
			continue
		btn.custom_minimum_size.y = 48  # TOUCH_TARGET_MIN

		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#2D5A7B")  # COLOR_ACCENT
		normal.border_color = Color("#3A7199")
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(4)
		normal.content_margin_left = 20
		normal.content_margin_right = 20
		normal.content_margin_top = 10
		normal.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", normal)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color("#3A7199")  # COLOR_ACCENT_HOVER
		hover.border_color = Color("#4FC3F7")  # COLOR_FOCUS
		hover.set_border_width_all(1)
		hover.set_corner_radius_all(4)
		hover.content_margin_left = 20
		hover.content_margin_right = 20
		hover.content_margin_top = 10
		hover.content_margin_bottom = 10
		btn.add_theme_stylebox_override("hover", hover)

		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color("#1E4A66")
		pressed.border_color = Color("#4FC3F7")
		pressed.set_border_width_all(2)
		pressed.set_corner_radius_all(4)
		pressed.content_margin_left = 20
		pressed.content_margin_right = 20
		pressed.content_margin_top = 10
		pressed.content_margin_bottom = 10
		btn.add_theme_stylebox_override("pressed", pressed)

		var disabled := StyleBoxFlat.new()
		disabled.bg_color = Color("#1A1A2E")  # COLOR_BASE
		disabled.border_color = Color("#3A3A5C")  # COLOR_BORDER
		disabled.set_border_width_all(1)
		disabled.set_corner_radius_all(4)
		disabled.content_margin_left = 20
		disabled.content_margin_right = 20
		disabled.content_margin_top = 10
		disabled.content_margin_bottom = 10
		btn.add_theme_stylebox_override("disabled", disabled)

		btn.add_theme_color_override("font_color", Color("#E0E0E0"))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_disabled_color", Color("#404040"))

	# Make Finish button more prominent (accent highlight)
	if finish_button:
		var finish_normal := StyleBoxFlat.new()
		finish_normal.bg_color = Color("#10B981")  # COLOR_SUCCESS
		finish_normal.border_color = Color("#34D399")
		finish_normal.set_border_width_all(1)
		finish_normal.set_corner_radius_all(4)
		finish_normal.content_margin_left = 24
		finish_normal.content_margin_right = 24
		finish_normal.content_margin_top = 12
		finish_normal.content_margin_bottom = 12
		finish_button.add_theme_stylebox_override("normal", finish_normal)
