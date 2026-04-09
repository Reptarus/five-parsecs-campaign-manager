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
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _armory: PlanetfallArmoryScript
var _deployed: Dictionary = {}  # character_id → {weapon_id: String}
var _max_deploy: int = 6

var _title_label: Label
var _roster_container: VBoxContainer
var _weapon_container: VBoxContainer
var _deploy_count_label: Label
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


func refresh() -> void:
	_deployed = {}
	_clear_container(_roster_container)
	_clear_container(_weapon_container)
	_build_roster_list()
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
		_deploy_count_label.text = "Deployed: %d / %d" % [
			_deployed.size(), _max_deploy]


func _on_confirm_pressed() -> void:
	if _confirm_btn:
		_confirm_btn.disabled = true
	phase_completed.emit({
		"deployed_characters": _deployed.duplicate(true),
		"deploy_count": _deployed.size()
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
