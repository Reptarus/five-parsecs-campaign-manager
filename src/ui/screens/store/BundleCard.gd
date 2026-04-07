extends PanelContainer

## Bundle pricing card — shown when < 3 Compendium packs are owned.
## Amber-accented to visually distinguish from individual pack cards.

signal bundle_buy_requested()

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")

const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_CYAN := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

var _buy_btn: Button = null
var _checklist: VBoxContainer = null
var _savings_label: Label = null

func setup(bundle_info: Dictionary) -> void:
	_build_ui(bundle_info)

func refresh(bundle_info: Dictionary) -> void:
	var all_owned: bool = bundle_info.get("all_owned", false)
	visible = not all_owned
	if all_owned:
		return
	# Update checklist
	if _checklist:
		_update_checklist(bundle_info)
	# Update buy button
	if _buy_btn:
		var store: Node = Engine.get_main_loop().root.get_node_or_null(
			"/root/StoreManager"
		) if Engine.get_main_loop() else null
		if store and store.is_offline_mode():
			_buy_btn.disabled = true
			_buy_btn.text = "Not Available"

func _build_ui(bundle_info: Dictionary) -> void:
	# Amber accent border
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_AMBER.darkened(0.3)
	style.set_border_width_all(2)
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
	title.text = DLCContentCatalogRef.BUNDLE_INFO.get(
		"name", "Compendium Bundle")
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_savings_label = Label.new()
	_savings_label.text = DLCContentCatalogRef.get_bundle_savings_text()
	_savings_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_MD)
	_savings_label.add_theme_color_override(
		"font_color", COLOR_AMBER)
	header.add_child(_savings_label)

	# Description
	var desc := Label.new()
	desc.text = DLCContentCatalogRef.BUNDLE_INFO.get(
		"description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(desc)

	# Pack checklist
	_checklist = VBoxContainer.new()
	_checklist.add_theme_constant_override("separation", 4)
	vbox.add_child(_checklist)
	_update_checklist(bundle_info)

	# Price row
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", SPACING_SM)
	price_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(price_row)

	var individual_price := Label.new()
	individual_price.text = DLCContentCatalogRef.BUNDLE_INFO.get(
		"individual_total", "$17.97")
	individual_price.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	individual_price.add_theme_color_override(
		"font_color", COLOR_TEXT_MUTED)
	# Strikethrough via BBCode would need RichTextLabel;
	# simple parenthetical instead
	individual_price.text = "(was %s)" % individual_price.text
	price_row.add_child(individual_price)

	var bundle_price := Label.new()
	bundle_price.text = DLCContentCatalogRef.BUNDLE_INFO.get(
		"price_default", "$14.99")
	bundle_price.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	bundle_price.add_theme_color_override("font_color", COLOR_CYAN)
	price_row.add_child(bundle_price)

	_buy_btn = Button.new()
	_buy_btn.text = "Buy Bundle"
	_buy_btn.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COLOR_AMBER.darkened(0.2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(SPACING_SM)
	_buy_btn.add_theme_stylebox_override("normal", btn_style)
	var hover := btn_style.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_AMBER
	_buy_btn.add_theme_stylebox_override("hover", hover)
	_buy_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	_buy_btn.pressed.connect(
		func(): bundle_buy_requested.emit())
	price_row.add_child(_buy_btn)

	# Hide if all owned
	if bundle_info.get("all_owned", false):
		visible = false

func _update_checklist(bundle_info: Dictionary) -> void:
	if not _checklist:
		return
	# Clear existing
	for child in _checklist.get_children():
		child.queue_free()

	var dlc_mgr: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	var pack_ids: Array = DLCContentCatalogRef.BUNDLE_INFO.get(
		"included_packs", [])
	for pid: Variant in pack_ids:
		var pack_id: String = str(pid)
		var owned: bool = false
		if dlc_mgr and dlc_mgr.has_method("has_dlc"):
			owned = dlc_mgr.has_dlc(pack_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_checklist.add_child(row)

		var check := Label.new()
		check.text = "[x]" if owned else "[ ]"
		check.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		check.add_theme_color_override("font_color",
			COLOR_EMERALD if owned else COLOR_TEXT_MUTED)
		row.add_child(check)

		var name_lbl := Label.new()
		name_lbl.text = DLCContentCatalogRef.get_pack_name(pack_id)
		name_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		name_lbl.add_theme_color_override("font_color",
			COLOR_TEXT_PRIMARY if owned else COLOR_TEXT_SECONDARY)
		row.add_child(name_lbl)
