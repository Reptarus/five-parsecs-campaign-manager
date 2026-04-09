# Character Details Screen - View and Edit Individual Character
# Allows editing character properties and equipment
class_name CharacterDetailsScreen
extends Control

# ============ PRELOADS ============
const CharacterCard = preload("res://src/ui/components/character/CharacterCard.gd")
const CharacterHistoryPanelClass = preload(
	"res://src/ui/components/history/CharacterHistoryPanel.gd")
const CharacterEventTimelineClass = preload(
	"res://src/ui/components/character/CharacterEventTimeline.gd")
const EquipmentTransferServiceRef = preload(
	"res://src/core/equipment/EquipmentTransferService.gd")

# ============ DESIGN SYSTEM CONSTANTS ============
# Unified styling from BaseCampaignPanel

## Spacing System (8px grid)
const SPACING_XS := 4   # Icon padding, label-to-input gap
const SPACING_SM := 8   # Element gaps within cards
const SPACING_MD := 16  # Inner card padding
const SPACING_LG := 24  # Section gaps between cards
const SPACING_XL := 32  # Panel edge padding

## Touch Target Minimums
const TOUCH_TARGET_MIN := 48      # Minimum interactive element height
const TOUCH_TARGET_COMFORT := 56  # Comfortable input height

## Typography Sizes
const FONT_SIZE_XS := 11  # Captions, limits
const FONT_SIZE_SM := 14  # Descriptions, helpers
const FONT_SIZE_MD := 16  # Body text, inputs
const FONT_SIZE_LG := 18  # Section headers
const FONT_SIZE_XL := 24  # Panel titles

## Color Palette - Deep Space Theme
const COLOR_BASE := Color("#1A1A2E")         # Panel background
const COLOR_ELEVATED := Color("#252542")     # Card backgrounds
const COLOR_INPUT := Color("#1E1E36")        # Form field backgrounds
const COLOR_BORDER := Color("#3A3A5C")       # Card borders
const COLOR_ACCENT := Color("#2D5A7B")       # Primary accent (Deep Space Blue)
const COLOR_ACCENT_HOVER := Color("#3A7199") # Hover state
const COLOR_FOCUS := Color("#4FC3F7")        # Focus ring (cyan)

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")   # Main content
const COLOR_TEXT_SECONDARY := Color("#808080") # Descriptions
const COLOR_TEXT_DISABLED := Color("#404040")  # Inactive

const COLOR_SUCCESS := Color("#10B981")  # Green
const COLOR_WARNING := Color("#D97706")  # Orange
const COLOR_DANGER := Color("#DC2626")   # Red

# UI Node References - using %NodeName for maintainability
@onready var hero_card: Control = %HeroCard
@onready var xp_label: Label = %XPLabel
@onready var xp_progress_bar: ProgressBar = %XPProgressBar
@onready var character_info_container: VBoxContainer = %InfoContainer
@onready var stats_grid: GridContainer = %StatsGrid
@onready var equipment_rich_text: RichTextLabel = %EquipmentRichText
@onready var add_equipment_button: Button = %AddEquipmentButton
@onready var remove_equipment_button: Button = %RemoveEquipmentButton
@onready var notes_edit: TextEdit = %NotesEdit
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
@onready var keyword_tooltip: KeywordTooltip = %KeywordTooltip
@onready var advancement_section: VBoxContainer = %AdvancementSection
@onready var char_info_panel: PanelContainer = %CharacterInfoPanel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var equipment_panel: PanelContainer = %EquipmentPanel
@onready var notes_panel: PanelContainer = %NotesPanel

# State
var current_character = null
var original_data: Dictionary = {}
var _history_overlay: Control = null
var _equipment_db_cache: Dictionary = {}

# Advancement UI references (created dynamically)
var stat_advancement_buttons: Dictionary = {}
var training_purchase_buttons: Dictionary = {}

# Crew swipe navigation
var _crew_list: Array[Dictionary] = []
var _current_index: int = 0
var _touch_start: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _page_dots_container: HBoxContainer = null

func _ready() -> void:

	# Connect button signals
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if add_equipment_button:
		add_equipment_button.pressed.connect(_on_add_equipment_pressed)
	if remove_equipment_button:
		remove_equipment_button.pressed.connect(_on_remove_equipment_pressed)

	# Connect keyword tooltip
	if equipment_rich_text and keyword_tooltip:
		equipment_rich_text.meta_clicked.connect(_on_equipment_keyword_clicked)

	# Style XP progress bar
	if xp_progress_bar:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_INPUT
		style.set_corner_radius_all(4)
		xp_progress_bar.add_theme_stylebox_override("background", style)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = COLOR_SUCCESS  # Green for XP progress
		fill_style.set_corner_radius_all(4)
		xp_progress_bar.add_theme_stylebox_override("fill", fill_style)

	# Apply visual polish (buttons, panels, stat badges, headers, notes)
	_apply_ui_styling()

	# Sprint 26.9 Phase 8.3: Connect viewport resize for responsive stats grid
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_responsive_stats_grid()

	# Load character data
	load_character_data()


func _apply_ui_styling() -> void:
	## Apply Deep Space theme polish to all UI elements.
	## Patterns sourced from ConfirmationDialog.gd and CharacterCard.gd.

	# -- Save button: primary green (ConfirmationDialog confirm pattern)
	if save_button:
		var s := StyleBoxFlat.new()
		s.bg_color = COLOR_SUCCESS
		s.set_corner_radius_all(6)
		s.set_content_margin_all(SPACING_SM)
		save_button.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = COLOR_ACCENT_HOVER
		save_button.add_theme_stylebox_override("hover", h)

	# -- Cancel button: subdued border (ConfirmationDialog cancel pattern)
	if cancel_button:
		var s := StyleBoxFlat.new()
		s.bg_color = COLOR_BORDER
		s.set_corner_radius_all(6)
		s.set_content_margin_all(SPACING_SM)
		cancel_button.add_theme_stylebox_override("normal", s)

	# -- Equipment buttons: accent-bordered
	for btn in [add_equipment_button, remove_equipment_button]:
		if btn:
			var s := StyleBoxFlat.new()
			s.bg_color = COLOR_ELEVATED
			s.border_color = COLOR_ACCENT
			s.set_border_width_all(1)
			s.set_corner_radius_all(6)
			s.set_content_margin_all(SPACING_SM)
			btn.add_theme_stylebox_override("normal", s)
			var h := s.duplicate()
			h.bg_color = COLOR_ACCENT
			btn.add_theme_stylebox_override("hover", h)

	# -- Panel containers: elevated card with border
	for panel in [
		char_info_panel, stats_panel,
		equipment_panel, notes_panel
	]:
		if panel:
			var s := StyleBoxFlat.new()
			s.bg_color = COLOR_ELEVATED
			s.border_color = COLOR_BORDER
			s.set_border_width_all(1)
			s.set_corner_radius_all(8)
			s.set_content_margin_all(SPACING_MD)
			panel.add_theme_stylebox_override("panel", s)

	# -- Section headers: cyan accent color
	_style_section_header(char_info_panel, "InfoTitle")
	_style_section_header(stats_panel, "StatsTitle")
	_style_section_header(equipment_panel, "EquipmentTitle")
	_style_section_header(notes_panel, "NotesTitle")

	# -- Stat cells: badge backgrounds (CharacterCard badge pattern)
	_style_stat_cells()

	# -- Notes TextEdit: input background with focus ring
	if notes_edit:
		var s := StyleBoxFlat.new()
		s.bg_color = COLOR_INPUT
		s.border_color = COLOR_BORDER
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.set_content_margin_all(SPACING_SM)
		notes_edit.add_theme_stylebox_override("normal", s)
		var f := s.duplicate()
		f.border_color = COLOR_FOCUS
		notes_edit.add_theme_stylebox_override("focus", f)

