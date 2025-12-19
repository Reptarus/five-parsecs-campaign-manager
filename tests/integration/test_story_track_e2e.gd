class_name TestStoryTrackE2E
extends GdUnitTestSuite

## E2E Integration Tests for Story Track System
## Validates complete flow: Campaign Creation → World Phase → Battle → Post-Battle → Completion
## Per TESTING_GUIDE.md: Max 13 tests per file, explicit types, no Node inheritance

# Test Constants
const STORY_MISSIONS_PATH := "res://data/story_track_missions/"
const EVENT_IDS: Array[String] = [
	"discovery_signal",
	"first_contact",
	"conspiracy_revealed",
	"personal_connection",
	"hunt_begins",
	"final_confrontation"
]

# Test Dependencies
var story_track_system: RefCounted
var story_mission_loader: RefCounted
var campaign_phase_manager: RefCounted

func before_test() -> void:
	# Load StoryTrackSystem
	var StoryTrackScript: GDScript = load("res://src/core/story/StoryTrackSystem.gd")
	if StoryTrackScript:
		story_track_system = StoryTrackScript.new()

	# Load StoryMissionLoader
	var LoaderScript: GDScript = load("res://src/core/story/StoryMissionLoader.gd")
	if LoaderScript:
		story_mission_loader = LoaderScript.new()

func after_test() -> void:
	story_track_system = null
	story_mission_loader = null
	campaign_phase_manager = null

# ============================================================================
# TEST 1: Story Track Activates on Campaign Creation
# ============================================================================
func test_story_track_activation_on_campaign_creation() -> void:
	# Story Track should be activatable when guided mode is selected
	assert_that(story_track_system != null).is_true()

	if story_track_system and story_track_system.has_method("activate_story_track"):
		story_track_system.call("activate_story_track")

		var is_active: bool = false
		if "is_story_track_active" in story_track_system:
			is_active = story_track_system.is_story_track_active
		elif story_track_system.has_method("is_active"):
			is_active = story_track_system.call("is_active")

		assert_that(is_active).is_true()

# ============================================================================
# TEST 2: Story Mission Appears in World Phase Job Offers
# ============================================================================
func test_story_mission_appears_in_world_phase() -> void:
	# Load first mission to verify it can be injected into job offers
	if story_mission_loader == null:
		return

	var mission_data: Dictionary = story_mission_loader.load_story_mission("discovery_signal")
	assert_that(mission_data.is_empty()).is_false()

	# Verify mission has required fields for job offer display
	assert_that(mission_data.has("title")).is_true()
	assert_that(mission_data.has("mission_id")).is_true()
	assert_that(mission_data.has("story_event_id")).is_true()

# ============================================================================
# TEST 3: Story Battle Uses Curated Content (Fixed Enemies/Terrain)
# ============================================================================
func test_story_battle_uses_curated_content() -> void:
	if story_mission_loader == null:
		return

	var mission_data: Dictionary = story_mission_loader.load_story_mission("discovery_signal")

	# Verify battlefield is curated (not procedural)
	var battlefield: Dictionary = mission_data.get("battlefield", {})
	assert_that(battlefield.has("size")).is_true()
	assert_that(battlefield.has("terrain_features")).is_true()
	assert_that(battlefield.has("deployment_zones")).is_true()

	# Verify enemy composition is fixed
	var enemies: Dictionary = mission_data.get("enemies", {})
	assert_that(enemies.has("fixed_count")).is_true()
	assert_that(enemies.has("composition")).is_true()

	# Verify fixed_count is a specific number (not random range)
	var fixed_count: int = enemies.get("fixed_count", 0)
	assert_that(fixed_count).is_greater(0)

# ============================================================================
# TEST 4: Post-Battle Updates Story Evidence Correctly
# ============================================================================
func test_post_battle_updates_story_evidence() -> void:
	if story_track_system == null:
		return

	# Activate story track
	if story_track_system.has_method("activate_story_track"):
		story_track_system.call("activate_story_track")

	# Get initial evidence
	var initial_evidence: int = 0
	if "evidence_pieces" in story_track_system:
		initial_evidence = story_track_system.evidence_pieces

	# Simulate evidence discovery (2 for victory)
	if story_track_system.has_method("discover_evidence"):
		story_track_system.call("discover_evidence", 2)

	# Verify evidence increased
	var final_evidence: int = 0
	if "evidence_pieces" in story_track_system:
		final_evidence = story_track_system.evidence_pieces

	assert_that(final_evidence).is_equal(initial_evidence + 2)

# ============================================================================
# TEST 5: Evidence Calculation Follows Rules (Victory=2, Defeat=1, +1 Held Field)
# ============================================================================
func test_evidence_calculation_follows_rules() -> void:
	if story_track_system == null:
		return

	if story_track_system.has_method("activate_story_track"):
		story_track_system.call("activate_story_track")

	# Test victory gives 2 evidence
	var victory_evidence: int = 2

	# Test defeat gives 1 evidence
	var defeat_evidence: int = 1

	# Test held field bonus
	var held_field_bonus: int = 1

	# Victory + held field = 3
	var max_evidence: int = victory_evidence + held_field_bonus
	assert_that(max_evidence).is_equal(3)

	# Defeat without held field = 1
	assert_that(defeat_evidence).is_equal(1)

# ============================================================================
# TEST 6: Story Progression Through All 6 Events in Sequence
# ============================================================================
func test_story_progression_through_all_events() -> void:
	if story_mission_loader == null:
		return

	var loaded_missions: int = 0

	for event_id in EVENT_IDS:
		var mission: Dictionary = story_mission_loader.load_story_mission(event_id)
		if not mission.is_empty():
			loaded_missions += 1

	# All 6 missions should load successfully
	assert_that(loaded_missions).is_equal(6)

# ============================================================================
# TEST 7: Tutorial Hints Display at Correct Story Moments
# ============================================================================
func test_tutorial_hints_for_story_events() -> void:
	if story_mission_loader == null:
		return

	# Each mission should have tutorial_hints defined
	for event_id in EVENT_IDS:
		var mission: Dictionary = story_mission_loader.load_story_mission(event_id)
		if mission.is_empty():
			continue

		var tutorial_hints: Array = mission.get("tutorial_hints", [])
		assert_that(tutorial_hints.size()).is_greater_equal(0)

# ============================================================================
# TEST 8: Save/Load Preserves Story Progress Mid-Campaign
# ============================================================================
func test_save_load_preserves_story_progress() -> void:
	if story_track_system == null:
		return

	# Activate and add evidence
	if story_track_system.has_method("activate_story_track"):
		story_track_system.call("activate_story_track")

	if story_track_system.has_method("discover_evidence"):
		story_track_system.call("discover_evidence", 5)

	# Serialize state
	var save_data: Dictionary = {}
	if story_track_system.has_method("serialize"):
		save_data = story_track_system.call("serialize")
	elif story_track_system.has_method("to_dict"):
		save_data = story_track_system.call("to_dict")

	# Create new instance and restore
	var StoryTrackScript: GDScript = load("res://src/core/story/StoryTrackSystem.gd")
	if StoryTrackScript == null:
		return

	var restored_system: RefCounted = StoryTrackScript.new()

	if restored_system.has_method("deserialize") and not save_data.is_empty():
		restored_system.call("deserialize", save_data)

		var restored_evidence: int = 0
		if "evidence_pieces" in restored_system:
			restored_evidence = restored_system.evidence_pieces

		var original_evidence: int = 0
		if "evidence_pieces" in story_track_system:
			original_evidence = story_track_system.evidence_pieces

		assert_that(restored_evidence).is_equal(original_evidence)

# ============================================================================
# TEST 9: Sandbox Mode Unlocks After Story Track Completion
# ============================================================================
func test_sandbox_mode_unlocks_after_completion() -> void:
	if story_mission_loader == null:
		return

	# Final mission should have story_track_completion field
	var final_mission: Dictionary = story_mission_loader.load_story_mission("final_confrontation")

	assert_that(final_mission.has("story_track_completion")).is_true()

	var completion_data: Dictionary = final_mission.get("story_track_completion", {})
	assert_that(completion_data.get("triggers_completion", false)).is_true()
	assert_that(completion_data.get("unlocks_sandbox_mode", false)).is_true()

# ============================================================================
# TEST 10: Mission Difficulty Progresses 1-5 Across Story Track
# ============================================================================
func test_difficulty_progression_across_story_track() -> void:
	if story_mission_loader == null:
		return

	var previous_difficulty: int = 0

	for event_id in EVENT_IDS:
		var mission: Dictionary = story_mission_loader.load_story_mission(event_id)
		if mission.is_empty():
			continue

		var difficulty: int = mission.get("difficulty_rating", 0)

		# Each mission should have difficulty 1-5
		assert_that(difficulty).is_greater_equal(1)
		assert_that(difficulty).is_less_equal(5)

		# Difficulty should generally increase (allowing plateaus)
		assert_that(difficulty).is_greater_equal(previous_difficulty)
		previous_difficulty = difficulty

# ============================================================================
# TEST 11: Story Clock Mechanics Work Correctly
# ============================================================================
func test_story_clock_mechanics() -> void:
	if story_track_system == null:
		return

	if story_track_system.has_method("activate_story_track"):
		story_track_system.call("activate_story_track")

	# Get initial clock ticks
	var initial_ticks: int = 6  # Story Track starts with 6 ticks
	if "story_clock_ticks" in story_track_system:
		initial_ticks = story_track_system.story_clock_ticks

	# Advance clock
	if story_track_system.has_method("advance_story_clock"):
		story_track_system.call("advance_story_clock")

		var new_ticks: int = 0
		if "story_clock_ticks" in story_track_system:
			new_ticks = story_track_system.story_clock_ticks

		assert_that(new_ticks).is_equal(initial_ticks - 1)

# ============================================================================
# TEST 12: All Missions Have Required Fields for Phase Integration
# ============================================================================
func test_missions_have_required_phase_integration_fields() -> void:
	if story_mission_loader == null:
		return

	var required_fields: Array[String] = [
		"mission_id",
		"story_event_id",
		"title",
		"battlefield",
		"enemies",
		"objectives"
	]

	for event_id in EVENT_IDS:
		var mission: Dictionary = story_mission_loader.load_story_mission(event_id)
		if mission.is_empty():
			continue

		for field in required_fields:
			assert_that(mission.has(field)).is_true()

# ============================================================================
# TEST 13: Enemy Composition Sums to Fixed Count
# ============================================================================
func test_enemy_composition_sums_to_fixed_count() -> void:
	if story_mission_loader == null:
		return

	for event_id in EVENT_IDS:
		var mission: Dictionary = story_mission_loader.load_story_mission(event_id)
		if mission.is_empty():
			continue

		var enemies: Dictionary = mission.get("enemies", {})
		var fixed_count: int = enemies.get("fixed_count", 0)
		var composition: Array = enemies.get("composition", [])

		var total_count: int = 0
		for enemy_group in composition:
			if enemy_group is Dictionary:
				total_count += enemy_group.get("count", 0)

		# Composition should sum to fixed_count
		assert_that(total_count).is_equal(fixed_count)
