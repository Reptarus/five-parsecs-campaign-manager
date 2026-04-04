extends Control

# Character class_name is globally available — do NOT preload Base/Character.gd (shadows the canonical class)
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
signal crew_updated(crew: Array)

@onready var content = $Content
@onready var crew_size_option = $Content/CrewSize/OptionButton
@onready var crew_list = $Content/CrewList/ItemList
@onready var character_creator = $CharacterCreator

var crew_members: Array = [] # Untyped — avoids Character.gd type shadowing crash
var selected_size: int = 6  # Core Rules p.63 default crew size

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	_apply_base_background()
	_wrap_content_in_scroll()
	_add_guidance_label()
	_setup_crew_size_options()
	_connect_signals()
	_style_action_buttons()
	_update_crew_list()

func _wrap_content_in_scroll() -> void:
	## Wrap Content VBox in a ScrollContainer so crew cards
	## don't overflow the viewport
	var scroll := ScrollContainer.new()
	scroll.name = "__crew_scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Reparent Content into scroll
	var parent := content.get_parent()
	var idx := content.get_index()
	parent.add_child(scroll)
	parent.move_child(scroll, idx)
	content.reparent(scroll)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

func _add_guidance_label() -> void:
	## Add guidance text at top of content area
	var guidance := Label.new()
	guidance.text = (
		"Select your crew size and add members."
		+ " Each crew member is generated with random"
		+ " backgrounds, skills, and starting equipment."
	)
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance.add_theme_color_override(
		"font_color", Color("#808080"))
	guidance.add_theme_font_size_override("font_size", _scaled_font(14))
	content.add_child(guidance)
	content.move_child(guidance, 0)

func _setup_crew_size_options() -> void:
	crew_size_option.clear()
	
	crew_size_option.add_item("4 Total (Captain + 3 Crew)", 4)
	crew_size_option.add_item("5 Total (Captain + 4 Crew)", 5)
	crew_size_option.add_item("6 Total (Captain + 5 Crew)", 6)
	
	crew_size_option.select(2) # Default to 6 members (Core Rules p.63 default)

func _connect_signals() -> void:
	crew_size_option.item_selected.connect(_on_crew_size_selected)
	$Content/Controls/AddButton.pressed.connect(_on_add_member_pressed)
	$Content/Controls/EditButton.pressed.connect(_on_edit_member_pressed)
	$Content/Controls/RemoveButton.pressed.connect(_on_remove_member_pressed)
	$Content/Controls/RandomizeButton.pressed.connect(_on_randomize_pressed)
	
	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)
	character_creator.creation_cancelled.connect(func(): character_creator.hide(); content.show())

	crew_list.item_selected.connect(_on_crew_member_selected)

func _on_crew_size_selected(index: int) -> void:
	selected_size = crew_size_option.get_item_id(index)
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	if crew_members.size() >= selected_size - 1:
		return

	content.hide()
	character_creator.start_creation(CharacterCreator.CreatorMode.INITIAL_CREW)
	character_creator.show()

func _on_edit_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return

	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		content.hide()
		character_creator.edit_character(crew_members[index])
		character_creator.show()

func _on_remove_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		crew_members.remove_at(index)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_randomize_pressed() -> void:
	crew_members.clear()

	for i in range(selected_size - 1):
		character_creator.start_creation(CharacterCreator.CreatorMode.INITIAL_CREW)
		character_creator._on_randomize_pressed()
		if character_creator.current_character:
			crew_members.append(character_creator.current_character)
	character_creator.hide()

	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_character_created(character) -> void:
	character_creator.hide()
	content.show()
	if crew_members.size() < selected_size - 1:
		crew_members.append(character)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_character_edited(character) -> void:
	character_creator.hide()
	content.show()
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return

	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		crew_members[index] = character
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_crew_member_selected(index: int) -> void:
	$Content/Controls/EditButton.disabled = false
	$Content/Controls/RemoveButton.disabled = false

func _update_crew_list() -> void:
	crew_list.clear()
	# Also clear dynamic card container if it exists
	var card_container := crew_list.get_parent().get_node_or_null(
		"__crew_cards")
	if card_container:
		for child in card_container.get_children():
			child.queue_free()
	else:
		# Create card container as sibling of crew_list
		card_container = VBoxContainer.new()
		card_container.name = "__crew_cards"
		card_container.add_theme_constant_override(
			"separation", 8)
		crew_list.get_parent().add_child(card_container)
		crew_list.get_parent().move_child(
			card_container, crew_list.get_index() + 1)

	# Hide the plain ItemList, show cards instead
	crew_list.visible = false

	if crew_members.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override(
			"panel", _card_style())
		empty.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL)
		var lbl := Label.new()
		lbl.text = "No crew members yet.\n" \
			+ "Use 'Randomize All' or 'Add Member' below."
		lbl.add_theme_font_size_override("font_size", _scaled_font(14))
		lbl.add_theme_color_override(
			"font_color", Color("#6b7280"))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER)
		empty.add_child(lbl)
		card_container.add_child(empty)
	else:
		for i in range(crew_members.size()):
			var card := _build_crew_card(crew_members[i], i)
			card_container.add_child(card)

	# Keep ItemList in sync for selection logic
	for character in crew_members:
		var text = "%s - %s (%s)" % [
			character.character_name,
			_enum_value_name(
				GlobalEnums.CharacterClass,
				int(character.character_class)),
			_enum_value_name(
				GlobalEnums.Origin,
				int(character.origin))
		]
		crew_list.add_item(text)

	# Update controls state
	$Content/Controls/AddButton.disabled = (
		crew_members.size() >= selected_size - 1)
	$Content/Controls/EditButton.disabled = true
	$Content/Controls/RemoveButton.disabled = true