func _style_section_header(panel: PanelContainer, label_name: String) -> void:
	## Find a section title Label inside a panel and style it cyan.
	if not panel:
		return
	var label = panel.find_child(label_name, true, false)
	if label and label is Label:
		label.add_theme_color_override("font_color", COLOR_FOCUS)

func _style_stat_cells() -> void:
	## Add badge-style backgrounds to each stat cell in the StatsGrid.
	if not stats_grid:
		return
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(
		COLOR_FOCUS.r, COLOR_FOCUS.g, COLOR_FOCUS.b, 0.08
	)
	badge_style.border_color = COLOR_BORDER
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	badge_style.set_content_margin_all(SPACING_XS)
	for child in stats_grid.get_children():
		if child is VBoxContainer:
			# Add a styled ColorRect behind the cell content
			var bg := ColorRect.new()
			bg.name = "__stat_bg"
			bg.color = Color(
				COLOR_FOCUS.r, COLOR_FOCUS.g, COLOR_FOCUS.b, 0.06
			)
			bg.show_behind_parent = true
			bg.set_anchors_and_offsets_preset(
				Control.PRESET_FULL_RECT
			)
			child.add_child(bg)
			child.move_child(bg, 0)

func load_character_data() -> void:
	## Load character from GameStateManager temp storage
	if not GameStateManager:
		push_error("CharacterDetailsScreen: GameStateManager not available")
		return

	# Get character from temp storage (set by CrewManagementScreen or CrewPanel)
	if GameStateManager.has_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		current_character = GameStateManager.get_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER)

	if not current_character:
		push_error("CharacterDetailsScreen: No character selected")
		return


	# Store original data for cancel
	if current_character.has_method("to_dictionary"):
		original_data = current_character.to_dictionary()
	else:
		original_data = {}

	# Load crew list for swipe navigation (set by CrewManagementScreen)
	if GameStateManager.has_temp_data("crew_list_for_swipe"):
		var raw_list = GameStateManager.get_temp_data("crew_list_for_swipe")
		_crew_list.clear()
		for item in raw_list:
			if item is Dictionary:
				_crew_list.append(item)
	if GameStateManager.has_temp_data("crew_index_for_swipe"):
		_current_index = GameStateManager.get_temp_data("crew_index_for_swipe")

	# Populate UI fields
	populate_ui()
	_build_page_dots()

func populate_ui() -> void:
	## Fill UI elements with character data
	if not current_character:
		return

	# Hero Card (STANDARD variant)
	if hero_card and hero_card.has_method("set_character"):
		hero_card.set_character(current_character)
		if hero_card.has_method("set_variant"):
			hero_card.set_variant(
				CharacterCard.CardVariant.STANDARD)
	# Portrait upload button (overlay on HeroCard)
	if not hero_card.get_node_or_null("__ChangePortraitBtn"):
		_setup_portrait_upload()
	# Status summary bar
	_build_status_bar()
	# XP Progress Bar
	_update_xp_display()

	# Character Info (Background, Motivation, Origin, XP, Story Points)
	if character_info_container:
		clear_character_info_display()

		# Add prominent character creation info (like Crew Management screen)
		var background = current_character.background if "background" in current_character else "Unknown"
		var motivation = current_character.motivation if "motivation" in current_character else "Unknown"
		var char_class = current_character.character_class if "character_class" in current_character else "Working Class"
		var origin = current_character.origin if "origin" in current_character else "HUMAN"

		var creation_summary = Label.new()
		creation_summary.text = "%s | %s / %s / %s" % [origin, background, motivation, char_class]
		creation_summary.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		creation_summary.add_theme_color_override("font_color", COLOR_FOCUS)  # Cyan highlight
		character_info_container.add_child(creation_summary)

		# Add separator
		var separator = HSeparator.new()
		separator.custom_minimum_size = Vector2(0, SPACING_MD)
		character_info_container.add_child(separator)

		# Add injury status if wounded (Five Parsecs p.94-95)
		if "injuries" in current_character and current_character.injuries.size() > 0:
			var injury_header = Label.new()
			injury_header.text = "INJURIES (%d active)" % current_character.injuries.size()
			injury_header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			injury_header.add_theme_color_override("font_color", COLOR_DANGER)  # Red for injuries
			character_info_container.add_child(injury_header)

			# List all injuries with recovery time
			for injury in current_character.injuries:
				var injury_label = Label.new()
				var injury_type = injury.get("type", "UNKNOWN")
				var recovery_turns = injury.get("recovery_turns", 0)
				injury_label.text = "  • %s: %d turns remaining" % [injury_type, recovery_turns]
				injury_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
				injury_label.add_theme_color_override("font_color", COLOR_WARNING)  # Orange for injury details
				character_info_container.add_child(injury_label)

			# Add separator after injuries
			var injury_separator = HSeparator.new()
			injury_separator.custom_minimum_size = Vector2(0, SPACING_MD)
			character_info_container.add_child(injury_separator)

		# Add detailed info fields
		var info_fields = [
			["Experience", str(current_character.experience if "experience" in current_character else 0) + " XP"],
			["Story Points", str(current_character.story_points if "story_points" in current_character else 0)],
		]

		for field_data in info_fields:
			var info_row = HBoxContainer.new()
			info_row.set("theme_override_constants/separation", SPACING_SM)

			var field_name = Label.new()
			field_name.text = field_data[0] + ":"
			field_name.custom_minimum_size = Vector2(120, 0)
			field_name.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			field_name.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			info_row.add_child(field_name)

			var field_value = Label.new()
			field_value.text = str(field_data[1])
			field_value.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			field_value.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			info_row.add_child(field_value)

			character_info_container.add_child(info_row)

		# (History + Event Timeline are inline below — no overlay button needed)

	# Stats (5-column grid with centered values)
	if stats_grid:
		_update_stats_grid()
		# Staggered pop_in on stat badges
		var tm := get_node_or_null("/root/ThemeManager")
		var skip_a: bool = tm != null and tm.is_reduced_animation_enabled()
		if not skip_a:
			var st := create_tween()
			for badge in stats_grid.get_children():
				if badge is Control:
					badge.modulate.a = 0.0
					badge.pivot_offset = badge.size / 2
					st.tween_callback(func():
						if is_instance_valid(badge):
							badge.modulate.a = 1.0
							TweenFX.pop_in(badge, 0.18)
					)
					st.tween_interval(0.04)

	# Species rules for Strange Characters (Core Rules pp.19-22)
	_update_species_rules_display()

	# Equipment with keyword tooltips
	if equipment_rich_text and "equipment" in current_character:
		_update_equipment_display()

	# Implants display (after equipment)
	_update_implants_display()

	# Player Notes — persisted on Character.player_notes
	if notes_edit:
		notes_edit.text = current_character.player_notes if "player_notes" in current_character else ""
		notes_edit.placeholder_text = "Write notes, lore, or story for this character..."
		notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	
	# Character History — lifetime stats, advancement timeline, journal entries
	_populate_history_section()

	# Advancement Section (stat upgrades and training) OR Bot Upgrades (for bots)
	if advancement_section:
		var is_bot: bool = current_character.is_bot if "is_bot" in current_character else false
		if is_bot:
			_populate_bot_upgrade_section()
		else:
			_populate_advancement_section()

