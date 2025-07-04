# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Node

## Campaign Phase Manager - Official Five Parsecs Rules Implementation
## Coordinates the Four-Phase Campaign Turn Structure

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameEnums = null
var game_state_manager = null
var TravelPhase = null
var WorldPhase = null
var PostBattlePhase = null

## Current campaign state
var current_phase: int = 0
var current_substep: int = 0
var transition_in_progress: bool = false
var turn_number: int = 1

## Phase handlers
var travel_phase_handler: Node = null
var world_phase_handler: Node = null
var post_battle_phase_handler: Node = null

## Campaign Phase Manager Signals
signal phase_changed(new_phase: int)
signal phase_completed(phase: int)
signal phase_started(phase: int)
signal substep_changed(phase: int, substep: int)
signal campaign_turn_started(turn: int)
signal campaign_turn_completed(turn: int)

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "CampaignPhaseManager GameEnums")
	# Access GameStateManagerAutoload autoload directly
	game_state_manager = get_node_or_null("/root/GameStateManagerAutoload")
	
	# Load phase classes
	TravelPhase = UniversalResourceLoader.load_script_safe("res://src/core/campaign/phases/TravelPhase.gd", "CampaignPhaseManager TravelPhase")
	WorldPhase = UniversalResourceLoader.load_script_safe("res://src/core/campaign/phases/WorldPhase.gd", "CampaignPhaseManager WorldPhase")
	PostBattlePhase = UniversalResourceLoader.load_script_safe("res://src/core/campaign/phases/PostBattlePhase.gd", "CampaignPhaseManager PostBattlePhase")
	
	# Initialize enum values after loading GameEnums
	if GameEnums:
		current_phase = GameEnums.FiveParsecsCampaignPhase.NONE
	
	# Initialize phase handlers
	_initialize_phase_handlers()
	
	_validate_universal_connections()
	print("CampaignPhaseManager: Initialized with official Four-Phase structure")

func _initialize_phase_handlers() -> void:
	"""Initialize the phase handler instances"""
	if TravelPhase:
		travel_phase_handler = TravelPhase.new()
		add_child(travel_phase_handler)
		# Connect signals
		if travel_phase_handler.has_signal("travel_phase_completed"):
			travel_phase_handler.travel_phase_completed.connect(_on_travel_phase_completed)
		if travel_phase_handler.has_signal("travel_substep_changed"):
			travel_phase_handler.travel_substep_changed.connect(_on_travel_substep_changed)
	
	if WorldPhase:
		world_phase_handler = WorldPhase.new()
		add_child(world_phase_handler)
		# Connect signals
		if world_phase_handler.has_signal("world_phase_completed"):
			world_phase_handler.world_phase_completed.connect(_on_world_phase_completed)
		if world_phase_handler.has_signal("world_substep_changed"):
			world_phase_handler.world_substep_changed.connect(_on_world_substep_changed)
	
	if PostBattlePhase:
		post_battle_phase_handler = PostBattlePhase.new()
		add_child(post_battle_phase_handler)
		# Connect signals
		if post_battle_phase_handler.has_signal("post_battle_phase_completed"):
			post_battle_phase_handler.post_battle_phase_completed.connect(_on_post_battle_phase_completed)
		if post_battle_phase_handler.has_signal("post_battle_substep_changed"):
			post_battle_phase_handler.post_battle_substep_changed.connect(_on_post_battle_substep_changed)

func _validate_universal_connections() -> void:
	# Validate core system connections
	_validate_core_connections()
	_register_with_game_state()

func _validate_core_connections() -> void:
	# Validate required dependencies
	if not GameEnums:
		push_error("CORE SYSTEM FAILURE: GameEnums not accessible from CampaignPhaseManager")
	
	if not game_state_manager:
		push_error("CORE SYSTEM FAILURE: GameStateManager not accessible from CampaignPhaseManager")

func _register_with_game_state() -> void:
	# Register this manager with the global game state system using direct autoload access
	if GameState and GameState.has_method("register_manager"):
		GameState.register_manager("CampaignPhaseManager", self)

## Main Campaign Turn Management
func start_new_campaign_turn() -> bool:
	"""Start a new campaign turn with the official Four-Phase structure"""
	if transition_in_progress:
		print("CampaignPhaseManager: Turn transition already in progress")
		return false
	
	turn_number += 1
	print("CampaignPhaseManager: Starting Campaign Turn %d" % turn_number)
	UniversalSignalManager.emit_signal_safe(self, "campaign_turn_started", [turn_number], "CampaignPhaseManager campaign_turn_started")
	
	# Phase 1: Travel Phase
	return start_phase(GameEnums.FiveParsecsCampaignPhase.TRAVEL)

func get_current_phase() -> int:
	return current_phase

func get_current_substep() -> int:
	return current_substep

func get_turn_number() -> int:
	return turn_number

