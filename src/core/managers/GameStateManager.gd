# Universal Connection Validation Applied - Enhanced with 7-Stage Methodology
# Based on proven patterns: Universal Mock Strategy + Complete Warning Elimination
extends Node

# Stage 1: Enhanced Universal imports with comprehensive safety patterns

# Safe dependency loading - GameState accessed as autoload
# GlobalEnums available as autoload singleton

# Stage 2: Enhanced signal definitions with comprehensive type safety
signal game_state_changed(new_state)
signal campaign_phase_changed(new_phase: int)
signal difficulty_changed(new_difficulty: int)
signal credits_changed(new_amount: int)
signal debt_changed(new_amount: int)
signal ship_seized_due_to_debt()
signal supplies_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal story_progress_changed(new_amount: int)
signal manager_registered(manager_name: String)
signal manager_unregistered(manager_name: String)
signal state_save_completed(success: bool)
signal state_load_completed(success: bool)
signal state_changed()

# Stage 3: Enhanced exported variables with comprehensive validation
@export var initial_credits: int = 1000
@export var initial_supplies: int = 5
@export var initial_reputation: int = 0
@export var enable_debug_logging: bool = false
@export var auto_save_interval: float = 300.0 # 5 minutes

# ============================================================================
# STANDARDIZED TEMP DATA KEYS - Use these constants for consistency
# ============================================================================
const TEMP_KEY_SELECTED_CHARACTER = "selected_character"
const TEMP_KEY_EDIT_MODE = "edit_mode"
const TEMP_KEY_RETURN_SCREEN = "return_screen"
const TEMP_KEY_CREW_ADD_MODE = "crew_add_mode"
const TEMP_KEY_NAVIGATION_CONTEXT = "navigation_context"

# Core state variables with enhanced type safety
var game_state: Node = null
var current_campaign: Resource = null  # Reference to active campaign data
var campaign_phase: int = 0 # Will be set to NONE enum value in _ready()
var difficulty_level: int = 1 # Will be set to NORMAL enum value in _ready()
var credits: int = initial_credits
var campaign_debt: int = 0  # Five Parsecs debt system - ship seized at 75 credits
var supplies: int = initial_supplies
var reputation: int = initial_reputation
var story_progress: int = 0
var victory_conditions: Dictionary = {}  # Victory condition configuration
var ship_seized: bool = false  # Ship seizure flag for debt system

# Debt system constants (Five Parsecs Core Rules)
const SHIP_SEIZURE_THRESHOLD: int = 75  # Credits of debt before ship is seized

# Manager registration system for cross-system communication
var registered_managers: Dictionary = {}

# Internal state tracking
var _initialization_complete: bool = false
var _dependencies_loaded: bool = false
var _auto_save_timer: Timer = null
var _campaign_modified: bool = false

# Temporary data storage for UI navigation and state
var temp_data: Dictionary = {}

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

## Helper function to safely access GlobalEnums autoload
func _get_global_enums():
	"""Safe access to GlobalEnums autoload to avoid compilation errors"""
	return get_node_or_null("/root/GlobalEnums")

## Stage 1: Enhanced dependency loading with comprehensive validation
func _load_dependencies_safe() -> bool:
	"""Validate preloaded dependencies"""

	# Validate GlobalEnums autoload (safe runtime check)
	var global_enums = _get_global_enums()
	if not global_enums:
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

	var global_enums = _get_global_enums()
	if not global_enums:
		push_error("GameStateManager: Cannot initialize enum values - GlobalEnums not loaded")
		return

	# Set default campaign phase to NONE if available
	if global_enums and "FiveParsecsCampaignPhase" in global_enums:
		if "NONE" in global_enums.FiveParsecsCampaignPhase:
			campaign_phase = global_enums.FiveParsecsCampaignPhase.NONE
			print("GameStateManager: Campaign phase set to NONE")
		else:
			push_warning("GameStateManager: NONE not found in FiveParsecsCampaignPhase enum")
	else:
		push_warning("GameStateManager: FiveParsecsCampaignPhase enum not found in GlobalEnums")

	# Set default difficulty to STANDARD if available
	if global_enums and "DifficultyLevel" in global_enums:
		if "STANDARD" in global_enums.DifficultyLevel:
			difficulty_level = global_enums.DifficultyLevel.STANDARD
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
	var global_enums = _get_global_enums()
	if not global_enums:
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
	# Register this manager with global GameState autoload if available
	var global_game_state = get_node_or_null("/root/GameState")
	if global_game_state and global_game_state.has_method("register_manager"):
		global_game_state.register_manager("GameStateManager", self)
		print("GameStateManager: Successfully registered with global GameState")
	else:
		# Register with local game state instead
		if game_state and game_state.has_method("register_manager"):
			game_state.register_manager("GameStateManager", self)
			print("GameStateManager: Registered with local game state")
		else:
			print("GameStateManager: No GameState available for registration")

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

	# Connect to GameState autoload instead of creating new instance
	game_state = get_node_or_null("/root/GameState")
	if game_state:
		print("GameStateManager: Connected to GameState autoload")
		# Initialize the game state with current values
		_sync_state_to_game_state()
	else:
		push_error("CRASH PREVENTION: Failed to connect to GameState autoload")

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
	var global_enums = _get_global_enums()
	if game_state.has_method("set_resource") and global_enums and "ResourceType" in global_enums:
		if "CREDITS" in global_enums.ResourceType:
			game_state.set_resource(global_enums.ResourceType.CREDITS, credits)
		if "SUPPLIES" in global_enums.ResourceType:
			game_state.set_resource(global_enums.ResourceType.SUPPLIES, supplies)

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
		print("GameStateManager: Deferring credits setting until initialization complete: %d" % new_amount)
		# Store the value to set after initialization
		call_deferred("_set_credits_after_init", new_amount)
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

func _set_credits_after_init(amount: int) -> void:
	"""Set credits after initialization is complete"""
	if _initialization_complete:
		set_credits(amount)
	else:
		# Still not ready, try again later
		call_deferred("_set_credits_after_init", amount)

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
		var old_reputation = reputation
		reputation = new_amount

		# Sync to game state if available
		_sync_reputation_to_game_state()

		if enable_debug_logging:
			print("GameStateManager: Reputation changed from %d to %d" % [old_reputation, reputation])

## Add to reputation (convenience function)
func add_reputation(amount: int) -> void:
	set_reputation(reputation + amount)

## Add to supplies (convenience function)  
func add_supplies(amount: int) -> void:
	set_supplies(supplies + amount)

## Add to story progress (convenience function)
func add_story_progress(amount: int) -> void:
	set_story_progress(story_progress + amount)

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

## Set victory conditions for campaign
func set_victory_conditions(conditions: Dictionary) -> void:
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set victory_conditions before initialization complete")
		return

	victory_conditions = conditions.duplicate()
	if current_campaign and "victory_conditions" in current_campaign:
		current_campaign.victory_conditions = conditions.duplicate()
	state_changed.emit()
	if enable_debug_logging:
		print("GameStateManager: Set victory_conditions with %d conditions" % conditions.size())

## Get victory conditions for campaign
func get_victory_conditions() -> Dictionary:
	return victory_conditions.duplicate()

## Set ship debt (updates ship resource and emits state_changed)
func set_ship_debt(debt: int) -> void:
	if not is_instance_valid(self):
		return
	var ship = get_player_ship()
	if ship:
		ship.debt = debt
		state_changed.emit()
		if enable_debug_logging:
			print("GameStateManager: Ship debt set to %d credits" % debt)

## Set story track enabled setting
func set_story_track_enabled(enabled: bool) -> void:
	if not is_instance_valid(self):
		return
	if current_campaign:
		current_campaign.set_meta("story_track_enabled", enabled)
	state_changed.emit()
	if enable_debug_logging:
		print("GameStateManager: Story track %s" % ("enabled" if enabled else "disabled"))

## Get story track enabled setting
func get_story_track_enabled() -> bool:
	if current_campaign and current_campaign.has_meta("story_track_enabled"):
		return current_campaign.get_meta("story_track_enabled")
	return true  # Default enabled

## Set custom victory targets (stores in victory_conditions dict)
func set_custom_victory_targets(targets: Dictionary) -> void:
	if not is_instance_valid(self):
		return
	if not victory_conditions.has("custom_targets"):
		victory_conditions["custom_targets"] = {}
	victory_conditions["custom_targets"] = targets.duplicate()
	if current_campaign and "victory_conditions" in current_campaign:
		if not current_campaign.victory_conditions.has("custom_targets"):
			current_campaign.victory_conditions["custom_targets"] = {}
		current_campaign.victory_conditions["custom_targets"] = targets.duplicate()
	state_changed.emit()
	if enable_debug_logging:
		print("GameStateManager: Custom victory targets set for %d conditions" % targets.size())

## Set patrons list for campaign
func set_patrons(patron_list: Array) -> void:
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set patrons before initialization complete")
		return

	if current_campaign:
		current_campaign.patrons = patron_list.duplicate()
		state_changed.emit()
		if enable_debug_logging:
			print("GameStateManager: Set %d patrons" % patron_list.size())

## Set rivals list for campaign
func set_rivals(rival_list: Array) -> void:
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set rivals before initialization complete")
		return

	if current_campaign:
		current_campaign.rivals = rival_list.duplicate()
		state_changed.emit()
		if enable_debug_logging:
			print("GameStateManager: Set %d rivals" % rival_list.size())

## Set quest rumors count for campaign
func set_quest_rumors(count: int) -> void:
	if not is_instance_valid(self):
		return
	if not _initialization_complete:
		push_warning("GameStateManager: Attempting to set quest rumors before initialization complete")
		return

	if count < 0:
		push_warning("GameStateManager: Cannot set negative quest rumors: %d" % count)
		count = 0

	if current_campaign:
		current_campaign.quest_rumors = count
		state_changed.emit()
		if enable_debug_logging:
			print("GameStateManager: Set quest rumors to %d" % count)

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

	var global_enums = _get_global_enums()
	if not global_enums or not "FiveParsecsCampaignPhase" in global_enums:
		push_warning("GameStateManager: Cannot validate campaign phase - GlobalEnums not available")
		return true # Allow if we can't validate

	var phase_enum = global_enums.FiveParsecsCampaignPhase

	# Check if phase is within valid enum range
	var valid_phases: Array = []
	for phase_name in phase_enum:
		@warning_ignore("return_value_discarded")
		valid_phases.append(phase_enum[phase_name])

	return phase in valid_phases

## Validate difficulty level
func _validate_difficulty_level(level: int) -> bool:
	"""Validate that a difficulty level value is valid"""

	var global_enums = _get_global_enums()
	if not global_enums or not "DifficultyLevel" in global_enums:
		push_warning("GameStateManager: Cannot validate difficulty level - GlobalEnums not available")
		return true # Allow if we can't validate

	var difficulty_enum = global_enums.DifficultyLevel

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

	var global_enums = _get_global_enums()
	if game_state.has_method("set_resource") and global_enums and "ResourceType" in global_enums:
		if "CREDITS" in global_enums.ResourceType:
			game_state.set_resource(global_enums.ResourceType.CREDITS, credits)
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

	var global_enums = _get_global_enums()
	if game_state.has_method("set_resource") and global_enums and "ResourceType" in global_enums:
		if "SUPPLIES" in global_enums.ResourceType:
			game_state.set_resource(global_enums.ResourceType.SUPPLIES, supplies)
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

## Campaign Resource Accessors (for UI display of rulebook-accurate data)
func get_patrons() -> Array:
	"""Get list of patrons (from character creation or campaign events)"""
	if game_state and game_state.current_campaign and "patrons" in game_state.current_campaign:
		return game_state.current_campaign.patrons
	return []

func get_rivals() -> Array:
	"""Get list of rivals (from character creation or campaign events)"""
	if game_state and game_state.current_campaign and "rivals" in game_state.current_campaign:
		return game_state.current_campaign.rivals
	return []

