extends Control

## Character Transfer Panel — Guided flow for transferring characters between
## Five Parsecs from Home and Bug Hunt campaigns.
##
## Compendium p.212 (Enlisting): 2D6+CS >= 7+, keep stats, strip equipment
## Compendium p.213 (Mustering Out): Keep profile+XP, rewards based on missions

signal character_transferred(character_data: Dictionary, direction: String)
signal transfer_cancelled

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

var _transfer_service: TransferServiceClass
var _source_characters: Array = []
var _direction: String = "enlist"
var _selected_character: Dictionary = {}

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


func set_direction(dir: String) -> void:
	_direction = dir
	_selected_character = {}
	_show_step_1()


func load_characters_from_save(save_path: String) -> void:
	_source_characters.clear()
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
	if data.has("squad") and data.squad is Dictionary:
		_source_characters = data.squad.get("main_characters", [])
	elif data.has("crew") and data.crew is Dictionary:
		_source_characters = data.crew.get("members", [])
	elif data.has("crew_members"):
		_source_characters = data.crew_members
	_show_step_1()


func load_characters_from_array(characters: Array) -> void:
	_source_characters = characters
	_show_step_1()


func _build_ui() -> void:
	# Full-screen backdrop
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


## ── STEP 1: Explain the process + Select character ──────────────────────

func _show_step_1() -> void:
	_clear_steps()

	# Title
	var title := Label.new()
	if _direction == "enlist":
		title.text = "ENLIST INTO BUG HUNT"
	else:
		title.text = "MUSTER OUT TO FIVE PARSECS"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	# Explanation card — build trust with new users
	var explain_card := _create_glass_card(_step_container)

	if _direction == "enlist":
		_add_explanation(explain_card, "What happens when you enlist:",
			[
				"Your character applies to join a Bug Hunt military squad",
				"Roll 2D6 + Combat Skill — need 7 or higher to be accepted (Compendium p.212)",
				"If a Story Point is available, it can bypass a failed roll",
				"All equipment is stashed safely — you keep ONE Pistol",
				"Your stats (Combat, Reactions, Speed, Toughness, Savvy) carry over exactly",
				"Luck is NOT used in Bug Hunt — it will be restored when you return",
				"Your Completed Missions and Reputation start at 0 for the military",
				"You can return to Five Parsecs later via Mustering Out"
			])
	else:
		_add_explanation(explain_card, "What happens when you muster out:",
			[
				"Your character leaves military service and returns to civilian life",
				"All stats carry over — including any improvements earned in Bug Hunt",
				"You receive 1 Credit for every 2 Completed Missions (Compendium p.213)",
				"You gain +1 Story Point",
				"You gain a Sector Government Patron contact",
				"Stashed equipment from enlistment is returned",
				"If you served 10+ missions, you keep your Service Pistol",
				"Unused XP carries over (but advancement costs switch to 5PFH rules)"
			])

	# Character selection
	var select_header := Label.new()
	select_header.text = "SELECT CHARACTER"
	select_header.add_theme_font_size_override("font_size", _scaled_font(16))
	select_header.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_step_container.add_child(select_header)

	if _source_characters.is_empty():
		var empty := Label.new()
		empty.text = "No eligible characters found. Load a save file first."
		empty.add_theme_color_override("font_color", COLOR_WARNING)
		_step_container.add_child(empty)

		var load_btn := Button.new()
		load_btn.text = "Load Characters from Save File"
		load_btn.custom_minimum_size = Vector2(260, 48)
		load_btn.pressed.connect(_on_load_save)
		_step_container.add_child(load_btn)
	else:
		for char_data in _source_characters:
			if char_data is not Dictionary:
				continue
			var game_mode: String = char_data.get("game_mode", "standard")
			var eligible: bool = false
			if _direction == "enlist" and game_mode != "bug_hunt":
				eligible = true
			elif _direction == "muster_out" and game_mode == "bug_hunt":
				if not char_data.get("is_grunt", false):
					eligible = true
			if not eligible:
				continue

			_build_character_select_card(char_data)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel — Go Back"
	cancel_btn.custom_minimum_size = Vector2(200, 44)
	cancel_btn.pressed.connect(func():
		transfer_cancelled.emit()
		queue_free()
	)
	_step_container.add_child(cancel_btn)


