# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const TutorialOverlay = preload("res://src/ui/components/tutorial/TutorialOverlay.gd")

signal tutorial_completed
signal tutorial_skipped

@onready var overlay: Object
@onready var tutorial_data := {}

var current_tutorial: String
var tutorial_progress: Dictionary

func _ready() -> void:
	overlay = TutorialOverlay.new()
	add_child(overlay)
	_connect_signals()
	_load_tutorial_progress()

func _connect_signals() -> void:
	overlay.tutorial_completed.connect(_on_tutorial_completed)
	overlay.tutorial_skipped.connect(_on_tutorial_skipped)

## Start a tutorial. `force` replays one that is already marked complete —
## required by the dashboard "?" button, whose entire job is replaying it.
func start_tutorial(tutorial_name: String, force: bool = false) -> void:
	if not force and is_tutorial_completed(tutorial_name):
		# Auto-run path: already seen, nothing to do. Free ourselves so the caller
		# does not have to — see the leak note on _finish().
		_finish()
		return

	current_tutorial = tutorial_name
	var steps = _load_tutorial_steps(tutorial_name)
	if steps.is_empty():
		push_error("Tutorial steps not found for: " + tutorial_name)
		_finish()
		return

	overlay.start_tutorial(steps)

func skip_tutorial(tutorial_name: String) -> void:
	if current_tutorial == tutorial_name:
		overlay.hide_overlay()
	tutorial_progress[tutorial_name] = {"completed": true, "skipped": true}
	_save_tutorial_progress()
	tutorial_skipped.emit()

func is_tutorial_completed(tutorial_name: String) -> bool:
	return tutorial_progress.has(tutorial_name) and tutorial_progress[tutorial_name].completed

func _load_tutorial_steps(tutorial_name: String) -> Array:
	# Load tutorial steps from configuration
	if tutorial_data.has(tutorial_name):
		return tutorial_data[tutorial_name]
    
	# Try loading from file
	var file_path = "res://data/tutorials/" + tutorial_name + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return []
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse tutorial file: " + file_path)
		return []
    
	var steps: Array = json.get_data()
	tutorial_data[tutorial_name] = steps
	return steps

func _load_tutorial_progress() -> void:
	var save_path = "user://tutorial_progress.json"
	if not FileAccess.file_exists(save_path):
		tutorial_progress = {}
		return
    
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse tutorial progress file")
		tutorial_progress = {}
		return
    
	tutorial_progress = json.get_data()

func _save_tutorial_progress() -> void:
	var save_path = "user://tutorial_progress.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("TutorialUI: could not write %s" % save_path)
		return
	file.store_string(JSON.stringify(tutorial_progress))

func _finish() -> void:
	## Every caller does `TutorialUIScript.new()` + `add_child()` and none of them
	## free it afterwards, so each auto-run and each "?" press left another node
	## (carrying a CanvasLayer at layer 95) parented to the screen. Owning our own
	## teardown here fixes all call sites at once.
	if is_instance_valid(overlay):
		overlay.hide_overlay()
	queue_free()

func _on_tutorial_completed() -> void:
	if current_tutorial:
		tutorial_progress[current_tutorial] = {"completed": true, "skipped": false}
		_save_tutorial_progress()
		tutorial_completed.emit()
		current_tutorial = ""
	_finish()

func _on_tutorial_skipped() -> void:
	if current_tutorial:
		tutorial_progress[current_tutorial] = {"completed": true, "skipped": true}
		_save_tutorial_progress()
		tutorial_skipped.emit()
		current_tutorial = ""
	_finish()
