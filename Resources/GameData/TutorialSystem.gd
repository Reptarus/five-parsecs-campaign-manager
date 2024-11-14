class_name TutorialSystem
extends Node

# Signals from various tutorial classes
signal tutorial_step_changed(step_id: String)
signal tutorial_completed(track_id: String)
signal tutorial_step_completed
signal tutorial_track_completed

# Components
@onready var tutorial_manager: Node
@onready var tutorial_ui: Node
@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")

# Resources
var tutorial_progress: Resource
var tutorial_content: Resource

func _ready() -> void:
	if not game_state_manager:
		push_error("GameStateManager not found")
		return
		
	# Load resources
	var progress_path := "res://Resources/GameData/TutorialProgress.tres"
	var content_path := "res://Resources/GameData/TutorialContent.tres"
	
	if ResourceLoader.exists(progress_path) and ResourceLoader.exists(content_path):
		tutorial_progress = load(progress_path)
		tutorial_content = load(content_path)
	else:
		push_error("Tutorial resources not found")
		return
	
	_initialize_components()
	_connect_signals()

func _initialize_components() -> void:
	tutorial_manager = Node.new()
	tutorial_manager.name = "TutorialManager"
	add_child(tutorial_manager)
	
	tutorial_ui = Node.new()
	tutorial_ui.name = "TutorialUI"
	add_child(tutorial_ui)

func _connect_signals() -> void:
	if tutorial_manager and tutorial_ui:
		tutorial_manager.connect("step_changed", _on_step_changed)
		tutorial_manager.connect("tutorial_completed", _on_tutorial_completed)
		tutorial_ui.connect("step_completed", _on_step_completed)
		tutorial_ui.connect("track_completed", _on_track_completed)
	else:
		push_error("Tutorial components not properly initialized")

func start_tutorial(type: GlobalEnums.TutorialType) -> void:
	if not tutorial_manager:
		push_error("Tutorial manager not initialized")
		return
		
	tutorial_manager.start_tutorial(type)
	tutorial_ui.show()

func _on_step_changed(step: String) -> void:
	if tutorial_content and tutorial_ui:
		tutorial_ui.update_content(tutorial_content.get_step_content(step))
		tutorial_progress.save_progress()

func _on_tutorial_completed(type: String) -> void:
	if tutorial_progress:
		tutorial_progress.mark_track_complete(type)
	if tutorial_ui:
		tutorial_ui.hide()

func _on_step_completed(step_id: String) -> void:
	if tutorial_progress and tutorial_manager:
		tutorial_progress.complete_step(step_id)
		tutorial_manager.advance_tutorial()

func _on_track_completed(track_id: String) -> void:
	if tutorial_progress and tutorial_manager:
		tutorial_progress.complete_track(track_id)
		tutorial_manager.end_tutorial()
