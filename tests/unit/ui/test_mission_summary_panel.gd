extends "res://addons/gut/test.gd"

const MissionSummaryPanel = preload("res://src/ui/components/mission/MissionSummaryPanel.gd")

var panel: MissionSummaryPanel
var continue_pressed_signal_emitted := false

func before_each() -> void:
	panel = MissionSummaryPanel.new()
	add_child(panel)
	continue_pressed_signal_emitted = false
	panel.continue_pressed.connect(_on_continue_pressed)

func after_each() -> void:
	panel.queue_free()

func _on_continue_pressed() -> void:
	continue_pressed_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(panel)
	assert_not_null(panel.title_label)
	assert_not_null(panel.outcome_label)
	assert_not_null(panel.stats_container)
	assert_not_null(panel.rewards_container)
	assert_not_null(panel.continue_button)

func test_setup_with_mission_data() -> void:
	var mission_data = {
		"title": "Test Mission",
		"outcome": {
			"victory": true,
			"victory_type": "objective"
		},
		"stats": {
			"turns": 5,
			"enemies_defeated": 3,
			"damage_dealt": 100,
			"damage_taken": 50,
			"items_used": 2,
			"crew_status": [
				{"name": "John", "condition": "Healthy"},
				{"name": "Jane", "condition": "Wounded"}
			]
		},
		"rewards": {
			"credits": 1000,
			"items": [
				{"name": "Rare Weapon"},
				{"name": "Shield Generator"}
			],
			"reputation": 5,
			"experience": 100
		}
	}
	
	panel.setup(mission_data)
	
	assert_eq(panel.title_label.text, "Test Mission")
	assert_true(panel.outcome_label.text.contains("Successful"))
	assert_true(panel.outcome_label.text.contains("objectives completed"))

func test_get_outcome_text() -> void:
	var victory_outcome = {
		"victory": true,
		"victory_type": "elimination"
	}
	var defeat_outcome = {
		"victory": false,
		"failure_reason": "All crew incapacitated"
	}
	
	var victory_text = panel._get_outcome_text(victory_outcome)
	var defeat_text = panel._get_outcome_text(defeat_outcome)
	
	assert_true(victory_text.contains("Successful"))
	assert_true(victory_text.contains("enemies eliminated"))
	assert_true(defeat_text.contains("Failed"))
	assert_true(defeat_text.contains("crew incapacitated"))

func test_get_victory_type_text() -> void:
	assert_eq(panel._get_victory_type_text("objective"), "All objectives completed")
	assert_eq(panel._get_victory_type_text("elimination"), "All enemies eliminated")
	assert_eq(panel._get_victory_type_text("survival"), "Survived the encounter")
	assert_eq(panel._get_victory_type_text("extraction"), "Successfully extracted")
	assert_eq(panel._get_victory_type_text("unknown"), "Mission completed")

func test_update_stats() -> void:
	var stats = {
		"turns": 5,
		"enemies_defeated": 3,
		"damage_dealt": 100,
		"damage_taken": 50,
		"items_used": 2
	}
	
	panel._update_stats(stats)
	
	var stat_entries = panel.stats_container.get_children()
	assert_true(stat_entries.size() > 0)
	
	# Skip the label node
	for i in range(1, stat_entries.size()):
		var entry = stat_entries[i]
		assert_true(entry is HBoxContainer)

func test_update_rewards() -> void:
	var rewards = {
		"credits": 1000,
		"items": [
			{"name": "Medkit"},
			{"name": "Ammo"}
		],
		"reputation": 5,
		"experience": 100
	}
	
	panel._update_rewards(rewards)
	
	var reward_entries = panel.rewards_container.get_children()
	assert_true(reward_entries.size() > 0)
	
	# Skip the label node
	for i in range(1, reward_entries.size()):
		var entry = reward_entries[i]
		assert_true(entry is HBoxContainer)

func test_continue_button() -> void:
	panel._on_continue_pressed()
	assert_true(continue_pressed_signal_emitted)