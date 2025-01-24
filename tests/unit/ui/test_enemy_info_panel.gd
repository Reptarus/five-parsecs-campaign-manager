extends "res://addons/gut/test.gd"

const EnemyInfoPanel = preload("res://src/ui/components/mission/EnemyInfoPanel.gd")

var panel: EnemyInfoPanel

func before_each() -> void:
	panel = EnemyInfoPanel.new()
	add_child(panel)

func after_each() -> void:
	panel.queue_free()

func test_initial_setup() -> void:
	assert_not_null(panel)
	assert_not_null(panel.enemy_list)
	assert_not_null(panel.threat_level)
	assert_not_null(panel.special_rules)

func test_setup_with_enemy_data() -> void:
	var enemy_data = {
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
	
	panel.setup(enemy_data)
	
	# Check threat level
	assert_true(panel.threat_level.text.contains("High"))
	
	# Check enemy list
	var enemy_items = panel.enemy_list.get_children()
	assert_eq(enemy_items.size(), 2)
	
	# Check special rules
	var rule_items = panel.special_rules.get_children()
	assert_eq(rule_items.size(), 1)
	assert_true(rule_items[0].get_child(0).text.contains("Ambush"))

func test_clear_lists() -> void:
	# Add some test items first
	var test_enemy = panel._create_enemy_item({"type": "Test Enemy", "count": 1})
	var test_rule = panel._create_rule_item({"name": "Test Rule", "description": "Test"})
	
	panel.enemy_list.add_child(test_enemy)
	panel.special_rules.add_child(test_rule)
	
	panel._clear_lists()
	
	assert_eq(panel.enemy_list.get_child_count(), 0)
	assert_eq(panel.special_rules.get_child_count(), 0)

func test_create_enemy_item() -> void:
	var enemy_data = {
		"type": "Elite Soldier",
		"count": 2
	}
	
	var item = panel._create_enemy_item(enemy_data)
	assert_not_null(item)
	
	var type_label = item.get_child(0)
	var count_label = item.get_child(1)
	
	assert_eq(type_label.text, "Elite Soldier")
	assert_eq(count_label.text, "x2")

func test_create_rule_item() -> void:
	var rule_data = {
		"name": "Reinforcements",
		"description": "Additional enemies arrive after round 3"
	}
	
	var item = panel._create_rule_item(rule_data)
	assert_not_null(item)
	
	var title = item.get_child(0)
	var description = item.get_child(1)
	
	assert_eq(title.text, "Reinforcements")
	assert_eq(description.text, "Additional enemies arrive after round 3")

func test_get_threat_text() -> void:
	assert_eq(panel._get_threat_text(0), "Low")
	assert_eq(panel._get_threat_text(1), "Medium")
	assert_eq(panel._get_threat_text(2), "High")
	assert_eq(panel._get_threat_text(3), "Extreme")
	assert_eq(panel._get_threat_text(4), "Unknown")