# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends RefCounted


# Name data loaded from res://data/character_names.json
static var _names_data: Dictionary = {}
static var _names_loaded: bool = false

static func _ensure_names_loaded() -> void:
	if _names_loaded:
		return
	_names_loaded = true
	var file := FileAccess.open("res://data/character_names.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_names_data = json.data
	file.close()

static var FIRST_NAMES: Array: # @no-lint:variable-name
	get:
		_ensure_names_loaded()
		var a: Array = _names_data.get("first_names", [])
		if a.is_empty():
			return ["Alex", "Blake", "Casey", "Nova", "Orion"]
		return a

static var LAST_NAMES: Array: # @no-lint:variable-name
	get:
		_ensure_names_loaded()
		var a: Array = _names_data.get("last_names", [])
		if a.is_empty():
			return ["Adler", "Chen", "Drake", "Smith"]
		return a

static var TITLES: Array: # @no-lint:variable-name
	get:
		_ensure_names_loaded()
		var a: Array = _names_data.get("titles", [])
		if a.is_empty():
			return ["Captain", "Commander", "Pilot"]
		return a

static func generate_random_name() -> String:
	var first_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last_name = LAST_NAMES[randi() % LAST_NAMES.size()]
	
	# 20% chance to add a title
	if randf() < 0.2:
		var title = TITLES[randi() % TITLES.size()]
		return title + " " + first_name + " " + last_name
	
	return first_name + " " + last_name