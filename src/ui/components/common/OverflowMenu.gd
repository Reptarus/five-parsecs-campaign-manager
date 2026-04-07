class_name OverflowMenu
extends Button

## Three-dot overflow button that opens a popup showing state counts.
## "2 Loot Items / 1 Injury / 0 Promotions" — phase summary at a glance.
## Inspired by Fallout Wasteland Warfare settlement phase overflow menu.

signal item_selected(item_id: String)

var _popup: PopupPanel
var _items: Array[Dictionary] = []  # {id: String, label: String, count: int}
var _item_vbox: VBoxContainer

func _init() -> void:
	text = "⋮"
	flat = true
	custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN
	)
	add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY
	)
	tooltip_text = "More options"
	pressed.connect(_toggle_popup)

## Add a menu item with a count badge.
func add_item(id: String, label_text: String, count: int = 0) -> OverflowMenu:
	_items.append({"id": id, "label": label_text, "count": count})
	return self

## Update the count for an existing item by ID.
func set_count(id: String, count: int) -> void:
	for item: Dictionary in _items:
		if item["id"] == id:
			item["count"] = count
			break
	if _popup and _popup.visible:
		_rebuild_popup_content()

func _toggle_popup() -> void:
	if _popup and _popup.visible:
		_popup.hide()
		return
	_show_popup()

func _show_popup() -> void:
	if not _popup:
		_popup = PopupPanel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = UIColors.COLOR_SECONDARY
		style.border_color = UIColors.COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = UIColors.SPACING_SM
		style.content_margin_right = UIColors.SPACING_SM
		style.content_margin_top = UIColors.SPACING_SM
		style.content_margin_bottom = UIColors.SPACING_SM
		_popup.add_theme_stylebox_override("panel", style)
		add_child(_popup)

	_rebuild_popup_content()

	# Position below the button
	var btn_rect: Rect2 = get_global_rect()
	_popup.position = Vector2i(
		int(btn_rect.position.x),
		int(btn_rect.position.y + btn_rect.size.y + 4)
	)
	_popup.popup()

func _rebuild_popup_content() -> void:
	if _item_vbox:
		_item_vbox.queue_free()

	_item_vbox = VBoxContainer.new()
	_item_vbox.add_theme_constant_override(
		"separation", UIColors.SPACING_XS
	)
	_popup.add_child(_item_vbox)

	for item: Dictionary in _items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(
			"separation", UIColors.SPACING_SM
		)
		row.custom_minimum_size = Vector2(180, 32)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Label
		var lbl := Label.new()
		lbl.text = item["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_SM
		)
		lbl.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_PRIMARY
		)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)

		# Count badge
		var count: int = item["count"]
		var badge := Label.new()
		badge.text = str(count)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(28, 0)
		badge.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_SM
		)
		var badge_color: Color = UIColors.COLOR_AMBER if count > 0 else UIColors.COLOR_TEXT_MUTED
		badge.add_theme_color_override("font_color", badge_color)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)

		# Click handler
		var item_id: String = item["id"]
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				item_selected.emit(item_id)
				_popup.hide()
		)

		_item_vbox.add_child(row)

	# Auto-size popup
	_popup.size = Vector2i(
		220, _items.size() * 36 + UIColors.SPACING_MD
	)
