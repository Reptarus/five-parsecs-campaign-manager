extends HBoxContainer
class_name CampaignTurnProgressTracker

## Campaign Turn Progress Tracker Component
## Displays 7-step turn flow: Travel → World → Mission → Battle → Loot → Advancement → End Turn
## Visual states: Completed (emerald), Current (amber pulsing), Upcoming (muted gray)
## Signal architecture: call-down-signal-up pattern

# ============ SIGNALS (Up Communication) ============
signal step_clicked(step_index: int)  # User tapped a step indicator

# ============ CONSTANTS (From UIColors) ============
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD

const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM

# Colors
const COLOR_EMERALD := UIColors.COLOR_EMERALD       # Completed steps
const COLOR_AMBER := UIColors.COLOR_AMBER            # Current step
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED  # Upcoming steps
const COLOR_BORDER := UIColors.COLOR_BORDER          # Connector lines
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY

# ============ TURN STEPS CONFIGURATION ============
const TURN_STEPS := [
	{"label": "Travel", "phase_key": "travel"},
	{"label": "World", "phase_key": "world"},
	{"label": "Mission", "phase_key": "mission"},
	{"label": "Battle", "phase_key": "battle"},
	{"label": "Loot", "phase_key": "loot"},
	{"label": "Advance", "phase_key": "advancement"},
	{"label": "End Turn", "phase_key": "end_turn"}
]

# ============ PROPERTIES ============
var current_step: int = 0  # 0-6 index into TURN_STEPS
var completed_steps: Array[int] = []  # Array of completed step indices

# ============ NODE REFERENCES ============
var _step_indicators: Array[Control] = []
var _connector_lines: Array[Control] = []

# Pulsing animation for current step
var _pulse_tween: Tween = null

# ============ LIFECYCLE ============
func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 0)  # Manual spacing via connectors
	_build_progress_tracker()
	_start_pulse_animation()

func _exit_tree() -> void:
	## Cleanup animations on removal
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null

# ============ PUBLIC INTERFACE (Call Down) ============
func set_current_step(step_index: int) -> void:
	## Update current step (0-6)
	if step_index < 0 or step_index >= TURN_STEPS.size():
		push_error("CampaignTurnProgressTracker: Invalid step index %d" % step_index)
		return
	
	current_step = step_index
	_update_step_visuals()
	_start_pulse_animation()

func mark_step_completed(step_index: int) -> void:
	## Mark a step as completed
	if step_index < 0 or step_index >= TURN_STEPS.size():
		return
	
	if not completed_steps.has(step_index):
		completed_steps.append(step_index)
		_update_step_visuals()

func reset_progress() -> void:
	## Reset all progress (new turn)
	current_step = 0
	completed_steps.clear()
	_update_step_visuals()
	_start_pulse_animation()

func get_current_step_name() -> String:
	## Get current step label
	if current_step >= 0 and current_step < TURN_STEPS.size():
		return TURN_STEPS[current_step]["label"]
	return ""

# ============ PRIVATE METHODS ============
func _build_progress_tracker() -> void:
	## Build the complete progress tracker UI
	for i in range(TURN_STEPS.size()):
		# Add connector line before step (except first)
		if i > 0:
			var connector := _create_connector_line()
			add_child(connector)
			_connector_lines.append(connector)
		
		# Add step indicator
		var step_indicator := _create_step_indicator(i)
		add_child(step_indicator)
		_step_indicators.append(step_indicator)
	
	_update_step_visuals()

func _create_step_indicator(step_index: int) -> VBoxContainer:
	## Create a single step indicator (circle + label)
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_XS)
	container.custom_minimum_size = Vector2(64, 72)
	
	# Circle indicator
	var circle := PanelContainer.new()
	circle.name = "Circle"
	circle.custom_minimum_size = Vector2(40, 40)
	
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TEXT_MUTED  # Default: upcoming
	style.set_corner_radius_all(20)  # Circular
	circle.add_theme_stylebox_override("panel", style)
	
	# Phase icon from IconRegistry
	var phase_key: String = TURN_STEPS[step_index]["phase_key"]
	var phase_tex := IconRegistry.get_icon("phase", phase_key)
	var icon_rect := TextureRect.new()
	icon_rect.name = "PhaseIcon"
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = COLOR_TEXT_PRIMARY
	if phase_tex:
		icon_rect.texture = phase_tex
	circle.add_child(icon_rect)

	# Checkmark label (hidden by default, shown when completed)
	var icon_label := Label.new()
	icon_label.name = "Icon"
	icon_label.text = "✓"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 18)
	icon_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	icon_label.visible = false
	circle.add_child(icon_label)
	
	container.add_child(circle)
	
	# Step label below circle
	var label := Label.new()
	label.name = "Label"
	label.text = TURN_STEPS[step_index]["label"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	container.add_child(label)
	
	# Make clickable
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(64, 72)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_step_clicked.bind(step_index))
	container.add_child(button)
	button.move_to_front()
	
	return container

