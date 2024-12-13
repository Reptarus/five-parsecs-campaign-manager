@tool
class_name Mission
extends Resource

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

@export var mission_name: String = ""
@export var mission_type: GlobalEnums.MissionType = GlobalEnums.MissionType.GREEN_ZONE
@export var deployment_type: GlobalEnums.DeploymentType = GlobalEnums.DeploymentType.STANDARD
@export var objectives: Array[Dictionary] = []
@export var enemy_count: int = 5
@export var terrain_type: String = "urban"
@export var difficulty: GlobalEnums.DifficultyMode = GlobalEnums.DifficultyMode.NORMAL

func _init() -> void:
	objectives = []

func add_objective(objective_type: GlobalEnums.MissionObjective, position: Vector2) -> void:
	objectives.append({
		"type": objective_type,
		"position": position,
		"completed": false
	})

func get_objective_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for objective in objectives:
		positions.append(objective.position)
	return positions

func is_completed() -> bool:
	for objective in objectives:
		if not objective.completed:
			return false
	return true

func get_mission_data() -> Dictionary:
	return {
		"name": mission_name,
		"type": mission_type,
		"deployment_type": deployment_type,
		"objectives": objectives.duplicate(),
		"enemy_count": enemy_count,
		"terrain_type": terrain_type,
		"difficulty": difficulty
	} 