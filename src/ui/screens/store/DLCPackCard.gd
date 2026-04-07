extends PanelContainer

## Rich expansion pack card for the Store screen.
## Shows marketing copy, feature list, and buy/manage actions.
## Two states: pre-purchase (buy) and post-purchase (owned + manage).

signal buy_requested(dlc_id: String)
signal manage_requested(dlc_id: String)

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")

# Design tokens
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
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
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

var _dlc_id: String = ""
var _is_owned: bool = false
var _details_expanded: bool = false
var _buy_btn: Button = null
var _details_toggle: Button = null
var _features_container: VBoxContainer = null
var _price_label: Label = null
var _enabled_badge: Label = null

func setup(dlc_id: String) -> void:
	_dlc_id = dlc_id
	_build_ui()

func refresh(is_owned: bool, price: String, enabled_count: int,
		total_count: int) -> void:
	_is_owned = is_owned
	if _buy_btn:
		if is_owned:
			_style_owned_button()
		else:
			_style_buy_button(price)
	if _price_label:
		_price_label.text = "" if is_owned else price
	if _enabled_badge:
		if is_owned:
			_enabled_badge.text = "%d / %d enabled" % [
				enabled_count, total_count]
			_enabled_badge.visible = true
		else:
			_enabled_badge.visible = false
	# Show features when owned
	if is_owned and _features_container:
		_features_container.visible = true
		_details_expanded = true
		if _details_toggle:
			_details_toggle.text = "Hide Details"

func _build_ui() -> void:
	var catalog: Dictionary = DLCContentCatalogRef.get_pack_catalog(
		_dlc_id)
	if catalog.is_empty():
		return

	# Card style
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

	# Header row: name + tagline + price
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(header)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header.add_child(title_col)

	var name_lbl := Label.new()
	name_lbl.text = catalog.get("name", _dlc_id)
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	title_col.add_child(name_lbl)

	var tagline_lbl := Label.new()
	tagline_lbl.text = catalog.get("tagline", "")
	tagline_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	tagline_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	title_col.add_child(tagline_lbl)

	_price_label = Label.new()
	_price_label.text = catalog.get("price_default", "")
	_price_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	_price_label.add_theme_color_override("font_color", COLOR_CYAN)
	header.add_child(_price_label)

	# Description
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = catalog.get("description", "")
	desc.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM)
	desc.add_theme_color_override(
		"default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(desc)

	# Enabled count badge (post-purchase)
	_enabled_badge = Label.new()
	_enabled_badge.visible = false
	_enabled_badge.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)
	_enabled_badge.add_theme_color_override(
		"font_color", COLOR_ACCENT_HOVER)
	vbox.add_child(_enabled_badge)

	# Feature details toggle
	_details_toggle = Button.new()
	_details_toggle.text = "Show Details"
	_details_toggle.flat = true
	_details_toggle.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	_details_toggle.add_theme_color_override(
		"font_color", COLOR_CYAN)
	_details_toggle.custom_minimum_size.y = TOUCH_TARGET_MIN
	_details_toggle.pressed.connect(_on_details_toggled)
	vbox.add_child(_details_toggle)

	# Feature list (hidden by default for pre-purchase)
	_features_container = VBoxContainer.new()
	_features_container.visible = false
	_features_container.add_theme_constant_override(
		"separation", 2)
	vbox.add_child(_features_container)

	_build_feature_list(catalog)

	# Action row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", SPACING_MD)
	action_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(action_row)

	_buy_btn = Button.new()
	_buy_btn.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	action_row.add_child(_buy_btn)
	_style_buy_button(catalog.get("price_default", ""))

func _build_feature_list(catalog: Dictionary) -> void:
	var categories: Array = catalog.get("categories", [])
	for cat: Variant in categories:
		var cat_dict: Dictionary = cat as Dictionary
		var cat_name: String = cat_dict.get("name", "")

		var cat_label := Label.new()
		cat_label.text = cat_name
		cat_label.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		cat_label.add_theme_color_override(
			"font_color", COLOR_ACCENT)
		_features_container.add_child(cat_label)

		var features: Array = cat_dict.get("features", [])
		for f: Variant in features:
			var feat: Dictionary = f as Dictionary
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", SPACING_SM)
			_features_container.add_child(row)

			var bullet := Label.new()
			bullet.text = "  ·"
			bullet.add_theme_font_size_override(
				"font_size", FONT_SIZE_SM)
			bullet.add_theme_color_override(
				"font_color", COLOR_TEXT_MUTED)
			row.add_child(bullet)

			var feat_label := Label.new()
			feat_label.text = "%s — %s" % [
				feat.get("label", ""),
				feat.get("preview", "")]
			feat_label.add_theme_font_size_override(
				"font_size", FONT_SIZE_SM)
			feat_label.add_theme_color_override(
				"font_color", COLOR_TEXT_SECONDARY)
			feat_label.autowrap_mode = (
				TextServer.AUTOWRAP_WORD_SMART)
			feat_label.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL)
			row.add_child(feat_label)

func _style_buy_button(price: String) -> void:
	if not _buy_btn:
		return
	_buy_btn.text = "Buy %s" % price if price else "Buy"
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	_buy_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_ACCENT_HOVER
	_buy_btn.add_theme_stylebox_override("hover", hover)
	_buy_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_buy_btn.disabled = false
	# Reconnect
	for conn: Dictionary in _buy_btn.pressed.get_connections():
		_buy_btn.pressed.disconnect(conn.callable)
	_buy_btn.pressed.connect(
		func(): buy_requested.emit(_dlc_id))

	# Check offline
	var store: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/StoreManager") if Engine.get_main_loop() else null
	if store and store.is_offline_mode():
		_buy_btn.disabled = true
		_buy_btn.text = "Not Available"

func _style_owned_button() -> void:
	if not _buy_btn:
		return
	_buy_btn.text = "Manage Features"
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SUCCESS.darkened(0.3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	_buy_btn.add_theme_stylebox_override("normal", style)
	_buy_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_buy_btn.disabled = false
	for conn: Dictionary in _buy_btn.pressed.get_connections():
		_buy_btn.pressed.disconnect(conn.callable)
	_buy_btn.pressed.connect(
		func(): manage_requested.emit(_dlc_id))

func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	if _features_container:
		_features_container.visible = _details_expanded
	if _details_toggle:
		_details_toggle.text = (
			"Hide Details" if _details_expanded else "Show Details")
