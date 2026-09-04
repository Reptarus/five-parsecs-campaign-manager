extends GdUnitTestSuite
## Every `has_method()` guard on the NotificationManager autoload must name a
## method that actually EXISTS on it (Sep 3 2026).
##
## THE DEFECT THIS PINS. Five call sites guarded on `has_method("show_notification")`.
## `func show_notification` has ZERO definitions repo-wide, so all five were
## permanently-false branches — the CLAUDE.md trap, hit for the fourth time.
## Four of them were FAILURE paths that then said nothing at all to the player:
##
##   CampaignTurnController :1832  "Could not auto-resolve: no enemy force was
##                                  generated."
##   BugHuntDashboard       :333   "Muster out failed - the character is still in
##                                  your squad. Check device storage."
##   PlanetfallDashboard    :155   "Transfer failed - the colonist is still on
##                                  your roster."
##   TacticsDashboard       :268   "Transfer failed - the veteran is still on
##                                  your roster."
##
## The last three are the SAME error path on all three cross-mode dashboards: a
## transfer file that could not be written. The character is correctly kept
## rather than lost, but the player was never told the transfer failed, so the
## visible outcome was "I pressed muster out and nothing happened."
##
## SettingsScreen:771 was the odd one out — it had a working AcceptDialog
## fallback, so the user WAS told; the intended toast simply never appeared.
##
## The repo already knew: WorldPhaseAutomationController:569-570 carries the
## comment "No UI defines show_notification — route to the NotificationManager
## autoload (its real API is show_toast...)". That pass fixed one site and missed
## five. ⚠ `scripts/scan_dead_has_method_guards.py` reported only THREE of the
## five, so its site list is not exhaustive — grep the name yourself.
##
## gdUnit4 v6.0.3 compatible. Run with -c, never --headless (project rule).

const NOTIFICATION_MANAGER := "res://src/autoload/NotificationManager.gd"
const AUTOLOAD_PATH := "/root/NotificationManager"
const SRC_ROOT := "res://src"

## How many lines after the autoload lookup still count as "guarding it". The
## idiom is two lines (lookup, then `if x and x.has_method(...)`); 4 gives room
## for a wrapped condition without picking up an unrelated later guard.
const GUARD_WINDOW := 4


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func _all_scripts(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if d.current_is_dir():
				_all_scripts(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func _manager_methods() -> PackedStringArray:
	var names := PackedStringArray()
	var rx := RegEx.create_from_string("(?m)^func ([a-zA-Z_][a-zA-Z0-9_]*)")
	for m in rx.search_all(_read(NOTIFICATION_MANAGER)):
		names.append(m.get_string(1))
	return names


func test_the_autoload_exposes_the_methods_the_call_sites_use() -> void:
	# Sanity floor: if these ever vanish, the guards below all go dead again and
	# every failure message in the app goes silent at once.
	var methods := _manager_methods()
	for required: String in ["show_info", "show_success", "show_warning",
			"show_error", "show_toast"]:
		assert_bool(required in methods).override_failure_message(
			"NotificationManager lost %s(); call sites guard on it" % required
		).is_true()


func test_no_call_site_guards_on_the_nonexistent_show_notification() -> void:
	# The exact regression. `show_notification` is not, and never was, a method
	# on this autoload.
	var offenders: Array[String] = []
	var scripts: Array = []
	_all_scripts(SRC_ROOT, scripts)
	for path: String in scripts:
		var src: String = _read(path)
		if src.contains('has_method("show_notification")') \
				or src.contains(".show_notification("):
			offenders.append(path)
	assert_array(offenders).override_failure_message(
		"show_notification() does not exist on NotificationManager; use"
		+ " show_error / show_warning / show_info / show_success / show_toast."
		+ " Offenders: %s" % str(offenders)
	).is_empty()


func test_every_guard_on_the_notification_autoload_names_a_real_method() -> void:
	# The GENERAL invariant, so the next typo fails here rather than shipping as
	# a silent branch. Finds `x = get_node_or_null("/root/NotificationManager")`
	# and checks any `x.has_method("...")` in the following few lines.
	var methods := _manager_methods()
	var assign := RegEx.create_from_string(
		"var ([a-zA-Z_][a-zA-Z0-9_]*)[ :=].*" + AUTOLOAD_PATH)
	var offenders: Array[String] = []

	var scripts: Array = []
	_all_scripts(SRC_ROOT, scripts)
	for path: String in scripts:
		var lines: PackedStringArray = _read(path).split("\n")
		for i in range(lines.size()):
			var hit := assign.search(lines[i])
			if hit == null:
				continue
			var var_name: String = hit.get_string(1)
			var guard := RegEx.create_from_string(
				var_name + "[.]has_method[(]\"([a-zA-Z_][a-zA-Z0-9_]*)\"[)]")
			for j in range(i + 1, mini(i + 1 + GUARD_WINDOW, lines.size())):
				var g := guard.search(lines[j])
				if g == null:
					continue
				var called: String = g.get_string(1)
				if not (called in methods):
					offenders.append("%s:%d guards on %s(), which NotificationManager"
						% [path, j + 1, called] + " does not define")

	assert_array(offenders).override_failure_message(
		"permanently-false has_method guard(s) on NotificationManager: %s"
			% str(offenders)
	).is_empty()
