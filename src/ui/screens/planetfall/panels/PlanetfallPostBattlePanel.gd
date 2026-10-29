class_name PlanetfallPostBattlePanel
extends Control

## Combined panel for Steps 9-12: Injuries, Experience, Morale, Post-Mission
## Finds, and Enemy Info tracking.
## The TurnController maps phases 8-11 to this single panel.
## Internally tracks which sub-step is active and shows the appropriate section.
## Source: Planetfall pp.66-68, 134-136

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's one completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")
const PlanetfallPostMissionScript := preload(
	"res://src/core/systems/PlanetfallPostMissionSystem.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")
const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const CalamityScript := preload("res://src/core/systems/PlanetfallCalamitySystem.gd")
const RewardsScript := preload("res://src/core/systems/PlanetfallMissionRewards.gd")
## Each mission's own reward text, shown beside the Find-roll count it governs.
const MISSION_TYPES_PATH := "res://data/planetfall/mission_types.json"

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED

## p.67 Mission XP table. Step 10's preview and its award both read it; the preview used
## to restate the table as a literal beside a second hand-copied copy in the award.
const MISSION_XP := {
	"participated": {"xp": 1, "label": "participated in the battle"},
	"not_a_casualty": {"xp": 1, "label": "did not become a casualty"},
	"boss_or_leader": {"xp": 1, "label": "directly killed an enemy Boss or Leader (once per battle)"},
}
## p.127 Pitched Battle Rewards: "If you win ... each survivor receives 1 additional XP."
const PITCHED_SURVIVOR_XP := 1
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const ReceiptCardRef := preload("res://src/ui/components/common/ReceiptCard.gd")
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
var _xp_awarded: bool = false
## Step 9 debrief controls (pp.66-68, 134): what only the table knows.
var _grunt_spin: SpinBox
var _colonist_spin: SpinBox
var _find_spin: SpinBox
var _md_spin: SpinBox
var _objective_spin: SpinBox
## pp.165-168: the Calamity questions this mission asks, {answer key: SpinBox|CheckBox}.
var _calamity_inputs: Dictionary = {}
## Spins for the mission's own rewards (PlanetfallMissionRewards.DEBRIEF_ASKS).
var _mission_inputs: Dictionary = {}
var _coward_checks: Dictionary = {}
var _boss_checks: Dictionary = {}
## Every result line this sub-step printed, recorded as its receipt (Steps 10, 12).
var _receipt_lines: Array = []
var _scroll: ScrollContainer
var _mission_types: Array = []
var _finds_rolled: Array = []
## Step 11 choices made before the roll, and the Protests pick made after it (p.90).
var _appeals_check: CheckBox
var _reroll_check: CheckBox
var _supervisor_checks: Dictionary = {}
var _protest_picker: OptionButton
var _protest_ids: Array = []

