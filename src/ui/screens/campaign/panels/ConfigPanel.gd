@tool
extends FiveParsecsCampaignPanel

# Core systems and validation
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const StateManagerClass = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const FPCM_VictoryDescriptions = preload("res://src/game/victory/VictoryDescriptions.gd")
const HouseRulesDefinitions = preload("res://src/data/house_rules_definitions.gd")


# Existing signal for backward compatibility
signal config_updated(config: Dictionary)

# New self-management signals
signal configuration_complete(data: Dictionary)

# Granular signals for real-time integration
signal campaign_name_changed(name: String)
signal difficulty_changed(difficulty: int)
signal crew_size_changed(size: int)
signal ironman_toggled(enabled: bool)
signal house_rules_changed(enabled_rules: Array)

# UI References - initialized safely in _ready()
var campaign_name_input: LineEdit
var difficulty_option: OptionButton
var crew_size_option: OptionButton
var victory_condition_option: OptionButton
var story_track_toggle: CheckBox
var validation_panel: PanelContainer
var validation_icon: Label
var validation_text: Label

var current_config: Dictionary = {
	"name": "",
	"difficulty": 2, # GlobalEnums.DifficultyLevel.STANDARD
	"crew_size": 6, # Default crew size (4, 5, or 6)
	"victory_condition": "none",
	"story_track_enabled": false,
	"elite_ranks": 0,
	"house_rules": [] # Array of enabled house rule IDs
}

# House rules UI tracking
var house_rule_checkboxes: Dictionary = {} # rule_id -> CheckBox

# Panel state management - production-ready pattern
var is_panel_initialized: bool = false
var is_configuration_complete: bool = false
# last_validation_errors inherited from BaseCampaignPanel
var security_validator: SecurityValidator
var description_label: Label
var is_panel_valid: bool = false

# Panel lifecycle signals - Framework Bible compliant
# panel_ready signal now inherited from BaseCampaignPanel

