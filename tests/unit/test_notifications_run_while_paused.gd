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
