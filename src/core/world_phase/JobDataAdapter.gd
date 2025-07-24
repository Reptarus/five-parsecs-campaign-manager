@tool
extends RefCounted
class_name JobDataAdapter

## Job Data Adapter - Feature 8 Implementation
## Unified job data conversion between JobSelectionUI, WorldPhase, and WorldPhaseResources
## Supports seamless integration across all job systems in Godot v4.4.1-stable

const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")

## Job metadata field mappings for conversion
const FIELD_MAPPINGS = {
	"JobSelectionUI": {
		"id": "job_id",
		"type": "job_type", 
		"mission": "mission_type",
		"difficulty": "difficulty",
		"payment": "reward_credits",
		"description": "description",
		"requirements": "requirements",
		"time_limit": "time_limit",
		"title": "title",
		"risk_level": "risk_level",
		"special_type": "special_type"
	},
	"WorldPhase": {
		"id": "id",
		"type": "type",
		"mission": "mission_type",
		"difficulty": "danger_level",
		"payment": "payment",
		"description": "description",
		"requirements": "requirements",
		"time_limit": "time_limit",
		"patron_id": "patron_id",
		"patron_name": "patron_name"
	},
	"JobOpportunity": {
		"id": "job_id",
		"type": "job_type",
		"mission": "job_title",
		"difficulty": "danger_level",
		"payment": "base_payment",
		"description": "description",
		"requirements": "requirements",
		"time_limit": "time_limit",
		"patron_id": "patron_id",
		"patron_name": "patron_name"
	}
}

## Job type normalization mappings
const JOB_TYPE_MAPPING = {
	"patron": "patron",
	"opportunity": "opportunity", 
	"quest": "quest",
	"trade": "trade",
	"trade_opportunity": "trade"
}

## Validation rules for job data
const VALIDATION_RULES = {
	"required_fields": ["id", "type", "payment"],
	"min_payment": 50,
	"max_payment": 10000,
	"min_difficulty": 1,
	"max_difficulty": 5,
	"valid_job_types": ["patron", "opportunity", "quest", "trade"]
}

## Statistics tracking for diagnostics
static var conversion_stats = {
	"conversions_performed": 0,
	"validation_failures": 0,
	"last_error": "",
	"conversion_history": []
}

## Convert WorldPhase Dictionary job to JobSelectionUI Resource format
static func convert_world_phase_to_ui(world_job: Dictionary) -> Resource:
	if not _validate_world_phase_job(world_job):
		push_error("JobDataAdapter: Invalid WorldPhase job data: %s" % world_job)
		return _create_fallback_ui_job()
	
	var ui_job := Resource.new()
	
	# Core job properties
	ui_job.set_meta("job_id", world_job.get("id", _generate_job_id()))
	ui_job.set_meta("job_type", _normalize_job_type(world_job.get("type", "opportunity")))
	ui_job.set_meta("mission_type", world_job.get("mission_type", "Standard"))
	ui_job.set_meta("difficulty", world_job.get("danger_level", 1))
	ui_job.set_meta("reward_credits", world_job.get("payment", 300))
	ui_job.set_meta("description", world_job.get("description", "Mission briefing not available"))
	ui_job.set_meta("requirements", world_job.get("requirements", []))
	ui_job.set_meta("time_limit", world_job.get("time_limit", 3))
	
	# Extended properties for enhanced jobs
	if world_job.has("patron_id"):
		ui_job.set_meta("patron_id", world_job["patron_id"])
	if world_job.has("patron_name"):
		ui_job.set_meta("patron_name", world_job["patron_name"])
	if world_job.has("location"):
		ui_job.set_meta("location", world_job["location"])
	
	_record_conversion("world_phase_to_ui", true)
	return ui_job

