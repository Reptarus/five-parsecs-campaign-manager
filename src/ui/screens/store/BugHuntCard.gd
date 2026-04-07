extends PanelContainer

## Bug Hunt game mode marketing card for the Store screen.
## Simpler than DLCPackCard — no per-feature toggles.

signal buy_requested()
signal play_requested()

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")

const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_CYAN := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

var _action_btn: Button = null
var _is_owned: bool = false

func setup(is_owned: bool) -> void:
	_is_owned = is_owned
	_build_ui()

func refresh(is_owned: bool) -> void:
	_is_owned = is_owned
	if _action_btn:
		if is_owned:
			_style_play_button()
		else:
			_style_buy_button()

func _build_ui() -> void:
	var info: Dictionary = DLCContentCatalogRef.BUG_HUNT_INFO

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(header)

	var title := Label.new()
	title.text = info.get("name", "Bug Hunt")
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var tagline := Label.new()
	tagline.text = info.get("tagline", "")
	tagline.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	tagline.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	header.add_child(tagline)

	# Description
	var desc := Label.new()
	desc.text = info.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(desc)

	# Action
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(action_row)

	_action_btn = Button.new()
	_action_btn.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	action_row.add_child(_action_btn)

	if _is_owned:
		_style_play_button()
	else:
		_style_buy_button()

func _style_buy_button() -> void:
	if not _action_btn:
		return
	var price: String = DLCContentCatalogRef.BUG_HUNT_INFO.get(
		"price_default", "$2.99")
	_action_btn.text = "Buy %s" % price
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	_action_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_ACCENT_HOVER
	_action_btn.add_theme_stylebox_override("hover", hover)
	_action_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_action_btn.disabled = false
	for conn: Dictionary in _action_btn.pressed.get_connections():
		_action_btn.pressed.disconnect(conn.callable)
	_action_btn.pressed.connect(
		func(): buy_requested.emit())
	# Offline check
	var store: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/StoreManager") if Engine.get_main_loop() else null
	if store and store.is_offline_mode():
		_action_btn.disabled = true
		_action_btn.text = "Not Available"

func _style_play_button() -> void:
	if not _action_btn:
		return
	_action_btn.text = "Play Bug Hunt"
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SUCCESS.darkened(0.2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	_action_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_SUCCESS
	_action_btn.add_theme_stylebox_override("hover", hover)
	_action_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_action_btn.disabled = false
	for conn: Dictionary in _action_btn.pressed.get_connections():
		_action_btn.pressed.disconnect(conn.callable)
	_action_btn.pressed.connect(
		func(): play_requested.emit())
