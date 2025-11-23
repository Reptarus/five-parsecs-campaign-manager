class_name WorldPhaseTestHelper
## Phase 4 Helper: World Phase Component and Controller Testing
## Provides mock campaign/crew/equipment/job data, event bus utilities, and validation
## Plain class (no Node inheritance) for gdUnit4 v6.0.1 compatibility

## Mock Campaign Data Generators

func create_mock_campaign_data() -> Dictionary:
	"""Create minimal valid campaign data for world phase testing"""
	return {
		"campaign_id": "test_campaign_001",
		"campaign_name": "Test Campaign",
		"turn_number": 5,
		"credits": 50,
		"story_points": 3,
		"patron_jobs": 2,
		"difficulty": 1,
		"current_location": "Fringe World Alpha",
		"ship_debt": 0,
		"crew_count": 4
	}

func create_full_campaign_data() -> Dictionary:
	"""Create detailed campaign data with all fields"""
	var campaign = create_mock_campaign_data()
	campaign["ship_name"] = "The Wanderer"
	campaign["ship_hull"] = 20
	campaign["ship_fuel"] = 15
	campaign["rivals"] = 1
	campaign["rumors"] = 2
	campaign["upkeep_cost"] = 6
	campaign["crew_tasks_available"] = 4
	return campaign

## Mock Crew Data Generators

func create_mock_crew_member(
	crew_name: String = "Test Crew",
	crew_id: String = "",
	with_equipment: bool = false
) -> Dictionary:
	"""Create mock crew member dictionary"""
	var id = crew_id if crew_id != "" else "crew_%s" % crew_name.to_lower().replace(" ", "_")
	var crew = {
		"id": id,
		"name": crew_name,
		"species": "HUMAN",
		"background": "MILITARY",
		"motivation": "GLORY",
		"class": "SOLDIER",
		"reactions": 1,
		"speed": 4,
		"combat_skill": 1,
		"toughness": 3,
		"savvy": 1,
		"luck": 0,
		"experience": 0,
		"equipment": [],
		"status": "ACTIVE",
		"injuries": []
	}

	if with_equipment:
		crew["equipment"] = ["weapon_pistol", "armor_vest"]

	return crew

func create_mock_crew_data(crew_count: int = 4, with_equipment: bool = false) -> Array[Dictionary]:
	"""Create array of mock crew members"""
	var crew_list: Array[Dictionary] = []
	for i in range(crew_count):
		crew_list.append(create_mock_crew_member(
			"Crew Member %d" % (i + 1),
			"crew_%03d" % (i + 1),
			with_equipment
		))
	return crew_list

## Mock Equipment Data Generators

func create_mock_equipment_item(
	equipment_name: String = "Test Equipment",
	equipment_id: String = "",
	equipment_type: String = "weapon"
) -> Dictionary:
	"""Create mock equipment item dictionary"""
	var id = equipment_id if equipment_id != "" else "equip_%s" % equipment_name.to_lower().replace(" ", "_")
	return {
		"id": id,
		"name": equipment_name,
		"type": equipment_type,
		"damage": 1 if equipment_type == "weapon" else 0,
		"range": 12 if equipment_type == "weapon" else 0,
		"shots": 2 if equipment_type == "weapon" else 0,
		"traits": [],
		"cost": 10,
		"description": "Test equipment for %s" % equipment_type
	}

func create_mock_equipment_data(equipment_count: int = 6) -> Array[Dictionary]:
	"""Create array of mock equipment items (mix of weapons and gear)"""
	var equipment_list: Array[Dictionary] = []
	var weapons_count = int(equipment_count / 2.0)
	var gear_count = equipment_count - weapons_count

	# Add weapons
	for i in range(weapons_count):
		equipment_list.append(create_mock_equipment_item(
			"Weapon %d" % (i + 1),
			"weapon_%03d" % (i + 1),
			"weapon"
		))

	# Add gear
	for i in range(gear_count):
		equipment_list.append(create_mock_equipment_item(
			"Gear %d" % (i + 1),
			"gear_%03d" % (i + 1),
			"gear"
		))

	return equipment_list

## Mock Job Data Generators

func create_mock_job_data(
	job_id: String = "job_001",
	patron_name: String = "Test Patron",
	pay: int = 5,
	danger_level: int = 1
) -> Dictionary:
	"""Create mock job offer dictionary (Core Rules p.78-80)"""
	return {
		"id": job_id,
		"patron": patron_name,
		"objective": "Eliminate Raiders",
		"enemy_type": "RAIDERS",
		"danger_level": danger_level,
		"pay": pay,
		"location": "Fringe World Alpha",
		"required_crew_size": 3,
		"special_conditions": [],
		"description": "Test job offer from %s" % patron_name
	}

