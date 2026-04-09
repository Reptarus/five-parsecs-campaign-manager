class_name PlanetfallEquipmentPanel
extends Control

## Equipment pool browser — accessible from Dashboard.
## Shows all weapons available to the colony, filtered by tier and class.
## Weapons are NOT individually owned — they come from the colony pool.

const PlanetfallArmoryScript := preload(
	"res://src/core/systems/PlanetfallArmorySystem.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_CYAN := Color("#4FC3F7")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _armory: PlanetfallArmoryScript
var _current_filter: String = "all"  # "all", "standard", "tier_1", "tier_2"

var _content: VBoxContainer
var _filter_row: HBoxContainer
var _weapon_list: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	_armory = PlanetfallArmoryScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	_current_filter = "all"
	_clear_container(_weapon_list)
	_build_weapon_list()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)

	var title := Label.new()
	title.text = "COLONY ARMORY"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var info := Label.new()
	info.text = "Weapons are assigned per mission from the colony pool — not individually owned."
	info.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(info)

	# Filter buttons
	_filter_row = HBoxContainer.new()
	_filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_filter_row.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(_filter_row)

	for filter in ["all", "standard", "tier_1", "tier_2"]:
		var btn := Button.new()
		btn.text = filter.replace("_", " ").capitalize()
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(_on_filter_pressed.bind(filter))
		_filter_row.add_child(btn)

	_weapon_list = VBoxContainer.new()
	_weapon_list.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(_weapon_list)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(160, 48)
	_close_btn.pressed.connect(func(): hide())
	_content.add_child(_close_btn)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## WEAPON LIST
## ============================================================================

func _build_weapon_list() -> void:
	var available: Array = _armory.get_available_weapons(_campaign)
	var all_weapons: Array = _armory.get_all_weapons()
	var available_ids: Array = []
	for w in available:
		if w is Dictionary:
			available_ids.append(w.get("id", ""))

	var weapons_to_show: Array = all_weapons
	if _current_filter != "all":
		weapons_to_show = _armory.get_weapons_by_tier(_current_filter)

	for weapon in weapons_to_show:
		if weapon is not Dictionary:
			continue
		var wid: String = weapon.get("id", "")
		var wname: String = weapon.get("name", "?")
		var tier: String = weapon.get("tier", "standard")
		var is_available: bool = available_ids.has(wid)

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_ELEVATED
		style.border_color = COLOR_SUCCESS if is_available else COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(SPACING_SM)
		card.add_theme_stylebox_override("panel", style)
		_weapon_list.add_child(card)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", SPACING_MD)
		card.add_child(hbox)

		# Name + tier
		var name_vbox := VBoxContainer.new()
		name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_vbox)

		var name_lbl := Label.new()
		name_lbl.text = wname
		name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		name_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_PRIMARY if is_available else COLOR_TEXT_SECONDARY)
		name_vbox.add_child(name_lbl)

		var tier_lbl := Label.new()
		tier_lbl.text = tier.replace("_", " ").capitalize()
		tier_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		tier_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
		name_vbox.add_child(tier_lbl)

		if not is_available:
			var lock := Label.new()
			lock.text = "LOCKED"
			lock.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			lock.add_theme_color_override("font_color", COLOR_DANGER)
			name_vbox.add_child(lock)

		# Stats
		var stats_lbl := Label.new()
		var range_val: Variant = weapon.get("range", 0)
		var shots_val: Variant = weapon.get("shots", 0)
		var dmg: int = weapon.get("damage", 0)
		stats_lbl.text = "R:%s  S:%s  D:%+d" % [str(range_val), str(shots_val), dmg]
		stats_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		stats_lbl.add_theme_color_override("font_color", COLOR_CYAN)
		hbox.add_child(stats_lbl)

		# Traits
		var traits: Array = weapon.get("traits", [])
		if not traits.is_empty():
			var traits_lbl := Label.new()
			traits_lbl.text = ", ".join(traits)
			traits_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			traits_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			traits_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hbox.add_child(traits_lbl)


func _on_filter_pressed(filter: String) -> void:
	_current_filter = filter
	_clear_container(_weapon_list)
	_build_weapon_list()


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
