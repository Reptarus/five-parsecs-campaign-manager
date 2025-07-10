class_name AlphaGameManager
extends Node

## Alpha Game Manager for Five Parsecs Campaign Manager
## Optimized central coordinator for all core systems
## 
## Features:
## - Type-safe manager references
## - Efficient resource loading with caching
## - Robust error handling and recovery
## - Performance-optimized initialization

# Optimized dependency loading with preload pattern
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Performance optimization: Cache loaded scripts
static var _script_cache: Dictionary = {}
var _autoload_cache: Dictionary = {}  # Non-static since we're using instance methods

# System references
var game_state_manager: Node = null  # GameStateManagerAutoload when available
var campaign_creation_manager: CampaignCreationManager = null
var campaign_phase_manager: Node = null  # CampaignPhaseManager when available
var battle_results_manager: Node = null  # BattleResultsManager when available
var dice_manager: Node = null  # DiceManager when available

# Core state
var is_initialized: bool = false
var initialization_errors: Array[String] = []
var systems_ready: Dictionary = {}

# Type-safe signals
signal systems_initialized(success: bool, errors: Array[String])
signal game_state_ready(game_state: Node)  # GameStateManagerAutoload when available
signal campaign_creation_ready(manager: CampaignCreationManager)
signal system_error(system_name: String, error_message: String)
signal all_systems_ready()
signal manager_ready(manager_name: String, manager_instance: Node)

# Performance tracking
var _initialization_start_time: int = 0
var _system_load_times: Dictionary = {}

func _init() -> void:
	name = "AlphaGameManager"
	_initialization_start_time = Time.get_ticks_msec()
	print("AlphaGameManager: Initializing (Performance tracking enabled)...")

func _ready() -> void:
	# Defer initialization to next frame to ensure all autoloads are ready
	call_deferred("initialize_systems")

func initialize_systems() -> void:
	# Initialize all core systems in proper order with performance tracking
	print("AlphaGameManager: Starting optimized system initialization...")
	initialization_errors.clear()
	systems_ready.clear()
	_system_load_times.clear()

	# Step 1: Initialize GameStateManager first (it's the foundation)
	_initialize_manager("GameStateManager", _initialize_game_state_manager)

	# Step 2: Initialize other managers that depend on GameState
	_initialize_manager("CampaignCreationManager", _initialize_campaign_creation_manager)
	_initialize_manager("CampaignPhaseManager", _initialize_campaign_phase_manager)
	_initialize_manager("BattleResultsManager", _initialize_battle_results_manager)
	_initialize_manager("DiceManager", _initialize_dice_manager)

	# Step 3: Check if all systems are ready
	_finalize_initialization()

## Optimized manager initialization wrapper with performance tracking
func _initialize_manager(manager_name: String, init_function: Callable) -> void:
	var start_time = Time.get_ticks_msec()
	print("AlphaGameManager: Initializing %s..." % manager_name)
	
	init_function.call()
	
	var load_time = Time.get_ticks_msec() - start_time
	_system_load_times[manager_name] = load_time
	print("AlphaGameManager: %s loaded in %d ms" % [manager_name, load_time])

## Optimized script loader with caching
static func _load_script_cached(script_path: String) -> Script:
	if script_path in _script_cache:
		return _script_cache[script_path]
	
	if not FileAccess.file_exists(script_path):
		push_error("AlphaGameManager: Script not found: " + script_path)
		return null
	
	var script = load(script_path) as Script
	if script:
		_script_cache[script_path] = script
	
	return script

## Optimized autoload getter with caching (non-static for Node access)
func _get_autoload_cached(autoload_path: String) -> Node:
	if autoload_path in _autoload_cache:
		var cached_node = _autoload_cache[autoload_path]
		if is_instance_valid(cached_node):
			return cached_node
		else:
			_autoload_cache.erase(autoload_path)
	
	# Use Node's built-in get_tree() method for cleaner access
	var node = get_tree().root.get_node_or_null(autoload_path)
	if node:
		_autoload_cache[autoload_path] = node
	
	return node

