class_name DLCUpsellBanner
extends PanelContainer

## Subtle contextual banner shown near gated content.
## Non-aggressive: no modals, no urgency. Purely informational.

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")

const SPACING_SM := UIColors.SPACING_SM
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_CYAN := UIColors.COLOR_CYAN
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

## Factory: create a banner for a specific ContentFlag name.
static func create_for_flag(flag_name: String) -> DLCUpsellBanner:
	var banner := DLCUpsellBanner.new()
	var pack_id: String = DLCContentCatalogRef.get_pack_for_flag(
		flag_name)
	var pack_name: String = DLCContentCatalogRef.get_pack_name(
		pack_id)
	var preview: String = DLCContentCatalogRef.get_feature_preview(
		flag_name)
	banner._setup(pack_name, preview)
	return banner

func _setup(pack_name: String, preview: String) -> void:
	# Subtle style: transparent bg, thin amber border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.1)
	style.border_color = COLOR_AMBER.darkened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(hbox)

	var lock_lbl := Label.new()
	lock_lbl.text = "🔒"
	lock_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	hbox.add_child(lock_lbl)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	hbox.add_child(text_col)

	var title_lbl := Label.new()
	title_lbl.text = "Available with %s" % pack_name
	title_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	title_lbl.add_theme_color_override(
		"font_color", COLOR_AMBER)
	text_col.add_child(title_lbl)

	if not preview.is_empty():
		var preview_lbl := Label.new()
		preview_lbl.text = preview
		preview_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		preview_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_SECONDARY)
		preview_lbl.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART)
		text_col.add_child(preview_lbl)

	var learn_btn := Button.new()
	learn_btn.text = "Learn More"
	learn_btn.flat = true
	learn_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	learn_btn.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	learn_btn.add_theme_color_override(
		"font_color", COLOR_CYAN)
	learn_btn.pressed.connect(_on_learn_more)
	hbox.add_child(learn_btn)

func _on_learn_more() -> void:
	var router: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/SceneRouter") if Engine.get_main_loop() else null
	if router and router.has_method("navigate_to"):
		router.navigate_to("store")
