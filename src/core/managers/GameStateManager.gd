# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name GameStateManagerClass
extends Node

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameEnums = null
var CoreGameState = null

signal game_state_changed(new_state)
signal campaign_phase_changed(new_phase: int)
signal difficulty_changed(new_difficulty: int)
signal credits_changed(new_amount: int)
signal supplies_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal story_progress_changed(new_amount: int)

@export var initial_credits: int = 1000
@export var initial_supplies: int = 5
@export var initial_reputation: int = 0

var game_state = null
var campaign_phase: int = 0 # Will be set to NONE enum value in _ready()
var difficulty_level: int = 1 # Will be set to NORMAL enum value in _ready()
var credits: int = initial_credits
var supplies: int = initial_supplies
var reputation: int = initial_reputation
var story_progress: int = 0

# Manager registration system for cross-system communication
var registered_managers: Dictionary = {}

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "GameStateManager GameEnums")
	CoreGameState = UniversalResourceLoader.load_script_safe("res://src/core/state/GameState.gd", "GameStateManager CoreGameState")
	
	# Initialize enum values after loading GameEnums
	if GameEnums:
		# Set default campaign phase to NONE if available
		if "FiveParsecsCampaignPhase" in GameEnums and "NONE" in GameEnums.FiveParsecsCampaignPhase:
			campaign_phase = GameEnums.FiveParsecsCampaignPhase.NONE
		# Set default difficulty to NORMAL if available  
		if "DifficultyLevel" in GameEnums and "NORMAL" in GameEnums.DifficultyLevel:
			difficulty_level = GameEnums.DifficultyLevel.NORMAL
	
	_validate_universal_connections()
	print("GameStateManager: Initializing...")
	# Initialize with default values
	set_credits(initial_credits)
	set_supplies(initial_supplies)
	set_reputation(initial_reputation)
	set_story_progress(0)
	
	# Create default game state if none exists
	if not game_state:
		if CoreGameState:
			# Create instance using proper Godot 4.4 pattern
			var instance = (CoreGameState as Script).new()
			if instance:
				game_state = instance
				print("GameStateManager: Created new game state")
			else:
				push_error("CRASH PREVENTION: Failed to instantiate CoreGameState")
		else:
			push_error("CRASH PREVENTION: CoreGameState class not loaded")

func _validate_universal_connections() -> void:
	# Validate core system connections
	_validate_core_connections()
	_register_with_game_state()

func _validate_core_connections() -> void:
	# Validate required dependencies
	if not GameEnums:
		push_error("CORE SYSTEM FAILURE: GameEnums not accessible from GameStateManager")
	
	if not CoreGameState:
		push_error("CORE SYSTEM FAILURE: CoreGameState not accessible from GameStateManager")
	
	# Autoload validation skipped - dependencies checked at runtime

func _register_with_game_state() -> void:
	# Register this manager with the global game state system using direct autoload access
	if GameState and GameState.has_method("register_manager"):
		GameState.register_manager("GameStateManager", self)

## Initialize a new game state
func initialize_game_state() -> void:
	if not game_state:
		if CoreGameState:
			# Create instance using proper Godot 4.4 pattern
			var instance = (CoreGameState as Script).new()
			if instance:
				game_state = instance
			else:
				push_error("CRASH PREVENTION: Failed to instantiate CoreGameState")
				return
		else:
			push_error("CRASH PREVENTION: Cannot create CoreGameState - class not loaded")
			return
	
	# Set initial values using proper API
	if game_state.has_method("set_resource") and GameEnums:
		if "ResourceType" in GameEnums:
			if "CREDITS" in GameEnums.ResourceType:
				game_state.set_resource(GameEnums.ResourceType.CREDITS, initial_credits)
			if "SUPPLIES" in GameEnums.ResourceType:
				game_state.set_resource(GameEnums.ResourceType.SUPPLIES, initial_supplies)
	
	# Set other properties if they exist
	if "reputation" in game_state:
		game_state.reputation = initial_reputation
	if "story_points" in game_state:
		game_state.story_points = 0
	
	print("GameStateManager: Game state initialized")

