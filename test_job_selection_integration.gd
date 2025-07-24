@tool
extends EditorScript

## Test script for JobSelectionUI WorldPhase integration - Feature 8
## Run this from the editor to test the integration

func _run() -> void:
	print("=== Testing JobSelectionUI WorldPhase Integration ===")
	
	# Test 1: Basic initialization
	test_basic_initialization()
	
	# Test 2: JobDataAdapter conversion
	test_job_data_adapter()
	
	# Test 3: WorldPhase job generation
	test_world_phase_job_generation()
	
	print("=== Integration Tests Complete ===")

func test_basic_initialization() -> void:
	print("\n--- Test 1: Basic Initialization ---")
	
	var job_ui = load("res://src/ui/screens/world/JobSelectionUI.gd").new()
	
	# Test property initialization
	print("WorldPhase integration enabled: %s" % job_ui.use_world_phase_jobs)
	print("Fallback to internal enabled: %s" % job_ui.fallback_to_internal)
	print("Current job type: %s" % job_ui.current_job_type)
	
	job_ui.queue_free()
	print("✓ Basic initialization test passed")

func test_job_data_adapter() -> void:
	print("\n--- Test 2: JobDataAdapter Conversion ---")
	
	# Load JobDataAdapter
	var JobDataAdapter = load("res://src/core/world_phase/JobDataAdapter.gd")
	
	# Test WorldPhase to UI conversion
	var world_job = {
		"id": "test_job_123",
		"type": "patron",
		"mission_type": "Deliver",
		"danger_level": 2,
		"payment": 500,
		"description": "Test delivery mission",
		"requirements": ["Combat experience"],
		"time_limit": 4
	}
	
	var ui_job = JobDataAdapter.convert_world_phase_to_ui(world_job)
	
	if ui_job:
		print("✓ WorldPhase to UI conversion successful")
		print("  Job ID: %s" % ui_job.get_meta("job_id"))
		print("  Job Type: %s" % ui_job.get_meta("job_type"))
		print("  Reward: %d" % ui_job.get_meta("reward_credits"))
	else:
		print("✗ WorldPhase to UI conversion failed")
		return
	
	# Test roundtrip conversion
	var world_job_roundtrip = JobDataAdapter.convert_ui_to_world_phase(ui_job)
	
	if world_job_roundtrip.has("id") and world_job_roundtrip["id"] == world_job["id"]:
		print("✓ Roundtrip conversion successful")
	else:
		print("✗ Roundtrip conversion failed")

func test_world_phase_job_generation() -> void:
	print("\n--- Test 3: WorldPhase Job Generation ---")
	
	# Test job type matching
	var job_ui = load("res://src/ui/screens/world/JobSelectionUI.gd").new()
	
	var patron_job = {"type": "patron"}
	var opportunity_job = {"type": "opportunity"}
	var quest_job = {"type": "quest"}
	
	print("Patron job matches 'patron': %s" % job_ui._job_matches_type(patron_job, "patron"))
	print("Opportunity job matches 'opportunity': %s" % job_ui._job_matches_type(opportunity_job, "opportunity"))
	print("Quest job matches 'quest': %s" % job_ui._job_matches_type(quest_job, "quest"))
	
	# Test WorldPhase job creation
	var test_world_job = job_ui._create_world_phase_job("patron", 1)
	
	if test_world_job.has("id") and test_world_job.has("type"):
		print("✓ WorldPhase job creation successful")
		print("  Created job: %s (%s)" % [test_world_job["id"], test_world_job["type"]])
	else:
		print("✗ WorldPhase job creation failed")
	
	job_ui.queue_free()
	print("✓ WorldPhase job generation test completed")