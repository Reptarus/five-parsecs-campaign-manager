extends Control

## Reusable screen for displaying legal documents (Privacy Policy, EULA, Licenses, Credits).
## Navigate to with context: SceneRouter.navigate_to("legal_viewer", {"file": "res://...", "title": "..."})

const MAX_FORM_WIDTH := 800

var _title_label: Label
var _rtl: RichTextLabel


func _ready() -> void:
	_build_ui()
	_load_from_context()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UIColors.COLOR_PRIMARY
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.offset_left = UIColors.SPACING_XL
	outer.offset_right = -UIColors.SPACING_XL
	outer.offset_top = UIColors.SPACING_LG
	outer.offset_bottom = -UIColors.SPACING_LG
	add_child(outer)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	_title_label = Label.new()
	_title_label.text = "Legal Document"
	_title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title_label)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(center)

	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.fit_content = true
	_rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	_rtl.custom_minimum_size.x = 300
	_rtl.add_theme_font_size_override("normal_font_size", UIColors.FONT_SIZE_SM)
	_rtl.add_theme_color_override("default_color", UIColors.COLOR_TEXT_SECONDARY)
	center.add_child(_rtl)

	# Footer close button
	var footer := CenterContainer.new()
	outer.add_child(footer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_primary_button(close_btn)
	close_btn.pressed.connect(_on_back_pressed)
	footer.add_child(close_btn)

	# Apply max width
	_apply_max_width()
	get_viewport().size_changed.connect(_apply_max_width)


func _load_from_context() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if not router:
		return

	var context: Dictionary = {}
	if router.has_method("get_context"):
		context = router.get_context()
	elif "scene_contexts" in router:
		context = router.scene_contexts.get("legal_viewer", {})

	var title: String = context.get("title", "Legal Document")
	_title_label.text = title

	var file_path: String = context.get("file", "")
	if file_path.is_empty():
		_rtl.text = "[color=#ef4444]No document specified.[/color]"
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_rtl.text = "[color=#ef4444]Error: Could not load %s[/color]" % file_path
		return

	var md_text := file.get_as_text()
	file.close()
	_rtl.text = _markdown_to_bbcode(md_text)


func _markdown_to_bbcode(md: String) -> String:
	var lines := md.split("\n")
	var result := ""

	for line in lines:
		var trimmed := line.strip_edges()

		if trimmed.begins_with("# "):
			result += "[font_size=%d][b]%s[/b][/font_size]\n\n" % [
				UIColors.FONT_SIZE_LG, trimmed.substr(2)]
		elif trimmed.begins_with("## "):
			result += "\n[font_size=%d][b]%s[/b][/font_size]\n\n" % [
				UIColors.FONT_SIZE_MD + 1, trimmed.substr(3)]
		elif trimmed.begins_with("### "):
			result += "\n[b]%s[/b]\n\n" % trimmed.substr(4)
		elif trimmed.begins_with("- "):
			result += "  [color=#06b6d4]\u2022[/color] %s\n" % trimmed.substr(2)
		elif trimmed.begins_with("**") and trimmed.ends_with("**"):
			result += "[b]%s[/b]\n" % trimmed.trim_prefix("**").trim_suffix("**")
		elif trimmed.begins_with("[PENDING"):
			result += "[color=#f59e0b][i]%s[/i][/color]\n" % trimmed
		elif trimmed.begins_with("---"):
			result += "\n[color=#374151]────────────────────────────────[/color]\n\n"
		elif trimmed == "":
			result += "\n"
		else:
			var processed := trimmed
			while processed.find("**") != -1:
				var start := processed.find("**")
				var end := processed.find("**", start + 2)
				if end == -1:
					break
				var bold_text := processed.substr(start + 2, end - start - 2)
				processed = processed.substr(0, start) + "[b]" + bold_text + "[/b]" + processed.substr(end + 2)
			result += processed + "\n"

	return result


func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("go_back"):
		router.go_back()
	elif router and router.has_method("navigate_to"):
		router.navigate_to("settings")


func _apply_max_width() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var vp_width := vp.get_visible_rect().size.x
	var target_width := mini(int(vp_width - UIColors.SPACING_XL * 4), MAX_FORM_WIDTH)
	_rtl.custom_minimum_size.x = target_width
	_rtl.custom_maximum_size.x = target_width
