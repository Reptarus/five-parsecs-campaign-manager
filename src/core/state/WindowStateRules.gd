class_name WindowStateRules
extends RefCounted
## SSOT for what may be persisted to, and restored from, `user://window.ini`.
##
## THE DEFECT THIS EXISTS FOR (measured 2026-09-04). `SettingsScreen._exit_tree()`
## wrote `win.mode` verbatim, and BOTH restore sites — `SettingsScreen._enter_tree()`
## and `GameState._restore_window_state_at_boot()` (BUG-100) — replayed it verbatim:
##
##     var mode = wc.get_value("main", "mode", -1)
##     if mode is int and mode >= 0:
##         win.mode = mode
##
## `Window.MODE_MINIMIZED` is 1, so it passed `>= 0` like any other mode. This
## machine's window.ini held exactly that, with the result that the app launched
## MINIMIZED and minimised itself again every time the Settings screen was opened.
##
## It also silently broke the layout harness: a minimized window IGNORES
## `DisplayServer.window_set_size()`, so `verify_layout.gd` measured a single
## geometry six times and reported 690 measurements at one design space. Proven by
## an isolated probe — resizing worked at baseline, after a campaign load, and
## after instantiating MainMenu, and stopped the instant `SettingsScreen.tscn` was
## instantiated, with `window_get_mode()` flipping 0 -> 1.
##
## MINIMIZED (and, for the same reason, any unknown value) is a TRANSIENT STATE,
## never a preference. The rule lives here so the write site and both read sites
## cannot drift, and so it is testable without a real window.

## Modes it is meaningful to remember between sessions.
const PERSISTABLE: Array[int] = [
	Window.MODE_WINDOWED,
	Window.MODE_MAXIMIZED,
	Window.MODE_FULLSCREEN,
	Window.MODE_EXCLUSIVE_FULLSCREEN,
]


## The mode to WRITE for a window currently in `mode`.
## Minimized (or anything unrecognised) is recorded as windowed.
static func mode_to_persist(mode: int) -> int:
	if mode in PERSISTABLE:
		return mode
	return Window.MODE_WINDOWED


## True when a mode read back from window.ini may be applied to the window.
## Rejects the -1 "absent" sentinel the callers use, and MODE_MINIMIZED.
static func may_restore_mode(mode: int) -> bool:
	return mode in PERSISTABLE
