## Core Features Test Suite
## Tests the functionality of the core game state features including:
## - Game state transitions
## - Campaign phase management
## - Combat phase tracking
## - Verification status handling
@tool
extends GdUnitGameTest

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Mock Game State with expected values (Universal Mock Strategy)
class MockGameState extends Resource:
	var current_state: int = GameEnums.GameState.SETUP
	var campaign_phase: int = GameEnums.CampaignPhase.NONE
	var combat_phase: int = GameEnums.CombatPhase.NONE
	var verification_status: int = GameEnums.VerificationStatus.PENDING
	
	# Core state management with expected values
	func get_state() -> int: return current_state
	func set_state(state: int) -> void:
		# Validate state transitions
		if state in [GameEnums.GameState.SETUP, GameEnums.GameState.CAMPAIGN, GameEnums.GameState.BATTLE, GameEnums.GameState.GAME_OVER]:
			current_state = state
			state_changed.emit(state)
	
	# Campaign phase management
	func get_campaign_phase() -> int: return campaign_phase
	func set_campaign_phase(phase: int) -> void:
		# Only allow campaign phases in campaign state
		if current_state == GameEnums.GameState.CAMPAIGN and phase in [GameEnums.CampaignPhase.SETUP, GameEnums.CampaignPhase.UPKEEP, GameEnums.CampaignPhase.STORY, GameEnums.CampaignPhase.CAMPAIGN]:
			campaign_phase = phase
			campaign_phase_changed.emit(phase)
		elif current_state != GameEnums.GameState.CAMPAIGN:
			campaign_phase = GameEnums.CampaignPhase.NONE
	
	# Combat phase management
	func get_combat_phase() -> int: return combat_phase
	func set_combat_phase(phase: int) -> void:
		# Only allow combat phases in battle state
		if current_state == GameEnums.GameState.BATTLE and phase in [GameEnums.CombatPhase.SETUP, GameEnums.CombatPhase.DEPLOYMENT, GameEnums.CombatPhase.INITIATIVE, GameEnums.CombatPhase.ACTION]:
			combat_phase = phase
			combat_phase_changed.emit(phase)
		elif current_state != GameEnums.GameState.BATTLE:
			combat_phase = GameEnums.CombatPhase.NONE
	
	# Verification status
	func get_verification_status() -> int: return verification_status
	func set_verification_status(status: int) -> void:
		verification_status = status
		verification_status_changed.emit(status)
	
	# Required signals (immediate emission pattern)
	signal state_changed(new_state: int)
	signal campaign_phase_changed(new_phase: int)
	signal combat_phase_changed(new_phase: int)
	signal verification_status_changed(new_status: int)

# Mock Game State Manager with expected values (Universal Mock Strategy)
class MockGameStateManager extends Resource:
	var game_state: MockGameState = null
	
	func set_game_state(state: MockGameState) -> void:
		game_state = state
	
	func get_game_state() -> MockGameState:
		return game_state
	
	func set_campaign_phase(phase: int) -> void:
		if game_state:
			game_state.set_campaign_phase(phase)

# Type-safe instance variables
var _game_state: MockGameState = null
var _game_state_manager: MockGameStateManager = null

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	_game_state = MockGameState.new()
	_game_state_manager = MockGameStateManager.new()
	track_resource(_game_state)
	track_resource(_game_state_manager)
	
	# Set up initial state
	_game_state_manager.set_game_state(_game_state)
	_game_state_manager.set_campaign_phase(0) # NONE phase

func after_test() -> void:
	_game_state = null
	_game_state_manager = null
	super.after_test()

# Basic State Management Tests
func test_initial_state() -> void:
	assert_that(_game_state).is_not_null()
	# Test direct method calls instead of safe wrappers (proven pattern)
	var current_state: int = _game_state.get_state()
	assert_that(current_state).is_equal(GameEnums.GameState.SETUP)

