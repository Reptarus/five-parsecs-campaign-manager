@tool
class_name LegacyCampaignPhaseManager
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal phase_started(phase: int)
signal phase_failed(phase: int, reason: String)
signal phase_rolled_back(from_phase: int, to_phase: int, reason: String)

var game_state: FiveParsecsGameState
var phase_history: Array[Dictionary]
var current_phase: int = GameEnums.CampaignPhase.NONE
var previous_phase: int = GameEnums.CampaignPhase.NONE

const MAX_PHASE_HISTORY = 50

class PhaseState:
	var phase: int
	var timestamp: int
	var resources: Dictionary
	var crew_state: Dictionary
	var mission_state: Dictionary
	
	func _init(p_phase: int, p_game_state: FiveParsecsGameState) -> void:
		phase = p_phase
		timestamp = Time.get_unix_time_from_system()
		resources = _capture_resources(p_game_state)
		crew_state = _capture_crew_state(p_game_state)
		mission_state = _capture_mission_state(p_game_state)
	
	func _capture_resources(game_state: FiveParsecsGameState) -> Dictionary:
		var resources := {}
		for resource_type in GameEnums.ResourceType.values():
			resources[resource_type] = game_state.get_resource(resource_type)
		return resources
	
	func _capture_crew_state(game_state: FiveParsecsGameState) -> Dictionary:
		return {
			"crew_size": game_state.get_crew_size(),
			"crew_morale": game_state.get_crew_morale(),
			"crew_health": game_state.get_crew_health()
		}
	
	func _capture_mission_state(game_state: FiveParsecsGameState) -> Dictionary:
		return {
			"active_missions": game_state.get_active_mission_count(),
			"completed_missions": game_state.get_completed_mission_count()
		}

func _init(p_game_state: FiveParsecsGameState) -> void:
	game_state = p_game_state
	phase_history = []

func start_phase(new_phase: int) -> bool:
	if not _can_transition_to_phase(new_phase):
		return false
	
	# Store current phase state before transition
	if current_phase != GameEnums.CampaignPhase.NONE:
		_store_phase_state()
	
	previous_phase = current_phase
	current_phase = new_phase
	
	phase_changed.emit(previous_phase, current_phase)
	phase_started.emit(current_phase)
	
	return true

func complete_phase() -> void:
	if current_phase == GameEnums.CampaignPhase.NONE:
		return
	
	_store_phase_state()
	phase_completed.emit(current_phase)
	
	var next_phase = _calculate_next_phase()
	if next_phase != GameEnums.CampaignPhase.NONE:
		start_phase(next_phase)

func rollback_phase(reason: String = "") -> bool:
	if phase_history.is_empty():
		push_warning("No phase history available for rollback")
		return false
	
	var previous_state = phase_history[-1]
	var from_phase = current_phase
	var to_phase = previous_state.phase
	
	# Restore game state
	_restore_resources(previous_state.resources)
	_restore_crew_state(previous_state.crew_state)
	_restore_mission_state(previous_state.mission_state)
	
	# Update phase tracking
	current_phase = to_phase
	previous_phase = phase_history[-2].phase if phase_history.size() > 1 else GameEnums.CampaignPhase.NONE
	
	# Remove the restored state from history
	phase_history.pop_back()
	
	phase_rolled_back.emit(from_phase, to_phase, reason)
	return true

func can_rollback() -> bool:
	return not phase_history.is_empty()

func get_phase_history() -> Array[Dictionary]:
	return phase_history

func _store_phase_state() -> void:
	var state = PhaseState.new(current_phase, game_state)
	phase_history.append({
		"phase": state.phase,
		"timestamp": state.timestamp,
		"resources": state.resources,
		"crew_state": state.crew_state,
		"mission_state": state.mission_state
	})
	
	# Trim history if needed
	if phase_history.size() > MAX_PHASE_HISTORY:
		phase_history = phase_history.slice(-MAX_PHASE_HISTORY)

func _restore_resources(resources: Dictionary) -> void:
	for resource_type in resources:
		game_state.set_resource(resource_type, resources[resource_type])

func _restore_crew_state(crew_state: Dictionary) -> void:
	game_state.set_crew_morale(crew_state.crew_morale)
	game_state.set_crew_health(crew_state.crew_health)

func _restore_mission_state(mission_state: Dictionary) -> void:
	# This might need to be implemented based on your mission system
	pass

func _can_transition_to_phase(new_phase: int) -> bool:
	match new_phase:
		GameEnums.CampaignPhase.SETUP:
			return current_phase == GameEnums.CampaignPhase.NONE
		GameEnums.CampaignPhase.UPKEEP:
			return current_phase in [GameEnums.CampaignPhase.SETUP, GameEnums.CampaignPhase.END]
		GameEnums.CampaignPhase.STORY:
			return current_phase == GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.CAMPAIGN:
			return current_phase == GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return current_phase == GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return current_phase == GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.ADVANCEMENT:
			return current_phase == GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.TRADE:
			return current_phase == GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.END:
			return current_phase == GameEnums.CampaignPhase.TRADE
		_:
			return false

func _calculate_next_phase() -> int:
	match current_phase:
		GameEnums.CampaignPhase.SETUP:
			return GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.UPKEEP:
			return GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.STORY:
			return GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.CAMPAIGN:
			return GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.ADVANCEMENT:
			return GameEnums.CampaignPhase.TRADE
		GameEnums.CampaignPhase.TRADE:
			return GameEnums.CampaignPhase.END
		GameEnums.CampaignPhase.END:
			return GameEnums.CampaignPhase.UPKEEP
	return GameEnums.CampaignPhase.NONE