var _title_label: Label
var _section_label: Label
var _content_vbox: VBoxContainer
var _result_container: VBoxContainer
var _action_btn: Button
var _can_continue: bool = false


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
	## Determine which sub-step to show based on the phase manager's phase name.
	## Uses phase name strings to avoid hardcoding enum ordinals.
	if _phase_manager and _phase_manager.has_method("get_phase_name"):
		var name: String = _phase_manager.get_phase_name()
		if name == "Experience Progression":
			_current_sub_step = SubStep.EXPERIENCE
		elif name == "Colony Morale Adjustments":
			_current_sub_step = SubStep.MORALE
		else:
			_current_sub_step = SubStep.INJURIES

	_clear_container(_content_vbox)
	_clear_container(_result_container)

	match _current_sub_step:
		SubStep.INJURIES:
			_title_label.text = "STEP 9: INJURIES"
			_section_label.text = "Roll for injuries on each casualty."
			_action_btn.text = "Roll Injuries"
		SubStep.EXPERIENCE:
			_title_label.text = "STEP 10: EXPERIENCE PROGRESSION"
			_section_label.text = "Award XP to the characters who took part."
			_action_btn.text = "Award XP"
		SubStep.MORALE:
			_title_label.text = "STEP 11: COLONY MORALE ADJUSTMENTS"
			_section_label.text = "Work out this turn's colony Morale adjustments."
			_action_btn.text = "Calculate Morale"
		SubStep.POST_MISSION_FINDS:
			_title_label.text = "STEP 12: POST-MISSION FINDS"
			_section_label.text = "Roll for Post-Mission Finds."
			_action_btn.text = "Roll Finds"
		SubStep.ENEMY_INFO:
			_title_label.text = "STEP 12: TRACK ENEMY INFORMATION & MISSION DATA"
			_section_label.text = "Record the Enemy Information and Mission Data this mission earned."
			_action_btn.text = "Process Intel"

	_build_sub_step_info()
	_action_btn.visible = true
	_action_btn.disabled = false
	_set_can_continue(false)
	# A resume into a Step 11 that already rolled shows its receipt (built above) and
	# must not offer the roll again.
	if _current_sub_step == SubStep.MORALE and _phase_manager \
			and _phase_manager.has_method("get_morale_receipt") \
			and not _phase_manager.get_morale_receipt().is_empty():
		_action_btn.visible = false
		_set_can_continue(true)
	_show_recorded_receipt()
	TouchScrollOpenerRef.open_subtree(_scroll)


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
	_scroll = scroll

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "POST-BATTLE"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_section_label = Label.new()
	_section_label.text = ""
	_section_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
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
	_action_btn.custom_minimum_size = Vector2(0, 48)
	_action_btn.pressed.connect(_on_action_pressed)
	btn_box.add_child(_action_btn)



## ============================================================================
## SUB-STEP INFO DISPLAY
## ============================================================================

func _build_sub_step_info() -> void:
	match _current_sub_step:
		SubStep.INJURIES:
			_build_debrief()

		SubStep.EXPERIENCE:
			var participants: Array = _battle_results.get("participants", [])
			_add_info_text("Characters who participated: %d" % participants.size())
			var rows: Array[String] = []
			for key in MISSION_XP:
				rows.append("+%d %s" % [int(MISSION_XP[key].xp), MISSION_XP[key].label])
			_add_info_text("Mission XP (p.67): %s." % ", ".join(rows))
			if _pitched_win():
				_add_info_text("Pitched Battle won: each survivor +%d XP (p.127)."
						% PITCHED_SURVIVOR_XP)

		SubStep.MORALE:
			_build_morale_choices()

		SubStep.POST_MISSION_FINDS:
			var find_rolls: int = _battle_results.get("find_rolls", 0)
			var won: bool = _battle_results.get("won", false)
			var mission_id: String = _battle_results.get("mission_id", "")
			_add_info_text("Mission: %s" % mission_id.replace("_", " ").capitalize())
			_add_info_text("Post-Mission Find rolls earned: %d" % find_rolls)
			if not won:
				_add_info_text("[color=ui-warning]Mission not won — no Find rolls.[/color]")
			var has_scientist: bool = _battle_results.get("has_scientist_standing", false)
			var has_scout: bool = _battle_results.get("has_scout_standing", false)
			if has_scientist:
				_add_info_text("[color=ui-success]Scientist on feet — bonus available[/color]")
			if has_scout:
				_add_info_text("[color=ui-success]Scout on feet — bonus available[/color]")

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
	_receipt_lines = []

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

	# Steps 9, 11 and 12b keep their receipts in the phase manager already; the rest
	# record what was printed, in the same frame as the mutation it describes.
	var key: String = _receipt_key()
	if key != "" and key != "injuries" and key != "intel" and _phase_manager \
			and _phase_manager.has_method("record_step_receipt"):
		_phase_manager.record_step_receipt(key, _receipt_lines)

	_set_can_continue(true)


