extends Control

## Character Transfer Panel — Transfer characters between 5PFH and Bug Hunt.
## Used in BugHuntCreationUI (Squad Setup) and BugHuntDashboard.

signal character_transferred(character_data: Dictionary, direction: String)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_ACCENT := Color("#2D5A7B")

const TransferServiceClass := preload("res://src/core/character/CharacterTransferService.gd")

var _transfer_service: TransferServiceClass
var _source_characters: Array = []
var _direction: String = "enlist"  # "enlist" (5PFH→BH) or "muster_out" (BH→5PFH)

var _character_list: VBoxContainer
var _result_container: VBoxContainer
var _title_label: Label


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_transfer_service = TransferServiceClass.new()
	_build_ui()


func set_direction(dir: String) -> void:
	## "enlist" for 5PFH → Bug Hunt, "muster_out" for Bug Hunt → 5PFH
	_direction = dir
	if _title_label:
		if _direction == "enlist":
			_title_label.text = "ENLIST CHARACTER (5PFH → Bug Hunt)"
		else:
			_title_label.text = "MUSTER OUT (Bug Hunt → 5PFH)"


func load_characters_from_save(save_path: String) -> void:
	## Load characters from a save file for transfer selection.
	_source_characters.clear()

	if not FileAccess.file_exists(save_path):
		push_warning("CharacterTransferPanel: Save file not found: %s" % save_path)
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()

	var data: Dictionary = json.data if json.data is Dictionary else {}

	# Try to find crew/characters in various save formats
	if data.has("squad") and data.squad is Dictionary:
		# Bug Hunt format
		_source_characters = data.squad.get("main_characters", [])
	elif data.has("crew") and data.crew is Dictionary:
		# Standard format
		var members: Array = data.crew.get("members", [])
		_source_characters = members
	elif data.has("crew_members"):
		_source_characters = data.crew_members

	_populate_character_list()


func load_characters_from_array(characters: Array) -> void:
	## Directly set characters for transfer selection.
	_source_characters = characters
	_populate_character_list()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "ENLIST CHARACTER (5PFH → Bug Hunt)"
	_title_label.add_theme_font_size_override("font_size", _scaled_font(22))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Info
	var info := Label.new()
	info.text = "Select a character to transfer. Enlistment requires a 2D6+Combat Skill roll of 8+.\nAll equipment is stashed except one Pistol. Stats carry over."
	info.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info.add_theme_font_size_override("font_size", _scaled_font(14))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	# Load from save button
	var load_btn := Button.new()
	load_btn.text = "Load Characters from Save File"
	load_btn.custom_minimum_size = Vector2(260, 44)
	load_btn.pressed.connect(_on_load_save)
	vbox.add_child(load_btn)

	# Character list
	_character_list = VBoxContainer.new()
	_character_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_character_list)

	# Transfer result
	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_result_container)


func _on_load_save() -> void:
	## Show a file dialog to select a save file.
	# List available saves
	var save_dir := "user://saves/"
	if not DirAccess.dir_exists_absolute(save_dir):
		_show_result("No save directory found.", COLOR_WARNING)
		return

	var dir := DirAccess.open(save_dir)
	if not dir:
		return

	var saves: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".save"):
			saves.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if saves.is_empty():
		_show_result("No save files found.", COLOR_WARNING)
		return

	# Show saves as buttons
	for child in _character_list.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "Select a save file:"
	header.add_theme_color_override("font_color", COLOR_TEXT)
	_character_list.add_child(header)

	for save_name in saves:
		var btn := Button.new()
		btn.text = save_name
		btn.custom_minimum_size.y = 36
		var path: String = save_dir + save_name
		btn.pressed.connect(func(): load_characters_from_save(path))
		_character_list.add_child(btn)


func _populate_character_list() -> void:
	for child in _character_list.get_children():
		child.queue_free()

	if _source_characters.is_empty():
		var lbl := Label.new()
		lbl.text = "No eligible characters found in this save."
		lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_character_list.add_child(lbl)
		return

	for char_data in _source_characters:
		if char_data is not Dictionary:
			continue

		var char_name: String = char_data.get("name", char_data.get("character_name", "Unknown"))
		var game_mode: String = char_data.get("game_mode", "standard")

		# Check eligibility
		var eligible: bool = false
		if _direction == "enlist" and game_mode == "standard":
			eligible = true
		elif _direction == "muster_out" and game_mode == "bug_hunt" and not char_data.get("is_grunt", false):
			eligible = true

		if not eligible:
			continue

		var card := _create_card(char_name, _character_list)

		# Stats display
		var stats_text := "React:%d Spd:%d CS:%d Tough:%d Savvy:%d" % [
			char_data.get("reactions", char_data.get("reaction", 0)),
			char_data.get("speed", 0),
			char_data.get("combat_skill", char_data.get("combat", 0)),
			char_data.get("toughness", 0),
			char_data.get("savvy", 0)]
		var stats_lbl := Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		stats_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		card.add_child(stats_lbl)

		# Transfer button
		var transfer_btn := Button.new()
		if _direction == "enlist":
			var combat: int = char_data.get("combat_skill", char_data.get("combat", 0))
			transfer_btn.text = "Attempt Enlistment (2D6+%d >= 8)" % combat
		else:
			transfer_btn.text = "Muster Out to 5PFH"
		transfer_btn.custom_minimum_size.y = 36
		# Capture char_data in lambda
		var captured_data: Dictionary = char_data.duplicate(true)
		transfer_btn.pressed.connect(func(): _attempt_transfer(captured_data))
		card.add_child(transfer_btn)


func _attempt_transfer(char_data: Dictionary) -> void:
	for child in _result_container.get_children():
		child.queue_free()

	if _direction == "enlist":
		var result := _transfer_service.attempt_enlistment(char_data)
		if result.success:
			var transferred: Dictionary = result.transferred_character
			_show_result(
				"ENLISTED! Rolled %d (needed %d). %s is now a Bug Hunter!" % [
					result.roll, result.target,
					transferred.get("name", "Unknown")],
				COLOR_SUCCESS)
			character_transferred.emit(transferred, "enlist")
		else:
			_show_result(
				"REJECTED. Rolled %d (needed %d). %s" % [
					result.roll, result.target, result.get("reason", "")],
				COLOR_DANGER)
	else:
		var result := _transfer_service.muster_out(char_data)
		if result.success:
			var transferred: Dictionary = result.transferred_character
			_show_result(
				"MUSTERED OUT! %s leaves military service and joins your crew." % [
					transferred.get("name", "Unknown")],
				COLOR_SUCCESS)
			character_transferred.emit(transferred, "muster_out")
		else:
			_show_result(result.get("reason", "Transfer failed"), COLOR_DANGER)


func _show_result(text: String, color: Color) -> void:
	for child in _result_container.get_children():
		child.queue_free()
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_container.add_child(lbl)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox
