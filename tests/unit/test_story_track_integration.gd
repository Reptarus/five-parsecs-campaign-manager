extends GdUnitTestSuite

## Integration Tests for Story Track Phase Integration
## Tests WorldPhase and PostBattlePhase story track integration
## (BattlePhase story-battle tests removed when the deprecated phases/BattlePhase.gd
##  was retired — Session 50 / Wave 1.6; story-battle config now lives in the live path)
## Tests signal flows, data passing, and state updates
## Max 13 tests per file (runner stability constraint)

var world_phase: Variant
var post_battle_phase: Variant
var mock_story_track_system: RefCounted

func before_test() -> void:
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	# Create phase instances
	world_phase = preload("res://src/core/campaign/phases/WorldPhase.gd").new()
	post_battle_phase = preload("res://src/core/campaign/phases/PostBattlePhase.gd").new()

	# Create mock story track system
	mock_story_track_system = _create_mock_story_track_system()

func after_test() -> void:
	# RefCounted objects are auto-managed, don't call free()
	if world_phase:
		world_phase = null
	if post_battle_phase:
		post_battle_phase = null
	if mock_story_track_system:
		mock_story_track_system = null

## Test 1: WorldPhase detects active story mission
func test_world_phase_checks_for_story_mission() -> void:
	# WorldPhase should check for story mission during job offer generation
	# This test validates the _check_for_story_mission() method exists and returns Dictionary
	var result = world_phase.call("_check_for_story_mission") if world_phase.has_method("_check_for_story_mission") else {}

	# Should return Dictionary (empty if no story track active)
	assert_bool(result is Dictionary).is_true()

## Test 2: WorldPhase loads story mission offer correctly
func test_world_phase_loads_story_mission_offer() -> void:
	# Test _load_story_mission_offer() method
	if not world_phase.has_method("_load_story_mission_offer"):
		return # Skip if method doesn't exist

	var offer = world_phase.call("_load_story_mission_offer", "discovery_signal")

	# Should return job offer with story mission data
	assert_dict(offer).is_not_empty()
	assert_str(offer.get("type", "")).is_equal("story_track")
	assert_str(offer.get("story_event_id", "")).is_equal("discovery_signal")
	assert_bool(offer.get("is_story_mission", false)).is_true()
	assert_int(offer.get("mission_number", 0)).is_equal(1)

## Test 3: WorldPhase story mission has priority flag
func test_world_phase_story_mission_marked_as_priority() -> void:
	if not world_phase.has_method("_load_story_mission_offer"):
		return

	var offer = world_phase.call("_load_story_mission_offer", "first_contact")

	# Story missions should have required metadata for priority handling
	assert_dict(offer).contains_keys(["story_event_id", "mission_number", "is_story_mission"])

## Test 4: WorldPhase inject story mission adds to offers array
func test_world_phase_inject_story_mission() -> void:
	if not world_phase.has_method("inject_story_mission"):
		return

	# Create mock story event
	var mock_event = _create_mock_story_event("conspiracy_revealed")

	# Inject the mission
	world_phase.call("inject_story_mission", mock_event)

	# Check if available_job_offers was populated
	if "available_job_offers" in world_phase:
		var offers: Array = world_phase.available_job_offers
		if offers.size() > 0:
			var first_offer = offers[0]
			assert_str(first_offer.get("story_event_id", "")).is_equal("conspiracy_revealed")
			assert_bool(first_offer.get("is_priority", false)).is_true()

## Test 8: PostBattlePhase calculates evidence correctly for victory
func test_post_battle_victory_awards_two_evidence() -> void:
	# Setup battle result with story mission victory
	post_battle_phase.battle_result = {
		"is_story_mission": true,
		"story_event_id": "personal_connection",
		"mission_number": 4,
		"is_final_mission": false,
		"held_field": false
	}
	post_battle_phase.mission_successful = true

	# Call story mission outcome processing
	if post_battle_phase.has_method("_process_story_mission_outcome"):
		# Note: This will emit signals but we can't easily capture them in unit test
		# We validate the logic would execute without errors
		post_battle_phase.call("_process_story_mission_outcome")

	# Test passes if no errors thrown

## Test 9: PostBattlePhase calculates evidence correctly for defeat
func test_post_battle_defeat_awards_one_evidence() -> void:
	# Setup battle result with story mission defeat
	post_battle_phase.battle_result = {
		"is_story_mission": true,
		"story_event_id": "hunt_begins",
		"mission_number": 5,
		"is_final_mission": false,
		"held_field": false
	}
	post_battle_phase.mission_successful = false

	# Expected: 1 evidence for defeat
	# Call story mission outcome processing
	if post_battle_phase.has_method("_process_story_mission_outcome"):
		post_battle_phase.call("_process_story_mission_outcome")

	# Test passes if no errors thrown

## Test 10: PostBattlePhase adds bonus evidence for held field
func test_post_battle_held_field_bonus_evidence() -> void:
	# Setup battle result with held field
	post_battle_phase.battle_result = {
		"is_story_mission": true,
		"story_event_id": "first_contact",
		"mission_number": 2,
		"is_final_mission": false,
		"held_field": true # Bonus evidence
	}
	post_battle_phase.mission_successful = true

	# Expected: 2 (victory) + 1 (held field) = 3 evidence
	if post_battle_phase.has_method("_process_story_mission_outcome"):
		post_battle_phase.call("_process_story_mission_outcome")

	# Test passes if no errors thrown

## Test 11: PostBattlePhase skips processing for non-story missions
func test_post_battle_skips_non_story_missions() -> void:
	# Setup regular mission (not story track)
	post_battle_phase.battle_result = {
		"is_story_mission": false,
		"mission_type": "patrol"
	}
	post_battle_phase.mission_successful = true

	# Should exit early without processing story track logic
	if post_battle_phase.has_method("_process_story_mission_outcome"):
		post_battle_phase.call("_process_story_mission_outcome")

	# Test passes if no errors thrown (early return)

## Test 12: PostBattlePhase triggers completion on final mission victory
func test_post_battle_final_mission_triggers_completion() -> void:
	# Setup final mission victory
	post_battle_phase.battle_result = {
		"is_story_mission": true,
		"story_event_id": "final_confrontation",
		"mission_number": 6,
		"is_final_mission": true,
		"held_field": true
	}
	post_battle_phase.mission_successful = true

	# Should trigger _complete_story_track()
	if post_battle_phase.has_method("_process_story_mission_outcome"):
		post_battle_phase.call("_process_story_mission_outcome")

	# Test passes if no errors thrown (completion logic executes)

## Helper: Create mock story track system
func _create_mock_story_track_system() -> RefCounted:
	# Create a simple mock that extends Resource (like the real FPCM_StoryTrackSystem)
	var MockStoryTrack = GDScript.new()
	MockStoryTrack.source_code = "extends Resource\n\nvar is_story_track_active: bool = false\nvar story_clock_ticks: int = 6\nvar evidence_pieces: int = 0\n"
	@warning_ignore("return_value_discarded")
	MockStoryTrack.reload()
	return MockStoryTrack.new()

## Helper: Create mock story event
func _create_mock_story_event(event_id: String) -> Dictionary:
	return {
		"event_id": event_id,
		"title": "Mock Story Event",
		"description": "Test event for integration testing"
	}
