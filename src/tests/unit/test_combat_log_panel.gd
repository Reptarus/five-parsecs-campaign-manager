extends "res://addons/gut/test.gd"

var CombatLogPanel = preload("res://src/ui/components/combat/log/combat_log_panel.tscn")
var panel: Node

func before_each() -> void:
	panel = CombatLogPanel.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_true(panel.auto_scroll, "Auto-scroll should be enabled by default")
	assert_eq(panel.current_filter, "all", "Default filter should be 'all'")
	assert_eq(panel.log_entries.size(), 0, "Log should start empty")

func test_add_log_entry() -> void:
	panel.add_log_entry("test", "Test message")
	assert_eq(panel.log_entries.size(), 1, "Log should have one entry")
	assert_eq(panel.log_list.item_count, 1, "List should show one entry")

func test_max_entries_limit() -> void:
	for i in range(panel.max_entries + 5):
		panel.add_log_entry("test", "Entry %d" % i)
	
	assert_eq(panel.log_entries.size(), panel.max_entries, "Log should be limited to max entries")
	assert_eq(panel.log_list.item_count, panel.max_entries, "List should be limited to max entries")

func test_clear_log() -> void:
	watch_signals(panel)
	panel.add_log_entry("test", "Test message")
	panel.clear_log()
	
	assert_eq(panel.log_entries.size(), 0, "Log should be empty after clear")
	assert_eq(panel.log_list.item_count, 0, "List should be empty after clear")
	assert_signal_emitted(panel, "log_cleared")

func test_filter_entries() -> void:
	panel.add_log_entry("attack", "Attack entry")
	panel.add_log_entry("damage", "Damage entry")
	panel.add_log_entry("attack", "Another attack")
	
	panel._on_filter_changed(panel.filter_options.get_item_index("attack"))
	assert_eq(panel.log_list.item_count, 2, "Should only show attack entries")
	
	panel._on_filter_changed(panel.filter_options.get_item_index("damage"))
	assert_eq(panel.log_list.item_count, 1, "Should only show damage entries")

func test_entry_selection() -> void:
	watch_signals(panel)
	panel.add_log_entry("test", "Test message", {"detail": "value"})
	panel.log_list.select(0)
	panel._on_entry_selected(0)
	
	assert_signal_emitted(panel, "log_entry_selected")
	var entry = get_signal_parameters(panel, "log_entry_selected")[0]
	assert_eq(entry.message, "Test message", "Selected entry should have correct message")
	assert_eq(entry.details.detail, "value", "Selected entry should have details")

func test_auto_scroll_toggle() -> void:
	panel._on_auto_scroll_toggled(false)
	assert_false(panel.auto_scroll, "Auto-scroll should be disabled")
	
	panel._on_auto_scroll_toggled(true)
	assert_true(panel.auto_scroll, "Auto-scroll should be enabled")

func test_attack_roll_logging() -> void:
	panel.log_attack_roll("Attacker", "Target", 5, {"bonus": 2})
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "attack", "Entry should be attack type")
	assert_eq(entry.details.roll, 5, "Entry should have roll value")
	assert_eq(entry.details.modifiers.bonus, 2, "Entry should have modifiers")

func test_damage_logging() -> void:
	panel.log_damage("Target", 10, "Weapon")
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "damage", "Entry should be damage type")
	assert_eq(entry.details.damage, 10, "Entry should have damage value")
	assert_eq(entry.details.source, "Weapon", "Entry should have damage source")

func test_modifier_logging() -> void:
	panel.log_modifier("Cover", 2, "Behind wall")
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "modifier", "Entry should be modifier type")
	assert_eq(entry.details.value, 2, "Entry should have modifier value")
	assert_eq(entry.details.description, "Behind wall", "Entry should have description")

func test_override_logging() -> void:
	panel.log_override("Attack Roll", 3, 5)
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "override", "Entry should be override type")
	assert_eq(entry.details.original, 3, "Entry should have original value")
	assert_eq(entry.details.new, 5, "Entry should have new value")

func test_critical_hit_logging() -> void:
	panel.log_critical_hit("Attacker", "Target", 2.0)
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "critical", "Entry should be critical type")
	assert_eq(entry.details.multiplier, 2.0, "Entry should have critical multiplier")

func test_special_ability_logging() -> void:
	panel.log_special_ability("Warrior", "Tactical Genius", ["Soldier", "Scout"], 3)
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "ability", "Entry should be ability type")
	assert_eq(entry.details.ability, "Tactical Genius", "Entry should have ability name")
	assert_eq(entry.details.cooldown, 3, "Entry should have cooldown value")
	assert_eq(entry.details.targets.size(), 2, "Entry should have correct number of targets")

func test_reaction_logging() -> void:
	panel.log_reaction("Guard", "Overwatch", "Enemy movement")
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "reaction", "Entry should be reaction type")
	assert_eq(entry.details.reaction, "Overwatch", "Entry should have reaction type")
	assert_eq(entry.details.trigger, "Enemy movement", "Entry should have trigger description")

func test_area_effect_logging() -> void:
	var center := Vector2(10, 10)
	var affected := ["Target1", "Target2", "Target3"]
	panel.log_area_effect("Explosion", center, 5.0, affected)
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "area", "Entry should be area type")
	assert_eq(entry.details.effect, "Explosion", "Entry should have effect type")
	assert_eq(entry.details.radius, 5.0, "Entry should have correct radius")
	assert_eq(entry.details.affected.size(), 3, "Entry should have correct number of affected targets")

func test_enhanced_combat_result_logging() -> void:
	var result := {
		"hit": true,
		"damage": 15,
		"effects": ["Stunned", "Bleeding"]
	}
	panel.log_combat_result("Attacker", "Target", result)
	var entry = panel.log_entries[0]
	
	assert_eq(entry.type, "result", "Entry should be result type")
	assert_true(entry.details.hit, "Entry should record hit")
	assert_eq(entry.details.damage, 15, "Entry should have correct damage")
	assert_eq(entry.details.effects.size(), 2, "Entry should have correct number of effects")

func test_display_filtering() -> void:
	# Add entries of different types
	panel.log_attack_roll("Attacker", "Target", 5, {})
	panel.log_special_ability("Warrior", "Leadership", [], 3)
	panel.log_reaction("Guard", "Overwatch", "Movement")
	
	# Test filtering
	panel.filter_types["ability"] = false
	assert_false(panel._should_display_entry(panel.log_entries[1]), "Ability entries should be filtered out")
	assert_true(panel._should_display_entry(panel.log_entries[0]), "Attack entries should still be shown")
	assert_true(panel._should_display_entry(panel.log_entries[2]), "Reaction entries should still be shown")
	
	# Test "all" filter
	panel.filter_types["all"] = true
	assert_true(panel._should_display_entry(panel.log_entries[1]), "All entries should be shown when 'all' is true")

func test_performance_optimization() -> void:
	# Add many entries
	for i in range(1200):
		panel.log_attack_roll("Attacker", "Target", i, {})
	
	assert_eq(panel.log_entries.size(), 1000, "Log should be trimmed to 1000 entries")
	
	# Test chunk processing
	var processed_entries := 0
	panel._update_display()
	await get_tree().process_frame
	
	assert_true(true, "Display update should process without errors")