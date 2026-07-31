extends Window

## In-app bug report form for closed-alpha testers.
##
## Reachable from anywhere via the button beside the settings gear
## (SettingsOverlay) and from Settings > About.
##
## Submitting always writes the report to user://bug_reports/ FIRST, then copies
## the full text to the clipboard, then opens the tester's mail client with a
## short summary. Nothing is lost if the mail handoff fails.
##
## Built entirely in code (no .tscn), following the Window pattern in
## CampaignJournalScreen._ensure_notes_dialog().

const BugReportContextScript = preload("res://src/core/support/BugReportContext.gd")
const BugReportStoreScript = preload("res://src/core/support/BugReportStore.gd")
const BugReportWebhookScript = preload("res://src/core/support/BugReportWebhook.gd")
const UIColorsScript = preload("res://src/ui/components/base/UIColors.gd")

## Emitted after a report is saved. `saved_path` is "" if the write failed.
signal report_submitted(report: Dictionary, saved_path: String)

const CATEGORIES: Array[String] = [
	"Crash or freeze",
	"Wrong rule or number",
	"UI or layout problem",
	"Confusing or unclear",
	"Suggestion",
	"Other",
]

## Where tester reports are addressed. Changing this changes where every
## report in the field lands, so it is a deliberate single constant rather
## than a setting.
const SUPPORT_EMAIL := "aftermidnightmakers@gmail.com"

const LOG_TAIL_LINES := 100
const SETTINGS_SECTION := "support"
const SETTINGS_KEY := "reporter_contact"

var _category_btn: OptionButton
var _what_edit: TextEdit
var _steps_edit: TextEdit
var _contact_edit: LineEdit
var _include_log_check: CheckBox
var _details_toggle: CheckButton
var _details_label: RichTextLabel
var _status_label: Label
var _send_btn: Button
var _copy_btn: Button
var _close_btn: Button
var _actions: HFlowContainer

var _context: Dictionary = {}
var _log_tail: PackedStringArray = PackedStringArray()
var _submitted := false


## Creates, parents and shows the dialog. Always pass an explicit size:
## popup_centered() runs synchronously after add_child() while _ready() is
## deferred, so a Window whose `size` is still default collapses to the
## minimum and clips the form.
static func show_report(parent: Node) -> Window:
	var dlg := (load("res://src/ui/components/common/BugReportDialog.gd") as GDScript).new()
	parent.add_child(dlg)
	var vp: Vector2 = Vector2(900, 700)
	if parent.is_inside_tree():
		vp = parent.get_viewport().get_visible_rect().size
	dlg.popup_centered(Vector2i(
		mini(600, int(vp.x * 0.92)),
		mini(680, int(vp.y * 0.88))
	))
	return dlg


func _ready() -> void:
	title = "Report a Bug"
	exclusive = true
	transient = true
	# The settings overlay pauses the tree; the dialog must still work there.
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_requested.connect(_on_close)

	# Defensive: if the factory was bypassed, do not render at the minimum.
	if size.x < 200 or size.y < 200:
		size = Vector2i(600, 680)

	_context = BugReportContextScript.collect()
	_log_tail = BugReportContextScript.read_log_tail(LOG_TAIL_LINES)

	_build_ui()
	_refresh_details()
	_apply_layout_class()

	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		rm.layout_class_changed.connect(_on_layout_class_changed)


