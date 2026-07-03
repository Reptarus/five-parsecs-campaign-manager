extends GdUnitTestSuite
## Compendium 5-step terrain generation (pp.94-95) + rules-audit pins.
## F1: the "second open ground becomes a hill" rule is INDUSTRIAL-ONLY
## (p.97). F2: toxic_environment is a Stun rule, NOT terrain (p.88).
## Minimums are p.109 guidelines and injections are labeled as suggestions.

const GeneratorClass = preload("res://src/core/battle/BattlefieldGenerator.gd")

const BOOK_THEMES: Array[String] = [
	"industrial_zone", "wilderness", "alien_ruin", "crash_site"]
const CENTER_SECTORS: Array[String] = ["B2", "B3", "C2", "C3"]

var _gen: RefCounted


func before_test() -> void:
	_gen = GeneratorClass.new()


func _all_features(result: Dictionary) -> Array:
	var out: Array = []
	for sector: Dictionary in result.get("sectors", []):
		for feat in sector.get("features", []):
			out.append(str(feat))
	return out


func test_five_step_structure() -> void:
	var result: Dictionary = _gen.generate_terrain_suggestions(
		"wilderness", [], {}, 12345)
	var sectors: Array = result.get("sectors", [])
	assert_int(sectors.size()).is_equal(16)
	# Labels are the full A1-D4 grid
	var labels: Array = []
	for s: Dictionary in sectors:
		labels.append(str(s.get("label", "")))
	for row_c in ["A", "B", "C", "D"]:
		for col_c in ["1", "2", "3", "4"]:
			assert_bool(labels.has(row_c + col_c)).is_true()
	# Exactly ONE notable (LARGE:) feature — the Compendium Step 2 center
	# roll (regular tables carry no LARGE entries) — in a center sector.
	var large_count: int = 0
	for s: Dictionary in sectors:
		for feat in s.get("features", []):
			if str(feat).begins_with("LARGE:"):
				large_count += 1
				assert_bool(CENTER_SECTORS.has(str(s.get("label", "")))) \
					.is_true()
	assert_int(large_count).is_equal(1)
	assert_int(int(result.get("seed", 0))).is_equal(12345)
	assert_bool(result.has("terrain_set")).is_true()
	assert_str(str(result.get("summary", ""))).contains("Table size")
	assert_float(float(result.get("table_size_ft", 0.0))) \
		.is_equal_approx(3.0, 0.001)


func test_unknown_theme_returns_error() -> void:
	var result: Dictionary = _gen.generate_terrain_suggestions("moonbase")
	assert_bool(result.has("error")).is_true()


func test_minimums_guidelines_hold_across_seeds() -> void:
	# Core Rules p.109: >=2 climbable, >=1 elevated, >=1 enterable
	var elevated_kw := ["hill", "elevated", "platform", "ridge", "high ground"]
	var enterable_kw := ["forest", "rubble", "cluster", "bushes", "enter", "swamp"]
	var climbable_kw := ["building", "structure", "outcrop", "climb", "tower",
		"hab-block"]
	for theme in BOOK_THEMES:
		for seed_val in [11, 222, 3333]:
			var result: Dictionary = _gen.generate_terrain_suggestions(
				theme, [], {}, seed_val)
			var elevated := 0
			var enterable := 0
			var climbable := 0
			for feat in _all_features(result):
				var lower: String = feat.to_lower()
				for kw in elevated_kw:
					if kw in lower:
						elevated += 1
						break
				for kw in enterable_kw:
					if kw in lower:
						enterable += 1
						break
				for kw in climbable_kw:
					if kw in lower:
						climbable += 1
						break
			assert_bool(elevated >= 1).is_true()
			assert_bool(enterable >= 1).is_true()
			assert_bool(climbable >= 2).is_true()


func test_injected_minimums_are_labeled_as_suggestions() -> void:
	# F7: app assistance must be distinguishable from table rolls
	for seed_val in range(1, 15):
		var result: Dictionary = _gen.generate_terrain_suggestions(
			"crash_site", [], {}, seed_val)
		for feat in _all_features(result):
			if "Climbable structure or rocky outcrop" in feat \
					or "Enterable rubble cluster" in feat:
				assert_str(feat).contains("suggested — Core Rules p.109")


func test_f1_hill_rule_is_industrial_only() -> void:
	# The bare hill conversion string (no "(suggested" suffix) must never
	# appear for non-industrial themes (Compendium p.97).
	for theme in ["wilderness", "alien_ruin", "crash_site"]:
		for seed_val in range(1, 40):
			var result: Dictionary = _gen.generate_terrain_suggestions(
				theme, [], {}, seed_val)
			for feat in _all_features(result):
				if feat.begins_with("SMALL: Hill or elevated ground") \
						and not ("suggested" in feat):
					fail("Hill conversion fired for theme %s (seed %d)"
						% [theme, seed_val])
	# ...and it DOES fire for industrial_zone on some seed.
	var fired: bool = false
	for seed_val in range(1, 60):
		var result: Dictionary = _gen.generate_terrain_suggestions(
			"industrial_zone", [], {}, seed_val)
		for feat in _all_features(result):
			if feat.begins_with("SMALL: Hill or elevated ground") \
					and not ("suggested" in feat):
				fired = true
				break
		if fired:
			break
	assert_bool(fired).is_true()


func test_f2_toxic_environment_is_a_note_not_terrain() -> void:
	var result: Dictionary = _gen.generate_terrain_suggestions(
		"wilderness", [], {"id": "toxic_environment"}, 777)
	for feat in _all_features(result):
		assert_bool(feat.begins_with("HAZARD: Toxic")).is_false()
	var notes: Array = result.get("combat_notes", [])
	var found := false
	for note in notes:
		if "Toxic environment" in str(note):
			found = true
			assert_str(str(note)).contains("p.88")
	assert_bool(found).is_true()


func test_condition_id_uppercase_key_is_accepted() -> void:
	# The campaign flow emits {condition_id: "TOXIC_ENVIRONMENT"} — the
	# C-phase fix accepts both key spellings case-insensitively.
	var result: Dictionary = _gen.generate_terrain_suggestions(
		"wilderness", [], {"condition_id": "TOXIC_ENVIRONMENT"}, 777)
	var found := false
	for note in result.get("combat_notes", []):
		if "Toxic environment" in str(note):
			found = true
	assert_bool(found).is_true()


func test_flat_trait_strips_elevation() -> void:
	var elevation_kw := ["hill", "elevated", "ridge", "high ground", "mound",
		"hilltop"]
	for seed_val in [5, 55, 555]:
		var result: Dictionary = _gen.generate_terrain_suggestions(
			"wilderness", ["flat"], {}, seed_val)
		for feat in _all_features(result):
			var lower: String = feat.to_lower()
			for kw in elevation_kw:
				assert_bool(kw in lower).is_false()


func test_barren_trait_strips_vegetation() -> void:
	var vegetation_kw := ["tree", "bush", "grass", "vegetation", "vine",
		"growth", "plant", "mushroom", "flower", "spore", "fungal"]
	for seed_val in [7, 77, 777]:
		var result: Dictionary = _gen.generate_terrain_suggestions(
			"wilderness", ["barren"], {}, seed_val)
		for feat in _all_features(result):
			var lower: String = feat.to_lower()
			for kw in vegetation_kw:
				assert_bool(kw in lower).is_false()


func test_crystals_trait_adds_2d6_crystals() -> void:
	for seed_val in [9, 99, 999]:
		var result: Dictionary = _gen.generate_terrain_suggestions(
			"crash_site", ["crystals"], {}, seed_val)
		var count := 0
		for feat in _all_features(result):
			if "Crystal formation (world trait" in feat:
				count += 1
		assert_bool(count >= 2 and count <= 12).is_true()
