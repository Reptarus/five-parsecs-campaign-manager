class_name BattleTestHelper
## Phase 2A Helper: Battle Initialization and State Testing
## Provides mock battle data, validation, and state management for integration tests
## Plain class (no Node inheritance) for gdUnit4 v6.0.1 compatibility

## Mock battle data generators

func create_minimal_mission() -> Resource:
	"""Create minimal valid mission data for testing"""
	var mission = Resource.new()
	mission.set_meta("name", "Test Mission")
	mission.set_meta("mission_type", "OPPORTUNITY")
	mission.set_meta("mission_id", "test_mission_001")
	mission.set_meta("difficulty", 1)
	mission.set_meta("credits_reward", 10)
	return mission

func create_full_mission() -> Resource:
	"""Create detailed mission data for complex testing"""
	var mission = create_minimal_mission()
	mission.set_meta("description", "Test battle mission with full details")
	mission.set_meta("enemy_type", "RAIDERS")
	mission.set_meta("enemy_count", 5)
	mission.set_meta("battlefield_size", Vector2i(20, 20))
	mission.set_meta("victory_conditions", {"eliminate_enemies": true})
	mission.set_meta("special_rules", ["cover_bonus", "night_fighting"])
	return mission

func create_mock_crew_member(crew_name: String = "Test Crew", equipped_items: Array = []) -> Resource:
	"""Create mock crew member with optional equipment"""
	var crew = Resource.new()
	crew.set_meta("name", crew_name)
	crew.set_meta("species", "HUMAN")
	crew.set_meta("reactions", 1)
	crew.set_meta("speed", 4)
	crew.set_meta("combat_skill", 1)
	crew.set_meta("toughness", 3)
	crew.set_meta("savvy", 1)
	crew.set_meta("luck", 0)
	crew.set_meta("equipped_items", equipped_items)
	crew.set_meta("experience", 0)
	return crew

func create_mock_crew(size: int = 3, with_equipment: bool = false) -> Array[Resource]:
	"""Create array of mock crew members"""
	var crew: Array[Resource] = []
	for i in range(size):
		var equipped: Array = []
		if with_equipment:
			equipped = ["weapon_%d" % i, "armor_%d" % i]
		crew.append(create_mock_crew_member("Crew %d" % i, equipped))
	return crew

func create_mock_enemy(enemy_name: String = "Test Enemy") -> Resource:
	"""Create mock enemy unit"""
	var enemy = Resource.new()
	enemy.set_meta("name", enemy_name)
	enemy.set_meta("type", "RAIDER")
	enemy.set_meta("reactions", 1)
	enemy.set_meta("speed", 4)
	enemy.set_meta("combat_skill", 0)
	enemy.set_meta("toughness", 3)
	enemy.set_meta("ai_type", "AGGRESSIVE")
	return enemy

func create_mock_enemies(count: int = 5) -> Array[Resource]:
	"""Create array of mock enemy units"""
	var enemies: Array[Resource] = []
	for i in range(count):
		enemies.append(create_mock_enemy("Enemy %d" % i))
	return enemies

## Battle state validation

func validate_battle_state_structure(state) -> Dictionary:
	"""Validate battle state has all required fields"""
	var result = {"valid": true, "missing_fields": [], "errors": []}

	var required_fields = [
		"mission_data",
		"crew_members",
		"enemy_forces",
		"current_phase",
		"crew_deployment",
		"enemy_deployment",
		"battlefield_setup"
	]

	for field in required_fields:
		if not state.has(field):
			result.valid = false
			result.missing_fields.append(field)
			result.errors.append("Missing required field: %s" % field)

	return result

func validate_crew_deployment(state) -> Dictionary:
	"""Validate crew deployment matches crew members"""
	var result = {"valid": true, "errors": []}

	if not state.has("crew_members") or not state.has("crew_deployment"):
		result.valid = false
		result.errors.append("Missing crew_members or crew_deployment")
		return result

	# Check if deployment has positions
	if not state.crew_deployment.has("positions"):
		result.valid = false
		result.errors.append("crew_deployment missing 'positions' array")
		return result

	# Validate position count matches crew size
	var crew_count = state.crew_members.size()
	var position_count = state.crew_deployment["positions"].size()

	if crew_count != position_count:
		result.valid = false
		result.errors.append("Position count (%d) does not match crew count (%d)" % [position_count, crew_count])

	return result

