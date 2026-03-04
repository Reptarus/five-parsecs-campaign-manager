extends Control

## Bug Hunt Review Panel — Step 4 of 4
## Shows campaign summary before launch.

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")

var _coordinator = null
var _summary_container: VBoxContainer


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
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "MISSION BRIEFING — REVIEW"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	# Campaign info card
	var info_card := _create_card("Campaign", _summary_container)
	_add_row(info_card, "Name", config.get("campaign_name", "Unnamed"))
	_add_row(info_card, "Regiment", config.get("regiment_name", "No regiment"))
	_add_row(info_card, "Uniform", config.get("uniform_color", "—"))
	_add_row(info_card, "Difficulty", config.get("difficulty", "mess_me_up").replace("_", " ").capitalize())
	if config.get("use_campaign_escalation", false):
		_add_row(info_card, "Escalation", "Fixed Priority sequence")

	# Squad card
	var squad_card := _create_card("Squad (%d Main Characters)" % characters.size(), _summary_container)
	for mc in characters:
		if mc is Dictionary:
			var text := "%s — React:%d Spd:%d CS:%d Tough:%d Savvy:%d (XP:%d)" % [
				mc.get("name", "?"), mc.get("reactions", 0), mc.get("speed", 0),
				mc.get("combat_skill", 0), mc.get("toughness", 0), mc.get("savvy", 0),
				mc.get("xp", 0)]
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_color_override("font_color", COLOR_TEXT)
			lbl.add_theme_font_size_override("font_size", 14)
			squad_card.add_child(lbl)

	_add_row(squad_card, "Starting Reputation", str(squad.get("total_reputation", 0)))
	_add_row(squad_card, "Free Fire Team", "4 Grunts with Combat Rifles")

	# Movie Magic card
	var magic_card := _create_card("Movie Magic (10 one-time abilities)", _summary_container)
	var magic_list := "Barricade, Double-Up, Escape, Evac, Extra Support, Lucky Find, Reinforcements, Remove Contact, Survived, You Want Some Too?"
	var magic_lbl := Label.new()
	magic_lbl.text = magic_list
	magic_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	magic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	magic_card.add_child(magic_lbl)

	# Validation
	var errors: Array = _get_validation_errors(config, characters)
	if errors.is_empty():
		var ready_lbl := Label.new()
		ready_lbl.text = "Ready to deploy! Click Finish to begin your campaign."
		ready_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		ready_lbl.add_theme_font_size_override("font_size", 16)
		ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_summary_container.add_child(ready_lbl)
	else:
		for err in errors:
			var err_lbl := Label.new()
			err_lbl.text = "! " + err
			err_lbl.add_theme_color_override("font_color", COLOR_WARNING)
			_summary_container.add_child(err_lbl)


func _get_validation_errors(config: Dictionary, characters: Array) -> Array:
	var errors: Array = []
	if config.get("campaign_name", "").is_empty():
		errors.append("Campaign name is required")
	if characters.size() < 3:
		errors.append("Need at least 3 Main Characters")
	return errors


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
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
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox


func _add_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
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
	hbox.add_child(val)
