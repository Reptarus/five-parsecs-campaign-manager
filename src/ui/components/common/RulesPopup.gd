class_name RulesPopup
extends Window

## Full-modal rules reference popup for any item, weapon, skill, or alien.
## Tap a name anywhere in the UI → see full rules text → close → continue.
## Data-driven from compendium JSON / KeywordDB data.
## Inspired by Fallout Wasteland Warfare structure info reference popups.

var _pending_title: String = ""
var _pending_body: String = ""
var _pending_requirements: PackedStringArray = PackedStringArray()

var _vbox: VBoxContainer

func _init() -> void:
	title = ""
	size = Vector2i(420, 340)
	transient = true
	exclusive = false
	unresizable = true
	close_requested.connect(_on_close)

func _ready() -> void:
	_build_ui()
	_populate()

func _build_ui() -> void:
	# Background
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_BASE
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

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

func _populate() -> void:
	if not _vbox:
		return

	# Title
	var title_label := Label.new()
	title_label.text = _pending_title
	title_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL
	)
	title_label.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN
	)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title_label)

	var sep := HSeparator.new()
	sep.modulate = UIColors.COLOR_BORDER
	_vbox.add_child(sep)

	# Body text
	if not _pending_body.is_empty():
		var body := RichTextLabel.new()
		body.text = _pending_body
		body.bbcode_enabled = true
		body.fit_content = true
		body.scroll_active = true
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_font_size_override(
			"normal_font_size", UIColors.FONT_SIZE_SM
		)
		body.add_theme_color_override(
			"default_color", UIColors.COLOR_TEXT_SECONDARY
		)
		_vbox.add_child(body)

	# Requirements (perk gating display, like Fallout's "Requires: ARMORER")
	if not _pending_requirements.is_empty():
		var req_sep := HSeparator.new()
		req_sep.modulate = UIColors.COLOR_BORDER
		_vbox.add_child(req_sep)

		var req_title := Label.new()
		req_title.text = "Requirements"
		req_title.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_SM
		)
		req_title.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_MUTED
		)
		_vbox.add_child(req_title)

		for req: String in _pending_requirements:
			var bullet := Label.new()
			bullet.text = "  • %s" % req
			bullet.add_theme_font_size_override(
				"font_size", UIColors.FONT_SIZE_SM
			)
			bullet.add_theme_color_override(
				"font_color", UIColors.COLOR_TEXT_PRIMARY
			)
			_vbox.add_child(bullet)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DialogStyles.style_primary_button(close_btn)
	close_btn.pressed.connect(_on_close)
	_vbox.add_child(close_btn)

func _on_close() -> void:
	queue_free()

## Show a rules reference popup.
static func show_rules(
	parent: Node,
	title_text: String,
	body_text: String,
	requirements: PackedStringArray = PackedStringArray()
) -> RulesPopup:
	var popup := RulesPopup.new()
	popup._pending_title = title_text
	popup._pending_body = body_text
	popup._pending_requirements = requirements
	parent.add_child(popup)
	popup.popup_centered()
	return popup
