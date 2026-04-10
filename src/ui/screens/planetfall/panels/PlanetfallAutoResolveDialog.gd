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

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")

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
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _step_id: String = ""
var _phase_index: int = -1
var _resolver: PlanetfallEventResolverScript
var _resolved: bool = false

var _title_label: Label
var _description_label: RichTextLabel
var _resolve_btn: Button
var _continue_btn: Button
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
	if _title_label:
		_title_label.text = _get_step_title().to_upper()
	if _description_label:
		_description_label.text = _get_step_description()
	if _resolve_btn:
		_resolve_btn.visible = _needs_resolve_button()
		_resolve_btn.disabled = false
		_resolve_btn.text = _get_resolve_button_text()
	if _continue_btn:
		_continue_btn.visible = not _needs_resolve_button()
		_continue_btn.disabled = false
	# Clear previous results
	if _result_container:
		for child in _result_container.get_children():
			child.queue_free()


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
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Description
	_description_label = RichTextLabel.new()
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.text = _get_step_description()
	_description_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
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
	_resolve_btn.custom_minimum_size = Vector2(200, 48)
	_resolve_btn.pressed.connect(_on_resolve_pressed)
	_resolve_btn.visible = _needs_resolve_button()
	btn_box.add_child(_resolve_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = not _needs_resolve_button()
	btn_box.add_child(_continue_btn)


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
		"update_tracking":
			_resolve_update_tracking()
		_:
			_add_result_text("Step resolved.", COLOR_TEXT_PRIMARY)

	# Show continue button
	_continue_btn.visible = true
	_continue_btn.disabled = false


func _on_continue_pressed() -> void:
	_continue_btn.disabled = true
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
		_add_result_text(
			"[color=#10B981]%d character(s) recovered from Sick Bay![/color]" % recovered.size(),
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

	# Bot repair check
	if _campaign and "bot_operational" in _campaign and not _campaign.bot_operational:
		_add_result_text(
			"\n[color=#D97706]Bot Broken — repair in Step 2.[/color]",
			COLOR_WARNING)


func _resolve_enemy_activity() -> void:
	## Step 4: Roll D100 for enemy activity. Planetfall p.62.
	if not _campaign:
		_add_result_text("No campaign data.", COLOR_WARNING)
		return

	# Check if tactical enemies exist
	var enemies: Array = _campaign.tactical_enemies if "tactical_enemies" in _campaign else []
	if enemies.is_empty():
		_add_result_text(
			"No Tactical Enemies on map. Step skipped.",
			COLOR_TEXT_SECONDARY)
		return

	var roll: int = _resolver.roll_d100()
	var result: Dictionary = _resolver.resolve_enemy_activity(roll)
	var name: String = result.get("name", "Unknown")
	var desc: String = result.get("description", "")
	var activity_type: String = result.get("type", "")

	_add_result_text("[b]D100 Roll: %d[/b]" % roll, COLOR_ACCENT)
	_add_result_text("[b]%s[/b]" % name, COLOR_TEXT_PRIMARY)
	_add_result_text(desc, COLOR_TEXT_SECONDARY)

	# Apply colony damage for raids
	if activity_type == "raid":
		# Damage = occupied sectors + 1
		var occupied: int = 0
		for enemy in enemies:
			if enemy is Dictionary:
				var sectors: Array = enemy.get("occupied_sectors", [])
				occupied += sectors.size()
		var base_damage: int = occupied + 1

		# Colony defenses mitigation
		var defenses: int = _campaign.colony_defenses if "colony_defenses" in _campaign else 0
		var mitigated: int = 0
		for idx in range(defenses):
			if _resolver.roll_d6() >= 4:
				mitigated += 1

		var final_damage: int = max(0, base_damage - mitigated)
		_add_result_text(
			"\n[color=#DC2626]Raid Damage: %d (base %d, %d mitigated by defenses)[/color]" % [
				final_damage, base_damage, mitigated],
			COLOR_DANGER)

		if _campaign.has_method("apply_enemy_activity"):
			_campaign.apply_enemy_activity({"colony_damage": final_damage})


func _resolve_colony_integrity() -> void:
	## Step 16: Check if integrity ≤ -3. Planetfall p.69, p.87.
	if not _campaign:
		_add_result_text("No campaign data.", COLOR_WARNING)
		return

	var integrity: int = _campaign.colony_integrity if "colony_integrity" in _campaign else 0
	_add_result_text("Current Colony Integrity: %d" % integrity, COLOR_TEXT_PRIMARY)

	if integrity <= -3:
		_add_result_text(
			"\n[color=#DC2626]INTEGRITY FAILURE" +
			" — Integrity %d (threshold: -3).[/color]" % integrity,
			COLOR_DANGER)

		# Apply failure consequences (Planetfall p.87)
		# Roll D6 for each point below 0 to determine damage severity
		var damage_points: int = absi(integrity)
		var morale_loss: int = 0
		var grunts_lost: int = 0

		for dmg_idx in range(damage_points):
			var roll: int = randi_range(1, 6)
			match roll:
				1, 2:
					# Minor structural damage — already reflected in integrity
					pass
				3, 4:
					morale_loss += 1
				5:
					grunts_lost += 1
				6:
					morale_loss += 1
					grunts_lost += 1

		if morale_loss > 0:
			if _campaign.has_method("adjust_morale"):
				_campaign.adjust_morale(-morale_loss)
			_add_result_text(
				"Colony Morale: -%d (instability)" % morale_loss,
				COLOR_WARNING)

		if grunts_lost > 0:
			for grunt_idx in range(grunts_lost):
				if _campaign.has_method("lose_grunt"):
					_campaign.lose_grunt()
			_add_result_text(
				"Grunts lost: %d (collapse)" % grunts_lost,
				COLOR_DANGER)

		if morale_loss == 0 and grunts_lost == 0:
			_add_result_text(
				"The colony weathers the damage with no additional casualties.",
				COLOR_WARNING)

		_add_result_text(
			"\nRepair via Repairs step (Step 2).",
			COLOR_TEXT_SECONDARY)
	else:
		_add_result_text(
			"\n[color=#10B981]Colony integrity is stable (above -3 threshold).[/color]",
			COLOR_SUCCESS)


func _resolve_update_tracking() -> void:
	## Step 18: Save campaign state. Planetfall p.70.
	_add_result_text("Campaign data saved. Turn complete!", COLOR_SUCCESS)
	_add_result_text(
		"Take a moment to review your Colony Tracking Sheet.",
		COLOR_TEXT_SECONDARY)

	# Auto-save
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs and gs.has_method("save_campaign") and _campaign:
		gs.save_campaign(_campaign)


## ============================================================================
## HELPERS
## ============================================================================

func _get_step_title() -> String:
	match _step_id:
		"recovery": return "Step 1: Recovery"
		"enemy_activity": return "Step 4: Enemy Activity"
		"colony_integrity": return "Step 16: Colony Integrity"
		"update_tracking": return "Step 18: Update Colony Sheet"
	return "Auto-Resolve Step"


func _get_step_description() -> String:
	match _step_id:
		"recovery":
			return "Characters in Sick Bay heal, reducing recovery time by 1 turn. Fully healed characters are ready for deployment."
		"enemy_activity":
			return "If Tactical Enemies are present, one is randomly selected and rolls on the Enemy Activity table (D100)."
		"colony_integrity":
			return "If Colony Integrity is -3 or worse, check the Integrity Failure table for consequences."
		"update_tracking":
			return "Ensure all changes from this campaign turn are recorded. Campaign data will be saved automatically."
	return ""


func _get_resolve_button_text() -> String:
	match _step_id:
		"recovery": return "Process Recovery"
		"enemy_activity": return "Roll Enemy Activity"
		"colony_integrity": return "Check Integrity"
		"update_tracking": return "Save & Complete"
	return "Resolve"


func _needs_resolve_button() -> bool:
	# All auto-resolve steps need a resolve button
	return true


func _add_result_text(text: String, _color: Color) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
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
			# Colony damage tracked by campaign already
			pass
		"colony_integrity":
			var integrity: int = _campaign.colony_integrity if _campaign and "colony_integrity" in _campaign else 0
			data["integrity_failure"] = integrity <= -3
	return data
