class_name PlanetfallLockAndLoadPanel
extends Control

## Step 7: Lock and Load — deploy characters and assign equipment.
## Shows roster with deploy toggles, equipment pool, class restrictions.
## Source: Planetfall p.65

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's one completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const PlanetfallArmoryScript := preload(
	"res://src/core/systems/PlanetfallArmorySystem.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const DisplayTextRef := preload("res://src/ui/components/common/DisplayText.gd")
const TOUCH_TARGET_MIN := 48
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _armory: PlanetfallArmoryScript
var _deployed: Dictionary = {}  # character_id → {weapon_id: String}
var _max_deploy: int = 6
var _max_grunts: int = 0
var _grunt_fireteams: int = 0
var _grunts_deployed: int = 0
var _force_limits: Dictionary = {}
var _active_condition: Dictionary = {}
var _opposition_type: String = ""
## The chosen mission's opposition block, so a Slyn-check mission can say when it is decided.
var _opposition: Dictionary = {}
## The chosen mission's type id ("pitched_battle" lifts the p.90 Protests sit-out).
var _mission_id: String = ""
## character_id → its deploy CheckBox, so a refused toggle can be put back.
var _deploy_checks: Dictionary = {}

var _title_label: Label
## Says why the last deploy toggle was refused (p.70 Dispute); hidden otherwise.
var _conflict_label: Label
var _roster_container: VBoxContainer
var _grunt_section: VBoxContainer
var _mission_info_section: VBoxContainer
var _weapon_container: VBoxContainer
var _deploy_count_label: Label
var _grunt_count_label: Label


func _ready() -> void:
	_armory = PlanetfallArmoryScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func set_force_limits(limits: Dictionary) -> void:
	## Called by TurnController with force_limits from MissionPanel result.
	_force_limits = limits
	_max_deploy = limits.get("max_characters", 6)
	_max_grunts = limits.get("max_grunts", 0)
	_grunt_fireteams = limits.get("grunt_fireteams", 0)


func set_mission_context(context: Dictionary) -> void:
	## Called by TurnController with condition/slyn data from MissionPanel.
	_active_condition = context.get("active_condition", {})
	_opposition_type = context.get("opposition_type", "")
	var sel: Variant = context.get("selected_mission", {})
	_mission_id = str((sel as Dictionary).get("id", "")) if sel is Dictionary else ""
	var opp: Variant = (sel as Dictionary).get("opposition", {}) if sel is Dictionary else {}
	_opposition = opp if opp is Dictionary else {}


func refresh() -> void:
	_deployed = {}
	_deploy_checks = {}
	_grunts_deployed = 0
	_clear_container(_roster_container)
	_clear_container(_weapon_container)
	if _grunt_section:
		_clear_container(_grunt_section)
	if _mission_info_section:
		_clear_container(_mission_info_section)
	_build_mission_info()
	_build_roster_list()
	_build_grunt_section()
	_update_deploy_count()


func complete() -> void:
	_on_confirm_pressed()


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
	_title_label.text = "STEP 7: LOCK AND LOAD"
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_deploy_count_label = Label.new()
	_deploy_count_label.text = "Deployed: 0 / %d" % _max_deploy
	_deploy_count_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	_deploy_count_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_deploy_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_deploy_count_label)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.text = "Select characters to deploy and assign weapons from the colony pool. Characters in Sick Bay cannot deploy."
	info.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	info.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(info)

	# Roster section
	var roster_header := Label.new()
	roster_header.text = "ROSTER"
	roster_header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	roster_header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(roster_header)

	_roster_container = VBoxContainer.new()
	_roster_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_roster_container)

	# Mission info section (conditions, slyn warning, opposition)
	_mission_info_section = VBoxContainer.new()
	_mission_info_section.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_mission_info_section)

	# Grunt deployment section (visible only when grunts allowed)
	_grunt_section = VBoxContainer.new()
	_grunt_section.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_grunt_section)

	_grunt_count_label = Label.new()
	_grunt_count_label.text = ""
	_grunt_count_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	_grunt_count_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_grunt_count_label.visible = false
	vbox.add_child(_grunt_count_label)

	# Weapon assignment placeholder
	_weapon_container = VBoxContainer.new()
	_weapon_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_weapon_container)



## ============================================================================
## MISSION INFO (conditions, slyn, opposition)
## ============================================================================