## Official Phase Management
func start_phase(phase: int) -> bool:
	"""Start a specific campaign phase"""
	if transition_in_progress:
		print("CampaignPhaseManager: Phase transition already in progress")
		return false
	
	if not _can_transition_to_phase(phase):
		print("CampaignPhaseManager: Cannot transition to phase %d from phase %d" % [phase, current_phase])
		return false
	
	transition_in_progress = true
	var previous_phase = current_phase
	current_phase = phase
	current_substep = 0
	
	print("CampaignPhaseManager: Starting phase %s" % get_phase_name(phase))
	UniversalSignalManager.emit_signal_safe(self, "phase_started", [phase], "CampaignPhaseManager start_phase")
	UniversalSignalManager.emit_signal_safe(self, "phase_changed", [phase], "CampaignPhaseManager phase_changed")
	
	# Update game state
	if game_state_manager and game_state_manager.has_method("set_campaign_phase"):
		game_state_manager.set_campaign_phase(phase)
	
	# Start the appropriate phase handler
	_start_phase_handler(phase)
	
	transition_in_progress = false
	return true

func _start_phase_handler(phase: int) -> void:
	"""Start the appropriate phase handler"""
	if not GameEnums:
		return
	
	match phase:
		GameEnums.FiveParsecsCampaignPhase.TRAVEL:
			if travel_phase_handler and travel_phase_handler.has_method("start_travel_phase"):
				travel_phase_handler.start_travel_phase()
		
		GameEnums.FiveParsecsCampaignPhase.WORLD:
			if world_phase_handler and world_phase_handler.has_method("start_world_phase"):
				world_phase_handler.start_world_phase()
		
		GameEnums.FiveParsecsCampaignPhase.BATTLE:
			# Battle phase is handled separately by combat system
			print("CampaignPhaseManager: Battle phase started - transitioning to combat system")
			# Auto-complete battle phase for now (would integrate with combat system)
			_complete_battle_phase()
		
		GameEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			if post_battle_phase_handler and post_battle_phase_handler.has_method("start_post_battle_phase"):
				# Get battle results from combat system
				var battle_results = _get_battle_results()
				post_battle_phase_handler.start_post_battle_phase(battle_results)

