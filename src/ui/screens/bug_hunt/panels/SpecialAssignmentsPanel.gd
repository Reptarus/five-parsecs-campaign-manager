extends Control

## Special Assignments Panel — Bug Hunt Turn Stage 1 of 3
## Characters can attempt training, request support, or skip.
## Each assignment requires a 2D6 roll against a target number.

signal phase_completed(result_data: Dictionary)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_ACCENT := Color("#2D5A7B")

const ASSIGNMENTS_PATH := "res://data/bug_hunt/bug_hunt_special_assignments.json"

var _campaign: Resource
var _phase_manager = null
var _assignments_data: Array = []
var _assignment_slots: Array[Dictionary] = []  # {character_id, character_name, assignment_id}
var _results_container: VBoxContainer
var _characters_container: VBoxContainer
var _completed: bool = false


func _ready() -> void:
	_load_assignments_data()
	_build_ui()


func set_campaign(c: Resource) -> void:
	_campaign = c


func set_phase_manager(pm) -> void:
	_phase_manager = pm


func refresh() -> void:
	_completed = false
	_assignment_slots.clear()
	_populate_characters()


func complete() -> void:
	if _completed:
		return
	_completed = true
	# Gather results and emit
	var results := {"completed_assignments": _assignment_slots.duplicate(true)}
	phase_completed.emit(results)


func _load_assignments_data() -> void:
	var file := FileAccess.open(ASSIGNMENTS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_assignments_data = json.data.get("assignments", [])
	file.close()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Info card
	var info_card := _create_card("Special Assignments", vbox)
	var info_lbl := Label.new()
	info_lbl.text = "Each Main Character not in Sick Bay may attempt one Special Assignment.\nRoll 2D6 — meet or beat the target number to succeed.\nA character can only complete each assignment once in their career."
	info_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_card.add_child(info_lbl)

	# Characters + assignment selection
	_characters_container = VBoxContainer.new()
	_characters_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_characters_container)

	# Results area
	_results_container = VBoxContainer.new()
	_results_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_results_container)

	# Roll All button
	var roll_btn := Button.new()
	roll_btn.text = "Roll All Assignments"
	roll_btn.custom_minimum_size = Vector2(200, 44)
	roll_btn.pressed.connect(_on_roll_all)
	vbox.add_child(roll_btn)

	# Skip button
	var skip_btn := Button.new()
	skip_btn.text = "Skip Assignments"
	skip_btn.custom_minimum_size = Vector2(200, 44)
	skip_btn.pressed.connect(func(): complete())
	vbox.add_child(skip_btn)


func _populate_characters() -> void:
	for child in _characters_container.get_children():
		child.queue_free()
	for child in _results_container.get_children():
		child.queue_free()

	if not _campaign or not "main_characters" in _campaign:
		return

	var characters: Array = _campaign.main_characters
	var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}

	for mc in characters:
		if mc is not Dictionary:
			continue
		var char_id: String = mc.get("id", mc.get("character_id", ""))
		var char_name: String = mc.get("name", mc.get("character_name", "Unknown"))

		# Skip sick bay characters
		if sick_bay.has(char_id):
			var sick_card := _create_card(char_name + " (Sick Bay)", _characters_container)
			var sick_lbl := Label.new()
			sick_lbl.text = "Recovering — %d turn(s) remaining" % sick_bay.get(char_id, 1)
			sick_lbl.add_theme_color_override("font_color", COLOR_WARNING)
			sick_card.add_child(sick_lbl)
			continue

		var card := _create_card(char_name, _characters_container)

		# Assignment dropdown
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var assign_lbl := Label.new()
		assign_lbl.text = "Assignment:"
		assign_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		hbox.add_child(assign_lbl)

		var option := OptionButton.new()
		option.add_item("None (Skip)", 0)
		for i in range(_assignments_data.size()):
			var assignment: Dictionary = _assignments_data[i]
			var target: int = assignment.get("target_2d6", 99)
			option.add_item("%s (2D6 >= %d)" % [assignment.get("name", "?"), target], i + 1)
		option.custom_minimum_size.x = 300
		hbox.add_child(option)

		# Store reference for later
		_assignment_slots.append({
			"character_id": char_id,
			"character_name": char_name,
			"option_button": option,
			"assignment_id": "",
			"result": ""
		})


func _on_roll_all() -> void:
	for child in _results_container.get_children():
		child.queue_free()

	for slot in _assignment_slots:
		var option: OptionButton = slot.get("option_button")
		if not is_instance_valid(option):
			continue

		var selected_idx: int = option.selected
		if selected_idx <= 0:
			slot.assignment_id = ""
			slot.result = "skipped"
			continue

		var assignment_idx: int = selected_idx - 1
		if assignment_idx >= _assignments_data.size():
			continue

		var assignment: Dictionary = _assignments_data[assignment_idx]
		var target: int = assignment.get("target_2d6", 99)

		# Roll 2D6
		var die1: int = (randi() % 6) + 1
		var die2: int = (randi() % 6) + 1
		var total: int = die1 + die2
		var success: bool = total >= target

		slot.assignment_id = assignment.get("id", "")
		slot.result = "success" if success else "failure"

		# Display result
		var result_lbl := Label.new()
		if success:
			result_lbl.text = "%s: %s — Rolled %d+%d=%d vs %d — SUCCESS! %s" % [
				slot.character_name, assignment.get("name", "?"),
				die1, die2, total, target,
				assignment.get("training_award", "")]
			result_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			result_lbl.text = "%s: %s — Rolled %d+%d=%d vs %d — FAILED" % [
				slot.character_name, assignment.get("name", "?"),
				die1, die2, total, target]
			result_lbl.add_theme_color_override("font_color", COLOR_WARNING)
		result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_results_container.add_child(result_lbl)

	# Auto-complete after rolling
	complete()


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
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox
