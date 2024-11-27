class_name TutorialSystem
extends Node

# Signals from various tutorial classes
signal tutorial_step_changed(step_id: String)
signal tutorial_completed(track_id: String)
signal tutorial_step_completed
signal tutorial_track_completed

# Components with proper typing
@onready var tutorial_manager: GameTutorialManager
@onready var tutorial_ui: Control
@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")

# Resources
var tutorial_progress: Resource
var tutorial_content: Resource

func _ready() -> void:
	if not game_state_manager:
		push_error("GameStateManager not found")
		return
		
	# Create resources if they don't exist
	var progress_path := "res://Resources/GameData/TutorialProgress.tres"
	var content_path := "res://Resources/GameData/TutorialContent.tres"
	
	if not ResourceLoader.exists(progress_path):
		tutorial_progress = Resource.new()
		ResourceSaver.save(tutorial_progress, progress_path)
	else:
		tutorial_progress = load(progress_path) as Resource
		
	if not ResourceLoader.exists(content_path):
		tutorial_content = Resource.new()
		ResourceSaver.save(tutorial_content, content_path)
	else:
		tutorial_content = load(content_path) as Resource
	
	_initialize_components()
	_connect_signals()

func _initialize_components() -> void:
	tutorial_manager = GameTutorialManager.new()
	tutorial_manager.name = "TutorialManager"
	add_child(tutorial_manager)
	
	tutorial_ui = Control.new()
	tutorial_ui.name = "TutorialUI"
	add_child(tutorial_ui)

func _connect_signals() -> void:
	if tutorial_manager:
		tutorial_manager.tutorial_step_completed.connect(_on_step_completed)
		tutorial_manager.tutorial_track_completed.connect(_on_track_completed)
	else:
		push_error("TutorialManager not initialized")

func start_tutorial(type: GlobalEnums.TutorialType) -> void:
	if not tutorial_manager:
		push_error("Tutorial manager not initialized")
		return
		
	# Convert GlobalEnums.TutorialType to GameTutorialManager.TutorialTrack
	var tutorial_track: GameTutorialManager.TutorialTrack
	match type:
		GlobalEnums.TutorialType.QUICK_START:
			tutorial_track = GameTutorialManager.TutorialTrack.QUICK_START
		GlobalEnums.TutorialType.ADVANCED:
			tutorial_track = GameTutorialManager.TutorialTrack.ADVANCED
		_:
			push_error("Unsupported tutorial type")
			return
			
	tutorial_manager.start_tutorial(tutorial_track)
	tutorial_ui.show()

func _on_step_changed(step: String) -> void:
	if tutorial_content and tutorial_ui:
		tutorial_ui.update_content(tutorial_content.get_step_content(step))
		tutorial_progress.save_progress()

func _on_tutorial_completed(_track_id: String = "") -> void:
	tutorial_completed.emit()

func _on_step_completed(step_id: String) -> void:
	if tutorial_progress and tutorial_manager:
		tutorial_progress.complete_step(step_id)
		tutorial_manager.advance_tutorial()

func _on_track_completed(track_id: String) -> void:
	if tutorial_progress and tutorial_manager:
		tutorial_progress.complete_track(track_id)
		tutorial_manager.end_tutorial()
