class_name FiveParsecsGameState
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

signal resource_changed(type: int, old_value: int, new_value: int)
signal credits_changed(old_value: int, new_value: int)
signal phase_changed(old_phase: int, new_phase: int)
signal story_points_changed(old_value: int, new_value: int)
signal mission_added(mission: Dictionary)
signal mission_completed(mission: Dictionary)
signal faction_standing_changed(faction: String, old_value: float, new_value: float)
signal state_validated(is_valid: bool, issues: Array)
signal state_recovered(success: bool, recovery_info: Dictionary)

# Campaign State
var campaign_turns: int = 0:
    set(value):
        var old_value = campaign_turns
        campaign_turns = value
        _validate_campaign_turns()

var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP:
    set(value):
        var old_phase = current_phase
        current_phase = value
        phase_changed.emit(old_phase, value)

var story_points: int = 0:
    set(value):
        var old_value = story_points
        story_points = value
        story_points_changed.emit(old_value, value)

var patrons: Array = []
var rivals: Array = []
var available_missions: Array = []
var completed_missions: Array = []
var ship_hull_points: int = 10
var current_travel_destination: String = ""

# Resources
var credits: int = 1000:
    set(value):
        var old_value = credits
        credits = value
        credits_changed.emit(old_value, value)
        _validate_credits()

var resources: Dictionary = {}

# Crew Management
var current_crew = null # Will be set by CharacterManager
var faction_standings: Dictionary = {}

# Campaign Settings
var difficulty_level: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
var has_red_zone_license: bool = false

# State validation
var _validation_rules: Array[Callable] = []
var _recovery_handlers: Dictionary = {}
var _state_metadata: Dictionary = {}

# Constants
const MAX_CREDITS = 1000000
const MIN_CREDITS = 0
const MAX_STORY_POINTS = 100
const MIN_STORY_POINTS = 0
const MAX_SHIP_HULL_POINTS = 20
const MIN_SHIP_HULL_POINTS = 0
const MAX_RESOURCE_VALUE = 9999

func _init() -> void:
    _setup_initial_resources()
    _setup_validation_rules()
    _setup_recovery_handlers()

func _setup_initial_resources() -> void:
    resources = {
        GameEnums.ResourceType.FUEL: 100,
        GameEnums.ResourceType.SUPPLIES: 50,
        GameEnums.ResourceType.MEDICAL_SUPPLIES: 25,
        GameEnums.ResourceType.WEAPONS: 10,
        GameEnums.ResourceType.STORY_POINT: 0
    }

func _setup_validation_rules() -> void:
    _validation_rules = [
        _validate_credits,
        _validate_resources,
        _validate_campaign_turns,
        _validate_story_points,
        _validate_ship_hull_points,
        _validate_missions,
        _validate_faction_standings
    ]

func _setup_recovery_handlers() -> void:
    _recovery_handlers = {
        "invalid_credits": _recover_credits,
        "invalid_resources": _recover_resources,
        "invalid_campaign_turns": _recover_campaign_turns,
        "invalid_story_points": _recover_story_points,
        "invalid_ship_hull": _recover_ship_hull,
        "invalid_mission": _recover_mission,
        "invalid_faction": _recover_faction_standing
    }

# Enhanced resource management
func get_resource(type: GameEnums.ResourceType) -> int:
    return resources.get(type, 0)

func set_resource(type: GameEnums.ResourceType, amount: int) -> void:
    var old_value = get_resource(type)
    amount = clampi(amount, 0, MAX_RESOURCE_VALUE)
    resources[type] = amount
    resource_changed.emit(type, old_value, amount)
    _validate_resources()

func add_resource(type: GameEnums.ResourceType, amount: int) -> void:
    var current = get_resource(type)
    set_resource(type, current + amount)

func remove_resource(type: GameEnums.ResourceType, amount: int) -> bool:
    var current = get_resource(type)
    if current >= amount:
        set_resource(type, current - amount)
        return true
    return false

func has_enough_resource(type: GameEnums.ResourceType, amount: int) -> bool:
    return get_resource(type) >= amount

# Mission management
func add_available_mission(mission: Dictionary) -> void:
    if _validate_mission(mission):
        available_missions.append(mission)
        mission_added.emit(mission)

func complete_mission(mission: Dictionary) -> void:
    if mission in available_missions:
        available_missions.erase(mission)
        completed_missions.append(mission)
        mission_completed.emit(mission)

# Faction management
func set_faction_standing(faction: String, value: float) -> void:
    var old_value = faction_standings.get(faction, 0.0)
    value = clampf(value, -100.0, 100.0)
    faction_standings[faction] = value
    faction_standing_changed.emit(faction, old_value, value)

# Validation methods
func _validate_credits() -> Dictionary:
    if credits < MIN_CREDITS or credits > MAX_CREDITS:
        return {
            "valid": false,
            "type": "invalid_credits",
            "value": credits,
            "reason": "Credits must be between %d and %d" % [MIN_CREDITS, MAX_CREDITS]
        }
    return {"valid": true}

func _validate_resources() -> Dictionary:
    var issues = []
    for type in resources:
        var value = resources[type]
        if value < 0 or value > MAX_RESOURCE_VALUE:
            issues.append({
                "type": "invalid_resources",
                "resource_type": type,
                "value": value,
                "reason": "Resource value must be between 0 and %d" % MAX_RESOURCE_VALUE
            })
    return {"valid": issues.is_empty(), "issues": issues}

