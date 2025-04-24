@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends "res://src/ui/components/base/ResponsiveContainer.gd"
const CampaignResponsiveLayoutClass := "res://src/ui/components/base/CampaignResponsiveLayout.gd" # Class reference as string path

## Campaign-specific responsive layout component
##
## Extends the base responsive container to provide campaign-specific
## layout functionality, including sidebars and touch-friendly controls

# Use parent's ThisClass for parent class references, use CampaignResponsiveLayoutClass for self-references

# Type-safe constants with explicit types
const PORTRAIT_SIDEBAR_HEIGHT_RATIO: float = 0.4 # Sidebar takes 40% in portrait mode
const LANDSCAPE_SIDEBAR_WIDTH: float = 300.0 # Fixed sidebar width in landscape mode
const TOUCH_BUTTON_HEIGHT: float = 60.0 # Height for touch-friendly buttons

# Type-annotated variables for improved type safety
@onready var sidebar: Control = $MainContainer/Sidebar if has_node("MainContainer/Sidebar") else null
@onready var main_content: Control = $MainContainer/MainContent if has_node("MainContainer/MainContent") else null

# Signal for back button actions
signal back_pressed

func _ready() -> void:
	# Ensure parent _ready is called
	super._ready()
	_setup_touch_controls()
	_connect_signals()

## Sets up touch-friendly controls for mobile devices
func _setup_touch_controls() -> void:
	if OS.has_feature("mobile"):
		var touch_buttons = get_tree().get_nodes_in_group("touch_buttons")
		for i in range(touch_buttons.size()):
			var button = touch_buttons[i]
			if button is Control:
				button.custom_minimum_size.y = TOUCH_BUTTON_HEIGHT
		
		var touch_lists = get_tree().get_nodes_in_group("touch_lists")
		for i in range(touch_lists.size()):
			var list = touch_lists[i]
			if list and "fixed_item_height" in list:
				list.fixed_item_height = TOUCH_BUTTON_HEIGHT

## Connects internal signals for the responsive layout
func _connect_signals() -> void:
	if not sidebar:
		return
		
	if sidebar.has_signal("back_pressed"):
		if sidebar.back_pressed.is_connected(_on_back_pressed):
			sidebar.back_pressed.disconnect(_on_back_pressed)
		sidebar.back_pressed.connect(_on_back_pressed)

## Initializes the layout with the parent control
## @param parent_control: The parent control to attach to
func initialize(parent_control: Control) -> void:
	if not parent_control:
		push_error("Cannot initialize layout with null parent control")
		return
		
	# Connect to the parent control and set up responsive behavior
	var parent_size: Vector2 = parent_control.size
	size = parent_size
	
	# Connect to parent resizing
	if parent_control.resized.is_connected(_on_parent_resized):
		parent_control.resized.disconnect(_on_parent_resized)
	parent_control.resized.connect(_on_parent_resized)
	
	# Add this layout to the parent
	if not is_inside_tree() and parent_control.is_inside_tree():
		parent_control.add_child(self)
	
	# Force layout update
	_check_orientation()

## Handle parent resizing
func _on_parent_resized() -> void:
	var parent := get_parent() as Control
	if parent:
		size = parent.size

## Override _apply_portrait_layout from the base class
func _apply_portrait_layout() -> void:
	if not main_container or not sidebar or not main_content:
		return
	
	# Stack panels vertically with BoxContainer orientation
	if main_container.has_method("set"):
		main_container.set("vertical", true)
	# For VBoxContainer
	elif "vertical" in main_container:
		main_container.vertical = true
	
	# Adjust panel sizes for portrait mode
	var viewport_height: float = get_viewport_rect().size.y
	sidebar.custom_minimum_size.y = viewport_height * PORTRAIT_SIDEBAR_HEIGHT_RATIO
	sidebar.custom_minimum_size.x = 0
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)

## Override _apply_landscape_layout from the base class
func _apply_landscape_layout() -> void:
	if not main_container or not sidebar or not main_content:
		return
	
	# Side by side layout with BoxContainer orientation
	if main_container.has_method("set"):
		main_container.set("vertical", false)
	# For HBoxContainer
	elif "vertical" in main_container:
		main_container.vertical = false
	
	# Reset panel sizes
	sidebar.custom_minimum_size = Vector2(LANDSCAPE_SIDEBAR_WIDTH, 0)
	
	# Reset control sizes
	_adjust_touch_sizes(false)

## Adjusts control sizes for touch interaction
## @param is_portrait: Whether the device is in portrait mode
func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height: float = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons with safer iteration
	var touch_buttons = get_tree().get_nodes_in_group("touch_buttons")
	for i in range(touch_buttons.size()):
		var button = touch_buttons[i]
		if button is Control:
			button.custom_minimum_size.y = button_height
	
	# Adjust list items with safer iteration
	var touch_lists = get_tree().get_nodes_in_group("touch_lists")
	for i in range(touch_lists.size()):
		var list = touch_lists[i]
		if list and "fixed_item_height" in list:
			list.fixed_item_height = button_height

## Handler for back button press
func _on_back_pressed() -> void:
	# Emit our own signal for parent classes to handle
	back_pressed.emit()

## Returns the current breakpoints for responsive layouts
## @return: Dictionary containing breakpoint values
func get_breakpoints() -> Dictionary:
	return {
		"phone": 480.0,
		"tablet": 768.0,
		"desktop": 1280.0
	}

## Checks if the current layout is phone-sized
## @return: True if the layout is phone-sized
func is_phone() -> bool:
	var breakpoints: Dictionary = get_breakpoints()
	return size.x < breakpoints.phone

## Checks if the current layout is tablet-sized
## @return: True if the layout is tablet-sized
func is_tablet() -> bool:
	var breakpoints: Dictionary = get_breakpoints()
	return size.x >= breakpoints.phone and size.x < breakpoints.desktop

## Checks if the current layout is desktop-sized
## @return: True if the layout is desktop-sized
func is_desktop() -> bool:
	var breakpoints: Dictionary = get_breakpoints()
	return size.x >= breakpoints.desktop

## Checks if the current orientation is portrait
## @return: True if the orientation is portrait
func get_is_portrait() -> bool:
	return size.y > size.x

## Checks if the component has a specific theme constant
## @param name: Name of the theme constant
## @return: True if the component has the theme constant
func has_theme_constant(name: StringName, type: StringName = &"") -> bool:
	return super.has_theme_constant(name, type if not type.is_empty() else &"CampaignResponsiveLayout")
