@tool
extends Control
class_name FiveParsecsInfoCard

## Base Information Card - Abstract base for all information display cards
## Follows Digital Dice System visual patterns and Universal Safety framework
## Provides consistent color coding, context labels, and responsive design

# Universal Safety patterns
signal card_selected(card_data: Dictionary)
signal card_action_requested(action: String, data: Variant)
signal card_updated(card_id: String)

# Color coding system from Digital Dice System
const SUCCESS_COLOR = Color.GREEN
const WARNING_COLOR = Color.YELLOW
const DANGER_COLOR = Color.RED
const NEUTRAL_COLOR = Color.BLUE
const INFO_COLOR = Color.CYAN

# Visual feedback constants
const ANIMATION_DURATION = 0.3
const HOVER_SCALE = 1.05
const NORMAL_SCALE = 1.0

# Card properties
@export var card_id: String = ""
@export var card_title: String = ""
@export var card_description: String = ""
@export var card_type: String = "info"
@export var is_interactive: bool = true
@export var show_context_label: bool = true

# Visual elements
@onready var main_container: Control = %MainContainer
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var context_label: Label = %ContextLabel
@onready var visual_indicator: Control = %VisualIndicator
@onready var action_button: Button = %ActionButton

# Internal state
var card_data: Dictionary = {}
var is_selected: bool = false
var is_hovered: bool = false

func _ready() -> void:
	_setup_card()
	_connect_signals()
	_apply_visual_theme()

## Abstract methods for implementation
func display_data(data: Dictionary) -> void:
	push_error("Must implement display_data in subclass")
	pass

func get_context_label() -> String:
	push_error("Must implement get_context_label in subclass")
	return ""

func get_card_type() -> String:
	push_error("Must implement get_card_type in subclass")
	return "info"

## Universal Safety setup
func _setup_card() -> void:
	if not main_container:
		push_warning("BaseInformationCard: MainContainer not found - creating default")
		main_container = VBoxContainer.new()
		main_container.name = "MainContainer"
		add_child(main_container)
	
	if not title_label:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.add_to_group("card_labels")
		main_container.add_child(title_label)
	
	if not description_label:
		description_label = Label.new()
		description_label.name = "DescriptionLabel"
		description_label.add_to_group("card_labels")
		main_container.add_child(description_label)
	
	if not context_label and show_context_label:
		context_label = Label.new()
		context_label.name = "ContextLabel"
		context_label.add_to_group("card_labels")
		main_container.add_child(context_label)

## Signal connections with Universal Safety
func _connect_signals() -> void:
	if action_button:
		action_button.pressed.connect(_on_action_button_pressed)
	
	# Connect mouse events for interactive cards
	if is_interactive:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		gui_input.connect(_on_gui_input)

## Visual theme application following dice system patterns
func _apply_visual_theme() -> void:
	# Apply color coding based on card type
	var card_color = _get_color_for_type(get_card_type())
	
	if title_label:
		title_label.add_theme_color_override("font_color", card_color)
	
	if visual_indicator:
		visual_indicator.modulate = card_color
	
	# Apply responsive sizing
	custom_minimum_size = Vector2(200, 100)
	
	# Add to touch-friendly group for mobile
	add_to_group("touch_cards")

## Color coding system from Digital Dice System
func _get_color_for_type(card_type: String) -> Color:
	match card_type.to_lower():
		"success", "positive", "good":
			return SUCCESS_COLOR
		"warning", "caution", "medium":
			return WARNING_COLOR
		"danger", "negative", "bad", "critical":
			return DANGER_COLOR
		"info", "neutral", "default":
			return NEUTRAL_COLOR
		"highlight", "special":
			return INFO_COLOR
		_:
			return NEUTRAL_COLOR

## Context label management
func set_context_label(context: String) -> void:
	if context_label:
		context_label.text = context
		context_label.visible = not context.is_empty()

## Visual feedback methods
func _on_mouse_entered() -> void:
	if not is_interactive:
		return
	
	is_hovered = true
	_animate_hover_enter()

func _on_mouse_exited() -> void:
	if not is_interactive:
		return
	
	is_hovered = false
	_animate_hover_exit()

func _on_gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_card_clicked()

func _on_action_button_pressed() -> void:
	card_action_requested.emit("button_pressed", card_data)

func _on_card_clicked() -> void:
	is_selected = !is_selected
	card_selected.emit(card_data)
	_animate_selection()

## Animation methods following dice system patterns
func _animate_hover_enter() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), ANIMATION_DURATION)
	tween.tween_property(self, "modulate:a", 0.9, ANIMATION_DURATION)

func _animate_hover_exit() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(NORMAL_SCALE, NORMAL_SCALE), ANIMATION_DURATION)
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)

func _animate_selection() -> void:
	var tween = create_tween()
	if is_selected:
		tween.tween_property(self, "modulate", Color.WHITE, ANIMATION_DURATION)
	else:
		tween.tween_property(self, "modulate", Color.WHITE, ANIMATION_DURATION)

## Public API methods
func update_card(data: Dictionary) -> void:
	card_data = data
	display_data(data)
	card_updated.emit(card_id)

func set_card_title(title: String) -> void:
	card_title = title
	if title_label:
		title_label.text = title

func set_card_description(description: String) -> void:
	card_description = description
	if description_label:
		description_label.text = description

func set_interactive(interactive: bool) -> void:
	is_interactive = interactive
	# Update visual state based on interactivity
	modulate.a = 1.0 if interactive else 0.7

## Universal Safety setup method
func setup_with_safety_validation(data: Variant = null) -> void:
	"""Setup card with safety validation following Universal Safety patterns"""
	
	# Validate data if provided
	if data != null:
		if data is Dictionary:
			card_data = data
			# Extract basic properties safely
			card_title = data.get("title", "")
			card_description = data.get("description", "")
			card_type = data.get("type", "info")
			card_id = data.get("id", "")
		else:
			push_warning("BaseInformationCard: Invalid data type for setup_with_safety_validation")
	
	# Ensure card is properly initialized
	_setup_card()
	_connect_signals()
	_apply_visual_theme()
	
	# Display data if available
	if not card_data.is_empty():
		display_data(card_data)

## Utility methods
func get_card_data() -> Dictionary:
	return card_data

func is_card_selected() -> bool:
	return is_selected

func clear_selection() -> void:
	is_selected = false
	_animate_selection()
