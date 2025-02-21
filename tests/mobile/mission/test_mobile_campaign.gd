@tool
extends "res://tests/fixtures/mobile_test_base.gd"

const FiveParcsecsCampaignSystemScript := preload("res://src/core/campaign/CampaignSystem.gd")
const GameEnumsScript := preload("res://src/core/systems/GlobalEnums.gd")

# Test variables
var campaign_system: Node = null
var campaign: Resource = null
var game_state: Node = null

# Performance thresholds
const MIN_FPS := 30.0
const MIN_MEMORY_MB := 2.0

# Helper functions for type-safe operations
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

func _safe_cast_dictionary(value: Variant, error_message: String = "") -> Dictionary:
	if not value is Dictionary:
		push_error("Cannot cast to Dictionary: %s" % error_message)
		return {}
	return value

func _safe_cast_float(value: Variant, error_message: String = "") -> float:
	if not value is float:
		push_error("Cannot cast to float: %s" % error_message)
		return 0.0
	return value

# Add this helper function with the other safe casting functions
func _safe_cast_error(value: Variant, error_message: String = "") -> Error:
	if not value is int:
		push_error("Cannot cast to Error: %s" % error_message)
		return ERR_INVALID_DATA
	# Error is just an enum (integer) type, so we can return the int value directly
	return value

# Helper function to safely call methods
func _call_method_safe(obj: Variant, method: String, args: Array = [], expected_type: int = TYPE_NIL, default_value: Variant = null) -> Variant:
	var object: Object = _safe_cast_object(obj, "Cannot call method on non-Object")
	if not object:
		return default_value
	
	if not object.has_method(method):
		push_error("Method %s not found in object" % method)
		return default_value
	
	var result: Variant = object.callv(method, args)
	
	if expected_type != TYPE_NIL and typeof(result) != expected_type:
		push_error("Expected return type %s but got %s" % [expected_type, typeof(result)])
		return default_value
	
	return result

# Helper function for safe node method calls
func _call_node_method(obj: Object, method: String, args: Array = [], default_value: Variant = null) -> Variant:
	if not obj:
		push_error("Cannot call method on null object")
		return default_value
	return TypeSafeMixin._safe_method_call_variant(obj, method, args, default_value)

# Helper function for safe resource method calls
func _call_resource_method(resource: Variant, method: String, args: Array = [], expected_type: int = TYPE_NIL, default_value: Variant = null) -> Variant:
	var res: Resource = _safe_cast_resource(resource, "Cannot call method on non-Resource")
	if not res:
		return default_value
	
	return _call_method_safe(res, method, args, expected_type, default_value)

