class_name MobileAppBar
extends PanelContainer

## Portrait-only top app bar (mobile information-density: back + title + key-stat
## subtitle + a right-aligned actions slot for buttons / a ⋮ overflow menu).
## Self-hiding in landscape, so it has ZERO desktop/landscape impact.
##
## Pure-.gd component (matches the OverflowMenu / HubFeatureCard / ItemPreviewPopup
## convention — those reference `UIColors.X` directly, no scene, no preload).
##
## Adopt: instantiate, mount as the FIRST child of a screen's content VBox
## (`vbox.add_child(bar); vbox.move_child(bar, 0)`), then `setup(...)`. The bar reads
## `/root/ResponsiveManager` and is visible ONLY in portrait, re-evaluating on the
## `layout_class_changed` signal (which fires on rotation, not just bucket change).
##
## The actions slot HOSTS controls (it does not own them): a screen can REPARENT an
## existing interactive node (e.g. the dashboard's Story Points button, whose popover
## anchors to its live global rect) into the bar in portrait, then reparent it back
## to its home in landscape. `clear_actions()` removes without freeing.

signal back_pressed

var _title_label: Label
var _subtitle_label: Label
var _back_button: Button
var _actions_box: HBoxContainer
var _back_handler: Callable
var _rm: Node
var _pending: Dictionary = {}

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.set_border_width_all(0)
	style.border_width_bottom = 2          # cyan accent on the bottom edge only
	style.border_color = UIColors.COLOR_CYAN
	style.content_margin_left = UIColors.SPACING_SM
	style.content_margin_right = UIColors.SPACING_SM
	style.content_margin_top = UIColors.SPACING_XS
	style.content_margin_bottom = UIColors.SPACING_XS
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_COMFORT)

func _ready() -> void:
	_build()
	_rm = get_node_or_null("/root/ResponsiveManager")
	if _rm and _rm.has_signal("layout_class_changed") \
			and not _rm.layout_class_changed.is_connected(_on_layout_changed):
		_rm.layout_class_changed.connect(_on_layout_changed)
	if not _pending.is_empty():
		_apply_setup(_pending.get("title", ""), _pending.get("subtitle", ""), _pending.get("back", true))
		_pending.clear()
	_refresh_visibility()

func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	add_child(row)

	_back_button = Button.new()
	_back_button.text = "←"  # ←
	_back_button.flat = true
	_back_button.custom_minimum_size = Vector2(UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN)
	_back_button.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	_back_button.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	_back_button.tooltip_text = "Back"
	_back_button.pressed.connect(_on_back)
	row.add_child(_back_button)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.clip_text = true
	text_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_subtitle_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle_label.clip_text = true
	_subtitle_label.visible = false
	text_box.add_child(_subtitle_label)

	_actions_box = HBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", UIColors.SPACING_XS)
	_actions_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_actions_box)

# ── Public API ────────────────────────────────────────────────────────────────

## Chainable; defer-safe if called before _ready().
func setup(title_text: String, subtitle_text: String = "", show_back: bool = true) -> MobileAppBar:
	if _title_label == null:
		_pending = {"title": title_text, "subtitle": subtitle_text, "back": show_back}
		return self
	_apply_setup(title_text, subtitle_text, show_back)
	return self

func _apply_setup(title_text: String, subtitle_text: String, show_back: bool) -> void:
	_title_label.text = title_text
	set_subtitle(subtitle_text)
	_back_button.visible = show_back

func set_subtitle(text_value: String) -> void:
	if _subtitle_label:
		_subtitle_label.text = text_value
		_subtitle_label.visible = not text_value.is_empty()

func set_back_handler(cb: Callable) -> void:
	_back_handler = cb

## Mount a control into the right-aligned actions slot. If it already has a parent,
## it is reparented here (the caller can reparent it back later). Does NOT free.
func add_action(control: Control) -> void:
	if _actions_box == null or control == null:
		return
	var p := control.get_parent()
	if p:
		p.remove_child(control)
	_actions_box.add_child(control)

## Convenience for an OverflowMenu (or any single control) in the actions slot.
func set_overflow(menu: Control) -> void:
	add_action(menu)

## Remove all hosted action controls WITHOUT freeing them (caller may own them).
func clear_actions() -> void:
	if _actions_box == null:
		return
	for c in _actions_box.get_children():
		_actions_box.remove_child(c)

func _on_back() -> void:
	if _back_handler.is_valid():
		_back_handler.call()
	else:
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_back"):
			router.navigate_back()
		elif router and router.has_method("navigate_to"):
			router.navigate_to("main_menu")
	back_pressed.emit()

func _refresh_visibility() -> void:
	var portrait := true
	if _rm and _rm.has_method("is_portrait"):
		portrait = _rm.is_portrait()
	else:
		var vp := get_viewport()
		if vp:
			var s := vp.get_visible_rect().size
			portrait = s.y > s.x
	visible = portrait

func _on_layout_changed(_cols: int) -> void:
	_refresh_visibility()
