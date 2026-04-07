extends CampaignScreenBase

## Store / Expansions screen — DLC packs, bundle, Bug Hunt game mode.
## Accessible from MainMenu via SceneRouter key "store".
## Uses DLCPackCard, BundleCard, BugHuntCard components.

const DLCPackCardScript = preload(
	"res://src/ui/screens/store/DLCPackCard.gd")
const BundleCardScript = preload(
	"res://src/ui/screens/store/BundleCard.gd")
const BugHuntCardScript = preload(
	"res://src/ui/screens/store/BugHuntCard.gd")
const DLCDialogScript = preload(
	"res://src/ui/dialogs/DLCManagementDialog.gd")

var _store_mgr: Node = null
var _dlc_mgr: Node = null
var _review_mgr: Node = null

var _pack_cards: Dictionary = {}  # dlc_id -> DLCPackCard
var _bundle_card: PanelContainer = null
var _bug_hunt_card: PanelContainer = null
var _status_label: RichTextLabel = null
var _restore_button: Button = null

func _setup_screen() -> void:
	_store_mgr = get_node_or_null("/root/StoreManager")
	_dlc_mgr = get_node_or_null("/root/DLCManager")
	_review_mgr = get_node_or_null("/root/ReviewManager")
	_build_ui()
	_connect_store_signals()
	_refresh_all()

func _build_ui() -> void:
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

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED)
	root_vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(
		"separation", SPACING_LG)
	scroll.add_child(content)

	# Dev mode banner
	if _store_mgr and _store_mgr.is_offline_mode():
		content.add_child(_create_dev_banner())

	# Bundle card (hidden if all 3 owned)
	var bundle_info: Dictionary = {}
	if _store_mgr and _store_mgr.has_method("get_bundle_info"):
		bundle_info = _store_mgr.get_bundle_info()
	_bundle_card = BundleCardScript.new()
	_bundle_card.setup(bundle_info)
	_bundle_card.bundle_buy_requested.connect(
		_on_bundle_buy_pressed)
	content.add_child(_bundle_card)

	# Section: Expansions
	var exp_header := Label.new()
	exp_header.text = "Compendium Expansions"
	exp_header.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	exp_header.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	content.add_child(exp_header)

	# DLC pack cards
	for dlc_id: String in ["trailblazers_toolkit",
			"freelancers_handbook", "fixers_guidebook"]:
		var card: PanelContainer = DLCPackCardScript.new()
		card.setup(dlc_id)
		card.buy_requested.connect(_on_buy_pressed)
		card.manage_requested.connect(
			_on_manage_features_pressed)
		content.add_child(card)
		_pack_cards[dlc_id] = card

	# Section: Game Modes
	var modes_sep := HSeparator.new()
	content.add_child(modes_sep)

	var modes_header := Label.new()
	modes_header.text = "Game Modes"
	modes_header.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	modes_header.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	content.add_child(modes_header)

	var bh_owned: bool = false
	if _dlc_mgr and _dlc_mgr.has_method("has_dlc"):
		bh_owned = _dlc_mgr.has_dlc("bug_hunt")
	_bug_hunt_card = BugHuntCardScript.new()
	_bug_hunt_card.setup(bh_owned)
	_bug_hunt_card.buy_requested.connect(
		_on_bug_hunt_buy_pressed)
	_bug_hunt_card.play_requested.connect(
		_on_bug_hunt_play_pressed)
	content.add_child(_bug_hunt_card)

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
	title.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	# Help link (Library was relocated here)
	var help_btn := Button.new()
	help_btn.text = "Help"
	help_btn.flat = true
	help_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	help_btn.pressed.connect(_on_help_pressed)
	hbox.add_child(help_btn)

	parent.add_child(HSeparator.new())

