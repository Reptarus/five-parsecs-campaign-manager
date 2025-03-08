@tool
extends Node

signal character_added(character)
signal character_updated(character)
signal character_removed(character_id: String)
signal character_status_changed(character_id: String, old_status: String, new_status: String)
signal character_injured(character, injury_data: Dictionary)
signal character_killed(character)
signal character_experience_gained(character, amount: int)
signal character_advanced(character, improvements: Dictionary)

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterBox = preload("res://src/core/character/Base/CharacterBox.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")
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
	pass

func create_character() -> Character:
	var character = Character.new()
	add_character(character)
	return character

func add_character(character) -> bool:
	if not character:
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
		
	character.improve_stat(stat)
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func add_experience(character, amount: int) -> void:
	if not character:
		return
		
	var current_xp = _get_character_property(character, "experience", 0)
	_set_character_property(character, "experience", current_xp + amount)
	
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func add_equipment(character, equipment) -> bool:
	if not character:
		return false
		
	if equipment is GameWeapon:
		var weapons = _get_character_property(character, "weapons", [])
		weapons.append(equipment)
		_set_character_property(character, "weapons", weapons)
	else:
		var items = _get_character_property(character, "items", [])
		items.append(equipment)
		_set_character_property(character, "items", items)
	
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)
		
	return true

func remove_equipment(character, equipment_id: String) -> bool:
	if not character:
		return false
		
	var weapons = _get_character_property(character, "weapons", [])
	var items = _get_character_property(character, "items", [])
	
	# Try to remove from weapons
	for i in range(weapons.size() - 1, -1, -1):
		var weapon = weapons[i]
		if weapon.id == equipment_id:
			weapons.remove_at(i)
			_set_character_property(character, "weapons", weapons)
			
			var char_id = _get_character_property(character, "id", "")
			if not char_id.is_empty():
				update_character(char_id, character)
			
			return true
	
	# Try to remove from items
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		if item.id == equipment_id:
			items.remove_at(i)
			_set_character_property(character, "items", items)
			
			var char_id = _get_character_property(character, "id", "")
			if not char_id.is_empty():
				update_character(char_id, character)
			
			return true
			
	return false

# Helper functions
func _update_active_characters() -> void:
	_active_characters.clear()
	for id in _characters:
		var character = _characters[id]
		if _get_character_property(character, "is_active", false):
			_active_characters.append(character)

func _roll_character_improvements(character) -> Dictionary:
	# Roll for random stat improvements based on character class and rules
	var improvements = {}
	var roll1 = randi() % 6 + 1 # d6
	var roll2 = randi() % 6 + 1 # d6
	
	var primary_stat = ""
	var secondary_stat = ""
	
	# Determine which stats to improve based on character class
	match _get_character_property(character, "character_class", GameEnums.CharacterClass.NONE):
		GameEnums.CharacterClass.SOLDIER:
			primary_stat = "combat"
			secondary_stat = "toughness"
		GameEnums.CharacterClass.MEDIC:
			primary_stat = "savvy"
			secondary_stat = "luck"
		GameEnums.CharacterClass.ENGINEER:
			primary_stat = "savvy"
			secondary_stat = "combat"
		GameEnums.CharacterClass.PILOT:
			primary_stat = "reaction"
			secondary_stat = "speed"
		_:
			primary_stat = "combat"
			secondary_stat = "reaction"
	
	# 50% chance to improve primary stat, otherwise improve secondary
	if roll1 <= 3:
		improvements[primary_stat] = 1
	else:
		improvements[secondary_stat] = 1
	
	# 1 in 6 chance to improve a random stat as well
	if roll2 == 6:
		var random_stats = ["reaction", "combat", "speed", "savvy", "toughness", "luck"]
		random_stats.shuffle()
		var random_stat = random_stats[0]
		
		if random_stat in improvements:
			improvements[random_stat] += 1
		else:
			improvements[random_stat] = 1
	
	return improvements

func _initialize_class_stats(character) -> void:
	var char_class = _get_character_property(character, "character_class", GameEnums.CharacterClass.NONE)
	
	match char_class:
		GameEnums.CharacterClass.SOLDIER:
			_set_character_property(character, "combat", 3)
			_set_character_property(character, "toughness", 2)
			_set_character_property(character, "reaction", 2)
			_set_character_property(character, "savvy", 1)
		GameEnums.CharacterClass.MEDIC:
			_set_character_property(character, "combat", 1)
			_set_character_property(character, "toughness", 2)
			_set_character_property(character, "reaction", 2)
			_set_character_property(character, "savvy", 3)
		GameEnums.CharacterClass.ENGINEER:
			_set_character_property(character, "combat", 2)
			_set_character_property(character, "toughness", 1)
			_set_character_property(character, "reaction", 2)
			_set_character_property(character, "savvy", 3)
		GameEnums.CharacterClass.PILOT:
			_set_character_property(character, "combat", 2)
			_set_character_property(character, "toughness", 1)
			_set_character_property(character, "reaction", 3)
			_set_character_property(character, "savvy", 2)
		GameEnums.CharacterClass.SECURITY:
			_set_character_property(character, "combat", 3)
			_set_character_property(character, "toughness", 3)
			_set_character_property(character, "reaction", 1)
			_set_character_property(character, "savvy", 1)

func _get_character_property(character, property: String, default_value = null):
	if character.has_method("get"):
		return character.get(property, default_value)
	elif property in character:
		return character[property]
	return default_value

func _set_character_property(character, property: String, value) -> void:
	if character.has_method("set"):
		character.set(property, value)
	else:
		character[property] = value
