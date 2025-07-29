extends GdUnitTestSuite

## Production Readiness Tests - Phase 3C.3
## Comprehensive tests for ProductionReadinessChecker
## Final validation that the system is ready for production deployment

const ProductionReadinessChecker = preload("res://src/core/production/ProductionReadinessChecker.gd")
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const IntegrationHealthMonitor = preload("res://src/core/monitoring/IntegrationHealthMonitor.gd")

## Test fixtures
var test_scene: Node
var mock_ui_controller: Node
var test_state_manager: CampaignCreationStateManager
var production_results: Array = []

func before_test() -> void:
	"""Setup production readiness testing environment"""
	print("=== Production Readiness Tests - Phase 3C.3 Setup ===")
	
	# Create test scene container
	test_scene = Node.new()
	test_scene.name = "ProductionReadinessTestScene"
	add_child(test_scene)
	
	# Create comprehensive mock UI controller
	_create_comprehensive_mock_ui_controller()
	
	# Initialize state manager
	test_state_manager = CampaignCreationStateManager.new()
	
	# Clear previous results
	production_results.clear()
	
	print("Production Readiness Tests: Environment ready for validation")

func after_test() -> void:
	"""Cleanup after production readiness tests"""
	if test_scene:
		test_scene.queue_free()
	production_results.clear()
	print("Production Readiness Tests: Cleanup complete")

func _create_comprehensive_mock_ui_controller() -> void:
	"""Create comprehensive mock UI controller for production testing"""
	mock_ui_controller = Node.new()
	mock_ui_controller.name = "MockCampaignCreationUI"
	test_scene.add_child(mock_ui_controller)
	
	# Create all required panels with production-level integration
	var panels = ["config_panel", "crew_panel", "captain_panel", "ship_panel", "equipment_panel", "final_panel"]
	
	for panel_name in panels:
		var panel = Node.new()
		panel.name = panel_name
		panel.set_script(GDScript.new())
		
		# Panel-specific production configuration
		if panel_name == "crew_panel":
			panel.get_script().source_code = """
extends Node
signal crew_updated(crew_data: Array)
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Variant)

var mock_crew: Array = [
	{"character_name": "Production Captain", "is_captain": true, "combat": 4, "backend_generated": true},
	{"character_name": "Production Crew 1", "combat": 3, "backend_generated": true},
	{"character_name": "Production Crew 2", "combat": 3, "backend_generated": true}
]

func get_data() -> Dictionary:
	return {"crew_members": mock_crew, "captain": mock_crew[0], "crew_size": mock_crew.size(), "backend_generated": true}

func is_valid() -> bool:
	return mock_crew.size() > 0

func has_signal(signal_name: String) -> bool:
	return signal_name in ["crew_updated", "crew_generation_requested", "character_customization_needed"]
"""
		elif panel_name == "equipment_panel":
			panel.get_script().source_code = """
extends Node
signal equipment_generated(equipment: Array)
signal equipment_requested(crew_data: Array)

var mock_equipment: Array = [
	{"name": "Production Weapon 1", "type": "Weapon", "owner": "Production Captain", "backend_generated": true},
	{"name": "Production Weapon 2", "type": "Weapon", "owner": "Production Crew 1", "backend_generated": true},
	{"name": "Production Weapon 3", "type": "Weapon", "owner": "Production Crew 2", "backend_generated": true}
]

func get_data() -> Dictionary:
	return {"equipment": mock_equipment, "starting_credits": 1500, "is_complete": true, "backend_generated": true}

func is_valid() -> bool:
	return mock_equipment.size() > 0

func has_signal(signal_name: String) -> bool:
	return signal_name in ["equipment_generated", "equipment_requested"]
"""
		else:
			panel.get_script().source_code = """
extends Node

func get_data() -> Dictionary:
	return {"configured": true, "valid": true}

func is_valid() -> bool:
	return true

func has_signal(signal_name: String) -> bool:
	return true
"""
		
		mock_ui_controller.add_child(panel)
		mock_ui_controller.set(panel_name, panel)

## CORE PRODUCTION READINESS TESTS