func _create_connector_line() -> ColorRect:
	## Create horizontal connector line between steps
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(32, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = COLOR_BORDER
	return line

func _update_step_visuals() -> void:
	## Update visual state of all steps based on current_step and completed_steps
	for i in range(_step_indicators.size()):
		var indicator := _step_indicators[i] as VBoxContainer
		if not indicator:
			continue

		var circle := indicator.get_node("Circle") as PanelContainer
		var phase_icon := indicator.get_node("Circle/PhaseIcon") as TextureRect
		var check_label := indicator.get_node("Circle/Icon") as Label
		var label := indicator.get_node("Label") as Label

		if not circle or not label:
			continue

		# Determine step state
		var is_completed := completed_steps.has(i) or i < current_step
		var is_current := i == current_step

		# Update circle background
		var style := circle.get_theme_stylebox("panel") as StyleBoxFlat
		if not style:
			style = StyleBoxFlat.new()
			style.set_corner_radius_all(20)

		if is_completed:
			# Completed: emerald with checkmark
			style.bg_color = COLOR_EMERALD
			if phase_icon:
				phase_icon.visible = false
			if check_label:
				check_label.visible = true
			label.add_theme_color_override("font_color", COLOR_EMERALD)
		elif is_current:
			# Current: amber (pulsing handled by animation)
			style.bg_color = COLOR_AMBER
			if phase_icon:
				phase_icon.visible = true
				phase_icon.modulate = Color.WHITE
			if check_label:
				check_label.visible = false
			label.add_theme_color_override("font_color", COLOR_AMBER)
		else:
			# Upcoming: muted gray
			style.bg_color = COLOR_TEXT_MUTED
			if phase_icon:
				phase_icon.visible = true
				phase_icon.modulate = Color(0.3, 0.3, 0.3)
			if check_label:
				check_label.visible = false
			label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)

		circle.add_theme_stylebox_override("panel", style)
	
	# Update connector lines (completed connectors are emerald)
	for i in range(_connector_lines.size()):
		var line := _connector_lines[i] as ColorRect
		if not line:
			continue
		
		# Connector i connects step i to step i+1
		var is_completed_connector := i < current_step
		line.color = COLOR_EMERALD if is_completed_connector else COLOR_BORDER

func _start_pulse_animation() -> void:
	## Start pulsing animation for current step indicator
	# Kill existing animation
	if _pulse_tween:
		_pulse_tween.kill()
	
	if current_step < 0 or current_step >= _step_indicators.size():
		return
	
	var indicator := _step_indicators[current_step] as VBoxContainer
	if not indicator:
		return
	
	var circle := indicator.get_node("Circle") as Control
	if not circle:
		return
	
	# Create pulsing scale animation
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()  # Infinite loop
	_pulse_tween.tween_property(circle, "scale", Vector2(1.1, 1.1), 0.6).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_IN_OUT)

# ============ SIGNAL HANDLERS ============
func _on_step_clicked(step_index: int) -> void:
	## Handle step indicator click
	step_clicked.emit(step_index)

# ============ INTEGRATION HELPERS ============
func sync_with_game_state() -> void:
	## Sync progress tracker with GameStateManager (call from parent)
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return
	
	# Map GameState phase to step index
	# This would need actual implementation based on GameStateManager API
	# For now, placeholder
	var current_phase := "world_phase"  # Example
	match current_phase:
		"travel_phase":
			set_current_step(0)
		"world_phase":
			set_current_step(1)
		"mission_phase":
			set_current_step(2)
		"battle_phase":
			set_current_step(3)
		"loot_phase":
			set_current_step(4)
		"advancement_phase":
			set_current_step(5)
		"end_turn":
			set_current_step(6)
		_:
			set_current_step(0)
