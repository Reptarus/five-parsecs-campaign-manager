class_name UnitActivationCard
extends Control

## UnitActivationCard - Compact battle unit status display (mobile-first)
## Displays activation status, health, and status effects for a single unit
## Design: 72px height, touch-optimized, team-color borders

# ============ SIGNALS ============
signal activation_toggled(unit_id: String)
signal damage_requested(unit_id: String)
signal unit_selected(unit_id: String)

# ============ CONSTANTS ============
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

# Visual states
const COLOR_ACTIVATED := UIColors.COLOR_EMERALD     # Green - acted
const COLOR_NOT_ACTED := UIColors.COLOR_TEXT_MUTED  # Gray - not acted
const COLOR_CANNOT_ACT := UIColors.COLOR_DANGER     # Red - cannot act
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

# Team colors
const COLOR_CREW := UIColors.COLOR_BLUE        # Blue border
const COLOR_ENEMY := UIColors.COLOR_RED        # Red border

# Health bar colors
const COLOR_HEALTH_HIGH := UIColors.COLOR_EMERALD  # Green (>66%)
const COLOR_HEALTH_MED := UIColors.COLOR_AMBER     # Amber (33-66%)
const COLOR_HEALTH_LOW := UIColors.COLOR_DANGER    # Red (<33%)
const COLOR_HEALTH_DEAD := Color("#000000")        # Black (0 HP)

# ============ STATE ============
var unit_id: String = ""
var unit_name: String = ""
var is_activated: bool = false
var is_crew: bool = true
var current_health: int = 10
var max_health: int = 10
var status_effects: Array[String] = []
var combat_skill: int = 0
var toughness: int = 4

# ============ @ONREADY REFERENCES ============
@onready var _background: PanelContainer = $Background
@onready var _activation_dot: ColorRect = %ActivationDot
@onready var _name_label: Label = %NameLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_text: Label = %HealthText
@onready var _stats_label: Label = %StatsLabel
@onready var _status_container: HBoxContainer = %StatusContainer

# ============ LIFECYCLE METHODS ============
func _ready() -> void:
	# Ensure touch target compliance
	custom_minimum_size.y = TOUCH_TARGET_MIN

	# Setup input handling for activation toggle
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Initial visual state
	_update_visual_state()


# ============ PUBLIC INTERFACE ============
func initialize(unit_data: Dictionary) -> void:
	## Initialize card with unit data
	unit_id = unit_data.get("id", "")
	unit_name = unit_data.get("name", "Unknown")
	is_crew = unit_data.get("is_crew", true)
	current_health = unit_data.get("current_health", 10)
	max_health = unit_data.get("max_health", 10)
	combat_skill = unit_data.get("combat", 0)
	toughness = unit_data.get("toughness", 4)

	# Parse status effects
	status_effects.clear()
	if unit_data.has("status_effects"):
		var effects: Array = unit_data.get("status_effects", [])
		for effect in effects:
			status_effects.append(str(effect))

	# Reset activation state
	is_activated = false

	_update_visual_state()


func set_activated(activated: bool) -> void:
	## Update activation state
	if is_activated == activated:
		return

	is_activated = activated
	_update_activation_dot()


func update_health(current: int, max_hp: int) -> void:
	## Update health display
	current_health = current
	max_health = max_hp
	_update_health_bar()


func update_status_effects(effects: Array) -> void:
	## Update status effects display
	status_effects.clear()
	for effect in effects:
		status_effects.append(str(effect))

	_update_status_effects()


func set_team(is_crew_member: bool) -> void:
	## Set team color (crew blue, enemy red)
	is_crew = is_crew_member
	_update_team_border()


# ============ VISUAL UPDATE METHODS ============
func _update_visual_state() -> void:
	## Update all visual elements
	if not is_inside_tree():
		return

	_update_team_border()
	_update_activation_dot()
	_update_name()
	_update_health_bar()
	_update_stats()
	_update_status_effects()


