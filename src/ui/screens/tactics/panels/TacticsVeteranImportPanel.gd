extends Control

## Tactics Veteran Import Panel — commission a 5PFH / Bug Hunt / Planetfall veteran
## into a Tactics force as a named officer/hero figure (Tactics pp.184-185).
##
## Flow: select source character → preview the Tactics conversion → commission.
## Emits veteran_commissioned(veteran_dict). The veteran is a named figure attached
## to the army, NOT a squad unit — it is stored in TacticsCampaignCore.veteran_characters[].
##
## Conversion (Tactics p.184): Combat capped at +2; Toughness capped at 5; 1 Kill
## Point per Luck point; Training +1 (+2 with a military-type background); weapons
## carry over. No points cost — "eyeball the closest equivalent figure".

signal veteran_commissioned(veteran: Dictionary)
signal import_cancelled

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_WARNING := _UC.COLOR_WARNING
const COLOR_CYAN := _UC.COLOR_CYAN

const TransferServiceClass := preload("res://src/core/character/CharacterTransferService.gd")

var _transfer_service: TransferServiceClass
var _source_characters: Array = []

var _content: VBoxContainer
var _step_container: VBoxContainer


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_transfer_service = TransferServiceClass.new()
	_build_ui()


## Load every standard / Bug Hunt / Planetfall save in user://saves/ as a source.
func load_all_sources() -> void:
	_source_characters.clear()
	var dir := DirAccess.open("user://saves/")
	if dir:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while not fn.is_empty():
			if fn.ends_with(".save"):
				_load_from_save_file("user://saves/" + fn)
			fn = dir.get_next()
		dir.list_dir_end()
	_show_step_1()


func _load_from_save_file(save_path: String) -> void:
	if not FileAccess.file_exists(save_path):
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
	var chars: Array = []
	var src_mode := "five_parsecs"
	if data.has("squad") and data.squad is Dictionary:
		chars = data.squad.get("main_characters", [])
		src_mode = "bug_hunt"
	elif data.has("roster") and data.roster is Array:
		chars = data.roster
		src_mode = "planetfall"
	elif data.has("crew") and data.crew is Dictionary:
		chars = data.crew.get("members", [])
		src_mode = "five_parsecs"
	for c in chars:
		if c is Dictionary:
			var tagged: Dictionary = (c as Dictionary).duplicate(true)
			tagged["_source_mode"] = src_mode
			_source_characters.append(tagged)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(COLOR_BASE, 0.95)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_left", 24)
	scroll.add_theme_constant_override("margin_right", 24)
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)

	_step_container = VBoxContainer.new()
	_step_container.add_theme_constant_override("separation", 12)
	_content.add_child(_step_container)


func _show_step_1() -> void:
	_clear_steps()

	var title := Label.new()
	title.text = "COMMISSION VETERAN"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	var note := Label.new()
	note.text = "Bring a veteran from another campaign into your force as a named officer or hero (Tactics p.185). They join as an individual figure, not a squad unit."
	note.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	note.add_theme_font_size_override("font_size", _scaled_font(13))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_container.add_child(note)

	var any := false
	for char_data in _source_characters:
		if char_data is not Dictionary:
			continue
		if str(char_data.get("status", "active")).to_lower() in ["dead", "retired", "missing"]:
			continue
		any = true
		_build_select_card(char_data)

	if not any:
		var empty := Label.new()
		empty.text = "No eligible veterans found in your saves."
		empty.add_theme_color_override("font_color", COLOR_WARNING)
		_step_container.add_child(empty)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(200, 44)
	cancel.pressed.connect(func() -> void:
		import_cancelled.emit()
		queue_free())
	_step_container.add_child(cancel)


