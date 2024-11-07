class_name TutorialSystem
extends Node

# Signals from various tutorial classes
signal tutorial_step_changed(step: String)
signal tutorial_completed(type: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_track_completed(track_id: String)

# Components
var tutorial_manager: GameTutorialManager
var tutorial_ui: TutorialUI
var tutorial_progress: Resource # Changed to Resource for data container
var tutorial_content: Resource # Changed to Resource for data container

# Update to use GameStateManager
var game_state_manager: GameStateManager

func _ready() -> void:
    game_state_manager = get_node("/root/GameStateManager")
    if not game_state_manager:
        push_error("GameStateManager not found")
        return
        
    tutorial_manager = GameTutorialManager.new()
    tutorial_ui = TutorialUI.new()
    tutorial_progress = load("res://Resources/GameData/TutorialProgress.tres") # Load as Resource
    tutorial_content = load("res://Resources/GameData/TutorialContent.tres") # Load as Resource
    
    _connect_signals()

func _connect_signals() -> void:
    tutorial_manager.tutorial_step_changed.connect(_on_step_changed)
    tutorial_manager.tutorial_completed.connect(_on_tutorial_completed)
    tutorial_ui.tutorial_step_completed.connect(_on_step_completed)
    tutorial_ui.tutorial_track_completed.connect(_on_track_completed)

func start_tutorial(type: GameTutorialManager.TutorialTrack) -> void:
    tutorial_manager.start_tutorial(type)
    tutorial_ui.show()
    
func _on_step_changed(step: String) -> void:
    tutorial_ui.update_content(tutorial_content.get_step_content(step))
    tutorial_progress.save_progress()

func _on_tutorial_completed(type: String) -> void:
    tutorial_progress.mark_track_complete(type)
    tutorial_ui.hide()

func _on_step_completed(step_id: String) -> void:
    tutorial_progress.complete_step(step_id)
    tutorial_manager.advance_tutorial()

func _on_track_completed(track_id: String) -> void:
    tutorial_progress.complete_track(track_id)
    tutorial_manager.end_tutorial() 