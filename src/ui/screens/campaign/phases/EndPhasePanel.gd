extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/EndPhasePanel.gd")

signal cycle_completed
signal campaign_saved

@onready var summary_label: Label = $VBoxContainer/SummaryLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton

var cycle_summary: Dictionary = {}

func _ready() -> void:
    super._ready()
    save_button.pressed.connect(_on_save_button_pressed)
    continue_button.pressed.connect(_on_continue_button_pressed)
    continue_button.disabled = true

func setup_phase() -> void:
    super.setup_phase()
    # Generate cycle summary
    generate_cycle_summary()
    # Update UI with summary
    update_summary_display()
    # Enable save button
    save_button.disabled = false

func generate_cycle_summary() -> void:
    # TODO: Get actual data from campaign state
    cycle_summary = {
        "missions_completed": 2,
        "credits_earned": 500,
        "items_acquired": 3,
        "casualties": 0,
        "experience_gained": 150
    }

func update_summary_display() -> void:
    summary_label.text = "Campaign Cycle Summary"
    
    # Clear existing stats
    for child in stats_container.get_children():
        child.queue_free()
    
    # Add stats to container
    for stat in cycle_summary:
        var stat_label = Label.new()
        stat_label.text = stat.capitalize().replace("_", " ") + ": " + str(cycle_summary[stat])
        stats_container.add_child(stat_label)

func _on_save_button_pressed() -> void:
    # TODO: Implement actual save functionality
    emit_signal("campaign_saved")
    save_button.disabled = true
    continue_button.disabled = false

func _on_continue_button_pressed() -> void:
    emit_signal("cycle_completed")

func validate_phase_requirements() -> bool:
    return true # No specific requirements for end phase

func get_phase_data() -> Dictionary:
    return {
        "cycle_summary": cycle_summary,
        "save_completed": not save_button.disabled,
        "cycle_completed": not continue_button.disabled
    }
