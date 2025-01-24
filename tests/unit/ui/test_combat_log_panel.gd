@tool
extends "res://addons/gut/test.gd"

const CombatLogPanel = preload("res://src/ui/components/combat/log/combat_log_panel.gd")

var panel: CombatLogPanel
var log_list: ItemList
var clear_button: Button
var filter_options: OptionButton
var auto_scroll_check: CheckBox

func before_each() -> void:
	panel = CombatLogPanel.new()
	
	# Create required nodes
	log_list = ItemList.new()
	log_list.name = "LogList"
	log_list.set_meta("_edit_group_", true) # To make it unique for %
	
	clear_button = Button.new()
	clear_button.name = "ClearButton"
	clear_button.set_meta("_edit_group_", true)
	
	filter_options = OptionButton.new()
	filter_options.name = "FilterOptions"
	filter_options.set_meta("_edit_group_", true)
	
	auto_scroll_check = CheckBox.new()
	auto_scroll_check.name = "AutoScrollCheck"
	auto_scroll_check.set_meta("_edit_group_", true)
	
	# Set up hierarchy
	add_child(panel)
	panel.add_child(log_list)
	panel.add_child(clear_button)
	panel.add_child(filter_options)
	panel.add_child(auto_scroll_check)
	
	# Force ready call after setup
	panel._ready()

func after_each() -> void:
	panel.queue_free()

func test_initial_setup() -> void:
	assert_not_null(panel.log_list)
	assert_not_null(panel.clear_button)
	assert_not_null(panel.filter_options)
	assert_not_null(panel.auto_scroll_check)
	
	assert_eq(panel.max_entries, 100)
	assert_true(panel.auto_scroll)
	assert_eq(panel.current_filter, "all")
	assert_eq(panel.log_entries.size(), 0)

func test_filter_options_setup() -> void:
	for key in panel.FILTER_OPTIONS:
		var found := false
		for i in range(filter_options.item_count):
			if filter_options.get_item_metadata(i) == key:
				found = true
				break
		assert_true(found, "Filter option '%s' should be in dropdown" % key)

func test_add_log_entry() -> void:
	panel.add_log_entry("combat", "Test combat message")
	
	assert_eq(panel.log_entries.size(), 1)
	assert_eq(panel.log_entries[0].type, "combat")
	assert_eq(panel.log_entries[0].message, "Test combat message")
	assert_eq(log_list.item_count, 1)

func test_max_entries_limit() -> void:
	# Add more than max_entries
	for i in range(panel.max_entries + 10):
		panel.add_log_entry("test", "Entry %d" % i)
	
	assert_eq(panel.log_entries.size(), panel.max_entries)
	assert_eq(log_list.item_count, panel.max_entries)

func test_clear_log() -> void:
	# Add some entries
	panel.add_log_entry("test", "Entry 1")
	panel.add_log_entry("test", "Entry 2")
	
	# Clear the log
	panel.clear_log()
	
	assert_eq(panel.log_entries.size(), 0)
	assert_eq(log_list.item_count, 0)

func test_filter_handling() -> void:
	# Add entries of different types
	panel.add_log_entry("combat", "Combat entry")
	panel.add_log_entry("damage", "Damage entry")
	
	# Change filter to combat only
	panel.current_filter = "combat"
	panel._refresh_log_display()
	
	var visible_entries := 0
	for i in range(log_list.item_count):
		var entry = log_list.get_item_metadata(i)
		if entry.type == "combat":
			visible_entries += 1
	
	assert_eq(visible_entries, 1)

func test_combat_result_logging() -> void:
	var result = {
		"hit": true,
		"damage": 15,
		"effects": ["stunned", "bleeding"]
	}
	panel.log_combat_result("Warrior", "Dragon", result)
	
	assert_eq(panel.log_entries.size(), 1)
	var entry = panel.log_entries[0]
	assert_eq(entry.type, "result")
	assert_true(entry.message.contains("Hit!"))
	assert_true(entry.message.contains("15 damage"))
	assert_true(entry.message.contains("stunned"))
	assert_true(entry.message.contains("bleeding"))

func test_special_ability_logging() -> void:
	panel.log_special_ability("Mage", "Fireball", ["Goblin", "Orc"], 3)
	
	assert_eq(panel.log_entries.size(), 1)
	var entry = panel.log_entries[0]
	assert_eq(entry.type, "ability")
	assert_true(entry.message.contains("Mage"))
	assert_true(entry.message.contains("Fireball"))
	assert_true(entry.message.contains("Goblin"))
	assert_true(entry.message.contains("Orc"))
	assert_true(entry.message.contains("Cooldown: 3"))

func test_reaction_logging() -> void:
	panel.log_reaction("Fighter", "Parry", "incoming_attack")
	
	assert_eq(panel.log_entries.size(), 1)
	var entry = panel.log_entries[0]
	assert_eq(entry.type, "reaction")
	assert_true(entry.message.contains("Fighter"))
	assert_true(entry.message.contains("Parry"))
	assert_true(entry.message.contains("incoming_attack"))

func test_area_effect_logging() -> void:
	panel.log_area_effect("Explosion", Vector2(100, 100), 5.0, ["Target1", "Target2"])
	
	assert_eq(panel.log_entries.size(), 1)
	var entry = panel.log_entries[0]
	assert_eq(entry.type, "area")
	assert_true(entry.message.contains("Explosion"))
	assert_true(entry.message.contains("2 targets"))
	assert_true(entry.message.contains("5.0 radius"))