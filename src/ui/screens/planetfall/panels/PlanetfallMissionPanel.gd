class_name PlanetfallMissionPanel
extends Control

## Step 6: Mission Determination — select mission type for this turn.
## 13 mission types loaded from mission_types.json.
## Some missions are event-triggered, some require tactical enemies.
## Source: Planetfall pp.64-65, 114-133

signal phase_completed(result_data: Dictionary)

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

const PlanetfallConditionScript := preload(
	"res://src/core/systems/PlanetfallConditionSystem.gd")
const PlanetfallMissionSetupScript := preload(
	"res://src/core/systems/PlanetfallMissionSetup.gd")

var _campaign: Resource
var _phase_manager: Node
var _missions: Array = []
var _selected_mission: Dictionary = {}
var _condition_sys: PlanetfallConditionScript
var _mission_setup: PlanetfallMissionSetupScript

var _title_label: Label
var _list_container: VBoxContainer
var _detail_container: VBoxContainer
var _confirm_btn: Button


func _ready() -> void:
	_condition_sys = PlanetfallConditionScript.new()
	_mission_setup = PlanetfallMissionSetupScript.new()
	_load_missions()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_selected_mission = {}
	_clear_container(_list_container)
	_clear_container(_detail_container)
	_build_mission_list()
	if _confirm_btn:
		_confirm_btn.disabled = true


func complete() -> void:
	if not _selected_mission.is_empty():
		_on_confirm_pressed()


## ============================================================================
## DATA
## ============================================================================

func _load_missions() -> void:
	var path := "res://data/planetfall/mission_types.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if json.data is Dictionary:
		_missions = json.data.get("missions", [])


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
	_title_label.text = "STEP 6: MISSION DETERMINATION"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Two-column layout: mission list + detail
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(hbox)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", SPACING_SM)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_list_container)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", SPACING_SM)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail_container)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm Mission Selection"
	_confirm_btn.custom_minimum_size = Vector2(240, 48)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_btn)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## MISSION LIST
## ============================================================================

func _build_mission_list() -> void:
	var header := Label.new()
	header.text = "Available Missions"
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_list_container.add_child(header)

	for mission in _missions:
		if mission is not Dictionary:
			continue
		var mid: String = mission.get("id", "")
		var mname: String = mission.get("name", "Unknown")
		var category: String = mission.get("category", "")
		var forced: bool = mission.get("forced", false)
		var needs_enemies: bool = mission.get("requires_tactical_enemies", false)
		var event_triggered: bool = mission.get("event_triggered", false)

		var btn := Button.new()
		btn.text = mname
		btn.custom_minimum_size.y = 40
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Dim unavailable missions
		if needs_enemies and not _has_tactical_enemies():
			btn.tooltip_text = "Requires Tactical Enemies on the map"
			btn.disabled = true
		if event_triggered:
			btn.tooltip_text = "Triggered by campaign events"

		btn.pressed.connect(_on_mission_selected.bind(mission))
		_list_container.add_child(btn)


func _on_mission_selected(mission: Dictionary) -> void:
	_selected_mission = mission
	_show_mission_detail(mission)
	if _confirm_btn:
		_confirm_btn.disabled = false


func _show_mission_detail(mission: Dictionary) -> void:
	_clear_container(_detail_container)

	# Mission name
	var name_lbl := Label.new()
	name_lbl.text = mission.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	# Category + table size
	var cat_text: String = "%s  |  Table: %s ft" % [
		mission.get("category", "").capitalize(),
		mission.get("table_size", "3x3")]
	var cat_lbl := Label.new()
	cat_lbl.text = cat_text
	cat_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	cat_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(cat_lbl)

	# Description
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = mission.get("description", "")
	desc.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(desc)

	# Briefing sections
	_add_briefing_section("Player Forces", _format_player_forces(mission))
	_add_briefing_section("Opposition", _format_opposition(mission))
	_add_briefing_section("Objectives", _format_objectives(mission))
	_add_briefing_section("Rewards", _format_rewards(mission))

	# Special rules
	var special: Array = mission.get("special_rules", [])
	if not special.is_empty():
		_add_briefing_section("Special Rules", "\n".join(special))

	# Battlefield conditions indicator
	var has_conditions: bool = mission.get("battlefield_conditions", false)
	if has_conditions:
		var cond_lbl := Label.new()
		cond_lbl.text = "Battlefield Conditions: Roll on Campaign Condition table"
		cond_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		cond_lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_detail_container.add_child(cond_lbl)

	# Page reference
	var page_lbl := Label.new()
	page_lbl.text = "Rulebook: p.%d" % mission.get("page", 0)
	page_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	page_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(page_lbl)


func _add_briefing_section(title: String, content: String) -> void:
	if content.is_empty():
		return

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_SM)
	card.add_theme_stylebox_override("panel", style)
	_detail_container.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	title_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	inner.add_child(title_lbl)

	var content_lbl := RichTextLabel.new()
	content_lbl.bbcode_enabled = true
	content_lbl.fit_content = true
	content_lbl.scroll_active = false
	content_lbl.text = content
	content_lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_XS)
	content_lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	inner.add_child(content_lbl)


func _format_player_forces(mission: Dictionary) -> String:
	var forces: Dictionary = mission.get("player_forces", {})
	var max_chars: int = forces.get("max_characters", 6)
	var max_grunts: int = forces.get("max_grunts", 0)
	var fireteams: int = forces.get("grunt_fireteams", 0)

	var parts: Array = ["Characters: up to %d" % max_chars]
	if max_grunts > 0:
		parts.append("Grunts: up to %d (%d fireteam%s)" % [
			max_grunts, fireteams, "s" if fireteams != 1 else ""])
	else:
		parts.append("No grunts")

	var deployment: String = mission.get("deployment", "")
	if not deployment.is_empty():
		parts.append(deployment)
	return "\n".join(parts)


