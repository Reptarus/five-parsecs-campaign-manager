@tool
extends Resource

signal mission_generated(mission_data: Dictionary)
signal mission_completed(mission_data: Dictionary, success: bool)

var difficulty_levels: Dictionary = {
	0: "Tutorial",
	1: "Easy",
	2: "Normal",
	3: "Hard",
	4: "Very Hard",
	5: "Extreme"
}

var mission_types: Dictionary = {
	0: "Combat",
	1: "Exploration",
	2: "Retrieval",
	3: "Escort",
	4: "Defense",
	5: "Sabotage",
	6: "Assassination",
	7: "Rescue",
	8: "Infiltration",
	9: "Investigation"
}

func generate_mission(difficulty: int = 2, type: int = -1) -> Dictionary:
	push_error("BaseMissionGenerator.generate_mission() must be overridden by derived class")
	return {}

func generate_random_mission() -> Dictionary:
	var difficulty = randi() % 5 + 1
	var type = randi() % (safe_call_method(mission_types, "size") as int)

	return generate_mission(difficulty, type)

func generate_mission_batch(count: int = 3, min_difficulty: int = 1, max_difficulty: int = 5) -> Array:
	var missions: Array[Dictionary] = []

	for i: int in range(count):
		var _difficulty = randi() % (max_difficulty - min_difficulty + 1) + min_difficulty
		var mission = generate_mission(_difficulty)
		missions.append(mission)

	return missions

func complete_mission(mission_data: Dictionary, success: bool = true) -> void:
	mission_completed.emit(mission_data, success)

func get_difficulty_name(difficulty: int) -> String:
	if difficulty_levels.has(difficulty):
		return difficulty_levels[difficulty]
	return "Unknown"

func get_mission_type_name(type: int) -> String:
	if mission_types.has(type):
		return mission_types[type]
	return "Unknown"

func generate_mission_title(type: int) -> String:
	push_error("BaseMissionGenerator.generate_mission_title() must be overridden by derived class")
	return "Mission"

func generate_mission_description(type: int, difficulty: int) -> String:
	push_error("BaseMissionGenerator.generate_mission_description() must be overridden by derived class")
	return "Mission description"

func calculate_mission_reward(difficulty: int, type: int) -> int:
	# Base reward calculation
	var base_reward: int = 100 * difficulty

	# Adjust based on mission type
	match type:
		0: # Combat
			base_reward *= 1.2
		1: # Exploration
			base_reward *= 0.8
		2: # Retrieval
			base_reward *= 1.0
		3: # Escort
			base_reward *= 1.1
		4: # Defense
			base_reward *= 1.3
		5: # Sabotage
			base_reward *= 1.4
		6: # Assassination
			base_reward *= 1.5
		7: # Rescue
			base_reward *= 1.2
		8: # Infiltration
			base_reward *= 1.3
		9: # Investigation
			base_reward *= 0.9

	return int(base_reward)

func serialize_mission(mission_data: Dictionary) -> Dictionary:
	# Base implementation just returns a copy of the mission _data
	return mission_data.duplicate(true)

func deserialize_mission(serialized_data: Dictionary) -> Dictionary:
	# Base implementation just returns a copy of the serialized _data
	return serialized_data.duplicate(true)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null