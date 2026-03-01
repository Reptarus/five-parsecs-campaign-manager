extends PanelContainer
## No-Minis Combat Panel - Abstract battle UI without miniatures
##
## Code-only UI component that provides zone-based abstract combat.
## Replaces standard battle display when NO_MINIS_COMBAT is enabled.
##
## Shows: Location zones, crew/enemy counts per zone, action buttons,
## round counter, and instruction text output.

const CompendiumNoMinisRef = preload("res://src/data/compendium_no_minis.gd")

signal round_advanced(round_num: int)
signal battle_completed(result: Dictionary)
signal action_resolved(action_text: String)

var _battle_data: Dictionary = {}
var _current_round: int = 0
var _max_rounds: int = 6
var _is_active: bool = false

# UI references
var _title_label: Label
var _round_label: Label
var _instructions_text: RichTextLabel
var _locations_container: VBoxContainer
var _action_buttons_container: HBoxContainer
var _advance_button: Button
var _end_button: Button
var _flow_event_button: Button
var _variant_container: HBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(400, 500)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "NO-MINIS COMBAT"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	# Round counter
	_round_label = Label.new()
	_round_label.text = "Round: 0 / 6"
	_round_label.add_theme_font_size_override("font_size", 16)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_round_label)

	# Separator
	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	# Locations display
	var loc_header := Label.new()
	loc_header.text = "Locations"
	loc_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(loc_header)

	_locations_container = VBoxContainer.new()
	_locations_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_locations_container)

	# Separator
	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# Action buttons
	var action_header := Label.new()
	action_header.text = "Actions"
	action_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(action_header)

	_action_buttons_container = HBoxContainer.new()
	_action_buttons_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_action_buttons_container)

	# Create action buttons
	var actions := ["Fire", "Engage", "Cover", "Sprint", "Search", "Aid"]
	for action_name in actions:
		var btn := Button.new()
		btn.text = action_name
		btn.custom_minimum_size = Vector2(60, 40)
		btn.pressed.connect(_on_action_pressed.bind(action_name.to_lower()))
		_action_buttons_container.add_child(btn)

	# Separator
	var sep3 := HSeparator.new()
	main_vbox.add_child(sep3)

	# Control buttons
	var control_hbox := HBoxContainer.new()
	control_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(control_hbox)

	_advance_button = Button.new()
	_advance_button.text = "Next Round"
	_advance_button.custom_minimum_size = Vector2(100, 44)
	_advance_button.pressed.connect(_on_advance_round)
	control_hbox.add_child(_advance_button)

	_flow_event_button = Button.new()
	_flow_event_button.text = "Flow Event"
	_flow_event_button.custom_minimum_size = Vector2(100, 44)
	_flow_event_button.pressed.connect(_on_flow_event)
	control_hbox.add_child(_flow_event_button)

	_end_button = Button.new()
	_end_button.text = "End Battle"
	_end_button.custom_minimum_size = Vector2(100, 44)
	_end_button.pressed.connect(_on_end_battle)
	control_hbox.add_child(_end_button)

	# Variant buttons
	_variant_container = HBoxContainer.new()
	_variant_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_variant_container)

	var hectic_btn := Button.new()
	hectic_btn.text = "Hectic Rules"
	hectic_btn.custom_minimum_size = Vector2(100, 36)
	hectic_btn.pressed.connect(_on_show_hectic)
	_variant_container.add_child(hectic_btn)

	var faster_btn := Button.new()
	faster_btn.text = "Faster Rules"
	faster_btn.custom_minimum_size = Vector2(100, 36)
	faster_btn.pressed.connect(_on_show_faster)
	_variant_container.add_child(faster_btn)

	# Instructions output
	var sep4 := HSeparator.new()
	main_vbox.add_child(sep4)

	_instructions_text = RichTextLabel.new()
	_instructions_text.bbcode_enabled = true
	_instructions_text.custom_minimum_size = Vector2(380, 200)
	_instructions_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_instructions_text.scroll_active = true
	main_vbox.add_child(_instructions_text)

	_set_controls_enabled(false)


## ============================================================================
## PUBLIC API
## ============================================================================

