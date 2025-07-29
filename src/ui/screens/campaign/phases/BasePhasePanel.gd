extends Control
class_name FPCM_BasePhasePanel

const GameState = preload("res://src/core/state/GameState.gd")
# GlobalEnums available as autoload singleton

signal phase_completed(phase_data: Dictionary)
signal phase_failed(reason: String)

## The game state
var game_state: GameState

## The current campaign phase
var current_phase: int = -1

## Base ready function
func _ready() -> void:
	# Connect to the game state
	var state_manager: Node = get_node("/root/Game/Managers/GameStateManager")
	if state_manager:
		var state_node: Node = state_manager.get_game_state()
		if state_node is GameState:
			game_state = state_node

	if not game_state:
		push_error("Failed to get game state in BasePhasePanel")

## Setup the phase panel
func setup_phase() -> void:
	# Base implementation - should be overridden by subclasses
	if not game_state:
		push_error("Cannot setup phase - no game state")
		return

	# Get the current phase from the game state
	current_phase = game_state.get_current_phase()

## Validate that all requirements are met to proceed with this phase
func validate_phase_requirements() -> bool:
	# Base implementation - should be overridden by subclasses
	return game_state != null

## Complete the current phase
func complete_phase() -> void:
	if not game_state:
		push_error("Cannot complete phase - no game state")
		return

	# Save phase data before completing
	var phase_data = get_phase_data()

	# Emit completion signal
	phase_completed.emit(phase_data)

## Fail the current phase with a reason
func fail_phase(reason: String) -> void:
	phase_failed.emit(reason) # warning: return value discarded (intentional)

## Get phase data to pass to the next phase
func get_phase_data() -> Dictionary:
	# Base implementation - should be overridden by subclasses
	return {
		"phase": current_phase
	}

## Set phase data from the previous phase
func set_phase_data(data: Dictionary) -> void:
	# Base implementation - should be overridden by subclasses
	pass
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null