## Convert JobSelectionUI Resource to WorldPhase Dictionary format
static func convert_ui_to_world_phase(ui_job: Resource) -> Dictionary:
	if not _validate_ui_job(ui_job):
		push_error("JobDataAdapter: Invalid UI job resource")
		return _create_fallback_world_phase_job()
	
	var world_job = {
		"id": ui_job.get_meta("job_id", _generate_job_id()),
		"type": _normalize_job_type(ui_job.get_meta("job_type", "opportunity")),
		"mission_type": ui_job.get_meta("mission_type", "Standard"),
		"danger_level": ui_job.get_meta("difficulty", 1),
		"payment": ui_job.get_meta("reward_credits", 300),
		"description": ui_job.get_meta("description", "Mission briefing not available"),
		"requirements": ui_job.get_meta("requirements", []),
		"time_limit": ui_job.get_meta("time_limit", 3)
	}
	
	# Include patron information if available
	if ui_job.has_meta("patron_id"):
		world_job["patron_id"] = ui_job.get_meta("patron_id")
	if ui_job.has_meta("patron_name"):
		world_job["patron_name"] = ui_job.get_meta("patron_name")
	if ui_job.has_meta("location"):
		world_job["location"] = ui_job.get_meta("location")
	
	_record_conversion("ui_to_world_phase", true)
	return world_job

## Convert JobSelectionUI Resource to WorldPhaseResources.JobOpportunity
static func convert_ui_to_job_opportunity(ui_job: Resource) -> WorldPhaseResources.JobOpportunity:
	if not _validate_ui_job(ui_job):
		push_error("JobDataAdapter: Invalid UI job resource for JobOpportunity conversion")
		return _create_fallback_job_opportunity()
	
	var job_opportunity = WorldPhaseResources.create_job_opportunity(
		ui_job.get_meta("job_id", _generate_job_id()),
		ui_job.get_meta("mission_type", "Standard"),
		_normalize_job_type(ui_job.get_meta("job_type", "opportunity"))
	)
	
	# Set core properties
	job_opportunity.base_payment = ui_job.get_meta("reward_credits", 300)
	job_opportunity.danger_level = ui_job.get_meta("difficulty", 1)
	job_opportunity.description = ui_job.get_meta("description", "Mission briefing not available")
	job_opportunity.requirements = ui_job.get_meta("requirements", [])
	job_opportunity.time_limit = ui_job.get_meta("time_limit", 3)
	
	# Set patron information if available
	if ui_job.has_meta("patron_id"):
		job_opportunity.patron_id = ui_job.get_meta("patron_id")
	if ui_job.has_meta("patron_name"):
		job_opportunity.patron_name = ui_job.get_meta("patron_name")
	
	# Set location if available
	if ui_job.has_meta("location"):
		job_opportunity.job_location = ui_job.get_meta("location")
	
	_record_conversion("ui_to_job_opportunity", true)
	return job_opportunity

## Convert WorldPhaseResources.JobOpportunity to JobSelectionUI Resource
static func convert_job_opportunity_to_ui(job_opportunity: WorldPhaseResources.JobOpportunity) -> Resource:
	if not _validate_job_opportunity(job_opportunity):
		push_error("JobDataAdapter: Invalid JobOpportunity for UI conversion")
		return _create_fallback_ui_job()
	
	var ui_job := Resource.new()
	
	# Core properties from JobOpportunity
	ui_job.set_meta("job_id", job_opportunity.job_id)
	ui_job.set_meta("job_type", _normalize_job_type(job_opportunity.job_type))
	ui_job.set_meta("mission_type", job_opportunity.job_title)
	ui_job.set_meta("difficulty", job_opportunity.danger_level)
	ui_job.set_meta("reward_credits", job_opportunity.base_payment)
	ui_job.set_meta("description", job_opportunity.description)
	ui_job.set_meta("requirements", job_opportunity.requirements)
	ui_job.set_meta("time_limit", job_opportunity.time_limit)
	
	# Patron information
	if not job_opportunity.patron_id.is_empty():
		ui_job.set_meta("patron_id", job_opportunity.patron_id)
	if not job_opportunity.patron_name.is_empty():
		ui_job.set_meta("patron_name", job_opportunity.patron_name)
	
	# Location information
	if not job_opportunity.job_location.is_empty():
		ui_job.set_meta("location", job_opportunity.job_location)
	
	_record_conversion("job_opportunity_to_ui", true)
	return ui_job

