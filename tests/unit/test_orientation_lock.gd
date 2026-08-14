extends GdUnitTestSuite

## OrientationLock holds a fixed-aspect document screen in landscape and must put the
## device back on the way out. The failure that matters is a LEAK: a screen locks
## landscape, is freed without restoring, and every other screen in the app is stuck
## that way for the rest of the session with nothing pointing at the cause.
##
## Desktop has no FEATURE_ORIENTATION, so the real device behaviour cannot be asserted
## here. What CAN be asserted — and is the whole risk for desktop QA — is that the
## helper is inert without the feature, and that its restore path is safe to call in
## any order. Stated plainly rather than dressed up as more coverage than it is.

const OrientationLockScript = preload("res://src/ui/components/base/OrientationLock.gd")


func _lock() -> Node:
	var n: Node = OrientationLockScript.new()
	add_child(n)
	auto_free(n)
	return n


## Adding it to a desktop screen must change nothing at all — this is what lets the
## helper be wired unconditionally instead of behind a platform check at every site.
func test_it_is_inert_on_a_platform_without_orientation_support() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		return  # real device: covered by device QA, not here
	var lock: Node = _lock()
	lock.setup(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	assert_bool(lock._locked).override_failure_message(
		"OrientationLock recorded a lock on a platform with no orientation support; " +
		"it would then 'restore' an orientation it never actually set."
	).is_false()


## release() must be safe before setup, after setup, and twice — _exit_tree() calls it
## on every teardown regardless of what happened earlier.
func test_release_is_safe_in_any_order() -> void:
	var lock: Node = _lock()
	lock.release()  # never set up
	lock.setup(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	lock.release()
	lock.release()  # idempotent
	assert_bool(lock._locked).is_false()


## Locking to the orientation the device is ALREADY in must not record a lock: doing so
## would make this node "restore" a value it never changed, stomping a lock owned by
## whichever screen set it.
func test_locking_to_the_current_orientation_records_nothing() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		return
	var lock: Node = _lock()
	lock.setup(DisplayServer.screen_get_orientation())
	assert_bool(lock._locked).is_false()
