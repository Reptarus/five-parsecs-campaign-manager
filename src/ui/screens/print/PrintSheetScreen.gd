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
# Preloaded rather than referenced by its class_name, matching the three above and the
# same note in SheetRenderer.gd: the global class_name cache can lag behind file edits
# (CLAUDE.md "Preload Pattern for UI Class References" / Sprint 2 F4). A bare
# `SheetDataContext.build(...)` resolves fine in tests, which import fresh — the risk is
# an exported build, which is exactly where a blank sheet would be hardest to diagnose.
const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")

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
var _center_row: BoxContainer = null


func _ready() -> void:
	_apply_background()
	_build_layout()
	_render_active_sheet()
	_apply_responsive_layout()
	# Push the header below the floating gear/bug buttons. Must run after
	# _build_layout(): the MarginContainer it targets is created there.
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)

	# Short-screen scroll. This is also the "scrollable rail" fix: the preview and the
	# 240px action rail stack in portrait, and on a short screen the stack is taller
	# than the viewport, so Save PNG / Save PDF sat below the fold with no way to
	# reach them. The top bar stays pinned.
	var _sss_column := get_node_or_null("MarginContainer/VBoxContainer")
	if _sss_column == null:
		for _child in get_children():
			if _child is MarginContainer:
				for _inner in _child.get_children():
					if _inner is BoxContainer:
						_sss_column = _inner
						break
	if _sss_column is BoxContainer:
		var _sss = load("res://src/ui/components/base/ShortScreenScroll.gd").new()
		add_child(_sss)
		_sss.setup(_sss_column as BoxContainer, 1)

	# Hold the device landscape while a sheet is on screen. The sheets are 3:2
	# landscape pages from the rulebook — a fixed-aspect DOCUMENT, not a layout — so
	# in portrait the preview can only shrink to fit the width and the stat numbers
	# stop being readable. Nothing to reflow, so the orientation is the fix.
	# No-ops on desktop (FEATURE_ORIENTATION is false there) and restores on exit.
	var _orientation = load("res://src/ui/components/base/OrientationLock.gd").new()
	add_child(_orientation)
	_orientation.setup(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	var rm := get_node_or_null("/root/ResponsiveManager")
	# layout_class_changed, not breakpoint_changed: rotating a device keeps the
	# width bucket but flips portrait/landscape, and this screen only cares about
	# the latter (docs/sop/responsive-adaptive-ui.md).
	if rm and rm.has_signal("layout_class_changed"):
		# A METHOD callable, not a lambda. Godot cleans up connections whose target
		# object is freed, but a lambda's captures are not tracked that way — after
		# this screen is freed the autoload kept calling it, printing "Lambda capture
		# at index 0 was freed" on every rotation for the rest of the session.
		rm.layout_class_changed.connect(_on_layout_class_changed)


## The preview and the 240px action rail do not fit side by side in ~339 design px,
## so the rail was pushed off the right edge with Save PNG/PDF unreachable. Stack
## them instead. BoxContainer.vertical is the documented toggle for this — the same
## HBoxContainer becomes a column without rebuilding the tree.
func _apply_responsive_layout() -> void:
	if _center_row == null or not is_instance_valid(_center_row):
		return
	var rm := get_node_or_null("/root/ResponsiveManager")
	var stack := false
	if rm and rm.has_method("should_collapse_to_single_column"):
		stack = rm.should_collapse_to_single_column()
	_center_row.vertical = stack


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
	# One page-gutter rule for the whole app: 16dp in portrait, this screen's own
	# value restored in landscape. PortraitChrome reads the scene's current margin
	# as the landscape value, so the 24px here is preserved on wide layouts.
	ScreenChrome.apply_page_chrome(self, margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	margin.add_child(root_vbox)

	# ── Top bar: back + tabs ───────────────────────────────────────
	# HFlow: Back + title + the sheet tabs need 324px side by side, more than a 310px
	# phone, and an HBox has no way to give that back. They wrap onto a second line.
	var top_bar := HFlowContainer.new()
	top_bar.add_theme_constant_override("h_separation", UIColors.SPACING_MD)
	top_bar.add_theme_constant_override("v_separation", UIColors.SPACING_XS)
	root_vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	# Was left unstyled, so it rendered as a project-theme button next to a header
	# that otherwise matched the Library's exactly.
	DialogStyles.style_back_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "Print Sheet"
	title.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_XL))
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	# A Label with neither autowrap nor clipping demands its full unwrapped width as a
	# MINIMUM, and that minimum propagates to the top of the tree. In an HBox header the
	# fix is clip + ellipsis (autowrap here would make the row taller instead).
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	_tabs = TabBar.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Without this a TabBar's minimum width is the SUM of every tab label, which on this
	# screen is ~505px in a 339px space — the single largest driver of the whole screen
	# hanging off both edges. clip_tabs scrolls them instead.
	_tabs.clip_tabs = true
	for sheet in SHEETS:
		_tabs.add_tab(str(sheet.label))
	_tabs.tab_changed.connect(_on_tab_changed)
	top_bar.add_child(_tabs)

	# ── Center row: renderer + right rail ──────────────────────────
	# BoxContainer, NOT HBoxContainer. The H/V subclasses hard-set their orientation,
	# so assigning `vertical` on an HBoxContainer silently does nothing — verified
	# here by reading the property straight back off the running scene after the
	# assignment. The base class is the one whose `vertical` is actually togglable.
	# (Same rule as SplitContainer vs HSplitContainer, already in project memory.)
	var center := BoxContainer.new()
	center.vertical = false
	center.add_theme_constant_override("separation", UIColors.SPACING_MD)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(center)
	_center_row = center

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
	# A themed CheckBox comes out 40 design px = 41.8dp, under the 48dp floor, and
	# unlike Button/LineEdit its height is driven by the check icon rather than the
	# stylebox — adding content margins to checkbox_normal measurably did nothing.
	# Pin it explicitly.
	_blank_toggle.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_blank_toggle.toggled.connect(_on_blank_toggled)
	vbox.add_child(_blank_toggle)

	# Debug overlay — only visible in editor / debug builds.
	if OS.is_debug_build():
		_debug_toggle = CheckBox.new()
		_debug_toggle.text = "Debug overlay"
		_debug_toggle.tooltip_text = "Show field bounding rects (red) " \
			+ "for calibration"
		_debug_toggle.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
		_debug_toggle.toggled.connect(_on_debug_toggled)
		vbox.add_child(_debug_toggle)

	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override(
		"font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_SM))
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
	## Delegates to SheetDataContext, which projects the campaign into the shape the
	## field manifests address (T9-09). This used to hand the raw campaign Resource
	## straight to the renderer, so every `campaign.crew[N]` / `campaign.captain` /
	## `campaign.ship` path walked into a property that does not exist —
	## 154 of 163 sources resolved to null and the printed sheet came out 94.5% blank.
	## Pinned by tests/unit/test_sheet_source_paths_resolve.gd.
	var campaign: Object = null
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and "current_campaign" in game_state:
		campaign = game_state.get("current_campaign")

	var world: Variant = null
	var planet_mgr: Node = get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("get_current_planet"):
		world = planet_mgr.get_current_planet()

	var entries: Array = []
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	# `get_all_entries()` — NOT `get_entries()`, which has ZERO definitions repo-wide.
	# That made this a permanently-false branch (CLAUDE.md: "a has_method() guard on a
	# method with zero definitions is not a safety net"), so `entries` was ALWAYS [] and
	# the Encounter Log's whole journal block printed blank in every campaign on every
	# platform. Found on device, deploy #5, Aug 9 2026 — the unit suite calls
	# SheetDataContext.build() directly with entries, so it is structurally blind here.
	if journal and journal.has_method("get_all_entries"):
		entries = journal.get_all_entries()

	return SheetDataContextScript.build(campaign, world, entries)


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
	# MANDATORY on Android — see the note on _on_save_pdf_pressed().
	dialog.use_native_dialog = true
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
	# MANDATORY on Android (T9-10, measured on a TB361FU Aug 9 2026: without it the
	# save fails with error 13 / ERR_FILE_CANT_WRITE and NOTHING is written).
	#
	# Godot's own FileDialog browses the real filesystem, so it happily shows
	# /storage/emulated/0 and lets the player pick Documents/ — but the app requests
	# ONLY android.permission.INTERNET at targetSdk 35, and under scoped storage an
	# app with no storage permission cannot write there. The pick succeeds and the
	# WRITE fails, which is the worst possible split.
	#
	# use_native_dialog routes to the Android Storage Access Framework instead, which
	# needs no permission at all: the picker returns a content:// URI and the docs are
	# explicit that "this URI can be passed directly to FileAccess to perform
	# read/write operations". PDF.gd:137 and export_to_png() both write via FileAccess,
	# so the URI flows straight through.
	#
	# Per the Godot 4.6 docs this is supported on Android 10+ and ONLY for
	# ACCESS_FILESYSTEM — with ACCESS_RESOURCES/ACCESS_USERDATA it silently falls back
	# to the custom dialog. So do NOT "tidy" the access mode above; the two settings
	# only work as a pair.
	dialog.use_native_dialog = true
	dialog.file_selected.connect(_on_pdf_path_selected.bind(dialog))
	dialog.canceled.connect(_on_dialog_canceled.bind(dialog))
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()


## Put the screen into "working" state and let the UI actually PAINT it.
##
## Both exports rasterise a 2764x1843 sheet and write ~15 MB, so even after the
## bulk-write fix they are not instant. Without this the screen sat silent — measured
## over 4 minutes on device with no indication anything was happening, which reads as a
## freeze and invites the player to kill the app mid-write.
##
## The two awaited frames are load-bearing: setting a Label's text does not repaint it,
## and the export that follows blocks the main thread. Yield first or the "Exporting"
## message only becomes visible after the work it was describing has finished.
func _begin_export(what: String) -> void:
	_set_status("Exporting %s… this can take a few seconds for a full sheet." % what)
	_save_png_btn.disabled = true
	_save_pdf_btn.disabled = true
	await get_tree().process_frame
	await get_tree().process_frame


func _end_export(message: String) -> void:
	_set_status(message)
	_save_png_btn.disabled = false
	# Never re-enable a PDF button the backend cannot serve.
	_save_pdf_btn.disabled = not PdfExportRouter.is_pdf_available()


## The filename to show the player after a save.
##
## Android's native (SAF) dialog hands back a content:// URI, not a path — on
## device the status read
##   content://com.android.externalstorage.documents/document/primary%3Acrew_log_...
## wrapped over five lines. The player picked the location, so the location is not
## news; the filename is. Falls back to the whole string if nothing parses out,
## which is better than showing an empty "Saved:".
static func _display_file_name(path: String) -> String:
	var decoded: String = path.uri_decode()
	for separator: String in ["/", "\\", ":"]:
		if decoded.contains(separator):
			decoded = decoded.get_slice(separator, decoded.get_slice_count(separator) - 1)
	return decoded if not decoded.is_empty() else path


func _on_png_path_selected(path: String, dialog: FileDialog) -> void:
	_cleanup_dialog(dialog)
	if _renderer == null:
		_set_status("Renderer not ready.")
		return
	await _begin_export("PNG")
	var err: Error = await _renderer.export_to_png(path)
	if err == OK:
		_end_export("Saved PNG: %s" % _display_file_name(path))
	else:
		_end_export("PNG save failed (error %d)" % err)


func _on_pdf_path_selected(path: String, dialog: FileDialog) -> void:
	_cleanup_dialog(dialog)
	if _renderer == null:
		_set_status("Renderer not ready.")
		return
	await _begin_export("PDF")
	var err: Error = await _renderer.export_to_pdf(path)
	if err == ERR_UNAVAILABLE:
		_end_export("PDF backend not installed. Save as PNG instead.")
	elif err == OK:
		_end_export("Saved PDF: %s" % _display_file_name(path))
	else:
		_end_export("PDF save failed (error %d)" % err)


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


func _on_layout_class_changed(_cols: int = 0) -> void:
	_apply_responsive_layout()
