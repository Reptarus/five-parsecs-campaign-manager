extends PanelContainer

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

@onready var progress_bar := $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label := $MarginContainer/VBoxContainer/ProgressLabel
@onready var milestone_container := $MarginContainer/VBoxContainer/MilestoneContainer

var game_state: FiveParsecsGameState
var campaign_manager # Type will be inferred from CampaignManager singleton
var victory_type: GameEnums.FiveParcsecsCampaignVictoryType
var current_progress: float = 0.0
var target_progress: float = 20.0 # Default for TURNS_20
var milestones: Array[float] = []

func _ready() -> void:
	campaign_manager = get_node("/root/CampaignManager")
	if not campaign_manager:
		push_error("CampaignManager not found")
		queue_free()
		return
		
	game_state = campaign_manager.game_state
	if not game_state:
		push_error("GameState not found")
		queue_free()
		return
	
	_initialize_victory_tracking()
	_connect_signals()
	update_display()

func _connect_signals() -> void:
	if campaign_manager:
		campaign_manager.campaign_system.campaign_turn_completed.connect(_on_turn_completed)
		campaign_manager.campaign_system.campaign_progress_updated.connect(_on_progress_updated)

func _initialize_victory_tracking() -> void:
	victory_type = game_state.campaign_victory_condition
	
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_20:
			target_progress = 20.0
			milestones = [5.0, 10.0, 15.0]
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_50:
			target_progress = 50.0
			milestones = [15.0, 30.0, 45.0]
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_100:
			target_progress = 100.0
			milestones = [25.0, 50.0, 75.0]
		GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_3:
			target_progress = 3.0
			milestones = [1.0, 2.0, 3.0]
		GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_5:
			target_progress = 5.0
			milestones = [2.0, 3.0, 4.0]
		GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_10:
			target_progress = 10.0
			milestones = [3.0, 6.0, 9.0]
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			target_progress = 1.0
			milestones = [0.3, 0.6, 0.9]
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			target_progress = 1000.0
			milestones = [250.0, 500.0, 750.0]
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			target_progress = 100.0
			milestones = [25.0, 50.0, 75.0]
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			target_progress = 100.0
			milestones = [30.0, 60.0, 90.0]
	
	progress_bar.max_value = target_progress
	_setup_milestone_icons()

func _setup_milestone_icons() -> void:
	for i in range(3):
		var milestone_icon = milestone_container.get_child(i)
		if milestone_icon:
			milestone_icon.modulate = Color(0.5, 0.5, 0.5) # Dim by default

func update_display() -> void:
	current_progress = _calculate_current_progress()
	progress_bar.value = current_progress
	
	var progress_text = ""
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_20, GameEnums.FiveParcsecsCampaignVictoryType.TURNS_50, GameEnums.FiveParcsecsCampaignVictoryType.TURNS_100:
			progress_text = "Progress: %d/%d Turns" % [current_progress, target_progress]
		GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_3, GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_5, GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_10:
			progress_text = "Progress: %d/%d Quests" % [current_progress, target_progress]
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			progress_text = "Story Progress: %d%%" % (current_progress * 100)
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			progress_text = "Credits: %d/%d" % [current_progress, target_progress]
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			progress_text = "Reputation: %d/%d" % [current_progress, target_progress]
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			progress_text = "Faction Control: %d%%" % current_progress
	
	progress_label.text = progress_text
	_update_milestone_display()

func _calculate_current_progress() -> float:
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_20, GameEnums.FiveParcsecsCampaignVictoryType.TURNS_50, GameEnums.FiveParcsecsCampaignVictoryType.TURNS_100:
			return float(game_state.campaign_turn)
		GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_3, GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_5, GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_10:
			return float(game_state.completed_quests.size())
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			return game_state.story_progress
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			return float(game_state.credits)
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			return float(game_state.reputation)
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			return game_state.faction_control
	return 0.0

func _update_milestone_display() -> void:
	for i in range(3):
		var milestone_icon = milestone_container.get_child(i)
		if milestone_icon and i < milestones.size():
			if current_progress >= milestones[i]:
				milestone_icon.modulate = Color(1, 1, 1) # Full brightness for achieved
			else:
				milestone_icon.modulate = Color(0.5, 0.5, 0.5) # Dim for not achieved

func _on_turn_completed() -> void:
	update_display()

func _on_progress_updated(progress: float) -> void:
	current_progress = progress
	update_display()