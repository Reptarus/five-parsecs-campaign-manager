extends BugHuntScreenBase

## Bug Hunt Dashboard — Campaign overview screen.
## Uses CampaignScreenBase factory methods for glass cards, stat displays,
## character cards, and responsive layout.

const EmptyStateWidgetClass = preload("res://src/ui/components/common/EmptyStateWidget.gd")
const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")
const TransferPanelClass = preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")

var _campaign: Resource
var _content: VBoxContainer
var _play_btn: Control  # HubFeatureCard (extends Control, not Button)


func _setup_screen() -> void:
	_campaign = _get_bug_hunt_campaign()
	_build_dashboard()


func _build_dashboard() -> void:
	var layout := _create_scroll_layout()
	_content = layout.content

	if not _campaign or not "main_characters" in _campaign:
		var empty := EmptyStateWidgetClass.new()
		empty.setup(
			"No Active Bug Hunt",
			"The barracks are quiet. Create a new campaign to deploy your squad.",
			"New Bug Hunt",
			func(): _navigate("bug_hunt_creation"))
		_content.add_child(empty)
		return

	# ── Header ──────────────────────────────────────────────────────
	var name_str: String = _campaign.campaign_name if "campaign_name" in _campaign else "Unknown"
	var regiment: String = _campaign.regiment_name if "regiment_name" in _campaign else ""

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", SPACING_XS)

	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL + 4))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title)

	if not regiment.is_empty():
		var reg_lbl := Label.new()
		reg_lbl.text = regiment
		reg_lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_LG))
		reg_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		reg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_box.add_child(reg_lbl)

	_content.add_child(header_box)

	# ── Stat Strip ──────────────────────────────────────────────────
	var turn: int = _campaign.campaign_turn if "campaign_turn" in _campaign else 0
	var rep: int = _campaign.reputation if "reputation" in _campaign else 0
	var chars: Array = _campaign.main_characters if "main_characters" in _campaign else []
	var grunts: Array = _campaign.grunts if "grunts" in _campaign else []
	var movie_remaining: int = 0
	if _campaign.has_method("get_available_movie_magic"):
		movie_remaining = _campaign.get_available_movie_magic().size()

	var stats := {"TURN": turn, "REP": rep, "MCs": chars.size(), "GRUNTS": grunts.size(), "MAGIC": movie_remaining}
	var stat_grid := _create_stats_grid(stats, mini(stats.size(), 5))
	_content.add_child(stat_grid)

	# ── Navigation Hub Cards ────────────────────────────────────────
	var hub_box := VBoxContainer.new()
	hub_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(hub_box)

	var continue_card := HubFeatureCardClass.new()
	continue_card.setup("", "Continue Campaign", "Start the next campaign turn")
	continue_card.card_pressed.connect(func(): _navigate("bug_hunt_turn_controller"))
	hub_box.add_child(continue_card)
	_play_btn = continue_card  # Reference for breathe animation

	var save_card := HubFeatureCardClass.new()
	save_card.setup("", "Save Campaign", "Save current progress to disk")
	save_card.card_pressed.connect(_on_save)
	hub_box.add_child(save_card)

	var menu_card := HubFeatureCardClass.new()
	menu_card.setup("", "Main Menu", "Return to the main menu")
	menu_card.card_pressed.connect(func(): _navigate("main_menu"))
	hub_box.add_child(menu_card)

	# ── Character Transfer (Compendium pp.212-213) ──────────────────
	var transfer_box := VBoxContainer.new()
	transfer_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(transfer_box)

	var enlist_card := HubFeatureCardClass.new()
	enlist_card.setup("", "Enlist from 5PFH", "Transfer a Five Parsecs character into Bug Hunt (2D6+CS >= 7+)")
	enlist_card.card_pressed.connect(_on_enlist_pressed)
	transfer_box.add_child(enlist_card)

	var muster_card := HubFeatureCardClass.new()
	muster_card.setup("", "Muster Out to 5PFH", "Transfer a Bug Hunt character to a Five Parsecs campaign")
	muster_card.card_pressed.connect(_on_muster_out_pressed)
	transfer_box.add_child(muster_card)

	# ── Squad Roster ────────────────────────────────────────────────
	var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	var roster_content := VBoxContainer.new()
	roster_content.add_theme_constant_override("separation", SPACING_SM)

	for mc in chars:
		if mc is not Dictionary:
			continue
		var mc_name: String = mc.get("name", mc.get("character_name", "?"))
		var mc_stats := {
			"R": int(mc.get("reactions", 0)),
			"S": int(mc.get("speed", 0)),
			"CS": int(mc.get("combat_skill", 0)),
			"T": int(mc.get("toughness", 0)),
			"Sv": int(mc.get("savvy", 0))
		}
		var missions: int = mc.get("completed_missions_count", 0)
		var subtitle: String = "XP: %d | Service Record: %d mission%s" % [
			mc.get("xp", 0), missions, "" if missions == 1 else "s"]
		var char_id: String = mc.get("id", mc.get("character_id", ""))
		if sick_bay.has(char_id):
			subtitle += " | SICK BAY (%d turns)" % sick_bay.get(char_id, 1)

		var card := _create_character_card(mc_name, subtitle, mc_stats)
		roster_content.add_child(card)

	var roster_section := _create_section_card("Squad Roster", roster_content, "%d main characters" % chars.size())
	_content.add_child(roster_section)

	# ── Grunt Pool ──────────────────────────────────────────────────
	var grunt_content := VBoxContainer.new()
	if grunts.is_empty():
		var no_lbl := Label.new()
		no_lbl.text = "No grunts in pool"
		no_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		grunt_content.add_child(no_lbl)
	else:
		grunt_content.add_child(_create_info_row("Grunts Available", str(grunts.size()), COLOR_CYAN))
		grunt_content.add_child(_create_info_row("Profile", "R:1 S:4 CS:0 T:4", COLOR_TEXT_SECONDARY))
	var grunt_section := _create_section_card("Grunt Pool", grunt_content)
	_content.add_child(grunt_section)

	# ── Movie Magic ─────────────────────────────────────────────────
	var movie_content := VBoxContainer.new()
	movie_content.add_theme_constant_override("separation", SPACING_XS)
	var used: Dictionary = _campaign.movie_magic_used if "movie_magic_used" in _campaign else {}
	var all_magic := [
		["barricade", "Barricade"], ["double_up", "Double-Up"], ["escape", "Escape"],
		["evac", "Evac"], ["extra_support", "Extra Support"], ["lucky_find", "Lucky Find"],
		["reinforcements", "Reinforcements"], ["remove_contact", "Remove Contact"],
		["survived", "Survived"], ["you_want_some_too", "You Want Some Too?"]]
	for pair in all_magic:
		var ability_id: String = pair[0]
		var ability_name: String = pair[1]
		var is_used: bool = used.get(ability_id, false)
		var color: Color = COLOR_TEXT_MUTED if is_used else COLOR_SUCCESS
		var prefix: String = "[USED]" if is_used else "[READY]"
		movie_content.add_child(_create_info_row(ability_name, prefix, color))
	var movie_section := _create_section_card("Movie Magic", movie_content, "%d remaining" % movie_remaining)
	_content.add_child(movie_section)

	# ── Stagger fade-in ─────────────────────────────────────────────
	_stagger_reveal()

	# ── Breathe animation on Continue card ──────────────────────────
	if is_instance_valid(_play_btn):
		_play_btn.pivot_offset = _play_btn.size / 2
		TweenFX.breathe(_play_btn, 3.0, 0.03)