# CRITICAL FIX: Recursion prevention guards
var _is_validating: bool = false
var _validation_scheduled: bool = false

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("Campaign Configuration", "Name your campaign and select victory conditions. Your choices here affect the entire campaign.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")
	
	# Set up proper focus management
	call_deferred("_setup_focus_management")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup config-specific content"""
	_initialize_self_management()
	_setup_difficulty_options()
	_setup_crew_size_options()
	_setup_victory_conditions()
	_connect_signals()
	_update_description()

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: ConfigPanel] INITIALIZATION ====")
	print("  Phase: 1 of 7 (Campaign Configuration)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# Check for coordinator access (will be null initially, but we want to track this)
	# Fixed: Check owner (CampaignCreationUI) instead of direct parent (content_container)
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	var has_coordinator = campaign_ui != null and campaign_ui.has_method("get_coordinator")
	print("  Has Coordinator Access: %s" % has_coordinator)
	if has_coordinator:
		var coordinator = campaign_ui.get_coordinator() if campaign_ui.has_method("get_coordinator") else null
		print("    Coordinator Available: %s" % (coordinator != null))
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var campaign_state_service = get_node_or_null("/root/CampaignStateService")
	var scene_router = get_node_or_null("/root/SceneRouter")
	var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")

	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    CampaignStateService: %s" % (campaign_state_service != null))
	print("    SceneRouter: %s" % (scene_router != null))
	print("    CampaignPhaseManager: %s" % (campaign_phase_manager != null))
	
	# Check current campaign data
	print("  === INITIAL CAMPAIGN DATA ===")
	print("    Current Config Keys: %s" % str(current_config.keys()))
	print("    Campaign Name: '%s'" % current_config.get("name", ""))
	print("    Difficulty: %d" % current_config.get("difficulty", 0))
	print("    Victory Condition: '%s'" % current_config.get("victory_condition", ""))
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Campaign Name Input: %s" % (campaign_name_input != null))
	print("    Difficulty Option: %s" % (difficulty_option != null))
	print("    Victory Condition Option: %s" % (victory_condition_option != null))
	print("    Story Track Toggle: %s" % (story_track_toggle != null))
	
	print("==== [PANEL: ConfigPanel] INIT COMPLETE ====\n")

func _setup_focus_management() -> void:
	"""Setup proper focus management for input fields"""
	if campaign_name_input:
		# Ensure the input field can receive focus
		campaign_name_input.focus_mode = Control.FOCUS_ALL
		campaign_name_input.grab_focus()
		
		# Handle focus events to maintain focus
		if not campaign_name_input.focus_entered.is_connected(_on_name_input_focus_entered):
			var result1 = campaign_name_input.focus_entered.connect(_on_name_input_focus_entered)
			if result1 != OK:
				push_error("ConfigPanel: Failed to connect focus_entered signal")
		if not campaign_name_input.focus_exited.is_connected(_on_name_input_focus_exited):
			var result2 = campaign_name_input.focus_exited.connect(_on_name_input_focus_exited)
			if result2 != OK:
				push_error("ConfigPanel: Failed to connect focus_exited signal")

func _on_name_input_focus_entered() -> void:
	"""Handle name input focus gained"""
	print("ConfigPanel: Name input gained focus")

func _on_name_input_focus_exited() -> void:
	"""Handle name input focus lost"""
	print("ConfigPanel: Name input lost focus")

func _initialize_self_management() -> void:
	"""Initialize state management and build card-based UI"""
	# Create security validator instance for input sanitization
	security_validator = SecurityValidator.new()
	
	print("ConfigPanel: Building card-based UI with design system")
	
	# Get or create main container
	var main_container = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer",
		func(): return create_basic_container("VBox"))
	
	# Clear existing content to rebuild with design system
	for child in main_container.get_children():
		child.queue_free()
	
	# Apply proper spacing between cards (24px)
	main_container.add_theme_constant_override("separation", SPACING_LG)
	
	# Add progress indicator at the top
	var progress = _create_progress_indicator(0, 7)  # Step 1 of 7
	main_container.add_child(progress)
	
	# Add visual separator after progress indicator
	var separator_space = Control.new()
	separator_space.custom_minimum_size.y = SPACING_LG
	main_container.add_child(separator_space)
	
	# Build card-based sections
	_build_campaign_name_section(main_container)
	_build_difficulty_section(main_container)
	_build_crew_size_section(main_container)
	_build_victory_section(main_container)
	_build_story_track_section(main_container)
	_build_house_rules_section(main_container)
	
	print("ConfigPanel: Card-based UI built successfully")

func _build_campaign_name_section(parent: Control) -> void:
	"""Build campaign name input with card design"""
	campaign_name_input = LineEdit.new()
	campaign_name_input.placeholder_text = "The Starlight Wanderers"
	_style_line_edit(campaign_name_input)
	
	var content = _create_labeled_input("Campaign Name", campaign_name_input)
	
	var card = _create_section_card(
		"CAMPAIGN IDENTITY",
		content,
		"Choose a memorable name for your crew's story"
	)
	parent.add_child(card)

func _build_difficulty_section(parent: Control) -> void:
	"""Build difficulty selector with card design and description"""
	difficulty_option = OptionButton.new()
	_style_option_button(difficulty_option)
	
	# Create description label for difficulty details
	description_label = Label.new()
	description_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	description_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Difficulty Level", difficulty_option))
	content.add_child(description_label)
	
	var card = _create_section_card(
		"CHALLENGE LEVEL",
		content,
		""
	)
	parent.add_child(card)

func _build_crew_size_section(parent: Control) -> void:
	"""Build crew size selector with card design and description"""
	crew_size_option = OptionButton.new()
	_style_option_button(crew_size_option)
	
	# Create description label for crew size details
	var crew_size_description_label = Label.new()
	crew_size_description_label.name = "CrewSizeDescriptionLabel"
	crew_size_description_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	crew_size_description_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	crew_size_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crew_size_description_label.text = "Crew size affects enemy number generation in battles"
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Crew Size", crew_size_option))
	content.add_child(crew_size_description_label)
	
	var card = _create_section_card(
		"CREW SIZE",
		content,
		"Determines how many crew members you'll manage and affects battle difficulty"
	)
	parent.add_child(card)

func _build_victory_section(parent: Control) -> void:
	"""Build victory condition selector with card design and rich descriptions"""
	victory_condition_option = OptionButton.new()
	_style_option_button(victory_condition_option)
	
	# Add description label for victory condition details
	var victory_description_label = Label.new()
	victory_description_label.name = "VictoryDescriptionLabel"
	victory_description_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	victory_description_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	victory_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	victory_description_label.text = "Select a victory condition to see details"
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Victory Condition", victory_condition_option))
	content.add_child(victory_description_label)
	
	var card = _create_section_card(
		"VICTORY GOAL",
		content,
		"Choose how you'll win this campaign (or select 'None' for sandbox play)"
	)
	parent.add_child(card)

func _build_story_track_section(parent: Control) -> void:
	"""Build story track toggle with card design"""
	story_track_toggle = CheckBox.new()
	story_track_toggle.text = "Enable Story Track"
	story_track_toggle.custom_minimum_size.y = TOUCH_TARGET_MIN
	story_track_toggle.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	story_track_toggle.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	var card = _create_section_card(
		"NARRATIVE MODE",
		story_track_toggle,
		"Enable for guided story missions and plot progression"
	)
	parent.add_child(card)


func _build_house_rules_section(parent: Control) -> void:
	"""Build house rules selection with collapsible sections by category"""
	house_rule_checkboxes.clear()

	# Create main container for all house rules
	var rules_container := VBoxContainer.new()
	rules_container.add_theme_constant_override("separation", SPACING_SM)

	# Get all available house rules from definitions
	var all_rules := HouseRulesDefinitions.get_all_rules()

	# Group by category for cleaner UI
	var categories := HouseRulesDefinitions.get_category_names()
	for category in categories:
		var category_rules := HouseRulesDefinitions.get_rules_by_category(category)
		if category_rules.is_empty():
			continue

		var category_info := HouseRulesDefinitions.get_category_info(category)

		# Category header
		var category_label := Label.new()
		category_label.text = category_info.get("name", category.capitalize())
		category_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		category_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		rules_container.add_child(category_label)

		# Add checkboxes for each rule in this category
		for rule in category_rules:
			var checkbox := CheckBox.new()
			checkbox.text = rule.get("name", "Unknown Rule")
			checkbox.tooltip_text = rule.get("description", "")
			checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
			checkbox.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			checkbox.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

			# Store reference for later access
			var rule_id: String = rule.get("id", "")
			house_rule_checkboxes[rule_id] = checkbox

			# Connect toggle signal
			checkbox.toggled.connect(_on_house_rule_toggled.bind(rule_id))

			rules_container.add_child(checkbox)

		# Small spacer between categories
		var spacer := Control.new()
		spacer.custom_minimum_size.y = SPACING_XS
		rules_container.add_child(spacer)

	var card = _create_section_card(
		"HOUSE RULES (Optional)",
		rules_container,
		"Enable optional rule modifications for your campaign (Core Rules p.65)"
	)
	parent.add_child(card)


func _on_house_rule_toggled(enabled: bool, rule_id: String) -> void:
	"""Handle house rule checkbox toggle"""
	var enabled_rules: Array = current_config.get("house_rules", [])

	if enabled:
		if not enabled_rules.has(rule_id):
			enabled_rules.append(rule_id)
	else:
		enabled_rules.erase(rule_id)

	current_config.house_rules = enabled_rules
	house_rules_changed.emit(enabled_rules)
	_emit_config_update()
	print("ConfigPanel: House rules updated - %d rules enabled" % enabled_rules.size())


# _emit_panel_ready method now inherited from BaseCampaignPanel

func _setup_difficulty_options() -> void:
	difficulty_option.clear()

	difficulty_option.add_item("Story", 1)      # GlobalEnums.DifficultyLevel.STORY
	difficulty_option.add_item("Standard", 2)   # GlobalEnums.DifficultyLevel.STANDARD
	difficulty_option.add_item("Challenging", 3) # GlobalEnums.DifficultyLevel.CHALLENGING
	difficulty_option.add_item("Hardcore", 4)   # GlobalEnums.DifficultyLevel.HARDCORE
	difficulty_option.add_item("Nightmare", 5)  # GlobalEnums.DifficultyLevel.NIGHTMARE

	difficulty_option.select(1) # Default to Standard

func _setup_crew_size_options() -> void:
	crew_size_option.clear()
	
	crew_size_option.add_item("4 Crew (Minimal)", 4)
	crew_size_option.add_item("5 Crew (Reduced)", 5)
	crew_size_option.add_item("6 Crew (Standard)", 6)
	
	crew_size_option.select(2) # Default to 6 Crew (Standard)

func _setup_victory_conditions() -> void:
	if not victory_condition_option:
		return

	victory_condition_option.clear()

	# Official Victory Conditions from Five Parsecs rules
	victory_condition_option.add_item("No Victory Condition", 0)
	victory_condition_option.add_item("Play 20 Campaign Turns", 1)
	victory_condition_option.add_item("Play 50 Campaign Turns", 2)
	victory_condition_option.add_item("Play 100 Campaign Turns", 3)
	victory_condition_option.add_item("Complete 3 Quests", 4)
	victory_condition_option.add_item("Complete 5 Quests", 5)
	victory_condition_option.add_item("Complete 10 Quests", 6)
	victory_condition_option.add_item("Win 20 Tabletop Battles", 7)
	victory_condition_option.add_item("Win 50 Tabletop Battles", 8)
	victory_condition_option.add_item("Upgrade 1 Character 10 Times", 9)
	victory_condition_option.add_item("Upgrade 3 Characters 10 Times", 10)
	victory_condition_option.add_item("Upgrade 5 Characters 10 Times", 11)
	victory_condition_option.add_item("Play 50 Turns in Challenging Mode", 12)
	victory_condition_option.add_item("Play 50 Turns in Hardcore Mode", 13)
	victory_condition_option.add_item("Play 50 Turns in Insanity Mode", 14)

	victory_condition_option.select(0) # Default to no victory condition

func _connect_signals() -> void:
	if campaign_name_input and campaign_name_input.has_signal("text_changed"):
		if not campaign_name_input.text_changed.is_connected(_on_campaign_name_changed):
			var result1 = campaign_name_input.text_changed.connect(_on_campaign_name_changed)
			if result1 != OK:
				push_error("ConfigPanel: Failed to connect text_changed signal")
	if difficulty_option and difficulty_option.has_signal("item_selected"):
		if not difficulty_option.item_selected.is_connected(_on_difficulty_selected):
			var result2 = difficulty_option.item_selected.connect(_on_difficulty_selected)
			if result2 != OK:
				push_error("ConfigPanel: Failed to connect difficulty item_selected signal")
	if crew_size_option and crew_size_option.has_signal("item_selected"):
		if not crew_size_option.item_selected.is_connected(_on_crew_size_selected):
			var result3 = crew_size_option.item_selected.connect(_on_crew_size_selected)
			if result3 != OK:
				push_error("ConfigPanel: Failed to connect crew_size item_selected signal")
	if victory_condition_option and victory_condition_option.has_signal("item_selected"):
		if not victory_condition_option.item_selected.is_connected(_on_victory_condition_selected):
			var result4 = victory_condition_option.item_selected.connect(_on_victory_condition_selected)
			if result4 != OK:
				push_error("ConfigPanel: Failed to connect victory_condition item_selected signal")
	if story_track_toggle and story_track_toggle.has_signal("toggled"):
		if not story_track_toggle.toggled.is_connected(_on_story_track_toggled):
			var result5 = story_track_toggle.toggled.connect(_on_story_track_toggled)
			if result5 != OK:
				push_error("ConfigPanel: Failed to connect toggled signal")

func _on_campaign_name_changed(new_text: String) -> void:
	"""Handle campaign name changes with focus preservation"""
	# Store the current cursor position
	var cursor_pos = campaign_name_input.caret_column if campaign_name_input else 0
	
	# Sanitize input using SecurityValidator
	var sanitized_name = new_text
	var needs_ui_update = false
	
	if security_validator:
		var validation_result = security_validator.validate_string_input(new_text, 50)
		if validation_result.valid:
			sanitized_name = validation_result.sanitized_value
			_clear_error_display()
			# Only update UI if sanitization actually changed the text
			needs_ui_update = (sanitized_name != new_text)
		else:
			# Handle validation failure
			_show_error_display(validation_result.error)
			validation_failed.emit([validation_result.error])
			# Don't return - allow the input to continue but mark as invalid
	
	# CRITICAL FIX: Update internal state immediately
	current_config.name = sanitized_name
	
	# CRITICAL FIX: Only modify input text if NOT currently focused AND sanitization changed text
	if needs_ui_update and campaign_name_input and not campaign_name_input.has_focus():
		campaign_name_input.text = sanitized_name
		# Restore cursor position if input was updated
		campaign_name_input.caret_column = min(cursor_pos, sanitized_name.length())
	
	# Emit granular signal for real-time integration
	campaign_name_changed.emit(sanitized_name)
	
	# Always trigger config change handling
	_handle_config_change()

func _on_difficulty_selected(index: int) -> void:
	var difficulty_value = difficulty_option.get_item_id(index)
	current_config.difficulty = difficulty_value
	_update_description()
	
	# Emit granular signal for real-time integration
	difficulty_changed.emit(difficulty_value)
	
	_handle_config_change()

func _on_crew_size_selected(index: int) -> void:
	var crew_size_value = crew_size_option.get_item_id(index)
	current_config.crew_size = crew_size_value
	_update_crew_size_description(crew_size_value)
	
	# Emit granular signal for real-time integration
	crew_size_changed.emit(crew_size_value)
	
	_handle_config_change()

func _on_victory_condition_selected(index: int) -> void:
	var victory_id = victory_condition_option.get_item_id(index)
	current_config.victory_condition = _get_victory_condition_string(victory_id)
	# Store the enum value as well for consistent usage
	current_config.victory_condition_enum = GlobalEnums.victory_condition_string_to_enum(current_config.victory_condition)
	_update_victory_description(victory_id)
	_handle_config_change()

func _on_story_track_toggled(enabled: bool) -> void:
	current_config.story_track_enabled = enabled
	
	# Emit granular signal for real-time integration (treating story track as ironman mode)
	ironman_toggled.emit(enabled)
	
	_handle_config_change()

func _handle_config_change() -> void:
	"""Handle any configuration change with validation and state updates"""
	# COMPREHENSIVE DEBUG OUTPUT - Data Flow Tracking
	print("\n==== [PANEL: ConfigPanel] DATA CHANGE ====")
	print("  Panel Phase: 1 of 7 (Campaign Configuration)")
	print("  === DATA BEING SAVED ===")
	print("    Campaign Name: '%s'" % current_config.get("name", ""))
	print("    Difficulty: %d (%s)" % [current_config.get("difficulty", 0), _get_difficulty_name(current_config.get("difficulty", 0))])
	print("    Crew Size: %d" % current_config.get("crew_size", 6))
	print("    Victory Condition: '%s'" % current_config.get("victory_condition", ""))
	print("    Story Track: %s" % current_config.get("story_track_enabled", false))
	print("    Elite Ranks: %d" % current_config.get("elite_ranks", 0))
	
	var config_data = get_config_data()
	print("  === FORMATTED CONFIG DATA ===")
	print("    Config Data Keys: %s" % str(config_data.keys()))
	print("    Is Valid: %s" % is_valid())
	print("    Completion Requirements Met: %s" % _check_completion_requirements())
	
	# Emit backward compatibility signal
	config_updated.emit(current_config)
	
	# Validate and check completion
	_validate_and_check_completion()
	
	# Emit panel data update for signal-based architecture (no arguments needed)
	panel_data_changed.emit()
	
	print("  === SIGNAL EMISSIONS ===")
	print("    config_updated signal emitted: %s" % str(current_config.keys()))
	print("    panel_data_changed signal emitted")
	print("==== [PANEL: ConfigPanel] DATA CHANGE COMPLETE ====\n")

func _throttle_config_change() -> void:
	"""Throttle config change handling to prevent validation cascades"""
	if _validation_scheduled:
		return
	
	_validation_scheduled = true
	# Use a short delay to batch rapid changes
	await get_tree().create_timer(0.1).timeout
	_handle_config_change()

func _get_victory_condition_string(victory_id: int) -> String:
	match victory_id:
		0: return "none"
		1: return "play_20_turns"
		2: return "play_50_turns"
		3: return "play_100_turns"
		4: return "complete_3_quests"
		5: return "complete_5_quests"
		6: return "complete_10_quests"
		7: return "win_20_battles"
		8: return "win_50_battles"
		9: return "upgrade_1_character_10_times"
		10: return "upgrade_3_characters_10_times"
		11: return "upgrade_5_characters_10_times"
		12: return "play_50_turns_challenging"
		13: return "play_50_turns_hardcore"
		14: return "play_50_turns_insanity"
		_: return "none"

func _update_description() -> void:
	var description: String = ""

	match current_config.difficulty:
		1: # GlobalEnums.DifficultyLevel.STORY
			description = "Story Mode: Casual play with reduced difficulty, more starting resources, easier combat encounters. Perfect for learning the game mechanics."
		2: # GlobalEnums.DifficultyLevel.STANDARD
			description = "Standard Mode: Core rules as written, balanced challenges, standard resource allocation. The authentic Five Parsecs experience."
		3: # GlobalEnums.DifficultyLevel.CHALLENGING
			description = "Challenging Mode: Increased enemy strength, tougher combat encounters, higher upkeep costs. For experienced captains seeking a challenge."
		4: # GlobalEnums.DifficultyLevel.HARDCORE
			description = "Hardcore Mode: Maximum difficulty with elite enemies, minimal starting resources, brutal combat encounters. The ultimate test of survival."
		5: # GlobalEnums.DifficultyLevel.NIGHTMARE
			description = "Nightmare Mode: Custom ultra-hard mode with extreme challenges, minimal resources, and the most difficult encounters possible."

	if description_label:
		description_label.text = description

func _update_crew_size_description(crew_size: int) -> void:
	"""Update crew size description based on selected size"""
	var crew_size_desc_label = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/CrewSizeDescriptionLabel")
	if not crew_size_desc_label:
		return
	
	var description: String = ""
	match crew_size:
		4:
			description = "Minimal Crew: Roll 2D6 and pick the LOWER result for enemy numbers. Fewer crew to manage, but battles are more challenging."
		5:
			description = "Reduced Crew: Roll 1D6 for enemy numbers. Standard difficulty with slightly smaller crew size."
		6:
			description = "Standard Crew: Roll 2D6 and pick the HIGHER result for enemy numbers. Full crew complement with easier battles."
		_:
			description = "Invalid crew size selected."
	
	crew_size_desc_label.text = description

func _update_victory_description(victory_id: int) -> void:
	"""Update victory condition description with rich details from VictoryDescriptions"""
	var victory_desc_label = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/VictoryDescriptionLabel")
	if not victory_desc_label:
		return
	
	# Map victory_id to GlobalEnums victory type
	var victory_type = _get_victory_enum_from_id(victory_id)
	
	if victory_type == GlobalEnums.FiveParsecsCampaignVictoryType.NONE:
		victory_desc_label.text = "Sandbox Mode: Play without a victory condition. Perfect for endless exploration and story-driven play."
		return
	
	# Use VictoryDescriptions for rich details
	var victory_data = FPCM_VictoryDescriptions.VICTORY_DATA.get(victory_type, {})
	if victory_data.is_empty():
		victory_desc_label.text = "No description available."
		return
	
	# Format rich description with metadata
	var desc_parts: Array[String] = []
	desc_parts.append(victory_data.get("full_desc", ""))
	desc_parts.append("\n[color=#10B981]Strategy:[/color] " + victory_data.get("strategy", ""))
	desc_parts.append("[color=#808080]Difficulty:[/color] " + victory_data.get("difficulty", "Unknown"))
	desc_parts.append("[color=#808080]Estimated Time:[/color] " + victory_data.get("estimated_hours", "Unknown") + " hours")
	
	victory_desc_label.text = "\n".join(desc_parts)

func _get_victory_enum_from_id(victory_id: int) -> int:
	"""Map victory option ID to GlobalEnums.FiveParsecsCampaignVictoryType"""
	match victory_id:
		0: return GlobalEnums.FiveParsecsCampaignVictoryType.NONE
		1: return GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20
		2: return GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50
		3: return GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100
		4: return GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3
		5: return GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5
		6: return GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10
		7: return GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20
		8: return GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50
		9: return GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_1_CHARACTER_10_TIMES
		10: return GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_3_CHARACTERS_10_TIMES
		11: return GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_5_CHARACTERS_10_TIMES
		12: return GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50_CHALLENGING
		13: return GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50_HARDCORE
		14: return GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50_INSANITY
		_: return GlobalEnums.FiveParsecsCampaignVictoryType.NONE

func get_config() -> Dictionary:
	return current_config.duplicate()

func get_config_data() -> Dictionary:
	"""Get configuration data in the format expected by FiveParsecsCampaignCreationStateManager"""
	var config_data = {
		"campaign_name": current_config.get("name", "").strip_edges(),
		"difficulty_level": current_config.get("difficulty", 2), # GlobalEnums.DifficultyLevel.STANDARD
		"crew_size": current_config.get("crew_size", 6),
		"victory_condition": current_config.get("victory_condition", "none"),
		"story_track_enabled": current_config.get("story_track_enabled", false),
		"elite_ranks": current_config.get("elite_ranks", 0),
		"house_rules": current_config.get("house_rules", []),
		"created_date": Time.get_datetime_string_from_system(),
		"version": "1.0"
	}
	return config_data

func is_valid() -> bool:
	return not current_config.name.strip_edges().is_empty()

func validate() -> Array[String]:
	"""Validate configuration and return error messages"""
	var errors: Array[String] = []
	
	if current_config.name.strip_edges().is_empty():
		errors.append("Campaign name is required")
	elif current_config.name.strip_edges().length() < 3:
		errors.append("Campaign name must be at least 3 characters")
	elif current_config.name.strip_edges().length() > 50:
		errors.append("Campaign name cannot exceed 50 characters")
	
	# Additional validation using SecurityValidator
	if security_validator and not current_config.name.is_empty():
		var validation_result = security_validator.validate_string_input(current_config.name, 50)
		if not validation_result.valid:
			errors.append(validation_result.error)
	
	return errors

func _validate_and_check_completion() -> void:
	"""Validate current configuration and check if panel is complete"""
	# CRITICAL FIX: Prevent validation race conditions
	if _is_validating:
		if not _validation_scheduled:
			_validation_scheduled = true
			call_deferred("_validate_and_check_completion")
		return
	
	_is_validating = true
	
	var validation_result = validate_panel()
	is_panel_valid = validation_result.valid
	
	if not validation_result.valid:
		is_configuration_complete = false
		# CRITICAL FIX: Get errors directly from validation result to ensure consistency
		var errors = validate() # Use direct validation method instead of cached errors
		last_validation_errors = errors
		validation_failed.emit(errors)
	else:
		_clear_error_display()
		last_validation_errors = [] # Clear errors on successful validation
		var was_complete = is_configuration_complete
		is_configuration_complete = _check_completion_requirements()
		
		# Emit completion signal when transitioning to complete state
		if is_configuration_complete and not was_complete:
			configuration_complete.emit(get_config_data())
			panel_completed.emit(get_config_data())
	
	_is_validating = false
	_validation_scheduled = false

func _check_completion_requirements() -> bool:
	"""Check if all requirements for completion are met"""
	# Required: Campaign name with valid length
	var name = current_config.name.strip_edges()
	if name.is_empty() or name.length() < 3:
		return false
	
	# Required: Valid difficulty selection (1-5 range)
	if current_config.difficulty < 1 or current_config.difficulty > 5:
		return false
	
	# Required: Valid victory condition
	if current_config.victory_condition.is_empty():
		return false
	
	return true

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return get_config_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("name"):
		campaign_name_input.text = data.name
		current_config.name = data.name
	if data.has("difficulty"):
		_set_difficulty_selection(data.difficulty)
		current_config.difficulty = data.difficulty
	if data.has("crew_size"):
		_set_crew_size_selection(data.crew_size)
		current_config.crew_size = data.crew_size
	if data.has("victory_condition"):
		_set_victory_condition_selection(data.victory_condition)
		current_config.victory_condition = data.victory_condition
	if data.has("story_track_enabled"):
		story_track_toggle.button_pressed = data.story_track_enabled
		current_config.story_track_enabled = data.story_track_enabled
	
	_update_config()

func _set_difficulty_selection(difficulty: int) -> void:
	"""Set difficulty selection safely"""
	for i in range(difficulty_option.get_item_count()):
		if difficulty_option.get_item_id(i) == difficulty:
			difficulty_option.select(i)
			break

func _set_crew_size_selection(crew_size: int) -> void:
	"""Set crew size selection safely"""
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == crew_size:
			crew_size_option.select(i)
			break

func _set_victory_condition_selection(victory_condition: String) -> void:
	"""Set victory condition selection safely"""
	for i in range(victory_condition_option.get_item_count()):
		if victory_condition_option.get_item_text(i).to_lower().contains(victory_condition.to_lower()):
			victory_condition_option.select(i)
			break

func _update_config() -> void:
	"""Update configuration and emit the config_updated signal"""
	_update_description()
	_handle_config_change()

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	"""Validate panel data and return simple boolean result"""
	var errors = validate()
	return errors.is_empty()

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation"""
	return get_config_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	current_config = {
		"name": "",
		"difficulty": 2, # GlobalEnums.DifficultyLevel.STANDARD
		"crew_size": 6, # Default crew size
		"victory_condition": "none",
		"story_track_enabled": false,
		"elite_ranks": 0
	}
	
	if campaign_name_input:
		campaign_name_input.text = ""
	if difficulty_option:
		difficulty_option.select(1) # Default to Standard
	if crew_size_option:
		crew_size_option.select(2) # Default to 6 Crew (Standard)
	if victory_condition_option:
		victory_condition_option.select(0) # Default to no victory condition
	if story_track_toggle:
		story_track_toggle.button_pressed = false
	
	_update_description()
	is_configuration_complete = false
	last_validation_errors.clear()

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("config") and state_data.config is Dictionary:
		var config_data = state_data.config
		if config_data.has("campaign_name"):
			current_config.name = config_data.campaign_name
			if campaign_name_input:
				campaign_name_input.text = config_data.campaign_name

