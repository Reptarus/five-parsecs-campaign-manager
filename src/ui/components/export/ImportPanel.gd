extends PanelContainer

## ImportPanel - Import campaign data from JSON files

signal back_pressed()
signal import_completed()

## Deep Space theme colors
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

var _selected_path: String = ""
var _parsed_data: Dictionary = {}
var _preview_container: VBoxContainer = null
var _status_label: Label = null
var _import_button: Button = null
var _file_dialog: FileDialog = null
var _game_state = null

func setup(game_state) -> void:
	_game_state = game_state

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	var back_btn = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.pressed.connect(func(): back_pressed.emit())
	header_hbox.add_child(back_btn)

	var title = Label.new()
	title.text = "Import Campaign Data"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header_hbox.add_child(title)

	# File selection
	var file_card = _create_card()
	vbox.add_child(file_card)

	var file_vbox = VBoxContainer.new()
	file_vbox.add_theme_constant_override("separation", 8)
	file_card.add_child(file_vbox)

	var file_label = Label.new()
	file_label.text = "Select File"
	file_label.add_theme_font_size_override("font_size", 16)
	file_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	file_vbox.add_child(file_label)

	var file_hbox = HBoxContainer.new()
	file_hbox.add_theme_constant_override("separation", 8)
	file_vbox.add_child(file_hbox)

	var browse_btn = Button.new()
	browse_btn.text = "Browse..."
	browse_btn.custom_minimum_size = Vector2(120, 40)
	browse_btn.pressed.connect(_on_browse_pressed)
	file_hbox.add_child(browse_btn)

	var path_label = Label.new()
	path_label.name = "PathLabel"
	path_label.text = "No file selected"
	path_label.add_theme_font_size_override("font_size", 13)
	path_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_hbox.add_child(path_label)

	# Preview section
	var preview_label = Label.new()
	preview_label.text = "Preview"
	preview_label.add_theme_font_size_override("font_size", 16)
	preview_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(preview_label)

	var preview_card = _create_card()
	vbox.add_child(preview_card)

	_preview_container = VBoxContainer.new()
	_preview_container.add_theme_constant_override("separation", 4)
	preview_card.add_child(_preview_container)

	_show_empty_preview()

	# Import button
	_import_button = Button.new()
	_import_button.text = "Import"
	_import_button.custom_minimum_size = Vector2(200, 48)
	_import_button.disabled = true
	_import_button.pressed.connect(_on_import_pressed)
	vbox.add_child(_import_button)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

func _show_empty_preview() -> void:
	if not _preview_container:
		return
	for child in _preview_container.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "Select a JSON file to preview its contents."
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	label.add_theme_font_size_override("font_size", 13)
	_preview_container.add_child(label)

func _on_browse_pressed() -> void:
	if _file_dialog and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Select Campaign File"
	_file_dialog.add_filter("*.json", "JSON Files")
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(600, 400))

