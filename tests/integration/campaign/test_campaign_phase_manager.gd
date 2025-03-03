@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# Type-safe script references
const CampaignPhaseManager := preload("res://src/core/campaign/CampaignPhaseManager.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")
const CampaignManagerScript := preload("res://src/core/managers/CampaignManager.gd")
const CampaignPhaseManagerScript := preload("res://src/core/campaign/CampaignPhaseManager.gd")

# Type-safe enums
enum CampaignPhase {
	SETUP,
	STORY,
	BATTLE,
	RESOLUTION,
	UPKEEP,
	ADVANCEMENT
}

# Type-safe instance variables
var _phase_manager: Node = null
var _test_enemies: Array[Node] = []
var _campaign_manager: Node = null

# Type-safe constants
const PHASE_TIMEOUT := 2.0
const STABILIZE_WAIT := 0.1

func before_each() -> void:
	await super.before_each()
	
	# Initialize campaign test environment
	_game_state = Node.new()
	_game_state.set_script(GameStateManager)
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	_campaign_manager = Node.new()
	_campaign_manager.set_script(CampaignManagerScript)
	if not _campaign_manager:
		push_error("Failed to create campaign manager")
		return
	add_child_autofree(_campaign_manager)
	track_test_node(_campaign_manager)
	
	_phase_manager = Node.new()
	_phase_manager.set_script(CampaignPhaseManagerScript)
	if not _phase_manager:
		push_error("Failed to create phase manager")
		return
	add_child_autofree(_phase_manager)
	track_test_node(_phase_manager)
	
	# Create test enemies
	_setup_test_enemies()
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_cleanup_test_enemies()
	
	if is_instance_valid(_campaign_manager):
		_campaign_manager.queue_free()
	if is_instance_valid(_phase_manager):
		_phase_manager.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
		
	_campaign_manager = null
	_phase_manager = null
	_game_state = null
	
	await super.after_each()

# Helper Methods
func _setup_test_enemies() -> void:
	# Create a mix of enemy types
	var enemy_types := ["BASIC", "ELITE", "BOSS"]
	for type in enemy_types:
		var enemy := _create_test_enemy(type)
		if not enemy:
			push_error("Failed to create enemy of type: %s" % type)
			continue
		_test_enemies.append(enemy)
		add_child_autofree(enemy)
		track_test_node(enemy)

# Helper method to create test enemies since CampaignTest doesn't have this method
func _create_test_enemy(type: String) -> Node:
	var enemy := Node.new()
	enemy.name = "TestEnemy_" + type
	
	# Add some basic enemy properties based on type
	match type:
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
	for enemy in _test_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_test_enemies.clear()

func verify_phase_transition(from_phase: int, to_phase: int) -> void:
	assert_eq(
		_call_node_method_int(_phase_manager, "get_current_phase", []),
		from_phase,
		"Should start in correct phase"
	)
	
	_signal_watcher.watch_signals(_phase_manager)
	_call_node_method_bool(_phase_manager, "transition_to", [to_phase])
	
	await stabilize_engine(STABILIZE_WAIT)
	
	assert_eq(
		_call_node_method_int(_phase_manager, "get_current_phase", []),
		to_phase,
		"Should transition to new phase"
	)
	verify_signal_emitted(_phase_manager, "phase_changed")

# Test Methods
func test_phase_manager_initialization():
	"""Test that the phase manager initializes correctly."""
	# Then it should be set to the initial phase
	assert_eq(
		_call_node_method_int(_phase_manager, "get_current_phase", []),
		CampaignPhase.SETUP
	)

func test_phase_transitions():
	"""Test that the phase manager can transition between phases correctly."""
	# When transitioning to a new phase
	var to_phase = CampaignPhase.STORY
	assert_true(
		_call_node_method_bool(_phase_manager, "transition_to", [to_phase])
	)
	
	# Then the current phase should be updated
	assert_eq(
		_call_node_method_int(_phase_manager, "get_current_phase", []),
		to_phase
	)
	
	# Test invalid transition (skipping phases)
	to_phase = CampaignPhase.ADVANCEMENT
	assert_false(
		_call_node_method_bool(_phase_manager, "transition_to", [to_phase])
	)
	
	# Current phase should remain unchanged
	assert_eq(
		_call_node_method_int(_phase_manager, "get_current_phase", []),
		CampaignPhase.STORY
	)

