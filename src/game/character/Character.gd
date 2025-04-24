@tool
extends Resource # Changed from "res://src/base/character/character_base.gd" to enforce proper type inheritance

# This file should be referenced via preload
# Use explicit preloads instead of global class names

# Import the actual base character to use its functionality
const BaseCharacter = preload("res://src/base/character/character_base.gd")
const Self = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Game implementation of the Five Parsecs character
##
## Extends the core character with game-specific functionality
## for the Five Parsecs From Home implementation.

# Game-specific properties
var portrait_path: String = ""
var faction_relations: Dictionary = {}
var morale: int = 5
var credits_earned: int = 0
var missions_completed: int = 0
var kills: int = 0
var character_class: int = 0 # Reference to character class enum value

# Core properties delegated to the base character
var character_name: String = "New Character"
var health: int = 100
var max_health: int = 100
var is_wounded: bool = false
var is_dead: bool = false
var status_effects: Array = []
var experience: int = 0
var level: int = 1

# Core stats from base character
var reaction: int = 0
var combat: int = 0
var toughness: int = 0
var speed: int = 0

# Base character instance for delegation
var _base_character = null

func _init() -> void:
	# Create the base character for delegation
	_base_character = BaseCharacter.new()
	
	# Initialize default values
	if _base_character:
		character_name = _base_character.character_name
		health = _base_character.health
		max_health = _base_character.max_health
		is_wounded = _base_character.is_wounded
		is_dead = _base_character.is_dead
		status_effects = _base_character.status_effects.duplicate()
		experience = _base_character.experience
		level = _base_character.level
		
		# Copy stats
		reaction = _base_character.reaction
		combat = _base_character.combat
		toughness = _base_character.toughness
		speed = _base_character.speed

## Game-specific methods

## Track a kill for this character
func add_kill() -> void:
	kills += 1
	
	# Award experience for kills
	add_experience(10)

## Track mission completion
func complete_mission(credits: int = 0) -> void:
	missions_completed += 1
	
	if credits > 0:
		credits_earned += credits
		
	# Award experience for mission completion
	add_experience(50)

## Apply morale changes
func modify_morale(amount: int) -> void:
	morale = clampi(morale + amount, 0, 10)
	
	# Handle morale effects
	if morale <= 2:
		apply_status_effect({
			"id": "low_morale",
			"type": "debuff",
			"duration": 2,
			"effects": {
				"combat": - 1
			}
		})
	elif morale >= 8:
		apply_status_effect({
			"id": "high_morale",
			"type": "buff",
			"duration": 2,
			"effects": {
				"reaction": 1
			}
		})

## Set faction relations
func set_faction_relation(faction_id: String, value: int) -> void:
	faction_relations[faction_id] = value

## Get faction relation
func get_faction_relation(faction_id: String) -> int:
	return faction_relations.get(faction_id, 0)

## Get character portrait path
func get_portrait() -> String:
	if portrait_path.is_empty():
		# Return default portrait based on character class
		return "res://assets/portraits/default_%s.png" % GameEnums.CharacterClass.keys()[character_class].to_lower()
	return portrait_path

## Set character portrait
func set_portrait(path: String) -> void:
	portrait_path = path

## Get character experience summary
func get_experience_summary() -> String:
	var summary = "Level %d (%d/%d XP)" % [
		level,
		experience,
		level * 100 # XP needed for next level
	]
	return summary

## Get character's service record summary
func get_service_record() -> String:
	var record = "Missions: %d | Kills: %d | Credits: %d" % [
		missions_completed,
		kills,
		credits_earned
	]
	return record

# Delegate methods to base character

func add_experience(amount: int) -> bool:
	if _base_character:
		var result = _base_character.add_experience(amount)
		# Update our local copy after the base character update
		experience = _base_character.experience
		level = _base_character.level
		return result
	return false

func apply_status_effect(effect: Dictionary) -> void:
	if _base_character:
		_base_character.apply_status_effect(effect)
		# Update our local copy
		status_effects = _base_character.status_effects.duplicate()