func test_complete_production_readiness_validation():
	"""Test complete production readiness validation"""
	print("Testing complete production readiness validation...")
	
	# Generate multi-turn campaign sequence for comprehensive testing
	var campaign_sequence = _generate_production_campaign_sequence(5)
	
	# Run complete production readiness validation
	var result = ProductionReadinessChecker.validate_production_readiness(
		mock_ui_controller,
		test_state_manager,
		campaign_sequence
	)
	
	production_results.append(result)
	
	# Validate result structure
	assert_that(result).is_not_null()
	assert_that(result.overall_level).is_not_null()
	assert_that(result.validation_timestamp).is_not_empty()
	assert_that(result.total_validation_time_ms).is_greater_than(0)
	assert_that(result.category_results.size()).is_equal(8) # All 8 validation categories
	
	# Validate that result includes deployment decision
	assert_that(result.deployment_approval).is_not_null()
	
	# Check minimum readiness requirements
	var readiness_level = result.overall_level
	assert_that(readiness_level).is_greater_equal(ProductionReadinessChecker.ProductionReadinessLevel.ALPHA_READY).override_failure_message(
		"System readiness level %s below minimum Alpha Ready" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[readiness_level]
	)
	
	print("✅ Complete production readiness validation test passed")
	print("  Overall Level: %s" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[readiness_level])
	print("  Deployment Approved: %s" % result.deployment_approval)
	print("  Total Duration: %dms" % result.total_validation_time_ms)

func test_production_readiness_smoke_tests_category():
	"""Test production readiness smoke tests category"""
	print("Testing production readiness smoke tests category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var smoke_category = result.category_results[ProductionReadinessChecker.ValidationCategory.SMOKE_TESTS]
	
	assert_that(smoke_category).is_not_null()
	assert_that(smoke_category.passed).is_true().override_failure_message(
		"Smoke tests category failed: %s" % ", ".join(smoke_category.details)
	)
	assert_that(smoke_category.score).is_greater_than(0.8).override_failure_message(
		"Smoke tests score %.1f%% below 80%%" % (smoke_category.score * 100)
	)
	
	# Check smoke test metrics
	assert_that(smoke_category.metrics.has("smoke_test_result")).is_true()
	assert_that(smoke_category.metrics.has("execution_time_ms")).is_true()
	
	print("✅ Production readiness smoke tests category passed")
	print("  Score: %.1f%%" % (smoke_category.score * 100))
	print("  Duration: %dms" % smoke_category.duration_ms)

func test_production_readiness_data_consistency_category():
	"""Test production readiness data consistency category"""
	print("Testing production readiness data consistency category...")
	
	var campaign_sequence = _generate_production_campaign_sequence(3)
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager, campaign_sequence)
	var consistency_category = result.category_results[ProductionReadinessChecker.ValidationCategory.DATA_CONSISTENCY]
	
	assert_that(consistency_category).is_not_null()
	assert_that(consistency_category.score).is_greater_than(0.0)
	
	# Check data consistency metrics
	assert_that(consistency_category.metrics.has("validations_run")).is_true()
	assert_that(consistency_category.metrics.has("consistency_score")).is_true()
	
	print("✅ Production readiness data consistency category completed")
	print("  Score: %.1f%%" % (consistency_category.score * 100))
	print("  Validations Run: %d" % consistency_category.metrics.validations_run)

