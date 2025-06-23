# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
extends Node

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameEnums = null
var GameState = null

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

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "GameStateManager GameEnums")
	GameState = UniversalResourceLoader.load_script_safe("res://src/core/state/GameState.gd", "GameStateManager GameState")
	
	# Initialize enum values after loading GameEnums
	if GameEnums:
		# Set default campaign phase to NONE if available
		if "FiveParcsecsCampaignPhase" in GameEnums and "NONE" in GameEnums.FiveParcsecsCampaignPhase:
			campaign_phase = GameEnums.FiveParcsecsCampaignPhase.NONE
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
		if GameState:
			game_state = GameState.new()
			print("GameStateManager: Created new game state")
		else:
			push_error("CRASH PREVENTION: GameState class not loaded")

func _validate_universal_connections() -> void:
	# Validate core system connections
	_validate_core_connections()
	_register_with_game_state()

func _validate_core_connections() -> void:
	# Validate required dependencies
	if not GameEnums:
		push_error("CORE SYSTEM FAILURE: GameEnums not accessible from GameStateManager")
	
	if not GameState:
		push_error("CORE SYSTEM FAILURE: GameState not accessible from GameStateManager")
	
	# Validate autoload connections
	var required_systems = ["EventBus"]
	for system_name in required_systems:
		var system = get_node_or_null("/root/" + system_name)
		if not system:
			push_warning("CORE DEPENDENCY MISSING: %s not found (GameStateManager)" % system_name)

func _register_with_game_state() -> void:
	# Register this manager with the global game state system
	var global_game_state = get_node_or_null("/root/GameState")
	if global_game_state and global_game_state.has_method("register_manager"):
		global_game_state.register_manager("GameStateManager", self)

func initialize_game_state() -> void:
	"""Initialize a new game state"""
	if not game_state:
		if GameState:
			game_state = GameState.new()
		else:
			push_error("CRASH PREVENTION: Cannot create GameState - class not loaded")
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

# Campaign management
func has_active_campaign() -> bool:
	"""Check if there's an active campaign"""
	if not game_state:
		return false
	return game_state.has_method("has_active_campaign") and game_state.has_active_campaign()

func start_new_campaign(campaign_config: Dictionary = {}) -> bool:
	"""Start a new campaign with given configuration"""
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

func save_current_state() -> bool:
	"""Save the current game state"""
	if not game_state:
		push_error("GameStateManager: No game state to save")
		return false
	
	if game_state.has_method("save_game"):
		return game_state.save_game("current_campaign")
	else:
		push_warning("GameStateManager: Game state doesn't support saving")
		return false

func load_saved_state(save_name: String = "current_campaign") -> bool:
	"""Load a saved game state"""
	if not game_state:
		initialize_game_state()
	
	if game_state.has_method("load_game"):
		return game_state.load_game(save_name)
	else:
		push_warning("GameStateManager: Game state doesn't support loading")
		return false

## Campaign System Integration Methods

# Credits Management
func add_credits(amount: int) -> void:
	"""Add credits to current total"""
	set_credits(credits + amount)

func remove_credits(amount: int) -> bool:
	"""Remove credits from current total"""
	if credits >= amount:
		set_credits(credits - amount)
		return true
	return false

# Crew Management
func get_crew_members() -> Array:
	"""Get array of crew members"""
	if game_state and game_state.has_method("get_crew_members"):
		return game_state.get_crew_members()
	return []

func get_crew_size() -> int:
	"""Get current crew size"""
	if game_state and game_state.has_method("get_crew_size"):
		return game_state.get_crew_size()
	return 4 # Default crew size

func get_sick_crew_count() -> int:
	"""Get number of crew members in sick bay"""
	if game_state and game_state.has_method("get_sick_crew_count"):
		return game_state.get_sick_crew_count()
	return 0

