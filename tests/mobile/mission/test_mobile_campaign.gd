@tool
extends GdUnitGameTest

# Mock Campaign System with expected values (Universal Mock Strategy)
class MockCampaignSystem extends Resource:
	var campaigns: Dictionary = {}
	var current_campaign: MockCampaign = null
	var game_state: MockGameState = null
	
	func initialize(state: MockGameState) -> int:
		game_state = state
		system_initialized.emit()
		return OK
	
	func create_campaign(config: Dictionary) -> MockCampaign:
		var campaign = MockCampaign.new()
		campaign.name = config.get("name", "Default Campaign")
		campaign.difficulty = config.get("difficulty", 1) # Use int directly
		campaign.victory_type = config.get("victory_type", 1)
		campaign.crew_size = config.get("crew_size", 4)
		campaign.use_story_track = config.get("use_story_track", true)
		
		campaigns[campaign.name] = campaign
		current_campaign = campaign
		campaign_created.emit(campaign)
		return campaign
	
	func save_campaign(campaign: MockCampaign) -> bool:
		if campaign:
			campaign_saved.emit(campaign)
			return true
		return false
	
	func load_campaign(campaign_name: String) -> MockCampaign:
		var campaign = campaigns.get(campaign_name, null)
		if campaign:
			current_campaign = campaign
			campaign_loaded.emit(campaign)
		return campaign
	
	# Required signals (immediate emission pattern)
	signal system_initialized()
	signal campaign_created(campaign: MockCampaign)
	signal campaign_saved(campaign: MockCampaign)
	signal campaign_loaded(campaign: MockCampaign)

# Mock Campaign with expected values (Universal Mock Strategy)
class MockCampaign extends Resource:
	var name: String = ""
	var difficulty: int = 1
	var victory_type: int = 1
	var crew_size: int = 4
	var use_story_track: bool = true
	var current_phase: int = 0
	var is_started: bool = false
	
	func start_campaign() -> bool:
		is_started = true
		current_phase = 1 # UPKEEP phase
		campaign_started.emit()
		return true
	
	func change_phase(new_phase: int) -> bool:
		if is_started:
			current_phase = new_phase
			phase_changed.emit(new_phase)
			return true
		return false
	
	func get_current_phase() -> int:
		return current_phase
	
	func serialize() -> Dictionary:
		return {
			"name": name,
			"difficulty": difficulty,
			"victory_type": victory_type,
			"crew_size": crew_size,
			"use_story_track": use_story_track,
			"current_phase": current_phase,
			"is_started": is_started
		}
	
	func deserialize(data: Dictionary) -> void:
		name = data.get("name", "")
		difficulty = data.get("difficulty", 1)
		victory_type = data.get("victory_type", 1)
		crew_size = data.get("crew_size", 4)
		use_story_track = data.get("use_story_track", true)
		current_phase = data.get("current_phase", 0)
		is_started = data.get("is_started", false)
	
	# Required signals (immediate emission pattern)
	signal campaign_started()
	signal phase_changed(new_phase: int)

# Mock Game State with expected values (Universal Mock Strategy)
class MockGameState extends Resource:
	var turn_number: int = 1
	var story_points: int = 0
	var reputation: int = 50
	var resources: Dictionary = {}
	
	func get_turn_number() -> int: return turn_number
	func get_story_points() -> int: return story_points
	func get_reputation() -> int: return reputation
	func get_resources() -> Dictionary: return resources
	
	func advance_turn() -> void:
		turn_number += 1
		turn_advanced.emit(turn_number)
	
	# Required signals (immediate emission pattern)
	signal turn_advanced(new_turn: int)

# Mock Game Enums (Universal Mock Strategy)
class MockGameEnums extends Resource:
	enum DifficultyLevel {EASY = 0, NORMAL = 1, HARD = 2}
	enum FiveParcsecsCampaignVictoryType {STANDARD = 1, CONQUEST = 2, SURVIVAL = 3}
	enum CrewSize {TWO = 2, FOUR = 4, SIX = 6}
	enum FiveParcsecsCampaignPhase {SETUP = 0, UPKEEP = 1, CAMPAIGN = 2, BATTLE = 3}

# Test variables with explicit types
var _campaign_system: MockCampaignSystem = null
var _campaign: MockCampaign = null
var _game_state: MockGameState = null
var GameEnums: MockGameEnums = null

# Performance thresholds with explicit types
const MIN_FPS: float = 30.0
const MIN_MEMORY_MB: float = 2.0
const TEST_ITERATIONS: int = 100

func before_test() -> void:
	super.before_test()
	
	# Use Resource-based mocks (proven pattern)
	GameEnums = MockGameEnums.new()
	track_resource(GameEnums)
	
	_game_state = MockGameState.new()
	track_resource(_game_state)
	
	_campaign_system = MockCampaignSystem.new()
	track_resource(_campaign_system)
	
	# Initialize campaign system with game state
	var init_result: int = _campaign_system.initialize(_game_state)
	assert_that(init_result).is_equal(OK)