func _build_character_select_card(char_data: Dictionary) -> void:
	var char_name: String = char_data.get("name", char_data.get("character_name", "Unknown"))
	var card := _create_glass_card(_step_container)

	var name_lbl := Label.new()
	name_lbl.text = char_name
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	card.add_child(name_lbl)

	# Stats row
	var stats := "R:%d  S:%d  CS:%d  T:%d  Sv:%d" % [
		char_data.get("reactions", char_data.get("reaction", 0)),
		char_data.get("speed", 0),
		char_data.get("combat_skill", char_data.get("combat", 0)),
		char_data.get("toughness", 0),
		char_data.get("savvy", 0)]
	var xp_val: int = char_data.get("xp", char_data.get("experience", 0))
	var missions_val: int = char_data.get("completed_missions_count",
		char_data.get("missions_completed", 0))
	var detail := "%s  |  XP: %d  |  Missions: %d" % [stats, xp_val, missions_val]
	var detail_lbl := Label.new()
	detail_lbl.text = detail
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	detail_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
	card.add_child(detail_lbl)

	var select_btn := Button.new()
	select_btn.text = "Select %s" % char_name
	select_btn.custom_minimum_size = Vector2(200, 44)
	var captured: Dictionary = char_data.duplicate(true)
	select_btn.pressed.connect(func(): _show_step_2(captured))
	card.add_child(select_btn)


## ── STEP 2: Preview changes + Confirm ───────────────────────────────────

func _show_step_2(char_data: Dictionary) -> void:
	_clear_steps()
	_selected_character = char_data

	var char_name: String = char_data.get("name", char_data.get("character_name", "Unknown"))

	var title := Label.new()
	title.text = "CONFIRM TRANSFER: %s" % char_name
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(title)

	# Preview card — show exactly what will change
	var preview_card := _create_glass_card(_step_container)
	var preview_title := Label.new()
	preview_title.text = "TRANSFER PREVIEW"
	preview_title.add_theme_font_size_override("font_size", _scaled_font(16))
	preview_title.add_theme_color_override("font_color", COLOR_CYAN)
	preview_card.add_child(preview_title)

	if _direction == "enlist":
		var combat: int = char_data.get("combat_skill", char_data.get("combat", 0))
		_add_preview_row(preview_card, "Enlistment Roll", "2D6 + %d (Combat Skill) — need 7+" % combat, COLOR_TEXT)
		_add_preview_row(preview_card, "Stats", "All carry over unchanged", COLOR_SUCCESS)
		_add_preview_row(preview_card, "Luck", "Set to 0 (not used in Bug Hunt)", COLOR_WARNING)
		_add_preview_row(preview_card, "Equipment", "Stashed safely — 1 Pistol retained", COLOR_WARNING)
		_add_preview_row(preview_card, "Missions/Rep", "Reset to 0 for military career", COLOR_WARNING)
		_add_preview_row(preview_card, "XP", "Reset to 0", COLOR_WARNING)
		_add_preview_row(preview_card, "Return Trip", "Muster out later to restore everything", COLOR_SUCCESS)

		# Odds display
		var odds_lbl := Label.new()
		var target := 7 - combat
		var success_chance := _calculate_2d6_odds(target)
		odds_lbl.text = "Success chance: ~%d%% (need %d+ on 2D6)" % [success_chance, maxi(target, 2)]
		odds_lbl.add_theme_color_override("font_color", COLOR_CYAN)
		odds_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
		preview_card.add_child(odds_lbl)
	else:
		var missions: int = char_data.get("completed_missions_count", 0)
		var credits: int = missions / 2
		_add_preview_row(preview_card, "Stats", "All carry over unchanged", COLOR_SUCCESS)
		_add_preview_row(preview_card, "Luck", "Restored to 1 (base)", COLOR_SUCCESS)
		_add_preview_row(preview_card, "XP", "%d unused XP carries over" % char_data.get("xp", 0), COLOR_SUCCESS)
		_add_preview_row(preview_card, "Credits Earned", "+%d (1 per 2 missions from %d served)" % [credits, missions], COLOR_SUCCESS)
		_add_preview_row(preview_card, "Story Points", "+1", COLOR_SUCCESS)
		_add_preview_row(preview_card, "Patron", "+1 Sector Government Patron", COLOR_SUCCESS)
		if missions >= 10:
			_add_preview_row(preview_card, "Service Pistol", "Retained (10+ missions)", COLOR_SUCCESS)
		else:
			_add_preview_row(preview_card, "Service Pistol", "Not retained (%d/10 missions)" % missions, COLOR_WARNING)
		_add_preview_row(preview_card, "Stashed Equipment", "Returned from enlistment", COLOR_SUCCESS)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_step_container.add_child(btn_row)

	var confirm_btn := Button.new()
	if _direction == "enlist":
		confirm_btn.text = "Roll for Enlistment"
	else:
		confirm_btn.text = "Confirm Muster Out"
	confirm_btn.custom_minimum_size = Vector2(220, 52)
	confirm_btn.pressed.connect(func(): _execute_transfer())
	btn_row.add_child(confirm_btn)

	var back_btn := Button.new()
	back_btn.text = "Go Back"
	back_btn.custom_minimum_size = Vector2(140, 48)
	back_btn.pressed.connect(func(): _show_step_1())
	btn_row.add_child(back_btn)


