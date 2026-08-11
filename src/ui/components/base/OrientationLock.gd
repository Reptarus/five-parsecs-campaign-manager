class_name OrientationLock
extends Node

## Self-wiring helper that holds a screen in one orientation while it is on screen,
## and puts the device back exactly as it found it on the way out.
##
## WHY. Most of this app reflows (see docs/sop/responsive-adaptive-ui.md) and should
## keep doing so. A few screens do NOT reflow, because what they show is a FIXED-ASPECT
## DOCUMENT rather than a layout: the Print Sheet preview is a 3:2 landscape page from
## the rulebook, and its proportions are the artwork's, not ours. Shown in portrait it
## can only shrink to fit the width — on the test tablet the whole crew roster rendered
## about a third of the screen tall, with the stat numbers too small to read and two
## thirds of the screen empty above and below. There is no responsive answer to that,
## because there is nothing to re-flow.
##
## SENSOR_LANDSCAPE, not LANDSCAPE: this forbids portrait but still lets the device be
## held either way round, so it never fights someone holding a tablet "upside down".
##
## Usage (from a screen's _ready):
##   var lock := OrientationLock.new()
##   add_child(lock)
##   lock.setup(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
##
## The restore is in _exit_tree(), NOT tree_exited: tree_exited fires after the node has
## detached, and this project has been bitten by that before — cleanup that needs the
## tree (or an autoload) must run while the node is still in it. See CLAUDE.md, the
## NarrativeScreen chrome-restore note.

## What the device was doing before we touched it, so we restore rather than assume.
## project.godot ships `window/handheld/orientation=6` (SENSOR), but reading the live
## value means a screen entered from some other locked screen still restores correctly.
var _previous: int = -1
var _locked: bool = false


## Lock to `orientation` (a DisplayServer.ScreenOrientation). No-op on any platform
## that does not support orientation control, which is every desktop build — so this
## is safe to add unconditionally and desktop QA sees no change at all.
func setup(orientation: int = DisplayServer.SCREEN_SENSOR_LANDSCAPE) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		return
	_previous = DisplayServer.screen_get_orientation()
	if _previous == orientation:
		# Already there. Do not record a lock, or we would "restore" a value we
		# never changed and could stomp a lock set by whoever came before us.
		return
	DisplayServer.screen_set_orientation(orientation)
	_locked = true


## Restore early, if a screen wants the device released before it is freed.
func release() -> void:
	if not _locked:
		return
	_locked = false
	if _previous >= 0:
		DisplayServer.screen_set_orientation(_previous)


func _exit_tree() -> void:
	release()
