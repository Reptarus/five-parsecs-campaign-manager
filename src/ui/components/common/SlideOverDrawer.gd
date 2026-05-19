class_name SlideOverDrawer
extends Control

## Reusable edge-anchored slide-over drawer (non-blocking, one-content).
##
## A drawer holds ONE content Control set once via `set_content()`. It slides
## in from a screen edge on `open()` and back out on `close()`. A light scrim
## (tap-to-close) sits behind the panel; the rest of the screen stays readable
## (non-blocking — the drawer never halts game flow). Exclusivity ("one open
## at a time") is the host's responsibility: call `close()` on the others
## before `open()`-ing one. See TacticalBattleUI `_make_drawer`/`_open_drawer`
## for the production host pattern.
##
## Edge directions follow the project's established gesture-spatial language
## (docs/falloutappscreenshots/five-parsecs-ux-design-analysis.md:868-879):
## browse/crew = LEFT, tools/reference = RIGHT, reveals = BOTTOM.
##
## Animation: raw Tween on panel position (CLAUDE.md gotcha — TweenFX has no
## horizontal variant; raw Tween is the established project decision). Matches
## the existing card slide-in: 0.25s TRANS_CUBIC / EASE_OUT.

signal opened
signal closed

enum Edge { LEFT, RIGHT, BOTTOM }

const ANIM_DURATION := 0.25
const SCRIM_ALPHA := 0.35  # low enough that glance rails stay readable behind

@export var edge: Edge = Edge.RIGHT
@export var drawer_title: String = ""
## When false (tests/headless), open/close snap instantly with no Tween.
@export var animate: bool = true
## LEFT/RIGHT minimum panel width. 0 = the default tight reading column
## (clampf(vp.x*0.26, 300, 380)). A host that puts WIDE content in the drawer
## (e.g. full unit-tracker cards with a 5-button action row) sets this so the
## panel grows to fit instead of horizontally clipping/scrolling. Still capped
## to half the viewport so it never becomes a screen takeover.
@export var min_panel_width: float = 0.0

## Smallest panel height (LEFT/RIGHT) so a 1-line drawer still reads as a
## panel, not a sliver. Content shorter than this is top-aligned within it.
const MIN_PANEL_H := 200.0

var _scrim: Button
var _panel: PanelContainer
var _header: HBoxContainer
var _title_label: Label
var _scroll: ScrollContainer
var _content_host: MarginContainer
var _content: Control = null
var _tween: Tween = null
var _is_open: bool = false


func _ready() -> void:
	# Fill the parent (CanvasLayer / Control) so geometry math uses our rect.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # only children catch input
	_build()
	visible = false


func _build() -> void:
	# Scrim: a full-rect button behind the panel; tap closes the drawer.
	_scrim = Button.new()
	_scrim.flat = true
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.focus_mode = Control.FOCUS_NONE
	var scrim_style := StyleBoxFlat.new()
	scrim_style.bg_color = Color(0.02, 0.02, 0.06, SCRIM_ALPHA)
	_scrim.add_theme_stylebox_override("normal", scrim_style)
	_scrim.add_theme_stylebox_override("hover", scrim_style)
	_scrim.add_theme_stylebox_override("pressed", scrim_style)
	_scrim.pressed.connect(close)
	add_child(_scrim)

	# Panel: the sliding surface, Deep Space themed.
	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.COLOR_ELEVATED
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(UIColors.SPACING_MD)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	_panel.add_child(vbox)

	# Header: title + close button.
	var header := HBoxContainer.new()
	_header = header
	header.add_theme_constant_override("separation", UIColors.SPACING_SM)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = drawer_title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long title (e.g. "Battle Round Reference (Core Rules p.119)") must
	# NOT dictate panel width: a non-wrapping Label's min width is its full
	# text, which propagates header -> panel and overhangs the viewport.
	# Wrap it instead so the header min width stays tiny.
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size.x = 0.0
	_title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	_title_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# The drawer owns scrolling: callers pass plain content and the panel
	# hugs that content's height (capped to the viewport). Tall content
	# (e.g. the crew list) scrolls inside this; short content (a few rules
	# lines) leaves a small panel, not a full-height empty slab.
	_scroll = ScrollContainer.new()
	# AUTO (not DISABLED): a ScrollContainer only stops propagating a child's
	# minimum size on axes it can scroll. With horizontal DISABLED, a wide
	# production body (e.g. WeaponTableDisplay, ~420px min) pushes the panel
	# past its width cap and off-screen. AUTO keeps the column the fixed
	# tight width and lets inherently-wide content scroll inside it.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	# Content host (caller's Control is parented here, once). NOT vertical-
	# expand — it must report its natural height so the panel can fit it.
	_content_host = MarginContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_host)