## Note: get_quest_rumors() already exists at line 1062 - no duplicate needed

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
		var global_enums = _get_global_enums()
		if game_state.has_method("set_resource") and global_enums and "ResourceType" in global_enums:
			if "CREDITS" in global_enums.ResourceType:
				game_state.set_resource(global_enums.ResourceType.CREDITS, initial_credits)
			if "SUPPLIES" in global_enums.ResourceType:
				game_state.set_resource(global_enums.ResourceType.SUPPLIES, initial_supplies)

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
		"difficulty_level": difficulty_level,
		"victory_conditions": victory_conditions  # Contains custom_targets within it
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
	victory_conditions = data.get("victory_conditions", {})  # Contains custom_targets within it

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

## Debt Management System (Five Parsecs Core Rules)

## Add debt to campaign total
func add_debt(amount: int) -> void:
	if amount <= 0:
		return
	
	var old_debt: int = campaign_debt
	campaign_debt += amount
	
	print("GameStateManager: Debt increased by %d credits (total: %d)" % [amount, campaign_debt])
	debt_changed.emit(campaign_debt)
	_mark_campaign_modified()
	
	# Check for ship seizure threshold
	if campaign_debt >= SHIP_SEIZURE_THRESHOLD and not ship_seized:
		_trigger_ship_seizure()

## Pay down debt
func pay_debt(amount: int) -> bool:
	if amount <= 0:
		return false
	
	var payment: int = mini(amount, campaign_debt)
	
	if credits >= payment:
		remove_credits(payment)
		campaign_debt -= payment
		
		print("GameStateManager: Paid %d credits toward debt (remaining: %d)" % [payment, campaign_debt])
		debt_changed.emit(campaign_debt)
		_mark_campaign_modified()
		return true
	
	return false

## Get current debt
func get_debt() -> int:
	return campaign_debt

## Check if ship is seized
func is_ship_seized() -> bool:
	return ship_seized

## Trigger ship seizure due to excessive debt
func _trigger_ship_seizure() -> void:
	ship_seized = true
	print("GameStateManager: ❌ SHIP SEIZED - Debt reached %d credits (threshold: %d)" % [campaign_debt, SHIP_SEIZURE_THRESHOLD])
	ship_seized_due_to_debt.emit()
	
	# Campaign effectively ends when ship is seized
	# This would typically trigger a game over or forced debt payment scenario

## Get array of crew members
func get_crew_members() -> Array:
	if game_state and game_state and game_state.has_method("get_crew_members"):
		return game_state.get_crew_members()
	return []

## Mark campaign as modified (triggers auto-save if enabled)
func _mark_campaign_modified() -> void:
	# Mark campaign as modified for save tracking
	if game_state:
		# Could trigger auto-save here if needed
		pass

## Enhanced state persistence methods
func auto_save_current_state() -> bool:
	# Perform automatic save with error handling
	print("GameStateManager: Performing auto-save...")
	var success = save_current_state()

	if success:
		print("GameStateManager: Auto-save completed successfully")
	else:
		push_warning("GameStateManager: Auto-save failed")

	state_save_completed.emit(success)
	return success

func create_state_backup() -> bool:
	"""Create a backup of current state"""
	var timestamp = Time.get_unix_time_from_system()
	var backup_name = "backup_%d" % timestamp
	
	# Collect all manager data
	var backup_data = _collect_all_manager_data()
	
	# Get SaveManager for backup operations
	var save_manager: Node = get_manager("SaveManager")
	if save_manager and save_manager.has_method("save_game"):
		var success = save_manager.save_game(backup_data, backup_name)
		print("GameStateManager: State backup created: %s" % backup_name)
		return success
	else:
		push_warning("GameStateManager: No save system available for backup")
		return false

func restore_from_backup(backup_name: String) -> bool:
	"""Restore state from a backup"""
	print("GameStateManager: Restoring from backup: %s" % backup_name)
	var success = load_saved_state(backup_name)
	
	if success:
		print("GameStateManager: Backup restoration completed")
	else:
		push_error("GameStateManager: Failed to restore from backup")
	
	state_load_completed.emit(success)
	return success

func validate_current_state() -> Dictionary:
	"""Validate the current game state for consistency"""
	var validation_result = {
		"valid": true,
		"errors": [],
		"warnings": [],
		"state_summary": {}
	}
	
	# Validate basic state values
	if credits < 0:
		validation_result.errors.append("Credits cannot be negative")
		validation_result.valid = false
	
	if supplies < 0:
		validation_result.errors.append("Supplies cannot be negative")
		validation_result.valid = false
	
	if story_progress < 0 or story_progress > 100:
		validation_result.warnings.append("Story progress seems out of normal range")
	
	# Validate campaign phase
	if campaign_phase < 0 or campaign_phase > 4:
		validation_result.errors.append("Invalid campaign phase")
		validation_result.valid = false
	
	# Collect state summary
	validation_result.state_summary = {
		"credits": credits,
		"supplies": supplies,
		"reputation": reputation,
		"story_progress": story_progress,
		"campaign_phase": campaign_phase,
		"difficulty_level": difficulty_level,
		"registered_managers": registered_managers.keys(),
		"has_active_campaign": has_active_campaign()
	}
	
	print("GameStateManager: State validation completed - Valid: %s" % validation_result.valid)
	return validation_result

func reset_to_defaults() -> void:
	"""Reset state to default values"""
	print("GameStateManager: Resetting to default state")
	
	credits = initial_credits
	supplies = initial_supplies
	reputation = initial_reputation
	story_progress = 0
	var global_enums = _get_global_enums()
	campaign_phase = global_enums.FiveParsecsCampaignPhase.NONE if global_enums else 0
	difficulty_level = 1
	
	# Emit all change signals
	credits_changed.emit(credits)
	supplies_changed.emit(supplies)
	reputation_changed.emit(reputation)
	story_progress_changed.emit(story_progress)
	campaign_phase_changed.emit(campaign_phase)
	difficulty_changed.emit(difficulty_level)
	
	print("GameStateManager: State reset completed")

func get_save_file_info(save_name: String = "current_campaign") -> Dictionary:
	"""Get information about a save file"""
	var save_manager: Node = get_manager("SaveManager")
	if save_manager and save_manager.has_method("get_save_info"):
		return save_manager.get_save_info(save_name)
	
	# Fallback info
	return {
		"exists": false,
		"save_name": save_name,
		"timestamp": 0,
		"size": 0,
		"version": "unknown"
	}

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

