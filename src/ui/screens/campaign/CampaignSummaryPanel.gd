extends Control

# GlobalEnums available as autoload singleton

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
		GlobalEnums.DifficultyLevel.STORY:
			return "Story"
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Standard"
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Challenging"
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Hardcore"
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "Nightmare"
		_:
			return "Unknown"