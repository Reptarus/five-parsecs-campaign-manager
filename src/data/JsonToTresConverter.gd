class_name JsonToTresConverter
extends RefCounted

## JSON to TRES Converter
## Converts JSON data files to Godot's native .tres resources
## Optimizes performance and leverages Godot's strengths

const CharacterBackgroundResource = preload("res://src/data/resources/CharacterBackgroundResource.gd")
const CharacterMotivationResource = preload("res://src/data/resources/CharacterMotivationResource.gd")
const CharacterClassResource = preload("res://src/data/resources/CharacterClassResource.gd")

signal conversion_progress(step: String, current: int, total: int)
signal conversion_complete(success_count: int, error_count: int)

func convert_all_json_to_tres() -> void:
	"""Convert all JSON data files to TRES resources"""
	print("JsonToTresConverter: Starting conversion of all JSON files...")
	
	var success_count = 0
	var error_count = 0
	
	# Convert character backgrounds
	var backgrounds_result = convert_character_backgrounds()
	success_count += backgrounds_result.success
	error_count += backgrounds_result.errors
	
	# Convert character motivations
	var motivations_result = convert_character_motivations()
	success_count += motivations_result.success
	error_count += motivations_result.errors
	
	# Convert character classes
	var classes_result = convert_character_classes()
	success_count += classes_result.success
	error_count += classes_result.errors
	
	conversion_complete.emit(success_count, error_count)
	print("JsonToTresConverter: Conversion complete - %d success, %d errors" % [success_count, error_count])

func convert_character_backgrounds() -> Dictionary:
	"""Convert character backgrounds JSON to TRES resources"""
	print("JsonToTresConverter: Converting character backgrounds...")
	
	var json_file = "res://data/character_backgrounds.json"
	var output_dir = "res://src/data/resources/backgrounds/"
	
	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(output_dir)
	
	var json_data = _load_json_file(json_file)
	if not json_data:
		return {"success": 0, "errors": 1}
	
	var backgrounds = json_data.get("backgrounds", [])
	var success_count = 0
	var error_count = 0
	
	for i in range(backgrounds.size()):
		var background_data = backgrounds[i]
		var result = _convert_background_to_tres(background_data, output_dir)
		if result.success:
			success_count += 1
		else:
			error_count += 1
		
		conversion_progress.emit("backgrounds", i + 1, backgrounds.size())
	
	print("JsonToTresConverter: Backgrounds conversion - %d success, %d errors" % [success_count, error_count])
	return {"success": success_count, "errors": error_count}

func convert_character_motivations() -> Dictionary:
	"""Convert character motivations JSON to TRES resources"""
	print("JsonToTresConverter: Converting character motivations...")
	
	var json_file = "res://data/character_creation_data.json"
	var output_dir = "res://src/data/resources/motivations/"
	
	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(output_dir)
	
	var json_data = _load_json_file(json_file)
	if not json_data:
		return {"success": 0, "errors": 1}
	
	var motivations = json_data.get("motivations", {})
	var success_count = 0
	var error_count = 0
	var motivation_list = motivations.keys()
	
	for i in range(motivation_list.size()):
		var motivation_id = motivation_list[i]
		var motivation_data = motivations[motivation_id]
		motivation_data["id"] = motivation_id
		
		var result = _convert_motivation_to_tres(motivation_data, output_dir)
		if result.success:
			success_count += 1
		else:
			error_count += 1
		
		conversion_progress.emit("motivations", i + 1, motivation_list.size())
	
	print("JsonToTresConverter: Motivations conversion - %d success, %d errors" % [success_count, error_count])
	return {"success": success_count, "errors": error_count}

func convert_character_classes() -> Dictionary:
	"""Convert character classes JSON to TRES resources"""
	print("JsonToTresConverter: Converting character classes...")
	
	var json_file = "res://data/character_creation_data.json"
	var output_dir = "res://src/data/resources/classes/"
	
	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(output_dir)
	
	var json_data = _load_json_file(json_file)
	if not json_data:
		return {"success": 0, "errors": 1}
	
	var classes = json_data.get("classes", {})
	var success_count = 0
	var error_count = 0
	var class_list = classes.keys()
	
	for i in range(class_list.size()):
		var class_id = class_list[i]
		var class_data = classes[class_id]
		class_data["id"] = class_id
		
		var result = _convert_class_to_tres(class_data, output_dir)
		if result.success:
			success_count += 1
		else:
			error_count += 1
		
		conversion_progress.emit("classes", i + 1, class_list.size())
	
	print("JsonToTresConverter: Classes conversion - %d success, %d errors" % [success_count, error_count])
	return {"success": success_count, "errors": error_count}

