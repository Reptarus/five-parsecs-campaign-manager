class_name PlanetfallAutoResolveDialog
extends Control

## Reusable auto-resolve panel for Planetfall turn steps that require
## minimal player interaction: roll dice, show result, continue.
## Used for Steps 1 (Recovery), 4 (Enemy Activity), 16 (Colony Integrity),
## and 18 (Update Tracking).
##
## Configured via configure() with a step ID that determines behavior.
## Implements the standard panel interface contract.

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _step_id: String = ""
var _phase_index: int = -1
var _resolver: PlanetfallEventResolverScript
var _resolved: bool = false
## Raid damage dealt this step, REPORTED to the phase manager, which applies it and
## counts it for Step 11 Morale (p.89).
var _raid_damage: int = 0
## Step 16's Emergency Repairs choice (p.88), built only when a roll is owed.
var _emergency_check: CheckBox
## Step 4's Waiting for the Right Moment (p.61). The choice is REPORTED; the phase
## manager spends the Story Point on completion.
var _wait_check: CheckBox
var _waited: bool = false

var _title_label: Label
var _description_label: RichTextLabel
var _resolve_btn: Button
## The step's result is in and nothing is waiting for the player, so the turn
## screen's footer may continue. This used to be a "Continue" button inside the
## scroll, beside a footer "Complete Phase" that was disabled on every step.
var _can_continue: bool = false
var _result_container: VBoxContainer


func _ready() -> void:
	_resolver = PlanetfallEventResolverScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func configure(step_id: String, phase_index: int) -> void:
	## Configure this dialog for a specific turn step.
	## step_id: "recovery", "enemy_activity", "colony_integrity", "update_tracking"
	_step_id = step_id
	_phase_index = phase_index
	if _title_label:
		_title_label.text = _get_step_title().to_upper()


func refresh() -> void:
	_resolved = false
	_raid_damage = 0
	_waited = false
	if _title_label:
		_title_label.text = _get_step_title().to_upper()
	if _description_label:
		_description_label.text = _get_step_description()
	if _resolve_btn:
		_resolve_btn.visible = _needs_resolve_button()
		_resolve_btn.disabled = false
		_resolve_btn.text = _get_resolve_button_text()
	_can_continue = not _needs_resolve_button()
	# Clear previous results
	if _result_container:
		for child in _result_container.get_children():
			child.queue_free()
	if _step_id == "recovery" and _result_container:
		_prepare_recovery()
	if _step_id == "colony_integrity" and _result_container:
		_prepare_colony_integrity()
	if _step_id == "enemy_activity" and _result_container:
		_prepare_enemy_activity()
	if _step_id == "update_tracking" and _result_container:
		_prepare_update_tracking()
	step_status_changed.emit()


## A step the book says has nothing to do this turn says so on arrival and lets the
## footer continue. Steps 1, 4 and 16 each held the footer behind a button whose only
## result was "nothing happens".
func _skip_step(text: String) -> void:
	_add_result_text(text, COLOR_TEXT_SECONDARY)
	_resolved = true
	_resolve_btn.visible = false
	_can_continue = true


func complete() -> void:
	if not _resolved and _needs_resolve_button():
		_on_resolve_pressed()
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

	# Title
	_title_label = Label.new()
	_title_label.text = _get_step_title().to_upper()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Description
	_description_label = RichTextLabel.new()
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.text = _get_step_description()
	ScreenChrome.size_rich_text(_description_label, ScreenChrome.font_size(FONT_SIZE_SM))
	_description_label.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_description_label)

	# Result area
	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_result_container)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(btn_box)

	_resolve_btn = Button.new()
	_resolve_btn.text = _get_resolve_button_text()
	_resolve_btn.custom_minimum_size = Vector2(0, 48)
	_resolve_btn.pressed.connect(_on_resolve_pressed)
	_resolve_btn.visible = _needs_resolve_button()
	btn_box.add_child(_resolve_btn)


## ============================================================================
## STEP-SPECIFIC LOGIC
## ============================================================================

func _on_resolve_pressed() -> void:
	_resolve_btn.disabled = true
	_resolved = true

	match _step_id:
		"recovery":
			_resolve_recovery()
		"enemy_activity":
			_resolve_enemy_activity()
		"colony_integrity":
			_resolve_colony_integrity()
		_:
			_add_result_text("Step resolved.", COLOR_TEXT_PRIMARY)

	_set_can_continue(true)


func _on_continue_pressed() -> void:
	_can_continue = false
	var result_data: Dictionary = _build_result_data()
	phase_completed.emit(result_data)