func _format_opposition(mission: Dictionary) -> String:
	var opp: Dictionary = mission.get("opposition", {})
	var opp_type: String = opp.get("type", "unknown")

	match opp_type:
		"lifeforms":
			var contact_setup: String = opp.get("contact_setup", "")
			if opp.get("slyn_immune", false):
				return "Lifeforms (Contact system). Slyn will not interfere.\n%s" % contact_setup
			return "Lifeforms (Contact system).\n%s" % contact_setup
		"tactical":
			var note: String = "Tactical Enemies."
			if opp.get("slyn_immune", false):
				note += " Slyn will not interfere."
			if opp.get("double_force", false):
				note += "\nTwo separate enemy forces!"
			if opp.get("max_encounter", false):
				note += "\nMaximum strength + reinforcements!"
			return note
		"slyn_check":
			var aggro: Dictionary = opp.get("slyn_aggression", {})
			var range_str: String = "%d-%d" % [
				aggro.get("slyn_range_min", 2), aggro.get("slyn_range_max", 4)]
			return "2D6 Slyn check: %s = Slyn attack. Otherwise Lifeforms/Tactical." % range_str
		"delve_hazards":
			return "Delve Hazards (4 initial markers). No conventional enemies — Sleepers and traps instead."
		_:
			return opp_type.capitalize()


func _format_objectives(mission: Dictionary) -> String:
	var obj: Dictionary = mission.get("objectives", {})
	var obj_type: String = obj.get("type", "")
	var desc: String = obj.get("description", "")
	if not desc.is_empty():
		return desc
	match obj_type:
		"discovery_markers":
			return "Investigate %d Discovery markers (within %d inches). Each triggers a D6 table result." % [
				obj.get("marker_count", 4), obj.get("investigate_range", 2)]
		"recon_markers":
			return "Recon %d markers in terrain features. Scouts auto-succeed; others: 1D6+Savvy, 5+." % obj.get("marker_count", 6)
		"sweep_objectives":
			return "Sweep Objectives (Resource value count). End round within 3 inches, no enemies closer."
		"science_markers":
			return "Collect samples from %d markers. Scientists auto-succeed; others: 1D6+Savvy, 5+." % obj.get("marker_count", 6)
		"specimen_capture":
			return "Kill 2 Lifeforms, transmit data from each, then escape. (Slyn attack = no specimens.)"
		"patrol_objectives":
			return "Clear 3 Objectives (within 2 inches, no enemies same distance). Can clear multiple per round."
		"skirmish_objectives":
			return "Complete 2 random Skirmish Objectives (D6 each). Carry items, complete conditions, evacuate."
		"rescue_colonists":
			return "Save 3 colonists by escorting them off any table edge."
		"rescue_scout":
			return "Rescue downed scout off any edge. Scout is injured (move OR act, not both)."
		"delve_devices":
			return "Activate 3 of 4 Delve Devices to unlock Artifact location. Each requires base contact + D6 check."
		_:
			return obj_type.replace("_", " ").capitalize()


func _format_rewards(mission: Dictionary) -> String:
	var rewards: Array = mission.get("rewards", [])
	var detail: String = mission.get("rewards_detail", "")
	if not detail.is_empty():
		return detail
	if not rewards.is_empty():
		return "\n".join(rewards)
	return "No special rewards."


func _on_confirm_pressed() -> void:
	if _confirm_btn:
		_confirm_btn.disabled = true

	var forces: Dictionary = _selected_mission.get("player_forces", {})
	var force_limits: Dictionary = {
		"max_characters": forces.get("max_characters", 6),
		"max_grunts": forces.get("max_grunts", 0),
		"grunt_fireteams": forces.get("grunt_fireteams", 0)
	}

	# Generate battlefield condition if mission uses them
	var active_condition: Dictionary = {}
	var has_conditions: bool = _selected_mission.get(
		"battlefield_conditions", false)
	if has_conditions and _condition_sys and _campaign:
		var slot_roll: int = randi_range(1, 100)
		var slot: int = _condition_sys.get_slot_for_roll(slot_roll)
		if slot >= 0:
			var cond_roll: int = randi_range(1, 100)
			active_condition = _condition_sys.fill_condition_slot(
				_campaign, slot, cond_roll)

	# Check Slyn aggression for missions with slyn_check opposition
	var slyn_attacking: bool = false
	var opposition: Dictionary = _selected_mission.get("opposition", {})
	var opp_type: String = opposition.get("type", "")
	if opp_type == "slyn_check" and _mission_setup:
		var mid: String = _selected_mission.get("id", "")
		var aggro_roll: int = randi_range(1, 6) + randi_range(1, 6)
		slyn_attacking = _mission_setup.check_slyn_aggression(
			mid, aggro_roll)

	phase_completed.emit({
		"selected_mission": _selected_mission,
		"force_limits": force_limits,
		"battlefield_conditions": has_conditions,
		"active_condition": active_condition,
		"uncertain_features": _selected_mission.get(
			"uncertain_features", false),
		"slyn_attacking": slyn_attacking,
		"opposition_type": "slyn" if slyn_attacking else opp_type
	})


## ============================================================================
## HELPERS
## ============================================================================

func _has_tactical_enemies() -> bool:
	if not _campaign or not "tactical_enemies" in _campaign:
		return false
	return not _campaign.tactical_enemies.is_empty()


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
