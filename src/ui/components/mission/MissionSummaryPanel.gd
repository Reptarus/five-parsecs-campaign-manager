# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self := "res://src/ui/components/mission/MissionSummaryPanel.gd" # Use string path instead of preload

signal continue_pressed

@onready var title_label := $TitleLabel
@onready var outcome_label := $OutcomeLabel
@onready var stats_container := $StatsContainer
@onready var rewards_container := $RewardsContainer
@onready var continue_button := $ContinueButton

var mission_data: Dictionary

func _ready() -> void:
    continue_button.pressed.connect(_on_continue_pressed)

func setup(data: Dictionary) -> void:
    mission_data = data
    _update_display()

func _update_display() -> void:
    title_label.text = mission_data.get("title", "Mission Complete")
    
    var outcome = mission_data.get("outcome", {})
    outcome_label.text = _get_outcome_text(outcome)
    
    _update_stats(mission_data.get("stats", {}))
    _update_rewards(mission_data.get("rewards", {}))

func _get_outcome_text(outcome: Dictionary) -> String:
    var victory = outcome.get("victory", false)
    var text = "Mission "
    
    if victory:
        text += "Successful!"
        if outcome.has("victory_type"):
            text += "\n" + _get_victory_type_text(outcome.victory_type)
    else:
        text += "Failed"
        if outcome.has("failure_reason"):
            text += "\n" + outcome.failure_reason
    
    return text

func _get_victory_type_text(type: String) -> String:
    match type:
        "objective":
            return "All objectives completed"
        "elimination":
            return "All enemies eliminated"
        "survival":
            return "Survived the encounter"
        "extraction":
            return "Successfully extracted"
        _:
            return "Mission completed"

func _update_stats(stats: Dictionary) -> void:
    # Clear existing stats
    for child in stats_container.get_children():
        child.queue_free()
    
    # Add new stat entries
    _add_stat_entry("Turns", str(stats.get("turns", 0)))
    _add_stat_entry("Enemies Defeated", str(stats.get("enemies_defeated", 0)))
    _add_stat_entry("Damage Dealt", str(stats.get("damage_dealt", 0)))
    _add_stat_entry("Damage Taken", str(stats.get("damage_taken", 0)))
    _add_stat_entry("Items Used", str(stats.get("items_used", 0)))
    
    if stats.has("crew_status"):
        _add_stat_entry("Crew Status", _format_crew_status(stats.crew_status))

func _update_rewards(rewards: Dictionary) -> void:
    # Clear existing rewards
    for child in rewards_container.get_children():
        child.queue_free()
    
    # Add new reward entries
    if rewards.has("credits"):
        _add_reward_entry("Credits", str(rewards.credits))
    
    if rewards.has("items"):
        for item in rewards.items:
            _add_reward_entry("Item", item.name)
    
    if rewards.has("reputation"):
        _add_reward_entry("Reputation", str(rewards.reputation))
    
    if rewards.has("experience"):
        _add_reward_entry("Experience", str(rewards.experience))

func _add_stat_entry(label: String, value: String) -> void:
    var container = HBoxContainer.new()
    
    var label_node = Label.new()
    label_node.text = label + ":"
    container.add_child(label_node)
    
    var value_node = Label.new()
    value_node.text = value
    container.add_child(value_node)
    
    stats_container.add_child(container)

func _add_reward_entry(type: String, value: String) -> void:
    var container = HBoxContainer.new()
    
    var type_label = Label.new()
    type_label.text = type + ":"
    container.add_child(type_label)
    
    var value_label = Label.new()
    value_label.text = value
    container.add_child(value_label)
    
    rewards_container.add_child(container)

func _format_crew_status(status: Array) -> String:
    var text = ""
    for member in status:
        text += member.name + ": " + member.condition + "\n"
    return text.strip_edges()

func _on_continue_pressed() -> void:
    continue_pressed.emit()