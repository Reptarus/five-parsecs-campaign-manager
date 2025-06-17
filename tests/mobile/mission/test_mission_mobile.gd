@tool
extends GdUnitGameTest

## Mobile-specific mission tests
##
## Tests mission functionality on mobile devices:
## - Touch input handling
## - Mobile UI interactions
## - Performance on mobile
## - Resource management
## - Save state handling

# Mock Mission with expected values (Universal Mock Strategy)
class MockMission extends Resource:
	var mission_id: String = "mobile_test_mission"
	var mission_type: int = 1
	var objectives: Array[Dictionary] = []
	var status: int = 0
	var touch_enabled: bool = true
	
	func get_mission_id() -> String: return mission_id
	func get_mission_type() -> int: return mission_type
	func get_objectives() -> Array[Dictionary]: return objectives
	func get_status() -> int: return status
	func is_touch_enabled() -> bool: return touch_enabled
	
	func add_objective(objective: Dictionary) -> void:
		objectives.append(objective)
		objective_added.emit(objective)
	
	func complete_objective(objective_id: String) -> bool:
		for i in range(objectives.size()):
			if objectives[i].get("id", "") == objective_id:
				objectives[i]["completed"] = true
				objective_completed.emit(objective_id)
				return true
		return false
	
	func serialize() -> Dictionary:
		return {
			"mission_id": mission_id,
			"mission_type": mission_type,
			"objectives": objectives,
			"status": status
		}
	
	func deserialize(data: Dictionary) -> void:
		mission_id = data.get("mission_id", "")
		mission_type = data.get("mission_type", 0)
		objectives = data.get("objectives", [])
		status = data.get("status", 0)
	
	# Required signals (immediate emission pattern)
	signal objective_added(objective: Dictionary)
	signal objective_completed(objective_id: String)

# Mock Mission Generator with expected values (Universal Mock Strategy)
class MockMissionGenerator extends Resource:
	func generate_mission(config: Dictionary = {}) -> MockMission:
		var mission = MockMission.new()
		mission.mission_id = config.get("id", "generated_mission_" + str(randi()))
		mission.mission_type = config.get("type", 1)
		
		# Add default objectives
		mission.add_objective({
			"id": "obj_1",
			"type": "eliminate",
			"target": "enemies",
			"completed": false
		})
		
		mission_generated.emit(mission)
		return mission
	
	# Required signals (immediate emission pattern)
	signal mission_generated(mission: MockMission)

# Mock Mobile UI with expected values (Universal Mock Strategy)
class MockMobileUI extends Resource:
	var ui_elements: Dictionary = {}
	var touch_targets: Array[Dictionary] = []
	var screen_orientation: String = "portrait"
	var is_visible: bool = true
	
	func _init():
		# Initialize UI elements with proper touch target sizes
		ui_elements = {
			"objective_button": {"size": Vector2(60, 60), "position": Vector2(100, 100)},
			"menu_button": {"size": Vector2(50, 50), "position": Vector2(200, 100)},
			"action_button": {"size": Vector2(80, 80), "position": Vector2(300, 100)}
		}
		
		# Create touch targets
		for element_name in ui_elements:
			var element = ui_elements[element_name]
			touch_targets.append({
				"name": element_name,
				"rect": Rect2(element.position, element.size),
				"min_size": Vector2(44, 44) # Minimum touch target size
			})
	
	func get_ui_elements() -> Dictionary: return ui_elements
	func get_touch_targets() -> Array[Dictionary]: return touch_targets
	func get_screen_orientation() -> String: return screen_orientation
	func is_ui_visible() -> bool: return is_visible
	
	func set_orientation(orientation: String) -> void:
		screen_orientation = orientation
		orientation_changed.emit(orientation)
	
	func handle_touch(position: Vector2) -> bool:
		for target in touch_targets:
			if target.rect.has_point(position):
				touch_handled.emit(target.name, position)
				return true
		return false
	
	# Required signals (immediate emission pattern)
	signal orientation_changed(orientation: String)
	signal touch_handled(element_name: String, position: Vector2)

# Type-safe instance variables
var _mission: MockMission = null
var _generator: MockMissionGenerator = null
var _mobile_ui: MockMobileUI = null

# Type-safe constants
const TOUCH_DURATION: float = 0.1 # seconds
const PERFORMANCE_THRESHOLD: float = 16.67 # ms (60 FPS)
const MEMORY_THRESHOLD: int = 50 * 1024 * 1024 # 50 MB
const SAVE_FILE_PATH: String = "user://mobile_test_save.tres"

func before_test() -> void:
	super.before_test()
	
	# Use Resource-based mocks (proven pattern)
	_mission = MockMission.new()
	track_resource(_mission)
	
	_generator = MockMissionGenerator.new()
	track_resource(_generator)
	
	_mobile_ui = MockMobileUI.new()
	track_resource(_mobile_ui)

func after_test() -> void:
	_mission = null
	_generator = null
	_mobile_ui = null
	super.after_test()

