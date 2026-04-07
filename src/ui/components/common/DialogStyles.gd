class_name DialogStyles
extends RefCounted

## Shared dialog button styling utilities.
## Ensures consistent red/green binary button patterns across all dialogs.
## Extract from CrewTaskEventDialog and FPCMConfirmationDialog patterns.

## Style a confirm/positive action button (green accent).
static func style_confirm_button(btn: Button) -> void:
	_apply_button_style(btn, UIColors.COLOR_EMERALD)

## Style a destructive/danger action button (red accent).
static func style_danger_button(btn: Button) -> void:
	_apply_button_style(btn, UIColors.COLOR_RED)

## Style a neutral/cancel action button (muted).
static func style_cancel_button(btn: Button) -> void:
	_apply_button_style(btn, UIColors.COLOR_SECONDARY)

## Style a primary action button (blue accent).
static func style_primary_button(btn: Button) -> void:
	_apply_button_style(btn, UIColors.COLOR_ACCENT)

## Style a secondary/skip action button (elevated dark).
static func style_secondary_button(btn: Button) -> void:
	_apply_button_style(btn, UIColors.COLOR_ELEVATED)

static func _apply_button_style(btn: Button, bg_color: Color) -> void:
	btn.custom_minimum_size.y = maxf(
		btn.custom_minimum_size.y, UIColors.TOUCH_TARGET_MIN
	)
	btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	btn.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_MD
	)

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(4)
	normal.content_margin_left = UIColors.SPACING_MD
	normal.content_margin_right = UIColors.SPACING_MD
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.border_color = UIColors.COLOR_FOCUS
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.content_margin_left = UIColors.SPACING_MD
	hover.content_margin_right = UIColors.SPACING_MD
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.15)
	pressed.set_corner_radius_all(4)
	pressed.content_margin_left = UIColors.SPACING_MD
	pressed.content_margin_right = UIColors.SPACING_MD
	btn.add_theme_stylebox_override("pressed", pressed)
