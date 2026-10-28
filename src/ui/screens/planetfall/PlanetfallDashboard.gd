extends "res://src/ui/screens/planetfall/PlanetfallScreenBase.gd"

## Planetfall Dashboard: the colony between turns. Every number the colony tracks, the
## colony map with each Tactical Enemy's state, the screens a player opens between turns,
## and the roster as the Colony Tracking Sheet records it (p.24).
## Code-built from CampaignScreenBase's factories, like BugHuntDashboard.

const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")
# Used at :142 but never declared here, so this screen failed to PARSE and the
# Planetfall Dashboard hard-broke into the debugger. BugHuntDashboard and
# TacticsDashboard both declare it; only this one was missed.
const SaveFileWriterRef = preload("res://src/core/state/SaveFileWriter.gd")
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
const ImportPanelClass = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd")
const SectorGridScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const RosterRules := preload("res://src/core/systems/PlanetfallRosterRules.gd")
const BackgroundsScript := preload("res://src/core/systems/PlanetfallBackgrounds.gd")
const PhaseManagerScript := preload("res://src/core/campaign/PlanetfallPhaseManager.gd")

## Wider than a form: the dashboard lays its cards out in columns on a tablet.
const MAX_DASHBOARD_WIDTH := 1400

var _campaign: Resource
var _content: VBoxContainer
var _overlay_container: Control
## Where an overlay panel goes inside _overlay_container (ScreenChrome.overlay_frame).
var _overlay_frame: MarginContainer
var _root_scroll: ScrollContainer
## Whether the dashboard was last built for a phone (one column), so a rotation that
## changes it rebuilds.
var _built_narrow: bool = false


func _setup_screen() -> void:
	_campaign = _get_planetfall_campaign()
	_build_dashboard()
	# Surface any veterans transferred toward this colony (CampaignScreenBase).
	_check_pending_transfers.call_deferred()


## CampaignScreenBase hook — rebuild after veterans muster in.
func _on_transfers_applied() -> void:
	_campaign = _get_planetfall_campaign()
	_rebuild()


## ── Character transfer ──────────────────────────────────────────────────

func _on_import_pressed() -> void:
	if not _campaign or not "roster" in _campaign:
		return
	var panel = ImportPanelClass.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(panel)
	panel.set_existing_roster(_campaign.roster)
	panel.character_imported.connect(func(pf_char: Dictionary) -> void:
		_apply_import(pf_char))
	panel.load_all_sources()


func _apply_import(pf_char: Dictionary) -> void:
	if not _campaign or not _campaign.has_method("add_roster_character"):
		return
	# Pull the source coordinates off before the character lands in the roster, so
	# they never persist into the Planetfall save.
	var src_path: String = str(pf_char.get("_source_path", ""))
	var src_id: String = str(pf_char.get("_source_character_id", ""))
	pf_char.erase("_source_path")
	pf_char.erase("_source_character_id")

	_campaign.add_roster_character(pf_char)
	_on_save()

	# DESTINATION FIRST, THEN DROP THE SOURCE — the same ordering muster-out uses.
	# Without this the imported veteran stayed in their original campaign as well,
	# so one character existed in two campaigns and could be imported repeatedly.
	if not src_path.is_empty() and not src_id.is_empty():
		if not CharacterTransferService.remove_character_from_save(src_path, src_id):
			push_warning(
				"PlanetfallDashboard: imported %s but could not remove them from %s"
				% [src_id, src_path])
	_rebuild()


func _on_muster_out_pressed() -> void:
	if not _campaign or not "roster" in _campaign:
		return
	var roster: Array = _campaign.get_musterable_roster() \
			if _campaign.has_method("get_musterable_roster") else _campaign.roster
	if roster.is_empty():
		return
	# Lightweight full-screen picker: each colonist row offers two destinations.
	var overlay := _build_muster_out_overlay(roster)
	get_tree().root.add_child(overlay)


func _do_muster_out(char_data: Dictionary, target_mode: String, overlay: Node) -> void:
	# Stamp the campaign ending so end-of-campaign bonuses apply (empty mid-campaign).
	var c: Dictionary = char_data.duplicate(true)
	c["planetfall_ending"] = _campaign.get_planetfall_ending() \
			if _campaign.has_method("get_planetfall_ending") else ""

	var svc = CharacterTransferService.new()
	var envelope: Dictionary = svc.transfer_character(c, "planetfall", target_mode)
	envelope["source_campaign_id"] = _campaign.campaign_id if "campaign_id" in _campaign else ""
	envelope["source_campaign_name"] = _campaign.campaign_name \
		if "campaign_name" in _campaign else ""
	# Write the destination FIRST and only drop the source if it succeeded. The
	# transfer file is the ONLY copy of this character once it leaves the roster.
	if not _write_transfer_file(envelope, c):
		_notify_transfer_write_failed()
		return

	var cid: String = str(c.get("id", c.get("character_id", "")))
	if _campaign.has_method("remove_roster_character"):
		_campaign.remove_roster_character(cid)
	_on_save()

	if is_instance_valid(overlay):
		overlay.queue_free()
	_rebuild()


