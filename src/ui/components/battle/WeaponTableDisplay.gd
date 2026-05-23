class_name FPCM_WeaponTableDisplay
extends PanelContainer

## Weapon Table Display Panel
##
## Quick reference card for weapon stats during tabletop play.
## Shows weapon stats with filtering and search capabilities.

const WeaponTableSystem = preload("res://src/core/battle/WeaponTableSystem.gd")
const FiveParsecsCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")
# Preload-based ref bypasses the global class_name cache (which can be stale
# until the editor reopens — see CLAUDE.md "Preload Pattern for UI Class
# References"). Sprint 2 F4 MCP verification surfaced a parse error caused by
# the cache missing KeywordLinker.
const KeywordLinker = preload("res://src/ui/components/tooltips/KeywordLinker.gd")

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
var _keyword_tooltip: KeywordTooltip = null  # Lazy-instantiated for clickable trait popovers

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

	# Header row
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 28
	var col_defs := [
		{"text": "WEAPON", "width": 140},
		{"text": "RANGE", "width": 50},
		{"text": "SHOTS", "width": 30},
		{"text": "DMG", "width": 30},
		{"text": "TRAITS", "width": 120},
	]
	for col in col_defs:
		var lbl := Label.new()
		lbl.text = col["text"]
		lbl.custom_minimum_size.x = col["width"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_MUTED)
		header.add_child(lbl)
	weapon_list.add_child(header)

	var sep := HSeparator.new()
	weapon_list.add_child(sep)

	# Weapon entries
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
	range_label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
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
		dmg_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	container.add_child(dmg_label)

	# Traits — clickable keyword links so players can pop the rule for
	# "Pistol", "Heavy", "Area", etc. without leaving the table.
	if weapon.traits.is_empty():
		var traits_dash := Label.new()
		traits_dash.text = "-"
		traits_dash.custom_minimum_size.x = 120
		traits_dash.add_theme_font_size_override("font_size", 12)
		traits_dash.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_MUTED)
		container.add_child(traits_dash)
	else:
		var traits_rtl := RichTextLabel.new()
		traits_rtl.bbcode_enabled = true
		traits_rtl.fit_content = true
		traits_rtl.scroll_active = false
		traits_rtl.text = KeywordLinker.build_traits_bbcode(weapon.traits)
		traits_rtl.custom_minimum_size.x = 120
		traits_rtl.add_theme_font_size_override("normal_font_size", 12)
		traits_rtl.add_theme_color_override("default_color", Color.GOLD)
		KeywordLinker.attach(traits_rtl, _ensure_keyword_tooltip())
		container.add_child(traits_rtl)

	return container

## Lazy-instantiate the shared keyword tooltip used by trait popovers.
func _ensure_keyword_tooltip() -> KeywordTooltip:
	if _keyword_tooltip == null:
		_keyword_tooltip = KeywordTooltip.new()
		add_child(_keyword_tooltip)
	return _keyword_tooltip

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
			# Trait name is a clickable KeywordDB link (Sprint 2 F3).
			var trait_link: String = KeywordLinker.build_keyword_link(trait_name)
			var trait_desc: String = _get_trait_description(trait_name)
			text += "  %s: %s\n" % [trait_link, trait_desc]

	details_label.bbcode_enabled = true
	details_label.text = text
	# Wire details_label clicks to the shared KeywordTooltip.
	KeywordLinker.attach(details_label, _ensure_keyword_tooltip())

## Trait description via KeywordDB autoload (Sprint 2 F3).
## Replaces the previously hardcoded p.51 trait table — KeywordDB is now the
## single source of truth. Handles space → underscore for multi-word trait
## keys ("Single use" → single_use, "Snap Shot" → snap_shot).
func _get_trait_description(trait_name: String) -> String:
	var kdb: Node = get_node_or_null("/root/KeywordDB")
	if kdb == null or not kdb.has_method("get_keyword"):
		return trait_name  # Autoload missing — fall back to raw name
	var lookup: String = trait_name.strip_edges()
	var entry: Dictionary = kdb.get_keyword(lookup)
	if str(entry.get("category", "")) == "unknown":
		# Try underscored variant ("Single use" → single_use).
		lookup = lookup.replace(" ", "_")
		entry = kdb.get_keyword(lookup)
	var def: String = str(entry.get("definition", ""))
	if def.is_empty() or str(entry.get("category", "")) == "unknown":
		return trait_name
	return def

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
