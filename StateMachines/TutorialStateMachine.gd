@tool
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://StateMachines/TutorialStateMachine.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const Mission := preload("res://src/core/systems/Mission.gd")

signal state_changed(new_state: int)
signal track_changed(new_track: int)
signal step_completed(step: String)
signal tutorial_completed(success: bool)
signal tutorial_step_completed(step: int)
signal tutorial_step_failed(step: int, reason: String)

enum TutorialTrack {
	NONE,
	QUICK_START,
	ADVANCED,
	BATTLE,
	CAMPAIGN,
	STORY
}

enum TutorialState {
	NONE,
	SETUP,
	RUNNING,
	PAUSED,
	COMPLETED,
	QUICK_START,
	ADVANCED,
	BATTLE_TUTORIAL,
	CAMPAIGN_TUTORIAL,
	STORY_TUTORIAL
}

# Tutorial state
var current_state: int = TutorialState.NONE
var current_track: int = TutorialTrack.NONE
var current_step: int = 0
var completed_steps: Array[String] = []
var steps_completed: Array[int] = []
var game_state: FiveParsecsGameState

func _init(state: FiveParsecsGameState) -> void:
	game_state = state

func _exit_quick_start() -> void:
	if current_track == TutorialTrack.QUICK_START:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(false)

func _exit_advanced() -> void:
	if current_track == TutorialTrack.ADVANCED:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(false)

func _exit_battle_tutorial() -> void:
	if game_state:
		game_state.is_tutorial_active = false
	if current_track == TutorialTrack.BATTLE:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(false)

func _exit_campaign_tutorial() -> void:
	if game_state:
		game_state.is_tutorial_active = false
	if current_track == TutorialTrack.CAMPAIGN:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(false)

func _exit_story_tutorial() -> void:
	if game_state:
		game_state.is_tutorial_active = false
	if current_track == TutorialTrack.STORY:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(false)

func _complete_tutorial() -> void:
	var previous_track := current_track
	current_track = TutorialTrack.NONE
	if previous_track != TutorialTrack.NONE:
		tutorial_completed.emit(false)

func start_tutorial_track(track: int) -> void:
	current_track = track
	match track:
		TutorialTrack.QUICK_START:
			_start_quick_start()
		TutorialTrack.ADVANCED:
			_start_advanced()
		TutorialTrack.BATTLE:
			_start_battle_tutorial()
		TutorialTrack.CAMPAIGN:
			_start_campaign_tutorial()
		TutorialTrack.STORY:
			_start_story_tutorial()
		_:
			push_error("Invalid tutorial track: %d" % track)

func start_tutorial() -> void:
	current_step = 0
	steps_completed.clear()
	_advance_to_next_step()

func complete_current_step() -> void:
	if current_step > 0:
		steps_completed.append(current_step)
		tutorial_step_completed.emit(current_step)
		_advance_to_next_step()

func fail_current_step(reason: String) -> void:
	tutorial_step_failed.emit(current_step, reason)

func _advance_to_next_step() -> void:
	current_step += 1
	if current_step > get_total_steps():
		tutorial_completed.emit(true)
	else:
		_setup_step(current_step)

func _setup_step(step: int) -> void:
	match step:
		1: # Introduction
			game_state.set_victory_type(GameEnums.FiveParcsecsCampaignVictoryType.STANDARD)
		2: # Basic Movement
			_setup_movement_tutorial()
		3: # Combat
			_setup_combat_tutorial()
		4: # Resource Management
			_setup_resource_tutorial()
		5: # Mission System
			_setup_mission_tutorial()
		_:
			push_error("Invalid tutorial step: %d" % step)

func get_total_steps() -> int:
	return 5

func _setup_movement_tutorial() -> void:
	# Implementation for movement tutorial setup
	pass

func _setup_combat_tutorial() -> void:
	# Implementation for combat tutorial setup
	pass

func _setup_resource_tutorial() -> void:
	# Implementation for resource management tutorial setup
	pass

func _setup_mission_tutorial() -> void:
	# Implementation for mission system tutorial setup
	pass

func _start_quick_start() -> void:
	if not game_state:
		return
	game_state.is_tutorial_active = true
	_setup_tutorial_mission(TutorialTrack.QUICK_START)

func _start_advanced() -> void:
	if not game_state:
		return
	game_state.is_tutorial_active = true
	_setup_tutorial_mission(TutorialTrack.ADVANCED)

func _start_battle_tutorial() -> void:
	if not game_state:
		return
		
	var battle_setup := {
		"enemy_count": 2,
		"battle_environment": GameEnums.PlanetEnvironment.URBAN,
		"objective": GameEnums.MissionObjective.DEFEND
	}
	game_state.is_tutorial_active = true
	if game_state.has_method("start_tutorial_battle"):
		game_state.start_tutorial_battle(battle_setup)

func _start_campaign_tutorial() -> void:
	if not game_state:
		return
		
	game_state.is_tutorial_active = true
	var campaign_setup := {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": false
	}
	
	if game_state.has_method("start_tutorial_campaign"):
		game_state.start_tutorial_campaign(campaign_setup)

func _start_story_tutorial() -> void:
	if not game_state:
		return
		
	game_state.is_tutorial_active = true
	_setup_tutorial_mission(TutorialTrack.STORY)

func _setup_tutorial_mission(track: int) -> void:
	var mission = {
		"type": GameEnums.MissionType.PATROL, # Using PATROL as a basic mission type for tutorials
		"difficulty": GameEnums.DifficultyLevel.EASY,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"track": track
	}
	
	if game_state.has_method("start_tutorial_mission"):
		game_state.start_tutorial_mission(mission)

func transition_to(new_state: int) -> void:
	if new_state == current_state:
		return
		
	# Exit current state
	match current_state:
		TutorialState.QUICK_START:
			_exit_quick_start()
		TutorialState.ADVANCED:
			_exit_advanced()
		TutorialState.BATTLE_TUTORIAL:
			_exit_battle_tutorial()
		TutorialState.CAMPAIGN_TUTORIAL:
			_exit_campaign_tutorial()
		TutorialState.STORY_TUTORIAL:
			_exit_story_tutorial()
		TutorialState.COMPLETED:
			_complete_tutorial()

	# Enter new state
	current_state = new_state
	if game_state:
		game_state.is_tutorial_active = new_state != TutorialState.NONE and new_state != TutorialState.COMPLETED
	
	match new_state:
		TutorialState.QUICK_START:
			_start_quick_start()
		TutorialState.ADVANCED:
			_start_advanced()
		TutorialState.BATTLE_TUTORIAL:
			_start_battle_tutorial()
		TutorialState.CAMPAIGN_TUTORIAL:
			_start_campaign_tutorial()
		TutorialState.STORY_TUTORIAL:
			_start_story_tutorial()
		TutorialState.COMPLETED:
			_complete_tutorial()

	state_changed.emit(current_state)