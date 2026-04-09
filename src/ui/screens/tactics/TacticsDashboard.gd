extends "res://src/ui/screens/tactics/TacticsScreenBase.gd"

## Tactics Dashboard — Full campaign overview and navigation hub.
## Shows campaign stats, army roster, operational map summary, and hub cards.

const EmptyStateWidgetClass = preload("res://src/ui/components/common/EmptyStateWidget.gd")
const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")

var _campaign: Resource  # TacticsCampaignCore
var _content: VBoxContainer


func _ready() -> void:
	_setup_screen()


func _setup_screen() -> void:
	_campaign = _get_tactics_campaign()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_PRIMARY
	bg.show_behind_parent = true
	add_child(bg)

	var layout: Dictionary = _create_scroll_layout()
	_content = layout.content
	_apply_content_max_width(layout.scroll)
	get_viewport().size_changed.connect(
		func(): _apply_content_max_width(layout.scroll))

	_build_dashboard()


func _build_dashboard() -> void:
	if not _campaign or not "campaign_units" in _campaign:
		var empty := EmptyStateWidgetClass.new()
		empty.setup(
			"No Active Tactics Campaign",
			"The command post is empty. Create a new campaign to marshal your forces.",
			"New Tactics Campaign",
			func(): _navigate("tactics_creation"))
		_content.add_child(empty)
		return

	# ── Header ──────────────────────────────────────────────────────
	var name_str: String = _campaign.campaign_name \
		if "campaign_name" in _campaign else "Tactics Campaign"
	var species_str: String = ""
	if "species_id" in _campaign:
		species_str = _campaign.species_id.replace("_", " ").capitalize()
	var army_str: String = _campaign.army_name \
		if "army_name" in _campaign else ""

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", SPACING_XS)
	_content.add_child(header_box)

	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override(
		"font_size", get_responsive_font_size(FONT_SIZE_XL + 4))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title)

	if not army_str.is_empty() or not species_str.is_empty():
		var sub := Label.new()
		if not army_str.is_empty():
			sub.text = "%s — %s" % [army_str, species_str]
		else:
			sub.text = species_str
		sub.add_theme_font_size_override(
			"font_size", get_responsive_font_size(FONT_SIZE_LG))
		sub.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_box.add_child(sub)

	# ── Stat Strip ──────────────────────────────────────────────────
	var turn: int = _campaign.campaign_turn \
		if "campaign_turn" in _campaign else 0
	var op_turn: int = _campaign.operational_turn \
		if "operational_turn" in _campaign else 0
	var cp: int = 0
	if _campaign.has_method("get_available_cp"):
		cp = _campaign.get_available_cp()
	var pts: int = _campaign.points_limit \
		if "points_limit" in _campaign else 500
	var active_units: int = 0
	if _campaign.has_method("get_active_campaign_units"):
		active_units = _campaign.get_active_campaign_units().size()
	var battles_won: int = 0
	if _campaign.has_method("get_battles_won"):
		battles_won = _campaign.get_battles_won()

	var stats := {
		"TURN": str(turn),
		"OP TURN": str(op_turn),
		"CP": str(cp),
		"UNITS": str(active_units),
		"WINS": str(battles_won),
	}
	_content.add_child(_create_stats_grid(stats, 5))

	# ── Navigation Hub Cards ────────────────────────────────────────
	var hub_box := VBoxContainer.new()
	hub_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(hub_box)

	var continue_card := HubFeatureCardClass.new()
	continue_card.setup("", "Continue Campaign",
		"Start the next operational turn")
	continue_card.card_pressed.connect(
		func(): _navigate("tactics_turn_controller"))
	hub_box.add_child(continue_card)

	var save_card := HubFeatureCardClass.new()
	save_card.setup("", "Save Campaign",
		"Save current progress to disk")
	save_card.card_pressed.connect(_on_save)
	hub_box.add_child(save_card)

	var menu_card := HubFeatureCardClass.new()
	menu_card.setup("", "Main Menu",
		"Return to the main menu")
	menu_card.card_pressed.connect(
		func(): _navigate("main_menu"))
	hub_box.add_child(menu_card)

	# ── Operational Map Summary ─────────────────────────────────────
	if "operational_map" in _campaign \
			and not _campaign.operational_map.is_empty():
		_build_map_summary()

	# ── Army Roster ─────────────────────────────────────────────────
	_build_roster_section()

	# ── Battle History ──────────────────────────────────────────────
	if "battle_history" in _campaign \
			and not _campaign.battle_history.is_empty():
		_build_battle_history()