func _on_continue_pressed() -> void:
	_can_continue = false

	# MORALE transitions to POST_MISSION_FINDS instead of emitting
	if _current_sub_step == SubStep.MORALE:
		if _protest_picker and _protest_picker.selected >= 0 and _phase_manager:
			_phase_manager.assign_protest(str(_protest_ids[_protest_picker.selected]))
		# p.90 Campaign Failure: complete the step so the phase manager ends the turn.
		if _campaign and _campaign.has_method("is_failed") and _campaign.is_failed():
			phase_completed.emit({})
			return
		_transition_to_sub_step(SubStep.POST_MISSION_FINDS,
			"STEP 12: POST-MISSION FINDS",
			"Roll for Post-Mission Finds.",
			"Roll Finds")
		return

	# POST_MISSION_FINDS transitions to ENEMY_INFO instead of emitting
	if _current_sub_step == SubStep.POST_MISSION_FINDS:
		_transition_to_sub_step(SubStep.ENEMY_INFO,
			"STEP 12: TRACK ENEMY INFORMATION & MISSION DATA",
			"Record the Enemy Information and Mission Data this mission earned.",
			"Process Intel")
		return

	# INJURIES and EXPERIENCE emit phase_completed normally (advance phase)
	# ENEMY_INFO emits phase_completed to finish the post-battle block
	var result_data: Dictionary = {}

	match _current_sub_step:
		SubStep.EXPERIENCE:
			result_data = {"xp_awarded": _xp_awarded}
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
	## Planetfall p.66. The debrief goes in first (it carries the grunt count), then the
	## phase manager rolls the step ONCE through PlanetfallColonyCrisis.resolve_injury_
	## step -- the same p.66 roller the Integrity table uses. This panel used to carry a
	## second copy that rolled bots and civvies and never removed a dead character.
	if not _phase_manager or not _phase_manager.has_method("resolve_injury_step"):
		return
	_battle_results = _phase_manager.apply_battle_debrief(_collect_debrief())
	var receipt: Dictionary = _phase_manager.resolve_injury_step()
	_clear_container(_content_vbox)
	for line in receipt.get("lines", []):
		_add_result_bbcode(str(line))


## Step 9 debrief (pp.66-68, 134). The battle screen records who deployed and who went
## down; these are the facts only the table knows. Each is the player's declaration,
## and PlanetfallBattleResultNormalizer bounds it by what the battle recorded.
func _build_debrief() -> void:
	_grunt_spin = null
	_colonist_spin = null
	_find_spin = null
	_md_spin = null
	_objective_spin = null
	_mission_inputs = {}
	_coward_checks = {}
	_boss_checks = {}
	var br: Dictionary = _battle_results
	var rolls: Array = br.get("injury_roll_ids", [])
	var bots: Array = br.get("broken_bot_ids", [])
	var civvies: Array = br.get("civvy_casualty_ids", [])
	_add_info_text("Casualties the battle recorded: %d to roll on the Injury table, %d bot(s), "
			% [rolls.size(), bots.size()] + "%d civvy casualties (p.66)." % civvies.size())
	var grunts_in: int = int(br.get("grunts_deployed", 0))
	# With nothing that can reach the Injury table, the press records this debrief and
	# rolls nothing; it read "Roll Injuries" over "0 to roll on the Injury table".
	if rolls.is_empty() and bots.is_empty() and civvies.is_empty() and grunts_in == 0:
		_action_btn.text = "Record the Debrief"
	if grunts_in > 0:
		_grunt_spin = _debrief_spin("Grunts that became casualties (each rolls 1D6, p.66):",
				grunts_in, int(br.get("grunt_casualties", 0)))
	if str(br.get("mission_id", "")) == "rescue":
		_colonist_spin = _debrief_spin(
				"Colonists lost in the mission (they still cost Morale, p.68):",
				99, int(br.get("colonists_lost", 0)))
	var participants: Array = br.get("participants", [])
	var casualties: Array = br.get("casualties", [])
	if not participants.is_empty():
		_add_info_text("[b]Experience (p.67)[/b]")
		var killers: Array = br.get("boss_killers", [])
		var cowards: Array = br.get("coward_ids", [])
		for pid in participants:
			var cid: String = str(pid)
			var who: String = _get_character_name(cid)
			_boss_checks[cid] = _debrief_check(
					"%s directly killed an enemy Boss or Leader" % who, killers.has(cid))
			if cid not in casualties:
				_coward_checks[cid] = _debrief_check(
						"%s left by a table edge in the first two rounds (Cowardice: no XP)"
						% who, cowards.has(cid))
	if bool(br.get("won", false)):
		_add_info_text("[b]Post-Mission Finds (p.134)[/b] "
				+ _mission_reward_text(str(br.get("mission_id", ""))))
		_find_spin = _debrief_spin("Find rolls this mission earned:", 10,
				int(br.get("find_rolls", 0)))
	_md_spin = _debrief_spin("Mission Data obtained (p.68):", 10,
			int(br.get("mission_data_gained", 0)))
	# The mission's objectives, which its Campaign Factors and Rewards read (pp.115-133).
	# Nothing asked for them until 2026-10-28, so every one of those rules read 0.
	var mission_id: String = str(br.get("mission_id", ""))
	if MapScript.OBJECTIVE_PROMPTS.has(mission_id):
		_objective_spin = _debrief_spin(str(MapScript.OBJECTIVE_PROMPTS[mission_id]) + ":",
				int(MapScript.OBJECTIVE_CAPS.get(mission_id, 10)),
				int(br.get("objectives_completed", 0)))
	_build_mission_reward_questions(br, mission_id)
	_build_calamity_questions(br, mission_id)