func clear_character_info_display() -> void:
	## Clear all character info labels
	if not character_info_container:
		return

	for child in character_info_container.get_children():
		child.queue_free()

func _update_xp_display() -> void:
	## Update XP progress bar and label
	if not current_character:
		return
	
	var current_xp: int = current_character.experience if "experience" in current_character else 0
	var next_level_xp: int = _calculate_next_level_xp(current_xp)
	
	# Update label
	if xp_label:
		xp_label.text = "XP: %d/%d" % [current_xp, next_level_xp]
	
	# Update progress bar
	if xp_progress_bar:
		xp_progress_bar.max_value = next_level_xp
		xp_progress_bar.value = current_xp

func _calculate_next_level_xp(current_xp: int) -> int:
	## Calculate XP needed for next level (Five Parsecs uses 1000 XP increments)
	# Five Parsecs advancement: Every 1000 XP grants advancement roll
	var current_level := int(current_xp / 1000)
	return (current_level + 1) * 1000

func _update_stats_grid() -> void:
	## Update 5-column stats grid with character stats
	if not current_character or not stats_grid:
		return
	
	# Stat cells ordered to match the physical Crew Log: Reactions, Speed, Combat, Toughness, Savvy, Luck
	var stat_cells := {
		"ReactionsCell/ReactionsValue": ["reactions", 0],
		"SpeedCell/SpeedValue": ["speed", 4],
		"CombatCell/CombatValue": ["combat", 0],
		"ToughnessCell/ToughnessValue": ["toughness", 0],
		"SavvyCell/SavvyValue": ["savvy", 0],
		"LuckCell/LuckValue": ["luck", 0],
	}
	# Stat maximums for color coding
	var stat_maxes: Dictionary = {
		"reactions": 6, "speed": 8, "combat": 5,
		"toughness": 6, "savvy": 5, "luck": 4,
	}
	for path: String in stat_cells:
		var label: Label = stats_grid.get_node_or_null(path)
		if label:
			var stat_name: String = stat_cells[path][0]
			var default_val: int = stat_cells[path][1]
			var val: int = current_character.get(
				stat_name) if stat_name in current_character \
				else default_val
			label.text = str(val)
			# Color code: green at max, red at danger, default
			var smax: int = stat_maxes.get(stat_name, 6)
			if val >= smax:
				label.add_theme_color_override(
					"font_color", COLOR_SUCCESS)
			elif val <= 0 and stat_name in [
				"combat", "savvy", "luck"]:
				label.add_theme_color_override(
					"font_color", COLOR_DANGER)
			elif stat_name == "toughness" and val <= 3:
				label.add_theme_color_override(
					"font_color", COLOR_WARNING)
			else:
				label.add_theme_color_override(
					"font_color", COLOR_TEXT_PRIMARY)

## Sprint 26.9 Phase 8.3: Responsive stats grid to prevent horizontal scroll on mobile
func _on_viewport_resized() -> void:
	## Handle viewport resize - adjust stats grid columns
	_apply_responsive_stats_grid()

func _apply_responsive_stats_grid() -> void:
	## Adjust stats grid columns based on viewport width to prevent horizontal scroll on mobile
	if not stats_grid:
		return

	var viewport := get_viewport()
	if not viewport:
		return

	var viewport_width := viewport.get_visible_rect().size.x

	# Determine column count based on screen size (6 stats: REA, SPD, COM, TOU, SAV, LCK)
	# Mobile (<768px): 3 columns (2 rows of 3) - readable on small screens
	# Tablet (768-1024px): 3 columns - balanced layout
	# Desktop (>1024px): 6 columns - all stats in one row, matches Crew Log
	var columns: int
	var h_spacing: int
	var v_spacing: int

	if viewport_width < 768:
		# Mobile: 3 columns (2 rows), compact spacing
		columns = 3
		h_spacing = 8
		v_spacing = 8
	elif viewport_width < 1024:
		# Tablet: 3 columns (2 rows), moderate spacing
		columns = 3
		h_spacing = 12
		v_spacing = 8
	else:
		# Desktop: 6 columns (all stats in one row), full spacing
		columns = 6
		h_spacing = 16
		v_spacing = 8

	# Apply columns and spacing
	stats_grid.columns = columns
	stats_grid.add_theme_constant_override("h_separation", h_spacing)
	stats_grid.add_theme_constant_override("v_separation", v_spacing)

func _update_species_rules_display() -> void:
	## Show Strange Character special rules below stats (Core Rules pp.19-22)
	if not current_character:
		return
	var container = get_node_or_null("SpeciesRulesContainer")
	if not container:
		# Create container on first call — placed after stats_grid
		container = VBoxContainer.new()
		container.name = "SpeciesRulesContainer"
		if stats_grid and stats_grid.get_parent():
			var parent = stats_grid.get_parent()
			var idx: int = stats_grid.get_index() + 1
			parent.add_child(container)
			parent.move_child(container, mini(
				idx, parent.get_child_count() - 1))

	# Clear and rebuild
	for child in container.get_children():
		child.queue_free()

	var rules: Array = []
	if "special_rules" in current_character:
		rules = current_character.special_rules
	if rules.is_empty():
		container.visible = false
		return
	container.visible = true

	var header := Label.new()
	header.text = "Species Rules"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override(
		"font_color", Color("#D97706"))
	container.add_child(header)

	var rules_label := RichTextLabel.new()
	rules_label.bbcode_enabled = true
	rules_label.fit_content = true
	rules_label.scroll_active = false
	var bbcode := ""
	for rule in rules:
		bbcode += "[color=#808080]• %s[/color]\n" % str(rule)
	rules_label.text = bbcode
	container.add_child(rules_label)

func _update_equipment_display() -> void:
	## Update equipment list — separates Weapons (with stats) from Gear/Armor, matching Crew Log layout
	if not current_character or not equipment_rich_text:
		return

	if not "equipment" in current_character or current_character.equipment.size() == 0:
		equipment_rich_text.text = "[color=#808080]No equipment[/color]"
		return

	# Load equipment database for weapon detail lookups
	var equip_db: Dictionary = _load_equipment_database()

	var weapons_bbcode := ""
	var gear_bbcode := ""

	for item in current_character.equipment:
		var item_str := str(item)
		var db_entry: Dictionary = _find_equipment_entry(item_str, equip_db)

		if not db_entry.is_empty() and db_entry.get("type", "") not in ["Armor", "Screen", "Consumable", "Gadget", "Utility"]:
			# Weapon — show detailed stats like the Crew Log
			var name_formatted := _format_equipment_with_keywords(item_str)
			var range_val: String = str(db_entry.get("range", 0)) + "\""
			var shots_val: String = str(db_entry.get("shots", 0))
			var dmg_val: String = "+" + str(db_entry.get("damage", 0)) if db_entry.get("damage", 0) > 0 else str(db_entry.get("damage", 0))
			var traits_arr: Array = db_entry.get("traits", [])
			var traits_str := ""
			for i in range(traits_arr.size()):
				var t: String = str(traits_arr[i])
				traits_str += "[url=keyword:%s][color=#4FC3F7]%s[/color][/url]" % [t, t]
				if i < traits_arr.size() - 1:
					traits_str += ", "
			if traits_str.is_empty():
				traits_str = "[color=#808080]—[/color]"

			weapons_bbcode += "  %s\n" % name_formatted
			weapons_bbcode += "    [color=#808080]Range:[/color] %s  [color=#808080]Shots:[/color] %s  [color=#808080]Dmg:[/color] %s  [color=#808080]Traits:[/color] %s\n" % [range_val, shots_val, dmg_val, traits_str]
		else:
			# Gear / Armor / Unknown — simple bullet
			var formatted_item := _format_equipment_with_keywords(item_str)
			gear_bbcode += "  • %s\n" % formatted_item

	var bbcode := ""
	if not weapons_bbcode.is_empty():
		bbcode += "[color=#4FC3F7]WEAPONS[/color]\n" + weapons_bbcode
	if not gear_bbcode.is_empty():
		if not bbcode.is_empty():
			bbcode += "\n"
		bbcode += "[color=#4FC3F7]GEAR & ARMOR[/color]\n" + gear_bbcode

	if bbcode.is_empty():
		bbcode = "[color=#808080]No equipment[/color]"

	equipment_rich_text.text = bbcode.strip_edges()

