# This file should be referenced via preload
# Use explicit preloads instead of global class names
@tool
extends Container

## A unified responsive container that adapts to screen size and orientation
##
## This container automatically adjusts its layout based on screen size,
## orientation, and theme settings. It can switch between horizontal and
## vertical layouts, and supports both width-based and aspect ratio-based
## responsiveness.

# Signals
signal layout_changed(is_compact: bool)
signal orientation_changed(is_portrait: bool)

# Layout mode options
enum ResponsiveLayoutMode {
	AUTO, ## Automatically determine layout based on available width
	HORIZONTAL, ## Force horizontal layout
	VERTICAL, ## Force vertical layout
}

# Orientation constants
const ORIENTATION_PORTRAIT := 0
const ORIENTATION_LANDSCAPE := 1

# Class reference - using a direct resource path instead of preload to avoid circular reference
const ThisClass := "res://src/ui/components/base/ResponsiveContainer.gd"

## The minimum width at which to use horizontal layout (in pixels)
@export var min_width_for_horizontal: int = 600:
	set(value):
		min_width_for_horizontal = value
		queue_sort()

## Width/Height ratio threshold for portrait mode
@export var portrait_threshold := 1.0:
	set(value):
		portrait_threshold = value
		_check_orientation()

## The layout mode to use
@export var responsive_mode: ResponsiveLayoutMode = ResponsiveLayoutMode.AUTO:
	set(value):
		responsive_mode = value
		queue_sort()

## Spacing between children when in horizontal layout
@export var horizontal_spacing: int = 10:
	set(value):
		horizontal_spacing = value
		queue_sort()

## Spacing between children when in vertical layout
@export var vertical_spacing: int = 10:
	set(value):
		vertical_spacing = value
		queue_sort()

## Padding around the container
@export var padding: int = 10:
	set(value):
		padding = value
		queue_sort()

## Whether the container is currently in compact (vertical) mode
var is_compact: bool = false

## Whether the container is currently in portrait orientation
var is_portrait: bool = false

## The current UI scale factor
var _scale_factor: float = 1.0

## Reference to the theme manager
var _theme_manager = null # Will be assigned in _find_theme_manager

## Main container node (for backward compatibility with older implementation)
var main_container: Container

func _ready() -> void:
	# Connect to size changed signal
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	
	# Find theme manager in the scene tree
	_find_theme_manager()
	
	# Setup container if present for backward compatibility
	_setup_container()
	
	# Initial layout update
	_update_layout()
	_check_orientation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()
	elif what == NOTIFICATION_THEME_CHANGED:
		_update_from_theme()

func _find_theme_manager() -> void:
	# Try to find the theme manager in the scene tree
	var node := self as Node
	while node:
		if node.has_node("/root/ThemeManager"):
			_theme_manager = node.get_node("/root/ThemeManager")
			if _theme_manager and _theme_manager.has_signal("scale_changed"):
				if not _theme_manager.is_connected("scale_changed", Callable(self, "_on_scale_changed")):
					_theme_manager.connect("scale_changed", Callable(self, "_on_scale_changed"))
			if _theme_manager and _theme_manager.has_signal("theme_changed"):
				if not _theme_manager.is_connected("theme_changed", Callable(self, "_on_theme_changed")):
					_theme_manager.connect("theme_changed", Callable(self, "_on_theme_changed"))
			break
		node = node.get_parent()
	
	# If theme manager not found, try loading it directly
	if not _theme_manager and Engine.has_singleton("ThemeManager"):
		_theme_manager = Engine.get_singleton("ThemeManager")

func _setup_container() -> void:
	# For backward compatibility with the Control-based implementation
	main_container = $MainContainer if has_node("MainContainer") else null

