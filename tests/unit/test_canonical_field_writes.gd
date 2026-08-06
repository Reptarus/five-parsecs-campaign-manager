extends GdUnitTestSuite
## Writers must write the field names their READERS actually read.
##
## Four separate defects in this codebase shared one shape: a writer stored state
## under a name (or in a location) that no consumer checks, so a rule silently did
## nothing while every individual function looked correct. These pin the four
## repaired contracts.
##
## gdUnit4 v6.0.3 compatible.

const CTX = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const COMPLETION = preload("res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")


# --- #12: post-battle injuries must enter Sick Bay ---------------------------
#
# apply_crew_injury wrote only `injury_recovery_turns`, a name no reader knows.
# Every gate reads in_sick_bay / recovery_turns / status / injuries, so an injured
# crew member stayed deployable, stayed task-eligible, and still counted for
# upkeep. Core Rules p.55 / p.76 / p.99.

func _ctx_with_member() -> Object:
	var ctx = CTX.new()
	ctx.campaign = {"crew": [
		{"character_id": "c1", "character_name": "Vance", "equipment": []},
	]}
	ctx.battle_result = {"turn": 4}
	return ctx


func _member_of(ctx) -> Dictionary:
	return (ctx.campaign["crew"] as Array)[0]


func test_injury_sets_the_fields_the_sick_bay_gates_actually_read() -> void:
	var ctx = _ctx_with_member()
	ctx.apply_crew_injury("c1", {"type": "CRIPPLING_WOUND", "recovery_turns": 4})
	var m := _member_of(ctx)

	# UpkeepPhaseComponent.gd:151 and CrewTaskComponent.gd:182
	assert_bool(bool(m.get("in_sick_bay", false))).override_failure_message(
		"in_sick_bay not set; crew stays task-eligible and counts for upkeep"
	).is_true()
	# UpkeepPhaseComponent.gd:153 fallback
	assert_int(int(m.get("recovery_turns", 0))).is_equal(4)
	# CrewTaskComponent.gd:183 ORs this in
	assert_str(str(m.get("status", ""))).is_equal("injured")


func test_injury_appends_to_the_injuries_array_the_countdown_walks() -> void:
	# CampaignPhaseManager's rollover decrements each entry's recovery_turns and
	# removes it at zero. Without an entry here, recovery never counts down.
	var ctx = _ctx_with_member()
	ctx.apply_crew_injury("c1", {"type": "CRIPPLING_WOUND", "recovery_turns": 3})
	var injuries: Array = _member_of(ctx).get("injuries", [])
	assert_int(injuries.size()).is_equal(1)
	assert_int(int((injuries[0] as Dictionary).get("recovery_turns", 0))).is_equal(3)


func test_a_zero_recovery_injury_does_not_bench_the_member() -> void:
	# Not every injury benches. recovery_turns 0 must record the injury without
	# putting the member in Sick Bay, or trivial wounds would lock crew out.
	var ctx = _ctx_with_member()
	ctx.apply_crew_injury("c1", {"type": "SCRATCH", "recovery_turns": 0})
	var m := _member_of(ctx)
	assert_bool(bool(m.get("in_sick_bay", false))).is_false()
	assert_bool(bool(m.get("is_wounded", false))).is_true()


func test_the_legacy_private_counter_is_still_written() -> void:
	# Kept so anything already reading it keeps working; it is simply no longer
	# the ONLY home.
	var ctx = _ctx_with_member()
	ctx.apply_crew_injury("c1", {"type": "WOUND", "recovery_turns": 2})
	assert_int(int(_member_of(ctx).get("injury_recovery_turns", 0))).is_equal(2)


# --- #6: the crew-edit chokepoint must MERGE, not replace --------------------
#
# Editors rebuild a member from Character.to_dictionary(), a NARROWING projection:
# roster-only keys are not Character properties and vanished on write-back, which
# sprang edited crew out of Sick Bay.