func _resolve_recovery() -> void:
	## Step 1: Tick sick bay, show who recovered. Planetfall p.58.
	if not _campaign:
		_add_result_text("No campaign data.", COLOR_WARNING)
		return

	var recovered: Array = []
	if _campaign.has_method("tick_sick_bay"):
		recovered = _campaign.tick_sick_bay()

	if recovered.is_empty():
		_add_result_text("No characters were recovering this turn.", COLOR_TEXT_SECONDARY)
	else:
		_add_result_text("%d character(s) recovered from Sick Bay!" % recovered.size(),
			COLOR_SUCCESS)
		for cid in recovered:
			var char_name: String = _get_character_name(cid)
			_add_result_text("  - %s is ready for deployment" % char_name, COLOR_TEXT_PRIMARY)

	# Show who's still in sick bay
	if _campaign and "sick_bay" in _campaign:
		var still_sick: Dictionary = _campaign.sick_bay
		if not still_sick.is_empty():
			_add_result_text("\nStill in Sick Bay:", COLOR_TEXT_SECONDARY)
			for cid in still_sick:
				var char_name: String = _get_character_name(cid)
				var turns: int = still_sick[cid]
				_add_result_text(
					"  - %s (%d turn(s) remaining)" % [char_name, turns],
					COLOR_WARNING)

	_note_broken_bot()


## p.59: a broken Bot is repaired in Step 2, not healed here.
func _note_broken_bot() -> void:
	if _campaign and "bot_operational" in _campaign and not _campaign.bot_operational:
		_add_result_text("The colony Bot is broken: repair it in Step 2 (p.59).",
			COLOR_WARNING)


## p.58: "every character in sick bay will heal". With nobody there, nothing to do.
func _prepare_recovery() -> void:
	if not _campaign or not "sick_bay" in _campaign or not _campaign.sick_bay.is_empty():
		return
	_skip_step("No one is in Sick Bay, so no one has recovery time to reduce (p.58).")
	_note_broken_bot()


func _resolve_enemy_activity() -> void:
	## Step 4: Roll D100 for enemy activity. Planetfall p.62.
	if not _campaign:
		_add_result_text("No campaign data.", COLOR_WARNING)
		return

	# p.61: "If any Tactical Enemies are present on the map, randomly pick one and roll
	# D100". One enemy acts, never all of them; one defeated at its Strongpoint is
	# gone (p.51) and is not on the map.
	var enemies: Array = _campaign.get_active_tactical_enemies() \
			if _campaign.has_method("get_active_tactical_enemies") else []
	if enemies.is_empty():
		_add_result_text(
			"No Tactical Enemies on map. Step skipped.",
			COLOR_TEXT_SECONDARY)
		return

	if _wait_check != null and _wait_check.button_pressed:
		_waited = true
		_add_result_text("Waiting for the Right Moment: 1 Story Point is spent and the "
				+ "enemy takes no action this turn (p.61).", COLOR_TEXT_PRIMARY)
		return

	# Milestones widen the step: the 6th makes EVERY enemy act each turn (p.158), and the
	# 3rd queues one extra roll "in addition to the normal event" (p.157), resolved here
	# against another random enemy. The phase manager clears the queue on completion.
	var acting: Array = []
	if _campaign.has_method("get_milestone_flag") \
			and bool(_campaign.get_milestone_flag("enemy_activity_every_enemy", false)):
		acting = enemies.duplicate()
	else:
		acting.append(enemies[_resolver.pick_index(enemies.size(),
				"Planetfall Enemy Activity Target")])
	var extra: int = _campaign.get_extra_rolls("enemy_activity") \
			if _campaign.has_method("get_extra_rolls") else 0
	for _i in range(extra):
		acting.append(enemies[_resolver.pick_index(enemies.size(),
				"Planetfall Enemy Activity Target")])
	_raid_damage = 0
	for n in range(acting.size()):
		if n > 0:
			_add_result_text("", COLOR_TEXT_SECONDARY)
		_resolve_one_enemy_activity(acting[n])


