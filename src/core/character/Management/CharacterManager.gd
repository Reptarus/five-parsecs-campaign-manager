@tool
extends Node

signal character_added(character)
signal character_removed(character)
signal character_updated(character)
signal character_deleted(character_id)
signal character_health_changed(character_id, old_health, new_health)
signal character_status_changed(character_id, old_status, new_status)

# Character collections
var _characters = {}
var _active_characters = []
var _inactive_characters = []

func _init() -> void:
	# Initialize collections
	pass

func _ready() -> void:
	pass

# Create a new empty character
func create_character():
	var character = {
		"id": _generate_character_id({}),
		"name": "New Character",
		"health": 100,
		"status": {}
	}
	
	add_character(character)
	return character

# Add an existing character
func add_character(character) -> bool:
	# Ensure character has an ID
	if not ("id" in character) or character.id.is_empty():
		character.id = _generate_character_id(character)
		
	# Ensure character has required fields
	if not ("status" in character):
		character.status = {}
		
	# Add to collections
	var char_id = character.id
	_characters[char_id] = character
	_active_characters.append(character)
	
	# Emit signal
	character_added.emit(character)
	
	return true

# Remove a character
func remove_character(character_id: String) -> bool:
	if not (character_id in _characters):
		return false
		
	var character = _characters[character_id]
	
	# Remove from collections
	_characters.erase(character_id)
	
	if character in _active_characters:
		_active_characters.erase(character)
		
	if character in _inactive_characters:
		_inactive_characters.erase(character)
	
	# Emit signal
	character_removed.emit(character)
	
	return true

# Delete a character permanently
func delete_character(character_id: String) -> bool:
	if not (character_id in _characters):
		return false
	
	# Remove from all collections
	var success = remove_character(character_id)
	
	if success:
		# Emit signal for permanent deletion
		character_deleted.emit(character_id)
	
	return success

# Update character data
func update_character(character_id: String, character_data) -> bool:
	if not (character_id in _characters):
		return false
	
	var character = _characters[character_id]
	
	# Update fields
	for key in character_data:
		character[key] = character_data[key]
	
	# Ensure ID doesn't change
	character.id = character_id
	
	# Update character in collections
	_characters[character_id] = character
	
	# Emit signal
	character_updated.emit(character)
	
	return true

# Check if a character exists
func has_character(character_id: String) -> bool:
	if character_id is String:
		return (character_id in _characters)
	else:
		# If given a character object, extract ID
		return (_get_character_id(character_id) in _characters)

# Get a character by ID
func get_character(character_id: String):
	if (character_id in _characters):
		return _characters[character_id]
	return null

# Set a property on a character
func _set_character_property(character_id: String, property: String, value) -> bool:
	var character = get_character(character_id)
	if not character:
		return false
	
	# Ensure character is a valid Dictionary before using subscript
	if character is Dictionary:
		character[property] = value
		
		# Update character in collections
		_characters[character_id] = character
		
		# Emit signal for update
		character_updated.emit(character)
		
		return true
	return false

# Get a property from a character
func get_character_property(character_id: String, property: String):
	var character = get_character(character_id)
	if not character or not (property in character):
		return null
	
	# Ensure character is a valid Dictionary before using subscript
	if character is Dictionary:
		return character[property]
	return null

# Get all characters
func get_all_characters() -> Array:
	return _characters.values()

# Get active characters
func get_active_characters() -> Array:
	return _active_characters

# Get inactive characters
func get_inactive_characters() -> Array:
	return _inactive_characters

# Get character by index
func get_character_by_index(index: int):
	if index < 0 or index >= _active_characters.size():
		return null
		
	return _active_characters[index]

# Set character health
func set_character_health(character_id: String, health: int) -> bool:
	var character = get_character(character_id)
	if not character:
		return false
		
	var old_health = character.get("health", 0)
	var new_health = health
	
	# Update health value
	character.health = new_health
	
	# Update character in collections
	_characters[character_id] = character
	
	# Emit signal
	character_health_changed.emit(character_id, old_health, new_health)
	
	return true

# Set character status
func set_character_status(character_id, status_data: Dictionary) -> bool:
	var character = get_character(character_id)
	if not character:
		return false
		
	# Store old status for signal
	var old_status = {}
	if ("status" in character):
		old_status = character.status.duplicate()
	
	# Make sure status is initialized
	if not ("status" in character) or not character.status is Dictionary:
		character.status = {}
	
	# Update status with new values
	var new_status = character.status.duplicate()
	for key in status_data:
		new_status[key] = status_data[key]
	
	character.status = new_status
	
	# Update character in collections
	if character_id is String:
		_characters[character_id] = character
	elif ("id" in character):
		_characters[character.id] = character
	
	# Emit signal
	character_status_changed.emit(character_id, old_status, new_status)
	
	return true

