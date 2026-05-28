extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/CharacterPhasePanel.gd")
const CharacterEvents = preload("res://src/data/character_events.gd")
const NARRATIVE_SCREEN_PATH := "res://src/ui/screens/narrative/NarrativeScreen.gd"

signal character_event_resolved(crew_member_name: String, event_type: String)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var events_list: VBoxContainer = $VBoxContainer/EventsList
@onready var continue_button: Button = $VBoxContainer/ContinueButton

var resolved_events: Array[Dictionary] = []

# NarrativeScreen serial-chain queue (one beat per crew event when the
# narrative toggle is on). Untyped so resolved_events.duplicate() assigns cleanly.
var _narrative_queue: Array = []

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
	# Narrative-mode branch (default ON via SettingsManager). Presents each
	# resolved crew event as a full-screen beat in series. The list UI built
	# in _generate_crew_events() is the fallback shown when the toggle is off
	# or the screen fails to load. Mirrors the StoryPhasePanel integration.
	if _narrative_enabled() and not resolved_events.is_empty():
		_present_character_events_via_narrative()

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


# ── NarrativeScreen integration (Phase 3 — Character events) ──────────
# Toggle: SettingsManager.are_narrative_events_enabled() (default ON).
# Each crew member's resolved event is shown as a full-screen NarrativeScreen
# beat in series; the last beat completing advances the phase. The list UI in
# _generate_crew_events() remains the fallback when the toggle is off or the
# screen fails to load. State (rolls, journal, character_event_resolved) is
# already applied in _generate_crew_events() — these methods are presentation
# only, so behavior is identical whether the toggle is on or off.

func _narrative_enabled() -> bool:
	var settings = get_node_or_null("/root/SettingsManager")
	return settings != null \
		and settings.has_method("are_narrative_events_enabled") \
		and settings.are_narrative_events_enabled()


func _present_character_events_via_narrative() -> void:
	_narrative_queue = resolved_events.duplicate()
	_present_next_character_event()


func _present_next_character_event() -> void:
	if _narrative_queue.is_empty():
		complete_phase()
		return
	var NarrativeScreenClass = load(NARRATIVE_SCREEN_PATH)
	if not NarrativeScreenClass:
		push_warning("CharacterPhasePanel: narrative screen load failed; " \
			+ "falling back to list UI")
		return  # list UI + continue button is the safety net
	var event_data: Dictionary = _narrative_queue.pop_front()
	var screen = NarrativeScreenClass.new()
	get_tree().root.add_child(screen)
	screen.narrative_completed.connect(_on_character_narrative_done)
	screen.skip_requested.connect(_on_character_narrative_skipped)
	screen.present(_character_event_to_narrative_dict(event_data),
		_build_narrative_context())


func _character_event_to_narrative_dict(event_data: Dictionary) -> Dictionary:
	var ev_type: String = str(event_data.get("event_type", ""))
	var member: String = str(event_data.get("crew_member", "Crew Member"))
	var desc: String = str(event_data.get("description", ""))
	return {
		"id": "character_event_" + ev_type.to_lower(),
		"title": "%s: %s" % [member, ev_type.capitalize()],
		"art_tag": "character_event",
		"core_text": desc,
		"advisor_role": "",  # the beat is about the crew member, no advisor row
		"choices": [{"id": 0, "label": "Continue", "hint": ""}],
	}


func _build_narrative_context() -> Dictionary:
	# World data lives on /root/PlanetDataManager (an inner PlanetData with
	# .name/.traits), NOT on the campaign Resource. Mirrors StoryPhasePanel.
	var planet_mgr = get_node_or_null("/root/PlanetDataManager")
	var planet = null
	if planet_mgr and planet_mgr.has_method("get_current_planet"):
		planet = planet_mgr.get_current_planet()
	var world_name: String = "Unknown"
	var world_traits: Array = []
	if planet:
		if "name" in planet:
			world_name = str(planet.get("name"))
		if "traits" in planet and planet.get("traits") is Array:
			world_traits = planet.get("traits")
	var turn_number: int = 0
	var campaign = game_state.campaign if game_state else null
	if campaign and "progress_data" in campaign:
		turn_number = int(campaign.progress_data.get("turns_played", 0))
	return {
		"world_name": world_name,
		"world_traits": world_traits,
		"crew": _get_crew_members(),
		"turn_number": turn_number,
	}


func _on_character_narrative_done(_result: Dictionary) -> void:
	# Chain to the next crew event; completes the phase when the queue empties.
	# Deferred so the just-completed screen's dismiss() (queue_free) settles
	# before the next overlay is added.
	call_deferred("_present_next_character_event")


func _on_character_narrative_skipped() -> void:
	# Skip advances past the current beat; the chain continues.
	call_deferred("_present_next_character_event")
