## BookFrame - wraps any child Control with the book-style ornamental chrome
## extracted from the Modiphius rulebook borders.
##
## Architecture (per docs/design — Phase 2 BookFrame plan):
##   BookFrame (extends Control)
##     ├── BackgroundPanel (PanelContainer — existing glass-card StyleBox)
##     │   └── ContentMargin (MarginContainer — ornament-clearance padding)
##     │       └── <consumer-supplied content>
##     └── OrnamentLayer (Control — modulate sets all ornament tints at once)
##         └── ~10 TextureRects, each anchored to its corner/edge position
##             at native size (no stretching).
##
## Source assets: res://assets/ui/borders/ornaments/ornament_*.svg (10 files,
## extracted from White master via Inkscape --shell mode, Phase 1b).
##
## Color: panels use a single White SVG asset and modulate the OrnamentLayer
## to any color. Color cascades to all child TextureRects via Godot's
## standard modulate inheritance — one property sets all 10 ornaments.
##
## Path-loaded (no class_name) per docs/sop/component-patterns.md.
## Consumers: preload("res://src/ui/components/common/BookFrame.gd").new()
extends Control

const ORNAMENT_DIR := "res://assets/ui/borders/ornaments/"
const CONTENT_MARGIN := 80  ## page-scale ornament-clearance padding inside frame

## Edge-ornament inset from the nearest corner, in pixels. Pulls rt/rb
## inward from the corner so they sit at "edge-near-corner" position.
## Tuned visually in test scene against page-scale BookFrame use.
const EDGE_INSET := 80

## Short-ID list of all ornament positions actually present in the extracted
## SVG set (merge_distance=100 produced 6 real ornaments + 1 purple registration
## artifact which was filtered out). The 10-id-original-plan list (tr, lt, lb,
## bm) was reduced because composites merged at the chosen clustering distance
## and one was an Illustrator artifact.
const ORNAMENT_IDS: Array[String] = [
	"tl", "tm",
	"rt", "rb",
	"bl", "br",
]

## Semantic color tokens mirroring BaseCampaignPanel.gd palette so the book
## chrome reads as an extension of the existing visual language.
const COLOR_NEUTRAL := Color("#E0E0E0")   ## generic, default
const COLOR_PRIMARY := Color("#4FC3F7")   ## primary narrative / focus
const COLOR_SUCCESS := Color("#10B981")   ## owned / positive
const COLOR_WARNING := Color("#D97706")   ## caution / low resources
const COLOR_DANGER  := Color("#DC2626")   ## hostile / critical

## Glass card StyleBox copied from BaseCampaignPanel._create_glass_card_style()
## so BookFrame can be used standalone without inheriting from a campaign panel.
const BG_COLOR := Color("#252542")
const BORDER_COLOR := Color("#3A3A5C")

@export var border_color: Color = COLOR_NEUTRAL:
	set(value):
		border_color = value
		if _ornament_layer:
			_ornament_layer.modulate = value

## Per-instance opt-out for individual ornaments. Defaults to all 10 visible.
## Example: ["tl", "tr", "bl", "br"] = corners only.
@export var show_ornaments: PackedStringArray = PackedStringArray(ORNAMENT_IDS):
	set(value):
		show_ornaments = value
		if _ornament_layer:
			_apply_ornament_visibility()

## When false, the inner background panel is hidden and only the ornament
## overlay renders. Use this mode to LAYER a BookFrame's ornaments over an
## existing UI scene without disrupting its layout — e.g., add a BookFrame
## as the last child of CampaignDashboard's root with `show_background = false`
## to overlay ornaments on the existing 3-column dashboard.
## Defaults true (standalone wrapper mode used by the test scene and any
## consumer that adds child content via `add_content_child`).
@export var show_background: bool = true:
	set(value):
		show_background = value
		if _background_panel:
			_background_panel.visible = value

var _background_panel: PanelContainer = null
var _content_margin: MarginContainer = null
var _ornament_layer: Control = null
var _ornament_rects: Dictionary = {}  ## short_id -> TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_background_panel.visible = show_background  # re-apply in case setter ran before _ready
	_build_ornament_layer()
	_ornament_layer.modulate = border_color
	_apply_ornament_visibility()


func _build_background() -> void:
	_background_panel = PanelContainer.new()
	_background_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_panel.add_theme_stylebox_override("panel", _make_glass_stylebox())
	add_child(_background_panel)

	_content_margin = MarginContainer.new()
	_content_margin.add_theme_constant_override("margin_left", CONTENT_MARGIN)
	_content_margin.add_theme_constant_override("margin_right", CONTENT_MARGIN)
	_content_margin.add_theme_constant_override("margin_top", CONTENT_MARGIN)
	_content_margin.add_theme_constant_override("margin_bottom", CONTENT_MARGIN)
	_background_panel.add_child(_content_margin)


