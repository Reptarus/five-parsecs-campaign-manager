@tool
extends "res://tests/fixtures/base/mobile_test_base.gd"

# Type-safe script references
const FiveParcsecsCampaignSystemScript := preload("res://src/core/campaign/CampaignSystem.gd")
const GameEnumsScript := preload("res://src/core/systems/GlobalEnums.gd")

# Test variables with explicit types
var _campaign_system: Node = null
var _campaign: Resource = null

# Performance thresholds with explicit types
const MIN_FPS: float = 30.0
const MIN_MEMORY_MB: float = 2.0
const TEST_ITERATIONS: int = 100

func before_each() -> void:
	await super.before_each()
	
	# Set up mobile environment
	await simulate_mobile_environment("phone_portrait")
	
	# Initialize game state
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Set up campaign system
	_campaign_system = FiveParcsecsCampaignSystemScript.new()
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return
	
	# Initialize campaign system with game state
	var init_result: Error = TypeSafeMixin._call_node_method_int(_campaign_system, "initialize", [_game_state])
	if init_result != OK:
		push_error("Failed to initialize campaign system: %s" % error_string(init_result))
		return
	
	add_child_autofree(_campaign_system)
	track_test_node(_campaign_system)
	watch_signals(_campaign_system)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	await super.after_each()
	_campaign = null
	_campaign_system = null
	_game_state = null

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
		await stabilize_engine(STABILIZE_TIME)
	
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

func test_mobile_campaign_performance() -> void:
	print_debug("Starting mobile campaign performance test")
	
	# Create and start campaign
	var campaign_config: Dictionary = {
		"name": "Mobile Test Campaign",
		"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
		"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnumsScript.CrewSize.FOUR,
		"use_story_track": true
	}
	
	_campaign = TypeSafeMixin._call_node_method(_campaign_system, "create_campaign", [campaign_config]) as Resource
	if not _campaign:
		assert_true(false, "Campaign should be created successfully")
		return
	
	watch_signals(_campaign)
	
	var start_success: bool = TypeSafeMixin._call_node_method_bool(_campaign, "start_campaign", [])
	assert_true(start_success, "Campaign should start successfully")
	
	# Test campaign phase transitions under different mobile conditions
	var resolutions: Array[String] = ["phone_portrait", "phone_landscape", "tablet_portrait"]
	
	for resolution in resolutions:
		print_debug("Testing campaign performance in %s mode..." % resolution)
		await simulate_mobile_environment(resolution)
		await stabilize_engine(STABILIZE_TIME)
		
		# Measure phase transition performance
		var metrics: Dictionary = await measure_performance(
			func() -> void:
				var phase_success: bool = TypeSafeMixin._call_node_method_bool(_campaign, "change_phase",
					[GameEnumsScript.FiveParcsecsCampaignPhase.UPKEEP])
				assert_true(phase_success, "Should change to UPKEEP phase")
				await get_tree().process_frame
				
				phase_success = TypeSafeMixin._call_node_method_bool(_campaign, "change_phase",
					[GameEnumsScript.FiveParcsecsCampaignPhase.CAMPAIGN])
				assert_true(phase_success, "Should change to CAMPAIGN phase")
				await get_tree().process_frame
		)
		
		verify_performance_metrics(metrics, {
			"average_fps": MIN_FPS,
			"minimum_fps": MIN_FPS * 0.67,
			"memory_delta_kb": MIN_MEMORY_MB * 1024,
			"draw_calls_delta": 50
		})
		
		print_debug("Performance results for %s:" % resolution)
		print_debug("- Average FPS: %.2f" % metrics.get("average_fps", 0.0))
		print_debug("- 95th percentile FPS: %.2f" % metrics.get("95th_percentile_fps", 0.0))
		print_debug("- Minimum FPS: %.2f" % metrics.get("minimum_fps", 0.0))
		print_debug("- Memory Delta: %.2f KB" % metrics.get("memory_delta_kb", 0.0))
		print_debug("- Draw Calls Delta: %d" % metrics.get("draw_calls_delta", 0))
		print_debug("- Objects Delta: %d" % metrics.get("objects_delta", 0))

