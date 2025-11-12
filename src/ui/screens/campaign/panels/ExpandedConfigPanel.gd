extends FiveParsecsCampaignPanel

## GDScript 2.0: Five Parsecs Expanded Campaign Configuration Panel
## Production-ready implementation with comprehensive campaign setup options
## NOW INCLUDES VICTORY CONDITIONS (removes need for separate VictoryConditionsPanel)

# GlobalEnums available as autoload singleton

# GDScript 2.0: Typed signals
signal campaign_config_updated(config: Dictionary)
signal campaign_setup_complete(config: Dictionary)

# Autonomous signals for coordinator pattern
signal campaign_config_data_complete(data: Dictionary)
signal campaign_config_validation_failed(errors: Array[String])

# Granular signals for real-time integration
signal campaign_config_data_changed(data: Dictionary)
signal victory_conditions_set(conditions: Dictionary)
signal victory_conditions_changed(conditions: Dictionary)  # NEW for real-time updates
signal story_track_selected(track: String)
signal tutorial_mode_selected(tutorial: String)

var local_campaign_config: Dictionary = {
	"campaign_name": "",
	"campaign_type": "standard",
	"victory_conditions": {},
	"story_track": "",
	"tutorial_mode": "",
	"is_complete": false
}

# UI Components with safe access
var campaign_name_input: LineEdit
var campaign_type_option: OptionButton
var victory_conditions_list: VBoxContainer
var story_track_option: OptionButton
var tutorial_mode_option: OptionButton
var apply_button: Button
var reset_button: Button
var summary_label: Label

# Campaign configuration options
var campaign_types: Dictionary = {
	"standard": {
		"name": "Standard Campaign",
		"description": "A full campaign with all systems enabled"
	},
	"story_focused": {
		"name": "Story-Focused Campaign",
		"description": "Emphasis on narrative and story track progression"
	},
	"combat_focused": {
		"name": "Combat-Focused Campaign",
		"description": "Emphasis on tactical combat and missions"
	},
	"exploration_focused": {
		"name": "Exploration-Focused Campaign",
		"description": "Emphasis on exploration and discovery"
	}
}

var victory_conditions: Dictionary = {
	"wealth": {
		"name": "Wealth Victory",
		"description": "Accumulate 10,000 credits",
		"target": 10000,
		"type": "credits"
	},
	"reputation": {
		"name": "Reputation Victory",
		"description": "Achieve maximum reputation with 3 factions",
		"target": 3,
		"type": "factions"
	},
	"exploration": {
		"name": "Exploration Victory",
		"description": "Visit 20 different worlds",
		"target": 20,
		"type": "worlds"
	},
	"combat": {
		"name": "Combat Victory",
		"description": "Defeat 50 enemies in total",
		"target": 50,
		"type": "enemies"
	},
	"story": {
		"name": "Story Victory",
		"description": "Complete 5 story missions",
		"target": 5,
		"type": "missions"
	}
}

var story_tracks: Dictionary = {
	"none": {
		"name": "No Story Track",
		"description": "Standard campaign without story progression"
	},
	"mystery_signal": {
		"name": "Mystery Signal",
		"description": "Your crew discovers a mysterious signal that leads to a greater conspiracy"
	},
	"faction_conflict": {
		"name": "Faction Conflict",
		"description": "Navigate the complex politics between warring factions"
	},
	"ancient_ruins": {
		"name": "Ancient Ruins",
		"description": "Explore ancient alien ruins and uncover their secrets"
	},
	"smuggler_network": {
		"name": "Smuggler Network",
		"description": "Build a criminal empire in the shadows"
	}
}

var tutorial_modes: Dictionary = {
	"none": {
		"name": "No Tutorial",
		"description": "Standard campaign without tutorial guidance"
	},
	"quick_start": {
		"name": "Quick Start Tutorial",
		"description": "Learn basic mechanics with guided steps"
	},
	"advanced": {
		"name": "Advanced Tutorial",
		"description": "Master all systems with comprehensive guidance"
	}
}

var selected_victory_conditions: Dictionary = {}
var selected_story_track: String = ""
var selected_tutorial_mode: String = ""

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("campaign_config") and state_data.campaign_config is Dictionary:
		var config_state_data = state_data.campaign_config
		if config_state_data.has("campaign_name"):
			# Update local campaign config state from external changes
			local_campaign_config = config_state_data.duplicate()
			_update_display()

