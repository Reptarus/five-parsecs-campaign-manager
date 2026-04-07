class_name SettingsScreen
extends Control

## Options/Settings Screen — platform-adaptive, Deep Space themed
## Accessible from MainMenu via SceneRouter key "settings"
## Desktop: Audio, Display (Fullscreen/VSync/UI Scale), Gameplay, Accessibility, Difficulty
## Mobile: Audio, Display (UI Scale only), Gameplay, Touch/Haptics, Accessibility, Difficulty
## Persists to user://options.cfg. Window state saved to user://window.ini (desktop only).
##
## When overlay_mode is true, this screen is embedded in the SettingsOverlay
## CanvasLayer instead of being a standalone scene. Back button emits
## back_requested instead of calling SceneRouter.

signal back_requested

## When true, this screen is hosted inside SettingsOverlay as a non-destructive
## overlay. Disables window state save/restore and uses signal instead of
## SceneRouter for navigation.
var overlay_mode: bool = false

const AccessibilitySettingsPanelScript = preload("res://src/ui/screens/settings/AccessibilitySettingsPanel.gd")
const DifficultyTogglesPanelScript = preload("res://src/ui/screens/settings/DifficultyTogglesPanel.gd")

# Deep Space theme colors
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")

# Base sizes — multiplied by ResponsiveManager at build time
const BASE_SPACING_SM := 8
const BASE_SPACING_MD := 16
const BASE_SPACING_LG := 24
const BASE_SPACING_XL := 32
const BASE_FONT_SM := 14
const BASE_FONT_MD := 16
const BASE_FONT_LG := 18
const BASE_FONT_XL := 24

# Persistence
var _config_path := "user://options.cfg"
var _window_config_path := "user://window.ini"
var _config := ConfigFile.new()

# Responsive manager ref
var _responsive: Node

# Platform flags (cached at build time)
var _is_desktop: bool
var _is_mobile: bool

# UI references for reading values
var _master_vol_slider: HSlider
var _music_vol_slider: HSlider
var _sfx_vol_slider: HSlider
var _fullscreen_check: CheckButton
var _vsync_option: OptionButton
var _ui_scale_slider: HSlider
var _ui_scale_label: Label
var _auto_save_check: CheckButton
var _show_tooltips_check: CheckButton
var _show_fps_check: CheckButton
var _screen_shake_check: CheckButton
# Mobile-only
var _haptic_check: CheckButton
var _touch_sensitivity_slider: HSlider

# Responsive computed sizes
var _touch_target: int
var _spacing_sm: int
var _spacing_md: int
var _spacing_lg: int
var _spacing_xl: int
var _font_sm: int
var _font_md: int
var _font_lg: int
var _font_xl: int


func _ready() -> void:
	_responsive = get_node_or_null("/root/ResponsiveManager")
	_is_desktop = OS.has_feature("pc")
	_is_mobile = OS.has_feature("mobile")
	_compute_responsive_sizes()
	_load_config()
	_build_ui()
	_apply_settings()


func _enter_tree() -> void:
	# Restore window state (desktop only) — per Godot docs best practice
	if overlay_mode:
		return
	if not OS.has_feature("pc"):
		return
	if Engine.is_editor_hint():
		return
	var wc := ConfigFile.new()
	if wc.load(_window_config_path) != OK:
		return
	var win := get_window()
	if not win:
		return
	var screen = wc.get_value("main", "screen", -1)
	if screen is int and screen >= 0:
		win.current_screen = screen
	var mode = wc.get_value("main", "mode", -1)
	if mode is int and mode >= 0:
		win.mode = mode
	var pos = wc.get_value("main", "position", -1)
	if pos is Vector2i:
		win.position = pos
	var sz = wc.get_value("main", "size", -1)
	if sz is Vector2i:
		win.size = sz


func _exit_tree() -> void:
	# Save window state (desktop only)
	if overlay_mode:
		return
	if not OS.has_feature("pc"):
		return
	var win := get_window()
	if not win:
		return
	var wc := ConfigFile.new()
	wc.set_value("main", "screen", win.current_screen)
	wc.set_value("main", "mode", win.mode)
	wc.set_value("main", "position", win.position)
	wc.set_value("main", "size", win.size)
	wc.save(_window_config_path)


func _compute_responsive_sizes() -> void:
	if _responsive:
		_touch_target = _responsive.get_touch_target_size()
		_spacing_sm = _responsive.get_responsive_spacing(BASE_SPACING_SM)
		_spacing_md = _responsive.get_responsive_spacing(BASE_SPACING_MD)
		_spacing_lg = _responsive.get_responsive_spacing(BASE_SPACING_LG)
		_spacing_xl = _responsive.get_responsive_spacing(BASE_SPACING_XL)
		_font_sm = _responsive.get_responsive_font_size(BASE_FONT_SM)
		_font_md = _responsive.get_responsive_font_size(BASE_FONT_MD)
		_font_lg = _responsive.get_responsive_font_size(BASE_FONT_LG)
		_font_xl = _responsive.get_responsive_font_size(BASE_FONT_XL)
	else:
		_touch_target = 48
		_spacing_sm = BASE_SPACING_SM
		_spacing_md = BASE_SPACING_MD
		_spacing_lg = BASE_SPACING_LG
		_spacing_xl = BASE_SPACING_XL
		_font_sm = BASE_FONT_SM
		_font_md = BASE_FONT_MD
		_font_lg = BASE_FONT_LG
		_font_xl = BASE_FONT_XL


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = COLOR_BASE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	bg.name = "__settings_bg"
	add_child(bg)

	# Root margin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _spacing_xl)
	margin.add_theme_constant_override("margin_right", _spacing_xl)
	margin.add_theme_constant_override("margin_top", _spacing_lg)
	margin.add_theme_constant_override("margin_bottom", _spacing_lg)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", _spacing_md)
	margin.add_child(root_vbox)

	# Header
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size.y = 48  # ISSUE-035: meet TOUCH_TARGET_MIN
	back_btn.pressed.connect(_on_back_pressed)
	back_btn.accessibility_name = "Back to Main Menu"
	header.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", _font_xl)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer2)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", _spacing_lg)
	scroll.add_child(content)

	# Sections — platform-adaptive
	_build_audio_section(content)
	_build_display_section(content)
	_build_gameplay_section(content)

	if _is_mobile:
		_build_mobile_section(content)

	# Accessibility panel (existing code-built component)
	var acc_panel := AccessibilitySettingsPanelScript.new()
	acc_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(acc_panel)

	# Expansions summary
	_build_expansions_section(content)

	# Difficulty toggles (DLC-gated)
	var toggles_panel := DifficultyTogglesPanelScript.new()
	toggles_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(toggles_panel)

	# Legal & Privacy section
	_build_legal_section(content)

	# Footer buttons
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", _spacing_md)
	root_vbox.add_child(footer)

	var save_btn := _create_accent_button("Save Settings")
	save_btn.pressed.connect(_on_save_pressed)
	save_btn.accessibility_name = "Save all settings changes"
	footer.add_child(save_btn)

	var reset_btn := _create_button("Reset to Defaults")
	reset_btn.pressed.connect(_on_reset_pressed)
	reset_btn.accessibility_name = "Reset all settings to default values"
	footer.add_child(reset_btn)

	# Debug button — bottom of settings, like Fallout companion app
	var debug_btn := Button.new()
	debug_btn.text = "DEBUG"
	debug_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	debug_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dbg_style := StyleBoxFlat.new()
	dbg_style.bg_color = UIColors.COLOR_TERTIARY
	dbg_style.border_color = UIColors.COLOR_BORDER
	dbg_style.set_border_width_all(1)
	dbg_style.set_corner_radius_all(4)
	debug_btn.add_theme_stylebox_override("normal", dbg_style)
	debug_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	debug_btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	debug_btn.pressed.connect(_on_debug_pressed)
	root_vbox.add_child(debug_btn)