func validate_equipment_tracking(state) -> Dictionary:
	"""Validate equipment is tracked in battle state"""
	var result = {"valid": true, "equipment_tracked": false, "errors": []}

	# Check various possible equipment tracking locations
	if state.has("equipment_in_battle"):
		result.equipment_tracked = true
	elif state.has("crew_equipment"):
		result.equipment_tracked = true
	elif state.crew_deployment.has("equipment"):
		result.equipment_tracked = true
	else:
		result.valid = false
		result.errors.append("No equipment tracking found in battle state")

	return result

## Phase transition helpers

func get_valid_battle_phase_transitions() -> Dictionary:
	"""Returns map of valid battle phase transitions"""
	return {
		"NONE": ["PRE_BATTLE"],
		"PRE_BATTLE": ["TACTICAL_BATTLE", "BATTLE_RESOLUTION"],
		"TACTICAL_BATTLE": ["BATTLE_RESOLUTION"],
		"BATTLE_RESOLUTION": ["POST_BATTLE"],
		"POST_BATTLE": ["BATTLE_COMPLETE"],
		"BATTLE_COMPLETE": []
	}

func is_valid_battle_transition(from_phase_int: int, to_phase_int: int, BattlePhaseEnum) -> bool:
	"""Check if battle phase transition is valid"""
	var valid_transitions = get_valid_battle_phase_transitions()

	# Convert enum ints to strings for lookup
	var from_phase = BattlePhaseEnum.keys()[from_phase_int]
	var to_phase = BattlePhaseEnum.keys()[to_phase_int]

	if not valid_transitions.has(from_phase):
		return false

	return to_phase in valid_transitions[from_phase]

## Battle state snapshots

func create_battle_state_snapshot(battle_manager) -> Dictionary:
	"""Create snapshot of current battle state for comparison"""
	var snapshot = {
		"is_active": battle_manager.is_active,
		"current_phase": battle_manager.current_phase,
		"timestamp": Time.get_ticks_msec()
	}

	if battle_manager.battle_state:
		snapshot["has_state"] = true
		snapshot["crew_count"] = battle_manager.battle_state.crew_members.size()
		snapshot["enemy_count"] = battle_manager.battle_state.enemy_forces.size()
		snapshot["state_phase"] = battle_manager.battle_state.current_phase
		snapshot["battle_id"] = battle_manager.battle_state.battle_id
	else:
		snapshot["has_state"] = false

	return snapshot

func compare_battle_snapshots(before: Dictionary, after: Dictionary) -> Dictionary:
	"""Compare two battle state snapshots"""
	return {
		"phase_changed": after.current_phase != before.current_phase,
		"phase_from": before.current_phase,
		"phase_to": after.current_phase,
		"activation_changed": after.is_active != before.is_active,
		"state_created": after.has_state and not before.has_state,
		"time_elapsed_ms": after.timestamp - before.timestamp
	}

## Battle result validation

func validate_battle_result(result) -> Dictionary:
	"""Validate battle result has required fields"""
	var validation = {"valid": true, "errors": []}

	if not result:
		validation.valid = false
		validation.errors.append("Result is null")
		return validation

	# Check required fields
	var required = ["victory", "crew_casualties", "crew_injuries", "loot_found",
	                "credits_earned", "experience_gained"]

	for field in required:
		if not result.has(field):
			validation.valid = false
			validation.errors.append("Missing field: %s" % field)

	return validation

## Deployment helper functions

func create_mock_deployment(crew_size: int) -> Dictionary:
	"""Create mock deployment data for testing"""
	var positions = []
	for i in range(crew_size):
		positions.append(Vector2i(i, 0))  # Line deployment

	return {
		"positions": positions,
		"ready": true,
		"formation": "LINE"
	}

func create_scattered_deployment(crew_size: int) -> Dictionary:
	"""Create scattered deployment for testing"""
	var positions = []
	for i in range(crew_size):
		positions.append(Vector2i(randi() % 10, randi() % 10))

	return {
		"positions": positions,
		"ready": true,
		"formation": "SCATTERED"
	}