## Get pending deferred events
func get_pending_events() -> Array:
	if not game_state:
		return []
	var campaign = game_state.get("current_campaign")
	if not campaign:
		return []
	if campaign is Resource and "pending_events" in campaign:
		return campaign.pending_events
	elif campaign is Dictionary:
		return campaign.get("pending_events", [])
	return []

## Get pending events filtered by trigger type
func get_pending_events_by_trigger(trigger_type: String) -> Array:
	var all_events = get_pending_events()
	var filtered: Array = []
	for event in all_events:
		if event.get("trigger_type", "") == trigger_type and not event.get("consumed", false):
			filtered.append(event)
	return filtered

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


# ============================================================================
# CHARACTER CREATION MODIFIER TABLES (Rulebook pp.24-28)
# ============================================================================
# These tables define stat bonuses, equipment, and resources from Background/Motivation/Class rolls

const BACKGROUND_MODIFIERS = {
	# Official Five Parsecs Rulebook Backgrounds:
	"PEACEFUL_HIGH_TECH_COLONY": {"stat_bonus": {"savvy": 1}, "equipment": ["HIGH_TECH_WEAPON"], "credits_dice": "1d6"},
	"OVERCROWDED_DYSTOPIAN_CITY": {"stat_bonus": {"toughness": 1}, "equipment": ["LOW_TECH_WEAPON"]},
	"LOW_TECH_COLONY": {"stat_bonus": {}, "equipment": ["LOW_TECH_WEAPON"], "starting_rolls": {"gear": 1}},
	"MINING_COLONY": {"stat_bonus": {"toughness": 1}, "equipment": [], "credits": 0},
	"MILITARY_BRAT": {"stat_bonus": {"combat": 1}, "equipment": [], "credits": 0},
	"SPACE_STATION": {"stat_bonus": {}, "starting_rolls": {"gear": 1}},
	"MILITARY_OUTPOST": {"stat_bonus": {"combat": 1}, "equipment": ["MILITARY_WEAPON"]},
	"DRIFTER": {"stat_bonus": {}, "starting_rolls": {"gear": 1}},
	"LOWER_MEGACITY_CLASS": {"stat_bonus": {"reactions": 1}, "equipment": ["LOW_TECH_WEAPON"]},
	"WEALTHY_MERCHANT": {"stat_bonus": {}, "credits_dice": "2d6"},
	"FRONTIER_GANG": {"stat_bonus": {"combat": 1}, "equipment": []},
	"RELIGIOUS_CULT": {"stat_bonus": {}, "resources": {"patron": true, "story_points": 1}},
	# Custom/Expansion Backgrounds:
	"TECH_GUILD": {"stat_bonus": {"savvy": 1}, "equipment": ["HIGH_TECH_WEAPON"], "credits_dice": "1d6"},
	"WAR_TORN": {"stat_bonus": {"reactions": 1}, "equipment": ["MILITARY_WEAPON"]},
	"ORPHAN": {"stat_bonus": {}, "resources": {"patron": true, "story_points": 1}}
}

const MOTIVATION_MODIFIERS = {
	# Official Five Parsecs Rulebook Motivations:
	"WEALTH": {"stat_bonus": {}, "credits_dice": "1d6"},
	"FAME": {"stat_bonus": {}, "resources": {"patron": true, "xp": 1}},
	"GLORY": {"stat_bonus": {"combat": 1}, "equipment": ["MILITARY_WEAPON"]},
	"SURVIVAL": {"stat_bonus": {"toughness": 1}},
	"ESCAPE": {"stat_bonus": {"speed": 1}},
	"ADVENTURE": {"stat_bonus": {}, "credits_dice": "1d6", "equipment": ["LOW_TECH_WEAPON"]},
	"TRUTH": {"stat_bonus": {"savvy": 1}, "resources": {"xp": 1}},
	"TECHNOLOGY": {"stat_bonus": {"savvy": 1}, "starting_rolls": {"gadget": 1}},
	"DISCOVERY": {"stat_bonus": {}, "resources": {"xp": 2}, "starting_rolls": {"gear": 1}},
	# Custom/Expansion Motivations:
	"REVENGE": {"stat_bonus": {}, "resources": {"xp": 2, "rival": true}},
	"KNOWLEDGE": {"stat_bonus": {"savvy": 1}, "resources": {"xp": 1}},
	"POWER": {"stat_bonus": {}, "resources": {"xp": 2, "rival": true}},
	"JUSTICE": {"stat_bonus": {}, "resources": {"patron": true, "story_points": 1}},
	"LOYALTY": {"stat_bonus": {}, "resources": {"patron": true, "story_points": 1}},
	"FREEDOM": {"stat_bonus": {}, "resources": {"xp": 2}},
	"REDEMPTION": {"stat_bonus": {}, "resources": {"xp": 1, "story_points": 1}},
	"DUTY": {"stat_bonus": {}, "resources": {"patron": true}}
}

const CLASS_MODIFIERS = {
	# Official Five Parsecs Rulebook Classes:
	"WORKING_CLASS": {"stat_bonus": {"savvy": 1, "luck": 1}},
	"TECHNICIAN": {"stat_bonus": {"savvy": 1}, "starting_rolls": {"gear": 1}},
	"SCIENTIST": {"stat_bonus": {"savvy": 1}, "starting_rolls": {"gadget": 1}},
	"HACKER": {"stat_bonus": {"savvy": 1, "tech": 1}, "starting_rolls": {"gadget": 1}},
	"SOLDIER": {"stat_bonus": {"combat": 1}, "credits_dice": "1d6"},
	"MERCENARY": {"stat_bonus": {"combat": 1}, "equipment": ["MILITARY_WEAPON"]},
	"AGITATOR": {"stat_bonus": {"reactions": 1}, "resources": {"story_points": 1, "rival": true}},
	"PRIMITIVE": {"stat_bonus": {"toughness": 1}, "equipment": ["LOW_TECH_WEAPON"]},
	"ARTIST": {"stat_bonus": {"luck": 1}, "credits_dice": "1d6"},
	# GameStateManager Custom Classes:
	"NEGOTIATOR": {"stat_bonus": {}, "resources": {"patron": true, "story_points": 1}},
	"SCAVENGER": {"stat_bonus": {}, "equipment": ["HIGH_TECH_WEAPON"], "resources": {"rumors": 1}},
	"GANGER": {"stat_bonus": {"reactions": 1}, "equipment": ["LOW_TECH_WEAPON"]},
	"TRADER": {"stat_bonus": {}, "credits_dice": "2d6"},
	"EXPLORER": {"stat_bonus": {}, "resources": {"xp": 2}, "starting_rolls": {"gear": 1}}
}


