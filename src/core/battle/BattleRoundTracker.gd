class_name BattleRoundTracker
extends Node

## Battle Round and Phase Tracking System - Five Parsecs Core Rules p.118
##
## Manages the Five Parsecs battle sequence (p.118):
## 1. Reaction Roll - Roll 1D6 per crew, assign to determine initiative
## 2. Quick Actions - Crew with reactions <= dice result
## 3. Enemy Actions - All enemies act
## 4. Slow Actions - Remaining crew act
## 5. End Phase - Morale checks, conditions, battle events
##
## Tracks round progression and triggers battle events at rounds 2 and 4.

# Battle phase enumeration
enum BattlePhase {
	REACTION_ROLL,
	QUICK_ACTIONS,
	ENEMY_ACTIONS,
	SLOW_ACTIONS,
	END_PHASE
}

# Signals for phase and round transitions
signal phase_changed(new_phase: int, phase_name: String)
signal round_changed(new_round: int)
signal battle_event_triggered(round: int, event_type: String)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal battle_started()
signal battle_ended()

# Phase name mapping for UI display
const PHASE_NAMES: Dictionary = {
	BattlePhase.REACTION_ROLL: "Reaction Roll",
	BattlePhase.QUICK_ACTIONS: "Quick Actions",
	BattlePhase.ENEMY_ACTIONS: "Enemy Actions",
	BattlePhase.SLOW_ACTIONS: "Slow Actions",
	BattlePhase.END_PHASE: "End Phase"
}

# Phase descriptions for tooltips/help
const PHASE_DESCRIPTIONS: Dictionary = {
	BattlePhase.REACTION_ROLL: "Roll 1D6 per crew member. Results <= Reactions act in Quick Actions.",
	BattlePhase.QUICK_ACTIONS: "Crew members with successful reactions act first.",
	BattlePhase.ENEMY_ACTIONS: "All enemies take their actions.",
	BattlePhase.SLOW_ACTIONS: "Remaining crew members act.",
	BattlePhase.END_PHASE: "Morale checks, condition updates, battle events."
}

# Battle event tracking (Five Parsecs p.118)
# Events occur on rounds 2 and 4
const BATTLE_EVENT_ROUNDS: Array[int] = [2, 4]

# Current state - use int to avoid enum type conflicts
var _current_phase: int = BattlePhase.REACTION_ROLL
var _current_round: int = 0
var _is_battle_active: bool = false

func _ready() -> void:
	set_process(false)  # No frame updates needed

## Start a new battle
func start_battle() -> void:
	"""Initialize battle round tracking"""
	_current_round = 1
	_current_phase = int(BattlePhase.REACTION_ROLL)
	_is_battle_active = true

	battle_started.emit()
	round_started.emit(_current_round)
	phase_changed.emit(_current_phase, get_phase_name(_current_phase))

	# Check for battle event (shouldn't happen on round 1, but consistent)
	_check_and_trigger_battle_event()

## Advance to next phase in sequence
func advance_phase() -> void:
	"""Move to next phase or start new round"""
	if not _is_battle_active:
		push_warning("BattleRoundTracker: Cannot advance phase - battle not active")
		return

	var next_phase: int = _current_phase + 1

	# Check if we've completed all phases
	if next_phase > BattlePhase.END_PHASE:
		_complete_round()
		_start_next_round()
	else:
		_set_phase(next_phase)

## Get current phase
func get_current_phase() -> int:
	"""Returns current battle phase as int (cast to BattlePhase if needed)"""
	return _current_phase

## Get current round number
func get_current_round() -> int:
	"""Returns current round number (1-indexed)"""
	return _current_round

## Get phase name for display
func get_phase_name(phase: int) -> String:
	"""Returns human-readable phase name"""
	return PHASE_NAMES.get(phase, "Unknown Phase")

## Get phase description for tooltips
func get_phase_description(phase: int) -> String:
	"""Returns phase description for help text"""
	return PHASE_DESCRIPTIONS.get(phase, "")

## Check if battle event should trigger
func check_battle_event() -> Dictionary:
	"""
	Returns battle event data if one should occur this round.
	Battle events happen on rounds 2 and 4 (Five Parsecs p.118).

	Returns Dictionary with:
	- should_trigger: bool
	- round: int
	- event_type: String
	"""
	var result: Dictionary = {
		"should_trigger": false,
		"round": _current_round,
		"event_type": ""
	}

	if _current_round in BATTLE_EVENT_ROUNDS:
		result.should_trigger = true
		result.event_type = "random_event"  # Will be rolled on event table

	return result

## End the battle
func end_battle() -> void:
	"""Terminate battle tracking"""
	_is_battle_active = false
	battle_ended.emit()

## Reset tracker to initial state
func reset() -> void:
	"""Reset to initial state for new battle"""
	_current_phase = int(BattlePhase.REACTION_ROLL)
	_current_round = 0
	_is_battle_active = false

## Check if currently in specific phase
func is_in_phase(phase: int) -> bool:
	"""Returns true if currently in specified phase"""
	return _current_phase == phase

## Get total number of phases
func get_phase_count() -> int:
	"""Returns total number of phases per round"""
	return BattlePhase.size()

## Get phase progress (for UI progress bars)
func get_phase_progress() -> float:
	"""Returns progress through current round (0.0 - 1.0)"""
	return float(_current_phase) / float(BattlePhase.END_PHASE + 1)

# Private methods

func _set_phase(new_phase: int) -> void:
	"""Internal: Set new phase and emit signals"""
	_current_phase = new_phase
	phase_changed.emit(_current_phase, get_phase_name(_current_phase))

	# Check for battle events at end phase
	if _current_phase == int(BattlePhase.END_PHASE):
		_check_and_trigger_battle_event()

func _complete_round() -> void:
	"""Internal: Complete current round"""
	round_ended.emit(_current_round)

func _start_next_round() -> void:
	"""Internal: Start next round"""
	_current_round += 1
	_current_phase = int(BattlePhase.REACTION_ROLL)

	round_started.emit(_current_round)
	round_changed.emit(_current_round)
	phase_changed.emit(_current_phase, get_phase_name(_current_phase))

	_check_and_trigger_battle_event()

func _check_and_trigger_battle_event() -> void:
	"""Internal: Check and trigger battle events"""
	var event_data: Dictionary = check_battle_event()
	if event_data.should_trigger:
		battle_event_triggered.emit(_current_round, event_data.event_type)