func _build_ornament_layer() -> void:
	_ornament_layer = Control.new()
	_ornament_layer.name = "OrnamentLayer"
	_ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ornament_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ornament_layer)

	for short_id in ORNAMENT_IDS:
		var rect := _make_ornament_rect(short_id)
		if rect:
			_ornament_layer.add_child(rect)
			_ornament_rects[short_id] = rect


## Builds and anchors one TextureRect for the given short-id ornament.
## Returns null and logs nothing if the source SVG is missing — this is
## the intentional "silent fallback" pattern: the background panel still
## renders, just without the book chrome.
func _make_ornament_rect(short_id: String) -> TextureRect:
	var path := ORNAMENT_DIR + "ornament_" + short_id + ".svg"
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if not tex:
		return null

	var rect := TextureRect.new()
	rect.name = "ornament_" + short_id
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_apply_anchor(rect, short_id)
	return rect


## Anchor an ornament at a (anchor_x, anchor_y) fractional position in parent
## with the rect's corresponding edge/corner aligned to that anchor. Uses the
## canonical Godot 4 "centering a TextureRect" pattern (explicit four offsets
## relative to texture size) rather than presets — more robust because it
## doesn't depend on PRESET_MODE_MINSIZE picking up texture size from
## EXPAND_KEEP_SIZE before the rect is in a tree.
##
##   anchor_x=0   -> rect's LEFT aligns with anchor x
##   anchor_x=0.5 -> rect's CENTER aligns with anchor x
##   anchor_x=1   -> rect's RIGHT aligns with anchor x
## Same logic for anchor_y. Optional pixel offset (offset_x, offset_y)
## translates the rect away from the anchor (e.g., EDGE_INSET for edge-mid
## ornaments that should sit "near" a corner, not on top of it).
func _anchor_at(rect: TextureRect, anchor_x: float, anchor_y: float,
		offset_x: float = 0.0, offset_y: float = 0.0) -> void:
	var tex_size := rect.texture.get_size()
	rect.anchor_left = anchor_x
	rect.anchor_right = anchor_x
	rect.anchor_top = anchor_y
	rect.anchor_bottom = anchor_y
	var dx := -anchor_x * tex_size.x + offset_x
	var dy := -anchor_y * tex_size.y + offset_y
	rect.offset_left = dx
	rect.offset_right = dx + tex_size.x
	rect.offset_top = dy
	rect.offset_bottom = dy + tex_size.y


## Anchor mapping per ornament short-id. Edge-mid pieces (lt/lb/rt/rb) sit
## near the nearest corner with an EDGE_INSET pixel offset on the long axis.
func _apply_anchor(rect: TextureRect, short_id: String) -> void:
	match short_id:
		"tl": _anchor_at(rect, 0.0, 0.0)
		"tm": _anchor_at(rect, 0.5, 0.0)
		"tr": _anchor_at(rect, 1.0, 0.0)
		"rt": _anchor_at(rect, 1.0, 0.0, 0.0, EDGE_INSET)
		"rb": _anchor_at(rect, 1.0, 1.0, 0.0, -EDGE_INSET)
		"bl": _anchor_at(rect, 0.0, 1.0)
		"bm": _anchor_at(rect, 0.5, 1.0)
		"br": _anchor_at(rect, 1.0, 1.0)
		"lt": _anchor_at(rect, 0.0, 0.0, 0.0, EDGE_INSET)
		"lb": _anchor_at(rect, 0.0, 1.0, 0.0, -EDGE_INSET)


func _apply_ornament_visibility() -> void:
	var visible_set := {}
	for s in show_ornaments:
		visible_set[s] = true
	for short_id in _ornament_rects:
		var r: TextureRect = _ornament_rects[short_id]
		r.visible = visible_set.has(short_id)


func _make_glass_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = BORDER_COLOR
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb


## Convenience builder: wrap content and set color in one call.
func setup(content: Control, color: Color = COLOR_NEUTRAL) -> void:
	add_content_child(content)
	border_color = color


## Slot a child Control into the content margin (the area inside the
## ornaments). Add multiple children if needed — they stack via
## MarginContainer's default behavior. For complex layouts, pass a
## VBoxContainer or HBoxContainer as the single child.
func add_content_child(content: Control) -> void:
	if not _content_margin:
		# _ready hasn't run yet — defer until tree-ready
		ready.connect(func(): _content_margin.add_child(content), CONNECT_ONE_SHOT)
		return
	_content_margin.add_child(content)
