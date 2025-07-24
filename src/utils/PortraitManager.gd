extends RefCounted
class_name PortraitManager

## Portrait Management Utility for Five Parsecs Campaign Manager
## Handles importing, exporting, validation, and processing of character portraits

const PORTRAIT_DIR = "user://portraits/"
const MAX_FILE_SIZE = 10 * 1024 * 1024 # 10MB
const MAX_IMAGE_SIZE = 512
const MIN_IMAGE_SIZE = 64
const VALID_EXTENSIONS = ["png", "jpg", "jpeg"]

signal portrait_loaded(portrait_path: String)
signal portrait_exported(export_path: String)
signal portrait_error(error_message: String)

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
	"""Get a default portrait based on character class"""
	var default_path = "res://assets/portraits/default_%s.png" % GlobalEnums.CharacterClass.keys()[character_class].to_lower()
	
	if ResourceLoader.exists(default_path):
		return load(default_path)
	else:
		# Return a colored placeholder
		return _create_placeholder_portrait(character_class)

func _create_placeholder_portrait(character_class: int) -> Texture2D:
	"""Create a colored placeholder portrait"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Set color based on character class
	var color = Color.GRAY
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