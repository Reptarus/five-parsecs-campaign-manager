@tool
extends PanelTestBase

const MissionSummaryPanel := preload("res://src/ui/components/mission/MissionSummaryPanel.gd")

# Override _create_panel_instance to provide the specific panel
func _create_panel_instance() -> Control:
	return MissionSummaryPanel.new()

func test_initial_setup() -> void:
	await test_panel_structure()
	
	# Additional panel-specific checks
	assert_not_null(_panel.title_label)
	assert_not_null(_panel.outcome_label)
	assert_not_null(_panel.stats_container)
	assert_not_null(_panel.rewards_container)
	assert_not_null(_panel.continue_button)

func test_setup_with_mission_data() -> void:
	var mission_data := {
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
	
	_panel.setup(mission_data)
	
	assert_eq(_panel.title_label.text, "Test Mission")
	assert_true(_panel.outcome_label.text.contains("Successful"))
	assert_true(_panel.outcome_label.text.contains("objectives completed"))

func test_get_outcome_text() -> void:
	var victory_outcome := {
		"victory": true,
		"victory_type": "elimination"
	}
	var defeat_outcome := {
		"victory": false,
		"failure_reason": "All crew incapacitated"
	}
	
	var victory_text: String = _panel._get_outcome_text(victory_outcome)
	var defeat_text: String = _panel._get_outcome_text(defeat_outcome)
	
	assert_true(victory_text.contains("Successful"))
	assert_true(victory_text.contains("enemies eliminated"))
	assert_true(defeat_text.contains("Failed"))
	assert_true(defeat_text.contains("crew incapacitated"))

func test_get_victory_type_text() -> void:
	assert_eq(_panel._get_victory_type_text("objective"), "All objectives completed")
	assert_eq(_panel._get_victory_type_text("elimination"), "All enemies eliminated")
	assert_eq(_panel._get_victory_type_text("survival"), "Survived the encounter")
	assert_eq(_panel._get_victory_type_text("extraction"), "Successfully extracted")
	assert_eq(_panel._get_victory_type_text("unknown"), "Mission completed")

func test_update_stats() -> void:
	var stats := {
		"turns": 5,
		"enemies_defeated": 3,
		"damage_dealt": 100,
		"damage_taken": 50,
		"items_used": 2
	}
	
	_panel._update_stats(stats)
	
	var stat_entries: Array[Node] = _panel.stats_container.get_children()
	assert_true(stat_entries.size() > 0)
	
	# Skip the label node
	for i in range(1, stat_entries.size()):
		var entry := stat_entries[i] as Control
		assert_true(entry is HBoxContainer)

func test_update_rewards() -> void:
	var rewards := {
		"credits": 1000,
		"items": [
			{"name": "Medkit"},
			{"name": "Ammo"}
		],
		"reputation": 5,
		"experience": 100
	}
	
	_panel._update_rewards(rewards)
	
	var reward_entries: Array[Node] = _panel.rewards_container.get_children()
	assert_true(reward_entries.size() > 0)
	
	# Skip the label node
	for i in range(1, reward_entries.size()):
		var entry := reward_entries[i] as Control
		assert_true(entry is HBoxContainer)

func test_continue_button() -> void:
	_panel._on_continue_pressed()
	assert_signal_emitted(_panel, "continue_pressed")

# Additional tests using base class functionality
func test_panel_accessibility() -> void:
	await super.test_panel_accessibility()
	
	# Additional accessibility checks for mission summary panel
	for label in _panel.find_children("*", "Label"):
		assert_true(label.clip_text, "Labels should clip text to prevent overflow")
		assert_true(label.size.x > 0, "Labels should have minimum width")
		
		# Check text contrast
		var background_color: Color = label.get_parent().get_theme_color("background_color")
		var text_color: Color = label.get_theme_color("font_color")
		var contrast_ratio := _calculate_contrast_ratio(text_color, background_color)
		assert_gt(contrast_ratio, 4.5, "Text contrast ratio should meet WCAG AA standards")

func test_panel_theme() -> void:
	await super.test_panel_theme()
	
	# Additional theme checks for mission summary panel
	assert_true(_panel.has_theme_stylebox("panel"),
		"Panel should have panel stylebox")
	
	# Check label themes
	var labels := [
		_panel.title_label,
		_panel.outcome_label
	]
	
	for label in labels:
		assert_true(label.has_theme_color("font_color"),
			"Label should have font color theme override")
		assert_true(label.has_theme_font("font"),
			"Label should have font theme override")

func test_panel_layout() -> void:
	await super.test_panel_layout()
	
	# Additional layout checks for mission summary panel
	assert_true(_panel.title_label.size.y <= _panel.size.y * 0.1,
		"Title should not exceed 10% of panel height")
	assert_true(_panel.outcome_label.size.y <= _panel.size.y * 0.1,
		"Outcome should not exceed 10% of panel height")
	assert_true(_panel.stats_container.size.y <= _panel.size.y * 0.4,
		"Stats should not exceed 40% of panel height")
	assert_true(_panel.rewards_container.size.y <= _panel.size.y * 0.3,
		"Rewards should not exceed 30% of panel height")

func test_panel_performance() -> void:
	start_performance_monitoring()
	
	# Perform mission summary panel specific operations
	var test_data := {
		"title": "Performance Test Mission",
		"outcome": {"victory": true, "victory_type": "objective"},
		"stats": {
			"turns": 5,
			"enemies_defeated": 3,
			"damage_dealt": 100,
			"damage_taken": 50,
			"items_used": 2
		},
		"rewards": {
			"credits": 1000,
			"items": [ {"name": "Test Item"}],
			"reputation": 5,
			"experience": 100
		}
	}
	
	for i in range(5):
		_panel.setup(test_data)
		test_data.stats.turns += 1
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 15,
		"draw_calls": 10,
		"theme_lookups": 25
	})

# Helper method for calculating contrast ratio
func _calculate_contrast_ratio(color1: Color, color2: Color) -> float:
	var l1 := _get_relative_luminance(color1)
	var l2 := _get_relative_luminance(color2)
	var lighter := maxf(l1, l2)
	var darker := minf(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)

func _get_relative_luminance(color: Color) -> float:
	var r := _gamma_correct(color.r)
	var g := _gamma_correct(color.g)
	var b := _gamma_correct(color.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

func _gamma_correct(value: float) -> float:
	return value if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)