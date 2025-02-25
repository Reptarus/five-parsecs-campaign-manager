@tool
extends Node2D
class_name FiveParsecsBattleCharacter

const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")

var character_data: FiveParsecsCharacter

func _init(data: FiveParsecsCharacter = null) -> void:
	if data:
		character_data = data
	else:
		character_data = FiveParsecsCharacter.new()

func get_character_data() -> FiveParsecsCharacter:
	return character_data

# Delegate common properties to character_data
var character_name: String:
	get: return character_data.character_name
	set(value): character_data.character_name = value

var health: int:
	get: return character_data.health
	set(value): character_data.health = value

var max_health: int:
	get: return character_data.max_health
	set(value): character_data.max_health = value

# Add battle-specific properties and methods
var is_active: bool = false
var current_action: int = GameEnums.UnitAction.NONE
var available_actions: Array[int] = []

func initialize_for_battle() -> void:
	is_active = true
	current_action = GameEnums.UnitAction.NONE
	available_actions = [] # Will be populated by battle system

func cleanup_battle() -> void:
	is_active = false
	current_action = GameEnums.UnitAction.NONE
	available_actions.clear()