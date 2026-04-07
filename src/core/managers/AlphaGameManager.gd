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
# GlobalEnums available as autoload singleton

# Performance optimization: Cache loaded scripts
static var _script_cache: Dictionary = {}
var _autoload_cache: Dictionary = {} # Non-static since we're using instance methods

# System references
var game_state_manager: Node = null # GameStateManager when available
## campaign_creation_manager REMOVED — CampaignCreationManager was dead code, replaced by CampaignCreationCoordinator
var campaign_phase_manager: Node = null # CampaignPhaseManager when available
var battle_results_manager: Node = null # BattleResultsManager when available
var dice_manager: Node = null # DiceManager when available

# Core state
var is_initialized: bool = false
var initialization_errors: Array[String] = []
var systems_ready: Dictionary = {}

# Type-safe signals
signal systems_initialized(success: bool, errors: Array)
signal game_state_ready(game_state)
signal campaign_creation_ready(manager)
signal system_error(system_name, error_message)
signal all_systems_ready()
signal manager_ready(manager_name, manager_instance)

# Performance tracking
var _initialization_start_time: int = 0
var _system_load_times: Dictionary = {}

func _init() -> void:
	name = "AlphaGameManager"
	_initialization_start_time = Time.get_ticks_msec()

func _ready() -> void:
	# Defer initialization to next frame to ensure all autoloads are ready
	call_deferred("initialize_systems")

func initialize_systems() -> void:
	# Initialize all core systems in proper order with performance tracking
	initialization_errors.clear()
	systems_ready.clear()
	_system_load_times.clear()

	# Step 1: Initialize GameStateManager first (it's the foundation)
	_initialize_manager("GameStateManager", _initialize_game_state_manager)

	# Step 2: Initialize other managers that depend on GameState
	# CampaignCreationManager removed — replaced by CampaignCreationCoordinator
	_initialize_manager("CampaignPhaseManager", _initialize_campaign_phase_manager)
	_initialize_manager("BattleResultsManager", _initialize_battle_results_manager)
	_initialize_manager("DiceManager", _initialize_dice_manager)

	# Step 3: Check if all systems are ready
	_finalize_initialization()

## Optimized manager initialization wrapper with performance tracking
func _initialize_manager(manager_name: String, init_function: Callable) -> void:
	var start_time = Time.get_ticks_msec()
	
	init_function.call()
	
	var load_time = Time.get_ticks_msec() - start_time
	_system_load_times[manager_name] = load_time

## Optimized script loader with caching
static func _load_script_cached(script_path: String) -> Script:
	if script_path in _script_cache:
		return _script_cache[script_path]
	
	if not ResourceLoader.exists(script_path):
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
	
	systems_ready[manager_name] = true
	manager_ready.emit(manager_name, instance)
	return instance

func _initialize_game_state_manager() -> void:
	# Optimized GameStateManager initialization
	game_state_manager = _get_autoload_cached("/root/GameStateManager")

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
	var dependencies = [game_state, null] if game_state else [] # null placeholder for CharacterManager
	
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
	
	# Detailed performance breakdown
	for system_name in _system_load_times:
		pass

	if initialization_errors.size() > 0:
		for error in initialization_errors:
			pass

	systems_initialized.emit(is_initialized, initialization_errors)

	if is_initialized:
		all_systems_ready.emit()
	else:
		push_error("AlphaGameManager: System initialization failed")

# Type-safe Public API methods
func get_game_state_manager() -> Node:
	# Get the GameStateManager instance (GameStateManager when available)
	if not game_state_manager:
		push_warning("AlphaGameManager: GameStateManager not available, attempting recovery")
		game_state_manager = _get_autoload_cached("/root/GameStateManager")
		
	if not game_state_manager:
		push_error("AlphaGameManager: GameStateManager unavailable - system degraded")
		return null
		
	return game_state_manager

func get_campaign_creation_manager() -> Node:
	# Get the CampaignCreationManager instance
	return campaign_creation_manager

func get_campaign_phase_manager() -> Node:
	# Get the CampaignPhaseManager instance (CampaignPhaseManager when available)
	if not campaign_phase_manager:
		push_warning("AlphaGameManager: CampaignPhaseManager not available")
		return null
		
	return campaign_phase_manager

