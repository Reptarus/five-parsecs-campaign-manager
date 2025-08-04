@tool
extends Resource
class_name FiveParsecsBattleData

# Enhanced battle data management - Universal framework removed for simplification

# Comprehensive Warning Ignore Coverage
@warning_ignore("unused_signal")

## Base battle data class for managing battle state and configuration
##
## Stores and manages battle-related data including:
	## - Battle configuration
## - Combatant information
## - Battle state
## - Results tracking

# Enhanced Battle Data Signals
signal battle_configured(config: Dictionary)
signal battle_state_changed(old_state: Dictionary, new_state: Dictionary)
signal combatant_added(combatant: Variant, is_player: bool)
signal combatant_removed(combatant: Variant)
signal rewards_updated(rewards: Dictionary)
signal penalties_updated(penalties: Dictionary)

# Battle configuration
var battle_type: int
var difficulty_level: int
var risk_level: int

# Battle state
var is_active: bool = false
var is_completed: bool = false
var is_victory: bool = false

# Combatant tracking
var player_combatants: Array[Variant] = []
var enemy_combatants: Array[Variant] = []

# Results
var rewards: Dictionary = {}
var penalties: Dictionary = {}

# Enhanced battle data tracking
var _battle_statistics: Dictionary = {}
var _validation_enabled: bool = true
var _data_cache: Dictionary = {}

func _init() -> void:
	# Setup enhanced battle data tracking
	_setup_universal_framework()
	_initialize_battle_statistics()

func _setup_universal_framework() -> void:
	# Configure Universal Framework for battle data
	_connect_battle_signals()

func _connect_battle_signals() -> void:
	# Connect internal signals
	if not battle_state_changed.is_connected(_on_battle_state_changed):
		var result1 = battle_state_changed.connect(_on_battle_state_changed)
		if result1 != OK:
			push_error("BaseBattleData: Failed to connect battle_state_changed signal")

	if not combatant_added.is_connected(_on_combatant_added):
		var result2 = combatant_added.connect(_on_combatant_added)
		if result2 != OK:
			push_error("BaseBattleData: Failed to connect combatant_added signal")

func _on_battle_state_changed(old_state: Dictionary, new_state: Dictionary) -> void:
	# Handle battle state changes with Universal framework
	# Note: Using direct dictionary access since UniversalDataAccess is static-only
	pass

func _on_combatant_added(combatant: Variant, is_player: bool) -> void:
	# Handle combatant additions with Universal framework
	# Note: Using direct dictionary access since UniversalDataAccess is static-only
	pass

func _initialize_battle_statistics() -> void:
	# Initialize comprehensive battle statistics
	_battle_statistics = {
		"battle_start_time": 0,
		"battle_end_time": 0,
		"battle_duration": 0,
		"total_combatants": 0,
		"player_combatants_count": 0,
		"enemy_combatants_count": 0,
		"configuration_changes": 0,
		"state_changes": 0,
		"combatant_changes": 0
	}

## Enhanced configuration with Universal framework validation
## @param config: Dictionary containing battle configuration
func configure(config: Dictionary) -> void:
	# Validate configuration
	if _validation_enabled and config.is_empty():
		push_warning("BaseBattleData: Invalid configuration provided")
		return

	var old_config: Dictionary = get_battle_configuration()

	if config.has("battle_type"):
		battle_type = config.battle_type
	if config.has("difficulty_level"):
		difficulty_level = config.difficulty_level
	if config.has("risk_level"):
		risk_level = config.risk_level

	# Update statistics
	_battle_statistics.configuration_changes += 1

	# Emit enhanced signal
	battle_configured.emit(config)

## Enhanced battle start with Universal framework tracking
func start_battle() -> void:
	var old_state: Dictionary = get_battle_state()

	is_active = true
	is_completed = false
	is_victory = false

	# Update statistics
	_battle_statistics.battle_start_time = Time.get_unix_time_from_system()
	_battle_statistics.state_changes += 1

	# Emit enhanced signal
	var new_state: Dictionary = get_battle_state()
	battle_state_changed.emit(old_state, new_state)

## Enhanced battle end with Universal framework tracking
## @param victory: Whether the battle ended in victory
func end_battle(victory: bool = false) -> void:
	var old_state: Dictionary = get_battle_state()

	is_active = false
	is_completed = true
	is_victory = victory

	# Update statistics
	_battle_statistics.battle_end_time = Time.get_unix_time_from_system()
	_battle_statistics.battle_duration = _battle_statistics.battle_end_time - _battle_statistics.battle_start_time
	_battle_statistics.state_changes += 1

	# Emit enhanced signal
	var new_state: Dictionary = get_battle_state()
	battle_state_changed.emit(old_state, new_state)

