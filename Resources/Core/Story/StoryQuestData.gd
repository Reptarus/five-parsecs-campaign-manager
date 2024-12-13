class_name StoryQuestData
extends Resource

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const BattleRules = preload("res://Resources/Battle/Core/BattleRules.gd")

# Basic Properties
@export var title: String = ""
@export var description: String = ""
@export var quest_type: GameEnums.QuestType = GameEnums.QuestType.MAIN
@export var difficulty: int = 1
@export var story_point_reward: int = 1

# Story Event Properties
@export var event_type: GameEnums.GlobalEvent = GameEnums.GlobalEvent.NONE
@export var next_event_ticks: int = 0
@export var event_requirements: Dictionary = {}
@export var event_effects: Dictionary = {}

# Quest Properties
@export var objectives: Array = []
@export var rewards: Dictionary = {}
@export var patron: Resource = null  # Will be cast to Patron
@export var special_rules: Array[String] = []

# Battle Properties
@export var battle_type: GameEnums.BattleType = GameEnums.BattleType.STANDARD
@export var enemy_force: Dictionary = {}
@export var terrain_modifiers: Array = []
@export var deployment_rules: Dictionary = {}
@export var victory_conditions: Array = []
@export var special_conditions: Array = []

# State Tracking
var status: GameEnums.QuestStatus = GameEnums.QuestStatus.ACTIVE
var turn_started: int = -1
var turn_completed: int = -1
var objectives_completed: int = 0
var battle_results: Dictionary = {}

# Optional Properties
var story_id: String = ""
var location_requirement: String = ""
var required_reputation: int = 0

func _init() -> void:
    objectives = []
    rewards = {}
    event_requirements = {}
    event_effects = {}
    special_rules = []
    terrain_modifiers = []
    victory_conditions = []
    special_conditions = []
    battle_results = {}
    enemy_force = {
        "units": [],
        "reinforcements": [],
        "commander": null
    }
    deployment_rules = {
        "zones": [],
        "restrictions": [],
        "special_rules": []
    }

# Quest Management
func start(current_turn: int) -> void:
    turn_started = current_turn
    status = GameEnums.QuestStatus.ACTIVE

func complete(current_turn: int) -> void:
    turn_completed = current_turn
    status = GameEnums.QuestStatus.COMPLETED

func fail(current_turn: int) -> void:
    turn_completed = current_turn
    status = GameEnums.QuestStatus.FAILED

func is_expired(current_turn: int) -> bool:
    return turn_started >= 0 and (current_turn - turn_started) > 5

func is_completed() -> bool:
    return status == GameEnums.QuestStatus.COMPLETED

func is_failed() -> bool:
    return status == GameEnums.QuestStatus.FAILED

func is_active() -> bool:
    return status == GameEnums.QuestStatus.ACTIVE

# Objective Management
func add_objective(objective_type: int, description: String, required_progress: int = 1) -> void:
    objectives.append({
        "type": objective_type,
        "description": description,
        "required_progress": required_progress,
        "current_progress": 0,
        "completed": false
    })

func update_objective_progress(index: int, progress: int) -> bool:
    if index < 0 or index >= objectives.size():
        return false
        
    var objective = objectives[index]
    objective.current_progress = min(objective.current_progress + progress, objective.required_progress)
    
    if objective.current_progress >= objective.required_progress and not objective.completed:
        objective.completed = true
        objectives_completed += 1
        
    return objective.completed

func are_all_objectives_complete() -> bool:
    return objectives_completed >= objectives.size()

# Battle Management
func setup_battle(battle_system: Node) -> void:
    if not battle_system:
        push_error("Invalid battle system provided")
        return
    
    # Configure battle settings
    battle_system.battle_type = battle_type
    
    # Setup enemy forces
    _setup_enemy_forces(battle_system)
    
    # Apply terrain modifiers
    _apply_terrain_modifiers(battle_system)
    
    # Set victory conditions
    _setup_victory_conditions(battle_system)
    
    # Apply special conditions
    _apply_special_conditions(battle_system)

