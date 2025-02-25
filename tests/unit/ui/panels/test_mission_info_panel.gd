@tool
extends PanelTestBase

const MissionInfoPanel := preload("res://src/ui/components/mission/MissionInfoPanel.gd")

# Type-safe instance variables
var _last_mission_data: Dictionary

# Override _create_panel_instance to provide the specific panel
func _create_panel_instance() -> Control:
	return MissionInfoPanel.new()

func before_each() -> void:
	await super.before_each()
	_last_mission_data = {}

func after_each() -> void:
	_last_mission_data.clear()
	await super.after_each()

func _on_mission_selected(mission_data: Dictionary) -> void:
	_last_mission_data = mission_data.duplicate()

func test_initial_setup() -> void:
	await test_panel_structure()
	
	# Additional panel-specific checks
	assert_not_null(_panel.title_label)
	assert_not_null(_panel.description_label)
	assert_not_null(_panel.difficulty_label)
	assert_not_null(_panel.rewards_label)

func test_setup_with_mission_data() -> void:
	var mission_data := {
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
	
	_panel.setup(mission_data)
	
	assert_eq(_panel.title_label.text, "Test Mission")
	assert_eq(_panel.description_label.text, "Test mission description")
	assert_true(_panel.difficulty_label.text.contains("Hard"))
	assert_true(_panel.rewards_label.text.contains("1000"))
	assert_true(_panel.rewards_label.text.contains("Health Pack"))
	assert_true(_panel.rewards_label.text.contains("5"))

func test_get_difficulty_text() -> void:
	assert_eq(_panel._get_difficulty_text(0), "Easy")
	assert_eq(_panel._get_difficulty_text(1), "Normal")
	assert_eq(_panel._get_difficulty_text(2), "Hard")
	assert_eq(_panel._get_difficulty_text(3), "Very Hard")
	assert_eq(_panel._get_difficulty_text(4), "Unknown")

func test_format_rewards() -> void:
	var rewards := {
		"credits": 500,
		"items": [
			{"name": "Medkit"},
			{"name": "Grenade"}
		],
		"reputation": 3
	}
	
	var formatted: String = _panel._format_rewards(rewards)
	assert_true(formatted.contains("500"))
	assert_true(formatted.contains("Medkit"))
	assert_true(formatted.contains("Grenade"))
	assert_true(formatted.contains("3"))

func test_accept_button_signal() -> void:
	_panel.title_label.text = "Test Mission"
	_panel.description_label.text = "Test Description"
	
	_panel._on_accept_button_pressed()
	
	assert_signal_emitted(_panel, "mission_selected")
	assert_eq(_last_mission_data.title, "Test Mission")
	assert_eq(_last_mission_data.description, "Test Description")

# Additional tests using base class functionality
func test_panel_accessibility() -> void:
	await super.test_panel_accessibility()
	
	# Additional accessibility checks for mission info panel
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
	
	# Additional theme checks for mission info panel
	assert_true(_panel.has_theme_stylebox("panel"),
		"Panel should have panel stylebox")
	
	# Check label themes
	var labels := [
		_panel.title_label,
		_panel.description_label,
		_panel.difficulty_label,
		_panel.rewards_label
	]
	
	for label in labels:
		assert_true(label.has_theme_color("font_color"),
			"Label should have font color theme override")
		assert_true(label.has_theme_font("font"),
			"Label should have font theme override")

func test_panel_layout() -> void:
	await super.test_panel_layout()
	
	# Additional layout checks for mission info panel
	assert_true(_panel.title_label.size.y <= _panel.size.y * 0.2,
		"Title should not exceed 20% of panel height")
	assert_true(_panel.description_label.size.y <= _panel.size.y * 0.4,
		"Description should not exceed 40% of panel height")

func test_panel_performance() -> void:
	start_performance_monitoring()
	
	# Perform mission info panel specific operations
	var test_data := {
		"title": "Performance Test Mission",
		"description": "Testing performance with multiple updates",
		"difficulty": 2,
		"rewards": {
			"credits": 1000,
			"items": [ {"name": "Test Item"}],
			"reputation": 5
		}
	}
	
	for i in range(5):
		_panel.setup(test_data)
		test_data.difficulty = (test_data.difficulty + 1) % 4
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