func _build_map_summary() -> void:
	var map: Dictionary = _campaign.operational_map
	var section := _create_section_card(
		"Operational Map",
		VBoxContainer.new(),
		"Strategic overview")
	_content.add_child(section)

	var info_box: VBoxContainer = section.get_child(0).get_child(0) \
		if section.get_child_count() > 0 else VBoxContainer.new()

	# Find the VBoxContainer inside the section card
	var card_content: VBoxContainer = null
	for child in _recurse_children(section):
		if child is VBoxContainer and child.get_child_count() == 0:
			card_content = child
			break
	if not card_content:
		card_content = VBoxContainer.new()
		section.add_child(card_content)

	var p_coh: int = map.get("player_cohesion", 5)
	var e_coh: int = map.get("enemy_cohesion", 5)
	var pbp: int = map.get("player_battle_points", 0)
	var zones: Array = map.get("zones", [])

	var stats_text := "Cohesion: Player %d / Enemy %d | PBP: %d | Zones: %d" % [
		p_coh, e_coh, pbp, zones.size()]
	var stats_lbl := Label.new()
	stats_lbl.text = stats_text
	stats_lbl.add_theme_font_size_override(
		"font_size", get_responsive_font_size(FONT_SIZE_SM))
	stats_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_content.add_child(stats_lbl)


func _build_roster_section() -> void:
	var section_lbl := Label.new()
	section_lbl.text = "Army Roster"
	section_lbl.add_theme_font_size_override(
		"font_size", get_responsive_font_size(FONT_SIZE_LG))
	section_lbl.add_theme_color_override("font_color", COLOR_CYAN)
	_content.add_child(section_lbl)

	var units: Array = _campaign.campaign_units \
		if "campaign_units" in _campaign else []

	if units.is_empty():
		var empty := Label.new()
		empty.text = "No units in roster"
		empty.add_theme_font_size_override(
			"font_size", get_responsive_font_size(FONT_SIZE_SM))
		empty.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_content.add_child(empty)
		return

	for unit in units:
		if unit is not Dictionary:
			continue
		var card := _create_unit_card(unit)
		_content.add_child(card)


func _create_unit_card(unit: Dictionary) -> PanelContainer:
	var name_str: String = unit.get("custom_name",
		unit.get("base_unit_id", "Unknown").replace("_", " ").capitalize())
	var models: int = unit.get("current_models", 0)
	var battles: int = unit.get("battles_fought", 0)
	var destroyed: bool = unit.get("is_destroyed", false)

	var subtitle := "%d models — %d battles" % [models, battles]
	if destroyed:
		subtitle = "DESTROYED — " + subtitle

	var stats := {
		"Models": str(models),
		"Battles": str(battles),
		"Wins": str(unit.get("battles_won", 0)),
		"CP": str(unit.get("campaign_points", 0)),
	}

	var card: PanelContainer = _create_character_card(
		name_str, subtitle, stats)

	# Dim destroyed units
	if destroyed:
		card.modulate = Color(1, 1, 1, 0.5)

	return card


func _build_battle_history() -> void:
	var section_lbl := Label.new()
	section_lbl.text = "Battle History"
	section_lbl.add_theme_font_size_override(
		"font_size", get_responsive_font_size(FONT_SIZE_LG))
	section_lbl.add_theme_color_override("font_color", COLOR_CYAN)
	_content.add_child(section_lbl)

	var history: Array = _campaign.battle_history
	# Show last 5 battles (newest first)
	var count: int = mini(history.size(), 5)
	for i in range(history.size() - 1, history.size() - count - 1, -1):
		var entry: Dictionary = history[i]
		var won: bool = entry.get("won", false)
		var lbl := Label.new()
		lbl.text = "Turn %d: %s — CP earned: %d" % [
			entry.get("turn", 0),
			"Victory" if won else "Defeat",
			entry.get("cp_earned", 0)]
		lbl.add_theme_font_size_override(
			"font_size", get_responsive_font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color",
			COLOR_SUCCESS if won else COLOR_DANGER)
		_content.add_child(lbl)


func _navigate(route: String) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to(route)


func _on_save() -> void:
	if not _campaign or not _campaign.has_method("save_to_file"):
		return
	var save_dir := "user://saves/"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var path: String = save_dir + _campaign.get_campaign_id() + ".save"
	var err: Error = _campaign.save_to_file(path)
	if err == OK:
		print("[TacticsDashboard] Campaign saved to: %s" % path)


func _recurse_children(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_recurse_children(child))
	return result
