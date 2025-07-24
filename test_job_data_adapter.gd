@tool
extends RefCounted

## Test script for JobDataAdapter validation
## Run this to verify all conversion methods work correctly

const JobDataAdapter = preload("res://src/core/world_phase/JobDataAdapter.gd")

static func run_tests() -> void:
	print("=== JobDataAdapter Test Suite ===")
	
	# Test individual conversion methods
	test_ui_to_world_phase_conversion()
	test_world_phase_to_ui_conversion()
	test_ui_to_job_opportunity_conversion()
	test_job_opportunity_to_ui_conversion()
	test_world_phase_to_job_opportunity_conversion()
	test_job_opportunity_to_world_phase_conversion()
	
	# Test batch conversion methods
	test_batch_conversions()
	
	# Test validation methods
	test_validation_methods()
	
	# Test error handling
	test_error_handling()
	
	# Run comprehensive integrity tests
	var integrity_result = JobDataAdapter.validate_conversion_integrity()
	print("Conversion integrity test: ", "PASSED" if integrity_result else "FAILED")
	
	print("=== Test Suite Complete ===")

static func test_ui_to_world_phase_conversion() -> void:
	print("\n--- Testing UI -> WorldPhase Conversion ---")
	var ui_job = JobDataAdapter.create_test_ui_job()
	var world_job = JobDataAdapter.convert_ui_to_world_phase(ui_job)
	
	print("UI job type: ", ui_job.get_meta("job_type"))
	print("WorldPhase job type: ", world_job.get("type"))
	print("UI reward: ", ui_job.get_meta("reward_credits"))
	print("WorldPhase payment: ", world_job.get("payment"))
	print("Conversion successful: ", not world_job.is_empty())

static func test_world_phase_to_ui_conversion() -> void:
	print("\n--- Testing WorldPhase -> UI Conversion ---")
	var world_job = JobDataAdapter.create_test_world_phase_job()
	var ui_job = JobDataAdapter.convert_world_phase_to_ui(world_job)
	
	print("WorldPhase name: ", world_job.get("name"))
	print("UI mission type: ", ui_job.get_meta("mission_type") if ui_job else "null")
	print("WorldPhase payment: ", world_job.get("payment"))
	print("UI reward: ", ui_job.get_meta("reward_credits") if ui_job else "null")
	print("Conversion successful: ", ui_job != null)

static func test_ui_to_job_opportunity_conversion() -> void:
	print("\n--- Testing UI -> JobOpportunity Conversion ---")
	var ui_job = JobDataAdapter.create_test_ui_job()
	var job_opportunity = JobDataAdapter.convert_ui_to_job_opportunity(ui_job)
	
	print("UI mission type: ", ui_job.get_meta("mission_type"))
	print("JobOpportunity title: ", job_opportunity.job_title if job_opportunity else "null")
	print("UI reward: ", ui_job.get_meta("reward_credits"))
	print("JobOpportunity payment: ", job_opportunity.base_payment if job_opportunity else "null")
	print("Conversion successful: ", job_opportunity != null)

static func test_job_opportunity_to_ui_conversion() -> void:
	print("\n--- Testing JobOpportunity -> UI Conversion ---")
	var job_opportunity = JobDataAdapter.create_test_job_opportunity()
	var ui_job = JobDataAdapter.convert_job_opportunity_to_ui(job_opportunity)
	
	print("JobOpportunity title: ", job_opportunity.job_title)
	print("UI mission type: ", ui_job.get_meta("mission_type") if ui_job else "null")
	print("JobOpportunity payment: ", job_opportunity.base_payment)
	print("UI reward: ", ui_job.get_meta("reward_credits") if ui_job else "null")
	print("Conversion successful: ", ui_job != null)

