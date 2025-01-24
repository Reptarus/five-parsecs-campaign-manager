@tool
extends "res://tests/fixtures/base_test.gd"

const CampaignPhaseManager = preload("res://src/core/managers/CampaignPhaseManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")

var _phase_manager: FiveParsecsCampaignPhaseManager
var _game_state: GameState

func before_each() -> void:
	await super.before_each()
	_game_state = GameState.new()
	add_child(_game_state)
	track_test_node(_game_state)
	
	_phase_manager = FiveParsecsCampaignPhaseManager.new(_game_state)
	add_child(_phase_manager)
	track_test_node(_phase_manager)

func after_each() -> void:
	await super.after_each()
	_phase_manager = null
	_game_state = null

func test_initial_phase() -> void:
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.NONE)

func test_phase_transitions() -> void:
	# Start campaign
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP)
	
	# Test phase transitions
	_phase_manager.complete_phase()
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.UPKEEP)
	
	_phase_manager.complete_phase()
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.CAMPAIGN)
	
	_phase_manager.complete_phase()
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.BATTLE_SETUP)

func test_phase_validation() -> void:
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	# Add test character to meet requirements
	var character = _create_test_character()
	_phase_manager.active_characters.append(character)
	
	# Complete setup phase
	_phase_manager.complete_phase()
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.UPKEEP)

func test_phase_rollback() -> void:
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	_phase_manager.complete_phase() # To UPKEEP
	
	# Test rollback
	var success = _phase_manager.rollback_phase("Testing rollback")
	assert_true(success)
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP)

func test_phase_signals() -> void:
	var phase_started_emitted = false
	var phase_completed_emitted = false
	
	_phase_manager.phase_started.connect(
		func(phase: int): phase_started_emitted = true
	)
	_phase_manager.phase_completed.connect(
		func(phase: int): phase_completed_emitted = true
	)
	
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	assert_true(phase_started_emitted)
	
	_phase_manager.complete_phase()
	assert_true(phase_completed_emitted)

func test_phase_requirements() -> void:
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	# Try to complete setup without meeting requirements
	_phase_manager.complete_phase()
	
	# Should not advance due to missing requirements
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP)
	
	# Add required character
	var character = _create_test_character()
	_phase_manager.active_characters.append(character)
	
	# Now should be able to complete
	_phase_manager.complete_phase()
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.UPKEEP)

func test_phase_validation_failure() -> void:
	var validation_failed_emitted = false
	_phase_manager.validation_failed.connect(
		func(phase: int, errors: Array): validation_failed_emitted = true
	)
	
	_phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	# Force validation failure by not meeting requirements
	_phase_manager.complete_phase()
	
	assert_true(validation_failed_emitted)
	assert_eq(_phase_manager.current_phase, GameEnums.CampaignPhase.SETUP)

# Helper function to create test character
func _create_test_character() -> FiveParsecsCharacter:
	var character = FiveParsecsCharacter.new()
	character.character_name = "Test Character"
	character.character_class = GameEnums.CharacterClass.SOLDIER
	return character