func _build_footer(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

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

	# Rate button (mobile only)
	if _review_mgr \
			and _review_mgr.has_method("is_review_available") \
			and _review_mgr.is_review_available():
		var rate_btn := Button.new()
		rate_btn.text = "Rate This App"
		rate_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
		rate_btn.pressed.connect(_on_rate_pressed.bind(rate_btn))
		if _review_mgr.has_method("can_request_review") \
				and not _review_mgr.can_request_review():
			rate_btn.disabled = true
		hbox.add_child(rate_btn)

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
		_status_label.text = (
			"[color=#808080]%s[/color]" % platform)
	hbox.add_child(_status_label)

func _create_dev_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_AMBER.darkened(0.7)
	style.border_color = COLOR_AMBER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "Development Mode — No store connection"
	label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	label.add_theme_color_override("font_color", COLOR_AMBER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

# ── Refresh ────────────────────────────────────────────────────

func _refresh_all() -> void:
	for dlc_id: String in _pack_cards:
		_refresh_pack_card(dlc_id)
	_refresh_bundle()
	_refresh_bug_hunt()

func _refresh_pack_card(dlc_id: String) -> void:
	var card: Variant = _pack_cards.get(dlc_id)
	if not card:
		return
	var is_owned: bool = false
	if _dlc_mgr and _dlc_mgr.has_method("has_dlc"):
		is_owned = _dlc_mgr.has_dlc(dlc_id)
	var price: String = ""
	if _store_mgr and _store_mgr.has_method("get_dlc_price"):
		price = _store_mgr.get_dlc_price(dlc_id)
	var enabled := 0
	var total := 0
	if _dlc_mgr:
		if _dlc_mgr.has_method("get_enabled_count_for_dlc"):
			enabled = _dlc_mgr.get_enabled_count_for_dlc(dlc_id)
		if _dlc_mgr.has_method("get_features_for_dlc"):
			total = _dlc_mgr.get_features_for_dlc(dlc_id).size()
	card.refresh(is_owned, price, enabled, total)

func _refresh_bundle() -> void:
	if not _bundle_card:
		return
	var info: Dictionary = {}
	if _store_mgr and _store_mgr.has_method("get_bundle_info"):
		info = _store_mgr.get_bundle_info()
	_bundle_card.refresh(info)

func _refresh_bug_hunt() -> void:
	if not _bug_hunt_card:
		return
	var owned: bool = false
	if _dlc_mgr and _dlc_mgr.has_method("has_dlc"):
		owned = _dlc_mgr.has_dlc("bug_hunt")
	_bug_hunt_card.refresh(owned)

# ── Signal connections ─────────────────────────────────────────

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

# ── Handlers ───────────────────────────────────────────────────

func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")

func _on_help_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("help")

func _on_buy_pressed(dlc_id: String) -> void:
	if _store_mgr and _store_mgr.has_method("purchase_dlc"):
		_store_mgr.purchase_dlc(dlc_id)

func _on_bundle_buy_pressed() -> void:
	if _store_mgr and _store_mgr.has_method("purchase_dlc"):
		_store_mgr.purchase_dlc("compendium_bundle")

func _on_bug_hunt_buy_pressed() -> void:
	if _store_mgr and _store_mgr.has_method("purchase_dlc"):
		_store_mgr.purchase_dlc("bug_hunt")

func _on_bug_hunt_play_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("bug_hunt_creation")

func _on_manage_features_pressed(dlc_id: String) -> void:
	# dlc_id available for future per-pack filtering
	if DLCDialogScript:
		var dialog: AcceptDialog = DLCDialogScript.new()
		add_child(dialog)
		dialog.popup_centered()

func _on_restore_pressed() -> void:
	if _store_mgr \
			and _store_mgr.has_method("restore_all_purchases"):
		_store_mgr.restore_all_purchases()
		if _restore_button:
			_restore_button.text = "Restoring..."
			_restore_button.disabled = true

func _on_rate_pressed(btn: Button) -> void:
	if _review_mgr \
			and _review_mgr.has_method("request_review"):
		_review_mgr.request_review()
		if btn:
			btn.disabled = true
			btn.text = "Thanks!"

func _on_purchase_completed(dlc_id: String) -> void:
	_refresh_all()
	_show_status("[color=#10B981]%s purchased![/color]" % (
		_get_dlc_name(dlc_id)))

func _on_purchase_failed(
	dlc_id: String, reason: String,
) -> void:
	_refresh_all()
	_show_status(
		"[color=#DC2626]Purchase failed: %s[/color]" % reason)

func _on_purchase_cancelled(_dlc_id: String) -> void:
	_refresh_all()
	_show_status(
		"[color=#D97706]Purchase cancelled[/color]")

func _on_products_loaded(
	_products: Array[Dictionary],
) -> void:
	_refresh_all()

func _on_restore_completed(
	owned_ids: Array[String],
) -> void:
	_refresh_all()
	if _restore_button:
		_restore_button.text = "Restore Purchases"
		_restore_button.disabled = (
			_store_mgr.is_offline_mode() if _store_mgr else true)
	if owned_ids.is_empty():
		_show_status(
			"[color=#808080]No purchases to restore[/color]")
	else:
		_show_status(
			"[color=#10B981]Restored %d purchase(s)[/color]" % (
				owned_ids.size()))

# ── Helpers ────────────────────────────────────────────────────

func _show_status(bbcode: String) -> void:
	if _status_label:
		_status_label.text = bbcode

func _get_dlc_name(dlc_id: String) -> String:
	if _store_mgr and _store_mgr.has_method("get_dlc_info"):
		var info: Dictionary = _store_mgr.get_dlc_info(dlc_id)
		return str(info.get("name", dlc_id))
	return dlc_id
