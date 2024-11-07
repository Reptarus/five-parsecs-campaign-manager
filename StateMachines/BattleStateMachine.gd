class_name BattleStateMachine
extends Node

signal state_changed(new_state: BattleState)

var game_state_manager: GameStateManager

enum BattleState {SETUP, ROUND, CLEANUP}
enum UnitAction {MOVE, ATTACK, DASH, ITEMS, SNAP_FIRE, FREE_ACTION, STUNNED, BRAWL, OTHER}

var current_battle_state: BattleState = BattleState.SETUP
var current_round_phase: GlobalEnums.BattlePhase = GlobalEnums.BattlePhase.REACTION_ROLL

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm

func transition_to_battle_state(new_state: BattleState):
	current_battle_state = new_state
	match new_state:
		BattleState.SETUP:
			setup_battle()
		BattleState.ROUND:
			start_round()
		BattleState.CLEANUP:
			cleanup_battle()

func transition_to_round_phase(new_phase: GlobalEnums.BattlePhase):
	current_round_phase = new_phase
	match new_phase:
		GlobalEnums.BattlePhase.REACTION_ROLL:
			perform_reaction_roll()
		GlobalEnums.BattlePhase.QUICK_ACTIONS:
			handle_quick_actions()
		GlobalEnums.BattlePhase.ENEMY_ACTIONS:
			handle_enemy_actions()
		GlobalEnums.BattlePhase.SLOW_ACTIONS:
			handle_slow_actions()
		GlobalEnums.BattlePhase.END_PHASE:
			end_round()

func perform_unit_action(unit, action: UnitAction):
	match action:
		UnitAction.MOVE:
			unit.move()
		UnitAction.ATTACK:
			unit.attack()
		UnitAction.DASH:
			unit.dash()
		UnitAction.ITEMS:
			unit.use_item()
		UnitAction.SNAP_FIRE:
			unit.snap_fire()
		UnitAction.FREE_ACTION:
			unit.free_action()
		UnitAction.STUNNED:
			unit.stunned_action()
		UnitAction.BRAWL:
			unit.brawl()
		UnitAction.OTHER:
			unit.other_action()

# Implement the following methods based on the Core Rules
func setup_battle():
	pass

func start_round():
	pass

func cleanup_battle():
	pass

func perform_reaction_roll():
	pass

func handle_quick_actions():
	pass

func handle_enemy_actions():
	pass

func handle_slow_actions():
	pass

func end_round():
	pass
