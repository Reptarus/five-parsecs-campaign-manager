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
	"ScrollContainer", "Tree", "ItemList", "TextEdit", "RichTextLabel",
	"GraphEdit",
]


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
		if child is Control:
			var c := child as Control
			var skip: bool = false
			for cls: String in _SKIP:
				if c.is_class(cls):
					skip = true
					break
			if not skip and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
				opened += 1
		opened += open_subtree(child)
	return opened