# Helper function to safely get property
func _get_property_safe(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	var object: Object = _safe_cast_object(obj, "Cannot get property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	return object.get(property)

# Helper function to safely set property
func _set_property_safe(obj: Variant, property: String, value: Variant) -> void:
	var object := _safe_cast_object(obj, "Cannot set property on non-Object")
	if not object:
		return
	
	if not property in object:
		return
	
	object.set(property, value)

# Helper function to safely add user signal
func _add_user_signal_safe(signal_name: String) -> void:
	if not _signal_watcher:
		push_error("Signal watcher not initialized")
		return
	
	if not signal_name.is_empty():
		_signal_watcher.add_user_signal(signal_name)

# Helper function to safely connect signal
func _connect_signal_safe(emitter: Object, signal_name: String, callable: Callable) -> void:
	if not emitter or signal_name.is_empty():
		return
	
	if not emitter.has_signal(signal_name):
		push_error("Signal %s not found in emitter" % signal_name)
		return
	
	var result: Error = emitter.connect(signal_name, callable)
	if result != OK:
		push_error("Failed to connect signal %s: %s" % [signal_name, error_string(result)])

# Helper function to safely check if a signal exists
func _has_signal_safe(obj: Object, signal_name: String) -> bool:
	if not obj:
		return false
	return obj.has_signal(signal_name)

# Helper function to safely check if a method exists
func _has_method_safe(obj: Object, method_name: String) -> bool:
	if not obj:
		return false
	return obj.has_method(method_name)

# Helper function to safely get a property
func _get_property_safe_typed(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not obj or not property in obj:
		return default_value
	return obj.get(property)

# Helper function to safely connect a signal with error handling
func _connect_signal_with_error_check(obj: Object, signal_name: String, callable: Callable) -> bool:
	if not obj or not _has_signal_safe(obj, signal_name):
		return false
	return obj.connect(signal_name, callable) == OK

# Helper function to safely connect signal with return value check
func _connect_signal_with_return_check(emitter: Object, signal_name: String, callable: Callable) -> Error:
	if not emitter or signal_name.is_empty():
		return ERR_INVALID_PARAMETER
	
	if not emitter.has_signal(signal_name):
		push_error("Signal %s not found in emitter" % signal_name)
		return ERR_DOES_NOT_EXIST
	
	var result: Error = emitter.connect(signal_name, callable)
	if result != OK:
		push_error("Failed to connect signal %s: %s" % [signal_name, error_string(result)])
	return result

# Helper function to safely check monitor value
func _get_monitor_safe(monitor_type: int) -> Variant:
	if not Performance.has_method("get_monitor"):
		push_error("Performance monitor method not available")
		return null
	return Performance.get_monitor(monitor_type)

# Helper function to safely get monitor value
func _get_monitor_value(monitor_type: int, default_value: int = 0) -> int:
	var monitor_value: Variant = _get_monitor_safe(monitor_type)
	if monitor_value == null:
		return default_value
	if not monitor_value is int:
		push_error("Monitor value is not an integer")
		return default_value
	return monitor_value

# Helper function to safely set window size with return value check
func _set_window_size_safe(size: Vector2) -> Error:
	if not DisplayServer.has_method("window_set_size"):
		push_error("Window size method not available")
		return ERR_UNAVAILABLE
	DisplayServer.window_set_size(size)
	return OK

# Helper function to safely set window size
func _set_window_size(size: Vector2) -> void:
	var result: Error = _set_window_size_safe(size)
	if result != OK:
		push_error("Failed to set window size: %s" % error_string(result))

# Mobile environment simulation
func simulate_mobile_environment(mode: String, orientation: String = "portrait") -> void:
	var resolution: Vector2
	match mode:
		"phone_portrait":
			resolution = Vector2(360, 640)
		"phone_landscape":
			resolution = Vector2(640, 360)
		"tablet_portrait":
			resolution = Vector2(768, 1024)
		_:
			resolution = Vector2(360, 640)
	
	DisplayServer.window_set_size(resolution)
	await get_tree().process_frame

# Performance measurement
func measure_mobile_performance(test_function: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"fps_samples": [],
		"memory_samples": [],
		"draw_calls": [],
		"objects": []
	}
	
	for i in range(iterations):
		await test_function.call()
		results.fps_samples.append(Engine.get_frames_per_second())
		results.memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		results.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		results.objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	
	return {
		"average_fps": _calculate_average(results.fps_samples),
		"minimum_fps": _calculate_minimum(results.fps_samples),
		"95th_percentile_fps": _calculate_percentile(results.fps_samples, 0.95),
		"memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024,
		"draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls),
		"objects_delta": _calculate_maximum(results.objects) - _calculate_minimum(results.objects)
	}

func before_each() -> void:
	await super.before_each()
	
	# Set up mobile environment
	await simulate_mobile_environment("phone_portrait")
	
	# Initialize game state
	var state_node: Node = create_test_game_state()
	if not state_node or not state_node.get_script():
		push_error("Failed to create game state with proper script")
		return
		
	add_child(state_node)
	track_test_node(state_node)
	assert_valid_game_state(state_node)
	game_state = state_node
	
	# Set up campaign system
	var campaign_system_instance: Node = FiveParcsecsCampaignSystemScript.new()
	if not campaign_system_instance:
		push_error("Failed to create campaign system")
		return
	
	# Initialize campaign system with game state using safe method call
	var init_result_variant: Variant = _call_node_method(campaign_system_instance, "initialize", [state_node])
	var init_result: Error = _safe_cast_error(init_result_variant, "Failed to cast initialize result to Error")
	if init_result != OK:
		push_error("Failed to initialize campaign system: %s" % error_string(init_result))
		return
	
	campaign_system = campaign_system_instance
	add_child(campaign_system_instance)
	track_test_node(campaign_system_instance)
	watch_signals(campaign_system_instance)
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	campaign = null
	campaign_system = null
	game_state = null

func test_mobile_campaign_performance() -> void:
	print_debug("Starting mobile campaign performance test")
	
	# Create and start campaign
	var campaign_config := {
		"name": "Mobile Test Campaign",
		"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
		"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnumsScript.CrewSize.FOUR,
		"use_story_track": true
	}
	
	var campaign_system_node := _safe_cast_node(campaign_system, "Campaign system not initialized")
	if not campaign_system_node:
		assert_true(false, "Campaign system should be initialized")
		return
	
	campaign = _call_node_method(campaign_system_node, "create_campaign", [campaign_config])
	var campaign_resource := _safe_cast_resource(campaign, "Failed to create campaign")
	if not campaign_resource:
		assert_true(false, "Campaign should be created successfully")
		return
	
	watch_resource_signals(campaign_resource)
	
	var start_success := _call_method_bool(campaign_resource, "start_campaign", [])
	assert_true(start_success, "Campaign should start successfully")
	
	# Test campaign phase transitions under different mobile conditions
	var resolutions: Array[String] = ["phone_portrait", "phone_landscape", "tablet_portrait"]
	
	for resolution in resolutions:
		print_debug("Testing campaign performance in %s mode..." % resolution)
		await simulate_mobile_environment(resolution)
		await get_tree().process_frame
		
		# Measure phase transition performance
		var results: Dictionary = await measure_mobile_performance(func() -> void:
			var phase_success := _call_method_bool(campaign_resource, "change_phase", [GameEnumsScript.FiveParcsecsCampaignPhase.UPKEEP])
			assert_true(phase_success, "Should change to UPKEEP phase")
			await get_tree().process_frame
			
			phase_success = _call_method_bool(campaign_resource, "change_phase", [GameEnumsScript.FiveParcsecsCampaignPhase.CAMPAIGN])
			assert_true(phase_success, "Should change to CAMPAIGN phase")
			await get_tree().process_frame
		)
		
		# Performance assertions
		var avg_fps := _safe_cast_float(results.get("average_fps", 0.0), "Invalid average FPS")
		var min_fps := _safe_cast_float(results.get("minimum_fps", 0.0), "Invalid minimum FPS")
		var memory_delta := _safe_cast_float(results.get("memory_delta_kb", 0.0), "Invalid memory delta")
		
		assert_true(avg_fps >= MIN_FPS,
			"Average FPS should be at least %d in %s mode" % [MIN_FPS, resolution])
		assert_true(min_fps >= MIN_FPS * 0.67,
			"Minimum FPS should be at least %d in %s mode" % [MIN_FPS * 0.67, resolution])
		assert_true(memory_delta < MIN_MEMORY_MB * 1024,
			"Memory usage increase should be less than %dMB in %s mode" % [MIN_MEMORY_MB, resolution])
		
		print_debug("Performance results for %s:" % resolution)
		print_debug("- Average FPS: %.2f" % avg_fps)
		print_debug("- 95th percentile FPS: %.2f" % results.get("95th_percentile_fps", 0.0))
		print_debug("- Minimum FPS: %.2f" % min_fps)
		print_debug("- Memory Delta: %.2f KB" % memory_delta)
		print_debug("- Draw Calls Delta: %d" % results.get("draw_calls_delta", 0))
		print_debug("- Objects Delta: %d" % results.get("objects_delta", 0))

func test_mobile_save_load() -> void:
	print_debug("Testing mobile save/load functionality")
	
	# Create initial campaign
	var campaign_config := {
		"name": "Mobile Save Test",
		"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
		"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnumsScript.CrewSize.FOUR,
		"use_story_track": true
	}
	
	var campaign_system_node := _safe_cast_node(campaign_system, "Campaign system not initialized")
	if not campaign_system_node:
		assert_true(false, "Campaign system should be initialized")
		return
	
	campaign = _call_node_method(campaign_system_node, "create_campaign", [campaign_config])
	var campaign_resource := _safe_cast_resource(campaign, "Failed to create campaign")
	if not campaign_resource:
		assert_true(false, "Campaign should be created successfully")
		return
	
	watch_resource_signals(campaign_resource)
	
	var start_success := _call_method_bool(campaign_resource, "start_campaign", [])
	assert_true(start_success, "Campaign should start successfully")
	
	# Test save/load under different mobile conditions
	var save_load_resolutions: Array[String] = ["phone_portrait", "phone_landscape"]
	
	for resolution in save_load_resolutions:
		print_debug("Testing save/load in %s mode..." % resolution)
		await simulate_mobile_environment(resolution)
		await get_tree().process_frame
		
		# Save campaign
		var save_results: Dictionary = await measure_mobile_performance(func() -> void:
			var save_success := _call_method_bool(campaign_system_node, "save_campaign", [campaign_resource])
			assert_true(save_success, "Should save campaign successfully")
			await get_tree().process_frame
		)
		
		# Load campaign
		var load_results: Dictionary = await measure_mobile_performance(func() -> void:
			var load_success := _call_method_bool(campaign_system_node, "load_campaign", ["Mobile Save Test"])
			assert_true(load_success, "Should load campaign successfully")
			await get_tree().process_frame
		)
		
		# Performance assertions
		var save_fps: float = _safe_cast_float(save_results.get("average_fps", 0.0), "Invalid save FPS")
		var load_fps: float = _safe_cast_float(load_results.get("average_fps", 0.0), "Invalid load FPS")
		
		assert_true(save_fps >= MIN_FPS,
			"Save operation should maintain at least %d FPS in %s mode" % [MIN_FPS, resolution])
		assert_true(load_fps >= MIN_FPS,
			"Load operation should maintain at least %d FPS in %s mode" % [MIN_FPS, resolution])
		
		print_debug("Save/Load performance in %s:" % resolution)
		print_debug("Save operation:")
		print_debug("- Average FPS: %.2f" % save_fps)
		print_debug("- Memory Delta: %.2f KB" % save_results.get("memory_delta_kb", 0.0))

func test_mobile_input_handling() -> void:
	print_debug("Testing mobile input handling")
	
	# Create and start campaign
	var campaign_config := {
		"name": "Mobile Input Test",
		"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
		"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnumsScript.CrewSize.FOUR,
		"use_story_track": true
	}
	
	var campaign_system_node := _safe_cast_node(campaign_system, "Campaign system not initialized")
	if not campaign_system_node:
		assert_true(false, "Campaign system should be initialized")
		return
	
	campaign = _call_node_method(campaign_system_node, "create_campaign", [campaign_config])
	var campaign_resource := _safe_cast_resource(campaign, "Failed to create campaign")
	if not campaign_resource:
		assert_true(false, "Campaign should be created successfully")
		return
	
	watch_resource_signals(campaign_resource)
	
	var start_result: Variant = _call_resource_method(campaign_resource, "start_campaign", [])
	var start_success: bool = _safe_cast_bool(start_result, "Campaign start result must be boolean")
	assert_true(start_success, "Campaign should start successfully")
	
	# Test touch input for common campaign actions
	var touch_actions: Array[Dictionary] = [
		{"position": Vector2(100, 100), "action": "select_character"},
		{"position": Vector2(200, 200), "action": "open_inventory"},
		{"position": Vector2(300, 300), "action": "start_mission"}
	]
	
	for action in touch_actions:
		var action_dict: Dictionary = _safe_cast_dictionary(action, "Invalid action configuration")
		if not action_dict:
			continue
		
		var position: Vector2 = action_dict.get("position", Vector2.ZERO)
		var action_name: String = action_dict.get("action", "")
		
		# Simulate touch
		await simulate_touch_event(position, true)
		await get_tree().process_frame
		await simulate_touch_event(position, false)
		await get_tree().process_frame
		
		# Verify action response
		assert_resource_signal_emitted(campaign_resource, action_name + "_triggered",
			"Campaign should respond to touch input for " + action_name)
		
		# Test touch responsiveness
		var response_results: Dictionary = await measure_mobile_performance(func() -> void:
			await simulate_touch_event(position, true)
			await get_tree().process_frame
			await simulate_touch_event(position, false)
			await get_tree().process_frame
		)
		
		var response_fps: float = _safe_cast_float(response_results.get("average_fps", 0.0), "Invalid response FPS")
		assert_true(response_fps >= MIN_FPS,
			"Touch response should maintain at least %d FPS" % MIN_FPS)
		
		print_debug("Touch response performance for %s:" % action_name)
		print_debug("- Average FPS: %.2f" % response_fps)
		print_debug("- Response Time: %.2f ms" % (1000.0 / response_fps))

func assert_resource_signal_emitted(resource: Resource, signal_name: String, message: String = "") -> void:
	var res := _safe_cast_resource(resource, "Cannot assert signals on non-Resource")
	if not res or not _signal_watcher:
		push_error("Signal watcher or resource not initialized")
		return
	
	var meta_key := "signal_" + signal_name
	var signal_emitted := false
	
	if _signal_watcher.has_meta(meta_key):
		var meta_value: Variant = _signal_watcher.get_meta(meta_key, false)
		signal_emitted = _safe_cast_bool(meta_value, "Signal emission value must be boolean")
	
	if not signal_emitted:
		push_error("Signal %s was not emitted" % signal_name)
	assert_true(signal_emitted, message)

# Signal tracking for resources
func watch_resource_signals(resource: Resource) -> void:
	var res := _safe_cast_resource(resource, "Cannot watch signals on non-Resource")
	if not res or not _signal_watcher:
		return
	
	var signal_list: Array = res.get_signal_list()
	for signal_info: Dictionary in signal_list:
		if not signal_info is Dictionary:
			continue
		
		var signal_name: String = signal_info.get("name", "")
		if signal_name.is_empty():
			continue
		
		# Add user signal if it doesn't exist
		if _has_method_safe(_signal_watcher, "add_user_signal") and not _has_signal_safe(_signal_watcher, signal_name):
			_signal_watcher.add_user_signal(signal_name)
		
		# Connect signal if not already connected
		if _has_signal_safe(res, signal_name) and not res.is_connected(signal_name, _on_resource_signal_emitted.bind(signal_name)):
			var result: Error = _connect_signal_with_return_check(res, signal_name, _on_resource_signal_emitted.bind(signal_name))
			if result != OK:
				push_error("Failed to connect signal %s: %s" % [signal_name, error_string(result)])

func _on_resource_signal_emitted(signal_name: String) -> void:
	if not _signal_watcher or signal_name.is_empty():
		return
	
	_signal_watcher.set_meta("signal_" + signal_name, true)

# Helper function to safely cast to bool
func _safe_cast_bool(value: Variant, error_message: String = "") -> bool:
	if value == null:
		push_error("Cannot cast null to bool: %s" % error_message)
		return false
	if not value is bool:
		push_error("Cannot cast %s to bool: %s" % [typeof(value), error_message])
		return false
	return value

# Helper functions for mobile testing
func verify_mobile_ui_state(ui: Control, expected_state: Dictionary) -> void:
	if not ui:
		push_error("Cannot verify state of null UI")
		return
	
	for property in expected_state:
		var actual_value = _call_node_method(ui, "get_" + property, [])
		assert_eq(actual_value, expected_state[property],
			"UI property '%s' should be %s but was %s" % [property, expected_state[property], actual_value])

func verify_mobile_input(input_node: Node, expected_input: Dictionary) -> void:
	if not input_node:
		push_error("Cannot verify input on null node")
		return
	
	for action in expected_input:
		var is_pressed = _call_node_method(input_node, "is_action_pressed", [action])
		assert_eq(is_pressed, expected_input[action],
			"Input action '%s' should be %s but was %s" % [action, expected_input[action], is_pressed])

func verify_mobile_touch(touch_node: Node, expected_touch: Dictionary) -> void:
	if not touch_node:
		push_error("Cannot verify touch on null node")
		return
	
	for property in expected_touch:
		var actual_value = _call_node_method(touch_node, "get_" + property, [])
		assert_eq(actual_value, expected_touch[property],
			"Touch property '%s' should be %s but was %s" % [property, expected_touch[property], actual_value])

# Helper functions for type-safe method calls
func _call_method_with_type(obj: Object, method: String, args: Array, expected_type: int) -> Variant:
	var result = _call_node_method(obj, method, args)
	if typeof(result) != expected_type:
		push_error("Method '%s' returned wrong type: expected %d, got %d" % [method, expected_type, typeof(result)])
		return null
	return result

func _call_method_bool(obj: Object, method: String, args: Array) -> bool:
	var result = _call_method_with_type(obj, method, args, TYPE_BOOL)
	return result if result != null else false

func _call_method_int(obj: Object, method: String, args: Array) -> int:
	var result = _call_method_with_type(obj, method, args, TYPE_INT)
	return result if result != null else 0
