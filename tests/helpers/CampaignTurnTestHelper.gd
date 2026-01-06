class_name CampaignTurnTestHelper
## Phase 2 Helper: Campaign Turn and Phase Transition Testing
## Provides orchestration, validation, and state management for integration tests
## Plain class (no Node inheritance) for gdUnit4 v6.0.1 compatibility
## UPDATED: Uses correct stat names matching Character.gd

## Mock campaign data generator
func create_minimal_campaign() -> Dictionary:
	"""Create minimal valid campaign data for testing"""
	return {
		"config": {
			"campaign_name": "Test Campaign",
			"difficulty": "NORMAL",
			"victory_condition": "SURVIVE_10_TURNS",
			"is_complete": true
		},
		"captain": {
			"name": "Test Captain",
			"character_name": "Test Captain",  # Compatibility alias
			"origin": "HUMAN",          # CORRECT: NOT species
			"background": "MILITARY",
			"motivation": "SURVIVAL",
			"character_class": "BASELINE",
			"experience": 0,
			"reactions": 1,
			"speed": 4,
			"combat": 1,               # CORRECT: NOT combat_skill
			"toughness": 3,
			"savvy": 1,
			"tech": 1,                 # ADDED: missing stat
			"move": 4,                 # ADDED: missing stat
			"luck": 0,
			"is_captain": true,
			"status": "ACTIVE",
			"is_complete": true
		},
		"crew": {
			"members": [
				{
					"name": "Crew Member 1",
					"character_name": "Crew Member 1",
					"origin": "HUMAN",         # CORRECT: NOT species
					"background": "COLONIST",
					"motivation": "SURVIVAL",
					"character_class": "BASELINE",
					"experience": 0,
					"reactions": 1,
					"speed": 4,
					"combat": 1,              # CORRECT: NOT combat_skill
					"toughness": 3,
					"savvy": 1,
					"tech": 1,                # ADDED: missing stat
					"move": 4,                # ADDED: missing stat
					"luck": 0,
					"is_captain": false,
					"status": "ACTIVE"
				}
			],
			"is_complete": true
		},
		"ship": {
			"name": "Test Ship",
			"hull_points": 10,
			"fuel": 6,
			"debt": 0,
			"is_complete": true
		},
		"equipment": {
			"starting_credits": 50,
			"equipment": [
				{"id": "gun_1", "type": "SCRAP_PISTOL", "equipped_by": ""}
			],
			"is_complete": true
		},
		"world": {
			"current_world": "Test World",
			"world_type": "COLONY",
			"is_complete": true
		},
		"metadata": {
			"created_at": "2025-11-16T00:00:00",
			"version": "0.1.0"
		}
	}

func create_full_campaign() -> Dictionary:
	"""Create campaign with more crew, equipment, and resources for complex testing"""
	var campaign = create_minimal_campaign()

	# Add more crew - using CORRECT stat names matching Character.gd
	campaign["crew"]["members"].append({
		"name": "Crew Member 2",
		"character_name": "Crew Member 2",
		"origin": "ALIEN_SWIFT",       # CORRECT: NOT species
		"background": "EXPLORER",
		"motivation": "ADVENTURE",
		"character_class": "BASELINE",
		"experience": 5,
		"reactions": 2,
		"speed": 5,
		"combat": 1,                   # CORRECT: NOT combat_skill
		"toughness": 2,
		"savvy": 1,
		"tech": 1,
		"move": 5,
		"luck": 0,
		"is_captain": false,
		"status": "ACTIVE"
	})
	campaign["crew"]["members"].append({
		"name": "Crew Member 3",
		"character_name": "Crew Member 3",
		"origin": "ALIEN_FERAL",       # CORRECT: NOT species
		"background": "MILITARY",
		"motivation": "SURVIVAL",
		"character_class": "BASELINE",
		"experience": 3,
		"reactions": 1,
		"speed": 4,
		"combat": 2,                   # CORRECT: NOT combat_skill
		"toughness": 4,
		"savvy": 1,
		"tech": 1,
		"move": 4,
		"luck": 0,
		"is_captain": false,
		"status": "ACTIVE"
	})

	# Add more equipment
	campaign["equipment"]["starting_credits"] = 150
	campaign["equipment"]["equipment"].append({"id": "gun_2", "type": "COLONY_RIFLE", "equipped_by": ""})
	campaign["equipment"]["equipment"].append({"id": "gun_3", "type": "HANDGUN", "equipped_by": ""})
	campaign["equipment"]["equipment"].append({"id": "armor_1", "type": "FLAK_SCREEN", "equipped_by": ""})

	# Add ship fuel
	campaign["ship"]["fuel"] = 6

	return campaign