# State management
func set_game_state(new_state) -> void:
	if game_state != new_state:
		game_state = new_state
		UniversalSignalManager.emit_signal_safe(self, "game_state_changed", [game_state], "GameStateManager set_game_state")

func set_campaign_phase(new_phase: int) -> void:
	if campaign_phase != new_phase:
		campaign_phase = new_phase
		UniversalSignalManager.emit_signal_safe(self, "campaign_phase_changed", [campaign_phase], "GameStateManager set_campaign_phase")

func set_difficulty(new_difficulty: int) -> void:
	if difficulty_level != new_difficulty:
		difficulty_level = new_difficulty
		UniversalSignalManager.emit_signal_safe(self, "difficulty_changed", [difficulty_level], "GameStateManager set_difficulty")

# Resource management
func set_credits(new_amount: int) -> void:
	if credits != new_amount:
		credits = new_amount
		UniversalSignalManager.emit_signal_safe(self, "credits_changed", [credits], "GameStateManager set_credits")
		if game_state and game_state.has_method("set_resource") and GameEnums:
			if "ResourceType" in GameEnums and "CREDITS" in GameEnums.ResourceType:
				game_state.set_resource(GameEnums.ResourceType.CREDITS, credits)

func set_supplies(new_amount: int) -> void:
	if supplies != new_amount:
		supplies = new_amount
		UniversalSignalManager.emit_signal_safe(self, "supplies_changed", [supplies], "GameStateManager set_supplies")
		if game_state and game_state.has_method("set_resource") and GameEnums:
			if "ResourceType" in GameEnums and "SUPPLIES" in GameEnums.ResourceType:
				game_state.set_resource(GameEnums.ResourceType.SUPPLIES, supplies)

func set_reputation(new_amount: int) -> void:
	if reputation != new_amount:
		reputation = new_amount
		UniversalSignalManager.emit_signal_safe(self, "reputation_changed", [reputation], "GameStateManager set_reputation")
		if game_state and "reputation" in game_state:
			game_state.reputation = reputation

func set_story_progress(new_amount: int) -> void:
	if story_progress != new_amount:
		story_progress = new_amount
		UniversalSignalManager.emit_signal_safe(self, "story_progress_changed", [story_progress], "GameStateManager set_story_progress")
		if game_state and "story_points" in game_state:
			game_state.story_points = story_progress

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

# Manager Registration System for Cross-System Communication

## Register a manager for cross-system access
func register_manager(manager_name: String, manager_instance: Node) -> void:
	"""Register a manager for cross-system communication"""
	if not manager_instance:
		push_warning("GameStateManager: Attempted to register null manager: " + manager_name)
		return
	
	registered_managers[manager_name] = manager_instance
	print("GameStateManager: Registered manager: " + manager_name)

## Get a registered manager by name
func get_manager(manager_name: String) -> Node:
	"""Get a registered manager by name"""
	if manager_name in registered_managers:
		return registered_managers[manager_name]
	else:
		push_warning("GameStateManager: Manager not found: " + manager_name)
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
		print("GameStateManager: Unregistered manager: " + manager_name)
	else:
		push_warning("GameStateManager: Cannot unregister unknown manager: " + manager_name)

