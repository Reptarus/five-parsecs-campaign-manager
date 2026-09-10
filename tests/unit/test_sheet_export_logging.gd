extends GdUnitTestSuite
## The sheet export must leave a trace, and its size probe must never lie.
##
## WHY THIS EXISTS. Until 2026-09-09 `PrintSheetScreen` contained **zero** logging:
## every outcome went to `_set_status()`, an on-screen label that dies with the
## screen. Three states were therefore indistinguishable after the fact — ran and
## failed, ran and succeeded, and never ran because the native SAF dialog was still
## waiting for a tap. The third is the common one, and it is what made a working
## export read as a broken one during the deploy #32 renderer smoke test.
##
## `BugReportContext` attaches `user://logs/godot.log` to every bug report, so the
## logging is deliberately NOT debug-gated: "I pressed export and nothing happened"
## is precisely the report it has to answer, in a release build.
##
## ⚠ WHAT THIS SUITE PINS. The `print()` calls themselves are verified on device
## (deploy #33: REQUESTED / WRITING / SAVED / CANCELLED all observed in
## `godot.log`). What is pinned HERE is `_written_size_note()`, because it is the
## piece with real branching and the piece most likely to be "simplified" into
## something that lies.

const ScreenScript = preload("res://src/ui/screens/print/PrintSheetScreen.gd")

var _screen


func before_test() -> void:
	_screen = ScreenScript.new()
	auto_free(_screen)


func test_a_content_uri_reports_unavailable_not_zero() -> void:
	# THE CASE THAT MATTERS. Android's SAF hands back a content:// URI, which
	# FileAccess cannot stat. Reporting "0 bytes" there would read as "the export
	# produced nothing" — inventing a failure out of an unmeasurable success, which
	# is worse than not measuring at all. Same shape as the .gdc string-grep that
	# returned ABSENT for strings that were definitely present: a probe that cannot
	# tell "I could not measure" from "there is nothing there" is worse than none.
	var note: String = _screen._written_size_note(
		"content://com.android.externalstorage.documents/document/primary%3Acrew_log.pdf")
	assert_str(note).override_failure_message(
		"a content:// URI must report UNAVAILABLE, never a byte count: got '%s'" % note
		).contains("unavailable")
	assert_str(note).override_failure_message(
		"a content:// note must not claim a size of 0: got '%s'" % note
		).not_contains("size=0")


func test_a_missing_file_is_reported_as_a_real_zero() -> void:
	# The other half: when the path IS measurable and there is genuinely nothing
	# there, say so loudly. A writer that returned OK while producing no file is a
	# defect, and this is the line that would expose it.
	var note: String = _screen._written_size_note("user://__does_not_exist_%d.png" % randi())
	assert_str(note).contains("size=0")
	assert_str(note).override_failure_message(
		"a genuinely missing file must be called out, not reported blandly"
		).contains("NO FILE")


func test_a_real_file_reports_its_actual_length() -> void:
	var path := "user://__sheet_export_probe_%d.bin" % randi()
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_object(f).is_not_null()
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7]))
	f.close()

	var note: String = _screen._written_size_note(path)
	assert_str(note).override_failure_message(
		"a readable 7-byte file must report 7: got '%s'" % note).contains("size=7 bytes")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_sheet_id_survives_an_unbuilt_tab_bar() -> void:
	# _log_export runs on paths where the screen may not be fully built (the
	# renderer-null failure branch fires before anything is guaranteed). A logger
	# that crashes while reporting a failure destroys the evidence it exists for.
	assert_str(_screen._sheet_id_for_log()).override_failure_message(
		"the log helper must not depend on a built TabBar"
		).is_equal("unknown")
