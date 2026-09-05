class_name ShortScreenScroll
extends Node

## Self-wiring helper that lets a screen's content scroll when it does not FIT.
## Companion to PortraitChrome, which does the same job horizontally.
##
## The problem it solves: a phone in landscape has ~338 design px of HEIGHT. Several
## screens lay out a header, a content area and a footer with fixed spacing that adds
## up to more than that, and because their roots grow both ways the overflow re-centres
## the screen — so content hangs off the TOP as well as the bottom, and the part that
## hangs off the top lands underneath the floating SettingsOverlay buttons. Fixing the
## height therefore also fixes the "title collides with the band" findings.
##
## ── WHY THE GATE IS NOT "IS THE SCREEN SHORT" (rewritten 2026-09-04, T11-01) ──
##
## It used to be exactly that — `viewport.height < short_px`, short_px 620 — and that
## is how T11-01 shipped. A tablet in landscape has a DESIGN height of 689, so the
## gate never fired, the scroll stayed DISABLED, and a DISABLED ScrollContainer
## propagates its child's minimum: PreBattleUI's populated 4-pane AdaptivePanelGroup
## pushed the chain 196.7 px past the viewport. PreBattle.tscn's root MarginContainer
## is anchored full-rect with `grow_vertical = 2` (GROW_DIRECTION_BOTH), so it grew in
## BOTH directions — the footer left the screen at the bottom, the header at the top —
## and because the scroll was DISABLED rather than exhausted, swiping did nothing.
##
## The tell was in the layout sweep's own numbers once its screens were populated:
##
##   phone landscape    338 design px of height   scroll AUTO       PASS
##   small phone        551                       scroll AUTO       PASS
##   phone portrait     733                       scroll DISABLED   FAIL   91.8 px
##   tablet landscape   689                       scroll DISABLED   FAIL  196.7 px
##   desktop 1080p      931                       scroll DISABLED   FAIL   14.5 px
##
## The config with the LEAST room passed and the roomier ones failed, because only the
## short one turned scrolling on. "The screen is short" and "the content does not fit"
## are different questions and only the second one matters.
##
## So the gate now also asks whether the CONTENT overflows the space the scroll is
## actually given. The viewport-height clause is KEPT as a floor: it is what all nine
## existing callers have been getting, it can only ever turn scrolling ON, and on a
## screen whose content fits, AUTO renders identically to DISABLED anyway — Godot 4.6
## adds scrollbars only "if the child node's size exceeds the container's dimensions",
## and "both vertical and horizontal size options are respected", so an EXPAND_FILL
## child is still stretched to fill the container (class_scrollcontainer,
## gui_containers). That is what keeps the promise below honest.
##
## ⚠ THE MEASUREMENT IS CIRCULAR IF TAKEN IN THE WRONG STATE. While DISABLED, the
## scroll has ALREADY propagated the content's minimum upward, so its own rect has
## grown to fit it and `content_min > scroll.size.y` is false no matter how badly the
## screen overflows — the check would report "fits" precisely when it does not. The
## measurement is therefore taken with scrolling ENABLED, where the scroll contributes
## no vertical minimum and its rect is the real budget. That costs two frames, which
## is why _apply() defers into _apply_deferred().
##
## ⚠ THE CONTENT USUALLY ARRIVES AFTER _ready(). PreBattleUI is set up by its
## navigator (CampaignTurnController._launch_pre_battle_directly), so a measurement
## taken once at _ready() measures an EMPTY screen and concludes it fits. The inner
## column's `minimum_size_changed` is connected for exactly this reason — it is the
## signal Godot emits "when the node's minimum size changes" (class_control), and
## without it this whole fix would never fire on the screen it was written for.
##
## Usage (from a screen's _ready, after its UI exists):
##   var s := ShortScreenScroll.new()
##   add_child(s)
##   s.setup($MarginContainer/VBoxContainer, 1)             # pin the header
##   s.setup($MarginContainer/VBoxContainer, 1, 620.0, 1)   # ...and the footer
##
## Leading pinned children stay ABOVE the scroll; trailing pinned children stay BELOW
## it, which is what keeps a footer on screen instead of scrolling away with the
## content. Everything between them moves into the scroll, in order.