## Enhanced combatant management with Universal framework validation
## @param combatant: The combatant to add
## @param is_player: Whether the combatant is a player character
func add_combatant(combatant, is_player: bool = true) -> void:
	# Basic validation
	if not combatant:
		push_warning("BaseBattleData: Invalid combatant provided")
		return

	if is_player:
		player_combatants.append(combatant)
		_battle_statistics.player_combatants_count += 1
	else:
		enemy_combatants.append(combatant)
		_battle_statistics.enemy_combatants_count += 1

	# Update total statistics
	_battle_statistics.total_combatants += 1
	_battle_statistics.combatant_changes += 1

	# Log combatant addition
	_data_cache["last_combatant_addition"] = {
		"combatant": combatant,
		"is_player": is_player,
		"total_combatants": _battle_statistics.total_combatants,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	combatant_added.emit(combatant, is_player)

## Enhanced combatant removal with Universal framework tracking
## @param combatant: The combatant to remove
func remove_combatant(combatant: Variant) -> void:
	var was_player: bool = false
	var was_removed: bool = false

	if combatant in player_combatants:
		player_combatants.erase(combatant)
		_battle_statistics.player_combatants_count -= 1
		was_player = true
		was_removed = true
	elif combatant in enemy_combatants:
		enemy_combatants.erase(combatant)
		_battle_statistics.enemy_combatants_count -= 1
		was_removed = true

	if was_removed:
		# Update total statistics
		_battle_statistics.total_combatants -= 1
		_battle_statistics.combatant_changes += 1

		# Log combatant removal
		_data_cache["last_combatant_removal"] = {
			"combatant": combatant,
			"was_player": was_player,
			"total_combatants": _battle_statistics.total_combatants,
			"timestamp": Time.get_unix_time_from_system()
		}

		# Emit enhanced signal
		combatant_removed.emit(combatant)

## Enhanced combatant retrieval with Universal framework validation
## @return: Array of all combatants
func get_all_combatants() -> Array:
	var all_combatants: Array = player_combatants + enemy_combatants

	# Validate result
	if _validation_enabled and all_combatants.is_empty():
		push_warning("BaseBattleData: Invalid combatants array detected")
		return []

	return all_combatants

## Enhanced rewards management with tracking
## @param reward_data: Dictionary of rewards
func set_battle_rewards(reward_data: Dictionary) -> void:
	# Validate rewards
	if _validation_enabled and reward_data.is_empty():
		push_warning("BaseBattleData: Invalid rewards data provided")
		return

	var old_rewards: Dictionary = rewards.duplicate()
	rewards = reward_data.duplicate()

	# Log rewards update
	_data_cache["last_rewards_update"] = {
		"old_rewards": old_rewards,
		"new_rewards": rewards,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	rewards_updated.emit(rewards)

## Enhanced penalties management with tracking
## @param penalty_data: Dictionary of penalties
func set_battle_penalties(penalty_data: Dictionary) -> void:
	# Validate penalties
	if _validation_enabled and penalty_data.is_empty():
		push_warning("BaseBattleData: Invalid penalties data provided")
		return

	var old_penalties: Dictionary = penalties.duplicate()
	penalties = penalty_data.duplicate()

	# Log penalties update
	_data_cache["last_penalties_update"] = {
		"old_penalties": old_penalties,
		"new_penalties": penalties,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Emit enhanced signal
	penalties_updated.emit(penalties)

## Enhanced battle outcome with validation
## @return: Dictionary containing battle outcome information
func get_battle_outcome() -> Dictionary:
	var outcome: Dictionary = {
		"is_completed": is_completed,
		"is_victory": is_victory,
		"rewards": rewards,
		"penalties": penalties,
		"statistics": _battle_statistics
	}

	# Validate outcome
	if _validation_enabled and outcome.is_empty():
		push_warning("BaseBattleData: Invalid battle outcome generated")
		return {}

	return outcome

# Enhanced Universal framework utility methods
func get_battle_configuration() -> Dictionary:
	return {
		"battle_type": battle_type,
		"difficulty_level": difficulty_level,
		"risk_level": risk_level
	}

func get_battle_state() -> Dictionary:
	return {
		"is_active": is_active,
		"is_completed": is_completed,
		"is_victory": is_victory
	}

func get_battle_statistics() -> Dictionary:
	return _battle_statistics.duplicate()

func get_combatant_count(is_player: bool = true) -> int:
	if is_player:
		return player_combatants.size()
	else:
		return enemy_combatants.size()

func get_total_combatant_count() -> int:
	return player_combatants.size() + enemy_combatants.size()

func validate_battle_data() -> bool:
	# Simple validation - check if critical data is valid
	return not player_combatants.is_empty() or not enemy_combatants.is_empty()

func reset_battle_data() -> void:
	# Reset all battle data
	is_active = false
	is_completed = false
	is_victory = false
	player_combatants.clear()
	enemy_combatants.clear()
	rewards.clear()
	penalties.clear()

	# Reset statistics
	_initialize_battle_statistics()

	# Clear data cache
	_data_cache.clear()

func set_validation_enabled(enabled: bool) -> void:
	_validation_enabled = enabled