func _build_select_card(char_data: Dictionary) -> void:
	var char_name: String = char_data.get("name", char_data.get("character_name", "Unknown"))
	var sm := str(char_data.get("_source_mode", "five_parsecs"))
	var origin := {"bug_hunt": "Bug Hunt", "planetfall": "Planetfall"}.get(sm, "5PFH")
	var card := _create_glass_card(_step_container)

	var name_lbl := Label.new()
	name_lbl.text = "%s  [%s]" % [char_name, origin]
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(name_lbl)

	var select_btn := Button.new()
	select_btn.text = "Select %s" % char_name
	select_btn.custom_minimum_size = Vector2(200, 44)
	var captured: Dictionary = char_data.duplicate(true)
	select_btn.pressed.connect(func() -> void: _show_step_2(captured))
	card.add_child(select_btn)


func _show_step_2(source_char: Dictionary) -> void:
	_clear_steps()
	var sm := str(source_char.get("_source_mode", "five_parsecs"))

	# Canonical 5PFH-standard form is the lossless snapshot; convert INTO Tactics.
	var canonical: Dictionary = _transfer_service.export_to_canonical(source_char, sm)
	var veteran: Dictionary = _transfer_service.convert_to_tactics(canonical, "5pfh")

	var char_name: String = veteran.get("name", "Unknown")
	var title := Label.new()
	title.text = "COMMISSION PREVIEW: %s" % char_name
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	var card := _create_glass_card(_step_container)
	_add_preview_row(card, "Combat", "+%d (capped at +2)" % veteran.get("combat_skill", 0), COLOR_TEXT)
	_add_preview_row(card, "Reactions", str(veteran.get("reactions", 0)), COLOR_TEXT)
	_add_preview_row(card, "Speed", str(veteran.get("speed", 0)), COLOR_TEXT)
	_add_preview_row(card, "Toughness", "%d (capped at 5)" % veteran.get("toughness", 0), COLOR_TEXT)
	_add_preview_row(card, "Savvy", str(veteran.get("savvy", 0)), COLOR_TEXT)
	_add_preview_row(card, "Kill Points",
		"%d (1 per Luck point)" % veteran.get("kill_points", 0), COLOR_SUCCESS)
	_add_preview_row(card, "Training",
		"+%d%s" % [veteran.get("training", 1),
			"  (military-type background)" if veteran.get("training", 1) >= 2 else ""],
		COLOR_SUCCESS if veteran.get("training", 1) >= 2 else COLOR_TEXT)
	_add_preview_row(card, "Role", "Named veteran (officer/hero) — not a squad unit", COLOR_CYAN)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_step_container.add_child(btn_row)

	var commission_btn := Button.new()
	commission_btn.text = "Commission %s" % char_name
	commission_btn.custom_minimum_size = Vector2(240, 52)
	commission_btn.pressed.connect(func() -> void:
		_finalize(veteran, canonical))
	btn_row.add_child(commission_btn)

	var back_btn := Button.new()
	back_btn.text = "Go Back"
	back_btn.custom_minimum_size = Vector2(140, 48)
	back_btn.pressed.connect(func() -> void: _show_step_1())
	btn_row.add_child(back_btn)


func _finalize(veteran: Dictionary, canonical: Dictionary) -> void:
	veteran["is_imported"] = true
	# Embed the lossless 5PFH-standard snapshot so a later retirement restores the
	# original veteran verbatim (strip any nested snapshot to avoid recursion).
	var clean: Dictionary = canonical.duplicate(true)
	clean.erase("snapshot")
	veteran["snapshot"] = clean
	veteran_commissioned.emit(veteran)
	queue_free()


# ── Helpers (mirrored from the Planetfall import panel) ─────────────────

func _clear_steps() -> void:
	if _step_container:
		for child in _step_container.get_children():
			child.queue_free()


func _add_preview_row(parent: VBoxContainer, label: String, value: String, color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	lbl.custom_minimum_size.x = 140
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_color_override("font_color", color)
	val.add_theme_font_size_override("font_size", _scaled_font(14))
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(val)


func _create_glass_card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	return vbox