func _ready() -> void:
	# GDScript 2.0: Set panel info before base initialization - updated to emphasize victory conditions
	set_panel_info("Campaign Setup", "Configure campaign name, victory conditions, and options. Victory conditions define how you'll achieve victory in your Five Parsecs campaign.")
	
	# GDScript 2.0: Use super() keyword
	super()
	
	# Initialize campaign config-specific functionality
	call_deferred("_initialize_components")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup campaign config-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_components() -> void:
	"""Initialize campaign config panel with safe component access and fallbacks"""
	# Safe component retrieval with fallback creation
	campaign_name_input = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/CampaignName/Value",
		func(): return _create_line_edit("CampaignNameInput"))
	campaign_type_option = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/CampaignType/Value",
		func(): return _create_option_button("CampaignTypeOption"))
	victory_conditions_list = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/VictoryConditions/Container",
		func(): return _create_container("VictoryConditionsContainer"))
	story_track_option = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/StoryTrack/Value",
		func(): return _create_option_button("StoryTrackOption"))
	tutorial_mode_option = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/TutorialMode/Value",
		func(): return _create_option_button("TutorialModeOption"))
	apply_button = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/ApplyButton",
		func(): return _create_button("ApplyButton", "Apply Configuration"))
	reset_button = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/ResetButton",
		func(): return _create_button("ResetButton", "Reset"))
	summary_label = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer/Content/Summary/Label",
		func(): return _create_label("SummaryLabel", "Campaign Summary"))

	_connect_signals()
	_setup_campaign_options()
	_update_display()
	call_deferred("emit_panel_ready")

func _connect_signals() -> void:
	"""Establish signal connections with error handling"""
	if campaign_name_input:
		campaign_name_input.text_changed.connect(_on_campaign_name_changed)
	if campaign_type_option:
		campaign_type_option.item_selected.connect(_on_campaign_type_changed)
	if story_track_option:
		story_track_option.item_selected.connect(_on_story_track_changed)
	if tutorial_mode_option:
		tutorial_mode_option.item_selected.connect(_on_tutorial_mode_changed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)

func _setup_campaign_options() -> void:
	"""Setup campaign configuration options"""
	_setup_campaign_type_options()
	_setup_victory_conditions()
	_setup_story_track_options()
	_setup_tutorial_mode_options()

func _setup_campaign_type_options() -> void:
	"""Setup campaign type options"""
	if not campaign_type_option:
		return
	
	campaign_type_option.clear()
	for key in campaign_types.keys():
		var campaign_type = campaign_types[key]
		campaign_type_option.add_item(campaign_type.name)
	
	# Set default selection
	campaign_type_option.select(0)

func _setup_victory_conditions() -> void:
	"""Setup victory conditions checkboxes"""
	if not victory_conditions_list:
		return
	
	# Clear existing conditions
	for child in victory_conditions_list.get_children():
		child.queue_free()
	
	# Create checkboxes for each victory condition
	for key in victory_conditions.keys():
		var condition = victory_conditions[key]
		var checkbox = CheckBox.new()
		checkbox.layout_mode = 2
		checkbox.text = condition.name
		checkbox.tooltip_text = condition.description
		checkbox.toggled.connect(func(is_checked: bool): _on_victory_condition_toggled(key, is_checked))
		victory_conditions_list.add_child(checkbox)
		
		# Debug output to verify correct names are being used
		print("ExpandedConfigPanel: Creating checkbox - key: %s, name: %s" % [key, condition.name])

func _setup_story_track_options() -> void:
	"""Setup story track options"""
	if not story_track_option:
		return
	
	story_track_option.clear()
	for key in story_tracks.keys():
		var story_track = story_tracks[key]
		story_track_option.add_item(story_track.name)
	
	# Set default selection
	story_track_option.select(0)

func _setup_tutorial_mode_options() -> void:
	"""Setup tutorial mode options"""
	if not tutorial_mode_option:
		return
	
	tutorial_mode_option.clear()
	for key in tutorial_modes.keys():
		var tutorial_mode = tutorial_modes[key]
		tutorial_mode_option.add_item(tutorial_mode.name)
	
	# Set default selection
	tutorial_mode_option.select(0)

