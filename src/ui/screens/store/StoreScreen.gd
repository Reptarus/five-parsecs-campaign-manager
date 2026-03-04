extends CampaignScreenBase

## Store screen displaying DLC packs available for purchase.
## Accessible from MainMenu via the Store/Library button.
## Connects to StoreManager autoload for pricing and purchase flow.

var _store_mgr: Node = null
var _dlc_mgr: Node = null
var _review_mgr: Node = null
var _card_refs: Dictionary = {}  # dlc_id -> { button, price_label, badge }
var _status_label: RichTextLabel = null
var _restore_button: Button = null
var _rate_button: Button = null

func _setup_screen() -> void:
	_store_mgr = get_node_or_null("/root/StoreManager")
	_dlc_mgr = get_node_or_null("/root/DLCManager")
	_review_mgr = get_node_or_null("/root/ReviewManager")
	_build_ui()
	_connect_store_signals()
	_refresh_all_cards()

func _build_ui() -> void:
	# Root margin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SPACING_XL)
	margin.add_theme_constant_override("margin_right", SPACING_XL)
	margin.add_theme_constant_override("margin_top", SPACING_LG)
	margin.add_theme_constant_override("margin_bottom", SPACING_LG)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override(
		"separation", SPACING_LG)
	margin.add_child(root_vbox)

	# Header
	_build_header(root_vbox)

	# Scroll area for DLC cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var cards_vbox := VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override(
		"separation", SPACING_LG)
	scroll.add_child(cards_vbox)

	# Dev mode banner (if offline)
	if _store_mgr and _store_mgr.is_offline_mode():
		var banner := _create_dev_mode_banner()
		cards_vbox.add_child(banner)

	# DLC pack cards
	var dlc_ids: Array = []
	if _store_mgr and _store_mgr.has_method("get_dlc_ids"):
		dlc_ids = _store_mgr.get_dlc_ids()
	else:
		dlc_ids = [
			"trailblazers_toolkit",
			"freelancers_handbook",
			"fixers_guidebook"]
	for dlc_id: String in dlc_ids:
		var card := _build_dlc_card(dlc_id)
		cards_vbox.add_child(card)

	# Footer
	_build_footer(root_vbox)