func _write_transfer_file(envelope: Dictionary, char_data: Dictionary) -> bool:
	## Returns true only if the envelope is on disk.
	##
	## This used to return void and swallow every failure: the write was wrapped in
	## `if file:` while the caller removed the character and saved unconditionally.
	## An I/O failure therefore deleted the colonist from this campaign, PERSISTED
	## that deletion, and wrote nothing for the destination to pick up — the character
	## vanished from both ends, silently. That is the exact loss the file-drop
	## mechanism exists to prevent.
	##
	## Routed through SaveFileWriter so the write is checked rather than assumed
	## (flush, get_error, verified rename) instead of hand-rolled here.
	var transfer_dir := "user://transfers/"
	if not DirAccess.dir_exists_absolute(transfer_dir):
		DirAccess.make_dir_recursive_absolute(transfer_dir)
	var cid: String = str(char_data.get("id", char_data.get("character_id", "")))
	var filename := "transfer_%s_%s.json" % [cid, str(Time.get_unix_time_from_system())]
	var err: Error = SaveFileWriterRef.write_text_atomic(
		transfer_dir + filename, JSON.stringify(envelope, "\t"))
	return err == OK


func _notify_transfer_write_failed() -> void:
	push_error("PlanetfallDashboard: transfer file could not be written — "
		+ "colonist kept in the roster rather than lost")
	# ⚠ `show_notification` DOES NOT EXIST on NotificationManager — `func
	# show_notification` has ZERO definitions repo-wide, so this guard was
	# permanently false and the player was told NOTHING on a failure path.
	# The real API is show_info / show_success / show_warning / show_error /
	# show_toast (src/autoload/NotificationManager.gd:105-131).
	# WorldPhaseAutomationController:569-570 already found and documented this
	# trap; these call sites were missed by that pass.
	var notifier := get_node_or_null("/root/NotificationManager")
	if notifier and notifier.has_method("show_error"):
		notifier.show_error(
			"Transfer failed — the colonist is still on your roster. Check device storage.")


func _build_muster_out_overlay(roster: Array) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox := ScreenChrome.overlay_page(overlay, MAX_FORM_WIDTH)

	# First and top right, as on the dashboard's other overlays: below a long roster a
	# phone had to scroll past every colonist to back out.
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 48)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(cancel)

	var title := Label.new()
	title.text = "MUSTER COLONISTS OUT"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for member in roster:
		if member is not Dictionary:
			continue
		# A flow: the name and the button pair share a line where they fit and the pair
		# drops below the name on a phone (side by side they ran off the right edge).
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", SPACING_SM)
		row.add_theme_constant_override("v_separation", 4)
		var name_lbl := Label.new()
		name_lbl.text = str(member.get("name", "Colonist"))
		name_lbl.custom_minimum_size.x = 180
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		row.add_child(name_lbl)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", SPACING_SM)
		row.add_child(buttons)
		var captured: Dictionary = (member as Dictionary).duplicate(true)
		var to_5pfh := Button.new()
		to_5pfh.text = "→ 5PFH"
		to_5pfh.custom_minimum_size.y = 44
		to_5pfh.pressed.connect(func() -> void:
			_do_muster_out(captured, "five_parsecs", overlay))
		buttons.add_child(to_5pfh)
		var to_bh := Button.new()
		to_bh.text = "→ Bug Hunt"
		to_bh.custom_minimum_size.y = 44
		to_bh.pressed.connect(func() -> void:
			_do_muster_out(captured, "bug_hunt", overlay))
		buttons.add_child(to_bh)
		vbox.add_child(row)
	return overlay


func _build_dashboard() -> void:
	var layout := _create_scroll_layout(MAX_DASHBOARD_WIDTH)
	_root_scroll = layout.scroll
	_content = layout.content
	_built_narrow = _is_narrow()

	# Overlay container for detail panels (rendered on top). One frame hosts all six,
	# so each gets the page colour, a gutter and a top clear of the Settings buttons.
	_overlay_container = Control.new()
	_overlay_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_container.visible = false
	add_child(_overlay_container)
	_overlay_frame = ScreenChrome.overlay_frame(_overlay_container, MAX_FORM_WIDTH)

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

	_build_header()
	_build_stats_section()
	_build_continue_card()
	_build_map_section()
	_build_hub_section()
	_build_roster_section(_campaign.roster if "roster" in _campaign else [])
	TouchScrollOpenerRef.open_subtree(self)


