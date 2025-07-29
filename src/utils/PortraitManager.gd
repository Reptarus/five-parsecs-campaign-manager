extends RefCounted
class_name PortraitManager

## Portrait Management Utility for Five Parsecs Campaign Manager
## Handles importing, exporting, validation, and processing of character portraits
## Enhanced with JSON metadata management and default portrait configuration

# Enhanced with JSON data management
const DataManager = preload("res://src/core/data/DataManager.gd")
var data_manager: DataManager = DataManager.new()

const PORTRAIT_DIR = "user://portraits/"
const MAX_FILE_SIZE = 10 * 1024 * 1024 # 10MB
const MAX_IMAGE_SIZE = 512
const MIN_IMAGE_SIZE = 64
const VALID_EXTENSIONS = ["png", "jpg", "jpeg"]

# JSON data storage
var portrait_metadata: Dictionary = {}
var default_portrait_config: Dictionary = {}
var portrait_categories: Dictionary = {}

signal portrait_loaded(portrait_path: String)
signal portrait_exported(export_path: String)
signal portrait_error(error_message: String)
signal portrait_metadata_updated(character_id: String, metadata: Dictionary)

func _init() -> void:
	"""Initialize with JSON configuration loading"""
	_load_portrait_configuration()
	_load_portrait_metadata()

## JSON Configuration Loading

func _load_portrait_configuration() -> void:
	"""Load portrait configuration from JSON files"""
	# Load default portrait configuration
	default_portrait_config = data_manager.load_json_file("res://data/portraits/default_portraits.json")
	if default_portrait_config.is_empty():
		print("PortraitManager: default_portraits.json not found, creating fallback config")
		_create_default_portrait_config()
	else:
		print("PortraitManager: Loaded %d portrait categories from JSON" % default_portrait_config.get("categories", []).size())
	
	# Load portrait categories and settings
	portrait_categories = data_manager.load_json_file("res://data/portraits/portrait_categories.json")
	if portrait_categories.is_empty():
		print("PortraitManager: portrait_categories.json not found, creating fallback categories")
		_create_portrait_categories_fallback()
	else:
		print("PortraitManager: Loaded portrait categories configuration")

func _create_default_portrait_config() -> void:
	"""Create fallback default portrait configuration"""
	default_portrait_config = {
		"categories": [
			{
				"class": "Soldier",
				"default_path": "res://assets/portraits/default_soldier.png",
				"placeholder_color": "#CC5555",
				"style": "military",
				"tags": ["combat", "armor", "weapons"]
			},
			{
				"class": "Scout",
				"default_path": "res://assets/portraits/default_scout.png",
				"placeholder_color": "#55CC55",
				"style": "tactical",
				"tags": ["stealth", "reconnaissance", "agile"]
			},
			{
				"class": "Medic",
				"default_path": "res://assets/portraits/default_medic.png",
				"placeholder_color": "#5555CC",
				"style": "medical",
				"tags": ["healing", "support", "caring"]
			},
			{
				"class": "Engineer",
				"default_path": "res://assets/portraits/default_engineer.png",
				"placeholder_color": "#CCCC55",
				"style": "technical",
				"tags": ["repair", "technology", "tools"]
			},
			{
				"class": "Pilot",
				"default_path": "res://assets/portraits/default_pilot.png",
				"placeholder_color": "#CC55CC",
				"style": "aviation",
				"tags": ["flight", "navigation", "vehicles"]
			}
		],
		"settings": {
			"auto_resize": true,
			"quality_settings": "high",
			"compression_level": 0.8,
			"backup_originals": true
		}
	}

