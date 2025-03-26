@tool
extends Node
# Removed class_name declaration to prevent conflict with Management version
# The autoload should use the Management version to maintain compatibility

# This file exists in the management (lowercase m) directory
# All functionality has been moved from the Management (capital M) directory
# The autoload now correctly references the lowercase version in project.godot

func _init():
	push_warning("Using lowercase version of CharacterManager at res://src/core/character/management/CharacterManager.gd")

signal character_added(character)
signal character_updated(character)
signal character_removed(character_id: String)
signal character_status_changed(character_id: String, old_status: String, new_status: String)
signal character_injured(character, injury_data: Dictionary)
signal character_killed(character)
signal character_experience_gained(character, amount: int)
signal character_advanced(character, improvements: Dictionary)

var Character = null
var CharacterBox = null
var GameEnums = null
var GameWeapon = null
const MAX_CHARACTERS = 100

# Character status constants
const STATUS_READY = "ready"
const STATUS_INJURED = "injured"
const STATUS_CRITICAL = "critical"
const STATUS_DEAD = "dead"
const STATUS_RESTING = "resting"
const STATUS_UNAVAILABLE = "unavailable"

var _characters: Dictionary = {}
var _active_characters: Array = []
var _recovery_queue: Array = []

func _ready() -> void:
	# Load classes to avoid circular references
	Character = load("res://src/core/character/Base/Character.gd")
	CharacterBox = load("res://src/core/character/Base/CharacterBox.gd")
	GameEnums = load("res://src/core/systems/GlobalEnums.gd")
	GameWeapon = load("res://src/core/systems/items/GameWeapon.gd")

func create_character():
	if not Character:
		Character = load("res://src/core/character/Base/Character.gd")
		
	if not Character:
		push_error("CharacterManager: Cannot create character - Character class not found")
		return null
		
	var character = Character.new()
	add_character(character)
	return character

func add_character(character) -> bool:
	if not character or not is_instance_valid(character):
		return false
		
	if _characters.size() >= MAX_CHARACTERS:
		return false
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty():
		push_error("Character missing required id property")
		return false
		
	_characters[char_id] = character
	if _get_character_property(character, "is_active", false):
		_active_characters.append(character)
	
	character_added.emit(character)
	return true

func update_character(character_id: String, character) -> bool:
	if not character_id in _characters:
		return false
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty() or char_id != character_id:
		push_error("Character id mismatch or missing")
		return false
		
	_characters[character_id] = character
	_update_active_characters()
	
	character_updated.emit(character)
	return true

func remove_character(character_id: String) -> bool:
	if not character_id in _characters:
		return false
		
	var character = _characters[character_id]
	_characters.erase(character_id)
	_active_characters.erase(character)
	
	character_removed.emit(character_id)
	return true

func get_character(character_id: String):
	return _characters.get(character_id)

func has_character(character_id: String) -> bool:
	return character_id in _characters

func get_character_count() -> int:
	return _characters.size()

func get_active_characters() -> Array:
	return _active_characters.duplicate()

func get_ready_characters() -> Array:
	var ready_characters = []
	for character in _active_characters:
		if _get_character_property(character, "status", "") == STATUS_READY:
			ready_characters.append(character)
	return ready_characters

func get_injured_characters() -> Array:
	var injured_characters = []
	for character in _active_characters:
		var status = _get_character_property(character, "status", "")
		if status == STATUS_INJURED or status == STATUS_CRITICAL:
			injured_characters.append(character)
	return injured_characters

# Helper function to get character properties safely
func _get_character_property(character, property: String, default_value = null):
	if not character or not is_instance_valid(character):
		return default_value
		
	# Try direct property access first
	if property in character:
		return character.get(property)
		
	# Try get method
	var get_method = "get_" + property
	if character.get_method_list().any(func(method): return method.name == get_method):
		return character.call(get_method)
		
	# Try generic get method
	if character.get_method_list().any(func(method): return method.name == "get"):
		return character.call("get", property, default_value)
		
	return default_value

# Helper function to set character properties safely
func _set_character_property(character, property: String, value) -> void:
	if not character or not is_instance_valid(character):
		return
		
	# Try direct property access first
	if property in character:
		character.set(property, value)
		return
		
	# Try set method
	var set_method = "set_" + property
	if character.get_method_list().any(func(method): return method.name == set_method):
		character.call(set_method, value)
		return
		
	# Try generic set method
	if character.get_method_list().any(func(method): return method.name == "set"):
		character.call("set", property, value)

# Update the active characters list
func _update_active_characters() -> void:
	_active_characters.clear()
	for char_id in _characters:
		var character = _characters[char_id]
		if _get_character_property(character, "is_active", false):
			_active_characters.append(character)

# Phase-specific character management functions