func create_multiple_job_offers(job_count: int = 3) -> Array[Dictionary]:
	"""Create array of mock job offers"""
	var jobs: Array[Dictionary] = []
	var patrons = ["Merchant Guild", "Local Government", "Corporate Contact", "Crime Boss"]
	var objectives = ["Eliminate Raiders", "Defend Settlement", "Recover Artifact", "Escort Mission"]
	var enemies = ["RAIDERS", "MUTANTS", "RIVALS", "CORPORATE_TROOPS"]

	for i in range(job_count):
		jobs.append(create_mock_job_data(
			"job_%03d" % (i + 1),
			patrons[i % patrons.size()],
			3 + i,  # Pay increases
			1 + (i % 3)  # Danger level 1-3
		))
		jobs[i]["objective"] = objectives[i % objectives.size()]
		jobs[i]["enemy_type"] = enemies[i % enemies.size()]

	return jobs

## Mock Ship Data

func create_mock_ship_data() -> Dictionary:
	"""Create mock ship data for upkeep phase"""
	return {
		"ship_name": "The Wanderer",
		"ship_hull": 20,
		"ship_fuel": 15,
		"ship_debt": 0,
		"crew_quarters": 8,
		"cargo_space": 10,
		"upgrades": ["IMPROVED_ENGINES"]
	}

## Validation Functions

func validate_job_structure(job: Dictionary) -> bool:
	"""Validate job offer has all required fields (Core Rules p.78-80)"""
	var required_fields = [
		"id", "patron", "objective", "enemy_type",
		"danger_level", "pay", "location"
	]

	for field in required_fields:
		if not job.has(field):
			push_error("WorldPhaseTestHelper: Job missing required field: %s" % field)
			return false

	# Validate ranges
	if job["danger_level"] < 1 or job["danger_level"] > 3:
		push_error("WorldPhaseTestHelper: Invalid danger_level: %d (must be 1-3)" % job["danger_level"])
		return false

	if job["pay"] < 0:
		push_error("WorldPhaseTestHelper: Invalid pay: %d (must be >= 0)" % job["pay"])
		return false

	return true

func validate_equipment_assignment(assignments: Dictionary) -> bool:
	"""Validate equipment assignment dictionary structure"""
	if assignments.is_empty():
		return true  # Empty assignments are valid

	# Check each crew_id maps to array of equipment_ids
	for crew_id in assignments.keys():
		if not crew_id is String:
			push_error("WorldPhaseTestHelper: crew_id must be String, got %s" % typeof(crew_id))
			return false

		var equipment_ids = assignments[crew_id]
		if not equipment_ids is Array:
			push_error("WorldPhaseTestHelper: equipment_ids must be Array, got %s" % typeof(equipment_ids))
			return false

		# Check for duplicate equipment assignments
		var unique_equipment = {}
		for equipment_id in equipment_ids:
			if not equipment_id is String:
				push_error("WorldPhaseTestHelper: equipment_id must be String, got %s" % typeof(equipment_id))
				return false
			if unique_equipment.has(equipment_id):
				push_error("WorldPhaseTestHelper: Duplicate equipment assignment: %s" % equipment_id)
				return false
			unique_equipment[equipment_id] = true

	return true

func validate_crew_readiness(readiness: Dictionary) -> bool:
	"""Validate crew readiness check result structure"""
	var required_fields = [
		"is_ready", "warnings", "crew_count",
		"equipped_crew", "total_equipment"
	]

	for field in required_fields:
		if not readiness.has(field):
			push_error("WorldPhaseTestHelper: Readiness missing required field: %s" % field)
			return false

	# Type validation
	if not readiness["is_ready"] is bool:
		push_error("WorldPhaseTestHelper: is_ready must be bool")
		return false

	if not readiness["warnings"] is Array:
		push_error("WorldPhaseTestHelper: warnings must be Array")
		return false

	if not readiness["crew_count"] is int:
		push_error("WorldPhaseTestHelper: crew_count must be int")
		return false

	return true

func validate_world_phase_results(results: Dictionary) -> bool:
	"""Validate world phase completion results structure"""
	var required_fields = [
		"upkeep_completed", "crew_tasks_completed",
		"job_accepted", "mission_prepared"
	]

	for field in required_fields:
		if not results.has(field):
			push_error("WorldPhaseTestHelper: Results missing field: %s" % field)
			return false

	return true

## Event Bus Helper Functions

