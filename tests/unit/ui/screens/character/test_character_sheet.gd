@tool
extends GameTest

const CharacterSheetScript: GDScript = preload("res://src/ui/components/character/CharacterSheet.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

var character_sheet: Node
var character_updated_signal_emitted := false
var character_deleted_signal_emitted := false
var last_character_data: Dictionary = {}

# Type-safe test lifecycle
func before_each() -> void:
	await super.before_each()
	character_sheet = Node.new()
	character_sheet.set_script(CharacterSheetScript)
	if not character_sheet.get_script() == CharacterSheetScript:
		push_error("Failed to set CharacterSheet script")
		return
	add_child_autofree(character_sheet)
	track_test_node(character_sheet)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	character_sheet = null
	await super.after_each()

# Type-safe property access
func _get_sheet_property(property: String, default_value: Variant = null) -> Variant:
	if not character_sheet:
		push_error("Trying to access property '%s' on null character sheet" % property)
		return default_value
	if not property in character_sheet:
		push_error("Character sheet missing required property: %s" % property)
		return default_value
	return character_sheet.get(property)

func _set_sheet_property(property: String, value: Variant) -> void:
	if not character_sheet:
		push_error("Trying to set property '%s' on null character sheet" % property)
		return
	if not property in character_sheet:
		push_error("Character sheet missing required property: %s" % property)
		return
	character_sheet.set(property, value)

# Type-safe signal handling
func _connect_signals() -> void:
	if not character_sheet:
		return
		
	if character_sheet.has_signal("character_updated"):
		character_sheet.connect("character_updated", _on_character_updated)
	if character_sheet.has_signal("character_deleted"):
		character_sheet.connect("character_deleted", _on_character_deleted)

func _disconnect_signals() -> void:
	if not character_sheet:
		return
		
	if character_sheet.has_signal("character_updated") and character_sheet.is_connected("character_updated", _on_character_updated):
		character_sheet.disconnect("character_updated", _on_character_updated)
	if character_sheet.has_signal("character_deleted") and character_sheet.is_connected("character_deleted", _on_character_deleted):
		character_sheet.disconnect("character_deleted", _on_character_deleted)

func _on_character_updated(character_data: Dictionary) -> void:
	character_updated_signal_emitted = true
	last_character_data = character_data

func _on_character_deleted() -> void:
	character_deleted_signal_emitted = true

func _reset_signals() -> void:
	character_updated_signal_emitted = false
	character_deleted_signal_emitted = false
	last_character_data = {}

# Type-safe test methods
func test_initial_setup() -> void:
	assert_not_null(character_sheet, "Character sheet should exist")
	
	var required_nodes := {
		"name_input": "LineEdit node for character name",
		"class_option": "OptionButton for character class",
		"stats_container": "Container for character stats",
		"equipment_container": "Container for character equipment",
		"save_button": "Button for saving character",
		"delete_button": "Button for deleting character"
	}
	
	for node_name: String in required_nodes:
		var node: Node = _get_sheet_property(node_name)
		assert_not_null(node, required_nodes[node_name] + " should exist")

func test_character_data_loading() -> void:
	var test_character := {
		"name": "Test Character",
		"class": GameEnumsScript.CharacterClass.SOLDIER,
		"stats": {
			"health": 100,
			"armor": 50,
			"speed": 30
		},
		"equipment": {
			"weapon": "Rifle",
			"armor": "Light Armor",
			"items": ["Medkit", "Ammo"]
		}
	}
	
	_call_node_method(character_sheet, "load_character", [test_character])
	
	var name_input: Node = _get_sheet_property("name_input")
	var class_option: Node = _get_sheet_property("class_option")
	
	if name_input:
		var text: String = _get_property_safe(name_input, "text", "")
		assert_eq(text, "Test Character", "Name input should match test data")
	
	if class_option:
		var selected: int = _get_property_safe(class_option, "selected", -1)
		assert_eq(selected, GameEnumsScript.CharacterClass.SOLDIER, "Class option should match test data")
	
	var health: int = _call_node_method_int(character_sheet, "get_stat", ["health"])
	var armor: int = _call_node_method_int(character_sheet, "get_stat", ["armor"])
	var speed: int = _call_node_method_int(character_sheet, "get_stat", ["speed"])
	
	assert_eq(health, 100, "Health stat should match test data")
	assert_eq(armor, 50, "Armor stat should match test data")
	assert_eq(speed, 30, "Speed stat should match test data")
	
	var equipment: Dictionary = _call_node_method_dict(character_sheet, "get_equipment", [])
	assert_eq(equipment, test_character.equipment, "Equipment should match test data")

func test_character_data_saving() -> void:
	var name_input: Node = _get_sheet_property("name_input")
	var class_option: Node = _get_sheet_property("class_option")
	
	# Set up test data
	if name_input:
		_set_property_safe(name_input, "text", "New Character")
	if class_option:
		_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.MEDIC)
	
	_call_node_method(character_sheet, "set_stat", ["health", 80])
	_call_node_method(character_sheet, "set_stat", ["armor", 30])
	_call_node_method(character_sheet, "set_stat", ["speed", 40])
	
	var equipment := {
		"weapon": "Pistol",
		"armor": "Medium Armor",
		"items": ["Bandages"]
	}
	_call_node_method(character_sheet, "set_equipment", [equipment])
	
	# Save character
	_call_node_method(character_sheet, "save_character")
	
	assert_true(character_updated_signal_emitted, "Character updated signal should be emitted")
	assert_eq(last_character_data.name, "New Character", "Saved name should match input")
	assert_eq(last_character_data. class , GameEnumsScript.CharacterClass.MEDIC, "Saved class should match selection")
	assert_eq(last_character_data.stats.health, 80, "Saved health should match input")
	assert_eq(last_character_data.stats.armor, 30, "Saved armor should match input")
	assert_eq(last_character_data.stats.speed, 40, "Saved speed should match input")
	assert_eq(last_character_data.equipment.weapon, "Pistol", "Saved weapon should match input")

