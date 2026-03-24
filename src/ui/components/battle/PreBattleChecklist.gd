class_name FPCM_PreBattleChecklist
extends PanelContainer

## Pre-Battle Checklist - Physical table setup assistant
##
## Interactive checklist of physical table setup steps from the Five Parsecs
## Core Rules. Tier-aware: shows more items at higher tracking tiers.
## Each item can optionally include a DualInputRoll for dice.
##
## Reference: Five Parsecs From Home Core Rules
## "Before the first round, set up terrain, deploy forces, and resolve pre-battle steps."

const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")
const DualInputRollScene = preload("res://src/ui/components/battle/DualInputRoll.gd")
const CompendiumSpeciesRef = preload("res://src/data/compendium_species.gd")
const CompendiumEquipmentRef = preload("res://src/data/compendium_equipment.gd")
const CompendiumNoMinisRef = preload("res://src/data/compendium_no_minis.gd")

signal checklist_completed()
signal checklist_item_checked(item_id: String, checked: bool)

# Design system constants (from UIColors)
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const SPACING_XL := UIColors.SPACING_XL
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const FONT_SIZE_XL := UIColors.FONT_SIZE_XL
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS

## Checklist items per tier. Each item: {id, label, tier, dice_type (optional), hint (optional)}
const CHECKLIST_ITEMS: Array[Dictionary] = [
	# Tier 1 - LOG_ONLY (3 items: basic physical setup)
	{
		"id": "setup_terrain",
		"label": "Set up terrain on table",
		"hint": "Place terrain features across the 2'x2' (or 3'x3') playing area.",
		"tier": 0,
	},
	{
		"id": "deploy_enemies",
		"label": "Deploy enemy forces",
		"hint": "Place enemy figures according to mission deployment rules.",
		"tier": 0,
	},
	{
		"id": "deploy_crew",
		"label": "Deploy crew",
		"hint": "Place your crew within your deployment zone.",
		"tier": 0,
	},
	# Tier 2 - ASSISTED (adds 5 items: rules prompts with dice)
	{
		"id": "deployment_conditions",
		"label": "Roll deployment conditions",
		"hint": "Roll d100 to determine special deployment conditions (Core Rules p.90).",
		"tier": 1,
		"dice_type": "d100",
	},
	{
		"id": "notable_sighting",
		"label": "Check for Notable Sighting",
		"hint": "Roll d100 to check if a notable sight is encountered (Core Rules p.94).",
		"tier": 1,
		"dice_type": "d100",
	},
	{
		"id": "seize_initiative",
		"label": "Seize Initiative roll",
		"hint": "Roll 1d6. On a 6, your crew seizes the initiative and acts first (Core Rules p.38).",
		"tier": 1,
		"dice_type": "d6",
	},
	{
		"id": "assign_reactions",
		"label": "Assign Reaction dice",
		"hint": "Note each crew member's Reactions stat. This determines Quick/Slow action assignment.",
		"tier": 1,
	},
	{
		"id": "note_conditions",
		"label": "Note environmental conditions",
		"hint": "Record any weather, lighting, or environmental effects for this battle.",
		"tier": 1,
	},
	# Tier 3 - FULL_ORACLE (adds 3 items: AI-assisted setup)
	{
		"id": "generate_enemies",
		"label": "Generate enemy forces",
		"hint": "Use the Enemy Generation Wizard to determine enemy types and numbers.",
		"tier": 2,
	},
	{
		"id": "determine_ai_behavior",
		"label": "Determine AI behavior type",
		"hint": "Assign an AI type to each enemy group (Aggressive, Cautious, Tactical, etc.).",
		"tier": 2,
	},
	{
		"id": "select_oracle_mode",
		"label": "Select AI Oracle mode",
		"hint": "Choose: Reference (read rules), D6 Table (roll per group), or Card Oracle (draw cards).",
		"tier": 2,
	},
]

var _current_tier: int = 0
var _check_states: Dictionary = {} # item_id -> bool
var _item_nodes: Dictionary = {} # item_id -> CheckBox
var _vbox: VBoxContainer

func _ready() -> void:
	_setup_panel_style()
	_build_ui()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = COLOR_BORDER
	style.set_content_margin_all(SPACING_LG)
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(_vbox)

	# Title
	var title := Label.new()
	title.text = "Pre-Battle Setup Checklist"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Complete each step on your physical table before starting the battle."
	subtitle.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(subtitle)

	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	# Build checklist items
	for item: Dictionary in CHECKLIST_ITEMS:
		var item_node := _create_checklist_item(item)
		_vbox.add_child(item_node)
		_check_states[item.id] = false

	# Apply initial tier visibility
	_apply_tier_filter()

