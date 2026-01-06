extends Resource

# GlobalEnums available as autoload singleton

@export var rival_name: String = ""
@export var rival_type: String = ""
@export var threat_level: GlobalEnums.DifficultyLevel = GlobalEnums.DifficultyLevel.STANDARD
@export var reputation: int = 0
@export var active: bool = true
@export var last_encounter_turn: int = -1

# Planet binding - tracks which planets this rival is associated with
@export var origin_planet_id: String = ""  # Planet where rival was first encountered
@export var current_planet_id: String = ""  # Planet where rival is currently located
@export var can_follow: bool = true  # Whether rival can follow crew to other planets

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
	match threat_level:
		GlobalEnums.DifficultyLevel.STORY:
			return 0.8
		GlobalEnums.DifficultyLevel.STANDARD:
			return 1.0
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return 1.2
		GlobalEnums.DifficultyLevel.HARDCORE:
			return 1.4
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return 1.6
	return 1.0

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
		"encounter_history": encounter_history,
		"origin_planet_id": origin_planet_id,
		"current_planet_id": current_planet_id,
		"can_follow": can_follow
	}

func deserialize(data: Dictionary) -> void:
	rival_name = data.get("name", "")

	rival_type = data.get("type", "")

	threat_level = data.get("threat_level", GlobalEnums.DifficultyLevel.STANDARD)

	reputation = data.get("reputation", 0)

	active = data.get("active", true)

	last_encounter_turn = data.get("last_encounter_turn", -1)

	# Type conversion: JSON returns untyped Array, we need Array[String]
	var raw_traits = data.get("special_traits", [])
	special_traits = []
	for trait_entry in raw_traits:
		special_traits.append(str(trait_entry))

	resources = data.get("resources", {})

	# Type conversion: JSON returns untyped Array, we need Array[Dictionary]
	encounter_history.clear()
	for entry in data.get("encounter_history", []):
		if entry is Dictionary:
			encounter_history.append(entry)

	origin_planet_id = data.get("origin_planet_id", "")
	current_planet_id = data.get("current_planet_id", "")
	can_follow = data.get("can_follow", true)