## Get all registered manager names
func get_registered_managers() -> Array[String]:
	"""Get all registered manager names"""
	var manager_names: Array[String] = []
	for name in registered_managers.keys():
		manager_names.append(name)
	return manager_names

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
	var difficulty = UniversalDataAccess.get_dict_value_safe(campaign_config, "difficulty", difficulty_level, "GameStateManager start_new_campaign difficulty")
	if difficulty != difficulty_level:
		set_difficulty(difficulty)
	
	var config_credits = UniversalDataAccess.get_dict_value_safe(campaign_config, "credits", initial_credits, "GameStateManager start_new_campaign credits")
	if config_credits != credits:
		set_credits(config_credits)
	
	var config_supplies = UniversalDataAccess.get_dict_value_safe(campaign_config, "supplies", initial_supplies, "GameStateManager start_new_campaign supplies")
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
	var save_manager = get_manager("SaveManager")
	if save_manager and save_manager.has_method("save_game"):
		return save_manager.save_game(save_data, "current_campaign")
	elif game_state.has_method("save_game"):
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
		var manager = registered_managers[manager_name]
		if manager and manager.has_method("save_data"):
			save_data.managers[manager_name] = manager.save_data()
		elif manager and manager.has_method("serialize"):
			save_data.managers[manager_name] = manager.serialize()
	
	# Include game state data
	if game_state and game_state.has_method("serialize"):
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
	var save_manager = get_manager("SaveManager")
	var save_data: Dictionary = {}
	
	if save_manager and save_manager.has_method("load_game"):
		save_data = save_manager.load_game(save_name)
	elif game_state.has_method("load_game"):
		return game_state.load_game(save_name)
	else:
		push_warning("GameStateManager: No load system available")
		return false
	
	if save_data.is_empty():
		push_error("GameStateManager: Failed to load save data")
		return false
	
	# Restore GameStateManager's own state
	if save_data.has("game_state_manager"):
		_restore_manager_state(save_data.game_state_manager)
	
	# Restore data for all registered managers
	if save_data.has("managers"):
		_restore_all_manager_data(save_data.managers)
	
	# Restore game state
	if save_data.has("game_state") and game_state.has_method("deserialize"):
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
		var manager = get_manager(manager_name)
		if manager and manager.has_method("load_data"):
			manager.load_data(managers_data[manager_name])
		elif manager and manager.has_method("deserialize"):
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
	if game_state and game_state.has_method("get_crew_members"):
		return game_state.get_crew_members()
	return []

## Get current crew size
func get_crew_size() -> int:
	if game_state and game_state.has_method("get_crew_size"):
		return game_state.get_crew_size()
	return 4 # Default crew size

## Get number of crew members in sick bay
func get_sick_crew_count() -> int:
	if game_state and game_state.has_method("get_sick_crew_count"):
		return game_state.get_sick_crew_count()
	return 0

## Add experience to crew member
func add_crew_experience(crew_id: String, xp: int) -> void:
	if game_state and game_state.has_method("add_crew_experience"):
		game_state.add_crew_experience(crew_id, xp)

## Apply injury to crew member
func apply_crew_injury(crew_id: String, injury_data: Dictionary) -> void:
	if game_state and game_state.has_method("apply_crew_injury"):
		game_state.apply_crew_injury(crew_id, injury_data)

## Get player ship instance
func get_player_ship():
	if game_state and game_state.has_method("get_player_ship"):
		return game_state.get_player_ship()
	return null

## Get ship debt interest payment
func get_ship_debt_interest() -> int:
	if game_state and game_state.has_method("get_ship_debt_interest"):
		return game_state.get_ship_debt_interest()
	return 0

## Get number of active rivals
func get_rival_count() -> int:
	if game_state and game_state.has_method("get_rival_count"):
		return game_state.get_rival_count()
	return 0

## Remove rival from active rivals
func remove_rival(rival_id: String) -> void:
	if game_state and game_state.has_method("remove_rival"):
		game_state.remove_rival(rival_id)

## Add patron to contacts
func add_patron_contact(patron_id: String) -> void:
	if game_state and game_state.has_method("add_patron_contact"):
		game_state.add_patron_contact(patron_id)

## Dismiss patrons without persistence trait
func dismiss_non_persistent_patrons() -> void:
	if game_state and game_state.has_method("dismiss_non_persistent_patrons"):
		game_state.dismiss_non_persistent_patrons()

