class_name PlanetfallPostBattlePanel
extends Control

## Combined panel for Steps 9-12: Injuries, Experience, Morale, Post-Mission
## Finds, and Enemy Info tracking.
## The TurnController maps phases 8-11 to this single panel.
## Internally tracks which sub-step is active and shows the appropriate section.
## Source: Planetfall pp.66-68, 134-136

signal phase_completed(result_data: Dictionary)

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")
const PlanetfallPostMissionScript := preload(
	"res://src/core/systems/PlanetfallPostMissionSystem.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

enum SubStep { INJURIES, EXPERIENCE, MORALE, POST_MISSION_FINDS, ENEMY_INFO }

var _campaign: Resource
var _phase_manager: Node
var _resolver: PlanetfallEventResolverScript
var _post_mission: PlanetfallPostMissionScript
var _current_sub_step: int = SubStep.INJURIES
var _battle_results: Dictionary = {}
var _casualties_count: int = 0
var _grunt_losses: int = 0
var _xp_awarded: bool = false
var _finds_rolled: Array = []

var _title_label: Label
var _section_label: Label
var _content_vbox: VBoxContainer
var _result_container: VBoxContainer
var _action_btn: Button
var _continue_btn: Button


func _ready() -> void:
	_resolver = PlanetfallEventResolverScript.new()
	_post_mission = PlanetfallPostMissionScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func set_battle_results(results: Dictionary) -> void:
	## Called by TurnController before refresh when resuming after battle.
	_battle_results = results


func refresh() -> void:
	## Determine which sub-step to show based on the phase manager's current phase.
	if _phase_manager:
		var phase: int = _phase_manager.current_phase
		# Phase enum values: INJURIES=8, EXPERIENCE=9, MORALE_ADJUSTMENTS=10, TRACK_ENEMY_INFO=11
		if phase == 9:
			_current_sub_step = SubStep.EXPERIENCE
		elif phase == 10:
			_current_sub_step = SubStep.MORALE
		elif phase == 11:
			# Step 12 maps to both FINDS and ENEMY_INFO — show FINDS first
			_current_sub_step = SubStep.POST_MISSION_FINDS
		else:
			_current_sub_step = SubStep.INJURIES

	_clear_container(_content_vbox)
	_clear_container(_result_container)

	match _current_sub_step:
		SubStep.INJURIES:
			_title_label.text = "POST-BATTLE — INJURIES"
			_section_label.text = "Step 9: Roll for injuries on each casualty"
			_action_btn.text = "Roll Injuries"
		SubStep.EXPERIENCE:
			_title_label.text = "POST-BATTLE — EXPERIENCE"
			_section_label.text = "Step 10: Award XP to participating characters"
			_action_btn.text = "Award XP"
		SubStep.MORALE:
			_title_label.text = "POST-BATTLE — MORALE"
			_section_label.text = "Step 11: Calculate colony morale adjustments"
			_action_btn.text = "Calculate Morale"
		SubStep.POST_MISSION_FINDS:
			_title_label.text = "POST-BATTLE — MISSION FINDS"
			_section_label.text = "Step 12a: Roll for Post-Mission Finds"
			_action_btn.text = "Roll Finds"
		SubStep.ENEMY_INFO:
			_title_label.text = "POST-BATTLE — ENEMY INFO"
			_section_label.text = "Step 12b: Track Enemy Information & Mission Data"
			_action_btn.text = "Process Intel"

	_build_sub_step_info()
	_action_btn.visible = true
	_action_btn.disabled = false
	_continue_btn.visible = false


func complete() -> void:
	if _action_btn.visible and not _action_btn.disabled:
		_on_action_pressed()
	else:
		_on_continue_pressed()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "POST-BATTLE"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_section_label = Label.new()
	_section_label.text = ""
	_section_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_section_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_section_label)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content_vbox)

	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_result_container)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(btn_box)

	_action_btn = Button.new()
	_action_btn.text = "Roll Injuries"
	_action_btn.custom_minimum_size = Vector2(200, 48)
	_action_btn.pressed.connect(_on_action_pressed)
	btn_box.add_child(_action_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = false
	btn_box.add_child(_continue_btn)


## ============================================================================
## SUB-STEP INFO DISPLAY
## ============================================================================

func _build_sub_step_info() -> void:
	match _current_sub_step:
		SubStep.INJURIES:
			var casualties: Array = _battle_results.get("casualties", [])
			var grunt_casualties: int = _battle_results.get("grunt_casualties", 0)
			_add_info_text("Character casualties to process: %d" % casualties.size())
			_add_info_text("Grunt casualties to process: %d" % grunt_casualties)
			if casualties.is_empty() and grunt_casualties == 0:
				_add_info_text(
					"\n[color=#10B981]No casualties this battle![/color]")

		SubStep.EXPERIENCE:
			var participants: Array = _battle_results.get("participants", [])
			_add_info_text("Characters who participated: %d" % participants.size())
			_add_info_text(
				"XP Awards: +1 for participating, +1 if not a casualty, +1 for killing a Boss/Leader")

		SubStep.MORALE:
			_add_info_text("Automatic: -1 Colony Morale per turn")
			_add_info_text("Additional: -1 per battle casualty (%d)" % _casualties_count)
			_add_info_text(
				"If Colony Morale reaches -10 or worse, roll on the Morale Incident table.")

		SubStep.POST_MISSION_FINDS:
			var find_rolls: int = _battle_results.get("find_rolls", 0)
			var won: bool = _battle_results.get("won", false)
			var mission_id: String = _battle_results.get("mission_id", "")
			_add_info_text("Mission: %s" % mission_id.replace("_", " ").capitalize())
			_add_info_text("Post-Mission Find rolls earned: %d" % find_rolls)
			if not won:
				_add_info_text("[color=#D97706]Mission not won — no Find rolls.[/color]")
			var has_scientist: bool = _battle_results.get("has_scientist_standing", false)
			var has_scout: bool = _battle_results.get("has_scout_standing", false)
			if has_scientist:
				_add_info_text("[color=#10B981]Scientist on feet — bonus available[/color]")
			if has_scout:
				_add_info_text("[color=#10B981]Scout on feet — bonus available[/color]")

		SubStep.ENEMY_INFO:
			var mission_id: String = _battle_results.get("mission_id", "")
			var won: bool = _battle_results.get("won", false)
			var enemy_fought: String = _battle_results.get("enemy_type", "")
			if not enemy_fought.is_empty():
				_add_info_text("Enemy fought: %s" % enemy_fought)
			if won:
				_add_info_text("Victory: +1 Enemy Information (if Tactical Enemy)")
			var md_gained: int = _battle_results.get("mission_data_gained", 0)
			if md_gained > 0:
				_add_info_text("Mission Data gained: %d" % md_gained)


## ============================================================================
## ACTION HANDLERS
## ============================================================================

func _on_action_pressed() -> void:
	_action_btn.disabled = true

	match _current_sub_step:
		SubStep.INJURIES:
			_resolve_injuries()
		SubStep.EXPERIENCE:
			_resolve_experience()
		SubStep.MORALE:
			_resolve_morale()
		SubStep.POST_MISSION_FINDS:
			_resolve_post_mission_finds()
		SubStep.ENEMY_INFO:
			_resolve_enemy_info()

	_continue_btn.visible = true
	_continue_btn.disabled = false


func _on_continue_pressed() -> void:
	_continue_btn.disabled = true

	# POST_MISSION_FINDS transitions to ENEMY_INFO instead of emitting
	if _current_sub_step == SubStep.POST_MISSION_FINDS:
		_current_sub_step = SubStep.ENEMY_INFO
		_clear_container(_content_vbox)
		_clear_container(_result_container)
		_title_label.text = "POST-BATTLE — ENEMY INFO"
		_section_label.text = "Step 12b: Track Enemy Information & Mission Data"
		_action_btn.text = "Process Intel"
		_build_sub_step_info()
		_action_btn.visible = true
		_action_btn.disabled = false
		_continue_btn.visible = false
		return

	var result_data: Dictionary = {}

	match _current_sub_step:
		SubStep.INJURIES:
			result_data = {
				"casualties_count": _casualties_count,
				"grunt_losses": _grunt_losses
			}
		SubStep.EXPERIENCE:
			result_data = {"xp_awarded": _xp_awarded}
		SubStep.MORALE:
			result_data = {
				"casualties_count": _casualties_count,
				"colony_damage": 0
			}
		SubStep.ENEMY_INFO:
			result_data = {
				"finds": _finds_rolled,
				"enemy_info_processed": true
			}

	phase_completed.emit(result_data)


## ============================================================================
## INJURY RESOLUTION (Step 9)
## ============================================================================

func _resolve_injuries() -> void:
	## Planetfall p.66 — D100 per character casualty, D6 per grunt casualty.
	_casualties_count = 0
	_grunt_losses = 0

	# Character injuries
	var casualties: Array = _battle_results.get("casualties", [])
	if casualties.is_empty():
		_add_result_bbcode("No character casualties to process.")
	else:
		for casualty_id in casualties:
			var char_name: String = _get_character_name(str(casualty_id))
			var roll: int = _resolver.roll_d100()
			var result: Dictionary = _resolver.resolve_injury(roll)
			var injury_name: String = result.get("name", "Unknown")
			var sick_turns: int = result.get("sick_bay_turns", 0)
			var is_dead: bool = result.get("permanent", false)

			_add_result_bbcode(
				"[b]%s[/b] — D100: %d → %s" % [char_name, roll, injury_name])

			if is_dead:
				_add_result_bbcode(
					"  [color=#DC2626]%s is dead.[/color]" % char_name)
				_casualties_count += 1
			elif sick_turns > 0:
				if _campaign and _campaign.has_method("add_to_sick_bay"):
					_campaign.add_to_sick_bay(str(casualty_id), sick_turns)
				_add_result_bbcode(
					"  [color=#D97706]%s → Sick Bay for %d turn(s)[/color]" % [
						char_name, sick_turns])
				_casualties_count += 1
			else:
				_add_result_bbcode(
					"  [color=#10B981]%s is okay.[/color]" % char_name)
				var bonus_xp: int = result.get("bonus_xp", 0)
				if bonus_xp > 0:
					_add_result_bbcode(
						"  [color=#10B981]+%d XP (School of Hard Knocks)[/color]" % bonus_xp)
					_apply_xp_to_character(str(casualty_id), bonus_xp)

	# Grunt casualties
	var grunt_casualties: int = _battle_results.get("grunt_casualties", 0)
	if grunt_casualties > 0:
		_add_result_bbcode("\n[b]Grunt Casualties:[/b]")
		for i in range(grunt_casualties):
			var roll: int = _resolver.roll_d6()
			var result: Dictionary = _resolver.resolve_grunt_casualty(roll)
			if result.get("permanent", false):
				_grunt_losses += 1
				_add_result_bbcode(
					"  Grunt %d — D6: %d → [color=#DC2626]Permanent casualty[/color]" % [
						i + 1, roll])
			else:
				_add_result_bbcode(
					"  Grunt %d — D6: %d → [color=#10B981]Okay[/color]" % [i + 1, roll])

		if _grunt_losses > 0:
			_add_result_bbcode(
				"\n[color=#DC2626]%d grunt(s) permanently lost.[/color]" % _grunt_losses)
			_casualties_count += _grunt_losses
	elif grunt_casualties == 0:
		_add_result_bbcode("\nNo grunt casualties.")


## ============================================================================
## EXPERIENCE RESOLUTION (Step 10)
## ============================================================================

func _resolve_experience() -> void:
	## Planetfall p.67 — XP awards per participant.
	var participants: Array = _battle_results.get("participants", [])
	var casualties_list: Array = _battle_results.get("casualties", [])
	var boss_killers: Array = _battle_results.get("boss_killers", [])

	if participants.is_empty():
		_add_result_bbcode("No participants to award XP.")
		_xp_awarded = true
		return

	_add_result_bbcode("[b]XP Awards:[/b]")
	for pid in participants:
		var char_name: String = _get_character_name(str(pid))
		var xp: int = 1  # Participated
		var reasons: Array[String] = ["+1 participated"]

		if not casualties_list.has(pid):
			xp += 1
			reasons.append("+1 not a casualty")

		if boss_killers.has(pid):
			xp += 1
			reasons.append("+1 killed Boss/Leader")

		_apply_xp_to_character(str(pid), xp)
		_add_result_bbcode(
			"  %s: +%d XP (%s)" % [char_name, xp, ", ".join(reasons)])

	_xp_awarded = true
	_add_result_bbcode(
		"\n[color=#10B981]XP awarded to %d character(s).[/color]" % participants.size())


## ============================================================================
## MORALE RESOLUTION (Step 11)
## ============================================================================

func _resolve_morale() -> void:
	## Planetfall p.68 — automatic morale adjustments.
	if not _campaign:
		_add_result_bbcode("No campaign data.")
		return

	var base: int = -1  # Automatic per turn
	var casualty_penalty: int = -_casualties_count
	var total: int = base + casualty_penalty

	_add_result_bbcode("[b]Colony Morale Adjustments:[/b]")
	_add_result_bbcode("  Automatic per turn: -1")
	if _casualties_count > 0:
		_add_result_bbcode("  Casualties (%d): %d" % [_casualties_count, casualty_penalty])
	_add_result_bbcode(
		"\n[b]Total Change: %+d[/b]" % total)

	if _campaign.has_method("apply_morale_adjustments"):
		_campaign.apply_morale_adjustments(_casualties_count, 0)

	var new_morale: int = _campaign.colony_morale if "colony_morale" in _campaign else 0
	_add_result_bbcode("Colony Morale is now: %d" % new_morale)

	if new_morale <= -10:
		_add_result_bbcode(
			"\n[color=#DC2626]WARNING: Morale is -10 or worse! " +
			"Roll on the Morale Incident table (Planetfall p.90).[/color]")


## ============================================================================
## POST-MISSION FINDS RESOLUTION (Step 12a)
## ============================================================================

func _resolve_post_mission_finds() -> void:
	## Planetfall p.134 — roll on Finds table per earned roll.
	_finds_rolled = []
	var find_rolls: int = _battle_results.get("find_rolls", 0)
	var won: bool = _battle_results.get("won", false)

	if not won or find_rolls <= 0:
		_add_result_bbcode("No Post-Mission Finds to roll.")
		return

	var has_scientist: bool = _battle_results.get("has_scientist_standing", false)
	var has_scout: bool = _battle_results.get("has_scout_standing", false)

	_add_result_bbcode("[b]Post-Mission Finds (%d roll%s):[/b]" % [
		find_rolls, "s" if find_rolls != 1 else ""])

	for i in range(find_rolls):
		var roll: int = _post_mission.roll_d100()
		var find: Dictionary = _post_mission.roll_find_with_bonuses(
			roll, has_scientist, has_scout)

		if find.is_empty():
			_add_result_bbcode("  Roll %d: D100=%d → Nothing found" % [i + 1, roll])
			continue

		var find_name: String = find.get("name", "Unknown")
		var reward: Dictionary = find.get("reward", {})
		var reward_parts: Array = []

		for key in reward:
			if key == "character_xp":
				reward_parts.append("+%d XP (pick 1 character)" % reward[key])
			else:
				reward_parts.append("+%d %s" % [reward[key], key.replace("_", " ")])

		_add_result_bbcode("  Roll %d: D100=%d → [b]%s[/b]" % [i + 1, roll, find_name])
		if not reward_parts.is_empty():
			_add_result_bbcode("    Reward: %s" % ", ".join(reward_parts))

		# Show bonuses
		for bonus_entry in find.get("applied_bonuses", []):
			var source: String = bonus_entry.get("source", "")
			var bonus: Dictionary = bonus_entry.get("bonus", {})
			var bonus_parts: Array = []
			for bkey in bonus:
				bonus_parts.append("+%d %s" % [bonus[bkey], bkey.replace("_", " ")])
			_add_result_bbcode(
				"    [color=#10B981]%s bonus: %s[/color]" % [
					source.capitalize(), ", ".join(bonus_parts)])

		# Apply to campaign
		if _campaign:
			_post_mission.apply_find_to_campaign(_campaign, find)

		_finds_rolled.append(find)

	_add_result_bbcode(
		"\n[color=#10B981]%d find(s) processed and applied.[/color]" % _finds_rolled.size())


## ============================================================================
## ENEMY INFO RESOLUTION (Step 12b)
## ============================================================================

func _resolve_enemy_info() -> void:
	## Planetfall p.68 — track Enemy Information and Mission Data.
	var won: bool = _battle_results.get("won", false)
	var enemy_index: int = _battle_results.get("tactical_enemy_index", -1)
	var md_gained: int = _battle_results.get("mission_data_gained", 0)

	_add_result_bbcode("[b]Intelligence Report:[/b]")

	# Enemy Information
	if won and enemy_index >= 0 and _campaign:
		var status: Dictionary = _post_mission.process_enemy_info_gain(
			_campaign, enemy_index, 1)
		var total: int = status.get("total_info", 0)
		_add_result_bbcode(
			"  +1 Enemy Information (total: %d)" % total)

		if status.get("boss_located", false):
			_add_result_bbcode(
				"  [color=#D97706]Boss location identified! Strike Mission now available.[/color]")
	elif won:
		_add_result_bbcode("  No Tactical Enemy fought — no Enemy Information gained.")
	else:
		_add_result_bbcode("  Mission not won — no Enemy Information gained.")

	# Mission Data
	if md_gained > 0 and _campaign:
		if _campaign.has_method("add_mission_data_points"):
			_campaign.add_mission_data_points(md_gained)
		_add_result_bbcode(
			"\n  +%d Mission Data (total: %d)" % [
				md_gained,
				_campaign.mission_data if "mission_data" in _campaign else 0])


## ============================================================================
## HELPERS
## ============================================================================

func _get_character_name(character_id: String) -> String:
	if not _campaign or not "roster" in _campaign:
		return character_id
	for char_dict in _campaign.roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				return char_dict.get("name", character_id)
	return character_id


func _apply_xp_to_character(character_id: String, xp: int) -> void:
	if not _campaign or not "roster" in _campaign:
		return
	for char_dict in _campaign.roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				char_dict["xp"] = char_dict.get("xp", 0) + xp
				break


func _add_info_text(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
