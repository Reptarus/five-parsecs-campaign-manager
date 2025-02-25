@tool
extends Resource
class_name FiveParsecsBattleData

## Core battle data class for managing battle state and configuration
##
## Stores and manages battle-related data including:
## - Battle configuration
## - Combatant information
## - Battle state
## - Results tracking

# Battle configuration
var battle_type: int
var difficulty_level: int
var risk_level: int

# Battle state
var is_active: bool = false
var is_completed: bool = false
var is_victory: bool = false

# Combatant tracking
var player_combatants: Array = []
var enemy_combatants: Array = []

# Results
var rewards: Dictionary = {}
var penalties: Dictionary = {}

func _init() -> void:
    pass

func configure(config: Dictionary) -> void:
    if config.has("battle_type"):
        battle_type = config.battle_type
    if config.has("difficulty_level"):
        difficulty_level = config.difficulty_level
    if config.has("risk_level"):
        risk_level = config.risk_level

func start_battle() -> void:
    is_active = true
    is_completed = false
    is_victory = false

func end_battle(victory: bool = false) -> void:
    is_active = false
    is_completed = true
    is_victory = victory

func add_combatant(combatant: Node, is_player: bool = true) -> void:
    if is_player:
        player_combatants.append(combatant)
    else:
        enemy_combatants.append(combatant)

func remove_combatant(combatant: Node) -> void:
    player_combatants.erase(combatant)
    enemy_combatants.erase(combatant)

func get_all_combatants() -> Array:
    return player_combatants + enemy_combatants

func set_battle_rewards(reward_data: Dictionary) -> void:
    rewards = reward_data.duplicate()

func set_battle_penalties(penalty_data: Dictionary) -> void:
    penalties = penalty_data.duplicate()

func get_battle_outcome() -> Dictionary:
    return {
        "is_completed": is_completed,
        "is_victory": is_victory,
        "rewards": rewards,
        "penalties": penalties
    }