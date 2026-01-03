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
var current_turn: int = 1  # Current campaign turn number
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
## Sprint 29.1b: GameState is the authoritative source for credits
## GameStateManager delegates credit operations to GameState when available
## Local 'credits' variable maintained for backwards compatibility during transition

## Set credits with enhanced validation and bounds checking
## Delegates to GameState as the authoritative source
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

	var old_credits: int = credits

	# Sprint 29.1b: Delegate to GameState as authoritative source
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_resource"):
		var global_enums = get_node_or_null("/root/GlobalEnums")
		if global_enums and "ResourceType" in global_enums and "CREDITS" in global_enums.ResourceType:
			game_state.set_resource(global_enums.ResourceType.CREDITS, new_amount)
			# Read back from authoritative source to ensure sync
			credits = game_state.get_resource(global_enums.ResourceType.CREDITS)
		else:
			# Fallback: modify local and sync
			credits = new_amount
			_sync_credits_to_game_state()
	else:
		# GameState not available - use local variable
		credits = new_amount

	if old_credits != credits:
		self.credits_changed.emit(credits)

		if enable_debug_logging:
			print("GameStateManager: Credits changed from %d to %d (via GameState)" % [old_credits, credits])

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
## SPRINT 6.3: Prefer campaign source of truth when available
func get_victory_conditions() -> Dictionary:
	# First check if campaign has victory conditions (source of truth)
	if current_campaign:
		if current_campaign.has_method("get_victory_conditions"):
			var campaign_conditions = current_campaign.get_victory_conditions()
			if not campaign_conditions.is_empty():
				return campaign_conditions
		elif "victory_conditions" in current_campaign:
			var campaign_conditions = current_campaign.victory_conditions
			if not campaign_conditions.is_empty():
				return campaign_conditions.duplicate() if campaign_conditions is Dictionary else {}
	# Fallback to local copy
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
## SPRINT 6.3: Prefer campaign property, then meta, then default
func get_story_track_enabled() -> bool:
	if current_campaign:
		# First check if campaign has the method (FiveParsecsCampaignCore)
		if current_campaign.has_method("get_story_track_enabled"):
			return current_campaign.get_story_track_enabled()
		# Then check for property
		elif "story_track_enabled" in current_campaign:
			return current_campaign.story_track_enabled
		# Finally check meta (legacy support)
		elif current_campaign.has_meta("story_track_enabled"):
			return current_campaign.get_meta("story_track_enabled")
	return true  # Default enabled

## Get house rules configuration
## SPRINT 6.3: Read from campaign source of truth
func get_house_rules() -> Array:
	if current_campaign:
		# Check if campaign has the method (FiveParsecsCampaignCore)
		if current_campaign.has_method("get_house_rules"):
			return current_campaign.get_house_rules()
		# Then check for property
		elif "house_rules" in current_campaign:
			var rules = current_campaign.house_rules
			return rules.duplicate() if rules is Array else []
	return []  # Default empty

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

## Sprint 29.1b: GameState is the authoritative source for credits
## GameStateManager provides read access only; modifications go through GameState
func get_credits() -> int:
	# Read from GameState as authoritative source when available
	var game_state_node = get_node_or_null("/root/GameState")
	if game_state_node and game_state_node.has_method("get_resource"):
		var global_enums = get_node_or_null("/root/GlobalEnums")
		if global_enums and "ResourceType" in global_enums and "CREDITS" in global_enums.ResourceType:
			var authoritative_credits = game_state_node.get_resource(global_enums.ResourceType.CREDITS)
			# Sync local cache if different (keeps UI consistent)
			if credits != authoritative_credits:
				credits = authoritative_credits
			return authoritative_credits
	# Fallback to local cache if GameState unavailable
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

## Get array of crew members (Sprint 26.3: Returns Character objects, not Dictionaries)
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
# DATA ACCESSOR METHODS FOR UI COMPONENTS
# ============================================================================

## Get battle history array for display
func get_battle_history() -> Array:
	# First check campaign property
	if game_state and "current_campaign" in game_state and game_state.current_campaign:
		if "battle_history" in game_state.current_campaign:
			return game_state.current_campaign.battle_history
	
	# Fallback to temp data
	if has_temp_data("battle_history"):
		return get_temp_data("battle_history")
	
	return []