## Developer Testing Methods
## These methods support the DeveloperQuickStart panel for efficient playtesting

## Create a test campaign with specified parameters for playtesting
func create_test_campaign(campaign_data: Dictionary) -> bool:
	print("GameStateManager: Creating test campaign - ", campaign_data.get("name", "Unknown"))

	# CRITICAL FIX: Create FiveParsecsCampaign instance first
	if not game_state:
		_initialize_game_state_safe()

	# Create new campaign instance using FiveParsecsCampaign
	const FiveParsecsCampaign = preload("res://src/core/campaign/Campaign.gd")
	var new_campaign = FiveParsecsCampaign.new()
	new_campaign.campaign_name = campaign_data.get("name", "Test Campaign")
	new_campaign.difficulty = campaign_data.get("difficulty", 1)
	new_campaign.crew_size = campaign_data.get("crew_size", 4)

	# Set campaign in GameState
	if game_state and "current_campaign" in game_state:
		game_state.current_campaign = new_campaign
		print("GameStateManager: Campaign instance created and assigned to GameState")
	else:
		push_error("GameStateManager: GameState doesn't support current_campaign property")
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

	# Create test ship
	_create_test_ship(campaign_data.get("ship_name", "Test Ship"))

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

## Create test crew members with full rulebook-accurate modifiers
func _create_test_crew(crew_size: int) -> void:
	print("GameStateManager: Creating rulebook-accurate test crew of size ", crew_size)

	if not game_state:
		push_error("GameStateManager: Cannot create crew - game_state not available")
		return

	# Initialize campaign resources accumulator
	var campaign_resources = {
		"credits": crew_size,  # Base: 1 credit per crew member (rulebook p.29)
		"story_points": 0,
		"patrons": [],
		"rivals": [],
		"quest_rumors": 0
	}

	# Generate crew equipment pool (rulebook p.29: 3 military, 3 low-tech, 1 gear, 1 gadget)
	var equipment_pool = _generate_crew_equipment_pool()

	# Create crew members with full modifiers
	var test_crew: Array = []
	var test_names: Array[String] = ["Alex", "Jordan", "Casey", "Riley", "Morgan", "Taylor"]

	for i in range(crew_size):
		var character = _generate_character_with_modifiers(test_names[i % test_names.size()])

		# Accumulate campaign resources from character creation
		campaign_resources.credits += character.get("creation_credits", 0)
		campaign_resources.story_points += character.get("creation_story_points", 0)
		campaign_resources.quest_rumors += character.get("creation_rumors", 0)

		if character.get("has_patron", false):
			campaign_resources.patrons.append({"name": "Patron %d" % (i+1), "type": "creation"})
		if character.get("has_rival", false):
			campaign_resources.rivals.append({"name": "Rival %d" % (i+1), "type": "creation"})

		# Add individual equipment bonuses to pool
		equipment_pool.append_array(character.get("bonus_equipment", []))

		test_crew.append(character)

	# Designate first character as Leader (gets +1 Luck per rulebook)
	if test_crew.size() > 0:
		test_crew[0]["luck"] = test_crew[0].get("luck", 0) + 1
		test_crew[0]["is_leader"] = true
		print("GameStateManager: %s designated as Leader (Luck +1)" % test_crew[0].get("character_name", "Unknown"))

	# Distribute equipment from pool to crew
	_distribute_equipment_to_crew(test_crew, equipment_pool)

	# Convert to Character instances and set in campaign
	if "current_campaign" in game_state and game_state.current_campaign:
		const Character = preload("res://src/core/character/Character.gd")
		game_state.current_campaign.crew_members.clear()

		for crew_dict in test_crew:
			var character = Character.deserialize(crew_dict)

			if not character:
				push_error("GameStateManager: Failed to deserialize crew member: %s" % crew_dict.get("character_name", "Unknown"))
				continue

			game_state.current_campaign.crew_members.append(character)

		print("GameStateManager: Set %d crew members in current_campaign" % game_state.current_campaign.crew_members.size())

		# Set campaign-level resources
		set_credits(campaign_resources.credits)
		story_progress = campaign_resources.story_points

		# Store patrons/rivals/rumors in campaign (if properties exist)
		if "patrons" in game_state.current_campaign:
			game_state.current_campaign.patrons = campaign_resources.patrons
		if "rivals" in game_state.current_campaign:
			game_state.current_campaign.rivals = campaign_resources.rivals
		if "quest_rumors" in game_state.current_campaign:
			game_state.current_campaign.quest_rumors = campaign_resources.quest_rumors

		print("GameStateManager: Campaign resources - Credits: %d, Story Points: %d, Patrons: %d, Rivals: %d, Rumors: %d" % [
			campaign_resources.credits,
			campaign_resources.story_points,
			campaign_resources.patrons.size(),
			campaign_resources.rivals.size(),
			campaign_resources.quest_rumors
		])
	else:
		push_error("GameStateManager: current_campaign not available - cannot set crew")

## Create test ship
func _create_test_ship(ship_name: String = "Starlight") -> void:
	print("GameStateManager: Creating test ship: ", ship_name)

	if not game_state:
		push_error("GameStateManager: Cannot create ship - game_state not available")
		return

	# Create basic ship data
	var test_ship = {
		"name": ship_name,
		"hull_integrity": 100,
		"fuel": 100,
		"cargo_capacity": 20,
		"debt": 0
	}

	# Store ship in GameState.player_ship (simpler approach)
	if "player_ship" in game_state:
		game_state.player_ship = test_ship
		print("GameStateManager: Set ship data in GameState.player_ship")
	else:
		push_error("GameStateManager: player_ship property not found in GameState")

	print("GameStateManager: Created test ship '%s'" % ship_name)

