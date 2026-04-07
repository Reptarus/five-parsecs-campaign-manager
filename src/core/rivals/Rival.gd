extends Resource

const GameEnums = preload("res://src/core/enums/GameEnums.gd")

@export var rival_name: String = ""
@export var rival_type: String = ""
@export var threat_level: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
@export var reputation: int = 0
@export var active: bool = true
@export var last_encounter_turn: int = -1

var special_traits: Array[String] = []
var resources: Dictionary = {}
var encounter_history: Array[Dictionary] = []

func _init() -> void:
	_initialize_resources()

func _initialize_resources() -> void:
	resources = {
		"credits": 1000,
		"influence": 0,
		"territory": 0
	}

func get_threat_modifier() -> float:
	## Core Rules pp.64-65: 5 difficulty modes only. App-level UX scaling (not rules data).
	match threat_level:
		GameEnums.DifficultyLevel.EASY:
			return 0.8
		GameEnums.DifficultyLevel.NORMAL, GameEnums.DifficultyLevel.CHALLENGING:
			return 1.0
		GameEnums.DifficultyLevel.HARDCORE:
			return 1.4
		GameEnums.DifficultyLevel.INSANITY:
			return 1.6
	return 1.0  # Catches NONE + deprecated HARD/NIGHTMARE/ELITE

func add_encounter(encounter_data: Dictionary) -> void:
	encounter_data["turn"] = last_encounter_turn
	encounter_history.append(encounter_data)

func get_encounter_history() -> Array[Dictionary]:
	return encounter_history

func serialize() -> Dictionary:
	return {
		"name": rival_name,
		"type": rival_type,
		"threat_level": threat_level,
		"reputation": reputation,
		"active": active,
		"last_encounter_turn": last_encounter_turn,
		"special_traits": special_traits,
		"resources": resources,
		"encounter_history": encounter_history
	}

func deserialize(data: Dictionary) -> void:
	rival_name = data.get("name", "")
	rival_type = data.get("type", "")
	threat_level = data.get("threat_level", GameEnums.DifficultyLevel.NORMAL)
	reputation = data.get("reputation", 0)
	active = data.get("active", true)
	last_encounter_turn = data.get("last_encounter_turn", -1)
	special_traits.assign(data.get("special_traits", []))
	resources = data.get("resources", {})
	encounter_history.assign(data.get("encounter_history", []))