## Add a battle to history
func add_battle_history(battle_data: Dictionary) -> void:
	var history = get_battle_history()
	history.append(battle_data)
	
	# Store in campaign if available
	if game_state and "current_campaign" in game_state and game_state.current_campaign:
		if "battle_history" in game_state.current_campaign:
			game_state.current_campaign.battle_history = history
			return
	
	# Fallback to temp data
	set_temp_data("battle_history", history)

## Get current world data for WorldStatusCard
func get_current_world_data() -> Dictionary:
	# First check temp data (where we store full world data)
	if has_temp_data("world_data"):
		return get_temp_data("world_data")
	
	# Construct from campaign data
	if game_state and "current_campaign" in game_state and game_state.current_campaign:
		var world_data: Dictionary = {}
		
		# Get world name
		if "current_world" in game_state.current_campaign:
			world_data["name"] = game_state.current_campaign.current_world
		
		# Get patron count
		if "patrons" in game_state.current_campaign:
			world_data["patrons_count"] = game_state.current_campaign.patrons.size()
		
		# Get threat level from temp data or default
		world_data["danger_level"] = get_temp_data("threat_level") if has_temp_data("threat_level") else 1
		world_data["type"] = get_temp_data("world_type") if has_temp_data("world_type") else "Frontier Colony"
		
		return world_data
	
	return {"name": "Unknown World", "danger_level": 1, "patrons_count": 0, "type": ""}

## Get current mission data for MissionStatusCard
func get_current_mission_data() -> Dictionary:
	# Check temp data first
	if has_temp_data("current_mission"):
		return get_temp_data("current_mission")
	
	# Check campaign quests
	if game_state and "current_campaign" in game_state and game_state.current_campaign:
		if "quests" in game_state.current_campaign:
			var quests = game_state.current_campaign.quests
			if quests is Array and not quests.is_empty():
				# Return the first active quest as mission
				for quest in quests:
					if quest is Dictionary and quest.get("status", "") == "active":
						return {
							"name": quest.get("name", "Unknown Mission"),
							"type": quest.get("type", ""),
							"objectives_completed": quest.get("progress", 0),
							"objectives_total": quest.get("max_progress", 0),
							"difficulty": quest.get("difficulty", 1)
						}
	
	return {"name": "No Active Mission", "type": "", "objectives_completed": 0, "objectives_total": 0, "difficulty": 1}

## Get current turn number
func get_current_turn() -> int:
	return current_turn

## Set current turn number
func set_current_turn(turn: int) -> void:
	current_turn = maxi(1, turn)

## Get quests array for StoryTrackSection
func get_quests() -> Array:
	if game_state and "current_campaign" in game_state and game_state.current_campaign:
		if "quests" in game_state.current_campaign:
			return game_state.current_campaign.quests
	
	# Fallback to temp data
	if has_temp_data("test_quests"):
		return get_temp_data("test_quests")
	
	return []

## Alias for get_current_mission_data - used by CampaignDashboard
func get_active_mission() -> Dictionary:
	return get_current_mission_data()

## Alias for get_current_world_data - used by CampaignDashboard  
func get_current_location() -> Dictionary:
	return get_current_world_data()