## pp.165-168: what only the table knows about each active Calamity, asked only on the
## missions its rule names. Nothing asked any of it before 2026-10-28, so seven of the
## eight Calamities could never end.
## The mission's own rewards only the table knows (pp.115-133), from the asks its resolver
## publishes, so the prompt and the cap live in one table. Until 2026-10-28 nothing asked
## an Investigation for its Rewards or Action required results, so both were lost.
func _build_mission_reward_questions(br: Dictionary, mission_id: String) -> void:
	var asks: Array = RewardsScript.DEBRIEF_ASKS.get(mission_id, [])
	if asks.is_empty():
		return
	var given: Dictionary = br.get("mission_rewards", {}) \
			if br.get("mission_rewards") is Dictionary else {}
	for a in asks:
		_mission_inputs[str(a[0])] = _debrief_spin(str(a[2]), int(a[1]),
				int(given.get(str(a[0]), 0)))


func _build_calamity_questions(br: Dictionary, mission_id: String) -> void:
	_calamity_inputs = {}
	if _campaign == null:
		return
	var cal := CalamityScript.new()
	var md: Dictionary = _campaign.map_data if "map_data" in _campaign else {}
	var k: String = str(br.get("sector", ""))
	var asks: Array = []
	if mission_id == "patrol" and cal.is_active(_campaign, "environmental_risk") \
			and k != "" and bool(MapScript.sector(md, k).get("anomaly", false)):
		asks.append(["anomaly_cleared", 0, "With all three Objectives clear, a character "
				+ "at one scored 6+ on 1D6+Savvy (scientists roll twice): the anomaly is "
				+ "cleared (p.166)"])
	if mission_id == "patrol" and cal.is_active(_campaign, "mega_predators"):
		asks.append(["marked_lifeforms_killed", 10,
				"Lifeforms from the marked Contacts killed (p.166):"])
	if mission_id != "delve" and cal.is_active(_campaign, "robot_rampage"):
		asks.append(["sleeper_chips", 10,
				"Sleeper chips found, a 5+ on 1D6+Savvy where a Sleeper fell (p.166):"])
	if str(br.get("opposition_type", "")) == "slyn" and cal.is_active(_campaign, "slyn_assault"):
		asks.append(["slyn_killed", 8, "Slyn killed (p.167):"])
	if mission_id == "hunt" and cal.is_active(_campaign, "wildlife_aggression"):
		asks.append(["controller_killed", 0, "The Controller was killed and a character "
				+ "reached where it fell (p.168)"])
	if asks.is_empty():
		return
	_add_info_text("[b]Calamities (pp.165-168)[/b]")
	var given: Dictionary = br.get("calamity", {}) if br.get("calamity") is Dictionary else {}
	for a in asks:
		var key: String = str(a[0])
		if int(a[1]) == 0:
			_calamity_inputs[key] = _debrief_check(str(a[2]), bool(given.get(key, false)))
		else:
			_calamity_inputs[key] = _debrief_spin(str(a[2]), int(a[1]), int(given.get(key, 0)))


