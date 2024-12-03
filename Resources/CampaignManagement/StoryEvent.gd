# StoryEvent.gd
class_name StoryEvent
extends Resource

enum MissionType {
    STORY,
    SIDE_QUEST,
    MAIN_QUEST,
    RANDOM_EVENT,
    SPECIAL_EVENT
}

enum HazardType {
    RADIATION,
    TOXIC,
    FIRE,
    ELECTRIC,
    GRAVITY,
    VOID
}

enum VictoryConditionType {
    ELIMINATE_ALL,
    SURVIVE_TIME,
    REACH_OBJECTIVE,
    PROTECT_TARGET,
    COLLECT_ITEMS
}

enum MissionObjective {
    SURVIVE,
    MOVE_THROUGH,
    ACQUIRE,
    DEFEND,
    ESCORT,
    DESTROY,
    CONTROL_POINT,
    RETRIEVE,
    PROTECT,
    ELIMINATE,
    EXPLORE,
    NEGOTIATE,
    RESCUE
}

@export var event_id: String
@export var title: String
@export var description: String
@export var requirements: Dictionary
@export var rewards: Dictionary
@export var next_event_ticks: int
@export var event_type: MissionType = MissionType.STORY

# Story event specific fields based on Core Rules
@export var clock_ticks: int = 0 # For ticking clock events
@export var search_locations: Array[String] = [] # For hidden item searches
@export var spawn_points: Array[Vector2] = [] # For enemy spawn locations
@export var hazards: Array[HazardType] = []
@export var victory_condition: VictoryConditionType
@export var objective: MissionObjective

func _init() -> void:
    requirements = {}
    rewards = {}
    search_locations = []
    spawn_points = []
    hazards = []

func generate_random_event() -> void:
    event_type = MissionType.STORY
    victory_condition = VictoryConditionType.values()[randi() % VictoryConditionType.size()]
    objective = MissionObjective.values()[randi() % MissionObjective.size()]
    
    # Setup appropriate hazards and spawn points based on objective
    match objective:
        MissionObjective.SURVIVE:
            hazards.append(HazardType.values()[randi() % HazardType.size()])
        MissionObjective.MOVE_THROUGH:
            var spawn_count = randi() % 3 + 1 # 1-3 spawn points
            for i in spawn_count:
                spawn_points.append(Vector2(randi() % 24, randi() % 24)) # Random positions on map