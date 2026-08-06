class_name ShortScreenScroll
extends Node

## Self-wiring helper that lets a screen's content scroll ONLY when the screen is too
## short for it. Companion to PortraitChrome, which does the same job horizontally.
##
## The problem it solves: a phone in landscape has ~338 design px of HEIGHT. Several
## screens lay out a header, a content area and a footer with fixed spacing that adds
## up to more than that, and because their roots grow both ways the overflow re-centres
## the screen — so content hangs off the TOP as well as the bottom, and the part that
## hangs off the top lands underneath the floating SettingsOverlay buttons. Fixing the
## height therefore also fixes the "title collides with the band" findings.
##
## Why not just always scroll: on a tall screen an always-on scroll is worse than no
## scroll — it disconnects the footer from the bottom edge and adds a scrollbar to a
## layout that fits. So the ScrollContainer is created once and always present, and
## only its vertical_scroll_mode changes: AUTO on a short screen, DISABLED otherwise.
## A DISABLED ScrollContainer propagates its child's minimum exactly like the plain
## container it replaced, so tall screens lay out as they always did.
##
## Usage (from a screen's _ready, after its UI exists):
##   var s := ShortScreenScroll.new()
##   add_child(s)
##   s.setup($MarginContainer/VBoxContainer, 1)   # keep the first child pinned
##
## The pinned children stay outside the scroll — a header usually should. Everything
## after them moves into the scroll, in order.

const SCROLL_NAME := "ContentScroll"
const COLUMN_NAME := "ScrollColumn"

var _column: BoxContainer = null
var _scroll: ScrollContainer = null
var _short_px: float = 620.0


## `column` is the screen's content column; `pinned` is how many of its leading
## children stay outside the scroll; `short_px` is the DESIGN height below which
## scrolling turns on.
func setup(column: BoxContainer, pinned: int = 0, short_px: float = 620.0) -> void:
	if column == null or not is_instance_valid(column) or not column.vertical:
		return
	_column = column
	_short_px = short_px
	_build(pinned)
	_apply()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply):
		vp.size_changed.connect(_apply)


func _build(pinned: int) -> void:
	if _column.get_node_or_null(SCROLL_NAME) != null:
		_scroll = _column.get_node(SCROLL_NAME)
		return
	var movable: Array[Node] = []
	var index := 0
	for child in _column.get_children():
		if index >= pinned and child is Control:
			movable.append(child)
		index += 1
	if movable.is_empty():
		return

	_scroll = ScrollContainer.new()
	_scroll.name = SCROLL_NAME
	# DISABLED horizontally on purpose: a ScrollContainer absorbs a child's minimum on
	# its SCROLLABLE axes only, so the column keeps reporting its content WIDTH (which
	# must still be fixed properly) while the height stops propagating.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.name = COLUMN_NAME
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", _column.get_theme_constant("separation"))

	_column.add_child(_scroll)
	_scroll.add_child(inner)
	for child in movable:
		_column.remove_child(child)
		inner.add_child(child)


func _apply() -> void:
	if _scroll == null or not is_instance_valid(_scroll) or not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	# get_visible_rect() is the DESIGN space, which is the correct measure here: this
	# is a layout budget, not the orientation question that needs physical pixels
	# (docs/sop/responsive-adaptive-ui.md).
	var tight: bool = vp.get_visible_rect().size.y < _short_px
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if tight \
		else ScrollContainer.SCROLL_MODE_DISABLED
