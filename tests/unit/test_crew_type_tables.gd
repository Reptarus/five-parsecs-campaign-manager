extends GdUnitTestSuite

## Core Rules p.14 "Crew Type Tables" — the Random Method (p.13).
##
## WHAT THIS PINS AND WHY IT MATTERS. The crew-type roll was
## `randi() % _origin_species_ids.size()`: a flat pick across the whole species
## dropdown. The book's roll is steeply weighted, so the flat version produced a
## crew that was roughly 69% Strange Characters where the book says 10%, and 3.8%
## Baseline Human where the book says 60%.
##
## Both live creation paths reach it (CaptainPanel:64, CrewPanel:236), and so
## does the p.78 recruit rule, whose own text is "Each recruit rolls using the
## random method in the character creation process (see p.14)".
##
## Book spans, verbatim from p.14:
##   Crew Type          1-60 Baseline Human | 61-80 Primary Alien
##                      81-90 Bot           | 91-100 Strange Character
##   Primary Alien      1-20 Engineer   21-40 KErin   41-55 Soulless
##                      56-70 Precursor 71-90 Feral   91-100 Swift
##   Strange Character  18 rows, 1-2 De-converted ... 94-100 Bio-upgrade

const Species = preload("res://src/core/character/SpeciesDataService.gd")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var s := f.get_as_text()
	f.close()
	return s


# ── the spans themselves ──────────────────────────────────────────────────

func test_the_crew_type_spans_are_the_book_spans() -> void:
	var expected := {
		1: "baseline_human", 60: "baseline_human",
		61: "primary_alien", 80: "primary_alien",
		81: "bot", 90: "bot",
		91: "strange_character", 100: "strange_character",
	}
	for roll in expected:
		var row: Dictionary = Species.crew_type_row_for("crew_type", roll)
		assert_str(str(row.get("category", ""))).override_failure_message(
			"p.14 crew type roll %d should be %s" % [roll, expected[roll]]
		).is_equal(expected[roll])


func test_the_primary_alien_subtable_is_the_book_subtable() -> void:
	var expected := {
		1: "engineer", 20: "engineer",
		21: "kerin", 40: "kerin",
		41: "soulless", 55: "soulless",
		56: "precursor", 70: "precursor",
		71: "feral", 90: "feral",
		91: "swift", 100: "swift",
	}
	for roll in expected:
		var row: Dictionary = Species.crew_type_row_for("primary_alien", roll)
		assert_str(str(row.get("species_id", ""))).override_failure_message(
			"p.14 Primary Alien roll %d should be %s" % [roll, expected[roll]]
		).is_equal(expected[roll])


func test_the_strange_character_subtable_has_all_eighteen_rows() -> void:
	# CLAUDE.md said "16 Strange Character types" for months. The book prints 18.
	var expected := {
		1: "de_converted", 2: "de_converted",
		3: "unity_agent", 8: "unity_agent",
		9: "mysterious_past", 17: "mysterious_past",
		18: "hakshan", 22: "hakshan",
		23: "stalker", 27: "stalker",
		28: "hulker", 34: "hulker",
		35: "hopeful_rookie", 41: "hopeful_rookie",
		42: "genetic_uplift", 47: "genetic_uplift",
		48: "mutant", 53: "mutant",
		54: "assault_bot", 58: "assault_bot",
		59: "manipulator", 62: "manipulator",
		63: "primitive_character", 67: "primitive_character",
		68: "feeler", 73: "feeler",
		74: "emo_suppressed", 79: "emo_suppressed",
		80: "minor_alien", 85: "minor_alien",
		86: "traveler", 87: "traveler",
		88: "empath", 93: "empath",
		94: "bio_upgrade", 100: "bio_upgrade",
	}
	for roll in expected:
		var row: Dictionary = Species.crew_type_row_for("strange_character", roll)
		assert_str(str(row.get("species_id", ""))).override_failure_message(
			"p.14 Strange Character roll %d should be %s" % [roll, expected[roll]]
		).is_equal(expected[roll])
	var seen := {}
	for roll in range(1, 101):
		seen[str(Species.crew_type_row_for("strange_character", roll).get("species_id", ""))] = true
	assert_int(seen.size()).override_failure_message(
		"the p.14 Strange Character subtable prints EIGHTEEN rows; %d are reachable"
		% seen.size()
	).is_equal(18)


