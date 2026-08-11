extends GdUnitTestSuite
## T9-05 (Aug 9 2026): difficulty names shown to a player must be the BOOK's names.
##
## data/RulesReference/DifficultyOptions.json (_source: "Core Rules pp.64-65") lists
## exactly five modes: Easy / Normal / Challenging / Hardcore / Insanity.
##
## Four separate maps existed and none matched. The dashboard rendered "Story",
## "Standard" and "Nightmare" — a player cross-referencing their rulebook finds none of
## them — and "Nightmare" is one of the DEPRECATED fabricated enum labels CLAUDE.md
## says never to expose in UI. FinalPanel was worse than mis-named: it matched a
## contiguous 1..5 scale, but the enum interleaves the three deprecated members at
## HARD=3 / NIGHTMARE=5 / ELITE=7, so it reported Challenging(4) as "Hardcore" and both
## HARDCORE(6) and INSANITY(8) as "Standard" — on the final review screen.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const BOOK_NAMES := ["Easy", "Normal", "Challenging", "Hardcore", "Insanity"]


func test_every_real_mode_gets_its_book_name() -> void:
	var expected := {
		GlobalEnums.DifficultyLevel.EASY: "Easy",
		GlobalEnums.DifficultyLevel.NORMAL: "Normal",
		GlobalEnums.DifficultyLevel.CHALLENGING: "Challenging",
		GlobalEnums.DifficultyLevel.HARDCORE: "Hardcore",
		GlobalEnums.DifficultyLevel.INSANITY: "Insanity",
	}
	for level: int in expected:
		assert_str(DifficultyModifiers.get_display_name(level)).override_failure_message(
			"difficulty %d rendered as '%s', book says '%s' (DifficultyOptions.json)" % [
				level, DifficultyModifiers.get_display_name(level), expected[level]]
		).is_equal(expected[level])


func test_the_non_contiguous_enum_does_not_shift_the_names() -> void:
	# DETECTION-CRITICAL, and the actual bug. Anything that matches difficulty on a
	# 1..5 range passes the first two and fails from CHALLENGING on, because the
	# deprecated members sit at 3, 5 and 7.
	assert_int(int(GlobalEnums.DifficultyLevel.CHALLENGING)).is_equal(4)
	assert_int(int(GlobalEnums.DifficultyLevel.HARDCORE)).is_equal(6)
	assert_int(int(GlobalEnums.DifficultyLevel.INSANITY)).is_equal(8)
	assert_str(DifficultyModifiers.get_display_name(4)).is_equal("Challenging")
	assert_str(DifficultyModifiers.get_display_name(6)).is_equal("Hardcore")
	assert_str(DifficultyModifiers.get_display_name(8)).is_equal("Insanity")


func test_no_deprecated_or_invented_label_can_reach_the_player() -> void:
	# HARD / NIGHTMARE / ELITE are save-compat aliases, not modes. Whatever a save
	# holds, the name shown must be one of the five the book defines.
	for level in range(0, 12):
		var shown: String = DifficultyModifiers.get_display_name(level)
		assert_bool(shown in BOOK_NAMES).override_failure_message(
			"difficulty %d rendered as '%s', which is not a Core Rules difficulty. " % [
				level, shown] + "Allowed: %s" % str(BOOK_NAMES)).is_true()


func test_the_names_match_the_rules_reference_file_verbatim() -> void:
	# Guards against the book data and the code drifting apart later. The JSON is the
	# extraction of Core Rules pp.64-65 and is the higher authority of the two.
	var f := FileAccess.open("res://data/RulesReference/DifficultyOptions.json", FileAccess.READ)
	assert_that(f).override_failure_message("DifficultyOptions.json missing").is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	var modes: Array = parsed.get("DifficultyModes", {}).get("modes", [])
	var from_book: Array = []
	for m: Dictionary in modes:
		from_book.append(str(m.get("name", "")))
	assert_array(from_book).override_failure_message(
		"the book file lists %s but the code speaks %s" % [str(from_book), str(BOOK_NAMES)]
	).is_equal(BOOK_NAMES)
