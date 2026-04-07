class_name ItemPreviewPopup
extends Window

## Read-only item/weapon/skill detail popup.
## Shows item name, stats, and rules text without selecting or committing.
## Inspired by Fallout Wasteland Warfare structure info reference popups.

func _init() -> void:
	title = ""
	size = Vector2i(400, 320)
	transient = true
	exclusive = false  # Non-blocking — user can dismiss
	unresizable = true
	close_requested.connect(_on_close)

var _pending_data: Dictionary = {}

func _ready() -> void:
	_build_ui()
	if not _pending_data.is_empty():
		_populate(_pending_data)

func _build_ui() -> void:
	# Background
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_BASE
	style.border_color = UIColors.COLOR_CYAN
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UIColors.SPACING_MD)
	margin.add_theme_constant_override("margin_right", UIColors.SPACING_MD)
	margin.add_theme_constant_override("margin_top", UIColors.SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", UIColors.SPACING_MD)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	margin.add_child(_vbox)

var _vbox: VBoxContainer

func _populate(data: Dictionary) -> void:
	if not _vbox:
		return

	# Item name
	var name_text: String = str(data.get("name", data.get("item_name", "Unknown")))
	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL
	)
	name_label.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN
	)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = UIColors.COLOR_BORDER
	_vbox.add_child(sep)

	# Stats section (if weapon/equipment)
	var stats_added := false
	for key: String in ["range", "shots", "damage", "traits", "type", "category"]:
		if key in data:
			var row := _create_stat_row(
				key.capitalize(),
				str(data[key])
			)
			_vbox.add_child(row)
			stats_added = true

	if stats_added:
		var sep2 := HSeparator.new()
		sep2.modulate = UIColors.COLOR_BORDER
		_vbox.add_child(sep2)

	# Description / rules text
	var desc: String = str(data.get(
		"description",
		data.get("rules_text", data.get("effect", ""))
	))
	if not desc.is_empty():
		var desc_label := RichTextLabel.new()
		desc_label.text = desc
		desc_label.bbcode_enabled = true
		desc_label.fit_content = true
		desc_label.scroll_active = true
		desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_font_size_override(
			"normal_font_size", UIColors.FONT_SIZE_SM
		)
		desc_label.add_theme_color_override(
			"default_color", UIColors.COLOR_TEXT_SECONDARY
		)
		_vbox.add_child(desc_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIColors.COLOR_ACCENT
	btn_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	close_btn.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_MD
	)
	close_btn.pressed.connect(_on_close)
	_vbox.add_child(close_btn)

func _create_stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	val.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	row.add_child(val)
	return row

func _on_close() -> void:
	queue_free()

## Show a preview popup for the given item data dictionary.
static func show_preview(
	parent: Node, data: Dictionary
) -> ItemPreviewPopup:
	var popup := ItemPreviewPopup.new()
	popup._pending_data = data
	parent.add_child(popup)
	popup.popup_centered()
	return popup
