extends GdUnitTestSuite
## Pins the 2026-06-02 STRICT biome removal: planet_types.json was deleted and WorldGenerator no
## longer has a biome "planet type". The world "type"/"type_name" is now a cosmetic label DERIVED
## from the trait-based world (Core Rules "World Traits Table") via _derive_world_type_label().
## (Supersedes the 2026-06-01 fix that replaced the fabricated biome D100 table with a uniform
## pick; the biome concept is now gone entirely. The biome never drove mechanics: trade-demand /
## world-event matches keyed on it were dead, and name/danger/locations used only fallbacks.)

const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")

var wg


func before_test() -> void:
	wg = WorldGenerator.new()  # _init() loads location_types + world_traits (no planet_types)


func after_test() -> void:
	wg.free()


func test_world_type_label_is_trait_derived() -> void:
	# type/type_name are derived from the world's first trait (no fabricated biome). When the
	# world has traits, the type id must equal the first trait id.
	for i in range(40):
		var wd: Dictionary = wg.generate_world(1)
		var traits: Array = wd.get("traits", [])
		var type_id := str(wd.get("type", ""))
		var type_name := str(wd.get("type_name", ""))
		assert_str(type_name).is_not_empty()
		if traits.is_empty():
			assert_str(type_id).is_equal("standard")
		else:
			assert_str(type_id).is_equal(str(traits[0]))


func test_world_type_varies() -> void:
	# Trait-derived label varies across worlds (regression vs the old always-"Desert World" bug).
	var seen := {}
	for i in range(80):
		seen[str(wg.generate_world(1).get("type_name", ""))] = true
	assert_int(seen.size()).is_greater(1)


func test_no_dead_biome_accessors() -> void:
	# planet_types.json + the dead biome accessors were removed 2026-06-02.
	assert_bool(wg.has_method("get_planet_types")).is_false()
	assert_bool(wg.has_method("set_specific_planet_type")).is_false()


func test_world_has_book_faithful_fields() -> void:
	var wd: Dictionary = wg.generate_world(3)
	# Trait-based world gen (Core Rules) + cosmetic type label, danger, locations.
	assert_bool(wd.has("traits")).is_true()
	assert_bool(wd.has("danger_level")).is_true()
	assert_bool(wd.has("type_name")).is_true()
	assert_str(str(wd.get("type_name", ""))).is_not_empty()
	assert_int(int(wd.get("danger_level", 0))).is_greater_equal(1)