func _collect_debrief() -> Dictionary:
	var d: Dictionary = {
		"coward_ids": _checked_ids(_coward_checks),
		"boss_killers": _checked_ids(_boss_checks),
	}
	if _grunt_spin:
		d["grunt_casualties"] = int(_grunt_spin.value)
	if _colonist_spin:
		d["colonists_lost"] = int(_colonist_spin.value)
	if _find_spin:
		d["find_rolls"] = int(_find_spin.value)
	if _md_spin:
		d["mission_data_gained"] = int(_md_spin.value)
	if _objective_spin:
		d["objectives_completed"] = int(_objective_spin.value)
	if not _mission_inputs.is_empty():
		var rewards: Dictionary = {}
		for key in _mission_inputs:
			if is_instance_valid(_mission_inputs[key]):
				rewards[key] = int((_mission_inputs[key] as SpinBox).value)
		d["mission_rewards"] = rewards
	if not _calamity_inputs.is_empty():
		var answers: Dictionary = {}
		for key in _calamity_inputs:
			var input: Variant = _calamity_inputs[key]
			if input is CheckBox and is_instance_valid(input):
				answers[key] = (input as CheckBox).button_pressed
			elif input is SpinBox and is_instance_valid(input):
				answers[key] = int((input as SpinBox).value)
		d["calamity"] = answers
	return d


func _checked_ids(checks: Dictionary) -> Array:
	var ids: Array = []
	for cid in checks:
		var check: CheckBox = checks[cid]
		if is_instance_valid(check) and check.button_pressed:
			ids.append(cid)
	return ids


func _debrief_spin(text: String, max_value: int, value: int) -> SpinBox:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content_vbox.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = max_value
	spin.value = clampi(value, 0, max_value)
	# A count of a few rolls: sized to its number, not stretched across the column, which
	# put the steppers a tablet's width away from the value they change.
	spin.custom_minimum_size = Vector2(160, 48)
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content_vbox.add_child(spin)
	return spin


func _debrief_check(text: String, pressed: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = pressed
	check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	check.custom_minimum_size = Vector2(0, 48)
	_content_vbox.add_child(check)
	return check


## The mission's own reward rule (data/planetfall/mission_types.json), so the number
## of Find rolls is read off the mission rather than a literal in this panel.
func _mission_reward_text(mission_id: String) -> String:
	if _mission_types.is_empty() and FileAccess.file_exists(MISSION_TYPES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_TYPES_PATH))
		if parsed is Dictionary:
			_mission_types = parsed.get("missions", [])
	for m in _mission_types:
		if m is Dictionary and str(m.get("id", "")) == mission_id:
			return str(m.get("rewards_detail", ""))
	return ""


## The step name a sub-step records its receipt under in the phase manager.
func _receipt_key() -> String:
	match _current_sub_step:
		SubStep.INJURIES:
			return "injuries"
		SubStep.EXPERIENCE:
			return "experience"
		SubStep.POST_MISSION_FINDS:
			return "finds"
		SubStep.ENEMY_INFO:
			return "intel"
	return ""


## A resume into a step that already resolved shows what happened and offers only
## Continue: nothing is rolled or awarded twice (the T1 shape, for Steps 9-12).
func _show_recorded_receipt() -> void:
	var key: String = _receipt_key()
	if key == "" or not _phase_manager or not _phase_manager.has_method("get_step_receipt"):
		return
	var receipt: Dictionary = _phase_manager.get_step_receipt(key)
	if receipt.is_empty():
		return
	_clear_container(_content_vbox)
	_clear_container(_result_container)
	for line in receipt.get("lines", []):
		_add_result_bbcode(str(line))
	_action_btn.visible = false
	_set_can_continue(true)

## ============================================================================
## EXPERIENCE RESOLUTION (Step 10)
## ============================================================================

