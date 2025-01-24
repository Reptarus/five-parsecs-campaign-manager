extends "res://addons/gut/test.gd"

const CharacterSheet = preload("res://src/ui/components/character/CharacterSheet.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var character_sheet: CharacterSheet
var character_updated_signal_emitted := false
var character_deleted_signal_emitted := false
var last_character_data: Dictionary

func before_each() -> void:
	character_sheet = CharacterSheet.new()
	add_child(character_sheet)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	character_sheet.queue_free()

func _reset_signals() -> void:
	character_updated_signal_emitted = false
	character_deleted_signal_emitted = false
	last_character_data = {}

func _connect_signals() -> void:
	character_sheet.character_updated.connect(_on_character_updated)
	character_sheet.character_deleted.connect(_on_character_deleted)

func _on_character_updated(character_data: Dictionary) -> void:
	character_updated_signal_emitted = true
	last_character_data = character_data

func _on_character_deleted() -> void:
	character_deleted_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(character_sheet)
	assert_not_null(character_sheet.name_input)
	assert_not_null(character_sheet.class_option)
	assert_not_null(character_sheet.stats_container)
	assert_not_null(character_sheet.equipment_container)
	assert_not_null(character_sheet.save_button)
	assert_not_null(character_sheet.delete_button)

func test_character_data_loading() -> void:
	var test_character = {
		"name": "Test Character",
		"class": GameEnums.CharacterClass.SOLDIER,
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
	
	character_sheet.load_character(test_character)
	
	assert_eq(character_sheet.name_input.text, "Test Character")
	assert_eq(character_sheet.class_option.selected, GameEnums.CharacterClass.SOLDIER)
	assert_eq(character_sheet.get_stat("health"), 100)
	assert_eq(character_sheet.get_stat("armor"), 50)
	assert_eq(character_sheet.get_stat("speed"), 30)
	assert_eq(character_sheet.get_equipment(), test_character.equipment)

func test_character_data_saving() -> void:
	# Set up test data
	character_sheet.name_input.text = "New Character"
	character_sheet.class_option.selected = GameEnums.CharacterClass.MEDIC
	character_sheet.set_stat("health", 80)
	character_sheet.set_stat("armor", 30)
	character_sheet.set_stat("speed", 40)
	character_sheet.set_equipment({
		"weapon": "Pistol",
		"armor": "Medium Armor",
		"items": ["Bandages"]
	})
	
	# Save character
	character_sheet.save_character()
	
	assert_true(character_updated_signal_emitted)
	assert_eq(last_character_data.name, "New Character")
	assert_eq(last_character_data. class , GameEnums.CharacterClass.MEDIC)
	assert_eq(last_character_data.stats.health, 80)
	assert_eq(last_character_data.stats.armor, 30)
	assert_eq(last_character_data.stats.speed, 40)
	assert_eq(last_character_data.equipment.weapon, "Pistol")

func test_character_deletion() -> void:
	character_sheet.delete_character()
	
	assert_true(character_deleted_signal_emitted)

func test_validation() -> void:
	# Test empty name
	character_sheet.name_input.text = ""
	assert_false(character_sheet.is_valid())
	
	# Test valid name
	character_sheet.name_input.text = "Test Character"
	assert_true(character_sheet.is_valid())
	
	# Test invalid class
	character_sheet.class_option.selected = GameEnums.CharacterClass.NONE
	assert_false(character_sheet.is_valid())
	
	# Test valid class
	character_sheet.class_option.selected = GameEnums.CharacterClass.SOLDIER
	assert_true(character_sheet.is_valid())

func test_stat_limits() -> void:
	# Test minimum stat values
	character_sheet.set_stat("health", -10)
	assert_eq(character_sheet.get_stat("health"), 0)
	
	# Test maximum stat values
	character_sheet.set_stat("health", 1000)
	assert_eq(character_sheet.get_stat("health"), character_sheet.MAX_HEALTH)
	
	# Test valid stat values
	character_sheet.set_stat("armor", 50)
	assert_eq(character_sheet.get_stat("armor"), 50)

func test_equipment_management() -> void:
	# Test adding equipment
	character_sheet.add_equipment("weapon", "Rifle")
	assert_eq(character_sheet.get_equipment().weapon, "Rifle")
	
	# Test removing equipment
	character_sheet.remove_equipment("weapon")
	assert_null(character_sheet.get_equipment().weapon)
	
	# Test adding items
	character_sheet.add_item("Medkit")
	assert_true("Medkit" in character_sheet.get_equipment().items)
	
	# Test removing items
	character_sheet.remove_item("Medkit")
	assert_false("Medkit" in character_sheet.get_equipment().items)

func test_class_specific_stats() -> void:
	# Test Soldier class stats
	character_sheet.class_option.selected = GameEnums.CharacterClass.SOLDIER
	character_sheet.update_class_stats()
	assert_eq(character_sheet.get_stat("combat_bonus"), 2)
	
	# Test Medic class stats
	character_sheet.class_option.selected = GameEnums.CharacterClass.MEDIC
	character_sheet.update_class_stats()
	assert_eq(character_sheet.get_stat("healing_bonus"), 2)
	
	# Test Engineer class stats
	character_sheet.class_option.selected = GameEnums.CharacterClass.ENGINEER
	character_sheet.update_class_stats()
	assert_eq(character_sheet.get_stat("repair_bonus"), 2)

func test_character_reset() -> void:
	# Set up some data
	character_sheet.name_input.text = "Test Character"
	character_sheet.class_option.selected = GameEnums.CharacterClass.SOLDIER
	character_sheet.set_stat("health", 100)
	
	# Reset character sheet
	character_sheet.reset()
	
	# Verify everything is cleared
	assert_eq(character_sheet.name_input.text, "")
	assert_eq(character_sheet.class_option.selected, GameEnums.CharacterClass.NONE)
	assert_eq(character_sheet.get_stat("health"), 0)
	assert_eq(character_sheet.get_equipment().items.size(), 0)

func test_ui_updates() -> void:
	# Test stat display updates
	character_sheet.set_stat("health", 75)
	assert_eq(character_sheet.get_stat_display("health").text, "75")
	
	# Test equipment display updates
	character_sheet.add_equipment("weapon", "Rifle")
	assert_eq(character_sheet.get_equipment_display("weapon").text, "Rifle")
	
	# Test class display updates
	character_sheet.class_option.selected = GameEnums.CharacterClass.SOLDIER
	assert_eq(character_sheet.get_class_display().text, "Soldier")