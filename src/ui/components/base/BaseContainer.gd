# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Container
class_name FPCM_BaseContainer

## Base container class for UI layout management
## Provides horizontal and vertical layout capabilities with spacing

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

enum ContainerOrientation {
	HORIZONTAL,
	VERTICAL
}

@export var orientation: ContainerOrientation = ContainerOrientation.HORIZONTAL
@export var spacing: float = 10.0

func _ready() -> void:
	_validate_universal_connections()
	_setup_signal_connections()

func _validate_universal_connections() -> void:
	# Validate UI component connections
	_validate_base_container_connections()

func _validate_base_container_connections() -> void:
	# BaseContainer is self-contained, but validate basic functionality
	if not has_method("get_children"):
		push_error("UI SYSTEM FAILURE: BaseContainer missing get_children method")

func _setup_signal_connections() -> void:
	# Connect sort_children signal safely
	self.sort_children.connect(_on_sort_children)

func _on_sort_children() -> void:
	var offset := Vector2.ZERO
	var available_size := size

	for child in get_children():
		if not child is Control or not child.visible:
			continue

		var child_min_size: Vector2 = child.get_combined_minimum_size()
		var child_size := Vector2.ZERO

		match orientation:
			ContainerOrientation.HORIZONTAL:
				child_size.x = child_min_size.x
				child_size.y = available_size.y
				if offset.x + child_size.x > available_size.x:
					offset.x = 0
					offset.y += child_min_size.y + spacing
			ContainerOrientation.VERTICAL:
				child_size.x = available_size.x
				child_size.y = child_min_size.y
				if offset.y + child_size.y > available_size.y:
					offset.y = 0
					offset.x += child_min_size.x + spacing

		fit_child_in_rect(child, Rect2(offset, child_size))

		match orientation:
			ContainerOrientation.HORIZONTAL:
				offset.x += child_size.x + spacing
			ContainerOrientation.VERTICAL:
				offset.y += child_size.y + spacing