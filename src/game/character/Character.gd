@tool
extends "res://src/core/character/Base/Character.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

# Use a different constant name to avoid conflicts with parent's Self constant
const GameCharacterSelf = preload("res://src/game/character/Character.gd")

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

func _init() -> void:
	super._init()

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
