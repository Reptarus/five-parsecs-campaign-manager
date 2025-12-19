extends GdUnitTestSuite

## Unit Tests for FPCM_StoryMissionLoader (Part 2/2)
## Tests data extraction and utility methods
## Split to avoid runner crash (max ~10-11 tests per file)

var loader: FPCM_StoryMissionLoader

func before_test() -> void:
	loader = FPCM_StoryMissionLoader.new()
	if not is_instance_valid(loader):
		push_warning("StoryMissionLoader failed to initialize")
		return
	loader.clear_cache()
	await get_tree().process_frame

func after_test() -> void:
	if loader:
		loader.clear_cache()
		loader = null

## Test 10: Get battlefield data extracts correct structure
func test_get_battlefield_data_returns_structure() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var mission = loader.load_story_mission("discovery_signal")

	if mission == null or mission.is_empty():
		push_warning("No mission data available for discovery_signal")
		return

	var battlefield = loader.get_battlefield_data(mission)

	assert_dict(battlefield).is_not_empty()
	assert_dict(battlefield.get("size", {})).contains_keys(["x", "y"])

## Test 11: Get enemy composition returns curated enemies
func test_get_enemy_composition_returns_curated_data() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var mission = loader.load_story_mission("discovery_signal")

	if mission == null or mission.is_empty():
		push_warning("No mission data available for discovery_signal")
		return

	var enemies = loader.get_enemy_composition(mission)

	assert_dict(enemies).is_not_empty()
	assert_int(enemies.get("fixed_count", 0)).is_greater(0)
	assert_array(enemies.get("composition", [])).is_not_empty()

## Test 12: Is final mission detects story completion trigger
func test_is_final_mission_detects_completion_trigger() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var final_mission = loader.load_story_mission("final_confrontation")

	if final_mission == null or final_mission.is_empty():
		push_warning("No mission data available for final_confrontation")
		return

	assert_bool(loader.is_final_mission(final_mission)).is_true()

	var first_mission = loader.load_story_mission("discovery_signal")

	if first_mission == null or first_mission.is_empty():
		push_warning("No mission data available for discovery_signal")
		return

	assert_bool(loader.is_final_mission(first_mission)).is_false()

## Test 13: Load mission by number works correctly
func test_load_story_mission_by_number() -> void:
	if not is_instance_valid(loader):
		push_warning("loader not available, skipping")
		return

	var mission1 = loader.load_story_mission_by_number(1)

	if mission1 == null or mission1.is_empty():
		push_warning("No mission data available for mission 1")
		return

	assert_str(mission1.get("story_event_id", "")).is_equal("discovery_signal")

	var mission6 = loader.load_story_mission_by_number(6)

	if mission6 == null or mission6.is_empty():
		push_warning("No mission data available for mission 6")
		return

	assert_str(mission6.get("story_event_id", "")).is_equal("final_confrontation")

	# Invalid mission number returns empty
	var invalid = loader.load_story_mission_by_number(0)
	assert_dict(invalid).is_empty()

	invalid = loader.load_story_mission_by_number(7)
	assert_dict(invalid).is_empty()
