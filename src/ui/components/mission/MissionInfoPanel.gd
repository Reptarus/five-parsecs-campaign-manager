# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/ui/components/mission/MissionInfoPanel.gd")

signal mission_selected(mission_data: Dictionary)

@onready var title_label := $TitleLabel
@onready var description_label := $DescriptionLabel
@onready var difficulty_label := $DifficultyLabel
@onready var rewards_label := $RewardsLabel

func setup(mission_data: Dictionary) -> void:
    title_label.text = mission_data.get("title", "Unknown Mission")
    description_label.text = mission_data.get("description", "No description available")
    
    var difficulty = mission_data.get("difficulty", 1)
    difficulty_label.text = "Difficulty: " + _get_difficulty_text(difficulty)
    
    var rewards = mission_data.get("rewards", {})
    rewards_label.text = _format_rewards(rewards)

func _get_difficulty_text(difficulty: int) -> String:
    match difficulty:
        0: return "Easy"
        1: return "Normal"
        2: return "Hard"
        3: return "Very Hard"
        _: return "Unknown"

func _format_rewards(rewards: Dictionary) -> String:
    var reward_text := "Rewards:\n"
    
    if rewards.has("credits"):
        reward_text += "- %d Credits\n" % rewards.credits
    if rewards.has("items"):
        for item in rewards.items:
            reward_text += "- %s\n" % item.name
    if rewards.has("reputation"):
        reward_text += "- %d Reputation\n" % rewards.reputation
    
    return reward_text

func _on_accept_button_pressed() -> void:
    mission_selected.emit({
        "title": title_label.text,
        "description": description_label.text
    })