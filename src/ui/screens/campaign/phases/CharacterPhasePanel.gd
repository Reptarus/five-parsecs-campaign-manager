extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/CharacterPhasePanel.gd")
const CharacterEvents = preload("res://src/data/character_events.gd")

signal character_event_resolved(crew_member_name: String, event_type: String)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var events_list: VBoxContainer = $VBoxContainer/EventsList
@onready var continue_button: Button = $VBoxContainer/ContinueButton

var resolved_events: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_section_label(description_label)
	_style_phase_button(continue_button, true)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	_wrap_character_content_in_cards()

func _wrap_character_content_in_cards() -> void:
	var vbox = $VBoxContainer
	if not vbox:
		return
	for child in vbox.get_children():
		if child is HSeparator:
			child.queue_free()
	# Wrap events_list in a card
	if events_list and events_list.get_parent() == vbox:
		_wrap_in_phase_card(events_list, "Character Events")

func setup_phase() -> void:
	super.setup_phase()
	resolved_events.clear()
	_clear_events_display()
	_generate_crew_events()
	if continue_button:
		continue_button.disabled = false

func _clear_events_display() -> void:
	if not events_list:
		return
	for child in events_list.get_children():
		child.queue_free()

func _generate_crew_events() -> void:
	var crew_members := _get_crew_members()
	if crew_members.is_empty():
		if events_list:
			var no_crew_label = Label.new()
			no_crew_label.text = "No crew members available for character events."
			events_list.add_child(no_crew_label)
		return

	for member in crew_members:
		if member is Dictionary and member.get("is_dead", false):
			continue
		elif member is not Dictionary and "is_dead" in member and member.is_dead:
			continue

		var event = CharacterEvents.roll_event()
		var member_name: String = "Crew Member"
		if member is Dictionary:
			member_name = member.get("character_name", member.get("name", "Crew Member"))
		elif "character_name" in member:
			member_name = member.character_name

		var event_data = {
			"crew_member": member_name,
			"event_type": event.type,
			"description": event.description,
		}
		resolved_events.append(event_data)

		if events_list:
			# Create UI for this event
			var event_panel = PanelContainer.new()
			_style_sub_panel(event_panel)
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			event_panel.add_child(hbox)

			var name_label = Label.new()
			name_label.text = member_name
			name_label.custom_minimum_size = Vector2(150, 0)
			name_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
			name_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
			hbox.add_child(name_label)

			var event_label = Label.new()
			event_label.text = event.description
			event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hbox.add_child(event_label)

			events_list.add_child(event_panel)

		character_event_resolved.emit(member_name, event.type)

		# Log character event to CampaignJournal
		var journal = get_node_or_null("/root/CampaignJournal")
		if journal and journal.has_method("auto_create_character_event"):
			var member_id: String = ""
			if member is Dictionary:
				member_id = member.get("character_id", member.get("id", ""))
			elif "character_id" in member:
				member_id = member.character_id
			if not member_id.is_empty():
				var turn_num: int = 0
				var campaign = game_state.campaign if game_state else null
				if campaign and "progress_data" in campaign:
					turn_num = campaign.progress_data.get("turns_played", 0)
				journal.auto_create_character_event(member_id, event.type, {
					"turn": turn_num,
					"description": event.description,
				})

func _get_crew_members() -> Array:
	if not game_state:
		return []
	if game_state.has_method("get_crew_members"):
		return game_state.get_crew_members()
	var campaign = game_state.campaign if game_state else null
	if not campaign:
		return []
	if campaign.has_method("get_active_crew_members"):
		return campaign.get_active_crew_members()
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	if "crew_data" in campaign:
		return campaign.crew_data.get("members", [])
	return []

func _on_continue_pressed() -> void:
	complete_phase()

func validate_phase_requirements() -> bool:
	return true

func get_phase_data() -> Dictionary:
	return {
		"events": resolved_events,
		"event_count": resolved_events.size()
	}
