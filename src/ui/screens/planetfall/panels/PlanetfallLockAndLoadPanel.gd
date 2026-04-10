class_name PlanetfallLockAndLoadPanel
extends Control

## Step 7: Lock and Load — deploy characters and assign equipment.
## Shows roster with deploy toggles, equipment pool, class restrictions.
## Source: Planetfall p.65

signal phase_completed(result_data: Dictionary)

const PlanetfallArmoryScript := preload(
	"res://src/core/systems/PlanetfallArmorySystem.gd")

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
var _slyn_attacking: bool = false
var _opposition_type: String = ""

var _title_label: Label
var _roster_container: VBoxContainer
var _grunt_section: VBoxContainer
var _mission_info_section: VBoxContainer
var _weapon_container: VBoxContainer
var _deploy_count_label: Label
var _grunt_count_label: Label
var _confirm_btn: Button


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
	_slyn_attacking = context.get("slyn_attacking", false)
	_opposition_type = context.get("opposition_type", "")


func refresh() -> void:
	_deployed = {}
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
	if _confirm_btn:
		_confirm_btn.disabled = false


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
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_deploy_count_label = Label.new()
	_deploy_count_label.text = "Deployed: 0 / %d" % _max_deploy
	_deploy_count_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_deploy_count_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_deploy_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_deploy_count_label)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.text = "Select characters to deploy and assign weapons from the colony pool. Characters in Sick Bay cannot deploy."
	info.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	info.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(info)

	# Roster section
	var roster_header := Label.new()
	roster_header.text = "ROSTER"
	roster_header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
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
	_grunt_count_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_grunt_count_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_grunt_count_label.visible = false
	vbox.add_child(_grunt_count_label)

	# Weapon assignment placeholder
	_weapon_container = VBoxContainer.new()
	_weapon_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_weapon_container)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Deploy for Mission"
	_confirm_btn.custom_minimum_size = Vector2(220, 48)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_btn)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## MISSION INFO (conditions, slyn, opposition)
## ============================================================================

func _build_mission_info() -> void:
	if not _mission_info_section:
		return
	_clear_container(_mission_info_section)

	var has_info: bool = false

	# Slyn warning
	if _slyn_attacking:
		has_info = true
		var slyn_card := _create_info_card(
			"SLYN ATTACKING!",
			"The Slyn have been detected. You will fight Slyn " +
			"pairs instead of the regular opposition. Prepare " +
			"for beam focus weapons and short-range distortion.",
			Color("#DC2626"))
		_mission_info_section.add_child(slyn_card)

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
			Color("#D97706"))
		_mission_info_section.add_child(cond_card)

	# Opposition type
	if not _opposition_type.is_empty() and not _slyn_attacking:
		has_info = true
		var opp_text: String = _opposition_type.replace("_", " ").capitalize()
		var opp_lbl := Label.new()
		opp_lbl.text = "Opposition: %s" % opp_text
		opp_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
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
	t.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	t.add_theme_color_override("font_color", accent)
	inner.add_child(t)

	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.fit_content = true
	d.scroll_active = false
	d.text = desc_text
	d.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
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

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_roster_container.add_child(row)

		# Deploy checkbox
		var check := CheckBox.new()
		check.text = ""
		check.disabled = in_sick_bay
		check.toggled.connect(_on_deploy_toggled.bind(cid))
		row.add_child(check)

		# Name + class
		var name_lbl := Label.new()
		var status: String = " [SICK BAY]" if in_sick_bay else ""
		name_lbl.text = "%s (%s)%s" % [cname, cclass.capitalize(), status]
		name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		name_lbl.add_theme_color_override(
			"font_color",
			COLOR_TEXT_SECONDARY if in_sick_bay else COLOR_TEXT_PRIMARY)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Weapon selector
		var weapon_select := OptionButton.new()
		weapon_select.custom_minimum_size.x = 180
		weapon_select.disabled = in_sick_bay
		_populate_weapon_options(weapon_select, cclass)
		weapon_select.item_selected.connect(
			_on_weapon_selected.bind(cid, weapon_select))
		row.add_child(weapon_select)


func _populate_weapon_options(
		option_btn: OptionButton, character_class: String) -> void:
	option_btn.clear()
	var weapons: Array = _armory.get_weapons_for_class(_campaign, character_class)
	for i in range(weapons.size()):
		var w: Dictionary = weapons[i]
		var label: String = "%s (R:%s S:%s D:%+d)" % [
			w.get("name", "?"),
			str(w.get("range", 0)),
			str(w.get("shots", 0)),
			w.get("damage", 0)
		]
		option_btn.add_item(label, i)
		option_btn.set_item_metadata(i, w.get("id", ""))


func _on_deploy_toggled(toggled: bool, character_id: String) -> void:
	if toggled:
		_deployed[character_id] = {"weapon_id": ""}
	else:
		_deployed.erase(character_id)
	_update_deploy_count()


func _on_weapon_selected(
		idx: int,
		character_id: String,
		option_btn: OptionButton) -> void:
	var weapon_id: String = str(option_btn.get_item_metadata(idx))
	if _deployed.has(character_id):
		_deployed[character_id]["weapon_id"] = weapon_id


func _update_deploy_count() -> void:
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
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
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
		check.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		check.toggled.connect(_on_grunt_fireteam_toggled.bind(ft_idx, mini(per_fireteam, can_deploy)))
		row.add_child(check)

	var info := Label.new()
	info.text = "Each fireteam deploys up to 4 grunts. Grunts past 4 form a second team."
	info.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grunt_section.add_child(info)


func _on_grunt_fireteam_toggled(toggled: bool, ft_idx: int, count: int) -> void:
	if toggled:
		_grunts_deployed += count
	else:
		_grunts_deployed = maxi(0, _grunts_deployed - count)
	_update_deploy_count()


func _on_confirm_pressed() -> void:
	if _confirm_btn:
		_confirm_btn.disabled = true
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