func get_completion_status() -> bool:
	"""Get current completion status"""
	return is_configuration_complete

func get_validation_errors() -> Array[String]:
	"""Get current validation errors"""
	return last_validation_errors.duplicate()

func force_validation_check() -> void:
	"""Force a validation check and emit appropriate signals"""
	_validate_and_check_completion()

# Error Display System
func _show_error_display(error_text: String) -> void:
	"""Show error message in the UI"""
	var error_label = _get_or_create_error_label()
	error_label.text = "❌ " + error_text
	error_label.visible = true
	error_label.modulate = Color.RED

func _clear_error_display() -> void:
	"""Clear error message from the UI"""
	var error_label = _get_or_create_error_label()
	error_label.visible = false

func _get_or_create_error_label() -> Label:
	"""Get or create the error display label"""
	var error_label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/ErrorLabel")
	if not error_label:
		error_label = Label.new()
		error_label.name = "ErrorLabel"
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Insert after campaign name input
		var content = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
		if content:
			content.add_child(error_label)
			content.move_child(error_label, 2) # Place after campaign name section
		else:
			push_warning("ConfigPanel: Content container not found, cannot add error label")
	return error_label

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("ConfigPanel: No data to restore")
		return
	
	print("ConfigPanel: Restoring panel data: ", data.keys())
	
	# Restore campaign name
	if data.has("campaign_name") and campaign_name_input:
		var name = data.campaign_name
		current_config.name = name
		campaign_name_input.text = name
		print("ConfigPanel: Restored campaign name: ", name)
	
	# Restore difficulty
	if data.has("difficulty_level"):
		var difficulty = data.difficulty_level
		current_config.difficulty = difficulty
		_set_difficulty_selection(difficulty)
		print("ConfigPanel: Restored difficulty: ", difficulty)
	
	# Restore crew size
	if data.has("crew_size"):
		var crew_size = data.crew_size
		current_config.crew_size = crew_size
		_set_crew_size_selection(crew_size)
		print("ConfigPanel: Restored crew size: ", crew_size)
	
	# Restore victory condition
	if data.has("victory_condition"):
		var victory_condition = data.victory_condition
		current_config.victory_condition = victory_condition
		_set_victory_condition_selection(victory_condition)
		print("ConfigPanel: Restored victory condition: ", victory_condition)
	
	# Restore story track setting
	if data.has("story_track_enabled") and story_track_toggle:
		var story_track = data.story_track_enabled
		current_config.story_track_enabled = story_track
		story_track_toggle.button_pressed = story_track
		print("ConfigPanel: Restored story track: ", story_track)
	
	# Update UI and validation after restoration
	_update_description()
	_validate_and_check_completion()
	
	print("ConfigPanel: Panel data restoration complete")

