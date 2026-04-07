class_name EmptyStateWidget
extends VBoxContainer

## Reusable empty state component with themed icon, flavor text, and optional action.
## Replaces plain "No X found" labels with immersive, on-brand placeholders.
## Inspired by Fallout Wasteland Warfare companion app empty state patterns.

signal action_pressed

func _ready() -> void:
	# Animate entrance
	TweenFX.fade_in(self, 0.4)

## Configure the widget. Call after instantiation and before adding to tree.
## Returns self for optional chaining.
func setup(
	title_text: String,
	flavor_text: String,
	action_text: String = "",
	action_callback: Callable = Callable()
) -> EmptyStateWidget:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", UIColors.SPACING_SM)

	# Icon placeholder (unicode glyph)
	var icon_label := Label.new()
	icon_label.text = "◇"
	icon_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL + 8)
	icon_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(icon_label)

	# Title
	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	# Flavor text (italic feel via secondary color + smaller size)
	var flavor_label := Label.new()
	flavor_label.text = flavor_text
	flavor_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	flavor_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(flavor_label)

	# Optional action button
	if not action_text.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size.y = UIColors.SPACING_XS
		add_child(spacer)

		var action_btn := Button.new()
		action_btn.text = action_text
		action_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
		action_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = UIColors.COLOR_ACCENT
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = UIColors.SPACING_MD
		btn_style.content_margin_right = UIColors.SPACING_MD
		action_btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = UIColors.COLOR_ACCENT_HOVER
		btn_hover.set_corner_radius_all(4)
		btn_hover.content_margin_left = UIColors.SPACING_MD
		btn_hover.content_margin_right = UIColors.SPACING_MD
		action_btn.add_theme_stylebox_override("hover", btn_hover)

		action_btn.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		action_btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)

		action_btn.pressed.connect(func():
			action_pressed.emit()
		)
		if action_callback.is_valid():
			action_btn.pressed.connect(action_callback)
		add_child(action_btn)

	return self
