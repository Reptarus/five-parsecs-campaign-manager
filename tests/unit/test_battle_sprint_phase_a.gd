extends GdUnitTestSuite
## Battle-phase sprint, Phase A. Each test pins a fix whose failure mode was a
## SILENT no-op — the UI kept reporting success while nothing reached the campaign.
## So every assertion here checks OBJECT/CAMPAIGN STATE, never a log line or label.

const CTX = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const XP_PROC = preload("res://src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd")
const NORMALIZER = preload("res://src/core/battle/BattleResultNormalizer.gd")
const CharacterClass = preload("res://src/core/character/Character.gd")

# ── P0.3: XP must reach participants of EVERY shape ────────────────────────
#
# All three live producers fill crew_participants with character OBJECTS
# (TacticalBattleUI passes unit.original_character; BattleResultsInputForm passes
# its _crew array). On a FRESH campaign those objects are Character RESOURCES —
# crew_data["members"] only becomes Dictionaries after a save/load round-trip.
# ExperienceTrainingProcessor resolved only String and Dictionary participants, so
# the Resource shape fell through to `continue` and NOBODY gained XP on a new
# campaign. A fixture that used dicts (or ids) could never catch it.

func _make_character(id: String, cname: String) -> Resource:
	var c: Resource = CharacterClass.new()
	c.character_id = id
	c.character_name = cname
	c.experience = 0
	return c

func _ctx_for_xp(crew: Array, participants: Array) -> Object:
	var ctx = CTX.new()
	ctx.campaign = {"crew": crew}
	ctx.crew_participants = participants
	ctx.mission_successful = true
	ctx.battle_result = {"victory": true, "success": true}
	return ctx

func test_xp_reaches_character_resource_participants() -> void:
	# THE REGRESSION GUARD. Reverting the Resource branch in process_experience
	# makes crew_id stay "" -> `continue` -> zero awards and experience stays 0.
	var alpha := _make_character("c1", "Alpha")
	var beta := _make_character("c2", "Beta")
	var ctx = _ctx_for_xp([alpha, beta], [alpha, beta])

	var awards: Array = XP_PROC.new().process_experience(ctx)

	assert_int(awards.size()).is_equal(2)
	# State, not the returned array: the Resource itself must have moved.
	assert_int(alpha.experience).is_greater(0)
	assert_int(beta.experience).is_greater(0)

func test_xp_resource_participants_get_the_won_battle_value() -> void:
	# Core Rules p.123: "Survived and Won" = +3.
	var alpha := _make_character("c1", "Alpha")
	var ctx = _ctx_for_xp([alpha], [alpha])

	XP_PROC.new().process_experience(ctx)

	assert_int(alpha.experience).is_equal(3)

func test_xp_still_reaches_dictionary_participants() -> void:
	# No regression on the loaded-save shape.
	var alpha := {"character_id": "c1", "character_name": "Alpha", "experience": 0}
	var ctx = _ctx_for_xp([alpha], [alpha])

	XP_PROC.new().process_experience(ctx)

	assert_int(alpha["experience"]).is_equal(3)

func test_xp_still_reaches_string_id_participants() -> void:
	# Test fixtures elsewhere supply plain ids — keep them working.
	var alpha := {"character_id": "c1", "character_name": "Alpha", "experience": 0}
	var ctx = _ctx_for_xp([alpha], ["c1"])

	XP_PROC.new().process_experience(ctx)

	assert_int(alpha["experience"]).is_equal(3)

func test_xp_zero_for_everyone_when_crew_fled_in_first_two_rounds() -> void:
	# Core Rules p.123, verbatim: "Any character that flees the battlefield in the
	# first 2 rounds of the battle receives no XP."
	var alpha := _make_character("c1", "Alpha")
	var ctx = _ctx_for_xp([alpha], [alpha])
	ctx.battle_result["fled_early"] = true

	XP_PROC.new().process_experience(ctx)

	assert_int(alpha.experience).is_equal(0)

# ── P0.7: the evacuation ("It's time to go!") result contract ──────────────
#
# The star path used to emit an ad-hoc 8-key dict with Arrays where ints belong.
# The normalizer builds injuries_sustained/casualties FROM crew_*_data, so those
# came out empty and PostBattlePhase read a missing "success" as false: invoking
# the once-per-campaign escape silently cost every injury roll and all XP.

func _evacuation_result_current_shape() -> Dictionary:
	# Mirrors TacticalBattleUI._build_evacuation_result_dict().
	return {
		"victory": false, "won": false, "success": true, "held_field": false,
		"evacuated": true, "evacuated_via_star": true, "fled_early": false,
		"objective_id": "DELIVER", "objective_met": true, "objective_progress": [],
		"rounds_fought": 5,
		"crew_casualties": 0, "crew_injuries": 1,
		"crew_casualties_data": [],
		"crew_injuries_data": [{"character_id": "c1", "character_name": "Alpha"}],
		"crew_participants": [{"character_id": "c1", "character_name": "Alpha"}],
		"defeated_enemies": [], "enemies_defeated_count": 0, "enemies_remaining": 3,
		"crew_alive": 1, "is_red_zone": false, "is_black_zone": false,
		"is_quest_finale": false, "mission_source": "opportunity",
		"mission_type": "", "auto_resolved": false, "psionic_uses": 0,
	}

func test_evacuation_result_normalizes_into_an_injury_roll() -> void:
	var out: Dictionary = NORMALIZER.normalize(
		_evacuation_result_current_shape(), {}, 7)

	# InjuryProcessor iterates ctx.injuries_sustained and reads crew_id.
	assert_int(out["injuries_sustained"].size()).is_equal(1)
	assert_str(out["injuries_sustained"][0]["crew_id"]).is_equal("c1")

func test_evacuation_keeps_an_objective_completed_before_leaving() -> void:
	# Core Rules p.115: leaving the table forfeits Holding the Field, but an
	# objective achieved BEFORE exiting still stands.
	var out: Dictionary = NORMALIZER.normalize(
		_evacuation_result_current_shape(), {}, 7)

	assert_bool(out["success"]).is_true()
	assert_bool(out["held_field"]).is_false()

func test_evacuation_casualty_count_is_int_shaped() -> void:
	# An Array reaching an int read aborts the reading function (see
	# BattleResultNormalizer.casualty_count's header). The old shape sent Arrays.
	var out: Dictionary = NORMALIZER.normalize(
		_evacuation_result_current_shape(), {}, 7)

	assert_int(NORMALIZER.casualty_count(out)).is_equal(0)
	assert_int(out["crew_injuries"]).is_equal(1)

func test_detection_proof_old_evacuation_shape_loses_everything() -> void:
	# Proves the tests above actually detect the bug: the PREVIOUS dict, fed
	# through the same normalizer, yields no injuries and no success.
	var old_shape: Dictionary = {
		"victory": false, "held_field": false, "evacuated": true,
		"evacuated_via_star": true, "crew_casualties": [], "crew_injuries": [],
		"rounds_fought": 0, "objectives_met": [],
	}
	var out: Dictionary = NORMALIZER.normalize(old_shape, {}, 7)

	assert_int(out["injuries_sustained"].size()).is_equal(0)
	assert_bool(out.has("success")).is_false()