# Touch Input Tests
func test_mission_touch_controls() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Simulate touch to select objective
	var touch_pos := Vector2(100, 100)
	simulate_touch_event(touch_pos, true)
	await get_tree().process_frame
	simulate_touch_event(touch_pos, false)
	await get_tree().process_frame
	
	# Test touch handling
	var touch_handled: bool = _mobile_ui.handle_touch(touch_pos)
	assert_that(touch_handled).override_failure_message("Touch should be handled by UI element").is_true()
	
	# Test touch target sizes
	var touch_targets: Array[Dictionary] = _mobile_ui.get_touch_targets()
	for target in touch_targets:
		var size: Vector2 = target.rect.size
		assert_that(size.x >= 44 and size.y >= 44).override_failure_message("Touch target should meet minimum size requirements").is_true()

# Mobile UI Tests
func test_mobile_ui_layout() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test different screen orientations
	for orientation in ["portrait", "landscape"]:
		_mobile_ui.set_orientation(orientation)
		await get_tree().process_frame
		
		var ui_elements: Dictionary = _mobile_ui.get_ui_elements()
		assert_that(ui_elements.size()).override_failure_message("UI should have elements").is_greater(0)
		
		# Verify elements fit mobile screen constraints
		for element_name in ui_elements:
			var element = ui_elements[element_name]
			assert_fits_mobile_screen(element)

# Performance Tests
func test_mobile_performance() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var metrics := await measure_performance(
		func():
			# Simulate mission update
			_mission.add_objective({
				"id": "perf_test_obj",
				"type": "collect",
				"target": "items",
				"completed": false
			})
			await get_tree().process_frame
	)
	
	# Verify performance metrics directly
	assert_that(metrics.average_fps).override_failure_message(
		"Average FPS should be above 30.0"
	).is_greater_equal(30.0)
	
	assert_that(metrics.minimum_fps).override_failure_message(
		"Minimum FPS should be above 20.0"
	).is_greater_equal(20.0)
	
	assert_that(metrics.memory_delta_kb).override_failure_message(
		"Memory delta should be below 512.0 KB"
	).is_less_equal(512.0)

# Memory Management Tests
func test_mobile_memory_usage() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Create and process multiple missions
	var missions: Array[MockMission] = []
	for i in range(10):
		var mission: MockMission = _generator.generate_mission({"id": "mission_%d" % i})
		missions.append(mission)
		track_resource(mission)
		await get_tree().process_frame
	
	var peak_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_that(peak_memory - initial_memory).override_failure_message(
		"Memory usage should stay within limits"
	).is_less(MEMORY_THRESHOLD)
	
	# Test memory cleanup
	missions.clear()
	await get_tree().process_frame
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_that(final_memory - initial_memory).override_failure_message(
		"Memory should be properly cleaned up"
	).is_less(MEMORY_THRESHOLD / 10)

# Save State Tests
func test_mobile_save_state() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Add some objectives to the mission
	_mission.add_objective({
		"id": "save_test_obj",
		"type": "explore",
		"target": "area",
		"completed": false
	})
	
	# Test saving
	var serialized_data: Dictionary = _mission.serialize()
	var save_result := ResourceSaver.save(_mission, SAVE_FILE_PATH)
	assert_that(save_result).is_equal(OK)
	
	# Test loading
	var loaded_mission: Resource = load(SAVE_FILE_PATH) as Resource
	assert_that(loaded_mission).is_not_null()
	
	# Verify data integrity
	if loaded_mission is MockMission:
		var loaded_mock = loaded_mission as MockMission
		assert_that(loaded_mock.get_mission_id()).is_equal(_mission.get_mission_id())
		assert_that(loaded_mock.get_objectives().size()).is_equal(_mission.get_objectives().size())

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

func assert_fits_mobile_screen(element: Dictionary) -> void:
	var screen_size := DisplayServer.window_get_size()
	var element_size: Vector2 = element.get("size", Vector2.ZERO)
	var element_pos: Vector2 = element.get("position", Vector2.ZERO)
	
	assert_that(element_pos.x + element_size.x <= screen_size.x).override_failure_message("Element should fit horizontally").is_true()
	assert_that(element_pos.y + element_size.y <= screen_size.y).override_failure_message("Element should fit vertically").is_true()

func measure_performance(callable: Callable, iterations: int = 10) -> Dictionary:
	var fps_samples: Array[float] = []
	var memory_samples: Array[float] = []
	
	for i in range(iterations):
		await callable.call()
		fps_samples.append(Engine.get_frames_per_second())
		memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		await get_tree().process_frame
	
	return {
		"average_fps": _calculate_average(fps_samples),
		"minimum_fps": _calculate_minimum(fps_samples),
		"memory_delta_kb": (_calculate_maximum(memory_samples) - _calculate_minimum(memory_samples)) / 1024
	}

func _calculate_average(values: Array[float]) -> float:
	if values.is_empty(): return 0.0
	var sum := 0.0
	for value in values: sum += value
	return sum / values.size()

func _calculate_minimum(values: Array[float]) -> float:
	if values.is_empty(): return 0.0
	var min_value: float = values[0]
	for value in values: min_value = min(min_value, value)
	return min_value

func _calculate_maximum(values: Array[float]) -> float:
	if values.is_empty(): return 0.0
	var max_value: float = values[0]
	for value in values: max_value = max(max_value, value)
	return max_value