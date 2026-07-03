extends GdUnitTestSuite
## Seed determinism: the persistence design depends on reproducible
## generation (same seed -> identical battlefield) and deterministic
## derived seeds for per-sector re-rolls.

const GeneratorClass = preload("res://src/core/battle/BattlefieldGenerator.gd")

var _gen: RefCounted


func before_test() -> void:
	_gen = GeneratorClass.new()


func _sectors_fingerprint(result: Dictionary) -> String:
	return JSON.stringify(result.get("sectors", []))


func test_same_seed_same_battlefield() -> void:
	for theme in ["industrial_zone", "wilderness", "alien_ruin", "crash_site"]:
		var a: Dictionary = _gen.generate_terrain_suggestions(
			theme, ["overgrown"], {"id": "poor_visibility"}, 424242)
		var b: Dictionary = _gen.generate_terrain_suggestions(
			theme, ["overgrown"], {"id": "poor_visibility"}, 424242)
		assert_str(_sectors_fingerprint(a)) \
			.is_equal(_sectors_fingerprint(b))
		assert_str(str(a.get("summary", ""))) \
			.is_equal(str(b.get("summary", "")))
		assert_int(int(a.get("seed", 0))).is_equal(int(b.get("seed", 0)))


func test_different_seeds_differ() -> void:
	var a: Dictionary = _gen.generate_terrain_suggestions(
		"wilderness", [], {}, 111)
	var b: Dictionary = _gen.generate_terrain_suggestions(
		"wilderness", [], {}, 222)
	assert_bool(_sectors_fingerprint(a) == _sectors_fingerprint(b)).is_false()


func test_world_trait_mods_deterministic_under_seed() -> void:
	var a: Dictionary = _gen.generate_terrain_suggestions(
		"crash_site", ["crystals", "warzone"], {}, 987)
	var b: Dictionary = _gen.generate_terrain_suggestions(
		"crash_site", ["crystals", "warzone"], {}, 987)
	assert_str(_sectors_fingerprint(a)).is_equal(_sectors_fingerprint(b))


func test_regenerate_sector_deterministic_with_seed_override() -> void:
	var a: Dictionary = _gen.regenerate_sector("wilderness", "B3", 5150)
	var b: Dictionary = _gen.regenerate_sector("wilderness", "B3", 5150)
	assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))
	assert_str(str(a.get("label", ""))).is_equal("B3")
	assert_bool(a.get("features", []).is_empty()).is_false()
	# A different derived seed re-rolls differently (over a few tries —
	# a single D6 can legitimately repeat).
	var differs := false
	for alt_seed in [1, 2, 3, 4, 5, 6, 7, 8]:
		var c: Dictionary = _gen.regenerate_sector("wilderness", "B3", alt_seed)
		if JSON.stringify(c) != JSON.stringify(a):
			differs = true
			break
	assert_bool(differs).is_true()


func test_regenerate_sector_unknown_theme_is_empty() -> void:
	assert_bool(_gen.regenerate_sector("moonbase", "A1", 1).is_empty()) \
		.is_true()


func test_derived_reroll_seed_formula_is_stable() -> void:
	# The UI derives per-sector re-roll seeds as
	# hash("base|label|count") — pin that hashing is stable and distinct
	# per label/count so re-rolls are reproducible after reload.
	var s1: int = hash("%d|%s|%d" % [123, "B3", 1])
	var s2: int = hash("%d|%s|%d" % [123, "B3", 1])
	var s3: int = hash("%d|%s|%d" % [123, "B3", 2])
	var s4: int = hash("%d|%s|%d" % [123, "C1", 1])
	assert_int(s1).is_equal(s2)
	assert_bool(s1 == s3).is_false()
	assert_bool(s1 == s4).is_false()
