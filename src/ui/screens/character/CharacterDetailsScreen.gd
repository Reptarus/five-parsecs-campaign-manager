# Character Details Screen - View and Edit Individual Character
# Allows editing character properties and equipment
class_name CharacterDetailsScreen
extends Control

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

# State
var current_character = null
var original_data: Dictionary = {}

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

	# Notes (if we add a notes field to Character)
	if notes_edit:
		notes_edit.text = ""  # Placeholder for future notes system

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
	"""Format equipment name with BBCode keyword links for traits"""
	# Common weapon traits as keywords
	var trait_keywords := ["Assault", "Bulky", "Heavy", "Pistol", "Melee", "Single-Use", 
	                       "Snap Shot", "Stun", "Piercing", "Area", "Critical"]
	
	var formatted := item_name
	
	# Detect traits in parentheses: "Infantry Laser (Assault, Bulky)"
	var trait_start := formatted.find("(")
	var trait_end := formatted.find(")")
	
	if trait_start != -1 and trait_end != -1:
		var traits_section := formatted.substr(trait_start + 1, trait_end - trait_start - 1)
		var formatted_traits := ""
		
		# Split by comma and format each trait
		var traits := traits_section.split(",")
		for i in range(traits.size()):
			var trait := traits[i].strip_edges()
			
			# Check if trait is a known keyword
			if trait in trait_keywords:
				formatted_traits += "[url=keyword:%s][color=#4FC3F7]%s[/color][/url]" % [trait, trait]
			else:
				formatted_traits += trait
			
			if i < traits.size() - 1:
				formatted_traits += ", "
		
		# Reconstruct item name with formatted traits
		var base_name := formatted.substr(0, trait_start)
		formatted = "%s(%s)" % [base_name, formatted_traits]
	
	return formatted

func _on_equipment_keyword_clicked(meta: Variant) -> void:
	"""Handle keyword clicks in equipment list"""
	var meta_str := str(meta)
	
	if meta_str.begins_with("keyword:") and keyword_tooltip:
		var keyword := meta_str.substr(8)  # Remove "keyword:" prefix
		
		# Get click position for tooltip placement
		var click_position := equipment_rich_text.global_position
		
		# Show tooltip
		keyword_tooltip.show_for_keyword(keyword, click_position)

func _on_save_pressed() -> void:
	"""Save character changes"""
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
