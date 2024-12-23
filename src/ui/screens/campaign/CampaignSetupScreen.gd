class_name CampaignSetupScreen
extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

const DEFAULT_CREW_SIZE := GameEnums.CrewSize.SIX
const MIN_CREW_SIZE := GameEnums.CrewSize.FOUR
const MAX_CREW_SIZE := GameEnums.CrewSize.SIX

@onready var crew_name_input := $HBoxContainer/LeftPanel/VBoxContainer/CrewNameContainer/CrewNameInput
@onready var crew_size_option := $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/CrewSizeOption
@onready var difficulty_option := $HBoxContainer/LeftPanel/VBoxContainer/DifficultyContainer/DifficultyOption
@onready var victory_option := $HBoxContainer/LeftPanel/VBoxContainer/VictoryContainer/VictoryOption
@onready var story_track_toggle := $HBoxContainer/LeftPanel/VBoxContainer/StoryTrackContainer/StoryTrackToggle
@onready var start_campaign_button := $HBoxContainer/LeftPanel/VBoxContainer/StartCampaignButton
@onready var summary_label := $HBoxContainer/RightPanel/Panel/MarginContainer/VBoxContainer/SummaryLabel

var campaign_manager: GameCampaignManager
var campaign_config := {
    "crew_name": "",
    "crew_size": DEFAULT_CREW_SIZE,
    "difficulty_mode": GameEnums.DifficultyMode.NORMAL,
    "victory_condition": GameEnums.CampaignVictoryType.TURNS_20,
    "use_story_track": false,
    "enable_tutorial": true,
    "use_expanded_missions": false,
    "starting_credits": 1000,
    "starting_supplies": 5,
    "enable_permadeath": false
}

func _ready() -> void:
    campaign_manager = get_node("/root/CampaignManager")
    if not campaign_manager:
        push_error("CampaignManager not found")
        return
        
    _setup_difficulty_options()
    _setup_victory_options()
    _setup_crew_size_options()
    _connect_signals()
    _update_summary()
    _validate_config()

func _connect_signals() -> void:
    crew_name_input.text_changed.connect(_on_crew_name_changed)
    crew_size_option.item_selected.connect(_on_crew_size_changed)
    difficulty_option.item_selected.connect(_on_difficulty_changed)
    victory_option.item_selected.connect(_on_victory_condition_selected)
    story_track_toggle.toggled.connect(_on_story_track_toggled)
    start_campaign_button.pressed.connect(_on_start_campaign_pressed)

func _setup_difficulty_options() -> void:
    difficulty_option.clear()
    
    difficulty_option.add_item("Easy", GameEnums.DifficultyMode.EASY)
    difficulty_option.add_item("Normal", GameEnums.DifficultyMode.NORMAL)
    difficulty_option.add_item("Hard", GameEnums.DifficultyMode.HARD)
    difficulty_option.add_item("Ironman", GameEnums.DifficultyMode.IRONMAN)
    
    difficulty_option.select(GameEnums.DifficultyMode.NORMAL)

func _setup_victory_options() -> void:
    victory_option.clear()
    
    # Easy mode only allows specific victory conditions
    if campaign_config.difficulty_mode == GameEnums.DifficultyMode.EASY:
        victory_option.add_item("20 Campaign Turns", GameEnums.CampaignVictoryType.TURNS_20)
        victory_option.add_item("3 Story Quests", GameEnums.CampaignVictoryType.QUESTS_3)
        return
    
    # Turn-based Victory Conditions
    victory_option.add_item("20 Campaign Turns", GameEnums.CampaignVictoryType.TURNS_20)
    victory_option.add_item("50 Campaign Turns", GameEnums.CampaignVictoryType.TURNS_50)
    victory_option.add_item("100 Campaign Turns", GameEnums.CampaignVictoryType.TURNS_100)
    
    # Quest-based Victory Conditions
    victory_option.add_item("3 Story Quests", GameEnums.CampaignVictoryType.QUESTS_3)
    victory_option.add_item("5 Story Quests", GameEnums.CampaignVictoryType.QUESTS_5)
    victory_option.add_item("10 Story Quests", GameEnums.CampaignVictoryType.QUESTS_10)
    
    # Other Victory Conditions
    victory_option.add_item("Story Completion", GameEnums.CampaignVictoryType.STORY_COMPLETE)
    victory_option.add_item("Wealth Goal", GameEnums.CampaignVictoryType.WEALTH_GOAL)
    victory_option.add_item("Reputation Goal", GameEnums.CampaignVictoryType.REPUTATION_GOAL)
    victory_option.add_item("Faction Dominance", GameEnums.CampaignVictoryType.FACTION_DOMINANCE)

func _setup_crew_size_options() -> void:
    crew_size_option.clear()
    
    crew_size_option.add_item("6 Crew Members (2D6 higher)", GameEnums.CrewSize.SIX)
    crew_size_option.add_item("5 Crew Members (1D6)", GameEnums.CrewSize.FIVE)
    crew_size_option.add_item("4 Crew Members (2D6 lower)", GameEnums.CrewSize.FOUR)
    
    crew_size_option.select(DEFAULT_CREW_SIZE - MIN_CREW_SIZE)