## Create test rival encounters
func _create_test_rivals(rival_count: int) -> void:
	print("GameStateManager: Creating ", rival_count, " test rivals")

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: GameState or current_campaign is not available.")
		return

	# Store rivals directly in campaign.rivals array (no add_rival() method exists)
	if "rivals" in game_state.current_campaign:
		for i: int in range(rival_count):
			var test_rival_id = "test_rival_" + str(i + 1)
			game_state.current_campaign.rivals.append(test_rival_id)
			print("GameStateManager: Added rival '%s'" % test_rival_id)
	else:
		push_error("GameStateManager: current_campaign does not have 'rivals' property")

## Create test quest scenarios
func _create_test_quests(quest_count: int) -> void:
	print("GameStateManager: Creating ", quest_count, " test quests")

	# This would interface with the quest system
	if game_state and game_state and game_state.has_method("create_test_quests"):
		game_state.create_test_quests(quest_count)

## Apply test equipment level to crew
func _apply_test_equipment_level(level: String) -> void:
	print("GameStateManager: Applying equipment level: ", level)

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: No active campaign for equipment application")
		return

	# Define equipment tiers
	var equipment_tiers = {
		"basic": ["hand_gun", "blade", "light_armor"],
		"standard": ["military_rifle", "combat_armor", "frag_grenade", "med_kit"],
		"advanced": ["plasma_rifle", "powered_armor", "targeting_system", "combat_drone"]
	}

	var tier_items = equipment_tiers.get(level.to_lower(), equipment_tiers.basic)
	var crew_members = []
	if game_state.current_campaign and "crew_members" in game_state.current_campaign:
		crew_members = game_state.current_campaign.crew_members

	for i in range(crew_members.size()):
		var crew_member = crew_members[i]
		if crew_member is Dictionary:
			# Clear existing equipment and add tier-appropriate items
			crew_member["equipment"] = tier_items.duplicate()
			print("GameStateManager: Applied %s equipment to crew member %d" % [level, i])

	print("GameStateManager: Equipment level '%s' applied to %d crew members" % [level, crew_members.size()])

# ============================================================================
# RULEBOOK-ACCURATE CHARACTER GENERATION HELPERS
# ============================================================================

## Generate character with Background/Motivation/Class modifiers applied
func _generate_character_with_modifiers(char_name: String) -> Dictionary:
	"""Generate character with full Background/Motivation/Class modifiers applied per rulebook"""

	# Roll Background/Motivation/Class from available options
	var backgrounds = BACKGROUND_MODIFIERS.keys()
	var motivations = MOTIVATION_MODIFIERS.keys()
	var classes = CLASS_MODIFIERS.keys()

	var background = backgrounds[randi() % backgrounds.size()]
	var motivation = motivations[randi() % motivations.size()]
	var char_class = classes[randi() % classes.size()]

	# Base stats (Baseline Human per rulebook p.21)
	var character = {
		"character_name": char_name,
		"origin": "HUMAN",
		"background": background,
		"motivation": motivation,
		"class": char_class,
		"status": "ACTIVE",
		"reactions": 1,
		"speed": 4,
		"combat": 0,  # Rulebook: Combat Skill +0
		"toughness": 3,
		"savvy": 0,  # Rulebook: Savvy +0
		"luck": 0,  # Baseline: 0 (Leader gets +1)
		"experience": 0,
		"equipment": [],
		# Creation resources (accumulated, then moved to campaign level)
		"creation_credits": 0,
		"creation_story_points": 0,
		"creation_rumors": 0,
		"has_patron": false,
		"has_rival": false,
		"bonus_equipment": []
	}

	# Apply Background modifiers
	var bg_data = BACKGROUND_MODIFIERS[background]
	_apply_stat_bonuses(character, bg_data.get("stat_bonus", {}))
	_apply_equipment_bonuses(character, bg_data.get("equipment", []))
	_apply_resource_bonuses(character, bg_data)

	# Apply Motivation modifiers
	var mot_data = MOTIVATION_MODIFIERS[motivation]
	_apply_stat_bonuses(character, mot_data.get("stat_bonus", {}))
	_apply_equipment_bonuses(character, mot_data.get("equipment", []))
	_apply_resource_bonuses(character, mot_data)

	# Apply Class modifiers
	var class_data = CLASS_MODIFIERS[char_class]
	_apply_stat_bonuses(character, class_data.get("stat_bonus", {}))
	_apply_equipment_bonuses(character, class_data.get("equipment", []))
	_apply_resource_bonuses(character, class_data)

	print("GameStateManager: Generated %s - %s/%s/%s (C:%d R:%d T:%d Sv:%d L:%d)" % [
		char_name, background, motivation, char_class,
		character.combat, character.reactions, character.toughness, character.savvy, character.luck
	])

	return character

## Apply stat bonuses to character
func _apply_stat_bonuses(character: Dictionary, bonuses: Dictionary) -> void:
	for stat in bonuses.keys():
		character[stat] = character.get(stat, 0) + bonuses[stat]

## Apply equipment bonuses to character's equipment pool
func _apply_equipment_bonuses(character: Dictionary, equipment: Array) -> void:
	character["bonus_equipment"].append_array(equipment)

## Apply resource bonuses (credits, story points, XP, patrons, rivals, rumors)
func _apply_resource_bonuses(character: Dictionary, data: Dictionary) -> void:
	# Credits from dice rolls
	if "credits_dice" in data:
		character["creation_credits"] += _roll_dice_formula(data["credits_dice"])

	# Resources dict (story_points, xp, patron, rival, rumors)
	if "resources" in data:
		var resources = data["resources"]
		character["creation_story_points"] += resources.get("story_points", 0)
		character["experience"] += resources.get("xp", 0)
		character["creation_rumors"] += resources.get("rumors", 0)
		character["has_patron"] = character.get("has_patron", false) or resources.get("patron", false)
		character["has_rival"] = character.get("has_rival", false) or resources.get("rival", false)

## Simple dice roller for formulas like "1d6", "2d6"
func _roll_dice_formula(formula: String) -> int:
	var parts = formula.split("d")
	if parts.size() == 2:
		var num_dice = int(parts[0])
		var sides = int(parts[1])
		var total = 0
		for i in range(num_dice):
			total += randi() % sides + 1
		return total
	return 0

