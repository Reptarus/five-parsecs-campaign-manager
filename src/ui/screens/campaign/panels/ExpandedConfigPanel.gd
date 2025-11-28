extends FiveParsecsCampaignPanel

## GDScript 2.0: Five Parsecs Expanded Campaign Configuration Panel
## Production-ready implementation with comprehensive campaign setup options
## NOW INCLUDES VICTORY CONDITIONS (removes need for separate VictoryConditionsPanel)

# GlobalEnums available as autoload singleton
const FPCM_VictoryDescriptions = preload("res://src/game/victory/VictoryDescriptions.gd")
const CustomVictoryDialog = preload("res://src/ui/components/victory/CustomVictoryDialog.gd")

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

# Description labels for displaying option details
var campaign_type_description: Label
var victory_condition_description: RichTextLabel  # Rich text for full narrative + strategy
var story_track_description: Label
var tutorial_mode_description: Label

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

# Custom victory dialog
var custom_victory_button: Button
var custom_victory_dialog: Window

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
	"""Initialize campaign config panel with card-based design system"""
	# Get or create main container
	var main_container = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer", 
		func(): return create_basic_container("VBox"))
	
	# Clear existing content to rebuild with design system
	for child in main_container.get_children():
		child.queue_free()
	
	# Apply proper spacing between section cards
	main_container.add_theme_constant_override("separation", SPACING_LG)
	
	# Add progress indicator at the top
	var progress = _create_progress_indicator(1, 7)  # Step 2 of 7
	main_container.add_child(progress)
	
	# Add visual separator after progress indicator
	var separator_space = Control.new()
	separator_space.custom_minimum_size.y = SPACING_LG
	main_container.add_child(separator_space)
	
	# Build card-based UI sections
	_build_campaign_identity_section(main_container)
	_build_campaign_type_section(main_container)
	_build_victory_conditions_section(main_container)
	_build_story_track_section(main_container)
	_build_tutorial_section(main_container)
	_build_controls_section(main_container)
	
	_connect_signals()
	_setup_campaign_options()
	_update_display()
	_update_all_descriptions()
	call_deferred("emit_panel_ready")

func _build_campaign_identity_section(parent: Control) -> void:
	"""Build campaign name input section with card design"""
	campaign_name_input = LineEdit.new()
	campaign_name_input.placeholder_text = "Enter a memorable campaign name..."
	_style_line_edit(campaign_name_input)
	
	var input_wrapper = _create_labeled_input("Campaign Name", campaign_name_input)
	
	var card = _create_section_card(
		"CAMPAIGN IDENTITY",
		input_wrapper,
		"Choose a memorable name for your crew's journey across the Fringe"
	)
	parent.add_child(card)

func _build_campaign_type_section(parent: Control) -> void:
	"""Build campaign type selector with card design"""
	campaign_type_option = OptionButton.new()
	_style_option_button(campaign_type_option)
	
	# Create description label
	campaign_type_description = Label.new()
	campaign_type_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	campaign_type_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	campaign_type_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Campaign Type", campaign_type_option))
	content.add_child(campaign_type_description)
	
	var card = _create_section_card(
		"CAMPAIGN STYLE",
		content,
		""
	)
	parent.add_child(card)

func _build_victory_conditions_section(parent: Control) -> void:
	"""Build victory conditions section with card selectors"""
	victory_conditions_list = VBoxContainer.new()
	victory_conditions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create description label for selection summary
	victory_condition_description = RichTextLabel.new()
	victory_condition_description.bbcode_enabled = true
	victory_condition_description.fit_content = true
	victory_condition_description.custom_minimum_size = Vector2(0, 60)
	victory_condition_description.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	victory_condition_description.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_MD)
	content.add_child(victory_conditions_list)
	content.add_child(victory_condition_description)
	
	var card = _create_section_card(
		"VICTORY CONDITIONS",
		content,
		"Select one or more conditions - achieve ANY to win your campaign"
	)
	parent.add_child(card)

