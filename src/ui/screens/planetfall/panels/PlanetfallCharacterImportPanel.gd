extends Control

## Planetfall Character Import Panel — guided flow for importing a 5PFH or Bug Hunt
## veteran into a Planetfall colony (Planetfall pp.26-29).
##
## Flow: select source character → preview conversion → Class Training aptitude
##       test → finalize. Emits character_imported(planetfall_char).
##
## Conversion (book): 5PFH Luck → 1 KP each; Bug Hunt Tech → Savvy; imported
## characters begin Loyal; up to 3 may be Class-Trained (1 per class).

signal character_imported(planetfall_char: Dictionary)
signal import_cancelled

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_WARNING := _UC.COLOR_WARNING
const COLOR_DANGER := _UC.COLOR_DANGER
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_CYAN := _UC.COLOR_CYAN

const TransferServiceClass := preload("res://src/core/character/CharacterTransferService.gd")
const PLANETFALL_CLASSES := ["trooper", "scientist", "scout"]

var _transfer_service: TransferServiceClass
var _source_characters: Array = []
## Classes already filled by imported trainees + count, for the max-3 / 1-per-class cap.
var _taken_classes: Array = []
var _trained_count: int = 0

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


## Tell the panel which classes are already taken by imported trainees so it can
## enforce the max-3 / one-per-class Class Training cap (Planetfall p.27).
func set_existing_roster(roster: Array) -> void:
	_taken_classes.clear()
	_trained_count = 0
	for c in roster:
		if c is Dictionary and c.get("is_imported", false):
			var cls := str(c.get("class", ""))
			if cls in PLANETFALL_CLASSES:
				_taken_classes.append(cls)
				_trained_count += 1


## Load every standard + Bug Hunt save in user://saves/ as an import source.
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


## ── STEP 1: Explain + select source character ───────────────────────────

func _show_step_1() -> void:
	_clear_steps()

	var title := Label.new()
	title.text = "IMPORT VETERAN INTO COLONY"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	var explain := _create_glass_card(_step_container)
	_add_explanation(explain, "What happens when you import a veteran:",
		[
			"Their ability scores carry over (Planetfall p.26)",
			"Five Parsecs Luck becomes Kill Points — 1 KP per Luck point",
			"Bug Hunt Tech is converted to Savvy",
			"They begin the campaign Loyal",
			"Up to 3 imported veterans may receive Class Training (1 per class)",
			"You can muster them back out later — their original profile is preserved"
		])

	var header := Label.new()
	header.text = "SELECT VETERAN"
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	header.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_step_container.add_child(header)

	var any := false
	for char_data in _source_characters:
		if char_data is not Dictionary:
			continue
		if str(char_data.get("status", "active")).to_lower() in ["dead", "retired", "missing"]:
			continue
		var sm := str(char_data.get("_source_mode", "five_parsecs"))
		if sm not in ["five_parsecs", "bug_hunt"]:
			continue
		any = true
		_build_character_select_card(char_data)

	if not any:
		var empty := Label.new()
		empty.text = "No eligible 5PFH or Bug Hunt veterans found in your saves."
		empty.add_theme_color_override("font_color", COLOR_WARNING)
		_step_container.add_child(empty)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(200, 44)
	cancel_btn.pressed.connect(func() -> void:
		import_cancelled.emit()
		queue_free())
	_step_container.add_child(cancel_btn)


func _build_character_select_card(char_data: Dictionary) -> void:
	var char_name: String = char_data.get("name", char_data.get("character_name", "Unknown"))
	var sm := str(char_data.get("_source_mode", "five_parsecs"))
	var card := _create_glass_card(_step_container)

	var name_lbl := Label.new()
	name_lbl.text = "%s  [%s]" % [char_name, "Bug Hunt" if sm == "bug_hunt" else "5PFH"]
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(name_lbl)

	var stats := "R:%d  S:%d  CS:%d  T:%d  Sv:%d  Luck:%d" % [
		char_data.get("reactions", char_data.get("reaction", 0)),
		char_data.get("speed", 0),
		char_data.get("combat_skill", char_data.get("combat", 0)),
		char_data.get("toughness", 0),
		char_data.get("savvy", 0),
		char_data.get("luck", 0)]
	var detail_lbl := Label.new()
	detail_lbl.text = stats
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	detail_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	card.add_child(detail_lbl)

	var select_btn := Button.new()
	select_btn.text = "Select %s" % char_name
	select_btn.custom_minimum_size = Vector2(200, 44)
	var captured: Dictionary = char_data.duplicate(true)
	select_btn.pressed.connect(func() -> void: _show_step_2(captured))
	card.add_child(select_btn)