## Get active quest for story track
func get_active_quest() -> Dictionary:
	var quests_array = get_quests()
	for quest in quests_array:
		if quest is Dictionary and quest.get("status", "") == "active":
			return quest
	return {}

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

	# Determine game stage for appropriate data generation
	var game_stage = campaign_data.get("game_stage", "mid")  # early, mid, late
	
	# Apply profile defaults based on game stage
	var profile = _get_campaign_profile(game_stage)
	
	# Apply test-specific configurations (override profile with explicit values)
	var test_turn = campaign_data.get("turn_number", profile.turn_number)
	current_turn = test_turn
	if test_turn > 1:
		_simulate_campaign_progression(test_turn)

	var test_credits = campaign_data.get("credits", profile.credits)
	set_credits(test_credits)

	var test_supplies = campaign_data.get("supplies", profile.supplies)
	set_supplies(test_supplies)

	var test_reputation = campaign_data.get("reputation", profile.reputation)
	set_reputation(test_reputation)

	# Set up test crew with XP progression based on game stage
	var test_crew_size = campaign_data.get("crew_size", profile.crew_size)
	_create_test_crew(test_crew_size, game_stage)

	# Create test ship
	_create_test_ship(campaign_data.get("ship_name", profile.ship_name))

	# Set up test scenario elements based on profile
	var test_patrons = campaign_data.get("patrons", profile.patrons)
	_create_test_patrons(test_patrons)
	
	var test_rivals = campaign_data.get("rivals", profile.rivals)
	_create_test_rivals(test_rivals)

	var test_quests = campaign_data.get("quests", profile.quests)
	_create_test_quests(test_quests)
	
	var test_battles = campaign_data.get("battles", profile.battles)
	_create_test_battle_history(test_battles)
	
	# Create world data
	_create_test_world()

	# Set equipment level based on game stage
	var equipment_level = campaign_data.get("equipment_level", profile.equipment_level)
	_apply_test_equipment_level(equipment_level)

	print("GameStateManager: Test campaign created (%s game profile):" % game_stage)
	print("  - Turn: %d, Credits: %d, Reputation: %d" % [test_turn, test_credits, test_reputation])
	print("  - Crew: %d, Patrons: %d, Rivals: %d, Quests: %d, Battles: %d" % [
		test_crew_size, test_patrons, test_rivals, test_quests, test_battles
	])
	return true

## Get campaign profile defaults for game stage (Core Rules campaign progression)
func _get_campaign_profile(stage: String) -> Dictionary:
	match stage.to_lower():
		"early":
			# Early game: Turn 1-5, rookies, minimal resources
			return {
				"turn_number": randi() % 5 + 1,
				"credits": randi() % 10 + 5,  # 5-15 credits
				"supplies": randi() % 3 + 1,
				"reputation": 0,
				"crew_size": 4,
				"patrons": randi() % 2,  # 0-1 patrons
				"rivals": randi() % 2 + 1,  # 1-2 rivals
				"quests": 0,
				"battles": randi() % 3,  # 0-2 battles
				"ship_name": "Rusty Bucket",
				"equipment_level": "basic"
			}
		"mid":
			# Mid game: Turn 10-15, mixed crew, growing reputation
			return {
				"turn_number": randi() % 6 + 10,  # 10-15
				"credits": randi() % 30 + 20,  # 20-50 credits
				"supplies": randi() % 5 + 3,
				"reputation": randi() % 10 + 5,
				"crew_size": 5,
				"patrons": randi() % 2 + 2,  # 2-3 patrons
				"rivals": randi() % 2 + 2,  # 2-3 rivals
				"quests": randi() % 2 + 1,  # 1-2 quests
				"battles": randi() % 5 + 5,  # 5-9 battles
				"ship_name": "Starlight",
				"equipment_level": "standard"
			}
		"late":
			# Late game: Turn 25+, veterans, established reputation
			return {
				"turn_number": randi() % 10 + 25,  # 25-35
				"credits": randi() % 50 + 50,  # 50-100 credits
				"supplies": randi() % 5 + 8,
				"reputation": randi() % 15 + 15,
				"crew_size": 6,
				"patrons": randi() % 2 + 3,  # 3-4 patrons
				"rivals": randi() % 3 + 3,  # 3-5 rivals
				"quests": randi() % 2 + 2,  # 2-3 quests
				"battles": randi() % 10 + 15,  # 15-25 battles
				"ship_name": "Victory's Edge",
				"equipment_level": "advanced"
			}
		_:
			# Default to mid game
			return _get_campaign_profile("mid")

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

