extends GdUnitTestSuite
## UX-2: a toast keeps fading while Settings pauses the tree.
##
## SettingsOverlay sets get_tree().paused = true. Every toast tween is bound to
## NotificationManager (TWEEN_PAUSE_BOUND), so with the inherited process mode a
## toast froze mid-fade for as long as Settings stayed open: the T11-27 shape.
##
## The pause is set and cleared in the same frame, so the test runner never stalls.


func test_the_notification_layer_runs_under_a_paused_tree() -> void:
	var nm: Node = get_tree().root.get_node_or_null("/root/NotificationManager")
	assert_object(nm).is_not_null()
	var probe := Node.new()
	add_child(probe)
	var was_paused := get_tree().paused
	get_tree().paused = true
	var probe_runs := probe.can_process()
	var toasts_run: bool = nm.can_process()
	get_tree().paused = was_paused
	probe.free()
	# The premise: a pause does stop a node that inherits its mode. Without it this
	# case could pass against a tree that was never paused.
	assert_bool(probe_runs).override_failure_message(
		"the pause did not stop an inheriting node, so the case below proves nothing") \
		.is_false()
	assert_bool(toasts_run).override_failure_message(
		"NotificationManager stops while paused, so a toast freezes under Settings") \
		.is_true()


## A suite that detaches the autoload and puts it back (test_bug_hunt_coop_mission
## does, to stop a launch navigating) must not leave the manager unable to show a
## toast: _exit_tree() used to null the container and _ready() never rebuilds it,
## so every later toast in that process aborted at _show_notification().
func test_a_detached_and_reattached_manager_still_shows_a_toast() -> void:
	var root := get_tree().root
	var nm: Node = root.get_node_or_null("NotificationManager")
	assert_object(nm).is_not_null()
	var index := nm.get_index()
	root.remove_child(nm)
	root.add_child(nm)
	root.move_child(nm, index)
	nm.show_info("detach probe", 0.1)
	await await_idle_frame()
	var container: Variant = nm.get("_container")
	assert_bool(is_instance_valid(container)).override_failure_message(
		"the notification container is gone after a detach and re-attach").is_true()
	assert_int((container as Node).get_child_count()).override_failure_message(
		"the toast never reached the container").is_greater(0)
	nm.clear_all()
