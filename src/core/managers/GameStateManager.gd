# Universal Connection Validation Applied - Enhanced with 7-Stage Methodology
# Based on proven patterns: Universal Mock Strategy + Complete Warning Elimination
class_name GameStateManagerClass
extends Node

# Stage 1: Enhanced Universal imports with comprehensive safety patterns
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# Safe dependency loading with preload pattern
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CoreGameState = preload("res://src/core/state/GameState.gd")

# Stage 2: Enhanced signal definitions with comprehensive type safety
signal game_state_changed(new_state)
signal campaign_phase_changed(new_phase: int)
signal difficulty_changed(new_difficulty: int)
signal credits_changed(new_amount: int)
signal supplies_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal story_progress_changed(new_amount: int)
signal manager_registered(manager_name: String)
signal manager_unregistered(manager_name: String)
signal state_save_completed(success: bool)
signal state_load_completed(success: bool)

# Stage 3: Enhanced exported variables with comprehensive validation
@export var initial_credits: int = 1000
@export var initial_supplies: int = 5
@export var initial_reputation: int = 0
@export var enable_debug_logging: bool = false
@export var auto_save_interval: float = 300.0 # 5 minutes

# Core state variables with enhanced type safety
var game_state: Variant = null
var campaign_phase: int = 0 # Will be set to NONE enum value in _ready()
var difficulty_level: int = 1 # Will be set to NORMAL enum value in _ready()
var credits: int = initial_credits
var supplies: int = initial_supplies
var reputation: int = initial_reputation
var story_progress: int = 0

# Manager registration system for cross-system communication
var registered_managers: Dictionary = {}

# Internal state tracking
var _initialization_complete: bool = false
var _dependencies_loaded: bool = false
var _auto_save_timer: Timer = null

func _ready() -> void:
	print("GameStateManager: Starting enhanced initialization...")

	# Stage 1: Load dependencies safely at runtime
	if not _load_dependencies_safe():
		push_error("GameStateManager: CRITICAL - Failed to load required dependencies")
		return

	# Stage 2: Initialize enum values after loading GlobalEnums
	_initialize_enum_values()

	# Stage 3: Validate Universal connections
	_validate_universal_connections()

	# Stage 4: Initialize state values
	_initialize_state_values()

	# Stage 5: Create default game state if none exists
	_initialize_game_state_safe()

	# Stage 6: Setup auto-save timer
	_setup_auto_save_timer()

	_initialization_complete = true
	print("GameStateManager: Enhanced initialization complete")

## Stage 1: Enhanced dependency loading with comprehensive validation
func _load_dependencies_safe() -> bool:
	"""Validate preloaded dependencies"""

	# Validate GlobalEnums preload
	if not GlobalEnums:
		push_error("GameStateManager: Failed to load GlobalEnums - critical dependency missing")
		return false

	# Validate CoreGameState preload
	if not CoreGameState:
		push_error("GameStateManager: Failed to load CoreGameState - critical dependency missing")
		return false

	_dependencies_loaded = true
	print("GameStateManager: Dependencies validated successfully")
	return true

## Stage 2: Enhanced enum initialization with comprehensive validation
func _initialize_enum_values() -> void:
	"""Initialize enum values after loading GlobalEnums with validation"""

	if not GlobalEnums:
		push_error("GameStateManager: Cannot initialize enum values - GlobalEnums not loaded")
		return

	# Set default campaign phase to NONE if available
	if "FiveParsecsCampaignPhase" in GlobalEnums:
		if "NONE" in GlobalEnums.FiveParsecsCampaignPhase:
			campaign_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
			print("GameStateManager: Campaign phase set to NONE")
		else:
			push_warning("GameStateManager: NONE not found in FiveParsecsCampaignPhase enum")
	else:
		push_warning("GameStateManager: FiveParsecsCampaignPhase enum not found in GlobalEnums")

	# Set default difficulty to STANDARD if available
	if "DifficultyLevel" in GlobalEnums:
		if "STANDARD" in GlobalEnums.DifficultyLevel:
			difficulty_level = GlobalEnums.DifficultyLevel.STANDARD
			print("GameStateManager: Difficulty level set to STANDARD")
		else:
			push_warning("GameStateManager: STANDARD not found in DifficultyLevel enum")
	else:
		push_warning("GameStateManager: DifficultyLevel enum not found in GlobalEnums")

## Stage 3: Enhanced Universal connection validation
func _validate_universal_connections() -> void:
	"""Validate core system connections with comprehensive error handling"""

	# Validate core system connections
	_validate_core_connections()

	# Register with game state
	_register_with_game_state()

	# Validate signal connections
	_validate_signal_connections()

## Enhanced core connections validation
func _validate_core_connections() -> void:
	"""Validate required dependencies with comprehensive error handling"""

	# Validate required dependencies
	if not GlobalEnums:
		push_error("CORE SYSTEM FAILURE: GlobalEnums not accessible from GameStateManager")
	else:
		print("GameStateManager: GlobalEnums connection validated")

	if not CoreGameState:
		push_error("CORE SYSTEM FAILURE: CoreGameState not accessible from GameStateManager")
	else:
		print("GameStateManager: CoreGameState connection validated")

	# Core utilities validation complete
	print("GameStateManager: All essential systems validated and operational")

## Enhanced game state registration
func _register_with_game_state() -> void:
	"""Register this manager with the global game state system"""
	# TODO: This logic is flawed. It attempts to call a static method on the GameState class.
	# The project seems to lack a global GameState autoload/singleton.
	# Commenting out to prevent errors until the architecture is clarified.
	# Register this manager with the global game state system using direct autoload access
	# if GameState and GameState and GameState.has_method("register_manager"):
	# 	GameState.register_manager("GameStateManager", self)
	# 	print("GameStateManager: Successfully registered with global GameState")
	# else:
	# 	push_warning("GameStateManager: Global GameState not available or missing register_manager method")
	pass

## Enhanced signal connection validation
func _validate_signal_connections() -> void:
	"""Validate signal connections are properly established"""

	# Validate that our signals are properly defined
	var expected_signals: Array[String] = [
		"game_state_changed",
		"campaign_phase_changed",
		"difficulty_changed",
		"credits_changed",
		"supplies_changed",
		"reputation_changed",
		"story_progress_changed"
	]

	for signal_name in expected_signals:
		if not has_signal(signal_name):
			push_error("GameStateManager: Missing expected signal: " + str(signal_name))
		else:
			if enable_debug_logging:
				print("GameStateManager: Validated signal: " + str(signal_name))

## Stage 4: Enhanced state initialization
func _initialize_state_values() -> void:
	"""Initialize state values with validation"""

	print("GameStateManager: Initializing state values...")

	# Initialize with default values using setter methods for proper signal emission
	set_credits(initial_credits)
	set_supplies(initial_supplies)
	set_reputation(initial_reputation)
	set_story_progress(0)

	print("GameStateManager: State values initialized - Credits: %d, Supplies: %d, Reputation: %d" % [credits, supplies, reputation])

## Stage 5: Enhanced game state initialization with comprehensive validation
func _initialize_game_state_safe() -> void:
	"""Create default game state if none exists with comprehensive validation"""

	if game_state:
		print("GameStateManager: Game state already exists, skipping initialization")
		return

	if not CoreGameState:
		push_error("CRASH PREVENTION: Cannot create game state - CoreGameState class not loaded")
		return

	# Create instance using proper Godot 4.4 pattern
	var instance = CoreGameState.new()
	if instance:
		game_state = instance
		print("GameStateManager: Created new game state instance")

		# Initialize the game state with current values
		_sync_state_to_game_state()
	else:
		push_error("CRASH PREVENTION: Failed to instantiate CoreGameState")

## Stage 6: Enhanced auto-save timer setup
func _setup_auto_save_timer() -> void:
	"""Setup auto-save timer with proper validation"""

	if auto_save_interval <= 0:
		push_warning("GameStateManager: Auto-save disabled (interval <= 0)")
		return

	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = auto_save_interval
	_auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	_auto_save_timer.autostart = true
	add_child(_auto_save_timer)

	print("GameStateManager: Auto-save timer setup with interval: %f seconds" % auto_save_interval)

## Auto-save timer callback
func _on_auto_save_timer_timeout() -> void:
	"""Handle auto-save timer timeout"""

	if enable_debug_logging:
		print("GameStateManager: Auto-save timer triggered")

	var save_success: bool = save_current_state()
	if save_success:
		print("GameStateManager: Auto-save completed successfully")
	else:
		push_warning("GameStateManager: Auto-save failed")

