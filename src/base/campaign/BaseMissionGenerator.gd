# Base class for mission generators
# Extends RefCounted rather than Node so it can be used without scene tree
extends RefCounted

# Base mission types
enum MissionType {
	NONE = 0,
	COMBAT = 1,
	EXPLORATION = 2,
	RECOVERY = 3,
	ESCORT = 4,
	DEFENSE = 5,
	SPECIAL = 6
}

# Signal for when a mission is generated
signal mission_generated(mission: Dictionary)

# Default mission properties
var mission_types: Dictionary = {
	MissionType.NONE: "Unknown",
	MissionType.COMBAT: "Combat",
	MissionType.EXPLORATION: "Exploration",
	MissionType.RECOVERY: "Recovery",
	MissionType.ESCORT: "Escort",
	MissionType.DEFENSE: "Defense",
	MissionType.SPECIAL: "Special"
}

# Generate a mission with given parameters
# To be overridden by subclasses
func generate_mission(difficulty: int = 1, type: int = -1) -> Dictionary:
	# Base implementation creates a simple mission template
	var mission = {
		"id": str(randi()),
		"type": type if type >= 0 else MissionType.NONE,
		"difficulty": difficulty,
		"title": "Generic Mission",
		"description": "A generic mission description.",
		"reward": difficulty * 50,
		"objectives": ["Complete the mission"],
		"completed": false,
		"success": false
	}
	
	mission_generated.emit(mission)
	return mission

# Helper function to get mission type name
func get_mission_type_name(type: int) -> String:
	if mission_types.has(type):
		return mission_types[type]
	return "Unknown"

# Serialize mission data for saving
func serialize_mission(mission_data: Dictionary) -> Dictionary:
	return mission_data.duplicate(true)

# Deserialize mission data from saved data
func deserialize_mission(serialized_data: Dictionary) -> Dictionary:
	return serialized_data.duplicate(true)
