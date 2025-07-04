extends Resource
class_name BaseBattleData

## Base battle data class for managing battle state and configuration
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

## Configure the battle with the provided settings
## @param config: Dictionary containing battle configuration
func configure(config: Dictionary) -> void:
    if config.has("battle_type"):
        battle_type = config.battle_type
    if config.has("difficulty_level"):
        difficulty_level = config.difficulty_level
    if config.has("risk_level"):
        risk_level = config.risk_level

## Start the battle, resetting state variables
func start_battle() -> void:
    is_active = true
    is_completed = false
    is_victory = false

## End the battle with the specified outcome
## @param victory: Whether the battle ended in victory
func end_battle(victory: bool = false) -> void:
    is_active = false
    is_completed = true
    is_victory = victory

## Add a combatant to the battle
## @param combatant: The combatant to add
## @param is_player: Whether the combatant is a player character
func add_combatant(combatant, is_player: bool = true) -> void:
    if is_player:
        player_combatants.append(combatant) # warning: return value discarded (intentional)
    else:
        enemy_combatants.append(combatant) # warning: return value discarded (intentional)

## Remove a combatant from the battle
## @param combatant: The combatant to remove
func remove_combatant(combatant) -> void:
    player_combatants.erase(combatant)
    enemy_combatants.erase(combatant)

## Get all combatants in the battle
## @return: Array of all combatants
func get_all_combatants() -> Array:
    return player_combatants + enemy_combatants

## Set the rewards for completing the battle
## @param reward_data: Dictionary of rewards
func set_battle_rewards(reward_data: Dictionary) -> void:
    rewards = reward_data.duplicate()

## Set the penalties for failing the battle
## @param penalty_data: Dictionary of penalties
func set_battle_penalties(penalty_data: Dictionary) -> void:
    penalties = penalty_data.duplicate()

## Get the outcome of the battle
## @return: Dictionary containing battle outcome information
func get_battle_outcome() -> Dictionary:
    return {
        "is_completed": is_completed,
        "is_victory": is_victory,
        "rewards": rewards,
        "penalties": penalties
    }