# ============ AUDIO ============
func _build_audio_section(parent: VBoxContainer) -> void:
	var card := _create_section_card("Audio", parent)

	_master_vol_slider = _add_slider_row(card, "Master Volume", 0.0, 1.0, 0.05,
		_config.get_value("audio", "master_volume", 1.0), "Master volume control")

	_music_vol_slider = _add_slider_row(card, "Music Volume", 0.0, 1.0, 0.05,
		_config.get_value("audio", "music_volume", 0.8), "Music volume control")

	_sfx_vol_slider = _add_slider_row(card, "SFX Volume", 0.0, 1.0, 0.05,
		_config.get_value("audio", "sfx_volume", 0.8), "Sound effects volume control")


# ============ DISPLAY ============
func _build_display_section(parent: VBoxContainer) -> void:
	var card := _create_section_card("Display", parent)

	# Desktop-only: Fullscreen and VSync
	if _is_desktop:
		_fullscreen_check = _add_toggle_row(card, "Fullscreen",
			_config.get_value("display", "fullscreen", false), "Toggle fullscreen mode")

		# VSync — 4 modes per Godot docs best practice
		var vsync_row := HBoxContainer.new()
		card.add_child(vsync_row)

		var vsync_label := Label.new()
		vsync_label.text = "VSync Mode"
		vsync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vsync_label.add_theme_font_size_override("font_size", _font_md)
		vsync_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		vsync_row.add_child(vsync_label)

		_vsync_option = OptionButton.new()
		_vsync_option.add_item("Disabled", DisplayServer.VSYNC_DISABLED)
		_vsync_option.add_item("Enabled", DisplayServer.VSYNC_ENABLED)
		_vsync_option.add_item("Adaptive", DisplayServer.VSYNC_ADAPTIVE)
		_vsync_option.add_item("Mailbox", DisplayServer.VSYNC_MAILBOX)
		var saved_vsync: int = _config.get_value("display", "vsync_mode", DisplayServer.VSYNC_ENABLED)
		# Find matching index by ID
		for i in range(_vsync_option.item_count):
			if _vsync_option.get_item_id(i) == saved_vsync:
				_vsync_option.select(i)
				break
		_vsync_option.custom_minimum_size = Vector2(200, _touch_target)
		_vsync_option.accessibility_name = "Vertical sync mode selection"
		vsync_row.add_child(_vsync_option)

	# UI Scale — all platforms
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", _spacing_sm)
	card.add_child(scale_row)

	var scale_label := Label.new()
	scale_label.text = "UI Scale"
	scale_label.custom_minimum_size.x = 180
	scale_label.add_theme_font_size_override("font_size", _font_md)
	scale_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	scale_row.add_child(scale_label)

	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.75
	_ui_scale_slider.max_value = 2.0
	_ui_scale_slider.step = 0.05
	_ui_scale_slider.value = _config.get_value("display", "ui_scale", 1.0)
	_ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_scale_slider.custom_minimum_size.y = _touch_target
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	_ui_scale_slider.accessibility_name = "UI scale adjustment"
	scale_row.add_child(_ui_scale_slider)

	_ui_scale_label = Label.new()
	_ui_scale_label.text = "%d%%" % int(_ui_scale_slider.value * 100)
	_ui_scale_label.custom_minimum_size.x = 50
	_ui_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_scale_label.add_theme_font_size_override("font_size", _font_md)
	_ui_scale_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	scale_row.add_child(_ui_scale_label)


