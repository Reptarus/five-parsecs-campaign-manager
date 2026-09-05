extends GdUnitTestSuite
## The window-state persistence rule (found 2026-09-04 by the layout sweep).
##
## `user://window.ini` on the dev machine held `mode=1` — Window.MODE_MINIMIZED.
## Both restore sites applied it verbatim behind a `mode >= 0` check, so the app
## LAUNCHED MINIMIZED and re-minimised itself whenever the Settings screen was
## opened. A minimized window also ignores DisplayServer.window_set_size(), which
## is why `verify_layout.gd` silently measured one geometry six times.
##
## These cases pin the RULE, not the three call sites, because the rule is what
## must not drift. gdUnit4 v6.0.3; run with -c, never --headless (project rule).

const Rules = preload("res://src/core/state/WindowStateRules.gd")


func test_minimized_is_never_restored() -> void:
	# DETECTION-CRITICAL. This single assertion is the whole defect.
	assert_bool(Rules.may_restore_mode(Window.MODE_MINIMIZED)).is_false()


func test_minimized_is_never_persisted() -> void:
	# Guarding only the read would leave every existing window.ini poisoned; the
	# write site has to stop recording the transient state as well.
	assert_int(Rules.mode_to_persist(Window.MODE_MINIMIZED)) \
		.is_equal(Window.MODE_WINDOWED)


func test_the_real_preferences_still_round_trip() -> void:
	# A guard that rejected everything would "fix" the bug and silently discard
	# the user's actual window preference, which is what BUG-100 existed to
	# restore. Each of these must survive both directions.
	for mode: int in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED,
			Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		assert_bool(Rules.may_restore_mode(mode)).override_failure_message(
			"mode %d must still be restorable" % mode).is_true()
		assert_int(Rules.mode_to_persist(mode)).override_failure_message(
			"mode %d must round-trip unchanged" % mode).is_equal(mode)


func test_the_absent_sentinel_is_rejected() -> void:
	# Both callers read the key with a -1 default meaning "not recorded". The old
	# code screened that out with `mode >= 0`; the rule has to keep doing so now
	# that the comparison lives here.
	assert_bool(Rules.may_restore_mode(-1)).is_false()


func test_an_unknown_mode_degrades_to_windowed() -> void:
	# A future engine mode, or a corrupted file, must not be applied blind.
	assert_bool(Rules.may_restore_mode(99)).is_false()
	assert_int(Rules.mode_to_persist(99)).is_equal(Window.MODE_WINDOWED)