## FALLBACK UI CREATION METHODS - Safe panel initialization

func _create_campaign_name_input() -> LineEdit:
	"""Create fallback campaign name input if scene node missing"""
	print("ConfigPanel DEBUG: Creating fallback campaign name input")
	var input = LineEdit.new()
	input.name = "CampaignNameInput"
	input.placeholder_text = "Enter campaign name..."
	input.focus_mode = Control.FOCUS_ALL
	# Apply design system styling
	_style_line_edit(input)
	return input

func _create_difficulty_option() -> OptionButton:
	"""Create fallback difficulty option if scene node missing"""
	print("ConfigPanel DEBUG: Creating fallback difficulty option")
	var option = OptionButton.new()
	option.name = "DifficultyOption"
	# Apply design system styling
	_style_option_button(option)
	return option

func _create_victory_condition_option() -> OptionButton:
	"""Create fallback victory condition option if scene node missing"""
	print("ConfigPanel DEBUG: Creating fallback victory condition option")
	var option = OptionButton.new()
	option.name = "VictoryConditionOption"
	# Apply design system styling
	_style_option_button(option)
	return option

func _create_story_track_toggle() -> CheckBox:
	"""Create fallback story track toggle if scene node missing"""
	print("ConfigPanel DEBUG: Creating fallback story track toggle")
	var toggle = CheckBox.new()
	toggle.name = "StoryTrackToggle"
	toggle.text = "Enable Story Track"
	toggle.custom_minimum_size.y = TOUCH_TARGET_MIN
	toggle.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	toggle.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	return toggle

