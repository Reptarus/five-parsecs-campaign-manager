extends Node

# Preload all required resources
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")

# Enums for game state management
enum BattlePhase {
	SETUP,
	COMBAT,
	CLEANUP,
	END
}

enum CampaignVictoryType {
	WEALTH_5000,
	REPUTATION_NOTORIOUS,
	INFLUENCE_MASTER,
	BLACK_ZONE_MASTER,
	RED_ZONE_VETERAN,
	QUEST_MASTER
}

# Game state and managers
var game_state: Node  # Will be cast to GameState at runtime
var mission_generator: Node  # Will be cast to MissionGenerator at runtime
var equipment_manager: Node  # Will be cast to EquipmentManager at runtime
var patron_job_manager: Node  # Will be cast to PatronJobManager at runtime

# Game state getters
func get_game_state() -> Node:  # Will return GameState at runtime
	return game_state

func get_current_ship() -> Node:  # Will return Ship at runtime
	return game_state.current_ship if game_state else null

func _handle_battle_phase() -> void:
	match current_battle_phase:
		BattlePhase.SETUP:
			game_manager._handle_battle_setup()
		BattlePhase.COMBAT:
			game_manager._handle_battle_round()
		BattlePhase.CLEANUP:
			game_manager._handle_battle_cleanup()

func save_game() -> void:
	if not game_state:
		push_error("Cannot save: No active game state")
		return
	
	var save_data: Dictionary = game_state.serialize()
	var save_path: String = _get_save_file_path()
	
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	# Save the file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	else:
		push_error("Failed to save game: Could not open file for writing")

func check_campaign_victory(campaign_victory_condition: int) -> bool:
	if not game_state:
		return false
		
	match campaign_victory_condition:
		CampaignVictoryType.WEALTH_5000:
			if game_state.credits >= 5000:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		CampaignVictoryType.REPUTATION_NOTORIOUS:
			if game_state.reputation >= 10:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		CampaignVictoryType.INFLUENCE_MASTER:
			if game_state.influence >= 15:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		CampaignVictoryType.BLACK_ZONE_MASTER:
			if game_state.completed_black_zone_jobs >= 3:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		CampaignVictoryType.RED_ZONE_VETERAN:
			if game_state.completed_red_zone_jobs >= 5:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
		CampaignVictoryType.QUEST_MASTER:
			if game_state.completed_quests >= 10:
				campaign_victory_achieved.emit(campaign_victory_condition)
				return true
	return false