func _build_ui() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = UIColorsScript.COLOR_BASE
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", UIColorsScript.SPACING_MD)
	pad.add_theme_constant_override("margin_right", UIColorsScript.SPACING_MD)
	pad.add_theme_constant_override("margin_top", UIColorsScript.SPACING_MD)
	pad.add_theme_constant_override("margin_bottom", UIColorsScript.SPACING_MD)
	bg.add_child(pad)

	# Outer column: the form scrolls, the action row is pinned below it so Send
	# is always reachable without scrolling — on a 430px phone the form is
	# taller than the dialog, and burying the primary action costs reports.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIColorsScript.SPACING_SM)
	pad.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UIColorsScript.SPACING_SM)
	scroll.add_child(vbox)

	_add_hint(vbox, "Thanks for testing. The more specific you are, the faster it gets fixed.")

	# ── Category ──
	_add_label(vbox, "What kind of problem?")
	_category_btn = OptionButton.new()
	for c in CATEGORIES:
		_category_btn.add_item(c)
	_style_option_button(_category_btn)
	vbox.add_child(_category_btn)

	# ── What happened (required) ──
	_add_label(vbox, "What happened?")
	_what_edit = _make_text_edit(140, "Describe what you saw, and what you expected instead.")
	vbox.add_child(_what_edit)

	# ── Steps (optional) ──
	_add_label(vbox, "Steps to reproduce (optional)")
	_steps_edit = _make_text_edit(90, "1. ...\n2. ...")
	vbox.add_child(_steps_edit)

	# ── Contact (optional, remembered) ──
	_add_label(vbox, "Your name or email (optional)")
	_contact_edit = LineEdit.new()
	_contact_edit.placeholder_text = "So I can follow up if I need more detail"
	_style_line_edit(_contact_edit)
	_contact_edit.text = _load_saved_contact()
	vbox.add_child(_contact_edit)

	# ── Log toggle ──
	# Button labels do NOT autowrap by default, and an unwrapped label sets the
	# whole dialog's minimum width — at 341px portrait that pushed the panel out
	# to 396px and clipped every field. Keep these short AND wrap-enabled.
	_include_log_check = CheckBox.new()
	_include_log_check.text = "Attach app log (%d lines)" % _log_tail.size()
	_include_log_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_include_log_check.button_pressed = _log_tail.size() > 0
	_include_log_check.disabled = _log_tail.size() == 0
	_include_log_check.custom_minimum_size = Vector2(0, UIColorsScript.TOUCH_TARGET_MIN)
	_include_log_check.add_theme_color_override("font_color", UIColorsScript.COLOR_TEXT_SECONDARY)
	_include_log_check.toggled.connect(func(_p: bool) -> void: _refresh_details())
	vbox.add_child(_include_log_check)

	# ── Collapsed "what will be included" ──
	_details_toggle = CheckButton.new()
	_details_toggle.text = "Show what is sent"
	_details_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_toggle.custom_minimum_size = Vector2(0, UIColorsScript.TOUCH_TARGET_MIN)
	_details_toggle.add_theme_color_override("font_color", UIColorsScript.COLOR_TEXT_SECONDARY)
	_details_toggle.toggled.connect(_on_details_toggled)
	vbox.add_child(_details_toggle)

	_details_label = RichTextLabel.new()
	_details_label.visible = false
	_details_label.fit_content = true
	_details_label.selection_enabled = true
	_details_label.custom_minimum_size.y = 160
	_details_label.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(UIColorsScript.FONT_SIZE_XS))
	_details_label.add_theme_color_override("default_color", UIColorsScript.COLOR_TEXT_MUTED)
	vbox.add_child(_details_label)

	# ── Status + actions live OUTSIDE the scroll, pinned to the bottom ──
	_status_label = Label.new()
	_status_label.visible = false
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColorsScript.FONT_SIZE_SM))
	outer.add_child(_status_label)

	# HFlow so a narrow portrait dialog wraps the row instead of clipping it.
	_actions = HFlowContainer.new()
	_actions.alignment = FlowContainer.ALIGNMENT_END
	_actions.add_theme_constant_override("h_separation", UIColorsScript.SPACING_SM)
	_actions.add_theme_constant_override("v_separation", UIColorsScript.SPACING_SM)
	outer.add_child(_actions)

	_close_btn = Button.new()
	_close_btn.text = "Cancel"
	_style_button(_close_btn)
	_close_btn.pressed.connect(_on_close)
	_actions.add_child(_close_btn)

	_copy_btn = Button.new()
	_copy_btn.text = "Save & Copy"
	_copy_btn.tooltip_text = "Save the report and copy it to the clipboard, without opening email"
	_style_button(_copy_btn)
	_copy_btn.pressed.connect(func() -> void: _submit(false))
	_actions.add_child(_copy_btn)

	_send_btn = Button.new()
	_send_btn.text = "Send"
	_style_button(_send_btn, true)
	_send_btn.pressed.connect(func() -> void: _submit(true))
	_actions.add_child(_send_btn)


# ── Submission ───────────────────────────────────────────────────────────────

func _build_report() -> Dictionary:
	var category := "Other"
	if _category_btn and _category_btn.selected >= 0 and _category_btn.selected < CATEGORIES.size():
		category = CATEGORIES[_category_btn.selected]
	return {
		"category": category,
		"what_happened": _what_edit.text.strip_edges() if _what_edit else "",
		"steps": _steps_edit.text.strip_edges() if _steps_edit else "",
		"reporter_contact": _contact_edit.text.strip_edges() if _contact_edit else "",
		"context": _context,
		"log_tail": _log_tail if _include_log() else PackedStringArray(),
	}


func _include_log() -> bool:
	return _include_log_check != null and _include_log_check.button_pressed


