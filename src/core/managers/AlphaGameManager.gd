@tool
extends Node
class_name FPCM_AlphaGameManager

## Alpha Game Manager for Five Parsecs Campaign Manager
## Central coordinator for all core systems

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameEnums = null

# System references
var game_state_manager: Node = null
var campaign_creation_manager: Node = null
var campaign_phase_manager: Node = null
var battle_results_manager: Node = null
var dice_manager: Node = null

# Core state
var is_initialized: bool = false
var initialization_errors: Array[String] = []
var systems_ready: Dictionary = {}

# Signals
signal systems_initialized(success: bool, errors: Array[String])
signal game_state_ready(game_state: Node)
signal campaign_creation_ready(manager: Node)
signal system_error(system_name: String, error_message: String)
signal all_systems_ready()

func _init() -> void:
	name = "AlphaGameManager"
	print("AlphaGameManager: Initializing...")

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "AlphaGameManager GameEnums")
	
	# Defer initialization to next frame to ensure all autoloads are ready
	call_deferred("initialize_systems")

func initialize_systems() -> void:
	"""Initialize all core systems in proper order"""
	print("AlphaGameManager: Starting system initialization...")
	initialization_errors.clear()
	systems_ready.clear()
	
	# Step 1: Initialize GameStateManager first (it's the foundation)
	_initialize_game_state_manager()
	
	# Step 2: Initialize other managers that depend on GameState
	_initialize_campaign_creation_manager()
	_initialize_campaign_phase_manager()
	_initialize_battle_results_manager()
	_initialize_dice_manager()
	
	# Step 3: Check if all systems are ready
	_finalize_initialization()

func _initialize_game_state_manager() -> void:
	"""Initialize the GameStateManager"""
	print("AlphaGameManager: Initializing GameStateManager...")
	
	# Try to get existing GameStateManager from autoload
	game_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not game_state_manager:
		# Create new GameStateManager if not found
		var GameStateManagerClass = UniversalResourceLoader.load_script_safe("res://src/core/managers/GameStateManager.gd", "AlphaGameManager GameStateManagerClass")
		if GameStateManagerClass:
			game_state_manager = GameStateManagerClass.new()
			game_state_manager.name = "GameStateManager"
			add_child(game_state_manager)
			print("AlphaGameManager: Created new GameStateManager")
		else:
			var error = "Failed to load GameStateManager class"
			initialization_errors.append(error)
			system_error.emit("GameStateManager", error)
			systems_ready["GameStateManager"] = false
			return
	
	# Initialize the GameStateManager
	if game_state_manager.has_method("initialize_game_state"):
		game_state_manager.initialize_game_state()
	
	systems_ready["GameStateManager"] = true
	game_state_ready.emit(game_state_manager)
	print("AlphaGameManager: GameStateManager ready")

func _initialize_campaign_creation_manager() -> void:
	"""Initialize the CampaignCreationManager"""
	print("AlphaGameManager: Initializing CampaignCreationManager...")
	
	if not game_state_manager:
		var error = "Cannot initialize CampaignCreationManager: GameStateManager not available"
		initialization_errors.append(error)
		system_error.emit("CampaignCreationManager", error)
		systems_ready["CampaignCreationManager"] = false
		return
	
	var CampaignCreationManagerClass = UniversalResourceLoader.load_script_safe("res://src/core/campaign/CampaignCreationManager.gd", "AlphaGameManager CampaignCreationManagerClass")
	if CampaignCreationManagerClass:
		campaign_creation_manager = CampaignCreationManagerClass.new()
		campaign_creation_manager.name = "CampaignCreationManager"
		add_child(campaign_creation_manager)
		
		# Setup with dependencies
		if campaign_creation_manager.has_method("setup"):
			var game_state = game_state_manager.get_game_state()
			campaign_creation_manager.setup(game_state)
		
		systems_ready["CampaignCreationManager"] = true
		campaign_creation_ready.emit(campaign_creation_manager)
		print("AlphaGameManager: CampaignCreationManager ready")
	else:
		var error = "Failed to load CampaignCreationManager class"
		initialization_errors.append(error)
		system_error.emit("CampaignCreationManager", error)
		systems_ready["CampaignCreationManager"] = false

func _initialize_campaign_phase_manager() -> void:
	"""Initialize the CampaignPhaseManager"""
	print("AlphaGameManager: Initializing CampaignPhaseManager...")
	
	if not game_state_manager:
		var error = "Cannot initialize CampaignPhaseManager: GameStateManager not available"
		initialization_errors.append(error)
		system_error.emit("CampaignPhaseManager", error)
		systems_ready["CampaignPhaseManager"] = false
		return
	
	var CampaignPhaseManagerClass = UniversalResourceLoader.load_script_safe("res://src/core/campaign/CampaignPhaseManager.gd", "AlphaGameManager CampaignPhaseManagerClass")
	if CampaignPhaseManagerClass:
		campaign_phase_manager = CampaignPhaseManagerClass.new()
		campaign_phase_manager.name = "CampaignPhaseManager"
		add_child(campaign_phase_manager)
		
		# Setup with dependencies
		if campaign_phase_manager.has_method("setup"):
			var game_state = game_state_manager.get_game_state()
			campaign_phase_manager.setup(game_state)
		
		systems_ready["CampaignPhaseManager"] = true
		print("AlphaGameManager: CampaignPhaseManager ready")
	else:
		var error = "Failed to load CampaignPhaseManager class"
		initialization_errors.append(error)
		system_error.emit("CampaignPhaseManager", error)
		systems_ready["CampaignPhaseManager"] = false

func _initialize_battle_results_manager() -> void:
	"""Initialize the BattleResultsManager"""
	print("AlphaGameManager: Initializing BattleResultsManager...")
	
	if not game_state_manager:
		var error = "Cannot initialize BattleResultsManager: GameStateManager not available"
		initialization_errors.append(error)
		system_error.emit("BattleResultsManager", error)
		systems_ready["BattleResultsManager"] = false
		return
	
	var BattleResultsManagerClass = UniversalResourceLoader.load_script_safe("res://src/core/battle/BattleResultsManager.gd", "AlphaGameManager BattleResultsManagerClass")
	if BattleResultsManagerClass:
		battle_results_manager = BattleResultsManagerClass.new()
		battle_results_manager.name = "BattleResultsManager"
		add_child(battle_results_manager)
		
		# Setup with dependencies
		if battle_results_manager.has_method("setup"):
			var game_state = game_state_manager.get_game_state()
			# Note: CharacterManager would be loaded here if needed
			battle_results_manager.setup(game_state, null)
		
		systems_ready["BattleResultsManager"] = true
		print("AlphaGameManager: BattleResultsManager ready")
	else:
		var error = "Failed to load BattleResultsManager class"
		initialization_errors.append(error)
		system_error.emit("BattleResultsManager", error)
		systems_ready["BattleResultsManager"] = false

func _initialize_dice_manager() -> void:
	"""Initialize the DiceManager"""
	print("AlphaGameManager: Initializing DiceManager...")
	
	# Try to get existing DiceManager from autoload
	dice_manager = get_node_or_null("/root/DiceManager")
	
	if not dice_manager:
		var DiceManagerClass = UniversalResourceLoader.load_script_safe("res://src/core/managers/DiceManager.gd", "AlphaGameManager DiceManagerClass")
		if DiceManagerClass:
			dice_manager = DiceManagerClass.new()
			dice_manager.name = "DiceManager"
			add_child(dice_manager)
			print("AlphaGameManager: Created new DiceManager")
		else:
			var error = "Failed to load DiceManager class"
			initialization_errors.append(error)
			system_error.emit("DiceManager", error)
			systems_ready["DiceManager"] = false
			return
	
	systems_ready["DiceManager"] = true
	print("AlphaGameManager: DiceManager ready")

