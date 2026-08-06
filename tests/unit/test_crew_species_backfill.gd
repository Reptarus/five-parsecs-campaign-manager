extends GdUnitTestSuite
## Existing saves written by the narrowed writer must recover their species on load.
##
## CONTEXT
## Until CampaignCreationCoordinator._character_to_dict() was fixed, every NON-CAPTAIN
## crew member was saved through a ~17-field projection that dropped species_id,
## is_bot and is_soulless. Measured across the 30 save files on disk: 0 of 73
## non-captain members carried species_id. Fixing the writer does nothing for files
## already written — those campaigns would keep running with all 16 Strange Character
## rules inert — so from_dictionary() re-derives what it can.
##
## DERIVED, NOT INVENTED
## `origin` survived the projection and is the datum the species was chosen from.
## Every mapping target was checked against data/character_species.json (note `kerin`,
## NOT `k_erin`). Anything unresolvable is LEFT ALONE: an absent species_id is honest,
## a wrong one silently changes which rules fire.
##
## MEASURED against the 30 real saves: 62 of 85 species-less members recover, 23 are
## unrecoverable because they were saved with origin = NONE (0). 73%, not 100% — the
## remainder is a real limit of what the projection left behind.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _load_with_crew(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "backfill_t", "crew": {"members": members}})
	return c


func _members_of(campaign) -> Array:
	var cd = campaign.crew_data
	if not (cd is Dictionary):
		return []
	var m = (cd as Dictionary).get("members", [])
	return m if m is Array else []


# --- the three shapes `origin` actually takes on disk ---------------------------

func test_int_origin_recovers_species() -> void:
	# GlobalEnums.Origin.SWIFT == 7, the most common non-zero value in the real saves.
	var c = _load_with_crew([{"character_name": "Zip", "origin": 7}])
	assert_str(str(_members_of(c)[0].get("species_id", ""))).is_equal("swift")


func test_float_origin_recovers_species() -> void:
	# Legacy saves store origin as a FLOAT (the documented origin-float trap).
	var c = _load_with_crew([{"character_name": "Hollow", "origin": 6.0}])
	assert_str(str(_members_of(c)[0].get("species_id", ""))).is_equal("soulless")


func test_string_origin_recovers_species() -> void:
	# Display name -> id, matching the captains that DID round-trip.
	var c = _load_with_crew([{"character_name": "Ash", "origin": "De-converted"}])
	assert_str(str(_members_of(c)[0].get("species_id", ""))).is_equal("de_converted")


func test_kerin_maps_to_the_id_the_data_file_actually_uses() -> void:
	# character_species.json uses "kerin". "k_erin" would match nothing — this is the
	# exact guess the fix avoided by reading the data file.
	var c = _load_with_crew([{"character_name": "Krag Warrior", "origin": 4}])
	assert_str(str(_members_of(c)[0].get("species_id", ""))).is_equal("kerin")


func test_human_homeworld_origins_map_to_human() -> void:
	# The Origin enum conflates species with human homeworlds: PRISON_PLANET(17),
	# CORE_WORLDS(9) and FRONTIER(10) are all origins a HUMAN can have.
	for ordinal in [9, 10, 17]:
		var c = _load_with_crew([{"character_name": "Someone", "origin": ordinal}])
		assert_str(str(_members_of(c)[0].get("species_id", ""))).override_failure_message(
			"origin ordinal %d should resolve to human" % ordinal
		).is_equal("human")


# --- what must NOT happen ------------------------------------------------------

func test_unrecoverable_origin_is_left_alone_not_guessed() -> void:
	# Origin.NONE == 0. 23 of the 88 real crew members are in this state. Writing a
	# plausible-looking species here would silently change which rules fire.
	var c = _load_with_crew([{"character_name": "Nobody", "origin": 0}])
	var m: Dictionary = _members_of(c)[0]
	assert_bool(str(m.get("species_id", "")).is_empty()).override_failure_message(
		"an unrecoverable species was GUESSED instead of left absent"
	).is_true()


func test_an_existing_species_id_is_never_overwritten() -> void:
	# Captains and post-fix members already carry the real value; the backfill must
	# not second-guess it from a coarser field.
	var c = _load_with_crew([
		{"character_name": "Cap", "origin": 1, "species_id": "unity_agent"},
	])
	assert_str(str(_members_of(c)[0].get("species_id", ""))).is_equal("unity_agent")


# --- flags that are pure functions of species ----------------------------------

func test_bot_flag_is_restored_for_the_p98_no_xp_rule() -> void:
	var c = _load_with_crew([{"character_name": "Nine", "origin": 8}])
	var m: Dictionary = _members_of(c)[0]
	assert_str(str(m.get("species_id", ""))).is_equal("bot")
	assert_bool(bool(m.get("is_bot", false))).override_failure_message(
		"is_bot not restored — Core Rules p.98 (Bots never gain XP) stays unenforced"
	).is_true()


func test_backfilled_members_are_marked_auditable() -> void:
	# The value was derived on load, not read from the file. Say so in the data.
	var c = _load_with_crew([{"character_name": "Zip", "origin": 7}])
	assert_bool(bool(_members_of(c)[0].get("species_backfilled", false))).is_true()


func test_a_non_dictionary_member_does_not_break_the_load() -> void:
	var c = _load_with_crew(["not a dict", {"character_name": "Ok", "origin": 7}])
	assert_int(_members_of(c).size()).is_equal(2)
