extends GdUnitTestSuite
## BugReportStore is the durability guarantee: a report is written to disk
## BEFORE any attempt is made to send it, so a failed mail handoff or a killed
## app can never lose what the tester typed.
##
## The atomic write (.tmp then rename) is the part worth pinning — a rename over
## an unflushed buffer would publish a truncated file, which defeats the point.
##
## gdUnit4 v6.0.3 compatible.

const StoreClass = preload("res://src/core/support/BugReportStore.gd")

var _created: Array[String] = []


func after_test() -> void:
	# Never leave test reports behind for the real widget to list.
	for path in _created:
		StoreClass.delete(path)
	_created.clear()


func _sample(what: String = "The dice roller returned 7 on a D6.") -> Dictionary:
	return {
		"category": "Wrong rule or number",
		"what_happened": what,
		"steps": "1. Open the battle\n2. Roll for seize",
		"reporter_contact": "tester@example.com",
		"context": {"app_version": "0.9.7-dev", "platform": "Windows",
			"current_scene": "campaign_dashboard", "phase": "BATTLE",
			"turn_cpm": 4, "build_type": "debug"},
		"log_tail": PackedStringArray(["line one", "line two"]),
	}


func _save(report: Dictionary) -> String:
	var path: String = StoreClass.save(report)
	if not path.is_empty():
		_created.append(path)
	return path


# --- Round trip --------------------------------------------------------------

func test_save_returns_a_path_and_creates_the_file() -> void:
	var path := _save(_sample())
	assert_str(path).is_not_equal("")
	assert_bool(FileAccess.file_exists(path)).is_true()


func test_saved_report_round_trips_intact() -> void:
	var path := _save(_sample("Specific text to match on."))
	var loaded: Dictionary = StoreClass.load_report(path)
	assert_str(str(loaded.get("what_happened"))).is_equal("Specific text to match on.")
	assert_str(str(loaded.get("category"))).is_equal("Wrong rule or number")
	assert_object(loaded.get("context")).is_not_null()


func test_no_tmp_file_survives_a_successful_save() -> void:
	# The .tmp is an implementation detail of the atomic write; if one is left
	# behind, the rename failed and the report is not actually committed.
	var path := _save(_sample())
	assert_bool(path.ends_with(".tmp")).is_false()
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()


func test_saved_report_appears_in_list_pending() -> void:
	var path := _save(_sample())
	var pending: Array[String] = StoreClass.list_pending()
	assert_bool(pending.has(path)).is_true()


func test_delete_removes_the_file_and_the_listing() -> void:
	var path := _save(_sample())
	assert_bool(StoreClass.delete(path)).is_true()
	assert_bool(FileAccess.file_exists(path)).is_false()
	assert_bool(StoreClass.list_pending().has(path)).is_false()
	_created.erase(path)


func test_two_saves_do_not_collide() -> void:
	var a := _save(_sample("first"))
	var b := _save(_sample("second"))
	assert_str(a).is_not_equal(b)
	assert_str(str(StoreClass.load_report(a).get("what_happened"))).is_equal("first")
	assert_str(str(StoreClass.load_report(b).get("what_happened"))).is_equal("second")


func test_load_report_returns_empty_for_a_missing_path() -> void:
	var loaded: Dictionary = StoreClass.load_report("user://bug_reports/does_not_exist.json")
	assert_bool(loaded.is_empty()).is_true()


# --- Formatting --------------------------------------------------------------

func test_format_as_text_carries_the_answers_and_the_context() -> void:
	var text: String = StoreClass.format_as_text(_sample("Roller broke."))
	assert_bool(text.contains("Roller broke.")).is_true()
	assert_bool(text.contains("Wrong rule or number")).is_true()
	assert_bool(text.contains("tester@example.com")).is_true()
	assert_bool(text.contains("app_version: 0.9.7-dev")).is_true()
	assert_bool(text.contains("line one")).is_true()


func test_format_as_text_omits_empty_optional_sections() -> void:
	var report := _sample()
	report["steps"] = ""
	report["log_tail"] = PackedStringArray()
	var text: String = StoreClass.format_as_text(report)
	assert_bool(text.contains("STEPS TO REPRODUCE")).is_false()
	assert_bool(text.contains("LOG TAIL")).is_false()


func test_email_body_is_a_summary_not_the_whole_report() -> void:
	# mailto: URIs are length-capped by the OS and by mail clients, so the body
	# must stay short and point at the clipboard for the full text.
	var report := _sample()
	var body: String = StoreClass.format_email_body(report, "user://bug_reports/x.json")
	assert_bool(body.contains("PASTE THE FULL REPORT BELOW")).is_true()
	assert_bool(body.contains("user://bug_reports/x.json")).is_true()
	# The log must NOT be inlined into the URI.
	assert_bool(body.contains("line one")).is_false()
	assert_int(body.length()).is_less(1500)


func test_email_body_truncates_a_long_description() -> void:
	var report := _sample("x".repeat(5000))
	var body: String = StoreClass.format_email_body(report, "p")
	assert_int(body.length()).is_less(1500)
	assert_bool(body.contains("...")).is_true()


func test_format_context_handles_a_non_dictionary() -> void:
	assert_str(StoreClass.format_context("not a dict")).is_equal("(none)")
	assert_str(StoreClass.format_context({})).is_equal("(none)")
