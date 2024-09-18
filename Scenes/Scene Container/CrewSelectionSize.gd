# CrewSizeSelection.gd
extends Control

signal crew_size_selected(size: int)

@onready var slider = $HSlider
@onready var tutorial_label = $TutorialLabel

func _ready():
	if TutorialManager.is_tutorial_active:
		tutorial_label.text = TutorialManager.get_tutorial_text("crew_size_selection")
		tutorial_label.show()
	else:
		tutorial_label.hide()

	slider.connect("value_changed", _on_slider_value_changed)

func _on_slider_value_changed(value):
	emit_signal("crew_size_selected", int(value))
	if TutorialManager.is_tutorial_active:
		TutorialManager.set_step("campaign_setup")
