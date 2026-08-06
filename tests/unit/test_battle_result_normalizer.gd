extends GdUnitTestSuite
## Wave 1a — the battle-result normalizer maps producer vocabulary onto the keys
## the post-battle consumer chain reads, WITHOUT touching producer keys (which are
## pinned by test_battle_results_input_form.gd + test_post_battle_success_cascade.gd).
## Before this, the played tactical path passed the raw producer dict straight
## through → injuries never processed, danger pay dropped, journal stamped turn 0.

const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")

func _producer_dict() -> Dictionary:
	return {"victory": true, "won": true, "success": true, "held_field": true,
		"crew_casualties": 1, "crew_injuries": 1,
		"crew_casualties_data": [{"character_id": "c1", "character_name": "Alpha", "origin": "Human"}],
		"crew_injuries_data": [{"character_id": "c2", "character_name": "Beta", "species_id": "swift"}],
		"crew_participants": [], "defeated_enemies": [{"name": "Raider", "type": "Pirates"}],
		"enemies_defeated_count": 3, "mission_source": "patron", "auto_resolved": false}

func test_fills_consumer_keys_without_touching_producer_keys() -> void:
	var r := Normalizer.normalize(_producer_dict(), {"patron_id": "p1", "danger_pay": 2}, 7)
	assert_int(r["turn"]).is_equal(7)
	assert_int(r["danger_pay"]).is_equal(2)
	assert_str(r["patron_id"]).is_equal("p1")
	assert_str(r["injuries_sustained"][0]["crew_id"]).is_equal("c2")
	assert_str(r["casualties"][0]["type"]).is_equal("killed")
	assert_str(r["casualties"][0]["crew_id"]).is_equal("c1")
	assert_int(r["crew_casualties"]).is_equal(1)          # producer key untouched
	assert_bool(r.has("crew_casualties_data")).is_true()  # producer key untouched

func test_idempotent_never_overwrites() -> void:
	var r := Normalizer.normalize(_producer_dict(), {"patron_id": "p1", "danger_pay": 2}, 7)
	r = Normalizer.normalize(r, {"patron_id": "p2", "danger_pay": 99}, 99)
	assert_int(r["turn"]).is_equal(7)
	assert_int(r["danger_pay"]).is_equal(2)
	assert_str(r["patron_id"]).is_equal("p1")

func test_rival_stamp_and_is_rival_mission() -> void:
	var d := _producer_dict()
	d["mission_source"] = "rival"
	var r := Normalizer.normalize(d, {"rival_id": "riv_1"}, 1)
	assert_bool(r["defeated_enemies"][0]["is_rival"]).is_true()
	assert_str(r["defeated_enemies"][0]["rival_id"]).is_equal("riv_1")
	assert_bool(r["is_rival_mission"]).is_true()

func test_patron_id_only_for_patron_missions() -> void:
	# A non-patron mission must NOT get a patron_id even if the job carries one.
	var d := _producer_dict()
	d["mission_source"] = "opportunity"
	var r := Normalizer.normalize(d, {"patron_id": "p1"}, 1)
	assert_bool(r.has("patron_id")).is_false()

func test_empty_mission_degrades_gracefully() -> void:
	var r := Normalizer.normalize({"victory": false}, {}, 3)
	assert_int(r["turn"]).is_equal(3)
	assert_bool(r.has("danger_pay")).is_false()
	assert_that(r["casualties"]).is_equal([])
	assert_that(r["injuries_sustained"]).is_equal([])

# ---------------------------------------------------------------------------
# casualty_count — the shape contract every numeric read must go through.
#
# normalize() step 8 makes `casualties` an Array of dicts. Five consumers were
# written against an int, and in Godot 4.6 EVERY numeric use of an Array is a
# runtime error that aborts the enclosing function (verified: `int(Array)`,
# `Array == 0`, `Array > 0`, typed-int assignment, `"%d" % Array`). That cost
# the battle journal its description AND mood, the post-battle narrative screen,
# and the tail of the summary sheet — silently, because an abort unwinds only
# the callee. These pin the helper and the shapes it must tolerate.
# ---------------------------------------------------------------------------

func test_casualty_count_counts_the_normalized_array() -> void:
	var r := Normalizer.normalize(_producer_dict(), {}, 1)
	assert_bool(r["casualties"] is Array).is_true()
	assert_int(Normalizer.casualty_count(r)).is_equal(1)

func test_casualty_count_scales_with_the_array() -> void:
	var producer := _producer_dict()
	producer["crew_casualties_data"] = [
		{"character_id": "c1"}, {"character_id": "c2"}, {"character_id": "c3"}]
	assert_int(Normalizer.casualty_count(Normalizer.normalize(producer, {}, 1))).is_equal(3)

func test_casualty_count_tolerates_an_int() -> void:
	# Bug Hunt / Planetfall / pre-normalizer saves can still carry a plain int.
	assert_int(Normalizer.casualty_count({"casualties": 2})).is_equal(2)

func test_casualty_count_defaults_to_zero() -> void:
	assert_int(Normalizer.casualty_count({})).is_equal(0)
	assert_int(Normalizer.casualty_count({"casualties": null})).is_equal(0)
	assert_int(Normalizer.casualty_count({"casualties": []})).is_equal(0)

func test_black_zone_failure_pays_per_casualty() -> void:
	# THE JOIN, not the link. BlackZoneSystem read "casualties_count" — a key no
	# producer writes — so the Appendix III failure payout ("1cr per casualty
	# from Unity") always resolved to zero credits.
	var producer := _producer_dict()
	producer["success"] = false
	producer["crew_casualties_data"] = [{"character_id": "c1"}, {"character_id": "c2"}]
	var normalized := Normalizer.normalize(producer, {}, 1)
	var rewards: Dictionary = BlackZoneSystem.calculate_rewards(normalized)
	assert_bool(rewards["is_victory"]).is_false()
	# 1cr per casualty x 2 casualties. Float because the rate comes from JSON.
	assert_float(float(rewards["unity_casualty_pay"])).is_equal(2.0)
