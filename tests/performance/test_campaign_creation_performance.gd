@tool
extends GdUnitGameTest

## Performance benchmarks for campaign creation workflows
## Tests memory usage, execution time, and scalability of core systems

# Performance test imports
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const TestDataFactory = preload("res://tests/fixtures/TestDataFactory.gd")

# Performance tracking
var _performance_samples: Array[Dictionary] = []
var _memory_baseline: float
var _tracked_objects: Array[Node] = []

# Performance thresholds (in milliseconds)
const PERFORMANCE_THRESHOLDS = {
	"campaign_creation": 100.0,  # Max 100ms for complete campaign creation
	"state_validation": 10.0,    # Max 10ms for validation
	"data_serialization": 50.0,  # Max 50ms for save/load
	"crew_generation": 25.0,     # Max 25ms for crew setup
	"equipment_generation": 30.0  # Max 30ms for equipment generation
}

# Memory thresholds (in KB)
const MEMORY_THRESHOLDS = {
	"campaign_creation": 512.0,  # Max 512KB for campaign creation
	"state_manager": 128.0,      # Max 128KB for state manager
	"large_crew": 256.0          # Max 256KB for 8-member crew
}

func before_test() -> void:
	super.before_test()
	_memory_baseline = _get_memory_usage()
	_performance_samples.clear()

func after_test() -> void:
	# Clean up tracked objects
	for obj in _tracked_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_tracked_objects.clear()
	
	# Force garbage collection
	await get_tree().process_frame
	
	super.after_test()

func _get_memory_usage() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0  # Convert to KB

func _measure_performance(operation_name: String, operation: Callable) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var start_memory = _get_memory_usage()
	
	var result = await operation.call()
	
	var end_time = Time.get_ticks_msec()
	var end_memory = _get_memory_usage()
	
	var performance_data = {
		"operation": operation_name,
		"execution_time_ms": end_time - start_time,
		"memory_delta_kb": end_memory - start_memory,
		"start_memory_kb": start_memory,
		"end_memory_kb": end_memory,
		"result": result,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	_performance_samples.append(performance_data)
	return performance_data

func test_campaign_creation_performance() -> void:
	"""Test performance of complete campaign creation workflow."""
	var performance_data = await _measure_performance("complete_campaign_creation", func():
		# Create all components
		var state_manager = CampaignCreationStateManager.new()
		add_child(state_manager)
		_tracked_objects.append(state_manager)
		
		# Set up all phases with test data
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, 
			TestDataFactory.create_test_campaign_config("Performance Test"))
		
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, 
			TestDataFactory.create_test_crew(4, true))
		
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION, 
			{"character_data": TestDataFactory.create_test_captain()})
		
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT, 
			TestDataFactory.create_test_ship("Performance Ship"))
		
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, 
			TestDataFactory.create_test_equipment())
		
		# Complete campaign creation
		return state_manager.complete_campaign_creation()
	)
	
	# Validate performance thresholds
	assert_that(performance_data.execution_time_ms).is_less_than(PERFORMANCE_THRESHOLDS.campaign_creation)
	assert_that(performance_data.memory_delta_kb).is_less_than(MEMORY_THRESHOLDS.campaign_creation)
	assert_that(performance_data.result).is_not_empty()
	
	print("Campaign Creation Performance:")
	print("  Execution Time: %.2f ms (threshold: %.2f ms)" % [performance_data.execution_time_ms, PERFORMANCE_THRESHOLDS.campaign_creation])
	print("  Memory Usage: %.2f KB (threshold: %.2f KB)" % [performance_data.memory_delta_kb, MEMORY_THRESHOLDS.campaign_creation])

func test_state_validation_performance() -> void:
	"""Test performance of state validation operations."""
	# Set up state manager with test data
	var state_manager = CampaignCreationStateManager.new()
	add_child(state_manager)
	_tracked_objects.append(state_manager)
	
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, 
		TestDataFactory.create_test_campaign_config())
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, 
		TestDataFactory.create_test_crew(3, true))
	
	var performance_data = await _measure_performance("state_validation", func():
		return state_manager.get_validation_summary()
	)
	
	# Validate performance
	assert_that(performance_data.execution_time_ms).is_less_than(PERFORMANCE_THRESHOLDS.state_validation)
	assert_that(performance_data.result.completion_percentage).is_greater_than(0.0)
	
	print("State Validation Performance:")
	print("  Execution Time: %.2f ms (threshold: %.2f ms)" % [performance_data.execution_time_ms, PERFORMANCE_THRESHOLDS.state_validation])
	print("  Memory Usage: %.2f KB" % performance_data.memory_delta_kb)

