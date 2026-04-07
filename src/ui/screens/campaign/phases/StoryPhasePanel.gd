extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"

## Story Phase Panel — Core Rules Appendix V (pp.153-160)
##
## Three display modes:
## 1. Clock Status: Normal turn, show clock ticks + next event preview
## 2. Story Event: Story Event turn, show briefing + turn mods + battle info
## 3. Evidence Search: Post-Event 5, show evidence roll results

signal story_event_acknowledged()

@onready var _vbox: VBoxContainer = $ScrollContainer/VBoxContainer

# UI elements (built in code)
var _title_label: Label
var _clock_card: PanelContainer
var _event_card: PanelContainer
var _evidence_card: PanelContainer
var _action_button: Button
var _details_rtl: RichTextLabel
var _restrictions_vbox: VBoxContainer

# State
var _story_track: FPCM_StoryTrackSystem = null
var _current_event: StoryEvent = null
var _display_mode: String = "clock"  # clock, event, evidence


func _ready() -> void:
	super._ready()
	_build_ui()


func setup_phase() -> void:
	super.setup_phase()
	_load_story_state()
	_update_display()


func _load_story_state() -> void:
	var pm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if not pm:
		return
	_story_track = pm.get("story_track")
	if not _story_track:
		_display_mode = "clock"
		return

	if _story_track.is_story_event_turn:
		_current_event = _story_track.get_current_event()
		_display_mode = "event"
	elif _story_track.in_evidence_search:
		_display_mode = "evidence"
	else:
		_display_mode = "clock"


func _build_ui() -> void:
	if not _vbox:
		return

	# Title
	_title_label = Label.new()
	_title_label.text = "STORY TRACK"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_phase_title(_title_label)
	_vbox.add_child(_title_label)

	# Details card
	var details_content := VBoxContainer.new()
	details_content.add_theme_constant_override(
		"separation", UIColors.SPACING_SM)

	_details_rtl = RichTextLabel.new()
	_details_rtl.bbcode_enabled = true
	_details_rtl.fit_content = true
	_details_rtl.scroll_active = false
	_details_rtl.custom_minimum_size = Vector2(0, 60)
	_style_rich_text(_details_rtl)
	details_content.add_child(_details_rtl)

	_restrictions_vbox = VBoxContainer.new()
	_restrictions_vbox.add_theme_constant_override(
		"separation", UIColors.SPACING_XS)
	details_content.add_child(_restrictions_vbox)

	_event_card = _create_phase_card(
		"Story Event", details_content)
	_vbox.add_child(_event_card)

	# Action button
	_action_button = Button.new()
	_action_button.text = "Continue"
	_style_phase_button(_action_button, true)
	_action_button.pressed.connect(_on_action_pressed)
	_vbox.add_child(_action_button)


func _update_display() -> void:
	if not _vbox or not _details_rtl:
		return

	match _display_mode:
		"event":
			_show_event_view()
		"evidence":
			_show_evidence_view()
		_:
			_show_clock_view()


func _show_clock_view() -> void:
	_title_label.text = "STORY TRACK"

	if not _story_track or not _story_track.is_story_track_active:
		_set_keyword_text(_details_rtl,
			"[i]Story Track is not active.[/i]")
		_action_button.text = "Continue"
		_action_button.disabled = false
		_restrictions_vbox.visible = false
		return

	var ticks: int = _story_track.story_clock_ticks
	var idx: int = _story_track.current_event_index
	var next_event: StoryEvent = _story_track.get_current_event()
	var next_title: String = next_event.title if next_event else "?"

	var text := "[b]Story Clock[/b]: %d tick%s remaining\n\n" % [
		ticks, "" if ticks == 1 else "s"]
	text += "[b]Next Event[/b]: Event %d — %s\n\n" % [
		idx + 1, next_title]

	if _story_track.pending_story_event:
		text += "[color=#D97706][b]The clock has reached zero![/b][/color]\n"
		text += "Next turn will be a Story Event."
	else:
		text += "[color=#808080]The clock ticks down at the end "
		text += "of each campaign turn based on battle results.[/color]"

	_set_keyword_text(_details_rtl, text)
	_restrictions_vbox.visible = false
	_action_button.text = "Continue"
	_action_button.disabled = false


func _show_event_view() -> void:
	if not _current_event:
		_show_clock_view()
		return

	_title_label.text = "EVENT %d: %s" % [
		_current_event.event_number,
		_current_event.title.to_upper()]

	var text := "[b]%s[/b]\n\n" % _current_event.title
	text += "%s\n\n" % _current_event.narrative_intro
	text += "[b]Battle Briefing:[/b]\n%s" % (
		_current_event.narrative_briefing)

	# Enemy summary
	var enemy_summary: String = _current_event.get_enemy_summary()
	if not enemy_summary.is_empty():
		text += "\n\n[b]Opposition:[/b] %s" % enemy_summary

	_set_keyword_text(_details_rtl, text)

	# Show turn restrictions
	_restrictions_vbox.visible = true
	for child in _restrictions_vbox.get_children():
		child.queue_free()

	var restrictions: Array[String] = (
		_current_event.get_turn_restriction_strings())
	if not restrictions.is_empty():
		var header := Label.new()
		header.text = "Campaign Turn Modifications:"
		header.add_theme_font_size_override(
			"font_size", _scaled_font(UIColors.FONT_SIZE_MD))
		header.add_theme_color_override(
			"font_color", UIColors.COLOR_WARNING)
		_restrictions_vbox.add_child(header)

		for r: String in restrictions:
			var lbl := Label.new()
			lbl.text = "  - %s" % r
			lbl.add_theme_font_size_override(
				"font_size", _scaled_font(UIColors.FONT_SIZE_SM))
			lbl.add_theme_color_override(
				"font_color", UIColors.COLOR_TEXT_PRIMARY)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_restrictions_vbox.add_child(lbl)

	_action_button.text = "Acknowledge & Continue"
	_action_button.disabled = false


func _show_evidence_view() -> void:
	_title_label.text = "STORY TRACK — EVIDENCE SEARCH"

	if not _story_track:
		_show_clock_view()
		return

	var evidence: int = _story_track.evidence_pieces
	var turns: int = _story_track.evidence_search_turns
	var text := "[b]Searching for your companion...[/b]\n\n"
	text += "Evidence collected: [b]%d[/b] pieces\n" % evidence
	text += "Turns searching: %d\n\n" % turns
	text += "Each turn: Roll 1D6 + %d evidence. " % evidence
	text += "On [b]7+[/b]: location found!\n"
	text += "Otherwise: +1 evidence, play normal turn.\n\n"
	text += "[color=#808080]Core Rules Appendix V p.158[/color]"

	_set_keyword_text(_details_rtl, text)
	_restrictions_vbox.visible = false
	_action_button.text = "Continue"
	_action_button.disabled = false


func _on_action_pressed() -> void:
	if _display_mode == "event":
		story_event_acknowledged.emit()
	complete_phase()


func validate_phase_requirements() -> bool:
	return true


func get_phase_data() -> Dictionary:
	var data: Dictionary = {"display_mode": _display_mode}
	if _story_track:
		data["story_status"] = _story_track.get_status()
	if _current_event:
		data["event_id"] = _current_event.event_id
		data["event_number"] = _current_event.event_number
	return data
