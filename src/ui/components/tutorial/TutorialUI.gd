class_name FPCM_TutorialUI
extends Control

signal tutorial_completed
signal tutorial_skipped

@onready var overlay := TutorialOverlay.new()
@onready var tutorial_data := {}

var current_tutorial: String
var tutorial_progress: Dictionary

func _ready() -> void:
    add_child(overlay)
    _connect_signals()
    _load_tutorial_progress()

func _connect_signals() -> void:
    overlay.tutorial_completed.connect(_on_tutorial_completed)
    overlay.tutorial_skipped.connect(_on_tutorial_skipped)

func start_tutorial(tutorial_name: String) -> void:
    if tutorial_progress.has(tutorial_name) and tutorial_progress[tutorial_name].completed:
        return
    
    current_tutorial = tutorial_name
    var steps = _load_tutorial_steps(tutorial_name)
    if steps.is_empty():
        push_error("Tutorial steps not found for: " + tutorial_name)
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

func _load_tutorial_steps(tutorial_name: String) -> Array[Dictionary]:
    # Load tutorial steps from configuration
    if tutorial_data.has(tutorial_name):
        return tutorial_data[tutorial_name]
    
    # Try loading from file
    var file_path = "res://data/tutorials/" + tutorial_name + ".json"
    if not FileAccess.file_exists(file_path):
        return []
    
    var file = FileAccess.open(file_path, FileAccess.READ)
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
    file.store_string(JSON.stringify(tutorial_progress))

func _on_tutorial_completed() -> void:
    if current_tutorial:
        tutorial_progress[current_tutorial] = {"completed": true, "skipped": false}
        _save_tutorial_progress()
        tutorial_completed.emit()
        current_tutorial = ""

func _on_tutorial_skipped() -> void:
    if current_tutorial:
        tutorial_progress[current_tutorial] = {"completed": true, "skipped": true}
        _save_tutorial_progress()
        tutorial_skipped.emit()
        current_tutorial = ""