# ============ GAMEPLAY ============
func _build_gameplay_section(parent: VBoxContainer) -> void:
	var card := _create_section_card("Gameplay", parent)

	_auto_save_check = _add_toggle_row(card, "Auto-Save",
		_config.get_value("gameplay", "auto_save", true), "Toggle automatic saving",
		"Automatically save your campaign at the end of each turn.")

	_show_tooltips_check = _add_toggle_row(card, "Show Tooltips",
		_config.get_value("gameplay", "show_tooltips", true), "Toggle keyword tooltips",
		"Display keyword explanations when hovering game terms.")

	_show_fps_check = _add_toggle_row(card, "Show FPS Counter",
		_config.get_value("gameplay", "show_fps", false), "Toggle frames per second display",
		"Show a framerate counter in the corner of the screen.")

	_screen_shake_check = _add_toggle_row(card, "Screen Shake",
		_config.get_value("gameplay", "screen_shake", true), "Toggle screen shake effects",
		"Enable camera shake during combat and critical events.")


# ============ MOBILE-ONLY ============
func _build_mobile_section(parent: VBoxContainer) -> void:
	var card := _create_section_card("Touch & Haptics", parent)

	_haptic_check = _add_toggle_row(card, "Haptic Feedback",
		_config.get_value("mobile", "haptic_feedback", true), "Toggle vibration feedback",
		"Vibrate on dice rolls, critical hits, and important events.")

	_touch_sensitivity_slider = _add_slider_row(card, "Touch Sensitivity", 0.5, 2.0, 0.1,
		_config.get_value("mobile", "touch_sensitivity", 1.0), "Adjust touch input sensitivity")


# ============ EXPANSIONS ============
func _build_expansions_section(
	parent: VBoxContainer,
) -> void:
	var dlc_mgr := get_node_or_null("/root/DLCManager")
	if not dlc_mgr:
		return
	var card_vbox := _create_section_card("Expansions", parent)

	# Ownership summary
	var owned_count := 0
	for pid: String in ["trailblazers_toolkit",
			"freelancers_handbook", "fixers_guidebook"]:
		if dlc_mgr.has_dlc(pid):
			owned_count += 1
	var summary := Label.new()
	summary.text = "%d of 3 expansions owned" % owned_count
	summary.add_theme_font_size_override(
		"font_size", _font_md)
	summary.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	card_vbox.add_child(summary)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override(
		"separation", _spacing_sm)
	card_vbox.add_child(btn_row)

	var browse_btn := Button.new()
	browse_btn.text = "Browse Expansions"
	browse_btn.custom_minimum_size.y = 48
	browse_btn.pressed.connect(func():
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("store")
	)
	btn_row.add_child(browse_btn)

	if owned_count > 0:
		var manage_btn := Button.new()
		manage_btn.text = "Manage Features"
		manage_btn.custom_minimum_size.y = 48
		manage_btn.pressed.connect(func():
			var DLCDialogScript := load(
				"res://src/ui/dialogs/DLCManagementDialog.gd")
			if DLCDialogScript:
				var dialog: AcceptDialog = DLCDialogScript.new()
				add_child(dialog)
				dialog.popup_centered()
		)
		btn_row.add_child(manage_btn)


