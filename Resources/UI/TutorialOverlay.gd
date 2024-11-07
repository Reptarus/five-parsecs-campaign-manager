class_name TutorialOverlay
extends Control

# Signals
signal tutorial_step_completed(step_id: String)
signal tutorial_track_completed(track_id: String)

# Onready variables
@onready var content_panel := $ContentPanel
@onready var content_label := $ContentPanel/MarginContainer/VBoxContainer/ContentLabel
@onready var next_button := $ContentPanel/MarginContainer/VBoxContainer/ButtonContainer/NextButton
@onready var skip_button := $ContentPanel/MarginContainer/VBoxContainer/ButtonContainer/SkipButton

# Member variables
var current_step: String = ""
var tutorial_manager: GameTutorialManager

func _ready() -> void:
    # Get reference to tutorial manager
    tutorial_manager = get_node("/root/TutorialManager") as GameTutorialManager
    if not tutorial_manager:
        push_error("TutorialManager not found")
        return
        
    # Connect button signals
    next_button.pressed.connect(_on_next_pressed)
    skip_button.pressed.connect(_on_skip_pressed)
    
    # Start hidden
    hide()
    
    # Make sure we're on top
    set_as_top_level(true)

func update_content(content: Dictionary) -> void:
    content_label.text = content.get("text", "")
    current_step = content.get("id", "")
    
    # Position overlay based on content target
    if content.has("target_node"):
        position_overlay(content.target_node)

func position_overlay(target: Node) -> void:
    if target and is_instance_valid(target):
        var target_global_pos = target.get_global_position()
        var target_size = target.get_size()
        
        # Position panel next to target
        content_panel.global_position = target_global_pos + Vector2(target_size.x + 10, 0)
        
        # Keep panel on screen
        var viewport_size = get_viewport_rect().size
        if content_panel.global_position.x + content_panel.size.x > viewport_size.x:
            content_panel.global_position.x = target_global_pos.x - content_panel.size.x - 10

func _on_next_pressed() -> void:
    tutorial_step_completed.emit(current_step)

func _on_skip_pressed() -> void:
    if tutorial_manager:
        tutorial_track_completed.emit(tutorial_manager.current_tutorial)
    else:
        push_warning("TutorialManager not found, cannot emit track completion")

func show_tutorial() -> void:
    show()
    
func hide_tutorial() -> void:
    hide()