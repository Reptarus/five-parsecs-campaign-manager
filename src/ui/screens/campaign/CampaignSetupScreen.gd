class_name CampaignSetupScreen
extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var campaign_name_input = $VBoxContainer/CampaignNameInput
@onready var difficulty_option = $VBoxContainer/DifficultyOption
@onready var permadeath_toggle = $VBoxContainer/PermadeathToggle
@onready var story_track_toggle = $VBoxContainer/StoryTrackToggle
@onready var start_button = $VBoxContainer/StartButton

signal campaign_started(config: Dictionary)

var campaign_config = {
    "name": "",
    "difficulty_level": GameEnums.DifficultyLevel.NORMAL,
    "enable_permadeath": false,
    "use_story_track": true
}

func _ready() -> void:
    _setup_difficulty_options()
    _connect_signals()
    _update_ui_state()

func _setup_difficulty_options() -> void:
    difficulty_option.add_item("Easy", GameEnums.DifficultyLevel.EASY)
    difficulty_option.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
    difficulty_option.add_item("Hard", GameEnums.DifficultyLevel.HARD)
    difficulty_option.add_item("Hardcore", GameEnums.DifficultyLevel.HARDCORE)
    difficulty_option.add_item("Elite", GameEnums.DifficultyLevel.ELITE)
    
    difficulty_option.select(GameEnums.DifficultyLevel.NORMAL)

func _connect_signals() -> void:
    campaign_name_input.text_changed.connect(_on_campaign_name_changed)
    difficulty_option.item_selected.connect(_on_difficulty_changed)
    permadeath_toggle.toggled.connect(_on_permadeath_toggled)
    story_track_toggle.toggled.connect(_on_story_track_toggled)
    start_button.pressed.connect(_on_start_pressed)

func _update_ui_state() -> void:
    start_button.disabled = campaign_config.name.is_empty()
    
    if campaign_config.difficulty_level == GameEnums.DifficultyLevel.EASY:
        permadeath_toggle.disabled = true
        permadeath_toggle.button_pressed = false
    else:
        permadeath_toggle.disabled = false
    
    if campaign_config.difficulty_level in [GameEnums.DifficultyLevel.HARDCORE, GameEnums.DifficultyLevel.ELITE]:
        permadeath_toggle.disabled = true
        permadeath_toggle.button_pressed = true

func _get_difficulty_description(difficulty: int) -> String:
    match difficulty:
        GameEnums.DifficultyLevel.EASY:
            return "Reduced enemy count and easier combat."
        GameEnums.DifficultyLevel.NORMAL:
            return "Standard difficulty with balanced challenges."
        GameEnums.DifficultyLevel.HARD:
            return "More enemies and tougher combat encounters."
        GameEnums.DifficultyLevel.HARDCORE:
            return "Significantly harder with elite enemies. Permadeath enabled."
        GameEnums.DifficultyLevel.ELITE:
            return "The ultimate challenge. Elite enemies and permadeath."
        _:
            return "Unknown difficulty level"

func _on_campaign_name_changed(new_text: String) -> void:
    campaign_config.name = new_text
    _update_ui_state()

func _on_difficulty_changed(index: int) -> void:
    campaign_config.difficulty_level = index
    difficulty_option.tooltip_text = _get_difficulty_description(index)
    _update_ui_state()

func _on_permadeath_toggled(enabled: bool) -> void:
    campaign_config.enable_permadeath = enabled

func _on_story_track_toggled(enabled: bool) -> void:
    campaign_config.use_story_track = enabled

func _on_start_pressed() -> void:
    if campaign_config.difficulty_level in [GameEnums.DifficultyLevel.HARDCORE, GameEnums.DifficultyLevel.ELITE] and not campaign_config.enable_permadeath:
        campaign_config.enable_permadeath = true
    
    campaign_started.emit(campaign_config)
    queue_free()