## ── STEP 2: Preview the conversion ──────────────────────────────────────

func _show_step_2(source_char: Dictionary) -> void:
	_clear_steps()
	var sm := str(source_char.get("_source_mode", "five_parsecs"))
	var source_label := "bug_hunt" if sm == "bug_hunt" else "5pfh"

	# Convert directly from the raw source character (book-correct per source),
	# and capture the canonical 5PFH-standard form as the lossless snapshot.
	var planetfall_char: Dictionary = _transfer_service.convert_to_planetfall(
		source_char, source_label)
	var canonical: Dictionary = _transfer_service.export_to_canonical(source_char, sm)

	var char_name: String = planetfall_char.get("name", "Unknown")
	var title := Label.new()
	title.text = "IMPORT PREVIEW: %s" % char_name
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	var card := _create_glass_card(_step_container)
	_add_preview_row(card, "Combat", "+%d" % planetfall_char.get("combat_skill", 0), COLOR_TEXT)
	_add_preview_row(card, "Reactions", str(planetfall_char.get("reactions", 0)), COLOR_TEXT)
	_add_preview_row(card, "Speed", str(planetfall_char.get("speed", 0)), COLOR_TEXT)
	_add_preview_row(card, "Toughness", str(planetfall_char.get("toughness", 0)), COLOR_TEXT)
	_add_preview_row(card, "Savvy", str(planetfall_char.get("savvy", 0)),
		COLOR_SUCCESS if source_label == "bug_hunt" else COLOR_TEXT)
	if source_label == "5pfh":
		_add_preview_row(card, "Kill Points",
			"%d (from %d Luck)" % [planetfall_char.get("kp", 0), source_char.get("luck", 0)],
			COLOR_SUCCESS)
	else:
		_add_preview_row(card, "Savvy ← Tech", "Bug Hunt Tech converted to Savvy", COLOR_SUCCESS)
	_add_preview_row(card, "Loyalty", "Begins Loyal", COLOR_SUCCESS)
	_add_preview_row(card, "Class", "Assigned next via Class Training", COLOR_CYAN)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_step_container.add_child(btn_row)

	var next_btn := Button.new()
	next_btn.text = "Proceed to Class Training"
	next_btn.custom_minimum_size = Vector2(240, 52)
	next_btn.pressed.connect(func() -> void:
		_show_step_3_training(planetfall_char, canonical))
	btn_row.add_child(next_btn)

	var back_btn := Button.new()
	back_btn.text = "Go Back"
	back_btn.custom_minimum_size = Vector2(140, 48)
	back_btn.pressed.connect(func() -> void: _show_step_1())
	btn_row.add_child(back_btn)


## ── STEP 3: Class Training aptitude test (Planetfall p.27) ───────────────

