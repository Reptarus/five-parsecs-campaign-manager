@tool
extends GameTest

const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var _state_machine: BattleStateMachine
var _test_game_state: GameStateManager

func _ready() -> void:
	if not Engine.is_editor_hint():
		await get_tree().process_frame

func before_each() -> void:
	super.before_each()
	
	# Create game state manager
	_test_game_state = GameStateManager.new()
	var added_state := add_child_autofree(_test_game_state)
	if not added_state or not is_instance_valid(added_state):
		push_error("Failed to add game state manager")
		return
	track_test_node(_test_game_state)
	
	# Create battle state machine with dependencies
	_state_machine = BattleStateMachine.new(_test_game_state)
	var added_machine := add_child_autofree(_state_machine)
	if not added_machine or not is_instance_valid(added_machine):
		push_error("Failed to add battle state machine")
		return
	track_test_node(_state_machine)

func after_each() -> void:
	if is_instance_valid(_state_machine):
		_state_machine.queue_free()
	if is_instance_valid(_test_game_state):
		_test_game_state.queue_free()
	_state_machine = null
	_test_game_state = null
	super.after_each()

# Test initial state
func test_initial_state() -> void:
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.NONE,
		"Combat phase should start as NONE")
	assert_eq(_state_machine.current_state, GameEnums.BattleState.SETUP,
		"Battle should start in SETUP state")
	assert_false(_state_machine.is_battle_active,
		"Battle should not be active initially")

# Test phase transitions
func test_phase_transitions() -> void:
	watch_signals(_state_machine)
	
	# Start battle
	_state_machine.start_battle()
	assert_true(_state_machine.is_battle_active,
		"Battle should be active after start")
	verify_signal_emitted(_state_machine, "battle_started",
		"Battle started signal should be emitted")
	
	# Test phase transitions
	_state_machine.transition_to_phase(GameEnums.CombatPhase.SETUP)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.SETUP,
		"Should transition to setup phase")
	verify_signal_emitted(_state_machine, "phase_changed",
		"Phase changed signal should be emitted")
	
	_state_machine.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should transition to initiative phase")
	
	_state_machine.transition_to_phase(GameEnums.CombatPhase.ACTION)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.ACTION,
		"Should transition to action phase")

# Test phase validation
func test_phase_validation() -> void:
	# Test invalid phase transition before battle starts
	_state_machine.transition_to_phase(GameEnums.CombatPhase.ACTION)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.NONE,
		"Should not transition to action phase before battle starts")
	
	# Start battle and test valid transitions
	_state_machine.start_battle()
	
	# Test valid phase sequence
	_state_machine.transition_to_phase(GameEnums.CombatPhase.SETUP)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.SETUP,
		"Should allow transition to setup phase")
	
	_state_machine.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should allow transition to initiative phase")
	
	_state_machine.transition_to_phase(GameEnums.CombatPhase.ACTION)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.ACTION,
		"Should allow transition to action phase")

# Test phase completion
func test_phase_completion() -> void:
	watch_signals(_state_machine)
	
	# Start battle
	_state_machine.start_battle()
	
	# Complete setup phase
	_state_machine.transition_to_phase(GameEnums.CombatPhase.SETUP)
	_state_machine.advance_phase()
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should advance to initiative phase after setup")
	verify_signal_emitted(_state_machine, "phase_changed",
		"Phase changed signal should be emitted")
	
	# Complete initiative phase
	_state_machine.advance_phase()
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.ACTION,
		"Should advance to action phase after initiative")
	
	# Complete action phase
	_state_machine.advance_phase()
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.END,
		"Should advance to end phase after action")

# Test battle end
func test_battle_end() -> void:
	watch_signals(_state_machine)
	
	# Start and end battle
	_state_machine.start_battle()
	_state_machine.end_battle(GameEnums.VictoryConditionType.ELIMINATION)
	
	# Verify end state
	assert_false(_state_machine.is_battle_active,
		"Battle should not be active after end")
	verify_signal_emitted(_state_machine, "battle_ended",
		"Battle ended signal should be emitted")
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.NONE,
		"Phase should reset to NONE after battle ends")

# Add test methods here... 
