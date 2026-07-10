extends GdUnitTestSuite
## Wave 1b — every [connection] in these scenes must resolve to a real method on
## the target node's script (the class of bug behind the deleted-RewardsPanel dead
## buttons). This locks the invariant on a verified-clean scene; the project-wide
## scan is the Wave-4 permanent detector scripts/lint_tscn_connections.py, which
## catches the broader cases (e.g. the LEGACY TravelPhaseUI.tscn, whose script
## reference points at TravelPhase.gd — missing all 6 handlers — a Wave-2 item).

const SCENES: Array = [
	"res://src/ui/screens/mainmenu/MainMenu.tscn",
]

func test_all_connections_resolve() -> void:
	for path in SCENES:
		var scene: PackedScene = load(path)
		assert_object(scene).is_not_null()
		var inst: Node = auto_free(scene.instantiate())
		var state: SceneState = scene.get_state()
		for i in state.get_connection_count():
			var method: String = state.get_connection_method(i)
			var target: Node = inst.get_node_or_null(state.get_connection_target(i))
			assert_object(target) \
				.override_failure_message("%s: connection method '%s' -> missing target node '%s'" % [
					path, method, str(state.get_connection_target(i))]) \
				.is_not_null()
			if target != null and target.get_script() != null:
				assert_bool(target.has_method(method)) \
					.override_failure_message("%s: connection method '%s' not found on target '%s'" % [
						path, method, str(state.get_connection_target(i))]) \
					.is_true()