func _load_equipment_database() -> Dictionary:
	## Load equipment_database.json (cached after first load)
	if _equipment_db_cache and not _equipment_db_cache.is_empty():
		return _equipment_db_cache
	var path := "res://data/equipment_database.json"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	_equipment_db_cache = json.data if json.data is Dictionary else {}
	return _equipment_db_cache

func _find_equipment_entry(item_name: String, db: Dictionary) -> Dictionary:
	## Look up an equipment item by name across all categories in equipment_database.json
	var search_name := item_name.to_lower().strip_edges()
	# Strip parenthetical keywords: "Infantry Laser (Snap Shot)" → "infantry laser"
	var paren_pos := search_name.find("(")
	if paren_pos > 0:
		search_name = search_name.substr(0, paren_pos).strip_edges()
	for category in ["weapons", "armor", "gear", "gadgets"]:
		var items: Array = db.get(category, [])
		for entry in items:
			if entry is Dictionary:
				var entry_name: String = entry.get("name", "").to_lower()
				if entry_name == search_name:
					return entry
	return {}

func _format_equipment_with_keywords(item_name: String) -> String:
	## Format equipment name with BBCode keyword links for weapon keywords
	# Common weapon keywords (Five Parsecs equipment modifiers)
	var equipment_keywords := ["Assault", "Bulky", "Heavy", "Pistol", "Melee", "Single-Use", 
							   "Snap Shot", "Stun", "Piercing", "Area", "Critical"]
	
	var formatted := item_name
	
	# Detect keywords in parentheses: "Infantry Laser (Assault, Bulky)"
	var paren_start := formatted.find("(")
	var paren_end := formatted.find(")")
	
	if paren_start != -1 and paren_end != -1:
		var keywords_section := formatted.substr(paren_start + 1, paren_end - paren_start - 1)
		var formatted_keywords := ""
		
		# Split by comma and format each keyword
		var keyword_list := keywords_section.split(",")
		for i in range(keyword_list.size()):
			var keyword_name := keyword_list[i].strip_edges()
			
			# Check if this is a known equipment keyword
			if keyword_name in equipment_keywords:
				formatted_keywords += "[url=keyword:%s][color=#4FC3F7]%s[/color][/url]" % [keyword_name, keyword_name]
			else:
				formatted_keywords += keyword_name
			
			if i < keyword_list.size() - 1:
				formatted_keywords += ", "
		
		# Reconstruct item name with formatted keywords
		var base_name := formatted.substr(0, paren_start)
		formatted = "%s(%s)" % [base_name, formatted_keywords]
	
	return formatted

func _on_equipment_keyword_clicked(meta: Variant) -> void:
	## Handle keyword clicks in equipment list
	var meta_str := str(meta)

	if meta_str.begins_with("keyword:") and keyword_tooltip:
		var keyword := meta_str.substr(8)  # Remove "keyword:" prefix

		# Get click position for tooltip placement
		var click_position := equipment_rich_text.global_position

		# Show tooltip at the RichTextLabel position
		keyword_tooltip.show_for_keyword(keyword, click_position)

func _update_implants_display() -> void:
	## Update implants section after equipment
	if not current_character:
		return

	# Find implants container (create if not exists)
	var implants_label := character_info_container.get_node_or_null("ImplantsLabel")

	# Remove old implants display if it exists
	if implants_label:
		implants_label.queue_free()

	# Skip if no implants
	if not "implants" in current_character or current_character.implants.size() == 0:
		return

	# Create implants header
	var header := Label.new()
	header.name = "ImplantsLabel"
	header.text = "INSTALLED IMPLANTS (%d/3)" % current_character.implants.size()
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", Color("#8B5CF6"))  # Purple for implants
	character_info_container.add_child(header)

	# List each implant with stat bonus
	for implant in current_character.implants:
		var implant_row := Label.new()
		var formatted := EquipmentFormatter.format_implant(implant)
		implant_row.text = "  • %s" % formatted
		implant_row.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		implant_row.add_theme_color_override("font_color", COLOR_FOCUS)  # Cyan highlight
		character_info_container.add_child(implant_row)

	# Add separator after implants
	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(0, SPACING_MD)
	character_info_container.add_child(separator)

func _on_save_pressed() -> void:
	## Save character changes and return

	if not current_character:
		return

	# Save player notes back to character
	if notes_edit and current_character and "player_notes" in current_character:
		current_character.player_notes = notes_edit.text

	# Write changes back to the source crew dict (if this was a dict-based character).
	# Without this, notes/edits are lost because _on_dict_card_clicked creates a copy.
	_sync_character_to_source_dict()

	# Mark campaign as modified (needs save)
	if GameStateManager:
		GameStateManager.mark_campaign_modified()

	# Return to crew management
	return_to_crew_management()

func _on_cancel_pressed() -> void:
	## Cancel changes and return

	# Restore original data if possible
	if current_character and not original_data.is_empty():
		if current_character.has_method("from_dictionary"):
			current_character.from_dictionary(original_data)

	# Return to crew management
	return_to_crew_management()

func _populate_history_section() -> void:
	## Add character history + event timeline panels
	if not current_character:
		return

	var main_vbox: VBoxContainer = _find_main_vbox()
	if not main_vbox:
		return

	var char_id: String = _get_char_id()

	# Remove old panels if re-populating
	for old_name: String in [
		"__CharacterHistory", "__CharEventTimeline"
	]:
		var old: Node = main_vbox.get_node_or_null(old_name)
		if old:
			old.queue_free()

	# History panel (stats, advancement, journal entries)
	var history_panel := CharacterHistoryPanelClass.new()
	history_panel.name = "__CharacterHistory"
	history_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL)
	main_vbox.add_child(history_panel)

	# Position after NotesPanel
	var notes_panel_node: Node = null
	if notes_edit:
		notes_panel_node = notes_edit.get_parent()
		if notes_panel_node:
			notes_panel_node = notes_panel_node.get_parent()
	if notes_panel_node and notes_panel_node.get_parent() == main_vbox:
		var idx: int = notes_panel_node.get_index() + 1
		main_vbox.move_child(history_panel, mini(
			idx, main_vbox.get_child_count() - 1))

	history_panel.setup(current_character, char_id)

	# Hide history panel's built-in back button (we have Save/Cancel)
	_hide_history_back_button(history_panel)

	# Filterable event timeline (below history)
	var event_timeline := CharacterEventTimelineClass.new()
	event_timeline.name = "__CharEventTimeline"
	event_timeline.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL)
	main_vbox.add_child(event_timeline)
	main_vbox.move_child(event_timeline, mini(
		history_panel.get_index() + 1,
		main_vbox.get_child_count() - 1))
	event_timeline.setup(char_id)