func _show_step_3_training(planetfall_char: Dictionary, canonical: Dictionary) -> void:
	_clear_steps()

	var title := Label.new()
	title.text = "CLASS TRAINING"
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	var available: Array = []
	for cls in PLANETFALL_CLASSES:
		if cls not in _taken_classes:
			available.append(cls)

	var card := _create_glass_card(_step_container)

	# Cap: up to 3 trained, one per class (Planetfall p.27).
	if _trained_count >= 3 or available.is_empty():
		var note := Label.new()
		note.text = "All Class Training slots are filled (max 3, one per class).\nThis veteran joins the colony without a class."
		note.add_theme_color_override("font_color", COLOR_WARNING)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(note)
		var import_btn := Button.new()
		import_btn.text = "Import as Unclassed"
		import_btn.custom_minimum_size = Vector2(220, 48)
		import_btn.pressed.connect(func() -> void:
			_finalize_import(planetfall_char, "", canonical))
		_step_container.add_child(import_btn)
		return

	var intro := Label.new()
	intro.text = "Roll 1D6: 1-2 fails, 3 grants a random class, 4-6 grants the class you choose. Auto-qualifies if their background fits."
	intro.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	intro.add_theme_font_size_override("font_size", _scaled_font(13))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(intro)

	var picker := OptionButton.new()
	for cls in available:
		picker.add_item(str(cls).capitalize())
	picker.custom_minimum_size = Vector2(200, 44)
	card.add_child(picker)

	var roll_btn := Button.new()
	roll_btn.text = "Attempt Class Training"
	roll_btn.custom_minimum_size = Vector2(240, 48)
	roll_btn.pressed.connect(func() -> void:
		var desired := str(available[picker.selected]) if picker.selected >= 0 else str(available[0])
		var res: Dictionary = _transfer_service.attempt_class_training(planetfall_char, desired)
		_show_training_result(res, planetfall_char, canonical, available))
	_step_container.add_child(roll_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip — Import Unclassed"
	skip_btn.custom_minimum_size = Vector2(240, 44)
	skip_btn.pressed.connect(func() -> void:
		_finalize_import(planetfall_char, "", canonical))
	_step_container.add_child(skip_btn)


func _show_training_result(
		res: Dictionary, planetfall_char: Dictionary,
		canonical: Dictionary, _available: Array) -> void:
	_clear_steps()
	var card := _create_glass_card(_step_container)
	var assigned := str(res.get("assigned_class", ""))
	# Guard the one-per-class cap against a random-class result colliding.
	if res.get("success", false) and assigned in _taken_classes:
		res["success"] = false

	var title := Label.new()
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if res.get("success", false):
		title.text = "TRAINING APPROVED"
		title.add_theme_color_override("font_color", COLOR_SUCCESS)
		var msg := Label.new()
		var method := str(res.get("method", ""))
		msg.text = "Assigned class: %s (%s)." % [assigned.capitalize(), method.replace("_", " ")]
		if res.has("roll"):
			msg.text += "  D6 roll: %d." % int(res.roll)
		msg.add_theme_color_override("font_color", COLOR_TEXT)
		card.add_child(msg)
		var import_btn := Button.new()
		import_btn.text = "Import as %s" % assigned.capitalize()
		import_btn.custom_minimum_size = Vector2(240, 48)
		import_btn.pressed.connect(func() -> void:
			_finalize_import(planetfall_char, assigned, canonical))
		_step_container.add_child(import_btn)
	else:
		title.text = "TRAINING NOT APPROVED"
		title.add_theme_color_override("font_color", COLOR_WARNING)
		var msg := Label.new()
		msg.text = "Failed the aptitude test (roll %d). They can still join the colony without a class." % int(res.get("roll", 0))
		msg.add_theme_color_override("font_color", COLOR_TEXT)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(msg)
		var retry_btn := Button.new()
		retry_btn.text = "Try Again"
		retry_btn.custom_minimum_size = Vector2(160, 44)
		retry_btn.pressed.connect(func() -> void:
			_show_step_3_training(planetfall_char, canonical))
		_step_container.add_child(retry_btn)
		var unclassed_btn := Button.new()
		unclassed_btn.text = "Import as Unclassed"
		unclassed_btn.custom_minimum_size = Vector2(220, 44)
		unclassed_btn.pressed.connect(func() -> void:
			_finalize_import(planetfall_char, "", canonical))
		_step_container.add_child(unclassed_btn)

	_step_container.add_child(title)
	_step_container.move_child(title, 0)


func _finalize_import(
		planetfall_char: Dictionary, assigned_class: String, canonical: Dictionary) -> void:
	planetfall_char["class"] = assigned_class
	planetfall_char["is_imported"] = true
	# Embed the lossless 5PFH-standard snapshot so a later muster-out restores the
	# original veteran verbatim (strip any nested snapshot to avoid recursion).
	var clean: Dictionary = canonical.duplicate(true)
	clean.erase("snapshot")
	planetfall_char["snapshot"] = clean
	character_imported.emit(planetfall_char)
	queue_free()


## ── HELPERS (mirrored from CharacterTransferPanel) ──────────────────────

func _clear_steps() -> void:
	if _step_container:
		for child in _step_container.get_children():
			child.queue_free()


func _add_explanation(parent: VBoxContainer, header_text: String, points: Array) -> void:
	var header := Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	header.add_theme_color_override("font_color", COLOR_CYAN)
	parent.add_child(header)
	for point in points:
		var lbl := Label.new()
		lbl.text = "  •  " + str(point)
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.add_theme_font_size_override("font_size", _scaled_font(14))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(lbl)


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
