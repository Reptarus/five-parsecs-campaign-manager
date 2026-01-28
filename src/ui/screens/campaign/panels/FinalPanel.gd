extends FiveParsecsCampaignPanel

const STEP_NUMBER := 7  # Step 7 of 7 in campaign wizard (Final Review)

const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const CharacterCardScene = preload("res://src/ui/components/character/CharacterCard.tscn")

# Component preloads
const StatBadge = preload("res://src/ui/components/base/StatBadge.gd")
const ValidationPanel = preload("res://src/ui/components/feedback/ValidationPanel.gd")
const StarsOfTheStoryPanelScene = preload("res://src/ui/components/campaign/StarsOfTheStoryPanel.tscn")
const PlayerProfile = preload("res://src/core/player/PlayerProfile.gd")
const StarsOfTheStorySystem = preload("res://src/core/systems/StarsOfTheStorySystem.gd")

signal campaign_creation_requested(campaign_data: Dictionary)

# Autonomous signals for coordinator pattern
signal campaign_finalization_complete(data: Dictionary)
signal campaign_confirmed()  # New signal for Create Campaign button

# UI References - rebuilt programmatically
var summary_cards_container: VBoxContainer = null
var validation_feedback_container: Control = null  # Validation feedback panel
var validation_panel: ValidationPanel = null
var crew_preview_container: VBoxContainer = null
var create_button: Button = null

var campaign_data: Dictionary = {}
var campaign_state: Dictionary = {}  # Add missing campaign_state variable
var is_campaign_complete: bool = false
# Note: last_validation_errors is inherited from BaseCampaignPanel

# Coordinator reference for consistent access
var coordinator: Node = null

func set_coordinator(coord: Node) -> void:
	"""Set coordinator reference for consistent access"""
	coordinator = coord
	_coordinator = coord  # BUGFIX: Also set base class variable for consistency
	print("FinalPanel: Coordinator set")
	if coordinator and coordinator.has_signal("campaign_state_updated"):
		if not coordinator.campaign_state_updated.is_connected(_on_campaign_state_updated):
			coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
	# Defer sync to ensure coordinator is fully initialized
	call_deferred("sync_with_coordinator")

func sync_with_coordinator() -> void:
	"""Sync panel with coordinator state"""
	if not coordinator:
		print("FinalPanel: No coordinator available for sync")
		return
	print("FinalPanel: Syncing with coordinator")
	if coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		campaign_data = state.duplicate()
		_update_display()
		_validate_and_complete()

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update final panel with complete campaign state
	campaign_data = state_data.duplicate()
	_update_display()
	# Sprint 26.20: Emit standard panel signal for BaseCampaignPanel contract
	panel_data_changed.emit(get_panel_data())


func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("Campaign Review", "Review your campaign setup and create your adventure.")

	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()

	# Build final panel UI
	call_deferred("_build_final_panel_ui")

	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")

	# Initialize final panel-specific functionality
	_initialize_security_validator()

	# CRITICAL FIX: Aggregate campaign data when panel becomes ready
	# Delayed further to ensure coordinator is set by CampaignCreationUI
	call_deferred("_delayed_aggregate_campaign_data")

	# Connect visibility changed to refresh data when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)

	# SPRINT 5.1: Emit panel_ready after initialization complete
	call_deferred("emit_panel_ready")

func _on_visibility_changed() -> void:
	"""Refresh data when panel becomes visible"""
	if visible and is_inside_tree():
		print("FinalPanel: Visibility changed to visible - refreshing data")
		call_deferred("_aggregate_campaign_data")

func _delayed_aggregate_campaign_data() -> void:
	"""Delayed aggregation to ensure coordinator is set"""
	# Wait an extra frame for coordinator setup
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_aggregate_campaign_data()

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup final panel-specific content"""
	# Content built in _build_final_panel_ui
	pass

func _build_final_panel_ui() -> void:
	"""Build the complete final panel UI - use parent's scroll, don't nest

	SPRINT 27.2 FIX: BaseCampaignPanel.tscn already has FormContent (ScrollContainer)
	containing FormContainer (content_container). Creating another ScrollContainer
	inside causes layout issues - the inner scroll has undefined height and collapses.

	Solution: Add content directly to content_container (the VBoxContainer inside the
	existing ScrollContainer from the base class).
	"""
	if not content_container:
		push_error("FinalPanel: No content_container available")
		return

	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	# DON'T create ScrollContainer - FormContent already scrolls!
	# Add directly to content_container (FormContainer inside FormContent)

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display centrally

	# 1. Summary Cards Container
	summary_cards_container = VBoxContainer.new()
	summary_cards_container.name = "SummaryCards"
	summary_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_cards_container.add_theme_constant_override("separation", SPACING_MD)
	content_container.add_child(summary_cards_container)

	# 2. Crew Preview Section
	crew_preview_container = _create_crew_preview_section()
	content_container.add_child(crew_preview_container)

	# 3. Validation Feedback Panel
	validation_panel = ValidationPanel.new()
	validation_panel.name = "ValidationPanel"
	validation_feedback_container = validation_panel
	content_container.add_child(validation_panel)

	# 4. Create Campaign Button (at bottom of scroll content)
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_top", SPACING_MD)
	footer.add_theme_constant_override("margin_bottom", SPACING_SM)
	content_container.add_child(footer)

	create_button = _create_create_campaign_button()
	footer.add_child(create_button)

	print("FinalPanel: UI built successfully (no nested scroll)")

# NOTE: _create_progress_indicator() removed - CampaignCreationUI handles progress display centrally

func _create_crew_preview_section() -> VBoxContainer:
	"""Create crew preview section with CharacterCard COMPACT"""
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", SPACING_MD)
	
	var title := Label.new()
	title.text = "Your Crew"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	section.add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 100
	section.add_child(scroll)
	
	var crew_hbox := HBoxContainer.new()
	crew_hbox.add_theme_constant_override("separation", SPACING_SM)
	crew_hbox.name = "CrewCardsContainer"
	scroll.add_child(crew_hbox)
	
	return section

func _create_create_campaign_button() -> Button:
	"""Create large accent 'Create Campaign' button"""
	var btn := Button.new()
	btn.text = "Create Campaign & Start Adventure"
	btn.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Accent button styling
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = COLOR_ACCENT
	style_normal.set_corner_radius_all(8)
	style_normal.set_content_margin_all(SPACING_MD)
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = COLOR_ACCENT_HOVER
	style_hover.set_corner_radius_all(8)
	style_hover.set_content_margin_all(SPACING_MD)
	
	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = COLOR_TEXT_DISABLED
	style_disabled.set_corner_radius_all(8)
	style_disabled.set_content_margin_all(SPACING_MD)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	
	btn.pressed.connect(_on_create_campaign_pressed)
	
	return btn

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	# SecurityValidator is now available as a static class
	pass

func set_campaign_data(data: Dictionary) -> void:
	campaign_data = data
	_update_display()

func update_campaign_data(data: Dictionary) -> void:
	"""Alias for set_campaign_data - provides API compatibility"""
	set_campaign_data(data)

func _handle_campaign_state_update(state_data: Dictionary) -> void:
	"""Override from base class - auto-aggregate campaign data on state changes"""
	print("FinalPanel: Received state update with keys: %s" % str(state_data.keys()))

	# Auto-aggregate data from coordinator when any panel updates
	_aggregate_campaign_data()

func _aggregate_campaign_data() -> void:
	"""Aggregate campaign data from coordinator - enhanced for proper data access"""
	print("FinalPanel: Aggregating campaign data from coordinator")

	# Use base class method to get coordinator reference if needed
	if not coordinator:
		coordinator = get_coordinator_reference()
		print("FinalPanel: Got coordinator from base class: %s" % (coordinator != null))

	# Also sync with base class _coordinator for consistency
	if coordinator and not _coordinator:
		_coordinator = coordinator

	if coordinator and coordinator.has_method("get_unified_campaign_state"):
		var unified_state = coordinator.get_unified_campaign_state()
		print("FinalPanel: Retrieved unified campaign state with keys: %s" % str(unified_state.keys()))

		# Update campaign data
		campaign_data = unified_state.duplicate()
		campaign_state = unified_state.duplicate()

		# Update display with aggregated data
		_update_display()
		_validate_and_complete()

		print("FinalPanel: Campaign data aggregation complete")
		return

	# Fallback: Use signal-based data if coordinator not available
	if not campaign_state.is_empty():
		campaign_data = campaign_state.duplicate()
		_update_display()
		_validate_and_complete()
		print("FinalPanel: Used signal-based campaign data")
	else:
		print("FinalPanel: ⚠️ No campaign data available - showing placeholder UI")
		# Still update display to show placeholder/empty state
		_update_display()
		_validate_and_complete()

func _update_display() -> void:
	"""Update comprehensive campaign summary display with styled cards"""
	if not summary_cards_container:
		return

	# Clear existing cards
	for child in summary_cards_container.get_children():
		child.queue_free()

	# Build 5 summary cards with null-safety guards
	var config_card = _create_config_summary_card()
	if config_card:
		summary_cards_container.add_child(config_card)

	var ship_card = _create_ship_summary_card()
	if ship_card:
		summary_cards_container.add_child(ship_card)

	var captain_card = _create_captain_summary_card()
	if captain_card:
		summary_cards_container.add_child(captain_card)

	var crew_card = _create_crew_summary_card()
	if crew_card:
		summary_cards_container.add_child(crew_card)

	var equipment_card = _create_equipment_summary_card()
	if equipment_card:
		summary_cards_container.add_child(equipment_card)

	# Elite Bonuses card (shows Stars of the Story abilities and Elite Rank bonuses)
	var elite_card = _create_elite_bonuses_card()
	if elite_card:
		summary_cards_container.add_child(elite_card)

	# Update crew preview
	_update_crew_preview()

	# Update validation feedback panel (inserted before crew preview in UI hierarchy)
	_update_validation_feedback()

	# Update button state
	_update_create_button_state()

func _create_config_summary_card() -> PanelContainer:
	"""Create Card 1: Campaign Configuration"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	
	var config_data = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	
	# Campaign Name (Enhanced: XL size for primary data, accent color for prominence)
	var name_label := Label.new()
	name_label.text = config_data.get("campaign_name", "Unknown Campaign")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)  # XL for primary data hierarchy
	name_label.add_theme_color_override("font_color", COLOR_ACCENT)      # Accent color for emphasis
	content.add_child(name_label)
	
	# Difficulty & Mode - check both key names and convert integer to name
	var difficulty_value = config_data.get("difficulty", config_data.get("difficulty_level", 2))
	var difficulty_name = _get_difficulty_name(difficulty_value)
	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty: %s | Mode: %s" % [
		difficulty_name,
		config_data.get("game_mode", "Standard")
	]
	difficulty_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	difficulty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(difficulty_label)
	
	# Victory Conditions - Handle both dictionary and boolean formats
	var victory_conditions = config_data.get("victory_conditions", {})
	var selected_conditions = []
	for key in victory_conditions.keys():
		var value = victory_conditions[key]
		# Handle dictionary format from ExpandedConfigPanel: {"wealth": {name: "Wealth Victory", ...}}
		if value is Dictionary:
			var display_name = value.get("name", _get_victory_condition_display_name(key))
			selected_conditions.append(display_name)
		# Handle legacy boolean format: {"wealth": true}
		elif value == true:
			selected_conditions.append(_get_victory_condition_display_name(key))
	
	var victory_label := Label.new()
	if selected_conditions.size() > 0:
		victory_label.text = "Victory: %s" % ", ".join(selected_conditions)
	else:
		victory_label.text = "Victory: None Selected"
	victory_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	victory_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	victory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(victory_label)
	
	# Story Track
	var story_track = config_data.get("story_track_enabled", false)
	var story_label := Label.new()
	story_label.text = "Story Track: %s" % ("Enabled" if story_track else "Disabled")
	story_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	story_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(story_label)
	
	return _create_section_card("Campaign Configuration", content, "", "⚙️")

