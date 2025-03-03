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
		var preview = Button.new()
		preview.text = crew.get("name", "Unknown Crew")
		preview.pressed.connect(_on_preview_selected.bind(crew))
		preview_list.add_child(preview)

func _get_available_crews() -> Array:
	# This would be replaced with actual crew data loading
	return []

func _on_preview_selected(crew_data: Dictionary) -> void:
	crew_preview_selected.emit(crew_data)
