extends Control

## Bug Hunt Review Panel — Step 4 of 4
## Shows campaign summary before launch.

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_WARNING := _UC.COLOR_WARNING

const RefText := preload("res://src/ui/screens/bug_hunt/BugHuntReferenceText.gd")
const SquadPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd")

var _coordinator = null
var _summary_container: VBoxContainer


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


func refresh() -> void:
	## Called when panel becomes visible to update the summary.
	if not _coordinator or not _coordinator.state_manager:
		return
	_display_summary()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Never sideways (test_bug_hunt_screen_fit.gd): every row below wraps instead.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "MISSION BRIEFING — REVIEW"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	_summary_container = VBoxContainer.new()
	_summary_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_summary_container)


func _display_summary() -> void:
	for child in _summary_container.get_children():
		child.queue_free()

	var state = _coordinator.state_manager
	var config: Dictionary = state.config_data
	var squad: Dictionary = state.squad_data
	var characters: Array = squad.get("main_characters", [])

	# Campaign info card — ISSUE-043: show placeholders for empty fields
	var info_card := _create_card("Campaign", _summary_container)
	var name_val: String = config.get("campaign_name", "")
	_add_row(info_card, "Name", name_val if not name_val.is_empty() else "Not set")
	var regiment_val: String = config.get("regiment_name", "")
	_add_row(info_card, "Regiment", regiment_val if not regiment_val.is_empty() else "Not set")
	var uniform_val: String = config.get("uniform_color", "")
	_add_row(info_card, "Uniform", uniform_val if not uniform_val.is_empty() else "—")
	_add_row(info_card, "Difficulty", config.get("difficulty", "mess_me_up").replace("_", " ").capitalize())
	if config.get("use_campaign_escalation", false):
		_add_row(info_card, "Escalation", "Fixed Priority sequence")

	# Squad card
	var squad_card := _create_card("Squad (%d Main Characters)" % characters.size(), _summary_container)
	# Name, then the profile in the Squad step's order and format (p.170). This printed
	# "React:2 Spd:4 CS:0" on one unwrapped line, in a different order from the Squad
	# step's badges, and ran off a phone.
	for mc in characters:
		if mc is Dictionary:
			var name_lbl := Label.new()
			name_lbl.text = str(mc.get("name", "?"))
			name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
			name_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			squad_card.add_child(name_lbl)
			var parts := PackedStringArray()
			for pair in SquadPanelScript.stat_pairs_for(mc):
				parts.append("%s %s" % [pair[0], pair[1]])
			var stats_lbl := Label.new()
			stats_lbl.text = " · ".join(parts)
			stats_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
			stats_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
			stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			squad_card.add_child(stats_lbl)

	_add_row(squad_card, "Starting Reputation", str(squad.get("total_reputation", 0)))
	_add_row(squad_card, "Free Fire Team", RefText.fire_team_contents())

	# Movie Magic card
	var magic_card := _create_card("Movie Magic (10 one-time abilities)", _summary_container)
	var names := PackedStringArray()
	for row in BugHuntCampaignCore.movie_magic_abilities():
		if row is Dictionary:
			names.append(str(row.get("name", "")))
	# The ten p.181 names from the data; this was a literal beside it.
	var magic_list := ", ".join(names)
	var magic_lbl := Label.new()
	magic_lbl.text = magic_list
	magic_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	magic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	magic_card.add_child(magic_lbl)

	# Validation
	var errors: Array = _get_validation_errors(config, characters)
	if errors.is_empty():
		var ready_lbl := Label.new()
		# It named a "Finish" button this wizard does not have.
		ready_lbl.text = "Ready to deploy. Press Launch Campaign to begin."
		ready_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		ready_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
		ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_summary_container.add_child(ready_lbl)
	else:
		for err in errors:
			var err_lbl := Label.new()
			err_lbl.text = "! " + err
			err_lbl.add_theme_color_override("font_color", COLOR_WARNING)
			err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_summary_container.add_child(err_lbl)


func _get_validation_errors(config: Dictionary, characters: Array) -> Array:
	return BugHuntCampaignCore.validation_errors_for(
		str(config.get("campaign_name", "")), characters.size())


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	return vbox


## Label beside its value where the width allows; the value drops under the label on a
## phone (a flow row: the value keeps 120 px rather than wrapping a word per line).
func _add_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HFlowContainer.new()
	hbox.add_theme_constant_override("h_separation", 8)
	hbox.add_theme_constant_override("v_separation", 0)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.custom_minimum_size.x = 140
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", COLOR_TEXT)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.custom_minimum_size.x = 120
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(val)
