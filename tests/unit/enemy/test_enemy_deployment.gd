@tool
extends FiveParsecsEnemyTest

var _deployment_manager: EnemyDeploymentManager
var _battle_map: Node

func before_each() -> void:
	await super.before_each()
	
	# Create battle map
	_battle_map = Node.new()
	_battle_map.name = "BattleMap"
	add_child_autofree(_battle_map)
	
	# Create deployment manager
	_deployment_manager = EnemyDeploymentManager.new()
	track_test_resource(_deployment_manager)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_deployment_manager = null
	_battle_map = null
	await super.after_each()

func test_deployment_type_selection() -> void:
	# Test aggressive behavior
	var aggressive_type = _deployment_manager.get_deployment_type(
		GameEnums.AIBehavior.AGGRESSIVE)
	assert_true(aggressive_type in [
		GameEnums.DeploymentType.STANDARD,
		GameEnums.DeploymentType.AMBUSH,
		GameEnums.DeploymentType.OFFENSIVE
	], "Aggressive behavior should use appropriate deployment types")
	
	# Test cautious behavior
	var cautious_type = _deployment_manager.get_deployment_type(
		GameEnums.AIBehavior.CAUTIOUS)
	assert_true(cautious_type in [
		GameEnums.DeploymentType.LINE,
		GameEnums.DeploymentType.DEFENSIVE,
		GameEnums.DeploymentType.CONCEALED
	], "Cautious behavior should use appropriate deployment types")

func test_standard_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.STANDARD
	)
	
	assert_not_null(positions, "Deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_line_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.LINE
	)
	
	assert_not_null(positions, "Line deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_ambush_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.AMBUSH
	)
	
	assert_not_null(positions, "Ambush deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_scattered_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.SCATTERED
	)
	
	assert_not_null(positions, "Scattered deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_defensive_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.DEFENSIVE
	)
	
	assert_not_null(positions, "Defensive deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_infiltration_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.INFILTRATION
	)
	
	assert_not_null(positions, "Infiltration deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_reinforcement_deployment() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.REINFORCEMENT
	)
	
	assert_not_null(positions, "Reinforcement deployment positions should be generated")
	verify_signal_emitted(_deployment_manager, "enemy_deployment_generated")

func test_deployment_validation() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		GameEnums.DeploymentType.STANDARD
	)
	
	# Validate deployment
	verify_signal_emitted(_deployment_manager, "deployment_validated")

func test_invalid_deployment_type() -> void:
	watch_signals(_deployment_manager)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		-1  # Invalid type
	)
	
	assert_true(positions.is_empty(),
		"Invalid deployment type should return empty positions")

func test_deployment_pattern_matching() -> void:
	# Test aggressive behavior patterns
	var aggressive_type = _deployment_manager.get_deployment_type(
		GameEnums.AIBehavior.AGGRESSIVE)
	var positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		aggressive_type
	)
	
	assert_not_null(positions,
		"Deployment positions should match behavior pattern")
	
	# Test cautious behavior patterns
	var cautious_type = _deployment_manager.get_deployment_type(
		GameEnums.AIBehavior.CAUTIOUS)
	positions = _deployment_manager.generate_deployment_positions(
		_battle_map,
		cautious_type
	)
	
	assert_not_null(positions,
		"Deployment positions should match behavior pattern") 