func _build_story_track_section(parent: Control) -> void:
	"""Build story track selector with card design"""
	story_track_option = OptionButton.new()
	_style_option_button(story_track_option)
	
	# Create description label
	story_track_description = Label.new()
	story_track_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	story_track_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	story_track_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Story Track (Optional)", story_track_option))
	content.add_child(story_track_description)
	
	var card = _create_section_card(
		"NARRATIVE OPTIONS",
		content,
		""
	)
	parent.add_child(card)

func _build_tutorial_section(parent: Control) -> void:
	"""Build tutorial mode selector with card design"""
	tutorial_mode_option = OptionButton.new()
	_style_option_button(tutorial_mode_option)
	
	# Create description label
	tutorial_mode_description = Label.new()
	tutorial_mode_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	tutorial_mode_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	tutorial_mode_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Tutorial Mode (Optional)", tutorial_mode_option))
	content.add_child(tutorial_mode_description)
	
	var card = _create_section_card(
		"LEARNING SUPPORT",
		content,
		""
	)
	parent.add_child(card)

func _build_controls_section(parent: Control) -> void:
	"""Build action buttons section"""
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", SPACING_SM)
	
	reset_button = Button.new()
	reset_button.text = "Reset to Defaults"
	reset_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button_row.add_child(reset_button)
	
	apply_button = Button.new()
	apply_button.text = "Apply Configuration"
	apply_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	
	# Style apply button as primary action
	var primary_style = StyleBoxFlat.new()
	primary_style.bg_color = COLOR_ACCENT
	primary_style.set_corner_radius_all(6)
	primary_style.set_content_margin_all(SPACING_MD)
	apply_button.add_theme_stylebox_override("normal", primary_style)
	
	var primary_hover = primary_style.duplicate() as StyleBoxFlat
	primary_hover.bg_color = COLOR_ACCENT_HOVER
	apply_button.add_theme_stylebox_override("hover", primary_hover)
	
	button_row.add_child(apply_button)
	
	parent.add_child(button_row)

func _create_description_labels() -> void:
	"""DEPRECATED: Description labels now created inline during section building"""
	# This method is kept for compatibility but does nothing
	# Description labels are now created in _build_*_section methods
	pass

func _update_all_descriptions() -> void:
	"""Update all description labels with current selection info"""
	_update_campaign_type_description()
	_update_victory_condition_description()
	_update_story_track_description()
	_update_tutorial_mode_description()

func _update_campaign_type_description() -> void:
	"""Update campaign type description based on current selection"""
	if not campaign_type_description or not campaign_type_option:
		return

	var index = campaign_type_option.selected
	if index < 0:
		return

	var selected_text = campaign_type_option.get_item_text(index)
	for key in campaign_types.keys():
		if campaign_types[key].name == selected_text:
			campaign_type_description.text = "→ " + campaign_types[key].description
			return

	campaign_type_description.text = ""

func _update_victory_condition_description() -> void:
	"""Update victory condition description summary (descriptions now shown inline in cards)"""
	if not victory_condition_description:
		return

	if selected_victory_conditions.is_empty():
		victory_condition_description.text = "[i]Click cards above to select victory conditions. Descriptions are shown on each card.[/i]"
		return

	# Build summary for selected conditions (full descriptions are on the cards)
	var condition_count = selected_victory_conditions.size()
	var summary_text = ""
	
	if condition_count == 1:
		summary_text = "[b]1 Victory Condition Selected[/b]\n"
		summary_text += "[color=#88aa88]Achieve this condition to win your campaign![/color]"
	else:
		summary_text = "[b]%d Victory Conditions Selected[/b]\n" % condition_count
		summary_text += "[color=#ffcc88]You can achieve ANY of these conditions to win![/color]"
	
	victory_condition_description.text = summary_text

func _update_story_track_description() -> void:
	"""Update story track description based on current selection"""
	if not story_track_description or not story_track_option:
		return

	var index = story_track_option.selected
	if index < 0:
		return

	var selected_text = story_track_option.get_item_text(index)
	for key in story_tracks.keys():
		if story_tracks[key].name == selected_text:
			story_track_description.text = "→ " + story_tracks[key].description
			return

	story_track_description.text = ""