## Convert WorldPhase Dictionary to WorldPhaseResources.JobOpportunity
static func convert_world_phase_to_job_opportunity(world_job: Dictionary) -> WorldPhaseResources.JobOpportunity:
	if not _validate_world_phase_job(world_job):
		push_error("JobDataAdapter: Invalid WorldPhase job for JobOpportunity conversion")
		return _create_fallback_job_opportunity()
	
	var job_opportunity = WorldPhaseResources.create_job_opportunity(
		world_job.get("id", _generate_job_id()),
		world_job.get("mission_type", "Standard"),
		_normalize_job_type(world_job.get("type", "opportunity"))
	)
	
	# Set properties from world job
	job_opportunity.base_payment = world_job.get("payment", 300)
	job_opportunity.danger_level = world_job.get("danger_level", 1)
	job_opportunity.description = world_job.get("description", "Mission briefing not available")
	job_opportunity.requirements = world_job.get("requirements", [])
	job_opportunity.time_limit = world_job.get("time_limit", 3)
	
	# Set patron information if available
	if world_job.has("patron_id"):
		job_opportunity.patron_id = world_job["patron_id"]
	if world_job.has("patron_name"):
		job_opportunity.patron_name = world_job["patron_name"]
	if world_job.has("location"):
		job_opportunity.job_location = world_job["location"]
	
	_record_conversion("world_phase_to_job_opportunity", true)
	return job_opportunity

## Convert WorldPhaseResources.JobOpportunity to WorldPhase Dictionary
static func convert_job_opportunity_to_world_phase(job_opportunity: WorldPhaseResources.JobOpportunity) -> Dictionary:
	if not _validate_job_opportunity(job_opportunity):
		push_error("JobDataAdapter: Invalid JobOpportunity for WorldPhase conversion")
		return _create_fallback_world_phase_job()
	
	var world_job = {
		"id": job_opportunity.job_id,
		"type": _normalize_job_type(job_opportunity.job_type),
		"mission_type": job_opportunity.job_title,
		"danger_level": job_opportunity.danger_level,
		"payment": job_opportunity.base_payment,
		"description": job_opportunity.description,
		"requirements": job_opportunity.requirements,
		"time_limit": job_opportunity.time_limit
	}
	
	# Include patron information
	if not job_opportunity.patron_id.is_empty():
		world_job["patron_id"] = job_opportunity.patron_id
	if not job_opportunity.patron_name.is_empty():
		world_job["patron_name"] = job_opportunity.patron_name
	if not job_opportunity.job_location.is_empty():
		world_job["location"] = job_opportunity.job_location
	
	_record_conversion("job_opportunity_to_world_phase", true)
	return world_job

## Batch conversion methods for performance optimization

## Convert array of WorldPhase jobs to UI resources
static func convert_world_phase_batch_to_ui(world_jobs: Array[Dictionary]) -> Array[Resource]:
	var ui_jobs: Array[Resource] = []
	for world_job in world_jobs:
		ui_jobs.append(convert_world_phase_to_ui(world_job))
	return ui_jobs

## Convert array of UI resources to WorldPhase dictionaries
static func convert_ui_batch_to_world_phase(ui_jobs: Array[Resource]) -> Array[Dictionary]:
	var world_jobs: Array[Dictionary] = []
	for ui_job in ui_jobs:
		world_jobs.append(convert_ui_to_world_phase(ui_job))
	return world_jobs

## Convert array of JobOpportunities to UI resources
static func convert_job_opportunities_batch_to_ui(job_opportunities: Array[WorldPhaseResources.JobOpportunity]) -> Array[Resource]:
	var ui_jobs: Array[Resource] = []
	for job_opportunity in job_opportunities:
		ui_jobs.append(convert_job_opportunity_to_ui(job_opportunity))
	return ui_jobs

## Validation methods