func add_crew_experience(crew_id: String, xp: int) -> void:
	"""Add experience to crew member"""
	if game_state and game_state.has_method("add_crew_experience"):
		game_state.add_crew_experience(crew_id, xp)

func apply_crew_injury(crew_id: String, injury_data: Dictionary) -> void:
	"""Apply injury to crew member"""
	if game_state and game_state.has_method("apply_crew_injury"):
		game_state.apply_crew_injury(crew_id, injury_data)

# Ship Management
func get_player_ship():
	"""Get player ship instance"""
	if game_state and game_state.has_method("get_player_ship"):
		return game_state.get_player_ship()
	return null

func get_ship_debt_interest() -> int:
	"""Get ship debt interest payment"""
	if game_state and game_state.has_method("get_ship_debt_interest"):
		return game_state.get_ship_debt_interest()
	return 0

# Rival System
func get_rival_count() -> int:
	"""Get number of active rivals"""
	if game_state and game_state.has_method("get_rival_count"):
		return game_state.get_rival_count()
	return 0

func remove_rival(rival_id: String) -> void:
	"""Remove rival from active rivals"""
	if game_state and game_state.has_method("remove_rival"):
		game_state.remove_rival(rival_id)

# Patron System
func add_patron_contact(patron_id: String) -> void:
	"""Add patron to contacts"""
	if game_state and game_state.has_method("add_patron_contact"):
		game_state.add_patron_contact(patron_id)

func dismiss_non_persistent_patrons() -> void:
	"""Dismiss patrons without persistence trait"""
	if game_state and game_state.has_method("dismiss_non_persistent_patrons"):
		game_state.dismiss_non_persistent_patrons()

# Quest System
func has_active_quest() -> bool:
	"""Check if there's an active quest"""
	if game_state and game_state.has_method("has_active_quest"):
		return game_state.has_active_quest()
	return false

func get_quest_rumors() -> int:
	"""Get number of quest rumors"""
	if game_state and game_state.has_method("get_quest_rumors"):
		return game_state.get_quest_rumors()
	return 0

func advance_quest(progress: int) -> void:
	"""Advance quest progress"""
	if game_state and game_state.has_method("advance_quest"):
		game_state.advance_quest(progress)

func can_attack_rival() -> bool:
	"""Check if crew can attack a rival"""
	if game_state and game_state.has_method("can_attack_rival"):
		return game_state.can_attack_rival()
	return false

# World System
func set_location(world_data: Dictionary) -> void:
	"""Set current world location"""
	if game_state and game_state.has_method("set_location"):
		game_state.set_location(world_data)

func has_pending_invasion() -> bool:
	"""Check if invasion is pending"""
	if game_state and game_state.has_method("has_pending_invasion"):
		return game_state.has_pending_invasion()
	return false

func set_invasion_pending(pending: bool) -> void:
	"""Set invasion pending status"""
	if game_state and game_state.has_method("set_invasion_pending"):
		game_state.set_invasion_pending(pending)

# Inventory System
func add_inventory_item(item: Dictionary) -> void:
	"""Add item to crew inventory"""
	if game_state and game_state.has_method("add_inventory_item"):
		game_state.add_inventory_item(item)

func add_crew_contact(crew_id: String, contact_id: String) -> void:
	"""Add contact for crew member"""
	if game_state and game_state.has_method("add_crew_contact"):
		game_state.add_crew_contact(crew_id, contact_id)

# Manager Registration System
var registered_managers: Dictionary = {}

func register_manager(manager_name: String, manager_instance: Node) -> void:
	"""Register a manager instance"""
	registered_managers[manager_name] = manager_instance
	print("GameStateManager: Registered manager '%s'" % manager_name)

func get_manager(manager_name: String) -> Node:
	"""Get registered manager instance"""
	return registered_managers.get(manager_name, null)

## Developer Testing Methods
## These methods support the DeveloperQuickStart panel for efficient playtesting