func _hide_history_back_button(panel: PanelContainer) -> void:
	var header: Node = panel.get_node_or_null(
		"ScrollContainer/VBoxContainer/HBoxContainer")
	if not header and panel.get_child_count() > 0:
		var scroll: Node = panel.get_child(0)
		if scroll and scroll.get_child_count() > 0:
			var vbox: Node = scroll.get_child(0)
			if vbox and vbox.get_child_count() > 0:
				var first: Node = vbox.get_child(0)
				if first is HBoxContainer:
					header = first
	if header:
		header.visible = false

func _sync_character_to_source_dict() -> void:
	## Write modified character data back to the source dict in campaign crew_data.
	## This ensures notes and other edits persist through save/load when the character
	## was opened from a dictionary-based crew card (not a Character Resource).
	if not current_character or not GameStateManager:
		return
	if not GameStateManager.has_temp_data("source_crew_dict"):
		return

	var source_dict: Dictionary = GameStateManager.get_temp_data("source_crew_dict")
	if source_dict.is_empty():
		return

	# Serialize current character state and merge back into the source dict.
	# The source dict is a reference into campaign.crew_data["members"], so
	# updating it in-place updates the campaign's live data.
	if current_character.has_method("to_dictionary"):
		var updated: Dictionary = current_character.to_dictionary()
		for key in updated:
			source_dict[key] = updated[key]

	GameStateManager.clear_temp_data("source_crew_dict")

func return_to_crew_management() -> void:
	## Navigate back to crew management screen
	if GameStateManager and GameStateManager.has_temp_data(
		GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		GameStateManager.clear_temp_data(
			GameStateManager.TEMP_KEY_SELECTED_CHARACTER)
	GameStateManager.navigate_to_screen("crew_management")

# ── Shared Helpers ──────────────────────────────────────────────

func _get_char_id() -> String:
	## Extract character_id from current_character (dict or Resource)
	if not current_character:
		return ""
	if current_character is Dictionary:
		return str(current_character.get(
			"character_id", current_character.get("id", "")))
	if "character_id" in current_character:
		return str(current_character.character_id)
	if "id" in current_character:
		return str(current_character.id)
	return ""

# ── Portrait Upload ─────────────────────────────────────────────

func _setup_portrait_upload() -> void:
	## Add "Change Portrait" button overlaid on the HeroCard
	if not hero_card:
		return
	var btn := Button.new()
	btn.name = "__ChangePortraitBtn"
	btn.text = "Change Portrait"
	btn.custom_minimum_size = Vector2(120, 32)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		COLOR_BASE.r, COLOR_BASE.g, COLOR_BASE.b, 0.85)
	style.border_color = COLOR_ACCENT
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_XS)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = COLOR_ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	btn.pressed.connect(_on_change_portrait_pressed)
	hero_card.add_child(btn)
	# Position at bottom-left of hero card
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.position = Vector2(SPACING_SM, -40)

func _on_change_portrait_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray([
		"*.png ; PNG Images",
		"*.jpg ; JPEG Images",
		"*.jpeg ; JPEG Images",
		"*.webp ; WebP Images",
	])
	dialog.title = "Select Character Portrait"
	dialog.min_size = Vector2i(600, 400)
	dialog.file_selected.connect(_on_portrait_file_selected)
	add_child(dialog)
	dialog.popup_centered()

func _on_portrait_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if not img or img.is_empty():
		push_warning("CharacterDetails: Failed to load image")
		return
	# Resize if too large
	if img.get_width() > 256 or img.get_height() > 256:
		img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	# Save to user directory
	var char_id: String = _get_char_id()
	if char_id.is_empty():
		char_id = "char_%d" % Time.get_ticks_msec()
	var dir_path := "user://portraits"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)
	var save_path := "%s/%s.png" % [dir_path, char_id]
	var err: Error = img.save_png(save_path)
	if err != OK:
		push_error("CharacterDetails: Failed to save portrait")
		return
	# Update character
	if current_character and "portrait_path" in current_character:
		current_character.portrait_path = save_path
	# Refresh hero card
	if hero_card and hero_card.has_method("set_character"):
		hero_card.set_character(current_character)

# ── Status Summary Bar ──────────────────────────────────────────

func _build_status_bar() -> void:
	## Add at-a-glance status bar below HeroCard
	var main_vbox: VBoxContainer = _find_main_vbox()
	if not main_vbox:
		return
	# Remove old status bar
	var old := main_vbox.get_node_or_null("__StatusBar")
	if old:
		old.queue_free()

	var bar := HFlowContainer.new()
	bar.name = "__StatusBar"
	bar.add_theme_constant_override("h_separation", SPACING_MD)
	bar.add_theme_constant_override("v_separation", SPACING_XS)

	# Status dot
	var status_text: String = "ACTIVE"
	var status_color: Color = COLOR_SUCCESS
	if current_character:
		if "status" in current_character:
			status_text = str(current_character.status)
		if status_text == "DEAD":
			status_color = COLOR_DANGER
		elif status_text != "ACTIVE":
			status_color = COLOR_WARNING

	bar.add_child(_status_chip(status_text, status_color))

	# Sick bay recovery
	if current_character and "recovery_turns" in current_character:
		var rt: int = current_character.recovery_turns
		if rt > 0:
			bar.add_child(_status_chip(
				"Sick Bay (%d turns)" % rt, COLOR_WARNING))

	# Battle count
	var battles: int = 0
	if current_character and "battles_participated" in current_character:
		battles = current_character.battles_participated
	bar.add_child(_status_chip(
		"%d Battles" % battles, COLOR_TEXT_SECONDARY))

	# Kill count
	var kills: int = 0
	if current_character and "lifetime_kills" in current_character:
		kills = current_character.lifetime_kills
	bar.add_child(_status_chip(
		"%d Kills" % kills, COLOR_TEXT_SECONDARY))

	# XP
	var xp: int = 0
	if current_character and "experience" in current_character:
		xp = current_character.experience
	bar.add_child(_status_chip("%d XP" % xp, COLOR_ACCENT))

	# Insert after HeroCard (index 1 in main vbox)
	main_vbox.add_child(bar)
	if hero_card and hero_card.get_parent() == main_vbox:
		var idx: int = hero_card.get_index() + 1
		main_vbox.move_child(bar, mini(
			idx, main_vbox.get_child_count() - 1))

func _status_chip(
	text: String, color: Color
) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		color.r, color.g, color.b, 0.15)
	style.border_color = Color(
		color.r, color.g, color.b, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_XS)
	chip.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", color)
	chip.add_child(lbl)
	return chip

func _find_main_vbox() -> VBoxContainer:
	## Find the main VBoxContainer in the scroll tree
	var scroll: ScrollContainer = get_node_or_null(
		"MarginContainer/ScrollContainer")
	if scroll and scroll.get_child_count() > 0:
		var child: Node = scroll.get_child(0)
		if child is VBoxContainer:
			return child
	return null