## Check if there's an active quest
func has_active_quest() -> bool:
	if game_state and game_state.has_method("has_active_quest"):
		return game_state.has_active_quest()
	return false

## Get number of quest rumors
func get_quest_rumors() -> int:
	if game_state and game_state.has_method("get_quest_rumors"):
		return game_state.get_quest_rumors()
	return 0

## Advance quest progress
func advance_quest(progress: int) -> void:
	if game_state and game_state.has_method("advance_quest"):
		game_state.advance_quest(progress)

## Check if crew can attack a rival
func can_attack_rival() -> bool:
	if game_state and game_state.has_method("can_attack_rival"):
		return game_state.can_attack_rival()
	return false

## Set current world location
func set_location(world_data: Dictionary) -> void:
	if game_state and game_state.has_method("set_location"):
		game_state.set_location(world_data)

## Check if invasion is pending
func has_pending_invasion() -> bool:
	if game_state and game_state.has_method("has_pending_invasion"):
		return game_state.has_pending_invasion()
	return false

## Set invasion pending status
func set_invasion_pending(pending: bool) -> void:
	if game_state and game_state.has_method("set_invasion_pending"):
		game_state.set_invasion_pending(pending)

## Add item to crew inventory
func add_inventory_item(item: Dictionary) -> void:
	if game_state and game_state.has_method("add_inventory_item"):
		game_state.add_inventory_item(item)

## Add contact for crew member
func add_crew_contact(crew_id: String, contact_id: String) -> void:
	if game_state and game_state.has_method("add_crew_contact"):
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
			push_warning("GameStateManager: Unknown test scenario - " + scenario_name)
			return false
	
	return true

## Simulate campaign progression to target turn
func _simulate_campaign_progression(target_turn: int) -> void:
	# This is a simplified simulation for testing purposes
	# In a real implementation, this would involve proper turn progression
	print("GameStateManager: Simulating progression to turn ", target_turn)
	
	# Basic progression simulation
	for turn in range(1, target_turn):
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
	if game_state and game_state.has_method("set_crew_size"):
		game_state.set_crew_size(crew_size)

## Create test rival encounters
func _create_test_rivals(rival_count: int) -> void:
	print("GameStateManager: Creating ", rival_count, " test rivals")
	
	if not game_state or not game_state.has_method("add_rival"):
		push_warning("GameStateManager: GameState is not available or does not have add_rival method.")
		return
		
	for i in range(rival_count):
		var test_rival_id = "test_rival_" + str(i + 1)
		game_state.add_rival(test_rival_id)

## Create test quest scenarios
func _create_test_quests(quest_count: int) -> void:
	print("GameStateManager: Creating ", quest_count, " test quests")
	
	# This would interface with the quest system
	if game_state and game_state.has_method("create_test_quests"):
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
	if game_state and game_state.has_method("set_rival_aggression"):
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
	if game_state and game_state.has_method("add_quest_rumors"):
		game_state.add_quest_rumors(5)

## Setup equipment showcase test scenario
func _setup_equipment_showcase_scenario() -> void:
	print("GameStateManager: Setting up equipment showcase scenario")
	
	# High credits for equipment testing
	set_credits(50000)
	
	# All equipment available
	if game_state and game_state.has_method("unlock_all_equipment"):
		game_state.unlock_all_equipment()

## Setup combat ready test scenario
func _setup_combat_ready_scenario() -> void:
	print("GameStateManager: Setting up combat ready scenario")
	
	# Set to battle phase
	if GameEnums and "FiveParsecsCampaignPhase" in GameEnums:
		if "BATTLE" in GameEnums.FiveParsecsCampaignPhase:
			set_campaign_phase(GameEnums.FiveParsecsCampaignPhase.BATTLE)
	
	# Create varied enemy types
	if game_state and game_state.has_method("setup_varied_enemies"):
		game_state.setup_varied_enemies()
