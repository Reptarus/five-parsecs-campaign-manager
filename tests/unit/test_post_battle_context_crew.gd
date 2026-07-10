extends GdUnitTestSuite
## Wave 1a — PostBattleContext crew-lookup + injury-application API. These revive
## guards that were dead because GameStateManager never defined get_crew_member /
## apply_crew_injury, so post-battle injuries rolled but never mutated the crew.

const CTX = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func _ctx_with_crew() -> Object:
	var ctx = CTX.new()
	# Dictionary campaign path (PostBattleContext.get_crew_members reads campaign["crew"]).
	ctx.campaign = {"crew": [
		{"character_id": "c1", "character_name": "Alpha"},
		{"character_id": "c2", "character_name": "Beta"},
	]}
	return ctx

func test_get_crew_member_matches_by_id() -> void:
	var ctx = _ctx_with_crew()
	var m = ctx.get_crew_member("c2")
	assert_that(m).is_not_null()
	assert_str(m["character_name"]).is_equal("Beta")

func test_get_crew_member_missing_returns_null() -> void:
	var ctx = _ctx_with_crew()
	assert_that(ctx.get_crew_member("nope")).is_null()
	assert_that(ctx.get_crew_member("")).is_null()

func test_apply_crew_injury_mutates_member() -> void:
	var ctx = _ctx_with_crew()
	var ok: bool = ctx.apply_crew_injury("c1", {"type": "MINOR", "recovery_turns": 2})
	assert_bool(ok).is_true()
	var m: Dictionary = ctx.get_crew_member("c1")
	assert_bool(m["is_wounded"]).is_true()
	assert_int(m["injury_recovery_turns"]).is_equal(2)
	assert_int(m["status_effects"].size()).is_equal(1)

func test_apply_crew_injury_unknown_member_is_false() -> void:
	var ctx = _ctx_with_crew()
	assert_bool(ctx.apply_crew_injury("ghost", {"recovery_turns": 1})).is_false()

func test_get_participating_crew_passes_objects_through() -> void:
	# Producers fill crew_participants with character OBJECTS (dicts), not ids —
	# the old loop treated them as ids and returned []. They must pass through.
	var ctx = _ctx_with_crew()
	ctx.crew_participants = [
		{"character_id": "c1", "character_name": "Alpha"},
		{"character_id": "c2", "character_name": "Beta"},
	]
	var crew: Array = ctx.get_participating_crew()
	assert_int(crew.size()).is_equal(2)
	assert_str(crew[0]["character_name"]).is_equal("Alpha")

func test_get_participating_crew_resolves_string_ids() -> void:
	var ctx = _ctx_with_crew()
	ctx.crew_participants = ["c2"]
	var crew: Array = ctx.get_participating_crew()
	assert_int(crew.size()).is_equal(1)
	assert_str(crew[0]["character_name"]).is_equal("Beta")
