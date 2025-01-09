@tool
extends Control
class_name CampaignDashboard

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const CampaignPhaseManager = preload("res://src/core/managers/CampaignPhaseManager.gd")

# Campaign Turn Steps (as per core rules)
enum CampaignStep {
	TRAVEL, # Step 1: Travel phase
	WORLD, # Step 2: World phase (upkeep, tasks, jobs)
	BATTLE, # Step 3: Tabletop battle
	POST_BATTLE # Step 4: Post-battle sequence
}

# Signals
signal action_requested(action_name: String, action_data: Dictionary)
signal crew_management_requested
signal save_requested
signal load_requested
signal quit_requested
signal victory_achieved(victory_type: String, final_score: int)
signal resource_updated(resource_type: int, new_value: int)
signal event_triggered(event_data: Dictionary)
signal phase_changed(new_phase: GameEnums.CampaignPhase)
signal phase_completed

# Node references
@onready var phase_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/PhaseLabel
@onready var turn_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/TurnLabel
@onready var step_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StepLabel
@onready var victory_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/VictoryLabel

@onready var credits_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/CreditsLabel
@onready var story_points_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/StoryPointsLabel
@onready var xp_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/XPLabel
@onready var rumors_label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/RumorsLabel

@onready var crew_list = $MarginContainer/VBoxContainer/MainContent/LeftPanel/CrewPanel/VBoxContainer/CrewList
@onready var ship_info = $MarginContainer/VBoxContainer/MainContent/LeftPanel/ShipPanel/VBoxContainer/ShipInfo
@onready var quest_info = $MarginContainer/VBoxContainer/MainContent/RightPanel/QuestPanel/VBoxContainer/QuestInfo
@onready var world_info = $MarginContainer/VBoxContainer/MainContent/RightPanel/WorldPanel/VBoxContainer/WorldInfo
@onready var patron_list = $MarginContainer/VBoxContainer/MainContent/RightPanel/PatronPanel/VBoxContainer/PatronList

@onready var action_button = $MarginContainer/VBoxContainer/ButtonContainer/ActionButton
@onready var manage_crew_button = $MarginContainer/VBoxContainer/ButtonContainer/ManageCrewButton
@onready var save_button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button = $MarginContainer/VBoxContainer/ButtonContainer/LoadButton
@onready var quit_button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton

# Properties
var game_state: FiveParsecsGameState
var phase_manager: CampaignPhaseManager
var current_step: CampaignStep = CampaignStep.TRAVEL
var current_turn: int = 1
var victory_condition: Dictionary = {
	"type": "", # wealth_goal, reputation_goal, faction_dominance, story_complete
	"target": 0,
	"current": 0,
	"achieved": false
}

func _ready() -> void:
	_connect_signals()
	_initialize_ui()

func setup(state: FiveParsecsGameState) -> void:
	game_state = state
	if game_state:
		current_step = game_state.current_step
		current_turn = game_state.current_turn
		phase_manager = CampaignPhaseManager.new(game_state, game_state.campaign_manager)
		phase_manager.phase_changed.connect(_on_phase_changed)
		phase_manager.phase_completed.connect(_on_phase_completed)
		_update_display()
	else:
		_initialize_ui()