## Rebuild after something changed the colony (an import, a muster-out) or the layout
## class changed (rotation). Only the dashboard's own nodes are freed: the base screen's
## background stays.
func _rebuild() -> void:
	for node in [_root_scroll, _overlay_container]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_build_dashboard()


## A rotation can change how many columns fit, so rebuild when it does.
func _update_layout_for_mode() -> void:
	super._update_layout_for_mode()
	if _campaign and is_instance_valid(_content) and _is_narrow() != _built_narrow:
		_rebuild()


func _is_narrow() -> bool:
	var rm := get_node_or_null("/root/ResponsiveManager")
	return rm != null and rm.has_method("should_collapse_to_single_column") \
			and rm.should_collapse_to_single_column()


func _build_header() -> void:
	var name_str: String = _campaign.campaign_name \
		if "campaign_name" in _campaign else "Unknown Colony"
	var colony: String = _campaign.colony_name if "colony_name" in _campaign else ""
	var turn: int = int(_campaign.campaign_turn) if "campaign_turn" in _campaign else 0

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", SPACING_XS)
	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL + 4))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long campaign/colony names must wrap, not clip, in narrow portrait (~384px).
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title)

	var sub_parts: Array = []
	if not colony.is_empty() and colony != name_str:
		sub_parts.append("Colony: %s" % colony)
	# campaign_turn counts turns STARTED (advance_turn() runs at turn start), so 0 means
	# none yet; "Campaign turn 0" read like a fault on a freshly founded colony.
	sub_parts.append("Campaign turn %d" % turn if turn > 0 else "Colony founded, no turn played yet")
	var expedition: String = str(_campaign.expedition_type) \
			if "expedition_type" in _campaign else ""
	if expedition != "":
		sub_parts.append(expedition)
	var sub := Label.new()
	sub.text = " · ".join(PackedStringArray(sub_parts))
	sub.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_MD))
	sub.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(sub)
	_content.add_child(header_box)


## Every number the colony tracks (p.24 Colony Tracking Sheet), from the one reader the
## turn screen also uses. The roster count sits beside them.
func _build_stats_section() -> void:
	var all: Dictionary = colony_stats(_campaign)
	var stats: Dictionary = {}
	for key in COLONY_STAT_ORDER:
		if all.has(key):
			stats[all[key][1]] = all[key][2]
	stats["Characters"] = (_campaign.roster as Array).size() if "roster" in _campaign else 0
	var grid := _create_stats_grid(stats, 2 if _built_narrow else 5)
	# A GridContainer splits spare width only among children that EXPAND; without this
	# the tiles sat at their 64 px minimum in a clump at the column's left edge.
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tile in grid.get_children():
		(tile as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)


func _build_continue_card() -> void:
	var continue_card := HubFeatureCardClass.new()
	var gp: String = _campaign.game_phase if "game_phase" in _campaign else ""
	if gp == "failed":
		continue_card.setup("", "Campaign Failure",
			"Unity forces have taken control of the colony (p.90)")
	elif gp == "endgame":
		continue_card.setup("", "Enter End Game",
			"The 7th Milestone has been achieved")
	elif gp == "completed":
		continue_card.setup("", "Campaign Complete", "View your colony's final story")
	else:
		continue_card.setup("", "Continue Campaign", _continue_hint())
	continue_card.card_pressed.connect(func(): _navigate("planetfall_turn_controller"))
	_content.add_child(continue_card)


## Where Continue takes the player: the step a turn was left on, or a new turn.
func _continue_hint() -> String:
	if _campaign.has_method("has_recorded_turn_phase") and _campaign.has_recorded_turn_phase():
		var phase: int = int(_campaign.turn_phase)
		if phase >= 0:
			return "Resume turn %d at Step %d: %s" % [int(_campaign.campaign_turn), phase + 1,
					str(PhaseManagerScript.PHASE_NAMES.get(phase, ""))]
	return "Start campaign turn %d" % (int(_campaign.campaign_turn) + 1)


