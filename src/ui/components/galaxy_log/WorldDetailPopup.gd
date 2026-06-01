extends Window

## Window popup that shows a single PlanetData in full detail. Used by the
## Galaxy Log when the player clicks a hex.
##
## Body content is rendered by PlanetDetailBuilder.build_into() — the same
## utility CampaignDashboard's current-world overlay uses. Result: dashboard
## and popup always render identically.
##
## Static factory `show_for(parent, planet)` sizes the Window BEFORE
## popup_centered() to dodge the Window-_ready race documented in
## reference_godot_window_ready_race.md and demonstrated by ItemPreviewPopup.

const UIColorsClass := preload("res://src/ui/components/base/UIColors.gd")
const PlanetDetailBuilderClass := preload(
	"res://src/core/world/PlanetDetailBuilder.gd"
)

var _pending_planet: Object = null
var _vbox: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	title = ""
	transient = true
	exclusive = false  # Non-blocking: hexmap remains interactive behind.
	unresizable = true
	borderless = true  # Hide native title bar; use only the internal CLOSE button.
	close_requested.connect(_on_close)


func _ready() -> void:
	# Defensive size fallback in case factory wasn't used.
	if size.x < 200 or size.y < 200:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		size = Vector2i(
			mini(480, int(vp.x * 0.7)),
			mini(640, int(vp.y * 0.85))
		)
	_build_ui()
	if _pending_planet:
		_populate(_pending_planet)


func _build_ui() -> void:
	# Background panel with sci-fi border.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = UIColorsClass.COLOR_BASE
	style.border_color = UIColorsClass.COLOR_CYAN
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UIColorsClass.SPACING_MD)
	margin.add_theme_constant_override("margin_right", UIColorsClass.SPACING_MD)
	margin.add_theme_constant_override("margin_top", UIColorsClass.SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", UIColorsClass.SPACING_MD)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIColorsClass.SPACING_SM)
	margin.add_child(outer)

	# Scrollable body — planet detail can be long if there are many journal
	# entries or world events. Disable horizontal scroll so column layout
	# behaves like the dashboard overlay.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", UIColorsClass.SPACING_MD)
	_scroll.add_child(_vbox)

	# Footer close button.
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0, UIColorsClass.TOUCH_TARGET_MIN)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIColorsClass.COLOR_ACCENT
	btn_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_color_override(
		"font_color", UIColorsClass.COLOR_TEXT_PRIMARY
	)
	close_btn.add_theme_font_size_override(
		"font_size", UIColorsClass.FONT_SIZE_MD
	)
	close_btn.pressed.connect(_on_close)
	outer.add_child(close_btn)


func _populate(planet: Object) -> void:
	if not _vbox or not planet:
		return
	# Clear any prior content so show_for() with a new planet works.
	for child in _vbox.get_children():
		child.queue_free()
	# Delegate all the section rendering to the shared builder.
	PlanetDetailBuilderClass.build_into(_vbox, planet, self)


func _on_close() -> void:
	queue_free()


## Show a world-detail popup for the given planet. Sizes the Window BEFORE
## popup_centered() to dodge the Window-_ready race (popup_centered fires
## synchronously after add_child; _ready is deferred). Mirrors the pattern
## documented at ItemPreviewPopup.show_preview().
static func show_for(parent: Node, planet: Object) -> Window:
	var Self = load("res://src/ui/components/galaxy_log/WorldDetailPopup.gd")
	var popup = Self.new()
	popup._pending_planet = planet
	parent.add_child(popup)
	var vp: Vector2 = parent.get_viewport().get_visible_rect().size
	var target_size := Vector2i(
		mini(480, int(vp.x * 0.7)),
		mini(640, int(vp.y * 0.85))
	)
	popup.popup_centered(target_size)
	return popup