func _build_mission_info() -> void:
	if not _mission_info_section:
		return
	_clear_container(_mission_info_section)

	var has_info: bool = false

	# Active battlefield condition
	if not _active_condition.is_empty():
		has_info = true
		var cond_name: String = _active_condition.get("name", "Unknown")
		var cond_desc: String = _active_condition.get("description", "")
		var resolved: Dictionary = _active_condition.get(
			"resolved_sub_roll", {})
		var sub_desc: String = resolved.get("description", "")
		var full_desc: String = cond_desc
		if not sub_desc.is_empty():
			full_desc += "\n" + sub_desc
		var cond_card := _create_info_card(
			"Battlefield Condition: %s" % cond_name,
			full_desc,
			UIColors.COLOR_AMBER)
		_mission_info_section.add_child(cond_card)

	# Opposition type. A Slyn-check mission is decided AFTER deployment (pp.117/121/125:
	# "After deploying, roll 2D6"), so this screen names the roll instead of its result.
	# ⚠ It used to show "SLYN ATTACKING!" here, rolled a step early.
	if not _opposition_type.is_empty():
		has_info = true
		var opp_text: String = _opposition_type.replace("_", " ").capitalize()
		if _opposition_type == "slyn_check":
			var aggro: Dictionary = _opposition.get("slyn_aggression", {})
			opp_text = "rolled after you deploy. 2D6 %d-%d: the Slyn attack. Otherwise %s." % [
				int(aggro.get("slyn_range_min", 2)), int(aggro.get("slyn_range_max", 4)),
				"Tactical Enemies" if _opposition.get("tactical_fallback", false)
				else "Lifeforms, using Contacts"]
		var opp_lbl := Label.new()
		opp_lbl.text = "Opposition: %s" % opp_text
		opp_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		opp_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
		_mission_info_section.add_child(opp_lbl)

	_mission_info_section.visible = has_info


func _create_info_card(title_text: String, desc_text: String,
		accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_SM)
	card.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)

	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	t.add_theme_color_override("font_color", accent)
	inner.add_child(t)

	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.fit_content = true
	d.scroll_active = false
	d.text = desc_text
	d.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	d.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	inner.add_child(d)

	return card


## ============================================================================
## ROSTER DISPLAY
## ============================================================================

func _build_roster_list() -> void:
	if not _campaign or not "roster" in _campaign:
		return

	for char_dict in _campaign.roster:
		if char_dict is not Dictionary:
			continue
		var cid: String = char_dict.get("id", "")
		var cname: String = char_dict.get("name", "Unknown")
		var cclass: String = char_dict.get("class", "")
		var in_sick_bay: bool = _is_in_sick_bay(cid)
		# p.90 Protests: the chosen trooper sits out this turn unless it is a Pitched
		# Battle. The reason comes from the core, which owns the sit-out record.
		var blocked: String = _campaign.deployment_block_reason(cid, _mission_id) \
				if _campaign.has_method("deployment_block_reason") else ""

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_roster_container.add_child(row)

		# The character's name IS the deploy toggle, so the whole name is the tap
		# target. It used to be a bare 16-px box with the name in a separate Label that
		# did nothing when tapped (Sprint U capture: the box was all but invisible).
		var check := CheckBox.new()
		var status: String = " [SICK BAY]" if in_sick_bay \
				else (" [%s]" % blocked if not blocked.is_empty() else "")
		check.text = "%s (%s)%s%s" % [cname, cclass.capitalize(), status, _note_tags(cid)]
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		check.custom_minimum_size.y = TOUCH_TARGET_MIN
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.disabled = in_sick_bay or not blocked.is_empty()
		check.toggled.connect(_on_deploy_toggled.bind(cid))
		row.add_child(check)
		_deploy_checks[cid] = check

		# Weapon selector
		var weapon_select := OptionButton.new()
		weapon_select.custom_minimum_size = Vector2(260, TOUCH_TARGET_MIN)
		weapon_select.disabled = in_sick_bay
		_populate_weapon_options(weapon_select, cclass)
		weapon_select.item_selected.connect(
			_on_weapon_selected.bind(cid, weapon_select))
		row.add_child(weapon_select)

	_conflict_label = Label.new()
	_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conflict_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	_conflict_label.add_theme_color_override("font_color", COLOR_WARNING)
	_conflict_label.visible = false
	_roster_container.add_child(_conflict_label)


## The Character Event results (pp.70-71) a player must remember at the table.
func _note_tags(cid: String) -> String:
	if not _campaign.has_method("get_character_note"):
		return ""
	var tags: Array[String] = []
	if _campaign.get_character_note(cid, "calibrated", false):
		tags.append("Calibrated: +1 to hit with one weapon this mission")
	if _campaign.get_character_note(cid, "double_xp", false):
		tags.append("Double XP this mission")
	if int(_campaign.get_character_note(cid, "xp_forfeit_turn", -1)) == int(_campaign.campaign_turn):
		tags.append("Earns no XP this turn")
	return "" if tags.is_empty() else " [%s]" % ", ".join(tags)


func _populate_weapon_options(
		option_btn: OptionButton, character_class: String) -> void:
	option_btn.clear()
	var weapons: Array = _armory.get_weapons_for_class(_campaign, character_class)
	for i in range(weapons.size()):
		var w: Dictionary = weapons[i]
		# Whole numbers, an inch mark and words: it printed "Handgun (R:6.0 S:1.0 D:+0)",
		# the JSON floats verbatim (DisplayText exists for exactly this).
		var label: String = "%s · %s\" · %s · Dmg %+d" % [
			w.get("name", "?"),
			DisplayTextRef.number(w.get("range", 0)),
			DisplayTextRef.pluralize(w.get("shots", 0), "shot"),
			int(w.get("damage", 0))
		]
		option_btn.add_item(label, i)
		option_btn.set_item_metadata(i, w.get("id", ""))


