# Renamed from TutorialManager.gd to TutorialUI.gd
class_name TutorialUI
extends Control

signal tutorial_step_completed(step_id: String)
signal tutorial_track_completed(track_id: String)

@onready var overlay_container := $OverlayContainer
@onready var content_label := $OverlayContainer/ContentLabel
@onready var next_button := $OverlayContainer/ButtonContainer/NextButton
@onready var skip_button := $OverlayContainer/ButtonContainer/SkipButton

var current_step: String = ""
var tutorial_manager: GameTutorialManager

func _ready() -> void:
    tutorial_manager = get_node("/root/TutorialManager")
    if not tutorial_manager:
        push_error("TutorialManager not found")
        return
        
    next_button.pressed.connect(_on_next_pressed)
    skip_button.pressed.connect(_on_skip_pressed)
    
    tutorial_manager.tutorial_step_changed.connect(_on_step_changed)

func _on_step_changed(step_id: String) -> void:
    current_step = step_id
    var step_data = tutorial_manager.get_current_step_data()
    if not step_data.is_empty():
        content_label.text = step_data.get("content", "")
        _update_overlay_position()

func _update_overlay_position() -> void:
    # Implement overlay positioning logic
    pass

func _on_next_pressed() -> void:
    tutorial_step_completed.emit(current_step)

func _on_skip_pressed() -> void:
    tutorial_track_completed.emit(tutorial_manager.current_tutorial)
    