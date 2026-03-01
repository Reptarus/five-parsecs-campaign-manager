extends PanelContainer

## ExportPanel - Campaign data export with scope and format selection

signal back_pressed()
signal export_completed(path: String)

## Deep Space theme colors
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_DANGER := Color("#DC2626")

## Export scopes
enum ExportScope { FULL_CAMPAIGN, CREW_ONLY, JOURNAL_ONLY }

var _scope: ExportScope = ExportScope.FULL_CAMPAIGN
var _format_json: bool = true
var _format_markdown: bool = false
var _status_label: Label = null
var _export_dialog: FileDialog = null
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
	title.text = "Export Campaign Data"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header_hbox.add_child(title)

	# Scope selector
	var scope_card = _create_card()
	vbox.add_child(scope_card)

	var scope_vbox = VBoxContainer.new()
	scope_vbox.add_theme_constant_override("separation", 8)
	scope_card.add_child(scope_vbox)

	var scope_label = Label.new()
	scope_label.text = "Export Scope"
	scope_label.add_theme_font_size_override("font_size", 16)
	scope_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	scope_vbox.add_child(scope_label)

	var scope_option = OptionButton.new()
	scope_option.add_item("Full Campaign (all data + journal)", 0)
	scope_option.add_item("Crew Only (characters + equipment)", 1)
	scope_option.add_item("Journal Only (timeline + entries)", 2)
	scope_option.custom_minimum_size = Vector2(300, 40)
	scope_option.item_selected.connect(_on_scope_changed)
	scope_vbox.add_child(scope_option)

	var scope_desc = Label.new()
	scope_desc.name = "ScopeDescription"
	scope_desc.text = "Exports complete campaign state including crew, resources, world data, and journal entries."
	scope_desc.add_theme_font_size_override("font_size", 13)
	scope_desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	scope_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope_vbox.add_child(scope_desc)

	# Format selector
	var format_card = _create_card()
	vbox.add_child(format_card)

	var format_vbox = VBoxContainer.new()
	format_vbox.add_theme_constant_override("separation", 8)
	format_card.add_child(format_vbox)

	var format_label = Label.new()
	format_label.text = "Export Format"
	format_label.add_theme_font_size_override("font_size", 16)
	format_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	format_vbox.add_child(format_label)

	var json_check = CheckBox.new()
	json_check.text = "JSON Data (machine-readable, re-importable)"
	json_check.button_pressed = true
	json_check.custom_minimum_size.y = 36
	json_check.toggled.connect(func(pressed): _format_json = pressed)
	format_vbox.add_child(json_check)

	var md_check = CheckBox.new()
	md_check.text = "Markdown Narrative (human-readable journal)"
	md_check.button_pressed = false
	md_check.custom_minimum_size.y = 36
	md_check.toggled.connect(func(pressed): _format_markdown = pressed)
	format_vbox.add_child(md_check)

	# Export button
	var export_btn = Button.new()
	export_btn.text = "Export"
	export_btn.custom_minimum_size = Vector2(200, 48)
	export_btn.pressed.connect(_on_export_pressed)
	vbox.add_child(export_btn)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

func _on_scope_changed(index: int) -> void:
	_scope = index as ExportScope
	var desc_node = _find_node_by_name(self, "ScopeDescription")
	if desc_node:
		match _scope:
			ExportScope.FULL_CAMPAIGN:
				desc_node.text = "Exports complete campaign state including crew, resources, world data, and journal entries."
			ExportScope.CREW_ONLY:
				desc_node.text = "Exports crew member data: characters, stats, equipment, and advancement history."
			ExportScope.JOURNAL_ONLY:
				desc_node.text = "Exports campaign journal timeline, entries, milestones, and character histories."

func _on_export_pressed() -> void:
	if not _format_json and not _format_markdown:
		_set_status("Please select at least one export format.", COLOR_DANGER)
		return

	if _format_json:
		_show_file_dialog("json")
	elif _format_markdown:
		_show_file_dialog("markdown")