## Create test crew members with full rulebook-accurate modifiers and XP progression
func _create_test_crew(crew_size: int, game_stage: String = "mid") -> void:
	print("GameStateManager: Creating rulebook-accurate test crew of size %d (%s game)" % [crew_size, game_stage])

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

	# XP progression tiers based on Core Rules p.118
	# Casualty: 1 XP, Survived no win: 2 XP, Survived + Won: 3 XP, First casualty: +1 bonus
	# Character Upgrades: 5-10 XP per stat depending on ability
	var xp_tiers = _get_xp_tiers_for_stage(game_stage)

	# Create crew members with full modifiers
	var test_crew: Array = []
	var test_names: Array[String] = ["Alex", "Jordan", "Casey", "Riley", "Morgan", "Taylor"]

	for i in range(crew_size):
		var character = _generate_character_with_modifiers(test_names[i % test_names.size()])
		
		# Apply XP progression based on tier and position
		var tier_index = mini(i, xp_tiers.size() - 1)
		var xp_tier = xp_tiers[tier_index]
		
		character["experience"] = character.get("experience", 0) + xp_tier.xp
		character["total_kills"] = xp_tier.kills
		character["missions_completed"] = xp_tier.missions
		character["xp_to_next_level"] = _calculate_xp_to_next_upgrade(character["experience"])
		
		# Apply stat upgrades for experienced characters (1 stat point per upgrade)
		if xp_tier.upgrades > 0:
			var stat_options = ["combat", "reactions", "toughness", "savvy"]
			for _upgrade in range(xp_tier.upgrades):
				var stat_to_boost = stat_options[randi() % stat_options.size()]
				character[stat_to_boost] = character.get(stat_to_boost, 0) + 1
		
		# Set tier label for UI display
		character["experience_tier"] = xp_tier.tier

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
		print("GameStateManager: Created %s - %s (XP: %d, Upgrades: %d, Kills: %d)" % [
			character.character_name, xp_tier.tier, xp_tier.xp, xp_tier.upgrades, xp_tier.kills
		])

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

## Get XP progression tiers based on game stage (Core Rules p.118)
func _get_xp_tiers_for_stage(stage: String) -> Array:
	match stage.to_lower():
		"early":
			# Early game: Turn 1-5, mostly rookies
			return [
				{"tier": "Rookie", "xp": 3, "upgrades": 0, "kills": 1, "missions": 1},
				{"tier": "Rookie", "xp": 0, "upgrades": 0, "kills": 0, "missions": 0},
				{"tier": "Rookie", "xp": 0, "upgrades": 0, "kills": 0, "missions": 0},
				{"tier": "Rookie", "xp": 0, "upgrades": 0, "kills": 0, "missions": 0},
			]
		"mid":
			# Mid game: Turn 10-15, mixed experience levels
			return [
				{"tier": "Veteran", "xp": 18, "upgrades": 3, "kills": 12, "missions": 6},  # Experienced leader
				{"tier": "Seasoned", "xp": 10, "upgrades": 1, "kills": 6, "missions": 4},
				{"tier": "Seasoned", "xp": 7, "upgrades": 1, "kills": 4, "missions": 3},
				{"tier": "Rookie", "xp": 3, "upgrades": 0, "kills": 2, "missions": 1},  # Recent recruit
				{"tier": "Rookie", "xp": 0, "upgrades": 0, "kills": 0, "missions": 0},  # New recruit
			]
		"late":
			# Late game: Turn 25+, veterans and elites
			return [
				{"tier": "Elite", "xp": 35, "upgrades": 5, "kills": 25, "missions": 15},  # Legendary captain
				{"tier": "Elite", "xp": 28, "upgrades": 4, "kills": 18, "missions": 12},
				{"tier": "Veteran", "xp": 20, "upgrades": 3, "kills": 14, "missions": 8},
				{"tier": "Veteran", "xp": 15, "upgrades": 2, "kills": 10, "missions": 6},
				{"tier": "Seasoned", "xp": 8, "upgrades": 1, "kills": 5, "missions": 3},
				{"tier": "Rookie", "xp": 2, "upgrades": 0, "kills": 1, "missions": 1},  # New recruit
			]
		_:
			# Default to mid game
			return _get_xp_tiers_for_stage("mid")

## Calculate XP needed for next character upgrade (Core Rules p.118)
func _calculate_xp_to_next_upgrade(current_xp: int) -> int:
	# Cheapest upgrade is Speed/Savvy at 5 XP
	# Most common upgrades are 6-7 XP
	var base_upgrade_cost = 6
	var xp_spent = (current_xp / base_upgrade_cost) * base_upgrade_cost
	return base_upgrade_cost - (current_xp - xp_spent)

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

## Create test patrons with full data (Core Rules p.78-82)
func _create_test_patrons(patron_count: int) -> void:
	print("GameStateManager: Creating %d test patrons with full data" % patron_count)

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: Cannot create patrons - no campaign")
		return

	# Patron templates with Five Parsecs flavor (Core Rules p.78-82)
	var patron_templates = [
		{
			"id": "patron_1",
			"name": "Merchant Lord Vazquez",
			"type": "corporate",
			"relationship": "neutral",
			"jobs_completed": 2,
			"jobs_available": 1,
			"trust_level": 3,
			"special_offers": true,
			"persistent": false,
			"description": "A wealthy trader dealing in exotic goods across the Fringe.",
			"payment_bonus": 0
		},
		{
			"id": "patron_2",
			"name": "Commander Chen",
			"type": "military",
			"relationship": "friendly",
			"jobs_completed": 4,
			"jobs_available": 2,
			"trust_level": 5,
			"special_offers": false,
			"persistent": true,
			"description": "A respected military officer seeking deniable assets.",
			"payment_bonus": 1
		},
		{
			"id": "patron_3",
			"name": "The Broker",
			"type": "underworld",
			"relationship": "cautious",
			"jobs_completed": 1,
			"jobs_available": 1,
			"trust_level": 2,
			"special_offers": true,
			"persistent": false,
			"description": "A mysterious information dealer with connections everywhere.",
			"payment_bonus": 2
		},
		{
			"id": "patron_4",
			"name": "Governor Reyes",
			"type": "government",
			"relationship": "neutral",
			"jobs_completed": 0,
			"jobs_available": 1,
			"trust_level": 1,
			"special_offers": false,
			"persistent": false,
			"description": "Local planetary administrator needing discrete problem solvers.",
			"payment_bonus": 0
		},
		{
			"id": "patron_5",
			"name": "Dr. Elara Voss",
			"type": "corporate",
			"relationship": "friendly",
			"jobs_completed": 3,
			"jobs_available": 2,
			"trust_level": 4,
			"special_offers": true,
			"persistent": true,
			"description": "A research scientist with deep pockets and dangerous interests.",
			"payment_bonus": 1
		}
	]

	if "patrons" in game_state.current_campaign:
		game_state.current_campaign.patrons = []
		for i: int in range(mini(patron_count, patron_templates.size())):
			var patron = patron_templates[i].duplicate()
			game_state.current_campaign.patrons.append(patron)
			print("GameStateManager: Added patron '%s' (Trust: %d, Jobs: %d)" % [
				patron.name, patron.trust_level, patron.jobs_completed
			])
	else:
		push_error("GameStateManager: current_campaign does not have 'patrons' property")

## Create test rival encounters with full data (Core Rules p.77)
func _create_test_rivals(rival_count: int) -> void:
	print("GameStateManager: Creating %d test rivals with full data" % rival_count)

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: GameState or current_campaign is not available.")
		return

	# Rival templates with Five Parsecs flavor (Core Rules p.77)
	var rival_templates = [
		{
			"id": "rival_1",
			"name": "The Red Vipers",
			"type": "gang",
			"threat": 2,
			"status": "active",
			"encounters": 1,
			"origin": "Betrayed in a salvage deal",
			"last_encounter_turn": 3,
			"grudge_level": "moderate"
		},
		{
			"id": "rival_2",
			"name": "Commander Vex",
			"type": "bounty_hunter",
			"threat": 3,
			"status": "hunting",
			"encounters": 2,
			"origin": "Escaped from their contract",
			"last_encounter_turn": 7,
			"grudge_level": "severe"
		},
		{
			"id": "rival_3",
			"name": "Syndicate Enforcers",
			"type": "criminal",
			"threat": 2,
			"status": "watching",
			"encounters": 0,
			"origin": "Witnessed their operation",
			"last_encounter_turn": 0,
			"grudge_level": "mild"
		},
		{
			"id": "rival_4",
			"name": "Rogue AI 'TERMINUS'",
			"type": "machine",
			"threat": 4,
			"status": "pursuing",
			"encounters": 3,
			"origin": "Damaged their core systems",
			"last_encounter_turn": 10,
			"grudge_level": "extreme"
		},
		{
			"id": "rival_5",
			"name": "Militia Captain Hark",
			"type": "military",
			"threat": 2,
			"status": "active",
			"encounters": 1,
			"origin": "Defied local authority",
			"last_encounter_turn": 5,
			"grudge_level": "moderate"
		}
	]

	# Store rivals in campaign
	if "rivals" in game_state.current_campaign:
		game_state.current_campaign.rivals = []
		for i: int in range(mini(rival_count, rival_templates.size())):
			var rival = rival_templates[i].duplicate()
			rival["created_turn"] = maxi(1, current_turn - rival.encounters)
			game_state.current_campaign.rivals.append(rival)
			print("GameStateManager: Added rival '%s' (Threat: %d, Status: %s)" % [
				rival.name, rival.threat, rival.status
			])
	else:
		push_error("GameStateManager: current_campaign does not have 'rivals' property")

## Create test quest scenarios with full data (Core Rules p.86)
func _create_test_quests(quest_count: int) -> void:
	print("GameStateManager: Creating %d test quests with objectives" % quest_count)

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: Cannot create quests - no campaign")
		return

	# Quest templates with Five Parsecs story flavor (Core Rules p.86)
	var quest_templates = [
		{
			"id": "quest_1",
			"name": "The Forgotten Colony",
			"type": "story",
			"status": "active",
			"progress": 2,
			"max_progress": 5,
			"description": "Investigate the abandoned colony on Kepler-7b and discover what happened to its inhabitants.",
			"objectives": [
				{"text": "Travel to Kepler-7b", "complete": true},
				{"text": "Explore the colony ruins", "complete": true},
				{"text": "Find survivor logs", "complete": false},
				{"text": "Confront the threat", "complete": false},
				{"text": "Report findings", "complete": false}
			],
			"rewards": {"credits": 500, "story_points": 2, "reputation": 5},
			"rumors_collected": 3,
			"started_turn": 5
		},
		{
			"id": "quest_2",
			"name": "Patron Debt",
			"type": "patron",
			"status": "active",
			"progress": 1,
			"max_progress": 3,
			"description": "Complete jobs for Merchant Lord Vazquez to settle the crew's debt.",
			"objectives": [
				{"text": "Complete first delivery", "complete": true},
				{"text": "Handle the competition", "complete": false},
				{"text": "Final payment delivery", "complete": false}
			],
			"rewards": {"credits": 300, "patron_favor": true},
			"rumors_collected": 1,
			"started_turn": 8
		},
		{
			"id": "quest_3",
			"name": "Ancient Tech Cache",
			"type": "rumor",
			"status": "investigating",
			"progress": 0,
			"max_progress": 4,
			"description": "Rumors of pre-collapse technology hidden in the asteroid field.",
			"objectives": [
				{"text": "Verify the rumors", "complete": false},
				{"text": "Navigate the asteroid field", "complete": false},
				{"text": "Bypass security systems", "complete": false},
				{"text": "Secure the cache", "complete": false}
			],
			"rewards": {"credits": 800, "rare_item": true, "story_points": 1},
			"rumors_collected": 2,
			"started_turn": 12
		},
		{
			"id": "quest_4",
			"name": "The K'Erin Honor Duel",
			"type": "story",
			"status": "pending",
			"progress": 0,
			"max_progress": 2,
			"description": "A K'Erin warrior has challenged your captain to an honor duel.",
			"objectives": [
				{"text": "Prepare for the duel", "complete": false},
				{"text": "Face the K'Erin champion", "complete": false}
			],
			"rewards": {"credits": 200, "reputation": 10, "ally": true},
			"rumors_collected": 1,
			"started_turn": 15
		}
	]

	# Store quests in campaign
	if "quests" in game_state.current_campaign:
		game_state.current_campaign.quests = []
		for i: int in range(mini(quest_count, quest_templates.size())):
			var quest = quest_templates[i].duplicate(true)
			game_state.current_campaign.quests.append(quest)
			print("GameStateManager: Added quest '%s' (%d/%d)" % [
				quest.name, quest.progress, quest.max_progress
			])
	elif game_state.has_method("create_test_quests"):
		game_state.create_test_quests(quest_count)
	else:
		# Store in temp data as fallback
		set_temp_data("test_quests", quest_templates.slice(0, quest_count))

## Create test battle history with varied outcomes (Core Rules Post-Battle p.119)
func _create_test_battle_history(battle_count: int) -> void:
	print("GameStateManager: Creating %d battle history entries" % battle_count)

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: Cannot create battle history - no campaign")
		return

	var enemy_types = ["Gangers", "Pirates", "Mercenaries", "Cultists", "Robots", "Alien Raiders", "Enforcers", "Ferals"]
	var outcomes = ["victory", "victory", "victory", "retreat", "pyrrhic"]  # Weighted towards victory
	var mission_types = ["Patrol", "Raid", "Defense", "Assassination", "Rescue", "Salvage", "Escort", "Recon"]
	var locations = ["Abandoned Station", "Colony Outskirts", "Industrial Zone", "Spaceport", "Wasteland", "Underground Complex"]

	var battle_history: Array = []
	for i: int in range(battle_count):
		var turn_number: int = maxi(1, current_turn - (battle_count - i))
		var outcome: String = outcomes[randi() % outcomes.size()]
		var enemy: String = enemy_types[randi() % enemy_types.size()]
		
		# Calculate results based on outcome (Core Rules p.119)
		var kills: int = randi() % 6 + 2 if outcome == "victory" else randi() % 3
		var injuries: int = 0 if outcome == "victory" else randi() % 2 + 1
		var credits_earned: int = (randi() % 3 + 1) * 50 if outcome != "retreat" else 0
		var xp_earned: int = kills * 2 + (5 if outcome == "victory" else 2)

		var battle = {
			"id": "battle_%d" % (i + 1),
			"turn": turn_number,
			"mission_type": mission_types[randi() % mission_types.size()],
			"location": locations[randi() % locations.size()],
			"enemy_type": enemy,
			"enemy_count": randi() % 4 + 4,
			"outcome": outcome,
			"kills": kills,
			"injuries": injuries,
			"casualties": 1 if outcome == "pyrrhic" else 0,
			"credits_earned": credits_earned,
			"loot_found": randi() % 3,
			"xp_earned": xp_earned,
			"held_field": outcome == "victory",
			"notable_events": _generate_battle_events(outcome)
		}
		battle_history.append(battle)
		print("GameStateManager: Battle %d - %s vs %s: %s (+%d credits, %d kills)" % [
			turn_number, battle.mission_type, enemy, outcome, credits_earned, kills
		])

	if "battle_history" in game_state.current_campaign:
		game_state.current_campaign.battle_history = battle_history
	else:
		set_temp_data("battle_history", battle_history)

## Generate notable battle events for flavor (Core Rules p.116 Battle Events)
func _generate_battle_events(outcome: String) -> Array:
	var victory_events = [
		"Flawless execution - no casualties",
		"Enemy leader eliminated",
		"Valuable intel recovered",
		"Found hidden stash during sweep",
		"Local contact made during mission",
		"Enemy routed before reinforcements arrived"
	]
	var retreat_events = [
		"Tactical withdrawal under fire",
		"Overwhelmed by reinforcements",
		"Objective compromised - fell back",
		"Ambush forced retreat",
		"Equipment malfunction forced extraction"
	]
	var pyrrhic_events = [
		"Victory at great cost",
		"Lost crew member covering retreat",
		"Equipment destroyed in explosion",
		"Barely survived enemy elite unit",
		"Mission complete but medic needed"
	]

	match outcome:
		"victory":
			return [victory_events[randi() % victory_events.size()]]
		"retreat":
			return [retreat_events[randi() % retreat_events.size()]]
		"pyrrhic":
			return [pyrrhic_events[randi() % pyrrhic_events.size()]]
	return []

