@tool
extends GameTest

## Character Manager Test Suite
## Tests the functionality of the character manager system including:
## - Character creation and validation
## - Character state management
## - Character data persistence
## - Performance under various conditions

# Type-safe script references
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")
const CharacterManager: GDScript = preload("res://src/core/character/Management/CharacterManager.gd")
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")

# Type-safe constants
const MAX_CHARACTERS: int = 100
const PERFORMANCE_TEST_ITERATIONS: int = 1000

# Type-safe instance variables
var _character_manager: Node = null
var _test_character: Node = null

# Signal tracking
var _signal_data: Dictionary = {}

# Helper Methods
func _create_character_resource(name: String = "Test Character", char_class: int = GameEnums.CharacterClass.NONE) -> Node:
	var character: Node = Character.new()
	if not character:
		push_error("Failed to create character resource")
		return null
	TypeSafeMixin._call_node_method_bool(character, "set_character_name", [name])
	TypeSafeMixin._call_node_method_bool(character, "set_character_class", [char_class])
	add_child_autofree(character)
	track_test_node(character)
	return character

func _create_multiple_characters(count: int) -> Array[Node]:
	var characters: Array[Node] = []
	for i in range(count):
		var character := _create_character_resource("Character %d" % i)
		if character:
			characters.append(character)
	return characters

# Signal Handlers
func _on_character_added(character: Node) -> void:
	_signal_data["character_added"] = true
	_signal_data["last_character_added"] = character

func _on_character_updated(character: Node) -> void:
	_signal_data["character_updated"] = true
	_signal_data["last_character_updated"] = character

func _on_character_removed(character_id: String) -> void:
	_signal_data["character_removed"] = true
	_signal_data["last_character_removed_id"] = character_id

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize character manager
	var manager_instance: Node = CharacterManager.new()
	_character_manager = TypeSafeMixin._safe_cast_to_node(manager_instance)
	if not _character_manager:
		push_error("Failed to create character manager")
		return
	TypeSafeMixin._call_node_method_bool(_character_manager, "initialize", [_game_state])
	add_child_autofree(_character_manager)
	track_test_node(_character_manager)
	
	# Create test character
	_test_character = _create_character_resource()
	
	_connect_signals()
	_reset_signal_data()
	watch_signals(_character_manager)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_disconnect_signals()
	_reset_signal_data()
	_character_manager = null
	_test_character = null
	await super.after_each()

func _connect_signals() -> void:
	if not _character_manager:
		return
	
	if _character_manager.has_signal("character_added"):
		_character_manager.connect("character_added", _on_character_added)
	if _character_manager.has_signal("character_updated"):
		_character_manager.connect("character_updated", _on_character_updated)
	if _character_manager.has_signal("character_removed"):
		_character_manager.connect("character_removed", _on_character_removed)

func _disconnect_signals() -> void:
	if not _character_manager:
		return
	
	if _character_manager.has_signal("character_added") and _character_manager.is_connected("character_added", _on_character_added):
		_character_manager.disconnect("character_added", _on_character_added)
	if _character_manager.has_signal("character_updated") and _character_manager.is_connected("character_updated", _on_character_updated):
		_character_manager.disconnect("character_updated", _on_character_updated)
	if _character_manager.has_signal("character_removed") and _character_manager.is_connected("character_removed", _on_character_removed):
		_character_manager.disconnect("character_removed", _on_character_removed)

func _reset_signal_data() -> void:
	_signal_data.clear()

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(_character_manager, "Character manager should be initialized")
	
	var count: int = TypeSafeMixin._call_node_method_int(_character_manager, "get_character_count", [])
	assert_eq(count, 0, "Should start with no characters")
	
	var active_characters: Array = TypeSafeMixin._call_node_method_array(_character_manager, "get_active_characters", [])
	assert_eq(active_characters.size(), 0, "Should have no active characters")

# Character Management Tests
func test_add_character() -> void:
	var character := _create_character_resource()
	_reset_signal_data()
	
	var add_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character])
	assert_true(add_result, "Should add character successfully")
	
	var character_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(character, "get_id", []))
	var has_character: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "has_character", [character_id])
	assert_true(has_character, "Should find character by ID")
	
	assert_true(_signal_data.has("character_added"), "Character added signal should be emitted")
	assert_eq(_signal_data["last_character_added"], character, "Last added character should match")
	
	var retrieved: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(_character_manager, "get_character", [character_id]))
	assert_not_null(retrieved, "Should retrieve added character")
	
	var retrieved_name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(retrieved, "get_character_name", []))
	assert_eq(retrieved_name, "Test Character", "Character name should match")

func test_remove_character() -> void:
	var character := _create_character_resource()
	TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character])
	var character_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(character, "get_id", []))
	
	_reset_signal_data()
	var remove_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "remove_character", [character_id])
	assert_true(remove_result, "Should remove character successfully")
	
	var has_character: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "has_character", [character_id])
	assert_false(has_character, "Should not find removed character")
	
	assert_true(_signal_data.has("character_removed"), "Character removed signal should be emitted")
	assert_eq(_signal_data["last_character_removed_id"], character_id, "Last removed character ID should match")

# Performance Tests
func test_bulk_character_operations() -> void:
	var start_time := Time.get_ticks_msec()
	var characters := _create_multiple_characters(100)
	
	for character in characters:
		var add_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character])
		assert_true(add_result, "Should add character successfully")
	
	var count: int = TypeSafeMixin._call_node_method_int(_character_manager, "get_character_count", [])
	assert_eq(count, 100, "Should handle bulk additions")
	assert_true(Time.get_ticks_msec() - start_time < 1000, "Bulk operation should complete within 1 second")

# Error Boundary Tests
func test_invalid_character_operations() -> void:
	_reset_signal_data()
	
	var add_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [null])
	assert_false(add_result, "Should handle null character")
	assert_false(_signal_data.has("character_added"), "Should not emit signal for null character")
	
	var update_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "update_character", ["invalid_id", _test_character])
	assert_false(update_result, "Should handle invalid ID")
	assert_false(_signal_data.has("character_updated"), "Should not emit signal for invalid ID")
	
	var remove_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "remove_character", ["nonexistent_id"])
	assert_false(remove_result, "Should handle nonexistent ID")
	assert_false(_signal_data.has("character_removed"), "Should not emit signal for nonexistent ID")

# State Persistence Tests
func test_save_and_load_state() -> void:
	var character := _create_character_resource()
	TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character])
	
	var save_data: Dictionary = TypeSafeMixin._call_node_method_dict(_character_manager, "save_state", [])
	assert_not_null(save_data, "Should create save state")
	
	var load_result: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "load_state", [save_data])
	assert_true(load_result, "Should load state successfully")
	
	var character_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(character, "get_id", []))
	var has_character: bool = TypeSafeMixin._call_node_method_bool(_character_manager, "has_character", [character_id])
	assert_true(has_character, "Should restore character after load")
