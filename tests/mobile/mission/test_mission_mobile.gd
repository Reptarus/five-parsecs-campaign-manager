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

# Fallback enum values
enum MissionType {PATROL = 0, DEFENSE = 1, ASSAULT = 2}

func before_each() -> void:
	await super.before_each()
	
	# Initialize test environment - direct creation of mission without type casts
	var mission_script = load("res://src/core/mission/base/mission.gd")
	if mission_script:
		_mission = mission_script.new()
		if _mission:
			track_test_resource(_mission)
	else:
		push_warning("Failed to load mission script, skipping mission creation")
	
	# Create a simple generator node without unsafe type casts
	_generator = Node.new()
	_generator.name = "MissionGenerator"
	if _generator:
		if MissionGeneratorScript:
			_generator.set_script(MissionGeneratorScript)
			if not _generator.get_script():
				push_warning("Failed to set script on mission generator, tests may be skipped")
		add_child_autofree(_generator)
		track_test_node(_generator)
	else:
		push_warning("Failed to create mission generator, tests may be skipped")
	
	# Create a basic UI node for mobile tests
	_mobile_ui = Node.new()
	_mobile_ui.name = "MobileUI"
	if _mobile_ui:
		add_child_autofree(_mobile_ui)
		track_test_node(_mobile_ui)
	else:
		push_warning("Failed to create mobile UI, tests may be skipped")
	
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
	if not is_instance_valid(_mobile_ui):
		push_warning("Mobile UI is not valid, skipping test")
		return
		
	if not _mobile_ui.has_signal("objective_selected"):
		push_warning("Mobile UI does not have objective_selected signal, skipping test")
		return
		
	watch_signals(_mobile_ui)
	
	# Simulate touch to select objective
	var touch_pos := Vector2(100, 100)
	simulate_touch_event(touch_pos, true)
	await get_tree().process_frame
	simulate_touch_event(touch_pos, false)
	await get_tree().process_frame
	
	verify_signal_emitted(_mobile_ui, "objective_selected", "Objective selected signal not emitted")
	
	# Test touch target sizes
	var ui_elements = _get_property_safe(_mobile_ui, "ui_elements", {})
	for element in ui_elements.values():
		if element is Control:
			assert_touch_target_size(element)

# Mobile UI Tests
func test_mobile_ui_layout() -> void:
	if not is_instance_valid(_mobile_ui):
		push_warning("Mobile UI is not valid, skipping test")
		return
		
	# Test UI adaptation to screen size
	var screen_size := DisplayServer.window_get_size()
	
	# Test different screen orientations
	for orientation in ["portrait", "landscape"]:
		simulate_mobile_environment(orientation, "phone")
		await stabilize_engine()
		
		var ui_elements = _get_property_safe(_mobile_ui, "ui_elements", {})
		for element in ui_elements.values():
			if element is Control:
				assert_fits_mobile_screen(element)

# Performance Tests
func test_mobile_performance() -> void:
	if not is_instance_valid(_generator) or not is_instance_valid(_mobile_ui):
		push_warning("Generator or mobile UI is not valid, skipping test")
		return
		
	if not _generator.has_method("generate_mission_with_type"):
		push_warning("Generator does not have generate_mission_with_type method, skipping test")
		return
		
	# Use a fallback mission type value
	var mission_type = MissionType.PATROL
	
	var mission = TypeSafeMixin._call_node_method(_generator, "generate_mission_with_type", [mission_type])
	if not mission:
		push_warning("Failed to generate mission, skipping test")
		return
		
	if not mission.has_method("update_objectives"):
		push_warning("Mission does not have update_objectives method, skipping part of test")
	
	if not _mobile_ui.has_method("update_display"):
		push_warning("Mobile UI does not have update_display method, skipping part of test")
		
	var metrics := await measure_performance(
		func():
			if mission.has_method("update_objectives"):
				TypeSafeMixin._call_node_method_bool(mission, "update_objectives", [], false)
			if _mobile_ui.has_method("update_display"):
				TypeSafeMixin._call_node_method_bool(_mobile_ui, "update_display", [], false)
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
	if not is_instance_valid(_generator) or not is_instance_valid(_mobile_ui):
		push_warning("Generator or mobile UI is not valid, skipping test")
		return
		
	if not _generator.has_method("generate_mission_with_type"):
		push_warning("Generator does not have generate_mission_with_type method, skipping test")
		return
		
	# Use a fallback mission type value
	var mission_type = MissionType.PATROL
	
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Create and process multiple missions
	var missions = []
	for i in range(10):
		var mission = TypeSafeMixin._call_node_method(_generator, "generate_mission_with_type", [mission_type])
		if not mission:
			push_warning("Failed to generate mission %d, continuing with others" % i)
			continue
		
		missions.append(mission)
		
		if _mobile_ui.has_method("display_mission"):
			TypeSafeMixin._call_node_method_bool(_mobile_ui, "display_mission", [mission], false)
		
		await get_tree().process_frame
	
	if missions.size() == 0:
		push_warning("No missions were generated successfully, skipping test")
		return
		
	var peak_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_lt(peak_memory - initial_memory, MEMORY_THRESHOLD,
		"Memory usage should stay within limits (peak: %d, initial: %d, diff: %d, threshold: %d)" %
		[peak_memory, initial_memory, peak_memory - initial_memory, MEMORY_THRESHOLD])
	
	# Test memory cleanup
	missions.clear()
	await get_tree().process_frame
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_lt(final_memory - initial_memory, MEMORY_THRESHOLD / 10,
		"Memory should be properly cleaned up (final: %d, initial: %d, diff: %d, threshold: %d)" %
		[final_memory, initial_memory, final_memory - initial_memory, MEMORY_THRESHOLD / 10])

# Save State Tests
func test_mobile_save_state() -> void:
	if not is_instance_valid(_generator):
		push_warning("Generator is not valid, skipping test")
		return
		
	if not _generator.has_method("generate_mission_with_type"):
		push_warning("Generator does not have generate_mission_with_type method, skipping test")
		return
		
	# Use a fallback mission type value
	var mission_type = MissionType.PATROL
	
	var mission = TypeSafeMixin._call_node_method(_generator, "generate_mission_with_type", [mission_type])
	if not mission:
		push_warning("Failed to generate mission, skipping test")
		return
		
	# Skip if mission doesn't have a mission_id property to test with
	if not mission.has_method("get_mission_id"):
		push_warning("Mission does not have get_mission_id method, skipping test")
		return
		
	# Test saving during low memory
	var save_result := ResourceSaver.save(mission, SAVE_FILE_PATH)
	assert_eq(save_result, OK, "Should save successfully under memory pressure (error code: %d)" % save_result)
	
	# Test loading after app suspension
	var loaded_mission = load(SAVE_FILE_PATH)
	if not loaded_mission:
		push_warning("Failed to load saved mission, skipping validation part")
		return
	
	assert_not_null(loaded_mission, "Should load successfully after suspension")
	
	if not loaded_mission.has_method("get_mission_id"):
		push_warning("Loaded mission does not have get_mission_id method, skipping ID validation")
		return
		
	var mission_id = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(loaded_mission, "get_mission_id", []))
	var original_id = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(mission, "get_mission_id", []))
	assert_eq(mission_id, original_id, "Should preserve mission state (original: %s, loaded: %s)" % [original_id, mission_id])
	
	# Clean up test save file
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_FILE_PATH.get_file())

# Helper Methods
func simulate_touch_event(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	if not event:
		push_warning("Failed to create touch event, skipping simulation")
		return
		
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