## Validate WorldPhase job dictionary
static func _validate_world_phase_job(world_job: Dictionary) -> bool:
	if not world_job.has("id") or world_job["id"] == "":
		_record_conversion("world_phase_validation", false, "Missing or empty job ID")
		return false
	
	if not world_job.has("type") or not VALIDATION_RULES.valid_job_types.has(world_job["type"]):
		_record_conversion("world_phase_validation", false, "Invalid or missing job type")
		return false
	
	var payment = world_job.get("payment", 0)
	if payment < VALIDATION_RULES.min_payment or payment > VALIDATION_RULES.max_payment:
		_record_conversion("world_phase_validation", false, "Payment out of valid range")
		return false
	
	return true

## Validate JobSelectionUI resource
static func _validate_ui_job(ui_job: Resource) -> bool:
	if not ui_job:
		_record_conversion("ui_validation", false, "Null job resource")
		return false
	
	if not ui_job.has_meta("job_id") or ui_job.get_meta("job_id") == "":
		_record_conversion("ui_validation", false, "Missing job_id metadata")
		return false
	
	var payment = ui_job.get_meta("reward_credits", 0)
	if payment < VALIDATION_RULES.min_payment or payment > VALIDATION_RULES.max_payment:
		_record_conversion("ui_validation", false, "Reward credits out of valid range")
		return false
	
	return true

## Validate JobOpportunity resource
static func _validate_job_opportunity(job_opportunity: WorldPhaseResources.JobOpportunity) -> bool:
	if not job_opportunity:
		_record_conversion("job_opportunity_validation", false, "Null JobOpportunity")
		return false
	
	if not job_opportunity.validate():
		_record_conversion("job_opportunity_validation", false, "JobOpportunity failed internal validation")
		return false
	
	if job_opportunity.base_payment < VALIDATION_RULES.min_payment or job_opportunity.base_payment > VALIDATION_RULES.max_payment:
		_record_conversion("job_opportunity_validation", false, "Base payment out of valid range")
		return false
	
	return true

## Utility methods

## Normalize job type to standard values
static func _normalize_job_type(job_type: String) -> String:
	var normalized = job_type.to_lower().strip_edges()
	return JOB_TYPE_MAPPING.get(normalized, "opportunity")

## Generate unique job ID
static func _generate_job_id() -> String:
	return "job_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]

## Create fallback UI job for error cases
static func _create_fallback_ui_job() -> Resource:
	var ui_job := Resource.new()
	ui_job.set_meta("job_id", _generate_job_id())
	ui_job.set_meta("job_type", "opportunity")
	ui_job.set_meta("mission_type", "Emergency")
	ui_job.set_meta("difficulty", 1)
	ui_job.set_meta("reward_credits", 200)
	ui_job.set_meta("description", "Emergency fallback mission - data conversion failed")
	ui_job.set_meta("requirements", [])
	ui_job.set_meta("time_limit", 3)
	return ui_job

## Create fallback WorldPhase job for error cases
static func _create_fallback_world_phase_job() -> Dictionary:
	return {
		"id": _generate_job_id(),
		"type": "opportunity",
		"mission_type": "Emergency",
		"danger_level": 1,
		"payment": 200,
		"description": "Emergency fallback mission - data conversion failed",
		"requirements": [],
		"time_limit": 3
	}

## Create fallback JobOpportunity for error cases
static func _create_fallback_job_opportunity() -> WorldPhaseResources.JobOpportunity:
	var job_opportunity = WorldPhaseResources.create_job_opportunity(
		_generate_job_id(),
		"Emergency",
		"opportunity"
	)
	job_opportunity.base_payment = 200
	job_opportunity.danger_level = 1
	job_opportunity.description = "Emergency fallback mission - data conversion failed"
	job_opportunity.requirements = []
	job_opportunity.time_limit = 3
	return job_opportunity

## Record conversion statistics for diagnostics
static func _record_conversion(conversion_type: String, success: bool, error_message: String = "") -> void:
	conversion_stats.conversions_performed += 1
	if not success:
		conversion_stats.validation_failures += 1
		conversion_stats.last_error = "%s: %s" % [conversion_type, error_message]
	
	# Keep circular buffer of last 50 conversions
	conversion_stats.conversion_history.append({
		"type": conversion_type,
		"success": success,
		"timestamp": Time.get_datetime_string_from_system(),
		"error": error_message
	})
	
	if conversion_stats.conversion_history.size() > 50:
		conversion_stats.conversion_history.pop_front()