func _on_file_selected(path: String) -> void:
	_selected_path = path

	var path_label = _find_node_by_name(self, "PathLabel")
	if path_label:
		path_label.text = path

	# Parse and validate
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status("Failed to open file.", COLOR_DANGER)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		_set_status("Invalid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()], COLOR_DANGER)
		_import_button.disabled = true
		return

	_parsed_data = json.data
	if not _parsed_data is Dictionary:
		_set_status("JSON root must be a dictionary/object.", COLOR_DANGER)
		_import_button.disabled = true
		return

	_show_preview()
	_validate_data()

func _show_preview() -> void:
	if not _preview_container:
		return
	for child in _preview_container.get_children():
		child.queue_free()

	var export_type = _parsed_data.get("export_type", "unknown")
	var export_version = _parsed_data.get("export_version", "?")

	_add_preview_row("Type", export_type.replace("_", " ").capitalize())
	_add_preview_row("Version", str(export_version))

	# Export timestamp
	var ts = _parsed_data.get("export_timestamp", 0)
	if ts > 0:
		_add_preview_row("Exported", Time.get_datetime_string_from_unix_time(int(ts)))

	# Campaign-specific preview
	if _parsed_data.has("campaign_state"):
		var state = _parsed_data.campaign_state
		if state is Dictionary:
			_add_preview_row("Campaign Name", state.get("campaign_name", state.get("name", "Unknown")))
			var resources = state.get("resources", {})
			_add_preview_row("Credits", str(resources.get("credits", "?")))
			var crew = state.get("crew_members", state.get("crew", []))
			if crew is Array:
				_add_preview_row("Crew Size", str(crew.size()))

	# Crew-specific preview
	if _parsed_data.has("crew_members"):
		var crew = _parsed_data.crew_members
		if crew is Array:
			_add_preview_row("Crew Members", str(crew.size()))

	# Journal-specific preview
	if _parsed_data.has("journal"):
		var journal = _parsed_data.journal
		if journal is Dictionary:
			var entries = journal.get("entries", [])
			if entries is Array:
				_add_preview_row("Journal Entries", str(entries.size()))
	elif _parsed_data.has("entries"):
		var entries = _parsed_data.get("entries", [])
		if entries is Array:
			_add_preview_row("Journal Entries", str(entries.size()))

func _add_preview_row(key: String, value: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_preview_container.add_child(hbox)

	var key_label = Label.new()
	key_label.text = key + ":"
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	key_label.custom_minimum_size.x = 120
	hbox.add_child(key_label)

	var val_label = Label.new()
	val_label.text = value
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	hbox.add_child(val_label)

func _validate_data() -> void:
	var export_type = _parsed_data.get("export_type", "")

	if export_type.is_empty():
		# Could be a raw save file or journal export
		if _parsed_data.has("campaign_state") or _parsed_data.has("entries") or _parsed_data.has("crew_members"):
			_set_status("File recognized. Ready to import.", COLOR_SUCCESS)
			_import_button.disabled = false
		else:
			_set_status("Unrecognized file format. Expected campaign, crew, or journal data.", COLOR_WARNING)
			_import_button.disabled = true
	else:
		_set_status("Valid %s export file. Ready to import." % export_type.replace("_", " "), COLOR_SUCCESS)
		_import_button.disabled = false

func _on_import_pressed() -> void:
	if _parsed_data.is_empty():
		return

	var export_type = _parsed_data.get("export_type", "")

	match export_type:
		"full_campaign":
			_import_full_campaign()
		"crew_only":
			_import_crew()
		"journal_only":
			_import_journal()
		_:
			# Try to detect type from data structure
			if _parsed_data.has("campaign_state"):
				_import_full_campaign()
			elif _parsed_data.has("crew_members"):
				_import_crew()
			elif _parsed_data.has("entries") or _parsed_data.has("journal"):
				_import_journal()
			else:
				_set_status("Cannot determine import type.", COLOR_DANGER)

func _import_full_campaign() -> void:
	# Import journal data
	if _parsed_data.has("journal"):
		var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
		if journal and journal.has_method("load_from_save"):
			journal.load_from_save({"qol_data": {"journal": _parsed_data.journal}})

	_set_status("Campaign data imported successfully.", COLOR_SUCCESS)
	import_completed.emit()

func _import_crew() -> void:
	_set_status("Crew import preview loaded. Full crew merge requires active campaign.", COLOR_WARNING)

func _import_journal() -> void:
	var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
	if not journal:
		_set_status("Campaign Journal not available.", COLOR_DANGER)
		return

	var journal_data = _parsed_data.get("journal", _parsed_data)
	if journal.has_method("load_from_save"):
		journal.load_from_save({"qol_data": {"journal": journal_data}})
		_set_status("Journal data imported successfully.", COLOR_SUCCESS)
		import_completed.emit()
	else:
		_set_status("Journal import method not available.", COLOR_DANGER)

func _set_status(text: String, color: Color) -> void:
	if _status_label:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)

func _create_card() -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null
