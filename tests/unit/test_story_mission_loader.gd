extends GdUnitTestSuite
## Story Track event loader tests (rewritten 2026-07-02).
##
## The loader's real API is EVENT-based — 7 Story Track events from
## data/story_track_missions/ (Core Rules Appendix V): load_event /
## load_event_by_number / load_all_events / get_next_event / has_event /
## get_total_event_count / is_final_event / clear_cache. The old suite
## called a never-current 6-mission API (load_story_mission,
## get_next_story_mission, has_mission, get_total_mission_count) that does
## not exist on FPCM_StoryMissionLoader.

var loader: FPCM_StoryMissionLoader


func before_test() -> void:
	loader = FPCM_StoryMissionLoader.new()
	loader.clear_cache()


func after_test() -> void:
	if loader:
		loader.clear_cache()
		loader = null


func test_total_event_count_is_seven() -> void:
	# Story Track has 7 events (Core Rules Appendix V)
	assert_int(loader.get_total_event_count()).is_equal(7)


func test_load_all_events_returns_seven() -> void:
	var events: Array = loader.load_all_events()
	assert_int(events.size()).is_equal(7)
	for ev in events:
		assert_object(ev).is_not_null()
		assert_str(ev.event_id).is_not_empty()


func test_load_event_by_number_returns_event() -> void:
	var ev = loader.load_event_by_number(1)
	assert_object(ev).is_not_null()
	assert_int(ev.event_number).is_equal(1)


func test_load_event_caches_result() -> void:
	var first = loader.load_event_by_number(1)
	var again = loader.load_event(first.event_id)
	assert_object(again).is_same(first)


func test_has_event_true_for_all_loaded() -> void:
	for ev in loader.load_all_events():
		assert_bool(loader.has_event(ev.event_id)).is_true()


func test_has_event_false_for_unknown() -> void:
	assert_bool(loader.has_event("not_a_real_event")).is_false()


func test_load_event_unknown_id_returns_null() -> void:
	assert_object(loader.load_event("not_a_real_event")).is_null()


func test_get_next_event_progression() -> void:
	var first = loader.load_event_by_number(1)
	var next_event = loader.get_next_event(first.event_id)
	assert_object(next_event).is_not_null()
	assert_int(next_event.event_number).is_equal(2)


func test_final_event_is_final_and_has_no_next() -> void:
	var last = loader.load_event_by_number(7)
	assert_object(last).is_not_null()
	assert_bool(loader.is_final_event(last.event_id)).is_true()
	assert_object(loader.get_next_event(last.event_id)).is_null()


func test_clear_cache_reloads_fresh_instance() -> void:
	var first = loader.load_event_by_number(1)
	loader.clear_cache()
	var reloaded = loader.load_event(first.event_id)
	assert_object(reloaded).is_not_null()
	assert_bool(reloaded == first).is_false()
