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


## Widest the consent card may DEMAND. Capped against the live viewport so the
## minimum can never exceed the space it has to fit in — an over-large minimum
## propagates up the tree and pushes the whole screen off the edge, which is
## exactly what the old fixed 360 did on a phone in portrait (~339 design px).
func _card_min_width() -> float:
	var vp := get_viewport()
	if vp == null:
		return 360.0
	var avail: float = vp.get_visible_rect().size.x - float(UIColors.SPACING_XL) * 2.0
	return minf(360.0, maxf(240.0, avail))


## Minimum height for the EULA scroll. Kept to a fraction of the viewport so a
## phone in LANDSCAPE (~338 design px tall, shared with a title, a subtitle, a
## checkbox, a link and two buttons) is not asked for 250 of them.
func _scroll_min_height() -> float:
	var vp := get_viewport()
	if vp == null:
		return 250.0
	return minf(250.0, maxf(120.0, vp.get_visible_rect().size.y * 0.35))


## True when vertical space is tight enough that decorative padding costs the user
## reachable controls — a phone in landscape is ~338 design px tall in total.
func _is_short_viewport() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.get_visible_rect().size.y < 520.0


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

	# Top spacer for vertical centering effect. Purely decorative, so it yields all
	# of its share on a short viewport (a phone in landscape) where every pixel is
	# needed for the consent controls the user has to reach.
	var spacer_ratio: float = 0.2 if not _is_short_viewport() else 0.0
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = spacer_ratio
	outer.add_child(top_spacer)

	# The card carries a title, a subtitle, the EULA scroll, a consent checkbox, a
	# policy link and two buttons. On a phone in LANDSCAPE (~338 design px tall)
	# those cannot all fit however tightly the minimums are tuned — and this screen
	# is the gate in front of the entire app, so an unreachable ACCEPT button is a
	# hard block, not a cosmetic one. An outer scroll makes it degrade instead:
	# roomy screens are unchanged (nothing to scroll), short ones stay usable.
	var outer_scroll := ScrollContainer.new()
	outer_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	outer_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(outer_scroll)

	# Card container (max width)
	var card_wrapper := CenterContainer.new()
	card_wrapper.size_flags_vertical = SIZE_EXPAND_FILL
	card_wrapper.size_flags_horizontal = SIZE_EXPAND_FILL
	outer_scroll.add_child(card_wrapper)

	var card := PanelContainer.new()
	# A FIXED 360x400 minimum was bigger than the viewport it had to fit inside: 360
	# exceeds the ~339 design px of a phone in portrait, and 400 exceeds the ~338 of
	# one in landscape — so this screen, the FIRST thing a new user sees and the gate
	# in front of the whole app, hung 154-202px off the edge.
	#
	# A minimum only has to be big enough to look deliberate; the content below sets
	# the real size. Cap the width against the live viewport and let height come from
	# the content, with the EULA ScrollContainer absorbing the slack.
	card.custom_minimum_size = Vector2(_card_min_width(), 0)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	# The house card recipe, then widened: this is a full-page consent card rather
	# than a list row, so it keeps its generous padding. The 8px radius it used to
	# hardcode was the only remaining place the app drew a card at the old size.
	var card_style := ScreenChrome.panel_style()
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
	# Without this the Label demands its full unwrapped width as a MINIMUM and drags
	# the whole column past the screen edge on a phone — the MainMenu title bug. This
	# is the first screen a new user ever sees, and it gates the app behind a button.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# 250 is taller than a phone in LANDSCAPE has to spare (~338 design px total,
	# minus title, subtitle, checkbox, link and two buttons). Scale it to what is
	# actually available; SIZE_EXPAND_FILL still hands it every spare pixel on a
	# roomy screen, so the desktop reading experience is unchanged.
	_scroll.custom_minimum_size.y = _scroll_min_height()
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
	# THE WIDEST THING IN THE CARD. A CheckButton is a Button, so with autowrap off
	# this 46-character label demanded ~350px as a MINIMUM — more than a phone's ~339
	# design px once the card padding is added. Capping the card width did nothing,
	# because get_combined_minimum_size() takes the MAX of the custom minimum and the
	# content's own, and the content won. Safe to wrap here: it sits in a plain
	# VBoxContainer, not an HFlowContainer (where autowrap explodes the height).
	_privacy_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	bottom_spacer.size_flags_stretch_ratio = spacer_ratio
	outer.add_child(bottom_spacer)

	# Apply max width to card
	_apply_max_width(card_wrapper)
	# Capture WeakRefs, NOT the Nodes: this closure is bound to the PERSISTENT
	# viewport.size_changed, so it outlives this screen. A lambda whose capture is a
	# freed Node (self or card_wrapper) makes the engine refuse the call and log
	# "Lambda capture at index 0 was freed" on the next resize after this screen
	# closes. WeakRefs are RefCounted (never freed); the guards below then no-op
	# cleanly once the screen is gone.
	var screen_ref := weakref(self)
	var card_ref := weakref(card_wrapper)
	get_viewport().size_changed.connect(func():
		var s: Object = screen_ref.get_ref()
		var c: Object = card_ref.get_ref()
		if is_instance_valid(s) and is_instance_valid(c):
			s.call("_apply_max_width", c)
	)


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