func _resolve_one_enemy_activity(selected: Dictionary) -> void:
	var selected_type: Dictionary = selected.get("type", {}) \
			if selected.get("type") is Dictionary else {}
	_add_result_text("Acting enemy: [b]%s[/b]" % selected_type.get("name",
			selected.get("name", "Tactical Enemy")), COLOR_TEXT_PRIMARY)
	# p.61 Disruption: "If you won a battle against the selected enemy last turn, they
	# do NOT carry out an activity unless they are the Converted."
	if _campaign.has_method("is_enemy_disrupted") \
			and _campaign.is_enemy_disrupted(int(selected.get("index", -1))) \
			and not str(selected_type.get("id", "")).begins_with("converted"):
		_add_result_text("Disruption: you beat this enemy last turn, so it carries out no "
				+ "activity (p.61).", COLOR_TEXT_SECONDARY)
		return

	var roll: int = _resolver.roll_d100("Planetfall Enemy Activity")
	var result: Dictionary = _resolver.resolve_enemy_activity(roll)
	var name: String = result.get("name", "Unknown")
	var desc: String = result.get("description", "")
	var activity_type: String = result.get("type", "")

	_add_result_text("[b]D100 Roll: %d[/b]" % roll, COLOR_ACCENT)
	_add_result_text("[b]%s[/b]" % name, COLOR_TEXT_PRIMARY)
	_add_result_text(desc, COLOR_TEXT_SECONDARY)

	# Apply colony damage for raids
	if activity_type == "raid":
		# p.62 Raid: Colony Damage = the sectors THIS enemy occupies + 1.
		var sectors: Array = selected.get("occupied_sectors", []) \
				if selected.get("occupied_sectors") is Array else []
		var base_damage: int = sectors.size() + 1

		# Colony defenses mitigation
		var defenses: int = _campaign.colony_defenses if "colony_defenses" in _campaign else 0
		var mitigated: int = 0
		for idx in range(defenses):
			if _resolver.roll_d6("Planetfall Colony Defenses") >= 4:
				mitigated += 1

		var final_damage: int = max(0, base_damage - mitigated)
		_add_result_text("Raid Damage: %d (base %d, %d mitigated by defenses)" % [
				final_damage, base_damage, mitigated],
			COLOR_DANGER)

		# REPORTED, not applied. This dialog applied the damage itself and reported
		# nothing, so the phase manager's count stayed 0 and Step 11 never charged
		# Morale for a raid (p.89: -1 Morale per point of Colony Damage). Summed, since
		# a Milestone can make more than one enemy act.
		_raid_damage += final_damage


## Step 16, pp.87-88. Until 2026-10-27 this rolled a D6 per point of negative
## Integrity and lost grunts on a 5-6, a table in neither book. The phase manager now
## rolls the p.88 3D6 Integrity Failure table and applies it; this panel shows the
## receipt and offers Emergency Repairs (1 Story Point, p.88) before the roll.
func _resolve_colony_integrity() -> void:
	if not _campaign or not _phase_manager \
			or not _phase_manager.has_method("resolve_integrity_step"):
		_add_result_text("No campaign data.", COLOR_WARNING)
		return
	var options := {"emergency_repairs": _emergency_check != null
			and _emergency_check.button_pressed}
	_render_lines(_phase_manager.resolve_integrity_step(options))


## Before the roll: the Emergency Repairs choice, offered only when a roll is owed and
## a Story Point can be spent. A step already resolved (a resume) shows its receipt.
func _prepare_colony_integrity() -> void:
	_emergency_check = null
	if not _campaign or not _phase_manager \
			or not _phase_manager.has_method("get_integrity_receipt"):
		return
	var done: Dictionary = _phase_manager.get_integrity_receipt()
	if not done.is_empty():
		_render_lines(done)
		_resolved = true
		_resolve_btn.visible = false
		_can_continue = true
		return
	# p.87: above the threshold there is no roll, so the step resolves on arrival. The
	# phase manager resolves it once either way; nothing here is random.
	if _phase_manager.has_method("integrity_roll_owed") \
			and not _phase_manager.integrity_roll_owed():
		_render_lines(_phase_manager.resolve_integrity_step())
		_resolved = true
		_resolve_btn.visible = false
		_can_continue = true
		return
	var integrity: int = int(_campaign.colony_integrity)
	_add_result_text("Current Colony Integrity: %d (maximum %d)."
			% [integrity, int(_campaign.max_colony_integrity)], COLOR_TEXT_PRIMARY)
	var preview: Dictionary = _phase_manager.preview_morale_step()
	if bool(preview.get("can_spend", false)):
		_emergency_check = CheckBox.new()
		_emergency_check.text = "Emergency Repairs: spend 1 Story Point to skip the " \
				+ "Integrity Failure roll (p.88). %d Story Point(s) left." \
				% int(preview.get("story_points", 0))
		_emergency_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_emergency_check.custom_minimum_size = Vector2(0, 48)
		_result_container.add_child(_emergency_check)