func _build_header(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	parent.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	back_btn.pressed.connect(_on_back_pressed)
	hbox.add_child(back_btn)

	var title := Label.new()
	title.text = "Expansions"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var sep := HSeparator.new()
	parent.add_child(sep)

func _build_dlc_card(dlc_id: String) -> PanelContainer:
	var info: Dictionary = {}
	if _store_mgr and _store_mgr.has_method("get_dlc_info"):
		info = _store_mgr.get_dlc_info(dlc_id)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	panel.add_child(vbox)

	# Title row: name + price
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(title_row)

	var name_label := Label.new()
	name_label.text = str(info.get("name", dlc_id))
	name_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)

	var price_label := Label.new()
	price_label.text = str(info.get("default_price", ""))
	price_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	price_label.add_theme_color_override(
		"font_color", COLOR_CYAN)
	title_row.add_child(price_label)

	# Description
	var desc := Label.new()
	desc.text = str(info.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(desc)

	# Feature count badge
	var feat_count: int = info.get("feature_count", 0) as int
	if feat_count > 0:
		var badge := Label.new()
		badge.text = "%d Features Included" % feat_count
		badge.add_theme_font_size_override(
			"font_size", FONT_SIZE_XS)
		badge.add_theme_color_override(
			"font_color", COLOR_ACCENT_HOVER)
		vbox.add_child(badge)

	# Action row: Buy/Owned button + Manage link
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", SPACING_MD)
	action_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(action_row)

	var is_owned: bool = info.get("is_owned", false)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	if is_owned:
		_style_owned_button(buy_btn)
	else:
		_style_buy_button(buy_btn, dlc_id)
	action_row.add_child(buy_btn)

	if is_owned:
		var manage_btn := Button.new()
		manage_btn.text = "Manage Features"
		manage_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
		manage_btn.pressed.connect(
			_on_manage_features_pressed)
		action_row.add_child(manage_btn)

	_card_refs[dlc_id] = {
		"panel": panel,
		"button": buy_btn,
		"price_label": price_label,
		"action_row": action_row,
	}

	return panel

func _build_footer(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	parent.add_child(hbox)

	_restore_button = Button.new()
	_restore_button.text = "Restore Purchases"
	_restore_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_restore_button.pressed.connect(_on_restore_pressed)
	if _store_mgr and _store_mgr.is_offline_mode():
		_restore_button.disabled = true
	hbox.add_child(_restore_button)

	# Rate button — visible on mobile platforms only
	if _review_mgr and _review_mgr.has_method("is_review_available") \
			and _review_mgr.is_review_available():
		_rate_button = Button.new()
		_rate_button.text = "Rate This App"
		_rate_button.custom_minimum_size.y = TOUCH_TARGET_MIN
		_rate_button.pressed.connect(_on_rate_pressed)
		if _review_mgr.has_method("can_request_review") \
				and not _review_mgr.can_request_review():
			_rate_button.disabled = true
		hbox.add_child(_rate_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.fit_content = true
	_status_label.custom_minimum_size = Vector2(200, 0)
	_status_label.scroll_active = false
	if _store_mgr:
		var platform: String = _store_mgr.get_platform_name()
		_status_label.text = "[color=#808080]%s[/color]" % platform
	hbox.add_child(_status_label)

func _create_dev_mode_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_WARNING.darkened(0.7)
	style.border_color = COLOR_WARNING
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "Development Mode - No store connection"
	label.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_WARNING)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

# ── Button styling ─────────────────────────────

func _style_buy_button(btn: Button, dlc_id: String) -> void:
	var price: String = ""
	if _store_mgr and _store_mgr.has_method("get_dlc_price"):
		price = _store_mgr.get_dlc_price(dlc_id)
	btn.text = "Buy %s" % price if not price.is_empty() else "Buy"
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_ACCENT_HOVER
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	# Disable if offline or purchase in progress
	if _store_mgr and _store_mgr.is_offline_mode():
		btn.disabled = true
		btn.text = "Not Available"
	else:
		btn.pressed.connect(
			_on_buy_pressed.bind(dlc_id))

func _style_owned_button(btn: Button) -> void:
	btn.text = "Owned"
	btn.disabled = true
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SUCCESS.darkened(0.3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

# ── Signal connections ─────────────────────────

func _connect_store_signals() -> void:
	if not _store_mgr:
		return
	if _store_mgr.has_signal("purchase_completed"):
		_store_mgr.purchase_completed.connect(
			_on_purchase_completed)
	if _store_mgr.has_signal("purchase_failed"):
		_store_mgr.purchase_failed.connect(
			_on_purchase_failed)
	if _store_mgr.has_signal("purchase_cancelled"):
		_store_mgr.purchase_cancelled.connect(
			_on_purchase_cancelled)
	if _store_mgr.has_signal("products_loaded"):
		_store_mgr.products_loaded.connect(
			_on_products_loaded)
	if _store_mgr.has_signal("restore_completed"):
		_store_mgr.restore_completed.connect(
			_on_restore_completed)

# ── Refresh ────────────────────────────────────

func _refresh_all_cards() -> void:
	for dlc_id: String in _card_refs:
		_refresh_card(dlc_id)

func _refresh_card(dlc_id: String) -> void:
	var refs: Dictionary = _card_refs.get(dlc_id, {})
	if refs.is_empty():
		return
	var info: Dictionary = {}
	if _store_mgr and _store_mgr.has_method("get_dlc_info"):
		info = _store_mgr.get_dlc_info(dlc_id)
	var is_owned: bool = info.get("is_owned", false)
	var btn: Button = refs.get("button") as Button
	var price_lbl: Label = refs.get("price_label") as Label
	if btn:
		# Disconnect old signals to avoid duplicates
		for conn: Dictionary in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		if is_owned:
			_style_owned_button(btn)
		else:
			_style_buy_button(btn, dlc_id)
	if price_lbl:
		var price: String = ""
		if _store_mgr:
			price = _store_mgr.get_dlc_price(dlc_id)
		if is_owned:
			price_lbl.text = ""
		elif not price.is_empty():
			price_lbl.text = price

# ── Handlers ───────────────────────────────────

func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")

func _on_buy_pressed(dlc_id: String) -> void:
	if not _store_mgr:
		return
	if _store_mgr.has_method("purchase_dlc"):
		_store_mgr.purchase_dlc(dlc_id)
	# Show loading state
	var refs: Dictionary = _card_refs.get(dlc_id, {})
	var btn: Button = refs.get("button") as Button
	if btn:
		btn.text = "Purchasing..."
		btn.disabled = true

func _on_manage_features_pressed() -> void:
	var DLCDialogScript = load(
		"res://src/ui/dialogs/DLCManagementDialog.gd")
	if DLCDialogScript:
		var dialog: AcceptDialog = DLCDialogScript.new()
		add_child(dialog)
		dialog.popup_centered()

func _on_rate_pressed() -> void:
	if _review_mgr and _review_mgr.has_method("request_review"):
		_review_mgr.request_review()
		if _rate_button:
			_rate_button.disabled = true
			_rate_button.text = "Thanks!"

func _on_restore_pressed() -> void:
	if _store_mgr and _store_mgr.has_method("restore_all_purchases"):
		_store_mgr.restore_all_purchases()
		if _restore_button:
			_restore_button.text = "Restoring..."
			_restore_button.disabled = true

func _on_purchase_completed(dlc_id: String) -> void:
	_refresh_card(dlc_id)
	_show_status("[color=#10B981]%s purchased![/color]" % (
		_get_dlc_name(dlc_id)))

func _on_purchase_failed(dlc_id: String, reason: String) -> void:
	_refresh_card(dlc_id)
	_show_status("[color=#DC2626]Purchase failed: %s[/color]" % reason)

func _on_purchase_cancelled(_dlc_id: String) -> void:
	_refresh_all_cards()
	_show_status("[color=#D97706]Purchase cancelled[/color]")

func _on_products_loaded(_products: Array[Dictionary]) -> void:
	_refresh_all_cards()

func _on_restore_completed(owned_ids: Array[String]) -> void:
	_refresh_all_cards()
	if _restore_button:
		_restore_button.text = "Restore Purchases"
		_restore_button.disabled = _store_mgr.is_offline_mode() \
			if _store_mgr else true
	if owned_ids.is_empty():
		_show_status(
			"[color=#808080]No purchases to restore[/color]")
	else:
		_show_status(
			"[color=#10B981]Restored %d purchase(s)[/color]" % (
				owned_ids.size()))

# ── Helpers ────────────────────────────────────

func _show_status(bbcode: String) -> void:
	if _status_label:
		_status_label.text = bbcode

func _get_dlc_name(dlc_id: String) -> String:
	if _store_mgr and _store_mgr.has_method("get_dlc_info"):
		var info: Dictionary = _store_mgr.get_dlc_info(dlc_id)
		return str(info.get("name", dlc_id))
	return dlc_id