func _build_crew_card(
	character, index: int
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", _card_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Make card clickable for selection
	panel.gui_input.connect(
		_on_crew_card_input.bind(index))
	panel.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Left: Name + subtitle
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL)
	info_vbox.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	name_lbl.text = character.character_name
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	name_lbl.add_theme_color_override(
		"font_color", Color("#f3f4f6"))
	info_vbox.add_child(name_lbl)

	var cls := _enum_value_name(
		GlobalEnums.CharacterClass,
		int(character.character_class))
	var origin := _enum_value_name(
		GlobalEnums.Origin, int(character.origin))
	var sub_lbl := Label.new()
	sub_lbl.text = "%s  •  %s" % [cls, origin]
	sub_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	sub_lbl.add_theme_color_override(
		"font_color", Color("#9ca3af"))
	info_vbox.add_child(sub_lbl)

	hbox.add_child(info_vbox)

	# Wrap header + stats + bonuses in a VBox inside the panel
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	hbox.reparent(card_vbox)
	panel.add_child(card_vbox)

	# Stats grid — 3 columns x 2 rows (matches CaptainPanel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	var stats := {
		"Combat": character.combat,
		"Reactions": character.reaction,
		"Toughness": character.toughness,
		"Speed": character.speed,
		"Savvy": character.savvy,
		"Luck": character.luck,
	}
	for stat_name in stats:
		grid.add_child(
			_build_stat_badge(stat_name, stats[stat_name]))
	card_vbox.add_child(grid)

	# Starting bonus tags from background/motivation/class
	var bonuses := _get_starting_bonuses(character)
	if not bonuses.is_empty():
		var bonus_flow := HFlowContainer.new()
		bonus_flow.add_theme_constant_override(
			"h_separation", 6)
		bonus_flow.add_theme_constant_override(
			"v_separation", 2)
		for tag in bonuses:
			bonus_flow.add_child(
				_build_bonus_tag(
					tag.text, tag.color,
					tag.get("source", "")))
		card_vbox.add_child(bonus_flow)

	return panel

func _on_crew_card_input(
	event: InputEvent, index: int
) -> void:
	if event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		# Select in hidden ItemList for edit/remove
		if index < crew_list.item_count:
			crew_list.select(index)
			_on_crew_member_selected(index)
		# Highlight selected card
		var card_cont := crew_list.get_parent() \
			.get_node_or_null("__crew_cards")
		if card_cont:
			for i in range(card_cont.get_child_count()):
				var card = card_cont.get_child(i)
				if card is PanelContainer:
					var s := _card_style()
					if i == index:
						s.border_color = Color("#3b82f6")
						s.set_border_width_all(2)
					card.add_theme_stylebox_override(
						"panel", s)

func _build_stat_badge(
	stat_name: String, value: int
) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1f2937")
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", style)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var name_l := Label.new()
	name_l.text = stat_name
	name_l.add_theme_font_size_override(
		"font_size", _scaled_font(11))
	name_l.add_theme_color_override(
		"font_color", Color("#9ca3af"))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_l)
	var val_l := Label.new()
	val_l.text = str(value)
	val_l.add_theme_font_size_override(
		"font_size", _scaled_font(12))
	val_l.add_theme_color_override(
		"font_color", Color("#3b82f6"))
	hb.add_child(val_l)
	badge.add_child(hb)
	return badge

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111827")
	style.border_color = Color("#374151")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	return style

func _enum_value_name(enum_dict: Dictionary, value: int) -> String:
	for key in enum_dict:
		if enum_dict[key] == value:
			return key.capitalize()
	return "Unknown"

## Style action buttons with Deep Space accent theme
func _style_action_buttons() -> void:
	_apply_button_style(
		$Content/Controls/RandomizeButton, true)
	_apply_button_style(
		$Content/Controls/AddButton, false)
	_apply_button_style(
		$Content/Controls/EditButton, false)
	_apply_button_style(
		$Content/Controls/RemoveButton, false)