func _campaign_with_benched_member() -> Object:
	var campaign = CampaignCore.new()
	campaign.initialize_crew({"members": [{
		"character_id": "c1", "character_name": "Vance", "is_captain": false,
		"in_sick_bay": true, "sick_bay_turns_remaining": 2,
		"locked_out_this_turn": true, "status": "injured",
	}]})
	return campaign


func test_editing_a_member_preserves_roster_only_keys() -> void:
	var campaign = _campaign_with_benched_member()
	# What an editor produces: a Character projection with no roster keys.
	var edited := {"character_id": "c1", "character_name": "Vance Renamed", "combat": 2}
	assert_bool(campaign.update_crew_member("c1", edited)).is_true()

	var m: Dictionary = (campaign.crew_data["members"] as Array)[0]
	assert_str(str(m.get("character_name", ""))).override_failure_message(
		"the edit itself must still win"
	).is_equal("Vance Renamed")
	assert_bool(bool(m.get("in_sick_bay", false))).override_failure_message(
		"in_sick_bay was dropped by the write-back; editing freed them from Sick Bay"
	).is_true()
	assert_int(int(m.get("sick_bay_turns_remaining", 0))).is_equal(2)
	assert_bool(bool(m.get("locked_out_this_turn", false))).is_true()


func test_editing_still_preserves_captaincy() -> void:
	# The pre-existing guarantee must survive the switch to merge.
	var campaign = CampaignCore.new()
	campaign.initialize_crew({"members": [
		{"character_id": "cap", "character_name": "Cap", "is_captain": true},
	]})
	campaign.update_crew_member("cap", {"character_id": "cap", "character_name": "Cap2"})
	var m: Dictionary = (campaign.crew_data["members"] as Array)[0]
	assert_bool(bool(m.get("is_captain", false))).is_true()
	assert_str(str(m.get("character_name", ""))).is_equal("Cap2")


func test_a_real_character_round_trip_keeps_the_member_benched() -> void:
	# End to end through the actual narrowing projection, not a hand-built dict.
	var campaign = _campaign_with_benched_member()
	var source: Dictionary = (campaign.crew_data["members"] as Array)[0]
	var char_obj = CharacterScript.new()
	char_obj.from_dictionary(source)
	campaign.update_crew_member("c1", char_obj.to_dictionary())

	var m: Dictionary = (campaign.crew_data["members"] as Array)[0]
	assert_bool(bool(m.get("in_sick_bay", false))).override_failure_message(
		"Character.to_dictionary() does not model in_sick_bay, so a replace drops it"
	).is_true()


# --- #15: battle journal entries must be attributable ------------------------
#
# The harvest kept only `participant is String`, but every live producer supplies
# character OBJECTS, so characters_involved was always [].

func test_crew_ids_resolve_from_character_dictionaries() -> void:
	var ctx = CTX.new()
	ctx.crew_participants = [
		{"character_id": "c1", "character_name": "Vance"},
		{"character_id": "c2", "character_name": "Rook"},
	]
	var completion = COMPLETION.new()
	var ids: Array = completion._resolve_participant_ids(ctx.crew_participants)
	assert_array(ids).contains(["c1", "c2"])


func test_crew_ids_resolve_from_character_resources() -> void:
	var a = CharacterScript.new()
	a.character_id = "res1"
	var completion = COMPLETION.new()
	var ids: Array = completion._resolve_participant_ids([a])
	assert_array(ids).contains(["res1"])


func test_string_participants_are_still_accepted() -> void:
	# tests/fixtures/BattleTestFactory.gd:239 supplies Strings; those fixtures must
	# keep working.
	var completion = COMPLETION.new()
	var ids: Array = completion._resolve_participant_ids(["c9", ""])
	assert_array(ids).contains(["c9"])
	assert_int(ids.size()).override_failure_message(
		"empty ids must be dropped, not appended as blanks"
	).is_equal(1)