# Move character to inactive state
func deactivate_character(character_id: String) -> bool:
	var character = get_character(character_id)
	if not character:
		return false
		
	if character in _active_characters:
		_active_characters.erase(character)
		_inactive_characters.append(character)
		return true
		
	return false

# Move character to active state
func activate_character(character_id: String) -> bool:
	var character = get_character(character_id)
	if not character:
		return false
		
	if character in _inactive_characters:
		_inactive_characters.erase(character)
		_active_characters.append(character)
		return true
		
	return false

# Apply damage to a character and determine injury result
func apply_battle_damage(character, damage: int, is_critical: bool = false) -> Dictionary:
	var char_id = _get_character_id(character)
	var result = {
		"survived": true,
		"injury_type": "minor"
	}
	
	# Get character health
	var health = 0
	if ("health" in character):
		health = character.health
	elif ("toughness" in character):
		health = character.toughness * 10
	
	# Apply damage
	health -= damage
	
	# Update character health
	if ("health" in character):
		character.health = health
	
	# Determine injury severity
	if health <= 0:
		result.survived = false
		result.injury_type = "fatal"
	elif is_critical or health <= 10:
		result.injury_type = "critical"
	elif health <= 25:
		result.injury_type = "serious"
	else:
		result.injury_type = "minor"
	
	# Apply status effect
	var status_data = {}
	if not result.survived:
		status_data["dead"] = true
	elif result.injury_type == "critical":
		status_data["critical_injury"] = true
	elif result.injury_type == "serious":
		status_data["serious_injury"] = true
	elif result.injury_type == "minor":
		status_data["minor_injury"] = true
	
	set_character_status(char_id, status_data)
	
	return result

# Process character advancement
func process_advancement(character, xp_amount: int) -> Dictionary:
	var char_id = _get_character_id(character)
	var advancement_result = {
		"gained_xp": xp_amount,
		"new_level": false,
		"new_skills": []
	}
	
	# Get current XP and level
	var current_xp = _get_character_property(character, "xp", 0)
	var current_level = _get_character_property(character, "level", 1)
	
	# Add XP
	var new_xp = current_xp + xp_amount
	_set_character_property(char_id, "xp", new_xp)
	
	# Check for level up
	var xp_for_next_level = current_level * 5 # Example threshold
	if new_xp >= xp_for_next_level:
		# Level up
		var new_level = current_level + 1
		_set_character_property(char_id, "level", new_level)
		advancement_result.new_level = true
		
		# Roll for new skill
		var new_skill = _roll_random_skill(character)
		if not new_skill.is_empty():
			advancement_result.new_skills.append(new_skill)
			
			# Add skill to character
			var skills = _get_character_property(character, "skills", [])
			if not skills is Array:
				skills = []
			skills.append(new_skill)
			_set_character_property(char_id, "skills", skills)
	
	return advancement_result

# Helper for getting character ID
func _get_character_id(character) -> String:
	if character is String:
		return character
	elif character is Dictionary and ("id" in character):
		return character.id
	else:
		return ""

# Helper for character property access
func _get_character_property(character, property: String, default_value = null):
	if character is Dictionary:
		return character.get(property, default_value)
	elif character is String:
		var char_obj = get_character(character)
		if char_obj:
			return char_obj.get(property, default_value)
	return default_value

# Generate a unique character ID
func _generate_character_id(character) -> String:
	var char_name = "char"
	if character is Dictionary and ("name" in character) and not character.name.is_empty():
		char_name = character.name.to_lower().replace(" ", "_")
	
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % (1 << 16)
	
	return "%s_%d_%d" % [char_name, timestamp, random_suffix]

# Roll a random skill for advancement
func _roll_random_skill(character) -> String:
	var possible_skills = [
		"Combat", "Tech", "Science", "Leadership",
		"Reactions", "Savvy", "Tactics", "Pilot"
	]
	
	var existing_skills = _get_character_property(character, "skills", [])
	var available_skills = []
	
	for skill in possible_skills:
		if not skill in existing_skills:
			available_skills.append(skill)
	
	if available_skills.is_empty():
		return ""
	
	return available_skills[randi() % available_skills.size()]
