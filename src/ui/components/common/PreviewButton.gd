class_name PreviewButton
extends Button

## Small eye-icon button for preview-without-commit.
## Opens an ItemPreviewPopup showing read-only item details.
## Inspired by Fallout Wasteland Warfare companion app eye icon pattern.

signal preview_requested(item_data: Variant)

var _item_data: Variant = null

func _init() -> void:
	text = "👁"
	flat = true
	custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN
	)
	add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY
	)
	tooltip_text = "Preview"
	pressed.connect(_on_pressed)

## Set the data this button will preview.
func set_preview_data(data: Variant) -> PreviewButton:
	_item_data = data
	return self

func _on_pressed() -> void:
	preview_requested.emit(_item_data)
	if _item_data is Dictionary:
		ItemPreviewPopup.show_preview(self, _item_data)
