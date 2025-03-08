@tool
extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/components/ActionButton.gd")

# Signals
signal action_pressed
signal action_hovered
signal action_unhovered

# Node references
@onready var button: Button = $Button
@onready var icon_rect: TextureRect = $Button/HBoxContainer/IconRect
@onready var label: Label = $Button/HBoxContainer/Label
@onready var cooldown_overlay: ColorRect = $Button/CooldownOverlay
@onready var progress_arc: TextureProgressBar = $Button/ProgressArc

# Properties
var action_name: String = "":
	set(value):
		action_name = value
		if label:
			label.text = value.capitalize()

var action_icon: Texture = null:
	set(value):
		action_icon = value
		if icon_rect:
			icon_rect.texture = value
			icon_rect.visible = value != null

var is_enabled: bool = true:
	set(value):
		is_enabled = value
		if button:
			button.disabled = not value
		if cooldown_overlay:
			cooldown_overlay.visible = not value

var cooldown_progress: float = 1.0:
	set(value):
		cooldown_progress = clamp(value, 0.0, 1.0)
		if progress_arc:
			progress_arc.value = cooldown_progress * 100
		if cooldown_overlay:
			cooldown_overlay.visible = cooldown_progress < 1.0

var action_color: Color = Color.WHITE:
	set(value):
		action_color = value
		if button:
			# Apply color to button style
			var style = button.get_theme_stylebox("normal").duplicate()
			style.bg_color = action_color.darkened(0.7)
			button.add_theme_stylebox_override("normal", style)
			
			style = button.get_theme_stylebox("hover").duplicate()
			style.bg_color = action_color.darkened(0.5)
			button.add_theme_stylebox_override("hover", style)
			
			style = button.get_theme_stylebox("pressed").duplicate()
			style.bg_color = action_color.darkened(0.8)
			button.add_theme_stylebox_override("pressed", style)
			
			style = button.get_theme_stylebox("disabled").duplicate()
			style.bg_color = action_color.darkened(0.9)
			button.add_theme_stylebox_override("disabled", style)

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	# Set up button style
	if button:
		button.custom_minimum_size = Vector2(200, 40)
		button.disabled = not is_enabled
		
	# Set up icon
	if icon_rect:
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.visible = action_icon != null
		
	# Set up cooldown overlay
	if cooldown_overlay:
		cooldown_overlay.visible = false
		
	# Set up progress arc
	if progress_arc:
		progress_arc.min_value = 0
		progress_arc.max_value = 100
		progress_arc.value = cooldown_progress * 100
		progress_arc.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		progress_arc.visible = cooldown_progress < 1.0

func _connect_signals() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)
		button.mouse_entered.connect(_on_button_mouse_entered)
		button.mouse_exited.connect(_on_button_mouse_exited)

# Signal handlers
func _on_button_pressed() -> void:
	emit_signal("action_pressed")

func _on_button_mouse_entered() -> void:
	emit_signal("action_hovered")

func _on_button_mouse_exited() -> void:
	emit_signal("action_unhovered")

# Public methods
func setup(name: String, icon: Texture = null, enabled: bool = true, color: Color = Color.WHITE) -> void:
	action_name = name
	action_icon = icon
	is_enabled = enabled
	action_color = color

func start_cooldown(duration: float) -> void:
	cooldown_progress = 0.0
	is_enabled = false
	
	var tween = create_tween()
	tween.tween_property(self, "cooldown_progress", 1.0, duration)
	tween.tween_callback(func(): is_enabled = true)

func set_progress(progress: float) -> void:
	cooldown_progress = progress

func reset_cooldown() -> void:
	cooldown_progress = 1.0
	is_enabled = true