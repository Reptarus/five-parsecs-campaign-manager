extends Control

signal crew_preview_selected(crew_data: Dictionary)

@onready var preview_list := $ScrollContainer/VBoxContainer

func _ready() -> void:
	_setup_preview_list()
func _setup_preview_list() -> void:
	# Clear existing previews
	for child in preview_list.get_children():
		child.queue_free()

	# Add new previews
	for crew in _get_available_crews():
		var preview := Button.new()

		preview.text = crew.get("name", "Unknown Crew")
		preview.pressed.connect(_on_preview_selected.bind(crew))
		preview_list.add_child(preview)
func _get_available_crews() -> Array:
	# This would be replaced with actual crew data loading
	return []

func _on_preview_selected(crew_data: Dictionary) -> void:
	crew_preview_selected.emit(crew_data)

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null