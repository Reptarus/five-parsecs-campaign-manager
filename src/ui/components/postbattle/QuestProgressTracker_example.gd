extends Control

## Example usage of QuestProgressTracker component
## Shows all three quest outcomes: Dead End, Progress, Finale Ready

@onready var _example_container: VBoxContainer = $ExampleContainer

func _ready() -> void:
	_create_examples()

func _create_examples() -> void:
	"""Create example quest trackers for all outcomes"""

	# Example 1: Dead End (roll ≤3)
	var dead_end_tracker := QuestProgressTracker.new()
	dead_end_tracker.setup({
		"quest_name": "Hunt for the Crimson Star",
		"base_roll": 2,
		"rumors": 1,
		"modifier": 0,
		"total": 3,
		"outcome": QuestProgressTracker.QuestOutcome.DEAD_END,
		"travel_required": false,
		"progress_percent": 30.0
	})
	dead_end_tracker.quest_finale_ready.connect(_on_quest_finale_ready)
	_example_container.add_child(dead_end_tracker)

	# Spacer
	_example_container.add_child(_create_spacer())

	# Example 2: Progress (roll 4-6)
	var progress_tracker := QuestProgressTracker.new()
	progress_tracker.setup({
		"quest_name": "Retrieve the Lost Artifact",
		"base_roll": 4,
		"rumors": 2,
		"modifier": 0,
		"total": 6,
		"outcome": QuestProgressTracker.QuestOutcome.PROGRESS,
		"travel_required": false,
		"progress_percent": 60.0
	})
	progress_tracker.quest_finale_ready.connect(_on_quest_finale_ready)
	_example_container.add_child(progress_tracker)

	# Spacer
	_example_container.add_child(_create_spacer())

	# Example 3: Finale Ready (roll 7+)
	var finale_tracker := QuestProgressTracker.new()
	finale_tracker.setup({
		"quest_name": "Destroy the Unity Stronghold",
		"base_roll": 6,
		"rumors": 3,
		"modifier": 0,
		"total": 9,
		"outcome": QuestProgressTracker.QuestOutcome.FINALE_READY,
		"travel_required": false,
		"progress_percent": 100.0
	})
	finale_tracker.quest_finale_ready.connect(_on_quest_finale_ready)
	_example_container.add_child(finale_tracker)

	# Spacer
	_example_container.add_child(_create_spacer())

	# Example 4: Lost Battle with Modifier
	var lost_battle_tracker := QuestProgressTracker.new()
	lost_battle_tracker.setup({
		"quest_name": "Investigate the Abandoned Colony",
		"base_roll": 5,
		"rumors": 1,
		"modifier": -2,  # Lost battle penalty
		"total": 4,
		"outcome": QuestProgressTracker.QuestOutcome.PROGRESS,
		"travel_required": false,
		"progress_percent": 40.0
	})
	lost_battle_tracker.quest_finale_ready.connect(_on_quest_finale_ready)
	_example_container.add_child(lost_battle_tracker)

	# Spacer
	_example_container.add_child(_create_spacer())

	# Example 5: Travel Required
	var travel_tracker := QuestProgressTracker.new()
	travel_tracker.setup({
		"quest_name": "Chase the Pirate Fleet",
		"base_roll": 3,
		"rumors": 2,
		"modifier": 0,
		"total": 5,
		"outcome": QuestProgressTracker.QuestOutcome.PROGRESS,
		"travel_required": true,  # Must travel to continue
		"progress_percent": 50.0
	})
	travel_tracker.quest_finale_ready.connect(_on_quest_finale_ready)
	_example_container.add_child(travel_tracker)

func _create_spacer(height: int = 16) -> Control:
	"""Create vertical spacer"""
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

func _on_quest_finale_ready(quest_name: String) -> void:
	"""Handle quest finale ready signal"""
	print("Quest finale ready: %s - trigger climax battle next!" % quest_name)
