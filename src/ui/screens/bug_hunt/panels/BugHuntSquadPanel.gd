extends Control

## Bug Hunt Squad Panel — Step 2 of 4
## Generate 3-4 main characters, view their stats and backgrounds.

signal squad_updated(data: Dictionary)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")

var _coordinator = null
var _characters_container: VBoxContainer
var _generate_button: Button
var _status_label: Label
var _name_edits: Array[LineEdit] = []

var _squad_data: Dictionary = {
	"main_characters": [],
	"total_reputation": 0
}


func _ready() -> void:
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "SQUAD SETUP"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Your squad consists of 3-4 Main Characters. Enter names below (or leave blank for auto-names), then generate your squad."
	desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Name inputs
	var names_card := _create_card("Character Names", vbox)
	_name_edits.clear()
	for i in range(4):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		names_card.add_child(hbox)

		var lbl := Label.new()
		lbl.text = "Character %d:" % (i + 1)  # ISSUE-045: spell out, not "MC"
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.custom_minimum_size.x = 90
		hbox.add_child(lbl)

		var edit := LineEdit.new()
		edit.placeholder_text = "Auto-generate name" if i < 3 else "(Optional 4th character)"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.custom_minimum_size.y = 40
		hbox.add_child(edit)
		_name_edits.append(edit)

	# Generate button
	_generate_button = Button.new()
	_generate_button.text = "Generate Squad (D100 Tables)"
	_generate_button.custom_minimum_size.y = 56
	_generate_button.pressed.connect(_on_generate_squad)
	vbox.add_child(_generate_button)

	# Status
	_status_label = Label.new()
	_status_label.text = "No squad generated yet."
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	vbox.add_child(_status_label)

	# Characters display
	_characters_container = VBoxContainer.new()
	_characters_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_characters_container)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox


func _on_generate_squad() -> void:
	if not _coordinator or not _coordinator.has_method("generate_squad"):
		return

	var names: Array = []
	for edit in _name_edits:
		var txt: String = edit.text.strip_edges()
		if not txt.is_empty():
			names.append(txt)

	var result: Dictionary = _coordinator.generate_squad(names)
	_squad_data = result.duplicate(true)

	_display_squad()
	_emit_update()


func _display_squad() -> void:
	# Clear previous
	for child in _characters_container.get_children():
		child.queue_free()

	var characters: Array = _squad_data.get("main_characters", [])
	_status_label.text = "%d Main Characters generated. Starting Reputation: %d" % [
		characters.size(), _squad_data.get("total_reputation", 0)]
	_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)

	for mc in characters:
		if mc is Dictionary:
			_add_character_card(mc)


func _add_character_card(mc: Dictionary) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_characters_container.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# ISSUE-055: Colored initials avatar (matches CharacterCard pattern)
	var char_name: String = mc.get("name", "?")
	var avatar := Label.new()
	var initials := ""
	var parts := char_name.split(" ")
	for part in parts:
		if not part.is_empty():
			initials += part[0]
	if initials.is_empty():
		initials = "?"
	avatar.text = initials.substr(0, 2).to_upper()
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.add_theme_font_size_override("font_size", 16)
	# Deterministic color from name hash (8 colors like CharacterCard)
	var avatar_colors := [
		Color("#4FC3F7"), Color("#81C784"), Color("#FFB74D"),
		Color("#E57373"), Color("#BA68C8"), Color("#4DD0E1"),
		Color("#AED581"), Color("#FF8A65"),
	]
	var color_idx: int = char_name.hash() % avatar_colors.size()
	if color_idx < 0:
		color_idx += avatar_colors.size()
	var avatar_bg := StyleBoxFlat.new()
	avatar_bg.bg_color = avatar_colors[color_idx].darkened(0.4)
	avatar_bg.set_corner_radius_all(20)
	avatar_bg.set_content_margin_all(4)
	avatar.add_theme_stylebox_override("normal", avatar_bg)
	avatar.add_theme_color_override("font_color", avatar_colors[color_idx])
	hbox.add_child(avatar)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = char_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	info.add_child(name_lbl)

	var bg_lbl := Label.new()
	bg_lbl.text = "%s | %s | %s" % [
		mc.get("origin", "?"), mc.get("basic_training", "?"),
		mc.get("service_history", "?")]
	bg_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	bg_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(bg_lbl)

	# ISSUE-054: Stat badges in a flow container
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	info.add_child(stats_row)
	var stat_pairs := [
		["CS", mc.get("combat_skill", 0)],
		["React", mc.get("reactions", 0)],
		["Tough", mc.get("toughness", 0)],
		["Spd", mc.get("speed", 0)],
		["Savvy", mc.get("savvy", 0)],
		["XP", mc.get("xp", 0)],
	]
	for pair in stat_pairs:
		var badge := Label.new()
		badge.text = " %s %d " % [pair[0], pair[1]]
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", COLOR_TEXT)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
		badge_style.set_corner_radius_all(4)
		badge_style.content_margin_left = 4
		badge_style.content_margin_right = 4
		badge_style.content_margin_top = 2
		badge_style.content_margin_bottom = 2
		badge.add_theme_stylebox_override("normal", badge_style)
		stats_row.add_child(badge)

	if mc.get("commendation_xp", 0) > 0 or mc.get("commendation_rep", 0) > 0:
		var comm_lbl := Label.new()
		comm_lbl.text = "Commendation: +%d XP, +%d Rep" % [
			mc.get("commendation_xp", 0), mc.get("commendation_rep", 0)]
		comm_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		comm_lbl.add_theme_font_size_override("font_size", 12)
		info.add_child(comm_lbl)


func _emit_update() -> void:
	squad_updated.emit(_squad_data.duplicate(true))
