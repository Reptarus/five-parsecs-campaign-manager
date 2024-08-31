class_name ExpandedMissionsManager
extends Node

enum MissionType {
	ASSASSINATION,
	SABOTAGE,
	RESCUE,
	INFILTRATION,
	DEFENSE,
	ESCORT
}

const MIN_MISSION_CHAIN_LENGTH: int = 3
const MAX_MISSION_CHAIN_LENGTH: int = 5

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_expanded_mission() -> Dictionary:
	var mission_type: MissionType = MissionType.values()[randi() % MissionType.size()]
	
	var mission: Dictionary = {
		"type": mission_type,
		"primary_objective": _generate_primary_objective(mission_type),
		"secondary_objectives": _generate_secondary_objectives(mission_type),
		"rewards": _generate_rewards(mission_type),
		"difficulty": randi_range(1, 5)
	}
	
	return mission

func _generate_primary_objective(mission_type: MissionType) -> String:
	match mission_type:
		MissionType.ASSASSINATION:
			return "Eliminate the target: " + _generate_random_name()
		MissionType.SABOTAGE:
			return "Destroy the " + _generate_random_facility()
		MissionType.RESCUE:
			return "Rescue " + _generate_random_name() + " from captivity"
		MissionType.INFILTRATION:
			return "Infiltrate and gather intel from " + _generate_random_facility()
		MissionType.DEFENSE:
			return "Defend the " + _generate_random_facility() + " for " + str(randi_range(3, 6)) + " rounds"
		MissionType.ESCORT:
			return "Escort " + _generate_random_name() + " safely to the extraction point"
		_:
			assert(false, "Invalid mission type")
			return ""

func _generate_secondary_objectives(mission_type: MissionType) -> Array[String]:
	var objectives: Array[String] = []
	objectives.append("Minimize collateral damage")
	objectives.append("Complete the mission within " + str(randi_range(4, 8)) + " rounds")
	
	match mission_type:
		MissionType.ASSASSINATION, MissionType.SABOTAGE:
			objectives.append("Leave no witnesses")
		MissionType.RESCUE, MissionType.INFILTRATION:
			objectives.append("Remain undetected")
		MissionType.DEFENSE, MissionType.ESCORT:
			objectives.append("Ensure all team members survive")
	
	return objectives

func _generate_rewards(mission_type: MissionType) -> Dictionary:
	return {
		"credits": randi_range(1000, 5000),
		"reputation": randi_range(1, 5),
		"item": _generate_random_item()
	}

func generate_mission_chain(length: int) -> Array[Dictionary]:
	assert(length >= MIN_MISSION_CHAIN_LENGTH and length <= MAX_MISSION_CHAIN_LENGTH, "Invalid mission chain length")
	
	var mission_chain: Array[Dictionary] = []
	var base_difficulty: int = randi_range(1, 3)
	
	for i in range(length):
		var mission: Dictionary = generate_expanded_mission()
		mission.difficulty = min(base_difficulty + i, 5)
		mission_chain.append(mission)
	
	return mission_chain

func _generate_random_name() -> String:
	var first_names: Array[String] = ["John", "Jane", "Alex", "Sarah", "Michael"]
	var last_names: Array[String] = ["Smith", "Johnson", "Williams", "Brown", "Jones"]
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _generate_random_facility() -> String:
	var facilities: Array[String] = ["Research Lab", "Power Plant", "Communications Tower", "Weapons Depot", "Command Center"]
	return facilities[randi() % facilities.size()]

func _generate_random_item() -> String:
	var items: Array[String] = ["Advanced Weapon", "Protective Gear", "Stealth Device", "Medical Kit", "Hacking Tool"]
	return items[randi() % items.size()]