func _create_portrait_categories_fallback() -> void:
	"""Create fallback portrait categories configuration"""
	portrait_categories = {
		"character_types": [
			{
				"type": "crew_member",
				"description": "Main crew member portraits",
				"size_requirements": {
					"min_width": 64,
					"min_height": 64,
					"max_width": 512,
					"max_height": 512,
					"aspect_ratio": "1:1"
				},
				"style_guidelines": [
					"Clear face visibility",
					"Appropriate clothing for class",
					"Professional military/spacer appearance"
				]
			},
			{
				"type": "npc",
				"description": "Non-player character portraits",
				"size_requirements": {
					"min_width": 48,
					"min_height": 48,
					"max_width": 256,
					"max_height": 256,
					"aspect_ratio": "flexible"
				},
				"style_guidelines": [
					"Distinctive appearance",
					"Role-appropriate attire",
					"Clear expression"
				]
			},
			{
				"type": "enemy",
				"description": "Enemy and rival portraits",
				"size_requirements": {
					"min_width": 32,
					"min_height": 32,
					"max_width": 256,
					"max_height": 256,
					"aspect_ratio": "flexible"
				},
				"style_guidelines": [
					"Threatening or intimidating",
					"Faction-appropriate gear",
					"Combat-ready appearance"
				]
			}
		],
		"metadata_fields": [
			"character_id",
			"character_name",
			"character_class",
			"portrait_category",
			"creation_date",
			"last_modified",
			"source_file",
			"tags",
			"notes"
		]
	}

