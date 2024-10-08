class_name CampaignStateMachine
extends Node

var game_state_manager: GameStateManager
var current_state: GlobalEnums.ExpandedCampaignPhase = GlobalEnums.ExpandedCampaignPhase.UPKEEP

func initialize(gsm: GameStateManager):
	game_state_manager = gsm
	current_state = gsm.get_game_state() as GlobalEnums.ExpandedCampaignPhase

func transition_to(new_state: GlobalEnums.ExpandedCampaignPhase):
	current_state = new_state
	match new_state:
		GlobalEnums.ExpandedCampaignPhase.UPKEEP:
			handle_upkeep()
		GlobalEnums.ExpandedCampaignPhase.TRAVEL:
			handle_travel()
		GlobalEnums.ExpandedCampaignPhase.WORLD:
			handle_world()
		GlobalEnums.ExpandedCampaignPhase.POST_BATTLE:
			handle_post_battle()
		GlobalEnums.ExpandedCampaignPhase.TRACK_RIVALS:
			handle_track_rivals()
		GlobalEnums.ExpandedCampaignPhase.PATRON_JOB:
			handle_patron_job()
		GlobalEnums.ExpandedCampaignPhase.RIVAL_ATTACK:
			handle_rival_attack()
		GlobalEnums.ExpandedCampaignPhase.ASSIGN_EQUIPMENT:
			handle_assign_equipment()
		GlobalEnums.ExpandedCampaignPhase.READY_FOR_BATTLE:
			handle_ready_for_battle()

func handle_track_rivals():
	# 1. Identify rival movements
	# 2. Plan counteractions
	# 3. Update rival status
	pass

func handle_patron_job():
	# 1. Receive job details from patron
	# 2. Plan and execute the job
	# 3. Report back to patron
	# 4. Receive rewards and consequences
	pass

func handle_rival_attack():
	# 1. Detect incoming rival attack
	# 2. Prepare defenses
	# 3. Engage in combat
	# 4. Resolve aftermath
	pass

func handle_assign_equipment():
	# 1. Review available equipment
	# 2. Assign equipment to crew members
	# 3. Update equipment status
	pass

func handle_ready_for_battle():
	# 1. Finalize battle preparations
	# 2. Confirm crew readiness
	# 3. Move to battle phase
	pass

func handle_upkeep():
	# 1. Upkeep and ship repairs
	# 2. Assign and resolve crew tasks
	# 3. Determine job offers
	# 4. Assign equipment
	# 5. Resolve any Rumors
	# 6. Choose your battle
	pass

func handle_travel():
	# 1. Flee Invasion (if applicable)
	# 2. Decide whether to travel
	# 3. Starship travel event (if applicable)
	# 4. New world arrival steps (if applicable)
	pass

func handle_world():
	# 1. Upkeep and ship repairs
	# 2. Assign and resolve crew tasks
	# 3. Determine job offers
	# 4. Assign equipment
	# 5. Resolve any Rumors
	# 6. Choose your battle
	pass

func handle_post_battle():
	# 1. Resolve Rival status
	# 2. Resolve Patron status
	# 3. Determine Quest progress
	# 4. Get paid
	# 5. Battlefield finds
	# 6. Check for Invasion
	# 7. Gather the Loot
	# 8. Determine Injuries and recovery
	# 9. Experience and Character Upgrades
	# 10. Invest in Advanced Training
	# 11. Purchase items
	# 12. Roll for a Campaign Event
	# 13. Roll for a Character Event
	# 14. Check for Galactic War progress
	pass

func process_campaign_turn():
	transition_to(GlobalEnums.ExpandedCampaignPhase.UPKEEP)
	transition_to(GlobalEnums.ExpandedCampaignPhase.TRAVEL)
	transition_to(GlobalEnums.ExpandedCampaignPhase.WORLD)
	# Battle happens here (managed by MainGameStateMachine)
	transition_to(GlobalEnums.ExpandedCampaignPhase.POST_BATTLE)
