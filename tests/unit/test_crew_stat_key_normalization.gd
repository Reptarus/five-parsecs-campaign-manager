extends GdUnitTestSuite
## Pins the crew reaction-stat key normalization (Jul 30 core-loop walk).
##
## Character.to_dictionary() emits BOTH "reactions" and "reaction" because the
## consumers are split — battle reads the plural, the crew UI reads the singular.
## Every campaign saved BEFORE that fix contains only the plural, and nothing
## normalised it on load, so CampaignDashboard.gd:621 (`member.get("reaction", 0)`)
## rendered "R: 0" on every crew card of every pre-existing save.
##
## Reproduced on a real save file: 6/6 members had "reactions", 0/6 had "reaction".
##
## These cases FAIL without _normalize_crew_stat_keys().
## gdUnit4 v6.0.3. Run with -c, never --headless (project rule).

const CampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _legacy_save_dict(members: Array) -> Dictionary:
	return {
		"campaign_id": "keytest",
		"campaign_name": "Key Test",
		"crew": {"members": members},
	}


func test_legacy_plural_only_save_gains_singular_on_load() -> void:
	# The exact shape of a pre-fix save.
	var core = CampaignCore.new()
	core.from_dictionary(_legacy_save_dict([
		{"character_id": "c1", "character_name": "Blake", "reactions": 1},
		{"character_id": "c2", "character_name": "Ash", "reactions": 3},
	]))
	var members: Array = core.crew_data["members"]
	assert_int(members.size()).is_equal(2)
	for m in members:
		assert_bool(m.has("reaction")).override_failure_message(
			"load must backfill the singular key the crew UI reads").is_true()
	# Values must MATCH, not merely exist — a 0 default would still render R: 0.
	assert_int(int(members[0]["reaction"])).is_equal(1)
	assert_int(int(members[1]["reaction"])).is_equal(3)


func test_singular_only_save_gains_plural_on_load() -> void:
	# Mirror direction: battle code reads the plural.
	var core = CampaignCore.new()
	core.from_dictionary(_legacy_save_dict([
		{"character_id": "c1", "character_name": "Blake", "reaction": 2},
	]))
	var m: Dictionary = core.crew_data["members"][0]
	assert_bool(m.has("reactions")).is_true()
	assert_int(int(m["reactions"])).is_equal(2)


func test_existing_both_keys_are_not_clobbered() -> void:
	# Post-fix saves already carry both; normalization must be a no-op there.
	var core = CampaignCore.new()
	core.from_dictionary(_legacy_save_dict([
		{"character_id": "c1", "reaction": 4, "reactions": 4},
	]))
	var m: Dictionary = core.crew_data["members"][0]
	assert_int(int(m["reaction"])).is_equal(4)
	assert_int(int(m["reactions"])).is_equal(4)


func test_initialize_crew_also_normalizes() -> void:
	# Creation path, for crew not built via Character.to_dictionary().
	var core = CampaignCore.new()
	core.initialize_crew({"members": [{"character_id": "c1", "reactions": 5}]})
	var m: Dictionary = core.crew_data["members"][0]
	assert_bool(m.has("reaction")).is_true()
	assert_int(int(m["reaction"])).is_equal(5)


func test_non_dictionary_members_do_not_abort_the_load() -> void:
	# A malformed entry must not unwind the function and skip the rest — the
	# silent-abort failure mode this whole sweep exists to catch.
	var core = CampaignCore.new()
	core.from_dictionary(_legacy_save_dict([
		"not-a-dict",
		{"character_id": "c2", "reactions": 6},
	]))
	var members: Array = core.crew_data["members"]
	assert_int(members.size()).is_equal(2)
	assert_bool((members[1] as Dictionary).has("reaction")).override_failure_message(
		"a bad entry must not stop later members being normalised").is_true()