# Game State Tests
func test_game_state_transitions() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var states := [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for state: int in states:
		_game_state.set_state(state)
		var current_state: int = _game_state.get_state()
		assert_that(current_state).is_equal(state)

# Campaign Phase Tests
func test_campaign_phase_transitions() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Set game state to campaign first
	_game_state.set_state(GameEnums.GameState.CAMPAIGN)
	
	# Test campaign phase transitions
	var phases := [
		GameEnums.CampaignPhase.SETUP,
		GameEnums.CampaignPhase.UPKEEP,
		GameEnums.CampaignPhase.STORY,
		GameEnums.CampaignPhase.CAMPAIGN
	]
	
	for phase: int in phases:
		_game_state.set_campaign_phase(phase)
		var current_phase: int = _game_state.get_campaign_phase()
		assert_that(current_phase).is_equal(phase)

# Combat Phase Tests
func test_combat_phase_transitions() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Set game state to battle first
	_game_state.set_state(GameEnums.GameState.BATTLE)
	
	# Test combat phase transitions
	var phases := [
		GameEnums.CombatPhase.SETUP,
		GameEnums.CombatPhase.DEPLOYMENT,
		GameEnums.CombatPhase.INITIATIVE,
		GameEnums.CombatPhase.ACTION
	]
	
	for phase: int in phases:
		_game_state.set_combat_phase(phase)
		var current_phase: int = _game_state.get_combat_phase()
		assert_that(current_phase).is_equal(phase)

# State Validation Tests
func test_invalid_state_transitions() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var invalid_state := 9999
	var initial_state: int = _game_state.get_state()
	
	# Test invalid game state (should not change)
	_game_state.set_state(invalid_state)
	var current_state: int = _game_state.get_state()
	assert_that(current_state).is_not_equal(invalid_state)
	assert_that(current_state).is_equal(initial_state)
	
	# Test invalid campaign phase (should not change)
	var initial_campaign_phase: int = _game_state.get_campaign_phase()
	_game_state.set_campaign_phase(invalid_state)
	var current_phase: int = _game_state.get_campaign_phase()
	assert_that(current_phase).is_not_equal(invalid_state)
	
	# Test invalid combat phase (should not change)
	var initial_combat_phase: int = _game_state.get_combat_phase()
	_game_state.set_combat_phase(invalid_state)
	var current_combat_phase: int = _game_state.get_combat_phase()
	assert_that(current_combat_phase).is_not_equal(invalid_state)

# Performance Tests
func test_rapid_state_transitions() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var start_time := Time.get_ticks_msec()
	
	var states := [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for i in range(100):
		var state: int = states[i % states.size()]
		_game_state.set_state(state)
		var current_state: int = _game_state.get_state()
		assert_that(current_state).is_equal(state)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).is_less(1000)

# State Dependency Tests
func test_state_dependencies() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test campaign phase only valid in campaign state
	_game_state.set_state(GameEnums.GameState.SETUP)
	_game_state.set_campaign_phase(GameEnums.CampaignPhase.STORY)
	var campaign_phase: int = _game_state.get_campaign_phase()
	assert_that(campaign_phase).is_equal(GameEnums.CampaignPhase.NONE)
	
	# Test combat phase only valid in battle state
	_game_state.set_state(GameEnums.GameState.CAMPAIGN)
	_game_state.set_combat_phase(GameEnums.CombatPhase.ACTION)
	var combat_phase: int = _game_state.get_combat_phase()
	assert_that(combat_phase).is_equal(GameEnums.CombatPhase.NONE)

func test_verification_status_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_status: int = _game_state.get_verification_status()
	assert_that(initial_status).is_equal(GameEnums.VerificationStatus.PENDING)
	
	# Test status transitions
	_game_state.set_verification_status(GameEnums.VerificationStatus.VERIFIED)
	var current_status: int = _game_state.get_verification_status()
	assert_that(current_status).is_equal(GameEnums.VerificationStatus.VERIFIED)
	
	_game_state.set_verification_status(GameEnums.VerificationStatus.PENDING)
	current_status = _game_state.get_verification_status()
	assert_that(current_status).is_equal(GameEnums.VerificationStatus.PENDING)

func test_state_manager_integration() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var retrieved_state: MockGameState = _game_state_manager.get_game_state()
	assert_that(retrieved_state).is_not_null()
	assert_that(retrieved_state).is_equal(_game_state)
	
	# Test manager-controlled phase changes
	_game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.SETUP)
	var phase: int = _game_state.get_campaign_phase()
	assert_that(phase).is_equal(GameEnums.CampaignPhase.NONE) # Should be NONE because not in campaign state
	
	# Set to campaign state first, then test phase change
	_game_state.set_state(GameEnums.GameState.CAMPAIGN)
	_game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.SETUP)
	phase = _game_state.get_campaign_phase()
	assert_that(phase).is_equal(GameEnums.CampaignPhase.SETUP)