func create_test_event_bus() -> Node:
	"""Create a CampaignTurnEventBus instance for testing"""
	var EventBusScript = load("res://src/core/events/CampaignTurnEventBus.gd")
	var event_bus = EventBusScript.new()
	event_bus.name = "TestCampaignTurnEventBus"
	event_bus.debug_mode = true  # Enable debug logging for tests
	return event_bus

func count_event_subscribers(event_bus: Node, event_type: int) -> int:
	"""Count number of subscribers for a specific event type"""
	var subscribers = event_bus.get("event_subscribers")
	if subscribers == null:
		return 0

	if not subscribers.has(event_type):
		return 0

	return subscribers[event_type].size()

func get_published_events(event_bus: Node, event_type: int = -1) -> Array:
	"""Get published events from event bus history (optionally filtered by type)"""
	var history = event_bus.get("event_history")
	if history == null:
		return []

	if event_type == -1:
		return history.duplicate()

	# Filter by event type
	var filtered: Array = []
	for event in history:
		if event.get("event_type", -999) == event_type:
			filtered.append(event)

	return filtered

func clear_event_history(event_bus: Node) -> void:
	"""Clear event bus history (useful for test isolation)"""
	var history = event_bus.get("event_history")
	if history != null:
		history.clear()

## Signal Flow Validation

func validate_signal_flow(
	source_node: Node,
	event_bus: Node,
	expected_event_type: int,
	timeout: float = 1.0
) -> bool:
	"""
	Validate that a source node publishes expected event to event bus.
	Returns true if event found in history within timeout.
	"""
	var start_time = Time.get_unix_time_from_system()
	var initial_event_count = get_published_events(event_bus, expected_event_type).size()

	# Wait for event publication (with timeout)
	while (Time.get_unix_time_from_system() - start_time) < timeout:
		var current_events = get_published_events(event_bus, expected_event_type)
		if current_events.size() > initial_event_count:
			return true  # New event detected
		await source_node.get_tree().create_timer(0.1).timeout

	return false  # Timeout reached, no new event

func wait_for_event_publication(
	event_bus: Node,
	event_type: int,
	timeout: float = 1.0
) -> bool:
	"""
	Wait for specific event type to be published to event bus.
	Returns true if event found within timeout.
	"""
	var start_time = Time.get_unix_time_from_system()
	var initial_count = get_published_events(event_bus, event_type).size()

	while (Time.get_unix_time_from_system() - start_time) < timeout:
		var current_count = get_published_events(event_bus, event_type).size()
		if current_count > initial_count:
			return true
		# Small delay to prevent busy-waiting
		await Engine.get_main_loop().create_timer(0.05).timeout

	return false

## Component State Snapshot Functions

func capture_controller_state(controller: Node) -> Dictionary:
	"""Capture WorldPhaseController state for comparison"""
	var current_step = controller.get("current_step")
	var automation_enabled = controller.get("automation_enabled")
	var phase_results = controller.get("phase_results")
	var step_completed = controller.get("step_completed")

	return {
		"current_step": current_step if current_step != null else -1,
		"automation_enabled": automation_enabled if automation_enabled != null else false,
		"phase_results": phase_results.duplicate() if phase_results != null else {},
		"step_completed_flags": step_completed.duplicate() if step_completed != null else []
	}

func capture_component_state(component: Node) -> Dictionary:
	"""Capture component state (generic - works for any component)"""
	var state = {
		"component_name": component.name,
		"visible": component.visible
	}

	# Capture common component flags
	var phase_completed = component.get("phase_completed")
	if phase_completed != null:
		state["phase_completed"] = phase_completed

	var automation_enabled = component.get("automation_enabled")
	if automation_enabled != null:
		state["automation_enabled"] = automation_enabled

	return state

func compare_states(before: Dictionary, after: Dictionary) -> Dictionary:
	"""
	Compare two state snapshots and return differences.
	Returns dict with "changed_fields" array and "details" dict.
	"""
	var result = {
		"changed_fields": [],
		"details": {}
	}

	# Find changed fields
	for key in before.keys():
		if not after.has(key):
			result["changed_fields"].append(key)
			result["details"][key] = {"before": before[key], "after": null, "status": "REMOVED"}
		elif before[key] != after[key]:
			result["changed_fields"].append(key)
			result["details"][key] = {"before": before[key], "after": after[key], "status": "CHANGED"}

	# Find new fields
	for key in after.keys():
		if not before.has(key):
			result["changed_fields"].append(key)
			result["details"][key] = {"before": null, "after": after[key], "status": "ADDED"}

	return result
