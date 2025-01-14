class_name TutorialStateMachine
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const Mission := preload("res://src/core/systems/Mission.gd")

signal state_changed(new_state: int)
signal track_changed(new_track: int)
signal step_completed(step: String)
signal tutorial_completed

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
var current_step: String = ""
var completed_steps: Array[String] = []
var game_state: FiveParsecsGameState

func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state

func _exit_quick_start() -> void:
	if current_track == TutorialTrack.QUICK_START:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(TutorialTrack.QUICK_START)

func _exit_advanced() -> void:
	if current_track == TutorialTrack.ADVANCED:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(TutorialTrack.ADVANCED)

func _exit_battle_tutorial() -> void:
	if game_state:
		game_state.is_tutorial_active = false
	if current_track == TutorialTrack.BATTLE:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(TutorialTrack.BATTLE)

func _exit_campaign_tutorial() -> void:
	if game_state:
		game_state.is_tutorial_active = false
	if current_track == TutorialTrack.CAMPAIGN:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(TutorialTrack.CAMPAIGN)

func _exit_story_tutorial() -> void:
	if game_state:
		game_state.is_tutorial_active = false
	if current_track == TutorialTrack.STORY:
		current_track = TutorialTrack.NONE
		tutorial_completed.emit(TutorialTrack.STORY)

func _complete_tutorial() -> void:
	var previous_track := current_track
	current_track = TutorialTrack.NONE
	if previous_track != TutorialTrack.NONE:
		tutorial_completed.emit(previous_track)

func start_tutorial(track: int) -> void:
	match track:
		TutorialTrack.QUICK_START:
			transition_to(TutorialState.QUICK_START)
			current_track = TutorialTrack.QUICK_START
		TutorialTrack.ADVANCED:
			transition_to(TutorialState.ADVANCED)
			current_track = TutorialTrack.ADVANCED
		TutorialTrack.BATTLE:
			transition_to(TutorialState.BATTLE_TUTORIAL)
			current_track = TutorialTrack.BATTLE
		TutorialTrack.CAMPAIGN:
			transition_to(TutorialState.CAMPAIGN_TUTORIAL)
			current_track = TutorialTrack.CAMPAIGN
		TutorialTrack.STORY:
			transition_to(TutorialState.STORY_TUTORIAL)
			current_track = TutorialTrack.STORY
		_:
			push_error("Invalid tutorial track")

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
			_enter_quick_start()
		TutorialState.ADVANCED:
			_enter_advanced()
		TutorialState.BATTLE_TUTORIAL:
			_enter_battle_tutorial()
		TutorialState.CAMPAIGN_TUTORIAL:
			_enter_campaign_tutorial()
		TutorialState.STORY_TUTORIAL:
			_enter_story_tutorial()
		TutorialState.COMPLETED:
			_complete_tutorial()

	state_changed.emit(current_state)

func _enter_quick_start() -> void:
	if not game_state:
		return
	game_state.is_tutorial_active = true
	_setup_tutorial_mission(TutorialTrack.QUICK_START)

func _enter_advanced() -> void:
	if not game_state:
		return
	game_state.is_tutorial_active = true
	_setup_tutorial_mission(TutorialTrack.ADVANCED)

func _enter_battle_tutorial() -> void:
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

func _enter_campaign_tutorial() -> void:
	if not game_state:
		return
		
	game_state.is_tutorial_active = true
	var campaign_setup := {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_condition": GameEnums.CampaignVictoryType.STORY_COMPLETE,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": false
	}
	
	if game_state.has_method("start_tutorial_campaign"):
		game_state.start_tutorial_campaign(campaign_setup)

func _enter_story_tutorial() -> void:
	if not game_state:
		return
		
	game_state.is_tutorial_active = true
	_setup_tutorial_mission(TutorialTrack.STORY)

func _setup_tutorial_mission(track: int) -> void:
	var mission := Mission.new()
	if not mission:
		push_error("Failed to create tutorial mission")
		return
		
	mission.mission_type = GameEnums.MissionType.GREEN_ZONE
	mission.difficulty = GameEnums.DifficultyLevel.NORMAL
	mission.deployment_type = GameEnums.DeploymentType.STANDARD
	
	# Add tutorial objectives based on track
	match track:
		TutorialTrack.QUICK_START:
			mission.objectives = [
				{
					"type": GameEnums.MissionObjective.PATROL,
					"description": "Learn basic movement and controls",
					"completed": false
				}
			]
		TutorialTrack.ADVANCED:
			mission.objectives = [
				{
					"type": GameEnums.MissionObjective.SEEK_AND_DESTROY,
					"description": "Learn advanced combat mechanics",
					"completed": false
				}
			]
		TutorialTrack.STORY:
			mission.objectives = [
				{
					"type": GameEnums.MissionObjective.PATROL,
					"description": "Learn story and dialogue systems",
					"completed": false
				}
			]
	
	if game_state.has_method("start_tutorial_mission"):
		game_state.start_tutorial_mission(mission)