## The colony map (pp.52-53) and what the colony knows of each Tactical Enemy (pp.50-51):
## the sectors it holds, its Enemy Information, and a located Strongpoint or tracked Boss.
## The dashboard showed no map at all until 2026-10-28, and the enemy card only counted
## enemies.
func _build_map_section() -> void:
	_content.add_child(_create_section_header("COLONY MAP"))
	if _campaign.map_data is Dictionary and not (_campaign.map_data as Dictionary).is_empty():
		var grid: Control = SectorGridScript.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(grid)
		grid.show_map(_campaign)
	else:
		_content.add_child(_line("No map yet.", COLOR_TEXT_SECONDARY))
	var enemies: Array = _campaign.tactical_enemies if "tactical_enemies" in _campaign else []
	if enemies.is_empty():
		_content.add_child(_line("No Tactical Enemy has been encountered yet (p.50).",
				COLOR_TEXT_SECONDARY))
	for i in range(enemies.size()):
		_content.add_child(_line(enemy_summary(_campaign, i), COLOR_TEXT_PRIMARY
				if MapScript.is_active(_campaign, i) else COLOR_TEXT_SECONDARY))


## One line about Tactical Enemy `idx`, for the dashboard and a test.
static func enemy_summary(campaign: Resource, idx: int) -> String:
	var name: String = MapScript.enemy_name(campaign, idx)
	if not MapScript.is_active(campaign, idx):
		return "%s: defeated." % name
	var held: int = MapScript.held_by(campaign, idx).size()
	var parts: Array = ["holds %d sector%s" % [held, "" if held == 1 else "s"]]
	var info: int = int(campaign.get_enemy_info_count(idx)) \
			if campaign.has_method("get_enemy_info_count") else 0
	parts.append("Enemy Information %d" % info)
	var marks: Dictionary = MapScript.enemy_marks(campaign, idx)
	if str(marks.strongpoint) != "":
		parts.append("Strongpoint located at %s" % MapScript.label(str(marks.strongpoint)))
	if str(marks.boss) != "":
		parts.append("Boss tracked at %s" % MapScript.label(str(marks.boss)))
	return "%s: %s." % [name, ", ".join(PackedStringArray(parts))]


## The screens a player opens between turns, in a grid that is one column on a phone and
## three on a tablet. They used to be one column of 2560 px wide cards.
func _build_hub_section() -> void:
	_content.add_child(_create_section_header("COLONY MANAGEMENT"))
	var hub := GridContainer.new()
	hub.columns = 1 if _built_narrow else 3
	hub.add_theme_constant_override("h_separation", SPACING_SM)
	hub.add_theme_constant_override("v_separation", SPACING_SM)
	_content.add_child(hub)

	var r_summary: Dictionary = _campaign.get_research_summary() \
		if _campaign.has_method("get_research_summary") else {}
	var b_summary: Dictionary = _campaign.get_building_summary() \
		if _campaign.has_method("get_building_summary") else {}
	_hub_card(hub, "Colony Status", "Research: %d theories | Buildings: %d constructed" % [
			r_summary.get("completed_theories", 0), b_summary.get("constructed", 0)],
			func(): _show_overlay_panel("colony_status"))
	_hub_card(hub, "Armory", "Weapons the colony can field, and what unlocks the rest",
			func(): _show_overlay_panel("equipment"))
	var enemies: Array = _campaign.tactical_enemies if "tactical_enemies" in _campaign else []
	var signs: Array = _campaign.ancient_signs if "ancient_signs" in _campaign else []
	_hub_card(hub, "Enemy Tracker", "%d tactical enemies | %d ancient signs" % [
			enemies.size(), signs.size()], func(): _show_overlay_panel("enemy_tracker"))
	var aug_count: int = _campaign.get_augmentation_count() \
		if _campaign.has_method("get_augmentation_count") else 0
	var aug_ap: int = _campaign.augmentation_points if "augmentation_points" in _campaign else 0
	_hub_card(hub, "Augmentations", "%d owned | %d AP available" % [aug_count, aug_ap],
			func(): _show_overlay_panel("augmentation"))
	var ms_count: int = _campaign.milestones_completed \
		if "milestones_completed" in _campaign else 0
	_hub_card(hub, "Milestones & Progression", "%d / 7 completed" % ms_count,
			func(): _show_overlay_panel("milestones"))
	var active_calamities: Array = []
	if "active_calamities" in _campaign:
		for cal in _campaign.active_calamities:
			if cal is Dictionary and not cal.get("resolved", false):
				active_calamities.append(cal)
	if not active_calamities.is_empty():
		_hub_card(hub, "Active Calamities", "%d calamit%s" % [active_calamities.size(),
				"y" if active_calamities.size() == 1 else "ies"],
				func(): _show_overlay_panel("calamities"))
	# Character transfer (Planetfall pp.26-29 import, pp.165-166 export)
	_hub_card(hub, "Import Veterans", "Bring a 5PFH or Bug Hunt veteran into the colony",
			_on_import_pressed)
	_hub_card(hub, "Muster Colonists Out", "Send a colonist to a 5PFH or Bug Hunt campaign",
			_on_muster_out_pressed)
	_hub_card(hub, "Save Campaign", "Save current progress to disk", _on_save)
	_hub_card(hub, "Main Menu", "Return to the main menu", func(): _navigate("main_menu"))


