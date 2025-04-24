@tool
extends RefCounted

# Helper functions for character testing with proper type safety

# Use explicit preloads instead of global class names - fixed path
const CharacterManagerScript = preload("res://src/core/character/management/CharacterManager.gd")

# Create a test character with proper types
static func create_test_character() -> Dictionary:
	return {
		"id": "test_char",
		"name": "Test Character",
		"health": 100,
		"status": {} # Initialize as Dictionary, not Array
	}

# Get a property from character with type safety
static func get_character_property(character: Dictionary, property: String):
	# Return value without type annotation to avoid Variant issues
	if character == null or not character.has(property):
		return null
	return character[property]

# Set character status with type safety
static func set_character_status(character: Dictionary, status_data: Dictionary) -> Dictionary:
	if character != null:
		# Create new Dictionary if status doesn't exist
		if not character.has("status"):
			character["status"] = {}
		elif not (character["status"] is Dictionary):
			character["status"] = {}
			
		# Update status with new values using direct dictionary access
		var status_dict = character["status"] as Dictionary
		for key in status_data:
			status_dict[key] = status_data[key]
		character["status"] = status_dict
	return character

# Add status effect with proper typing
static func add_status_effect(character: Dictionary, effect: String, value = true) -> void:
	if character == null:
		return
		
	# Create status Dictionary if it doesn't exist
	if not character.has("status"):
		character["status"] = {}
	elif not (character["status"] is Dictionary):
		character["status"] = {}
	
	# Add the effect using direct dictionary access
	var status_dict = character["status"] as Dictionary
	status_dict[effect] = value
	character["status"] = status_dict