func record_battle_result(result: Dictionary) -> void:
    battle_results = result.duplicate()
    
    # Update objectives based on battle result
    _update_battle_objectives(result)
    
    # Check for battle-specific rewards
    _process_battle_rewards(result)

func has_battle_requirement() -> bool:
    return battle_type != GameEnums.BattleType.NONE

func get_deployment_rules() -> Dictionary:
    return deployment_rules

func get_victory_conditions() -> Array[Dictionary]:
    return victory_conditions

# Story Event Management
func apply_effects(game_state: GameState) -> void:
    if not game_state:
        return
        
    for effect_type in event_effects:
        match effect_type:
            "credits":
                game_state.add_credits(event_effects.credits)
            "reputation":
                game_state.add_reputation(event_effects.reputation)
            "resources":
                _apply_resource_effects(game_state, event_effects.resources)
            "relationships":
                _apply_relationship_effects(game_state, event_effects.relationships)
            "battle_modifiers":
                _apply_battle_modifiers(game_state, event_effects.battle_modifiers)

func check_requirements(game_state: GameState) -> bool:
    if not game_state:
        return false
        
    for req_type in event_requirements:
        match req_type:
            "credits":
                if game_state.credits < event_requirements.credits:
                    return false
            "reputation":
                if game_state.reputation < event_requirements.reputation:
                    return false
            "resources":
                if not _check_resource_requirements(game_state, event_requirements.resources):
                    return false
            "relationships":
                if not _check_relationship_requirements(game_state, event_requirements.relationships):
                    return false
            "battle_rating":
                if not _check_battle_rating_requirement(game_state, event_requirements.battle_rating):
                    return false
    
    return true

# Helper Methods
func get_objective_text() -> String:
    var text = ""
    for i in range(objectives.size()):
        var prefix = "Primary: " if i == 0 else "Secondary: "
        text += prefix + objectives[i].description + "\n"
        if objectives[i].required_progress > 1:
            text += "Progress: %d/%d\n" % [objectives[i].current_progress, objectives[i].required_progress]
    return text

func get_reward_text() -> String:
    var text = ""
    if rewards.has("credits"):
        text += "Credits: %d\n" % rewards.credits
    if rewards.has("reputation"):
        text += "Reputation: %d\n" % rewards.reputation
    if rewards.has("story_points"):
        text += "Story Points: %d\n" % rewards.story_points
    if rewards.has("items"):
        text += "Items: %s\n" % rewards.items.join(", ")
    return text

func _setup_enemy_forces(battle_system: Node) -> void:
    for unit_data in enemy_force.units:
        battle_system.add_enemy_unit(unit_data)
    
    if enemy_force.commander:
        battle_system.set_enemy_commander(enemy_force.commander)

func _apply_terrain_modifiers(battle_system: Node) -> void:
    for modifier in terrain_modifiers:
        battle_system.apply_terrain_modifier(modifier)

func _setup_victory_conditions(battle_system: Node) -> void:
    for condition in victory_conditions:
        battle_system.add_victory_condition(condition)

func _apply_special_conditions(battle_system: Node) -> void:
    for condition in special_conditions:
        battle_system.apply_special_condition(condition)

func _update_battle_objectives(result: Dictionary) -> void:
    if result.get("victory", false):
        # Update objectives that require battle victory
        for i in range(objectives.size()):
            var objective = objectives[i]
            if objective.type == GameEnums.MissionObjective.WIN_BATTLE:
                update_objective_progress(i, 1)

func _process_battle_rewards(result: Dictionary) -> void:
    if result.get("victory", false):
        # Add battle-specific rewards
        if not rewards.has("credits"):
            rewards.credits = 0
        rewards.credits += result.get("bonus_credits", 0)
        
        if not rewards.has("reputation"):
            rewards.reputation = 0
        rewards.reputation += result.get("bonus_reputation", 0)

