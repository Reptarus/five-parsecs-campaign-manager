extends RefCounted
## Let a touch-drag over content reach the ScrollContainer that owns it.
##
## THE PROBLEM, measured on a Lenovo TB361FU across three QA passes (T4-01,
## T9-45): a screen scrolls perfectly by dragging the thin scrollbar at the edge
## and does nothing at all when dragged in the middle. `Control.mouse_filter`
## defaults to `MOUSE_FILTER_STOP` on PanelContainer, HSeparator, CheckBox,
## OptionButton, SpinBox and Button, and STOP marks the event HANDLED whether or
## not the control does anything with it. The finger lands on one of those, the
## event dies there, and the ScrollContainer above never sees a drag.
##
## Verified against the Godot 4.6 docs before writing this:
##   - `ScrollContainer.scroll_deadzone` only governs a drag the container
##     RECEIVES; it cannot help when a child swallowed the event first. The
##     project already sets `gui/common/default_scroll_deadzone=16` and both
##     screens were still dead.
##   - `Control.mouse_force_pass_scroll_events` (default true) covers SCROLL
##     WHEEL events only, not touch drags.
## So relaxing mouse_filter is the only lever, which is what this does.
##
## WHY STOP -> PASS IS SAFE, and why the previous, narrower rule was not needed:
## PASS still delivers the event to the control FIRST. A widget that genuinely
## acts on a drag — a Tree or ItemList scrolling itself, a LineEdit selecting
## text, a Slider changing value — accepts it and nothing propagates. Only
## events the widget does NOT handle continue to the parent. A CheckBox has no
## drag behaviour at all, so its STOP is pure loss.
##
## The earlier sweep in WorldPhaseController guarded on
## `focus_mode == FOCUS_NONE` to protect exactly those inner-scrolling widgets.
## That is stricter than necessary and it is why T9-45 survived: CheckBox,
## SpinBox and OptionButton are all focusable, and the Record Battle Result
## drawer is wall-to-wall those three.
##
## Containers that own an inner scroll are still skipped outright, because they
## must keep claiming their gesture rather than merely getting first refusal.

## Controls whose own drag handling should never be competed with. Everything
## else is opened.
const _SKIP := [
	"ScrollContainer", "Tree", "ItemList", "TextEdit", "GraphEdit",
]


## True for a control that owns a drag of its own and must keep claiming it. A
## RichTextLabel does only while it scrolls its own text: this list used to name every
## RichTextLabel, so a fitted result line (`scroll_active = false`, which is how the
## variant-mode turn panels print nearly everything) kept STOP and a finger dragged over
## it moved nothing. PASS still hands a [url] tap to the label first.
static func keeps_its_gesture(c: Control) -> bool:
	if c is RichTextLabel:
		return (c as RichTextLabel).scroll_active
	for cls: String in _SKIP:
		if c.is_class(cls):
			return true
	return false


## Relax every STOP descendant of `root` so drags reach the owning scroll.
##
## Idempotent and cheap: STOP -> PASS only, so re-running after a rebuild is
## safe. Call it AFTER the content is populated — a sweep that runs before the
## children exist is a fix that silently does nothing, which is how the World
## Phase step area stayed dead through two rebuild paths.
##
## Returns the number of controls opened, so a caller (or a test) can tell the
## difference between "nothing needed opening" and "the sweep never ran".
static func open_subtree(root: Node) -> int:
	if root == null:
		return 0
	var opened: int = 0
	for child in root.get_children():
		if child is Control and open_one(child as Control):
			opened += 1
		opened += open_subtree(child)
	return opened


## Open `root` now and keep it open: every control that later enters the tree under it
## is opened as it arrives. A sweep reaches only the children that exist when it runs,
## so a result line added after a press arrived STOP and swallowed the drag meant for
## the page, and every rebuild path had to remember to sweep again. Order-independent,
## the shape KeyboardAvoidance uses for Windows. The keeper is a child of `root`, so it
## is freed with it and nothing outlives the screen. Idempotent per root.
static func keep_open(root: Node) -> void:
	if root == null or root.has_node(NodePath(_Keeper.NODE_NAME)):
		return
	open_subtree(root)
	var keeper := _Keeper.new()
	keeper.name = _Keeper.NODE_NAME
	root.add_child(keeper)


class _Keeper extends Node:
	const NODE_NAME := "__TouchScrollKeeper"

	func _ready() -> void:
		get_tree().node_added.connect(_on_node_added)

	func _on_node_added(node: Node) -> void:
		var root: Node = get_parent()
		if node is Control and root != null and root.is_ancestor_of(node):
			# Deferred: a control that sets its own filter in _ready() is read after.
			_open.call_deferred(node)

	func _open(node: Node) -> void:
		if is_instance_valid(node) and node is Control:
			TouchScrollOpenerScript.open_one(node as Control)


const TouchScrollOpenerScript := preload("res://src/ui/components/common/TouchScrollOpener.gd")


## Open one control (not its children). True when it was STOP and is now PASS.
static func open_one(c: Control) -> bool:
	if c == null or keeps_its_gesture(c) or c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return false
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return true