func _on_crew_name_changed(new_name: String) -> void:
    campaign_config.crew_name = new_name
    _validate_config()
    _update_summary()

func _on_crew_size_changed(index: int) -> void:
    campaign_config.crew_size = crew_size_option.get_item_id(index)
    _validate_config()
    _update_summary()

func _on_difficulty_changed(index: int) -> void:
    campaign_config.difficulty_mode = difficulty_option.get_item_id(index)
    campaign_config.enable_permadeath = campaign_config.difficulty_mode == GameEnums.DifficultyMode.IRONMAN
    
    # Update victory conditions based on difficulty
    _setup_victory_options()
    _validate_config()
    _update_summary()

func _on_victory_condition_selected(index: int) -> void:
    campaign_config.victory_condition = victory_option.get_item_id(index)
    _validate_config()
    _update_summary()

func _on_story_track_toggled(button_pressed: bool) -> void:
    campaign_config.use_story_track = button_pressed
    _validate_config()
    _update_summary()

func _validate_config() -> bool:
    var valid = true
    var errors = []
    
    # Validate crew name
    if campaign_config.crew_name.strip_edges().is_empty():
        valid = false
        errors.append("Crew name is required")
    
    # Validate crew size
    if campaign_config.crew_size < MIN_CREW_SIZE or campaign_config.crew_size > MAX_CREW_SIZE:
        valid = false
        errors.append("Invalid crew size")
    
    # Validate victory condition for difficulty
    if campaign_config.difficulty_mode == GameEnums.DifficultyMode.EASY:
        if not campaign_config.victory_condition in [
            GameEnums.CampaignVictoryType.TURNS_20,
            GameEnums.CampaignVictoryType.QUESTS_3
        ]:
            valid = false
            errors.append("Invalid victory condition for Easy difficulty")
    
    # Update start button state
    start_campaign_button.disabled = not valid
    
    # Update summary with errors if any
    if not errors.is_empty():
        summary_label.text += "\n\nErrors:\n" + "\n".join(errors)
    
    return valid

func _update_summary() -> void:
    var difficulty_name = difficulty_option.get_item_text(difficulty_option.selected)
    var victory_text = _get_victory_description(campaign_config.victory_condition)
    var crew_text = _get_crew_size_description(campaign_config.crew_size)
    
    summary_label.text = """Campaign Setup Summary:
    
    Crew Name: %s
    %s
    Difficulty: %s
    Victory Condition: %s
    Story Track: %s
    Starting Credits: %d
    Starting Supplies: %d
    Tutorial: %s
    Expanded Missions: %s
    Permadeath: %s""" % [
        campaign_config.crew_name,
        crew_text,
        difficulty_name,
        victory_text,
        "Enabled" if campaign_config.use_story_track else "Disabled",
        campaign_config.starting_credits,
        campaign_config.starting_supplies,
        "Enabled" if campaign_config.enable_tutorial else "Disabled",
        "Enabled" if campaign_config.use_expanded_missions else "Disabled",
        "Enabled" if campaign_config.enable_permadeath else "Disabled"
    ]

func _get_crew_size_description(size: int) -> String:
    match size:
        GameEnums.CrewSize.SIX:
            return "Crew Size: 6 (2D6 higher for enemies)"
        GameEnums.CrewSize.FIVE:
            return "Crew Size: 5 (1D6 for enemies)"
        GameEnums.CrewSize.FOUR:
            return "Crew Size: 4 (2D6 lower for enemies)"
        _:
            return "Invalid Crew Size"

func _get_victory_description(condition: int) -> String:
    match condition:
        GameEnums.CampaignVictoryType.TURNS_20:
            return "Complete 20 campaign turns"
        GameEnums.CampaignVictoryType.TURNS_50:
            return "Complete 50 campaign turns" 
        GameEnums.CampaignVictoryType.TURNS_100:
            return "Complete 100 campaign turns"
        GameEnums.CampaignVictoryType.QUESTS_3:
            return "Complete 3 story quests"
        GameEnums.CampaignVictoryType.QUESTS_5:
            return "Complete 5 story quests"
        GameEnums.CampaignVictoryType.QUESTS_10:
            return "Complete 10 story quests"
        GameEnums.CampaignVictoryType.STORY_COMPLETE:
            return "Complete the main story campaign"
        GameEnums.CampaignVictoryType.WEALTH_GOAL:
            return "Accumulate 1000 credits"
        GameEnums.CampaignVictoryType.REPUTATION_GOAL:
            return "Achieve maximum reputation"
        GameEnums.CampaignVictoryType.FACTION_DOMINANCE:
            return "Become the dominant faction"
        _:
            return "Invalid victory condition"

func _on_start_campaign_pressed() -> void:
    if not _validate_config():
        return
        
    if campaign_manager:
        campaign_manager.initialize_new_campaign(campaign_config)
        # Scene change will be handled by CampaignManager's _on_campaign_started signal 