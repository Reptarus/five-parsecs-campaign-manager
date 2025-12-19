extends FiveParsecsCampaignPanel

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
var progress_container: VBoxContainer = null
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
	print("FinalPanel: Coordinator set")
	if coordinator and coordinator.has_signal("campaign_state_updated"):
		if not coordinator.campaign_state_updated.is_connected(_on_campaign_state_updated):
			coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
	sync_with_coordinator()

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
	call_deferred("_aggregate_campaign_data")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup final panel-specific content"""
	# Content built in _build_final_panel_ui
	pass

func _build_final_panel_ui() -> void:
	"""Build the complete final panel UI with styled cards"""
	if not content_container:
		push_error("FinalPanel: No content_container available")
		return
	
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()
	
	var main_scroll := ScrollContainer.new()
	main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(main_scroll)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", SPACING_LG)
	main_scroll.add_child(main_vbox)
	
	# 1. Progress Indicator
	progress_container = _create_progress_indicator()
	main_vbox.add_child(progress_container)
	
	# 2. Summary Cards Container
	summary_cards_container = VBoxContainer.new()
	summary_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_cards_container.add_theme_constant_override("separation", SPACING_MD)
	main_vbox.add_child(summary_cards_container)
	
	# 3. Crew Preview Section
	crew_preview_container = _create_crew_preview_section()
	main_vbox.add_child(crew_preview_container)
	
	# 3.5. Validation Feedback Panel (NEW)
	validation_panel = ValidationPanel.new()
	validation_panel.name = "ValidationPanel"
	main_vbox.add_child(validation_panel)
	
	# 4. Create Campaign Button
	create_button = _create_create_campaign_button()
	main_vbox.add_child(create_button)
	
	print("FinalPanel: UI built successfully")

func _create_progress_indicator(current_step: int = 7, total_steps: int = 7, step_title: String = "Review & Create") -> Control:
	"""Create Step 7/7 progress indicator with 100% bar"""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)
	
	var label := Label.new()
	label.text = "Step 7 of 7 - Review & Create"
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	container.add_child(label)
	
	# Progress bar
	var progress := ProgressBar.new()
	progress.value = 100.0
	progress.custom_minimum_size.y = 8
	
	# Style progress bar
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = COLOR_INPUT
	style_bg.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background", style_bg)
	
	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = COLOR_SUCCESS
	style_fill.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("fill", style_fill)
	
	container.add_child(progress)
	
	return container

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

	# Use base class method to get coordinator reference
	if not coordinator:
		coordinator = get_coordinator_reference()
	
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
		print("FinalPanel: ⚠️ No campaign data available from coordinator or signals")

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
	
	# Difficulty & Mode
	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty: %s | Mode: %s" % [
		config_data.get("difficulty", "Normal"),
		config_data.get("game_mode", "Standard")
	]
	difficulty_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	difficulty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(difficulty_label)
	
	# Victory Conditions
	var victory_conditions = config_data.get("victory_conditions", {})
	var selected_conditions = []
	for key in victory_conditions.keys():
		if victory_conditions[key] == true:
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

func _create_captain_summary_card() -> PanelContainer:
	"""Create Card 3: Captain Info"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	
	var captain_data = campaign_data.get("captain", {})
	var captain_name = captain_data.get("name", "")
	if captain_name.is_empty():
		var captain = captain_data.get("captain")
		if captain:
			if captain is Dictionary:
				captain_name = captain.get("character_name", captain.get("name", "Unknown Captain"))
			elif captain.has("character_name"):
				captain_name = captain.character_name
	
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
	
	# Captain Stats (using stat badges)
	var captain_stats_hbox := HBoxContainer.new()
	captain_stats_hbox.add_theme_constant_override("separation", SPACING_SM)
	
	# Extract captain stats safely
	var captain: Variant = captain_data.get("captain", captain_data)
	if captain is Dictionary:
		var combat: int = captain.get("combat_skill", captain.get("combat", 0))
		var reactions: int = captain.get("reactions", 0)
		var xp: int = captain.get("xp", 0)
		
		captain_stats_hbox.add_child(_create_stat_badge("Combat", combat, true))  # Show +
		captain_stats_hbox.add_child(_create_stat_badge("Reactions", reactions))
		captain_stats_hbox.add_child(_create_stat_badge("XP", xp))
	
	content.add_child(captain_stats_hbox)
	
	return _create_section_card("Captain", content, "", "👤")

func _create_crew_summary_card() -> PanelContainer:
	"""Create Card 4: Crew Summary (count, avg stats with stat badges)"""
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)

	# TYPE CONVERSION FIX: Handle mixed Array (Character objects + Dictionaries)
	var crew_members_raw: Array = campaign_data.get("crew", {}).get("members", [])
	var crew_members: Array[Dictionary] = []

	# Convert Character objects to Dictionaries
	for member in crew_members_raw:
		if member is Dictionary:
			crew_members.append(member)
		elif member != null and member.has_method("to_dict"):
			crew_members.append(member.to_dict())
		elif member != null:
			# Fallback: Extract properties manually from Character object
			var member_dict = {}
			if "character_name" in member:
				member_dict["character_name"] = member.character_name
			if "combat" in member:
				member_dict["combat"] = member.combat
			if "reactions" in member:
				member_dict["reactions"] = member.reactions
			crew_members.append(member_dict)

	# Crew Count (Emphasis on number)
	var count_label := Label.new()
	count_label.text = "%d Crew Members" % crew_members.size()
	count_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)  # Larger!
	count_label.add_theme_color_override("font_color", COLOR_ACCENT)  # Accent color!
	content.add_child(count_label)

	# Calculate and display average stats using stat badges
	if crew_members.size() > 0:
		var total_combat := 0
		var total_reactions := 0
		for member in crew_members:
			if member is Dictionary:
				# Check multiple possible key names
				total_combat += int(member.get("combat", member.get("combat_skill", 0)))
				total_reactions += int(member.get("reactions", member.get("reaction", 0)))

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
	var resources_data = campaign_data.get("resources", equipment_data.get("resources", {}))
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
	for member in crew_members:
		var card = CharacterCardScene.instantiate()
		card.current_variant = 0  # COMPACT = 80px
		card.custom_minimum_size = Vector2(200, 80)
		
		# Set character data
		if member is Character:
			card.set_character(member)
		elif member is Dictionary:
			# Create temporary Character from dict
			var temp_char = Character.new()
			temp_char.character_name = member.get("name", member.get("character_name", "Unknown"))
			temp_char.background = member.get("background", "")
			temp_char.char_class = member.get("class", "")
			temp_char.combat_skill = member.get("combat_skill", 0)
			temp_char.reactions = member.get("reactions", 0)
			card.set_character(temp_char)
		
		crew_hbox.add_child(card)

