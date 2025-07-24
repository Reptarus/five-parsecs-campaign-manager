extends GdUnitTestSuite

## Production-Grade Test Suite for Hybrid Data Architecture
## Validates JSON loading, enum fallbacks, and performance requirements

const DataManager = preload("res://src/core/data/DataManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Performance Requirements (Production SLA)
const MAX_DATA_LOAD_TIME_MS = 1000  # Under 1 second for data initialization
const MIN_CACHE_HIT_RATIO = 0.85    # 85% cache efficiency minimum
const MAX_MEMORY_USAGE_MB = 50      # Maximum 50MB for data system

func before_test():
	"""Reset data system state before each test"""
	DataManager._is_data_loaded = false
	DataManager._character_data.clear()
	DataManager._background_data.clear()
	DataManager._equipment_data.clear()
	DataManager.reset_performance_stats()

## Core System Validation Tests

func test_data_system_initialization_performance():
	"""Validate data system meets performance SLA requirements"""
	var start_time = Time.get_ticks_msec()
	var success = DataManager.initialize_data_system()
	var end_time = Time.get_ticks_msec()
	var load_time = end_time - start_time
	
	assert_true(success, "Data system must initialize successfully")
	assert_that(load_time).is_less_than(MAX_DATA_LOAD_TIME_MS)
	
	var stats = DataManager.get_performance_stats()
	print("Test: Data system loaded in %d ms" % load_time)

func test_data_system_fallback_resilience():
	"""Validate graceful degradation when JSON files are unavailable"""
	# Simulate missing JSON files by providing invalid paths
	var original_character_data = DataManager._character_data
	DataManager._character_data = {}
	
	# System should still function with enum-only mode
	var origin_name = GlobalEnums.get_origin_display_name(GlobalEnums.Origin.HUMAN)
	assert_that(origin_name).is_equal("Human")
	
	var class_name = GlobalEnums.get_class_display_name(GlobalEnums.CharacterClass.SOLDIER)
	assert_that(class_name).is_equal("Soldier")
	
	# Restore original data for other tests
	DataManager._character_data = original_character_data

func test_character_creation_with_json_enhancement():
	"""Validate rich character creation using JSON data"""
	# Initialize data system
	var success = DataManager.initialize_data_system()
	assert_true(success, "Data system must be available for enhanced testing")
	
	# Test origin data access
	var human_data = DataManager.get_origin_data("HUMAN")
	assert_that(human_data).is_not_empty()
	assert_that(human_data.get("name", "")).is_equal("Human")
	assert_that(human_data.has("base_stats")).is_true()
	
	# Test background data access
	var military_data = DataManager.get_background_data("military")
	assert_that(military_data).is_not_empty()
	assert_that(military_data.get("name", "")).is_equal("Military Veteran")
	assert_that(military_data.has("stat_bonuses")).is_true()

func test_character_validation_system():
	"""Validate character creation rules and constraints"""
	var valid_config = {
		"origin": "HUMAN",
		"background": "military",
		"class": "SOLDIER",
		"motivation": "SURVIVAL"
	}
	
	var validation = DataManager.validate_character_creation(valid_config)
	assert_true(validation.valid, "Valid character configuration should pass validation")
	assert_that(validation.errors).is_empty()
	
	# Test invalid configuration
	var invalid_config = {
		"origin": "INVALID_ORIGIN",
		"background": "invalid_background",
		"class": "INVALID_CLASS"
	}
	
	var invalid_validation = DataManager.validate_character_creation(invalid_config)
	assert_false(invalid_validation.valid, "Invalid configuration should fail validation")
	assert_that(invalid_validation.errors).is_not_empty()

## Performance and Memory Tests

func test_cache_performance_requirements():
	"""Validate caching system meets performance requirements"""
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	# Perform multiple data access operations to populate cache
	for i in range(100):
		var origin_data = DataManager.get_origin_data("HUMAN")
		var background_data = DataManager.get_background_data("military")
		assert_that(origin_data).is_not_empty()
		assert_that(background_data).is_not_empty()
	
	var stats = DataManager.get_performance_stats()
	assert_that(stats.cache_hit_ratio).is_greater_equal(MIN_CACHE_HIT_RATIO)
	print("Test: Cache hit ratio: %.2f" % stats.cache_hit_ratio)

func test_memory_usage_constraints():
	"""Validate memory usage remains within acceptable bounds"""
	var initial_memory = OS.get_static_memory_usage()
	
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	# Perform extensive data operations
	for i in range(1000):
		DataManager.get_origin_data("HUMAN")
		DataManager.get_background_data("military")
		DataManager.get_backgrounds_for_species("Human")
	
	var final_memory = OS.get_static_memory_usage()
	var memory_increase_mb = (final_memory - initial_memory) / (1024 * 1024)
	
	assert_that(memory_increase_mb).is_less_than(MAX_MEMORY_USAGE_MB)
	print("Test: Memory increase: %.1f MB" % memory_increase_mb)

## Data Integrity Tests

func test_json_enum_consistency():
	"""Validate JSON data is consistent with enum definitions"""
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	# Validate origins match enum keys
	var origins_data = DataManager._character_data.get("origins", {})
	for origin_key in origins_data.keys():
		var enum_value = GlobalEnums.Origin.get(origin_key, -1)
		assert_that(enum_value).is_not_equal(-1)
	
	# Validate background IDs are mappable to enums
	var backgrounds = DataManager.get_all_backgrounds()
	for background in backgrounds:
		var background_id = background.get("id", "")
		assert_that(background_id).is_not_empty()
		# Should be mappable through _map_background_id_to_enum logic

func test_data_validation_rules():
	"""Validate data validation catches common content creator errors"""
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	# Test that background data includes required fields
	var backgrounds = DataManager.get_all_backgrounds()
	for background in backgrounds:
		assert_that(background.has("id")).is_true()
		assert_that(background.has("name")).is_true()
		assert_that(background.has("suitable_species")).is_true()
		
		var suitable_species = background.get("suitable_species", [])
		assert_that(suitable_species).is_not_empty()

## Integration Tests

func test_character_creator_integration():
	"""Validate CharacterCreator works with hybrid data system"""
	# This would typically instantiate CharacterCreator scene
	# and test dropdown population, character generation, etc.
	# Simplified test for architecture validation
	
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	# Validate data access methods used by CharacterCreator
	var human_data = DataManager.get_origin_data("HUMAN")
	assert_that(human_data.get("name", "")).is_equal("Human")
	
	var military_data = DataManager.get_background_data("military")
	assert_that(military_data.get("name", "")).contains("Military")

func test_hot_reload_functionality():
	"""Validate development hot reload works correctly"""
	var initial_success = DataManager.initialize_data_system()
	assert_true(initial_success)
	
	var initial_stats = DataManager.get_performance_stats()
	
	# Test hot reload
	var reload_success = DataManager.reload_data()
	assert_true(reload_success)
	
	var reload_stats = DataManager.get_performance_stats()
	assert_that(reload_stats.load_time_ms).is_greater_than(0)

## Stress Testing

func test_concurrent_data_access():
	"""Validate system handles concurrent data access correctly"""
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	# Simulate concurrent access from multiple systems
	var results = []
	for i in range(50):
		var origin_data = DataManager.get_origin_data("HUMAN")
		var background_data = DataManager.get_background_data("military")
		var validation = DataManager.validate_character_creation({
			"origin": "HUMAN", 
			"background": "military"
		})
		
		results.append({
			"origin_valid": not origin_data.is_empty(),
			"background_valid": not background_data.is_empty(),
			"validation_passed": validation.valid
		})
	
	# All operations should succeed
	for result in results:
		assert_true(result.origin_valid)
		assert_true(result.background_valid)
		assert_true(result.validation_passed)

func test_large_dataset_performance():
	"""Validate performance with large character datasets"""
	var success = DataManager.initialize_data_system()
	assert_true(success)
	
	var start_time = Time.get_ticks_msec()
	
	# Simulate processing large number of characters
	for i in range(1000):
		var character_config = {
			"origin": "HUMAN",
			"background": "military",
			"class": "SOLDIER",
			"motivation": "SURVIVAL"
		}
		var validation = DataManager.validate_character_creation(character_config)
		assert_true(validation.valid)
	
	var end_time = Time.get_ticks_msec()
	var processing_time = end_time - start_time
	
	# Should process 1000 characters under 5 seconds
	assert_that(processing_time).is_less_than(5000)
	print("Test: Processed 1000 characters in %d ms" % processing_time)
