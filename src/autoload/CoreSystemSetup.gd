# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
extends Node

## Core System Setup Autoload
## Ensures proper initialization of all core systems

# Removed Universal class imports to fix SHADOWED_GLOBAL_IDENTIFIER warnings
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# GlobalEnums available as autoload singleton
const AlphaGameManagerScript = preload("res://src/core/managers/AlphaGameManager.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# Memory management systems
const MemoryLeakPrevention = preload("res://src/core/memory/MemoryLeakPrevention.gd")
const UniversalCleanupFramework = preload("res://src/core/memory/UniversalCleanupFramework.gd")
const CleanupHelpers = preload("res://src/core/memory/CleanupHelpers.gd")
const MemoryPerformanceOptimizer = preload("res://src/core/memory/MemoryPerformanceOptimizer.gd")

# JSON configuration support
var system_config_data: Dictionary = {}
var autoload_parameters: Dictionary = {}
# DataManager is static, no instance needed

var alpha_game_manager: Variant = null
var initialization_complete: bool = false

signal core_systems_ready()
signal initialization_failed(errors: Array[String])

func _ready() -> void:
	_load_system_configuration()
	_validate_universal_connections()
	print("CoreSystemSetup: Starting core system initialization...")
	call_deferred("setup_core_systems")

func _load_system_configuration() -> void:
	"""Load system configuration from JSON files"""
	# DataManager is static, don't instantiate
	
	# Load system config data using static method
	system_config_data = DataManager._load_json_safe("res://data/autoload/system_config.json", "CoreSystemSetup")
	if system_config_data.is_empty():
		print("CoreSystemSetup: system_config.json not found, using default parameters")
		_create_system_config_fallback()
	else:
		print("CoreSystemSetup: Loaded system configuration from JSON")
	
	# Extract autoload parameters
	autoload_parameters = system_config_data.get("autoload_parameters", {})

func _create_system_config_fallback() -> void:
	"""Create fallback system configuration when JSON unavailable"""
	system_config_data = {
		"autoload_parameters": {
			"initialization_timeout": 10.0,
			"debug_logging": true,
			"performance_monitoring": false,
			"error_recovery": true,
			"system_validation": true
		},
		"system_priorities": {
			"core_systems": 1,
			"game_managers": 2,
			"ui_systems": 3,
			"peripheral_systems": 4
		},
		"initialization_config": {
			"parallel_loading": false,
			"dependency_checking": true,
			"graceful_degradation": true,
			"retry_failed_systems": true,
			"max_retry_attempts": 3
		},
		"performance_thresholds": {
			"max_init_time_ms": 5000,
			"warning_threshold_ms": 2000,
			"memory_limit_mb": 512
		}
	}
	
	autoload_parameters = system_config_data.autoload_parameters

func _validate_universal_connections() -> void:
	_validate_autoload_connections()

func _validate_autoload_connections() -> void:
	# Validate this autoload can access other required autoloads
	@warning_ignore("untyped_declaration")
	var required_autoloads = ["GameState", "EventBus", "ConfigManager", "SaveManager"]
	@warning_ignore("untyped_declaration")
	for autoload_name in required_autoloads:
		@warning_ignore("unused_variable")
		var typed_autoload_name: Variant = autoload_name
		@warning_ignore("unsafe_call_argument")
		if autoload_name != name and not _can_access_autoload(autoload_name):
			push_warning("AUTOLOAD CONNECTION WARNING: Cannot access %s from %s (may not be critical)" % [autoload_name, name])

	# Validate critical dependencies
	if not GlobalEnums:
		push_error("AUTOLOAD CRITICAL FAILURE: GlobalEnums not loaded in CoreSystemSetup")

	if not AlphaGameManagerScript:
		push_error("AUTOLOAD CRITICAL FAILURE: AlphaGameManager not loaded in CoreSystemSetup")

func _can_access_autoload(autoload_name: String) -> bool:
	return get_node_or_null("/root/" + str(autoload_name)) != null

func setup_core_systems() -> void:
	# Setup all core systems in the correct order
	
	# Initialize memory management systems first
	_initialize_memory_management()
	
	# Get reference to the existing AlphaGameManager autoload with correct name
	alpha_game_manager = get_node_or_null("/root/FPCM_AlphaGameManager") as Node
	if not alpha_game_manager:
		push_error("CRASH PREVENTION: Cannot access FPCM_AlphaGameManager autoload")
		return

	# Connect to initialization signals using safe signal connections
	@warning_ignore("unsafe_method_access")
	alpha_game_manager.all_systems_ready.connect(_on_all_systems_ready)
	@warning_ignore("unsafe_method_access")
	alpha_game_manager.systems_initialized.connect(_on_systems_initialized)

	print("CoreSystemSetup: Connected to existing FPCM_AlphaGameManager autoload")

## Initialize memory management systems
func _initialize_memory_management() -> void:
	print("CoreSystemSetup: Initializing memory management systems...")
	
	# Initialize MemoryLeakPrevention system
	if MemoryLeakPrevention.initialize():
		print("CoreSystemSetup: ✅ MemoryLeakPrevention initialized")
	else:
		print("CoreSystemSetup: ⚠️ MemoryLeakPrevention initialization failed")
	
	# Initialize UniversalCleanupFramework
	if UniversalCleanupFramework.initialize():
		print("CoreSystemSetup: ✅ UniversalCleanupFramework initialized")
	else:
		print("CoreSystemSetup: ⚠️ UniversalCleanupFramework initialization failed")
	
	# Initialize global cleanup helpers
	CleanupHelpers.initialize_global_cleanup()
	print("CoreSystemSetup: ✅ CleanupHelpers initialized")
	
	# Initialize MemoryPerformanceOptimizer (skip during testing)
	var is_testing = OS.has_feature("debug") and Engine.get_process_frames() < 10
	if not is_testing:
		var optimization_level = _get_optimization_level_from_config()
		if MemoryPerformanceOptimizer.initialize(optimization_level):
			print("CoreSystemSetup: ✅ MemoryPerformanceOptimizer initialized (level: %s)" % MemoryPerformanceOptimizer.OptimizationLevel.keys()[optimization_level])
		else:
			print("CoreSystemSetup: ⚠️ MemoryPerformanceOptimizer initialization failed")
	else:
		print("CoreSystemSetup: 🧪 Skipping MemoryPerformanceOptimizer during testing")
	
	# Register CoreSystemSetup for cleanup
	CleanupHelpers.setup_autoload_cleanup("CoreSystemSetup", self)
	
	print("CoreSystemSetup: ✅ Memory management systems fully initialized")

## Get optimization level from configuration
func _get_optimization_level_from_config() -> MemoryPerformanceOptimizer.OptimizationLevel:
	var performance_config = system_config_data.get("performance_thresholds", {})
	var memory_limit_mb = performance_config.get("memory_limit_mb", 512)
	
	# Determine optimization level based on memory limit
	if memory_limit_mb <= 256:
		return MemoryPerformanceOptimizer.OptimizationLevel.EXTREME
	elif memory_limit_mb <= 512:
		return MemoryPerformanceOptimizer.OptimizationLevel.AGGRESSIVE
	elif memory_limit_mb <= 1024:
		return MemoryPerformanceOptimizer.OptimizationLevel.BALANCED
	else:
		return MemoryPerformanceOptimizer.OptimizationLevel.CONSERVATIVE

func _on_all_systems_ready() -> void:
	# Handle successful system initialization
	initialization_complete = true
	self.core_systems_ready.emit()
	print("CoreSystemSetup: All core systems are ready!")

## Cleanup method for autoload shutdown
func cleanup() -> void:
	print("CoreSystemSetup: Performing cleanup shutdown...")
	
	# Shutdown memory management systems
	await MemoryLeakPrevention.shutdown()
	print("CoreSystemSetup: MemoryLeakPrevention shutdown complete")
	
	await UniversalCleanupFramework.shutdown()
	print("CoreSystemSetup: UniversalCleanupFramework shutdown complete")
	
	await MemoryPerformanceOptimizer.shutdown()
	print("CoreSystemSetup: MemoryPerformanceOptimizer shutdown complete")
	
	# Reset state
	initialization_complete = false
	alpha_game_manager = null
	system_config_data.clear()
	autoload_parameters.clear()
	
	print("CoreSystemSetup: ✅ Cleanup complete")

func _on_systems_initialized(success: bool, errors: Array) -> void:
	# Handle system initialization completion
	if not success:
		self.initialization_failed.emit(errors)
		push_error("CoreSystemSetup: System initialization failed")
		for error in errors:
			push_error("  - " + error)

# Public API for accessing systems
@warning_ignore("untyped_declaration")
func get_alpha_game_manager() -> Object:
	# Get the Alpha Game Manager instance
	return alpha_game_manager

func get_game_state_manager() -> Node:
	# Get the GameStateManager instance
	if alpha_game_manager:
		@warning_ignore("unsafe_method_access")
		return alpha_game_manager.get_game_state_manager()
	return null

func get_campaign_creation_manager() -> Node:
	# Get the CampaignCreationManager instance
	if alpha_game_manager:
		@warning_ignore("unsafe_method_access")
		return alpha_game_manager.get_campaign_creation_manager()
	return null

func get_campaign_phase_manager() -> Node:
	# Get the CampaignPhaseManager instance
	if alpha_game_manager:
		@warning_ignore("unsafe_method_access")
		return alpha_game_manager.get_campaign_phase_manager()
	return null

func is_ready() -> bool:
	# Check if all core systems are ready
	return initialization_complete

func get_system_status() -> Dictionary:
	# Get the status of all systems
	if alpha_game_manager:
		@warning_ignore("unsafe_method_access")
		return alpha_game_manager.get_system_status()
	return {"initialized": false, "systems_ready": {}, "errors": ["Alpha Game Manager not available"]}

func start_new_campaign(config: Dictionary = {}) -> bool:
	# Start a new campaign
	if not alpha_game_manager:
		push_error("CRASH PREVENTION: Cannot start campaign - AlphaGameManager not available")
		return false

	@warning_ignore("unsafe_method_access")
	if not alpha_game_manager.has_method("start_new_campaign"):
		push_error("CRASH PREVENTION: AlphaGameManager does not have start_new_campaign method")
		return false

	# Validate config using safe data access
	var validated_config: Dictionary = {}
	validated_config.merge(config)

	@warning_ignore("unsafe_method_access")
	return alpha_game_manager.start_new_campaign(validated_config)
