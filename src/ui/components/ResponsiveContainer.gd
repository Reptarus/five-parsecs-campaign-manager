@tool
class_name ResponsiveContainer
extends Container

## A container that adapts its layout based on screen size and theme settings
##
## This container automatically adjusts its layout based on the current screen size
## and theme settings. It can switch between horizontal and vertical layouts
## and adjust spacing based on the current UI scale.

signal layout_changed(is_compact: bool)

enum ResponsiveLayoutMode {
	AUTO, ## Automatically determine layout based on available width
	HORIZONTAL, ## Force horizontal layout
	VERTICAL, ## Force vertical layout
}

## The minimum width at which to use horizontal layout (in pixels)
@export var min_width_for_horizontal: int = 600:
	set(value):
		min_width_for_horizontal = value
		queue_sort()

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

## The current UI scale factor
var _scale_factor: float = 1.0

## Reference to the theme manager
var _theme_manager = null # Will be assigned in _find_theme_manager

func _ready() -> void:
	# Connect to size changed signal
	resized.connect(_on_resized)
	
	# Find theme manager in the scene tree
	_find_theme_manager()
	
	# Initial layout update
	_update_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()
	elif what == NOTIFICATION_THEME_CHANGED:
		_update_from_theme()

func _find_theme_manager() -> void:
	# Try to find the theme manager in the scene tree
	var node := self
	while node:
		if node.has_node("/root/ThemeManager"):
			_theme_manager = node.get_node("/root/ThemeManager")
			if _theme_manager.has_signal("scale_changed"):
				_theme_manager.scale_changed.connect(_on_scale_changed)
			if _theme_manager.has_signal("theme_changed"):
				_theme_manager.theme_changed.connect(_on_theme_changed)
			break
		node = node.get_parent()

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
		for child in get_children():
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
		for child in get_children():
			if not child is Control or not child.visible:
				continue
				
			var child_min_size: Vector2 = child.get_combined_minimum_size()
			total_width += child_min_size.x
			
			if child.size_flags_horizontal & SIZE_EXPAND:
				expandable_children.append(child)
			else:
				fixed_width += child_min_size.x
		
		# Add spacing
		total_width += h_spacing * (get_child_count() - 1)
		
		# Second pass: position children
		var extra_width: float = max(0.0, size_left.x - total_width)
		var expand_width := 0.0
		if expandable_children.size() > 0:
			expand_width = extra_width / expandable_children.size()
		
		for child in get_children():
			if not child is Control or not child.visible:
				continue
				
			var child_min_size: Vector2 = child.get_combined_minimum_size()
			var child_width: float = child_min_size.x
			
			if child in expandable_children:
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

func _update_layout() -> void:
	queue_sort()

func _update_from_theme() -> void:
	if _theme_manager and _theme_manager.has_method("get_current_scale_factor"):
		_scale_factor = _theme_manager.get_current_scale_factor()
	queue_sort()

func _on_resized() -> void:
	_update_layout()

func _on_scale_changed(scale_factor: float) -> void:
	_scale_factor = scale_factor
	queue_sort()

func _on_theme_changed(_theme) -> void:
	queue_sort()

## Register this container with the UI manager for responsive updates
func register_with_ui_manager() -> void:
	var ui_manager = null
	
	# Try to find the UI manager in the scene tree
	var node := self
	while node:
		if node.has_node("/root/UIManager"):
			ui_manager = node.get_node("/root/UIManager")
			break
		node = node.get_parent()
	
	if ui_manager and ui_manager.has_method("register_responsive_element"):
		ui_manager.register_responsive_element(self)

## Get the current layout mode (compact or not)
func is_compact_layout() -> bool:
	return is_compact

## Force a layout update
func force_layout_update() -> void:
	_update_layout()