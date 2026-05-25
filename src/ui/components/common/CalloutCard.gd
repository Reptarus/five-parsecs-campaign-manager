## CalloutCard - "callout box" style card matching the rulebook's
## boxed-out sections (e.g., the "Elite Ranks" yellow-bordered box visible
## in Campaign Preparation, Core Rules p.65).
##
## Visual recipe (per rulebook layout review 2026-05-23):
##   - Thick colored rectangular border (2px, semantic color)
##   - Sharp corners (no rounding — rulebook callouts are angular)
##   - Title in matching border color, UPPERCASE, top-left inside the border
##   - Body content below title with comfortable spacing
##   - Bg = COLOR_ELEVATED (matches existing glass card bg for continuity)
##
## NO SVG assets — pure StyleBoxFlat + Label composition. The .ai border
## ornaments are PAGE-level chrome (handled by BookFrame); CalloutCard is
## CARD-level chrome (handled here).
##
## Path-loaded (no class_name) per docs/sop/component-patterns.md.
## Consumers: preload + .new(), then add_content_child(<vbox or label>).
extends PanelContainer

## Pre-defined semantic color tokens. Mirror BookFrame's palette so the two
## layers (page chrome + callout cards) read as one design system.
const COLOR_NEUTRAL := Color("#E0E0E0")
const COLOR_PRIMARY := Color("#4FC3F7")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER  := Color("#DC2626")

## StyleBox geometry, tuned to match the rulebook's "Elite Ranks" callout.
const BORDER_WIDTH := 2
const CORNER_RADIUS := 0  ## sharp corners (rulebook callouts are angular)
const PADDING_HORIZONTAL := 16
const PADDING_TOP := 16  ## title sits near top edge but doesn't overlap border
const PADDING_BOTTOM := 16
const TITLE_FONT_SIZE := 18
const TITLE_BODY_SEPARATION := 8

const BG_COLOR := Color("#252542")  ## matches existing glass card bg

@export var border_color: Color = COLOR_WARNING:
	set(value):
		border_color = value
		_apply_style()
		_apply_title_color()

@export var title_text: String = "":
	set(value):
		title_text = value
		if _title_label:
			_title_label.text = value.to_upper()

var _title_label: Label = null
var _vbox: VBoxContainer = null


func _ready() -> void:
	_build_layout()
	_apply_style()
	_apply_title_color()


func _build_layout() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", TITLE_BODY_SEPARATION)
	add_child(_vbox)

	_title_label = Label.new()
	_title_label.text = title_text.to_upper()
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_vbox.add_child(_title_label)


func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = border_color
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = PADDING_HORIZONTAL
	sb.content_margin_right = PADDING_HORIZONTAL
	sb.content_margin_top = PADDING_TOP
	sb.content_margin_bottom = PADDING_BOTTOM
	add_theme_stylebox_override("panel", sb)


func _apply_title_color() -> void:
	if _title_label:
		_title_label.add_theme_color_override("font_color", border_color)


## Convenience builder: set title + color + slot content in one call.
func setup(title: String, content: Control, color: Color = COLOR_WARNING) -> void:
	title_text = title
	border_color = color
	add_content_child(content)


## Add a child to the content area (below the title). For complex layouts,
## pass a single VBoxContainer/HBoxContainer that holds the inner widgets.
## Adding multiple children works (they stack in the VBox); the title
## remains the first child.
func add_content_child(content: Control) -> void:
	if not _vbox:
		ready.connect(func(): _vbox.add_child(content), CONNECT_ONE_SHOT)
		return
	_vbox.add_child(content)