## Phase state validation
func validate_phase_state(current_phase: String, expected_phase: String) -> bool:
	"""Validate current phase matches expected phase"""
	return current_phase == expected_phase

func get_valid_phase_transitions() -> Dictionary:
	"""Returns map of valid phase transitions"""
	return {
		"NONE": ["TRAVEL"],
		"TRAVEL": ["WORLD"],
		"WORLD": ["BATTLE", "TRAVEL"],  # Can skip battle or proceed to next turn
		"BATTLE": ["POST_BATTLE"],
		"POST_BATTLE": ["TRAVEL"]
	}

func get_invalid_phase_transitions() -> Array:
	"""Returns array of invalid phase transition pairs [from, to]"""
	return [
		["TRAVEL", "BATTLE"],  # Must go through WORLD
		["TRAVEL", "POST_BATTLE"],  # Must go through WORLD and BATTLE
		["WORLD", "POST_BATTLE"],  # Must go through BATTLE
		["BATTLE", "TRAVEL"],  # Must go through POST_BATTLE
		["BATTLE", "WORLD"],  # Cannot go backwards
		["POST_BATTLE", "WORLD"],  # Cannot go backwards
		["POST_BATTLE", "BATTLE"],  # Cannot go backwards
	]

func is_valid_transition(from_phase: String, to_phase: String) -> bool:
	"""Check if phase transition is valid"""
	var valid_transitions = get_valid_phase_transitions()
	if not valid_transitions.has(from_phase):
		return false
	return to_phase in valid_transitions[from_phase]

## State snapshot and comparison
func create_state_snapshot(game_state) -> Dictionary:
	"""Create snapshot of current game state for comparison"""
	return {
		"turn_number": game_state.get("turn_number", 0),
		"current_phase": game_state.get("current_phase", "NONE"),
		"credits": game_state["resources"]["credits"] if game_state.has("resources") else 0,
		"crew_count": game_state["crew"].size() if game_state.has("crew") else 0,
		"equipment_count": game_state["equipment"].size() if game_state.has("equipment") else 0,
		"injured_count": game_state["injured_characters"].size() if game_state.has("injured_characters") else 0,
		"timestamp": Time.get_ticks_msec()
	}

func compare_snapshots(before: Dictionary, after: Dictionary) -> Dictionary:
	"""Compare two state snapshots and return differences"""
	return {
		"turn_changed": after.turn_number != before.turn_number,
		"turn_delta": after.turn_number - before.turn_number,
		"phase_changed": after.current_phase != before.current_phase,
		"phase_from": before.current_phase,
		"phase_to": after.current_phase,
		"credits_delta": after.credits - before.credits,
		"crew_delta": after.crew_count - before.crew_count,
		"equipment_delta": after.equipment_count - before.equipment_count,
		"injured_delta": after.injured_count - before.injured_count,
		"time_elapsed_ms": after.timestamp - before.timestamp
	}

## Turn advancement helpers
func create_turn_state() -> Dictionary:
	"""Create minimal turn state for testing"""
	return {
		"discovered_patrons": [],
		"active_rivals": [],
		"rumors_accumulated": 0,
		"tracked_rival": {},
		"decoy_planted": false,
		"equipment_stash_count": 0,
		"injured_characters": []
	}

func validate_turn_state_structure(turn_state: Dictionary) -> Dictionary:
	"""Validate turn state has all required fields"""
	var result = {"valid": true, "missing_fields": []}

	var required_fields = [
		"discovered_patrons",
		"active_rivals",
		"rumors_accumulated",
		"tracked_rival",
		"decoy_planted",
		"equipment_stash_count",
		"injured_characters"
	]

	for field in required_fields:
		if not turn_state.has(field):
			result.valid = false
			result.missing_fields.append(field)

	return result