func test_serialization_performance() -> void:
	"""Test performance of data serialization and deserialization."""
	# Set up complete campaign data
	var state_manager = CampaignCreationStateManager.new()
	add_child(state_manager)
	_tracked_objects.append(state_manager)
	
	var complete_campaign = TestDataFactory.create_complete_test_campaign()
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, complete_campaign.config)
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, complete_campaign.crew)
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION, {"character_data": complete_campaign.captain})
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT, complete_campaign.ship)
	state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, complete_campaign.equipment)
	
	# Test serialization performance
	var serialize_data = await _measure_performance("data_serialization", func():
		return state_manager.serialize_state()
	)
	
	assert_that(serialize_data.execution_time_ms).is_less_than(PERFORMANCE_THRESHOLDS.data_serialization)
	assert_that(serialize_data.result).is_not_empty()
	
	# Test deserialization performance  
	var new_state_manager = CampaignCreationStateManager.new()
	add_child(new_state_manager)
	_tracked_objects.append(new_state_manager)
	
	var deserialize_data = await _measure_performance("data_deserialization", func():
		return new_state_manager.deserialize_state(serialize_data.result)
	)
	
	assert_that(deserialize_data.execution_time_ms).is_less_than(PERFORMANCE_THRESHOLDS.data_serialization)
	assert_that(deserialize_data.result).is_true()
	
	print("Serialization Performance:")
	print("  Serialize Time: %.2f ms" % serialize_data.execution_time_ms)
	print("  Deserialize Time: %.2f ms" % deserialize_data.execution_time_ms)
	print("  Total Time: %.2f ms (threshold: %.2f ms)" % [serialize_data.execution_time_ms + deserialize_data.execution_time_ms, PERFORMANCE_THRESHOLDS.data_serialization])

func test_large_crew_performance() -> void:
	"""Test performance with maximum crew size (8 members)."""
	var performance_data = await _measure_performance("large_crew_creation", func():
		return TestDataFactory.create_test_crew(8, true)
	)
	
	assert_that(performance_data.execution_time_ms).is_less_than(PERFORMANCE_THRESHOLDS.crew_generation)
	assert_that(performance_data.memory_delta_kb).is_less_than(MEMORY_THRESHOLDS.large_crew)
	assert_that(performance_data.result.size).is_equal(8)
	
	print("Large Crew Performance:")
	print("  Execution Time: %.2f ms (threshold: %.2f ms)" % [performance_data.execution_time_ms, PERFORMANCE_THRESHOLDS.crew_generation])
	print("  Memory Usage: %.2f KB (threshold: %.2f KB)" % [performance_data.memory_delta_kb, MEMORY_THRESHOLDS.large_crew])

func test_equipment_generation_performance() -> void:
	"""Test performance of equipment generation with large inventories."""
	var performance_data = await _measure_performance("equipment_generation", func():
		# Generate equipment for multiple crew members
		var equipment_sets = []
		for i in range(8):  # 8 crew members worth of equipment
			equipment_sets.append(TestDataFactory.create_test_equipment())
		return equipment_sets
	)
	
	assert_that(performance_data.execution_time_ms).is_less_than(PERFORMANCE_THRESHOLDS.equipment_generation)
	assert_that(performance_data.result.size()).is_equal(8)
	
	print("Equipment Generation Performance:")
	print("  Execution Time: %.2f ms (threshold: %.2f ms)" % [performance_data.execution_time_ms, PERFORMANCE_THRESHOLDS.equipment_generation])
	print("  Memory Usage: %.2f KB" % performance_data.memory_delta_kb)