## Diagnostic and testing methods

## Get conversion statistics
static func get_conversion_stats() -> Dictionary:
	return conversion_stats.duplicate()

## Reset conversion statistics
static func reset_conversion_stats() -> void:
	conversion_stats = {
		"conversions_performed": 0,
		"validation_failures": 0,
		"last_error": "",
		"conversion_history": []
	}

## Test all conversion paths with sample data
static func test_all_conversions() -> Dictionary:
	var test_results = {
		"tests_passed": 0,
		"tests_failed": 0,
		"test_details": []
	}
	
	# Test UI -> WorldPhase -> UI roundtrip
	var sample_ui_job = _create_sample_ui_job()
	var world_job = convert_ui_to_world_phase(sample_ui_job)
	var roundtrip_ui_job = convert_world_phase_to_ui(world_job)
	
	if _compare_ui_jobs(sample_ui_job, roundtrip_ui_job):
		test_results.tests_passed += 1
		test_results.test_details.append("UI -> WorldPhase -> UI: PASSED")
	else:
		test_results.tests_failed += 1
		test_results.test_details.append("UI -> WorldPhase -> UI: FAILED")
	
	# Test JobOpportunity -> UI -> JobOpportunity roundtrip
	var sample_job_opportunity = _create_sample_job_opportunity()
	var ui_job = convert_job_opportunity_to_ui(sample_job_opportunity)
	var roundtrip_job_opportunity = convert_ui_to_job_opportunity(ui_job)
	
	if _compare_job_opportunities(sample_job_opportunity, roundtrip_job_opportunity):
		test_results.tests_passed += 1
		test_results.test_details.append("JobOpportunity -> UI -> JobOpportunity: PASSED")
	else:
		test_results.tests_failed += 1
		test_results.test_details.append("JobOpportunity -> UI -> JobOpportunity: FAILED")
	
	return test_results

## Create sample UI job for testing
static func _create_sample_ui_job() -> Resource:
	var ui_job := Resource.new()
	ui_job.set_meta("job_id", "test_job_123")
	ui_job.set_meta("job_type", "patron")
	ui_job.set_meta("mission_type", "Deliver")
	ui_job.set_meta("difficulty", 2)
	ui_job.set_meta("reward_credits", 500)
	ui_job.set_meta("description", "Test delivery mission")
	ui_job.set_meta("requirements", ["Combat experience"])
	ui_job.set_meta("time_limit", 4)
	return ui_job

## Create sample JobOpportunity for testing
static func _create_sample_job_opportunity() -> WorldPhaseResources.JobOpportunity:
	var job_opportunity = WorldPhaseResources.create_job_opportunity(
		"test_opportunity_456",
		"Patrol",
		"opportunity"
	)
	job_opportunity.base_payment = 350
	job_opportunity.danger_level = 2
	job_opportunity.description = "Test patrol mission"
	job_opportunity.requirements = ["Navigation skills"]
	job_opportunity.time_limit = 2
	return job_opportunity

## Compare UI jobs for testing
static func _compare_ui_jobs(job1: Resource, job2: Resource) -> bool:
	var key_fields = ["job_id", "job_type", "mission_type", "difficulty", "reward_credits"]
	for field in key_fields:
		if job1.get_meta(field) != job2.get_meta(field):
			return false
	return true

## Compare JobOpportunities for testing
static func _compare_job_opportunities(job1: WorldPhaseResources.JobOpportunity, job2: WorldPhaseResources.JobOpportunity) -> bool:
	return (job1.job_id == job2.job_id and 
			job1.job_type == job2.job_type and
			job1.job_title == job2.job_title and
			job1.danger_level == job2.danger_level and
			job1.base_payment == job2.base_payment)

## Universal Safety Framework integration
static func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	return WorldPhaseResources.safe_get_property(obj, property, default_value)

static func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	return WorldPhaseResources.safe_call_method(obj, method_name, args)