## Generic optimized manager creation pattern
func _create_manager_instance(script_path: String, manager_name: String, setup_dependencies: Array = []) -> Node:
	var script = _load_script_cached(script_path)
	if not script:
		var error = "Failed to load %s script from: %s" % [manager_name, script_path]
		initialization_errors.append(error)
		system_error.emit(manager_name, error)
		systems_ready[manager_name] = false
		return null
	
	var instance = script.new()
	if not instance:
		var error = "Failed to instantiate %s - constructor failed" % manager_name
		initialization_errors.append(error)
		system_error.emit(manager_name, error)
		systems_ready[manager_name] = false
		return null
	
	instance.name = manager_name
	add_child(instance)
	
	# Setup dependencies if available
	if instance.has_method("setup") and setup_dependencies.size() > 0:
		instance.callv("setup", setup_dependencies)
		print("AlphaGameManager: %s setup completed with dependencies" % manager_name)
	
	systems_ready[manager_name] = true
	manager_ready.emit(manager_name, instance)
	return instance

func _initialize_game_state_manager() -> void:
	# Optimized GameStateManager initialization
	game_state_manager = _get_autoload_cached("/root/GameStateManagerAutoload")

	if not game_state_manager:
		# Create new GameStateManager if not found
		game_state_manager = _create_manager_instance(
			"res://src/core/managers/GameStateManager.gd", 
			"GameStateManager"
		)
		if not game_state_manager:
			return

	# Initialize the GameStateManager
	if game_state_manager.has_method("initialize_game_state"):
		game_state_manager.initialize_game_state()

	systems_ready["GameStateManager"] = true
	game_state_ready.emit(game_state_manager)

func _initialize_campaign_creation_manager() -> void:
	# Optimized CampaignCreationManager initialization
	if not game_state_manager:
		var error = "Cannot initialize CampaignCreationManager: GameStateManager not available"
		initialization_errors.append(error)
		system_error.emit("CampaignCreationManager", error)
		systems_ready["CampaignCreationManager"] = false
		return

	var game_state = game_state_manager.get_game_state() if game_state_manager.has_method("get_game_state") else null
	var dependencies = [game_state] if game_state else []
	
	campaign_creation_manager = _create_manager_instance(
		"res://src/core/campaign/CampaignCreationManager.gd",
		"CampaignCreationManager",
		dependencies
	) as CampaignCreationManager
	
	if campaign_creation_manager:
		campaign_creation_ready.emit(campaign_creation_manager)

func _initialize_campaign_phase_manager() -> void:
	# Optimized CampaignPhaseManager initialization
	if not game_state_manager:
		var error = "Cannot initialize CampaignPhaseManager: GameStateManager not available"
		initialization_errors.append(error)
		system_error.emit("CampaignPhaseManager", error)
		systems_ready["CampaignPhaseManager"] = false
		return

	var game_state = game_state_manager.get_game_state() if game_state_manager.has_method("get_game_state") else null
	var dependencies = [game_state] if game_state else []
	
	campaign_phase_manager = _create_manager_instance(
		"res://src/core/campaign/CampaignPhaseManager.gd",
		"CampaignPhaseManager",
		dependencies
	)

func _initialize_battle_results_manager() -> void:
	# Optimized BattleResultsManager initialization
	if not game_state_manager:
		var error = "Cannot initialize BattleResultsManager: GameStateManager not available"
		initialization_errors.append(error)
		system_error.emit("BattleResultsManager", error)
		systems_ready["BattleResultsManager"] = false
		return

	var game_state = game_state_manager.get_game_state() if game_state_manager.has_method("get_game_state") else null
	var dependencies = [game_state, null] if game_state else []  # null placeholder for CharacterManager
	
	battle_results_manager = _create_manager_instance(
		"res://src/core/campaign/phases/PostBattlePhase.gd",
		"BattleResultsManager",
		dependencies
	)

func _initialize_dice_manager() -> void:
	# Optimized DiceManager initialization
	dice_manager = _get_autoload_cached("/root/DiceManager")

	if not dice_manager:
		# Try to create a simple DiceManager wrapper if needed
		var dice_script = _load_script_cached("res://src/core/systems/DiceSystem.gd")
		if dice_script:
			# Create a basic node wrapper for the dice system
			dice_manager = Node.new()
			dice_manager.name = "DiceManager"
			add_child(dice_manager)
		if not dice_manager:
			return

	systems_ready["DiceManager"] = true