func _update_team_border() -> void:
	## Apply team color to card border
	if not _background:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A1A2E")  # Dark background
	style.border_color = COLOR_CREW if is_crew else COLOR_ENEMY
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_SM)

	_background.add_theme_stylebox_override("panel", style)


func _update_activation_dot() -> void:
	## Update activation dot color based on state
	if not _activation_dot:
		return

	if current_health <= 0:
		_activation_dot.color = COLOR_CANNOT_ACT  # Dead - cannot act
	elif is_activated:
		_activation_dot.color = COLOR_ACTIVATED   # Acted this round
	else:
		_activation_dot.color = COLOR_NOT_ACTED   # Ready to act


func _update_name() -> void:
	## Update unit name label
	if not _name_label:
		return

	_name_label.text = unit_name


func _update_health_bar() -> void:
	## Update health bar and text with color coding
	if not _health_bar or not _health_text:
		return

	# Calculate health percentage
	var health_pct: float = 0.0
	if max_health > 0:
		health_pct = (float(current_health) / float(max_health)) * 100.0

	# Update progress bar
	_health_bar.value = health_pct

	# Color code health bar
	var health_color: Color = COLOR_HEALTH_DEAD
	if current_health <= 0:
		health_color = COLOR_HEALTH_DEAD
	elif health_pct > 66.0:
		health_color = COLOR_HEALTH_HIGH
	elif health_pct > 33.0:
		health_color = COLOR_HEALTH_MED
	else:
		health_color = COLOR_HEALTH_LOW

	# Apply health bar style
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = health_color
	fill_style.set_corner_radius_all(4)
	_health_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1E1E36")
	bg_style.set_corner_radius_all(4)
	_health_bar.add_theme_stylebox_override("background", bg_style)

	# Update health text
	_health_text.text = "%d/%d" % [current_health, max_health]


func _update_stats() -> void:
	## Update combat/toughness stats display
	if not _stats_label:
		return

	_stats_label.text = "Combat +%d | Tough %d" % [combat_skill, toughness]


func _update_status_effects() -> void:
	## Update status effect badges (max 3 shown)
	if not _status_container:
		return

	# Clear existing badges
	for child in _status_container.get_children():
		child.queue_free()

	# Show max 3 effects, with "..." if more
	var max_shown := 3
	var effects_to_show := status_effects.slice(0, max_shown)

	for effect in effects_to_show:
		var badge := _create_status_badge(effect)
		_status_container.add_child(badge)

	# Add overflow indicator
	if status_effects.size() > max_shown:
		var overflow := Label.new()
		overflow.text = "..."
		overflow.add_theme_font_size_override("font_size", 14)
		overflow.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_status_container.add_child(overflow)


func _create_status_badge(effect: String) -> PanelContainer:
	## Create a compact status effect badge
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(24, 24)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3A3A5C")
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = _effect_to_emoji(effect)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)

	return panel


func _effect_to_emoji(effect: String) -> String:
	## Convert effect name to emoji
	match effect.to_lower():
		"stunned", "stun":
			return "⚡"
		"injured", "injury":
			return "🩹"
		"poisoned", "poison":
			return "☠️"
		"burning", "burn":
			return "🔥"
		_:
			return "?"


# ============ INPUT HANDLING ============
func _on_gui_input(event: InputEvent) -> void:
	## Handle tap/click to toggle activation
	var is_tap := false

	if event is InputEventScreenTouch:
		is_tap = event.pressed
	elif event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if is_tap:
		_handle_tap()


func _handle_tap() -> void:
	## Handle card tap - toggle activation or select dead unit
	if current_health <= 0:
		# Dead units can't activate, but can be selected
		unit_selected.emit(unit_id)
		return

	# Toggle activation
	is_activated = !is_activated
	_update_activation_dot()
	activation_toggled.emit(unit_id)