## ── STEP 3: Execute + Show result ───────────────────────────────────────

func _execute_transfer() -> void:
	_clear_steps()

	if _direction == "enlist":
		var result := _transfer_service.attempt_enlistment(_selected_character)
		_show_enlistment_result(result)
	else:
		var result := _transfer_service.muster_out(_selected_character)
		_show_muster_result(result)


func _show_enlistment_result(result: Dictionary) -> void:
	var title := Label.new()
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var result_card := _create_glass_card(_step_container)

	var dice: Array = result.get("dice", [0, 0])
	var die1: int = dice[0] if dice.size() > 0 else 0
	var die2: int = dice[1] if dice.size() > 1 else 0
	var combat_bonus: int = result.get("combat_bonus", 0)
	var total: int = result.get("roll", 0)

	# Dice roll display
	var roll_lbl := Label.new()
	roll_lbl.text = "Dice: [%d] + [%d] + Combat Skill %d = %d  (needed 7+)" % [die1, die2, combat_bonus, total]
	roll_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	roll_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if result.success:
		title.text = "ENLISTMENT ACCEPTED!"
		title.add_theme_color_override("font_color", COLOR_SUCCESS)
		roll_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)

		result_card.add_child(roll_lbl)

		var name_str: String = result.get("transferred_character", {}).get("name", "Unknown")
		var msg := Label.new()
		msg.text = "%s has been accepted into Bug Hunt service!\n\nEquipment has been stashed safely. Stats carry over. Report to the barracks, trooper." % name_str
		msg.add_theme_color_override("font_color", COLOR_TEXT)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_card.add_child(msg)

		var done_btn := Button.new()
		done_btn.text = "Welcome Aboard!"
		done_btn.custom_minimum_size = Vector2(200, 48)
		done_btn.pressed.connect(func():
			character_transferred.emit(result.transferred_character, "enlist")
		)
		_step_container.add_child(done_btn)
	else:
		title.text = "ENLISTMENT REJECTED"
		title.add_theme_color_override("font_color", COLOR_DANGER)
		roll_lbl.add_theme_color_override("font_color", COLOR_DANGER)

		result_card.add_child(roll_lbl)

		var msg := Label.new()
		msg.text = "Application denied. The military has standards, apparently.\n\nYou may try again after your next mission. (1 Story Point can also bypass the roll.)"
		msg.add_theme_color_override("font_color", COLOR_TEXT)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_card.add_child(msg)

		var back_btn := Button.new()
		back_btn.text = "Back to Selection"
		back_btn.custom_minimum_size = Vector2(200, 48)
		back_btn.pressed.connect(func(): _show_step_1())
		_step_container.add_child(back_btn)

	_step_container.add_child(title)
	_step_container.move_child(title, 0)