func _create_ship_summary_card() -> PanelContainer:
	"""Create Card 2: Ship Details"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	
	var ship_data = campaign_data.get("ship", {})
	
	# Ship Name (Enhanced: XL size, accent color for primary data)
	var ship_name: String = ship_data.get("name", "Unnamed Ship")
	var name_label := Label.new()
	name_label.text = ship_name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)  # XL for primary data
	name_label.add_theme_color_override("font_color", COLOR_ACCENT)     # Accent color
	content.add_child(name_label)
	
	# Ship Type (Secondary info)
	var type_label := Label.new()
	type_label.text = ship_data.get("type", "Unknown Type")
	type_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	type_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(type_label)
	
	# Ship Stats (using StatBadge components)
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", SPACING_SM)

	var hull_badge = StatBadge.new()
	hull_badge.stat_name = "Hull"
	hull_badge.stat_value = ship_data.get("hull_points", 0)
	stats_hbox.add_child(hull_badge)

	var cargo_badge = StatBadge.new()
	cargo_badge.stat_name = "Cargo"
	cargo_badge.stat_value = ship_data.get("cargo_capacity", 0)
	stats_hbox.add_child(cargo_badge)

	var debt_badge = StatBadge.new()
	debt_badge.stat_name = "Debt"
	debt_badge.stat_value = "%d cr" % ship_data.get("debt", 0)
	debt_badge.accent_color = COLOR_WARNING  # Orange for debt
	stats_hbox.add_child(debt_badge)

	content.add_child(stats_hbox)
	
	return _create_section_card("Ship Details", content, "", "🚀")

## Data Contract Helpers - Standardized captain data access
func _get_captain_name_from_data(captain_data: Dictionary) -> String:
	"""Get captain name using standardized data contract.
	Priority: character_name (canonical) > name (legacy) > nested captain object"""
	# Try canonical key first
	if captain_data.has("character_name") and not captain_data.get("character_name", "").is_empty():
		return captain_data["character_name"]
	# Try legacy key
	if captain_data.has("name") and not captain_data.get("name", "").is_empty():
		return captain_data["name"]
	# Try nested captain object
	var nested_captain = captain_data.get("captain", {})
	if nested_captain is Dictionary:
		if nested_captain.has("character_name"):
			return nested_captain.get("character_name", "Unknown Captain")
		return nested_captain.get("name", "Unknown Captain")
	elif nested_captain is Object and "character_name" in nested_captain:
		return nested_captain.character_name
	# Fallback
	return "Unknown Captain"

func _get_captain_stats_from_data(captain_data: Dictionary) -> Dictionary:
	"""Get captain stats from data with standardized key handling"""
	var captain = captain_data.get("captain", captain_data)
	if not captain is Dictionary:
		if captain is Object and captain.has_method("to_dictionary"):
			captain = captain.to_dictionary()
		else:
			return {}
	return {
		"combat": captain.get("combat_skill", captain.get("combat", 0)),
		"reactions": captain.get("reactions", 0),
		"toughness": captain.get("toughness", 0),
		"savvy": captain.get("savvy", 0),
		"tech": captain.get("tech", 0),
		"speed": captain.get("speed", captain.get("move", 4)),
		"xp": captain.get("xp", captain.get("experience", 0))
	}

func _create_captain_summary_card() -> PanelContainer:
	"""Create Card 3: Captain Info"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)

	var captain_data = campaign_data.get("captain", {})
	var captain_name = _get_captain_name_from_data(captain_data)
	
	# Captain Name (Enhanced: XL size, accent color)
	var name_label := Label.new()
	name_label.text = captain_name if not captain_name.is_empty() else "No Captain Assigned"
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)  # XL for primary data
	name_label.add_theme_color_override("font_color", COLOR_ACCENT)     # Accent color
	content.add_child(name_label)
	
	# Background, Class, Motivation
	var background: String = captain_data.get("background", "")
	var char_class: String = captain_data.get("class", "")
	var motivation: String = captain_data.get("motivation", "")
	
	if not background.is_empty():
		var bg_label := Label.new()
		bg_label.text = "Background: %s" % background
		bg_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		bg_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		content.add_child(bg_label)
	
	if not char_class.is_empty():
		var class_label := Label.new()
		class_label.text = "Class: %s" % char_class
		class_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		class_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		content.add_child(class_label)
	
	# Captain Stats Grid (2 rows x 3 cols - all 6 stats)
	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", SPACING_SM)
	stats_grid.add_theme_constant_override("v_separation", SPACING_XS)

	# Extract captain stats using helper (standardized key handling)
	var stats = _get_captain_stats_from_data(captain_data)
	if not stats.is_empty():
		# Row 1: Combat, Reactions, Toughness
		stats_grid.add_child(_create_stat_badge("Combat", stats.get("combat", 0), true))
		stats_grid.add_child(_create_stat_badge("Reactions", stats.get("reactions", 0)))
		stats_grid.add_child(_create_stat_badge("Toughness", stats.get("toughness", 0)))
		# Row 2: Savvy, Tech, Speed
		stats_grid.add_child(_create_stat_badge("Savvy", stats.get("savvy", 0)))
		stats_grid.add_child(_create_stat_badge("Tech", stats.get("tech", 0)))
		stats_grid.add_child(_create_stat_badge("Speed", stats.get("speed", 4)))
		# Row 3: XP (standalone - important stat)
		stats_grid.add_child(_create_stat_badge("XP", stats.get("xp", 0)))

	content.add_child(stats_grid)
	
	return _create_section_card("Captain", content, "", "👤")