## Generate base crew equipment pool per rulebook (3 mil, 3 low, 1 gear, 1 gadget)
func _generate_crew_equipment_pool() -> Array:
	"""Generate base crew equipment pool per rulebook p.29"""
	var pool: Array = []

	# 3 Military Weapons
	var military_weapons = ["Infantry Laser", "Auto Rifle", "Military Rifle"]
	pool.append_array(military_weapons)

	# 3 Low-tech Weapons
	var lowtech_weapons = ["Handgun", "Colony Rifle", "Blade"]
	pool.append_array(lowtech_weapons)

	# 1 Gear item
	pool.append("Med-patch")

	# 1 Gadget item
	pool.append("Scanner Bot")

	return pool

## Distribute equipment from pool to crew members
func _distribute_equipment_to_crew(crew: Array, equipment_pool: Array) -> void:
	"""Distribute equipment from pool to crew members (simple round-robin)"""
	var equipment_index = 0

	for i in range(crew.size()):
		var character = crew[i]
		var equipment_list: Array = []

		# Give each character 1-2 items from pool
		var items_to_assign = min(2, equipment_pool.size() - equipment_index)
		for j in range(items_to_assign):
			if equipment_index < equipment_pool.size():
				equipment_list.append(equipment_pool[equipment_index])
				equipment_index += 1

		character["equipment"] = equipment_list

		print("GameStateManager: %s equipped with: %s" % [
			character.get("character_name", "Unknown"),
			", ".join(equipment_list) if equipment_list.size() > 0 else "none"
		])

	# Disabled until EquipmentManager is implemented
	#match level:
	#	"basic":
	#		_apply_basic_equipment()
	#	"improved":
	#		_apply_improved_equipment()
	#	"advanced":
	#		_apply_advanced_equipment()
	#	"elite":
	#		_apply_elite_equipment()

