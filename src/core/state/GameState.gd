class_name FiveParsecsGameState
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Campaign State
var campaign_turns: int = 0
var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
var story_points: int = 0
var patrons: Array = []
var rivals: Array = []
var available_missions: Array = []
var completed_missions: Array = []
var ship_hull_points: int = 10
var current_travel_destination: String = ""

# Resources
var credits: int = 1000
var resources: Dictionary = {}

# Crew Management
var current_crew = null  # Will be set by CharacterManager
var faction_standings: Dictionary = {}

# Campaign Settings
var difficulty_mode: GameEnums.DifficultyMode = GameEnums.DifficultyMode.NORMAL
var has_red_zone_license: bool = false

func _init() -> void:
    resources = {
        GameEnums.ResourceType.FUEL: 100,
        GameEnums.ResourceType.SUPPLIES: 50,
        GameEnums.ResourceType.MEDICAL_SUPPLIES: 25,
        GameEnums.ResourceType.WEAPONS: 10,
        GameEnums.ResourceType.STORY_POINT: 0
    }

func serialize() -> Dictionary:
    return {
        "campaign_turns": campaign_turns,
        "current_phase": current_phase,
        "story_points": story_points,
        "patrons": patrons,
        "rivals": rivals,
        "available_missions": available_missions,
        "completed_missions": completed_missions,
        "ship_hull_points": ship_hull_points,
        "current_travel_destination": current_travel_destination,
        "credits": credits,
        "resources": resources,
        "faction_standings": faction_standings,
        "difficulty_mode": difficulty_mode,
        "has_red_zone_license": has_red_zone_license
    }

func deserialize(data: Dictionary) -> void:
    campaign_turns = data.get("campaign_turns", 0)
    current_phase = data.get("current_phase", GameEnums.CampaignPhase.SETUP)
    story_points = data.get("story_points", 0)
    patrons = data.get("patrons", [])
    rivals = data.get("rivals", [])
    available_missions = data.get("available_missions", [])
    completed_missions = data.get("completed_missions", [])
    ship_hull_points = data.get("ship_hull_points", 10)
    current_travel_destination = data.get("current_travel_destination", "")
    credits = data.get("credits", 1000)
    resources = data.get("resources", {})
    faction_standings = data.get("faction_standings", {})
    difficulty_mode = data.get("difficulty_mode", GameEnums.DifficultyMode.NORMAL)
    has_red_zone_license = data.get("has_red_zone_license", false)

func get_resource(type: GameEnums.ResourceType) -> int:
    return resources.get(type, 0)

func set_resource(type: GameEnums.ResourceType, amount: int) -> void:
    resources[type] = amount

func add_resource(type: GameEnums.ResourceType, amount: int) -> void:
    resources[type] = get_resource(type) + amount

func remove_resource(type: GameEnums.ResourceType, amount: int) -> bool:
    var current = get_resource(type)
    if current >= amount:
        resources[type] = current - amount
        return true
    return false

func has_enough_resource(type: GameEnums.ResourceType, amount: int) -> bool:
    return get_resource(type) >= amount 