@tool
extends "res://tests/fixtures/base/mobile_test_base.gd"

## Mobile-specific mission tests
##
## Tests mission functionality on mobile devices:
## - Touch input handling
## - Mobile UI interactions
## - Performance on mobile
## - Resource management
## - Save state handling

# Type-safe script references
const MissionScript := preload("res://src/core/mission/base/mission.gd")
const MissionGeneratorScript: GDScript = preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const GameEnumsScript := preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe instance variables
var _mission: Resource = null
var _generator: Node = null
var _mobile_ui: Node = null

# Type-safe constants
const TOUCH_DURATION: float = 0.1 # seconds
const PERFORMANCE_THRESHOLD: float = 16.67 # ms (60 FPS)
const MEMORY_THRESHOLD: int = 50 * 1024 * 1024 # 50 MB
const SAVE_FILE_PATH: String = "user://mobile_test_save.tres"

func before_each() -> void:
	await super.before_each()
	
	# Initialize test environment
	_mission = TypeSafeMixin._safe_cast_to_resource(MissionScript.new(), "Mission")
	if not _mission:
		push_error("Failed to create mission")
		return
	track_test_resource(_mission)
	
	_generator = TypeSafeMixin._safe_cast_to_node(Node.new(), "Generator")
	if not _generator:
		push_error("Failed to create mission generator")
		return
	_generator.set_script(MissionGeneratorScript)
	add_child_autofree(_generator)
	track_test_node(_generator)
	
	_mobile_ui = TypeSafeMixin._safe_cast_to_node(Node.new(), "MobileUI")
	if not _mobile_ui:
		push_error("Failed to create mobile UI")
		return
	add_child_autofree(_mobile_ui)
	track_test_node(_mobile_ui)
	
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	
	if is_instance_valid(_mobile_ui):
		_mobile_ui.queue_free()
	if is_instance_valid(_generator):
		_generator.queue_free()
	
	_mission = null
	_generator = null
	_mobile_ui = null

# Touch Input Tests
func test_mission_touch_controls() -> void:
	watch_signals(_mobile_ui)
	
	# Simulate touch to select objective
	var touch_pos := Vector2(100, 100)
	simulate_touch_event(touch_pos, true)
	await get_tree().process_frame
	simulate_touch_event(touch_pos, false)
	await get_tree().process_frame
	
	verify_signal_emitted(_mobile_ui, "objective_selected")
	
	# Test touch target sizes
	var ui_elements: Dictionary = _get_property_safe(_mobile_ui, "ui_elements", {})
	for element in ui_elements.values():
		if element is Control:
			assert_touch_target_size(element)

# Mobile UI Tests
func test_mobile_ui_layout() -> void:
	# Test UI adaptation to screen size
	var screen_size := DisplayServer.window_get_size()
	
	# Test different screen orientations
	for orientation in ["portrait", "landscape"]:
		simulate_mobile_environment(orientation, "phone")
		await stabilize_engine()
		
		var ui_elements: Dictionary = _get_property_safe(_mobile_ui, "ui_elements", {})
		for element in ui_elements.values():
			if element is Control:
				assert_fits_mobile_screen(element)

# Performance Tests
func test_mobile_performance() -> void:
	var mission: Resource = TypeSafeMixin._call_node_method(_generator, "generate_mission_with_type",
		[GameEnumsScript.MissionType.PATROL]) as Resource
	if not mission:
		push_error("Failed to generate mission")
		return
	
	var metrics := await measure_performance(
		func():
			TypeSafeMixin._call_node_method_bool(mission, "update_objectives")
			TypeSafeMixin._call_node_method_bool(_mobile_ui, "update_display")
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, {
		"average_fps": 30.0,
		"minimum_fps": 20.0,
		"memory_delta_kb": 512.0,
		"draw_calls_delta": 50
	})

# Memory Management Tests
func test_mobile_memory_usage() -> void:
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Create and process multiple missions
	var missions: Array[Resource] = []
	for i in range(10):
		var mission: Resource = TypeSafeMixin._call_node_method(_generator, "generate_mission_with_type",
			[GameEnumsScript.MissionType.PATROL]) as Resource
		if not mission:
			push_error("Failed to generate mission %d" % i)
			continue
		
		missions.append(mission)
		TypeSafeMixin._call_node_method_bool(_mobile_ui, "display_mission", [mission])
		await get_tree().process_frame
	
	var peak_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_lt(peak_memory - initial_memory, MEMORY_THRESHOLD,
		"Memory usage should stay within limits")
	
	# Test memory cleanup
	missions.clear()
	await get_tree().process_frame
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_lt(final_memory - initial_memory, MEMORY_THRESHOLD / 10,
		"Memory should be properly cleaned up")

# Save State Tests
func test_mobile_save_state() -> void:
	var mission: Resource = TypeSafeMixin._call_node_method(_generator, "generate_mission_with_type",
		[GameEnumsScript.MissionType.PATROL]) as Resource
	if not mission:
		push_error("Failed to generate mission")
		return
	
	# Test saving during low memory
	var save_result := ResourceSaver.save(mission, SAVE_FILE_PATH)
	assert_eq(save_result, OK, "Should save successfully under memory pressure")
	
	# Test loading after app suspension
	var loaded_mission: Resource = load(SAVE_FILE_PATH) as Resource
	assert_not_null(loaded_mission, "Should load successfully after suspension")
	
	var mission_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(loaded_mission, "get_mission_id"))
	var original_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(mission, "get_mission_id"))
	assert_eq(mission_id, original_id, "Should preserve mission state")

# Helper Methods
func simulate_touch_event(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func simulate_mobile_environment(orientation: String, device_type: String = "phone") -> void:
	var resolution := Vector2i(360, 640) if orientation == "portrait" else Vector2i(640, 360)
	if device_type == "tablet":
		resolution *= 2
	DisplayServer.window_set_size(resolution)
	await get_tree().process_frame

# Performance testing methods
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"fps_samples": [],
		"memory_samples": [],
		"draw_calls": []
	}
	
	for i in range(iterations):
		await callable.call()
		results.fps_samples.append(Engine.get_frames_per_second())
		results.memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		results.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		await stabilize_engine()
	
	return {
		"average_fps": _calculate_average(results.fps_samples),
		"minimum_fps": _calculate_minimum(results.fps_samples),
		"memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024,
		"draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls)
	}

func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_value: float = values[0]
	for value in values:
		min_value = min(min_value, value)
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_value: float = values[0]
	for value in values:
		max_value = max(max_value, value)
	return max_value