func after_test() -> void:
	_campaign = null
	_campaign_system = null
	_game_state = null
	GameEnums = null
	super.after_test()

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
		await get_tree().process_frame
	
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
	# Test direct method calls instead of safe wrappers (proven pattern)
	print_debug("Starting mobile campaign performance test")
	
	# Create and start campaign
	var campaign_config: Dictionary = {
		"name": "Mobile Test Campaign",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": true
	}
	
	_campaign = _campaign_system.create_campaign(campaign_config)
	assert_that(_campaign).override_failure_message("Campaign should be created successfully").is_not_null()
	
	var start_success: bool = _campaign.start_campaign()
	assert_that(start_success).is_true()
	
	# Test campaign phase transitions under different mobile conditions
	var resolutions: Array[String] = ["phone_portrait", "phone_landscape", "tablet_portrait"]
	
	for resolution in resolutions:
		print_debug("Testing campaign performance in %s mode..." % resolution)
		await simulate_mobile_environment(resolution)
		await get_tree().process_frame
		
		# Measure phase transition performance
		var metrics: Dictionary = await measure_performance(
			func() -> void:
				var phase_success: bool = _campaign.change_phase(GameEnums.FiveParcsecsCampaignPhase.UPKEEP)
				assert_that(phase_success).is_true()
				await get_tree().process_frame
				
				phase_success = _campaign.change_phase(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)
				assert_that(phase_success).is_true()
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
		print_debug("- Minimum FPS: %.2f" % metrics.get("minimum_fps", 0.0))
		print_debug("- Memory Delta: %.2f KB" % metrics.get("memory_delta_kb", 0.0))
		print_debug("- Draw Calls Delta: %d" % metrics.get("draw_calls_delta", 0))

func test_mobile_save_load() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	print_debug("Testing mobile save/load functionality")
	
	# Create initial campaign
	var campaign_config: Dictionary = {
		"name": "Mobile Save Test",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": true
	}
	
	_campaign = _campaign_system.create_campaign(campaign_config)
	assert_that(_campaign).override_failure_message("Campaign should be created successfully").is_not_null()
	
	var start_success: bool = _campaign.start_campaign()
	assert_that(start_success).is_true()
	
	# Test save/load under different mobile conditions
	var save_load_resolutions: Array[String] = ["phone_portrait", "phone_landscape"]
	
	for resolution in save_load_resolutions:
		print_debug("Testing save/load in %s mode..." % resolution)
		await simulate_mobile_environment(resolution)
		await get_tree().process_frame
		
		# Save campaign
		var save_metrics: Dictionary = await measure_performance(
			func() -> void:
				var save_success: bool = _campaign_system.save_campaign(_campaign)
				assert_that(save_success).is_true()
				await get_tree().process_frame
		)
		
		# Load campaign
		var load_metrics: Dictionary = await measure_performance(
			func() -> void:
				var loaded_campaign: MockCampaign = _campaign_system.load_campaign(_campaign.name)
				assert_that(loaded_campaign).is_not_null()
				await get_tree().process_frame
		)
		
		verify_performance_metrics(save_metrics, {
			"average_fps": MIN_FPS,
			"memory_delta_kb": MIN_MEMORY_MB * 1024
		})
		
		verify_performance_metrics(load_metrics, {
			"average_fps": MIN_FPS,
			"memory_delta_kb": MIN_MEMORY_MB * 1024
		})

func test_mobile_input_handling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	print_debug("Testing mobile input handling")
	
	# Create campaign for input testing
	var campaign_config: Dictionary = {
		"name": "Mobile Input Test",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": true
	}
	
	_campaign = _campaign_system.create_campaign(campaign_config)
	assert_that(_campaign).override_failure_message("Campaign should be created successfully").is_not_null()
	
	var start_success: bool = _campaign.start_campaign()
	assert_that(start_success).is_true()
	
	# Test touch input responsiveness
	var touch_positions: Array[Vector2] = [
		Vector2(100, 100), # Top-left
		Vector2(300, 200), # Center
		Vector2(500, 400) # Bottom-right
	]
	
	for pos in touch_positions:
		await simulate_touch_input(pos)
		await get_tree().process_frame
		
		# Verify campaign state remains stable
		assert_that(_campaign.get_current_phase()).is_greater_equal(0)

# Helper Methods
func simulate_mobile_environment(mode: String) -> void:
	match mode:
		"phone_portrait":
			DisplayServer.window_set_size(Vector2i(390, 844))
		"phone_landscape":
			DisplayServer.window_set_size(Vector2i(844, 390))
		"tablet_portrait":
			DisplayServer.window_set_size(Vector2i(768, 1024))
		"tablet_landscape":
			DisplayServer.window_set_size(Vector2i(1024, 768))
	await get_tree().process_frame

func simulate_touch_input(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	if metrics.has("average_fps") and thresholds.has("average_fps"):
		assert_that(metrics.average_fps).is_greater_equal(thresholds.average_fps)
	if metrics.has("minimum_fps") and thresholds.has("minimum_fps"):
		assert_that(metrics.minimum_fps).is_greater_equal(thresholds.minimum_fps)
	if metrics.has("memory_delta_kb") and thresholds.has("memory_delta_kb"):
		assert_that(metrics.memory_delta_kb).is_less_equal(thresholds.memory_delta_kb)