func _apply_resource_effects(game_state: GameState, effects: Dictionary) -> void:
    for resource_type in effects:
        game_state.modify_resource(resource_type, effects[resource_type])

func _apply_relationship_effects(game_state: GameState, effects: Dictionary) -> void:
    for faction_id in effects:
        game_state.modify_faction_relationship(faction_id, effects[faction_id])

func _apply_battle_modifiers(game_state: GameState, modifiers: Dictionary) -> void:
    for modifier_type in modifiers:
        game_state.apply_battle_modifier(modifier_type, modifiers[modifier_type])

func _check_resource_requirements(game_state: GameState, requirements: Dictionary) -> bool:
    for resource_type in requirements:
        if not game_state.has_sufficient_resource(resource_type, requirements[resource_type]):
            return false
    return true

func _check_relationship_requirements(game_state: GameState, requirements: Dictionary) -> bool:
    for faction_id in requirements:
        if not game_state.has_sufficient_relationship(faction_id, requirements[faction_id]):
            return false
    return true

func _check_battle_rating_requirement(game_state: GameState, required_rating: int) -> bool:
    return game_state.get_battle_rating() >= required_rating

# Serialization
func serialize() -> Dictionary:
    return {
        "title": title,
        "description": description,
        "quest_type": GameEnums.QuestType.keys()[quest_type],
        "difficulty": difficulty,
        "story_point_reward": story_point_reward,
        "event_type": event_type,
        "next_event_ticks": next_event_ticks,
        "event_requirements": event_requirements,
        "event_effects": event_effects,
        "objectives": objectives,
        "rewards": rewards,
        "patron": patron.serialize() if patron else null,
        "special_rules": special_rules,
        "battle_type": battle_type,
        "enemy_force": enemy_force,
        "terrain_modifiers": terrain_modifiers,
        "deployment_rules": deployment_rules,
        "victory_conditions": victory_conditions,
        "special_conditions": special_conditions,
        "status": GameEnums.QuestStatus.keys()[status],
        "turn_started": turn_started,
        "turn_completed": turn_completed,
        "objectives_completed": objectives_completed,
        "battle_results": battle_results,
        "story_id": story_id,
        "location_requirement": location_requirement,
        "required_reputation": required_reputation
    }

func deserialize(data: Dictionary) -> void:
    title = data.get("title", "")
    description = data.get("description", "")
    quest_type = GameEnums.QuestType[data.quest_type] if data.has("quest_type") else GameEnums.QuestType.MAIN
    difficulty = data.get("difficulty", 1)
    story_point_reward = data.get("story_point_reward", 1)
    event_type = data.get("event_type", -1)
    next_event_ticks = data.get("next_event_ticks", 0)
    event_requirements = data.get("event_requirements", {})
    event_effects = data.get("event_effects", {})
    objectives = data.get("objectives", [])
    rewards = data.get("rewards", {})
    
    if data.has("patron") and data.patron:
        patron = load("res://Resources/Campaign/Relations/Patron.gd").new()
        patron.deserialize(data.patron)
    
    special_rules = data.get("special_rules", [])
    battle_type = data.get("battle_type", GameEnums.BattleType.NONE)
    enemy_force = data.get("enemy_force", {})
    terrain_modifiers = data.get("terrain_modifiers", [])
    deployment_rules = data.get("deployment_rules", {})
    victory_conditions = data.get("victory_conditions", [])
    special_conditions = data.get("special_conditions", [])
    status = GameEnums.QuestStatus[data.status] if data.has("status") else GameEnums.QuestStatus.ACTIVE
    turn_started = data.get("turn_started", -1)
    turn_completed = data.get("turn_completed", -1)
    objectives_completed = data.get("objectives_completed", 0)
    battle_results = data.get("battle_results", {})
    story_id = data.get("story_id", "")
    location_requirement = data.get("location_requirement", "")
    required_reputation = data.get("required_reputation", 0) 