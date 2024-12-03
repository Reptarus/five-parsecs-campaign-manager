class_name TutorialSystem
extends Node

signal tutorial_step_changed(step_id: String)
signal tutorial_completed(track_id: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_track_completed(track_id: String)

# Core components
var tutorial_state: TutorialState
var tutorial_manager: GameTutorialManager
var tutorial_ui: TutorialUI
var tutorial_overlay: TutorialOverlay

# Resources
var tutorial_content: TutorialContent
var tutorial_progress: TutorialProgress

# Add these signal handlers before _ready()
func _on_step_changed(step_id: String) -> void:
	if tutorial_content and tutorial_ui:
		# Convert enum to string for content lookup
		var track_id: String = TutorialState.TutorialTrack.keys()[tutorial_state.current_track].to_lower()
		var content: Dictionary = tutorial_content.get_step_content(track_id, step_id)
		tutorial_ui.update_content(content)
		tutorial_progress.save_progress()

func _on_tutorial_completed(track_id: String) -> void:
	tutorial_completed.emit(track_id)
	tutorial_state.reset()

func _on_step_completed(step_id: String) -> void:
	if tutorial_progress:
		tutorial_progress.complete_step(step_id)
		tutorial_manager.advance_tutorial()

func _on_track_completed(track_id: String) -> void:
	if tutorial_progress:
		tutorial_progress.complete_track(track_id)
		tutorial_manager.end_tutorial()

func _ready() -> void:
	_initialize_components()
	_connect_signals()
	_load_resources()

func _initialize_components() -> void:
	tutorial_state = TutorialState.new()
	tutorial_manager = GameTutorialManager.new()
	
	# Use load() since the scenes don't exist yet
	var ui_scene = load("res://Resources/UI/Scenes/TutorialUI.tscn")
	var overlay_scene = load("res://Resources/UI/Scenes/TutorialOverlay.tscn")
	
	if ui_scene and overlay_scene:
		tutorial_ui = ui_scene.instantiate()
		tutorial_overlay = overlay_scene.instantiate()
		
		add_child(tutorial_manager)
		add_child(tutorial_ui) 
		add_child(tutorial_overlay)
	else:
		push_error("Failed to load tutorial UI scenes")

func _connect_signals() -> void:
	tutorial_manager.tutorial_step_changed.connect(_on_step_changed)
	tutorial_manager.tutorial_completed.connect(_on_tutorial_completed)
	tutorial_overlay.tutorial_step_completed.connect(_on_step_completed)
	tutorial_overlay.tutorial_track_completed.connect(_on_track_completed)

func _load_resources() -> void:
	tutorial_content = load("res://Resources/GameData/TutorialContent.tres")
	tutorial_progress = load("res://Resources/GameData/TutorialProgress.tres")
	
	if not tutorial_content or not tutorial_progress:
		push_error("Failed to load tutorial resources")