func _finalize_initialization() -> void:
	# Finalize the initialization process with performance reporting
	var all_ready: bool = true
	var ready_count: int = 0
	var total_count = systems_ready.size()

	for system_name in systems_ready:
		if systems_ready[system_name]:
			ready_count += 1
		else:
			all_ready = false
			push_error("AlphaGameManager: System '" + str(system_name) + "' failed to initialize")

	is_initialized = all_ready
	
	# Performance reporting
	var total_init_time = Time.get_ticks_msec() - _initialization_start_time
	print("AlphaGameManager: Initialization complete - %d/%d systems ready in %d ms" % [ready_count, total_count, total_init_time])
	
	# Detailed performance breakdown
	print("AlphaGameManager: Performance breakdown:")
	for system_name in _system_load_times:
		print("  - %s: %d ms" % [system_name, _system_load_times[system_name]])

	if initialization_errors.size() > 0:
		print("AlphaGameManager: Initialization errors:")
		for error in initialization_errors:
			print("  - " + error)

	systems_initialized.emit(is_initialized, initialization_errors)

	if is_initialized:
		all_systems_ready.emit()
		print("AlphaGameManager: All systems ready! Total startup time: %d ms" % total_init_time)
	else:
		push_error("AlphaGameManager: System initialization failed")

# Type-safe Public API methods
func get_game_state_manager() -> Node:
	# Get the GameStateManager instance (GameStateManagerAutoload when available)
	return game_state_manager

func get_campaign_creation_manager() -> CampaignCreationManager:
	# Get the CampaignCreationManager instance
	return campaign_creation_manager

func get_campaign_phase_manager() -> Node:
	# Get the CampaignPhaseManager instance (CampaignPhaseManager when available)
	return campaign_phase_manager

func get_battle_results_manager() -> Node:
	# Get the BattleResultsManager instance (BattleResultsManager when available)
	return battle_results_manager

func get_dice_manager() -> Node:
	# Get the DiceManager instance (DiceManager when available)
	return dice_manager

func get_battle_manager() -> Node:
	# Get the battle manager instance for tactical combat
	if battle_results_manager:
		return battle_results_manager

	# Try to find or create a battle manager if not available
	var battle_manager: Node = get_node_or_null("/root/BattleManager")
	if not battle_manager:
		# Check if we have a FiveParsecsCombatManager registered
		if game_state_manager and game_state_manager.has_method("get_manager"):
			battle_manager = game_state_manager.get_manager("FiveParsecsCombatManager")

	return battle_manager

func is_system_ready(system_name: String) -> bool:
	# Check if a specific system is ready
	return systems_ready.get(system_name, false)

func get_system_status() -> Dictionary:
	# Get comprehensive system status with performance metrics
	var total_init_time = Time.get_ticks_msec() - _initialization_start_time if _initialization_start_time > 0 else 0
	return {
		"initialized": is_initialized,
		"systems_ready": systems_ready.duplicate(),
		"errors": initialization_errors.duplicate(),
		"performance": {
			"total_init_time_ms": total_init_time,
			"system_load_times": _system_load_times.duplicate(),
			"cache_hits": _script_cache.size(),
			"autoload_cache_size": _autoload_cache.size()
		},
		"memory": {
			"manager_count": get_children().size(),
			"error_count": initialization_errors.size()
		}
	}

## Get detailed performance report  
func get_performance_report() -> String:
	var report = "AlphaGameManager Performance Report:\\n"
	report += "=====================================\\n"
	
	var total_time = Time.get_ticks_msec() - _initialization_start_time if _initialization_start_time > 0 else 0
	report += "Total initialization time: %d ms\\n" % total_time
	report += "Script cache entries: %d\\n" % _script_cache.size()
	report += "Autoload cache entries: %d\\n" % _autoload_cache.size()
	report += "\\nSystem Load Times:\\n"
	
	for system_name in _system_load_times:
		var load_time = _system_load_times[system_name]
		var percentage = (load_time * 100.0 / total_time) if total_time > 0 else 0
		report += "  %s: %d ms (%.1f%%)\\n" % [system_name, load_time, percentage]
	
	report += "\\nCached Scripts:\\n"
	for script_path in _script_cache:
		report += "  %s\\n" % script_path
		
	return report

## Clear performance caches (useful for testing)
static func clear_caches() -> void:
	_script_cache.clear()
	print("AlphaGameManager: Script cache cleared")

## Clear autoload cache (instance method)
func clear_autoload_cache() -> void:
	_autoload_cache.clear()
	print("AlphaGameManager: Autoload cache cleared")

