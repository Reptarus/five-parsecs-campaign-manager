extends GutTest
class_name GameTest

# Script constants with descriptive names to avoid shadowing
const EnemyScript: GDScript = preload("res://src/core/enemy/base/Enemy.gd")
const CharacterScript: GDScript = preload("res://src/core/character/Base/Character.gd")
const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const FiveParcsecsCampaignScript: GDScript = preload("res://src/core/campaign/Campaign.gd")
const TestHelperScript: GDScript = preload("res://tests/fixtures/test_helper.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test configuration constants
const STABILIZATION_TIME := 0.1
const SIGNAL_TIMEOUT := 1.0

# Campaign test configuration
const DEFAULT_CAMPAIGN_CONFIG := {
	"difficulty_level": 1, # Normal difficulty
	"enable_permadeath": true,
	"use_story_track": true,
	"auto_save_enabled": true
}

# Game state references
var _game_state: Node = null
var _campaign_system: Node = null
var _signal_watcher: SignalWatcher = null

# Test tracking
var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []

# Type-safe node operations
func add_child_autofree(node: Node) -> Node:
	if not node:
		push_warning("Attempting to add null node")
		return null
		
	if node.get_parent():
		node.get_parent().remove_child(node)
	
	super.add_child(node)
	track_test_node(node)
	return node

func track_test_node(node: Node) -> void:
	if not node in _tracked_nodes:
		_tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if not resource in _tracked_resources:
		_tracked_resources.append(resource)

# Type-safe cleanup methods
func cleanup_tracked_nodes() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_tracked_nodes.clear()

func cleanup_tracked_resources() -> void:
	_tracked_resources.clear()

# Type-safe property access
func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not obj:
		push_warning("Attempting to get property from null object")
		return default_value
	if not property in obj:
		return default_value
	return obj.get(property)

func _set_property_safe(obj: Object, property: String, value: Variant) -> void:
	if not obj:
		push_warning("Attempting to set property on null object")
		return
	if not property in obj:
		push_warning("Property %s not found in object" % property)
		return
	obj.set(property, value)

# Type-safe signal handling
class SignalWatcher:
	var _watched_signals: Dictionary = {}
	var _signal_emissions: Dictionary = {}
	var _parent: Node
	
	func _init(parent: Node) -> void:
		_parent = parent
	
	func watch_signals(emitter: Object) -> void:
		if not emitter:
			push_warning("Attempting to watch signals on null emitter")
			return
			
		if not _watched_signals.has(emitter):
			_watched_signals[emitter] = []
			_signal_emissions[emitter] = {}
			
			var signal_list: Array = emitter.get_signal_list()
			for signal_info in signal_list:
				if not signal_info is Dictionary:
					continue
					
				var signal_name: String = signal_info.get("name", "")
				if signal_name.is_empty():
					continue
				
				if _watched_signals[emitter] is Array:
					var signals: Array = _watched_signals[emitter]
					if not signals.has(signal_name):
						signals.append(signal_name)
				_signal_emissions[emitter][signal_name] = []
				
				if emitter.has_signal(signal_name):
					# Using explicit typing for the callback
					var callback: Callable = func(arg1: Variant = null, arg2: Variant = null,
							arg3: Variant = null, arg4: Variant = null,
							arg5: Variant = null) -> void:
						var args: Array = []
						var arg_list: Array = [arg1, arg2, arg3, arg4, arg5]
						for arg in arg_list:
							if arg != null:
								args.append(arg)
						_on_signal_emitted.call_deferred(emitter, signal_name, args)
					
					# Connect returns void in Godot 4
					if not emitter.is_connected(signal_name, callback):
						emitter.connect(signal_name, callback, CONNECT_DEFERRED)
	
	func _on_signal_emitted(emitter: Object, signal_name: String, args: Array) -> void:
		if _signal_emissions.has(emitter) and \
		   _signal_emissions[emitter] is Dictionary and \
		   _signal_emissions[emitter].has(signal_name) and \
		   _signal_emissions[emitter][signal_name] is Array:
			var emissions: Array = _signal_emissions[emitter][signal_name]
			emissions.append(args)
	
	func check_signal_emission(object: Object, signal_name: String) -> bool:
		if not object or not signal_name:
			return false
			
		if not _signal_emissions.has(object):
			return false
		if not _signal_emissions[object].has(signal_name):
			return false
			
		var emissions: Array = _signal_emissions[object][signal_name]
		if not emissions is Array:
			return false
		return not emissions.is_empty()

# Signal verification methods
func watch_signals(emitter: Object) -> void:
	if not emitter:
		push_warning("Attempting to watch signals on null emitter")
		return
		
	if not _signal_watcher:
		_signal_watcher = SignalWatcher.new(self)
	_signal_watcher.watch_signals(emitter)

func verify_signal_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
		
	if not emitter or not signal_name:
		assert_true(false, "Invalid emitter or signal name")
		return
		
	var was_emitted: bool = _signal_watcher.check_signal_emission(emitter, signal_name)
	assert_true(was_emitted, message if message else "Signal '%s' was not emitted" % signal_name)

func verify_signal_not_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
		
	if not emitter or not signal_name:
		assert_true(false, "Invalid emitter or signal name")
		return
		
	var was_emitted: bool = _signal_watcher.check_signal_emission(emitter, signal_name)
	assert_false(was_emitted, message if message else "Signal '%s' should not have been emitted" % signal_name)

# Type-safe state property access
func _get_state_property(state: Node, property: String, default_value: Variant = null) -> Variant:
	if not state:
		push_warning("Trying to access property '%s' on null game state" % property)
		return default_value
	if not property in state:
		push_warning("Game state missing required property: %s" % property)
		return default_value
	return state.get(property)

func _set_state_property(state: Node, property: String, value: Variant) -> void:
	if not state:
		push_warning("Trying to set property '%s' on null game state" % property)
		return
	if not property in state:
		push_warning("Game state missing required property: %s" % property)
		return
	state.set(property, value)

# Type-safe method calls for Resources
func _call_resource_method(resource: Resource, method: String, args: Array = []) -> Variant:
	if not resource:
		push_warning("Attempting to call method '%s' on null resource" % method)
		return null
	if not resource.has_method(method):
		push_warning("Resource missing required method: %s" % method)
		return null
	return resource.callv(method, args)

func _call_resource_method_dict(resource: Resource, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
	var result: Variant = _call_resource_method(resource, method, args)
	if not result is Dictionary:
		push_warning("Method '%s' did not return a Dictionary" % method)
		return default_value
	return result

func _call_resource_method_array(resource: Resource, method: String, args: Array = [], default_value: Array = []) -> Array:
	var result: Variant = _call_resource_method(resource, method, args)
	if not result is Array:
		push_warning("Method '%s' did not return an Array" % method)
		return default_value
	return result

func _call_resource_method_bool(resource: Resource, method: String, args: Array = [], default_value: bool = false) -> bool:
	var result: Variant = _call_resource_method(resource, method, args)
	if not result is bool:
		push_warning("Method '%s' did not return a bool" % method)
		return default_value
	return result

func _call_resource_method_int(resource: Resource, method: String, args: Array = [], default_value: int = 0) -> int:
	var result: Variant = _call_resource_method(resource, method, args)
	if not result is int:
		push_warning("Method '%s' did not return an int" % method)
		return default_value
	return result

# Type-safe method calls for Nodes
func _call_node_method(node: Node, method: String, args: Array = []) -> Variant:
	if not node:
		push_warning("Attempting to call method '%s' on null node" % method)
		return null
	if not node.has_method(method):
		push_warning("Node missing required method: %s" % method)
		return null
	return node.callv(method, args)

func _call_node_method_dict(node: Node, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
	var result: Variant = _call_node_method(node, method, args)
	if not result is Dictionary:
		push_warning("Method '%s' did not return a Dictionary" % method)
		return default_value
	return result

func _call_node_method_array(node: Node, method: String, args: Array = [], default_value: Array = []) -> Array:
	var result: Variant = _call_node_method(node, method, args)
	if not result is Array:
		push_warning("Method '%s' did not return an Array" % method)
		return default_value
	return result

func _call_node_method_bool(node: Node, method: String, args: Array = [], default_value: bool = false) -> bool:
	var result: Variant = _call_node_method(node, method, args)
	if not result is bool:
		push_warning("Method '%s' did not return a bool" % method)
		return default_value
	return result

func _call_node_method_int(node: Node, method: String, args: Array = [], default_value: int = 0) -> int:
	var result: Variant = _call_node_method(node, method, args)
	if not result is int:
		push_warning("Method '%s' did not return an int" % method)
		return default_value
	return result

# Dictionary helper methods
func _get_dict_bool(dict: Dictionary, key: String, default_value: bool = false) -> bool:
	if not dict.has(key):
		return default_value
	var value: Variant = dict.get(key)
	if not value is bool:
		return default_value
	return value

# Type-safe test setup methods
func create_test_game_state() -> Node:
	var state_instance: Node = Node.new()
	if not state_instance:
		push_warning("Failed to create game state instance")
		return null
		
	state_instance.set_script(GameStateScript)
	if not state_instance.get_script() == GameStateScript:
		push_warning("Failed to set GameState script")
		return null
		
	add_child_autofree(state_instance)
	track_test_node(state_instance)
	return state_instance

func create_test_enemy() -> Node:
	var enemy_instance: Node = Node.new()
	if not enemy_instance:
		push_warning("Failed to create enemy instance")
		return null
		
	enemy_instance.set_script(EnemyScript)
	if not enemy_instance.get_script() == EnemyScript:
		push_warning("Failed to set Enemy script")
		return null
		
	add_child_autofree(enemy_instance)
	track_test_node(enemy_instance)
	return enemy_instance

func create_test_character() -> Node:
	var character_instance: Node = Node.new()
	if not character_instance:
		push_warning("Failed to create character instance")
		return null
		
	character_instance.set_script(CharacterScript)
	if not character_instance.get_script() == CharacterScript:
		push_warning("Failed to set Character script")
		return null
		
	add_child_autofree(character_instance)
	track_test_node(character_instance)
	return character_instance

func setup_campaign_system() -> Node:
	var system_instance: Node = Node.new()
	if not system_instance:
		push_warning("Failed to create campaign system instance")
		return null
		
	system_instance.name = "CampaignSystem"
	add_child_autofree(system_instance)
	track_test_node(system_instance)
	return system_instance

func create_test_campaign() -> Resource:
	var campaign_instance: Resource = FiveParcsecsCampaignScript.new()
	if not campaign_instance:
		push_warning("Failed to create campaign instance")
		return null
		
	track_test_resource(campaign_instance)
	return campaign_instance

# Type-safe state verification
func assert_valid_game_state(game_state: Node) -> void:
	assert_not_null_variant(game_state, "Game state should exist")
	
	var campaign: Resource = _get_state_property(game_state, "current_campaign")
	assert_not_null_variant(campaign, "Campaign state should be initialized")
	
	var difficulty: int = _get_state_property(game_state, "difficulty_level", -1)
	assert_eq_variant(difficulty, 1, "Difficulty should be set to normal")
	
	var permadeath: bool = _get_state_property(game_state, "enable_permadeath", false)
	assert_true_variant(permadeath, "Permadeath should be enabled")
	
	var story_track: bool = _get_state_property(game_state, "use_story_track", false)
	assert_true_variant(story_track, "Story track should be enabled")
	
	var auto_save: bool = _get_state_property(game_state, "auto_save_enabled", false)
	assert_true_variant(auto_save, "Auto save should be enabled")

# Type-safe utility methods
func stabilize_engine(time: float = STABILIZATION_TIME) -> void:
	await get_tree().create_timer(time).timeout

func assert_async_signal(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> bool:
	if not emitter or not signal_name:
		push_warning("Invalid emitter or signal name for async signal check")
		return false
		
	var timer := get_tree().create_timer(timeout)
	var signal_received := false
	
	var callable := func() -> void: signal_received = true
	if not emitter.is_connected(signal_name, callable):
		emitter.connect(signal_name, callable, CONNECT_ONE_SHOT)
	
	timer.timeout.connect(func() -> void: signal_received = false, CONNECT_ONE_SHOT)
	while not signal_received and not timer.is_stopped():
		await get_tree().process_frame
	
	return signal_received

# Type-safe assertion methods
func assert_eq_variant(got: Variant, expected: Variant, text: String = "") -> void:
	# Ensure both values are of the same type before comparison
	var got_type := typeof(got)
	var expected_type := typeof(expected)
	
	if got_type != expected_type:
		assert_false(true, "Type mismatch in assert_eq: got %s (%d), expected %s (%d). %s" % [
			got, got_type, expected, expected_type, text
		])
		return
	
	# Now we can safely compare
	assert_eq(got, expected, text)

func assert_true_variant(got: Variant, text: String = "") -> void:
	# Convert to boolean explicitly
	var bool_value: bool = false
	
	match typeof(got):
		TYPE_BOOL:
			bool_value = bool(got)
		TYPE_INT:
			bool_value = int(got) != 0
		TYPE_FLOAT:
			bool_value = float(got) != 0.0
		TYPE_STRING:
			bool_value = String(got).length() > 0
		TYPE_OBJECT:
			bool_value = got != null
		_:
			bool_value = got != null
	
	assert_true(bool_value, text)

func assert_false_variant(got: Variant, text: String = "") -> void:
	assert_true_variant(not got, text)

func assert_not_null_variant(got: Variant, text: String = "") -> void:
	assert_true_variant(got != null, text)

# Override base assertion methods to use type-safe variants
func assert_eq(got: Variant, expected: Variant, text: String = "") -> void:
	assert_eq_variant(got, expected, text)

func assert_true(condition: Variant, text: String = "") -> void:
	assert_true_variant(condition, text)

func assert_false(condition: Variant, text: String = "") -> void:
	assert_false_variant(condition, text)

func assert_not_null(got: Variant, text: String = "") -> void:
	assert_not_null_variant(got, text)

# Type-safe error handling
func _safe_cast_error(value: Variant, error_message: String = "") -> Error:
	if not value is int:
		push_warning("Cannot cast to Error: %s" % error_message)
		return ERR_INVALID_DATA
	return value # Error is an enum, which is an int, so this is safe

func _handle_error(error: Error, context: String) -> void:
	if error != OK:
		push_warning("%s failed with error: %s" % [context, error_string(error)])

# Type-safe casting functions
func _safe_cast_object(value: Variant, error_message: String = "") -> Object:
	if not value is Object:
		push_error("Cannot cast to Object: %s" % error_message)
		return null
	return value

func _safe_cast_node(value: Variant, error_message: String = "") -> Node:
	if not value is Node:
		push_error("Cannot cast to Node: %s" % error_message)
		return null
	return value

func _safe_cast_resource(value: Variant, error_message: String = "") -> Resource:
	if not value is Resource:
		push_error("Cannot cast to Resource: %s" % error_message)
		return null
	return value

func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	if not value is Array:
		push_error("Cannot cast to Array: %s" % error_message)
		return []
	return value

func _safe_cast_dictionary(value: Variant, error_message: String = "") -> Dictionary:
	if not value is Dictionary:
		push_error("Cannot cast to Dictionary: %s" % error_message)
		return {}
	return value

func _safe_cast_bool(value: Variant, error_message: String = "") -> bool:
	if not value is bool:
		push_error("Cannot cast to bool: %s" % error_message)
		return false
	return value

func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if not value is int:
		push_error("Cannot cast to int: %s" % error_message)
		return 0
	return value

func _safe_cast_float(value: Variant, error_message: String = "") -> float:
	if not value is float:
		push_error("Cannot cast to float: %s" % error_message)
		return 0.0
	return value

func _safe_cast_string(value: Variant, error_message: String = "") -> String:
	if not value is String:
		push_error("Cannot cast to String: %s" % error_message)
		return ""
	return value

# Type-safe node access
func _get_node_safe(node: Node, path: String) -> Node:
	if not node:
		push_error("Attempting to get node from null parent")
		return null
	if not path:
		push_error("Invalid node path")
		return null
		
	var child := node.get_node(path)
	if not child:
		push_error("Node not found at path: %s" % path)
		return null
	return child

# Type-safe helper methods
func _safe_cast_to_resource(value: Variant, type: String, error_message: String = "") -> Resource:
	return TypeSafeMixin._safe_cast_to_resource(value, type, error_message)

func _safe_cast_to_node(value: Variant, type: String, error_message: String = "") -> Node:
	return TypeSafeMixin._safe_cast_to_node(value, type, error_message)

func _safe_cast_to_object(value: Variant, type: String, error_message: String = "") -> Object:
	return TypeSafeMixin._safe_cast_to_object(value, type, error_message)

func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
	return TypeSafeMixin._safe_cast_to_string(value, error_message)

func _safe_method_call_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	return TypeSafeMixin._safe_method_call_bool(obj, method, args, default)

func _safe_method_call_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	return TypeSafeMixin._safe_method_call_int(obj, method, args, default)

func _safe_method_call_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	return TypeSafeMixin._safe_method_call_array(obj, method, args, default)

func _safe_method_call_string(obj: Object, method: String, args: Array = [], default: String = "") -> String:
	return TypeSafeMixin._safe_method_call_string(obj, method, args, default)

func _safe_method_call_resource(obj: Object, method: String, args: Array = [], default: Resource = null) -> Resource:
	return TypeSafeMixin._safe_method_call_resource(obj, method, args, default)

func _safe_method_call_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	return TypeSafeMixin._safe_method_call_dict(obj, method, args, default)

func _safe_method_call_float(obj: Object, method: String, args: Array = [], default: float = 0.0) -> float:
	return TypeSafeMixin._safe_method_call_float(obj, method, args, default)

# Test lifecycle methods
func before_all() -> void:
	pass

func after_all() -> void:
	pass

func before_each() -> void:
	await super.before_each()
	_tracked_nodes.clear()
	_tracked_resources.clear()

func after_each() -> void:
	cleanup_tracked_nodes()
	cleanup_tracked_resources()
	await super.after_each()

# Test utilities