func _update_tutorial_mode_description() -> void:
	"""Update tutorial mode description based on current selection"""
	if not tutorial_mode_description or not tutorial_mode_option:
		return

	var index = tutorial_mode_option.selected
	if index < 0:
		return

	var selected_text = tutorial_mode_option.get_item_text(index)
	for key in tutorial_modes.keys():
		if tutorial_modes[key].name == selected_text:
			tutorial_mode_description.text = "→ " + tutorial_modes[key].description
			return

	tutorial_mode_description.text = ""

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
	"""Setup victory conditions as interactive card selectors"""
	if not victory_conditions_list:
		return

	# Clear existing conditions
	for child in victory_conditions_list.get_children():
		child.queue_free()

	# Apply spacing between cards
	victory_conditions_list.add_theme_constant_override("separation", SPACING_SM)

	# Create card selectors for each victory condition
	for key in victory_conditions.keys():
		var condition = victory_conditions[key]
		var card = _create_victory_condition_card(key, condition)
		victory_conditions_list.add_child(card)

		print("ExpandedConfigPanel: Creating card - key: %s, name: %s" % [key, condition.name])

	# Add Custom button for creating custom victory conditions
	custom_victory_button = _create_add_button("+ Custom Victory Condition")
	custom_victory_button.tooltip_text = "Create a custom victory condition with adjusted targets"
	custom_victory_button.pressed.connect(_on_custom_victory_pressed)
	victory_conditions_list.add_child(custom_victory_button)

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

	_update_campaign_type_description()
	_update_display()
	_validate_and_complete()

func _create_victory_condition_card(key: String, condition: Dictionary) -> PanelContainer:
	"""Create an interactive card selector for a victory condition"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN * 2)  # 96dp tall
	card.name = "VictoryCard_%s" % key
	card.set_meta("victory_key", key)
	
	# Apply card styling (unselected state)
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)
	
	# Content layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	
	# Title row (name + checkmark indicator)
	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title = Label.new()
	title.text = condition.name
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	
	var checkmark = Label.new()
	checkmark.text = "✓"
	checkmark.name = "Checkmark"
	checkmark.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	checkmark.add_theme_color_override("font_color", COLOR_SUCCESS)
	checkmark.visible = false  # Hidden until selected
	title_row.add_child(checkmark)
	
	vbox.add_child(title_row)
	
	# Description (always visible inline)
	var desc = Label.new()
	desc.text = condition.description
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)
	
	# Target badge
	var target = Label.new()
	target.text = "Target: %s %s" % [condition.target, condition.type]
	target.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	target.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(target)
	
	card.add_child(vbox)
	
	# Make clickable
	card.gui_input.connect(_on_victory_card_clicked.bind(key, card))
	card.mouse_entered.connect(_on_victory_card_hover.bind(card))
	card.mouse_exited.connect(_on_victory_card_unhover.bind(card))
	
	return card

func _on_victory_card_clicked(event: InputEvent, key: String, card: PanelContainer) -> void:
	"""Handle click on victory condition card"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Toggle selection
		var is_selected = selected_victory_conditions.has(key)
		if is_selected:
			selected_victory_conditions.erase(key)
			_set_card_selected_state(card, false)
		else:
			selected_victory_conditions[key] = victory_conditions[key].duplicate()
			_set_card_selected_state(card, true)
		
		# Emit real-time update signals
		victory_conditions_changed.emit(selected_victory_conditions)
		_update_victory_condition_description()
		_update_display()
		_validate_and_complete()

func _on_victory_card_hover(card: PanelContainer) -> void:
	"""Handle mouse hover on victory card"""
	var is_selected = selected_victory_conditions.has(card.get_meta("victory_key"))
	if not is_selected:
		var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = COLOR_ACCENT
		style.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", style)

func _on_victory_card_unhover(card: PanelContainer) -> void:
	"""Handle mouse exit from victory card"""
	var is_selected = selected_victory_conditions.has(card.get_meta("victory_key"))
	if not is_selected:
		var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = COLOR_BORDER
		style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", style)