func _complete_battle_phase() -> void:
	"""Complete battle phase (placeholder for combat system integration)"""
	print("CampaignPhaseManager: Battle phase completed")
	UniversalSignalManager.emit_signal_safe(self, "phase_completed", [current_phase], "CampaignPhaseManager battle_phase_completed")
	
	# Transition to Post-Battle phase
	start_phase(GameEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func _get_battle_results() -> Dictionary:
	"""Get battle results from combat system (placeholder)"""
	return {
		"success": true,
		"enemies_defeated": 3,
		"crew_participants": ["crew_1", "crew_2", "crew_3"],
		"base_payment": 8,
		"danger_pay": 2,
		"defeated_enemy_list": [
			{"type": "basic", "is_rival": false},
			{"type": "elite", "is_rival": false},
			{"type": "boss", "is_rival": true, "rival_id": "rival_1"}
		]
	}

## Official Phase Transition Logic
func _can_transition_to_phase(phase: int) -> bool:
	"""Check if transition to target phase is valid (Official Rules)"""
	if not GameEnums:
		return false
	
	# Official Four-Phase Campaign Turn Structure
	match current_phase:
		GameEnums.FiveParsecsCampaignPhase.NONE:
			return phase in [GameEnums.FiveParsecsCampaignPhase.SETUP, GameEnums.FiveParsecsCampaignPhase.TRAVEL]
		
		GameEnums.FiveParsecsCampaignPhase.SETUP:
			return phase == GameEnums.FiveParsecsCampaignPhase.TRAVEL
		
		GameEnums.FiveParsecsCampaignPhase.TRAVEL:
			return phase == GameEnums.FiveParsecsCampaignPhase.WORLD
		
		GameEnums.FiveParsecsCampaignPhase.WORLD:
			return phase == GameEnums.FiveParsecsCampaignPhase.BATTLE
		
		GameEnums.FiveParsecsCampaignPhase.BATTLE:
			return phase == GameEnums.FiveParsecsCampaignPhase.POST_BATTLE
		
		GameEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return phase == GameEnums.FiveParsecsCampaignPhase.TRAVEL # Start new turn
	
	return false

func _get_next_phase(phase: int) -> int:
	"""Get the next phase in the official sequence"""
	if not GameEnums:
		return phase
	
	# Official Four-Phase Campaign Turn Progression
	match phase:
		GameEnums.FiveParsecsCampaignPhase.SETUP:
			return GameEnums.FiveParsecsCampaignPhase.TRAVEL
		GameEnums.FiveParsecsCampaignPhase.TRAVEL:
			return GameEnums.FiveParsecsCampaignPhase.WORLD
		GameEnums.FiveParsecsCampaignPhase.WORLD:
			return GameEnums.FiveParsecsCampaignPhase.BATTLE
		GameEnums.FiveParsecsCampaignPhase.BATTLE:
			return GameEnums.FiveParsecsCampaignPhase.POST_BATTLE
		GameEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return GameEnums.FiveParsecsCampaignPhase.TRAVEL # Start new turn
	
	return phase

## Phase Handler Signal Handlers
func _on_travel_phase_completed() -> void:
	"""Handle Travel Phase completion"""
	print("CampaignPhaseManager: Travel Phase completed")
	UniversalSignalManager.emit_signal_safe(self, "phase_completed", [current_phase], "CampaignPhaseManager travel_phase_completed")
	start_phase(GameEnums.FiveParsecsCampaignPhase.WORLD)

func _on_world_phase_completed() -> void:
	"""Handle World Phase completion"""
	print("CampaignPhaseManager: World Phase completed")
	UniversalSignalManager.emit_signal_safe(self, "phase_completed", [current_phase], "CampaignPhaseManager world_phase_completed")
	start_phase(GameEnums.FiveParsecsCampaignPhase.BATTLE)

func _on_post_battle_phase_completed() -> void:
	"""Handle Post-Battle Phase completion"""
	print("CampaignPhaseManager: Post-Battle Phase completed")
	UniversalSignalManager.emit_signal_safe(self, "phase_completed", [current_phase], "CampaignPhaseManager post_battle_phase_completed")
	
	# Complete the campaign turn
	UniversalSignalManager.emit_signal_safe(self, "campaign_turn_completed", [turn_number], "CampaignPhaseManager campaign_turn_completed")
	
	# Start next turn
	start_new_campaign_turn()

func _on_travel_substep_changed(substep: int) -> void:
	"""Handle Travel Phase sub-step changes"""
	current_substep = substep
	UniversalSignalManager.emit_signal_safe(self, "substep_changed", [current_phase, substep], "CampaignPhaseManager travel_substep_changed")

func _on_world_substep_changed(substep: int) -> void:
	"""Handle World Phase sub-step changes"""
	current_substep = substep
	UniversalSignalManager.emit_signal_safe(self, "substep_changed", [current_phase, substep], "CampaignPhaseManager world_substep_changed")

func _on_post_battle_substep_changed(substep: int) -> void:
	"""Handle Post-Battle Phase sub-step changes"""
	current_substep = substep
	UniversalSignalManager.emit_signal_safe(self, "substep_changed", [current_phase, substep], "CampaignPhaseManager post_battle_substep_changed")

## Legacy Support Methods (for backward compatibility)
func complete_current_phase() -> bool:
	"""Complete current phase and transition to next"""
	if current_phase == 0: # NONE
		return false
	
	print("CampaignPhaseManager: Completing phase %s" % get_phase_name(current_phase))
	UniversalSignalManager.emit_signal_safe(self, "phase_completed", [current_phase], "CampaignPhaseManager complete_current_phase")
	
	# Determine next phase
	var next_phase = _get_next_phase(current_phase)
	if next_phase != current_phase:
		return start_phase(next_phase)
	
	return true

func force_phase_transition(target_phase: int) -> bool:
	"""Force transition to specific phase (for debugging/admin)"""
	transition_in_progress = true
	current_phase = target_phase
	current_substep = 0
	
	UniversalSignalManager.emit_signal_safe(self, "phase_changed", [target_phase], "CampaignPhaseManager force_phase_transition")
	
	if GameState and GameState.has_method("set_campaign_phase"):
		GameState.set_campaign_phase(target_phase)
	
	transition_in_progress = false
	return true

## Utility Methods
func get_phase_name(phase: int) -> String:
	"""Get human-readable phase name"""
	if GameEnums and "PHASE_NAMES" in GameEnums:
		return GameEnums.PHASE_NAMES.get(phase, "Unknown Phase")
	return "Unknown Phase"

func get_substep_name(phase: int, substep: int) -> String:
	"""Get human-readable sub-step name"""
	if not GameEnums:
		return "Unknown Substep"
	
	match phase:
		GameEnums.FiveParsecsCampaignPhase.TRAVEL:
			if "TRAVEL_SUBSTEP_NAMES" in GameEnums:
				return GameEnums.TRAVEL_SUBSTEP_NAMES.get(substep, "Unknown Travel Step")
		GameEnums.FiveParsecsCampaignPhase.WORLD:
			if "WORLD_SUBSTEP_NAMES" in GameEnums:
				return GameEnums.WORLD_SUBSTEP_NAMES.get(substep, "Unknown World Step")
		GameEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			if "POST_BATTLE_SUBSTEP_NAMES" in GameEnums:
				return GameEnums.POST_BATTLE_SUBSTEP_NAMES.get(substep, "Unknown Post-Battle Step")
	
	return "Unknown Substep"

func is_transition_in_progress() -> bool:
	return transition_in_progress

func get_phase_progress() -> Dictionary:
	"""Get detailed phase progress information"""
	return {
		"turn_number": turn_number,
		"current_phase": current_phase,
		"current_substep": current_substep,
		"phase_name": get_phase_name(current_phase),
		"substep_name": get_substep_name(current_phase, current_substep),
		"transition_in_progress": transition_in_progress
	}

## Phase Handler Access
func get_travel_phase_handler() -> Node:
	"""Get Travel Phase handler for direct access"""
	return travel_phase_handler

func get_world_phase_handler() -> Node:
	"""Get World Phase handler for direct access"""
	return world_phase_handler

func get_post_battle_phase_handler() -> Node:
	"""Get Post-Battle Phase handler for direct access"""
	return post_battle_phase_handler