## Resource tracking
func track_resource_changes(before_credits: int, after_credits: int,
							operation: String) -> Dictionary:
	"""Track and validate resource changes"""
	return {
		"operation": operation,
		"before": before_credits,
		"after": after_credits,
		"delta": after_credits - before_credits,
		"valid": after_credits >= 0,  # Credits should never go negative
		"error": "Negative credits detected" if after_credits < 0 else ""
	}

## Multi-turn orchestration
func simulate_turn_advancement(initial_turn: int, turns_to_advance: int) -> Dictionary:
	"""Simulate turn advancement and return expected final turn"""
	return {
		"initial_turn": initial_turn,
		"turns_advanced": turns_to_advance,
		"expected_final_turn": initial_turn + turns_to_advance,
		"phase_cycles_expected": turns_to_advance  # Each turn = 1 full phase cycle
	}

func validate_multi_turn_consistency(snapshots: Array) -> Dictionary:
	"""Validate consistency across multiple turn snapshots"""
	if snapshots.size() < 2:
		return {"valid": false, "error": "Need at least 2 snapshots"}

	var result = {
		"valid": true,
		"errors": [],
		"turn_progression_valid": true,
		"total_snapshots": snapshots.size()
	}

	# Check turn numbers increment
	for i in range(1, snapshots.size()):
		var prev_turn = snapshots[i-1].turn_number
		var curr_turn = snapshots[i].turn_number

		if curr_turn <= prev_turn:
			result.valid = false
			result.turn_progression_valid = false
			result.errors.append("Turn %d -> %d: Turn number did not increase" % [prev_turn, curr_turn])

	return result

## Phase-specific validation
func validate_travel_phase_requirements(campaign: Dictionary) -> Dictionary:
	"""Validate campaign can execute travel phase"""
	var result = {"valid": true, "errors": []}

	# Need credits for travel (5 for starship, or 1 per crew for commercial)
	var min_credits_needed = 5  # Starship travel
	if campaign["equipment"]["starting_credits"] < min_credits_needed:
		result.valid = false
		result.errors.append("Insufficient credits for travel (need %d, have %d)" %
			[min_credits_needed, campaign["equipment"]["starting_credits"]])

	# Need ship
	if not campaign.has("ship") or campaign["ship"].is_empty():
		result.valid = false
		result.errors.append("No ship available")

	return result

func validate_battle_phase_requirements(campaign: Dictionary) -> Dictionary:
	"""Validate campaign can execute battle phase"""
	var result = {"valid": true, "errors": []}

	# Need at least one crew member
	if not campaign.has("crew") or campaign["crew"]["members"].is_empty():
		result.valid = false
		result.errors.append("No crew available for battle")

	# Need at least one weapon
	if not campaign.has("equipment") or campaign["equipment"]["equipment"].is_empty():
		result.valid = false
		result.errors.append("No equipment available for battle")

	return result

## Mock phase data
func create_mock_travel_phase_data() -> Dictionary:
	"""Create mock data for travel phase testing"""
	return {
		"substep": "START",
		"travel_cost": 5,
		"invasion_roll": 50,  # Mid-range, no invasion
		"travel_event_roll": 30,  # Some event
		"destination": "Target World"
	}

func create_mock_world_phase_data() -> Dictionary:
	"""Create mock data for world phase testing"""
	return {
		"available_jobs": 3,
		"selected_job": null,
		"trades_made": 0,
		"crew_tasks_completed": []
	}

func create_mock_battle_phase_data() -> Dictionary:
	"""Create mock battle data for testing"""
	return {
		"mission_type": "OPPORTUNITY",
		"enemy_count": 5,
		"enemy_type": "RAIDERS",
		"deployment_valid": true,
		"crew_deployed": 2
	}

func create_mock_post_battle_data() -> Dictionary:
	"""Create mock post-battle results"""
	return {
		"victory": true,
		"casualties": 0,
		"injuries": [
			{"name": "Crew Member 1", "type": "LIGHT_INJURY", "turns_remaining": 1}
		],
		"experience_gained": 1,
		"loot_items": 2,
		"credits_earned": 10
	}
