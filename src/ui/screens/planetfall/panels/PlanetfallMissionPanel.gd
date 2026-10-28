class_name PlanetfallMissionPanel
extends Control

## Step 6: Mission Determination — select mission type for this turn.
## 13 mission types loaded from mission_types.json.
## Source: Planetfall pp.64-65, 114-133
##
## Each mission is played in a sector its Map Location names (pp.115-130), and
## PlanetfallMap.mission_availability() is the one reader of that rule. Until 2026-10-28
## this screen offered every mission with no map, so no sector was ever stamped and
## PlanetfallMap.apply_mission_factors() received none: an Investigation never cleared its
## site, a Scouting Mission explored nothing and a Skirmish captured nothing. Delve,
## Rescue, Scout Down! and the Pitched Battle were always offered, whatever had happened.

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's one completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

const PlanetfallConditionScript := preload(
	"res://src/core/systems/PlanetfallConditionSystem.gd")
const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const SectorGridScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

var _campaign: Resource
var _phase_manager: Node
var _missions: Array = []
var _selected_mission: Dictionary = {}
## The sector picked for the selected mission: {key, enemy_index, label}, or {}.
var _selected_site: Dictionary = {}
## mission id -> {available, reason, sites}, computed once per refresh.
var _availability: Dictionary = {}
var _condition_sys: PlanetfallConditionScript
var _scroll: ScrollContainer
var _columns: BoxContainer
var _site_grid: Control
var _site_label: Label

var _title_label: Label
var _list_container: VBoxContainer
var _detail_container: VBoxContainer


func _ready() -> void:
	_condition_sys = PlanetfallConditionScript.new()
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
	_selected_site = {}
	_site_grid = null
	_site_label = null
	_clear_container(_list_container)
	_clear_container(_detail_container)
	_fit_columns()
	_build_mission_list()
	TouchScrollOpenerRef.open_subtree(self)
	step_status_changed.emit()


## Two columns (list | briefing) on a tablet; stacked on a phone, where two 160 px
## columns squeezed every mission name and briefing.
func _fit_columns() -> void:
	if not _columns:
		return
	var rm: Node = get_node_or_null("/root/ResponsiveManager")
	_columns.vertical = rm != null and rm.has_method("should_collapse_to_single_column") \
			and rm.should_collapse_to_single_column()


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

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	_scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 6: MISSION DETERMINATION"
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Two-column layout: mission list + detail (stacked on a phone, _fit_columns)
	_columns = BoxContainer.new()
	_columns.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(_columns)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", SPACING_SM)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(_list_container)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", SPACING_SM)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(_detail_container)



## ============================================================================
## MISSION LIST
## ============================================================================

func _build_mission_list() -> void:
	var header := Label.new()
	header.text = "Available Missions"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_list_container.add_child(header)

	# p.63 Hostile wildlife, accepted at Step 5: the cost of any other mission is paid
	# when this step completes (PlanetfallPhaseManager._settle_patrol_commitment).
	if _campaign and "patrol_required_turn" in _campaign \
			and int(_campaign.patrol_required_turn) == int(_campaign.campaign_turn):
		var note := Label.new()
		note.text = "Hostile wildlife: play a Patrol Mission this turn, or Colony Morale -2."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		note.add_theme_color_override("font_color", COLOR_WARNING)
		_list_container.add_child(note)

	_availability = {}
	for mission in _missions:
		if mission is not Dictionary:
			continue
		var mid: String = mission.get("id", "")
		var avail: Dictionary = MapScript.mission_availability(_campaign, mission)
		_availability[mid] = avail

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_list_container.add_child(row)

		var btn := Button.new()
		btn.text = mission.get("name", "Unknown")
		btn.custom_minimum_size.y = 44
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not bool(avail.available)
		btn.pressed.connect(_on_mission_selected.bind(mission))
		row.add_child(btn)

		# What the mission is, and -- a phone has no hover -- why it is greyed out.
		row.add_child(_small_label(_summary(mission), COLOR_TEXT_SECONDARY))
		if not bool(avail.available):
			row.add_child(_small_label(str(avail.reason), COLOR_WARNING))


## The mission's first sentence, as the list's one-line summary.
static func _summary(mission: Dictionary) -> String:
	var desc: String = str(mission.get("description", ""))
	var stop: int = desc.find(". ")
	return desc.substr(0, stop + 1) if stop >= 0 else desc