func test_campaign_integration():
	"""Test that the campaign manager integrates with phase manager correctly."""
	# Given an initialized campaign manager
	assert_true(
		_call_node_method_bool(_campaign_manager, "initialize", [])
	)
	assert_true(
		_call_node_method_bool(_campaign_manager, "is_initialized", []),
		"Campaign manager should be initialized"
	)
	
	# When going through the story phase
	assert_true(
		_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.STORY])
	)
	
	# Then we should be able to get story events
	var story_events: Array[Dictionary] = _call_node_method_array(_campaign_manager, "get_story_events", [])
	
	assert_true(story_events.size() > 0, "Should have at least one story event")
	
	var event = story_events[0]
	assert_true(
		_call_node_method_bool(_campaign_manager, "resolve_story_event", [event]),
		"Should be able to resolve a story event"
	)
	
	# When transitioning to battle phase
	assert_true(
		_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.BATTLE])
	)
	
	# Then we should be able to set up a battle
	assert_true(
		_call_node_method_bool(_campaign_manager, "setup_battle", []),
		"Should be able to set up a battle"
	)
	
	# Register an enemy
	var enemy = _create_test_enemy("BASIC")
	assert_true(
		_call_node_method_bool(_campaign_manager, "register_enemy", [enemy]),
		"Should be able to register an enemy"
	)
	
	# When transitioning to battle resolution
	assert_true(
		_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.RESOLUTION])
	)
	
	# Then we should be able to get campaign results
	var campaign_results: Dictionary = _call_node_method_dict(_campaign_manager, "get_campaign_results", [])
	
	assert_not_null(campaign_results, "Should have campaign results")
	
	# Clean up the enemy
	assert_true(
		_call_node_method_bool(enemy, "cleanup", [])
	)
	
	assert_true(
		_call_node_method_bool(enemy, "is_cleaned_up", []),
		"Enemy should be cleaned up"
	)
	
	# When transitioning to upkeep phase
	assert_true(
		_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.UPKEEP])
	)
	
	# Then we should be able to get resources and calculate upkeep
	var resources: Dictionary = _call_node_method_dict(_campaign_manager, "get_resources", [])
	
	assert_not_null(resources, "Should have resources")
	
	var upkeep_costs: Dictionary = _call_node_method_dict(_campaign_manager, "calculate_upkeep", [])
	
	assert_not_null(upkeep_costs, "Should have upkeep costs")
	
	# When transitioning to advancement phase
	assert_true(
		_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.ADVANCEMENT])
	)
	
	# Then we should be able to get characters and advance them
	var characters: Array[Dictionary] = _call_node_method_array(_campaign_manager, "get_characters", [])
	
	if characters.size() > 0:
		var character = characters[0]
		assert_true(
			_call_node_method_bool(_campaign_manager, "can_advance_character", [character]),
			"Should be able to advance a character"
		)
	
	# Finally, advance the campaign
	assert_true(
		_call_node_method_bool(_campaign_manager, "advance_campaign", []),
		"Should be able to advance the campaign"
	)

func test_full_campaign_cycle():
	"""Test a full campaign cycle with all phases."""
	# Given an initialized campaign
	assert_true(_call_node_method_bool(_campaign_manager, "initialize", []))
	
	# When going through all phases in order
	
	# 1. Story Phase
	assert_true(_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.STORY]))
	var events: Array[Dictionary] = _call_node_method_array(_campaign_manager, "get_story_events", [])
	if events.size() > 0:
		var event = events[0]
		assert_true(_call_node_method_bool(_campaign_manager, "resolve_story_event", [event]))
	
	# 2. Battle Setup
	assert_true(_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.BATTLE]))
	assert_true(_call_node_method_bool(_campaign_manager, "setup_battle", []))
	
	# Register an enemy
	var enemy = _create_test_enemy("BASIC")
	assert_true(_call_node_method_bool(_campaign_manager, "register_enemy", [enemy]))
	
	# 3. Battle Resolution
	assert_true(_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.RESOLUTION]))
	var results: Dictionary = _call_node_method_dict(_campaign_manager, "get_campaign_results", [])
	
	# 4. Upkeep
	assert_true(_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.UPKEEP]))
	var costs: Dictionary = _call_node_method_dict(_campaign_manager, "calculate_upkeep", [])
	assert_true(_call_node_method_bool(_campaign_manager, "apply_upkeep", [costs]))
	
	# 5. Advancement
	assert_true(_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.ADVANCEMENT]))
	assert_true(_call_node_method_bool(_campaign_manager, "advance_campaign", []))
	
	# Then we should be back at the story phase
	assert_true(_call_node_method_bool(_phase_manager, "transition_to", [CampaignPhase.STORY]))
	
	# And we should have updated campaign results
	assert_eq(
		_call_node_method_int(_phase_manager, "get_current_phase", []),
		CampaignPhase.STORY
	)
	
	var final_results: Dictionary = _call_node_method_dict(_campaign_manager, "get_campaign_results", [])
	assert_not_null(final_results)

func test_campaign_manager_hooks() -> void:
	# Register an enemy
	var enemy = _create_test_enemy("BASIC")
	assert_true(
		_call_node_method_bool(_campaign_manager, "register_enemy", [enemy]),
		"Should be able to register an enemy"
	)