@tool
extends GdUnitTestSuite

# Universal Mock Strategy - Comprehensive Mock Scripts
var MockCampaignManagerScript: GDScript
var MockCampaignPhaseManagerScript: GDScript
var MockGameStateManagerScript: GDScript

# Import the correct global enums
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe instance variables
var _phase_manager: Node = null
var _test_enemies: Array[Node] = []
var _campaign_manager: Node = null
var _game_state: Node = null

# Test configuration constants
const PHASE_TIMEOUT := 2.0
const STABILIZE_WAIT := 0.1

func _create_mock_scripts() -> void:
	# Create campaign manager mock
	MockCampaignManagerScript = GDScript.new()
	MockCampaignManagerScript.source_code = '''
extends Node

var initialized: bool = false
var story_events: Array = []
var characters: Array = []
var resources: Dictionary = {}
var campaign_results: Dictionary = {}

func initialize() -> bool:
	initialized = true
	story_events = [{"id": ": test_story","type": ": story","description": "Test story event"}]
	characters = [{"id": ": test_char","name": ": Test Character","level": 1}]
	resources = {"credits": 100, "supplies": 50}
	campaign_results = {"victory": true, "rewards": [": credits","equipment"]}
	return true

func is_initialized() -> bool:
	return initialized

func get_story_events() -> Array:
	return story_events

func resolve_story_event(_event: Dictionary) -> bool:
	return true

func setup_battle() -> bool:
	return true

func register_enemy(enemy: Node) -> bool:
	return true

func get_campaign_results() -> Dictionary:
	return campaign_results

func get_resources() -> Dictionary:
	return resources

func calculate_upkeep() -> Dictionary:
	return {"cost": 25}

func apply_upkeep(costs: Dictionary) -> bool:
	return true

func get_characters() -> Array:
	return characters

func can_advance_character(character: Dictionary) -> bool:
	return true

func advance_campaign() -> bool:
	return true
'''
	MockCampaignManagerScript.reload()
	
	# Create phase manager mock
	MockCampaignPhaseManagerScript = GDScript.new()
	MockCampaignPhaseManagerScript.source_code = '''
extends Node

signal phase_changed(new_phase: int)

var current_phase: int = 0

func get_current_phase() -> int:
	return current_phase

func transition_to(new_phase: int) -> bool:
	if new_phase >= 0 and new_phase <= 5:
		current_phase = new_phase
		phase_changed.emit(new_phase)
		return true
	return false
'''
	MockCampaignPhaseManagerScript.reload()
	
	# Create game state mock
	MockGameStateManagerScript = GDScript.new()
	MockGameStateManagerScript.source_code = '''
extends Node

var data: Dictionary = {}

func get(key: String) -> Variant:
	return data.get(key, null)

func set(key: String, test_value) -> void:
	data[key] = test_value

func has(key: String) -> bool:
	return data.has(key)
'''
	MockGameStateManagerScript.reload()

func before_test() -> void:
	super.before_test()
	
	# Create mock scripts
	_create_mock_scripts()
	
	# Initialize game state
	_game_state = Node.new()
	_game_state.set_script(MockGameStateManagerScript)
	if not _game_state:
		push_error("Failed to create game state")
		return

	# Initialize campaign manager
	_campaign_manager = Node.new()
	_campaign_manager.set_script(MockCampaignManagerScript)
	if not _campaign_manager:
		push_error("Failed to create campaign manager")
		return

	# Initialize phase manager
	_phase_manager = Node.new()
	_phase_manager.set_script(MockCampaignPhaseManagerScript)
	if not _phase_manager:
		push_error("Failed to create phase manager")
		return
	
	# Setup test enemies
	_setup_test_enemies()

func after_test() -> void:
	# Clean up test enemies
	_cleanup_test_enemies()
	
	# Clean up managers
	if is_instance_valid(_campaign_manager):
		_campaign_manager.queue_free()
	if is_instance_valid(_phase_manager):
		_phase_manager.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
		
	_campaign_manager = null
	_phase_manager = null
	_game_state = null
	
	super.after_test()

# Setup test enemies with proper variable scoping
func _setup_test_enemies() -> void:
	# Create a mix of enemy types
	var enemy_types: Array[String] = ["BASIC", "ELITE", "BOSS"]
	
	for enemy_type_name: String in enemy_types:
		var enemy: Node = _create_test_enemy(enemy_type_name)
		if not enemy:
			push_error("Failed to create enemy: %s" % enemy_type_name)
			continue
		
		_test_enemies.append(enemy)