# Signal handlers
func _on_campaign_name_changed(new_text: String) -> void:
	"""Handle campaign name change"""
	local_campaign_config.campaign_name = new_text
	_update_display()
	_validate_and_complete()

func _on_campaign_type_changed(index: int) -> void:
	"""Handle campaign type change"""
	if not campaign_type_option:
		return
	
	var selected_text = campaign_type_option.get_item_text(index)
	for key in campaign_types.keys():
		if campaign_types[key].name == selected_text:
			local_campaign_config.campaign_type = key
			break
	
	_update_display()
	_validate_and_complete()

func _on_victory_condition_toggled(condition_key: String, is_checked: bool) -> void:
	"""GDScript 2.0: Handle victory condition toggle with real-time updates"""
	if is_checked:
		selected_victory_conditions[condition_key] = victory_conditions[condition_key].duplicate()
	else:
		selected_victory_conditions.erase(condition_key)
	
	# GDScript 2.0: Emit new victory_conditions_changed signal for real-time updates
	victory_conditions_changed.emit(selected_victory_conditions)
	
	_update_display()
	_validate_and_complete()

func _on_story_track_changed(index: int) -> void:
	"""Handle story track change"""
	if not story_track_option:
		return
	
	var selected_text = story_track_option.get_item_text(index)
	for key in story_tracks.keys():
		if story_tracks[key].name == selected_text:
			selected_story_track = key
			break
	
	_update_display()
	_validate_and_complete()

func _on_tutorial_mode_changed(index: int) -> void:
	"""Handle tutorial mode change"""
	if not tutorial_mode_option:
		return
	
	var selected_text = tutorial_mode_option.get_item_text(index)
	for key in tutorial_modes.keys():
		if tutorial_modes[key].name == selected_text:
			selected_tutorial_mode = key
			break
	
	_update_display()
	_validate_and_complete()

func _on_apply_pressed() -> void:
	"""Apply campaign configuration"""
	print("ExpandedConfigPanel: Applying campaign configuration")
	
	# Update local campaign config data
	local_campaign_config.victory_conditions = selected_victory_conditions.duplicate()
	local_campaign_config.story_track = selected_story_track
	local_campaign_config.tutorial_mode = selected_tutorial_mode
	local_campaign_config.is_complete = true
	
	# Emit signals
	campaign_config_updated.emit(local_campaign_config)
	campaign_setup_complete.emit(local_campaign_config)
	campaign_config_data_complete.emit(local_campaign_config)
	victory_conditions_set.emit(selected_victory_conditions)
	story_track_selected.emit(selected_story_track)
	tutorial_mode_selected.emit(selected_tutorial_mode)
	
	# PHASE 6 INTEGRATION: Update coordinator state
	_notify_coordinator_of_campaign_config_update()
	
	print("ExpandedConfigPanel: Campaign configuration applied successfully")

func _on_reset_pressed() -> void:
	"""Reset campaign configuration to defaults"""
	print("ExpandedConfigPanel: Resetting campaign configuration")
	
	# Reset to default values
	local_campaign_config = {
		"campaign_name": "",
		"campaign_type": "standard",
		"victory_conditions": {},
		"story_track": "",
		"tutorial_mode": "",
		"is_complete": false
	}
	selected_victory_conditions = {}
	selected_story_track = ""
	selected_tutorial_mode = ""
	
	# Reset UI components
	_reset_ui_components()
	
	# Update display
	_update_display()
	
	print("ExpandedConfigPanel: Campaign configuration reset to defaults")

func _reset_ui_components() -> void:
	"""Reset UI components to default values"""
	if campaign_name_input:
		campaign_name_input.text = ""
	
	if campaign_type_option:
		campaign_type_option.select(0)
	
	if story_track_option:
		story_track_option.select(0)
	
	if tutorial_mode_option:
		tutorial_mode_option.select(0)
	
	# Reset victory condition checkboxes
	if victory_conditions_list:
		for child in victory_conditions_list.get_children():
			if child is CheckBox:
				child.button_pressed = false

func _update_display() -> void:
	"""Update the campaign configuration display"""
	_update_summary()

func _update_summary() -> void:
	"""Update summary display with current configuration"""
	if not summary_label:
		return
	
	var summary_text = "Campaign Configuration:\n"
	summary_text += "• Name: %s\n" % (local_campaign_config.campaign_name if local_campaign_config.campaign_name else "Unnamed")
	summary_text += "• Type: %s\n" % campaign_types.get(local_campaign_config.campaign_type, {}).get("name", "Standard")
	summary_text += "• Victory Conditions: %d selected\n" % selected_victory_conditions.size()
	summary_text += "• Story Track: %s\n" % (story_tracks.get(selected_story_track, {}).get("name", "None") if selected_story_track else "None")
	summary_text += "• Tutorial Mode: %s" % (tutorial_modes.get(selected_tutorial_mode, {}).get("name", "None") if selected_tutorial_mode else "None")
	
	summary_label.text = summary_text

func _validate_and_complete() -> void:
	"""Validate campaign configuration and update completion status"""
	var errors = _validate_campaign_config()
	
	if not errors.is_empty():
		local_campaign_config.is_complete = false
		campaign_config_validation_failed.emit(errors)
		return
	
	local_campaign_config.is_complete = true
	local_campaign_config.victory_conditions = selected_victory_conditions.duplicate()
	local_campaign_config.story_track = selected_story_track
	local_campaign_config.tutorial_mode = selected_tutorial_mode
	
	# Emit data change signal
	campaign_config_data_changed.emit(local_campaign_config)

func _validate_campaign_config() -> Array[String]:
	"""Validate campaign configuration and return error messages"""
	var errors: Array[String] = []
	
	# Validate campaign name
	if local_campaign_config.campaign_name.strip_edges().is_empty():
		errors.append("Campaign name cannot be empty")
	elif local_campaign_config.campaign_name.length() > 50:
		errors.append("Campaign name cannot exceed 50 characters")
	
	# Validate campaign type
	if not campaign_types.has(local_campaign_config.campaign_type):
		errors.append("Invalid campaign type selection")
	
	# Validate victory conditions (at least one required)
	if selected_victory_conditions.is_empty():
		errors.append("At least one victory condition must be selected")
	
	# Validate story track (optional)
	if not selected_story_track.is_empty() and not story_tracks.has(selected_story_track):
		errors.append("Invalid story track selection")
	
	# Validate tutorial mode (optional)
	if not selected_tutorial_mode.is_empty() and not tutorial_modes.has(selected_tutorial_mode):
		errors.append("Invalid tutorial mode selection")
	
	return errors

# PHASE 6 INTEGRATION: Coordinator communication
func _notify_coordinator_of_campaign_config_update() -> void:
	"""Notify the campaign coordinator of campaign config state changes"""
	# Try to find the coordinator through the scene tree
	var coordinator = _find_coordinator()
	if coordinator:
		coordinator.update_campaign_config_state(local_campaign_config)
		print("ExpandedConfigPanel: Notified coordinator of campaign config update")
	else:
		print("ExpandedConfigPanel: Warning - coordinator not found")

func _find_coordinator() -> Variant:
	"""Find the campaign coordinator in the scene tree"""
	# Fixed: Check owner first (CampaignCreationUI), then parent chain
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	if campaign_ui and campaign_ui.has_method("get_coordinator"):
		var coordinator = campaign_ui.get_coordinator()
		if coordinator and coordinator.has_method("update_campaign_config_state"):
			return coordinator
	
	# Look for coordinator in parent scenes (fallback)
	var current = get_parent()
	while current:
		if current.has_method("update_campaign_config_state"):
			return current
		current = current.get_parent()
	
	# CampaignCreationCoordinator is not an autoload - should be accessed through parent UI
	# This reference is invalid and should be removed
	
	return null

# Public API methods
func get_campaign_config() -> Dictionary:
	"""Get current campaign configuration"""
	return local_campaign_config.duplicate()

func set_campaign_config(config: Dictionary) -> void:
	"""Set campaign configuration from external source"""
	local_campaign_config = config.duplicate()
	selected_victory_conditions = config.get("victory_conditions", {}).duplicate()
	selected_story_track = config.get("story_track", "")
	selected_tutorial_mode = config.get("tutorial_mode", "")
	
	_update_display()
	_validate_and_complete()

func get_victory_conditions() -> Dictionary:
	"""Get selected victory conditions"""
	return selected_victory_conditions.duplicate()

func get_story_track() -> String:
	"""Get selected story track"""
	return selected_story_track

func get_tutorial_mode() -> String:
	"""Get selected tutorial mode"""
	return selected_tutorial_mode

# Required interface methods
func validate_panel() -> bool:
	"""Validate panel data and return simple boolean result"""
	var errors = _validate_campaign_config()
	return errors.is_empty()

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation"""
	return get_campaign_config_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	_on_reset_pressed()

func get_campaign_config_data() -> Dictionary:
	"""Get campaign config data in standardized format"""
	return {
		"campaign_name": local_campaign_config.campaign_name,
		"campaign_type": local_campaign_config.campaign_type,
		"victory_conditions": selected_victory_conditions.duplicate(),
		"story_track": selected_story_track,
		"tutorial_mode": selected_tutorial_mode,
		"is_complete": local_campaign_config.is_complete,
		"metadata": {
			"last_modified": Time.get_unix_time_from_system(),
			"version": "1.0",
			"panel_type": "expanded_campaign_config"
		}
	}

# Panel data persistence implementation
func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("ExpandedConfigPanel: No data to restore")
		return
	
	print("ExpandedConfigPanel: Restoring panel data: ", data.keys())
	
	# Restore campaign name
	if data.has("campaign_name"):
		local_campaign_config.campaign_name = data.campaign_name
	
	# Restore campaign type
	if data.has("campaign_type"):
		local_campaign_config.campaign_type = data.campaign_type
	
	# Restore victory conditions
	if data.has("victory_conditions"):
		selected_victory_conditions = data.victory_conditions.duplicate()
	
	# Restore story track
	if data.has("story_track"):
		selected_story_track = data.story_track
	
	# Restore tutorial mode
	if data.has("tutorial_mode"):
		selected_tutorial_mode = data.tutorial_mode
	
	# Restore completion status
	if data.has("is_complete"):
		local_campaign_config.is_complete = data.is_complete
	
	print("ExpandedConfigPanel: Restored campaign configuration")
	
	# Update UI with restored data
	_update_display()
	
	print("ExpandedConfigPanel: Panel data restoration complete")

func cleanup_panel() -> void:
	"""Clean up panel state when navigating away"""
	print("ExpandedConfigPanel: Cleaning up panel state")
	
	# Reset local campaign config
	local_campaign_config = {
		"campaign_name": "",
		"campaign_type": "standard",
		"victory_conditions": {},
		"story_track": "",
		"tutorial_mode": "",
		"is_complete": false
	}
	
	# Clear selected options
	selected_victory_conditions.clear()
	selected_story_track = ""
	selected_tutorial_mode = ""
	
	# Reset UI components if available
	if campaign_name_input:
		campaign_name_input.text = ""
	if campaign_type_option:
		campaign_type_option.select(0)
	if story_track_option:
		story_track_option.select(0)
	if tutorial_mode_option:
		tutorial_mode_option.select(0)
	
	# Clear victory conditions checkboxes
	if victory_conditions_list:
		for child in victory_conditions_list.get_children():
			if child is CheckBox:
				child.button_pressed = false
	
	print("ExpandedConfigPanel: Panel cleanup completed")

## ============ FALLBACK UI CREATION METHODS ============

func _create_line_edit(name: String) -> LineEdit:
	"""Create fallback LineEdit"""
	var line_edit = LineEdit.new()
	line_edit.name = name
	line_edit.placeholder_text = "Enter value..."
	print("ExpandedConfigPanel: Created fallback LineEdit: ", name)
	return line_edit

func _create_option_button(name: String) -> OptionButton:
	"""Create fallback OptionButton"""
	var option_button = OptionButton.new()
	option_button.name = name
	option_button.add_item("Default Option")
	print("ExpandedConfigPanel: Created fallback OptionButton: ", name)
	return option_button

func _create_container(name: String) -> VBoxContainer:
	"""Create fallback container"""
	var container = VBoxContainer.new()
	container.name = name
	print("ExpandedConfigPanel: Created fallback VBoxContainer: ", name)
	return container

func _create_button(name: String, text: String) -> Button:
	"""Create fallback Button"""
	var button = Button.new()
	button.name = name
	button.text = text
	print("ExpandedConfigPanel: Created fallback Button: ", name)
	return button

func _create_label(name: String, text: String) -> Label:
	"""Create fallback Label"""
	var label = Label.new()
	label.name = name
	label.text = text
	print("ExpandedConfigPanel: Created fallback Label: ", name)
	return label
