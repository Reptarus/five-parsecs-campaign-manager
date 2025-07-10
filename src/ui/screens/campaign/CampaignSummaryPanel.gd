extends Control

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var campaign_name_label: Label = $"VBoxContainer/CampaignNameLabel"
@onready var difficulty_label: Label = $"VBoxContainer/DifficultyLabel"
@onready var permadeath_label: Label = $"VBoxContainer/PermadeathLabel"
@onready var story_track_label: Label = $"VBoxContainer/StoryTrackLabel"
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
		GlobalEnums.DifficultyLevel.EASY:
			return "Easy"
		GlobalEnums.DifficultyLevel.NORMAL:
			return "Normal"
		GlobalEnums.DifficultyLevel.HARD:
			return "Hard"
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Hardcore"
		GlobalEnums.DifficultyLevel.ELITE:
			return "Elite"
		_:
			return "Unknown"