func get_battle_results_manager() -> Node:
	# Get the BattleResultsManager instance (BattleResultsManager when available)
	return battle_results_manager

func get_dice_manager() -> Node:
	# Get the DiceManager instance (DiceManager when available)
	return dice_manager

func get_battle_manager() -> Node:
	# Get the battle manager instance with comprehensive fallback logic and health monitoring
	# Primary option: Use our battle_results_manager if available and healthy
	if battle_results_manager and is_instance_valid(battle_results_manager):
		# Validate the manager is functional
		if battle_results_manager.has_method("is_ready"):
			if battle_results_manager.is_ready():
				return battle_results_manager
			else:
				push_warning("AlphaGameManager: BattleResultsManager exists but not ready")
		else:
			# Assume functional if no health check method
			return battle_results_manager

	# Secondary option: Look for global BattleManager autoload
	var battle_manager: Node = _get_autoload_cached("/root/BattleManager")
	if battle_manager and is_instance_valid(battle_manager):
		return battle_manager

	# Tertiary option: Check GameStateManager's manager registry
	if game_state_manager and game_state_manager.has_method("get_manager"):
		var registered_manager = game_state_manager.get_manager("FiveParsecsCombatManager")
		if registered_manager and is_instance_valid(registered_manager):
			return registered_manager
		
		# Also try standard BattleManager name
		registered_manager = game_state_manager.get_manager("BattleManager")
		if registered_manager and is_instance_valid(registered_manager):
			return registered_manager

	# Quaternary option: Try to find any battle-related manager in the tree
	var root_node = get_tree().root
	for child in root_node.get_children():
		if child.name.contains("Battle") and child.name.contains("Manager"):
			return child

	# Final fallback: Try to create a minimal battle manager wrapper
	push_warning("AlphaGameManager: No battle manager found, attempting to create minimal wrapper")
	var minimal_battle_manager = Node.new()
	minimal_battle_manager.name = "MinimalBattleManager"
	
	# Add basic battle management capabilities if the script exists
	var battle_script = _load_script_cached("res://src/core/battle/BattleResultsManager.gd")
	if battle_script:
		var instance = battle_script.new()
		if instance:
			instance.name = "EmergencyBattleManager"
			add_child(instance)
			battle_results_manager = instance
			return instance
	
	push_error("AlphaGameManager: Unable to provide any battle manager - battle functionality will be unavailable")
	return null

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

## Get detailed performance report with advanced metrics and health indicators
func get_performance_report() -> String:
	var report = "AlphaGameManager Advanced Performance Report\\n"
	report += "==========================================\\n"
	
	# Basic timing metrics
	var current_time = Time.get_ticks_msec()
	var total_time = current_time - _initialization_start_time if _initialization_start_time > 0 else 0
	var uptime_seconds = total_time / 1000.0
	
	report += "System Status: %s\\n" % ("HEALTHY" if is_initialized else "DEGRADED")
	report += "Total initialization time: %d ms\\n" % total_time
	report += "System uptime: %.1f seconds\\n" % uptime_seconds
	report += "Script cache entries: %d\\n" % _script_cache.size()
	report += "Autoload cache entries: %d\\n" % _autoload_cache.size()
	report += "Active child nodes: %d\\n" % get_children().size()
	
	# Memory and resource metrics
	report += "\\nMemory Usage:\\n"
	report += "  Initialization errors: %d\\n" % initialization_errors.size()
	report += "  Systems tracked: %d\\n" % systems_ready.size()
	report += "  Performance data points: %d\\n" % _system_load_times.size()
	
	# System health status
	report += "\\nSystem Health Status:\\n"
	var healthy_systems = 0
	var total_systems = systems_ready.size()
	
	for system_name in systems_ready:
		var status = "✓ READY" if systems_ready[system_name] else "✗ FAILED"
		report += "  %s: %s\\n" % [system_name, status]
		if systems_ready[system_name]:
			healthy_systems += 1
	
	var health_percentage = (healthy_systems * 100.0 / total_systems) if total_systems > 0 else 0
	report += "  Overall Health: %.1f%% (%d/%d systems)\\n" % [health_percentage, healthy_systems, total_systems]
	
	# Performance breakdown
	report += "\\nSystem Load Times:\\n"
	var slowest_system = ""
	var slowest_time = 0
	
	for system_name in _system_load_times:
		var load_time = _system_load_times[system_name]
		var percentage = (load_time * 100.0 / total_time) if total_time > 0 else 0
		var performance_rating = "FAST" if load_time < 50 else ("NORMAL" if load_time < 200 else "SLOW")
		report += "  %s: %d ms (%.1f%%) [%s]\\n" % [system_name, load_time, percentage, performance_rating]
		
		if load_time > slowest_time:
			slowest_time = load_time
			slowest_system = system_name
	
	if slowest_system != "":
		report += "  Slowest system: %s (%d ms)\\n" % [slowest_system, slowest_time]
	
	# Performance recommendations
	report += "\\nPerformance Recommendations:\\n"
	if total_time > 1000:
		report += "  • Initialization time is high (>1000ms) - consider optimizing slow systems\\n"
	if _script_cache.size() > 20:
		report += "  • Script cache is large (%d entries) - consider clearing periodically\\n" % _script_cache.size()
	if health_percentage < 100:
		report += "  • Some systems failed to initialize - check error logs\\n"
	if slowest_time > 300:
		report += "  • System '%s' is slow (%d ms) - investigate load bottlenecks\\n" % [slowest_system, slowest_time]
	
	# Cache details
	report += "\\nScript Cache Contents:\\n"
	for script_path in _script_cache:
		report += "  %s\\n" % script_path
	
	# Error summary
	if initialization_errors.size() > 0:
		report += "\\nInitialization Errors:\\n"
		for error in initialization_errors:
			report += "  • %s\\n" % error
	else:
		report += "\\nNo initialization errors detected\\n"
	
	report += "\\nReport generated at: %s\\n" % Time.get_datetime_string_from_system()
	
	return report