func _small_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _on_mission_selected(mission: Dictionary) -> void:
	_selected_mission = mission
	var sites: Array = _sites_for(mission)
	# One possible sector is no choice; pick it rather than ask.
	_selected_site = sites[0] if sites.size() == 1 else {}
	_show_mission_detail(mission)
	step_status_changed.emit()
	if _columns and _columns.vertical and _scroll:
		_scroll.ensure_control_visible.call_deferred(_detail_container)


func _sites_for(mission: Dictionary) -> Array:
	return (_availability.get(str(mission.get("id", "")), {}) as Dictionary).get("sites", [])


func _on_site_picked(sector_key: String) -> void:
	for site in _sites_for(_selected_mission):
		if str(site.key) == sector_key:
			_selected_site = site
	_update_site_label()
	step_status_changed.emit()


func _update_site_label() -> void:
	if not _site_label:
		return
	_site_label.text = "Mission sector: %s" % str(_selected_site.label) \
			if not _selected_site.is_empty() else "Tap a highlighted sector for this mission."


func _show_mission_detail(mission: Dictionary) -> void:
	_clear_container(_detail_container)

	# Mission name
	var name_lbl := Label.new()
	name_lbl.text = mission.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	# Category + table size
	var cat_text: String = "%s  |  Table: %s ft" % [
		mission.get("category", "").capitalize(),
		mission.get("table_size", "3x3")]
	var cat_lbl := Label.new()
	cat_lbl.text = cat_text
	cat_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	cat_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(cat_lbl)

	# Description
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = mission.get("description", "")
	desc.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
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
		cond_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
		cond_lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_detail_container.add_child(cond_lbl)

	_add_site_section(mission)

	# Page reference
	var page_lbl := Label.new()
	page_lbl.text = "Rulebook: p.%d" % mission.get("page", 0)
	page_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
	page_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(page_lbl)


## Where the mission is played: the colony map with only its Map Location's sectors
## pickable (pp.115-130).
func _add_site_section(mission: Dictionary) -> void:
	var sites: Array = _sites_for(mission)
	if sites.is_empty() or not _campaign:
		return
	var head := Label.new()
	head.text = "Mission Sector"
	head.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	head.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(head)
	var keys: Array = []
	for site in sites:
		keys.append(str(site.key))
	_site_grid = SectorGridScript.new()
	_detail_container.add_child(_site_grid)
	_site_grid.configure(_campaign, keys, str(_selected_site.get("key", "")))
	_site_grid.sector_selected.connect(_on_site_picked)
	_site_label = Label.new()
	_site_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_site_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	_site_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(_site_label)
	_update_site_label()


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
	title_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	title_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	inner.add_child(title_lbl)

	var content_lbl := RichTextLabel.new()
	content_lbl.bbcode_enabled = true
	content_lbl.fit_content = true
	content_lbl.scroll_active = false
	content_lbl.text = content
	content_lbl.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_XS))
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


## What the turn screen's footer shows for this step: it confirms the mission picked.
func step_status() -> Dictionary:
	if _selected_mission.is_empty():
		return {"ready": false, "reason": "Pick a mission above."}
	if _selected_site.is_empty() and not _sites_for(_selected_mission).is_empty():
		return {"ready": false, "reason": "Pick the mission's sector on the map."}
	return {"ready": true, "reason": "",
		"label": "Confirm %s" % str(_selected_mission.get("name", "Mission"))}


func _on_confirm_pressed() -> void:
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
		active_condition = _condition_sys.roll_mission_condition(_campaign)

	# The Slyn check is NOT rolled here. pp.117/121/125: "After deploying, roll 2D6." It
	# used to be rolled at this step, so Lock and Load announced "SLYN ATTACKING!" before
	# the player chose who to deploy. PlanetfallBattleGuide.resolve_opposition() rolls it
	# at battle launch, after Lock and Load.
	var opposition: Dictionary = _selected_mission.get("opposition", {})
	var opp_type: String = opposition.get("type", "")

	# The sector rides on the mission into the battle stamp, where Step 12's
	# PlanetfallMap.apply_mission_factors() reads it back as the result's `sector`.
	var chosen: Dictionary = _selected_mission.duplicate(true)
	chosen["sector"] = str(_selected_site.get("key", ""))
	chosen["site_enemy_index"] = int(_selected_site.get("enemy_index", -1))
	phase_completed.emit({
		"selected_mission": chosen,
		"force_limits": force_limits,
		"battlefield_conditions": has_conditions,
		"active_condition": active_condition,
		"uncertain_features": _selected_mission.get(
			"uncertain_features", false),
		"opposition_type": opp_type
	})


## ============================================================================
## HELPERS
## ============================================================================

func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