func _resolve_experience() -> void:
	## Planetfall p.67 — XP awards per participant.
	var participants: Array = _battle_results.get("participants", [])
	var casualties_list: Array = _battle_results.get("casualties", [])
	var boss_killers: Array = _battle_results.get("boss_killers", [])
	var cowards: Array = _battle_results.get("coward_ids", [])

	if participants.is_empty():
		_add_result_bbcode("No participants to award XP.")
		_xp_awarded = true
		return

	_add_result_bbcode("[b]XP Awards:[/b]")
	for pid in participants:
		var char_name: String = _get_character_name(str(pid))
		# pp.70-71: this was the character's next mission, so Personal reflection and
		# Personal calibrations are spent on it whatever the XP comes to.
		var double_xp: bool = _take_note(str(pid), "double_xp")
		_take_note(str(pid), "calibrated")
		# p.67 Cowardice: "moved off a battlefield edge in the first two rounds of a
		# battle forfeits all XP awards from that battle".
		if cowards.has(str(pid)):
			_add_result_bbcode("  %s: no XP (Cowardice, p.67)." % char_name)
			continue
		var xp: int = int(MISSION_XP.participated.xp)
		var reasons: Array[String] = ["+%d participated" % xp]

		if not casualties_list.has(pid):
			xp += int(MISSION_XP.not_a_casualty.xp)
			reasons.append("+%d not a casualty" % int(MISSION_XP.not_a_casualty.xp))

		if boss_killers.has(pid):
			xp += int(MISSION_XP.boss_or_leader.xp)
			reasons.append("+%d killed Boss/Leader" % int(MISSION_XP.boss_or_leader.xp))

		if _pitched_win() and not casualties_list.has(pid):
			xp += PITCHED_SURVIVOR_XP
			reasons.append("+%d Pitched Battle survivor (p.127)" % PITCHED_SURVIVOR_XP)

		if double_xp:
			xp *= 2
			reasons.append("doubled, Personal reflection (p.71)")

		if _apply_xp_to_character(str(pid), xp) == 0:
			_add_result_bbcode("  %s: no XP (Personal tragedy, p.71)." % char_name)
			continue
		_add_result_bbcode(
			"  %s: +%d XP (%s)" % [char_name, xp, ", ".join(reasons)])

	_xp_awarded = true
	_add_result_bbcode(
		"\n[color=ui-success]XP awarded to %d character(s).[/color]" % participants.size())


func _pitched_win() -> bool:
	return str(_battle_results.get("mission_id", "")) == "pitched_battle" \
			and bool(_battle_results.get("won", false))


## ============================================================================
## MORALE RESOLUTION (Step 11)
## ============================================================================

## Before the roll (pp.68, 89-90): what Step 11 will do, and the choices a player
## makes FIRST: Personal Appeals before an Incident, the Crisis double roll, and the
## Colonist demands supervisors. A step already resolved (a resume) shows its receipt.
func _build_morale_choices() -> void:
	_appeals_check = null
	_reroll_check = null
	_supervisor_checks = {}
	_protest_picker = null
	_protest_ids = []
	if not _campaign or not _phase_manager \
			or not _phase_manager.has_method("preview_morale_step"):
		_add_info_text("No campaign data.")
		return
	var done: Dictionary = _phase_manager.get_morale_receipt()
	if not done.is_empty():
		_render_morale_receipt(done)
		return
	var p: Dictionary = _phase_manager.preview_morale_step()
	if bool(p.get("in_crisis", false)):
		_add_info_text("[color=ui-danger]The colony is in Crisis[/color] (Political Upheaval "
				+ "%d). Colony Morale is fixed at 0; this step rolls 2D6 on the Crisis "
				% int(p.get("upheaval", 0)) + "Outcome table (p.90).")
		if bool(p.get("can_spend", false)):
			_reroll_check = _story_point_check(
				"Spend 1 Story Point to roll the Crisis Outcome twice and keep the better "
				+ "score (p.90).", int(p.get("story_points", 0)))
	else:
		var inputs: Dictionary = _phase_manager.get_morale_inputs()
		_add_info_text("Automatic: -1 Colony Morale (p.68).")
		_add_info_text("Battle casualties: %d (each -1; none on a Rescue Mission)."
				% int(inputs.get("casualties", 0)))
		_add_info_text("Colony Damage is charged when it is taken, not here (p.87).")
		_add_info_text("Colony Morale will be: %d -> [b]%d[/b]"
				% [int(p.get("before", 0)), int(p.get("after", 0))])
		if bool(p.get("incident", false)):
			_add_info_text("[color=ui-danger]That is -10 or worse: a Morale Incident will be "
					+ "rolled (D100, p.90).[/color]")
			if bool(p.get("can_spend", false)):
				_appeals_check = _story_point_check(
					"Personal Appeals: spend 1 Story Point and count the incident as "
					+ "\"nothing happens\". Morale is still set to 0 (p.89).",
					int(p.get("story_points", 0)))
	if bool(p.get("colonist_demands", false)):
		_build_supervisor_choices()