## Apply basic equipment set
func _apply_basic_equipment() -> void:
	"""Apply basic starting equipment for new campaigns"""
	var equipment_manager = get_manager("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("add_equipment"):
		# Basic Five Parsecs starting equipment
		equipment_manager.add_equipment({"name": "Scrap Pistol", "type": "weapon", "range": 12, "damage": 1, "traits": ["Pistol"]})
		equipment_manager.add_equipment({"name": "Blade", "type": "weapon", "range": 0, "damage": 1, "traits": ["Melee"]})
		equipment_manager.add_equipment({"name": "Basic Kit", "type": "gear", "traits": ["Utility"]})
		equipment_manager.add_equipment({"name": "Worn Clothing", "type": "armor", "save": 6, "traits": ["Basic"]})
		print("GameStateManager: Applied basic equipment set")
	else:
		print("GameStateManager: EquipmentManager not available for basic equipment")

## Apply improved equipment set
func _apply_improved_equipment() -> void:
	"""Apply improved equipment for experienced crews"""
	var equipment_manager = get_manager("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("add_equipment"):
		# Improved Five Parsecs equipment
		equipment_manager.add_equipment({"name": "Military Rifle", "type": "weapon", "range": 24, "damage": 1, "traits": ["Military"]})
		equipment_manager.add_equipment({"name": "Combat Armor", "type": "armor", "save": 5, "traits": ["Protection"]})
		equipment_manager.add_equipment({"name": "Analyzer", "type": "gadget", "traits": ["Tech"]})
		equipment_manager.add_equipment({"name": "Stims", "type": "consumable", "traits": ["Medical"]})
		equipment_manager.add_equipment({"name": "Credits Boost", "type": "special", "value": 1000})
		
		# Apply credits boost
		add_credits(1000)
		print("GameStateManager: Applied improved equipment set")
	else:
		print("GameStateManager: EquipmentManager not available for improved equipment")

## Apply advanced equipment set
func _apply_advanced_equipment() -> void:
	"""Apply advanced equipment for veteran crews"""
	var equipment_manager = get_manager("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("add_equipment"):
		# Advanced Five Parsecs equipment
		equipment_manager.add_equipment({"name": "Plasma Rifle", "type": "weapon", "range": 30, "damage": 2, "traits": ["Energy", "Military"]})
		equipment_manager.add_equipment({"name": "Power Armor", "type": "armor", "save": 4, "traits": ["Heavy", "Powered"]})
		equipment_manager.add_equipment({"name": "Shield Generator", "type": "gadget", "traits": ["Tech", "Defensive"]})
		equipment_manager.add_equipment({"name": "Advanced Medkit", "type": "gear", "traits": ["Medical", "Advanced"]})
		equipment_manager.add_equipment({"name": "Ship Upgrade", "type": "special", "value": 2500})
		
		# Apply credits and reputation boost
		add_credits(2500)
		add_reputation(10)
		print("GameStateManager: Applied advanced equipment set")
	else:
		print("GameStateManager: EquipmentManager not available for advanced equipment")

## Apply elite equipment set
func _apply_elite_equipment() -> void:
	"""Apply elite equipment for legendary crews"""
	var equipment_manager = get_manager("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("add_equipment"):
		# Elite Five Parsecs equipment
		equipment_manager.add_equipment({"name": "Fusion Cannon", "type": "weapon", "range": 36, "damage": 3, "traits": ["Energy", "Heavy", "Rare"]})
		equipment_manager.add_equipment({"name": "Exoskeleton", "type": "armor", "save": 3, "traits": ["Heavy", "Powered", "Elite"]})
		equipment_manager.add_equipment({"name": "AI Assistant", "type": "gadget", "traits": ["Tech", "AI", "Legendary"]})
		equipment_manager.add_equipment({"name": "Nano-medics", "type": "gear", "traits": ["Medical", "Nano", "Elite"]})
		equipment_manager.add_equipment({"name": "Elite Package", "type": "special", "value": 5000})
		
		# Apply major boosts
		add_credits(5000)
		add_reputation(25)
		add_supplies(10)
		
		# Unlock story progress
		add_story_progress(5)
		print("GameStateManager: Applied elite equipment set")
	else:
		print("GameStateManager: EquipmentManager not available for elite equipment")

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
	var global_enums = _get_global_enums()
	if global_enums and "FiveParsecsCampaignPhase" in global_enums:
		if "BATTLE" in global_enums.FiveParsecsCampaignPhase:
			set_campaign_phase(global_enums.FiveParsecsCampaignPhase.BATTLE)

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

# ============================================================================
# TEMPORARY DATA MANAGEMENT
# ============================================================================
# Temporary data storage for UI navigation state and inter-screen communication

func set_temp_data(key: String, value: Variant) -> void:
	"""Store temporary data for UI navigation"""
	temp_data[key] = value

func get_temp_data(key: String, default = null) -> Variant:
	"""Retrieve temporary data"""
	return temp_data.get(key, default)

func has_temp_data(key: String) -> bool:
	"""Check if temporary data exists"""
	return key in temp_data

func clear_temp_data(key: String = "") -> void:
	"""Clear temporary data (all if no key specified)"""
	if key.is_empty():
		temp_data.clear()
	else:
		temp_data.erase(key)

# ============================================================================
# CAMPAIGN MODIFICATION TRACKING
# ============================================================================
# Track unsaved changes to prompt user before losing data

func mark_campaign_modified() -> void:
	"""Mark campaign as having unsaved changes"""
	_campaign_modified = true
	if enable_debug_logging:
		print("GameStateManager: Campaign marked as modified")

func is_campaign_modified() -> bool:
	"""Check if campaign has unsaved changes"""
	return _campaign_modified

func clear_modified_flag() -> void:
	"""Clear the modified flag (call after successful save)"""
	_campaign_modified = false
	if enable_debug_logging:
		print("GameStateManager: Modified flag cleared")

# ============================================================================
# STANDARDIZED NAVIGATION HELPERS
# ============================================================================
# Use these for consistent navigation across all screens

## Navigate to a screen using SceneRouter with fallback
func navigate_to_screen(screen_name: String, context: Dictionary = {}) -> bool:
	"""Navigate to screen using SceneRouter with safe fallback.

	Args:
		screen_name: Name of screen (e.g., 'crew_management', 'campaign_dashboard')
		context: Optional context data to pass via temp_data

	Returns:
		true if navigation initiated successfully
	"""
	# Store context if provided
	if not context.is_empty():
		set_temp_data(TEMP_KEY_NAVIGATION_CONTEXT, context)

	# Try SceneRouter first (preferred)
	var scene_router = Engine.get_singleton("SceneRouter")
	if not scene_router:
		scene_router = get_node_or_null("/root/SceneRouter")

	if scene_router and scene_router.has_method("navigate_to"):
		scene_router.navigate_to(screen_name)
		if enable_debug_logging:
			print("GameStateManager: Navigated to %s via SceneRouter" % screen_name)
		return true

	# Fallback to direct scene path
	var scene_path = _get_scene_path_for_screen(screen_name)
	if not scene_path.is_empty():
		return navigate_to_scene_path(scene_path)

	push_error("GameStateManager: Cannot navigate to unknown screen: %s" % screen_name)
	return false

## Navigate directly to a scene path (use call_deferred for safety)
func navigate_to_scene_path(scene_path: String) -> bool:
	"""Navigate to scene path safely using call_deferred.

	Args:
		scene_path: Full resource path (e.g., 'res://src/ui/screens/...')

	Returns:
		true if navigation initiated
	"""
	var tree = get_tree()
	if not tree:
		push_error("GameStateManager: Scene tree not available for navigation")
		return false

	if not ResourceLoader.exists(scene_path):
		push_error("GameStateManager: Scene does not exist: %s" % scene_path)
		return false

	tree.call_deferred("change_scene_to_file", scene_path)
	if enable_debug_logging:
		print("GameStateManager: Navigating to scene: %s" % scene_path)
	return true

## Get scene path for common screen names
func _get_scene_path_for_screen(screen_name: String) -> String:
	"""Map screen names to scene paths for fallback navigation."""
	var screen_paths = {
		"main_menu": "res://src/ui/screens/mainmenu/MainMenu.tscn",
		"campaign_dashboard": "res://src/ui/screens/campaign/CampaignDashboard.tscn",
		"crew_management": "res://src/ui/screens/crew/CrewManagementScreen.tscn",
		"character_details": "res://src/ui/screens/character/CharacterDetailsScreen.tscn",
		"crew_creation": "res://src/ui/screens/crew/InitialCrewCreation.tscn",
		"campaign_creation": "res://src/ui/screens/campaign/CampaignCreationUI.tscn",
		"world_phase": "res://src/ui/screens/world/WorldPhaseController.tscn",
		"battle_dashboard": "res://src/ui/screens/battle/BattleDashboardUI.tscn",
		"equipment_manager": "res://src/ui/screens/equipment/EquipmentManager.tscn",
		"advancement_manager": "res://src/ui/screens/character/AdvancementManager.tscn",
		"load_campaign": "res://src/ui/screens/campaign/LoadCampaign.tscn"
	}
	return screen_paths.get(screen_name, "")

# ============================================================================
# CHARACTER STATUS HELPERS
# ============================================================================
# Standardized status tracking and display

## Character status enum values (match Character.gd status property)
const STATUS_ACTIVE = "ACTIVE"
const STATUS_INJURED = "INJURED"
const STATUS_RECOVERING = "RECOVERING"
const STATUS_DEAD = "DEAD"
const STATUS_MISSING = "MISSING"
const STATUS_RETIRED = "RETIRED"

## Get status icon for display
static func get_status_icon(status: String) -> String:
	"""Get emoji icon for character status."""
	match status:
		"ACTIVE": return "✅"
		"INJURED": return "🩹"
		"RECOVERING": return "🏥"
		"DEAD": return "💀"
		"MISSING": return "❓"
		"RETIRED": return "🏠"
		_: return "❓"

## Get status color for UI display
static func get_status_color(status: String) -> Color:
	"""Get color for character status display."""
	match status:
		"ACTIVE": return Color(0.5, 1.0, 0.5)      # Green
		"INJURED": return Color(1.0, 1.0, 0.5)     # Yellow
		"RECOVERING": return Color(0.5, 0.8, 1.0)  # Light blue
		"DEAD": return Color(1.0, 0.3, 0.3)        # Red
		"MISSING": return Color(0.8, 0.8, 0.8)     # Gray
		"RETIRED": return Color(0.6, 0.6, 0.8)     # Purple-gray
		_: return Color(1.0, 1.0, 1.0)             # White
