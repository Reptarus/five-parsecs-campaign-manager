class_name MissionData
extends Resource

# Mission properties
@export var mission_type: int  # GlobalEnums.MissionType
@export var difficulty: int
@export var location: String
@export var objectives: Array
@export var rewards: Dictionary
@export var deployment: Dictionary
@export var enemy_force: Dictionary

# Mission state
var is_completed: bool = false
var is_failed: bool = false
var turn_started: int = -1
var turn_completed: int = -1

# Optional properties
var patron: Patron = null
var story_id: String = ""
var special_rules: Array = []

func _init() -> void:
	pass

func start(current_turn: int) -> void:
	turn_started = current_turn

func complete(current_turn: int) -> void:
	is_completed = true
	turn_completed = current_turn

func fail(current_turn: int) -> void:
	is_failed = true
	turn_completed = current_turn

func is_expired(current_turn: int) -> bool:
	# Missions expire after 5 turns if not started
	return turn_started == -1 and current_turn - turn_started > 5

func get_objective_text() -> String:
	var text = ""
	for i in range(objectives.size()):
		var prefix = "Primary: " if i == 0 else "Secondary: "
		text += prefix + _get_objective_description(objectives[i]) + "\n"
	return text

func _get_objective_description(objective: int) -> String:
	match objective:
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			return "Move through the area"
		GlobalEnums.MissionObjective.RETRIEVE:
			return "Retrieve the objective"
		GlobalEnums.MissionObjective.SURVIVE:
			return "Survive and extract"
		GlobalEnums.MissionObjective.CONTROL_POINT:
			return "Control the objective point"
		GlobalEnums.MissionObjective.DEFEND:
			return "Defend the position"
		GlobalEnums.MissionObjective.ELIMINATE:
			return "Eliminate all hostiles"
		GlobalEnums.MissionObjective.DESTROY_STRONGPOINT:
			return "Destroy enemy strongpoint"
		GlobalEnums.MissionObjective.ELIMINATE_TARGET:
			return "Eliminate priority target"
		GlobalEnums.MissionObjective.PENETRATE_LINES:
			return "Break through enemy lines"
		GlobalEnums.MissionObjective.SABOTAGE:
			return "Sabotage the objective"
		GlobalEnums.MissionObjective.SECURE_INTEL:
			return "Secure intelligence"
		GlobalEnums.MissionObjective.CLEAR_ZONE:
			return "Clear the zone of hostiles"
		_:
			return "Unknown objective"

func serialize() -> Dictionary:
	return {
		"mission_type": GlobalEnums.MissionType.keys()[mission_type],
		"difficulty": difficulty,
		"location": location,
		"objectives": objectives.map(func(o): return GlobalEnums.MissionObjective.keys()[o]),
		"rewards": rewards,
		"deployment": deployment,
		"enemy_force": enemy_force,
		"is_completed": is_completed,
		"is_failed": is_failed,
		"turn_started": turn_started,
		"turn_completed": turn_completed,
		"story_id": story_id,
		"special_rules": special_rules
	}

static func deserialize(data: Dictionary) -> MissionData:
	var mission = MissionData.new()
	mission.mission_type = GlobalEnums.MissionType[data.mission_type]
	mission.difficulty = data.difficulty
	mission.location = data.location
	mission.objectives = data.objectives.map(func(o): return GlobalEnums.MissionObjective[o])
	mission.rewards = data.rewards
	mission.deployment = data.deployment
	mission.enemy_force = data.enemy_force
	mission.is_completed = data.is_completed
	mission.is_failed = data.is_failed
	mission.turn_started = data.turn_started
	mission.turn_completed = data.turn_completed
	mission.story_id = data.story_id
	mission.special_rules = data.special_rules
	return mission