func _sort_children() -> void:
	# Determine if we should use compact layout
	var use_compact := _should_use_compact_layout()
	
	# If layout mode changed, emit signal
	if is_compact != use_compact:
		is_compact = use_compact
		layout_changed.emit(is_compact)
	
	# Apply the current scale factor to spacing
	var h_spacing := int(horizontal_spacing * _scale_factor)
	var v_spacing := int(vertical_spacing * _scale_factor)
	var p := int(padding * _scale_factor)
	
	# Calculate positions for children
	var pos := Vector2(p, p)
	var size_left := size - Vector2(p * 2, p * 2)
	
	if is_compact:
		# Vertical layout
		for i in range(get_child_count()):
			var child = get_child(i)
			if not child is Control or not child.visible:
				continue
				
			var child_min_size: Vector2 = child.get_combined_minimum_size()
			var rect := Rect2(pos, Vector2(size_left.x, child_min_size.y))
			fit_child_in_rect(child, rect)
			
			pos.y += child_min_size.y + v_spacing
	else:
		# Horizontal layout
		var total_width := 0
		var expandable_children: Array[Control] = []
		var fixed_width := 0
		
		# First pass: calculate total minimum width and find expandable children
		for i in range(get_child_count()):
			var child = get_child(i)
			if not child is Control or not child.visible:
				continue
				
			var child_min_size: Vector2 = child.get_combined_minimum_size()
			total_width += child_min_size.x
			
			if child.size_flags_horizontal & SIZE_EXPAND:
				expandable_children.append(child)
			else:
				fixed_width += child_min_size.x
		
		# Add spacing
		var child_count := 0
		for i in range(get_child_count()):
			var child = get_child(i)
			if child is Control and child.visible:
				child_count += 1
		
		if child_count > 1:
			total_width += h_spacing * (child_count - 1)
		
		# Second pass: position children
		var extra_width: float = max(0.0, size_left.x - total_width)
		var expand_width := 0.0
		if expandable_children.size() > 0:
			expand_width = extra_width / expandable_children.size()
		
		for i in range(get_child_count()):
			var child = get_child(i)
			if not child is Control or not child.visible:
				continue
				
			var child_min_size: Vector2 = child.get_combined_minimum_size()
			var child_width: float = child_min_size.x
			
			if expandable_children.has(child):
				child_width += expand_width
			
			var rect := Rect2(pos, Vector2(child_width, size_left.y))
			fit_child_in_rect(child, rect)
			
			pos.x += child_width + h_spacing

func _should_use_compact_layout() -> bool:
	match responsive_mode:
		ResponsiveLayoutMode.HORIZONTAL:
			return false
		ResponsiveLayoutMode.VERTICAL:
			return true
		_: # AUTO
			var scaled_min_width := min_width_for_horizontal * _scale_factor
			return size.x < scaled_min_width

func _check_orientation() -> void:
	if size.y <= 0:
		return # Avoid division by zero
		
	var size_ratio := size.x / size.y
	var new_is_portrait := size_ratio < portrait_threshold or size.x < min_width_for_horizontal
	
	if new_is_portrait != is_portrait:
		is_portrait = new_is_portrait
		_apply_layout()
		orientation_changed.emit(is_portrait)

func _apply_layout() -> void:
	if main_container != null:
		# For backward compatibility with the Control-based implementation
		if is_portrait:
			_apply_portrait_layout()
		else:
			_apply_landscape_layout()
	else:
		# Default implementation just updates layout
		_update_layout()

func _apply_portrait_layout() -> void:
	# Override in child classes
	pass

func _apply_landscape_layout() -> void:
	# Override in child classes
	pass

func _update_layout() -> void:
	queue_sort()

func _update_from_theme() -> void:
	if _theme_manager and _theme_manager.has_method("get_current_scale_factor"):
		_scale_factor = _theme_manager.get_current_scale_factor()
	queue_sort()

func _on_resized() -> void:
	_update_layout()
	_check_orientation()

func _on_scale_changed(scale_factor: float) -> void:
	_scale_factor = scale_factor
	queue_sort()

func _on_theme_changed(_theme) -> void:
	queue_sort()

## Force an immediate layout update
func force_layout_update() -> void:
	_update_layout()
	_check_orientation()

## Get the current orientation (portrait or landscape)
func get_current_orientation() -> int:
	return ORIENTATION_PORTRAIT if is_portrait else ORIENTATION_LANDSCAPE

## Cleanup resources and disconnect signals
func cleanup() -> void:
	if _theme_manager:
		if _theme_manager.has_signal("scale_changed") and _theme_manager.is_connected("scale_changed", Callable(self, "_on_scale_changed")):
			_theme_manager.disconnect("scale_changed", Callable(self, "_on_scale_changed"))
		if _theme_manager.has_signal("theme_changed") and _theme_manager.is_connected("theme_changed", Callable(self, "_on_theme_changed")):
			_theme_manager.disconnect("theme_changed", Callable(self, "_on_theme_changed"))
	_theme_manager = null
	
	if resized.is_connected(_on_resized):
		resized.disconnect(_on_resized)

## Register this container with the UI manager for responsive updates
func register_with_ui_manager() -> void:
	var ui_manager = null
	
	# Try to find the UI manager in the scene tree
	var node := self as Node
	while node:
		if node.has_node("/root/UIManager"):
			ui_manager = node.get_node("/root/UIManager")
			break
		node = node.get_parent()
	
	if ui_manager and ui_manager.has_method("register_responsive_element"):
		ui_manager.register_responsive_element(self)

## Update responsive layout (for backward compatibility with test code)
func update_responsive_layout() -> void:
	_update_layout()
	_check_orientation()
