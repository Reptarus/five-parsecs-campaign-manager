extends GdUnitTestSuite
## Pins the 2026-06-01 WorldGenerator fix: the fabricated/broken biome D100-range table
## (which always returned the first entry, "Desert World") was replaced with an honest
## uniform pick on the JSON's real id/name schema. World generation remains trait-based
## (Core Rules), with the world "type"/"type_name" kept only as cosmetic display flavor.

const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")

var wg


func before_test() -> void:
	wg = WorldGenerator.new()  # _init() loads planet_types/location_types/world_traits


func after_test() -> void:
	wg.free()


func test_world_type_varies_not_always_desert() -> void:
	# Regression: the broken D100 match always returned "_planet_types[0]" (Desert World).
	var seen := {}
	for i in range(80):
		var wd: Dictionary = wg.generate_world(1)
		var tn := str(wd.get("type_name", ""))
		assert_str(tn).is_not_empty()
		seen[tn] = true
	# Uniform pick across the flavor entries must yield more than one distinct type.
	assert_int(seen.size()).is_greater(1)


func test_world_has_book_faithful_fields() -> void:
	var wd: Dictionary = wg.generate_world(3)
	# Trait-based world gen (Core Rules) + cosmetic type label, danger, locations.
	assert_bool(wd.has("traits")).is_true()
	assert_bool(wd.has("danger_level")).is_true()
	assert_bool(wd.has("type_name")).is_true()
	assert_str(str(wd.get("type_name", ""))).is_not_empty()
	assert_int(int(wd.get("danger_level", 0))).is_greater_equal(1)
