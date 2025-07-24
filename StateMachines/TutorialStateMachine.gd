@tool
extends Node
class_name FPCM_TutorialStateMachine

## Tutorial State Machine for Five Parsecs Campaign Manager
##
## Manages tutorial flow and progression through different learning stages

# Dependencies
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")

# Tutorial State Types
enum TutorialState {
	NONE,
	INTRODUCTION,
	MOVEMENT,
	COMBAT,
	OBJECTIVES,
	COMPLETION,
	QUICK_START,
	ADVANCED,
	BATTLE_TUTORIAL,
	CAMPAIGN_TUTORIAL,
	STORY_TUTORIAL,
	COMPLETED
}

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

# Tutorial state
var current_state: int = TutorialState.NONE
var previous_state: int = TutorialState.NONE
var tutorial_data: Dictionary = {}
var current_track: int = 0 # TutorialTrack.NONE
var current_step: int = 0
var completed_steps: Array[String] = []
var steps_completed: Array[int] = []
var game_state: Resource = null

# Campaign state
var campaign_state: Resource = null
var mission_state: Resource = null

func _init() -> void:
	name = "TutorialStateMachine"

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

func start_tutorial(tutorial_type: int) -> void:
	match tutorial_type:
		TutorialState.INTRODUCTION:
			_start_introduction_tutorial()
		TutorialState.MOVEMENT:
			_start_movement_tutorial()
		TutorialState.COMBAT:
			_start_combat_tutorial()
		TutorialState.OBJECTIVES:
			_start_objectives_tutorial()
		TutorialState.COMPLETION:
			_start_completion_tutorial()
		_:
			_start_basic_tutorial()

func _start_basic_tutorial() -> void:
	# Basic tutorial setup
	var tutorial_config = {
		"difficulty": GlobalEnums.DifficultyLevel.STORY,
		"victory_condition": 0, # WEALTH_GOAL
		"crew_size": 3 # TRIO
	}
	_setup_tutorial_campaign(tutorial_config)

func _start_advanced_tutorial() -> void:
	# Advanced tutorial setup
	var tutorial_config = {
		"difficulty": GlobalEnums.DifficultyLevel.STANDARD,
		"victory_condition": 1, # REPUTATION_GOAL
		"crew_size": 4 # QUARTET
	}
	_setup_tutorial_campaign(tutorial_config)

func _start_quick_start_tutorial() -> void:
	# Quick start tutorial
	var tutorial_config = {
		"difficulty": GlobalEnums.DifficultyLevel.STORY,
		"victory_condition": 0, # WEALTH_GOAL
		"crew_size": 2 # DUO
	}
	_setup_tutorial_campaign(tutorial_config)

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
			game_state.set_victory_type(0) # STANDARD
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
		"battle_environment": GlobalEnums.PlanetEnvironment.URBAN,
		"objective": GlobalEnums.MissionObjective.DEFENSE
	}
	game_state.is_tutorial_active = true
	if game_state.has_method("start_tutorial_battle"):
		game_state.start_tutorial_battle(battle_setup)

func _start_campaign_tutorial() -> void:
	if not game_state:
		return
		
	game_state.is_tutorial_active = true
	var campaign_setup := {
		"difficulty": GlobalEnums.DifficultyLevel.STANDARD,
		"victory_type": 0, # STANDARD
		"crew_size": 3, # TRIO
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
		"type": GlobalEnums.MissionType.PATROL, # Using PATROL as a basic mission type for tutorials
		"difficulty": GlobalEnums.DifficultyLevel.STORY,
		"victory_type": 0, # STANDARD
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

func _start_introduction_tutorial() -> void:
	# Introduction tutorial setup
	pass

func _start_movement_tutorial() -> void:
	# Movement tutorial setup
	pass

func _start_combat_tutorial() -> void:
	# Combat tutorial setup
	pass

func _start_objectives_tutorial() -> void:
	# Objectives tutorial setup
	pass

func _start_completion_tutorial() -> void:
	# Completion tutorial setup
	pass

func _setup_tutorial_campaign(config: Dictionary) -> void:
	# Setup tutorial campaign with given configuration
	pass

func _get_mission_objective_name(objective_type: int) -> String:
	match objective_type:
		GlobalEnums.MissionObjective.PATROL:
			return "Patrol"
		GlobalEnums.MissionObjective.DEFENSE:
			return "Defend"
		GlobalEnums.MissionObjective.ASSASSINATION:
			return "Eliminate"
		GlobalEnums.MissionObjective.EXPLORE:
			return "Explore"
		_:
			return "Unknown"

func _get_tutorial_track_name(track: int) -> String:
	match track:
		0: return "Basic"
		1: return "Advanced"
		2: return "Expert"
		_: return "Unknown"