# Character Details Screen - View and Edit Individual Character
# Allows editing character properties and equipment
class_name CharacterDetailsScreen
extends Control

# ============ PRELOADS ============
const CharacterCard = preload("res://src/ui/components/character/CharacterCard.gd")

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

# State
var current_character = null
var original_data: Dictionary = {}

# Advancement UI references (created dynamically)
var stat_advancement_buttons: Dictionary = {}
var training_purchase_buttons: Dictionary = {}

func _ready() -> void:
	print("CharacterDetailsScreen: Initializing...")

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

	# Sprint 26.9 Phase 8.3: Connect viewport resize for responsive stats grid
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_responsive_stats_grid()

	# Load character data
	load_character_data()

	print("CharacterDetailsScreen: Ready")

func load_character_data() -> void:
	"""Load character from GameStateManager temp storage"""
	if not GameStateManager:
		push_error("CharacterDetailsScreen: GameStateManager not available")
		return

	# Get character from temp storage (set by CrewManagementScreen or CrewPanel)
	if GameStateManager.has_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		current_character = GameStateManager.get_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER)

	if not current_character:
		push_error("CharacterDetailsScreen: No character selected")
		return

	print("CharacterDetailsScreen: Loading character - ", current_character.name if "name" in current_character else "Unknown")

	# Store original data for cancel
	if current_character.has_method("to_dictionary"):
		original_data = current_character.to_dictionary()
	else:
		original_data = {}

	# Populate UI fields
	populate_ui()

func populate_ui() -> void:
	"""Fill UI elements with character data"""
	if not current_character:
		return

	# Hero Card (EXPANDED variant with portrait, name, class, stats)
	if hero_card and hero_card.has_method("set_character"):
		hero_card.set_character(current_character)
		# Ensure EXPANDED variant for full stats display
		if hero_card.has_method("set_variant"):
			hero_card.set_variant(CharacterCard.CardVariant.EXPANDED)
	
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

	# Stats (5-column grid with centered values)
	if stats_grid:
		_update_stats_grid()
	
	# Equipment with keyword tooltips
	if equipment_rich_text and "equipment" in current_character:
		_update_equipment_display()

	# Implants display (after equipment)
	_update_implants_display()

	# Notes (if we add a notes field to Character)
	if notes_edit:
		notes_edit.text = ""  # Placeholder for future notes system
	
	# Advancement Section (stat upgrades and training) OR Bot Upgrades (for bots)
	if advancement_section:
		if current_character.is_bot():
			_populate_bot_upgrade_section()
		else:
			_populate_advancement_section()

func clear_character_info_display() -> void:
	"""Clear all character info labels"""
	if not character_info_container:
		return

	for child in character_info_container.get_children():
		child.queue_free()

func _update_xp_display() -> void:
	"""Update XP progress bar and label"""
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
	"""Calculate XP needed for next level (Five Parsecs uses 1000 XP increments)"""
	# Five Parsecs advancement: Every 1000 XP grants advancement roll
	var current_level := int(current_xp / 1000)
	return (current_level + 1) * 1000

func _update_stats_grid() -> void:
	"""Update 5-column stats grid with character stats"""
	if not current_character or not stats_grid:
		return
	
	# Get stat cells (VBoxContainer with Label children)
	var combat_cell = stats_grid.get_node_or_null("CombatCell/Value")
	var reactions_cell = stats_grid.get_node_or_null("ReactionsCell/Value")
	var toughness_cell = stats_grid.get_node_or_null("ToughnessCell/Value")
	var savvy_cell = stats_grid.get_node_or_null("SavvyCell/Value")
	var speed_cell = stats_grid.get_node_or_null("SpeedCell/Value")
	
	# Update stat values
	if combat_cell:
		combat_cell.text = str(current_character.combat if "combat" in current_character else 0)
	if reactions_cell:
		reactions_cell.text = str(current_character.reactions if "reactions" in current_character else 0)
	if toughness_cell:
		toughness_cell.text = str(current_character.toughness if "toughness" in current_character else 0)
	if savvy_cell:
		savvy_cell.text = str(current_character.savvy if "savvy" in current_character else 0)
	if speed_cell:
		speed_cell.text = str(current_character.speed if "speed" in current_character else 4)

## Sprint 26.9 Phase 8.3: Responsive stats grid to prevent horizontal scroll on mobile
func _on_viewport_resized() -> void:
	"""Handle viewport resize - adjust stats grid columns"""
	_apply_responsive_stats_grid()

func _apply_responsive_stats_grid() -> void:
	"""Adjust stats grid columns based on viewport width to prevent horizontal scroll on mobile"""
	if not stats_grid:
		return

	var viewport := get_viewport()
	if not viewport:
		return

	var viewport_width := viewport.get_visible_rect().size.x

	# Determine column count based on screen size
	# Mobile (<768px): 2 columns - fits well on small screens
	# Tablet (768-1024px): 3 columns - balanced layout
	# Desktop (>1024px): 5 columns - original layout, all stats visible
	var columns: int
	var h_spacing: int
	var v_spacing: int

	if viewport_width < 768:
		# Mobile: 2 columns, compact spacing
		columns = 2
		h_spacing = 8
		v_spacing = 8
	elif viewport_width < 1024:
		# Tablet: 3 columns, moderate spacing
		columns = 3
		h_spacing = 12
		v_spacing = 8
	else:
		# Desktop: 5 columns (all stats in one row), full spacing
		columns = 5
		h_spacing = 16
		v_spacing = 8

	# Apply columns and spacing
	stats_grid.columns = columns
	stats_grid.add_theme_constant_override("h_separation", h_spacing)
	stats_grid.add_theme_constant_override("v_separation", v_spacing)

	print("CharacterDetailsScreen: Stats grid adjusted to %d columns for %dpx viewport" % [columns, viewport_width])

