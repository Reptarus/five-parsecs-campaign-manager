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
	_style_phase_title(summary_label)
	_style_phase_button(save_button)
	_style_phase_button(continue_button, true)
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
		continue_button.disabled = true

func setup_phase() -> void:
	super.setup_phase()
	generate_cycle_summary()
	update_summary_display()
	if save_button:
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
	if summary_label:
		summary_label.text = "Campaign Cycle Summary"

	if not stats_container:
		return
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()

	# Add stats to container
	for stat in cycle_summary:
		var stat_label = Label.new()
		stat_label.text = stat.capitalize().replace("_", " ") + ": " + str(cycle_summary[stat])
		stats_container.add_child(stat_label)

func _on_save_button_pressed() -> void:
	if game_state and game_state.has_method("save_campaign"):
		game_state.save_campaign()
	campaign_saved.emit()
	if save_button:
		save_button.disabled = true
	if continue_button:
		continue_button.disabled = false

func _on_continue_button_pressed() -> void:
	cycle_completed.emit()
	complete_phase()

func validate_phase_requirements() -> bool:
	return true

func get_phase_data() -> Dictionary:
	return {
		"cycle_summary": cycle_summary,
		"save_completed": save_button != null and save_button.disabled,
		"cycle_completed": continue_button != null and not continue_button.disabled
	}
