extends Control

# Character class_name is globally available — do NOT preload Base/Character.gd (shadows the canonical class)
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
signal captain_updated(captain)

@onready var content = $Content
@onready var character_creator = $CharacterCreator
@onready var captain_info = $Content/CaptainInfo/Label
@onready var create_button = $Content/Controls/CreateButton
@onready var edit_button = $Content/Controls/EditButton
@onready var randomize_button = $Content/Controls/RandomizeButton

var current_captain # Untyped — CharacterCreator may return canonical Character or BaseCharacterResource

func _ready() -> void:
	_apply_base_background()
	_connect_signals()
	_style_action_buttons()
	_update_ui()

## Apply Deep Space COLOR_BASE background
func _apply_base_background() -> void:
	var bg := ColorRect.new()
	bg.name = "__panel_bg"
	bg.color = Color("#1A1A2E")  # COLOR_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)

func _connect_signals() -> void:
	create_button.pressed.connect(_on_create_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)

	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)
	character_creator.creation_cancelled.connect(_on_creation_cancelled)

func _on_create_pressed() -> void:
	content.hide()
	character_creator.start_creation(CharacterCreator.CreatorMode.CAPTAIN)
	character_creator.show()

func _on_edit_pressed() -> void:
	if current_captain:
		content.hide()
		character_creator.edit_character(current_captain)
		character_creator.show()

func _on_randomize_pressed() -> void:
	character_creator.creator_mode = CharacterCreator.CreatorMode.CAPTAIN
	character_creator.clear()
	character_creator._on_randomize_pressed()
	if character_creator._validate_character():
		_on_character_created(character_creator.current_character)

func _on_character_created(character) -> void:
	current_captain = character
	if character and "is_captain" in character:
		character.is_captain = true
	character_creator.hide()
	content.show()
	_update_ui()
	captain_updated.emit(current_captain)

func _on_character_edited(character) -> void:
	current_captain = character
	if character and "is_captain" in character:
		character.is_captain = true
	character_creator.hide()
	content.show()
	_update_ui()
	captain_updated.emit(current_captain)

func _on_creation_cancelled() -> void:
	character_creator.hide()
	content.show()

func _update_ui() -> void:
	# Clear existing dynamic content from CaptainInfo parent
	var info_parent: VBoxContainer = captain_info.get_parent()
	for child in info_parent.get_children():
		if child != captain_info and child.name.begins_with("__cap"):
			child.queue_free()

	if current_captain:
		captain_info.text = ""  # Hide plain label
		# Build styled character card
		var card := _build_captain_card()
		card.name = "__cap_card"
		info_parent.add_child(card)
		info_parent.move_child(card, captain_info.get_index() + 1)
		create_button.hide()
		edit_button.show()
		randomize_button.hide()
	else:
		captain_info.text = ""
		var empty_card := _build_empty_state_card()
		empty_card.name = "__cap_empty"
		info_parent.add_child(empty_card)
		info_parent.move_child(
			empty_card, captain_info.get_index() + 1)
		create_button.show()
		edit_button.hide()
		randomize_button.show()

func _build_captain_card() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _card_style()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Name header
	var name_lbl := Label.new()
	name_lbl.text = current_captain.character_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override(
		"font_color", Color("#f3f4f6"))
	vbox.add_child(name_lbl)

	# Subtitle: Class / Origin / Background / Motivation
	var cls := _enum_value_name(
		GlobalEnums.CharacterClass,
		current_captain.character_class)
	var origin := _enum_value_name(
		GlobalEnums.Origin, current_captain.origin)
	var bg := _enum_value_name(
		GlobalEnums.Background, current_captain.background)
	var motiv := _enum_value_name(
		GlobalEnums.Motivation, current_captain.motivation)
	var sub_lbl := Label.new()
	sub_lbl.text = "%s  •  %s  •  %s  •  %s" % [
		cls, origin, bg, motiv]
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override(
		"font_color", Color("#9ca3af"))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub_lbl)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = Color("#374151")
	vbox.add_child(sep)

	# Stats grid — 3 columns x 2 rows
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	var stats := {
		"Combat": current_captain.combat,
		"Reactions": current_captain.reaction,
		"Toughness": current_captain.toughness,
		"Speed": current_captain.speed,
		"Savvy": current_captain.savvy,
		"Luck": current_captain.luck,
	}
	for stat_name in stats:
		grid.add_child(
			_build_stat_badge(stat_name, stats[stat_name]))
	vbox.add_child(grid)
	return panel

func _build_stat_badge(
	stat_name: String, value: int
) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1f2937")
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	badge.add_theme_stylebox_override("panel", style)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var name_l := Label.new()
	name_l.text = stat_name
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override(
		"font_color", Color("#9ca3af"))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_l)

	var val_l := Label.new()
	val_l.text = str(value)
	val_l.add_theme_font_size_override("font_size", 14)
	val_l.add_theme_color_override(
		"font_color", Color("#3b82f6"))
	hbox.add_child(val_l)

	badge.add_child(hbox)
	return badge

func _build_empty_state_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", _card_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = "No captain created yet.\n" \
		+ "Click 'Create Captain' or 'Randomize' to begin."
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override(
		"font_color", Color("#6b7280"))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111827")
	style.border_color = Color("#374151")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	return style

func _enum_value_name(enum_dict: Dictionary, value: Variant) -> String:
	if value is String:
		if value.is_empty():
			return "None"
		return value.capitalize()
	for key in enum_dict:
		if enum_dict[key] == value:
			return key.capitalize()
	return "Unknown"

func get_captain_data():
	return current_captain

func is_valid() -> bool:
	return current_captain != null

## Style action buttons with Deep Space accent theme
func _style_action_buttons() -> void:
	_apply_button_style(create_button, true)
	_apply_button_style(edit_button, true)
	_apply_button_style(randomize_button, false)

func _apply_button_style(button: Button, is_primary: bool) -> void:
	if not button:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3b82f6") if is_primary \
		else Color("#1f2937")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#f3f4f6"))
	button.custom_minimum_size.y = 48
	var hover := style.duplicate()
	hover.bg_color = Color("#60a5fa") if is_primary \
		else Color("#2d3748")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(
		style.bg_color.r - 0.1,
		style.bg_color.g - 0.1,
		style.bg_color.b - 0.1)
	button.add_theme_stylebox_override("pressed", pressed)
	# Disabled state
	var disabled := style.duplicate()
	disabled.bg_color = Color(
		style.bg_color.r, style.bg_color.g,
		style.bg_color.b, 0.2)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override(
		"font_disabled_color", Color("#4b5563"))