## Set the drawer's content once. Subsequent calls replace it.
func set_content(content: Control) -> void:
	if _content and is_instance_valid(_content):
		_content_host.remove_child(_content)
		_content.queue_free()
	_content = content
	if _content:
		# Horizontal-fill so it wraps to the panel; vertical stays at its
		# natural height (the drawer measures it to size the panel).
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_host.add_child(_content)
		if _is_open:
			_fit_panel_height()


func is_open() -> bool:
	return _is_open


## Current panel rect (position + size) in this Control's local space.
## Public so hosts can position adjacent UI relative to the open drawer.
func get_panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


## Recompute panel size/position for the current viewport + edge.
func _panel_geometry() -> Dictionary:
	var vp := get_viewport_rect().size
	var size := Vector2.ZERO
	var docked := Vector2.ZERO
	var hidden := Vector2.ZERO
	match edge:
		Edge.LEFT:
			# A reference/tools drawer is a readable column, not a half-
			# screen takeover. Width is tight; height is then shrunk to the
			# content by _fit_panel_height (vp.y here is just the cap).
			size = Vector2(_lr_width(vp.x), vp.y)
			docked = Vector2(0, 0)
			hidden = Vector2(-size.x, 0)
		Edge.RIGHT:
			size = Vector2(_lr_width(vp.x), vp.y)
			docked = Vector2(vp.x - size.x, 0)
			hidden = Vector2(vp.x, 0)
		Edge.BOTTOM:
			size = Vector2(vp.x, clampf(vp.y * 0.5, 280.0, 600.0))
			docked = Vector2(0, vp.y - size.y)
			hidden = Vector2(0, vp.y)
	return {"size": size, "docked": docked, "hidden": hidden}


## LEFT/RIGHT panel width. Default = tight reading column. When a host opts
## into a wider drawer (min_panel_width > 0), the panel grows to fit that
## content but is still clamped to half the viewport so it never takes over
## the screen (the drawer stays non-blocking with a readable map behind it).
func _lr_width(vp_x: float) -> float:
	if min_panel_width <= 0.0:
		return clampf(vp_x * 0.26, 300.0, 380.0)
	# Wide drawers are CONTENT-sized, not a viewport fraction: a unit card
	# needs ~min_panel_width regardless of monitor size, so don't let a big
	# screen balloon it into a half-screen takeover. Only shrink (capped to
	# half the viewport) on a very narrow window.
	return minf(min_panel_width, vp_x * 0.5)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	var g := _panel_geometry()
	_panel.size = g["size"]
	_panel.position = g["hidden"]
	visible = true
	_scrim.modulate.a = 0.0
	_kill_tween()
	if animate:
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(_panel, "position", g["docked"], ANIM_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_scrim, "modulate:a", 1.0, ANIM_DURATION)
	else:
		_panel.position = g["docked"]
		_scrim.modulate.a = 1.0
	opened.emit()
	# Shrink LEFT/RIGHT panels to their content (BOTTOM keeps its fixed
	# half-height). Deferred so the x-docking stays synchronous for tests.
	if edge != Edge.BOTTOM:
		call_deferred("_fit_panel_height")


## Resize a LEFT/RIGHT panel to hug its content height (clamped to
## [MIN_PANEL_H, viewport]). Tall content scrolls inside _scroll instead
## of forcing a full-height empty slab for a few lines of text.
func _fit_panel_height() -> void:
	if not _is_open or edge == Edge.BOTTOM:
		return
	if not is_inside_tree() or _content == null:
		return
	# Two frames: one to parent/measure, one for autowrap to settle at the
	# now-known panel width so _content.size.y is the real wrapped height.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _is_open or _content == null:
		return
	var vp := get_viewport_rect().size
	var chrome: float = _header.size.y + UIColors.SPACING_MD * 3.0
	var want: float = _content.size.y + chrome
	var h: float = clampf(want, MIN_PANEL_H, vp.y)
	# Re-assert the capped WIDTH/position too: even with AUTO scroll, a
	# late layout pass can momentarily widen the panel. Snap it back to the
	# geometry so a RIGHT panel never overhangs the viewport edge.
	var g := _panel_geometry()
	_panel.size = Vector2(g["size"].x, h)
	_panel.position = Vector2(g["docked"].x, 0.0)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	var g := _panel_geometry()
	_kill_tween()
	if animate and visible:
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(_panel, "position", g["hidden"], ANIM_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(_scrim, "modulate:a", 0.0, ANIM_DURATION)
		_tween.set_parallel(false)
		_tween.tween_callback(func() -> void: visible = false)
	else:
		visible = false
	closed.emit()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
