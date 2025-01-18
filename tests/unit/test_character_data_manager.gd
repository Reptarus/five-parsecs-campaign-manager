@tool
extends "../fixtures/base_test.gd"

const CharacterDataManager := preload("res://src/core/character/Management/CharacterDataManager.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")

var manager: CharacterDataManager
var game_state_manager: GameStateManager

func before_each() -> void:
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	
	manager = CharacterDataManager.new(game_state_manager)
	add_child(manager)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_eq(manager.character_data.size(), 0, "Should start with no character data")
	assert_eq(manager.active_character_id, "", "Should start with no active character")

func test_save_character_data() -> void:
	var character := Character.new()
	character.character_name = "Test Character"
	character.is_human = true
	character.experience = 100
	character.level = 2
	
	watch_signals(manager)
	var character_id = manager.save_character_data(character)
	
	assert_not_null(character_id, "Should generate character ID")
	assert_true(manager.character_data.has(character_id), "Should store character data")
	assert_signal_emitted(manager, "character_data_saved")

func test_load_character_data() -> void:
	var character := Character.new()
	character.character_name = "Test Character"
	character.is_human = true
	character.experience = 100
	character.level = 2
	
	var character_id = manager.save_character_data(character)
	watch_signals(manager)
	
	var loaded_data = manager.load_character_data(character_id)
	
	assert_not_null(loaded_data, "Should load character data")
	assert_eq(loaded_data.character_name, "Test Character", "Should preserve character name")
	assert_eq(loaded_data.experience, 100, "Should preserve experience")
	assert_eq(loaded_data.level, 2, "Should preserve level")
	assert_signal_emitted(manager, "character_data_loaded")

func test_delete_character_data() -> void:
	var character := Character.new()
	character.character_name = "Test Character"
	var character_id = manager.save_character_data(character)
	
	watch_signals(manager)
	manager.delete_character_data(character_id)
	
	assert_false(manager.character_data.has(character_id), "Should remove character data")
	assert_signal_emitted(manager, "character_data_deleted")

func test_set_active_character() -> void:
	var character := Character.new()
	character.character_name = "Test Character"
	var character_id = manager.save_character_data(character)
	
	watch_signals(manager)
	manager.set_active_character(character_id)
	
	assert_eq(manager.active_character_id, character_id, "Should set active character ID")
	assert_signal_emitted(manager, "active_character_changed")

func test_update_character_data() -> void:
	var character := Character.new()
	character.character_name = "Test Character"
	var character_id = manager.save_character_data(character)
	
	character.experience = 100
	watch_signals(manager)
	manager.update_character_data(character_id, character)
	
	var updated_data = manager.load_character_data(character_id)
	assert_eq(updated_data.experience, 100, "Should update character data")
	assert_signal_emitted(manager, "character_data_updated")

func test_get_all_characters() -> void:
	var character1 := Character.new()
	character1.character_name = "Character 1"
	var character2 := Character.new()
	character2.character_name = "Character 2"
	
	manager.save_character_data(character1)
	manager.save_character_data(character2)
	
	var all_characters = manager.get_all_characters()
	assert_eq(all_characters.size(), 2, "Should return all characters")

func test_filter_characters() -> void:
	var human := Character.new()
	human.character_name = "Human"
	human.is_human = true
	
	var bot := Character.new()
	bot.character_name = "Bot"
	bot.is_bot = true
	
	manager.save_character_data(human)
	manager.save_character_data(bot)
	
	var humans = manager.filter_characters(func(data): return data.is_human)
	assert_eq(humans.size(), 1, "Should filter human characters")
	assert_eq(humans[0].character_name, "Human", "Should return correct character")

func test_sort_characters() -> void:
	var character1 := Character.new()
	character1.character_name = "Character A"
	character1.level = 1
	
	var character2 := Character.new()
	character2.character_name = "Character B"
	character2.level = 2
	
	manager.save_character_data(character2)
	manager.save_character_data(character1)
	
	var sorted = manager.sort_characters(func(a, b): return a.level < b.level)
	assert_eq(sorted[0].character_name, "Character A", "Should sort characters by level")
	assert_eq(sorted[1].character_name, "Character B", "Should maintain sort order")

func test_backup_restore() -> void:
	var character := Character.new()
	character.character_name = "Test Character"
	var character_id = manager.save_character_data(character)
	
	watch_signals(manager)
	var backup = manager.create_backup()
	manager.delete_character_data(character_id)
	manager.restore_from_backup(backup)
	
	assert_true(manager.character_data.has(character_id), "Should restore character data from backup")
	assert_signal_emitted(manager, "backup_restored")