func test_mobile_save_load() -> void:
	print_debug("Testing mobile save/load functionality")
	
	# Create initial campaign
	var campaign_config: Dictionary = {
		"name": "Mobile Save Test",
		"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
		"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnumsScript.CrewSize.FOUR,
		"use_story_track": true
	}
	
	_campaign = TypeSafeMixin._call_node_method(_campaign_system, "create_campaign", [campaign_config]) as Resource
	if not _campaign:
		assert_true(false, "Campaign should be created successfully")
		return
	
	watch_signals(_campaign)
	
	var start_success: bool = TypeSafeMixin._call_node_method_bool(_campaign, "start_campaign", [])
	assert_true(start_success, "Campaign should start successfully")
	
	# Test save/load under different mobile conditions
	var save_load_resolutions: Array[String] = ["phone_portrait", "phone_landscape"]
	
	for resolution in save_load_resolutions:
		print_debug("Testing save/load in %s mode..." % resolution)
		await simulate_mobile_environment(resolution)
		await stabilize_engine(STABILIZE_TIME)
		
		# Save campaign
		var save_metrics: Dictionary = await measure_performance(
			func() -> void:
				var save_success: bool = TypeSafeMixin._call_node_method_bool(_campaign_system, "save_campaign", [_campaign])
				assert_true(save_success, "Should save campaign successfully")
				await get_tree().process_frame
		)
		
		# Load campaign
		var load_metrics: Dictionary = await measure_performance(
			func() -> void:
				var load_success: bool = TypeSafeMixin._call_node_method_bool(_campaign_system, "load_campaign", ["Mobile Save Test"])
				assert_true(load_success, "Should load campaign successfully")
				await get_tree().process_frame
		)
		
		verify_performance_metrics(save_metrics, {
			"average_fps": MIN_FPS,
			"minimum_fps": MIN_FPS * 0.67,
			"memory_delta_kb": MIN_MEMORY_MB * 1024,
			"draw_calls_delta": 25
		})
		
		verify_performance_metrics(load_metrics, {
			"average_fps": MIN_FPS,
			"minimum_fps": MIN_FPS * 0.67,
			"memory_delta_kb": MIN_MEMORY_MB * 1024,
			"draw_calls_delta": 25
		})
		
		print_debug("Save/Load performance in %s:" % resolution)
		print_debug("Save operation:")
		print_debug("- Average FPS: %.2f" % save_metrics.get("average_fps", 0.0))
		print_debug("- Memory Delta: %.2f KB" % save_metrics.get("memory_delta_kb", 0.0))
		print_debug("Load operation:")
		print_debug("- Average FPS: %.2f" % load_metrics.get("average_fps", 0.0))
		print_debug("- Memory Delta: %.2f KB" % load_metrics.get("memory_delta_kb", 0.0))

func test_mobile_input_handling() -> void:
	print_debug("Testing mobile input handling")
	
	# Create and start campaign
	var campaign_config: Dictionary = {
		"name": "Mobile Input Test",
		"difficulty": GameEnumsScript.DifficultyLevel.NORMAL,
		"victory_type": GameEnumsScript.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnumsScript.CrewSize.FOUR,
		"use_story_track": true
	}
	
	_campaign = TypeSafeMixin._call_node_method(_campaign_system, "create_campaign", [campaign_config]) as Resource
	if not _campaign:
		assert_true(false, "Campaign should be created successfully")
		return
	
	watch_signals(_campaign)
	
	var start_success: bool = TypeSafeMixin._call_node_method_bool(_campaign, "start_campaign", [])
	assert_true(start_success, "Campaign should start successfully")
	
	# Test touch input for common campaign actions
	var touch_actions: Array[Dictionary] = [
		{"position": Vector2(100, 100), "action": "select_character"},
		{"position": Vector2(200, 200), "action": "open_inventory"},
		{"position": Vector2(300, 300), "action": "start_mission"}
	]
	
	for action in touch_actions:
		var position: Vector2 = action.get("position", Vector2.ZERO)
		var action_name: String = action.get("action", "")
		
		# Simulate touch
		await simulate_touch_event(position, true)
		await get_tree().process_frame
		await simulate_touch_event(position, false)
		await get_tree().process_frame
		
		verify_signal_emitted(_campaign, action_name + "_triggered",
			"Campaign should respond to touch input for " + action_name)
		
		# Test touch responsiveness
		var response_metrics: Dictionary = await measure_performance(
			func() -> void:
				await simulate_touch_event(position, true)
				await get_tree().process_frame
				await simulate_touch_event(position, false)
				await get_tree().process_frame
		)
		
		verify_performance_metrics(response_metrics, {
			"average_fps": MIN_FPS,
			"minimum_fps": MIN_FPS * 0.67,
			"memory_delta_kb": 256.0,
			"draw_calls_delta": 10
		})
		
		print_debug("Touch response performance for %s:" % action_name)
		print_debug("- Average FPS: %.2f" % response_metrics.get("average_fps", 0.0))
		print_debug("- Response Time: %.2f ms" % (1000.0 / response_metrics.get("average_fps", 60.0)))

# Helper function to simulate touch events for mobile tests
func simulate_touch_event(position: Vector2, is_pressed: bool) -> void:
	# Create a screen touch event
	var touch_event := InputEventScreenTouch.new()
	touch_event.position = position
	touch_event.pressed = is_pressed
	Input.parse_input_event(touch_event)
	
	# Also simulate a mouse event for platforms that don't fully support touch
	var mouse_event := InputEventMouseButton.new()
	mouse_event.position = position
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = is_pressed
	Input.parse_input_event(mouse_event)
	
	await get_tree().process_frame