func _update_equipment_display() -> void:
	"""Update equipment list with BBCode keyword links"""
	if not current_character or not equipment_rich_text:
		return
	
	if not "equipment" in current_character or current_character.equipment.size() == 0:
		equipment_rich_text.text = "[color=#808080]No equipment[/color]"
		return
	
	var equipment_bbcode := ""
	for item in current_character.equipment:
		var item_str := str(item)
		
		# Format equipment with clickable keywords
		var formatted_item := _format_equipment_with_keywords(item_str)
		equipment_bbcode += "• %s\n" % formatted_item
	
	equipment_rich_text.text = equipment_bbcode.strip_edges()

func _format_equipment_with_keywords(item_name: String) -> String:
	"""Format equipment name with BBCode keyword links for weapon keywords"""
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
	"""Handle keyword clicks in equipment list"""
	var meta_str := str(meta)

	if meta_str.begins_with("keyword:") and keyword_tooltip:
		var keyword := meta_str.substr(8)  # Remove "keyword:" prefix

		# Get click position for tooltip placement
		var click_position := equipment_rich_text.global_position

		# Show tooltip at the RichTextLabel position
		keyword_tooltip.show_for_keyword(keyword, click_position)

func _update_implants_display() -> void:
	"""Update implants section after equipment"""
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
	"""Save character changes and return"""
	print("CharacterDetailsScreen: Saving changes...")
	
	if not current_character:
		return
	
	# Equipment changes are now read-only (managed through dedicated UI)
	# Notes can still be edited
	
	# Mark campaign as modified (needs save)
	if GameStateManager:
		GameStateManager.mark_campaign_modified()
	
	print("CharacterDetailsScreen: Changes saved to character")
	
	# Return to crew management
	return_to_crew_management()

func _on_cancel_pressed() -> void:
	"""Cancel changes and return"""
	print("CharacterDetailsScreen: Canceling changes...")

	# Restore original data if possible
	if current_character and not original_data.is_empty():
		if current_character.has_method("from_dictionary"):
			current_character.from_dictionary(original_data)
			print("CharacterDetailsScreen: Restored original character data")

	# Return to crew management
	return_to_crew_management()

func return_to_crew_management() -> void:
	"""Navigate back to crew management screen"""
	# Clear temp data
	if GameStateManager and GameStateManager.has_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		GameStateManager.clear_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER)

	# Navigate back using standardized navigation
	GameStateManager.navigate_to_screen("crew_management")

func _on_add_equipment_pressed() -> void:
	"""Add equipment item via picker dialog (future feature)"""
	print("CharacterDetailsScreen: Equipment management through dedicated UI")
	# TODO: Navigate to equipment management screen or show picker dialog

func _on_remove_equipment_pressed() -> void:
	"""Remove equipment item (future feature)"""
	print("CharacterDetailsScreen: Equipment management through dedicated UI")
	# TODO: Navigate to equipment management screen

# ============ ADVANCEMENT SECTION ============

func _populate_advancement_section() -> void:
	"""Populate the advancement section with stat upgrades and training options"""
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
	"""Create XP display header for advancement section"""
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
	"""Create stat advancement grid with buttons"""
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
	"""Create a card for a single stat advancement option"""
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
	"""Create training options section"""
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
	"""Create a card for a single training option"""
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
	"""Handle stat advancement button press"""
	if not current_character:
		return
	
	print("CharacterDetailsScreen: Advancing stat - ", stat_name)
	
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
		
		print("CharacterDetailsScreen: %s" % result.message)
	else:
		print("CharacterDetailsScreen: Advancement failed - %s" % result.message)

func _on_training_pressed(training_type: String) -> void:
	"""Handle training purchase button press"""
	if not current_character:
		return
	
	print("CharacterDetailsScreen: Purchasing training - ", training_type)
	
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
		print("CharacterDetailsScreen: Already has this training")
		return
	
	if current_xp < cost:
		print("CharacterDetailsScreen: Insufficient XP - need %d, have %d" % [cost, current_xp])
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
	
	print("CharacterDetailsScreen: Purchased %s training for %d XP" % [training_type, cost])

func _character_to_dict(character: Resource) -> Dictionary:
	"""Convert Character resource to dictionary for advancement service"""
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
	"""Update Character resource from dictionary after advancement"""
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
	"""Populate bot upgrade section (credits-based upgrades instead of XP)"""
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
	"""Create header for bot upgrade section"""
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
	"""Create a card for a single bot upgrade option"""
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
	"""Create section showing installed bot upgrades"""
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
	"""Handle bot upgrade purchase button press"""
	if not current_character:
		return
	
	print("CharacterDetailsScreen: Installing bot upgrade - ", upgrade_id)
	
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
		
		print("CharacterDetailsScreen: Bot upgrade installed successfully")
	else:
		print("CharacterDetailsScreen: Bot upgrade installation failed")