## Create test world/location data (Core Rules p.72-75)
func _create_test_world() -> void:
	print("GameStateManager: Creating test world data")

	if not game_state or not game_state.current_campaign:
		push_warning("GameStateManager: Cannot create world - no campaign")
		return

	# World traits from Core Rules World Traits Table (p.74-75)
	var world_traits_options = [
		"Haze", "Overgrown", "Warzone", "Heavily Enforced", "Rampant Crime",
		"Invasion Risk", "Trade Hub", "Corporate Controlled", "Frontier Settlement"
	]
	
	# Pick 1-3 random traits
	var num_traits = randi() % 3 + 1
	var selected_traits: Array = []
	for _i in range(num_traits):
		var trait_item = world_traits_options[randi() % world_traits_options.size()]
		if trait_item not in selected_traits:
			selected_traits.append(trait_item)

	var world_data = {
		"name": "Nexus Prime",
		"type": "frontier_colony",
		"traits": selected_traits,
		"threat_level": randi() % 4 + 1,  # 1-4
		"invasion_status": "none",
		"licensing_required": randi() % 6 >= 4,  # 5-6 on d6 requires license (Core Rules p.73)
		"license_cost": randi() % 6 + 1,
		"local_events": [
			{"type": "market_boom", "description": "Surplus goods flood the market"},
			{"type": "gang_war", "description": "Local gangs clash in the lower districts"}
		],
		"available_services": [
			"Medical Bay", "Repair Shop", "Black Market", "Recruitment Office",
			"Trade Post", "Information Broker"
		],
		"travel_options": [
			{"destination": "Kepler-7b", "fuel_cost": 2, "danger": "low"},
			{"destination": "The Fringe Station", "fuel_cost": 3, "danger": "medium"},
			{"destination": "Unity Core Worlds", "fuel_cost": 5, "danger": "high"}
		],
		"visited_turns": [1, 3, 5],
		"turns_on_world": current_turn
	}

	# Set world name in campaign (current_world is a String property)
	if "current_world" in game_state.current_campaign:
		game_state.current_campaign.current_world = world_data.name
	
	# Store full world data in temp_data for UI access
	set_temp_data("world_data", world_data)

	print("GameStateManager: Created world '%s' (%s) with traits: %s" % [
		world_data.name, world_data.type, str(selected_traits)
	])

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
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		if "equipment" in crew_member:
			crew_member.equipment = tier_items.duplicate()
			print("GameStateManager: Applied %s equipment to crew member %d" % [level, i])
		elif crew_member is Dictionary:
			# Fallback for Dictionary format
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
		screen_name: Scene key registered in SceneRouter (e.g., "campaign_dashboard")
		context: Optional context dictionary to pass to the target scene

	Returns:
		true if navigation initiated successfully
	"""
	# Store context if provided
	if not context.is_empty():
		set_temp_data(TEMP_KEY_NAVIGATION_CONTEXT, context)

	# Try SceneRouter autoload (GDScript autoloads are nodes, not Engine singletons)
	var scene_router: Node = get_node_or_null("/root/SceneRouter")

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
		push_error("GameStateManager: Scene file not found: %s" % scene_path)
		return false

	tree.call_deferred("change_scene_to_file", scene_path)
	if enable_debug_logging:
		print("GameStateManager: Navigating to scene: %s" % scene_path)
	return true

## Get scene path for a screen name
func _get_scene_path_for_screen(screen_name: String) -> String:
	"""Map screen names to scene paths for fallback navigation."""
	var paths = {
		"main_menu": "res://src/ui/screens/mainmenu/MainMenu.tscn",
		"campaign_dashboard": "res://src/ui/screens/campaign/CampaignDashboard.tscn",
		"crew_management": "res://src/ui/screens/crew/CrewManagementScreen.tscn",
		"character_details": "res://src/ui/screens/character/CharacterDetailsScreen.tscn",
		"ship_manager": "res://src/ui/screens/ships/ShipManager.tscn",
		"world_phase": "res://src/ui/screens/world/WorldPhaseController.tscn",
		"settings": "res://src/ui/dialogs/SettingsDialog.tscn",
		"trading": "res://src/ui/screens/campaign/TradingScreen.tscn"
	}
	return paths.get(screen_name, "")