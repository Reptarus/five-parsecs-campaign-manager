# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
extends Node

## Core System Setup Autoload
## Ensures proper initialization of all core systems

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

var GameEnums = null
var FPCM_AlphaGameManager = null

var alpha_game_manager: FPCM_AlphaGameManager = null
var initialization_complete: bool = false

signal core_systems_ready()
signal initialization_failed(errors: Array[String])

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "CoreSystemSetup GameEnums")
	FPCM_AlphaGameManager = UniversalResourceLoader.load_script_safe("res://src/core/managers/AlphaGameManager.gd", "CoreSystemSetup AlphaGameManager")
	
	_validate_universal_connections()
	print("CoreSystemSetup: Starting core system initialization...")
	call_deferred("setup_core_systems")

func _validate_universal_connections() -> void:
	_validate_autoload_connections()

func _validate_autoload_connections() -> void:
	# Validate this autoload can access other required autoloads
	var required_autoloads = ["GameState", "EventBus", "ConfigManager", "SaveManager"]
	for autoload_name in required_autoloads:
		if autoload_name != name and not _can_access_autoload(autoload_name):
			push_warning("AUTOLOAD CONNECTION WARNING: Cannot access %s from %s (may not be critical)" % [autoload_name, name])
	
	# Validate critical dependencies
	if not GameEnums:
		push_error("AUTOLOAD CRITICAL FAILURE: GameEnums not loaded in CoreSystemSetup")
	
	if not FPCM_AlphaGameManager:
		push_error("AUTOLOAD CRITICAL FAILURE: AlphaGameManager not loaded in CoreSystemSetup")

func _can_access_autoload(autoload_name: String) -> bool:
	return get_node_or_null("/root/" + autoload_name) != null

func setup_core_systems() -> void:
	"""Setup all core systems in the correct order"""
	
	if not FPCM_AlphaGameManager:
		push_error("CRASH PREVENTION: Cannot create AlphaGameManager - class not loaded")
		return
	
	# Create the main game manager using safe methods
	alpha_game_manager = FPCM_AlphaGameManager.new()
	if not alpha_game_manager:
		push_error("CRASH PREVENTION: Failed to create AlphaGameManager instance")
		return
	
	alpha_game_manager.name = "AlphaGameManager"
	
	# Use safe child addition
	if not UniversalNodeAccess.add_child_safe(self, alpha_game_manager, "CoreSystemSetup alpha_game_manager"):
		push_error("CRASH PREVENTION: Failed to add AlphaGameManager to scene tree")
		return
	
	# Connect to initialization signals using safe signal connections
	UniversalSignalManager.connect_signal_safe(alpha_game_manager, "all_systems_ready", _on_all_systems_ready, "CoreSystemSetup all_systems_ready")
	UniversalSignalManager.connect_signal_safe(alpha_game_manager, "systems_initialized", _on_systems_initialized, "CoreSystemSetup systems_initialized")
	
	print("CoreSystemSetup: Alpha Game Manager created and initialized")

func _on_all_systems_ready() -> void:
	"""Handle successful system initialization"""
	initialization_complete = true
	UniversalSignalManager.emit_signal_safe(self, "core_systems_ready", [], "CoreSystemSetup all_systems_ready")
	print("CoreSystemSetup: All core systems are ready!")

func _on_systems_initialized(success: bool, errors: Array[String]) -> void:
	"""Handle system initialization completion"""
	if not success:
		UniversalSignalManager.emit_signal_safe(self, "initialization_failed", [errors], "CoreSystemSetup initialization_failed")
		push_error("CoreSystemSetup: System initialization failed")
		for error in errors:
			push_error("  - " + error)

# Public API for accessing systems
func get_alpha_game_manager() -> FPCM_AlphaGameManager:
	"""Get the Alpha Game Manager instance"""
	return alpha_game_manager

func get_game_state_manager() -> Node:
	"""Get the GameStateManager instance"""
	if alpha_game_manager:
		return alpha_game_manager.get_game_state_manager()
	return null

func get_campaign_creation_manager() -> Node:
	"""Get the CampaignCreationManager instance"""
	if alpha_game_manager:
		return alpha_game_manager.get_campaign_creation_manager()
	return null

func get_campaign_phase_manager() -> Node:
	"""Get the CampaignPhaseManager instance"""
	if alpha_game_manager:
		return alpha_game_manager.get_campaign_phase_manager()
	return null

func is_ready() -> bool:
	"""Check if all core systems are ready"""
	return initialization_complete

func get_system_status() -> Dictionary:
	"""Get the status of all systems"""
	if alpha_game_manager:
		return alpha_game_manager.get_system_status()
	return {"initialized": false, "systems_ready": {}, "errors": ["Alpha Game Manager not available"]}

func start_new_campaign(config: Dictionary = {}) -> bool:
	"""Start a new campaign"""
	if not alpha_game_manager:
		push_error("CRASH PREVENTION: Cannot start campaign - AlphaGameManager not available")
		return false
	
	if not alpha_game_manager.has_method("start_new_campaign"):
		push_error("CRASH PREVENTION: AlphaGameManager does not have start_new_campaign method")
		return false
	
	# Validate config using safe data access
	var validated_config = {}
	UniversalDataAccess.merge_dict_safe(validated_config, config, true, "CoreSystemSetup start_new_campaign config merge")
	
	return alpha_game_manager.start_new_campaign(validated_config)