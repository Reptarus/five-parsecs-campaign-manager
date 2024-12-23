@tool
class_name Mission
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Core Mission Properties
@export var mission_name: String = ""
@export var mission_type: GameEnums.MissionType = GameEnums.MissionType.GREEN_ZONE
@export var difficulty: GameEnums.DifficultyMode = GameEnums.DifficultyMode.NORMAL
@export var location: String = ""
@export var deployment_type: GameEnums.DeploymentType = GameEnums.DeploymentType.STANDARD
@export var objectives: Array[Dictionary] = []
@export var rewards: Dictionary = {}
@export var enemy_force: Dictionary = {
    "count": 5,
    "composition": [],
    "special_units": []
}

# Mission Configuration
@export var battle_environment: GameEnums.BattleEnvironment = GameEnums.BattleEnvironment.URBAN
@export var deployment_points: Array[Vector2] = []
@export var objective_points: Array[Vector2] = []

# Mission State
var is_completed: bool = false
var is_failed: bool = false
var turn_started: int = -1
var turn_completed: int = -1

# Optional Properties
var patron_id: String = ""  # Reference to patron by ID instead of direct reference
var story_id: String = ""
var special_rules: Array[String] = []  # Array of rule IDs or descriptions

func _init() -> void:
    reset_mission()

func reset_mission() -> void:
    objectives.clear()
    deployment_points.clear()
    objective_points.clear()
    rewards.clear()
    enemy_force = {
        "count": 5,
        "composition": [],
        "special_units": []
    }
    special_rules.clear()
    is_completed = false
    is_failed = false
    turn_started = -1
    turn_completed = -1

func start(current_turn: int) -> void:
    if current_turn < 1:
        push_error("Invalid turn number provided to start mission")
        return
    turn_started = current_turn

func complete(current_turn: int) -> void:
    if current_turn < turn_started:
        push_error("Cannot complete mission: completion turn before start turn")
        return
    is_completed = true
    turn_completed = current_turn

func fail(current_turn: int) -> void:
    if current_turn < turn_started:
        push_error("Cannot fail mission: failure turn before start turn")
        return
    is_failed = true
    turn_completed = current_turn

func is_expired(current_turn: int) -> bool:
    if current_turn < 1:
        push_error("Invalid turn number provided to check mission expiration")
        return false
    # Missions expire after 5 turns if not started
    return turn_started == -1 and current_turn > 5

func add_objective(objective_type: GameEnums.MissionObjective, position: Vector2) -> void:
    if not objective_type in GameEnums.MissionObjective.values():
        push_error("Invalid objective type provided")
        return
        
    objectives.append({
        "type": objective_type,
        "position": position,
        "completed": false,
        "victory_condition": _get_victory_condition_for_objective(objective_type)
    })
    objective_points.append(position)

func get_objective_positions() -> Array[Vector2]:
    return objective_points

func is_all_objectives_completed() -> bool:
    for objective in objectives:
        if not objective.get("completed", false):
            return false
    return true

func get_objective_text() -> String:
    var text: String = ""
    for i in range(objectives.size()):
        var objective: Dictionary = objectives[i]
        var prefix: String = "Primary: " if i == 0 else "Secondary: "
        text += prefix + get_objective_description(objective.get("type", GameEnums.MissionObjective.MOVE_THROUGH)) + "\n"
    return text

func _get_victory_condition_for_objective(objective_type: GameEnums.MissionObjective) -> GameEnums.VictoryConditionType:
    match objective_type:
        GameEnums.MissionObjective.SEEK_AND_DESTROY:
            return GameEnums.VictoryConditionType.ELIMINATION
        GameEnums.MissionObjective.RESCUE, GameEnums.MissionObjective.ESCORT:
            return GameEnums.VictoryConditionType.EXTRACTION
        GameEnums.MissionObjective.DEFEND:
            return GameEnums.VictoryConditionType.SURVIVAL
        GameEnums.MissionObjective.PATROL, GameEnums.MissionObjective.RECON:
            return GameEnums.VictoryConditionType.CONTROL_POINTS
        _:
            return GameEnums.VictoryConditionType.OBJECTIVE

func get_objective_description(objective_type: GameEnums.MissionObjective) -> String:
    match objective_type:
        GameEnums.MissionObjective.PATROL:
            return "Patrol and secure the area"
        GameEnums.MissionObjective.SEEK_AND_DESTROY:
            return "Locate and eliminate all hostiles"
        GameEnums.MissionObjective.RESCUE:
            return "Locate and extract target"
        GameEnums.MissionObjective.DEFEND:
            return "Hold position and protect assets"
        GameEnums.MissionObjective.ESCORT:
            return "Protect and escort target"
        GameEnums.MissionObjective.SABOTAGE:
            return "Destroy enemy assets"
        GameEnums.MissionObjective.RECON:
            return "Gather intelligence and report"
        _:
            return "Unknown objective"

func get_mission_data() -> Dictionary:
    return {
        "name": mission_name,
        "type": mission_type,
        "difficulty": difficulty,
        "location": location,
        "deployment_type": deployment_type,
        "objectives": objectives.duplicate(),
        "rewards": rewards.duplicate(),
        "enemy_force": enemy_force.duplicate(),
        "battle_environment": battle_environment,
        "deployment_points": deployment_points.duplicate(),
        "objective_points": objective_points.duplicate(),
        "special_rules": special_rules.duplicate()
    }

func serialize() -> Dictionary:
    var data: Dictionary = get_mission_data()
    data.merge({
        "is_completed": is_completed,
        "is_failed": is_failed,
        "turn_started": turn_started,
        "turn_completed": turn_completed,
        "patron_id": patron_id,
        "story_id": story_id
    })
    return data

static func deserialize(data: Dictionary) -> Mission:
    var mission := Mission.new()
    
    # Core properties
    mission.mission_name = data.get("name", "")
    mission.mission_type = data.get("type", GameEnums.MissionType.GREEN_ZONE)
    mission.difficulty = data.get("difficulty", GameEnums.DifficultyMode.NORMAL)
    mission.location = data.get("location", "")
    mission.deployment_type = data.get("deployment_type", GameEnums.DeploymentType.STANDARD)
    mission.objectives = data.get("objectives", [])
    mission.rewards = data.get("rewards", {})
    mission.enemy_force = data.get("enemy_force", {"count": 5, "composition": [], "special_units": []})
    mission.battle_environment = data.get("battle_environment", GameEnums.BattleEnvironment.URBAN)
    mission.deployment_points = data.get("deployment_points", [])
    mission.objective_points = data.get("objective_points", [])
    
    # State
    mission.is_completed = data.get("is_completed", false)
    mission.is_failed = data.get("is_failed", false)
    mission.turn_started = data.get("turn_started", -1)
    mission.turn_completed = data.get("turn_completed", -1)
    
    # Optional properties
    mission.patron_id = data.get("patron_id", "")
    mission.story_id = data.get("story_id", "")
    mission.special_rules = data.get("special_rules", [])
    
    return mission 