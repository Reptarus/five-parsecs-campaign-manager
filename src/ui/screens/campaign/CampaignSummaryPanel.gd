extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var campaign_name_label = $VBoxContainer/CampaignNameLabel
@onready var difficulty_label = $VBoxContainer/DifficultyLabel
@onready var permadeath_label = $VBoxContainer/PermadeathLabel
@onready var story_track_label = $VBoxContainer/StoryTrackLabel
@onready var missions_completed_label = $VBoxContainer/MissionsCompletedLabel
@onready var credits_label = $VBoxContainer/CreditsLabel

func update_summary(campaign_data: Dictionary) -> void:
    campaign_name_label.text = "Campaign: %s" % campaign_data.name
    difficulty_label.text = "Difficulty: %s" % _get_difficulty_name(campaign_data.difficulty_level)
    permadeath_label.text = "Permadeath: %s" % ("Enabled" if campaign_data.enable_permadeath else "Disabled")
    story_track_label.text = "Story Track: %s" % ("Enabled" if campaign_data.use_story_track else "Disabled")
    missions_completed_label.text = "Missions Completed: %d" % campaign_data.missions_completed
    credits_label.text = "Credits: %d" % campaign_data.credits

func _get_difficulty_name(difficulty: int) -> String:
    match difficulty:
        GameEnums.DifficultyLevel.EASY:
            return "Easy"
        GameEnums.DifficultyLevel.NORMAL:
            return "Normal"
        GameEnums.DifficultyLevel.HARD:
            return "Hard"
        GameEnums.DifficultyLevel.HARDCORE:
            return "Hardcore"
        GameEnums.DifficultyLevel.ELITE:
            return "Elite"
        _:
            return "Unknown"