func test_production_readiness_performance_benchmarks_category():
	"""Test production readiness performance benchmarks category"""
	print("Testing production readiness performance benchmarks category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var performance_category = result.category_results[ProductionReadinessChecker.ValidationCategory.PERFORMANCE_BENCHMARKS]
	
	assert_that(performance_category).is_not_null()
	assert_that(performance_category.score).is_greater_than(0.0)
	
	# Check performance metrics
	assert_that(performance_category.metrics.has("benchmarks_passed")).is_true()
	assert_that(performance_category.metrics.has("total_benchmarks")).is_true()
	
	# Performance should meet minimum standards
	var benchmarks_passed = performance_category.metrics.benchmarks_passed
	var total_benchmarks = performance_category.metrics.total_benchmarks
	var performance_ratio = float(benchmarks_passed) / float(total_benchmarks)
	
	assert_that(performance_ratio).is_greater_than(0.6).override_failure_message(
		"Performance benchmarks ratio %.1f%% below 60%%" % (performance_ratio * 100)
	)
	
	print("✅ Production readiness performance benchmarks category completed")
	print("  Score: %.1f%%" % (performance_category.score * 100))
	print("  Benchmarks Passed: %d/%d" % [benchmarks_passed, total_benchmarks])

func test_production_readiness_error_handling_category():
	"""Test production readiness error handling category"""
	print("Testing production readiness error handling category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var error_category = result.category_results[ProductionReadinessChecker.ValidationCategory.ERROR_HANDLING]
	
	assert_that(error_category).is_not_null()
	assert_that(error_category.score).is_greater_than(0.0)
	
	# Error handling should be robust
	assert_that(error_category.metrics.has("error_scenarios_passed")).is_true()
	assert_that(error_category.metrics.has("total_error_scenarios")).is_true()
	
	var error_scenarios_passed = error_category.metrics.error_scenarios_passed
	var total_error_scenarios = error_category.metrics.total_error_scenarios
	var error_handling_ratio = float(error_scenarios_passed) / float(total_error_scenarios)
	
	assert_that(error_handling_ratio).is_greater_than(0.7).override_failure_message(
		"Error handling coverage %.1f%% below 70%%" % (error_handling_ratio * 100)
	)
	
	print("✅ Production readiness error handling category completed")
	print("  Score: %.1f%%" % (error_category.score * 100))
	print("  Error Scenarios Passed: %d/%d" % [error_scenarios_passed, total_error_scenarios])

func test_production_readiness_integration_health_category():
	"""Test production readiness integration health category"""
	print("Testing production readiness integration health category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var health_category = result.category_results[ProductionReadinessChecker.ValidationCategory.INTEGRATION_HEALTH]
	
	assert_that(health_category).is_not_null()
	assert_that(health_category.score).is_greater_than(0.0)
	
	# Health monitoring should be operational
	assert_that(health_category.metrics.has("total_systems")).is_true()
	assert_that(health_category.metrics.has("operational_systems")).is_true()
	assert_that(health_category.metrics.has("health_score")).is_true()
	
	print("✅ Production readiness integration health category completed")
	print("  Score: %.1f%%" % (health_category.score * 100))
	print("  Health Score: %.1f%%" % (health_category.metrics.health_score * 100))

func test_production_readiness_memory_stability_category():
	"""Test production readiness memory stability category"""
	print("Testing production readiness memory stability category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var memory_category = result.category_results[ProductionReadinessChecker.ValidationCategory.MEMORY_STABILITY]
	
	assert_that(memory_category).is_not_null()
	assert_that(memory_category.score).is_greater_than(0.0)
	
	# Memory should be stable
	assert_that(memory_category.metrics.has("stability_checks_passed")).is_true()
	assert_that(memory_category.metrics.has("total_stability_checks")).is_true()
	
	print("✅ Production readiness memory stability category completed")
	print("  Score: %.1f%%" % (memory_category.score * 100))

func test_production_readiness_scalability_category():
	"""Test production readiness scalability category"""
	print("Testing production readiness scalability category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var scalability_category = result.category_results[ProductionReadinessChecker.ValidationCategory.SCALABILITY_TESTS]
	
	assert_that(scalability_category).is_not_null()
	assert_that(scalability_category.score).is_greater_than(0.0)
	
	# Scalability tests should demonstrate adequate performance
	assert_that(scalability_category.metrics.has("scalability_tests_passed")).is_true()
	assert_that(scalability_category.metrics.has("total_scalability_tests")).is_true()
	
	print("✅ Production readiness scalability category completed")
	print("  Score: %.1f%%" % (scalability_category.score * 100))

func test_production_readiness_security_category():
	"""Test production readiness security category"""
	print("Testing production readiness security category...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	var security_category = result.category_results[ProductionReadinessChecker.ValidationCategory.SECURITY_VALIDATION]
	
	assert_that(security_category).is_not_null()
	assert_that(security_category.score).is_greater_than(0.0)
	
	# Security validation should meet minimum standards
	assert_that(security_category.metrics.has("security_checks_passed")).is_true()
	assert_that(security_category.metrics.has("total_security_checks")).is_true()
	
	print("✅ Production readiness security category completed")
	print("  Score: %.1f%%" % (security_category.score * 100))

## PRODUCTION READINESS LEVEL TESTS

func test_production_ready_level_validation():
	"""Test production ready level requirements"""
	print("Testing production ready level validation...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	production_results.append(result)
	
	# For production ready level, need high scores across all categories
	if result.overall_level == ProductionReadinessChecker.ProductionReadinessLevel.PRODUCTION_READY:
		assert_that(result.performance_metrics.overall_score).is_greater_than(0.95)
		assert_that(result.critical_issues.size()).is_equal(0)
		assert_that(result.deployment_approval).is_true()
		
		print("✅ System achieved PRODUCTION_READY level")
	else:
		print("ℹ️ System level: %s" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[result.overall_level])
	
	print("  Overall Score: %.1f%%" % (result.performance_metrics.overall_score * 100))
	print("  Critical Issues: %d" % result.critical_issues.size())
	print("  Deployment Approved: %s" % result.deployment_approval)

func test_deployment_approval_logic():
	"""Test deployment approval logic"""
	print("Testing deployment approval logic...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	
	# Deployment should be approved for Alpha level and above
	var minimum_level = ProductionReadinessChecker.ProductionReadinessLevel.ALPHA_READY
	var deployment_should_be_approved = result.overall_level >= minimum_level
	
	assert_that(result.deployment_approval).is_equal(deployment_should_be_approved).override_failure_message(
		"Deployment approval mismatch - Level: %s, Approved: %s" % [
			ProductionReadinessChecker.ProductionReadinessLevel.keys()[result.overall_level],
			result.deployment_approval
		]
	)
	
	print("✅ Deployment approval logic test passed")
	print("  Level: %s" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[result.overall_level])
	print("  Deployment Approved: %s" % result.deployment_approval)

## EDGE CASE AND ERROR HANDLING TESTS

func test_production_readiness_with_null_inputs():
	"""Test production readiness validation with null inputs"""
	print("Testing production readiness with null inputs...")
	
	# Should handle null inputs gracefully
	var result = ProductionReadinessChecker.validate_production_readiness(null, null, [])
	
	assert_that(result).is_not_null()
	assert_that(result.overall_level).is_not_null()
	
	# Some categories should still pass (smoke tests, performance, etc.)
	# Others might fail due to missing components
	var categories_with_results = 0
	for category in result.category_results.keys():
		if result.category_results[category] != null:
			categories_with_results += 1
	
	assert_that(categories_with_results).is_equal(8) # All categories should have results
	
	print("✅ Production readiness null inputs test passed")
	print("  Result level: %s" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[result.overall_level])

func test_production_readiness_performance_under_load():
	"""Test production readiness performance under load"""
	print("Testing production readiness performance under load...")
	
	var load_start = Time.get_ticks_msec()
	
	# Run multiple production readiness validations simultaneously
	var results = []
	for i in range(3):
		var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
		results.append(result)
	
	var total_load_time = Time.get_ticks_msec() - load_start
	
	# All validations should complete successfully
	assert_that(results.size()).is_equal(3)
	for result in results:
		assert_that(result).is_not_null()
		assert_that(result.overall_level).is_not_null()
	
	# Performance should be reasonable even under load
	var avg_time_per_validation = total_load_time / 3
	assert_that(avg_time_per_validation).is_less_than(30000).override_failure_message(
		"Production readiness validation too slow under load: %dms average" % avg_time_per_validation
	)
	
	print("✅ Production readiness performance under load test passed")
	print("  Total load time: %dms" % total_load_time)
	print("  Average per validation: %dms" % avg_time_per_validation)

## REGRESSION AND COMPATIBILITY TESTS

func test_production_readiness_backwards_compatibility():
	"""Test production readiness backwards compatibility"""
	print("Testing production readiness backwards compatibility...")
	
	# Test with minimal UI controller (fewer panels)
	var minimal_ui = Node.new()
	minimal_ui.name = "MinimalUI"
	test_scene.add_child(minimal_ui)
	
	var result = ProductionReadinessChecker.validate_production_readiness(minimal_ui, test_state_manager)
	
	# Should handle minimal setup gracefully
	assert_that(result).is_not_null()
	assert_that(result.category_results.size()).is_equal(8) # All categories should run
	
	minimal_ui.queue_free()
	
	print("✅ Production readiness backwards compatibility test passed")

func test_production_readiness_comprehensive_reporting():
	"""Test production readiness comprehensive reporting"""
	print("Testing production readiness comprehensive reporting...")
	
	var result = ProductionReadinessChecker.validate_production_readiness(mock_ui_controller, test_state_manager)
	
	# Validate comprehensive report structure
	assert_that(result.validation_timestamp).is_not_empty()
	assert_that(result.total_validation_time_ms).is_greater_than(0)
	assert_that(result.category_results.size()).is_equal(8)
	assert_that(result.recommendations.size()).is_greater_than(0)
	assert_that(result.performance_metrics.size()).is_greater_than(0)
	
	# Each category should have detailed results
	for category in result.category_results.keys():
		var category_result = result.category_results[category]
		assert_that(category_result.duration_ms).is_greater_than(0)
		assert_that(category_result.details.size()).is_greater_than(0)
		assert_that(category_result.score).is_greater_equal(0.0)
		assert_that(category_result.score).is_less_equal(1.0)
	
	print("✅ Production readiness comprehensive reporting test passed")
	print("  Report timestamp: %s" % result.validation_timestamp)
	print("  Categories validated: %d" % result.category_results.size())
	print("  Recommendations provided: %d" % result.recommendations.size())

## HELPER METHODS

func _generate_production_campaign_sequence(num_turns: int) -> Array[Dictionary]:
	"""Generate production-quality campaign sequence for testing"""
	var sequence: Array[Dictionary] = []
	
	for turn in range(1, num_turns + 1):
		var turn_data = {
			"campaign_turn": turn,
			"crew_members": [
				{"character_name": "Production Captain", "is_captain": true, "combat": 4, "toughness": 4},
				{"character_name": "Production Crew 1", "combat": 3, "toughness": 3},
				{"character_name": "Production Crew 2", "combat": 3, "toughness": 3},
				{"character_name": "Production Crew 3", "combat": 2, "toughness": 3}
			],
			"equipment_items": [
				{"name": "Production Weapon 1", "type": "Weapon", "owner": "Production Captain"},
				{"name": "Production Weapon 2", "type": "Weapon", "owner": "Production Crew 1"},
				{"name": "Production Armor 1", "type": "Armor", "owner": "Production Captain"},
				{"name": "Production Gear 1", "type": "Gear", "owner": "Production Crew 2"}
			],
			"credits": 1500 + (turn * 200), # Credits increase with turns
			"ship_data": {
				"name": "Production Ship",
				"type": "Frigate",
				"hull_points": 20,
				"components": ["Bridge", "Engine", "Cargo Hold"]
			},
			"story_progress": turn * 15, # Story progression
			"reputation": turn * 8, # Reputation builds over time
			"relationships": {
				"patrons": ["Production Patron %d" % turn],
				"rivals": ["Production Rival %d" % (turn / 2)],
				"contacts": ["Production Contact %d" % turn]
			},
			"performance_metrics": {
				"missions_completed": turn,
				"battles_won": turn,
				"crew_experience": turn * 5
			}
		}
		sequence.append(turn_data)
	
	return sequence

## COMPREHENSIVE PRODUCTION READINESS SUMMARY

func test_comprehensive_production_readiness_summary():
	"""Generate comprehensive production readiness test summary"""
	print("=== COMPREHENSIVE PRODUCTION READINESS SUMMARY ===")
	
	# Run final comprehensive validation
	var campaign_sequence = _generate_production_campaign_sequence(5)
	var final_result = ProductionReadinessChecker.validate_production_readiness(
		mock_ui_controller,
		test_state_manager,
		campaign_sequence
	)
	
	production_results.append(final_result)
	
	# Generate detailed summary
	print("\n📋 FINAL PRODUCTION READINESS ASSESSMENT")
	print("Validation Timestamp: %s" % final_result.validation_timestamp)
	print("Overall Readiness Level: %s" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[final_result.overall_level])
	print("Deployment Approval: %s" % ("✅ APPROVED" if final_result.deployment_approval else "❌ DENIED"))
	print("Overall Score: %.1f%%" % (final_result.performance_metrics.overall_score * 100))
	print("Total Validation Time: %.2fs" % (float(final_result.total_validation_time_ms) / 1000.0))
	
	print("\n📊 CATEGORY BREAKDOWN:")
	for category in final_result.category_results.keys():
		var category_result = final_result.category_results[category]
		var category_name = ProductionReadinessChecker.ValidationCategory.keys()[category]
		var status_icon = "✅" if category_result.passed else "❌"
		print("  %s %s: %.1f%% (%dms)" % [
			status_icon,
			category_name.replace("_", " ").capitalize(),
			category_result.score * 100,
			category_result.duration_ms
		])
	
	if final_result.critical_issues.size() > 0:
		print("\n🚨 CRITICAL ISSUES:")
		for issue in final_result.critical_issues:
			print("  • %s" % issue)
	
	if final_result.warnings.size() > 0:
		print("\n⚠️ WARNINGS:")
		for warning in final_result.warnings:
			print("  • %s" % warning)
	
	print("\n🎯 KEY RECOMMENDATIONS:")
	for i in range(min(5, final_result.recommendations.size())):
		print("  • %s" % final_result.recommendations[i])
	
	# Final validation
	var minimum_readiness = ProductionReadinessChecker.ProductionReadinessLevel.ALPHA_READY
	assert_that(final_result.overall_level).is_greater_equal(minimum_readiness).override_failure_message(
		"Final production readiness level %s below minimum Alpha Ready" % ProductionReadinessChecker.ProductionReadinessLevel.keys()[final_result.overall_level]
	)
	
	print("\n🎯 PHASE 3C.3 PRODUCTION READINESS RESULT: %s" % ("PASSED" if final_result.deployment_approval else "NEEDS_WORK"))
	print("🚀 Five Parsecs Campaign Manager production readiness validation complete!")
	
	# Return result for external validation
	return final_result