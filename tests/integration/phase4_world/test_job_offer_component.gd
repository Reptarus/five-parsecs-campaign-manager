extends GdUnitTestSuite
## Phase 4: World Phase Integration Tests - Part 2: Job Offer Component
## Tests JobOfferComponent business logic (job generation, acceptance/rejection)
## gdUnit4 v6.0.1 compatible (UI mode required)
## HIGH BUG DISCOVERY PROBABILITY - Job generation dice logic

# System under test
var JobOfferComponentScene
var component = null

# Test helper
var HelperClass
var helper = null

# Mock dice manager for testing
var mock_dice_result: int = 3  # Default dice roll

func before():
	"""Suite-level setup - runs once before all tests"""
	JobOfferComponentScene = load("res://src/ui/screens/world/components/JobOfferComponent.tscn")
	HelperClass = load("res://tests/helpers/WorldPhaseTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh component for each test"""
	component = auto_free(JobOfferComponentScene.instantiate())
	# Component needs to be in tree for event bus access and @onready variables
	add_child(component)

func after_test():
	"""Test-level cleanup"""
	if component and component.get_parent():
		remove_child(component)
	component = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	JobOfferComponentScene = null

# ============================================================================
# Job Generation Tests (Core Rules p.78-80) - 6 tests
# ============================================================================

func test_initialize_job_phase_generates_jobs():
	"""Initializing job phase generates at least 1 job offer"""
	var patron_data = {"patron_name": "Test Patron"}
	var location = "Fringe World Alpha"

	component.initialize_job_phase(patron_data, location)

	var jobs = component.get("available_jobs")
	assert_that(jobs).is_not_null()
	assert_that(jobs.size()).is_greater_equal(1)

func test_generated_job_has_required_fields():
	"""🐛 BUG DISCOVERY: Generated jobs must have all required fields"""
	var patron_data = {"patron_name": "Corporate Contact"}
	var location = "Core World"

	component.initialize_job_phase(patron_data, location)

	var jobs = component.get("available_jobs")
	assert_that(jobs.size()).is_greater_than(0)

	var job = jobs[0]
	# Validate job structure using helper
	var is_valid = helper.validate_job_structure(job)

	# EXPECTED: All jobs have required fields (id, patron, objective, pay, etc.)
	# ACTUAL: May be missing fields due to incomplete generation logic
	assert_that(is_valid).is_true()

func test_job_pay_calculation():
	"""Job pay should be 1d6 + 2 credits (Core Rules p.79)"""
	var patron_data = {"patron_name": "Merchant Guild"}
	component.initialize_job_phase(patron_data, "Test Location")

	var jobs = component.get("available_jobs")
	assert_that(jobs.size()).is_greater_than(0)

	var job = jobs[0]
	var pay = job.get("pay", 0)

	# Core Rules p.79: Pay = 1d6 + 2 = range 3-8 credits
	assert_that(pay).is_greater_equal(3)
	assert_that(pay).is_less_equal(8)

func test_job_danger_level_range():
	"""Danger level should be 1-3"""
	var patron_data = {}
	component.initialize_job_phase(patron_data, "Test Location")

	var jobs = component.get("available_jobs")
	for job in jobs:
		var danger = job.get("danger_level", 0)
		assert_that(danger).is_greater_equal(1)
		assert_that(danger).is_less_equal(3)

func test_job_enemy_type_assignment():
	"""Generated jobs should have valid enemy type"""
	component.initialize_job_phase({}, "Test Location")

	var jobs = component.get("available_jobs")
	for job in jobs:
		var enemy_type = job.get("enemy_type", "")
		assert_that(enemy_type).is_not_empty()

func test_job_objective_determination():
	"""Generated jobs should have valid objective"""
	component.initialize_job_phase({}, "Test Location")

	var jobs = component.get("available_jobs")
	for job in jobs:
		var objective = job.get("objective", "")
		assert_that(objective).is_not_empty()

# ============================================================================
# Job Acceptance Tests - 4 tests
# ============================================================================

func test_accept_selected_job_succeeds():
	"""Accepting selected job marks it as accepted"""
	component.initialize_job_phase({"patron_name": "Test"}, "Location")

	# Select first job
	component.set("selected_job_index", 0)

	var result = component.accept_selected_job()

	assert_that(result).is_true()
	assert_that(component.get("job_accepted")).is_true()

func test_cannot_accept_without_selection():
	"""🐛 BUG DISCOVERY: Cannot accept job without selection"""
	component.initialize_job_phase({"patron_name": "Test"}, "Location")

	# No job selected (index = -1)
	var result = component.accept_selected_job()

	# EXPECTED: Should fail when no job selected
	# ACTUAL: May allow accepting non-existent job
	assert_that(result).is_false()
	assert_that(component.get("job_accepted")).is_false()

func test_job_accepted_flag_set():
	"""Job accepted flag becomes true after acceptance"""
	component.initialize_job_phase({"patron_name": "Test"}, "Location")
	component.set("selected_job_index", 0)

	# Initially false
	assert_that(component.get("job_accepted")).is_false()

	component.accept_selected_job()

	# Now true
	assert_that(component.get("job_accepted")).is_true()

func test_get_accepted_job_data():
	"""Can retrieve accepted job details"""
	component.initialize_job_phase({"patron_name": "Test Patron"}, "Test Location")
	component.set("selected_job_index", 0)

	component.accept_selected_job()

	var jobs = component.get("available_jobs")
	var accepted_job = jobs[0]

	assert_that(accepted_job.get("patron", "")).is_equal("Test Patron")

# ============================================================================
# Job Rejection Tests - 3 tests
# ============================================================================

func test_decline_selected_job_removes_from_list():
	"""Declining job removes it from available list"""
	component.initialize_job_phase({"patron_name": "Test"}, "Location")

	var initial_count = component.get("available_jobs").size()
	component.set("selected_job_index", 0)

	component.decline_selected_job()

	var new_count = component.get("available_jobs").size()
	assert_that(new_count).is_equal(initial_count - 1)

func test_decline_resets_selection():
	"""Declining job resets selection index to -1"""
	component.initialize_job_phase({"patron_name": "Test"}, "Location")
	component.set("selected_job_index", 0)

	component.decline_selected_job()

	assert_that(component.get("selected_job_index")).is_equal(-1)

func test_decline_without_selection_does_nothing():
	"""Declining without selection has no effect"""
	component.initialize_job_phase({"patron_name": "Test"}, "Location")

	var initial_count = component.get("available_jobs").size()

	# No job selected
	component.decline_selected_job()

	var new_count = component.get("available_jobs").size()
	assert_that(new_count).is_equal(initial_count)