func _load_portrait_metadata() -> void:
	"""Load existing portrait metadata from user data"""
	var metadata_path = PORTRAIT_DIR + "portrait_metadata.json"
	if FileAccess.file_exists(metadata_path):
		var file = FileAccess.open(metadata_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				portrait_metadata = json.data
				print("PortraitManager: Loaded metadata for %d portraits" % portrait_metadata.size())
			else:
				print("PortraitManager: Failed to parse portrait metadata JSON")
	else:
		print("PortraitManager: No existing portrait metadata found, starting fresh")

func _save_portrait_metadata() -> void:
	"""Save portrait metadata to user data"""
	_ensure_portrait_directory()
	var metadata_path = PORTRAIT_DIR + "portrait_metadata.json"
	var file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(portrait_metadata, "\t")
		file.store_string(json_string)
		file.close()
		print("PortraitManager: Saved metadata for %d portraits" % portrait_metadata.size())

## Enhanced Portrait Management

func register_portrait_metadata(character_id: String, portrait_path: String, metadata: Dictionary = {}) -> void:
	"""Register metadata for a portrait"""
	var portrait_metadata_entry = {
		"character_id": character_id,
		"portrait_path": portrait_path,
		"creation_date": Time.get_datetime_string_from_system(),
		"last_modified": Time.get_datetime_string_from_system(),
		"file_size": _get_file_size(portrait_path),
		"tags": metadata.get("tags", []),
		"notes": metadata.get("notes", ""),
		"character_class": metadata.get("character_class", "Unknown"),
		"source_type": metadata.get("source_type", "imported")
	}
	
	portrait_metadata[character_id] = portrait_metadata_entry
	_save_portrait_metadata()
	portrait_metadata_updated.emit(character_id, portrait_metadata_entry)

func get_portrait_metadata(character_id: String) -> Dictionary:
	"""Get metadata for a specific portrait"""
	return portrait_metadata.get(character_id, {})

func update_portrait_metadata(character_id: String, updates: Dictionary) -> void:
	"""Update metadata for an existing portrait"""
	if character_id in portrait_metadata:
		var metadata = portrait_metadata[character_id]
		for key in updates:
			metadata[key] = updates[key]
		metadata["last_modified"] = Time.get_datetime_string_from_system()
		_save_portrait_metadata()
		portrait_metadata_updated.emit(character_id, metadata)

func _get_file_size(file_path: String) -> int:
	"""Get file size for metadata"""
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var size = file.get_length()
			file.close()
			return size
	return 0

## Portrait Import Functions

func import_portrait(file_path: String) -> Texture2D:
	"""Import and process a portrait image from file path"""
	if not _validate_file(file_path):
		portrait_error.emit("Invalid portrait file. Please select a PNG, JPG, or JPEG image under 10MB.")
		return null
	
	var image = Image.new()
	var err = image.load(file_path)
	
	if err != OK:
		portrait_error.emit("Failed to load image file.")
		return null
	
	# Process the image
	var processed_image = _process_image(image)
	if not processed_image:
		portrait_error.emit("Failed to process image.")
		return null
	
	# Convert to texture
	var texture = ImageTexture.create_from_image(processed_image)
	portrait_loaded.emit(file_path)
	return texture

func _validate_file(file_path: String) -> bool:
	"""Validate that the file is a valid portrait image"""
	if not FileAccess.file_exists(file_path):
		return false
	
	# Check file extension
	var file_extension = file_path.get_extension().to_lower()
	if not VALID_EXTENSIONS.has(file_extension):
		return false
	
	# Check file size
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var file_size = file.get_length()
	file.close()
	
	if file_size > MAX_FILE_SIZE:
		return false
	
	return true

func _process_image(image: Image) -> Image:
	"""Process image with resizing and validation"""
	# Validate dimensions
	if image.get_width() < MIN_IMAGE_SIZE or image.get_height() < MIN_IMAGE_SIZE:
		portrait_error.emit("Image too small. Minimum size is %dx%d pixels." % [MIN_IMAGE_SIZE, MIN_IMAGE_SIZE])
		return null
	
	# Resize if too large
	if image.get_width() > MAX_IMAGE_SIZE or image.get_height() > MAX_IMAGE_SIZE:
		image.resize(MAX_IMAGE_SIZE, MAX_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
		print("PortraitManager: Resized image to %dx%d" % [image.get_width(), image.get_height()])
	
	return image

## Portrait Export Functions

func export_portrait(texture: Texture2D, character_name: String, base_path: String = "") -> String:
	"""Export portrait texture to user directory"""
	if not texture:
		portrait_error.emit("No portrait texture to export.")
		return ""
	
	# Ensure portraits directory exists
	_ensure_portrait_directory()
	
	# Generate export path
	var export_path = _generate_export_path(character_name, base_path)
	
	# Save the image
	var image = texture.get_image()
	var err = image.save_png(export_path)
	
	if err == OK:
		portrait_exported.emit(export_path)
		print("PortraitManager: Portrait exported to: ", export_path)
		return export_path
	else:
		portrait_error.emit("Failed to export portrait.")
		return ""

func _ensure_portrait_directory() -> void:
	"""Ensure the portrait directory exists"""
	if not DirAccess.dir_exists_absolute(PORTRAIT_DIR):
		DirAccess.make_dir_recursive_absolute(PORTRAIT_DIR)

func _generate_export_path(character_name: String, base_path: String = "") -> String:
	"""Generate a safe export path for the portrait"""
	var safe_name = character_name.to_lower().replace(" ", "_").replace("/", "_").replace("\\", "_")
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename = "%s_portrait_%s.png" % [safe_name, timestamp]
	
	if base_path.is_empty():
		return PORTRAIT_DIR + filename
	else:
		return base_path + filename

## Portrait Loading Functions

func load_portrait_from_path(portrait_path: String) -> Texture2D:
	"""Load a portrait texture from a saved path"""
	if portrait_path.is_empty():
		return null
	
	if not FileAccess.file_exists(portrait_path):
		portrait_error.emit("Portrait file not found: " + portrait_path)
		return null
	
	var image = Image.new()
	var err = image.load(portrait_path)
	
	if err != OK:
		portrait_error.emit("Failed to load portrait: " + portrait_path)
		return null
	
	return ImageTexture.create_from_image(image)

## Utility Functions

func get_default_portrait(character_class: int) -> Texture2D:
	"""Get a default portrait based on character class using JSON configuration"""
	var categories = default_portrait_config.get("categories", [])
	var character_class_name = ""
	
	# Get class name safely
	if GlobalEnums and GlobalEnums.CharacterClass and character_class < GlobalEnums.CharacterClass.size():
		character_class_name = GlobalEnums.CharacterClass.keys()[character_class]
	
	# Find matching category in JSON config
	for category in categories:
		if category.get("class", "").to_lower() == character_class_name.to_lower():
			var default_path = category.get("default_path", "")
			if not default_path.is_empty() and ResourceLoader.exists(default_path):
				return load(default_path)
			else:
				# Use JSON-configured placeholder color
				var color_string = category.get("placeholder_color", "#808080")
				return _create_placeholder_portrait_with_color(color_string, category)
	
	# Fallback to original method if JSON config not available
	var default_path = "res://assets/portraits/default_%s.png" % character_class_name.to_lower()
	if ResourceLoader.exists(default_path):
		return load(default_path)
	else:
		return _create_placeholder_portrait(character_class)

func _create_placeholder_portrait_with_color(color_string: String, category: Dictionary) -> Texture2D:
	"""Create a placeholder portrait using JSON-configured color and styling"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Parse color from string (e.g., "#CC5555")
	var color = Color(color_string) if color_string.begins_with("#") else Color.from_string(color_string, Color.GRAY)
	
	# Apply base color
	image.fill(color)
	
	# Add simple styling based on category if available
	var style = category.get("style", "")
	if style == "military":
		_add_military_styling(image, color)
	elif style == "technical":
		_add_technical_styling(image, color)
	elif style == "medical":
		_add_medical_styling(image, color)
	
	return ImageTexture.create_from_image(image)

func _add_military_styling(image: Image, base_color: Color) -> void:
	"""Add military-style visual elements"""
	# Add darker border for military look
	var border_color = base_color.darkened(0.4)
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			if x < 4 or x >= image.get_width() - 4 or y < 4 or y >= image.get_height() - 4:
				image.set_pixel(x, y, border_color)

func _add_technical_styling(image: Image, base_color: Color) -> void:
	"""Add technical/engineering style visual elements"""
	# Add grid pattern for technical look
	var grid_color = base_color.lightened(0.3)
	for x in range(0, image.get_width(), 16):
		for y in range(image.get_height()):
			image.set_pixel(x, y, grid_color)
	for y in range(0, image.get_height(), 16):
		for x in range(image.get_width()):
			image.set_pixel(x, y, grid_color)

func _add_medical_styling(image: Image, base_color: Color) -> void:
	"""Add medical style visual elements"""
	# Add cross pattern for medical look
	var cross_color = base_color.lightened(0.5)
	var center_x = image.get_width() / 2
	var center_y = image.get_height() / 2
	
	# Vertical line of cross
	for y in range(center_y - 20, center_y + 20):
		if y >= 0 and y < image.get_height():
			for x in range(center_x - 3, center_x + 3):
				if x >= 0 and x < image.get_width():
					image.set_pixel(x, y, cross_color)
	
	# Horizontal line of cross
	for x in range(center_x - 20, center_x + 20):
		if x >= 0 and x < image.get_width():
			for y in range(center_y - 3, center_y + 3):
				if y >= 0 and y < image.get_height():
					image.set_pixel(x, y, cross_color)

func _create_placeholder_portrait(character_class: int) -> Texture2D:
	"""Create a colored placeholder portrait (fallback method)"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Set color based on character class
	var color = Color.GRAY
	if GlobalEnums and GlobalEnums.CharacterClass:
		match character_class:
			GlobalEnums.CharacterClass.SOLDIER:
				color = Color(0.8, 0.3, 0.3, 1.0) # Red-ish
			GlobalEnums.CharacterClass.SCOUT:
				color = Color(0.3, 0.8, 0.3, 1.0) # Green-ish
			GlobalEnums.CharacterClass.MEDIC:
				color = Color(0.3, 0.3, 0.8, 1.0) # Blue-ish
			GlobalEnums.CharacterClass.ENGINEER:
				color = Color(0.8, 0.8, 0.3, 1.0) # Yellow-ish
			GlobalEnums.CharacterClass.PILOT:
				color = Color(0.8, 0.3, 0.8, 1.0) # Purple-ish
	
	image.fill(color)
	return ImageTexture.create_from_image(image)

func cleanup_old_portraits(max_age_days: int = 30) -> void:
	"""Clean up old portrait files"""
	var dir = DirAccess.open(PORTRAIT_DIR)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var current_time = Time.get_unix_time_from_system()
	
	while file_name != "":
		if file_name.ends_with(".png"):
			var file_path = PORTRAIT_DIR + file_name
			var file_time = FileAccess.get_modified_time(file_path)
			var age_seconds = current_time - file_time
			var age_days = age_seconds / (24 * 60 * 60)
			
			if age_days > max_age_days:
				dir.remove(file_name)
				print("PortraitManager: Cleaned up old portrait: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()