func _validate_campaign_turns() -> Dictionary:
    if campaign_turns < 0:
        return {
            "valid": false,
            "type": "invalid_campaign_turns",
            "value": campaign_turns,
            "reason": "Campaign turns cannot be negative"
        }
    return {"valid": true}

func _validate_story_points() -> Dictionary:
    if story_points < MIN_STORY_POINTS or story_points > MAX_STORY_POINTS:
        return {
            "valid": false,
            "type": "invalid_story_points",
            "value": story_points,
            "reason": "Story points must be between %d and %d" % [MIN_STORY_POINTS, MAX_STORY_POINTS]
        }
    return {"valid": true}

func _validate_ship_hull_points() -> Dictionary:
    if ship_hull_points < MIN_SHIP_HULL_POINTS or ship_hull_points > MAX_SHIP_HULL_POINTS:
        return {
            "valid": false,
            "type": "invalid_ship_hull",
            "value": ship_hull_points,
            "reason": "Ship hull points must be between %d and %d" % [MIN_SHIP_HULL_POINTS, MAX_SHIP_HULL_POINTS]
        }
    return {"valid": true}

func _validate_mission(mission: Dictionary) -> bool:
    return mission.has_all(["id", "type", "difficulty", "rewards"])

func _validate_missions() -> Dictionary:
    var issues = []
    for mission in available_missions:
        if not _validate_mission(mission):
            issues.append({
                "type": "invalid_mission",
                "mission": mission,
                "reason": "Mission missing required fields"
            })
    return {"valid": issues.is_empty(), "issues": issues}

func _validate_faction_standings() -> Dictionary:
    var issues = []
    for faction in faction_standings:
        var standing = faction_standings[faction]
        if standing < -100.0 or standing > 100.0:
            issues.append({
                "type": "invalid_faction",
                "faction": faction,
                "value": standing,
                "reason": "Faction standing must be between -100 and 100"
            })
    return {"valid": issues.is_empty(), "issues": issues}

# Recovery methods
func _recover_credits(issue: Dictionary) -> Dictionary:
    credits = clampi(issue.value, MIN_CREDITS, MAX_CREDITS)
    return {"success": true, "action": "clamped_credits"}

func _recover_resources(issue: Dictionary) -> Dictionary:
    var resource_type = issue.resource_type
    var value = issue.value
    resources[resource_type] = clampi(value, 0, MAX_RESOURCE_VALUE)
    return {"success": true, "action": "clamped_resource"}

func _recover_campaign_turns(issue: Dictionary) -> Dictionary:
    campaign_turns = maxi(0, issue.value)
    return {"success": true, "action": "fixed_campaign_turns"}

func _recover_story_points(issue: Dictionary) -> Dictionary:
    story_points = clampi(issue.value, MIN_STORY_POINTS, MAX_STORY_POINTS)
    return {"success": true, "action": "clamped_story_points"}

func _recover_ship_hull(issue: Dictionary) -> Dictionary:
    ship_hull_points = clampi(issue.value, MIN_SHIP_HULL_POINTS, MAX_SHIP_HULL_POINTS)
    return {"success": true, "action": "clamped_ship_hull"}

func _recover_mission(issue: Dictionary) -> Dictionary:
    var mission = issue.mission
    available_missions.erase(mission)
    return {"success": true, "action": "removed_invalid_mission"}

func _recover_faction_standing(issue: Dictionary) -> Dictionary:
    var faction = issue.faction
    var value = issue.value
    faction_standings[faction] = clampf(value, -100.0, 100.0)
    return {"success": true, "action": "clamped_faction_standing"}

# State validation and recovery
func validate_state() -> Dictionary:
    var issues = []
    var is_valid = true
    
    for rule in _validation_rules:
        var result = rule.call()
        if not result.valid:
            is_valid = false
            issues.append(result)
    
    state_validated.emit(is_valid, issues)
    return {"is_valid": is_valid, "issues": issues}

func attempt_recovery(issues: Array) -> Dictionary:
    var recovery_attempts = []
    var success = true
    
    for issue in issues:
        if _recovery_handlers.has(issue.type):
            var result = _recovery_handlers[issue.type].call(issue)
            recovery_attempts.append(result)
            if not result.success:
                success = false
    
    state_recovered.emit(success, {"attempts": recovery_attempts})
    return {"success": success, "attempts": recovery_attempts}

# Serialization
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
        "difficulty_level": difficulty_level,
        "has_red_zone_license": has_red_zone_license,
        "metadata": _state_metadata
    }

func deserialize(data: Dictionary) -> void:
    # Store old values for validation
    var old_state = serialize()
    
    # Apply new values
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
    difficulty_level = data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
    has_red_zone_license = data.get("has_red_zone_license", false)
    _state_metadata = data.get("metadata", {})
    
    # Validate new state
    var validation_result = validate_state()
    if not validation_result.is_valid:
        # Attempt recovery
        var recovery_result = attempt_recovery(validation_result.issues)
        if not recovery_result.success:
            # Restore old state if recovery failed
            deserialize(old_state)