static func test_world_phase_to_job_opportunity_conversion() -> void:
	print("\n--- Testing WorldPhase -> JobOpportunity Conversion ---")
	var world_job = JobDataAdapter.create_test_world_phase_job()
	var job_opportunity = JobDataAdapter.convert_world_phase_to_job_opportunity(world_job)
	
	print("WorldPhase name: ", world_job.get("name"))
	print("JobOpportunity title: ", job_opportunity.job_title if job_opportunity else "null")
	print("WorldPhase payment: ", world_job.get("payment"))
	print("JobOpportunity payment: ", job_opportunity.base_payment if job_opportunity else "null")
	print("Conversion successful: ", job_opportunity != null)

static func test_job_opportunity_to_world_phase_conversion() -> void:
	print("\n--- Testing JobOpportunity -> WorldPhase Conversion ---")
	var job_opportunity = JobDataAdapter.create_test_job_opportunity()
	var world_job = JobDataAdapter.convert_job_opportunity_to_world_phase(job_opportunity)
	
	print("JobOpportunity title: ", job_opportunity.job_title)
	print("WorldPhase name: ", world_job.get("name"))
	print("JobOpportunity payment: ", job_opportunity.base_payment)
	print("WorldPhase payment: ", world_job.get("payment"))
	print("Conversion successful: ", not world_job.is_empty())

static func test_batch_conversions() -> void:
	print("\n--- Testing Batch Conversions ---")
	
	# Create test arrays
	var world_jobs: Array[Dictionary] = [
		JobDataAdapter.create_test_world_phase_job(),
		{
			"id": "test_002",
			"type": "patron",
			"name": "Escort Mission",
			"payment": 300,
			"danger_level": 3
		}
	]
	
	var ui_jobs = JobDataAdapter.convert_world_phase_array_to_ui_array(world_jobs)
	print("WorldPhase array size: ", world_jobs.size())
	print("Converted UI array size: ", ui_jobs.size())
	
	var converted_back = JobDataAdapter.convert_ui_array_to_world_phase_array(ui_jobs)
	print("Converted back array size: ", converted_back.size())

static func test_validation_methods() -> void:
	print("\n--- Testing Validation Methods ---")
	
	# Test valid formats
	var valid_ui = JobDataAdapter.create_test_ui_job()
	print("Valid UI job validation: ", JobDataAdapter._validate_ui_format(valid_ui))
	
	var valid_world = JobDataAdapter.create_test_world_phase_job()
	print("Valid WorldPhase job validation: ", JobDataAdapter._validate_world_phase_format(valid_world))
	
	var valid_opportunity = JobDataAdapter.create_test_job_opportunity()
	print("Valid JobOpportunity validation: ", JobDataAdapter._validate_job_opportunity_format(valid_opportunity))
	
	# Test invalid formats
	var invalid_ui = Resource.new()  # Missing required metadata
	print("Invalid UI job validation: ", JobDataAdapter._validate_ui_format(invalid_ui))
	
	var invalid_world = {"incomplete": "data"}  # Missing required keys
	print("Invalid WorldPhase job validation: ", JobDataAdapter._validate_world_phase_format(invalid_world))

static func test_error_handling() -> void:
	print("\n--- Testing Error Handling ---")
	
	# Test null inputs
	var null_result = JobDataAdapter.convert_ui_to_world_phase(null)
	print("Null UI input result: ", null_result.is_empty())
	
	var empty_dict_result = JobDataAdapter.convert_world_phase_to_ui({})
	print("Empty dict input result: ", empty_dict_result == null)
	
	# Test fallback methods
	var fallback_ui = JobDataAdapter.create_fallback_ui_job()
	print("Fallback UI job created: ", fallback_ui != null)
	
	var fallback_world = JobDataAdapter.create_fallback_world_phase_job()
	print("Fallback WorldPhase job created: ", not fallback_world.is_empty())
	
	var fallback_opportunity = JobDataAdapter.create_fallback_job_opportunity()
	print("Fallback JobOpportunity created: ", fallback_opportunity != null)