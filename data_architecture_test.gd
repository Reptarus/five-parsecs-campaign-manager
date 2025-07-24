@tool
extends RefCounted
class_name HybridDataArchitectureTester

## Comprehensive Testing Script for Five Parsecs Hybrid Data Architecture
## Execute this script in Godot console to validate the production-ready data system

const PERFORMANCE_TARGETS = {
	"max_init_time_ms": 1000,
	"min_cache_hit_ratio": 0.90,
	"max_memory_increase_mb": 50,
	"min_throughput_ops_per_sec": 1000
}

var test_results = {}
var phase_results = {}

## Phase 1: Infrastructure Validation
func execute_phase_1_infrastructure_validation() -> Dictionary:
	print("=== PHASE 1: Infrastructure Validation ===")
	var results = {
		"passed": true,
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	# Test DataManager autoload accessibility
	if DataManager == null:
		results.passed = false
		results.errors.append("DataManager autoload not accessible")
		return results
	
	print("✓ DataManager autoload accessible")
	
	# Test GlobalEnums autoload accessibility  
	if GlobalEnums == null:
		results.passed = false
		results.errors.append("GlobalEnums autoload not accessible")
		return results
	
	print("✓ GlobalEnums autoload accessible")
	
	# Test data system initialization performance
	var start_time = Time.get_ticks_msec()
	var init_success = DataManager.initialize_data_system()
	var end_time = Time.get_ticks_msec()
	var load_time = end_time - start_time
	
	results.metrics["initialization_time_ms"] = load_time
	results.metrics["initialization_success"] = init_success
	
	if not init_success:
		results.passed = false
		results.errors.append("Data system initialization failed")
		return results
	
	print("✓ Data system initialization: SUCCESS")
	print("✓ Load time: %d ms" % load_time)
	
	# Performance target validation
	if load_time > PERFORMANCE_TARGETS.max_init_time_ms:
		results.warnings.append("Load time (%d ms) exceeds target (%d ms)" % [load_time, PERFORMANCE_TARGETS.max_init_time_ms])
		print("⚠ Performance target (<%dms): FAIL" % PERFORMANCE_TARGETS.max_init_time_ms)
	else:
		print("✓ Performance target (<%dms): PASS" % PERFORMANCE_TARGETS.max_init_time_ms)
	
	print("Phase 1 completed: %s\n" % ("PASS" if results.passed else "FAIL"))
	return results

## Phase 2: JSON Data Integrity Testing
func execute_phase_2_json_integrity() -> Dictionary:
	print("=== PHASE 2: JSON Data Integrity ===")
	var results = {
		"passed": true,
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	# Test character data loading
	var char_data = DataManager._character_data
	if char_data.is_empty():
		results.passed = false
		results.errors.append("Character data not loaded")
		return results
	
	print("✓ Character data loaded: %d entries" % char_data.size())
	
	# Test origins structure
	if not char_data.has("origins"):
		results.passed = false
		results.errors.append("Character data missing 'origins' key")
		return results
	
	var origins_count = char_data.get("origins", {}).size()
	results.metrics["origins_count"] = origins_count
	print("✓ Origins count: %d" % origins_count)
	
	# Test background data file
	var bg_data = DataManager._background_data
	if bg_data.is_empty():
		results.passed = false
		results.errors.append("Background data not loaded")
		return results
	
	print("✓ Background data loaded")
	
	if not bg_data.has("backgrounds"):
		results.passed = false
		results.errors.append("Background data missing 'backgrounds' key")
		return results
	
	var backgrounds_count = bg_data.get("backgrounds", []).size()
	results.metrics["backgrounds_count"] = backgrounds_count
	print("✓ Background array size: %d" % backgrounds_count)
	
	# Test specific data access
	var human_origin = DataManager.get_origin_data("HUMAN")
	if human_origin.is_empty():
		results.passed = false
		results.errors.append("Human origin data not accessible")
		return results
	
	print("✓ Human origin data accessible")
	print("  Base stats: %s" % human_origin.get("base_stats", {}))
	
	var military_bg = DataManager.get_background_data("military")
	if military_bg.is_empty():
		results.passed = false
		results.errors.append("Military background data not accessible")
		return results
	
	print("✓ Military background data accessible")
	print("  Stat bonuses: %s" % military_bg.get("stat_bonuses", {}))
	
	print("Phase 2 completed: %s\n" % ("PASS" if results.passed else "FAIL"))
	return results

## Phase 3: Performance & Memory Profiling
func execute_phase_3_performance_profiling() -> Dictionary:
	print("=== PHASE 3: Performance Profiling ===")
	var results = {
		"passed": true,
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	# Reset performance counters
	DataManager.reset_performance_stats()
	
	# Execute data access operations to test caching
	var test_iterations = 1000
	var start_memory = OS.get_static_memory_usage()
	
	print("Running %d cache performance test iterations..." % test_iterations)
	
	for i in range(test_iterations):
		var origin_data = DataManager.get_origin_data("HUMAN")
		var bg_data = DataManager.get_background_data("military")
		var validation = DataManager.validate_character_creation({
			"origin": "HUMAN",
			"background": "military",
			"class": "SOLDIER"
		})
	
	var end_memory = OS.get_static_memory_usage()
	var stats = DataManager.get_performance_stats()
	var memory_increase_mb = (end_memory - start_memory) / (1024.0 * 1024.0)
	
	results.metrics["cache_hits"] = stats.cache_hits
	results.metrics["cache_misses"] = stats.cache_misses
	results.metrics["cache_hit_ratio"] = stats.cache_hit_ratio
	results.metrics["memory_increase_mb"] = memory_increase_mb
	
	print("✓ Cache hits: %d" % stats.cache_hits)
	print("✓ Cache hit ratio: %.2f%%" % (stats.cache_hit_ratio * 100))
	print("✓ Memory increase: %.2f MB" % memory_increase_mb)
	
	# Validate performance targets
	if stats.cache_hit_ratio < PERFORMANCE_TARGETS.min_cache_hit_ratio:
		results.warnings.append("Cache hit ratio (%.2f%%) below target (%.2f%%)" % [stats.cache_hit_ratio * 100, PERFORMANCE_TARGETS.min_cache_hit_ratio * 100])
		print("⚠ Cache efficiency target (>%.0f%%): FAIL" % (PERFORMANCE_TARGETS.min_cache_hit_ratio * 100))
	else:
		print("✓ Cache efficiency target (>%.0f%%): PASS" % (PERFORMANCE_TARGETS.min_cache_hit_ratio * 100))
	
	if memory_increase_mb > PERFORMANCE_TARGETS.max_memory_increase_mb:
		results.warnings.append("Memory increase (%.2f MB) exceeds target (%.2f MB)" % [memory_increase_mb, PERFORMANCE_TARGETS.max_memory_increase_mb])
		print("⚠ Memory usage target (<%.0f MB): FAIL" % PERFORMANCE_TARGETS.max_memory_increase_mb)
	else:
		print("✓ Memory usage target (<%.0f MB): PASS" % PERFORMANCE_TARGETS.max_memory_increase_mb)
	
	print("Phase 3 completed: %s\n" % ("PASS" if results.passed else "FAIL"))
	return results

## Phase 4: Character Creator Integration Testing
func execute_phase_4_integration_testing() -> Dictionary:
	print("=== PHASE 4: Character Creator Integration ===")
	var results = {
		"passed": true,
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	# Test enum-to-JSON mapping consistency
	var enum_origins = GlobalEnums.Origin.keys()
	var json_origins = DataManager._character_data.get("origins", {}).keys()
	
	results.metrics["enum_origins_count"] = enum_origins.size()
	results.metrics["json_origins_count"] = json_origins.size()
	
	print("✓ Enum origins count: %d" % enum_origins.size())
	print("✓ JSON origins count: %d" % json_origins.size())
	
	# Test background mapping
	var all_backgrounds = DataManager.get_all_backgrounds()
	var unmapped_backgrounds = []
	
	print("✓ Available backgrounds: %d" % all_backgrounds.size())
	
	for bg in all_backgrounds:
		var bg_id = bg.get("id", "")
		var enum_mapped = GlobalEnums.Background.has(bg_id.to_upper())
		if not enum_mapped:
			unmapped_backgrounds.append(bg_id)
			results.warnings.append("Background '%s' has no enum mapping" % bg_id)
	
	results.metrics["unmapped_backgrounds"] = unmapped_backgrounds.size()
	
	if unmapped_backgrounds.size() > 0:
		print("⚠ Unmapped backgrounds found: %s" % unmapped_backgrounds)
	else:
		print("✓ All backgrounds properly mapped to enums")
	
	# Test character validation
	var valid_config = {
		"origin": "HUMAN",
		"background": "military",
		"class": "SOLDIER",
		"motivation": "SURVIVAL"
	}
	
	var validation = DataManager.validate_character_creation(valid_config)
	results.metrics["validation_passed"] = validation.valid
	results.metrics["validation_errors"] = validation.errors.size()
	results.metrics["validation_warnings"] = validation.warnings.size()
	
	if not validation.valid:
		results.passed = false
		results.errors.append("Character validation failed for valid configuration")
		print("✗ Character validation result: FAILED")
		print("  Errors: %s" % validation.errors)
	else:
		print("✓ Character validation result: PASSED")
	
	if validation.warnings.size() > 0:
		print("  Validation warnings: %s" % validation.warnings)
	
	print("Phase 4 completed: %s\n" % ("PASS" if results.passed else "FAIL"))
	return results

## Phase 5: Error Resilience & Fallback Testing
func execute_phase_5_error_resilience() -> Dictionary:
	print("=== PHASE 5: Error Resilience Testing ===")
	var results = {
		"passed": true,
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	# Store original data for restoration
	var original_char_data = DataManager._character_data.duplicate(true)
	
	# Test with corrupted JSON data
	DataManager._character_data = {}  # Simulate data corruption
	var fallback_test = GlobalEnums.get_origin_display_name(GlobalEnums.Origin.HUMAN)
	var fallback_functional = (fallback_test == "Human")
	
	results.metrics["fallback_mode_functional"] = fallback_functional
	
	if fallback_functional:
		print("✓ Fallback mode functional: %s" % fallback_test)
	else:
		results.passed = false
		results.errors.append("Fallback mode non-functional")
		print("✗ Fallback mode failed")
	
	# Restore original data
	DataManager._character_data = original_char_data
	
	# Test with invalid character configurations
	var invalid_configs = [
		{"origin": "INVALID", "background": "invalid"},
		{"origin": "", "background": ""},
		{},
		{"origin": "HUMAN"}  # Missing required fields
	]
	
	var properly_rejected_count = 0
	
	for i in range(invalid_configs.size()):
		var config = invalid_configs[i]
		var validation = DataManager.validate_character_creation(config)
		if not validation.valid:
			properly_rejected_count += 1
			print("✓ Invalid config %d properly rejected" % (i + 1))
		else:
			results.warnings.append("Invalid config %d was not rejected: %s" % [i + 1, config])
			print("⚠ Invalid config %d was not rejected: %s" % [i + 1, config])
	
	results.metrics["properly_rejected_configs"] = properly_rejected_count
	results.metrics["total_invalid_configs"] = invalid_configs.size()
	
	print("Phase 5 completed: %s\n" % ("PASS" if results.passed else "FAIL"))
	return results

## Scalability Testing
func execute_scalability_testing() -> Dictionary:
	print("=== SCALABILITY TESTING ===")
	var results = {
		"passed": true,
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	var valid_config = {
		"origin": "HUMAN",
		"background": "military",
		"class": "SOLDIER"
	}
	
	print("Running large-scale throughput test (10,000 operations)...")
	
	var large_test_start = Time.get_ticks_msec()
	for i in range(10000):
		DataManager.get_origin_data("HUMAN")
		DataManager.validate_character_creation(valid_config)
	var large_test_end = Time.get_ticks_msec()
	
	var test_duration_sec = (large_test_end - large_test_start) / 1000.0
	var throughput = 10000.0 / test_duration_sec
	
	results.metrics["operations_per_second"] = throughput
	results.metrics["test_duration_sec"] = test_duration_sec
	
	print("✓ Operations per second: %.0f" % throughput)
	print("✓ Test duration: %.2f seconds" % test_duration_sec)
	
	if throughput < PERFORMANCE_TARGETS.min_throughput_ops_per_sec:
		results.warnings.append("Throughput (%.0f ops/sec) below target (%.0f ops/sec)" % [throughput, PERFORMANCE_TARGETS.min_throughput_ops_per_sec])
		print("⚠ Scalability target (>%.0f ops/sec): FAIL" % PERFORMANCE_TARGETS.min_throughput_ops_per_sec)
	else:
		print("✓ Scalability target (>%.0f ops/sec): PASS" % PERFORMANCE_TARGETS.min_throughput_ops_per_sec)
	
	print("Scalability testing completed: %s\n" % ("PASS" if results.passed else "FAIL"))
	return results

## Execute Full Testing Protocol
func run_comprehensive_testing() -> Dictionary:
	print("🧪 FIVE PARSECS HYBRID DATA ARCHITECTURE - COMPREHENSIVE TESTING")
	print("======================================================================")
	
	var overall_results = {
		"overall_passed": true,
		"total_errors": 0,
		"total_warnings": 0,
		"phases": {},
		"recommendations": []
	}
	
	# Execute all test phases
	var phase_1 = execute_phase_1_infrastructure_validation()
	var phase_2 = execute_phase_2_json_integrity()
	var phase_3 = execute_phase_3_performance_profiling()
	var phase_4 = execute_phase_4_integration_testing()
	var phase_5 = execute_phase_5_error_resilience()
	var scalability = execute_scalability_testing()
	
	# Store phase results
	overall_results.phases["infrastructure"] = phase_1
	overall_results.phases["json_integrity"] = phase_2
	overall_results.phases["performance"] = phase_3
	overall_results.phases["integration"] = phase_4
	overall_results.phases["error_resilience"] = phase_5
	overall_results.phases["scalability"] = scalability
	
	# Calculate overall results
	var phases = [phase_1, phase_2, phase_3, phase_4, phase_5, scalability]
	for phase in phases:
		if not phase.passed:
			overall_results.overall_passed = false
		overall_results.total_errors += phase.errors.size()
		overall_results.total_warnings += phase.warnings.size()
	
	# Generate recommendations
	_generate_recommendations(overall_results)
	
	# Print final summary
	print("🎯 TESTING SUMMARY")
	print("======================================================================")
	print("Overall Result: %s" % ("✅ PASS" if overall_results.overall_passed else "❌ FAIL"))
	print("Total Errors: %d" % overall_results.total_errors)
	print("Total Warnings: %d" % overall_results.total_warnings)
	
	if overall_results.recommendations.size() > 0:
		print("\n📋 RECOMMENDATIONS:")
		for i in range(overall_results.recommendations.size()):
			print("%d. %s" % [i + 1, overall_results.recommendations[i]])
	
	# Performance summary
	var perf_metrics = phase_3.metrics
	var init_time = overall_results.phases.infrastructure.metrics.get("initialization_time_ms", 0)
	var cache_ratio = perf_metrics.get("cache_hit_ratio", 0.0) * 100
	var memory_usage = perf_metrics.get("memory_increase_mb", 0.0)
	var throughput = scalability.metrics.get("operations_per_second", 0.0)
	
	print("\n⚡ PERFORMANCE METRICS:")
	print("  Initialization: %d ms (target: <%d ms)" % [init_time, PERFORMANCE_TARGETS.max_init_time_ms])
	print("  Cache Hit Ratio: %.1f%% (target: >%.0f%%)" % [cache_ratio, PERFORMANCE_TARGETS.min_cache_hit_ratio * 100])
	print("  Memory Usage: %.2f MB (target: <%.0f MB)" % [memory_usage, PERFORMANCE_TARGETS.max_memory_increase_mb])
	print("  Throughput: %.0f ops/sec (target: >%.0f ops/sec)" % [throughput, PERFORMANCE_TARGETS.min_throughput_ops_per_sec])
	
	# Production readiness assessment
	var production_ready = _assess_production_readiness(overall_results)
	print("\n🚀 PRODUCTION READINESS: %s" % ("✅ READY" if production_ready else "⚠️ NEEDS WORK"))
	
	return overall_results

func _generate_recommendations(results: Dictionary) -> void:
	var recommendations = []
	
	# Performance recommendations
	var phase_3 = results.phases.get("performance", {})
	var metrics = phase_3.get("metrics", {})
	
	if metrics.get("cache_hit_ratio", 1.0) < PERFORMANCE_TARGETS.min_cache_hit_ratio:
		recommendations.append("Increase cache size and implement cache warming during initialization")
	
	if metrics.get("memory_increase_mb", 0.0) > PERFORMANCE_TARGETS.max_memory_increase_mb:
		recommendations.append("Implement object pooling and optimize data structures to reduce memory usage")
	
	# Integration recommendations
	var phase_4 = results.phases.get("integration", {})
	var unmapped_count = phase_4.get("metrics", {}).get("unmapped_backgrounds", 0)
	
	if unmapped_count > 0:
		recommendations.append("Add missing enum mappings for %d background(s) in GlobalEnums.gd" % unmapped_count)
	
	# Scalability recommendations
	var scalability = results.phases.get("scalability", {})
	var throughput = scalability.get("metrics", {}).get("operations_per_second", 0.0)
	
	if throughput < PERFORMANCE_TARGETS.min_throughput_ops_per_sec:
		recommendations.append("Optimize data access patterns and consider implementing batch processing")
	
	results.recommendations = recommendations

func _assess_production_readiness(results: Dictionary) -> bool:
	if not results.overall_passed:
		return false
	
	# Check critical performance metrics
	var init_time = results.phases.infrastructure.metrics.get("initialization_time_ms", 999999)
	var cache_ratio = results.phases.performance.metrics.get("cache_hit_ratio", 0.0)
	var memory_usage = results.phases.performance.metrics.get("memory_increase_mb", 999.0)
	var throughput = results.phases.scalability.metrics.get("operations_per_second", 0.0)
	
	return (init_time < PERFORMANCE_TARGETS.max_init_time_ms and
			cache_ratio > PERFORMANCE_TARGETS.min_cache_hit_ratio and
			memory_usage < PERFORMANCE_TARGETS.max_memory_increase_mb and
			throughput > PERFORMANCE_TARGETS.min_throughput_ops_per_sec)

## Entry point - call this function to run all tests
static func execute_testing_protocol():
	var tester = HybridDataArchitectureTester.new()
	return tester.run_comprehensive_testing()