const SCROLL_NAME := "ContentScroll"
const COLUMN_NAME := "ScrollColumn"

## Sub-pixel slack, so a rounding artefact does not flip the mode every resize.
const FIT_EPS := 1.0

var _column: BoxContainer = null
var _scroll: ScrollContainer = null
var _inner: VBoxContainer = null
var _short_px: float = 620.0
var _applying: bool = false


## `column` is the screen's content column; `pinned` is how many of its LEADING
## children stay above the scroll; `short_px` is the design height below which
## scrolling is forced on regardless of fit; `pinned_trailing` is how many of its
## TRAILING children stay below the scroll (a footer: pass 1).
func setup(column: BoxContainer, pinned: int = 0, short_px: float = 620.0,
		pinned_trailing: int = 0) -> void:
	if column == null or not is_instance_valid(column) or not column.vertical:
		return
	_column = column
	_short_px = short_px
	_build(pinned, pinned_trailing)
	_apply()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply):
		vp.size_changed.connect(_apply)
	# Re-decide when the content itself changes height. Without this the decision is
	# made once, against whatever the screen happened to hold at _ready().
	if _inner != null and is_instance_valid(_inner) \
			and not _inner.minimum_size_changed.is_connected(_apply):
		_inner.minimum_size_changed.connect(_apply)


func _build(pinned: int, pinned_trailing: int) -> void:
	if _column.get_node_or_null(SCROLL_NAME) != null:
		_scroll = _column.get_node(SCROLL_NAME)
		_inner = _scroll.get_node_or_null(COLUMN_NAME)
		return

	# Snapshot the children BEFORE inserting anything, so the indices the caller
	# reasoned about are the ones used.
	var kids: Array[Node] = []
	for child in _column.get_children():
		kids.append(child)
	var stop: int = kids.size() - maxi(0, pinned_trailing)
	var movable: Array[Node] = []
	for i in range(kids.size()):
		if i >= pinned and i < stop and kids[i] is Control:
			movable.append(kids[i])
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
	# add_child appends, which would put the scroll BELOW the trailing pins and undo
	# the whole point of pinning them. Seat it directly after the leading pins.
	_column.move_child(_scroll, pinned)
	_scroll.add_child(inner)
	for child in movable:
		_column.remove_child(child)
		inner.add_child(child)
	_inner = inner


func _apply() -> void:
	if _applying:
		return
	_applying = true
	_apply_deferred()


## Decide the scroll mode from a measurement taken in the ENABLED configuration.
## See the ⚠ notes in the class docblock for why it cannot be taken any other way.
func _apply_deferred() -> void:
	if not _still_valid():
		_applying = false
		return

	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	# Two frames is normally enough for the container chain to re-sort. A screen still
	# building can report a zero-height scroll, and deciding from that would call every
	# screen "overflowing"; poll a bounded number of frames for a real budget instead.
	var tree := get_tree()
	var budget: float = 0.0
	if tree != null:
		for _i in range(8):
			await tree.process_frame
			if not _still_valid():
				_applying = false
				return
			budget = _scroll.size.y
			if budget > 0.0:
				break

	if not _still_valid():
		_applying = false
		return

	var need: float = 0.0
	if _inner != null and is_instance_valid(_inner):
		need = _inner.get_combined_minimum_size().y

	# get_visible_rect() is the DESIGN space, which is the correct measure here: this
	# is a layout budget, not the orientation question that needs physical pixels
	# (docs/sop/responsive-adaptive-ui.md).
	var vp := get_viewport()
	var short_viewport: bool = vp != null \
		and vp.get_visible_rect().size.y < _short_px
	# budget <= 0 means the screen never finished laying out in the poll window. Left
	# scrollable is the safe side: an unnecessary AUTO shows no scrollbar, while a
	# wrong DISABLED is the defect this file exists to stop.
	var overflows: bool = budget <= 0.0 or need > budget + FIT_EPS

	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
		if (short_viewport or overflows) else ScrollContainer.SCROLL_MODE_DISABLED
	_applying = false


func _still_valid() -> bool:
	return _scroll != null and is_instance_valid(_scroll) and is_inside_tree() \
		and _scroll.is_inside_tree()