## Process upkeep phase for all characters
func process_upkeep_phase() -> Dictionary:
	var result = {
		"maintenance_cost": 0,
		"recovered": [],
		"still_injured": []
	}
	
	# Calculate upkeep costs
	result.maintenance_cost = _active_characters.size() * 100
	
	# Check for recovery of injured characters
	for character in _active_characters:
		var status = _get_character_property(character, "status", "")
		if status == STATUS_INJURED:
			# Roll for recovery
			var recovery_roll = randi() % 6 + 1 # d6
			if recovery_roll >= 4: # Succeed on 4+
				set_character_status(character, STATUS_READY)
				result.recovered.append(character)
			else:
				result.still_injured.append(character)
		elif status == STATUS_CRITICAL:
			# Critical injuries take longer to recover
			set_character_status(character, STATUS_INJURED)
			result.still_injured.append(character)
	
	return result

## Process battle damage for a character
func apply_battle_damage(character, damage: int, is_critical: bool = false) -> Dictionary:
	if not character:
		return {}
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty():
		return {}
	
	var old_status = _get_character_property(character, "status", STATUS_READY)
	var injury_data = {
		"character_id": char_id,
		"damage": damage,
		"is_critical": is_critical,
		"survived": true,
		"injury_type": "minor"
	}
	
	# Check for death
	if is_critical and damage >= _get_character_property(character, "toughness", 1) * 2:
		set_character_status(character, STATUS_DEAD)
		injury_data.survived = false
		character_killed.emit(character)
	# Check for critical injury
	elif is_critical or damage >= _get_character_property(character, "toughness", 1):
		set_character_status(character, STATUS_CRITICAL)
		injury_data.injury_type = "critical"
	# Regular injury
	elif damage > 0:
		set_character_status(character, STATUS_INJURED)
		injury_data.injury_type = "minor"
	
	update_character(char_id, character)
	
	# Emit signal for UI/logging purposes
	character_injured.emit(character, injury_data)
	
	return injury_data

## Process advancement phase for a character
func process_advancement(character, experience_points: int) -> Dictionary:
	if not character:
		return {}
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty():
		return {}
	
	# Add experience points
	add_experience(character, experience_points)
	character_experience_gained.emit(character, experience_points)
	
	var improvements = {}
	var xp = _get_character_property(character, "experience", 0)
	var level = _get_character_property(character, "level", 1)
	
	# Check for level up
	if xp >= level * 100:
		# Calculate stat improvements
		improvements = _roll_character_improvements(character)
		
		# Apply improvements
		for stat in improvements:
			improve_stat(character, stat)
		
		# Increase level
		_set_character_property(character, "level", level + 1)
		
		character_advanced.emit(character, improvements)
	
	update_character(char_id, character)
	return improvements

## Set a character's status
func set_character_status(character, new_status: String) -> void:
	if not character:
		return
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty():
		return
	
	var old_status = _get_character_property(character, "status", STATUS_READY)
	if old_status == new_status:
		return
	
	_set_character_property(character, "status", new_status)
	update_character(char_id, character)
	
	character_status_changed.emit(char_id, old_status, new_status)

func set_character_class(character, char_class: int) -> void:
	if not character:
		return
		
	_set_character_property(character, "character_class", char_class)
	_initialize_class_stats(character)
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func improve_stat(character, stat: int) -> void:
	if not character:
		return
		
	var current_value = _get_character_property(character, "stats", {}).get(stat, 0)
	var stats = _get_character_property(character, "stats", {}).duplicate()
	stats[stat] = current_value + 1
	_set_character_property(character, "stats", stats)

func add_experience(character, amount: int) -> void:
	if not character:
		return
		
	var current_xp = _get_character_property(character, "experience", 0)
	_set_character_property(character, "experience", current_xp + amount)

func _roll_character_improvements(character) -> Dictionary:
	if not character:
		return {}
		
	# This would typically roll for random stat improvements
	# For now, return a simple fixed improvement
	return {
		GameEnums.CharacterStat.COMBAT: 1
	}

func _initialize_class_stats(character) -> void:
	if not character:
		return
		
	var char_class = _get_character_property(character, "character_class", 0)
	var stats = _get_character_property(character, "stats", {}).duplicate()
	
	# Set default stats based on class
	match char_class:
		GameEnums.CharacterClass.SOLDIER:
			stats[GameEnums.CharacterStat.COMBAT] = 3
			stats[GameEnums.CharacterStat.TOUGHNESS] = 2
		GameEnums.CharacterClass.MEDIC:
			stats[GameEnums.CharacterStat.MEDICAL] = 3
			stats[GameEnums.CharacterStat.REACTIONS] = 2
		# Add other classes as needed
	
	_set_character_property(character, "stats", stats)