func test_every_table_covers_1_to_100_with_no_gap() -> void:
	# A gap returns {} and the caller falls back to Human, which would look like
	# a working roll while quietly reweighting the table.
	for table_name in ["crew_type", "primary_alien", "strange_character"]:
		for roll in range(1, 101):
			var row: Dictionary = Species.crew_type_row_for(table_name, roll)
			assert_bool(row.is_empty()).override_failure_message(
				"%s has no row for a roll of %d" % [table_name, roll]
			).is_false()


# ── the distribution the player actually sees ─────────────────────────────

func test_the_roll_produces_the_book_distribution_not_a_flat_one() -> void:
	# The whole point. A flat pick over the ~26-entry dropdown gives Humans 3.8%
	# and Strange Characters 69%; the book gives 60% and 10%. This asserts the
	# gap between those two worlds, so it fails loudly if the flat pick returns.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var counts := {"baseline_human": 0, "primary_alien": 0, "bot": 0,
		"strange_character": 0}
	var n := 4000
	for _i in range(n):
		var r: Dictionary = Species.roll_crew_type(rng)
		var cat: String = str(r.get("category", ""))
		if counts.has(cat):
			counts[cat] += 1
	var human_pct: float = 100.0 * counts["baseline_human"] / n
	var strange_pct: float = 100.0 * counts["strange_character"] / n
	# Generous bands: the book values are 60 and 10, the flat-pick values 3.8
	# and 69. Anything inside these bands cannot be the flat pick.
	assert_bool(human_pct > 52.0 and human_pct < 68.0).override_failure_message(
		"Baseline Human came out at %.1f percent; p.14 says 60 (a flat pick gives 3.8)"
		% human_pct).is_true()
	assert_bool(strange_pct > 5.0 and strange_pct < 16.0).override_failure_message(
		"Strange Characters came out at %.1f percent; p.14 says 10 (a flat pick gives 69)"
		% strange_pct).is_true()
	assert_int(counts["bot"]).override_failure_message(
		"Bots never came up in %d rolls; p.14 gives them 81-90" % n).is_greater(0)
	assert_int(counts["primary_alien"]).is_greater(0)


func test_a_primary_alien_or_strange_roll_resolves_to_a_real_species() -> void:
	# p.14 Step 1: "If you roll Primary Alien or Strange Character, proceed to
	# the relevant subtable, and roll for the exact type." A category with no
	# species_id would leave the character speciesless.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for _i in range(300):
		var r: Dictionary = Species.roll_crew_type(rng)
		var sid: String = str(r.get("species_id", ""))
		assert_str(sid).override_failure_message(
			"a %s roll produced no species_id" % str(r.get("category", ""))
		).is_not_empty()
		assert_bool(Species.get_species(sid).is_empty()).override_failure_message(
			"rolled species_id '%s' does not exist in character_species.json" % sid
		).is_false()


# ── the wiring, which is the half that was actually missing ───────────────

func test_the_creator_rolls_the_table_instead_of_picking_flat() -> void:
	var src: String = _read(
		"res://src/core/character/Generation/CharacterCreator.gd")
	assert_str(src).override_failure_message(
		"CharacterCreator must roll the p.14 table for a randomised character"
	).contains("SpeciesDataService.roll_crew_type()")
	# ⚠ Strip comments before scanning for the OLD form. The replacement's own
	# docblock quotes `randi() % _origin_species_ids.size()` to explain what it
	# replaced, so a raw scan matches the explanation and fails with the fix in.
	# (Same trap as the Sep 3 knock-out test, which read its own docblock.)
	var code := ""
	for line in src.split("\n"):
		var stripped := (line as String).strip_edges()
		if stripped.begins_with("#"):
			continue
		code += line + "\n"
	assert_str(code).override_failure_message(
		"the flat pick over _origin_species_ids is back in executable code"
	).not_contains("randi() % _origin_species_ids.size()")


func test_the_tables_carry_their_provenance() -> void:
	# Sep 3 2026 lesson: EnemyAI.json was a faithful extraction of the WRONG
	# book. Every extraction now says which book it came from, and these spans
	# are especially easy to corrupt — dropping a DLC species in reweights every
	# other row silently.
	var raw: String = _read("res://data/character_species.json")
	assert_str(raw).contains("crew_type_tables")
	assert_str(raw).contains("Core Rules p.14")
	assert_str(raw).contains("_provenance_warning")