func _finalize_initialization() -> void:
	"""Finalize the initialization process"""
	var all_ready = true
	var ready_count = 0
	var total_count = systems_ready.size()
	
	for system_name in systems_ready:
		if systems_ready[system_name]:
			ready_count += 1
		else:
			all_ready = false
			push_error("AlphaGameManager: System '" + system_name + "' failed to initialize")
	
	is_initialized = all_ready
	
	print("AlphaGameManager: Initialization complete - " + str(ready_count) + "/" + str(total_count) + " systems ready")
	
	if initialization_errors.size() > 0:
		print("AlphaGameManager: Initialization errors:")
		for error in initialization_errors:
			print("  - " + error)
	
	systems_initialized.emit(is_initialized, initialization_errors)
	
	if is_initialized:
		all_systems_ready.emit()
		print("AlphaGameManager: All systems ready!")
	else:
		push_error("AlphaGameManager: System initialization failed")

# Public API methods
func get_game_state_manager() -> Node:
	"""Get the GameStateManager instance"""
	return game_state_manager

func get_campaign_creation_manager() -> Node:
	"""Get the CampaignCreationManager instance"""
	return campaign_creation_manager

func get_campaign_phase_manager() -> Node:
	"""Get the CampaignPhaseManager instance"""
	return campaign_phase_manager

func get_battle_results_manager() -> Node:
	"""Get the BattleResultsManager instance"""
	return battle_results_manager

func get_dice_manager() -> Node:
	"""Get the DiceManager instance"""
	return dice_manager

func is_system_ready(system_name: String) -> bool:
	"""Check if a specific system is ready"""
	return systems_ready.get(system_name, false)

func get_system_status() -> Dictionary:
	"""Get the status of all systems"""
	return {
		"initialized": is_initialized,
		"systems_ready": systems_ready.duplicate(),
		"errors": initialization_errors.duplicate()
	}

func start_new_campaign(config: Dictionary = {}) -> bool:
	"""Start a new campaign with the given configuration"""
	if not is_initialized:
		push_error("AlphaGameManager: Cannot start campaign - systems not initialized")
		return false
	
	if not game_state_manager or not game_state_manager.has_method("start_new_campaign"):
		push_error("AlphaGameManager: Cannot start campaign - GameStateManager not available")
		return false
	
	print("AlphaGameManager: Starting new campaign...")
	return game_state_manager.start_new_campaign(config)

func get_current_phase() -> int:
	"""Get the current campaign phase"""
	if campaign_phase_manager and campaign_phase_manager.has_method("get_current_phase"):
		return campaign_phase_manager.get_current_phase()
	
	# Safe enum access
	if GameEnums and "FiveParcsecsCampaignPhase" in GameEnums and "NONE" in GameEnums.FiveParcsecsCampaignPhase:
		return GameEnums.FiveParcsecsCampaignPhase.NONE
	return 0  # Fallback to safe default

func transition_to_phase(new_phase: int) -> bool:
	"""Transition to a new campaign phase"""
	if not campaign_phase_manager or not campaign_phase_manager.has_method("start_phase"):
		push_error("AlphaGameManager: Cannot transition phase - CampaignPhaseManager not available")
		return false
	
	return campaign_phase_manager.start_phase(new_phase)

func save_current_state() -> bool:
	"""Save the current game state"""
	if not game_state_manager or not game_state_manager.has_method("save_current_state"):
		push_error("AlphaGameManager: Cannot save state - GameStateManager not available")
		return false
	
	return game_state_manager.save_current_state()

func load_saved_state(save_name: String = "current_campaign") -> bool:
	"""Load a saved game state"""
	if not game_state_manager or not game_state_manager.has_method("load_saved_state"):
		push_error("AlphaGameManager: Cannot load state - GameStateManager not available")
		return false
	
	return game_state_manager.load_saved_state(save_name)

func restart_systems() -> void:
	"""Restart all systems (useful for recovery)"""
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
	"""Clean up when the manager is removed"""
	print("AlphaGameManager: Shutting down...")
	
	# Clean up managed systems
	if campaign_creation_manager and is_instance_valid(campaign_creation_manager):
		campaign_creation_manager.queue_free()
	
	if campaign_phase_manager and is_instance_valid(campaign_phase_manager):
		campaign_phase_manager.queue_free()
	
	if battle_results_manager and is_instance_valid(battle_results_manager):
		battle_results_manager.queue_free()
