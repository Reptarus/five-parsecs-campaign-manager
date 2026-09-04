extends SceneTree
## ⛔ SUPERSEDED AND ITS NUMBERS ARE INADMISSIBLE — see TouchChainProbe.gd.
##
## Measured 2026-09-04: this probe CANNOT load the screen it claims to measure.
## A `--script` SceneTree context does not register autoloads, so
## WorldPhaseController.gd:1345's bare `TweenFX` reference fails to compile,
## _ready() never runs, `_ensure_content_scroll()` never runs, and the touch
## sweep never runs. It printed "ContentScroll present: false" and then
## "STOP controls under PhaseContainer AFTER THE SWEEP: 51" — against a tree the
## sweep had never touched. Every hypothesis below was disproved on device:
##   * the sweep is NOT stale (it runs at :479, :698 and :1331)
##   * ItemList is NOT the blocker (step 1 has none; step 2 scrolls fine)
##   * the gesture DOES reach ContentScroll (`scroll_started` fires)
## T10-09 was closed as NOT REPRODUCED. Use src/ui/components/common/
## TouchChainProbe.gd, which runs in the real app on the device.
##
## Kept only so the numbers above are never cited again as evidence.
## T10-09: find what swallows a touch-drag over the World Phase step area.
##
## Measured on the tablet 2026-09-04, landscape, World Phase step 1:
##   swipe over the CONTENT   (1280,1250)->(1280,450)  ->        0 px changed
##   swipe over the SCROLLBAR (2470, 600)->(2470,1100) -> 1,442,658 px changed
## So the scroll range exists and only the drag-over-content path is dead — the
## exact signature TouchScrollOpener's own docblock describes.
##
## The sweep IS wired (WorldPhaseController._open_content_to_scroll_gesture ->
## TouchScrollOpener.open_subtree), so this is not a missing call. The prime
## suspect is TouchScrollOpener._SKIP, which leaves ScrollContainer / Tree /
## ItemList / TextEdit / RichTextLabel / GraphEdit at MOUSE_FILTER_STOP. A STOP
## control marks the event handled whether or not it does anything with it, and
## an ItemList that cannot itself scroll still claims the gesture.
##
## This prints every control under the step area that is still STOP after the
## sweep, so the offender is named rather than guessed at. Read the CLASS column:
## anything in _SKIP is there by policy and needs a decision, anything else is a
## sweep that did not reach it.
##
## Run: godot --headless --path . --script res://tests/tools/probe_world_phase_drag.gd

const WPC := preload("res://src/ui/screens/world/WorldPhaseController.tscn")

var _frames := 0
var _done := false


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3 or _done:
		return _done
	_done = true
	_run()
	return true


func _walk(node: Node, depth: int, out: Array) -> void:
	if node is Control:
		var c := node as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append({
				"path": str(node.name),
				"class": node.get_class(),
				"depth": depth,
				"visible": c.is_visible_in_tree(),
			})
	for child in node.get_children():
		_walk(child, depth + 1, out)


func _run() -> void:
	var ui := WPC.instantiate()
	root.add_child(ui)

	# Drive the RELAXED layout explicitly. _apply_layout_for is split from the
	# decision precisely so a probe can pick the branch instead of depending on
	# whatever the headless window happens to measure.
	if ui.has_method("_apply_layout_for"):
		ui._apply_layout_for(false)

	var scroll := ui.get_node_or_null("MarginContainer/VBoxContainer/ContentScroll")
	print("ContentScroll present: %s" % str(scroll != null))
	if scroll:
		print("  vertical_scroll_mode = %d (2 = AUTO)"
			% int((scroll as ScrollContainer).vertical_scroll_mode))

	# Where did the nav end up? The T10-11 fix pins it OUTSIDE the scroll on a
	# relaxed layout, so these should report parent=VBoxContainer, not ContentColumn.
	for nav_name in ["Controls", "HSeparator2", "Footer"]:
		var n := ui.find_child(nav_name, true, false)
		print("  %-13s parent = %s" % [
			nav_name, str(n.get_parent().name) if n else "<missing>"])

	var phase_container = ui.get_node_or_null("%PhaseContainer")
	if phase_container == null:
		print("PhaseContainer not found — cannot probe the step area")
		quit(0)
		return

	var stops: Array = []
	_walk(phase_container, 0, stops)
	print("\nSTOP controls under PhaseContainer after the sweep: %d" % stops.size())
	var by_class: Dictionary = {}
	for s in stops:
		by_class[s["class"]] = int(by_class.get(s["class"], 0)) + 1
	for k in by_class.keys():
		print("   %-22s x%d" % [str(k), int(by_class[k])])
	for s in stops:
		if bool(s["visible"]):
			print("   VISIBLE  %-22s %s" % [str(s["class"]), str(s["path"])])

	quit(0)