func _connect_signals() -> void:
	action_button.pressed.connect(_on_action_pressed)
	manage_crew_button.pressed.connect(_on_manage_crew_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _initialize_ui() -> void:
	turn_label.text = "Turn: 1"
	step_label.text = "Step: Travel"
	victory_label.text = ""
	credits_label.text = "Credits: 0"
	story_points_label.text = "Story Points: 0"
	xp_label.text = "XP: 0"
	rumors_label.text = "Quest Rumors: 0"
	ship_info.text = "No Ship Data"
	quest_info.text = "No Active Quest"
	world_info.text = "No World Data"
	
	crew_list.clear()
	patron_list.clear()
	
	_update_button_states(true)

func _update_display() -> void:
	if not game_state:
		_initialize_ui()
		return
		
	# Update turn and step information
	turn_label.text = "Turn: %d" % current_turn
	
	var step_text = ""
	var step_details = ""
	
	match current_step:
		CampaignStep.TRAVEL:
			step_text = "Travel"
			step_details = "(Choose destination, handle events)"
		CampaignStep.WORLD:
			step_text = "World"
			step_details = "(Upkeep, tasks, job offers)"
		CampaignStep.BATTLE:
			step_text = "Battle"
			step_details = "(Combat encounter)"
		CampaignStep.POST_BATTLE:
			step_text = "Post-Battle"
			step_details = "(Recovery, rewards, events)"
	
	step_label.text = "Step: %s %s" % [step_text, step_details]
	
	# Update resources (core game currencies)
	credits_label.text = "Credits: %d" % game_state.credits
	story_points_label.text = "Story Points: %d" % game_state.story_points
	xp_label.text = "XP: %d" % game_state.experience_points
	rumors_label.text = "Quest Rumors: %d" % game_state.quest_rumors
	
	# Update victory progress if applicable
	if victory_condition.type != "":
		var progress = "%d/%d %s" % [
			victory_condition.current,
			victory_condition.target,
			victory_condition.type.capitalize()
		]
		victory_label.text = "Progress: %s" % progress
	else:
		victory_label.text = ""
	
	# Update crew list with detailed stats
	crew_list.clear()
	for character in game_state.crew:
		var stats = "R:%d S:%d C:%+d T:%d S:%+d XP:%d" % [
			character.reactions,
			character.speed,
			character.combat_skill,
				character.toughness,
			character.savvy,
			character.experience
		]
		var status = ""
		match character.status:
			GameEnums.CharacterStatus.HEALTHY:
				status = "[Active]"
			GameEnums.CharacterStatus.INJURED:
				status = "[Injured]"
			GameEnums.CharacterStatus.CRITICAL:
				status = "[Critical]"
			GameEnums.CharacterStatus.DEAD:
				status = "[Dead]"
		
		crew_list.add_item("%s (%s) %s - %s" % [character.name, character.origin, status, stats])
	
	_update_ship_info()
	_update_quest_info()
	_update_world_info()
	_update_patron_list()
	
	# Update button states based on current step
	_update_button_states(false)
	_update_action_button_text()

func _update_ship_info() -> void:
	if game_state.ship:
		var condition = ""
		match game_state.ship.condition:
			GameEnums.ShipCondition.PERFECT:
				condition = "Perfect"
			GameEnums.ShipCondition.GOOD:
				condition = "Good"
			GameEnums.ShipCondition.DAMAGED:
				condition = "Damaged"
			GameEnums.ShipCondition.BROKEN:
				condition = "Broken"
		
		ship_info.text = "Ship: %s\nCondition: %s\nHull: %d/%d\nDebt: %d credits" % [
			game_state.ship.name,
			condition,
			game_state.ship.current_hull,
			game_state.ship.max_hull,
			game_state.ship.debt
		]
	else:
		ship_info.text = "No Ship Data"

func _update_quest_info() -> void:
	if game_state.active_quest:
		var difficulty = ["Easy", "Normal", "Hard", "Very Hard"][game_state.active_quest.difficulty]
		quest_info.text = "%s\nDifficulty: %s\nReward: %d credits" % [
			game_state.active_quest.description,
			difficulty,
			game_state.active_quest.reward
		]
	else:
		quest_info.text = "No Active Quest"

func _update_world_info() -> void:
	if game_state.current_world:
		var environment = GameEnums.PlanetEnvironment.keys()[game_state.current_world.environment_type]
		var weather = GameEnums.WeatherType.keys()[game_state.current_world.weather]
		world_info.text = "%s\nEnvironment: %s\nWeather: %s" % [
			game_state.current_world.description,
			environment,
			weather
		]
	else:
		world_info.text = "No World Data"

func _update_patron_list() -> void:
	patron_list.clear()
	for patron in game_state.patrons:
		var relation = GameEnums.RelationType.keys()[patron.relation_type]
		patron_list.add_item("%s (%s)" % [patron.name, relation])

func _update_button_states(disabled: bool) -> void:
	var can_manage_crew = current_step == CampaignStep.POST_BATTLE
	
	action_button.disabled = disabled or victory_condition.achieved
	manage_crew_button.disabled = disabled or not can_manage_crew or victory_condition.achieved
	save_button.disabled = disabled

func _update_action_button_text() -> void:
	match current_step:
		CampaignStep.TRAVEL:
			action_button.text = "Choose Destination"
		CampaignStep.WORLD:
			action_button.text = "Handle World Step"
		CampaignStep.BATTLE:
			action_button.text = "Start Combat"
		CampaignStep.POST_BATTLE:
			action_button.text = "Process Results"

func _on_action_pressed() -> void:
	var action_data = {}
	match current_step:
		CampaignStep.TRAVEL:
			action_data["type"] = "choose_destination"
		CampaignStep.WORLD:
			action_data["type"] = "handle_world_step"
		CampaignStep.BATTLE:
			action_data["type"] = "start_combat"
		CampaignStep.POST_BATTLE:
			action_data["type"] = "process_results"
	
	action_requested.emit("step_action", action_data)

func _on_manage_crew_pressed() -> void:
	crew_management_requested.emit()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_load_pressed() -> void:
	load_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()

func _on_phase_changed(new_phase: int) -> void:
	_update_display()

func _on_phase_completed() -> void:
	# Advance to next step in campaign turn
	var next_step = (current_step + 1) % CampaignStep.size()
	if next_step == CampaignStep.TRAVEL:
		current_turn += 1
	current_step = next_step
	_update_display()
	
	# Check victory conditions
	_check_victory_conditions()

func _check_victory_conditions() -> void:
	if victory_condition.type == "" or victory_condition.achieved:
		return
		
	match victory_condition.type:
		"wealth_goal":
			victory_condition.current = game_state.credits
		"reputation_goal":
			victory_condition.current = game_state.reputation
		"faction_dominance":
			victory_condition.current = game_state.faction_influence
		"story_complete":
			victory_condition.current = game_state.story_progress
	
	if victory_condition.current >= victory_condition.target:
		victory_condition.achieved = true
		victory_achieved.emit(victory_condition.type, victory_condition.current)
		
		# Update UI to reflect victory
		victory_label.text = "VICTORY! %s Goal Achieved: %d" % [
			victory_condition.type.capitalize(),
			victory_condition.current
		]
		
		# Disable action buttons since campaign is complete
		_update_button_states(false)