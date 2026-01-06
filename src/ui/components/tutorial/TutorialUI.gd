class_name FPCM_TutorialUI
extends Control

const TutorialOverlay = preload("res://src/ui/components/tutorial/TutorialOverlay.gd")

signal tutorial_completed
signal tutorial_skipped

@onready var overlay: Object
@onready var tutorial_data := {}

var current_tutorial: String = ""
var tutorial_progress: Dictionary = {}
var tutorial_cache: Dictionary = {}  # Cache loaded tutorial data

func _ready() -> void:
	overlay = TutorialOverlay.new()
	add_child(overlay)
	_connect_signals()
	_load_tutorial_progress()

func _connect_signals() -> void:
	overlay.tutorial_completed.connect(_on_tutorial_completed)
	overlay.tutorial_skipped.connect(_on_tutorial_skipped)

func start_tutorial(tutorial_name: String) -> void:
	# Validate tutorial name
	if tutorial_name.is_empty():
		push_error("Tutorial name cannot be empty")
		return
	
	# Check if already completed (unless forced restart)
	if tutorial_progress.has(tutorial_name) and tutorial_progress[tutorial_name].get("completed", false):
		print("Tutorial %s already completed, skipping" % tutorial_name)
		return

	current_tutorial = tutorial_name
	var steps = _load_tutorial_steps_cached(tutorial_name)
	if steps.is_empty():
		push_error("Tutorial steps not found for: " + tutorial_name)
		return

	# Validate tutorial steps before starting
	if not _validate_tutorial_steps(steps):
		push_error("Tutorial steps validation failed for: " + tutorial_name)
		return
	
	print("Starting tutorial: %s with %d steps" % [tutorial_name, steps.size()])
	overlay.start_tutorial(steps)

func skip_tutorial(tutorial_name: String) -> void:
	if current_tutorial == tutorial_name:
		overlay.hide_overlay()
	tutorial_progress[tutorial_name] = {"completed": true, "skipped": true}
	_save_tutorial_progress()
	tutorial_skipped.emit() # warning: return value discarded (intentional)

func is_tutorial_completed(tutorial_name: String) -> bool:
	return tutorial_progress.has(tutorial_name) and tutorial_progress[tutorial_name].completed

func _load_tutorial_steps_cached(tutorial_name: String) -> Array[Dictionary]:
	"""Load tutorial steps with caching for better performance"""
	# Check cache first
	if tutorial_cache.has(tutorial_name):
		print("Tutorial %s loaded from cache" % tutorial_name)
		return tutorial_cache[tutorial_name]
	
	# Load tutorial steps from configuration
	if tutorial_data.has(tutorial_name):
		tutorial_cache[tutorial_name] = tutorial_data[tutorial_name]
		return tutorial_data[tutorial_name]

	# Try loading from file with enhanced error handling
	var tutorial_path: String = "res://data/tutorials/" + tutorial_name + ".json"
	if not FileAccess.file_exists(tutorial_path):
		print("Tutorial file not found: %s" % tutorial_path)
		return []

	var file: FileAccess = FileAccess.open(tutorial_path, FileAccess.READ)
	if not file:
		push_error("Failed to open tutorial file: %s" % tutorial_path)
		return []
		
	var content = file.get_as_text()
	file.close()
	
	if content.is_empty():
		push_error("Tutorial file is empty: %s" % tutorial_path)
		return []
	
	var json := JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		push_error("Failed to parse tutorial JSON: %s (Error: %s)" % [tutorial_path, json.get_error_message()])
		return []
	
	var steps = json.get_data()
	if steps is Array:
		tutorial_cache[tutorial_name] = steps
		print("Tutorial %s loaded and cached (%d steps)" % [tutorial_name, steps.size()])
		return steps
	else:
		push_error("Tutorial data is not an array: %s" % tutorial_path)
		return []

func _load_tutorial_steps(tutorial_name: String) -> Array[Dictionary]:
	"""Legacy method - redirects to cached version"""
	return _load_tutorial_steps_cached(tutorial_name)

func _load_tutorial_progress() -> void:
	var save_path: String = "user://tutorial_progress.json"
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
		
	var json := JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result != OK:
		return
	
	file.close()
	tutorial_progress = json.get_data()

func _save_tutorial_progress() -> void:
	var save_path: String = "user://tutorial_progress.json"
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return
		
	file.store_string(JSON.stringify(tutorial_progress))
	file.close()

func _on_tutorial_completed() -> void:
	if current_tutorial:
		tutorial_progress[current_tutorial] = {"completed": true, "skipped": false}
		_save_tutorial_progress()
		tutorial_completed.emit() # warning: return value discarded (intentional)
		current_tutorial = ""

func _on_tutorial_skipped() -> void:
	if current_tutorial:
		tutorial_progress[current_tutorial] = {"completed": true, "skipped": true}
		_save_tutorial_progress()
		tutorial_skipped.emit() # warning: return value discarded (intentional)
		current_tutorial = ""

## Enhanced Tutorial Management Methods

func _validate_tutorial_steps(steps: Array) -> bool:
	"""Validate tutorial steps structure before starting"""
	if steps.is_empty():
		return false
	
	for i in range(steps.size()):
		var step = steps[i]
		if not step is Dictionary:
			push_error("Tutorial step %d is not a dictionary" % i)
			return false
		
		# Check required fields
		if not step.has("text") or step.text.is_empty():
			push_error("Tutorial step %d missing or empty 'text' field" % i)
			return false
		
		# Validate target path if present
		if step.has("target_path") and not step.target_path.is_empty():
			# Could add node path validation here in the future
			pass
	
	return true

func get_tutorial_progress_summary() -> Dictionary:
	"""Get comprehensive tutorial progress information"""
	var completed_count = 0
	var skipped_count = 0
	var total_tutorials = tutorial_progress.size()
	
	for tutorial_name in tutorial_progress:
		var progress = tutorial_progress[tutorial_name]
		if progress.get("completed", false):
			completed_count += 1
			if progress.get("skipped", false):
				skipped_count += 1
	
	return {
		"total_tutorials": total_tutorials,
		"completed": completed_count,
		"skipped": skipped_count,
		"completion_rate": (float(completed_count) / float(total_tutorials)) if total_tutorials > 0 else 0.0
	}

func reset_tutorial_progress() -> void:
	"""Reset all tutorial progress (useful for testing)"""
	tutorial_progress.clear()
	_save_tutorial_progress()
	print("All tutorial progress reset")

func force_restart_tutorial(tutorial_name: String) -> void:
	"""Force restart a tutorial even if already completed"""
	if tutorial_progress.has(tutorial_name):
		tutorial_progress.erase(tutorial_name)
		_save_tutorial_progress()
	start_tutorial(tutorial_name)

func get_available_tutorials() -> Array[String]:
	"""Get list of available tutorial files"""
	var tutorials: Array[String] = []
	
	# Check data/tutorials directory
	var dir = DirAccess.open("res://data/tutorials/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var tutorial_name = file_name.get_basename()
				tutorials.append(tutorial_name)
			file_name = dir.get_next()
	
	return tutorials

func clear_tutorial_cache() -> void:
	"""Clear the tutorial cache (useful for development)"""
	tutorial_cache.clear()
	print("Tutorial cache cleared")
