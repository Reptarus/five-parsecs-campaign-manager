@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignPhaseManager = preload("res://src/core/managers/CampaignPhaseManager.gd")

var _phase_manager: FiveParsecsCampaignPhaseManager
var game_state: Node

func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	
	_phase_manager = FiveParsecsCampaignPhaseManager.new(game_state)
	add_child_autofree(_phase_manager)
	watch_signals(_phase_manager)
	
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	_phase_manager = null
	game_state = null

func test_initial_phase() -> void:
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.NONE,
		"Initial phase should be NONE")

func test_phase_transitions() -> void:
	# Start campaign
	var initial_phase = _phase_manager.current_phase
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	# Wait for phase started signal
	var phase_started = await assert_async_signal(_phase_manager, "phase_started")
	assert_true(phase_started, "Phase started signal should be emitted")
	
	# Wait for phase changed signal
	var phase_changed = await assert_async_signal(_phase_manager, "phase_changed")
	assert_true(phase_changed, "Phase changed signal should be emitted")
	
	# Verify initial transition
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP,
		"Phase should be SETUP after start")
	
	# Test phase transitions
	var transitions = [
		[GameEnums.CampaignPhase.UPKEEP, "UPKEEP"],
		[GameEnums.CampaignPhase.CAMPAIGN, "CAMPAIGN"],
		[GameEnums.CampaignPhase.BATTLE_SETUP, "BATTLE_SETUP"]
	]
	
	for transition in transitions:
		var old_phase = _phase_manager.current_phase
		
		# Complete current phase
		_phase_manager.complete_phase()
		
		# Wait for phase signals
		var signals_to_wait = [
			[_phase_manager, "phase_completed"],
			[_phase_manager, "phase_started"],
			[_phase_manager, "phase_changed"]
		]
		
		var results = await await_signals(signals_to_wait)
		assert_false(results.is_empty(), "Phase transition signals should be received")
		
		# Verify phase change
		assert_eq(_phase_manager.current_phase, transition[0],
			"Phase should transition to " + transition[1])
		
		# Verify no error signals
		var phase_failed = await assert_async_signal(_phase_manager, "phase_failed", 0.5)
		assert_false(phase_failed, "Phase failed signal should not be emitted during valid transition")
		
		var validation_failed = await assert_async_signal(_phase_manager, "validation_failed", 0.5)
		assert_false(validation_failed, "Validation failed signal should not be emitted during valid transition")

func test_phase_validation() -> void:
	var initial_phase = _phase_manager.current_phase
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	# Wait for phase started
	var phase_started = await assert_async_signal(_phase_manager, "phase_started")
	assert_true(phase_started, "Phase started signal should be emitted")
	
	# Add test character to meet requirements
	var character = _create_test_character()
	_phase_manager.active_characters.append(character)
	
	# Complete setup phase
	var old_phase = _phase_manager.current_phase
	_phase_manager.complete_phase()
	
	# Wait for phase signals
	var signals_to_wait = [
		[_phase_manager, "phase_completed"],
		[_phase_manager, "phase_changed"]
	]
	
	var results = await await_signals(signals_to_wait)
	assert_false(results.is_empty(), "Phase transition signals should be received")
	
	# Verify successful transition
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.UPKEEP,
		"Phase should transition to UPKEEP after valid completion")
	
	# Verify no error signals
	var validation_failed = await assert_async_signal(_phase_manager, "validation_failed", 0.5)
	assert_false(validation_failed, "Validation failed signal should not be emitted for valid transition")
	
	var phase_failed = await assert_async_signal(_phase_manager, "phase_failed", 0.5)
	assert_false(phase_failed, "Phase failed signal should not be emitted for valid transition")

func test_phase_rollback() -> void:
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	var phase_started = await assert_async_signal(_phase_manager, "phase_started")
	assert_true(phase_started, "Phase started signal should be emitted")
	
	var setup_phase = _phase_manager.current_phase
	_phase_manager.complete_phase() # To UPKEEP
	var phase_completed = await assert_async_signal(_phase_manager, "phase_completed")
	assert_true(phase_completed, "Phase completed signal should be emitted")
	
	# Test rollback
	var from_phase = _phase_manager.current_phase
	var success = _phase_manager.rollback_phase("Testing rollback")
	
	# Wait for rollback signals
	var signals_to_wait = [
		[_phase_manager, "phase_rolled_back"],
		[_phase_manager, "phase_changed"]
	]
	
	var results = await await_signals(signals_to_wait)
	assert_false(results.is_empty(), "Rollback signals should be received")
	
	# Verify rollback success
	assert_true(success, "Rollback should succeed")
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP,
		"Phase should rollback to SETUP")

func test_phase_requirements() -> void:
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	var phase_started = await assert_async_signal(_phase_manager, "phase_started")
	assert_true(phase_started, "Phase started signal should be emitted")
	
	# Try to complete setup without meeting requirements
	_phase_manager.complete_phase()
	
	# Wait for validation failure signals
	var signals_to_wait = [
		[_phase_manager, "validation_failed"],
		[_phase_manager, "phase_failed"]
	]
	
	var results = await await_signals(signals_to_wait)
	assert_false(results.is_empty(), "Validation failure signals should be received")
	
	# Verify failed transition
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP,
		"Phase should remain SETUP when requirements not met")
	
	# Add required character and try again
	var character = _create_test_character()
	_phase_manager.active_characters.append(character)
	
	var old_phase = _phase_manager.current_phase
	_phase_manager.complete_phase()
	
	# Wait for successful transition signals
	signals_to_wait = [
		[_phase_manager, "phase_completed"],
		[_phase_manager, "phase_changed"]
	]
	
	results = await await_signals(signals_to_wait)
	assert_false(results.is_empty(), "Phase transition signals should be received")
	
	# Verify successful transition
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.UPKEEP,
		"Phase should transition to UPKEEP when requirements met")

# Helper function to create test character
func _create_test_character() -> FiveParsecsCharacter:
	var character = FiveParsecsCharacter.new()
	character.character_name = "Test Character"
	character.character_class = GameEnums.CharacterClass.SOLDIER
	return character