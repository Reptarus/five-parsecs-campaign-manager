# CrewSizeSelection.gd
extends Control

signal crew_size_selected(size: int)

@onready var size_slider: HSlider = $HSlider
@onready var size_label: Label = $Label
@onready var crew_visual: Control = $CrewVisual

var min_crew_size: int = 3
var max_crew_size: int = 8
var current_size: int = 5

func _ready() -> void:
	size_slider.min_value = min_crew_size
	size_slider.max_value = max_crew_size
	size_slider.value = current_size
	update_ui()
	size_slider.value_changed.connect(_on_size_changed)
	$Next.pressed.connect(_on_confirm_pressed)
	$Back.pressed.connect(_on_back_pressed)

func _on_size_changed(new_size: float) -> void:
	current_size = int(new_size)
	update_ui()

func update_ui() -> void:
	size_label.text = str(current_size) + " Members"
	update_crew_visual()

func update_crew_visual() -> void:
	for i in range(max_crew_size):
		var member_icon: TextureRect = crew_visual.get_child(i)
		member_icon.visible = i < current_size

func _on_confirm_pressed() -> void:
	crew_size_selected.emit(current_size)

func _on_back_pressed() -> void:
	# Implement back functionality (e.g., returning to the previous scene)
	pass