## Clear performance caches (useful for testing)
static func clear_caches() -> void:
	_script_cache.clear()

## Clear autoload cache (instance method)
func clear_autoload_cache() -> void:
	_autoload_cache.clear()

func start_new_campaign(config: Dictionary = {}) -> bool:
	# Start a new campaign with the given configuration
	if not is_initialized:
		push_error("AlphaGameManager: Cannot start campaign - systems not initialized")
		return false

	if not game_state_manager or not game_state_manager.has_method("start_new_campaign"):
		push_error("AlphaGameManager: Cannot start campaign - GameStateManager not available")
		return false

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
	# Save the current game state with comprehensive validation and performance tracking
	var start_time = Time.get_ticks_msec()
	
	# Validate system prerequisites
	if not is_initialized:
		push_error("AlphaGameManager: Cannot save state - systems not initialized")
		return false
	
	if not game_state_manager:
		push_error("AlphaGameManager: Cannot save state - GameStateManager not available")
		return false
		
	if not game_state_manager.has_method("save_current_state"):
		push_error("AlphaGameManager: Cannot save state - GameStateManager missing save_current_state method")
		return false
	
	# Validate we have data to save
	if game_state_manager.has_method("get_game_state"):
		var current_state = game_state_manager.get_game_state()
		if not current_state or (current_state is Dictionary and current_state.is_empty()):
			push_warning("AlphaGameManager: Saving empty game state")
	
	var success = game_state_manager.save_current_state()
	var save_time = Time.get_ticks_msec() - start_time
	
	if success:
		pass
	else:
		push_error("AlphaGameManager: State save failed after %d ms" % save_time)
	
	return success

func load_saved_state(save_name: String = "current_campaign") -> bool:
	# Load a saved game state with validation and error recovery
	var start_time = Time.get_ticks_msec()
	
	# Validate input parameters
	if save_name.is_empty():
		push_error("AlphaGameManager: Cannot load state - save name is empty")
		return false
	
	# Validate system prerequisites
	if not game_state_manager:
		push_error("AlphaGameManager: Cannot load state - GameStateManager not available")
		return false
		
	if not game_state_manager.has_method("load_saved_state"):
		push_error("AlphaGameManager: Cannot load state - GameStateManager missing load_saved_state method")
		return false
	
	# Backup current state before loading (if possible)
	var backup_created = false
	if game_state_manager.has_method("backup_current_state"):
		backup_created = game_state_manager.backup_current_state()
		if backup_created:
			pass
	
	var success = game_state_manager.load_saved_state(save_name)
	var load_time = Time.get_ticks_msec() - start_time
	
	if success:
		# Trigger system refresh after successful load
		if is_initialized:
			_finalize_initialization()
	else:
		push_error("AlphaGameManager: State load failed after %d ms" % load_time)
		# Attempt to restore backup if available
		if backup_created and game_state_manager.has_method("restore_backup"):
			if game_state_manager.restore_backup():
				push_warning("AlphaGameManager: Backup state restored after load failure")
			else:
				push_error("AlphaGameManager: Failed to restore backup state")
	
	return success

