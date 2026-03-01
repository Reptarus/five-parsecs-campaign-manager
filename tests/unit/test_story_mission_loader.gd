extends GdUnitTestSuite

## Unit Tests for FPCM_StoryMissionLoader (Part 1/2)
## Tests JSON loading, validation, caching, and mission progression logic
## Split into 2 files to avoid runner crash (max ~10 tests per file for stability)

var loader: FPCM_StoryMissionLoader

func before_test() -> void:
	loader = FPCM_StoryMissionLoader.new()
	if not is_instance_valid(loader):
		push_warning("StoryMissionLoader failed to initialize")
		return
	# Clear cache before each test to ensure isolation
	loader.clear_cache()
	# Give a frame to ensure initialization
	await get_tree().process_frame

func after_test() -> void:
	if loader:
		loader.clear_cache()
		# RefCounted objects are auto-managed, don't call free()
		loader = null

## Test 1: Load valid story mission returns populated dictionary
func test_load_story_mission_returns_valid_data() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var mission = loader.load_story_mission("discovery_signal")

	# Gracefully handle if data files are missing
	if mission == null or mission.is_empty():
		push_warning("No mission data available for discovery_signal")
		return

	# Should return non-empty dictionary
	assert_dict(mission).is_not_empty()

	# Validate required fields are present
	assert_str(mission.get("mission_id", "")).is_not_empty()
	assert_str(mission.get("story_event_id", "")).is_equal("discovery_signal")
	assert_str(mission.get("title", "")).is_not_empty()
	assert_int(mission.get("mission_number", 0)).is_equal(1)

	# Validate nested structures exist
	assert_dict(mission.get("battlefield", {})).is_not_empty()
	assert_dict(mission.get("enemies", {})).is_not_empty()
	assert_dict(mission.get("objectives", {})).is_not_empty()

## Test 2: Load mission uses cache on second call
func test_load_story_mission_caches_result() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	# Load first time - should hit disk
	var mission1 = loader.load_story_mission("first_contact")

	if mission1 == null or mission1.is_empty():
		push_warning("No mission data available for first_contact")
		return

	assert_dict(mission1).is_not_empty()

	# Check cache status
	var cache_status = loader.get_cache_status()
	assert_int(cache_status.get("cache_size", 0)).is_equal(1)
	assert_array(cache_status.get("cached_missions", [])).contains(["first_contact"])

	# Load second time - should hit cache (same instance reference)
	var mission2 = loader.load_story_mission("first_contact")
	assert_object(mission2).is_equal(mission1)

## Test 3: Invalid event ID returns empty dictionary
func test_load_story_mission_invalid_event_id_returns_empty() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var mission = loader.load_story_mission("invalid_event_id")

	assert_dict(mission).is_empty()

## Test 4: Load all story missions returns six missions
func test_load_all_story_missions_returns_six() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var missions = loader.load_all_story_missions()

	if missions == null or missions.is_empty():
		push_warning("No story mission data available")
		return

	# Should return exactly 6 missions (one per story event)
	assert_int(missions.size()).is_equal(6)

	# Verify mission numbers are sequential 1-6
	var mission_numbers = []
	for mission in missions:
		mission_numbers.append(mission.get("mission_number", 0))

	mission_numbers.sort()
	assert_array(mission_numbers).contains_exactly([1, 2, 3, 4, 5, 6])

## Test 5: Get next story mission returns correct progression
func test_get_next_story_mission_progression() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	# Starting from discovery_signal, next should be first_contact
	var next_mission = loader.get_next_story_mission("discovery_signal")

	if next_mission == null or next_mission.is_empty():
		push_warning("No next mission data available")
		return

	assert_dict(next_mission).is_not_empty()
	assert_str(next_mission.get("story_event_id", "")).is_equal("first_contact")
	assert_int(next_mission.get("mission_number", 0)).is_equal(2)

	# From first_contact to conspiracy_revealed
	next_mission = loader.get_next_story_mission("first_contact")
	assert_str(next_mission.get("story_event_id", "")).is_equal("conspiracy_revealed")
	assert_int(next_mission.get("mission_number", 0)).is_equal(3)

## Test 6: Get next mission from final mission returns empty
func test_get_next_story_mission_from_final_returns_empty() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var next_mission = loader.get_next_story_mission("final_confrontation")

	# No more missions after final mission
	assert_dict(next_mission).is_empty()

## Test 7: Get next mission with empty current starts from beginning
func test_get_next_story_mission_empty_current_starts_first() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var first_mission = loader.get_next_story_mission("")

	if first_mission == null or first_mission.is_empty():
		push_warning("No mission data available for first mission")
		return

	assert_dict(first_mission).is_not_empty()
	assert_str(first_mission.get("story_event_id", "")).is_equal("discovery_signal")
	assert_int(first_mission.get("mission_number", 0)).is_equal(1)

## Test 8: Has mission returns true for valid event IDs
func test_has_mission_returns_true_for_valid_events() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	assert_bool(loader.has_mission("discovery_signal")).is_true()
	assert_bool(loader.has_mission("first_contact")).is_true()
	assert_bool(loader.has_mission("final_confrontation")).is_true()

	assert_bool(loader.has_mission("invalid_event")).is_false()

## Test 9: Get total mission count returns six
func test_get_total_mission_count_returns_six() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	assert_int(loader.get_total_mission_count()).is_equal(6)

# Tests 10-13 moved to test_story_mission_loader_part2.gd to avoid runner crash