func _on_add_equipment_pressed() -> void:
	## Show popup listing items from campaign equipment pool (Ship Stash)
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.campaign or not "equipment_data" in gs.campaign:
		return
	var pool: Array = []
	if gs.campaign.has_method("get_all_equipment"):
		pool = gs.campaign.get_all_equipment()
	else:
		pool = gs.campaign.equipment_data.get("equipment", [])
	if pool.is_empty():
		return
	var popup := PopupMenu.new()
	popup.name = "AddEquipPopup"
	add_child(popup)
	for i in range(pool.size()):
		var item = pool[i]
		var item_name: String = item.get("name", str(item)) if item is Dictionary else str(item)
		popup.add_item(item_name, i)
	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < pool.size():
			var chosen = pool[id]
			# Move item from ship stash to character using EquipmentTransferService.
			# The service handles the atomic remove-from-stash + add-to-character,
			# enforcing the "one item, one home" tabletop invariant.
			var char_id: String = ""
			if current_character is Dictionary:
				char_id = str(current_character.get("character_id",
					current_character.get("id", "")))
			elif "character_id" in current_character:
				char_id = str(current_character.character_id)
			var item_id: String = ""
			if chosen is Dictionary:
				item_id = str(chosen.get("id", ""))
			if not char_id.is_empty() and not item_id.is_empty():
				var svc = EquipmentTransferServiceRef.new(gs.current_campaign)
				svc.transfer_to_character(item_id, char_id)
			else:
				# Fallback for items without ids (legacy data)
				if current_character and "equipment" in current_character:
					current_character.equipment.append(chosen) # lint:ignore
				pool.remove_at(id)
				gs.current_campaign.equipment_data["equipment"] = pool
			_update_equipment_display()
		popup.queue_free()
	)
	popup.popup_centered()

func _on_remove_equipment_pressed() -> void:
	## Show popup listing character's equipment to return to ship stash
	if not current_character or not "equipment" in current_character:
		return
	var equipment: Array = current_character.equipment
	if equipment.is_empty():
		return
	var popup := PopupMenu.new()
	popup.name = "RemoveEquipPopup"
	add_child(popup)
	for i in range(equipment.size()):
		var item = equipment[i]
		var item_name: String = item.get("name", str(item)) if item is Dictionary else str(item)
		popup.add_item(item_name, i)
	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < equipment.size():
			var removed = equipment[id]
			# Route through EquipmentTransferService for atomic transfer
			# back to ship stash (tabletop: return card to the stash box).
			var gs = get_node_or_null("/root/GameState")
			var char_id: String = ""
			if current_character is Dictionary:
				char_id = str(current_character.get("character_id",
					current_character.get("id", "")))
			elif "character_id" in current_character:
				char_id = str(current_character.character_id)
			var item_id: String = ""
			if removed is Dictionary:
				item_id = str(removed.get("id", ""))
			elif removed is String:
				item_id = removed  # Legacy string-only equipment
			if not char_id.is_empty() and not item_id.is_empty() and gs and gs.current_campaign:
				var svc = EquipmentTransferServiceRef.new(gs.current_campaign)
				svc.transfer_to_stash(item_id, char_id)
			else:
				# Fallback for legacy data without ids
				equipment.remove_at(id)
				if gs and gs.current_campaign and "equipment_data" in gs.current_campaign:
					var stash: Array = gs.current_campaign.equipment_data.get("equipment", [])
					stash.append(removed)
			_update_equipment_display()
		popup.queue_free()
	)
	popup.popup_centered()

# ============ ADVANCEMENT SECTION ============

func _populate_advancement_section() -> void:
	## Populate the advancement section with stat upgrades and training options
	if not current_character or not advancement_section:
		return
	
	# Clear existing advancement UI
	for child in advancement_section.get_children():
		child.queue_free()
	
	stat_advancement_buttons.clear()
	training_purchase_buttons.clear()
	
	# Get character data as dictionary for CharacterAdvancementService
	var character_dict := _character_to_dict(current_character)
	
	# Create XP display header
	var xp_header := _create_advancement_header(character_dict)
	advancement_section.add_child(xp_header)
	
	# Add separator
	var separator1 := HSeparator.new()
	separator1.custom_minimum_size = Vector2(0, SPACING_MD)
	advancement_section.add_child(separator1)
	
	# Create stat advancement grid
	var stat_section := _create_stat_advancement_section(character_dict)
	advancement_section.add_child(stat_section)
	
	# Add separator
	var separator2 := HSeparator.new()
	separator2.custom_minimum_size = Vector2(0, SPACING_LG)
	advancement_section.add_child(separator2)
	
	# Create training options
	var training_section := _create_training_section(character_dict)
	advancement_section.add_child(training_section)

func _create_advancement_header(character_dict: Dictionary) -> VBoxContainer:
	## Create XP display header for advancement section
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_SM)
	
	# Title
	var title := Label.new()
	title.text = "CHARACTER ADVANCEMENT"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(title)
	
	# Current XP display (large and prominent)
	var xp_display := HBoxContainer.new()
	xp_display.add_theme_constant_override("separation", SPACING_SM)
	
	var xp_label_text := Label.new()
	xp_label_text.text = "Available XP:"
	xp_label_text.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	xp_label_text.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	xp_display.add_child(xp_label_text)
	
	var xp_value := Label.new()
	xp_value.text = str(character_dict.get("experience", 0))
	xp_value.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	xp_value.add_theme_color_override("font_color", COLOR_ACCENT)
	xp_value.name = "AvailableXPValue"
	xp_display.add_child(xp_value)
	
	header.add_child(xp_display)
	
	return header

func _create_stat_advancement_section(character_dict: Dictionary) -> VBoxContainer:
	## Create stat advancement grid with buttons
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", SPACING_MD)
	
	# Section title
	var title := Label.new()
	title.text = "STAT ADVANCEMENT"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	section.add_child(title)
	
	# Grid of stats (2 columns for mobile-friendly layout)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_SM)
	
	# Stats to display (in priority order)
	var stats := ["reactions", "combat_skill", "toughness", "savvy", "speed", "luck"]
	
	for stat in stats:
		var stat_card := _create_stat_advancement_card(character_dict, stat)
		grid.add_child(stat_card)
	
	section.add_child(grid)
	
	return section

func _create_stat_advancement_card(character_dict: Dictionary, stat_name: String) -> PanelContainer:
	## Create a card for a single stat advancement option
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style the card
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	
	# Stat name
	var stat_label := Label.new()
	stat_label.text = stat_name.capitalize().replace("_", " ")
	stat_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	stat_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(stat_label)
	
	# Current value / Max
	var current_value: int = character_dict.get(stat_name, 0)
	var max_value: int = CharacterAdvancementConstants.get_stat_maximum(stat_name, character_dict)
	
	var value_label := Label.new()
	value_label.text = "%d / %d" % [current_value, max_value]
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	value_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(value_label)
	
	# Advance button
	var can_advance_result := CharacterAdvancementService.can_advance_stat(character_dict, stat_name)
	
	var button := Button.new()
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if can_advance_result.can_advance:
		button.text = "Advance (%d XP)" % can_advance_result.xp_cost
		button.disabled = false
		button.pressed.connect(_on_stat_advance_pressed.bind(stat_name))
		stat_advancement_buttons[stat_name] = button
	else:
		button.text = can_advance_result.reason.split(":")[0]  # Just the first part
		button.disabled = true
	
	vbox.add_child(button)
	
	panel.add_child(vbox)
	return panel