func start_new_campaign(config: Dictionary = {}) -> bool:
	# Start a new campaign with the given configuration
	if not is_initialized:
		push_error("AlphaGameManager: Cannot start campaign - systems not initialized")
		return false

	if not game_state_manager or not game_state_manager.has_method("start_new_campaign"):
		push_error("AlphaGameManager: Cannot start campaign - GameStateManager not available")
		return false

	print("AlphaGameManager: Starting new campaign...")
	return game_state_manager.start_new_campaign(config)

func get_current_phase() -> int:
	# Get the current campaign phase
	if campaign_phase_manager and campaign_phase_manager.has_method("get_current_phase"):
		return campaign_phase_manager.get_current_phase()

	# Safe enum access
	if GlobalEnums and "FiveParsecsCampaignPhase" in GlobalEnums and "NONE" in GlobalEnums.FiveParsecsCampaignPhase:
		return GlobalEnums.FiveParsecsCampaignPhase.NONE
	return 0 # Fallback to safe default

func transition_to_phase(new_phase: int) -> bool:
	# Transition to a new campaign phase
	if not campaign_phase_manager or not campaign_phase_manager.has_method("start_phase"):
		push_error("AlphaGameManager: Cannot transition phase - CampaignPhaseManager not available")
		return false

	return campaign_phase_manager.start_phase(new_phase)

func save_current_state() -> bool:
	# Save the current game state
	if not game_state_manager or not game_state_manager.has_method("save_current_state"):
		push_error("AlphaGameManager: Cannot save state - GameStateManager not available")
		return false

	return game_state_manager.save_current_state()

func load_saved_state(save_name: String = "current_campaign") -> bool:
	# Load a saved game state
	if not game_state_manager or not game_state_manager.has_method("load_saved_state"):
		push_error("AlphaGameManager: Cannot load state - GameStateManager not available")
		return false

	return game_state_manager.load_saved_state(save_name)

func restart_systems() -> void:
	# Restart all systems (useful for recovery)
	print("AlphaGameManager: Restarting systems...")
	is_initialized = false
	systems_ready.clear()
	initialization_errors.clear()

	# Clean up existing systems
	if campaign_creation_manager:
		campaign_creation_manager.queue_free()
		campaign_creation_manager = null

	if campaign_phase_manager:
		campaign_phase_manager.queue_free()
		campaign_phase_manager = null

	if battle_results_manager:
		battle_results_manager.queue_free()
		battle_results_manager = null

	# Reinitialize
	call_deferred("initialize_systems")

func _exit_tree() -> void:
	# Clean up when the manager is removed
	print("AlphaGameManager: Shutting down...")

	# Disconnect all signals first
	_disconnect_all_signals()

	# Clean up managed systems in reverse order of creation
	if dice_manager and is_instance_valid(dice_manager):
		dice_manager.queue_free()
		dice_manager = null

	if battle_results_manager and is_instance_valid(battle_results_manager):
		battle_results_manager.queue_free()
		battle_results_manager = null

	if campaign_phase_manager and is_instance_valid(campaign_phase_manager):
		campaign_phase_manager.queue_free()
		campaign_phase_manager = null

	if campaign_creation_manager and is_instance_valid(campaign_creation_manager):
		campaign_creation_manager.queue_free()
		campaign_creation_manager = null

	# Clear state
	systems_ready.clear()
	initialization_errors.clear()
	_autoload_cache.clear()  # Clear autoload cache during cleanup
	is_initialized = false

	print("AlphaGameManager: Cleanup completed")

func _disconnect_all_signals() -> void:
	"""Disconnect all signal connections to prevent orphaned references"""
	# Note: Signals are automatically disconnected when objects are freed,
	# but explicit disconnection ensures immediate cleanup for memory-sensitive operations
	if game_state_manager and is_instance_valid(game_state_manager):
		# Disconnect any signals we may have connected to
		if game_state_manager.has_signal("state_changed"):
			if game_state_manager.state_changed.is_connected(_on_game_state_changed):
				game_state_manager.state_changed.disconnect(_on_game_state_changed)

	print("AlphaGameManager: Signal disconnection completed")

# Signal handler stubs (add if needed)
func _on_game_state_changed(_new_state: Variant) -> void:
	"""Handle game state changes"""
	pass

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