func _stagger_reveal() -> void:
	var children := _content.get_children()
	for child in children:
		if child is Control:
			child.modulate.a = 0.0
	for i in children.size():
		if children[i] is Control:
			if i > 0:
				await get_tree().create_timer(0.04).timeout
			TweenFX.fade_in(children[i], 0.2)


func _exit_tree() -> void:
	if _play_btn and is_instance_valid(_play_btn):
		TweenFX.stop_all(_play_btn)


func _navigate(route: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to(route)


func _on_save() -> void:
	if not _campaign:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(_campaign)
	elif _campaign.has_method("save_to_file") and _campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + _campaign.get_campaign_id() + ".save"
		_campaign.save_to_file(path)


func _on_enlist_pressed() -> void:
	## Show CharacterTransferPanel in enlist mode (5PFH → Bug Hunt).
	## Player picks a character from a standard campaign save to transfer in.
	var panel := TransferPanelClass.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_direction("enlist")
	panel.character_transferred.connect(
		func(char_data: Dictionary, _dir: String):
			_apply_enlistment(char_data)
			panel.queue_free()
	)
	add_child(panel)

	# Load standard campaign saves for character selection
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_available_campaigns"):
		var campaigns: Array = gs.get_available_campaigns()
		for info in campaigns:
			var path: String = info.get("path", "")
			# Only show standard (non-Bug Hunt) saves
			if info.get("type", "") != "bug_hunt" and not path.is_empty():
				panel.load_characters_from_save(path)
				break  # Load first standard save found


func _apply_enlistment(char_data: Dictionary) -> void:
	## Add transferred character to Bug Hunt campaign (with deep copy).
	if not _campaign or not "main_characters" in _campaign:
		return
	var safe_copy: Dictionary = char_data.duplicate(true)
	_campaign.main_characters.append(safe_copy)
	# Save immediately to persist the transfer
	_on_save()
	# Rebuild dashboard to show new character
	for child in get_children():
		child.queue_free()
	_build_dashboard()


func _on_muster_out_pressed() -> void:
	## Show CharacterTransferPanel in muster-out mode (Bug Hunt → 5PFH).
	var panel := TransferPanelClass.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_direction("muster_out")
	panel.character_transferred.connect(
		func(char_data: Dictionary, _dir: String):
			_apply_muster_out(char_data)
			panel.queue_free()
	)
	add_child(panel)

	# Load Bug Hunt characters for selection
	if _campaign and "main_characters" in _campaign:
		panel.load_characters_from_array(_campaign.main_characters)


func _apply_muster_out(char_data: Dictionary) -> void:
	## Save transferred character as pending transfer file for standard campaign pickup.
	## Remove from Bug Hunt squad. Deep copy to prevent shared references.
	if not _campaign or not "main_characters" in _campaign:
		return

	var safe_copy: Dictionary = char_data.duplicate(true)
	var char_id: String = safe_copy.get("id", safe_copy.get("character_id", ""))

	# Save pending transfer to user://transfers/
	var transfer_dir := "user://transfers/"
	if not DirAccess.dir_exists_absolute(transfer_dir):
		DirAccess.make_dir_recursive_absolute(transfer_dir)
	var timestamp := str(Time.get_unix_time_from_system())
	var filename := "transfer_%s_%s.json" % [char_id, timestamp]
	var transfer_data := {
		"schema_version": 1,
		"direction": "muster_out",
		"character": safe_copy,
		"mustering_credits": safe_copy.get("mustering_credits", 0),
		"bonus_story_points": safe_copy.get("bonus_story_points", 1),
		"add_sector_government_patron": true,
		"source_campaign_id": _campaign.campaign_id if "campaign_id" in _campaign else "",
		"source_campaign_name": _campaign.campaign_name if "campaign_name" in _campaign else "",
		"transferred_at": Time.get_datetime_string_from_system()
	}

	# Atomic write: temp file + rename
	var temp_path := transfer_dir + filename + ".tmp"
	var final_path := transfer_dir + filename
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(transfer_data, "\t"))
		file.close()
		DirAccess.rename_absolute(temp_path, final_path)

	# Remove character from Bug Hunt squad
	var idx_to_remove := -1
	for i in range(_campaign.main_characters.size()):
		var mc = _campaign.main_characters[i]
		if mc is Dictionary:
			var mc_id: String = mc.get("id", mc.get("character_id", ""))
			if mc_id == char_id:
				idx_to_remove = i
				break
	if idx_to_remove >= 0:
		_campaign.main_characters.remove_at(idx_to_remove)

	_on_save()
	# Rebuild dashboard
	for child in get_children():
		child.queue_free()
	_build_dashboard()
