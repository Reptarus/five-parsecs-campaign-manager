extends Window

## Warning dialog shown when loading a save that requires DLC packs
## the player doesn't own. Three options: Get Expansion, Load Anyway, Cancel.

signal load_requested
signal store_requested
signal cancelled

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")

const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const SPACING_XL := UIColors.SPACING_XL
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_RED := UIColors.COLOR_RED
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

func _ready() -> void:
	size = Vector2i(500, 400)
	unresizable = true
	transient = true
	exclusive = true
	title = "Missing Expansion Content"
	close_requested.connect(_on_cancel)

func show_missing_packs(missing_packs: Array[String]) -> void:
	_build_ui(missing_packs)
	popup_centered()

func _build_ui(missing_packs: Array[String]) -> void:
	# Background
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BASE
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SPACING_XL)
	margin.add_theme_constant_override("margin_right", SPACING_XL)
	margin.add_theme_constant_override("margin_top", SPACING_XL)
	margin.add_theme_constant_override("margin_bottom", SPACING_XL)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)
	margin.add_child(vbox)

	# Warning header
	var header := Label.new()
	header.text = "This campaign uses expansion content"
	header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header.add_theme_color_override("font_color", COLOR_AMBER)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Missing packs list
	var list_card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_ELEVATED
	card_style.border_color = COLOR_BORDER
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(SPACING_MD)
	list_card.add_theme_stylebox_override("panel", card_style)
	vbox.add_child(list_card)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", SPACING_SM)
	list_card.add_child(list_vbox)

	var requires_lbl := Label.new()
	requires_lbl.text = "Required expansions not owned:"
	requires_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	requires_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	list_vbox.add_child(requires_lbl)

	for pack_id: String in missing_packs:
		var pack_name: String = DLCContentCatalogRef.get_pack_name(
			pack_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		list_vbox.add_child(row)

		var bullet := Label.new()
		bullet.text = "·"
		bullet.add_theme_font_size_override(
			"font_size", FONT_SIZE_MD)
		bullet.add_theme_color_override("font_color", COLOR_RED)
		row.add_child(bullet)

		var name_lbl := Label.new()
		name_lbl.text = pack_name
		name_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_MD)
		name_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_PRIMARY)
		row.add_child(name_lbl)

	# Warning text
	var warning := Label.new()
	warning.text = (
		"Without these expansions, some features will be"
		+ " unavailable. Species bonuses, special mission rules,"
		+ " and other expansion content may not function correctly.")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	warning.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(warning)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", SPACING_SM)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = COLOR_BORDER
	cancel_style.set_corner_radius_all(6)
	cancel_style.set_content_margin_all(SPACING_SM)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Anyway"
	load_btn.custom_minimum_size = Vector2(130, TOUCH_TARGET_MIN)
	var load_style := StyleBoxFlat.new()
	load_style.bg_color = COLOR_AMBER.darkened(0.3)
	load_style.set_corner_radius_all(6)
	load_style.set_content_margin_all(SPACING_SM)
	load_btn.add_theme_stylebox_override("normal", load_style)
	load_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	load_btn.pressed.connect(_on_load_anyway)
	btn_row.add_child(load_btn)

	var store_btn := Button.new()
	store_btn.text = "Get Expansion"
	store_btn.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	var store_style := StyleBoxFlat.new()
	store_style.bg_color = COLOR_EMERALD.darkened(0.2)
	store_style.set_corner_radius_all(6)
	store_style.set_content_margin_all(SPACING_SM)
	store_btn.add_theme_stylebox_override("normal", store_style)
	store_btn.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	store_btn.pressed.connect(_on_store)
	btn_row.add_child(store_btn)

func _on_cancel() -> void:
	cancelled.emit()
	hide()
	queue_free()

func _on_load_anyway() -> void:
	load_requested.emit()
	hide()
	queue_free()

func _on_store() -> void:
	store_requested.emit()
	hide()
	queue_free()