func _submit(open_email: bool) -> void:
	if _what_edit == null or _what_edit.text.strip_edges().is_empty():
		_show_status("Please describe what happened before sending.", UIColorsScript.COLOR_AMBER)
		if _what_edit:
			_what_edit.grab_focus()
		return

	var report := _build_report()
	_save_contact(str(report.get("reporter_contact", "")))

	var saved_path: String = BugReportStoreScript.save(report)
	var full_text: String = BugReportStoreScript.format_as_text(report)
	DisplayServer.clipboard_set(full_text)

	var msg := ""
	var colour: Color = UIColorsScript.COLOR_EMERALD

	if saved_path.is_empty():
		msg = ("Could not save to disk, but the full text is on your clipboard. "
			+ "Please paste it somewhere safe.")
		colour = UIColorsScript.COLOR_AMBER
	elif open_email and BugReportWebhookScript.is_configured():
		# Preferred path: post straight to the dev's channel. The tester does
		# nothing further, which is the whole point — a mailto draft only
		# arrives if they remember to press Send in a second app.
		msg = "Saved. Sending your report…"
		_post_to_webhook(report)
	elif open_email:
		# No webhook in this build — fall back to a pre-filled mail draft.
		var err := _open_mail(report, saved_path)
		if err == OK:
			msg = ("Saved and copied to your clipboard. Your mail app should be "
				+ "opening — paste the full report into it.\n\nSaved at: %s") % saved_path
		else:
			msg = ("Saved and copied to your clipboard. No mail app was found, so "
				+ "please paste it into Discord or email manually.\n\nSaved at: %s") % saved_path
			colour = UIColorsScript.COLOR_AMBER
	else:
		msg = "Saved and copied to your clipboard.\n\nSaved at: %s" % saved_path

	_submitted = true
	_show_status(msg, colour)
	if _send_btn:
		_send_btn.disabled = true
	if _copy_btn:
		_copy_btn.disabled = true
	if _close_btn:
		_close_btn.text = "Done"

	report_submitted.emit(report, saved_path)


## Fires the Discord POST. Parented to the tree root, not to this dialog, so
## an in-flight request survives the tester closing the form. The report is
## already on disk and on the clipboard, so a failure costs nothing.
func _post_to_webhook(report: Dictionary) -> void:
	var poster: Node = BugReportWebhookScript.new()
	get_tree().root.add_child(poster)
	poster.post_completed.connect(_on_webhook_completed)
	poster.post_report(report)


func _on_webhook_completed(success: bool, status_code: int) -> void:
	# The dialog may already be gone; guard before touching UI.
	if not is_instance_valid(self) or _status_label == null:
		return
	if success:
		_show_status(
			"Report sent. Thanks — this one landed straight with the developer.",
			UIColorsScript.COLOR_EMERALD
		)
	else:
		_show_status(
			("Saved, but could not reach the developer's channel (code %d). "
				+ "The full report is on your clipboard — please paste it into "
				+ "Discord when you get a chance.") % status_code,
			UIColorsScript.COLOR_AMBER
		)


## Builds the mailto URI. Split out from _open_mail so it can be asserted on
## without launching a mail client — the missing-recipient bug shipped precisely
## because the only code path that would have caught it also opened a window.
func _build_mailto_uri(report: Dictionary, saved_path: String) -> String:
	var version := str(_context.get("app_version", "unknown"))
	var subject := ("FPCM Bug Report v%s — %s" % [
		version, str(report.get("category", "Other"))
	]).uri_encode()
	var body: String = BugReportStoreScript.format_email_body(report, saved_path).uri_encode()
	# The recipient is required. Without it the client opens a compose window
	# with a blank To: field and the tester has nowhere to send the report.
	return "mailto:%s?subject=%s&body=%s" % [SUPPORT_EMAIL, subject, body]


func _open_mail(report: Dictionary, saved_path: String) -> Error:
	var uri := _build_mailto_uri(report, saved_path)

	# Windows AppX/UWP protocol handlers (the new Outlook, olk.exe, is one and is
	# a common default) are NOT activated by OS.shell_open() — it returns OK and
	# silently does nothing. Verified 2026-07-27: PowerShell Start-Process opened
	# the compose window with an identical URI while shell_open did not.
	# Handing the URI to explorer.exe activates AppX handlers correctly.
	if OS.get_name() == "Windows":
		if OS.create_process("explorer.exe", [uri]) > 0:
			return OK
		# create_process failed outright; fall through and try shell_open anyway.

	return OS.shell_open(uri)


# ── Details preview ──────────────────────────────────────────────────────────

func _on_details_toggled(pressed: bool) -> void:
	if _details_label:
		_details_label.visible = pressed


func _refresh_details() -> void:
	if _details_label == null:
		return
	var text: String = BugReportStoreScript.format_context(_context)
	if _include_log() and _log_tail.size() > 0:
		text += "\n\n--- last %d log lines ---\n%s" % [
			_log_tail.size(), "\n".join(_log_tail)
		]
	_details_label.text = text


func _show_status(message: String, colour: Color) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", colour)
	_status_label.visible = true