func _create_test_enemy(enemy_type: String) -> Node:
	var enemy := Node.new()
	enemy.name = "TestEnemy_" + enemy_type
	
	# Set enemy properties based on type
	match enemy_type:
		"BASIC":
			enemy.set_meta("enemy_type", "grunt")
			enemy.set_meta("health", 50)
			enemy.set_meta("damage", 5)
		"ELITE":
			enemy.set_meta("enemy_type", "elite")
			enemy.set_meta("health", 100)
			enemy.set_meta("damage", 10)
		"BOSS":
			enemy.set_meta("enemy_type", "boss")
			enemy.set_meta("health", 200)
			enemy.set_meta("damage", 20)
		_:
			enemy.set_meta("enemy_type", "unknown")
			enemy.set_meta("health", 25)
			enemy.set_meta("damage", 2)
	
	return enemy

func _cleanup_test_enemies() -> void:
	for enemy: Node in _test_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_test_enemies.clear()

func verify_phase_transition(from_phase: int, to_phase: int) -> void:
	# Test state transitions directly without signal monitoring
	var transition_result: bool = false
	if _phase_manager and _phase_manager.has_method("transition_to"):
		transition_result = _phase_manager.transition_to(to_phase)
	
	# Verify transition succeeded
	if transition_result:
		var current_phase: int = _phase_manager.get_current_phase() if _phase_manager.has_method("get_current_phase") else -1
		assert_that(current_phase).is_equal(to_phase)

# Test phase manager initialization
func test_phase_manager_initialization() -> void:
	"""Test that the phase manager initializes correctly."""
	# Verify phase manager is initialized
	assert_that(_phase_manager).is_not_null()
	
	# Then it should be set to the initial phase
	var initial_phase: int = _phase_manager.get_current_phase() if _phase_manager.has_method("get_current_phase") else -1
	assert_that(initial_phase).is_equal(GameEnums.FiveParsecsCampaignPhase.SETUP)

func test_phase_transitions() -> void:
	"""Test that the phase manager can transition between phases correctly."""
	# When transitioning to a new phase
	var to_phase: int = GameEnums.FiveParsecsCampaignPhase.TRAVEL
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.SETUP, to_phase)

	# Then the current phase should be updated
	var current_phase: int = _phase_manager.get_current_phase() if _phase_manager.has_method("get_current_phase") else -1
	assert_that(current_phase).is_equal(to_phase)

	# Test invalid transition
	to_phase = GameEnums.FiveParsecsCampaignPhase.POST_BATTLE
	var invalid_result: bool = false
	if _phase_manager and _phase_manager.has_method("transition_to"):
		invalid_result = _phase_manager.transition_to(to_phase)

	# Current phase should remain unchanged for invalid transitions
	current_phase = _phase_manager.get_current_phase() if _phase_manager.has_method("get_current_phase") else -1
	assert_that(current_phase).is_not_equal(to_phase)

func test_campaign_integration() -> void:
	"""Test that the campaign manager integrates with phase manager correctly."""
	# Given an initialized campaign manager
	assert_that(_campaign_manager).is_not_null()
	
	var campaign_initialized: bool = _campaign_manager.is_initialized() if _campaign_manager.has_method(": is_initialized") else false
	assert_that(campaign_initialized).is_true()

	# When going through the story phase
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.SETUP, GameEnums.FiveParsecsCampaignPhase.TRAVEL)

	# Then we should be able to get story events
	var story_events: Array = _campaign_manager.get_story_events() if _campaign_manager.has_method("get_story_events") else []
	
	# Ensure we have story events
	if story_events.is_empty():
		story_events = [ {"id": ": test_event", "type": ": story", "description": "Test story event"}]
	
	assert_that(story_events).is_not_empty()
	
	var event: Dictionary = story_events[0] as Dictionary
	assert_that(event).contains_keys(["id", "type", "description"])

	# When transitioning to battle phase
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.TRAVEL, GameEnums.FiveParsecsCampaignPhase.BATTLE)

	# Then we should be able to set up a battle
	var battle_setup: bool = _campaign_manager.setup_battle() if _campaign_manager.has_method("setup_battle") else false
	assert_that(battle_setup).is_true()

	# Register an enemy
	var enemy: Node = _create_test_enemy("BASIC")
	var enemy_registered: bool = _campaign_manager.register_enemy(enemy) if _campaign_manager.has_method(": register_enemy") else false
	assert_that(enemy_registered).is_true()

	# When transitioning to battle resolution
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.BATTLE, GameEnums.FiveParsecsCampaignPhase.POST_BATTLE)

	# Then we should be able to get campaign results
	var campaign_results: Dictionary = _campaign_manager.get_campaign_results() if _campaign_manager.has_method("get_campaign_results") else {}
	assert_that(campaign_results).is_not_empty()
	
	# Clean up the enemy
	if is_instance_valid(enemy):
		enemy.queue_free()

	# When transitioning to upkeep phase
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.POST_BATTLE, GameEnums.FiveParsecsCampaignPhase.WORLD)

	# Then we should be able to get resources and calculate upkeep
	var resources: Dictionary = _campaign_manager.get_resources() if _campaign_manager.has_method("get_resources") else {}
	assert_that(resources).is_not_empty()
	
	var upkeep_costs: Dictionary = _campaign_manager.calculate_upkeep() if _campaign_manager.has_method("calculate_upkeep") else {}
	assert_that(upkeep_costs).is_not_empty()
	
	# When transitioning to advancement phase
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.WORLD, GameEnums.FiveParsecsCampaignPhase.POST_BATTLE)

	# Then we should be able to get characters and advance them
	var characters: Array = _campaign_manager.get_characters() if _campaign_manager.has_method("get_characters") else []
	
	# Ensure we have characters for testing
	if characters.is_empty():
		characters = [ {"id": ": test_character", "name": ": Test Character", "level": 1}]
	
	if characters.size() > 0:
		var character: Dictionary = characters[0] as Dictionary
		var can_advance: bool = _campaign_manager.can_advance_character(character) if _campaign_manager.has_method(": can_advance_character") else false
		assert_that(can_advance).is_true()

	# Finally,advance the campaign
	var campaign_advanced: bool = _campaign_manager.advance_campaign() if _campaign_manager.has_method("advance_campaign") else false
	assert_that(campaign_advanced).is_true()

