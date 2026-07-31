extends GdUnitTestSuite
## The three per-character battle_result keys that NO PRODUCER EVER WROTE, and
## the real mechanics that read them (Core Rules p.21, p.123).
##
## THE GAP THESE PIN: ExperienceTrainingProcessor and PostBattleCompletion both
## read keys that nothing on any of the four result paths produced.
##
##   units_downed      -> p.21 Hopeful Rookie "+1 XP if not downed", and the
##                        battles_survived counter. Absent means every Hopeful
##                        Rookie collected the bonus whether or not they went
##                        Out of Action, and battles_survived counted every
##                        battle — it silently meant "battles participated".
##   first_casualty_by -> p.123 "First character to inflict a casualty +1"
##   unique_kills      -> p.123 "Killed Unique Individual +1"
##
## units_downed is DERIVED (going Out of Action is already recorded on every
## path). The other two are ASKED, because the app does not watch the dice —
## which is the companion-app premise, not a shortcut.

const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")

func _entry(crew_id: String) -> Dictionary:
	return {"crew_id": crew_id, "name": crew_id}

# ── units_downed is derived from the crew who went Out of Action ──────────

func test_units_downed_is_the_union_of_injuries_and_casualties() -> void:
	var results: Dictionary = {
		"injuries_sustained": [_entry("c1"), _entry("c2")],
		"casualties": [_entry("c3")],
	}
	var out: Dictionary = Normalizer.normalize(results, {}, 1)
	var downed: Array = out["units_downed"]
	assert_int(downed.size()).is_equal(3)
	for cid in ["c1", "c2", "c3"]:
		assert_bool(cid in downed).override_failure_message(
			"%s went Out of Action but is not in units_downed" % cid).is_true()

func test_a_crew_member_downed_and_injured_is_listed_once() -> void:
	# The same figure can appear on both arrays; the XP and battles_survived
	# checks are membership tests, so a duplicate would be harmless — but a
	# duplicate-free list is what the key claims to be.
	var results: Dictionary = {
		"injuries_sustained": [_entry("c1")],
		"casualties": [_entry("c1")],
	}
	var out: Dictionary = Normalizer.normalize(results, {}, 1)
	assert_int((out["units_downed"] as Array).size()).is_equal(1)

func test_an_unscathed_crew_produces_an_empty_downed_list() -> void:
	var out: Dictionary = Normalizer.normalize({}, {}, 1)
	assert_array(out["units_downed"]).is_empty()

func test_units_downed_is_derived_from_the_raw_crew_arrays_too() -> void:
	# Producers write crew_injuries_data / crew_casualties_data; the normalizer
	# builds injuries_sustained / casualties from those FIRST, so the derivation
	# has to work from the raw producer shape as well as the mapped one.
	var results: Dictionary = {
		"crew_injuries_data": [{"character_id": "c9", "character_name": "Nine"}],
		"crew_casualties_data": [{"character_id": "c8", "character_name": "Eight"}],
	}
	var out: Dictionary = Normalizer.normalize(results, {}, 1)
	var downed: Array = out["units_downed"]
	assert_bool("c9" in downed).is_true()
	assert_bool("c8" in downed).is_true()

func test_the_normalizer_never_overwrites_a_producer_supplied_list() -> void:
	# ADD-ONLY is the normalizer's contract; a path that already knows who was
	# downed must win.
	var out: Dictionary = Normalizer.normalize(
		{"units_downed": ["explicit"], "casualties": [_entry("c1")]}, {}, 1)
	assert_array(out["units_downed"]).contains_exactly(["explicit"])

func test_normalizing_twice_is_idempotent() -> void:
	var results: Dictionary = {"casualties": [_entry("c1")]}
	var once: Dictionary = Normalizer.normalize(results, {}, 1)
	var twice: Dictionary = Normalizer.normalize(once, {}, 1)
	assert_array(twice["units_downed"]).contains_exactly(["c1"])

# ── The XP-credit keys keep the shapes their consumers expect ─────────────

func test_first_casualty_by_survives_normalization_as_a_crew_id() -> void:
	# ExperienceTrainingProcessor compares it directly: `== crew_id`. A shape
	# change here silently stops awarding the bonus rather than erroring.
	var out: Dictionary = Normalizer.normalize({"first_casualty_by": "c4"}, {}, 1)
	assert_str(str(out["first_casualty_by"])).is_equal("c4")

func test_unique_kills_survives_normalization_as_a_list() -> void:
	# Consumer does `crew_id in unique_kills`, so it must stay an Array even
	# when only one figure earned it.
	var out: Dictionary = Normalizer.normalize({"unique_kills": ["c5"]}, {}, 1)
	assert_array(out["unique_kills"]).contains_exactly(["c5"])

func test_no_xp_credit_declared_leaves_both_keys_award_nothing() -> void:
	# "Nobody" is the form's default, so the common case must award neither
	# bonus. Empty string never equals a crew_id; an empty list contains none.
	var out: Dictionary = Normalizer.normalize(
		{"first_casualty_by": "", "unique_kills": []}, {}, 1)
	assert_str(str(out["first_casualty_by"])).is_empty()
	assert_array(out["unique_kills"]).is_empty()