func test_character_deletion() -> void:
	_call_node_method(character_sheet, "delete_character")
	assert_true(character_deleted_signal_emitted, "Character deleted signal should be emitted")

func test_validation() -> void:
	var name_input: Node = _get_sheet_property("name_input")
	var class_option: Node = _get_sheet_property("class_option")
	
	# Test empty name
	if name_input:
		_set_property_safe(name_input, "text", "")
	var is_valid: bool = _call_node_method_bool(character_sheet, "is_valid")
	assert_false(is_valid, "Should be invalid with empty name")
	
	# Test valid name
	if name_input:
		_set_property_safe(name_input, "text", "Test Character")
	is_valid = _call_node_method_bool(character_sheet, "is_valid")
	assert_true(is_valid, "Should be valid with proper name")
	
	# Test invalid class
	if class_option:
		_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.NONE)
	is_valid = _call_node_method_bool(character_sheet, "is_valid")
	assert_false(is_valid, "Should be invalid with NONE class")
	
	# Test valid class
	if class_option:
		_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.SOLDIER)
	is_valid = _call_node_method_bool(character_sheet, "is_valid")
	assert_true(is_valid, "Should be valid with proper class")

func test_stat_limits() -> void:
	# Test minimum stat values
	_call_node_method(character_sheet, "set_stat", ["health", -10])
	var health: int = _call_node_method_int(character_sheet, "get_stat", ["health"])
	assert_eq(health, 0, "Health should not go below 0")
	
	# Test maximum stat values
	var max_health: int = _get_sheet_property("MAX_HEALTH", 100)
	_call_node_method(character_sheet, "set_stat", ["health", 1000])
	health = _call_node_method_int(character_sheet, "get_stat", ["health"])
	assert_eq(health, max_health, "Health should not exceed MAX_HEALTH")
	
	# Test valid stat values
	_call_node_method(character_sheet, "set_stat", ["armor", 50])
	var armor: int = _call_node_method_int(character_sheet, "get_stat", ["armor"])
	assert_eq(armor, 50, "Armor should accept valid values")