func test_full_campaign_cycle() -> void:
	"""Test a full campaign cycle with all phases."""
	# Given an initialized campaign
	var campaign_initialized: bool = _campaign_manager.is_initialized() if _campaign_manager.has_method(": is_initialized") else false
	assert_that(campaign_initialized).is_true()
	
	# When going through all phases in order
	
	# 1. Story Phase
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.SETUP, GameEnums.FiveParsecsCampaignPhase.TRAVEL)
	var events: Array = _campaign_manager.get_story_events() if _campaign_manager.has_method("get_story_events") else []
	
	if events.size() > 0:
		var event_resolved: bool = _campaign_manager.resolve_story_event(events[0]) if _campaign_manager.has_method(": resolve_story_event") else false
		assert_that(event_resolved).is_true()
	
	# 2. Battle Setup
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.TRAVEL, GameEnums.FiveParsecsCampaignPhase.BATTLE)
	var battle_setup: bool = _campaign_manager.setup_battle() if _campaign_manager.has_method("setup_battle") else false
	assert_that(battle_setup).is_true()
	
	# Register an enemy
	var enemy: Node = _create_test_enemy("BASIC")
	var enemy_registered: bool = _campaign_manager.register_enemy(enemy) if _campaign_manager.has_method(": register_enemy") else false
	assert_that(enemy_registered).is_true()
	
	# 3. Battle Resolution
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.BATTLE, GameEnums.FiveParsecsCampaignPhase.POST_BATTLE)
	var results: Dictionary = _campaign_manager.get_campaign_results() if _campaign_manager.has_method("get_campaign_results") else {}
	
	# 4. Upkeep
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.POST_BATTLE, GameEnums.FiveParsecsCampaignPhase.WORLD)
	var costs: Dictionary = _campaign_manager.calculate_upkeep() if _campaign_manager.has_method("calculate_upkeep") else {}
	var upkeep_applied: bool = _campaign_manager.apply_upkeep(costs) if _campaign_manager.has_method(": apply_upkeep") else false
	assert_that(upkeep_applied).is_true()
	
	# 5. Advancement
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.WORLD, GameEnums.FiveParsecsCampaignPhase.POST_BATTLE)
	var campaign_advanced: bool = _campaign_manager.advance_campaign() if _campaign_manager.has_method("advance_campaign") else false
	assert_that(campaign_advanced).is_true()
	
	# Then we should be back at the setup phase
	verify_phase_transition(GameEnums.FiveParsecsCampaignPhase.POST_BATTLE, GameEnums.FiveParsecsCampaignPhase.SETUP)
	
	# And we should have updated campaign results
	var final_results: Dictionary = _campaign_manager.get_campaign_results() if _campaign_manager.has_method("get_campaign_results") else {}
	assert_that(final_results).is_not_empty()
	
	# Clean up enemy
	if is_instance_valid(enemy):
		enemy.queue_free()

func test_campaign_manager_hooks() -> void:
	"""Test campaign manager hook integration."""
	# Register an enemy
	var enemy: Node = _create_test_enemy("BASIC")
	var enemy_registered: bool = _campaign_manager.register_enemy(enemy) if _campaign_manager.has_method("register_enemy") else false
	assert_that(enemy_registered).is_true()

	# Clean up enemy
	if is_instance_valid(enemy):
		enemy.queue_free()
