extends "res://src/ui/screens/planetfall/PlanetfallScreenBase.gd"

## Planetfall Dashboard — Colony overview screen.
## Shows colony stats, roster, map, research tree, buildings, and milestones.
## Follows BugHuntDashboard pattern: code-built, factory methods from CampaignScreenBase.
## TODO: Full implementation in Colony Systems sprint.

const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")
const ColonyStatusScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallColonyStatusPanel.gd")
const EquipmentPanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallEquipmentPanel.gd")
const EnemyTrackerScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallEnemyTrackerPanel.gd")
const AugmentationPanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallAugmentationPanel.gd")
const MilestonePanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallMilestonePanel.gd")
const CalamityPanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallCalamityPanel.gd")
const EndGamePanelScript = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallEndGamePanel.gd")

var _campaign: Resource
var _content: VBoxContainer
var _overlay_container: Control


func _setup_screen() -> void:
	_campaign = _get_planetfall_campaign()
	_build_dashboard()


func _build_dashboard() -> void:
	var layout := _create_scroll_layout()
	_content = layout.content

	if not _campaign or not "roster" in _campaign:
		var EmptyStateWidgetClass = load("res://src/ui/components/common/EmptyStateWidget.gd")
		if EmptyStateWidgetClass:
			var empty = EmptyStateWidgetClass.new()
			empty.setup(
				"No Active Colony",
				"The landing site is empty. Start a new " +
					"Planetfall campaign to establish your colony.",
				"New Planetfall Campaign",
				func(): _navigate("planetfall_creation"))
			_content.add_child(empty)
		return

	# Header
	var name_str: String = _campaign.campaign_name \
		if "campaign_name" in _campaign else "Unknown Colony"
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
	var milestones: int = _campaign.milestones_completed \
		if "milestones_completed" in _campaign else 0

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
	var gp: String = _campaign.game_phase if "game_phase" in _campaign else ""
	var is_endgame: bool = gp == "endgame"
	var is_completed: bool = gp == "completed"
	if is_endgame:
		continue_card.setup("", "Enter End Game",
			"The 7th Milestone has been achieved")
	elif is_completed:
		continue_card.setup("", "Campaign Complete", "View your colony's final story")
	else:
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

	# Detail hub cards (Sprint 4)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(detail_box)

	var detail_header := Label.new()
	detail_header.text = "COLONY MANAGEMENT"
	detail_header.add_theme_font_size_override(
		"font_size", get_responsive_font_size(FONT_SIZE_LG))
	detail_header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	detail_box.add_child(detail_header)

	var colony_status_card := HubFeatureCardClass.new()
	var r_summary: Dictionary = _campaign.get_research_summary() \
		if _campaign.has_method("get_research_summary") else {}
	var b_summary: Dictionary = _campaign.get_building_summary() \
		if _campaign.has_method("get_building_summary") else {}
	colony_status_card.setup("", "Colony Status",
		"Research: %d theories | Buildings: %d constructed" % [
			r_summary.get("completed_theories", 0),
			b_summary.get("constructed", 0)])
	colony_status_card.card_pressed.connect(func(): _show_overlay_panel("colony_status"))
	detail_box.add_child(colony_status_card)

	var armory_card := HubFeatureCardClass.new()
	armory_card.setup("", "Armory", "Browse available weapons and equipment")
	armory_card.card_pressed.connect(func(): _show_overlay_panel("equipment"))
	detail_box.add_child(armory_card)

	var enemy_card := HubFeatureCardClass.new()
	var enemies: Array = _campaign.tactical_enemies \
		if "tactical_enemies" in _campaign else []
	var signs: Array = _campaign.ancient_signs \
		if "ancient_signs" in _campaign else []
	enemy_card.setup("", "Enemy Tracker",
		"%d tactical enemies | %d ancient signs" % [
			enemies.size(), signs.size()])
	enemy_card.card_pressed.connect(func(): _show_overlay_panel("enemy_tracker"))
	detail_box.add_child(enemy_card)

	var aug_count: int = _campaign.get_augmentation_count() \
		if _campaign.has_method("get_augmentation_count") else 0
	var aug_ap: int = _campaign.augmentation_points \
		if "augmentation_points" in _campaign else 0
	var aug_card := HubFeatureCardClass.new()
	aug_card.setup("", "Augmentations",
		"%d owned | %d AP available" % [aug_count, aug_ap])
	aug_card.card_pressed.connect(func(): _show_overlay_panel("augmentation"))
	detail_box.add_child(aug_card)

	# Milestones & Progression
	var ms_count: int = _campaign.milestones_completed \
		if "milestones_completed" in _campaign else 0
	var milestone_card := HubFeatureCardClass.new()
	milestone_card.setup("", "Milestones & Progression",
		"%d / 7 completed" % ms_count)
	milestone_card.card_pressed.connect(func(): _show_overlay_panel("milestones"))
	detail_box.add_child(milestone_card)

	# Active Calamities (only show if any exist)
	var active_calamities: Array = []
	if "active_calamities" in _campaign:
		for cal in _campaign.active_calamities:
			if cal is Dictionary and not cal.get("resolved", false):
				active_calamities.append(cal)
	if not active_calamities.is_empty():
		var calamity_card := HubFeatureCardClass.new()
		calamity_card.setup("", "Active Calamities",
			"%d calamit%s" % [active_calamities.size(),
				"y" if active_calamities.size() == 1 else "ies"])
		calamity_card.card_pressed.connect(func(): _show_overlay_panel("calamities"))
		detail_box.add_child(calamity_card)

	# Roster summary
	_build_roster_section(roster_arr)

	# Overlay container for detail panels (rendered on top)
	_overlay_container = Control.new()
	_overlay_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_container.visible = false
	add_child(_overlay_container)


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


func _show_overlay_panel(panel_type: String) -> void:
	## Show a detail panel as an overlay on top of the dashboard.
	if not _overlay_container:
		return
	# Clear existing overlay
	for child in _overlay_container.get_children():
		child.queue_free()

	var panel: Control
	match panel_type:
		"colony_status":
			panel = ColonyStatusScript.new()
		"equipment":
			panel = EquipmentPanelScript.new()
		"enemy_tracker":
			panel = EnemyTrackerScript.new()
		"augmentation":
			panel = AugmentationPanelScript.new()
			if panel.has_method("set_standalone"):
				panel.set_standalone(true)
		"milestones":
			panel = MilestonePanelScript.new()
		"calamities":
			panel = CalamityPanelScript.new()
		_:
			return

	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if panel.has_method("set_campaign"):
		panel.set_campaign(_campaign)
	_overlay_container.add_child(panel)
	_overlay_container.visible = true

	# When panel hides itself, hide the overlay container
	panel.visibility_changed.connect(func():
		if not panel.visible:
			_overlay_container.visible = false
	)

	if panel.has_method("refresh"):
		panel.refresh()


func _on_save() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("save_campaign"):
		game_state.save_campaign()