## p.61 Waiting for the Right Moment: "You may forego a roll on the Enemy Activity
## table ... by spending 1 Story Point." Offered before the roll, only when a Tactical
## Enemy is on the map and a Story Point may be spent this turn.
func _prepare_enemy_activity() -> void:
	_wait_check = null
	# p.61: "If there are none currently on the map, skip this step."
	if _campaign and (not _campaign.has_method("get_active_tactical_enemies")
			or _campaign.get_active_tactical_enemies().is_empty()):
		_skip_step("No Tactical Enemies are on the map, so this step is skipped (p.61).")
		return
	if not _campaign or not _phase_manager \
			or not _phase_manager.has_method("can_spend_story_point") \
			or not _phase_manager.can_spend_story_point():
		return
	_wait_check = CheckBox.new()
	_wait_check.text = "Waiting for the Right Moment: spend 1 Story Point to forgo the " \
			+ "Enemy Activity roll (p.61). %d Story Point(s) left." % int(_campaign.story_points)
	_wait_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait_check.custom_minimum_size = Vector2(0, 48)
	_result_container.add_child(_wait_check)


func _render_lines(receipt: Dictionary) -> void:
	for line in receipt.get("lines", []):
		_add_result_text(str(line), COLOR_TEXT_PRIMARY)


## Step 18 (p.71): tidy the paper Colony Tracking Sheet and, if the player keeps one,
## the campaign diary. There is no roll and no choice, and the phase manager saves when
## the turn closes (`_complete_turn`), so the step arrives ready. It used to wait on a
## "Save & Complete" press whose own save ran first and recorded the turn as still on
## Step 18, one save before the real one.
func _prepare_update_tracking() -> void:
	_skip_step("Tidy your Colony Tracking Sheet and, if you keep one, your campaign "
			+ "diary (p.71). The campaign saves when the turn ends.")


## ============================================================================
## HELPERS
## ============================================================================

## The book's step heading, read from the phase manager's one name table. These used
## to be hand-copied per panel, and Step 18 drifted to "Update Colony Sheet" against
## the contents list's "Update Colony Tracking Sheet" (p.70; the step itself is p.71).
func _get_step_title() -> String:
	var names: Dictionary = load("res://src/core/campaign/PlanetfallPhaseManager.gd").PHASE_NAMES
	if names.has(_phase_index):
		return "Step %d: %s" % [_phase_index + 1, names[_phase_index]]
	return "Auto-Resolve Step"


func _get_step_description() -> String:
	match _step_id:
		"recovery":
			return "Characters in Sick Bay heal, reducing recovery time by 1 turn. Fully healed characters are ready for deployment."
		"enemy_activity":
			return "If Tactical Enemies are present, one is randomly selected and rolls on the Enemy Activity table (D100)."
		"colony_integrity":
			return "If Colony Integrity is -3 or worse, roll 3D6. A roll equal to or below the Integrity score flipped (-8 counts as 8) is an Integrity Failure, looked up on the table (pp.87-88)."
		"update_tracking":
			return "The last step of the turn. Nothing is rolled."
	return ""


func _get_resolve_button_text() -> String:
	match _step_id:
		"recovery": return "Process Recovery"
		"enemy_activity": return "Roll Enemy Activity"
		"colony_integrity": return "Check Integrity"
	return "Resolve"


func _needs_resolve_button() -> bool:
	# All auto-resolve steps need a resolve button
	return true


## The colour was accepted and ignored (every line rendered primary), which is why three
## lines hand-wrote hex [color] tags.
func _add_result_text(text: String, color: Color) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	ScreenChrome.size_rich_text(lbl, ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", color)
	_result_container.add_child(lbl)


func _get_character_name(character_id: String) -> String:
	if not _campaign or not "roster" in _campaign:
		return character_id
	for char_dict in _campaign.roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				return char_dict.get("name", character_id)
	return character_id


func _build_result_data() -> Dictionary:
	var data: Dictionary = {"step_id": _step_id}
	match _step_id:
		"enemy_activity":
			data["colony_damage"] = _raid_damage
			data["waited"] = _waited
	return data


## What the turn screen's footer shows for this step: {ready, reason}. The footer
## names the next step itself.
func step_status() -> Dictionary:
	var status: Dictionary = {"ready": _can_continue, "reason": ""}
	if not _can_continue:
		status.reason = "Press \"%s\" to finish this step." % _get_resolve_button_text()
	return status


func _set_can_continue(value: bool) -> void:
	_can_continue = value
	step_status_changed.emit()