func _create_crew_summary_card() -> PanelContainer:
	"""Create Card 4: Crew Summary (count, avg stats with stat badges)"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)

	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	var crew_members_raw: Array = campaign_data.get("crew", {}).get("members", [])
	var crew_members: Array = crew_members_raw  # Keep as Character objects

	# Crew Count (Emphasis on number)
	var count_label := Label.new()
	count_label.text = "%d Crew Members" % crew_members.size()
	count_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)  # Larger!
	count_label.add_theme_color_override("font_color", COLOR_ACCENT)  # Accent color!
	content.add_child(count_label)

	# Calculate and display average stats using stat badges (Sprint 26.3: Character-Everywhere)
	if crew_members.size() > 0:
		var total_combat := 0
		var total_reactions := 0
		for member in crew_members:
			# Character objects have direct properties
			total_combat += member.combat if "combat" in member else 0
			total_reactions += member.reactions if "reactions" in member else 0

		var avg_combat: int = total_combat / crew_members.size()
		var avg_reactions: int = total_reactions / crew_members.size()

		# Average stats (using StatBadge components)
		var avg_stats_hbox := HBoxContainer.new()
		avg_stats_hbox.add_theme_constant_override("separation", SPACING_SM)

		var combat_badge = StatBadge.new()
		combat_badge.stat_name = "Avg Combat"
		combat_badge.stat_value = avg_combat
		combat_badge.show_plus = true  # Shows "+5"
		combat_badge.accent_color = COLOR_SUCCESS  # Green for combat bonuses
		avg_stats_hbox.add_child(combat_badge)

		var reactions_badge = StatBadge.new()
		reactions_badge.stat_name = "Avg Reactions"
		reactions_badge.stat_value = avg_reactions
		avg_stats_hbox.add_child(reactions_badge)

		content.add_child(avg_stats_hbox)

	return _create_section_card("Crew Summary", content, "", "👥")

func _create_equipment_summary_card() -> PanelContainer:
	"""Create Card 5: Starting Equipment"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	
	var equipment_data = campaign_data.get("equipment", {})
	var equipment_list: Array = []
	var credits_value: int = 0
	if equipment_data is Array:
		equipment_list = equipment_data
	elif equipment_data is Dictionary:
		equipment_list = equipment_data.get("items", equipment_data.get("equipment", []))
		credits_value = equipment_data.get("starting_credits", equipment_data.get("credits", 0))

	# Credits
	var credits_label := Label.new()
	credits_label.text = "Starting Credits: %d cr" % credits_value
	credits_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	credits_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	content.add_child(credits_label)
	
	# Equipment Count
	# Equipment Count (Secondary info)
	var eq_label := Label.new()
	eq_label.text = "%d Equipment Items" % equipment_list.size()
	eq_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	eq_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(eq_label)
	
	# Resources
	var resources_data = campaign_data.get("resources", {})
	if resources_data.is_empty() and equipment_data is Dictionary:
		resources_data = equipment_data.get("resources", {})
	if not resources_data.is_empty():
		var story_points: int = resources_data.get("story_points", 0)
		var patrons: Array = resources_data.get("patrons", [])
		var rivals: Array = resources_data.get("rivals", [])
		
		if story_points > 0 or patrons.size() > 0 or rivals.size() > 0:
			var res_label := Label.new()
			res_label.text = "Story Points: %d | Patrons: %d | Rivals: %d" % [
				story_points,
				patrons.size(),
				rivals.size()
			]
			res_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			res_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			content.add_child(res_label)
	
	return _create_section_card("Starting Equipment", content, "", "🎒")