func test_campaign_manager_integration_performance() -> void:
	"""Test performance of campaign manager with real systems integration."""
	var performance_data = await _measure_performance("campaign_manager_integration", func():
		# Initialize real systems
		var game_state = GameState.new()
		add_child(game_state)
		_tracked_objects.append(game_state)
		
		var campaign_manager = CampaignManager.new()
		campaign_manager.game_state = game_state
		add_child(campaign_manager)
		_tracked_objects.append(campaign_manager)
		
		# Allow initialization
		await get_tree().process_frame
		
		# Create and start multiple missions
		var missions = []
		for i in range(3):
			var mission_config = TestDataFactory.create_test_mission("patrol_%d" % i)
			var mission = campaign_manager.create_mission(0, mission_config)  # PATROL = 0
			missions.append(mission)
		
		# Test mission workflow performance
		for mission in missions:
			campaign_manager.start_mission(mission)
			campaign_manager.complete_mission(mission)
		
		return {
			"missions_created": missions.size(),
			"completed_missions": campaign_manager.get_completed_missions().size()
		}
	)
	
	assert_that(performance_data.result.missions_created).is_equal(3)
	assert_that(performance_data.result.completed_missions).is_equal(3)
	
	print("Campaign Manager Integration Performance:")
	print("  Execution Time: %.2f ms" % performance_data.execution_time_ms)
	print("  Memory Usage: %.2f KB" % performance_data.memory_delta_kb)

func test_stress_test_multiple_campaigns() -> void:
	"""Stress test creating multiple campaigns to check for memory leaks."""
	var campaign_count = 10
	var initial_memory = _get_memory_usage()
	
	var performance_data = await _measure_performance("stress_test_campaigns", func():
		var campaigns = []
		
		for i in range(campaign_count):
			var state_manager = CampaignCreationStateManager.new()
			add_child(state_manager)
			_tracked_objects.append(state_manager)
			
			# Create complete campaign
			var campaign_data = TestDataFactory.create_complete_test_campaign()
			campaign_data.config.campaign_name = "Stress Test %d" % i
			
			state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, campaign_data.config)
			state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, campaign_data.crew)
			state_manager.set_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION, {"character_data": campaign_data.captain})
			state_manager.set_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT, campaign_data.ship)
			state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, campaign_data.equipment)
			
			var completed_campaign = state_manager.complete_campaign_creation()
			campaigns.append(completed_campaign)
		
		return campaigns
	)
	
	var final_memory = _get_memory_usage()
	var memory_per_campaign = (final_memory - initial_memory) / campaign_count
	
	assert_that(performance_data.result.size()).is_equal(campaign_count)
	assert_that(memory_per_campaign).is_less_than(MEMORY_THRESHOLDS.campaign_creation)
	
	print("Stress Test Results:")
	print("  Campaigns Created: %d" % campaign_count)
	print("  Total Execution Time: %.2f ms" % performance_data.execution_time_ms)
	print("  Average Time per Campaign: %.2f ms" % (performance_data.execution_time_ms / campaign_count))
	print("  Memory per Campaign: %.2f KB (threshold: %.2f KB)" % [memory_per_campaign, MEMORY_THRESHOLDS.campaign_creation])

func test_random_data_performance() -> void:
	"""Test performance with randomly generated test data to simulate real usage."""
	var iterations = 50
	var total_time = 0.0
	
	for i in range(iterations):
		var performance_data = await _measure_performance("random_character_%d" % i, func():
			return TestDataFactory.get_random_test_character()
		)
		total_time += performance_data.execution_time_ms
	
	var average_time = total_time / iterations
	
	assert_that(average_time).is_less_than(5.0)  # Average should be under 5ms per character
	
	print("Random Data Generation Performance:")
	print("  Iterations: %d" % iterations)
	print("  Total Time: %.2f ms" % total_time)
	print("  Average Time per Character: %.2f ms" % average_time)

func _after_test() -> void:
	# Print performance summary
	if _performance_samples.size() > 0:
		print("\n=== PERFORMANCE SUMMARY ===")
		var total_time = 0.0
		var total_memory = 0.0
		
		for sample in _performance_samples:
			total_time += sample.execution_time_ms
			total_memory += sample.memory_delta_kb
		
		print("Total Operations: %d" % _performance_samples.size())
		print("Total Execution Time: %.2f ms" % total_time)
		print("Total Memory Usage: %.2f KB" % total_memory)
		print("Average Time per Operation: %.2f ms" % (total_time / _performance_samples.size()))
		print("========================\n")
	
	super.after_test()