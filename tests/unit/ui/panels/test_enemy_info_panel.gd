@tool
extends PanelTestBase

const EnemyInfoPanel := preload("res://src/ui/components/mission/EnemyInfoPanel.gd")

# Override _create_panel_instance to provide the specific panel
func _create_panel_instance() -> Control:
	return EnemyInfoPanel.new()

func test_initial_setup() -> void:
	await test_panel_structure()
	
	# Additional panel-specific checks
	assert_not_null(_panel.enemy_list)
	assert_not_null(_panel.threat_level)
	assert_not_null(_panel.special_rules)

func test_setup_with_enemy_data() -> void:
	var enemy_data := {
		"units": [
			{
				"type": "Soldier",
				"count": 3
			},
			{
				"type": "Heavy",
				"count": 1
			}
		],
		"threat_level": 2,
		"special_rules": [
			{
				"name": "Ambush",
				"description": "Enemies get first strike"
			}
		]
	}
	
	_panel.setup(enemy_data)
	
	# Check threat level
	assert_true(_panel.threat_level.text.contains("High"))
	
	# Check enemy list
	var enemy_items: Array[Node] = _panel.enemy_list.get_children()
	assert_eq(enemy_items.size(), 2)
	
	# Check special rules
	var rule_items: Array[Node] = _panel.special_rules.get_children()
	assert_eq(rule_items.size(), 1)
	assert_true(rule_items[0].get_child(0).text.contains("Ambush"))

func test_clear_lists() -> void:
	# Add some test items first
	var test_enemy: Control = _panel._create_enemy_item({"type": "Test Enemy", "count": 1})
	var test_rule: Control = _panel._create_rule_item({"name": "Test Rule", "description": "Test"})
	
	_panel.enemy_list.add_child(test_enemy)
	_panel.special_rules.add_child(test_rule)
	
	_panel._clear_lists()
	
	assert_eq(_panel.enemy_list.get_child_count(), 0)
	assert_eq(_panel.special_rules.get_child_count(), 0)

func test_create_enemy_item() -> void:
	var enemy_data := {
		"type": "Elite Soldier",
		"count": 2
	}
	
	var item: Control = _panel._create_enemy_item(enemy_data)
	assert_not_null(item)
	
	var type_label: Label = item.get_child(0)
	var count_label: Label = item.get_child(1)
	
	assert_eq(type_label.text, "Elite Soldier")
	assert_eq(count_label.text, "x2")

func test_create_rule_item() -> void:
	var rule_data := {
		"name": "Reinforcements",
		"description": "Additional enemies arrive after round 3"
	}
	
	var item: Control = _panel._create_rule_item(rule_data)
	assert_not_null(item)
	
	var title: Label = item.get_child(0)
	var description: Label = item.get_child(1)
	
	assert_eq(title.text, "Reinforcements")
	assert_eq(description.text, "Additional enemies arrive after round 3")

func test_get_threat_text() -> void:
	assert_eq(_panel._get_threat_text(0), "Low")
	assert_eq(_panel._get_threat_text(1), "Medium")
	assert_eq(_panel._get_threat_text(2), "High")
	assert_eq(_panel._get_threat_text(3), "Extreme")
	assert_eq(_panel._get_threat_text(4), "Unknown")

# Additional tests using base class functionality
func test_panel_accessibility() -> void:
	await super.test_panel_accessibility()
	
	# Additional accessibility checks for enemy info panel
	for label in _panel.find_children("*", "Label"):
		assert_true(label.clip_text, "Labels should clip text to prevent overflow")
		assert_true(label.size.x > 0, "Labels should have minimum width")

func test_panel_theme() -> void:
	await super.test_panel_theme()
	
	# Additional theme checks for enemy info panel
	assert_true(_panel.has_theme_stylebox("panel"),
		"Panel should have panel stylebox")
	
	# Check list containers
	assert_true(_panel.enemy_list.has_theme_constant("separation"),
		"Enemy list should have separation constant")
	assert_true(_panel.special_rules.has_theme_constant("separation"),
		"Special rules list should have separation constant")

func test_panel_layout() -> void:
	await super.test_panel_layout()
	
	# Additional layout checks for enemy info panel
	assert_true(_panel.enemy_list.size.y <= _panel.size.y * 0.6,
		"Enemy list should not exceed 60% of panel height")
	assert_true(_panel.special_rules.size.y <= _panel.size.y * 0.4,
		"Special rules list should not exceed 40% of panel height")

func test_panel_performance() -> void:
	start_performance_monitoring()
	
	# Perform enemy info panel specific operations
	var test_data := {
		"units": [ {"type": "Test", "count": 1}],
		"threat_level": 1,
		"special_rules": [ {"name": "Test", "description": "Test"}]
	}
	
	for i in range(5):
		_panel.setup(test_data)
		_panel._clear_lists()
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 15,
		"draw_calls": 10,
		"theme_lookups": 25
	})