func _create_training_section(character_dict: Dictionary) -> VBoxContainer:
	## Create training options section
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", SPACING_MD)
	
	# Section title
	var title := Label.new()
	title.text = "TRAINING"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	section.add_child(title)
	
	# Training list (from AdvancementSystem)
	var training_types := ["pilot", "medical", "mechanic", "broker", "security", "merchant", "bot_tech", "engineer"]
	var training_costs := {
		"pilot": 20, "medical": 20, "mechanic": 15, "broker": 15,
		"security": 10, "merchant": 10, "bot_tech": 10, "engineer": 15
	}
	
	var current_training: Array = character_dict.get("training", [])
	var current_xp: int = character_dict.get("experience", 0)
	
	# Create grid for training (2 columns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_SM)
	
	for training_type in training_types:
		var training_card := _create_training_card(training_type, training_costs[training_type], current_training, current_xp)
		grid.add_child(training_card)
	
	section.add_child(grid)
	
	return section

func _create_training_card(training_type: String, cost: int, current_training: Array, current_xp: int) -> PanelContainer:
	## Create a card for a single training option
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style the card
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	
	# Training name
	var name_label := Label.new()
	name_label.text = training_type.capitalize().replace("_", " ")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(name_label)
	
	# Purchase button
	var button := Button.new()
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var already_has := training_type in current_training
	var can_afford := current_xp >= cost
	
	if already_has:
		button.text = "Already Trained"
		button.disabled = true
	elif can_afford:
		button.text = "Purchase (%d XP)" % cost
		button.disabled = false
		button.pressed.connect(_on_training_pressed.bind(training_type))
		training_purchase_buttons[training_type] = button
	else:
		button.text = "Need %d XP" % cost
		button.disabled = true
	
	vbox.add_child(button)
	
	panel.add_child(vbox)
	return panel

func _on_stat_advance_pressed(stat_name: String) -> void:
	## Handle stat advancement button press
	if not current_character:
		return
	
	
	# Convert character to dictionary
	var character_dict := _character_to_dict(current_character)
	
	# Attempt advancement
	var result := CharacterAdvancementService.advance_stat(character_dict, stat_name)
	
	if result.success:
		# Update character resource with new values
		_update_character_from_dict(current_character, character_dict)
		
		# Mark campaign as modified
		if GameStateManager:
			GameStateManager.mark_campaign_modified()
		
		# Refresh all UI
		populate_ui()
		
	else:
		pass

func _on_training_pressed(training_type: String) -> void:
	## Handle training purchase button press
	if not current_character:
		return
	
	
	# Get training cost
	var training_costs := {
		"pilot": 20, "medical": 20, "mechanic": 15, "broker": 15,
		"security": 10, "merchant": 10, "bot_tech": 10, "engineer": 15
	}
	
	var cost: int = training_costs.get(training_type, 0)
	var current_xp: int = current_character.experience if "experience" in current_character else 0
	var current_training: Array = current_character.training if "training" in current_character else []
	
	# Validate
	if training_type in current_training:
		return
	
	if current_xp < cost:
		return
	
	# Apply training
	current_training.append(training_type)
	current_character.training = current_training
	current_character.experience = current_xp - cost
	
	# Mark campaign as modified
	if GameStateManager:
		GameStateManager.mark_campaign_modified()
	
	# Refresh all UI
	populate_ui()
	

func _character_to_dict(character: Resource) -> Dictionary:
	## Convert Character resource to dictionary for advancement service
	var dict := {}
	
	# Core stats
	dict["reactions"] = character.reactions if "reactions" in character else 1
	dict["combat_skill"] = character.combat if "combat" in character else 0
	dict["speed"] = character.speed if "speed" in character else 4
	dict["savvy"] = character.savvy if "savvy" in character else 1
	dict["toughness"] = character.toughness if "toughness" in character else 3
	dict["luck"] = character.luck if "luck" in character else 0
	
	# Experience and training
	dict["experience"] = character.experience if "experience" in character else 0
	dict["training"] = character.training if "training" in character else []
	
	# Background and species for maximums
	dict["background"] = character.background if "background" in character else ""
	dict["species"] = character.origin if "origin" in character else "Human"
	
	return dict

func _update_character_from_dict(character: Resource, dict: Dictionary) -> void:
	## Update Character resource from dictionary after advancement
	# Update stats
	if "reactions" in dict:
		character.reactions = dict.reactions
	if "combat_skill" in dict:
		character.combat = dict.combat_skill
	if "speed" in dict:
		character.speed = dict.speed
	if "savvy" in dict:
		character.savvy = dict.savvy
	if "toughness" in dict:
		character.toughness = dict.toughness
	if "luck" in dict:
		character.luck = dict.luck
	
	# Update experience
	if "experience" in dict:
		character.experience = dict.experience
	
	# Update training
	if "training" in dict:
		character.training = dict.training

# ============ BOT UPGRADE SECTION ============

func _populate_bot_upgrade_section() -> void:
	## Populate bot upgrade section (credits-based upgrades instead of XP)
	if not current_character or not advancement_section:
		return
	
	# Clear existing advancement UI
	for child in advancement_section.get_children():
		child.queue_free()
	
	# Get game state for credits
	var game_state: Variant = GameStateManager.get_game_state()
	if not game_state:
		push_error("CharacterDetailsScreen: GameStateManager not available for bot upgrades")
		return
	
	var campaign_credits: int = 0
	if game_state.has_method("get_credits"):
		campaign_credits = game_state.get_credits()
	elif "credits" in game_state:
		campaign_credits = game_state.credits
	
	# Create header
	var header := _create_bot_upgrade_header(campaign_credits)
	advancement_section.add_child(header)
	
	# Add separator
	var separator1 := HSeparator.new()
	separator1.custom_minimum_size = Vector2(0, SPACING_MD)
	advancement_section.add_child(separator1)
	
	# Get advancement system
	var advancement_system := FPCM_AdvancementSystem.new()
	
	# Get available upgrades
	var available_upgrades := advancement_system.get_available_bot_upgrades(current_character)
	
	if available_upgrades.is_empty():
		var no_upgrades := Label.new()
		no_upgrades.text = "All upgrades installed!"
		no_upgrades.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		no_upgrades.add_theme_color_override("font_color", COLOR_SUCCESS)
		advancement_section.add_child(no_upgrades)
	else:
		# Create upgrade grid (2 columns for mobile-friendly layout)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", SPACING_SM)
		grid.add_theme_constant_override("v_separation", SPACING_SM)
		
		for upgrade in available_upgrades:
			var upgrade_card := _create_bot_upgrade_card(upgrade, campaign_credits, advancement_system)
			grid.add_child(upgrade_card)
		
		advancement_section.add_child(grid)
	
	# Add separator
	var separator2 := HSeparator.new()
	separator2.custom_minimum_size = Vector2(0, SPACING_LG)
	advancement_section.add_child(separator2)
	
	# Show installed upgrades
	var installed_section := _create_installed_upgrades_section()
	advancement_section.add_child(installed_section)

func _create_bot_upgrade_header(campaign_credits: int) -> VBoxContainer:
	## Create header for bot upgrade section
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_SM)
	
	# Title
	var title := Label.new()
	title.text = "BOT UPGRADES"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Bots purchase upgrades with credits (no XP system)"
	subtitle.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	header.add_child(subtitle)
	
	# Campaign credits display
	var credits_display := HBoxContainer.new()
	credits_display.add_theme_constant_override("separation", SPACING_SM)
	
	var credits_label := Label.new()
	credits_label.text = "Campaign Credits:"
	credits_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	credits_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	credits_display.add_child(credits_label)
	
	var credits_value := Label.new()
	credits_value.text = str(campaign_credits)
	credits_value.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	credits_value.add_theme_color_override("font_color", COLOR_ACCENT)
	credits_value.name = "CampaignCreditsValue"
	credits_display.add_child(credits_value)
	
	header.add_child(credits_display)
	
	return header

func _create_bot_upgrade_card(upgrade: Dictionary, campaign_credits: int, advancement_system: FPCM_AdvancementSystem) -> PanelContainer:
	## Create a card for a single bot upgrade option
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style the card
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	
	# Upgrade name
	var name_label := Label.new()
	name_label.text = upgrade.get("name", "Unknown Upgrade")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(name_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = upgrade.get("description", "")
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(desc_label)
	
	# Install button
	var upgrade_id: String = upgrade.get("id", "")
	var cost: int = upgrade.get("cost", 0)
	var can_afford: bool = campaign_credits >= cost
	
	var button := Button.new()
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if can_afford:
		button.text = "Install (%d Credits)" % cost
		button.disabled = false
		button.pressed.connect(_on_bot_upgrade_pressed.bind(upgrade_id, advancement_system))
	else:
		button.text = "Need %d Credits" % cost
		button.disabled = true
	
	vbox.add_child(button)
	
	panel.add_child(vbox)
	return panel

func _create_installed_upgrades_section() -> VBoxContainer:
	## Create section showing installed bot upgrades
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", SPACING_MD)
	
	# Title
	var title := Label.new()
	title.text = "INSTALLED UPGRADES"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	section.add_child(title)
	
	# Get installed upgrades
	var installed_upgrades: Array = current_character.bot_upgrades if "bot_upgrades" in current_character else []
	
	if installed_upgrades.is_empty():
		var no_upgrades := Label.new()
		no_upgrades.text = "No upgrades installed yet"
		no_upgrades.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		no_upgrades.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		section.add_child(no_upgrades)
	else:
		# Get upgrade definitions from advancement system
		var advancement_system := FPCM_AdvancementSystem.new()
		
		for upgrade_id in installed_upgrades:
			if advancement_system.bot_upgrades.has(upgrade_id):
				var upgrade_data: Dictionary = advancement_system.bot_upgrades[upgrade_id]
				
				var upgrade_label := Label.new()
				upgrade_label.text = "✓ %s: %s" % [upgrade_data.get("name", "Unknown"), upgrade_data.get("description", "")]
				upgrade_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
				upgrade_label.add_theme_color_override("font_color", COLOR_SUCCESS)
				section.add_child(upgrade_label)
	
	return section

func _on_bot_upgrade_pressed(upgrade_id: String, advancement_system: FPCM_AdvancementSystem) -> void:
	## Handle bot upgrade purchase button press
	if not current_character:
		return
	
	
	# Get game state
	var game_state: Variant = GameStateManager.get_game_state()
	if not game_state:
		push_error("CharacterDetailsScreen: GameStateManager not available")
		return
	
	# Attempt installation
	var success := advancement_system.install_bot_upgrade(current_character, upgrade_id, game_state)
	
	if success:
		# Mark campaign as modified
		if GameStateManager:
			GameStateManager.mark_campaign_modified()
		
		# Refresh all UI
		populate_ui()
		
	else:
		pass

# ============ CHARACTER HISTORY ============

func _on_view_history_pressed() -> void:
	if not current_character:
		return
	# Get character ID
	var char_id: String = ""
	if "character_id" in current_character:
		char_id = current_character.character_id
	elif "id" in current_character:
		char_id = current_character.id
	elif current_character is Dictionary:
		char_id = current_character.get("character_id", current_character.get("id", ""))
	# Create overlay
	if _history_overlay and is_instance_valid(_history_overlay):
		_history_overlay.queue_free()
	_history_overlay = Control.new()
	_history_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_history_overlay)
	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(COLOR_BASE.r, COLOR_BASE.g, COLOR_BASE.b, 0.95)
	_history_overlay.add_child(bg)
	# History panel
	var panel := CharacterHistoryPanelClass.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_overlay.add_child(panel)
	panel.setup(current_character, char_id)
	panel.back_pressed.connect(_on_history_back)

func _on_history_back() -> void:
	if _history_overlay and is_instance_valid(_history_overlay):
		_history_overlay.queue_free()
		_history_overlay = null

# ── Crew Swipe Navigation ─────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _crew_list.size() <= 1:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
		else:
			var delta: Vector2 = event.position - _touch_start
			var duration := Time.get_ticks_msec() / 1000.0 - _touch_start_time
			# Swipe: fast, horizontal, not diagonal
			if duration < 0.4 and absf(delta.x) > 80.0 and absf(delta.x) > absf(delta.y) * 2.0:
				if delta.x < 0.0:
					_navigate_crew(1)   # Swipe left = next
				else:
					_navigate_crew(-1)  # Swipe right = prev
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_navigate_crew(1)
		elif event.keycode == KEY_LEFT:
			_navigate_crew(-1)

func _navigate_crew(direction: int) -> void:
	if _crew_list.is_empty():
		return
	var new_idx := wrapi(_current_index + direction, 0, _crew_list.size())
	if new_idx == _current_index:
		return
	_current_index = new_idx
	var new_dict: Dictionary = _crew_list[_current_index]
	var character := Character.new()
	character.from_dictionary(new_dict)
	current_character = character
	if current_character.has_method("to_dictionary"):
		original_data = current_character.to_dictionary()
	# Update temp data so save works correctly
	if GameStateManager:
		GameStateManager.set_temp_data(
			GameStateManager.TEMP_KEY_SELECTED_CHARACTER, character)
		GameStateManager.set_temp_data("source_crew_dict", new_dict)
		GameStateManager.set_temp_data("crew_index_for_swipe", _current_index)
	populate_ui()
	_update_page_dots()

func _build_page_dots() -> void:
	if _crew_list.size() <= 1:
		return
	if _page_dots_container and is_instance_valid(_page_dots_container):
		_page_dots_container.queue_free()
	_page_dots_container = HBoxContainer.new()
	_page_dots_container.name = "__page_dots"
	_page_dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_dots_container.add_theme_constant_override("separation", 8)
	for i in _crew_list.size():
		var dot := Label.new()
		dot.text = "\u25cf" if i == _current_index else "\u25cb"
		dot.add_theme_font_size_override("font_size", 12)
		dot.add_theme_color_override("font_color",
			COLOR_FOCUS if i == _current_index else COLOR_TEXT_DISABLED)
		_page_dots_container.add_child(dot)
	# Add at the bottom of the screen
	add_child(_page_dots_container)

func _update_page_dots() -> void:
	if _crew_list.size() <= 1:
		if _page_dots_container and is_instance_valid(_page_dots_container):
			_page_dots_container.queue_free()
			_page_dots_container = null
		return
	if not _page_dots_container or not is_instance_valid(_page_dots_container):
		_build_page_dots()
		return
	var children := _page_dots_container.get_children()
	for i in children.size():
		var dot: Label = children[i]
		dot.text = "\u25cf" if i == _current_index else "\u25cb"
		dot.add_theme_color_override("font_color",
			COLOR_FOCUS if i == _current_index else COLOR_TEXT_DISABLED)