func _convert_background_to_tres(background_data: Dictionary, output_dir: String) -> Dictionary:
	"""Convert a single background to TRES resource"""
	var background = CharacterBackgroundResource.new()
	background.from_dict(background_data)
	
	var filename = background.id + ".tres"
	var filepath = output_dir + filename
	
	var result = ResourceSaver.save(background, filepath)
	if result == OK:
		print("JsonToTresConverter: Saved background: %s" % filepath)
		return {"success": true, "error": ""}
	else:
		var error_msg = "Failed to save background: %s (error: %d)" % [filepath, result]
		push_error("JsonToTresConverter: " + error_msg)
		return {"success": false, "error": error_msg}

func _convert_motivation_to_tres(motivation_data: Dictionary, output_dir: String) -> Dictionary:
	"""Convert a single motivation to TRES resource"""
	var motivation = CharacterMotivationResource.new()
	motivation.from_dict(motivation_data)
	
	var filename = motivation.id + ".tres"
	var filepath = output_dir + filename
	
	var result = ResourceSaver.save(motivation, filepath)
	if result == OK:
		print("JsonToTresConverter: Saved motivation: %s" % filepath)
		return {"success": true, "error": ""}
	else:
		var error_msg = "Failed to save motivation: %s (error: %d)" % [filepath, result]
		push_error("JsonToTresConverter: " + error_msg)
		return {"success": false, "error": error_msg}

func _convert_class_to_tres(class_data: Dictionary, output_dir: String) -> Dictionary:
	"""Convert a single class to TRES resource"""
	var character_class = CharacterClassResource.new()
	character_class.from_dict(class_data)
	
	var filename = character_class.id + ".tres"
	var filepath = output_dir + filename
	
	var result = ResourceSaver.save(character_class, filepath)
	if result == OK:
		print("JsonToTresConverter: Saved class: %s" % filepath)
		return {"success": true, "error": ""}
	else:
		var error_msg = "Failed to save class: %s (error: %d)" % [filepath, result]
		push_error("JsonToTresConverter: " + error_msg)
		return {"success": false, "error": error_msg}

func _load_json_file(filepath: String) -> Dictionary:
	"""Load and parse a JSON file"""
	if not FileAccess.file_exists(filepath):
		push_error("JsonToTresConverter: File not found: %s" % filepath)
		return {}
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		push_error("JsonToTresConverter: Failed to open file: %s" % filepath)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JsonToTresConverter: Failed to parse JSON: %s" % filepath)
		return {}
	
	return json.data

func load_background_resource(background_id: String) -> CharacterBackgroundResource:
	"""Load a background resource by ID"""
	var filepath = "res://src/data/resources/backgrounds/" + background_id + ".tres"
	return load(filepath) as CharacterBackgroundResource

func load_motivation_resource(motivation_id: String) -> CharacterMotivationResource:
	"""Load a motivation resource by ID"""
	var filepath = "res://src/data/resources/motivations/" + motivation_id + ".tres"
	return load(filepath) as CharacterMotivationResource

func load_class_resource(class_id: String) -> CharacterClassResource:
	"""Load a class resource by ID"""
	var filepath = "res://src/data/resources/classes/" + class_id + ".tres"
	return load(filepath) as CharacterClassResource

func get_all_background_resources() -> Array[CharacterBackgroundResource]:
	"""Get all background resources"""
	var backgrounds: Array[CharacterBackgroundResource] = []
	var dir = DirAccess.open("res://src/data/resources/backgrounds/")
	if not dir:
		return backgrounds
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	
	while filename != "":
		if filename.ends_with(".tres"):
			var filepath = "res://src/data/resources/backgrounds/" + filename
			var resource = load(filepath) as CharacterBackgroundResource
			if resource:
				backgrounds.append(resource)
		filename = dir.get_next()
	
	return backgrounds

func get_all_motivation_resources() -> Array[CharacterMotivationResource]:
	"""Get all motivation resources"""
	var motivations: Array[CharacterMotivationResource] = []
	var dir = DirAccess.open("res://src/data/resources/motivations/")
	if not dir:
		return motivations
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	
	while filename != "":
		if filename.ends_with(".tres"):
			var filepath = "res://src/data/resources/motivations/" + filename
			var resource = load(filepath) as CharacterMotivationResource
			if resource:
				motivations.append(resource)
		filename = dir.get_next()
	
	return motivations

func get_all_class_resources() -> Array[CharacterClassResource]:
	"""Get all class resources"""
	var classes: Array[CharacterClassResource] = []
	var dir = DirAccess.open("res://src/data/resources/classes/")
	if not dir:
		return classes
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	
	while filename != "":
		if filename.ends_with(".tres"):
			var filepath = "res://src/data/resources/classes/" + filename
			var resource = load(filepath) as CharacterClassResource
			if resource:
				classes.append(resource)
		filename = dir.get_next()
	
	return classes