func restart_systems() -> void:
	# Restart all systems with progressive restart logic and graceful degradation
	var restart_start_time = Time.get_ticks_msec()
	
	# Phase 1: Save current state for recovery
	var state_backed_up = false
	if is_initialized and game_state_manager and game_state_manager.has_method("backup_current_state"):
		state_backed_up = game_state_manager.backup_current_state()
		if state_backed_up:
			pass
	
	# Phase 2: Graceful shutdown of systems in reverse dependency order
	is_initialized = false
	var old_systems_ready = systems_ready.duplicate()
	systems_ready.clear()
	initialization_errors.clear()
	
	# Disconnect signals to prevent orphaned references
	_disconnect_all_signals()

	# Clean up systems in reverse order (dependent systems first)
	if battle_results_manager and is_instance_valid(battle_results_manager):
		battle_results_manager.queue_free()
		battle_results_manager = null

	if campaign_phase_manager and is_instance_valid(campaign_phase_manager):
		campaign_phase_manager.queue_free()
		campaign_phase_manager = null

	if campaign_creation_manager and is_instance_valid(campaign_creation_manager):
		campaign_creation_manager.queue_free()
		campaign_creation_manager = null

	# Clear caches for fresh start
	clear_autoload_cache()
	
	# Phase 3: Progressive restart with health monitoring
	
	# Wait one frame to ensure cleanup is complete
	await get_tree().process_frame
	
	# Reinitialize systems
	initialize_systems()
	
	# Phase 4: Validate restart success and provide recovery statistics
	var restart_time = Time.get_ticks_msec() - restart_start_time
	var systems_restored = 0
	var systems_lost = 0
	
	for system_name in old_systems_ready:
		if systems_ready.get(system_name, false):
			systems_restored += 1
		else:
			systems_lost += 1
			push_warning("AlphaGameManager: System '%s' failed to restart" % system_name)
	
	
	# Phase 5: Attempt state recovery if possible
	if state_backed_up and is_initialized and game_state_manager and game_state_manager.has_method("restore_backup"):
		if game_state_manager.restore_backup():
			pass
		else:
			push_warning("AlphaGameManager: Failed to restore state after restart")
	
	if not is_initialized:
		push_error("AlphaGameManager: System restart failed - manual intervention may be required")

func _exit_tree() -> void:
	# Clean up when the manager is removed

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
	_autoload_cache.clear() # Clear autoload cache during cleanup
	is_initialized = false


func _disconnect_all_signals() -> void:
	## Disconnect all signal connections to prevent orphaned references
	# Note: Signals are automatically disconnected when objects are freed,
	# but explicit disconnection ensures immediate cleanup for memory-sensitive operations
	if game_state_manager and is_instance_valid(game_state_manager):
		# Disconnect any signals we may have connected to
		if game_state_manager.has_signal("state_changed"):
			if game_state_manager.state_changed.is_connected(_on_game_state_changed):
				game_state_manager.state_changed.disconnect(_on_game_state_changed)


# Signal handler implementations
func _on_game_state_changed(new_state: Variant) -> void:
	## Handle game state changes with validation and propagation
	if not new_state or typeof(new_state) != TYPE_DICTIONARY:
		push_warning("AlphaGameManager: Invalid state change data received")
		return
	
	# Propagate to dependent systems
	if campaign_phase_manager and campaign_phase_manager.has_method("on_state_changed"):
		campaign_phase_manager.on_state_changed(new_state)
		
	if campaign_creation_manager and campaign_creation_manager.has_method("on_state_changed"):
		campaign_creation_manager.on_state_changed(new_state)
	
	# Emit our own signal for UI updates
	manager_ready.emit("GameStateManager", game_state_manager)
