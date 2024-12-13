# GameTutorialManager.gd - Main tutorial management class
class_name GameTutorialManager
extends Node2D

signal tutorial_step_changed(step: String)
signal tutorial_completed(type: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_track_completed(track_id: String)

enum TutorialTrack {
	STORY_TRACK,
	COMPENDIUM,
	QUICK_START,
	ADVANCED
}

# Tutorial data structure
var current_tutorial: TutorialTrack
var current_step: Dictionary = {}
var is_tutorial_active: bool = false
var tutorial_data: Dictionary = {}
var disabled_features: Array[String] = []

# Add new variables for tutorial state
var can_skip: bool = true
var tutorial_paused: bool = false
var tutorial_history: Array[Dictionary] = []

# Change from @onready var to regular vars
var tutorial_overlay: TutorialOverlay
var tutorial_progress: Control
var tutorial_content: Control

func _ready() -> void:
	# Load and instantiate the TutorialOverlay scene
	var overlay_scene = load("res://Resources/UI/Scenes/TutorialOverlay.tscn")
	if overlay_scene:
		tutorial_overlay = overlay_scene.instantiate()
	else:
		push_error("Failed to load TutorialOverlay scene")
		return
	
	add_child(tutorial_overlay)
	
	tutorial_progress = Control.new()
	tutorial_progress.name = "TutorialProgress"
	add_child(tutorial_progress)
	
	tutorial_content = Control.new()
	tutorial_content.name = "TutorialContent"
	add_child(tutorial_content)
	
	_connect_tutorial_signals()
	hide()  # Start hidden

func _connect_tutorial_signals() -> void:
	if tutorial_overlay:
		# Disconnect existing connections if any
		if tutorial_overlay.is_connected("overlay_clicked", _on_overlay_clicked):
			tutorial_overlay.overlay_clicked.disconnect(_on_overlay_clicked)
		if tutorial_overlay.is_connected("tutorial_step_completed", _on_step_completed):
			tutorial_overlay.tutorial_step_completed.disconnect(_on_step_completed)
		if tutorial_overlay.is_connected("tutorial_track_completed", _on_track_completed):
			tutorial_overlay.tutorial_track_completed.disconnect(_on_track_completed)
			
		# Connect new signals
		tutorial_overlay.overlay_clicked.connect(_on_overlay_clicked)
		tutorial_overlay.tutorial_step_completed.connect(_on_step_completed)
		tutorial_overlay.tutorial_track_completed.connect(_on_track_completed)
	else:
		push_error("Tutorial components not properly initialized")

func _load_tutorial_data() -> void:
	var quick_start = FileAccess.open("res://data/Tutorials/quick_start_tutorial.json", FileAccess.READ)
	var advanced = FileAccess.open("res://data/Tutorials/advanced_tutorial.json", FileAccess.READ)
	
	if quick_start and advanced:
		var json = JSON.new()
		var quick_start_parse = json.parse(quick_start.get_as_text())
		var advanced_parse = json.parse(advanced.get_as_text())
		
		if quick_start_parse == OK and advanced_parse == OK:
			tutorial_data = {
				TutorialTrack.QUICK_START: json.get_data(),
				TutorialTrack.ADVANCED: json.get_data()
			}
	else:
		push_error("Failed to load tutorial data files")

func start_tutorial(type: TutorialTrack) -> void:
	current_tutorial = type
	is_tutorial_active = true
	current_step = {}
	tutorial_history.clear()
	
	# Show tutorial UI
	show()
	tutorial_overlay.show()
	tutorial_progress.show()
	tutorial_content.show()
	
	# Load track-specific data
	var track_data = tutorial_data.get(type, {})
	if track_data.has("disabled_features"):
		disabled_features = track_data.disabled_features
	
	# Start first step
	advance_tutorial()

func end_tutorial() -> void:
	is_tutorial_active = false
	tutorial_completed.emit(TutorialTrack.keys()[current_tutorial])
	
	# Hide tutorial UI
	tutorial_overlay.hide()
	tutorial_progress.hide()
	tutorial_content.hide()
	hide()

func _on_overlay_clicked(position: Vector2) -> void:
	if current_step is Dictionary and current_step.has("click_target"):
		var target_rect = get_node(current_step.click_target).get_global_rect()
		if target_rect.has_point(position):
			advance_tutorial()

func _on_step_completed(step_id: String) -> void:
	if step_id == current_step.id:
		advance_tutorial()

func _on_track_completed(track_id: String) -> void:
	if track_id == TutorialTrack.keys()[current_tutorial]:
		complete_tutorial()

func _show_current_step() -> void:
	var step_data = _get_step_data(current_step.id)
	if step_data:
		tutorial_content.show_content(step_data)
		tutorial_progress.update_progress(step_data)
		
		if step_data.has("highlight_target"):
			var target = get_node(step_data.highlight_target)
			if target:
				tutorial_overlay.highlight_control(target, step_data)

func is_feature_disabled(feature: String) -> bool:
	return feature in disabled_features

func show_warning_dialog(message: String, callback: Callable) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.confirmed.connect(callback)
	dialog.popup_centered()

func advance_tutorial() -> void:
	if not is_tutorial_active:
		return
		
	var track_data = tutorial_data.get(current_tutorial, {})
	var steps = track_data.get("steps", [])
	
	if current_step.is_empty():
		current_step = steps[0].id if steps.size() > 0 else {}
	else:
		var current_index = steps.find(func(step): return step.id == current_step.id)
		if current_index < steps.size() - 1:
			current_step = steps[current_index + 1].id
		else:
			complete_tutorial()
			return
	
	tutorial_step_changed.emit(current_step.id)

func complete_tutorial() -> void:
	is_tutorial_active = false
	tutorial_completed.emit(TutorialTrack.keys()[current_tutorial])

func _get_step_data(step_id: String) -> Dictionary:
	var track_data = tutorial_data.get(current_tutorial, {})
	var steps = track_data.get("steps", [])
	for step in steps:
		if step.id == step_id:
			return step
	return {}