func _on_deploy_toggled(toggled: bool, character_id: String) -> void:
	if toggled:
		# p.70 Dispute: the two "cannot both be assigned to the mission next campaign turn
		# unless you are fighting a Pitched Battle". The core owns the dispute record.
		var conflict: String = _campaign.deployment_conflict(
				character_id, _deployed.keys(), _mission_id) \
				if _campaign.has_method("deployment_conflict") else ""
		if not conflict.is_empty():
			var check: Variant = _deploy_checks.get(character_id)
			if check is CheckBox:
				(check as CheckBox).set_pressed_no_signal(false)
			if _conflict_label:
				_conflict_label.text = "%s cannot deploy: %s" % [
						_character_name(character_id), conflict]
				_conflict_label.visible = true
			return
		_deployed[character_id] = {"weapon_id": ""}
	else:
		_deployed.erase(character_id)
	if _conflict_label:
		_conflict_label.visible = false
	_update_deploy_count()


func _character_name(character_id: String) -> String:
	var who: Variant = _campaign.get_roster_character_by_id(character_id) \
			if _campaign.has_method("get_roster_character_by_id") else null
	return str(who.get("name", character_id)) if who is Dictionary else character_id


func _on_weapon_selected(
		idx: int,
		character_id: String,
		option_btn: OptionButton) -> void:
	var weapon_id: String = str(option_btn.get_item_metadata(idx))
	if _deployed.has(character_id):
		_deployed[character_id]["weapon_id"] = weapon_id


func _update_deploy_count() -> void:
	step_status_changed.emit()
	if _deploy_count_label:
		var grunt_text: String = ""
		if _max_grunts > 0:
			grunt_text = "  |  Grunts: %d / %d" % [_grunts_deployed, _max_grunts]
		_deploy_count_label.text = "Characters: %d / %d%s" % [
			_deployed.size(), _max_deploy, grunt_text]

	if _grunt_count_label:
		if _max_grunts > 0:
			var available_grunts: int = _campaign.grunts if _campaign and "grunts" in _campaign else 0
			_grunt_count_label.text = "Colony grunts available: %d" % available_grunts
			_grunt_count_label.visible = true
		else:
			_grunt_count_label.visible = false


func _build_grunt_section() -> void:
	if not _grunt_section:
		return
	_clear_container(_grunt_section)

	if _max_grunts <= 0:
		_grunt_section.visible = false
		return
	_grunt_section.visible = true

	var header := Label.new()
	header.text = "GRUNT FIRETEAMS"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_grunt_section.add_child(header)

	var available: int = _campaign.grunts if _campaign and "grunts" in _campaign else 0
	var per_fireteam: int = 4

	for ft_idx in range(_grunt_fireteams):
		var can_deploy: int = mini(per_fireteam, available - (ft_idx * per_fireteam))
		if can_deploy <= 0:
			break

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_grunt_section.add_child(row)

		var check := CheckBox.new()
		check.text = "Fireteam %d (up to %d grunts)" % [ft_idx + 1, mini(per_fireteam, can_deploy)]
		check.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		check.toggled.connect(_on_grunt_fireteam_toggled.bind(ft_idx, mini(per_fireteam, can_deploy)))
		row.add_child(check)

	var info := Label.new()
	info.text = "Each fireteam deploys up to 4 grunts. Grunts past 4 form a second team."
	info.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
	info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grunt_section.add_child(info)


func _on_grunt_fireteam_toggled(toggled: bool, ft_idx: int, count: int) -> void:
	if toggled:
		_grunts_deployed += count
	else:
		_grunts_deployed = maxi(0, _grunts_deployed - count)
	_update_deploy_count()


## What the turn screen's footer shows for this step. A battle needs someone on the
## table; deploying nobody used to be accepted. When no character CAN deploy (all in
## Sick Bay or blocked) and no grunts are offered, the step stays finishable so the turn
## cannot lock.
func step_status() -> Dictionary:
	if _deployed.size() + _grunts_deployed > 0:
		return {"ready": true, "reason": "", "label": "Deploy %d for the Mission" % (
				_deployed.size() + _grunts_deployed)}
	var can_pick: bool = _max_grunts > 0
	for c in find_children("*", "CheckBox", true, false):
		if not (c as CheckBox).disabled:
			can_pick = true
	if not can_pick:
		return {"ready": true, "reason": ""}
	return {"ready": false, "reason": "Pick at least one character or grunt fireteam above."}


func _on_confirm_pressed() -> void:
	phase_completed.emit({
		"deployed_characters": _deployed.duplicate(true),
		"deploy_count": _deployed.size(),
		"grunts_deployed": _grunts_deployed,
		"grunt_fireteams": _grunt_fireteams if _grunts_deployed > 0 else 0,
		"force_limits": _force_limits
	})


## ============================================================================
## HELPERS
## ============================================================================

func _is_in_sick_bay(character_id: String) -> bool:
	if not _campaign or not "sick_bay" in _campaign:
		return false
	return _campaign.sick_bay.has(character_id) and _campaign.sick_bay[character_id] > 0


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