# ── Contact persistence ──────────────────────────────────────────────────────

func _load_saved_contact() -> String:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("get_setting"):
		return str(sm.get_setting(SETTINGS_SECTION, SETTINGS_KEY))
	return ""


func _save_contact(value: String) -> void:
	if value.is_empty():
		return
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("set_setting"):
		sm.set_setting(SETTINGS_SECTION, SETTINGS_KEY, value)


# ── Responsive ───────────────────────────────────────────────────────────────

func _on_layout_class_changed(_effective_columns: int) -> void:
	_apply_layout_class()


## A standalone Window does not inherit BaseCampaignPanel's responsive wiring,
## so pull the current class directly — ResponsiveManager has no boot emit.
func _apply_layout_class() -> void:
	var rm := get_node_or_null("/root/ResponsiveManager")
	var collapse := false
	if rm and rm.has_method("should_collapse_to_single_column"):
		collapse = bool(rm.should_collapse_to_single_column())
	if _actions:
		_actions.alignment = (
			FlowContainer.ALIGNMENT_CENTER if collapse else FlowContainer.ALIGNMENT_END
		)


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _on_close() -> void:
	hide()
	queue_free()


# ── Local styling helpers (copied from BaseCampaignPanel / CharacterDetailsScreen) ──

func _add_label(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColorsScript.FONT_SIZE_SM))
	l.add_theme_color_override("font_color", UIColorsScript.COLOR_TEXT_SECONDARY)
	parent.add_child(l)


func _add_hint(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColorsScript.FONT_SIZE_SM))
	l.add_theme_color_override("font_color", UIColorsScript.COLOR_TEXT_MUTED)
	parent.add_child(l)


func _make_text_edit(min_height: int, placeholder: String) -> TextEdit:
	var te := TextEdit.new()
	te.placeholder_text = placeholder
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(0, min_height)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_text_edit(te)
	return te


func _style_text_edit(te: TextEdit) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColorsScript.COLOR_INPUT
	s.border_color = UIColorsScript.COLOR_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(UIColorsScript.SPACING_SM)
	te.add_theme_stylebox_override("normal", s)
	var f := s.duplicate()
	f.border_color = UIColorsScript.COLOR_FOCUS
	te.add_theme_stylebox_override("focus", f)


func _style_line_edit(le: LineEdit) -> void:
	le.custom_minimum_size.y = UIColorsScript.TOUCH_TARGET_COMFORT
	var s := StyleBoxFlat.new()
	s.bg_color = UIColorsScript.COLOR_INPUT
	s.border_color = UIColorsScript.COLOR_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(UIColorsScript.SPACING_SM)
	le.add_theme_stylebox_override("normal", s)
	var f := s.duplicate()
	f.border_color = UIColorsScript.COLOR_FOCUS
	f.set_border_width_all(2)
	le.add_theme_stylebox_override("focus", f)


func _style_option_button(ob: OptionButton) -> void:
	ob.custom_minimum_size.y = UIColorsScript.TOUCH_TARGET_MIN
	var s := StyleBoxFlat.new()
	s.bg_color = UIColorsScript.COLOR_INPUT
	s.border_color = UIColorsScript.COLOR_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(UIColorsScript.SPACING_SM)
	ob.add_theme_stylebox_override("normal", s)


func _style_button(b: Button, is_primary: bool = false) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColorsScript.COLOR_BLUE if is_primary else UIColorsScript.COLOR_TERTIARY
	s.set_corner_radius_all(8)
	s.content_margin_left = UIColorsScript.SPACING_MD
	s.content_margin_right = UIColorsScript.SPACING_MD
	s.content_margin_top = UIColorsScript.SPACING_SM
	s.content_margin_bottom = UIColorsScript.SPACING_SM
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColorsScript.FONT_SIZE_MD))
	b.add_theme_color_override("font_color", UIColorsScript.COLOR_TEXT_PRIMARY)
	b.custom_minimum_size = Vector2(0, UIColorsScript.TOUCH_TARGET_MIN)

	var hover := s.duplicate()
	hover.bg_color = (
		UIColorsScript.COLOR_ACCENT_HOVER if is_primary
		else Color(s.bg_color.r + 0.1, s.bg_color.g + 0.1, s.bg_color.b + 0.1)
	)
	b.add_theme_stylebox_override("hover", hover)

	var pressed := s.duplicate()
	pressed.bg_color = Color(s.bg_color.r - 0.1, s.bg_color.g - 0.1, s.bg_color.b - 0.1)
	b.add_theme_stylebox_override("pressed", pressed)

	var disabled := s.duplicate()
	disabled.bg_color = Color(s.bg_color.r, s.bg_color.g, s.bg_color.b, 0.2)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color("#4b5563"))
