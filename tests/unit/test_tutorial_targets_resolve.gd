extends GdUnitTestSuite

## The tutorial coach marks point at nodes by path, and those paths have now broken
## TWICE without anyone noticing — once when the screens gained scroll containers, and
## again when they gained ShortScreenScroll, which REPARENTS every child after the
## pinned ones into a runtime-created `ContentScroll/ScrollColumn`.
##
## It stays silent because a step with no resolvable target falls back to a centred
## tooltip, which is the correct rendering for the deliberately target-less welcome
## step. A broken coach mark and a working welcome step look identical.
##
## Device log, Aug 9 2026: `MarginContainer/VBoxContainer/HeaderPanel` "did not resolve
## in scene CampaignDashboard" — while that exact path DOES exist in
## CampaignDashboard.tscn. The scene file was never the problem; the live tree was.

const TutorialOverlayScript = preload("res://src/ui/components/tutorial/TutorialOverlay.gd")

## Which scene each tutorial's paths are written against. The JSON files are bare step
## arrays and do not name their scene, so the mapping lives here.
const TUTORIAL_SCENES: Dictionary = {
	"res://data/tutorials/first_run.json": "res://src/ui/screens/mainmenu/MainMenu.tscn",
	"res://data/tutorials/campaign_dashboard.json":
		"res://src/ui/screens/campaign/CampaignDashboard.tscn",
}


func _load_steps(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		return parsed
	if parsed is Dictionary:
		var s: Variant = (parsed as Dictionary).get("steps", [])
		return s if s is Array else []
	return []


## Static guard: every target a tutorial names must exist SOMEWHERE in its scene. This
## cannot catch reparenting (the scene file is the pre-runtime tree) but it does catch
## a renamed or deleted node, which is the other half of how these rot.
func test_every_tutorial_target_name_exists_in_its_scene() -> void:
	for tutorial_path: String in TUTORIAL_SCENES:
		var scene_path: String = str(TUTORIAL_SCENES[tutorial_path])
		var packed: PackedScene = load(scene_path)
		assert_that(packed).override_failure_message(
			"Tutorial %s names scene %s, which does not load." % [tutorial_path, scene_path]
		).is_not_null()
		var root: Node = packed.instantiate()
		auto_free(root)

		var steps: Array = _load_steps(tutorial_path)
		assert_int(steps.size()).override_failure_message(
			"%s has no steps." % tutorial_path).is_greater(0)

		for step: Dictionary in steps:
			var target_path: String = str(step.get("target_path", ""))
			if target_path.is_empty():
				continue  # the welcome step is deliberately target-less
			var leaf: String = target_path.get_slice(
				"/", target_path.get_slice_count("/") - 1)
			var found: Node = root.find_child(leaf, true, false)
			assert_that(found).override_failure_message(
				"Tutorial %s points at '%s', but no node named '%s' exists anywhere in %s. " % [
					tutorial_path, target_path, leaf, scene_path] +
				"The coach mark will silently highlight nothing."
			).is_not_null()


## The mechanism itself: a node moved out from under its authored path must still be
## found. This is the case the app actually hits, and the one no static check can see.
func test_a_reparented_target_is_still_found_by_name() -> void:
	var overlay: Node = TutorialOverlayScript.new()
	add_child(overlay)
	auto_free(overlay)

	# Mimic CampaignDashboard: a column whose children get moved into a runtime-created
	# scroll after the first pinned one.
	var scene_root := Control.new()
	scene_root.name = "FakeScreen"
	var column := VBoxContainer.new()
	column.name = "VBoxContainer"
	var header := PanelContainer.new()
	header.name = "HeaderPanel"
	scene_root.add_child(column)
	column.add_child(header)
	add_child(scene_root)
	auto_free(scene_root)

	var authored := "VBoxContainer/HeaderPanel"
	assert_that(overlay._resolve_target(authored, scene_root)).override_failure_message(
		"The exact authored path must still be the fast path when nothing moved."
	).is_not_null()

	# Now reparent exactly the way ShortScreenScroll does.
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	var inner := VBoxContainer.new()
	inner.name = "ScrollColumn"
	column.add_child(scroll)
	scroll.add_child(inner)
	column.remove_child(header)
	inner.add_child(header)

	assert_that(scene_root.get_node_or_null(authored)).override_failure_message(
		"Precondition: after reparenting the authored path must NOT resolve, or this " +
		"test proves nothing."
	).is_null()
	assert_that(overlay._resolve_target(authored, scene_root)).override_failure_message(
		"HeaderPanel moved to ContentScroll/ScrollColumn and the resolver lost it. " +
		"Node names survive reparenting; paths do not."
	).is_not_null()


## An unresolvable target must return null rather than something arbitrary — the
## centred-tooltip fallback is correct, a coach mark on the wrong node is not.
func test_an_unknown_target_resolves_to_null() -> void:
	var overlay: Node = TutorialOverlayScript.new()
	add_child(overlay)
	auto_free(overlay)
	var scene_root := Control.new()
	scene_root.name = "FakeScreen"
	add_child(scene_root)
	auto_free(scene_root)

	assert_that(overlay._resolve_target("Nope/DoesNotExist", scene_root)).is_null()
