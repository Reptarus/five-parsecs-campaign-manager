extends GdUnitTestSuite
## Pins the terrain data files to the book:
## - compendium_terrain.json carries EXACTLY the 4 Compendium themes
##   (pp.96-98) with 6+6 D6 entries each (the 3 synthesized themes were
##   removed 2026-07-02 — do not re-add).
## - Each D6 entry shares vocabulary with the book-truth extraction in
##   data/RulesReference/TerrainTables.json (condensed forms — strict
##   equality is impossible, token overlap is the pin).
## - standard_terrain_set carries the PDF-verified per-size counts (p.109).
## - The planet->theme heuristic only ever emits the 4 book themes.

const GeneratorClass = preload("res://src/core/battle/BattlefieldGenerator.gd")

const RUNTIME_PATH := "res://data/battlefield/themes/compendium_terrain.json"
const BOOK_PATH := "res://data/RulesReference/TerrainTables.json"

const THEME_KEY_MAP := {
	"industrial_zone": "industrial",
	"wilderness": "wilderness",
	"alien_ruin": "alien_ruin",
	"crash_site": "crash_site",
}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_that(file).is_not_null()
	var data: Variant = JSON.parse_string(file.get_as_text())
	assert_bool(data is Dictionary).is_true()
	return data


func test_runtime_json_has_exactly_the_4_book_themes() -> void:
	var data: Dictionary = _load_json(RUNTIME_PATH)
	var themes: Dictionary = data.get("themes", {})
	assert_int(themes.size()).is_equal(4)
	for key in THEME_KEY_MAP:
		assert_bool(themes.has(key)).is_true()
		var t: Dictionary = themes[key]
		assert_int(t.get("notable_features_d6", []).size()).is_equal(6)
		assert_int(t.get("regular_features_d6", []).size()).is_equal(6)


func test_standard_terrain_set_matches_p109() -> void:
	var data: Dictionary = _load_json(RUNTIME_PATH)
	var by_size: Dictionary = data.get(
		"standard_terrain_set", {}).get("by_table_size", {})
	# PDF-verified 2026-07-02 (Core Rules p.109). Compared per-key with
	# int() casts — JSON numbers parse as floats.
	var expected := {
		"2x2": [2, 4, 2],
		"2.5x2.5": [2, 5, 4],
		"3x3": [3, 6, 3],
	}
	for size_key: String in expected:
		var row: Dictionary = by_size.get(size_key, {})
		assert_int(int(row.get("large", 0))).is_equal(expected[size_key][0])
		assert_int(int(row.get("small", 0))).is_equal(expected[size_key][1])
		assert_int(int(row.get("linear", 0))).is_equal(expected[size_key][2])
	var minimums: Dictionary = data.get(
		"standard_terrain_set", {}).get("minimums", {})
	assert_int(int(minimums.get("climbable", 0))).is_equal(2)
	assert_int(int(minimums.get("elevated", 0))).is_equal(1)
	assert_int(int(minimums.get("enterable", 0))).is_equal(1)


func test_book_extraction_structure_guard() -> void:
	# Guards the TerrainTables.json structure against hand-edit mangling
	var data: Dictionary = _load_json(BOOK_PATH)
	var tables: Dictionary = data.get("terrain_tables", {})
	assert_int(tables.get("terrain_types", []).size()).is_equal(6)
	var generation: Dictionary = tables.get("terrain_generation", {})
	for book_key in ["industrial", "wilderness", "alien_ruin", "crash_site"]:
		assert_bool(generation.has(book_key)).is_true()
	var effects: Dictionary = tables.get("terrain_effects", {})
	for eff_key in ["line_of_sight", "cover", "movement"]:
		assert_bool(effects.has(eff_key)).is_true()


func _significant_tokens(text: String) -> Array:
	var tokens: Array = []
	var cleaned: String = text.to_lower()
	for ch in ["(", ")", ",", ".", ":", ";", "\"", "-", "/"]:
		cleaned = cleaned.replace(ch, " ")
	for word in cleaned.split(" ", false):
		if word.length() > 4:
			tokens.append(word)
	return tokens


func test_d6_entries_share_vocabulary_with_book_extraction() -> void:
	var runtime: Dictionary = _load_json(RUNTIME_PATH).get("themes", {})
	var book: Dictionary = _load_json(BOOK_PATH).get(
		"terrain_tables", {}).get("terrain_generation", {})
	for runtime_key in THEME_KEY_MAP:
		var book_theme: Dictionary = book.get(THEME_KEY_MAP[runtime_key], {})
		var pairs := [
			["notable_features_d6", "notable_features"],
			["regular_features_d6", "regular_features"],
		]
		for pair in pairs:
			var runtime_rows: Array = runtime[runtime_key].get(pair[0], [])
			var book_rows: Array = book_theme.get(pair[1], [])
			assert_int(runtime_rows.size()).is_equal(6)
			assert_int(book_rows.size()).is_equal(6)
			for i in range(6):
				var rt: Array = _significant_tokens(str(runtime_rows[i]))
				var bt: Array = _significant_tokens(str(book_rows[i]))
				var overlap := false
				for token in rt:
					if bt.has(token):
						overlap = true
						break
				if not overlap:
					fail("No shared vocabulary: %s %s roll %d\n  runtime: %s\n  book: %s"
						% [runtime_key, pair[0], i + 1,
							str(runtime_rows[i]), str(book_rows[i])])


func test_planet_type_remap_totality() -> void:
	var valid := ["industrial_zone", "wilderness", "alien_ruin", "crash_site"]
	for planet_type in range(0, 8):
		var theme: String = GeneratorClass.planet_type_to_theme(planet_type)
		assert_bool(valid.has(theme)).is_true()
	# Name-map aliases for the removed synthesized themes route to book themes
	for alias in ["Urban Settlement", "wasteland", "Ship Interior",
			"corridor", "city", "blasted"]:
		assert_bool(valid.has(GeneratorClass.map_theme_name_to_key(alias))) \
			.is_true()
