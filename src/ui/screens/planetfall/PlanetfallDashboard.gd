extends PlanetfallScreenBase

## Planetfall Dashboard — Colony overview screen.
## Shows colony stats, roster, map, research tree, buildings, and milestones.
## Follows BugHuntDashboard pattern: code-built, factory methods from CampaignScreenBase.
## TODO: Full implementation in Colony Systems sprint.

const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")

var _campaign: Resource
var _content: VBoxContainer


func _setup_screen() -> void:
	_campaign = _get_planetfall_campaign()
	_build_dashboard()


func _build_dashboard() -> void:
	var layout := _create_scroll_layout()
	_content = layout.content

	if not _campaign or not "roster" in _campaign:
		var EmptyStateWidgetClass = load("res://src/ui/components/common/EmptyStateWidget.gd")
		if EmptyStateWidgetClass:
			var empty := EmptyStateWidgetClass.new()
			empty.setup(
				"No Active Colony",
				"The landing site is empty. Start a new Planetfall campaign to establish your colony.",
				"New Planetfall Campaign",
				func(): _navigate("planetfall_creation"))
			_content.add_child(empty)
		return

	# Header
	var name_str: String = _campaign.campaign_name if "campaign_name" in _campaign else "Unknown Colony"
	var colony: String = _campaign.colony_name if "colony_name" in _campaign else ""

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", SPACING_XS)

	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL + 4))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title)

	if not colony.is_empty() and colony != name_str:
		var colony_lbl := Label.new()
		colony_lbl.text = "Colony: %s" % colony
		colony_lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_LG))
		colony_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		colony_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_box.add_child(colony_lbl)

	_content.add_child(header_box)

	# Stat strip
	var turn: int = _campaign.campaign_turn if "campaign_turn" in _campaign else 0
	var morale: int = _campaign.colony_morale if "colony_morale" in _campaign else 0
	var integrity: int = _campaign.colony_integrity if "colony_integrity" in _campaign else 0
	var sp: int = _campaign.story_points if "story_points" in _campaign else 5
	var grunt_count: int = _campaign.grunts if "grunts" in _campaign else 12
	var roster_arr: Array = _campaign.roster if "roster" in _campaign else []
	var milestones: int = _campaign.milestones_completed if "milestones_completed" in _campaign else 0

	var stats := {
		"TURN": turn,
		"MORALE": morale,
		"INTEGRITY": integrity,
		"SP": sp,
		"ROSTER": roster_arr.size(),
		"GRUNTS": grunt_count,
		"MILESTONES": "%d/7" % milestones
	}
	var stat_grid := _create_stats_grid(stats, mini(stats.size(), 4))
	_content.add_child(stat_grid)

	# Navigation hub cards
	var hub_box := VBoxContainer.new()
	hub_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(hub_box)

	var continue_card := HubFeatureCardClass.new()
	continue_card.setup("", "Continue Campaign", "Start the next campaign turn")
	continue_card.card_pressed.connect(func(): _navigate("planetfall_turn_controller"))
	hub_box.add_child(continue_card)

	var save_card := HubFeatureCardClass.new()
	save_card.setup("", "Save Campaign", "Save current progress to disk")
	save_card.card_pressed.connect(_on_save)
	hub_box.add_child(save_card)

	var menu_card := HubFeatureCardClass.new()
	menu_card.setup("", "Main Menu", "Return to the main menu")
	menu_card.card_pressed.connect(func(): _navigate("main_menu"))
	hub_box.add_child(menu_card)

	# Roster summary
	_build_roster_section(roster_arr)


func _build_roster_section(roster: Array) -> void:
	var section_header := _create_section_header("COLONY ROSTER")
	_content.add_child(section_header)

	for char_dict in roster:
		if char_dict is not Dictionary:
			continue
		var card := _build_character_card(char_dict)
		_content.add_child(card)


func _build_character_card(char_dict: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(panel, "elevated")

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	panel.add_child(hbox)

	# Name + class
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = char_dict.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(name_lbl)

	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", SPACING_XS)
	pill_row.add_child(_create_class_pill(char_dict.get("class", "")))
	pill_row.add_child(_create_loyalty_pill(char_dict.get("loyalty", "committed")))
	if char_dict.get("is_imported", false):
		pill_row.add_child(_create_pill("Imported", Color("#8b5cf6")))
	vbox.add_child(pill_row)

	# Stat line
	var stat_parts: Array[String] = []
	for key in ["reactions", "speed", "combat_skill", "toughness", "savvy"]:
		var abbrev: String
		match key:
			"reactions": abbrev = "R"
			"speed": abbrev = "Spd"
			"combat_skill": abbrev = "CS"
			"toughness": abbrev = "T"
			"savvy": abbrev = "Sv"
			_: abbrev = key
		stat_parts.append("%s:%d" % [abbrev, char_dict.get(key, 0)])
	var stat_lbl := Label.new()
	stat_lbl.text = "  ".join(stat_parts)
	stat_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	stat_lbl.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(stat_lbl)

	return panel


func _on_save() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("save_campaign"):
		game_state.save_campaign()
