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
