# CrewSizeSelection.gd
extends Control

signal crew_size_selected(size: int)

@onready var slider = $HSlider
@onready var tutorial_label = $TutorialLabel

func _ready():
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager.is_tutorial_active:
		tutorial_label.text = tutorial_manager.get_tutorial_text("crew_size_selection")
		tutorial_label.show()
	else:
		tutorial_label.hide()

	slider.connect("value_changed", _on_slider_value_changed)

func _on_slider_value_changed(value):
	crew_size_selected.emit(int(value))
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager.is_tutorial_active:
		tutorial_manager.set_step("campaign_setup")
