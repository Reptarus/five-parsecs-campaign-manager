extends Control

## Full-screen viewer for printable Modiphius sheets. Tabs across the 3 Core
## Rulebook sheets (CrewLog / EncounterLog / WorldRecordSheet). Save PNG works
## universally; Save PDF works when GodotHaru or GodotPDF addons are installed.
##
## Entry points:
##   - SceneRouter "print_sheet"
##   - CampaignDashboard "Sheets" button
##   - CharacterDetailsScreen EntityCardActionsRow ACTION_PRINT (Sprint 2 Item 6)
##
## Code-built layout (matches BattleSimulatorUI pattern). The .tscn is a thin
## shell that attaches this script.

const SheetRenderer = preload("res://src/ui/components/sheet/SheetRenderer.gd")
const PdfExportRouter = preload("res://src/core/export/PdfExportRouter.gd")
const UIColors = preload("res://src/ui/components/base/UIColors.gd")

const SHEETS: Array[Dictionary] = [
	{"id": "crew_log", "label": "Crew Log"},
	{"id": "encounter_log", "label": "Encounter Log"},
	{"id": "world_record_sheet", "label": "World Record"},
]

var _tabs: TabBar = null
var _renderer: SheetRenderer = null
var _save_png_btn: Button = null
var _save_pdf_btn: Button = null
var _blank_toggle: CheckBox = null
var _debug_toggle: CheckBox = null
var _status_label: Label = null
var _active_dialogs: Array[Node] = []


func _ready() -> void:
	_apply_background()
	_build_layout()
	_render_active_sheet()


func _apply_background() -> void:
	var bg := ColorRect.new()
	bg.name = "__bg"
	bg.color = UIColors.COLOR_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UIColors.SPACING_LG)
	margin.add_theme_constant_override("margin_right", UIColors.SPACING_LG)
	margin.add_theme_constant_override("margin_top", UIColors.SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", UIColors.SPACING_MD)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	margin.add_child(root_vbox)

	# ── Top bar: back + tabs ───────────────────────────────────────
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", UIColors.SPACING_MD)
	root_vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, UIColors.TOUCH_TARGET_MIN)
	back_btn.pressed.connect(_on_back_pressed)
	top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "Print Sheet"
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	top_bar.add_child(title)

	_tabs = TabBar.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sheet in SHEETS:
		_tabs.add_tab(str(sheet.label))
	_tabs.tab_changed.connect(_on_tab_changed)
	top_bar.add_child(_tabs)

	# ── Center row: renderer + right rail ──────────────────────────
	var center := HBoxContainer.new()
	center.add_theme_constant_override("separation", UIColors.SPACING_MD)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(center)

	_renderer = SheetRenderer.new()
	_renderer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_renderer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_renderer)

	var rail := _build_right_rail()
	center.add_child(rail)


func _build_right_rail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_ELEVATED
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(UIColors.SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	panel.add_child(vbox)

	_save_png_btn = Button.new()
	_save_png_btn.text = "Save PNG"
	_save_png_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_save_png_btn.pressed.connect(_on_save_png_pressed)
	vbox.add_child(_save_png_btn)

	_save_pdf_btn = Button.new()
	_save_pdf_btn.text = "Save PDF"
	_save_pdf_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_save_pdf_btn.disabled = not PdfExportRouter.is_pdf_available()
	if _save_pdf_btn.disabled:
		_save_pdf_btn.tooltip_text = "PDF backend not installed " \
			+ "(GodotHaru or GodotPDF addon required)"
	_save_pdf_btn.pressed.connect(_on_save_pdf_pressed)
	vbox.add_child(_save_pdf_btn)

	vbox.add_child(HSeparator.new())

	_blank_toggle = CheckBox.new()
	_blank_toggle.text = "Print blank"
	_blank_toggle.tooltip_text = "Hide data overlay — for filling by hand on paper"
	_blank_toggle.toggled.connect(_on_blank_toggled)
	vbox.add_child(_blank_toggle)

	# Debug overlay — only visible in editor / debug builds.
	if OS.is_debug_build():
		_debug_toggle = CheckBox.new()
		_debug_toggle.text = "Debug overlay"
		_debug_toggle.tooltip_text = "Show field bounding rects (red) " \
			+ "for calibration"
		_debug_toggle.toggled.connect(_on_debug_toggled)
		vbox.add_child(_debug_toggle)

	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM)
	_status_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY)
	vbox.add_child(_status_label)

	# Pad bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	return panel