func test_equipment_management() -> void:
	# Test adding equipment
	_call_node_method(character_sheet, "add_equipment", ["weapon", "Rifle"])
	var equipment: Dictionary = _call_node_method_dict(character_sheet, "get_equipment")
	assert_eq(equipment.weapon, "Rifle", "Should add weapon correctly")
	
	# Test removing equipment
	_call_node_method(character_sheet, "remove_equipment", ["weapon"])
	equipment = _call_node_method_dict(character_sheet, "get_equipment")
	assert_null(equipment.get("weapon"), "Should remove weapon correctly")
	
	# Test adding items
	_call_node_method(character_sheet, "add_item", ["Medkit"])
	equipment = _call_node_method_dict(character_sheet, "get_equipment")
	var items: Array = equipment.get("items", [])
	assert_true("Medkit" in items, "Should add item correctly")
	
	# Test removing items
	_call_node_method(character_sheet, "remove_item", ["Medkit"])
	equipment = _call_node_method_dict(character_sheet, "get_equipment")
	items = equipment.get("items", [])
	assert_false("Medkit" in items, "Should remove item correctly")

func test_class_specific_stats() -> void:
	var class_option: Node = _get_sheet_property("class_option")
	if not class_option:
		return
	
	# Test Soldier class stats
	_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.SOLDIER)
	_call_node_method(character_sheet, "update_class_stats")
	var combat_bonus: int = _call_node_method_int(character_sheet, "get_stat", ["combat_bonus"])
	assert_eq(combat_bonus, 2, "Soldier should have combat bonus")
	
	# Test Medic class stats
	_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.MEDIC)
	_call_node_method(character_sheet, "update_class_stats")
	var healing_bonus: int = _call_node_method_int(character_sheet, "get_stat", ["healing_bonus"])
	assert_eq(healing_bonus, 2, "Medic should have healing bonus")
	
	# Test Engineer class stats
	_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.ENGINEER)
	_call_node_method(character_sheet, "update_class_stats")
	var repair_bonus: int = _call_node_method_int(character_sheet, "get_stat", ["repair_bonus"])
	assert_eq(repair_bonus, 2, "Engineer should have repair bonus")

func test_character_reset() -> void:
	var name_input: Node = _get_sheet_property("name_input")
	var class_option: Node = _get_sheet_property("class_option")
	
	# Set up some data
	if name_input:
		_set_property_safe(name_input, "text", "Test Character")
	if class_option:
		_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.SOLDIER)
	_call_node_method(character_sheet, "set_stat", ["health", 100])
	
	# Reset character sheet
	_call_node_method(character_sheet, "reset")
	
	# Verify everything is cleared
	if name_input:
		var text: String = _get_property_safe(name_input, "text", "")
		assert_eq(text, "", "Name should be cleared")
	if class_option:
		var selected: int = _get_property_safe(class_option, "selected", -1)
		assert_eq(selected, GameEnumsScript.CharacterClass.NONE, "Class should be reset to NONE")
	
	var health: int = _call_node_method_int(character_sheet, "get_stat", ["health"])
	assert_eq(health, 0, "Stats should be reset")
	
	var equipment: Dictionary = _call_node_method_dict(character_sheet, "get_equipment")
	var items: Array = equipment.get("items", [])
	assert_eq(items.size(), 0, "Equipment should be cleared")

func test_ui_updates() -> void:
	# Test stat display updates
	_call_node_method(character_sheet, "set_stat", ["health", 75])
	var health_display: Node = _call_node_method(character_sheet, "get_stat_display", ["health"])
	if health_display:
		var text: String = _get_property_safe(health_display, "text", "")
		assert_eq(text, "75", "Health display should update")
	
	# Test equipment display updates
	_call_node_method(character_sheet, "add_equipment", ["weapon", "Rifle"])
	var weapon_display: Node = _call_node_method(character_sheet, "get_equipment_display", ["weapon"])
	if weapon_display:
		var text: String = _get_property_safe(weapon_display, "text", "")
		assert_eq(text, "Rifle", "Equipment display should update")
	
	# Test class display updates
	var class_option: Node = _get_sheet_property("class_option")
	if class_option:
		_set_property_safe(class_option, "selected", GameEnumsScript.CharacterClass.SOLDIER)
		var class_display: Node = _call_node_method(character_sheet, "get_class_display")
		if class_display:
			var text: String = _get_property_safe(class_display, "text", "")
			assert_eq(text, "Soldier", "Class display should update")