func _show_file_dialog(format: String) -> void:
	if _export_dialog and is_instance_valid(_export_dialog):
		_export_dialog.queue_free()

	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.title = "Export Campaign Data"

	if format == "json":
		_export_dialog.add_filter("*.json", "JSON Files")
		_export_dialog.current_file = _get_default_filename("json")
	else:
		_export_dialog.add_filter("*.md", "Markdown Files")
		_export_dialog.current_file = _get_default_filename("md")

	_export_dialog.file_selected.connect(func(path: String): _do_export(format, path))
	add_child(_export_dialog)
	_export_dialog.popup_centered(Vector2i(600, 400))

func _get_default_filename(ext: String) -> String:
	match _scope:
		ExportScope.FULL_CAMPAIGN:
			return "campaign_export.%s" % ext
		ExportScope.CREW_ONLY:
			return "crew_export.%s" % ext
		ExportScope.JOURNAL_ONLY:
			return "journal_export.%s" % ext
	return "export.%s" % ext

func _do_export(format: String, path: String) -> void:
	var success = false

	match _scope:
		ExportScope.FULL_CAMPAIGN:
			success = _export_full_campaign(format, path)
		ExportScope.CREW_ONLY:
			success = _export_crew(format, path)
		ExportScope.JOURNAL_ONLY:
			success = _export_journal(format, path)

	if success:
		_set_status("Exported successfully to: %s" % path, COLOR_SUCCESS)
		export_completed.emit(path)

		# If both formats selected, export the second one too
		if _format_json and _format_markdown and format == "json":
			var md_path = path.get_basename() + ".md"
			_do_export("markdown", md_path)
	else:
		_set_status("Export failed. Check output log for details.", COLOR_DANGER)

func _export_full_campaign(format: String, path: String) -> bool:
	if format == "json":
		var data = {}
		data["export_type"] = "full_campaign"
		data["export_version"] = 1
		data["export_timestamp"] = Time.get_unix_time_from_system()

		# Campaign state
		if _game_state and _game_state.has_method("serialize"):
			data["campaign_state"] = _game_state.serialize()
		elif _game_state and "campaign" in _game_state and _game_state.campaign and _game_state.campaign.has_method("serialize"):
			data["campaign_state"] = _game_state.campaign.serialize()

		# Journal data
		var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
		if journal and journal.has_method("save_to_dict"):
			data["journal"] = journal.save_to_dict()

		return _write_json(path, data)
	else:
		# Markdown: use journal export
		var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
		if journal and journal.has_method("export_to_markdown"):
			return journal.export_to_markdown(path)
		return false

func _export_crew(format: String, path: String) -> bool:
	if not _game_state or not "campaign" in _game_state or not _game_state.campaign:
		_set_status("No campaign data available.", COLOR_DANGER)
		return false

	if format == "json":
		var data = {
			"export_type": "crew_only",
			"export_version": 1,
			"export_timestamp": Time.get_unix_time_from_system(),
			"crew_members": []
		}

		var crew = _game_state.campaign.crew_members if "crew_members" in _game_state.campaign else []
		for member in crew:
			var char_data = member.character if "character" in member else member
			if char_data and char_data.has_method("serialize"):
				data.crew_members.append(char_data.serialize())
			elif char_data and char_data.has_method("to_dictionary"):
				data.crew_members.append(char_data.to_dictionary())

		return _write_json(path, data)
	else:
		# Markdown crew summary
		var md = "# Crew Roster\n\n"
		var crew = _game_state.campaign.crew_members if "crew_members" in _game_state.campaign else []
		for member in crew:
			var char_data = member.character if "character" in member else member
			var char_name = char_data.character_name if "character_name" in char_data else "Unknown"
			md += "## %s\n" % char_name
			if "lifetime_kills" in char_data:
				md += "- Kills: %d\n" % char_data.lifetime_kills
			if "missions_completed" in char_data:
				md += "- Missions: %d\n" % char_data.missions_completed
			if "credits_earned" in char_data:
				md += "- Credits Earned: %d\n" % char_data.credits_earned
			md += "\n"
		return _write_text(path, md)

func _export_journal(format: String, path: String) -> bool:
	var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
	if not journal:
		_set_status("Campaign Journal not available.", COLOR_DANGER)
		return false

	if format == "json":
		return journal.export_to_json(path)
	else:
		return journal.export_to_markdown(path)

func _write_json(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("ExportPanel: Failed to open file: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func _write_text(path: String, text: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("ExportPanel: Failed to open file: " + path)
		return false
	file.store_string(text)
	file.close()
	return true

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
