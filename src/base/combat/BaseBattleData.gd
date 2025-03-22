@tool
extends Resource
class_name BaseBattleData

## Base class for battle data
##
## Provides core functionality for tracking battle state and outcome
## across different implementations and game systems

# Basic battle properties
var battle_id: String = ""
var battle_type: int = 0
var battle_difficulty: int = 0
var battle_started: bool = false
var battle_ended: bool = false
var victory: bool = false

# Combatant tracking
var player_combatants: Array = []
var enemy_combatants: Array = []

## Initialize the battle data
func _init() -> void:
	battle_id = "battle_" + str(Time.get_unix_time_from_system())

## Configure the battle with basic properties
## @param config: Dictionary containing battle configuration
func configure(config: Dictionary) -> void:
	if config.has("battle_id"):
		battle_id = config.battle_id
	if config.has("battle_type"):
		battle_type = config.battle_type
	if config.has("battle_difficulty"):
		battle_difficulty = config.battle_difficulty

## Start the battle
func start_battle() -> void:
	battle_started = true
	battle_ended = false
	victory = false

## End the battle
## @param victory: Whether the battle was won
func end_battle(battle_victory: bool = false) -> void:
	battle_ended = true
	victory = battle_victory

## Add a combatant to the battle
## @param combatant: The combatant to add
## @param is_player: Whether the combatant is a player character
func add_combatant(combatant, is_player: bool = true) -> void:
	if is_player:
		player_combatants.append(combatant)
	else:
		enemy_combatants.append(combatant)

## Remove a combatant from the battle
## @param combatant: The combatant to remove
func remove_combatant(combatant) -> void:
	var player_index = player_combatants.find(combatant)
	if player_index >= 0:
		player_combatants.remove_at(player_index)
		return
		
	var enemy_index = enemy_combatants.find(combatant)
	if enemy_index >= 0:
		enemy_combatants.remove_at(enemy_index)

## Get the battle outcome
## @return: Dictionary with battle outcome data
func get_battle_outcome() -> Dictionary:
	return {
		"victory": victory,
		"player_combatants": player_combatants.size(),
		"enemy_combatants": enemy_combatants.size(),
		"battle_type": battle_type,
		"battle_difficulty": battle_difficulty
	}

## Check if the battle is active
## @return: Whether the battle is active
func is_battle_active() -> bool:
	return battle_started and not battle_ended

## Get the battle difficulty level
## @return: Battle difficulty level
func get_difficulty() -> int:
	return battle_difficulty

## Set the battle difficulty level
## @param difficulty: New difficulty level
func set_difficulty(difficulty: int) -> void:
	battle_difficulty = difficulty
