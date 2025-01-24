## Test class for house rules panel functionality
##
## Tests the UI components and logic for managing house rules
## including rule addition, removal, and state management
@tool
extends "res://tests/fixtures/base_test.gd"

const HouseRulesPanel := preload("res://src/ui/components/combat/rules/house_rules_panel.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

var panel: HouseRulesPanel

func before_each() -> void:
	await super.before_each()
	panel = HouseRulesPanel.new()
	add_child(panel)
	track_test_node(panel)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	panel = null

# Basic UI Tests
func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.rules_container.get_child_count(), 0, "Should start with no rules")
	assert_eq(panel.get_active_rules().size(), 0, "Should start with no active rules")

# Rule Management Tests
func test_add_combat_rules() -> void:
	watch_signals(panel)
	
	var combat_rules = [
		{
			"id": "cover_bonus",
			"name": "Enhanced Cover",
			"description": "Units receive additional defense in cover",
			"enabled": true,
			"category": GameEnums.CombatModifier.COVER_HEAVY,
			"type": GameEnums.VerificationType.COMBAT
		},
		{
			"id": "flanking_bonus",
			"name": "Flanking Advantage",
			"description": "Units deal more damage when flanking",
			"enabled": true,
			"category": GameEnums.CombatModifier.FLANKING,
			"type": GameEnums.VerificationType.COMBAT
		}
	]
	
	for rule in combat_rules:
		panel.add_rule(rule)
		assert_signal_emitted(panel, "rule_added")
		var ui_rule = panel.get_rule(rule.id)
		assert_not_null(ui_rule, "Rule UI should be created")
		assert_eq(ui_rule.name, rule.name, "Rule name should match")
		assert_eq(ui_rule.enabled, rule.enabled, "Rule state should match")

func test_add_terrain_rules() -> void:
	watch_signals(panel)
	
	var terrain_rules = [
		{
			"id": "difficult_terrain",
			"name": "Difficult Terrain",
			"description": "Movement penalties in rough terrain",
			"enabled": true,
			"category": GameEnums.TerrainModifier.DIFFICULT_TERRAIN,
			"type": GameEnums.VerificationType.MOVEMENT
		},
		{
			"id": "elevation_bonus",
			"name": "High Ground",
			"description": "Bonus for elevated positions",
			"enabled": true,
			"category": GameEnums.TerrainModifier.ELEVATION_BONUS,
			"type": GameEnums.VerificationType.COMBAT
		}
	]
	
	for rule in terrain_rules:
		panel.add_rule(rule)
		assert_signal_emitted(panel, "rule_added")
		var ui_rule = panel.get_rule(rule.id)
		assert_not_null(ui_rule, "Rule UI should be created")
		assert_true(ui_rule.enabled, "Rule should be enabled by default")

func test_rule_categories() -> void:
	watch_signals(panel)
	
	var categories = {
		"combat": GameEnums.VerificationType.COMBAT,
		"movement": GameEnums.VerificationType.MOVEMENT,
		"objectives": GameEnums.VerificationType.OBJECTIVES
	}
	
	for category_name in categories:
		var rule = {
			"id": "rule_%s" % category_name,
			"name": "Test %s Rule" % category_name.capitalize(),
			"description": "A test rule for %s" % category_name,
			"enabled": true,
			"type": categories[category_name]
		}
		panel.add_rule(rule)
		assert_signal_emitted(panel, "rule_added")
		assert_eq(panel.get_rules_by_type(categories[category_name]).size(), 1, "Should track rules by category")

# Rule State Tests
func test_rule_toggle() -> void:
	watch_signals(panel)
	
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A test rule",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT
	}
	
	panel.add_rule(test_rule)
	panel.toggle_rule("test_rule", false)
	assert_false(panel.get_rule("test_rule").enabled, "Rule should be disabled")
	assert_signal_emitted(panel, "rule_toggled")
	
	panel.toggle_rule("test_rule", true)
	assert_true(panel.get_rule("test_rule").enabled, "Rule should be re-enabled")
	assert_signal_emitted(panel, "rule_toggled")

# Error Condition Tests
func test_invalid_rule_operations() -> void:
	watch_signals(panel)
	
	# Test adding invalid rule
	var invalid_rule = {
		"id": "",
		"name": "",
		"description": "",
		"enabled": true
	}
	panel.add_rule(invalid_rule)
	assert_eq(panel.rules_container.get_child_count(), 0, "Should not add invalid rule")
	assert_signal_not_emitted(panel, "rule_added")
	
	# Test removing non-existent rule
	panel.remove_rule("nonexistent_rule")
	assert_signal_not_emitted(panel, "rule_removed")
	
	# Test toggling non-existent rule
	panel.toggle_rule("nonexistent_rule", true)
	assert_signal_not_emitted(panel, "rule_toggled")

# Boundary Tests
func test_multiple_rules() -> void:
	watch_signals(panel)
	
	# Add maximum number of rules
	for i in range(50):
		var rule = {
			"id": "rule_%d" % i,
			"name": "Rule %d" % i,
			"description": "Test rule %d" % i,
			"enabled": true,
			"type": GameEnums.VerificationType.COMBAT
		}
		panel.add_rule(rule)
	
	assert_true(panel.rules_container.get_child_count() <= 50, "Should handle maximum rules")
	assert_signal_emit_count(panel, "rule_added", 50)

func test_rule_state_persistence() -> void:
	watch_signals(panel)
	
	# Add and modify rules
	var rules = []
	for i in range(5):
		var rule = {
			"id": "rule_%d" % i,
			"name": "Rule %d" % i,
			"description": "Test rule %d" % i,
			"enabled": true,
			"type": GameEnums.VerificationType.COMBAT
		}
		rules.append(rule)
		panel.add_rule(rule)
	
	# Toggle rules
	for i in range(5):
		panel.toggle_rule("rule_%d" % i, i % 2 == 0)
	
	# Verify state
	for i in range(5):
		var rule = panel.get_rule("rule_%d" % i)
		assert_eq(rule.enabled, i % 2 == 0, "Rule state should persist")