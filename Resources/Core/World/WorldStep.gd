extends CampaignResponsiveLayout

signal step_completed(step: int)
signal phase_completed

@onready var step_label = $MarginContainer/VBoxContainer/StepLabel
@onready var event_log = $MarginContainer/VBoxContainer/EventLog/ScrollContainer/EventLogText
@onready var main_content = $MarginContainer/VBoxContainer/HSplitContainer/MainContent
@onready var side_panel = $MarginContainer/VBoxContainer/HSplitContainer/SidePanel

# Touch-friendly minimum sizes
const TOUCH_BUTTON_HEIGHT := 60
const TOUCH_ITEM_HEIGHT := 50
const PORTRAIT_SIDE_PANEL_HEIGHT_RATIO := 0.3  # 30% of screen height in portrait mode

func _ready() -> void:
	super._ready()
	_setup_world_phase_ui()
	_connect_signals()

func _setup_world_phase_ui() -> void:
	_setup_step_indicators()
	_setup_main_panels()
	_setup_event_log()

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	# Stack main content and side panel vertically
	$MarginContainer/VBoxContainer/HSplitContainer.vertical = true
	
	# Adjust panel sizes for portrait mode
	side_panel.custom_minimum_size.y = get_viewport_rect().size.y * PORTRAIT_SIDE_PANEL_HEIGHT_RATIO
	main_content.custom_minimum_size.y = 0  # Let it take remaining space
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)
	
	# Adjust margins for mobile
	$MarginContainer.add_theme_constant_override("margin_left", 10)
	$MarginContainer.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	# Place main content and side panel side by side
	$MarginContainer/VBoxContainer/HSplitContainer.vertical = false
	
	# Reset panel sizes for landscape mode
	side_panel.custom_minimum_size = Vector2(300, 0)
	main_content.custom_minimum_size = Vector2(600, 0)
	
	# Reset control sizes
	_adjust_touch_sizes(false)
	
	# Reset margins
	$MarginContainer.add_theme_constant_override("margin_left", 20)
	$MarginContainer.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	var item_height = TOUCH_ITEM_HEIGHT if is_portrait else TOUCH_ITEM_HEIGHT * 0.75
	
	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height
	
	# Adjust all list items
	for list in get_tree().get_nodes_in_group("touch_lists"):
		if list is ItemList:
			list.fixed_item_height = item_height
	
	# Adjust step indicators
	var step_buttons = $MarginContainer/VBoxContainer/StepIndicator.get_children()
	for button in step_buttons:
		if button is Button:
			button.custom_minimum_size.y = button_height

func _setup_step_indicators() -> void:
	var step_container = $MarginContainer/VBoxContainer/StepIndicator
	for button in step_container.get_children():
		if button is Button:
			button.add_to_group("touch_buttons")
			button.custom_minimum_size.y = TOUCH_BUTTON_HEIGHT

func _setup_main_panels() -> void:
	# Add panels to groups for touch size adjustment
	for panel in main_content.get_children():
		if panel.has_node("CrewList"):
			panel.get_node("CrewList").add_to_group("touch_lists")
		if panel.has_node("TaskAssignment"):
			panel.get_node("TaskAssignment").add_to_group("touch_buttons")

func _setup_event_log() -> void:
	event_log.add_theme_constant_override("line_separation", 10)

func _connect_signals() -> void:
	# Connect your existing signals here
	pass