# ── Render + data context ──────────────────────────────────────────────────

func _render_active_sheet() -> void:
	if _renderer == null or _tabs == null:
		return
	var idx: int = _tabs.current_tab
	if idx < 0 or idx >= SHEETS.size():
		idx = 0
	var sheet_id: String = str(SHEETS[idx].id)
	_renderer.render_sheet(sheet_id, _build_data_context())


func _build_data_context() -> Dictionary:
	var ctx: Dictionary = {}
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and "current_campaign" in game_state:
		ctx["campaign"] = game_state.get("current_campaign")
	var planet_mgr: Node = get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("get_current_planet"):
		ctx["world"] = planet_mgr.get_current_planet()
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal:
		var entries: Array = []
		if journal.has_method("get_entries"):
			entries = journal.get_entries()
		# last_battle convenience: most recent entry where type == "battle"
		var last_battle: Dictionary = {}
		for i in range(entries.size() - 1, -1, -1):
			var entry: Variant = entries[i]
			if entry is Dictionary \
					and str((entry as Dictionary).get("type", "")) == "battle":
				last_battle = entry
				break
		ctx["journal"] = {
			"entries": entries,
			"last_battle": last_battle,
		}
	return ctx


# ── Signal handlers ────────────────────────────────────────────────────────

func _on_tab_changed(_idx: int) -> void:
	_render_active_sheet()


func _on_blank_toggled(pressed: bool) -> void:
	if _renderer:
		_renderer.set_blank_mode(pressed)
		_render_active_sheet()


func _on_debug_toggled(pressed: bool) -> void:
	if _renderer:
		_renderer.set_debug_overlay(pressed)


func _on_back_pressed() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_back"):
		router.navigate_back()
	elif router and router.has_method("navigate_to"):
		router.navigate_to("campaign_dashboard")
	else:
		get_tree().change_scene_to_file(
			"res://src/ui/screens/mainmenu/MainMenu.tscn")


func _on_save_png_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	dialog.title = "Save Sheet as PNG"
	dialog.current_file = _default_filename("png")
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(_on_png_path_selected.bind(dialog))
	dialog.canceled.connect(_on_dialog_canceled.bind(dialog))
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()


func _on_save_pdf_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.pdf ; PDF Documents"])
	dialog.title = "Save Sheet as PDF"
	dialog.current_file = _default_filename("pdf")
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(_on_pdf_path_selected.bind(dialog))
	dialog.canceled.connect(_on_dialog_canceled.bind(dialog))
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()


func _on_png_path_selected(path: String, dialog: FileDialog) -> void:
	_cleanup_dialog(dialog)
	if _renderer == null:
		_set_status("Renderer not ready.")
		return
	var err: Error = await _renderer.export_to_png(path)
	if err == OK:
		_set_status("Saved PNG: %s" % path)
	else:
		_set_status("PNG save failed (error %d)" % err)


func _on_pdf_path_selected(path: String, dialog: FileDialog) -> void:
	_cleanup_dialog(dialog)
	if _renderer == null:
		_set_status("Renderer not ready.")
		return
	var err: Error = await _renderer.export_to_pdf(path)
	if err == ERR_UNAVAILABLE:
		_set_status("PDF backend not installed. Saved PNG fallback recommended.")
	elif err == OK:
		_set_status("Saved PDF: %s" % path)
	else:
		_set_status("PDF save failed (error %d)" % err)


func _on_dialog_canceled(dialog: FileDialog) -> void:
	_cleanup_dialog(dialog)


func _cleanup_dialog(dialog: Node) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	_active_dialogs.erase(dialog)


func _default_filename(ext: String) -> String:
	var idx: int = _tabs.current_tab if _tabs else 0
	var sheet_id: String = str(SHEETS[idx].id) if idx >= 0 \
		and idx < SHEETS.size() else "sheet"
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	return "%s_%s.%s" % [sheet_id, stamp, ext]


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
