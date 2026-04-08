extends Control

## First-launch EULA acceptance screen.
## Blocks access to MainMenu until the user accepts both EULA and Privacy Policy.
## Re-shown if EULA_VERSION or PRIVACY_VERSION in LegalConsentManager changes.

const MAX_FORM_WIDTH := 800

var _scroll: ScrollContainer
var _accept_btn: Button
var _privacy_check: CheckButton
var _eula_text: RichTextLabel


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = UIColors.COLOR_PRIMARY
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)

	# Centered content column
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	add_child(outer)

	# Top spacer for vertical centering effect
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 0.2
	outer.add_child(top_spacer)

	# Card container (max width)
	var card_wrapper := CenterContainer.new()
	card_wrapper.size_flags_vertical = SIZE_EXPAND_FILL
	card_wrapper.size_flags_horizontal = SIZE_EXPAND_FILL
	outer.add_child(card_wrapper)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 400)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UIColors.COLOR_SECONDARY
	card_style.border_color = UIColors.COLOR_BORDER
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = UIColors.SPACING_XL
	card_style.content_margin_right = UIColors.SPACING_XL
	card_style.content_margin_top = UIColors.SPACING_LG
	card_style.content_margin_bottom = UIColors.SPACING_LG
	card.add_theme_stylebox_override("panel", card_style)
	card_wrapper.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIColors.SPACING_MD)
	card.add_child(content)

	# Title
	var title := Label.new()
	title.text = "End User License Agreement"
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Please read and accept the following terms to continue."
	subtitle.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)

	# Scrollable EULA text
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 250
	content.add_child(_scroll)

	_eula_text = RichTextLabel.new()
	_eula_text.bbcode_enabled = true
	_eula_text.fit_content = true
	_eula_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_eula_text.add_theme_font_size_override("normal_font_size", UIColors.FONT_SIZE_SM)
	_eula_text.add_theme_color_override("default_color", UIColors.COLOR_TEXT_SECONDARY)
	_scroll.add_child(_eula_text)

	_load_eula_text()

	# Privacy checkbox
	_privacy_check = CheckButton.new()
	_privacy_check.text = "I have also read and accept the Privacy Policy"
	_privacy_check.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_privacy_check.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	_privacy_check.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_privacy_check.toggled.connect(_on_checkbox_toggled)
	content.add_child(_privacy_check)

	# Privacy policy link
	var privacy_link := LinkButton.new()
	privacy_link.text = "Read the Privacy Policy"
	privacy_link.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	privacy_link.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	privacy_link.pressed.connect(_on_privacy_link_pressed)
	content.add_child(privacy_link)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", UIColors.SPACING_MD)
	content.add_child(btn_row)

	var decline_btn := Button.new()
	decline_btn.text = "DECLINE"
	decline_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	DialogStyles.style_danger_button(decline_btn)
	decline_btn.pressed.connect(_on_decline_pressed)
	btn_row.add_child(decline_btn)

	_accept_btn = Button.new()
	_accept_btn.text = "ACCEPT"
	_accept_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_accept_btn.disabled = true
	DialogStyles.style_confirm_button(_accept_btn)
	_accept_btn.pressed.connect(_on_accept_pressed)
	btn_row.add_child(_accept_btn)

	# Bottom spacer
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	bottom_spacer.size_flags_stretch_ratio = 0.2
	outer.add_child(bottom_spacer)

	# Apply max width to card
	_apply_max_width(card_wrapper)
	get_viewport().size_changed.connect(func(): _apply_max_width(card_wrapper))


func _load_eula_text() -> void:
	var file := FileAccess.open("res://data/legal/eula.md", FileAccess.READ)
	if not file:
		_eula_text.text = "[color=#ef4444]Error: Could not load EULA text.[/color]"
		return

	var md_text := file.get_as_text()
	file.close()
	_eula_text.text = _markdown_to_bbcode(md_text)


func _markdown_to_bbcode(md: String) -> String:
	## Simple Markdown to BBCode converter for legal documents.
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
		elif trimmed == "":
			result += "\n"
		else:
			# Inline bold
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


func _on_checkbox_toggled(_pressed: bool) -> void:
	_update_accept_state()


func _update_accept_state() -> void:
	_accept_btn.disabled = not _privacy_check.button_pressed


func _on_accept_pressed() -> void:
	var consent_mgr := get_node_or_null("/root/LegalConsentManager")
	if consent_mgr:
		consent_mgr.accept_eula()
		consent_mgr.accept_privacy()

	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu", {}, false)


func _on_decline_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Cannot Continue"
	dialog.dialog_text = (
		"You must accept the End User License Agreement and "
		+ "Privacy Policy to use this application.\n\n"
		+ "Press OK to return, or close this dialog to quit."
	)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func():
		dialog.queue_free()
		get_tree().quit()
	)
	add_child(dialog)
	dialog.popup_centered()


func _on_privacy_link_pressed() -> void:
	# Open privacy policy in a modal view
	var dialog := AcceptDialog.new()
	dialog.title = "Privacy Policy"
	dialog.size = Vector2(600, 500)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 400)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", UIColors.FONT_SIZE_SM)

	var file := FileAccess.open("res://data/legal/privacy_policy.md", FileAccess.READ)
	if file:
		rtl.text = _markdown_to_bbcode(file.get_as_text())
		file.close()
	else:
		rtl.text = "[color=#ef4444]Error: Could not load Privacy Policy.[/color]"

	scroll.add_child(rtl)
	dialog.add_child(scroll)
	add_child(dialog)
	dialog.popup_centered()


func _apply_max_width(wrapper: CenterContainer) -> void:
	var vp := get_viewport()
	if not vp:
		return
	var vp_width := vp.get_visible_rect().size.x
	var target_width := mini(int(vp_width - UIColors.SPACING_XL * 2), MAX_FORM_WIDTH)
	for child in wrapper.get_children():
		child.custom_minimum_size.x = target_width
