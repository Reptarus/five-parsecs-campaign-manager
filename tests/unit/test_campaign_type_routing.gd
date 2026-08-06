extends GdUnitTestSuite
## A save must always be loaded through the Core that matches its declared
## campaign_type, from EVERY entry point.
##
## THE BUG THIS EXISTS TO PREVENT
## GameState.load_campaign() routed correctly via _detect_campaign_type(), but
## _try_auto_load_last_campaign() — which runs at EVERY launch — hardcoded
## FiveParsecsCampaignCore.load_from_file(). A guard on one of two doors, and the
## unguarded one is the one that always runs.
##
## It destroyed data. FiveParsecsCampaignCore.load_from_file() only returns null on
## a JSON PARSE failure, and a Bug Hunt save is valid JSON, so it returned a
## populated 5PFH object carrying the BUG HUNT campaign_id and name with zero crew
## and zero credits. has_active_campaign() reported true, MainMenu lit up Continue,
## and because campaign_id was the Bug Hunt id the next autosave rewrote
## user://saves/<bughunt_id>.save through the 5PFH serialiser. That serialiser emits
## no campaign_type, so the campaign also vanished from the Bug Hunt menu, which
## filters on that field. Every mode reaches it: save_campaign() sets last_campaign
## for all four, and Bug Hunt / Planetfall / Tactics all call it.
##
## Measured on the real save asdasd_bh_1775343356 before the fix:
##   five_parsecs_loader_returned_null : false
##   loaded_as_class                   : FiveParsecsCampaignCore.gd
##   campaign_id                       : "asdasd_bh_1775343356"
##   crew_members                      : 0
##
## gdUnit4 v6.0.3 compatible.

const BUG_HUNT_FIXTURE := "user://test_type_routing_bh.save"
const LEGACY_FIXTURE := "user://test_type_routing_legacy.save"


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func before_test() -> void:
	# A minimal but SHAPE-ACCURATE Bug Hunt save: the real one has squad/state, not
	# crew/progress, and declares its type at the root.
	var bh := {
		"campaign_type": "bug_hunt",
		"campaign_id": "test_bh_routing",
		"meta": {"campaign_id": "test_bh_routing", "campaign_name": "Routing Probe"},
		"squad": {"main_characters": [], "grunts": []},
		"state": {"stage": 0},
	}
	var f := FileAccess.open(BUG_HUNT_FIXTURE, FileAccess.WRITE)
	f.store_string(JSON.stringify(bh))
	f.close()

	# A legacy 5PFH save predates the campaign_type field entirely.
	var legacy := {
		"campaign_id": "test_legacy_routing",
		"meta": {"campaign_id": "test_legacy_routing", "campaign_name": "Legacy Probe"},
		"crew": {"members": []},
		"progress": {"turns_played": 3},
	}
	var f2 := FileAccess.open(LEGACY_FIXTURE, FileAccess.WRITE)
	f2.store_string(JSON.stringify(legacy))
	f2.close()


func after_test() -> void:
	for p in [BUG_HUNT_FIXTURE, LEGACY_FIXTURE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _class_of(res) -> String:
	if res == null or res.get_script() == null:
		return "<null>"
	return str(res.get_script().resource_path).get_file()


# --- the routing contract ----------------------------------------------------

func test_a_bug_hunt_save_loads_as_a_bug_hunt_core() -> void:
	var gs := _gs()
	if gs == null or not gs.has_method("load_campaign_typed"):
		return
	var loaded = gs.load_campaign_typed(BUG_HUNT_FIXTURE)
	assert_str(_class_of(loaded)).override_failure_message(
		"a bug_hunt save was parsed by the wrong Core; this is the data-destruction path"
	).is_equal("BugHuntCampaignCore.gd")


func test_a_legacy_save_with_no_type_still_loads_as_5pfh() -> void:
	# Legacy saves predate campaign_type. Absent must mean 5PFH, not "unknown".
	var gs := _gs()
	if gs == null or not gs.has_method("load_campaign_typed"):
		return
	var loaded = gs.load_campaign_typed(LEGACY_FIXTURE)
	assert_str(_class_of(loaded)).is_equal("FiveParsecsCampaignCore.gd")


func test_the_bug_hunt_id_is_not_adopted_by_a_5pfh_campaign() -> void:
	# The precise mechanism of the destruction: the wrong Core adopted the Bug Hunt
	# campaign_id, so the next save overwrote that file through the 5PFH serialiser.
	var gs := _gs()
	if gs == null or not gs.has_method("load_campaign_typed"):
		return
	var loaded = gs.load_campaign_typed(BUG_HUNT_FIXTURE)
	if loaded == null:
		return
	var is_five_parsecs := _class_of(loaded) == "FiveParsecsCampaignCore.gd"
	assert_bool(is_five_parsecs and str(loaded.campaign_id) == "test_bh_routing") \
		.override_failure_message(
			"a 5PFH campaign is holding a Bug Hunt id; the next autosave would " +
			"overwrite the Bug Hunt save with 5PFH data"
		).is_false()


func test_the_wrong_core_would_have_silently_succeeded() -> void:
	# ANTI-VACUOUS GUARD. The routing above is only worth asserting because the
	# WRONG loader does not fail: it returns a populated object. If this ever starts
	# returning null, FiveParsecsCampaignCore gained its own type validation and the
	# tests above are no longer testing what they claim.
	var FiveCore = load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	var mis_parsed = FiveCore.load_from_file(BUG_HUNT_FIXTURE)
	assert_object(mis_parsed).override_failure_message(
		"the 5PFH loader now rejects a bug_hunt save outright — good, but re-read " +
		"these tests: they assume it silently succeeds"
	).is_not_null()