func _create_checklist_item(item: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "Item_%s" % item.id
	container.add_theme_constant_override("separation", 2)

	# Row with checkbox + label
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	container.add_child(row)

	var checkbox := CheckBox.new()
	checkbox.name = "Check_%s" % item.id
	checkbox.text = item.label
	checkbox.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	checkbox.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	checkbox.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	checkbox.toggled.connect(_on_item_toggled.bind(item.id))
	row.add_child(checkbox)
	_item_nodes[item.id] = checkbox

	# Hint text (smaller, secondary color)
	if item.has("hint") and not item.hint.is_empty():
		var hint_label := Label.new()
		hint_label.text = item.hint
		hint_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		hint_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(hint_label)

	# DualInputRoll for items with dice
	if item.has("dice_type"):
		var roll := DualInputRollScene.new()
		roll.dice_type = item.dice_type
		roll.context_label = item.label
		roll.show_result = true
		container.add_child(roll)

	# Bottom separator
	var item_sep := HSeparator.new()
	item_sep.modulate = Color(1, 1, 1, 0.3)
	container.add_child(item_sep)

	return container

func _on_item_toggled(toggled_on: bool, item_id: String) -> void:
	_check_states[item_id] = toggled_on
	checklist_item_checked.emit(item_id, toggled_on)

	# Check if all visible items are complete
	if _is_checklist_complete():
		checklist_completed.emit()

func _is_checklist_complete() -> bool:
	for item: Dictionary in CHECKLIST_ITEMS:
		if item.tier > _current_tier:
			continue
		if not _check_states.get(item.id, false):
			return false
	return true

## Set the tracking tier. Shows/hides checklist items accordingly.
func set_tier(tier: int) -> void:
	_current_tier = tier
	_apply_tier_filter()

func _apply_tier_filter() -> void:
	if not _vbox:
		return
	for item: Dictionary in CHECKLIST_ITEMS:
		var item_node: Control = _vbox.get_node_or_null("Item_%s" % item.id)
		if item_node:
			item_node.visible = item.tier <= _current_tier

## Get the number of visible checklist items for current tier.
func get_item_count() -> int:
	var count := 0
	for item: Dictionary in CHECKLIST_ITEMS:
		if item.tier <= _current_tier:
			count += 1
	return count

## Get the number of checked items for current tier.
func get_checked_count() -> int:
	var count := 0
	for item: Dictionary in CHECKLIST_ITEMS:
		if item.tier <= _current_tier and _check_states.get(item.id, false):
			count += 1
	return count

## Reset all checkboxes.
func reset() -> void:
	for item_id: String in _check_states:
		_check_states[item_id] = false
		var checkbox: CheckBox = _item_nodes.get(item_id)
		if checkbox:
			checkbox.button_pressed = false

## Serialize checked state for save/load.
func serialize() -> Dictionary:
	return {
		"tier": _current_tier,
		"checked": _check_states.duplicate(),
	}

## Deserialize from save data.
func deserialize(data: Dictionary) -> void:
	_current_tier = data.get("tier", 0)
	var checked: Dictionary = data.get("checked", {})
	for item_id: String in checked:
		_check_states[item_id] = checked[item_id]
		var checkbox: CheckBox = _item_nodes.get(item_id)
		if checkbox:
			checkbox.button_pressed = checked[item_id]
	_apply_tier_filter()

## Add species-specific reminder items for compendium species in the crew.
## Call this after _build_ui() with an array of origin strings (e.g., ["human", "krag"]).
func add_species_reminders(crew_origins: Array) -> void:
	var reminders: Array[String] = CompendiumSpeciesRef.get_crew_battle_reminders(crew_origins)
	if reminders.is_empty():
		return

	# Add a separator before species reminders
	var sep_label := Label.new()
	sep_label.text = "Species Reminders"
	sep_label.name = "Item_species_header"
	sep_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	sep_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_vbox.add_child(sep_label)

	for i in range(reminders.size()):
		var reminder_id := "species_reminder_%d" % i
		var item := {
			"id": reminder_id,
			"label": reminders[i],
			"tier": 0,  # Always visible regardless of tier
		}
		var item_node := _create_checklist_item(item)
		_vbox.add_child(item_node)
		_check_states[reminder_id] = false


## Add psionic power reminders for crew members with Psionic Powers.
## Call with an array of crew member dictionaries from Character.to_dictionary().
func add_psionic_reminders(crew_dicts: Array) -> void:
	var psionic_data: Dictionary = _load_psionic_powers_data()
	var psionic_entries: Array[String] = []
	for member in crew_dicts:
		if member is Dictionary:
			var power_id: String = member.get("psionic_power", "")
			if not power_id.is_empty():
				var power_info: Dictionary = psionic_data.get(power_id, {})
				var power_name: String = power_info.get("name", power_id.capitalize())
				var desc: String = power_info.get("description", "")
				var member_name: String = member.get("character_name", member.get("name", "Unknown"))
				psionic_entries.append("%s has Psionic Power: %s — %s" % [member_name, power_name, desc])
	if psionic_entries.is_empty():
		return

	var sep_label := Label.new()
	sep_label.text = "Psionic Powers"
	sep_label.name = "Item_psionic_header"
	sep_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	sep_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_vbox.add_child(sep_label)

	for i in range(psionic_entries.size()):
		var psi_id := "psionic_reminder_%d" % i
		var item_data := {"id": psi_id, "label": psionic_entries[i], "tier": 0}
		var item_node := _create_checklist_item(item_data)
		_vbox.add_child(item_node)
		_check_states[psi_id] = false


## Add compendium equipment instruction reminders for crew with DLC items.
## Call with an array of compendium item IDs the crew currently has equipped.
func add_equipment_reminders(equipped_item_ids: Array) -> void:
	var entries: Array[String] = []
	for item_id in equipped_item_ids:
		if item_id is String and not item_id.is_empty():
			var text: String = CompendiumEquipmentRef.get_instruction_text(item_id)
			if not text.is_empty():
				entries.append(text)
	if entries.is_empty():
		return

	var sep_label := Label.new()
	sep_label.text = "Compendium Equipment"
	sep_label.name = "Item_equipment_header"
	sep_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	sep_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_vbox.add_child(sep_label)

	for i in range(entries.size()):
		var eq_id := "equipment_reminder_%d" % i
		var item_data := {"id": eq_id, "label": entries[i], "tier": 0}
		var item_node := _create_checklist_item(item_data)
		_vbox.add_child(item_node)
		_check_states[eq_id] = false


## Add no-minis combat mission notes and incompatibility warnings.
## mission_id: the current mission objective type (e.g., "access", "deliver")
## active_flags: array of active DLC flag strings to check for incompatibilities
func add_no_minis_notes(mission_id: String, active_flags: Array) -> void:
	var notes_text: String = CompendiumNoMinisRef.get_mission_notes(mission_id)
	var incompatible: Array[String] = []
	for flag in active_flags:
		if flag is String and CompendiumNoMinisRef.is_incompatible(flag):
			incompatible.append(flag)

	if notes_text.is_empty() and incompatible.is_empty():
		return

	var sep_label := Label.new()
	sep_label.text = "No-Minis Combat Notes"
	sep_label.name = "Item_nominis_header"
	sep_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	sep_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_vbox.add_child(sep_label)

	var idx := 0
	if not notes_text.is_empty():
		var note_id := "nominis_note_%d" % idx
		var item_data := {"id": note_id, "label": notes_text, "tier": 0}
		var item_node := _create_checklist_item(item_data)
		_vbox.add_child(item_node)
		_check_states[note_id] = false
		idx += 1

	for flag_name: String in incompatible:
		var warn_id := "nominis_warn_%d" % idx
		var warn_text := "WARNING: %s is incompatible with No-Minis Combat and has been disabled." % flag_name.replace("_", " ").capitalize()
		var item_data := {"id": warn_id, "label": warn_text, "tier": 0}
		var item_node := _create_checklist_item(item_data)
		_vbox.add_child(item_node)
		_check_states[warn_id] = false
		idx += 1


## Add enemy psionic notes for Compendium DLC (DLC-gated).
## enemy_type: the enemy group type string (e.g., "Swift", "Rogue Psionic")
## legality: PsionicLegality enum int from progress_data, or -1 if unknown
func add_enemy_psionic_notes(enemy_type: String, legality: int = -1) -> void:
	var dlc = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc or not dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
		return

	const PsionicSysRef = preload(
		"res://src/core/systems/PsionicSystem.gd")
	var psi_data: Dictionary = PsionicSysRef.determine_enemy_psionics(
		enemy_type)
	var psi_text: String = PsionicSysRef.get_enemy_psionic_text(psi_data)

	var entries: Array[String] = []
	if not psi_text.is_empty():
		entries.append(psi_text)

	# Legality warning
	if legality == PsionicSysRef.PsionicLegality.OUTLAWED:
		entries.append(
			"WARNING: Psionics OUTLAWED on this world. "
			+ "Post-battle detection check required if used.")
	elif legality == PsionicSysRef.PsionicLegality.HIGHLY_UNUSUAL:
		entries.append(
			"Psionics Highly Unusual: If 2+ projection dice "
			+ "show 6, reinforcements arrive.")

	if entries.is_empty():
		return

	var sep_label := Label.new()
	sep_label.text = "Enemy Psionics"
	sep_label.name = "Item_enemy_psionic_header"
	sep_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	sep_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_vbox.add_child(sep_label)

	for i in range(entries.size()):
		var ep_id := "enemy_psionic_%d" % i
		var item_data := {"id": ep_id, "label": entries[i], "tier": 1}
		var item_node := _create_checklist_item(item_data)
		_vbox.add_child(item_node)
		_check_states[ep_id] = false


func _load_psionic_powers_data() -> Dictionary:
	var path := "res://data/psionic_powers.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
