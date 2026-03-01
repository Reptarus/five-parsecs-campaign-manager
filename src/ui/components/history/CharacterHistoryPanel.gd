extends PanelContainer

## CharacterHistoryPanel - Displays a character's lifetime stats, advancement history, and journal entries

signal back_pressed()

## Deep Space theme colors
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

var _character = null  # Character resource
var _character_id: String = ""

func setup(character, character_id: String = "") -> void:
	_character = character
	_character_id = character_id
	_build_ui()

func _build_ui() -> void:
	if not _character:
		return

	# Clear existing children
	for child in get_children():
		child.queue_free()

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Header with back button
	_add_header(vbox)

	# Character name and status
	_add_character_header(vbox)

	# Lifetime stats grid
	_add_stats_grid(vbox)

	# Advancement history
	_add_advancement_history(vbox)

	# Journal entries for this character
	_add_journal_entries(vbox)

func _add_header(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var back_btn = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.pressed.connect(func(): back_pressed.emit())
	hbox.add_child(back_btn)

	var title = Label.new()
	title.text = "Character History"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

func _add_character_header(parent: VBoxContainer) -> void:
	var card = _create_card()
	parent.add_child(card)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	# Character name
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_vbox)

	var char_name = _character.character_name if "character_name" in _character else str(_character)
	var name_label = Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_vbox.add_child(name_label)

	# Status
	var status_text = _character.status if "status" in _character else "ACTIVE"
	var status_label = Label.new()
	status_label.text = "Status: %s" % status_text
	var status_color = COLOR_SUCCESS if status_text == "ACTIVE" else (COLOR_DANGER if status_text == "DEAD" else COLOR_WARNING)
	status_label.add_theme_color_override("font_color", status_color)
	status_label.add_theme_font_size_override("font_size", 14)
	name_vbox.add_child(status_label)

	# Class/Origin if available
	if "character_class" in _character:
		var class_label = Label.new()
		class_label.text = "Class: %s" % str(_character.character_class)
		class_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		class_label.add_theme_font_size_override("font_size", 14)
		name_vbox.add_child(class_label)

func _add_stats_grid(parent: VBoxContainer) -> void:
	var section_label = Label.new()
	section_label.text = "Lifetime Statistics"
	section_label.add_theme_font_size_override("font_size", 18)
	section_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	parent.add_child(section_label)

	var card = _create_card()
	parent.add_child(card)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)

	var stats = [
		["Kills", _character.lifetime_kills if "lifetime_kills" in _character else 0],
		["Battles", _character.battles_participated if "battles_participated" in _character else 0],
		["Survived", _character.battles_survived if "battles_survived" in _character else 0],
		["Criticals", _character.critical_hits_landed if "critical_hits_landed" in _character else 0],
		["Missions", _character.missions_completed if "missions_completed" in _character else 0],
		["Credits", _character.credits_earned if "credits_earned" in _character else 0],
	]

	for stat in stats:
		var stat_box = VBoxContainer.new()
		stat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(stat_box)

		var value_label = Label.new()
		value_label.text = str(stat[1])
		value_label.add_theme_font_size_override("font_size", 24)
		value_label.add_theme_color_override("font_color", COLOR_ACCENT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_box.add_child(value_label)

		var label = Label.new()
		label.text = stat[0]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_box.add_child(label)

func _add_advancement_history(parent: VBoxContainer) -> void:
	var adv_history: Array = _character.advancement_history if "advancement_history" in _character else []
	if adv_history.is_empty():
		return

	var section_label = Label.new()
	section_label.text = "Advancement History"
	section_label.add_theme_font_size_override("font_size", 18)
	section_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	parent.add_child(section_label)

	var card = _create_card()
	parent.add_child(card)

	var timeline_vbox = VBoxContainer.new()
	timeline_vbox.add_theme_constant_override("separation", 4)
	card.add_child(timeline_vbox)

	# Show most recent first, limit to last 20
	var display_history = adv_history.duplicate()
	display_history.reverse()
	if display_history.size() > 20:
		display_history.resize(20)

	for entry in display_history:
		var entry_label = Label.new()
		var turn = entry.get("turn", "?")
		var stat_name = entry.get("stat", "unknown")
		var old_val = entry.get("old_value", "?")
		var new_val = entry.get("new_value", "?")
		entry_label.text = "Turn %s: %s %s -> %s" % [str(turn), stat_name, str(old_val), str(new_val)]
		entry_label.add_theme_font_size_override("font_size", 13)
		entry_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		timeline_vbox.add_child(entry_label)

func _add_journal_entries(parent: VBoxContainer) -> void:
	if _character_id.is_empty():
		return

	var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
	if not journal:
		return

	var entries = journal.get_character_entries(_character_id)
	if entries.is_empty():
		return

	var section_label = Label.new()
	section_label.text = "Journal Entries"
	section_label.add_theme_font_size_override("font_size", 18)
	section_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	parent.add_child(section_label)

	for entry in entries:
		var card = _create_card()
		parent.add_child(card)

		var entry_vbox = VBoxContainer.new()
		entry_vbox.add_theme_constant_override("separation", 4)
		card.add_child(entry_vbox)

		var title_label = Label.new()
		title_label.text = "Turn %d - %s" % [entry.get("turn_number", 0), entry.get("title", "Untitled")]
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		entry_vbox.add_child(title_label)

		var desc_label = Label.new()
		desc_label.text = entry.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry_vbox.add_child(desc_label)

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
