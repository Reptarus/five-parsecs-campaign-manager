extends GdUnitTestSuite
## BugReportDialog is the alpha's only structured feedback pipe, so the two
## things that must never regress are: it refuses to send an empty report
## (a blank submission is worse than none, it burns tester goodwill), and a
## real submission emits exactly once with the typed content intact.
##
## The dialog is a Window built entirely in code, so entering the tree is what
## builds the UI — same as test_battle_results_input_form.gd.
##
## gdUnit4 v6.0.3 compatible.

const DialogClass = preload("res://src/ui/components/common/BugReportDialog.gd")
const StoreClass = preload("res://src/core/support/BugReportStore.gd")

var _saved_paths: Array[String] = []


func after_test() -> void:
	for p in _saved_paths:
		StoreClass.delete(p)
	_saved_paths.clear()


func _make_dialog() -> Window:
	var dlg: Window = auto_free(DialogClass.new())
	# Explicit size: popup_centered() is bypassed here, and _ready()'s defensive
	# fallback is what keeps the form from collapsing to the Window minimum.
	dlg.size = Vector2i(600, 680)
	add_child(dlg)
	await get_tree().process_frame  # let _ready() build the UI
	return dlg


func _capture(dlg: Window) -> Array:
	var captured: Array = []
	dlg.report_submitted.connect(
		func(r: Dictionary, path: String) -> void:
			captured.append({"report": r, "path": path})
			if not path.is_empty():
				_saved_paths.append(path)
	)
	return captured


# --- It builds ---------------------------------------------------------------

func test_dialog_builds_its_form_controls() -> void:
	var dlg: Window = await _make_dialog()
	assert_object(dlg._category_btn).is_not_null()
	assert_object(dlg._what_edit).is_not_null()
	assert_object(dlg._steps_edit).is_not_null()
	assert_object(dlg._send_btn).is_not_null()


func test_dialog_offers_every_category() -> void:
	var dlg: Window = await _make_dialog()
	assert_int(dlg._category_btn.item_count).is_equal(DialogClass.CATEGORIES.size())


func test_dialog_survives_the_process_mode_contract() -> void:
	# The settings overlay pauses the tree; without ALWAYS the dialog would be
	# inert exactly where a tester is most likely to open it.
	var dlg: Window = await _make_dialog()
	assert_int(dlg.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_dialog_does_not_collapse_to_the_window_minimum() -> void:
	var dlg: Window = await _make_dialog()
	assert_int(dlg.size.x).is_greater(200)
	assert_int(dlg.size.y).is_greater(200)


# --- It refuses an empty report ---------------------------------------------

func test_submit_is_refused_when_what_happened_is_blank() -> void:
	var dlg: Window = await _make_dialog()
	var captured := _capture(dlg)
	dlg._submit(false)
	assert_int(captured.size()).is_equal(0)


func test_submit_is_refused_for_whitespace_only() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "   \n\t  "
	var captured := _capture(dlg)
	dlg._submit(false)
	assert_int(captured.size()).is_equal(0)


func test_refusal_surfaces_a_visible_status_message() -> void:
	var dlg: Window = await _make_dialog()
	dlg._submit(false)
	assert_bool(dlg._status_label.visible).is_true()
	assert_str(dlg._status_label.text).is_not_equal("")


# --- A real submission --------------------------------------------------------

func test_submit_emits_once_with_the_typed_content() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "Enemy count was 9 when the table says 6."
	dlg._steps_edit.text = "1. Start a battle"
	dlg._category_btn.selected = 1  # "Wrong rule or number"
	var captured := _capture(dlg)

	dlg._submit(false)  # false = do not launch a mail client during tests

	assert_int(captured.size()).is_equal(1)
	var report: Dictionary = captured[0]["report"]
	assert_str(str(report["what_happened"])).is_equal("Enemy count was 9 when the table says 6.")
	assert_str(str(report["steps"])).is_equal("1. Start a battle")
	assert_str(str(report["category"])).is_equal(DialogClass.CATEGORIES[1])


func test_submit_attaches_context() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "Something broke."
	var captured := _capture(dlg)
	dlg._submit(false)
	var ctx: Variant = captured[0]["report"]["context"]
	assert_bool(ctx is Dictionary).is_true()
	assert_bool((ctx as Dictionary).has("app_version")).is_true()
	assert_bool((ctx as Dictionary).has("current_scene")).is_true()


func test_submit_writes_the_report_to_disk() -> void:
	# Durability is the whole point of saving before sending.
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "Persisted to disk."
	var captured := _capture(dlg)
	dlg._submit(false)
	var path: String = captured[0]["path"]
	assert_str(path).is_not_equal("")
	assert_bool(FileAccess.file_exists(path)).is_true()
	assert_str(str(StoreClass.load_report(path).get("what_happened"))).is_equal("Persisted to disk.")


func test_submit_locks_the_buttons_so_it_cannot_double_send() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "Once only."
	var captured := _capture(dlg)
	dlg._submit(false)
	assert_bool(dlg._send_btn.disabled).is_true()
	assert_bool(dlg._copy_btn.disabled).is_true()
	assert_int(captured.size()).is_equal(1)


func test_log_toggle_controls_whether_the_tail_is_attached() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "No log please."
	dlg._include_log_check.button_pressed = false
	var captured := _capture(dlg)
	dlg._submit(false)
	var tail: Variant = captured[0]["report"]["log_tail"]
	assert_int((tail as PackedStringArray).size()).is_equal(0)


# --- The mailto URI ----------------------------------------------------------
# Regression: the first version built "mailto:?subject=..." with NO recipient,
# so a tester would get a compose window with a blank To: field. It survived
# every other test because the only path that exercised it also opened a mail
# client, so it was always run with open_email=false.

func test_mailto_uri_addresses_the_support_inbox() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "Recipient check."
	var uri: String = dlg._build_mailto_uri(dlg._build_report(), "user://bug_reports/x.json")
	assert_bool(uri.begins_with("mailto:" + DialogClass.SUPPORT_EMAIL)).is_true()


func test_mailto_uri_carries_subject_and_body() -> void:
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "Subject and body check."
	var uri: String = dlg._build_mailto_uri(dlg._build_report(), "user://bug_reports/x.json")
	assert_bool(uri.contains("?subject=")).is_true()
	assert_bool(uri.contains("&body=")).is_true()
	# uri_encode() must have run — a raw space would break the URI.
	assert_bool(uri.split("?subject=")[1].contains(" ")).is_false()


func test_mailto_uri_stays_under_client_length_caps() -> void:
	# Mail clients and the OS cap mailto length. The full report goes via the
	# clipboard precisely so this stays short even with a big log attached.
	var dlg: Window = await _make_dialog()
	dlg._what_edit.text = "x".repeat(4000)
	var uri: String = dlg._build_mailto_uri(dlg._build_report(), "user://bug_reports/x.json")
	assert_int(uri.length()).is_less(2000)


func test_details_preview_is_hidden_until_toggled() -> void:
	# The tester must be able to see exactly what is being sent, but it should
	# not dominate the form by default.
	var dlg: Window = await _make_dialog()
	assert_bool(dlg._details_label.visible).is_false()
	dlg._details_toggle.button_pressed = true
	dlg._on_details_toggled(true)
	assert_bool(dlg._details_label.visible).is_true()
	assert_str(dlg._details_label.text).is_not_equal("")