func _story_point_check(text: String, left: int) -> CheckBox:
	var check := CheckBox.new()
	check.text = "%s %d Story Point(s) left." % [text, left]
	check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	check.custom_minimum_size = Vector2(0, 48)
	_content_vbox.add_child(check)
	return check


## p.90 Colonist demands: "assign any number of scouts or troopers to supervise
## security. They cannot take part in any missions except for Pitched Battles." So the
## eligible are scouts and troopers who did not deploy this turn, or anyone of those
## two classes if this turn's mission was a Pitched Battle.
func _build_supervisor_choices() -> void:
	_add_info_text("[b]Colonist demands are in force.[/b] Choose scouts or troopers who "
			+ "supervised security; each rolls 1D6+Savvy, and a 5+ satisfies the "
			+ "demands (p.90).")
	var result: Dictionary = _phase_manager.get_battle_result()
	var pitched: bool = str(result.get("mission_id", "")) == "pitched_battle"
	var deployed: Array = result.get("participants", [])
	for c in _campaign.roster:
		if not c is Dictionary:
			continue
		var cid: String = str(c.get("id", ""))
		var cls: String = str(c.get("class", "")).to_lower()
		if cls != "scout" and cls != "trooper":
			continue
		if _campaign.sick_bay.has(cid) or (deployed.has(cid) and not pitched):
			continue
		var check := CheckBox.new()
		check.text = "%s (%s, Savvy %+d)" % [c.get("name", cid), cls.capitalize(),
				int(c.get("savvy", 0))]
		check.custom_minimum_size = Vector2(0, 48)
		_content_vbox.add_child(check)
		_supervisor_checks[cid] = check
	if _supervisor_checks.is_empty():
		_add_info_text("No scout or trooper is free to supervise this turn.")


func _resolve_morale() -> void:
	## Step 11, pp.68 and 89-90. Until 2026-10-27 this only PRINTED "roll on the
	## Morale Incident table", so no Incident, Political Upheaval or Crisis ever
	## happened. The phase manager rolls and applies it; this panel shows the receipt.
	if not _campaign or not _phase_manager \
			or not _phase_manager.has_method("resolve_morale_step"):
		_add_result_bbcode("No campaign data.")
		return
	var supervisors: Array = []
	for cid in _supervisor_checks:
		if (_supervisor_checks[cid] as CheckBox).button_pressed:
			supervisors.append(cid)
	_render_morale_receipt(_phase_manager.resolve_morale_step({
		"personal_appeals": _appeals_check != null and _appeals_check.button_pressed,
		"crisis_reroll": _reroll_check != null and _reroll_check.button_pressed,
		"supervisors": supervisors,
	}))


func _render_morale_receipt(receipt: Dictionary) -> void:
	_add_result_bbcode("[b]Colony Morale Adjustments:[/b]")
	for line in receipt.get("lines", []):
		_add_result_bbcode(str(line))
	_add_result_bbcode("Colony Morale is now [b]%d[/b]. Political Upheaval %d%s." % [
			int(_campaign.colony_morale), int(_campaign.political_upheaval),
			", in Crisis" if _campaign.in_crisis else ""])
	if _campaign.is_failed():
		_add_result_bbcode("\n[color=ui-danger]The campaign has ended (p.90).[/color]")
		return
	if _campaign.protest_pending:
		_build_protest_picker()


