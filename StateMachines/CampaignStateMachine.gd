class_name CampaignStateMachine
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const WorldStepManager = preload("res://Resources/GameData/WorldStepManager.gd")
const PostBattlePhase = preload("res://Resources/GameData/PostBattlePhase.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")

signal state_changed(new_state: int)  # GlobalEnums.CampaignPhase

var game_state_manager: GameStateManager
var current_state: int = GlobalEnums.CampaignPhase.UPKEEP

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm
	current_state = gsm.get_current_campaign_phase()

func transition_to(new_state: int) -> void:
	current_state = new_state
	match new_state:
		GlobalEnums.CampaignPhase.UPKEEP:
			handle_upkeep()
		GlobalEnums.CampaignPhase.TRAVEL:
			handle_travel()
		GlobalEnums.CampaignPhase.PATRONS:
			handle_patrons()
		GlobalEnums.CampaignPhase.POST_BATTLE:
			handle_post_battle()
		GlobalEnums.CampaignPhase.TRACK_RIVALS:
			handle_track_rivals()
		GlobalEnums.CampaignPhase.PATRON_JOB:
			handle_patron_job()
		GlobalEnums.CampaignPhase.RIVAL_ATTACK:
			handle_rival_attack()
		GlobalEnums.CampaignPhase.ASSIGN_EQUIPMENT:
			handle_assign_equipment()
		GlobalEnums.CampaignPhase.READY_FOR_BATTLE:
			handle_ready_for_battle()
	
	state_changed.emit(new_state)

# Phase handlers
func handle_upkeep() -> void:
	var world_step_manager = WorldStepManager.new(game_state_manager.game_state)
	world_step_manager.process_step()

func handle_travel() -> void:
	# Handle travel phase
	game_state_manager.world_generator.generate_new_location()
	game_state_manager.story_track.story_clock.count_down(false)
	state_changed.emit(GlobalEnums.CampaignPhase.TRAVEL)

func handle_patrons() -> void:
	# Handle patron interactions
	game_state_manager.patron_job_manager.check_patrons()
	state_changed.emit(GlobalEnums.CampaignPhase.PATRONS)

func handle_post_battle() -> void:
	var post_battle_manager = PostBattlePhase.new(game_state_manager.game_state)
	post_battle_manager.process_post_battle()
	state_changed.emit(GlobalEnums.CampaignPhase.POST_BATTLE)

func handle_track_rivals() -> void:
	# Handle rival tracking
	game_state_manager.expanded_faction_manager.update_factions()
	state_changed.emit(GlobalEnums.CampaignPhase.TRACK_RIVALS)

func handle_patron_job() -> void:
	# Handle patron job assignment
	game_state_manager.patron_job_manager.assign_jobs()
	state_changed.emit(GlobalEnums.CampaignPhase.PATRON_JOB)

func handle_rival_attack() -> void:
	# Handle rival attacks
	game_state_manager.expanded_faction_manager.resolve_faction_conflict()
	state_changed.emit(GlobalEnums.CampaignPhase.RIVAL_ATTACK)

func handle_assign_equipment() -> void:
	# Handle equipment assignment
	game_state_manager.equipment_manager.assign_equipment()
	state_changed.emit(GlobalEnums.CampaignPhase.ASSIGN_EQUIPMENT)

func handle_ready_for_battle() -> void:
	# Prepare for battle
	game_state_manager.battle_state_machine.prepare_for_battle()
	state_changed.emit(GlobalEnums.CampaignPhase.READY_FOR_BATTLE)