func _hub_card(parent: Control, title: String, desc: String, handler: Callable) -> void:
	var card := HubFeatureCardClass.new()
	card.setup("", title, desc)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.card_pressed.connect(handler)
	parent.add_child(card)


func _build_roster_section(roster: Array) -> void:
	_content.add_child(_create_section_header("COLONY ROSTER (%d)" % roster.size()))
	var grid := GridContainer.new()
	grid.columns = 1 if _built_narrow else 2
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_SM)
	_content.add_child(grid)
	for char_dict in roster:
		if char_dict is Dictionary:
			grid.add_child(_build_character_card(char_dict))
	_content.add_child(_line("Plus %d grunts and the colony bot (pp.16-17)." % (
			int(_campaign.grunts) if "grunts" in _campaign else 0), COLOR_TEXT_SECONDARY))


## A character as the Colony Tracking Sheet records them (p.24): class and sub-species,
## loyalty, the full profile, XP and Kill Points, Sick Bay, and the backgrounds rolled at
## creation with the Prior Experience bonus named, so a raised score explains itself.
func _build_character_card(char_dict: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(panel, "elevated")
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var name_lbl := _line(str(char_dict.get("name", "Unknown")), COLOR_TEXT_PRIMARY,
			FONT_SIZE_MD)
	vbox.add_child(name_lbl)

	var pill_row := HFlowContainer.new()
	pill_row.add_theme_constant_override("h_separation", SPACING_XS)
	pill_row.add_theme_constant_override("v_separation", SPACING_XS)
	pill_row.add_child(_create_class_pill(char_dict.get("class", "")))
	var kind: String = str(RosterRules.subspecies_data().get(
			str(char_dict.get("subspecies", "")), {}).get("name", ""))
	if kind != "":
		pill_row.add_child(_create_pill(kind, COLOR_TEXT_SECONDARY))
	pill_row.add_child(_create_loyalty_pill(char_dict.get("loyalty", "committed")))
	if char_dict.get("is_imported", false):
		pill_row.add_child(_create_pill("Imported", UIColors.COLOR_PURPLE))
	var cid: String = str(char_dict.get("id", ""))
	var sick: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	if int(sick.get(cid, 0)) > 0:
		pill_row.add_child(_create_pill("Sick Bay: %d turn%s" % [int(sick[cid]),
				"" if int(sick[cid]) == 1 else "s"], UIColors.COLOR_AMBER))
	vbox.add_child(pill_row)

	var profile: String = RosterRules.profile_line(char_dict)
	profile += " · %d XP · %d KP" % [int(char_dict.get("xp", 0)), int(char_dict.get("kp", 0))]
	vbox.add_child(_line(profile, COLOR_CYAN, FONT_SIZE_SM))

	var bg_parts: Array = []
	if str(char_dict.get("motivation", "")) != "":
		bg_parts.append("Motivation: %s" % str(char_dict.motivation))
	var prior: String = str(char_dict.get("prior_experience", ""))
	if prior != "":
		var bonus: String = BackgroundsScript.bonus_text_for(prior)
		bg_parts.append("Prior Experience: %s%s" % [prior,
				(" (%s)" % bonus) if bonus != "" else ""])
	if str(char_dict.get("notable_event", "")) != "":
		bg_parts.append("Notable Event: %s" % str(char_dict.notable_event))
	if not bg_parts.is_empty():
		vbox.add_child(_line(". ".join(PackedStringArray(bg_parts)) + ".",
				COLOR_TEXT_SECONDARY, FONT_SIZE_SM))
	return panel


func _line(text: String, color: Color, size: int = FONT_SIZE_SM) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _show_overlay_panel(panel_type: String) -> void:
	## Show a detail panel as an overlay on top of the dashboard.
	if not _overlay_container or not is_instance_valid(_overlay_frame):
		return
	# Clear existing overlay
	for child in _overlay_frame.get_children():
		_overlay_frame.remove_child(child)
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
	# An overlay that changes the campaign (the 4th Milestone's condition replacement)
	# says so, and the dashboard saves it at once so a force-stop cannot undo it.
	if panel.has_signal("campaign_changed"):
		panel.campaign_changed.connect(_on_save)
	_overlay_frame.add_child(panel)
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
