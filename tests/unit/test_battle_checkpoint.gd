extends GdUnitTestSuite

## FPCM_BattleCheckpoint — an interrupted battle must come back the way it was left.
##
## Built against the REAL TacticalUnit inner class, not a stub: the checkpoint reads
## the unit by duck typing, so a hand-written stub would happily agree with a
## checkpoint that had drifted away from the shape the battle screen actually uses.

const TBU = preload("res://src/ui/screens/battle/TacticalBattleUI.gd")
const Checkpoint = preload("res://src/core/battle/BattleCheckpoint.gd")

const TURN := 7


func _crew_unit(id: String, nm: String) -> Object:
	var u = TBU.TacticalUnit.new()
	u.initialize_from_crew_member({
		"character_id": id, "character_name": nm, "name": nm,
		"combat": 1, "toughness": 3, "savvy": 1, "reactions": 2, "luck": 2,
	})
	u.team = "crew"
	return u


func _enemy_unit(nm: String) -> Object:
	var u = TBU.TacticalUnit.new()
	u.initialize_from_enemy({
		"name": nm, "type": "Gangers", "combat": 0, "toughness": 3,
		"savvy": 0, "reactions": 1, "speed": 4,
	})
	u.team = "enemy"
	return u


func test_round_trip_restores_every_per_figure_fact() -> void:
	var crew := [_crew_unit("crew_a", "Ana"), _crew_unit("crew_b", "Bo")]
	var enemies := [_enemy_unit("G1"), _enemy_unit("G2")]

	# A fight in progress: one crew Stunned and activated with Luck spent, one
	# enemy down and credited.
	crew[0].stun_markers = 2
	crew[0].is_activated = true
	crew[0].react_slot = 1
	crew[0].initiative_roll = 3
	crew[0].luck_remaining = 1
	crew[1].is_knocked_out = true
	enemies[0].is_dead = true
	enemies[0].health = 0
	enemies[0].killed_by = "Ana"

	var data: Dictionary = Checkpoint.build(
		TURN, 1, 3, 2, crew, enemies, {"mission_data": {"title": "X"}})

	# Fresh figures, as a relaunch would build them.
	var crew2 := [_crew_unit("crew_a", "Ana"), _crew_unit("crew_b", "Bo")]
	var enemies2 := [_enemy_unit("G1"), _enemy_unit("G2")]
	var receipt: Dictionary = Checkpoint.apply(data, crew2, enemies2)

	assert_int(int(receipt["crew_restored"])).is_equal(2)
	assert_int(int(receipt["enemies_restored"])).is_equal(2)
	assert_array(receipt["unmatched"]).is_empty()

	assert_int(crew2[0].stun_markers).is_equal(2)
	assert_bool(crew2[0].is_activated).is_true()
	assert_int(crew2[0].react_slot).is_equal(1)
	assert_int(crew2[0].initiative_roll).is_equal(3)
	assert_int(crew2[0].luck_remaining).is_equal(1)
	assert_bool(crew2[1].is_knocked_out).is_true()
	assert_bool(enemies2[0].is_dead).is_true()
	assert_str(enemies2[0].killed_by).is_equal("Ana")
	# The figure that was still up must NOT come back dead.
	assert_bool(enemies2[1].is_dead).is_false()
	assert_int(data["round"]).is_equal(3)
	assert_int(data["phase"]).is_equal(2)


func test_health_follows_is_dead_not_the_stored_number() -> void:
	## health is an internal liveness flag now (Core Rules p.46 has no hit points).
	## A file whose health disagreed with is_dead would restore a figure that is
	## neither up nor removed.
	var crew := [_crew_unit("crew_a", "Ana")]
	crew[0].is_dead = true
	crew[0].health = 3  # deliberately incoherent
	var data: Dictionary = Checkpoint.build(TURN, 0, 1, 0, crew, [])

	var crew2 := [_crew_unit("crew_a", "Ana")]
	Checkpoint.apply(data, crew2, [])
	assert_bool(crew2[0].is_dead).is_true()
	assert_int(crew2[0].health).is_equal(0)


func test_a_checkpoint_from_another_turn_is_refused() -> void:
	## The gate that stops the NEXT battle opening with the previous one's
	## casualties already marked down.
	var data: Dictionary = Checkpoint.build(TURN, 0, 2, 1, [], [])
	assert_bool(Checkpoint.is_valid(data, TURN)).is_true()
	assert_bool(Checkpoint.is_valid(data, TURN + 1)).is_false()


