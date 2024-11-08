# Renamed from TutorialManager.gd to TutorialUI.gd
class_name TutorialUI
extends Control

const TOUCH_BUTTON_HEIGHT := 60
const MIN_TOUCH_TARGET := 44  # Minimum touch target size

@onready var tutorial_panel := $TutorialPanel
@onready var content_label := $TutorialPanel/ContentLabel
@onready var next_button := $TutorialPanel/ButtonContainer/NextButton
@onready var skip_button := $TutorialPanel/ButtonContainer/SkipButton
@onready var pause_button := $TutorialPanel/ButtonContainer/PauseButton

var current_step: String = ""
var tutorial_manager: GameTutorialManager

func _ready() -> void:
    tutorial_manager = get_node("/root/GameStateManager").tutorial_manager
    if not tutorial_manager:
        push_error("TutorialManager not found")
        return
    
    _setup_mobile_ui()
    _connect_signals()

func _setup_mobile_ui() -> void:
    if OS.has_feature("mobile"):
        # Adjust button sizes
        for button in [$NextButton, $SkipButton, $PauseButton]:
            button.custom_minimum_size = Vector2(MIN_TOUCH_TARGET, TOUCH_BUTTON_HEIGHT)
        
        # Add touch feedback
        for button in get_tree().get_nodes_in_group("tutorial_buttons"):
            button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _connect_signals() -> void:
    if tutorial_manager:
        tutorial_manager.tutorial_step_changed.connect(_on_tutorial_step_changed)
        tutorial_manager.tutorial_completed.connect(_on_tutorial_completed)
    
    if next_button:
        next_button.pressed.connect(_on_next_pressed)
    if skip_button:
        skip_button.pressed.connect(_on_skip_pressed)
    if pause_button:
        pause_button.pressed.connect(_on_pause_pressed)

func _on_tutorial_step_changed(step: String) -> void:
    current_step = step
    if tutorial_manager:
        var content = tutorial_manager.get_step_content(step)
        update_content(content)

func _on_tutorial_completed(_type: String) -> void:
    hide()

func _on_next_pressed() -> void:
    tutorial_manager.advance_tutorial()

func _on_skip_pressed() -> void:
    tutorial_manager.complete_tutorial()

func _on_pause_pressed() -> void:
    tutorial_manager.pause_tutorial()

func update_content(content: Dictionary) -> void:
    current_step = content.get("id", "")
    content_label.text = content.get("content", "")
    
    # Update UI based on step requirements
    skip_button.visible = tutorial_manager.can_skip
    
    # Position tutorial panel based on focus target
    if content.has("focus_target"):
        _position_panel_near_target(content.focus_target)

func _position_panel_near_target(target: Control) -> void:
    if not is_instance_valid(target):
        return
        
    var target_rect = target.get_global_rect()
    var panel_size = tutorial_panel.size
    
    # Try to position panel to the right of target
    var new_pos = target_rect.position + Vector2(target_rect.size.x + 10, 0)
    
    # If panel would go off screen, position below target instead
    if new_pos.x + panel_size.x > get_viewport_rect().size.x:
        new_pos = target_rect.position + Vector2(0, target_rect.size.y + 10)
    
    tutorial_panel.position = new_pos

# ... rest of TutorialUI implementation ...
    