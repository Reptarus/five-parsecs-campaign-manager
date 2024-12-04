extends Node

# Signals
signal state_changed(new_state: GlobalEnums.GameState)
signal campaign_phase_changed(new_phase: GlobalEnums.CampaignPhase)
signal battle_phase_changed(new_phase: GlobalEnums.BattlePhase)
signal campaign_victory_achieved(victory_type: GlobalEnums.CampaignVictoryType)

# Game state and managers
var game_state: Node  # Will be cast to GameState at runtime
var current_state: GlobalEnums.GameState = GlobalEnums.GameState.SETUP
var current_campaign_phase: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.SETUP
var current_battle_phase: GlobalEnums.BattlePhase = GlobalEnums.BattlePhase.SETUP

# Child managers
var campaign_manager: Node
var battle_manager: Node
var mission_manager: Node
var equipment_manager: Node
var patron_job_manager: Node
var fringe_world_manager: Node

func _ready() -> void:
	_initialize_managers()
	_connect_signals()

func _initialize_managers() -> void:
	campaign_manager = $CampaignManager
	battle_manager = $BattleManager
	mission_manager = $MissionManager
	equipment_manager = $EquipmentManager
	patron_job_manager = $PatronJobManager
	
	# Initialize fringe world manager
	fringe_world_manager = load("res://Resources/ExpansionContent/FringeWorldStrifeManager.gd").new(game_state)
	add_child(fringe_world_manager)

func _connect_signals() -> void:
	if campaign_manager:
		campaign_manager.phase_changed.connect(_on_campaign_phase_changed)
	if battle_manager:
		battle_manager.phase_changed.connect(_on_battle_phase_changed)
	if fringe_world_manager:
		fringe_world_manager.strife_level_changed.connect(_on_strife_level_changed)
		fringe_world_manager.unity_progress_changed.connect(_on_unity_progress_changed)

# State transitions
func transition_to(new_state: GlobalEnums.GameState) -> void:
	var old_state = current_state
	current_state = new_state
	
	match new_state:
		GlobalEnums.GameState.SETUP:
			_handle_setup_state()
		GlobalEnums.GameState.CAMPAIGN:
			_handle_campaign_state()
		GlobalEnums.GameState.BATTLE:
			_handle_battle_state()
		GlobalEnums.GameState.GAME_OVER:
			_handle_game_over_state()
	
	state_changed.emit(new_state)

func _handle_setup_state() -> void:
	# Show campaign setup screen
	var setup_screen = load("res://Resources/CampaignManagement/Scenes/CampaignSetupScreen.tscn").instantiate()
	get_tree().root.add_child(setup_screen)
	setup_screen.setup_completed.connect(_on_setup_completed)

func _handle_campaign_state() -> void:
	if current_campaign_phase == GlobalEnums.CampaignPhase.SETUP:
		current_campaign_phase = GlobalEnums.CampaignPhase.UPKEEP
	campaign_phase_changed.emit(current_campaign_phase)

func _handle_battle_state() -> void:
	current_battle_phase = GlobalEnums.BattlePhase.SETUP
	battle_phase_changed.emit(current_battle_phase)

func _handle_game_over_state() -> void:
	var game_over_screen = load("res://Resources/GameData/GameOverScreen.tscn").instantiate()
	get_tree().root.add_child(game_over_screen)

# Signal handlers
func _on_campaign_phase_changed(new_phase: GlobalEnums.CampaignPhase) -> void:
	current_campaign_phase = new_phase
	campaign_phase_changed.emit(new_phase)

func _on_battle_phase_changed(new_phase: GlobalEnums.BattlePhase) -> void:
	current_battle_phase = new_phase
	battle_phase_changed.emit(new_phase)
	
	if new_phase == GlobalEnums.BattlePhase.CLEANUP:
		transition_to(GlobalEnums.GameState.CAMPAIGN)

func _on_setup_completed(config: Dictionary) -> void:
	initialize_campaign(config)
	transition_to(GlobalEnums.GameState.CAMPAIGN)

func _on_strife_level_changed(location: Node, new_level: GlobalEnums.FringeWorldInstability) -> void:
	# Handle strife level changes
	if game_state:
		game_state.update_location_strife(location, new_level)

func _on_unity_progress_changed(location: Node, new_progress: int) -> void:
	# Handle unity progress changes
	if game_state:
		game_state.update_location_unity(location, new_progress)

# Game state management
func get_game_state() -> Node:
	return game_state

func get_current_ship() -> Node:
	return game_state.current_ship if game_state else null

func initialize_campaign(config: Dictionary) -> void:
	game_state = load("res://Resources/GameData/GameState.gd").new()
	game_state.initialize(config)
	current_state = GlobalEnums.GameState.CAMPAIGN
	current_campaign_phase = GlobalEnums.CampaignPhase.SETUP

# Save/Load functionality
func save_game() -> void:
	if not game_state:
		push_error("Cannot save: No active game state")
		return
	
	var save_data: Dictionary = game_state.serialize()
	
	# Add fringe world data to save
	if fringe_world_manager:
		save_data["fringe_world_data"] = fringe_world_manager.serialize()
	
	var save_path: String = _get_save_file_path()
	
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	else:
		push_error("Failed to save game: Could not open file for writing")

func load_game(save_path: String = "") -> void:
	if save_path.is_empty():
		save_path = _get_save_file_path()
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to load game: Could not open save file")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("Failed to parse save file")
		return
	
	var save_data = json.get_data()
	
	# Load game state
	game_state = load("res://Resources/GameData/GameState.gd").new()
	game_state.deserialize(save_data)
	
	# Load fringe world data
	if save_data.has("fringe_world_data") and fringe_world_manager:
		fringe_world_manager.deserialize(save_data["fringe_world_data"])
	
	current_state = GlobalEnums.GameState.CAMPAIGN
	state_changed.emit(current_state)

func _get_save_file_path() -> String:
	return "user://saves/campaign_save.json"

# Victory conditions
func check_campaign_victory(victory_type: GlobalEnums.CampaignVictoryType) -> bool:
	if not game_state:
		return false
		
	var victory_achieved := false
	
	match victory_type:
		GlobalEnums.CampaignVictoryType.WEALTH_GOAL:
			victory_achieved = game_state.credits >= 5000
		GlobalEnums.CampaignVictoryType.REPUTATION_GOAL:
			victory_achieved = game_state.reputation >= 10
		GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE:
			victory_achieved = game_state.influence >= 15
		GlobalEnums.CampaignVictoryType.STORY_COMPLETE:
			victory_achieved = game_state.completed_quests >= 10
	
	if victory_achieved:
		campaign_victory_achieved.emit(victory_type)
	
	return victory_achieved