func test_an_unknown_schema_is_refused() -> void:
	var data: Dictionary = Checkpoint.build(TURN, 0, 1, 0, [], [])
	data["schema_version"] = 999
	assert_bool(Checkpoint.is_valid(data, TURN)).is_false()
	assert_bool(Checkpoint.is_valid({}, TURN)).is_false()


func test_a_figure_the_checkpoint_does_not_know_is_reported() -> void:
	## A restore that silently matched half the figures is worse than none: it
	## looks complete. The receipt is what lets the screen say so.
	var data: Dictionary = Checkpoint.build(
		TURN, 0, 1, 0, [_crew_unit("crew_a", "Ana")], [])
	var crew2 := [_crew_unit("crew_a", "Ana"), _crew_unit("crew_zz", "Zed")]
	var receipt: Dictionary = Checkpoint.apply(data, crew2, [])
	assert_int(int(receipt["crew_restored"])).is_equal(1)
	assert_array(receipt["unmatched"]).contains(["crew crew_zz"])


func test_crew_keys_and_member_key_agree() -> void:
	## The resume filters the campaign roster against crew_keys() using
	## member_key(). If those two identity rules ever disagreed, the resumed battle
	## would field the wrong figures — so they are asserted against each other.
	var crew := [_crew_unit("crew_a", "Ana"), _crew_unit("crew_b", "Bo")]
	var data: Dictionary = Checkpoint.build(TURN, 0, 1, 0, crew, [])
	var keys: Array = Checkpoint.crew_keys(data)
	assert_array(keys).contains(["crew_a", "crew_b"])
	assert_str(Checkpoint.member_key({"character_id": "crew_a"})).is_equal("crew_a")
	assert_bool(keys.has(Checkpoint.member_key(
		{"character_id": "crew_b", "character_name": "Bo"}))).is_true()
	assert_bool(keys.has(Checkpoint.member_key(
		{"character_id": "crew_zz"}))).is_false()


# ── T10-06: the checkpoint has to reach DISK, not just progress_data ──────────
#
# Every case above round-trips the checkpoint DICTIONARY, which is why this suite
# was green while a real battle was being lost. On the tablet on 2026-09-04 the
# live save was pulled mid-battle and `grep -c active_battle` returned 0: nothing
# on the battle path ever called save_campaign(), so the fight existed only in
# RAM and a force-stop took it. Asserting the dict alone cannot see that — this
# case writes the campaign to a file and reads it back.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const TEST_DIR := "user://test_battle_checkpoint_disk/"


func _test_path() -> String:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	return TEST_DIR + "cp_round_trip.save"


func test_active_battle_survives_a_real_save_file_round_trip() -> void:
	var crew := [_crew_unit("crew_a", "Ana"), _crew_unit("crew_b", "Bo")]
	var enemies := [_enemy_unit("G1"), _enemy_unit("G2")]
	enemies[0].is_dead = true
	crew[0].stun_markers = 2

	var campaign := CampaignCore.new()
	campaign.campaign_id = "cp_disk_test"
	campaign.progress_data["turns_played"] = TURN
	campaign.progress_data["active_battle"] = Checkpoint.build(
		TURN, 1, 3, 2, crew, enemies, {"reaction_rolled": true})

	var path := _test_path()
	assert_int(campaign.save_to_file(path)).is_equal(OK)

	var loaded = CampaignCore.load_from_file(path)
	assert_object(loaded).is_not_null()

	# The key exists at all — this is the assertion the device disproved.
	var restored: Variant = loaded.progress_data.get("active_battle", null)
	assert_bool(restored is Dictionary).override_failure_message(
		"active_battle did not survive the save file at all").is_true()

	# ...and it is still a usable checkpoint, not just a present key. Godot's JSON
	# parser returns every number as a FLOAT, so a checkpoint that round-trips
	# structurally can still fail is_valid()/round on the way back in.
	assert_bool(Checkpoint.is_valid(restored, TURN)).is_true()
	assert_int(int(restored.get("round", -1))).is_equal(3)
	assert_int(int(restored.get("phase", -1))).is_equal(2)
	assert_array(Checkpoint.crew_keys(restored)).contains(["crew_a", "crew_b"])

	DirAccess.remove_absolute(path)