func _show_muster_result(result: Dictionary) -> void:
	var title := Label.new()
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var result_card := _create_glass_card(_step_container)

	if result.success:
		title.text = "MUSTERED OUT!"
		title.add_theme_color_override("font_color", COLOR_SUCCESS)

		var transferred: Dictionary = result.transferred_character
		var name_str: String = transferred.get("name", transferred.get("character_name", "Unknown"))
		var credits: int = transferred.get("mustering_credits", 0)

		var msg := Label.new()
		msg.text = "%s has completed their military service and returns to civilian life.\n" % name_str
		msg.text += "\nRewards earned:"
		msg.text += "\n  +%d Credits (mustering out pay)" % credits
		msg.text += "\n  +1 Story Point"
		msg.text += "\n  +1 Sector Government Patron added to contacts"
		if transferred.get("bug_hunt_missions_completed", 0) >= 10:
			msg.text += "\n  Service Pistol retained (veteran benefit)"
		msg.text += "\n\nThis character can now be added to any Five Parsecs crew."
		msg.add_theme_color_override("font_color", COLOR_TEXT)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_card.add_child(msg)

		var done_btn := Button.new()
		done_btn.text = "Dismiss — Good Luck Out There"
		done_btn.custom_minimum_size = Vector2(280, 48)
		done_btn.pressed.connect(func():
			character_transferred.emit(transferred, "muster_out")
		)
		_step_container.add_child(done_btn)
	else:
		title.text = "TRANSFER FAILED"
		title.add_theme_color_override("font_color", COLOR_DANGER)
		var msg := Label.new()
		msg.text = result.get("reason", "Unknown error occurred.")
		msg.add_theme_color_override("font_color", COLOR_WARNING)
		result_card.add_child(msg)

		var back_btn := Button.new()
		back_btn.text = "Go Back"
		back_btn.custom_minimum_size = Vector2(160, 48)
		back_btn.pressed.connect(func(): _show_step_1())
		_step_container.add_child(back_btn)

	_step_container.add_child(title)
	_step_container.move_child(title, 0)


## ── HELPERS ─────────────────────────────────────────────────────────────

func _clear_steps() -> void:
	if _step_container:
		for child in _step_container.get_children():
			child.queue_free()


func _on_load_save() -> void:
	var save_dir := "user://saves/"
	if not DirAccess.dir_exists_absolute(save_dir):
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

	_clear_steps()
	var header := Label.new()
	header.text = "SELECT SAVE FILE"
	header.add_theme_font_size_override("font_size", _scaled_font(20))
	header.add_theme_color_override("font_color", COLOR_TEXT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_container.add_child(header)

	if saves.is_empty():
		var empty := Label.new()
		empty.text = "No save files found in user://saves/"
		empty.add_theme_color_override("font_color", COLOR_WARNING)
		_step_container.add_child(empty)
	else:
		for save_name in saves:
			var btn := Button.new()
			btn.text = save_name
			btn.custom_minimum_size.y = 44
			var path: String = save_dir + save_name
			btn.pressed.connect(func(): load_characters_from_save(path))
			_step_container.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(160, 44)
	cancel.pressed.connect(func(): _show_step_1())
	_step_container.add_child(cancel)


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


func _calculate_2d6_odds(target_on_2d6: int) -> int:
	## Approximate percentage chance of rolling target+ on 2D6.
	## 36 total combinations on 2D6.
	var ways_to_succeed: int = 0
	for d1 in range(1, 7):
		for d2 in range(1, 7):
			if d1 + d2 >= target_on_2d6:
				ways_to_succeed += 1
	return int(round(float(ways_to_succeed) / 36.0 * 100.0))
