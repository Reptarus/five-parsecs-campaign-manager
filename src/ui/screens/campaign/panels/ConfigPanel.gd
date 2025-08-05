@tool
extends FiveParsecsCampaignPanel

# GlobalEnums available as autoload singleton
# State management and validation integration
const StateManagerClass = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")


# Existing signal for backward compatibility
signal config_updated(config: Dictionary)

# New self-management signals
signal configuration_complete(data: Dictionary)

# Granular signals for real-time integration
signal campaign_name_changed(name: String)
signal difficulty_changed(difficulty: int)
signal ironman_toggled(enabled: bool)

@onready var campaign_name_input: LineEdit = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/CampaignName/LineEdit")
@onready var difficulty_option: OptionButton = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/Difficulty/OptionButton")
@onready var victory_condition_option: OptionButton = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/VictoryCondition/OptionButton")
@onready var story_track_toggle: CheckBox = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/StoryTrack/CheckBox")
@onready var validation_panel: PanelContainer = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/ConfigValidationPanel")
@onready var validation_icon: Label = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/ConfigValidationPanel/ValidationContent/ValidationIcon")
@onready var validation_text: Label = get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/ConfigValidationPanel/ValidationContent/ValidationText")

var current_config: Dictionary = {
	"name": "",
	"difficulty": GlobalEnums.DifficultyLevel.STANDARD,
	"victory_condition": "none",
	"story_track_enabled": false,
	"elite_ranks": 0
}

# Panel state management - production-ready pattern
var is_panel_initialized: bool = false
var is_configuration_complete: bool = false
var last_validation_errors: Array[String] = []

# Panel lifecycle signals - Framework Bible compliant
signal panel_ready

# CRITICAL FIX: Recursion prevention guards
var _is_validating: bool = false
var _validation_scheduled: bool = false

func _ready() -> void:
	# Set panel info before base initialization
	set_panel_info("Campaign Configuration", "Set up your campaign's basic settings including name, difficulty, and victory conditions.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# Set up proper focus management
	call_deferred("_setup_focus_management")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup config-specific content"""
	_initialize_self_management()
	_setup_difficulty_options()
	_setup_victory_conditions()
	_connect_signals()
	_update_description()

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
	"""Initialize state management and validation components"""
	# Create security validator for input sanitization
	security_validator = _validate_simple_input()

func _emit_panel_ready() -> void:
	"""Emit panel ready signal after deferred initialization"""
	if not is_panel_initialized:
		is_panel_initialized = true
		panel_ready.emit()

func _setup_difficulty_options() -> void:
	difficulty_option.clear()

	difficulty_option.add_item("Story", GlobalEnums.DifficultyLevel.STORY)
	difficulty_option.add_item("Standard", GlobalEnums.DifficultyLevel.STANDARD)
	difficulty_option.add_item("Challenging", GlobalEnums.DifficultyLevel.CHALLENGING)
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)
	difficulty_option.add_item("Nightmare", GlobalEnums.DifficultyLevel.NIGHTMARE)

	difficulty_option.select(1) # Default to Standard

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
	if victory_condition_option and victory_condition_option.has_signal("item_selected"):
		if not victory_condition_option.item_selected.is_connected(_on_victory_condition_selected):
			var result3 = victory_condition_option.item_selected.connect(_on_victory_condition_selected)
			if result3 != OK:
				push_error("ConfigPanel: Failed to connect victory_condition item_selected signal")
	if story_track_toggle and story_track_toggle.has_signal("toggled"):
		if not story_track_toggle.toggled.is_connected(_on_story_track_toggled):
			var result4 = story_track_toggle.toggled.connect(_on_story_track_toggled)
			if result4 != OK:
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

func _on_victory_condition_selected(index: int) -> void:
	var victory_id = victory_condition_option.get_item_id(index)
	current_config.victory_condition = _get_victory_condition_string(victory_id)
	_handle_config_change()

func _on_story_track_toggled(enabled: bool) -> void:
	current_config.story_track_enabled = enabled
	
	# Emit granular signal for real-time integration (treating story track as ironman mode)
	ironman_toggled.emit(enabled)
	
	_handle_config_change()

func _handle_config_change() -> void:
	"""Handle any configuration change with validation and state updates"""
	# Emit backward compatibility signal
	config_updated.emit(current_config)
	
	# Validate and check completion
	_validate_and_check_completion()
	
	# Emit panel data update for signal-based architecture (no arguments needed)
	panel_data_changed.emit()

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
		GlobalEnums.DifficultyLevel.STORY:
			description = "Story Mode: Casual play with reduced difficulty, more starting resources, easier combat encounters. Perfect for learning the game mechanics."
		GlobalEnums.DifficultyLevel.STANDARD:
			description = "Standard Mode: Core rules as written, balanced challenges, standard resource allocation. The authentic Five Parsecs experience."
		GlobalEnums.DifficultyLevel.CHALLENGING:
			description = "Challenging Mode: Increased enemy strength, tougher combat encounters, higher upkeep costs. For experienced captains seeking a challenge."
		GlobalEnums.DifficultyLevel.HARDCORE:
			description = "Hardcore Mode: Maximum difficulty with elite enemies, minimal starting resources, brutal combat encounters. The ultimate test of survival."
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			description = "Nightmare Mode: Custom ultra-hard mode with extreme challenges, minimal resources, and the most difficult encounters possible."

	if description_label:
		description_label.text = description

func get_config() -> Dictionary:
	return current_config.duplicate()

func get_config_data() -> Dictionary:
	"""Get configuration data in the format expected by FiveParsecsCampaignCreationStateManager"""
	var config_data = {
		"campaign_name": current_config.get("name", "").strip_edges(),
		"difficulty_level": current_config.get("difficulty", GlobalEnums.DifficultyLevel.STANDARD),
		"victory_condition": current_config.get("victory_condition", "none"),
		"story_track_enabled": current_config.get("story_track_enabled", false),
		"elite_ranks": current_config.get("elite_ranks", 0),
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
	
	# Required: Valid difficulty selection
	if not GlobalEnums or current_config.difficulty < 0:
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
		result.sanitized_value = get_config_data()
	else:
		result.valid = false
		result.error = errors[0] if errors.size() > 0 else "Validation failed"
		# Add additional errors as warnings since ValidationResult only has one error field
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation"""
	return get_config_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	current_config = {
		"name": "",
		"difficulty": GlobalEnums.DifficultyLevel.STANDARD,
		"victory_condition": "none",
		"story_track_enabled": false,
		"elite_ranks": 0
	}
	
	if campaign_name_input:
		campaign_name_input.text = ""
	if difficulty_option:
		difficulty_option.select(1) # Default to Standard
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