func _build_legal_section(parent: VBoxContainer) -> void:
	var card_vbox := _create_section_card("Legal & Privacy", parent)

	# Document links
	var docs := [
		["Privacy Policy", "res://data/legal/privacy_policy.md", "Privacy Policy"],
		["Terms of Service / EULA", "res://data/legal/eula.md", "EULA"],
		["Open Source Licenses", "res://data/legal/third_party_licenses.md", "Open Source Licenses"],
		["Credits", "res://data/legal/credits.md", "Credits"],
	]
	for doc_info: Array in docs:
		var btn := Button.new()
		btn.text = doc_info[0]
		btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var file_path: String = doc_info[1]
		var doc_title: String = doc_info[2]
		btn.pressed.connect(func():
			var router := get_node_or_null("/root/SceneRouter")
			if router and router.has_method("navigate_to"):
				router.navigate_to("legal_viewer", {
					"file": file_path, "title": doc_title
				})
		)
		card_vbox.add_child(btn)

	var sep1 := HSeparator.new()
	card_vbox.add_child(sep1)

	# Data & Privacy subsection label
	var data_label := Label.new()
	data_label.text = "Data & Privacy"
	data_label.add_theme_font_size_override("font_size", _font_md)
	data_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	card_vbox.add_child(data_label)

	# Analytics consent toggle
	var consent_mgr := get_node_or_null("/root/LegalConsentManager")
	var analytics_initial := false
	if consent_mgr and consent_mgr.has_method("get_analytics_consent"):
		analytics_initial = consent_mgr.get_analytics_consent()

	var analytics_toggle := _add_toggle_row(
		card_vbox,
		"Share Anonymous Usage Data",
		analytics_initial,
		"Toggle anonymous usage data sharing",
		"Help improve the app by sharing anonymous gameplay statistics. No personal data is collected."
	)
	analytics_toggle.toggled.connect(func(enabled: bool):
		var mgr := get_node_or_null("/root/LegalConsentManager")
		if mgr and mgr.has_method("set_analytics_consent"):
			mgr.set_analytics_consent(enabled)
	)

	# Export My Data button
	var export_btn := Button.new()
	export_btn.text = "Export My Data"
	export_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.pressed.connect(_on_export_data_pressed)
	card_vbox.add_child(export_btn)

	# Delete All Data button (danger)
	var delete_btn := Button.new()
	delete_btn.text = "Delete All Data"
	delete_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DialogStyles.style_danger_button(delete_btn)
	delete_btn.pressed.connect(_on_delete_data_pressed)
	card_vbox.add_child(delete_btn)


func _on_export_data_pressed() -> void:
	var consent_mgr := get_node_or_null("/root/LegalConsentManager")
	if not consent_mgr or not consent_mgr.has_method("export_user_data"):
		return

	var manifest: Dictionary = consent_mgr.export_user_data()
	var json_text := JSON.stringify(manifest, "\t")

	# Save to user://data_export.json and notify
	var file := FileAccess.open("user://data_export.json", FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		var notify := get_node_or_null("/root/NotificationManager")
		if notify and notify.has_method("show_notification"):
			notify.show_notification(
				"Data exported to data_export.json in your user data folder.",
				"success"
			)
		else:
			var dialog := AcceptDialog.new()
			dialog.title = "Data Exported"
			dialog.dialog_text = "Your data manifest has been saved to:\nuser://data_export.json"
			add_child(dialog)
			dialog.popup_centered()
	else:
		var dialog := AcceptDialog.new()
		dialog.title = "Export Failed"
		dialog.dialog_text = "Could not write data export file."
		add_child(dialog)
		dialog.popup_centered()


func _on_delete_data_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete All Data?"
	dialog.dialog_text = (
		"This will permanently delete ALL app data including:\n\n"
		+ "  - All campaign save files\n"
		+ "  - Character portraits\n"
		+ "  - Settings and preferences\n"
		+ "  - Legal consent records\n\n"
		+ "This action cannot be undone. You will need to\n"
		+ "accept the EULA again after deletion."
	)
	dialog.ok_button_text = "Delete Everything"
	dialog.confirmed.connect(func():
		var consent_mgr := get_node_or_null("/root/LegalConsentManager")
		if consent_mgr and consent_mgr.has_method("delete_all_user_data"):
			consent_mgr.delete_all_user_data()
		# Navigate to main menu (which will re-trigger EULA)
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("main_menu", {}, false)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


# ============ UI HELPERS ============
func _create_section_card(title_text: String, parent: VBoxContainer) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(_spacing_md)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", _spacing_sm)
	card.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", _font_lg)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	return vbox


func _add_toggle_row(parent: VBoxContainer, label_text: String, initial: bool, acc_name: String = "", description: String = "") -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _spacing_sm)
	parent.add_child(row)

	# Left side: title + optional description (Fallout settings pattern)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", _font_md)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	text_col.add_child(label)

	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", _font_sm)
		desc.add_theme_color_override(
			"font_color", COLOR_TEXT_SECONDARY
		)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(desc)

	var toggle := CheckButton.new()
	toggle.button_pressed = initial
	toggle.custom_minimum_size.y = _touch_target
	if not acc_name.is_empty():
		toggle.accessibility_name = acc_name
	row.add_child(toggle)

	return toggle


func _add_slider_row(parent: VBoxContainer, label_text: String,
		min_val: float, max_val: float, step_val: float, initial: float, acc_name: String = "") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _spacing_sm)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 180
	label.add_theme_font_size_override("font_size", _font_md)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = _touch_target
	if not acc_name.is_empty():
		slider.accessibility_name = acc_name
	row.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%d%%" % int(initial * 100)
	val_label.custom_minimum_size.x = 50
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", _font_md)
	val_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	row.add_child(val_label)

	slider.value_changed.connect(func(v: float): val_label.text = "%d%%" % int(v * 100))

	return slider


