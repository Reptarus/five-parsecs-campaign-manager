extends "res://addons/gut/test.gd"

const MissionInfoPanel = preload("res://src/ui/components/mission/MissionInfoPanel.gd")

var panel: MissionInfoPanel
var mission_selected_signal_emitted := false
var last_mission_data: Dictionary

func before_each() -> void:
	panel = MissionInfoPanel.new()
	add_child(panel)
	mission_selected_signal_emitted = false
	panel.mission_selected.connect(_on_mission_selected)

func after_each() -> void:
	panel.queue_free()

func _on_mission_selected(mission_data: Dictionary) -> void:
	mission_selected_signal_emitted = true
	last_mission_data = mission_data

func test_initial_setup() -> void:
	assert_not_null(panel)
	assert_not_null(panel.title_label)
	assert_not_null(panel.description_label)
	assert_not_null(panel.difficulty_label)
	assert_not_null(panel.rewards_label)

func test_setup_with_mission_data() -> void:
	var mission_data = {
		"title": "Test Mission",
		"description": "Test mission description",
		"difficulty": 2,
		"rewards": {
			"credits": 1000,
			"items": [
				{"name": "Health Pack"},
				{"name": "Ammo Box"}
			],
			"reputation": 5
		}
	}
	
	panel.setup(mission_data)
	
	assert_eq(panel.title_label.text, "Test Mission")
	assert_eq(panel.description_label.text, "Test mission description")
	assert_true(panel.difficulty_label.text.contains("Hard"))
	assert_true(panel.rewards_label.text.contains("1000"))
	assert_true(panel.rewards_label.text.contains("Health Pack"))
	assert_true(panel.rewards_label.text.contains("5"))

func test_get_difficulty_text() -> void:
	assert_eq(panel._get_difficulty_text(0), "Easy")
	assert_eq(panel._get_difficulty_text(1), "Normal")
	assert_eq(panel._get_difficulty_text(2), "Hard")
	assert_eq(panel._get_difficulty_text(3), "Very Hard")
	assert_eq(panel._get_difficulty_text(4), "Unknown")

func test_format_rewards() -> void:
	var rewards = {
		"credits": 500,
		"items": [
			{"name": "Medkit"},
			{"name": "Grenade"}
		],
		"reputation": 3
	}
	
	var formatted = panel._format_rewards(rewards)
	assert_true(formatted.contains("500"))
	assert_true(formatted.contains("Medkit"))
	assert_true(formatted.contains("Grenade"))
	assert_true(formatted.contains("3"))

func test_accept_button_signal() -> void:
	panel.title_label.text = "Test Mission"
	panel.description_label.text = "Test Description"
	
	panel._on_accept_button_pressed()
	
	assert_true(mission_selected_signal_emitted)
	assert_eq(last_mission_data.title, "Test Mission")
	assert_eq(last_mission_data.description, "Test Description") 