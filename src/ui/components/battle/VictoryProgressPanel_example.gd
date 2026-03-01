## Example usage of VictoryProgressPanel
## This file demonstrates how to use the VictoryProgressPanel component

extends Node

func example_usage() -> void:
	# Create the panel
	var victory_panel := VictoryProgressPanel.new()
	add_child(victory_panel)

	# Connect signals
	victory_panel.victory_condition_met.connect(_on_victory_condition_met)
	victory_panel.defeat_condition_triggered.connect(_on_defeat_condition_triggered)
	victory_panel.objective_status_changed.connect(_on_objective_status_changed)

	# Set up victory conditions
	var conditions := [
		{
			"id": "eliminate_enemies",
			"name": "Eliminate All Enemies",
			"description": "Defeat all enemy units on the battlefield",
			"progress": 0.0,
			"status": "pending"
		},
		{
			"id": "defend_position",
			"name": "Defend Position",
			"description": "Hold the objective for 5 turns",
			"progress": 0.0,
			"status": "pending"
		},
		{
			"id": "extract_vip",
			"name": "Extract VIP",
			"description": "Get the VIP to the extraction point",
			"progress": 0.5,  # 50% complete
			"status": "in_progress"
		}
	]

	victory_panel.set_conditions(conditions)

	# Set turns remaining (optional)
	victory_panel.set_turns_remaining(8)

	# Simulate progress updates during battle
	await get_tree().create_timer(2.0).timeout
	victory_panel.update_condition_progress("eliminate_enemies", 0.3, "in_progress")

	await get_tree().create_timer(2.0).timeout
	victory_panel.update_condition_progress("defend_position", 0.6, "in_progress")

	await get_tree().create_timer(2.0).timeout
	victory_panel.update_condition_progress("extract_vip", 1.0, "complete")  # Complete!

	# Update turns
	victory_panel.set_turns_remaining(5)

	# Check victory status
	if victory_panel.is_victory_achieved():
		print("Victory achieved!")

	print("Overall progress: %.1f%%" % (victory_panel.get_overall_progress() * 100.0))

func _on_victory_condition_met(condition_id: String) -> void:
	print("Victory condition met: ", condition_id)

func _on_defeat_condition_triggered(reason: String) -> void:
	print("Defeat triggered: ", reason)

func _on_objective_status_changed(objective_id: String, status: String) -> void:
	print("Objective '%s' status changed to: %s" % [objective_id, status])