func _create_accent_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, _touch_target)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_ACCENT_HOVER
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	return btn


func _create_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, _touch_target)
	return btn


# ============ PERSISTENCE ============
func _load_config() -> void:
	_config.load(_config_path)


func _on_save_pressed() -> void:
	# Audio
	_config.set_value("audio", "master_volume", _master_vol_slider.value)
	_config.set_value("audio", "music_volume", _music_vol_slider.value)
	_config.set_value("audio", "sfx_volume", _sfx_vol_slider.value)

	# Display (desktop-only fields guarded)
	if _is_desktop:
		_config.set_value("display", "fullscreen", _fullscreen_check.button_pressed)
		_config.set_value("display", "vsync_mode", _vsync_option.get_selected_id())
	_config.set_value("display", "ui_scale", _ui_scale_slider.value)

	# Gameplay
	_config.set_value("gameplay", "auto_save", _auto_save_check.button_pressed)
	_config.set_value("gameplay", "show_tooltips", _show_tooltips_check.button_pressed)
	_config.set_value("gameplay", "show_fps", _show_fps_check.button_pressed)
	_config.set_value("gameplay", "screen_shake", _screen_shake_check.button_pressed)

	# Mobile
	if _is_mobile:
		_config.set_value("mobile", "haptic_feedback", _haptic_check.button_pressed)
		_config.set_value("mobile", "touch_sensitivity", _touch_sensitivity_slider.value)

	_config.save(_config_path)
	_apply_settings()


func _on_reset_pressed() -> void:
	_master_vol_slider.value = 1.0
	_music_vol_slider.value = 0.8
	_sfx_vol_slider.value = 0.8
	if _is_desktop:
		_fullscreen_check.button_pressed = false
		for i in range(_vsync_option.item_count):
			if _vsync_option.get_item_id(i) == DisplayServer.VSYNC_ENABLED:
				_vsync_option.select(i)
				break
	_ui_scale_slider.value = 1.0
	_auto_save_check.button_pressed = true
	_show_tooltips_check.button_pressed = true
	_show_fps_check.button_pressed = false
	_screen_shake_check.button_pressed = true
	if _is_mobile:
		_haptic_check.button_pressed = true
		_touch_sensitivity_slider.value = 1.0


func _apply_settings() -> void:
	# Audio buses
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(_master_vol_slider.value))

	for bus_info in [["Music", _music_vol_slider], ["SFX", _sfx_vol_slider]]:
		var idx: int = AudioServer.get_bus_index(bus_info[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(bus_info[1].value))

	# Display — desktop only
	if _is_desktop:
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen_check.button_pressed \
			else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(_vsync_option.get_selected_id())


func _on_ui_scale_changed(value: float) -> void:
	if _ui_scale_label:
		_ui_scale_label.text = "%d%%" % int(value * 100)


func _on_debug_pressed() -> void:
	var DebugScreenScript: GDScript = load(
		"res://src/ui/screens/settings/DebugScreen.gd"
	)
	var debug_screen: Control = DebugScreenScript.new()
	debug_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_screen.back_requested.connect(func():
		debug_screen.queue_free()
	)
	add_child(debug_screen)

func _on_back_pressed() -> void:
	if overlay_mode:
		back_requested.emit()
		return
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_back"):
		router.navigate_back()
	elif router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")
