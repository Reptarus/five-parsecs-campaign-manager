## OrnamentPanel — rulebook-accurate panel chrome.
##
## Visual recipe extracted from the Modiphius Core Rulebook (see plan
## `modular-forging-narwhal.md`):
##   1. Rounded rectangle background (StyleBoxFlat, corner_radius=12)
##   2. Colored 2px stroke (semantic accent color)
##   3. Optional title banner sub-panel at top (rounded, same accent color,
##      uppercase title text centered in accent color)
##   4. Four corner-accent brackets at FIXED NATIVE SIZE at each corner
##      (same `ornament_br.svg` texture, mirrored via TextureRect.flip_h
##      and flip_v to produce the 4 symmetric corners)
##
## Composition tree:
##   OrnamentPanel (Control, PRESET_FULL_RECT)
##     ├── BackgroundPanel (PanelContainer, stylebox=rounded + stroke)
##     │     └── VBoxContainer
##     │           ├── BannerRow (HBoxContainer, centers the banner)
##     │           │     └── TitleBanner (PanelContainer, smaller stylebox)
##     │           │           └── Label (uppercase, accent color)
##     │           └── ContentSlot (MarginContainer — where add_content_child
##     │                 places consumer-supplied children)
##     └── OrnamentLayer (Control overlay; modulate sets all 4 accents at once)
##           └── 4× TextureRect (tl/tr/bl/br via flip_h/flip_v on one source)
##
## Why extends Control (not PanelContainer): the corner accents need to render
## OUTSIDE the panel's content rect (right at the rounded outline's corners).
## If this were a PanelContainer, the corners would be laid out INSIDE the
## stylebox's content_margin — far from the panel's actual corners. The
## Control+composition pattern is the same one BookFrame.gd uses and matches
## `docs/sop/component-patterns.md`.
##
## Path-loaded (no class_name) per `docs/sop/component-patterns.md`.
## Consumers: `preload("res://src/ui/components/common/OrnamentPanel.gd").new()`
extends Control

## Two 9-slice atlases — pick based on panel size. The 64px-corner standard
## variant looks great on panels >= ~256px, but its corners eat too much
## visual space on stat-card-sized panels (<~256px). The 32px-corner compact
## variant is for those. Both produced by scripts/build_ornament_9slice_atlas.py.
const ATLAS_STANDARD := preload(
		"res://assets/ui/borders/ornament_atlas_9slice.png")
const ATLAS_STANDARD_CORNER := 64

const ATLAS_COMPACT := preload(
		"res://assets/ui/borders/ornament_atlas_compact.png")
const ATLAS_COMPACT_CORNER := 32

## Panels narrower (or shorter) than this auto-switch to the compact atlas.
## Tuned so the corner art occupies <= ~25% of the panel's shorter axis.
const COMPACT_THRESHOLD := 256

const CORNER_RADIUS := 12  ## rounded-rect corner radius for panel + banner
const BORDER_WIDTH := 2    ## stroke thickness (rulebook reads as ~2px)

## Extra breathing room added BEYOND the corner-art height to compute the
## vertical content padding. Horizontal padding stays constant (corner art
## only spans the corner regions, not full left/right edges).
const PADDING_BREATHING := 8

## Horizontal interior padding (constant — corner art doesn't span the
## full left/right edges, so the content's left/right doesn't conflict with
## anything except the small corner-fragment top/bottom tips).
const PADDING_HORIZONTAL := 18

## 5 semantic colors observed in the rulebook (cyan default, plus red, gold,
## purple, green). Mirror BaseCampaignPanel palette for consistency.
const COLOR_NEUTRAL := Color("#E0E0E0")
const COLOR_PRIMARY := Color("#4FC3F7")  ## cyan — rulebook default
const COLOR_SUCCESS := Color("#10B981")  ## green
const COLOR_WARNING := Color("#D97706")  ## gold/amber
const COLOR_DANGER  := Color("#DC2626")  ## red — Character Creation etc.
const COLOR_PURPLE  := Color("#9333EA")  ## GM appendix accent

const BG_COLOR := Color("#252542")  ## matches existing glass-card bg

@export var accent_color: Color = COLOR_PRIMARY:
	set(value):
		accent_color = value
		if _panel:
			_apply_accent_color()

@export var title_text: String = "":
	set(value):
		title_text = value
		if _banner_label:
			_apply_title_text()

@export var show_ornaments: bool = true:
	set(value):
		show_ornaments = value
		if _ornament_layer:
			_ornament_layer.visible = value

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _banner_row: HBoxContainer = null
var _banner: PanelContainer = null
var _banner_label: Label = null
var _content_slot: MarginContainer = null
var _ornament_layer: Control = null

## Atlas variant resolved once at _ready() and used by both _build_panel
## (for content_margin sizing) and _build_ornament_layer (for the texture
## + patch_margin). Picking once avoids size-thrash if the panel ever
## resizes (we keep the corner art at native size regardless of resize).
var _active_atlas: Texture2D = null
var _active_corner_size: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resolve_atlas_variant()
	_build_panel()
	_build_ornament_layer()
	_apply_accent_color()
	_apply_title_text()
	_ornament_layer.visible = show_ornaments


