extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

signal phase_completed(phase_data: Dictionary)
signal phase_failed(reason: String)

## The game state
var game_state: FiveParsecsGameState

## The current campaign phase
var current_phase: int = -1

## Base ready function
func _ready() -> void:
	# Connect to the game state
	var state_manager = get_node_or_null("/root/GameStateManager")
	if not state_manager:
		# Try fallback path
		state_manager = get_node_or_null("/root/Game/Managers/GameStateManager")
	
	if state_manager:
		var state_node = state_manager.get_game_state()
		if state_node is FiveParsecsGameState:
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
	phase_failed.emit(reason)

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