func _apply_button_style(
	button: Button, is_primary: bool
) -> void:
	if not button:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3b82f6") if is_primary \
		else Color("#1f2937")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", _scaled_font(16))
	button.add_theme_color_override(
		"font_color", Color("#f3f4f6"))
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
	var disabled := style.duplicate()
	disabled.bg_color = Color(
		style.bg_color.r, style.bg_color.g,
		style.bg_color.b, 0.2)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override(
		"font_disabled_color", Color("#4b5563"))

func get_crew_data() -> Array:
	return crew_members.duplicate()

func is_valid() -> bool:
	return crew_members.size() == selected_size - 1

func get_selected_total_size() -> int:
	## Returns total crew size including captain slot (4, 5, or 6)
	return selected_size

## Starting bonuses from gear_database.json tables
var _gear_db: Dictionary = {}

func _load_gear_db() -> void:
	if not _gear_db.is_empty():
		return
	var file := FileAccess.open(
		"res://data/gear_database.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_gear_db = json.data
	file.close()

func _get_starting_bonuses(character) -> Array:
	_load_gear_db()
	if _gear_db.is_empty() or not character:
		return []
	var tags: Array = []
	# Read rolled item names from creation_bonuses
	var cb: Dictionary = {}
	if "creation_bonuses" in character:
		cb = character.creation_bonuses
	elif character is Dictionary:
		cb = character.get("creation_bonuses", {})
	var rolled_items: Array = cb.get("rolled_items", [])
	for item in rolled_items:
		tags.append({
			"text": item.get("name", "Unknown"),
			"color": Color("#3b82f6"),
			"source": item.get("type", "").capitalize()})
	var tables := {
		"backgrounds": character.background,
		"motivations": character.motivation,
		"classes": character.character_class,
	}
	for table_key in tables:
		var enum_val = tables[table_key]
		var enum_name: String = ""
		match table_key:
			"backgrounds":
				enum_name = _enum_key_name(
					GlobalEnums.Background, enum_val)
			"motivations":
				enum_name = _enum_key_name(
					GlobalEnums.Motivation, enum_val)
			"classes":
				enum_name = _enum_key_name(
					GlobalEnums.CharacterClass, enum_val)
		if enum_name.is_empty() or enum_name == "NONE":
			continue
		var entry := _find_db_entry(
			table_key, enum_name.to_lower())
		if entry.is_empty():
			continue
		var source_name: String = entry.get(
			"name", enum_name.capitalize())
		# Fallback: show generic roll types if no rolled items
		if rolled_items.is_empty():
			var rolls: Array = entry.get(
				"starting_rolls", [])
			for roll_type in rolls:
				var label: String = roll_type.replace(
					"_", " ").capitalize() + " Roll"
				tags.append({
					"text": label,
					"color": Color("#3b82f6"),
					"source": source_name})
		var res: Dictionary = entry.get("resources", {})
		if res.get("patron", 0) > 0:
			tags.append({
				"text": "Patron ×%d" % res["patron"],
				"color": Color("#10B981"),
				"source": source_name})
		if res.get("rival", 0) > 0:
			tags.append({
				"text": "Rival ×%d" % res["rival"],
				"color": Color("#DC2626"),
				"source": source_name})
		if res.get("quest_rumors", 0) > 0:
			tags.append({
				"text": "Rumors ×%d" % res["quest_rumors"],
				"color": Color("#D97706"),
				"source": source_name})
		if res.has("credits_dice"):
			tags.append({
				"text": "+%s cr" % res["credits_dice"],
				"color": Color("#D97706"),
				"source": source_name})
		if res.get("story_points", 0) > 0:
			tags.append({
				"text": "SP ×%d" % res["story_points"],
				"color": Color("#8B5CF6"),
				"source": source_name})
	return tags

func _find_db_entry(
	table_key: String, enum_id: String
) -> Dictionary:
	var table: Array = _gear_db.get(table_key, [])
	for entry in table:
		if entry.get("id", "") == enum_id:
			return entry
	return {}

func _enum_key_name(
	enum_dict: Dictionary, value: Variant
) -> String:
	if value is String:
		return value
	for key in enum_dict:
		if enum_dict[key] == value:
			return key
	return ""

func _build_bonus_tag(
	text: String, color: Color, source: String = ""
) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.15)
	style.border_color = Color(
		color.r, color.g, color.b, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", style)
	if source.is_empty():
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override(
			"font_size", _scaled_font(10))
		lbl.add_theme_color_override("font_color", color)
		pill.add_child(lbl)
	else:
		var tag_vbox := VBoxContainer.new()
		tag_vbox.add_theme_constant_override("separation", 0)
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override(
			"font_size", _scaled_font(10))
		lbl.add_theme_color_override("font_color", color)
		tag_vbox.add_child(lbl)
		var src_lbl := Label.new()
		src_lbl.text = source
		src_lbl.add_theme_font_size_override(
			"font_size", _scaled_font(8))
		src_lbl.add_theme_color_override(
			"font_color", Color("#6b7280"))
		tag_vbox.add_child(src_lbl)
		pill.add_child(tag_vbox)
	return pill