func _create_elite_bonuses_card() -> PanelContainer:
	"""Create Card 6: Elite Rank Bonuses & Stars of the Story"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_MD)

	# Get player profile for Elite Rank bonuses
	var profile = PlayerProfile.get_instance()
	var elite_ranks: int = profile.elite_ranks if profile else 0

	# Elite Rank header
	var rank_label := Label.new()
	if elite_ranks > 0:
		rank_label.text = "Elite Rank: %d" % elite_ranks
		rank_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		rank_label.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		rank_label.text = "New Player (No Elite Ranks)"
		rank_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		rank_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(rank_label)

	# Show bonuses if any
	if elite_ranks > 0 and profile:
		var bonus_summary = profile.get_bonus_summary()

		var bonuses_container := VBoxContainer.new()
		bonuses_container.add_theme_constant_override("separation", SPACING_XS)

		# Story Points bonus
		if bonus_summary.get("story_points", 0) > 0:
			var sp_label := Label.new()
			sp_label.text = "+%d Starting Story Points" % bonus_summary.story_points
			sp_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			sp_label.add_theme_color_override("font_color", COLOR_SUCCESS)
			bonuses_container.add_child(sp_label)

		# Bonus XP
		if bonus_summary.get("bonus_xp", 0) > 0:
			var xp_label := Label.new()
			xp_label.text = "+%d Bonus XP (distributable)" % bonus_summary.bonus_xp
			xp_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			xp_label.add_theme_color_override("font_color", COLOR_SUCCESS)
			bonuses_container.add_child(xp_label)

		# Extra starting characters
		if bonus_summary.get("extra_characters", 0) > 0:
			var char_label := Label.new()
			char_label.text = "+%d Extra Starting Characters" % bonus_summary.extra_characters
			char_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			char_label.add_theme_color_override("font_color", COLOR_SUCCESS)
			bonuses_container.add_child(char_label)

		# Stars of the Story uses
		var stars_label := Label.new()
		stars_label.text = "%d Stars of the Story Uses" % bonus_summary.get("stars_uses", 1)
		stars_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		stars_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		bonuses_container.add_child(stars_label)

		content.add_child(bonuses_container)

	# Add Stars of the Story panel preview
	var stars_header := Label.new()
	stars_header.text = "Emergency Abilities Available:"
	stars_header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	stars_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(stars_header)

	# Create a preview StarsOfTheStorySystem with current elite ranks and difficulty
	var config_data = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	var difficulty_raw = config_data.get("difficulty_level", config_data.get("difficulty", 2))
	var difficulty: int = difficulty_raw if difficulty_raw is int else 2  # Convert string to default 2

	var preview_stars_system = StarsOfTheStorySystem.new()
	preview_stars_system.initialize(elite_ranks, difficulty)

	# Instantiate and initialize the StarsOfTheStoryPanel
	var stars_panel = StarsOfTheStoryPanelScene.instantiate()
	if stars_panel:
		content.add_child(stars_panel)
		# Initialize after adding to tree
		if stars_panel.has_method("initialize"):
			stars_panel.initialize(preview_stars_system)

	return _create_section_card("Elite Bonuses & Abilities", content, "Bonuses from completed campaigns", "⭐")


func _update_crew_preview() -> void:
	"""Update crew preview with CharacterCard COMPACT"""
	if not crew_preview_container:
		return

	# Guard against calls during scene exit
	if not is_inside_tree():
		return

	var crew_hbox = crew_preview_container.get_node_or_null("ScrollContainer/CrewCardsContainer")
	if not crew_hbox:
		return
	
	# Clear existing cards
	for child in crew_hbox.get_children():
		child.queue_free()
	
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	
	if crew_members.is_empty():
		var no_crew_label := Label.new()
		no_crew_label.text = "No crew members created yet"
		no_crew_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		no_crew_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		crew_hbox.add_child(no_crew_label)
		return
	
	# Create CharacterCard COMPACT for each crew member
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	for member in crew_members:
		var card = CharacterCardScene.instantiate()
		card.current_variant = 0  # COMPACT = 80px
		card.custom_minimum_size = Vector2(200, 80)

		# Set character data directly
		if member is Character:
			card.set_character(member)
		else:
			push_warning("FinalPanel: Expected Character object, got %s" % type_string(typeof(member)))

		crew_hbox.add_child(card)

func _update_validation_feedback() -> void:
	"""Update validation feedback panel based on campaign data validation"""
	# Guard against freed instance
	if not is_instance_valid(validation_panel):
		return

	if not is_instance_valid(validation_feedback_container):
		return

	# Clear existing feedback
	for child in validation_feedback_container.get_children():
		child.queue_free()

	# Validate campaign data
	var errors := _validate_campaign_data()

	# Create feedback panel
	var feedback_panel := _create_validation_feedback_panel(errors)
	validation_feedback_container.add_child(feedback_panel)

func _create_validation_feedback_panel(errors: Array) -> PanelContainer:
	"""Create validation feedback panel with success/error messages"""
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style based on validation state
	var style := StyleBoxFlat.new()
	if errors.is_empty():
		# Success state: Green border
		style.bg_color = Color(COLOR_SUCCESS, 0.1)  # Subtle green background
		style.border_color = COLOR_SUCCESS
	else:
		# Error state: Red border
		style.bg_color = Color(COLOR_DANGER, 0.1)  # Subtle red background
		style.border_color = COLOR_DANGER
	
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)
	
	# Content
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	
	# Rich text label for colored messages
	var message_label := RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if errors.is_empty():
		# Success message
		message_label.text = "[color=#10B981]✅ Campaign ready to create![/color]"
	else:
		# Error messages with bulleted list
		var error_text := "[color=#DC2626]❌ Issues to fix:[/color]\n"
		for error in errors:
			error_text += "[color=#808080]• %s[/color]\n" % error
		message_label.text = error_text
	
	content.add_child(message_label)
	panel.add_child(content)
	
	return panel

func _update_create_button_state() -> void:
	"""Enable/disable Create Campaign button AND update validation panel"""
	if not create_button:
		return
	
	var errors = _validate_campaign_data()
	create_button.disabled = not errors.is_empty()
	
	# Update validation panel
	if is_instance_valid(validation_panel):
		if errors.is_empty():
			validation_panel.show_feedback(
				ValidationPanel.FeedbackType.SUCCESS,
				PackedStringArray([])
			)
		else:
			validation_panel.show_feedback(
				ValidationPanel.FeedbackType.ERROR,
				PackedStringArray(errors)
			)

func _get_difficulty_name(difficulty_value: Variant) -> String:
	"""Convert difficulty value (integer or string) to display name"""
	if difficulty_value is String:
		return difficulty_value
	if difficulty_value is int:
		match difficulty_value:
			1:
				return "Story"
			2:
				return "Standard"
			3:
				return "Challenging"
			4:
				return "Hardcore"
			5:
				return "Nightmare"
			_:
				return "Standard"
	return "Standard"

func _get_victory_condition_display_name(condition_key: String) -> String:
	"""Get display name for victory condition key"""
	match condition_key:
		"standard_victory":
			return "Standard Victory"
		"quest_victory":
			return "Quest Victory"
		"wealth_victory":
			return "Wealth Victory"
		"exploration_victory":
			return "Exploration Victory"
		"survival_victory":
			return "Survival Victory"
		"custom_victory":
			return "Custom Victory"
		"none":
			return "No Victory Condition"
		"play_20_turns":
			return "Play 20 Campaign Turns"
		"play_50_turns":
			return "Play 50 Campaign Turns"
		"play_100_turns":
			return "Play 100 Campaign Turns"
		"complete_3_quests":
			return "Complete 3 Quests"
		"complete_5_quests":
			return "Complete 5 Quests"
		"complete_10_quests":
			return "Complete 10 Quests"
		"win_20_battles":
			return "Win 20 Tabletop Battles"
		"win_50_battles":
			return "Win 50 Tabletop Battles"
		"upgrade_1_character_10":
			return "Upgrade 1 Character 10 Times"
		"upgrade_3_characters_10":
			return "Upgrade 3 Characters 10 Times"
		"upgrade_5_characters_10":
			return "Upgrade 5 Characters 10 Times"
		"challenging_50_turns":
			return "Play 50 Turns in Challenging Mode"
		"hardcore_50_turns":
			return "Play 50 Turns in Hardcore Mode"
		"insanity_50_turns":
			return "Play 50 Turns in Insanity Mode"
		_:
			return condition_key.capitalize().replace("_", " ")

func _on_create_campaign_pressed() -> void:
	"""Handle create campaign button with CampaignFinalizationService"""
	_validate_and_complete()
	
	if is_campaign_complete:
		create_button.disabled = true  # Prevent double-clicks
		print("FinalPanel: Initiating campaign finalization...")
		
		# Emit campaign_confirmed signal
		campaign_confirmed.emit()
		
		# Load and use CampaignFinalizationService
		const CampaignFinalizationService = preload("res://src/core/campaign/creation/CampaignFinalizationService.gd")
		var service = CampaignFinalizationService.new()
		var state_manager = coordinator.state_manager if coordinator and "state_manager" in coordinator else null
		
		var result = await service.finalize_campaign(campaign_data, state_manager)

		if result.success:
			# SPRINT 26.23: Extract the finalized Campaign resource from result
			var finalized_campaign = result.get("campaign")
			var save_path = result.get("save_path", "")
			print("FinalPanel: Campaign finalized successfully - saved to: %s" % save_path)
			campaign_creation_requested.emit(campaign_data)
			# SPRINT 26.23: Emit result with Campaign resource, not just raw dictionary
			campaign_finalization_complete.emit({
				"campaign": finalized_campaign,
				"save_path": save_path,
				"raw_data": campaign_data
			})
			# Note: CampaignCreationUI handles transition via _on_campaign_finalization_complete_from_panel
		else:
			print("FinalPanel: Finalization failed: ", result.error)
			create_button.disabled = false
			validation_failed.emit([result.error])
	else:
		print("FinalPanel: Campaign validation failed: ", last_validation_errors)
		validation_failed.emit(last_validation_errors)

func _validate_and_complete() -> void:
	"""Enhanced validation with coordinator pattern integration"""
	last_validation_errors = _validate_campaign_data()

	if not last_validation_errors.is_empty():
		is_campaign_complete = false
		validation_failed.emit(last_validation_errors)
		# Sprint 26.20: Emit standard panel signal for BaseCampaignPanel contract
		panel_validation_changed.emit(false)
		print("FinalPanel: Campaign validation failed: ", last_validation_errors)
	else:
		is_campaign_complete = _check_completion_requirements()
		# Sprint 26.20: Emit standard panel signal for BaseCampaignPanel contract
		panel_validation_changed.emit(is_campaign_complete)

		if is_campaign_complete:
			print("FinalPanel: Campaign finalization validation passed")
		else:
			print("FinalPanel: Campaign completion requirements not met")

func _check_completion_requirements() -> bool:
	"""Check if all requirements for campaign completion are met based on actual data presence"""
	# Must have campaign data
	if campaign_data.is_empty():
		print("FinalPanel: Completion check failed - empty campaign data")
		return false
	
	var completed_phases := 0
	var total_required := 5  # Core required phases
	
	# Check CONFIG phase - campaign_config with name
	var config_data = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	if config_data.get("campaign_name", "").strip_edges() != "":
		completed_phases += 1
		print("FinalPanel: ✅ CONFIG phase complete")
	else:
		print("FinalPanel: ❌ CONFIG phase incomplete - no campaign name")
	
	# Check CAPTAIN phase - captain with some data
	var captain_data = campaign_data.get("captain", {})
	if captain_data.size() > 0 and (captain_data.get("name", "") != "" or captain_data.get("character_name", "") != "" or captain_data.get("captain") != null):
		completed_phases += 1
		print("FinalPanel: ✅ CAPTAIN phase complete")
	else:
		print("FinalPanel: ❌ CAPTAIN phase incomplete")
	
	# Check CREW phase - must meet user's selected crew size (or minimum 4)
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	# CRITICAL FIX: Use crew_size from data if available, otherwise default to game minimum (4)
	var required_crew_size = crew_data.get("crew_size", crew_data.get("selected_size", crew_data.get("size", 4)))
	if required_crew_size < 4:
		required_crew_size = 4  # Enforce game minimum
	if crew_members.size() >= required_crew_size:
		completed_phases += 1
		print("FinalPanel: ✅ CREW phase complete (%d/%d members)" % [crew_members.size(), required_crew_size])
	else:
		print("FinalPanel: ❌ CREW phase incomplete (%d/%d members)" % [crew_members.size(), required_crew_size])
	
	# Check SHIP phase - ship with name
	var ship_data = campaign_data.get("ship", {})
	if ship_data.get("name", "") != "":
		completed_phases += 1
		print("FinalPanel: ✅ SHIP phase complete")
	else:
		print("FinalPanel: ❌ SHIP phase incomplete")
	
	# Check EQUIPMENT phase - any equipment data
	var equipment_data = campaign_data.get("equipment", {})
	if equipment_data.size() > 0:
		completed_phases += 1
		print("FinalPanel: ✅ EQUIPMENT phase complete")
	else:
		print("FinalPanel: ❌ EQUIPMENT phase incomplete")
	
	# Calculate completion percentage
	var completion_pct: float = (float(completed_phases) / float(total_required)) * 100.0
	print("FinalPanel: Completion: %.1f%% (%d/%d phases)" % [completion_pct, completed_phases, total_required])
	
	# Require at least 80% completion (4 of 5 core phases)
	return completion_pct >= 80.0

func _validate_campaign_data() -> Array[String]:
	"""Performs validation with warnings-only approach for optional fields.
	Only truly blocking errors prevent campaign creation.
	Missing optional data gets sensible defaults applied."""
	var errors: Array[String] = []

	# BLOCKING ERROR: Campaign data must exist
	if campaign_data.is_empty():
		errors.append("Campaign data is empty.")
		return errors

	# Validate config phase - apply defaults for missing optional data
	var config_data = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	if config_data.is_empty():
		# Apply default config instead of blocking
		config_data = {"campaign_name": "New Campaign", "difficulty_level": 2}
		campaign_data["campaign_config"] = config_data
		print("FinalPanel: Applied default campaign config")

	# Apply default campaign name if missing (instead of blocking)
	if config_data.get("campaign_name", "").strip_edges().is_empty():
		var default_name = "Campaign_%s" % Time.get_datetime_string_from_system().replace(":", "-")
		config_data["campaign_name"] = default_name
		print("FinalPanel: Applied default campaign name: %s" % default_name)

	# BLOCKING ERROR: Must have crew members
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	if crew_members.is_empty():
		errors.append("Campaign must have crew members.")

	# Validate captain phase - check multiple ways captain data can be stored
	# (Not blocking - first crew member can be promoted to captain)
	var captain_data = campaign_data.get("captain", {})
	var has_captain = false
	if captain_data.get("captain"):
		has_captain = true
	elif captain_data.get("name", "") != "":
		has_captain = true
	elif captain_data.get("character_name", "") != "":
		has_captain = true
	elif captain_data.size() > 0:
		has_captain = true

	if not has_captain and crew_members.size() > 0:
		# Promote first crew member to captain instead of blocking
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		var first_crew = crew_members[0]
		if first_crew and "character_name" in first_crew:
			campaign_data["captain"] = first_crew  # Store Character directly
			print("FinalPanel: Promoted first crew member to captain: %s" % first_crew.character_name)
	
	# Apply default ship name if missing (instead of blocking)
	var ship_data = campaign_data.get("ship", {})
	if ship_data.get("name", "").strip_edges().is_empty():
		if ship_data.is_empty():
			ship_data = {"name": "Wandering Star", "hull_points": 30}
			campaign_data["ship"] = ship_data
		else:
			ship_data["name"] = "Wandering Star"
		print("FinalPanel: Applied default ship name: Wandering Star")

	# Calculate completion for informational purposes
	var completed_phases := 0
	var total_required := 5

	# CONFIG (now always true after defaults)
	if config_data.get("campaign_name", "").strip_edges() != "":
		completed_phases += 1
	# CAPTAIN (might have been promoted from crew)
	captain_data = campaign_data.get("captain", {})
	has_captain = captain_data.size() > 0
	if has_captain:
		completed_phases += 1
	# CREW - use crew_size from data if available
	var validation_crew_size = crew_data.get("crew_size", crew_data.get("selected_size", crew_data.get("size", 4)))
	if validation_crew_size < 4:
		validation_crew_size = 4  # Enforce game minimum
	if crew_members.size() >= validation_crew_size:
		completed_phases += 1
	elif crew_members.size() > 0:
		# At least some crew, still counts as partial progress
		completed_phases += 1
	# SHIP (now always has name after defaults)
	if ship_data.get("name", "") != "":
		completed_phases += 1
	# EQUIPMENT (optional - don't count towards blocking)
	var equipment_data = campaign_data.get("equipment", {})
	if equipment_data.size() > 0:
		completed_phases += 1

	# Log completion status but don't block on low percentage
	var completion_pct: float = (float(completed_phases) / float(total_required)) * 100.0
	print("FinalPanel: Campaign completion: %.1f%% (%d/%d phases)" % [completion_pct, completed_phases, total_required])

	# With warnings-only approach, only block if truly critical data is missing
	# The only blocking error at this point is "no crew members"

	return errors

func get_data() -> Dictionary:
	"""DEPRECATED: Use get_panel_data() instead. Will be removed in future version."""
	push_warning("FinalPanel.get_data() is deprecated - use get_panel_data() instead")
	return get_panel_data()

func get_panel_data() -> Dictionary:
	"""Get panel data with standardized metadata (BaseCampaignPanel compliance)"""
	var data = campaign_data.duplicate()
	data["is_complete"] = is_campaign_complete
	data["validation_errors"] = last_validation_errors.duplicate()
	data["finalization_metadata"] = {
		"finalized_at": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"panel_type": "campaign_finalization"
	}
	return data

func is_valid() -> bool:
	return is_campaign_complete and last_validation_errors.is_empty()

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	"""Validate panel data - simplified validation"""
	var errors = _validate_campaign_data()
	return errors.is_empty()

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("FinalPanel: No data to restore")
		return
	
	print("FinalPanel: Restoring panel data: ", data.keys())
	
	# Restore campaign data
	campaign_data = data.duplicate()
	
	# Update completion status
	if data.has("is_complete"):
		is_campaign_complete = data.is_complete
	
	print("FinalPanel: Restored campaign data with %d sections" % campaign_data.size())
	
	# Update display with restored data
	_update_display()
	
	print("FinalPanel: Panel data restoration complete")

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: FinalPanel] INITIALIZATION ====")
	print("  Phase: 7 of 7 (Campaign Review)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# Check for coordinator access
	# Fixed: Check owner (CampaignCreationUI) instead of direct parent (content_container)
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	var has_coordinator = campaign_ui != null and campaign_ui.has_method("get_coordinator")
	print("  Has Coordinator Access: %s" % has_coordinator)
	if has_coordinator:
		var coordinator = campaign_ui.get_coordinator() if campaign_ui.has_method("get_coordinator") else null
		print("    Coordinator Available: %s" % (coordinator != null))
		if coordinator and coordinator.has_method("get_unified_campaign_state"):
			var campaign_state = coordinator.get_unified_campaign_state()
			print("    Campaign State Keys: %s" % str(campaign_state.keys()))
		else:
			print("    ⚠️  No unified campaign state available")
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var save_manager = get_node_or_null("/root/SaveManager")
	
	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    SaveManager: %s" % (save_manager != null))
	
	# Check current campaign data
	print("  === FINAL CAMPAIGN DATA ===")
	print("    Campaign Data Keys: %s" % str(campaign_data.keys()))
	print("    Campaign State Keys: %s" % str(campaign_state.keys()))
	print("    Is Campaign Complete: %s" % is_campaign_complete)
	print("    Last Validation Errors: %d" % last_validation_errors.size())
	
	if campaign_data.size() > 0:
		print("  === CAMPAIGN DATA SUMMARY ===")
		if campaign_data.has("config"):
			print("    Config: Campaign '%s'" % campaign_data["config"].get("campaign_name", "Unknown"))
		if campaign_data.has("captain"):
			print("    Captain: '%s'" % campaign_data["captain"].get("name", "Unknown"))
		if campaign_data.has("crew"):
			print("    Crew: %d members" % campaign_data["crew"].get("members", []).size())
		if campaign_data.has("ship"):
			print("    Ship: '%s'" % campaign_data["ship"].get("name", "Unknown"))
		
		# Add mathematical validation from test file
		print("  === MATHEMATICAL VALIDATION ===")
		_log_mathematical_validation()
	else:
		print("    ⚠️  NO CAMPAIGN DATA AVAILABLE - Previous panels may not be saving correctly")
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Create Button: %s" % (create_button != null))
	
	print("==== [PANEL: FinalPanel] INIT COMPLETE ====\n")

func _log_mathematical_validation() -> void:
	"""Mathematical validation debug output - adapted from test file"""
	if campaign_data.is_empty():
		print("    ⚠️  No campaign data for mathematical validation")
		return
	
	# Calculate captain total skills
	var captain_data = campaign_data.get("captain", {})
	var captain = captain_data.get("captain", captain_data)
	var captain_total = 0
	if captain is Dictionary:
		captain_total = captain.get("reactions", 0) + captain.get("speed", 0) + captain.get("combat_skill", 0) + captain.get("toughness", 0) + captain.get("savvy", 0) + captain.get("luck", 0)
	
	# Calculate equipment value
	var equipment_data = campaign_data.get("equipment", {})
	var equipment_items: Array = []
	if equipment_data is Array:
		equipment_items = equipment_data
	elif equipment_data is Dictionary:
		equipment_items = equipment_data.get("items", equipment_data.get("equipment", []))
	var equipment_value = 0
	for item in equipment_items:
		if item is Dictionary and item.has("value"):
			equipment_value += item.value
	
	# Calculate net worth
	var ship_data = campaign_data.get("ship", {})
	var debt = ship_data.get("debt", 0)
	var credits = 0
	if equipment_data is Dictionary:
		credits = equipment_data.get("starting_credits", equipment_data.get("credits", 0))
	var net_worth = credits - debt + equipment_value
	
	# Crew size validation
	var crew_data = campaign_data.get("crew", {})
	var crew_size = crew_data.get("members", []).size()
	var debug_required_crew = crew_data.get("crew_size", crew_data.get("selected_size", crew_data.get("size", 4)))
	if debug_required_crew < 4:
		debug_required_crew = 4

	# Output mathematical validation
	print("    Captain Total Skills: %d" % captain_total)
	print("    Equipment Value: %d credits" % equipment_value)
	print("    Net Worth: %d credits (Credits: %d - Debt: %d + Equipment: %d)" % [
		net_worth, credits, debt, equipment_value
	])
	print("    Crew Size: %d/%d required (%s)" % [crew_size, debug_required_crew, "VALID" if crew_size >= debug_required_crew else "INVALID"])
	print("    Campaign Ready: %s" % ("YES" if is_campaign_complete else "NO"))

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	"""Mobile: Single column, comfortable touch targets, compact summaries"""
	super._apply_mobile_layout()

	# Increase button touch target to TOUCH_TARGET_COMFORT for comfortable mobile use
	if create_button:
		create_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT

func _apply_tablet_layout() -> void:
	"""Tablet: Two columns, minimum touch targets, detailed summaries"""
	super._apply_tablet_layout()

	# Standard button touch target at TOUCH_TARGET_MIN for larger screens
	if create_button:
		create_button.custom_minimum_size.y = TOUCH_TARGET_MIN

func _apply_desktop_layout() -> void:
	"""Desktop: Multi-column, minimum touch targets, full summaries"""
	super._apply_desktop_layout()

	# Standard button touch target at TOUCH_TARGET_MIN for mouse-first interaction
	if create_button:
		create_button.custom_minimum_size.y = TOUCH_TARGET_MIN