## p.90 Protests: "Select a trooper that is unable to undertake any missions next
## campaign turn." The first trooper is preselected so the step can always complete.
func _build_protest_picker() -> void:
	_protest_ids = []
	for c in _campaign.roster:
		if c is Dictionary and str(c.get("class", "")).to_lower() == "trooper":
			_protest_ids.append(str(c.get("id", "")))
	if _protest_ids.is_empty():
		_add_result_bbcode("There is no trooper on the roster to sit out (p.90).")
		return
	_add_result_bbcode("\nProtests: choose the trooper who sits out next turn's mission "
			+ "(unless it is a Pitched Battle):")
	_protest_picker = OptionButton.new()
	_protest_picker.custom_minimum_size = Vector2(0, 48)
	for cid in _protest_ids:
		_protest_picker.add_item(_get_character_name(cid))
	_protest_picker.select(0)
	_result_container.add_child(_protest_picker)


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
				"    [color=ui-success]%s bonus: %s[/color]" % [
					source.capitalize(), ", ".join(bonus_parts)])

		# Apply to campaign
		if _campaign:
			for line in _post_mission.apply_find_to_campaign(_campaign, find):
				_add_result_bbcode("    " + str(line))

		_finds_rolled.append(find)

	_add_result_bbcode(
		"\n[color=ui-success]%d find(s) processed and applied.[/color]" % _finds_rolled.size())


## ============================================================================
## ENEMY INFO RESOLUTION (Step 12b)
## ============================================================================

func _resolve_enemy_info() -> void:
	## Planetfall p.68 Step 12: the phase manager rolls and applies it ONCE (Enemy
	## Information, the map's Campaign Factors, Mission Data); this renders the receipt.
	_add_result_bbcode("[b]Intelligence Report:[/b]")
	if not _phase_manager or not _phase_manager.has_method("resolve_intel_step"):
		return
	for line in _phase_manager.resolve_intel_step().get("lines", []):
		_add_result_bbcode("  " + str(line))


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


## A one-use Character Event note (pp.70-71): true if it was set, and it is cleared.
func _take_note(character_id: String, key: String) -> bool:
	if not _campaign or not _campaign.has_method("get_character_note"):
		return false
	if not bool(_campaign.get_character_note(character_id, key, false)):
		return false
	_campaign.clear_character_note(character_id, key)
	return true


func _apply_xp_to_character(character_id: String, xp: int) -> int:
	# Through the core's one XP writer (p.71 Personal tragedy is checked there).
	if not _campaign or not _campaign.has_method("award_xp"):
		return 0
	return _campaign.award_xp(character_id, xp)


func _add_info_text(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = UIColors.bbcode(text)
	ScreenChrome.size_rich_text(lbl, ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


## One result line, live or replayed from the recorded receipt, through the shared
## receipt renderer (UX-6) so every mode prints a result the same way.
func _add_result_bbcode(text: String) -> void:
	ReceiptCardRef.add_line(_result_container, text, true, FONT_SIZE_SM)
	_receipt_lines.append(text)


func _transition_to_sub_step(
		step: SubStep, title: String,
		section: String, action_text: String) -> void:
	## Internal transition between sub-steps without emitting phase_completed.
	_current_sub_step = step
	_clear_container(_content_vbox)
	_clear_container(_result_container)
	_title_label.text = title
	_section_label.text = section
	_action_btn.text = action_text
	_build_sub_step_info()
	_action_btn.visible = true
	_action_btn.disabled = false
	_set_can_continue(false)
	_show_recorded_receipt()
	TouchScrollOpenerRef.open_subtree(_scroll)


## What the turn screen's footer shows for this step: {ready, reason, label}. Step 12's
## two parts follow Morale inside this panel, so the footer names them itself; the turn
## screen would otherwise call the next press "Step 13".
func step_status() -> Dictionary:
	if not _can_continue:
		return {"ready": false, "reason": "Press \"%s\" to finish this step." % _action_btn.text}
	match _current_sub_step:
		SubStep.MORALE:
			if not (_campaign and _campaign.has_method("is_failed") and _campaign.is_failed()):
				return {"ready": true, "reason": "", "label": "Continue to Post-Mission Finds"}
		SubStep.POST_MISSION_FINDS:
			return {"ready": true, "reason": "", "label": "Continue to Enemy Information"}
	return {"ready": true, "reason": ""}


func _set_can_continue(value: bool) -> void:
	_can_continue = value
	step_status_changed.emit()


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
