class_name TouchChainProbe
extends Node
## Debug-only: name what is under the finger when a touch-drag goes nowhere.
##
## THE SYMPTOM THIS EXISTS FOR: a screen scrolls perfectly by dragging the thin
## scrollbar at the edge and does nothing at all when dragged in the middle. It
## has now cost FOUR device deploys — T4-01, T9-45, and T10-09 twice — and every
## desk-side diagnosis of it has been wrong.
##
## WHY IT SHIPS (behind OS.is_debug_build()) RATHER THAN BEING A THROWAWAY:
##
##   1. A `--script` SceneTree probe CANNOT load these screens at all. Autoloads
##      are not registered in that context, so any script naming one as a bare
##      identifier fails to compile. Measured 2026-09-04:
##      WorldPhaseController.gd:1345 "Identifier not found: TweenFX" -> _ready()
##      never ran -> _ensure_content_scroll() and the touch sweep never ran ->
##      the probe reported "51 STOP controls under PhaseContainer AFTER THE
##      SWEEP" against a tree the sweep had never touched. It read exactly like
##      evidence and it was an artefact.
##      Note TacticalBattleUI probes fine headlessly only because it resolves
##      autoloads via get_node_or_null("/root/X"). Whether a screen is probeable
##      at the desk is decided by ITS CODING STYLE, not by anything meaningful —
##      so "it probed clean headlessly" is never an argument.
##   2. A pixel-diff can only say "nothing moved". It cannot say why.
##
## So the device is the only instrument, and this is it.
##
## Usage, from a screen's _ready():
##     var probe := TouchChainProbe.attach(self, "WorldPhase")
##     if probe: probe.watch_scroll(content_scroll, "ContentScroll")
## attach() returns null in a release build, so the caller needs no guard of its
## own and a release export cannot reach any of this.

const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")

var _root: Control = null
var _tag: String = ""
var _scrolls: Array[Dictionary] = []
var _dump_count: int = 0

## The subtree the SCREEN's own sweep covers. Defaults to _root, but a screen
## that sweeps something narrower must say so, or the staleness verdict lies.
##
## Measured 2026-09-04: probing the whole WorldPhaseController reported "SWEEP
## WAS STALE — opened 2", when one of the two was the `Background` ColorRect —
## a SIBLING of the scroll that production deliberately never sweeps and that
## blocks nothing. A diagnostic that over-reports is worse than none: it invents
## a defect to chase. Compare like with like.
var _sweep_root: Node = null


## Attach a probe to `root`. Returns null (and adds nothing) in a release build.
static func attach(root: Control, tag: String) -> TouchChainProbe:
	if not OS.is_debug_build():
		return null
	if root == null or not is_instance_valid(root):
		return null
	var probe := TouchChainProbe.new()
	probe.name = "TouchChainProbe"
	probe.set_root(root, tag)
	root.add_child(probe)
	return probe


func set_root(root: Control, tag: String) -> void:
	_root = root
	_tag = tag


## Point the staleness check at the same subtree the screen itself sweeps.
func set_sweep_root(node: Node) -> void:
	_sweep_root = node


## Report scroll_started / scroll_ended for one container.
##
## Per the Godot 4.6 docs these fire ONLY for a touch drag on the SCROLLABLE
## AREA — never for the scrollbar, the wheel or the keyboard — and only on
## Android/iOS. That makes them the exact discriminator this class needs: if
## scroll_started fires, the gesture reached the container and the fault is
## range or clamping; if it never fires, something upstream claimed the event.
func watch_scroll(scroll: ScrollContainer, label: String) -> void:
	if not OS.is_debug_build():
		return
	if scroll == null or not is_instance_valid(scroll):
		return
	_scrolls.append({"node": scroll, "label": label})
	if not scroll.scroll_started.is_connected(_on_scroll_started):
		scroll.scroll_started.connect(_on_scroll_started.bind(label))
	if not scroll.scroll_ended.is_connected(_on_scroll_ended):
		scroll.scroll_ended.connect(_on_scroll_ended.bind(label))


func _on_scroll_started(label: String) -> void:
	print("[TouchChainProbe:%s] scroll_started on %s — THE GESTURE ARRIVED" % [
		_tag, label])


func _on_scroll_ended(label: String) -> void:
	print("[TouchChainProbe:%s] scroll_ended on %s" % [_tag, label])


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	_dump(touch.position)


func _filter_name(f: int) -> String:
	match f:
		Control.MOUSE_FILTER_STOP: return "STOP  <-- blocks"
		Control.MOUSE_FILTER_PASS: return "PASS"
		Control.MOUSE_FILTER_IGNORE: return "IGNORE"
	return "?"


func _collect(node: Node, pos: Vector2, depth: int, out: Array) -> void:
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			out.append({
				"depth": depth,
				"class": node.get_class(),
				"name": str(node.name),
				"filter": c.mouse_filter,
			})
	for child in node.get_children():
		_collect(child, pos, depth + 1, out)


## Anything containing the point that is NOT under the tracked root — an overlay
## on a higher CanvasLayer, which is how T10-05 (an invisible KeywordTooltip
## stretched over a card) killed every tap on the battle drawer's enemy cards.
func _collect_foreign(node: Node, pos: Vector2, out: Array) -> void:
	if node is Control and not _root.is_ancestor_of(node) and node != _root:
		var c := node as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				out.append({
					"class": node.get_class(),
					"name": str(node.name),
					"filter": c.mouse_filter,
					"layer": _layer_of(c),
				})
	for child in node.get_children():
		_collect_foreign(child, pos, out)


func _layer_of(node: Node) -> int:
	var n: Node = node
	while n != null:
		if n is CanvasLayer:
			return (n as CanvasLayer).layer
		n = n.get_parent()
	return 0


func _dump(pos: Vector2) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_dump_count += 1
	print("")
	print("[TouchChainProbe:%s] touch #%d at %s" % [_tag, _dump_count, str(pos)])

	for entry in _scrolls:
		var sc = entry["node"]
		if sc == null or not is_instance_valid(sc):
			continue
		var bar := (sc as ScrollContainer).get_v_scroll_bar()
		var span: float = bar.max_value - bar.page
		print("  scroll %-16s v=%d  max=%d page=%d  scrollable_span=%d %s" % [
			str(entry["label"]), int((sc as ScrollContainer).scroll_vertical),
			int(bar.max_value), int(bar.page), int(span),
			"" if span > 0.0 else "<-- NOTHING TO SCROLL"])

	var inside: Array = []
	_collect(_root, pos, 0, inside)
	inside.sort_custom(func(a, b): return int(a["depth"]) > int(b["depth"]))
	print("  under the finger, DEEPEST FIRST:")
	if inside.is_empty():
		print("    <nothing — the touch missed %s entirely>" % _root.name)
	for row in inside:
		print("    %-14s %-18s %s" % [
			_filter_name(int(row["filter"])), str(row["class"]),
			str(row["name"])])

	var foreign: Array = []
	_collect_foreign(get_tree().root, pos, foreign)
	if not foreign.is_empty():
		print("  ALSO hit-testable OUTSIDE this screen (overlay suspects):")
		for row in foreign:
			print("    layer %-4d %-14s %-18s %s" % [
				int(row["layer"]), _filter_name(int(row["filter"])),
				str(row["class"]), str(row["name"])])

	# ⚠ This MUTATES the tree, so only the FIRST touch's count is evidence: after
	# it runs, the sweep really is current and a later touch reports 0 whether or
	# not there was ever a gap. Re-launch to re-measure.
	var sweep_target: Node = _sweep_root if _sweep_root != null else _root
	var reopened: int = TouchScrollOpenerRef.open_subtree(sweep_target)
	var verdict: String = "sweep was current"
	if reopened > 0:
		verdict = "SWEEP WAS STALE — something rebuilt after the last sweep"
	if _dump_count > 1:
		verdict += " (touch #2+; only touch #1 is evidence)"
	print("  TouchScrollOpener re-run over %s opened %d control(s) — %s" % [
		str(sweep_target.name), reopened, verdict])
