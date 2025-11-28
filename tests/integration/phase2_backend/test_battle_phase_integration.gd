extends GdUnitTestSuite
## Integration Tests: BattlePhase System
## Tests complete battle phase flow from setup to results
## gdUnit4 v6.0.1 compatible - UI mode only
## MAX 13 TESTS PER FILE

# System under test
var BattlePhaseClass: GDScript = null
var battle_phase: Node = null

# Supporting systems
var GameStateManagerClass: GDScript = null
var game_state_manager: Node = null

func before() -> void:
	"""Suite-level setup - runs once before all tests"""
	BattlePhaseClass = load("res://src/core/campaign/phases/BattlePhase.gd")
	GameStateManagerClass = load("res://src/core/managers/GameStateManager.gd")

func before_test() -> void:
	"""Test-level setup - create fresh instances for each test"""
	# Create battle phase instance
	battle_phase = auto_free(BattlePhaseClass.new())

	# Wait for _ready() to complete
	await await_signal_on(battle_phase, "ready", [], 2000)

	# Create basic game state manager mock
	game_state_manager = _create_mock_game_state_manager()

func after_test() -> void:
	"""Test-level cleanup"""
	battle_phase = null
	game_state_manager = null

func after() -> void:
	"""Suite-level cleanup - runs once after all tests"""
	BattlePhaseClass = null
	GameStateManagerClass = null

# ============================================================================
# Battle Phase Core Tests (10 tests)
# ============================================================================

@warning_ignore("return_value_discarded")
func test_battle_phase_starts_correctly() -> void:
	"""Battle phase starts and emits battle_phase_started signal"""
	# Create signal monitor
	var _monitor := monitor_signals(battle_phase)

	# Start battle phase
	battle_phase.start_battle_phase()

	# Verify signal emitted
	assert_signal(battle_phase).is_emitted("battle_phase_started")
	assert_bool(battle_phase.battle_in_progress).is_true()

@warning_ignore("return_value_discarded")
func test_battle_setup_generates_enemies() -> void:
	"""Battle setup generates appropriate enemy count"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for setup completion
	await await_signal_on(battle_phase, "battle_setup_completed", [], 2000)

	# Verify battle setup data contains enemies
	var setup: Dictionary = battle_phase.battle_setup_data
	assert_that(setup).contains_keys(["enemy_count", "enemy_types"])
	assert_int(setup.get("enemy_count", 0)).is_greater(0)

@warning_ignore("return_value_discarded")
func test_deployment_positions_crew_and_enemies() -> void:
	"""Deployment phase positions both crew and enemies"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for deployment completion
	await await_signal_on(battle_phase, "deployment_completed", [], 3000)

	# Verify deployment data
	var deployment: Dictionary = battle_phase.deployment_data
	assert_that(deployment).contains_keys(["crew_positions", "enemy_positions"])
	assert_array(deployment.get("crew_positions", [])).is_not_empty()
	assert_array(deployment.get("enemy_positions", [])).is_not_empty()

@warning_ignore("return_value_discarded")
func test_initiative_roll_within_valid_range() -> void:
	"""Initiative roll is within valid 1-6 range"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for initiative determination
	await await_signal_on(battle_phase, "initiative_determined", [], 4000)

	# Verify initiative roll
	assert_int(battle_phase.initiative_roll).is_between(1, 6)

@warning_ignore("return_value_discarded")
func test_battle_results_generated() -> void:
	"""Battle phase generates combat results"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for battle completion
	await await_signal_on(battle_phase, "battle_results_ready", [], 5000)

	# Verify results structure
	var results: Dictionary = battle_phase.get_battle_results()
	assert_that(results).contains_keys(["success", "rounds_fought", "enemies_defeated"])

@warning_ignore("return_value_discarded")
func test_battle_phase_completes_successfully() -> void:
	"""Battle phase completes and emits battle_phase_completed signal"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for completion
	await await_signal_on(battle_phase, "battle_phase_completed", [], 5000)

	# Verify phase completed
	assert_bool(battle_phase.battle_in_progress).is_false()
	assert_signal(battle_phase).is_emitted("battle_phase_completed")

@warning_ignore("return_value_discarded")
func test_battle_setup_includes_mission_type() -> void:
	"""Battle setup includes valid mission type"""
	# Start battle phase with mission data
	var mission_data: Dictionary = {"mission_type": 1}
	battle_phase.start_battle_phase(mission_data)

	# Wait for setup completion
	await await_signal_on(battle_phase, "battle_setup_completed", [], 2000)

	# Verify mission type preserved
	var setup: Dictionary = battle_phase.battle_setup_data
	assert_that(setup).contains_key("mission_type")

@warning_ignore("return_value_discarded")
func test_combat_results_include_casualties() -> void:
	"""Combat results track crew casualties"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for results
	await await_signal_on(battle_phase, "battle_results_ready", [], 5000)

	# Verify casualty tracking
	var results: Dictionary = battle_phase.get_battle_results()
	assert_that(results).contains_key("crew_casualties")

@warning_ignore("return_value_discarded")
func test_victory_determines_loot_opportunities() -> void:
	"""Successful battles generate loot opportunities"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for results
	await await_signal_on(battle_phase, "battle_results_ready", [], 5000)

	# Verify loot opportunities present
	var results: Dictionary = battle_phase.get_battle_results()
	if results.get("success", false):
		assert_that(results).contains_key("loot_opportunities")

@warning_ignore("return_value_discarded")
func test_deployed_crew_tracked_correctly() -> void:
	"""Crew members deployed to battle are tracked"""
	# Start battle phase
	battle_phase.start_battle_phase()

	# Wait for deployment
	await await_signal_on(battle_phase, "deployment_completed", [], 3000)

	# Verify crew deployment tracking
	var deployed_crew: Array = battle_phase.get_deployed_crew()
	assert_array(deployed_crew).is_not_null()

# ============================================================================
# Helper Methods
# ============================================================================

func _create_mock_game_state_manager() -> Node:
	"""Create a minimal mock GameStateManager for testing"""
	var mock_node := Node.new()
	auto_free(mock_node)

	# Add mock methods
	var script := GDScript.new()
	script.source_code = """
		extends Node

		func get_crew_size() -> int:
			return 4

		func get_crew_members() -> Array:
			return [
				{"id": "crew_0", "character_name": "Test Captain", "status": 0},
				{"id": "crew_1", "character_name": "Test Soldier", "status": 0}
			]
	"""
	@warning_ignore("return_value_discarded")
	script.reload()
	mock_node.set_script(script)

	return mock_node
