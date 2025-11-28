class_name FPCM_WeaponTableDisplay
extends PanelContainer

## Weapon Table Display Panel
##
## Quick reference card for weapon stats during tabletop play.
## Shows weapon stats with filtering and search capabilities.

const WeaponTableSystem = preload("res://src/core/battle/WeaponTableSystem.gd")
const FiveParsecsCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

# Signals
signal weapon_selected(weapon_data: WeaponTableSystem.WeaponData)

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var search_box: LineEdit = $VBox/SearchBox
@onready var category_tabs: TabBar = $VBox/CategoryTabs
@onready var weapon_list: VBoxContainer = $VBox/ScrollContainer/WeaponList
@onready var details_panel: PanelContainer = $VBox/DetailsPanel
@onready var details_label: RichTextLabel = $VBox/DetailsPanel/DetailsLabel

# System
var weapon_system: WeaponTableSystem
var current_category: String = "all"
var selected_weapon: WeaponTableSystem.WeaponData

func _ready() -> void:
	weapon_system = WeaponTableSystem.new()
	_setup_panel_style()
	_setup_category_tabs()
	_setup_search()
	_populate_weapon_list()

	if details_panel:
		details_panel.hide()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = FiveParsecsCampaignPanel.COLOR_ELEVATED  # Design system: card backgrounds
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_width_left = 3  # Accent border (weapon table indicator)
	style.border_color = Color.GOLD  # Keep gold accent for weapon specialty
	style.set_content_margin_all(FiveParsecsCampaignPanel.SPACING_SM)  # Design system: 8px
	add_theme_stylebox_override("panel", style)

func _setup_category_tabs() -> void:
	if not category_tabs:
		return

	category_tabs.clear_tabs()
	category_tabs.add_tab("All")
	category_tabs.add_tab("Pistols")
	category_tabs.add_tab("Rifles")
	category_tabs.add_tab("Heavy")
	category_tabs.add_tab("Melee")
	category_tabs.add_tab("Special")

	category_tabs.tab_changed.connect(_on_category_changed)

func _setup_search() -> void:
	if search_box:
		search_box.placeholder_text = "Search weapons..."
		search_box.text_changed.connect(_on_search_changed)

func _populate_weapon_list() -> void:
	if not weapon_list:
		return

	# Clear existing
	for child in weapon_list.get_children():
		child.queue_free()

	var weapons: Array[WeaponTableSystem.WeaponData] = []

	# Get weapons based on category
	if current_category == "all":
		weapons = weapon_system.get_all_weapons()
	else:
		weapons = weapon_system.get_weapons_by_category(current_category)

	# Apply search filter
	if search_box and not search_box.text.is_empty():
		var search_term := search_box.text.to_lower()
		var filtered: Array[WeaponTableSystem.WeaponData] = []
		for weapon in weapons:
			if weapon.name.to_lower().contains(search_term):
				filtered.append(weapon)
		weapons = filtered

	# Sort by name
	weapons.sort_custom(func(a, b): return a.name < b.name)

	# Create weapon entries
	for weapon in weapons:
		var entry := _create_weapon_entry(weapon)
		weapon_list.add_child(entry)

func _create_weapon_entry(weapon: WeaponTableSystem.WeaponData) -> Control:
	var container := HBoxContainer.new()
	container.custom_minimum_size.y = 48  # TOUCH_TARGET_MIN (mobile-first design)

	# Weapon name button
	var name_btn := Button.new()
	name_btn.text = weapon.name
	name_btn.flat = true
	name_btn.custom_minimum_size.x = 140
	name_btn.custom_minimum_size.y = 48  # Explicit touch target
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.pressed.connect(_on_weapon_clicked.bind(weapon))
	container.add_child(name_btn)

	# Range
	var range_label := Label.new()
	range_label.text = weapon.get_range_text()
	range_label.custom_minimum_size.x = 50
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	container.add_child(range_label)

	# Shots
	var shots_label := Label.new()
	shots_label.text = str(weapon.shots)
	shots_label.custom_minimum_size.x = 30
	shots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shots_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	container.add_child(shots_label)

	# Damage
	var dmg_label := Label.new()
	dmg_label.text = "+%d" % weapon.damage_bonus if weapon.damage_bonus > 0 else "-"
	dmg_label.custom_minimum_size.x = 30
	dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if weapon.damage_bonus > 0:
		dmg_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		dmg_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	container.add_child(dmg_label)

	# Traits indicator
	var traits_label := Label.new()
	traits_label.text = "*" if not weapon.traits.is_empty() else ""
	traits_label.custom_minimum_size.x = 20
	traits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	traits_label.add_theme_color_override("font_color", Color.GOLD)
	container.add_child(traits_label)

	return container

func _on_category_changed(tab_index: int) -> void:
	match tab_index:
		0: current_category = "all"
		1: current_category = "pistol"
		2: current_category = "rifle"
		3: current_category = "heavy"
		4: current_category = "melee"
		5: current_category = "special"
		_: current_category = "all"

	_populate_weapon_list()

func _on_search_changed(_new_text: String) -> void:
	_populate_weapon_list()

func _on_weapon_clicked(weapon: WeaponTableSystem.WeaponData) -> void:
	selected_weapon = weapon
	_show_weapon_details(weapon)
	weapon_selected.emit(weapon)

func _show_weapon_details(weapon: WeaponTableSystem.WeaponData) -> void:
	if not details_panel or not details_label:
		return

	details_panel.show()

	var text := "[b][font_size=16]%s[/font_size][/b]\n\n" % weapon.name
	text += "[color=gray]%s[/color]\n\n" % weapon.description

	text += "[b]Stats:[/b]\n"
	text += "  Range: %s\n" % weapon.get_range_text()
	text += "  Shots: %d\n" % weapon.shots
	text += "  Damage: +%d\n" % weapon.damage_bonus

	if not weapon.traits.is_empty():
		text += "\n[b]Traits:[/b]\n"
		for trait_name in weapon.traits:
			var trait_desc := _get_trait_description(trait_name)
			text += "  [color=gold]%s[/color]: %s\n" % [trait_name, trait_desc]

	details_label.bbcode_enabled = true
	details_label.text = text

func _get_trait_description(trait_name: String) -> String:
	match trait_name:
		"Critical": return "+1 to Injury roll"
		"Piercing": return "Ignores armor saves"
		"Area": return "Hits all in blast radius"
		"Burn": return "Target catches fire on hit"
		"Heavy": return "Requires both actions to fire"
		"Stabilize": return "Must set up before firing"
		"Melee": return "Close combat only"
		"Natural": return "Cannot be disarmed"
		"Clumsy": return "-1 to hit in melee"
		"Elegant": return "+1 to hit in melee"
		"Stun": return "Target is Stunned"
		"Blind": return "Target cannot shoot this round"
		"Overheat": return "Roll 1 = weapon disabled"
		"Silent": return "No alert generated"
		"Focused": return "+1 at close range"
		"Smoke": return "Blocks line of sight"
		"Grenade": return "Thrown once per battle"
		_: return "Special trait"

## Show specific weapon by ID
func show_weapon(weapon_id: String) -> void:
	var weapon := weapon_system.get_weapon(weapon_id)
	if weapon:
		_on_weapon_clicked(weapon)

## Roll random weapon for enemy type
func roll_enemy_weapon(enemy_type: String) -> WeaponTableSystem.WeaponData:
	var weapon := weapon_system.roll_enemy_weapon(enemy_type)
	if weapon:
		_on_weapon_clicked(weapon)
	return weapon

## Get selected weapon
func get_selected_weapon() -> WeaponTableSystem.WeaponData:
	return selected_weapon
