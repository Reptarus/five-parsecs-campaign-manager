class_name CampaignStateMachine
extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)

var game_state_manager: GameStateManager
var current_state: GlobalEnums.CampaignPhase

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm
	current_state = gsm.get_current_campaign_phase()

func transition_to(new_state: GlobalEnums.CampaignPhase) -> void:
	current_state = new_state
	match new_state:
		GlobalEnums.CampaignPhase.UPKEEP:
			handle_upkeep()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.TRAVEL:
			handle_travel()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.PATRONS:
			handle_patrons()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.POST_BATTLE:
			handle_post_battle()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.TRACK_RIVALS:
			handle_track_rivals()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.PATRON_JOB:
			handle_patron_job()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.RIVAL_ATTACK:
			handle_rival_attack()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.ASSIGN_EQUIPMENT:
			handle_assign_equipment()
			state_changed.emit(new_state)
		GlobalEnums.CampaignPhase.READY_FOR_BATTLE:
			handle_ready_for_battle()
			state_changed.emit(new_state)

# Phase handlers
func handle_upkeep() -> void:
	var world_step_manager = WorldStepManager.new()
	world_step_manager.initialize(game_state_manager)
	world_step_manager.process_step()

func handle_travel() -> void:
	# Handle travel phase
	pass

func handle_patrons() -> void:
	# Handle patron interactions
	pass
func handle_post_battle() -> void:
	var post_battle_manager = PostBattlePhase.new(game_state_manager.game_state)
	post_battle_manager.process_post_battle()

func handle_track_rivals() -> void:
	# Handle rival tracking
	pass
	pass

func handle_patron_job() -> void:
	# Handle patron job assignment
	pass

func handle_rival_attack() -> void:
	# Handle rival attacks
	pass

func handle_assign_equipment() -> void:
	# Handle equipment assignment
	pass

func handle_ready_for_battle() -> void:
	# Prepare for battle
	pass