func create_test_campaign(campaign_data: Dictionary) -> bool:
	"""Create a test campaign with specified parameters for playtesting"""
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

func apply_test_scenario(scenario_name: String) -> bool:
	"""Apply a specific test scenario to current campaign"""
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

func _simulate_campaign_progression(target_turn: int) -> void:
	"""Simulate campaign progression to target turn"""
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

func _create_test_crew(crew_size: int) -> void:
	"""Create test crew members"""
	print("GameStateManager: Creating test crew of size ", crew_size)
	
	# This would interface with the crew system to generate test crew
	# For now, just store the desired size
	if game_state and game_state.has_method("set_crew_size"):
		game_state.set_crew_size(crew_size)

func _create_test_rivals(rival_count: int) -> void:
	"""Create test rival encounters"""
	print("GameStateManager: Creating ", rival_count, " test rivals")
	
	if not game_state or not game_state.has_method("add_rival"):
		push_warning("GameStateManager: GameState is not available or does not have add_rival method.")
		return
		
	for i in range(rival_count):
		var test_rival_id = "test_rival_" + str(i + 1)
		game_state.add_rival(test_rival_id)

func _create_test_quests(quest_count: int) -> void:
	"""Create test quest scenarios"""
	print("GameStateManager: Creating ", quest_count, " test quests")
	
	# This would interface with the quest system
	if game_state and game_state.has_method("create_test_quests"):
		game_state.create_test_quests(quest_count)

func _apply_test_equipment_level(level: String) -> void:
	"""Apply test equipment level to crew"""
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

func _apply_basic_equipment() -> void:
	"""Apply basic equipment set"""
	# Basic starting equipment
	pass

func _apply_improved_equipment() -> void:
	"""Apply improved equipment set"""
	# Mid-tier equipment
	pass

func _apply_advanced_equipment() -> void:
	"""Apply advanced equipment set"""
	# High-tier equipment
	pass

func _apply_elite_equipment() -> void:
	"""Apply elite equipment set"""
	# Top-tier equipment
	pass

## Test Scenario Setups

func _setup_rival_attack_scenario() -> void:
	"""Setup rival attack test scenario"""
	print("GameStateManager: Setting up rival attack scenario")
	
	# Create multiple active rivals
	_create_test_rivals(2)
	
	# Set high tension/aggression
	if game_state and game_state.has_method("set_rival_aggression"):
		game_state.set_rival_aggression("high")

func _setup_resource_crisis_scenario() -> void:
	"""Setup resource crisis test scenario"""
	print("GameStateManager: Setting up resource crisis scenario")
	
	# Set low resources
	set_credits(100)
	set_supplies(1)
	
	# Large crew to create upkeep pressure
	_create_test_crew(6)

func _setup_quest_chain_scenario() -> void:
	"""Setup quest chain test scenario"""
	print("GameStateManager: Setting up quest chain scenario")
	
	# Create multiple active quests
	_create_test_quests(3)
	
	# Add quest rumors
	if game_state and game_state.has_method("add_quest_rumors"):
		game_state.add_quest_rumors(5)

func _setup_equipment_showcase_scenario() -> void:
	"""Setup equipment showcase test scenario"""
	print("GameStateManager: Setting up equipment showcase scenario")
	
	# High credits for equipment testing
	set_credits(50000)
	
	# All equipment available
	if game_state and game_state.has_method("unlock_all_equipment"):
		game_state.unlock_all_equipment()

func _setup_combat_ready_scenario() -> void:
	"""Setup combat ready test scenario"""
	print("GameStateManager: Setting up combat ready scenario")
	
	# Set to battle phase
	if GameEnums and "FiveParcsecsCampaignPhase" in GameEnums:
		if "BATTLE" in GameEnums.FiveParcsecsCampaignPhase:
			set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.BATTLE)
	
	# Create varied enemy types
	if game_state and game_state.has_method("setup_varied_enemies"):
		game_state.setup_varied_enemies()
      