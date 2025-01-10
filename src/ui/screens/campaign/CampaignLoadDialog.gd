extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var campaign_list = $VBoxContainer/CampaignList
@onready var load_button = $VBoxContainer/LoadButton
@onready var delete_button = $VBoxContainer/DeleteButton
@onready var summary_panel = $VBoxContainer/SummaryPanel

signal campaign_selected(campaign_data: Dictionary)
signal campaign_deleted(campaign_name: String)

var selected_campaign: Dictionary

func _ready() -> void:
    _connect_signals()
    _update_ui_state()

func _connect_signals() -> void:
    campaign_list.item_selected.connect(_on_campaign_selected)
    load_button.pressed.connect(_on_load_pressed)
    delete_button.pressed.connect(_on_delete_pressed)

func _update_ui_state() -> void:
    var has_selection = not selected_campaign.is_empty()
    load_button.disabled = not has_selection
    delete_button.disabled = not has_selection

func update_campaign_list(campaigns: Array) -> void:
    campaign_list.clear()
    for campaign in campaigns:
        var text = "%s (%s)" % [campaign.name, _get_difficulty_name(campaign.difficulty_level)]
        campaign_list.add_item(text)

func _get_difficulty_name(difficulty: int) -> String:
    match difficulty:
        GameEnums.DifficultyLevel.EASY:
            return "Easy"
        GameEnums.DifficultyLevel.NORMAL:
            return "Normal"
        GameEnums.DifficultyLevel.HARD:
            return "Hard"
        GameEnums.DifficultyLevel.VETERAN:
            return "Veteran"
        GameEnums.DifficultyLevel.ELITE:
            return "Elite"
        _:
            return "Unknown"

func _on_campaign_selected(index: int) -> void:
    selected_campaign = _get_campaign_data(index)
    summary_panel.update_summary(selected_campaign)
    _update_ui_state()

func _on_load_pressed() -> void:
    if not selected_campaign.is_empty():
        campaign_selected.emit(selected_campaign)

func _on_delete_pressed() -> void:
    if not selected_campaign.is_empty():
        campaign_deleted.emit(selected_campaign.name)
        selected_campaign = {}
        _update_ui_state()

func _get_campaign_data(index: int) -> Dictionary:
    # This would be replaced with actual campaign data retrieval
    return {
        "name": "Test Campaign",
        "difficulty_level": GameEnums.DifficultyLevel.NORMAL,
        "enable_permadeath": false,
        "use_story_track": true,
        "missions_completed": 5,
        "credits": 1000
    }