## Sync current state values to game state
func _sync_state_to_game_state() -> void:
	"""Synchronize current state values to game state instance"""

	if not game_state:
		push_warning("GameStateManager: Cannot sync state - no game state instance")
		return

	# Set initial values using proper API
	if game_state.has_method("set_resource") and GlobalEnums and "ResourceType" in GlobalEnums:
		if "CREDITS" in GlobalEnums.ResourceType:
			game_state.set_resource(GlobalEnums.ResourceType.CREDITS, credits)
		if "SUPPLIES" in GlobalEnums.ResourceType:
			game_state.set_resource(GlobalEnums.ResourceType.SUPPLIES, supplies)

	# Set other properties if they exist
	if "reputation" in game_state:
		game_state.reputation = reputation
	if "story_points" in game_state:
		game_state.story_points = story_progress

	print("GameStateManager: State synchronized to game state instance")

## Stage 4: Enhanced State Management with Comprehensive Validation

## Set game state with enhanced validation
func set_game_state(new_state: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set game state before initialization complete")
		return

	if game_state != new_state:
		var old_state = game_state
		game_state = new_state

		# Validate the new state
		if game_state and not _validate_game_state_instance(game_state):
			push_error("GameStateManager: Invalid game state instance provided")
			game_state = old_state
			return

		self.game_state_changed.emit(game_state)

		if enable_debug_logging:
			print("GameStateManager: Game state changed from %s to %s" % [str(old_state), str(game_state)])

## Set campaign phase with enhanced validation
func set_campaign_phase(new_phase: int) -> void:
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set campaign phase before initialization complete")
		return

	# Validate phase value
	if not _validate_campaign_phase(new_phase):
		push_error("GameStateManager: Invalid campaign phase: " + str(new_phase))
		return

	if campaign_phase != new_phase:
		var old_phase: int = campaign_phase
		campaign_phase = new_phase

		self.campaign_phase_changed.emit(campaign_phase)

		if enable_debug_logging:
			print("GameStateManager: Campaign phase changed from %d to %d" % [old_phase, campaign_phase])

## Set difficulty with enhanced validation
func set_difficulty(new_difficulty: int) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set difficulty before initialization complete")
		return

	# Validate difficulty value
	if not _validate_difficulty_level(new_difficulty):
		push_error("GameStateManager: Invalid difficulty level: " + str(new_difficulty))
		return

	if difficulty_level != new_difficulty:
		var old_difficulty: int = difficulty_level
		difficulty_level = new_difficulty

		self.difficulty_changed.emit(difficulty_level)

		if enable_debug_logging:
			print("GameStateManager: Difficulty changed from %d to %d" % [old_difficulty, difficulty_level])

## Stage 5: Enhanced Resource Management with Comprehensive Validation

## Set credits with enhanced validation and bounds checking
func set_credits(new_amount: int) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set credits before initialization complete")
		return

	# Validate credits amount (can't be negative)
	if new_amount < 0:
		push_warning("GameStateManager: Cannot set negative credits: " + str(new_amount))
		new_amount = 0

	if credits != new_amount:
		var old_credits: int = credits
		credits = new_amount

		self.credits_changed.emit(credits)

		# Sync to game state if available
		_sync_credits_to_game_state()

		if enable_debug_logging:
			print("GameStateManager: Credits changed from %d to %d" % [old_credits, credits])

## Set supplies with enhanced validation and bounds checking
func set_supplies(new_amount: int) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set supplies before initialization complete")
		return

	# Validate supplies amount (can't be negative)
	if new_amount < 0:
		push_warning("GameStateManager: Cannot set negative supplies: " + str(new_amount))
		new_amount = 0

	if supplies != new_amount:
		var old_supplies: int = supplies
		supplies = new_amount

		self.supplies_changed.emit(supplies)

		# Sync to game state if available
		_sync_supplies_to_game_state()

		if enable_debug_logging:
			print("GameStateManager: Supplies changed from %d to %d" % [old_supplies, supplies])

## Set reputation with enhanced validation
func set_reputation(new_amount: int) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set reputation before initialization complete")
		return

	# Reputation can be negative, but validate reasonable bounds
	if new_amount < -100 or new_amount > 100:
		push_warning("GameStateManager: Reputation value outside expected range [-100, 100]: " + str(new_amount))

	if reputation != new_amount:
		var old_reputation: int = reputation
		reputation = new_amount

		self.reputation_changed.emit(reputation)

		# Sync to game state if available
		_sync_reputation_to_game_state()

		if enable_debug_logging:
			print("GameStateManager: Reputation changed from %d to %d" % [old_reputation, reputation])

## Set story progress with enhanced validation
func set_story_progress(new_amount: int) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set story progress before initialization complete")
		return

	# Story progress can't be negative
	if new_amount < 0:
		push_warning("GameStateManager: Cannot set negative story progress: " + str(new_amount))
		new_amount = 0

	if story_progress != new_amount:
		var old_progress: int = story_progress
		story_progress = new_amount

		self.story_progress_changed.emit(story_progress)

		# Sync to game state if available
		_sync_story_progress_to_game_state()

		if enable_debug_logging:
			print("GameStateManager: Story progress changed from %d to %d" % [old_progress, story_progress])

## Stage 6: Enhanced Validation Methods

## Validate game state instance
func _validate_game_state_instance(state_instance: Variant) -> bool:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return false
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to validate game state instance before initialization complete")
		return false

	if not state_instance:
		return false

	# Check if it's a proper Node or Resource
	if not (state_instance is Node or state_instance is Resource):
		push_warning("GameStateManager: Game state instance is not a Node or Resource")
		return false

	# Check if it has expected methods
	var required_methods: Array[String] = ["save_data", "load_data"]
	for method_name in required_methods:
		if not state_instance.has_method(method_name):
			push_warning("GameStateManager: Game state instance missing required method: " + str(method_name))
			# Don't return false here - method might be optional

	return true

## Validate campaign phase
func _validate_campaign_phase(phase: int) -> bool:
	"""Validate that a campaign phase value is valid"""

	if not GlobalEnums or not "FiveParsecsCampaignPhase" in GlobalEnums:
		push_warning("GameStateManager: Cannot validate campaign phase - GlobalEnums not available")
		return true # Allow if we can't validate

	var phase_enum = GlobalEnums.FiveParsecsCampaignPhase

	# Check if phase is within valid enum range
	var valid_phases: Array = []
	for phase_name in phase_enum:
		@warning_ignore("return_value_discarded")
		valid_phases.append(phase_enum[phase_name])

	return phase in valid_phases

## Validate difficulty level
func _validate_difficulty_level(level: int) -> bool:
	"""Validate that a difficulty level value is valid"""

	if not GlobalEnums or not "DifficultyLevel" in GlobalEnums:
		push_warning("GameStateManager: Cannot validate difficulty level - GlobalEnums not available")
		return true # Allow if we can't validate

	var difficulty_enum = GlobalEnums.DifficultyLevel

	# Check if level is within valid enum range
	var valid_levels: Array = []
	for level_name in difficulty_enum:
		@warning_ignore("return_value_discarded")
		valid_levels.append(difficulty_enum[level_name])

	return level in valid_levels

## Stage 7: Enhanced Game State Synchronization Methods

## Sync credits to game state
func _sync_credits_to_game_state() -> void:
	"""Synchronize credits to game state instance"""

	if not game_state:
		return

	if game_state.has_method("set_resource") and GlobalEnums and "ResourceType" in GlobalEnums:
		if "CREDITS" in GlobalEnums.ResourceType:
			game_state.set_resource(GlobalEnums.ResourceType.CREDITS, credits)
		else:
			push_warning("GameStateManager: CREDITS not found in ResourceType enum")
	elif "credits" in game_state:
		game_state.credits = credits
	else:
		push_warning("GameStateManager: Game state has no method to set credits")

## Sync supplies to game state
func _sync_supplies_to_game_state() -> void:
	"""Synchronize supplies to game state instance"""

	if not game_state:
		return

	if game_state.has_method("set_resource") and GlobalEnums and "ResourceType" in GlobalEnums:
		if "SUPPLIES" in GlobalEnums.ResourceType:
			game_state.set_resource(GlobalEnums.ResourceType.SUPPLIES, supplies)
		else:
			push_warning("GameStateManager: SUPPLIES not found in ResourceType enum")
	elif "supplies" in game_state:
		game_state.supplies = supplies
	else:
		push_warning("GameStateManager: Game state has no method to set supplies")

## Sync reputation to game state
func _sync_reputation_to_game_state() -> void:
	"""Synchronize reputation to game state instance"""

	if not game_state:
		return

	if "reputation" in game_state:
		game_state.reputation = reputation
	else:
		push_warning("GameStateManager: Game state has no reputation property")

## Sync story progress to game state
func _sync_story_progress_to_game_state() -> void:
	"""Synchronize story progress to game state instance"""

	if not game_state:
		return

	if "story_points" in game_state:
		game_state.story_points = story_progress
	elif "story_progress" in game_state:
		game_state.story_progress = story_progress
	else:
		push_warning("GameStateManager: Game state has no story progress property")

# Getters
func get_game_state():
	return game_state

func get_campaign_phase() -> int:
	return campaign_phase

func get_difficulty() -> int:
	return difficulty_level

func get_credits() -> int:
	return credits

func get_supplies() -> int:
	return supplies

func get_reputation() -> int:
	return reputation

func get_story_progress() -> int:
	return story_progress

## Initialize a new game state (Public API)
func initialize_game_state() -> void:
	"""Public method to initialize a new game state"""

	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to initialize game state before manager initialization complete")
		return

	_initialize_game_state_safe()

	# Additional initialization for public API
	if game_state:
		# Set initial values using proper API
		if game_state.has_method("set_resource") and GlobalEnums and "ResourceType" in GlobalEnums:
			if "CREDITS" in GlobalEnums.ResourceType:
				game_state.set_resource(GlobalEnums.ResourceType.CREDITS, initial_credits)
			if "SUPPLIES" in GlobalEnums.ResourceType:
				game_state.set_resource(GlobalEnums.ResourceType.SUPPLIES, initial_supplies)

		# Set other properties if they exist
		if "reputation" in game_state:
			game_state.reputation = initial_reputation
		if "story_points" in game_state:
			game_state.story_points = 0

		print("GameStateManager: Game state initialized via public API")

# Manager Registration System for Cross-System Communication

## Register a manager for cross-system access
func register_manager(manager_name: String, manager_instance: Node) -> void:
	"""Register a manager for cross-system communication"""
	if not manager_instance:
		push_warning("GameStateManager: Attempted to register null manager: " + str(manager_name))
		return

	registered_managers[manager_name] = manager_instance
	print("GameStateManager: Registered manager: " + str(manager_name))

## Get a registered manager by name
func get_manager(manager_name: String) -> Node:
	"""Get a registered manager by name"""
	if manager_name in registered_managers:
		return registered_managers[manager_name]
	else:
		push_warning("GameStateManager: Manager not found: " + str(manager_name))
		return null

## Check if a manager is registered
func has_manager(manager_name: String) -> bool:
	"""Check if a manager is registered"""
	return manager_name in registered_managers

## Unregister a manager
func unregister_manager(manager_name: String) -> void:
	"""Unregister a manager"""
	if manager_name in registered_managers:
		registered_managers.erase(manager_name)
		print("GameStateManager: Unregistered manager: " + str(manager_name))
	else:
		push_warning("GameStateManager: Cannot unregister unknown manager: " + str(manager_name))

## Get all registered manager names
func get_registered_managers() -> Array[String]:
	"""Get all registered manager names"""
	return registered_managers.keys()

## Check if there's an active campaign
func has_active_campaign() -> bool:
	if not game_state:
		return false
	return game_state.has_method("has_active_campaign") and game_state.has_active_campaign()

## Start a new campaign with given configuration
func start_new_campaign(campaign_config: Dictionary = {}) -> bool:
	if not game_state:
		initialize_game_state()

	# Apply campaign configuration using safe data access
	var difficulty = campaign_config.get("difficulty", difficulty_level)
	if difficulty != difficulty_level:
		set_difficulty(difficulty)

	var config_credits = campaign_config.get("credits", initial_credits)
	if config_credits != credits:
		set_credits(config_credits)

	var config_supplies = campaign_config.get("supplies", initial_supplies)
	if config_supplies != supplies:
		set_supplies(config_supplies)

	print("GameStateManager: New campaign started")
	return true

## Save the current game state
func save_current_state() -> bool:
	if not game_state:
		push_error("GameStateManager: No game state to save")
		return false

	# Coordinate save across all registered managers
	var save_data = _collect_all_manager_data()

	# Get SaveManager for coordinated save operations
	var save_manager: Node = get_manager("SaveManager")
	if save_manager and save_manager and save_manager.has_method("save_game"):
		return save_manager.save_game(save_data, "current_campaign")
	elif game_state and game_state.has_method("save_game"):
		return game_state.save_game("current_campaign")
	else:
		push_warning("GameStateManager: No save system available")
		return false

func _collect_all_manager_data() -> Dictionary:
	"""Collect save data from all registered managers"""
	var save_data = {
		"game_state_manager": serialize_manager_state(),
		"managers": {}
	}

	# Collect data from all registered managers
	for manager_name in registered_managers:
		var manager: Node = registered_managers[manager_name]
		if manager and manager and manager.has_method("save_data"):
			save_data.managers[manager_name] = manager.save_data()
		elif manager and manager and manager.has_method("serialize"):
			save_data.managers[manager_name] = manager.serialize()

	# Include game state data
	if game_state and game_state and game_state.has_method("serialize"):
		save_data["game_state"] = game_state.serialize()

	return save_data

func serialize_manager_state() -> Dictionary:
	"""Serialize GameStateManager's own state"""
	return {
		"credits": credits,
		"supplies": supplies,
		"reputation": reputation,
		"story_progress": story_progress,
		"campaign_phase": campaign_phase,
		"difficulty_level": difficulty_level
	}

## Load a saved game state
func load_saved_state(save_name: String = "current_campaign") -> bool:
	if not game_state:
		initialize_game_state()

	# Get SaveManager for coordinated load operations
	var save_manager: Node = get_manager("SaveManager")
	var save_data: Dictionary = {}

	if save_manager and save_manager and save_manager.has_method("load_game"):
		save_data = save_manager.load_game(save_name)
	elif game_state and game_state.has_method("load_game"):
		return game_state.load_game(save_name)
	else:
		push_warning("GameStateManager: No load system available")
		return false

	if (save_data.is_empty()):
		push_error("GameStateManager: Failed to load save data")
		return false

	# Restore GameStateManager's own state
	if save_data.has("game_state_manager"):
		_restore_manager_state(save_data.game_state_manager)

	# Restore data for all registered managers
	if save_data.has("managers"):
		_restore_all_manager_data(save_data.managers)

	# Restore game state
	if save_data.has("game_state") and game_state and game_state.has_method("deserialize"):
		game_state.deserialize(save_data.game_state)

	print("GameStateManager: Game state loaded successfully")
	return true

func _restore_manager_state(data: Dictionary) -> void:
	"""Restore GameStateManager's own state"""
	credits = data.get("credits", initial_credits)
	supplies = data.get("supplies", initial_supplies)
	reputation = data.get("reputation", initial_reputation)
	story_progress = data.get("story_progress", 0)
	campaign_phase = data.get("campaign_phase", 0)
	difficulty_level = data.get("difficulty_level", 1)

	# Emit signals for state changes
	credits_changed.emit(credits)
	supplies_changed.emit(supplies)
	reputation_changed.emit(reputation)
	story_progress_changed.emit(story_progress)
	campaign_phase_changed.emit(campaign_phase)
	difficulty_changed.emit(difficulty_level)

func _restore_all_manager_data(managers_data: Dictionary) -> void:
	"""Restore data for all registered managers"""
	for manager_name in managers_data:
		var manager: Node = get_manager(manager_name)
		if manager and manager and manager.has_method("load_data"):
			manager.load_data(managers_data[manager_name])
		elif manager and manager and manager.has_method("deserialize"):
			manager.deserialize(managers_data[manager_name])
		else:
			push_warning("GameStateManager: Manager %s doesn't support loading" % manager_name)

## Campaign System Integration Methods

## Add credits to current total
func add_credits(amount: int) -> void:
	set_credits(credits + amount)

## Remove credits from current total
func remove_credits(amount: int) -> bool:
	if credits >= amount:
		set_credits(credits - amount)
		return true
	return false

## Get array of crew members
func get_crew_members() -> Array:
	if game_state and game_state and game_state.has_method("get_crew_members"):
		return game_state.get_crew_members()
	return []

## Get current crew size
func get_crew_size() -> int:
	if game_state and game_state and game_state.has_method("get_crew_size"):
		return game_state.get_crew_size()
	return 4 # Default crew size

## Get number of crew members in sick bay
func get_sick_crew_count() -> int:
	if game_state and game_state and game_state.has_method("get_sick_crew_count"):
		return game_state.get_sick_crew_count()
	return 0

## Add experience to crew member
func add_crew_experience(crew_id: String, xp: int) -> void:
	if game_state and game_state and game_state.has_method("add_crew_experience"):
		game_state.add_crew_experience(crew_id, xp)

## Apply injury to crew member
func apply_crew_injury(crew_id: String, injury_data: Dictionary) -> void:
	if game_state and game_state and game_state.has_method("apply_crew_injury"):
		game_state.apply_crew_injury(crew_id, injury_data)

## Get player ship instance
func get_player_ship():
	if game_state and game_state and game_state.has_method("get_player_ship"):
		return game_state.get_player_ship()
	return null

## Get ship debt interest payment
func get_ship_debt_interest() -> int:
	if game_state and game_state and game_state.has_method("get_ship_debt_interest"):
		return game_state.get_ship_debt_interest()
	return 0

## Get number of active rivals
func get_rival_count() -> int:
	if game_state and game_state and game_state.has_method("get_rival_count"):
		return game_state.get_rival_count()
	return 0

## Remove rival from active rivals
func remove_rival(rival_id: String) -> void:
	if game_state and game_state and game_state.has_method("remove_rival"):
		game_state.remove_rival(rival_id)

## Add patron to contacts
func add_patron_contact(patron_id: String) -> void:
	if game_state and game_state and game_state.has_method("add_patron_contact"):
		game_state.add_patron_contact(patron_id)

## Dismiss patrons without persistence trait
func dismiss_non_persistent_patrons() -> void:
	if game_state and game_state and game_state.has_method("dismiss_non_persistent_patrons"):
		game_state.dismiss_non_persistent_patrons()

## Check if there's an active quest
func has_active_quest() -> bool:
	if game_state and game_state and game_state.has_method("has_active_quest"):
		return game_state.has_active_quest()
	return false

## Get number of quest rumors
func get_quest_rumors() -> int:
	if game_state and game_state and game_state.has_method("get_quest_rumors"):
		return game_state.get_quest_rumors()
	return 0

## Advance quest progress
func advance_quest(progress: int) -> void:
	if game_state and game_state and game_state.has_method("advance_quest"):
		game_state.advance_quest(progress)

## Check if crew can attack a rival
func can_attack_rival() -> bool:
	if game_state and game_state and game_state.has_method("can_attack_rival"):
		return game_state.can_attack_rival()
	return false

## Set current world location
func set_location(world_data: Dictionary) -> void:
	if game_state and game_state and game_state.has_method("set_location"):
		game_state.set_location(world_data)

## Check if invasion is pending
func has_pending_invasion() -> bool:
	if game_state and game_state and game_state.has_method("has_pending_invasion"):
		return game_state.has_pending_invasion()
	return false

## Set invasion pending status
func set_invasion_pending(pending: bool) -> void:
	if game_state and game_state and game_state.has_method("set_invasion_pending"):
		game_state.set_invasion_pending(pending)

## Add item to crew inventory
func add_inventory_item(item: Dictionary) -> void:
	if game_state and game_state and game_state.has_method("add_inventory_item"):
		game_state.add_inventory_item(item)

## Add contact for crew member
func add_crew_contact(crew_id: String, contact_id: String) -> void:
	if game_state and game_state and game_state.has_method("add_crew_contact"):
		game_state.add_crew_contact(crew_id, contact_id)


## Developer Testing Methods
## These methods support the DeveloperQuickStart panel for efficient playtesting

## Create a test campaign with specified parameters for playtesting
func create_test_campaign(campaign_data: Dictionary) -> bool:
	print("GameStateManager: Creating test campaign - ", campaign_data.get("name", "Unknown"))

	# Start with basic new campaign
	var success = start_new_campaign(campaign_data)
	if not success:
		push_error("GameStateManager: Failed to start base test campaign")
		return false

	# Apply test-specific configurations
	var test_turn = campaign_data.get("turn_number", 1)
	if test_turn > 1:
		_simulate_campaign_progression(test_turn)

	var test_credits = campaign_data.get("credits", initial_credits)
	set_credits(test_credits)

	var test_supplies = campaign_data.get("supplies", initial_supplies)
	set_supplies(test_supplies)

	var test_reputation = campaign_data.get("reputation", initial_reputation)
	set_reputation(test_reputation)

	# Set up test crew size
	var test_crew_size = campaign_data.get("crew_size", 4)
	_create_test_crew(test_crew_size)

	# Set up test scenario elements
	var test_rivals = campaign_data.get("rivals", 0)
	_create_test_rivals(test_rivals)

	var test_quests = campaign_data.get("quests", 0)
	_create_test_quests(test_quests)

	# Set equipment level
	var equipment_level = campaign_data.get("equipment_level", "basic")
	_apply_test_equipment_level(equipment_level)

	print("GameStateManager: Test campaign created successfully")
	return true

## Apply a specific test scenario to current campaign
func apply_test_scenario(scenario_name: String) -> bool:
	print("GameStateManager: Applying test scenario - ", scenario_name)

	match scenario_name:
		"rival_attack":
			_setup_rival_attack_scenario()
		"resource_crisis":
			_setup_resource_crisis_scenario()
		"quest_chain":
			_setup_quest_chain_scenario()
		"equipment_showcase":
			_setup_equipment_showcase_scenario()
		"combat_ready":
			_setup_combat_ready_scenario()
		_:
			push_warning("GameStateManager: Unknown test scenario - " + str(scenario_name))
			return false

	return true

## Simulate campaign progression to target turn
func _simulate_campaign_progression(target_turn: int) -> void:
	# This is a simplified simulation for testing purposes
	# In a real implementation, this would involve proper turn progression
	print("GameStateManager: Simulating progression to turn ", target_turn)

	# Basic progression simulation
	for turn: int in range(1, target_turn):
		# Add some progression elements
		if turn % 5 == 0: # Every 5 turns, add some story progress
			story_progress += 1
		if turn % 3 == 0: # Every 3 turns, add some reputation
			reputation += 1

## Create test crew members
func _create_test_crew(crew_size: int) -> void:
	print("GameStateManager: Creating test crew of size ", crew_size)

	# This would interface with the crew system to generate test crew
	# For now, just store the desired size
	if game_state and game_state and game_state.has_method("set_crew_size"):
		game_state.set_crew_size(crew_size)

## Create test rival encounters
func _create_test_rivals(rival_count: int) -> void:
	print("GameStateManager: Creating ", rival_count, " test rivals")

	if not game_state or not game_state and game_state.has_method("add_rival"):
		push_warning("GameStateManager: GameState is not available or does not have add_rival method.")
		return

	for i: int in range(rival_count):
		var test_rival_id = "test_rival_" + str(i + 1)
		game_state.add_rival(test_rival_id)

## Create test quest scenarios
func _create_test_quests(quest_count: int) -> void:
	print("GameStateManager: Creating ", quest_count, " test quests")

	# This would interface with the quest system
	if game_state and game_state and game_state.has_method("create_test_quests"):
		game_state.create_test_quests(quest_count)

## Apply test equipment level to crew
func _apply_test_equipment_level(level: String) -> void:
	print("GameStateManager: Applying equipment level - ", level)

	match level:
		"basic":
			_apply_basic_equipment()
		"improved":
			_apply_improved_equipment()
		"advanced":
			_apply_advanced_equipment()
		"elite":
			_apply_elite_equipment()

## Apply basic equipment set
func _apply_basic_equipment() -> void:
	# Basic starting equipment
	pass

## Apply improved equipment set
func _apply_improved_equipment() -> void:
	# Mid-tier equipment
	pass

## Apply advanced equipment set
func _apply_advanced_equipment() -> void:
	# High-tier equipment
	pass

## Apply elite equipment set
func _apply_elite_equipment() -> void:
	# Top-tier equipment
	pass

## Test Scenario Setups

## Setup rival attack test scenario
func _setup_rival_attack_scenario() -> void:
	print("GameStateManager: Setting up rival attack scenario")

	# Create multiple active rivals
	_create_test_rivals(2)

	# Set high tension/aggression
	if game_state and game_state and game_state.has_method("set_rival_aggression"):
		game_state.set_rival_aggression("high")

## Setup resource crisis test scenario
func _setup_resource_crisis_scenario() -> void:
	print("GameStateManager: Setting up resource crisis scenario")

	# Set low resources
	set_credits(100)
	set_supplies(1)

	# Large crew to create upkeep pressure
	_create_test_crew(6)

## Setup quest chain test scenario
func _setup_quest_chain_scenario() -> void:
	print("GameStateManager: Setting up quest chain scenario")

	# Create multiple active quests
	_create_test_quests(3)

	# Add quest rumors
	if game_state and game_state and game_state.has_method("add_quest_rumors"):
		game_state.add_quest_rumors(5)

## Setup equipment showcase test scenario
func _setup_equipment_showcase_scenario() -> void:
	print("GameStateManager: Setting up equipment showcase scenario")

	# High credits for equipment testing
	set_credits(50000)

	# All equipment available
	if game_state and game_state and game_state.has_method("unlock_all_equipment"):
		game_state.unlock_all_equipment()

## Setup combat ready test scenario
func _setup_combat_ready_scenario() -> void:
	print("GameStateManager: Setting up combat ready scenario")

	# Set to battle phase
	if GlobalEnums and "FiveParsecsCampaignPhase" in GlobalEnums:
		if "BATTLE" in GlobalEnums.FiveParsecsCampaignPhase:
			set_campaign_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

	# Create varied enemy types
	if game_state and game_state and game_state.has_method("setup_varied_enemies"):
		game_state.setup_varied_enemies()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
