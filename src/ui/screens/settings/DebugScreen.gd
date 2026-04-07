class_name DebugScreen
extends Control

## Debug & Support screen — log viewer + copy to clipboard + email support.
## Zero-infrastructure support pipeline: Settings → Debug → Copy Log → Email.
## Inspired by Fallout Wasteland Warfare companion app debug screen.

signal back_requested

# Ring buffer for captured log messages
static var _log_buffer: PackedStringArray = PackedStringArray()
const MAX_LOG_LINES := 200

var _log_display: RichTextLabel
var _version_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = UIColors.COLOR_PRIMARY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UIColors.SPACING_XL)
	margin.add_theme_constant_override("margin_right", UIColors.SPACING_XL)
	margin.add_theme_constant_override("margin_top", UIColors.SPACING_LG)
	margin.add_theme_constant_override("margin_bottom", UIColors.SPACING_LG)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	margin.add_child(vbox)

	# Header with back button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIColors.SPACING_MD)
	vbox.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	back_btn.flat = true
	back_btn.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_MD
	)
	back_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN
	)
	back_btn.pressed.connect(func(): back_requested.emit())
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "Debug & Support"
	title.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL
	)
	title.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Version info
	_version_label = Label.new()
	var version: String = ProjectSettings.get_setting(
		"application/config/version", "unknown"
	)
	_version_label.text = "v%s • Godot %s" % [version, Engine.get_version_info().string]
	_version_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	_version_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	vbox.add_child(_version_label)

	# Description
	var desc := Label.new()
	desc.text = "This page helps debug issues. Copy the log below and include it when reporting bugs."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	desc.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY
	)
	vbox.add_child(desc)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	vbox.add_child(btn_row)

	var copy_btn := Button.new()
	copy_btn.text = "COPY TO CLIPBOARD"
	copy_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_btn(copy_btn, UIColors.COLOR_EMERALD)
	copy_btn.pressed.connect(_on_copy_pressed)
	btn_row.add_child(copy_btn)

	var email_btn := Button.new()
	email_btn.text = "EMAIL SUPPORT"
	email_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	email_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_btn(email_btn, UIColors.COLOR_ACCENT)
	email_btn.pressed.connect(_on_email_pressed)
	btn_row.add_child(email_btn)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = UIColors.COLOR_BORDER
	vbox.add_child(sep)

	# Log display
	_log_display = RichTextLabel.new()
	_log_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_display.bbcode_enabled = true
	_log_display.scroll_following = true
	_log_display.selection_enabled = true
	_log_display.add_theme_font_size_override(
		"normal_font_size", 12
	)
	_log_display.add_theme_color_override(
		"default_color", UIColors.COLOR_TEXT_SECONDARY
	)
	var log_bg := StyleBoxFlat.new()
	log_bg.bg_color = Color(0.02, 0.03, 0.06, 1.0)
	log_bg.border_color = UIColors.COLOR_BORDER
	log_bg.set_border_width_all(1)
	log_bg.set_corner_radius_all(4)
	log_bg.content_margin_left = UIColors.SPACING_SM
	log_bg.content_margin_right = UIColors.SPACING_SM
	log_bg.content_margin_top = UIColors.SPACING_SM
	log_bg.content_margin_bottom = UIColors.SPACING_SM
	_log_display.add_theme_stylebox_override("normal", log_bg)
	vbox.add_child(_log_display)

	_refresh_log()

func _style_action_btn(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.darkened(0.1)
	hover.border_color = color
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)

func _refresh_log() -> void:
	if not _log_display:
		return
	_log_display.clear()

	# Collect engine log + custom buffer
	var lines: PackedStringArray = _log_buffer.duplicate()

	# Add system info header
	_log_display.append_text(
		"[color=#6b7280]── System Info ──[/color]\n"
	)
	_log_display.append_text(
		"[color=#9ca3af]OS: %s[/color]\n" % OS.get_name()
	)
	_log_display.append_text(
		"[color=#9ca3af]Engine: Godot %s[/color]\n" % Engine.get_version_info().string
	)
	var version: String = ProjectSettings.get_setting(
		"application/config/version", "unknown"
	)
	_log_display.append_text(
		"[color=#9ca3af]App: v%s[/color]\n" % version
	)
	_log_display.append_text(
		"[color=#9ca3af]Display: %s[/color]\n" % str(
			DisplayServer.window_get_size()
		)
	)
	_log_display.append_text(
		"[color=#6b7280]── Log ──[/color]\n"
	)

	if lines.is_empty():
		_log_display.append_text(
			"[color=#6b7280]No log entries captured yet.[/color]\n"
		)
	else:
		for line: String in lines:
			_log_display.append_text(line + "\n")

func _get_log_text() -> String:
	var text := "FPCM Debug Log\n"
	text += "OS: %s\n" % OS.get_name()
	text += "Engine: Godot %s\n" % Engine.get_version_info().string
	var version: String = ProjectSettings.get_setting(
		"application/config/version", "unknown"
	)
	text += "App: v%s\n" % version
	text += "Display: %s\n" % str(DisplayServer.window_get_size())
	text += "---\n"
	for line: String in _log_buffer:
		text += line + "\n"
	return text

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_get_log_text())
	# Brief visual feedback
	if _log_display:
		_log_display.append_text(
			"\n[color=#10b981]✓ Log copied to clipboard[/color]\n"
		)

func _on_email_pressed() -> void:
	var body: String = _get_log_text().uri_encode()
	var version: String = ProjectSettings.get_setting(
		"application/config/version", "unknown"
	)
	var subject: String = ("FPCM Bug Report v%s" % version).uri_encode()
	OS.shell_open(
		"mailto:?subject=%s&body=%s" % [subject, body]
	)

## Static method to add a log entry from anywhere in the codebase.
static func log_message(
	category: String, message: String, severity: String = "INFO"
) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	var entry := "[%s] [%s] [%s] %s" % [
		timestamp, severity, category, message
	]
	_log_buffer.append(entry)
	if _log_buffer.size() > MAX_LOG_LINES:
		_log_buffer.remove_at(0)