func _update_validation_feedback() -> void:
	"""Update validation feedback panel based on campaign data validation"""
	if not validation_feedback_container:
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
	if validation_panel:
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
		var state_manager = coordinator.state_manager if coordinator and coordinator.has("state_manager") else null
		
		var result = await service.finalize_campaign(campaign_data, state_manager)
		
		if result.success:
			print("FinalPanel: Campaign finalized successfully")
			campaign_creation_requested.emit(campaign_data)
			campaign_finalization_complete.emit(campaign_data)
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
		print("FinalPanel: Campaign validation failed: ", last_validation_errors)
	else:
		is_campaign_complete = _check_completion_requirements()
		
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
	
	# Check CREW phase - at least 4 crew members
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	if crew_members.size() >= 4:
		completed_phases += 1
		print("FinalPanel: ✅ CREW phase complete (%d members)" % crew_members.size())
	else:
		print("FinalPanel: ❌ CREW phase incomplete (%d/4 members)" % crew_members.size())
	
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
	"""Performs validation on the complete campaign data"""
	var errors: Array[String] = []
	
	# Validate campaign has basic structure
	if campaign_data.is_empty():
		errors.append("Campaign data is empty.")
		return errors
	
	# Validate config phase - check both "config" and "campaign_config" keys
	var config_data = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	if config_data.is_empty():
		errors.append("Campaign configuration is missing.")
	elif config_data.get("campaign_name", "").strip_edges().is_empty():
		errors.append("Campaign name is required.")
	
	# Validate crew phase
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	if crew_members.is_empty():
		errors.append("Campaign must have crew members.")
	
	# Validate captain phase - check multiple ways captain data can be stored
	var captain_data = campaign_data.get("captain", {})
	var has_captain = false
	if captain_data.get("captain"):
		has_captain = true
	elif captain_data.get("name", "") != "":
		has_captain = true
	elif captain_data.get("character_name", "") != "":
		has_captain = true
	elif captain_data.size() > 0:
		# Captain data exists with some content
		has_captain = true
	
	if not has_captain:
		errors.append("Campaign must have a captain.")
	
	# Calculate completion based on actual data (same logic as _check_completion_requirements)
	var completed_phases := 0
	var total_required := 5
	
	# CONFIG
	if config_data.get("campaign_name", "").strip_edges() != "":
		completed_phases += 1
	# CAPTAIN  
	if has_captain:
		completed_phases += 1
	# CREW
	if crew_members.size() >= 4:
		completed_phases += 1
	# SHIP
	var ship_data = campaign_data.get("ship", {})
	if ship_data.get("name", "") != "":
		completed_phases += 1
	# EQUIPMENT
	var equipment_data = campaign_data.get("equipment", {})
	if equipment_data.size() > 0:
		completed_phases += 1
	
	var completion_pct: float = (float(completed_phases) / float(total_required)) * 100.0
	if completion_pct < 80.0:
		errors.append("Campaign setup is only %.1f%% complete. Must be at least 80%% to create." % completion_pct)
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data with standardized metadata"""
	var data = campaign_data.duplicate()
	data["is_complete"] = is_campaign_complete
	data["validation_errors"] = last_validation_errors.duplicate()
	data["finalization_metadata"] = {
		"finalized_at": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"panel_type": "campaign_finalization"
	}
	return data

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation (BaseCampaignPanel compliance)"""
	return get_data()

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
			print("    Config: Campaign '%s'" % campaign_data.config.get("campaign_name", "Unknown"))
		if campaign_data.has("captain"):
			print("    Captain: '%s'" % campaign_data.captain.get("name", "Unknown"))
		if campaign_data.has("crew"):
			print("    Crew: %d members" % campaign_data.crew.get("members", []).size())
		if campaign_data.has("ship"):
			print("    Ship: '%s'" % campaign_data.ship.get("name", "Unknown"))
		
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
	var credits = equipment_data.get("starting_credits", equipment_data.get("credits", 0))
	var net_worth = credits - debt + equipment_value
	
	# Crew size validation
	var crew_data = campaign_data.get("crew", {})
	var crew_size = crew_data.get("members", []).size()
	
	# Output mathematical validation
	print("    Captain Total Skills: %d" % captain_total)
	print("    Equipment Value: %d credits" % equipment_value)
	print("    Net Worth: %d credits (Credits: %d - Debt: %d + Equipment: %d)" % [
		net_worth, credits, debt, equipment_value
	])
	print("    Crew Size: %d/4 minimum (%s)" % [crew_size, "VALID" if crew_size >= 4 else "INVALID"])
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