## Decide compact vs standard atlas based on the consumer's declared
## min size. The shorter axis determines the choice — a tall narrow panel
## still uses compact corners so they don't dominate horizontally.
func _resolve_atlas_variant() -> void:
	var min_size := custom_minimum_size
	var shorter_axis: float = 9999.0
	if min_size.x > 0 and min_size.y > 0:
		shorter_axis = min(min_size.x, min_size.y)
	elif min_size.x > 0:
		shorter_axis = min_size.x
	elif min_size.y > 0:
		shorter_axis = min_size.y
	if shorter_axis < COMPACT_THRESHOLD:
		_active_atlas = ATLAS_COMPACT
		_active_corner_size = ATLAS_COMPACT_CORNER
	else:
		_active_atlas = ATLAS_STANDARD
		_active_corner_size = ATLAS_STANDARD_CORNER


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", _make_panel_stylebox())
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(_vbox)

	_banner_row = HBoxContainer.new()
	_banner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_row.visible = false  # only shows when title_text is non-empty
	_vbox.add_child(_banner_row)

	_banner = PanelContainer.new()
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner.add_theme_stylebox_override("panel", _make_banner_stylebox())
	_banner_row.add_child(_banner)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Banner font scales with atlas variant: smaller on compact panels so
	# the title doesn't compete with the body for visual weight.
	var banner_font_size: int = 14 if _active_atlas == ATLAS_COMPACT else 18
	_banner_label.add_theme_font_size_override("font_size", banner_font_size)
	_banner.add_child(_banner_label)

	_content_slot = MarginContainer.new()
	_content_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_content_slot)


## Builds the single NinePatchRect that paints 4 corner brackets from a
## pre-composited 9-slice atlas. Corners stay pixel-perfect at any panel
## size (Godot 4.6 NinePatchRect docs: "leaves the corners unchanged" on
## scale). Edges in the atlas are transparent (rulebook's dominant callout
## pattern is corners-only), so only the 4 corner brackets render — body
## is fully unobstructed.
##
## Atlas variant is already resolved at _ready() (see _resolve_atlas_variant);
## this just instantiates the NinePatchRect with the chosen atlas + patch
## margins. Corners stay pixel-perfect at any panel size (Godot 4.6
## NinePatchRect docs: "leaves the corners unchanged" on scale).
func _build_ornament_layer() -> void:
	_ornament_layer = NinePatchRect.new()
	_ornament_layer.name = "OrnamentLayer"
	_ornament_layer.texture = _active_atlas
	_ornament_layer.patch_margin_left = _active_corner_size
	_ornament_layer.patch_margin_top = _active_corner_size
	_ornament_layer.patch_margin_right = _active_corner_size
	_ornament_layer.patch_margin_bottom = _active_corner_size
	_ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ornament_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ornament_layer)  # rendered ABOVE _panel (later child = front)


func _make_panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = accent_color
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(CORNER_RADIUS)
	# Vertical padding must clear the corner art (which extends down from
	# the top edge by _active_corner_size pixels, and up from the bottom
	# edge by the same). Horizontal padding stays constant — corner art
	# only intrudes into the very top/bottom of left/right edges.
	var vertical: int = _active_corner_size + PADDING_BREATHING
	sb.content_margin_left = PADDING_HORIZONTAL
	sb.content_margin_right = PADDING_HORIZONTAL
	sb.content_margin_top = vertical
	sb.content_margin_bottom = vertical
	return sb


func _make_banner_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = accent_color
	sb.set_border_width_all(BORDER_WIDTH)
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Single update path: both stroke colors (panel + banner) and ornament
## modulate move together. Called from accent_color setter once _ready ran.
func _apply_accent_color() -> void:
	var panel_sb := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_sb:
		panel_sb.border_color = accent_color
	if _banner:
		var banner_sb := _banner.get_theme_stylebox("panel") as StyleBoxFlat
		if banner_sb:
			banner_sb.border_color = accent_color
	if _banner_label:
		_banner_label.add_theme_color_override("font_color", accent_color)
	if _ornament_layer:
		_ornament_layer.modulate = accent_color


func _apply_title_text() -> void:
	_banner_label.text = title_text.to_upper()
	_banner_row.visible = title_text.length() > 0


## Slot consumer-supplied content into the area below the title banner.
## Pass a single VBoxContainer/HBoxContainer for complex layouts.
func add_content_child(content: Control) -> void:
	if not _content_slot:
		ready.connect(func(): _content_slot.add_child(content),
				CONNECT_ONE_SHOT)
		return
	_content_slot.add_child(content)


## Convenience builder: set title + color + slot content in one call.
func setup(title: String, content: Control,
		color: Color = COLOR_PRIMARY) -> void:
	title_text = title
	accent_color = color
	add_content_child(content)