func setup_battle(crew_size: int, enemy_count: int) -> void:
	_battle_data = CompendiumNoMinisRef.generate_battle_setup(crew_size, enemy_count)
	if _battle_data.is_empty():
		_instructions_text.text = "[color=#DC2626]No-Minis Combat not enabled. Enable in DLC settings.[/color]"
		return

	_current_round = 0
	_max_rounds = _battle_data.get("max_rounds", 6)
	_is_active = true

	_update_round_display()
	_update_locations_display()
	_set_controls_enabled(true)

	var setup_text := CompendiumNoMinisRef.generate_setup_text(_battle_data)
	_instructions_text.text = setup_text


func is_battle_active() -> bool:
	return _is_active


## ============================================================================
## UI UPDATE METHODS
## ============================================================================

func _update_round_display() -> void:
	_round_label.text = "Round: %d / %d" % [_current_round, _max_rounds]


func _update_locations_display() -> void:
	# Clear existing
	for child in _locations_container.get_children():
		child.queue_free()

	var locs: Array = _battle_data.get("locations", [])
	for i in locs.size():
		var loc: Dictionary = locs[i]
		var loc_panel := PanelContainer.new()
		var loc_label := Label.new()
		var cover_text := " [Cover]" if loc.get("cover", false) else ""
		var elevated_text := " [Elevated]" if loc.get("elevated", false) else ""
		loc_label.text = "  %d. %s%s%s" % [i + 1, loc.get("name", "Unknown"), cover_text, elevated_text]
		loc_label.add_theme_font_size_override("font_size", 14)
		loc_panel.add_child(loc_label)
		_locations_container.add_child(loc_panel)


func _set_controls_enabled(enabled: bool) -> void:
	_advance_button.disabled = not enabled
	_flow_event_button.disabled = not enabled
	_end_button.disabled = not enabled
	for btn in _action_buttons_container.get_children():
		if btn is Button:
			btn.disabled = not enabled


func _append_instruction(text: String) -> void:
	_instructions_text.text += "\n\n" + text


## ============================================================================
## SIGNAL HANDLERS
## ============================================================================

func _on_advance_round() -> void:
	if not _is_active:
		return

	_current_round += 1
	_update_round_display()

	if _current_round > _max_rounds:
		_on_end_battle()
		return

	var round_text := CompendiumNoMinisRef.generate_round_text(_current_round, _battle_data)
	_instructions_text.text = round_text
	round_advanced.emit(_current_round)


func _on_action_pressed(action_id: String) -> void:
	if not _is_active:
		return

	# Find matching action
	for action in CompendiumNoMinisRef.INITIATIVE_ACTIONS:
		if action.id == action_id or action.id.begins_with(action_id):
			_append_instruction(action.instruction)
			action_resolved.emit(action.instruction)
			return

	# Fallback mapping
	var action_map := {
		"fire": "fire",
		"engage": "engage",
		"cover": "take_cover",
		"sprint": "sprint",
		"search": "search",
		"aid": "first_aid",
	}
	var mapped_id: String = action_map.get(action_id, action_id)
	for action in CompendiumNoMinisRef.INITIATIVE_ACTIONS:
		if action.id == mapped_id:
			_append_instruction(action.instruction)
			action_resolved.emit(action.instruction)
			return


func _on_flow_event() -> void:
	if not _is_active:
		return
	var event := CompendiumNoMinisRef.roll_battle_flow_event()
	if not event.is_empty():
		_append_instruction(event.instruction)


func _on_show_hectic() -> void:
	var text := CompendiumNoMinisRef.get_hectic_combat_text()
	if not text.is_empty():
		_append_instruction(text)


func _on_show_faster() -> void:
	var text := CompendiumNoMinisRef.get_faster_combat_text()
	if not text.is_empty():
		_append_instruction(text)


func _on_end_battle() -> void:
	_is_active = false
	_set_controls_enabled(false)

	var result := {
		"type": "no_minis",
		"rounds_played": _current_round,
		"completed": true,
	}

	_append_instruction("[b]BATTLE ENDED[/b]\nRounds played: %d\nResolve post-battle sequence normally." % _current_round)
	battle_completed.emit(result)