func _set_card_selected_state(card: PanelContainer, selected: bool) -> void:
	"""Update visual state of victory condition card"""
	var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var checkmark = card.get_node_or_null("VBoxContainer/HBoxContainer/Checkmark")
	
	if selected:
		# Selected state: focus border, subtle tint, visible checkmark
		style.border_color = COLOR_FOCUS
		style.set_border_width_all(3)
		style.bg_color = COLOR_FOCUS.lightened(0.85)
		if checkmark:
			checkmark.visible = true
	else:
		# Unselected state: normal border, default background
		style.border_color = COLOR_BORDER
		style.set_border_width_all(2)
		style.bg_color = COLOR_ELEVATED
		if checkmark:
			checkmark.visible = false
	
	card.add_theme_stylebox_override("panel", style)

func _on_victory_condition_toggled(condition_key: String, is_checked: bool) -> void:
	"""DEPRECATED: Legacy checkbox handler - kept for compatibility"""
	if is_checked:
		selected_victory_conditions[condition_key] = victory_conditions[condition_key].duplicate()
	else:
		selected_victory_conditions.erase(condition_key)

	victory_conditions_changed.emit(selected_victory_conditions)
	_update_victory_condition_description()
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

	_update_story_track_description()
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

	_update_tutorial_mode_description()
	_update_display()
	_validate_and_complete()

func _on_custom_victory_pressed() -> void:
	"""Open custom victory condition dialog"""
	if not custom_victory_dialog:
		custom_victory_dialog = CustomVictoryDialog.new()
		custom_victory_dialog.custom_condition_created.connect(_on_custom_condition_created)
		add_child(custom_victory_dialog)

	custom_victory_dialog.show_dialog()

func _on_custom_condition_created(condition_type: int, target_value: int) -> void:
	"""Handle custom victory condition creation"""
	var data = FPCM_VictoryDescriptions.get_victory_data(condition_type)
	var name = data.get("name", "Custom")

	# Create unique key for this custom condition
	var custom_key = "custom_%d_%d" % [condition_type, target_value]

	# Add to selected conditions
	selected_victory_conditions[custom_key] = {
		"name": "%s (Custom: %d)" % [name, target_value],
		"description": data.get("short_desc", "Custom victory condition"),
		"target": target_value,
		"type": condition_type,
		"is_custom": true
	}

	# Emit signals for real-time updates
	victory_conditions_changed.emit(selected_victory_conditions)
	_update_victory_condition_description()
	_update_display()
	_validate_and_complete()

	print("ExpandedConfigPanel: Created custom condition - %s with target %d" % [name, target_value])

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

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	"""Mobile: Single column, 56dp targets, compact victory descriptions"""
	super._apply_mobile_layout()

	# Increase touch targets to TOUCH_TARGET_COMFORT (56dp)
	if campaign_type_option:
		campaign_type_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if story_track_option:
		story_track_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if tutorial_mode_option:
		tutorial_mode_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if apply_button:
		apply_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if reset_button:
		reset_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT

	# Compact victory condition description for mobile
	if victory_condition_description:
		victory_condition_description.custom_minimum_size.y = 40

func _apply_tablet_layout() -> void:
	"""Tablet: Two columns, 48dp targets, detailed victory descriptions"""
	super._apply_tablet_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if campaign_type_option:
		campaign_type_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if story_track_option:
		story_track_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if tutorial_mode_option:
		tutorial_mode_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN
	if apply_button:
		apply_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if reset_button:
		reset_button.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Detailed victory condition description for tablet
	if victory_condition_description:
		victory_condition_description.custom_minimum_size.y = 60

func _apply_desktop_layout() -> void:
	"""Desktop: Multi-column, 48dp targets, full victory descriptions"""
	super._apply_desktop_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if campaign_type_option:
		campaign_type_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if story_track_option:
		story_track_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if tutorial_mode_option:
		tutorial_mode_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN
	if apply_button:
		apply_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if reset_button:
		reset_button.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Full victory condition description for desktop
	if victory_condition_description:
		victory_condition_description.custom_minimum_size.y = 80
