extends GdUnitTestSuite
## War tracks persist STATE only; the config comes from the data file.
##
## THE PROBLEM THIS FIXES
## get_save_data() duplicated the whole track — name, description, faction,
## thresholds and all their narrative text — into every save. Measured on the largest
## real save: 7.0 KB of a 41.4 KB file, 17%, all of it static config already present
## in data/war_progress_tracks.json. save_campaign() runs ~8x per campaign turn, so
## that config was re-serialised and rewritten eight times a turn on a phone.
##
## It was also a correctness problem, not just size: a corrected threshold or
## reworded effect shipped in a patch could never reach an existing campaign, because
## the stale copy in the save overwrote the data file on every load.
##
## THE RISK THIS PINS
## Loading now MERGES state onto config instead of replacing the tracks wholesale.
## That has to read BOTH shapes — every existing save carries the full blob, new ones
## carry state only — and a wholesale replace would destroy the config when reading a
## slim save. These cases cover both directions plus the removed-track edge.
##
## gdUnit4 v6.0.3 compatible.

const STATE_FIELDS := ["current_progress", "highest_threshold_reached", "active"]


func _war() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GalacticWarManager")


func after_test() -> void:
	var w := _war()
	if w and w.has_method("reset_all_tracks"):
		w.reset_all_tracks()


func test_saved_tracks_carry_state_and_not_config() -> void:
	var w := _war()
	if w == null:
		return
	w.reset_all_tracks()
	var data: Dictionary = w.get_save_data()
	var tracks = data.get("war_tracks", {})
	assert_bool(tracks is Dictionary and not (tracks as Dictionary).is_empty()) \
		.override_failure_message("no war tracks were saved at all").is_true()

	for tid in tracks:
		var t: Dictionary = tracks[tid]
		for k in t.keys():
			assert_array(STATE_FIELDS).override_failure_message(
				"track '%s' still persists config field '%s' — the static blob is back"
				% [tid, k]
			).contains([k])


func test_progress_round_trips() -> void:
	var w := _war()
	if w == null or not w.has_method("get_save_data"):
		return
	w.reset_all_tracks()
	var tid = w.war_tracks.keys()[0]
	w.war_tracks[tid]["current_progress"] = 13

	var saved: Dictionary = w.get_save_data()
	w.reset_all_tracks()          # wipe, as a fresh session would
	w.load_save_data(saved)

	assert_int(int(w.war_tracks[tid]["current_progress"])).override_failure_message(
		"campaign progress did not survive the slim round-trip"
	).is_equal(13)


func test_config_is_restored_from_the_data_file_not_the_save() -> void:
	# The point of slimming: the save no longer carries name/description/thresholds,
	# so they must still be present after a load — sourced from the JSON.
	var w := _war()
	if w == null:
		return
	w.reset_all_tracks()
	var tid = w.war_tracks.keys()[0]
	var saved: Dictionary = w.get_save_data()
	w.load_save_data(saved)

	var track: Dictionary = w.war_tracks[tid]
	for f in ["name", "description", "thresholds"]:
		assert_bool(track.has(f)).override_failure_message(
			"config field '%s' vanished — loading a slim save destroyed the track config" % f
		).is_true()


func test_a_legacy_full_blob_save_still_loads() -> void:
	# Every save currently on disk is this shape. Its state must be taken and its
	# stale config ignored in favour of the data file.
	var w := _war()
	if w == null:
		return
	w.reset_all_tracks()
	var tid = w.war_tracks.keys()[0]
	var legacy := {
		"war_tracks": {
			tid: {
				"current_progress": 9,
				"highest_threshold_reached": 2,
				"active": true,
				"name": "STALE NAME FROM AN OLD SAVE",
				"description": "stale",
				"thresholds": {},
			}
		},
		"active_track_ids": [],
		"current_effects": {},
	}
	w.load_save_data(legacy)

	assert_int(int(w.war_tracks[tid]["current_progress"])).override_failure_message(
		"state from a legacy full-blob save was ignored"
	).is_equal(9)
	assert_str(str(w.war_tracks[tid]["name"])).override_failure_message(
		"a stale name from an old save overwrote the data file — the very bug slimming removes"
	).is_not_equal("STALE NAME FROM AN OLD SAVE")


func test_a_track_the_data_file_no_longer_defines_is_kept() -> void:
	# A renamed or removed track must not silently erase a player's progress.
	var w := _war()
	if w == null:
		return
	w.reset_all_tracks()
	w.load_save_data({
		"war_tracks": {"retired_track": {"current_progress": 4}},
		"active_track_ids": [], "current_effects": {},
	})
	assert_bool(w.war_tracks.has("retired_track")).override_failure_message(
		"progress on a track the data file dropped was discarded"
	).is_true()