func _create_validation_icon() -> Label:
	"""Create fallback validation icon if scene node missing"""
	print("ConfigPanel DEBUG: Creating fallback validation icon")
	var icon = Label.new()
	icon.name = "ValidationIcon"
	icon.text = "✓"
	icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	icon.add_theme_color_override("font_color", COLOR_SUCCESS)
	return icon

func _create_validation_text() -> Label:
	"""Create fallback validation text if scene node missing"""
	print("ConfigPanel DEBUG: Creating fallback validation text")
	var text = Label.new()
	text.name = "ValidationText"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	text.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return text

## Debug Helper Methods

func _get_difficulty_name(difficulty: int) -> String:
	"""Get human-readable difficulty name for debug output"""
	match difficulty:
		1: return "Story"
		2: return "Standard"
		3: return "Challenging"
		4: return "Hardcore"
		5: return "Nightmare"
		_: return "Unknown"

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	"""Mobile: Single column, 56dp targets, compact descriptions"""
	super._apply_mobile_layout()

	# Increase touch targets to TOUCH_TARGET_COMFORT (56dp)
	if difficulty_option:
		difficulty_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if crew_size_option:
		crew_size_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if victory_condition_option:
		victory_condition_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if story_track_toggle:
		story_track_toggle.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_COMFORT

func _apply_tablet_layout() -> void:
	"""Tablet: Two columns, 48dp targets, detailed descriptions"""
	super._apply_tablet_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if difficulty_option:
		difficulty_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if crew_size_option:
		crew_size_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if victory_condition_option:
		victory_condition_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if story_track_toggle:
		story_track_toggle.custom_minimum_size.y = TOUCH_TARGET_MIN
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN

func _apply_desktop_layout() -> void:
	"""Desktop: Multi-column, 48dp targets, full layout"""
	super._apply_desktop_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if difficulty_option:
		difficulty_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if crew_size_option:
		crew_size_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if victory_condition_option:
		victory_condition_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if story_track_toggle:
		story_track_toggle.custom_minimum_size.y = TOUCH_TARGET_MIN
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN
