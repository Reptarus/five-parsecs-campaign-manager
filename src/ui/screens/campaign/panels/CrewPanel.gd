extends FiveParsecsCampaignPanel

# Enhanced CrewPanel with Coordinator Pattern for campaign creation
# Extends FiveParsecsCampaignPanel for standardized interface and enhanced functionality
# Implements autonomous operation with self-management capabilities

# Progress tracking
const STEP_NUMBER := 3  # Step 3 of 7 in campaign wizard (Core Rules: Config → Captain → Crew)

# Import character functionality
const CharacterClass = preload("res://src/core/character/Character.gd")
const CharacterCardScene = preload("res://src/ui/components/character/CharacterCard.tscn")
const CharacterCardScript = preload("res://src/ui/components/character/CharacterCard.gd")

# Security validation integration
const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

# Character creator integration
const CharacterCreatorClass = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")

# Enhanced Five Parsecs character generation system - now using static Character methods
const PatronSystem = preload("res://src/core/systems/PatronSystem.gd")
const RivalSystem = preload("res://src/core/rivals/RivalSystem.gd")
const CharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")

# Crew Flavor Details - Core Rules p.30 (We Met Through + Characterized As)
const CrewRelationshipManager = preload("res://src/core/campaign/crew/CrewRelationshipManager.gd")

# Existing signals for backward compatibility
# Sprint 26.3: Removed Dictionary type hints - actual types are Character or nested structures
signal crew_setup_complete(crew_data)
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character)
signal crew_valid(is_valid: bool)  # Wizard validation signal

# New autonomous signals for coordinator pattern
signal crew_data_complete(data)
signal crew_validation_failed(errors: Array[String])

# Additional crew-specific signals
signal crew_updated(crew: Array)
signal crew_member_selected(member)  # CharacterClass reference removed

# Granular signals for real-time integration
# Sprint 26.3: member_data may be Character object or Dictionary
signal crew_member_added(member_data)
signal crew_composition_changed(composition: Array)

# Enhanced state management and validation logic
var local_crew_data: Dictionary = {
	"members": [],
	"size": 0,
	"captain": null,
	"has_captain": false,
	"patrons": [],
	"rivals": [],
	"starting_equipment": [],
	"is_complete": false,
	# Core Rules p.30 - Crew Flavor Details
	"crew_flavor": {
		"meeting_story": "",
		"characteristic": "",
		"relationships": {}
	}
}

# Crew flavor manager instance - Core Rules p.30 (We Met Through + Characterized As)
var crew_relationship_manager: CrewRelationshipManager = null

# Base crew component properties - UNIFIED DATA: crew_members is now a getter
var crew_members: Array:
	get: return local_crew_data.get("members", [])
	set(value): local_crew_data["members"] = value
var current_captain = null  # CharacterClass reference removed

# Deduplication tracking to prevent duplicate crew members (Sprint 6 fix)
var _added_character_ids: Dictionary = {}  # Track by character name to prevent duplicates
const MIN_CREW_SIZE: int = 1
const MAX_CREW_SIZE: int = 8

# Panel state management - production-ready pattern
var is_panel_initialized: bool = false
var is_crew_complete: bool = false
# Note: last_validation_errors is inherited from BaseCampaignPanel
var security_validator: SecurityValidator

# UNIFIED: panel_data is now a getter that returns local_crew_data
var panel_data: Dictionary:
	get: return local_crew_data
	set(value): local_crew_data = value

# Enhanced Five Parsecs system instances
var patron_system: PatronSystem = null
var rival_system: RivalSystem = null
var generated_patrons: Array[Dictionary] = []
var generated_rivals: Array[Dictionary] = []

# Panel lifecycle signals - Framework Bible compliant
signal panel_data_updated(data: Dictionary)

# PHASE 1 INTEGRATION: InitialCrewCreation connection
var crew_creation_instance: Control = null

# ============ RUNTIME TYPE VALIDATION ============
# Safe crew member management with runtime type checking

func add_crew_member(member) -> bool:
	"""Add crew member - converts Dictionary to Character (Sprint 26.3: Character-Everywhere)"""
	var character_to_add: Character = null

	if member is Character:
		character_to_add = member
	elif member is Dictionary:
		# Convert Dictionary to Character object (Sprint 26.3: Character-Everywhere)
		character_to_add = _reconstruct_character_from_dict(member)
		if not character_to_add:
			push_error("CrewPanel: Failed to convert Dictionary to Character")
			return false
	else:
		push_error("CrewPanel: Invalid crew member type: %s" % type_string(typeof(member)))
		return false

	# UNIFIED: Append Character object to local_crew_data.members
	local_crew_data["members"].append(character_to_add)
	_validate_crew_setup()
	print("CrewPanel: Added crew member '%s', total: %d" % [character_to_add.character_name, local_crew_data.members.size()])
	return true

func safe_get_crew_member(index: int):
	"""Safely get crew member by index"""
	if index >= 0 and index < crew_members.size():
		return crew_members[index]
	return null

func get_crew_count() -> int:
	"""Get current crew count"""
	return crew_members.size()
var crew_creation_container: Control = null

# UI Components - using safe access pattern
var crew_size_option: OptionButton
var crew_list: Control  # Can be either ItemList or VBoxContainer
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

# UI component references - all UI now provided by InitialCrewCreation
# These are set dynamically when InitialCrewCreation loads
var content_area: VBoxContainer = null
var crew_container: VBoxContainer = null
var crew_size_input: SpinBox = null
var crew_size_option_node: OptionButton = null
var crew_list_node: VBoxContainer = null
var crew_summary: Label = null
var add_button_node: Button = null
var edit_button_node: Button = null
var remove_button_node: Button = null
var randomize_button_node: Button = null
var validation_panel: PanelContainer = null
var validation_icon: Label = null
var validation_text: Label = null

# Five Parsecs UI component references - set from InitialCrewCreation
var patron_list: VBoxContainer = null
var rival_list: VBoxContainer = null
var equipment_list: VBoxContainer = null

# Core Rules p.30 - Crew Flavor UI container (created dynamically)
var crew_flavor_container: VBoxContainer = null
var crew_flavor_meeting_label: Label = null
var crew_flavor_char_label: Label = null

# Character creator integration
var character_creator: SimpleCharacterCreator

var selected_size: int = 6  # Default Five Parsecs crew size (6 including captain)

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("crew") and state_data.crew is Dictionary:
		var crew_data = state_data.crew
		if crew_data.has("members"):
			# Update local crew state from external changes
			local_crew_data.members = crew_data.get("members", [])
			_update_crew_display()

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("Crew Generation", "Generate 6 crew members (including captain). Each character has unique stats and backgrounds that affect equipment.")

	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display

	# CRITICAL FIX: Remove BaseCampaignPanel's placeholder label
	var form_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer")
	if form_container:
		var placeholder = form_container.get_node_or_null("PlaceholderLabel")
		if placeholder:
			placeholder.queue_free()
			print("CrewPanel: Removed BaseCampaignPanel placeholder label")

	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")

	# Initialize crew-specific functionality
	_initialize_security_validator()
	_initialize_five_parsecs_systems()
	call_deferred("_initialize_components")

	# SPRINT 5.1: Emit panel_ready after initialization complete
	call_deferred("emit_panel_ready")

# NOTE: _add_progress_indicator() removed - CampaignCreationUI handles progress display centrally

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup crew-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	security_validator = SecurityValidator.new()

func _initialize_five_parsecs_systems() -> void:
	"""Initialize the Five Parsecs patron, rival, and crew flavor systems"""
	print("CrewPanel: Initializing Five Parsecs systems...")

	# Initialize patron system
	patron_system = PatronSystem.new()
	if patron_system and patron_system.has_method("initialize"):
		var success = patron_system.initialize()
		if success:
			print("CrewPanel: Patron system initialized successfully")
		else:
			push_warning("CrewPanel: Patron system initialization failed")
	else:
		print("CrewPanel: PatronSystem not available, creating basic instance")
		patron_system = PatronSystem.new()

	# Initialize rival system
	rival_system = RivalSystem.new()
	if rival_system:
		print("CrewPanel: Rival system initialized successfully")
	else:
		push_warning("CrewPanel: Rival system initialization failed")

	# Initialize crew relationship/flavor manager (Core Rules p.30)
	crew_relationship_manager = CrewRelationshipManager.new()
	add_child(crew_relationship_manager)
	print("CrewPanel: Crew relationship manager initialized (Core Rules flavor tables)")

func _initialize_components() -> void:
	"""Initialize crew panel with safe component access"""
	# PHASE 1 INTEGRATION: Connect to existing InitialCrewCreation
	_connect_to_crew_creation()
	
	# Initialize existing components
	_initialize_existing_components()
	
	_connect_signals()
	
	# Initialize validation panel state
	call_deferred("_update_validation_panel")
	
	_validate_crew_setup()
	# Don't auto-validate during setup - let user control validation

# Modern Crew UI - Design System Compliant
func _connect_to_crew_creation() -> void:
	"""Build modern crew generation UI using design system - NO InitialCrewCreation dependency"""
	print("CrewPanel: Building modern crew generation UI...")

	# Build modern UI instead of loading old InitialCrewCreation scene
	_create_modern_crew_ui()

	print("CrewPanel: Modern crew UI created successfully")

func _create_modern_crew_ui() -> void:
	"""Create modern crew generation UI using design system constants"""
	var form_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer")
	if not form_container:
		push_error("CrewPanel: FormContainer not found - cannot create UI")
		return

	# Main container for the crew generation UI
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "ModernCrewUI"
	main_vbox.add_theme_constant_override("separation", SPACING_LG)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_container.add_child(main_vbox)

	# === SECTION 1: Crew Configuration Card ===
	var config_card = _create_crew_config_section()
	main_vbox.add_child(config_card)

	# === SECTION 2: Generation Controls ===
	var gen_controls = _create_generation_controls()
	main_vbox.add_child(gen_controls)

	# === SECTION 3: Crew List (CharacterCards) ===
	var crew_section = _create_crew_list_section()
	main_vbox.add_child(crew_section)

	# === SECTION 4: Validation Panel ===
	var val_panel = _create_validation_section()
	main_vbox.add_child(val_panel)

	# Store reference for display updates
	crew_creation_container = main_vbox

	print("CrewPanel: Modern UI created with 4 sections")

func _create_crew_config_section() -> PanelContainer:
	"""Create crew configuration card with size selection"""
	var card = PanelContainer.new()
	card.name = "ConfigCard"
	card.add_theme_stylebox_override("panel", _create_glass_card_style())

	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", SPACING_MD)
	card.add_child(card_content)

	# Card title
	var title = Label.new()
	title.text = "Crew Configuration"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_content.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator_color", COLOR_BORDER)
	card_content.add_child(sep)

	# Crew size row
	var size_row = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", SPACING_MD)
	card_content.add_child(size_row)

	var size_label = Label.new()
	size_label.text = "Crew Size:"
	size_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	size_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	size_row.add_child(size_label)

	var size_option = OptionButton.new()
	size_option.name = "CrewSizeOption"
	size_option.add_item("4 Members", 4)
	size_option.add_item("5 Members", 5)
	size_option.add_item("6 Members (Standard)", 6)
	size_option.add_item("7 Members", 7)
	size_option.add_item("8 Members (Max)", 8)
	size_option.select(2)  # Default to 6
	size_option.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(size_option)
	size_option.item_selected.connect(_on_modern_crew_size_changed)
	size_row.add_child(size_option)
	crew_size_option_node = size_option

	return card

func _create_generation_controls() -> PanelContainer:
	"""Create character generation controls (mode, species, generate button)"""
	var card = PanelContainer.new()
	card.name = "GenerationControls"
	card.add_theme_stylebox_override("panel", _create_glass_card_style())

	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", SPACING_MD)
	card.add_child(card_content)

	# Mode toggle (Random / Bespoke)
	var mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", SPACING_SM)
	card_content.add_child(mode_row)

	var mode_label = Label.new()
	mode_label.text = "Creation Mode:"
	mode_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	mode_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	mode_row.add_child(mode_label)

	var random_btn = Button.new()
	random_btn.name = "RandomModeButton"
	random_btn.text = "Random"
	random_btn.toggle_mode = true
	random_btn.button_pressed = true
	random_btn.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	random_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_btn.toggled.connect(_on_random_mode_toggled)
	_style_toggle_button(random_btn, true)
	mode_row.add_child(random_btn)

	var bespoke_btn = Button.new()
	bespoke_btn.name = "BespokeModeButton"
	bespoke_btn.text = "Bespoke"
	bespoke_btn.toggle_mode = true
	bespoke_btn.button_pressed = false
	bespoke_btn.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	bespoke_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bespoke_btn.toggled.connect(_on_bespoke_mode_toggled)
	_style_toggle_button(bespoke_btn, false)
	mode_row.add_child(bespoke_btn)

	# Species row
	var species_row = HBoxContainer.new()
	species_row.add_theme_constant_override("separation", SPACING_SM)
	card_content.add_child(species_row)

	var species_label = Label.new()
	species_label.text = "Species:"
	species_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	species_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	species_row.add_child(species_label)

	var species_option = OptionButton.new()
	species_option.name = "SpeciesOption"
	species_option.add_item("Human", 0)
	species_option.add_item("Bot", 1)
	species_option.add_item("Engineer", 2)
	species_option.add_item("K'Erin", 3)
	species_option.add_item("Soulless", 4)
	species_option.add_item("Swift", 5)
	species_option.add_item("Precursor", 6)
	species_option.add_item("Feral", 7)
	species_option.custom_minimum_size = Vector2(150, TOUCH_TARGET_MIN)
	species_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(species_option)
	species_row.add_child(species_option)

	var random_species = CheckBox.new()
	random_species.name = "RandomSpeciesCheck"
	random_species.text = "Random"
	random_species.button_pressed = true
	random_species.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	random_species.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	random_species.toggled.connect(_on_random_species_toggled)
	species_row.add_child(random_species)

	# Generate button
	var gen_btn = Button.new()
	gen_btn.name = "GenerateButton"
	gen_btn.text = "Generate Character (0/%d)" % selected_size
	gen_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gen_btn.pressed.connect(_on_generate_character_pressed)
	_style_primary_button(gen_btn)
	card_content.add_child(gen_btn)
	add_button_node = gen_btn

	return card

func _create_crew_list_section() -> PanelContainer:
	"""Create scrollable crew list section for CharacterCards"""
	var card = PanelContainer.new()
	card.name = "CrewListSection"
	card.add_theme_stylebox_override("panel", _create_glass_card_style())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", SPACING_SM)
	card_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(card_content)

	# Section header with count
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", SPACING_SM)
	card_content.add_child(header_row)

	var title = Label.new()
	title.name = "CrewListTitle"
	title.text = "Your Crew (0/%d)" % selected_size
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	crew_summary = title

	var clear_btn = Button.new()
	clear_btn.text = "Clear All"
	clear_btn.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	clear_btn.pressed.connect(_on_clear_crew_pressed)
	_style_danger_button(clear_btn)
	header_row.add_child(clear_btn)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator_color", COLOR_BORDER)
	card_content.add_child(sep)

	# Scrollable crew list container
	var scroll = ScrollContainer.new()
	scroll.name = "CrewScroll"
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_content.add_child(scroll)

	var crew_vbox = VBoxContainer.new()
	crew_vbox.name = "CrewList"
	crew_vbox.add_theme_constant_override("separation", SPACING_SM)
	crew_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(crew_vbox)
	crew_list_node = crew_vbox
	crew_list = crew_vbox

	return card

func _create_validation_section() -> PanelContainer:
	"""Create validation status panel"""
	var panel = PanelContainer.new()
	panel.name = "ValidationPanel"

	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_MD)
	panel.add_child(content)

	var icon = Label.new()
	icon.name = "ValidationIcon"
	icon.text = "⚠️"
	icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	content.add_child(icon)
	validation_icon = icon

	var text = Label.new()
	text.name = "ValidationText"
	text.text = "Need at least 4 crew members"
	text.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	text.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text)
	validation_text = text

	validation_panel = panel
	_update_validation_panel()

	return panel

# === MODERN UI STYLING HELPERS ===

func _style_toggle_button(btn: Button, is_active: bool) -> void:
	"""Style toggle button with design system colors"""
	var style = StyleBoxFlat.new()
	if is_active:
		style.bg_color = COLOR_ACCENT
	else:
		style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _style_primary_button(btn: Button) -> void:
	"""Style primary action button"""
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.border_color = COLOR_ACCENT_HOVER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = COLOR_ACCENT_HOVER
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _style_danger_button(btn: Button) -> void:
	"""Style danger/destructive action button"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_DANGER, 0.2)
	style.border_color = COLOR_DANGER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(COLOR_DANGER, 0.4)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

# === MODERN UI EVENT HANDLERS ===

func _on_modern_crew_size_changed(index: int) -> void:
	"""Handle crew size selection from modern UI"""
	var option = crew_size_option_node as OptionButton
	if option:
		selected_size = option.get_item_id(index)
		print("CrewPanel: Crew size changed to %d" % selected_size)
		_update_generate_button_text()
		_update_crew_list_header()
		_update_validation_panel()
		_notify_coordinator_of_crew_update()

func _on_random_mode_toggled(pressed: bool) -> void:
	"""Handle Random mode toggle"""
	if pressed:
		var bespoke = crew_creation_container.get_node_or_null("GenerationControls/VBoxContainer/HBoxContainer/BespokeModeButton") as Button
		if bespoke:
			bespoke.button_pressed = false
			_style_toggle_button(bespoke, false)
		var random_btn = crew_creation_container.get_node_or_null("GenerationControls/VBoxContainer/HBoxContainer/RandomModeButton") as Button
		if random_btn:
			_style_toggle_button(random_btn, true)
		print("CrewPanel: Random mode enabled")

func _on_bespoke_mode_toggled(pressed: bool) -> void:
	"""Handle Bespoke mode toggle"""
	if pressed:
		var random_btn = crew_creation_container.get_node_or_null("GenerationControls/VBoxContainer/HBoxContainer/RandomModeButton") as Button
		if random_btn:
			random_btn.button_pressed = false
			_style_toggle_button(random_btn, false)
		var bespoke = crew_creation_container.get_node_or_null("GenerationControls/VBoxContainer/HBoxContainer/BespokeModeButton") as Button
		if bespoke:
			_style_toggle_button(bespoke, true)
		print("CrewPanel: Bespoke mode enabled")

func _on_random_species_toggled(pressed: bool) -> void:
	"""Handle random species checkbox toggle"""
	var species_option = crew_creation_container.get_node_or_null("GenerationControls/VBoxContainer/HBoxContainer2/SpeciesOption") as OptionButton
	if species_option:
		species_option.disabled = pressed
	print("CrewPanel: Random species = %s" % pressed)

func _on_generate_character_pressed() -> void:
	"""Handle generate character button press"""
	if crew_members.size() >= selected_size:
		print("CrewPanel: Crew already at target size (%d)" % selected_size)
		return

	print("CrewPanel: Generating new character...")
	var character = generate_random_character()
	if character:
		add_crew_member(character)
		_update_crew_display()
		_update_generate_button_text()
		_update_crew_list_header()
		_update_validation_panel()
		crew_updated.emit(crew_members)
		print("CrewPanel: Character added - %s" % character.character_name)

func _on_clear_crew_pressed() -> void:
	"""Handle clear all crew button press"""
	clear_crew()
	_update_crew_display()
	_update_generate_button_text()
	_update_crew_list_header()
	_update_validation_panel()
	print("CrewPanel: Crew cleared")

func _update_generate_button_text() -> void:
	"""Update generate button text with current count"""
	if add_button_node:
		var remaining = selected_size - crew_members.size()
		if remaining > 0:
			add_button_node.text = "Generate Character (%d/%d)" % [crew_members.size(), selected_size]
			add_button_node.disabled = false
		else:
			add_button_node.text = "Crew Complete (%d/%d)" % [crew_members.size(), selected_size]
			add_button_node.disabled = true

func _update_crew_list_header() -> void:
	"""Update crew list header with current count"""
	if crew_summary:
		crew_summary.text = "Your Crew (%d/%d)" % [crew_members.size(), selected_size]

func _create_fallback_crew_interface() -> void:
	"""Create fallback crew interface when InitialCrewCreation unavailable"""
	print("CrewPanel: Creating fallback crew interface")

	var form_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer")
	if not form_container:
		push_error("CrewPanel: Cannot create fallback - FormContainer not found")
		return

	var fallback_container = VBoxContainer.new()
	fallback_container.name = "FallbackCrewInterface"
	fallback_container.add_theme_constant_override("separation", SPACING_MD)
	form_container.add_child(fallback_container)

	# Warning label with design system colors
	var warning = Label.new()
	warning.text = "⚠️ Using simplified crew creation (InitialCrewCreation.tscn not available)"
	warning.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	warning.add_theme_color_override("font_color", COLOR_WARNING)
	fallback_container.add_child(warning)

	# Crew size selector
	var size_container = HBoxContainer.new()
	size_container.add_theme_constant_override("separation", SPACING_SM)
	fallback_container.add_child(size_container)

	var size_label = Label.new()
	size_label.text = "Crew Size:"
	size_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	size_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	size_container.add_child(size_label)

	var size_spin = SpinBox.new()
	size_spin.min_value = 1
	size_spin.max_value = 8
	size_spin.value = 4
	size_spin.custom_minimum_size.y = TOUCH_TARGET_MIN
	size_spin.value_changed.connect(_on_fallback_crew_size_changed)
	size_container.add_child(size_spin)

	# Generate crew button with touch-friendly size
	var generate_btn = Button.new()
	generate_btn.text = "Generate Random Crew"
	generate_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	generate_btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	generate_btn.pressed.connect(_generate_fallback_crew)
	fallback_container.add_child(generate_btn)

	# Crew list display
	var crew_list = ItemList.new()
	crew_list.custom_minimum_size.y = 200
	crew_list.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	fallback_container.add_child(crew_list)
	crew_list_node = crew_list

func _on_fallback_crew_size_changed(size: int) -> void:
	"""Handle crew size changes in fallback mode"""
	selected_size = size

func _generate_fallback_crew() -> void:
	"""Generate crew using fallback interface"""
	print("========== CrewPanel: FALLBACK CREW GENERATION START ==========")
	print("CrewPanel: DEBUG - Target crew size: %d" % selected_size)
	print("CrewPanel: DEBUG - Clearing existing crew...")
	clear_crew()
	print("CrewPanel: DEBUG - Crew cleared, size now: %d" % crew_members.size())
	
	for i in range(selected_size):
		print("CrewPanel: DEBUG - Generating character %d/%d..." % [i+1, selected_size])
		var character = generate_random_character()
		if character:
			print("CrewPanel: DEBUG - Character %d created successfully: %s" % [i+1, character.name if "name" in character else "Unknown"])
			var added = add_crew_member(character)
			print("CrewPanel: DEBUG - Character %d added to crew: %s" % [i+1, "SUCCESS" if added else "FAILED"])
		else:
			print("CrewPanel: DEBUG - Character %d creation FAILED" % [i+1])
	
	print("CrewPanel: DEBUG - Final crew size: %d" % crew_members.size())
	print("CrewPanel: DEBUG - Updating crew display...")
	_update_crew_display()
	
	print("CrewPanel: DEBUG - Emitting signals...")
	emit_data_changed()
	crew_updated.emit(crew_members)
	crew_setup_complete.emit(get_panel_data())
	print("========== CrewPanel: FALLBACK CREW GENERATION COMPLETE ==========")

# NOTE: _connect_crew_creation_signals() and _initialize_crew_creation_data() removed
# Modern UI is built programmatically - no InitialCrewCreation dependency

func _get_current_crew_data() -> Dictionary:
	"""Get current crew data from local state"""
	return local_crew_data

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation (BaseCampaignPanel compliance)"""
	# Ensure crew_size is included in the data (Sprint 26.7: Standardized key)
	local_crew_data["crew_size"] = selected_size
	return _get_current_crew_data()

func set_panel_data(data: Dictionary) -> void:
	"""Set panel data - interface implementation for state restoration"""
	if data.is_empty():
		print("CrewPanel: No data to restore in set_panel_data")
		return

	print("CrewPanel: Restoring panel data with keys: %s" % str(data.keys()))

	# Restore members (Sprint 26.3: Character-Everywhere - convert any Dictionary to Character)
	if data.has("members") and data["members"] is Array:
		local_crew_data["members"] = []
		for member in data["members"]:
			if member is Character:
				local_crew_data["members"].append(member)
			elif member is Dictionary:
				var character = _reconstruct_character_from_dict(member)
				if character:
					local_crew_data["members"].append(character)
				else:
					push_warning("CrewPanel: Failed to restore member from Dictionary")
			else:
				push_warning("CrewPanel: Skipping unknown member type: %s" % type_string(typeof(member)))
		print("CrewPanel: Restored %d crew members as Character objects" % local_crew_data["members"].size())

	# Restore selected size (target size for crew)
	# Sprint 26.7: Standardized to crew_size key (check legacy keys for backwards compat)
	if data.has("crew_size"):
		selected_size = data["crew_size"]
		print("CrewPanel: Restored crew_size: %d" % selected_size)
	elif data.has("selected_size"):
		selected_size = data["selected_size"]
		print("CrewPanel: Restored selected_size (legacy): %d" % selected_size)
	elif data.has("size"):
		selected_size = data["size"]
		print("CrewPanel: Restored size (legacy): %d" % selected_size)

	# Restore captain
	if data.has("captain"):
		current_captain = data["captain"]
		local_crew_data["captain"] = current_captain
		local_crew_data["has_captain"] = current_captain != null
		print("CrewPanel: Restored captain")

	# Restore patrons and rivals
	if data.has("patrons") and data["patrons"] is Array:
		local_crew_data["patrons"] = data["patrons"].duplicate()
		generated_patrons = []
		for p in data["patrons"]:
			generated_patrons.append(p)

	if data.has("rivals") and data["rivals"] is Array:
		local_crew_data["rivals"] = data["rivals"].duplicate()
		generated_rivals = []
		for r in data["rivals"]:
			generated_rivals.append(r)

	# Restore starting equipment
	if data.has("starting_equipment") and data["starting_equipment"] is Array:
		local_crew_data["starting_equipment"] = data["starting_equipment"].duplicate()

	# Restore crew flavor (Core Rules p.30 - We Met Through + Characterized As)
	if data.has("crew_flavor") and data["crew_flavor"] is Dictionary:
		local_crew_data["crew_flavor"] = data["crew_flavor"].duplicate()
		# Also restore to manager if available
		if crew_relationship_manager:
			crew_relationship_manager.deserialize(data["crew_flavor"])
		print("CrewPanel: Restored crew flavor - '%s'" % data["crew_flavor"].get("characteristic", ""))

	# Restore completion status
	local_crew_data["is_complete"] = data.get("is_complete", false)
	is_crew_complete = local_crew_data["is_complete"]

	# Rebuild tracking for duplicates (Sprint 26.3: All members are Character objects)
	_added_character_ids.clear()
	for member in local_crew_data["members"]:
		if member is Character and member.character_name:
			_added_character_ids[member.character_name] = true

	# Update UI
	call_deferred("_update_crew_display")
	call_deferred("refresh_all_displays")

	# Emit signals
	crew_updated.emit(crew_members)
	print("CrewPanel: Panel data restoration complete")

# InitialCrewCreation signal handlers
# REMOVED: Duplicate _on_crew_created function - using Phase 2 implementation at line 1227
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_crew_update()

func _notify_coordinator_of_crew_update() -> void:
	"""Notify the campaign coordinator of crew state changes"""
	# Try to find the coordinator through the scene tree
	var coordinator = _find_coordinator()
	if coordinator:
		# KEY NORMALIZATION: Ensure consistent keys for coordinator
		var normalized_crew_data = local_crew_data.duplicate()

		# Equipment: Convert "starting_equipment" to "items" key
		if normalized_crew_data.has("starting_equipment"):
			normalized_crew_data["items"] = normalized_crew_data.get("starting_equipment", [])

		# Sprint 26.7: Standardized to crew_size key (set legacy keys for backwards compat)
		normalized_crew_data["crew_size"] = selected_size
		normalized_crew_data["selected_size"] = selected_size  # Legacy compat
		normalized_crew_data["size"] = selected_size  # Legacy compat

		coordinator.update_crew_state(normalized_crew_data)
		print("CrewPanel: Notified coordinator of crew update (size: %d)" % selected_size)
	else:
		print("CrewPanel: Warning - coordinator not found")

func _find_coordinator() -> Variant:
	"""Find the campaign coordinator - prefer base class reference"""
	# CRITICAL FIX: Use base class _coordinator first (set via set_coordinator())
	var coord = get_coordinator()
	if coord and coord.has_method("update_crew_state"):
		return coord

	# Fallback: Look for coordinator in parent scenes
	var current = get_parent()
	while current:
		if current.has_method("update_crew_state"):
			return current
		current = current.get_parent()

	return null

# NOTE: _update_crew_data_from_creation() removed - modern UI manages crew data directly

func _initialize_existing_components() -> void:
	"""Initialize existing crew panel components"""
	# Initialize existing component references with fallback paths
	crew_list = crew_list_node
	if not crew_list:
		crew_list = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/ScrollContainer/VBoxContainer/CrewList")
	if not crew_list:
		push_error("CrewPanel: Could not find CrewList node!")

	add_button = add_button_node
	edit_button = edit_button_node
	remove_button = remove_button_node
	randomize_button = randomize_button_node

func _connect_signals() -> void:
	"""Connect UI signals with safety checks"""
	# Wire SpinBox for crew size (scene has SpinBox, not OptionButton)
	if crew_size_input and not crew_size_input.value_changed.is_connected(_on_crew_size_value_changed):
		crew_size_input.value_changed.connect(_on_crew_size_value_changed)

	# NOTE: add_button (gen_btn) is already connected to _on_generate_character_pressed
	# during creation in _create_generation_controls(). Do NOT connect again here
	# to avoid double character generation.

	if edit_button and not edit_button.pressed.is_connected(_on_edit_member_pressed):
		edit_button.pressed.connect(_on_edit_member_pressed)

	if remove_button and not remove_button.pressed.is_connected(_on_remove_member_pressed):
		remove_button.pressed.connect(_on_remove_member_pressed)

	if randomize_button and not randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.connect(_on_randomize_pressed)

	# Only connect item_selected if crew_list is an ItemList (not VBoxContainer)
	if crew_list and crew_list is ItemList and not crew_list.item_selected.is_connected(_on_crew_member_selected):
		crew_list.item_selected.connect(_on_crew_member_selected)

func _validate_crew_setup() -> void:
	"""Validate crew setup and update completion status"""
	print("========== CrewPanel: CREW VALIDATION START ==========")
	print("CrewPanel: DEBUG - Current crew size: %d" % crew_members.size())
	print("CrewPanel: DEBUG - Target crew size: %d" % selected_size)
	print("CrewPanel: DEBUG - Current captain: %s" % ("SET" if current_captain else "NONE"))
	
	# Update local crew data with current state
	print("CrewPanel: DEBUG - Updating local crew data...")
	_update_local_crew_data()
	print("CrewPanel: DEBUG - Local crew data updated, members: %d" % local_crew_data.get("members", []).size())
	
	print("CrewPanel: DEBUG - Running panel validation...")
	var validation_result = validate_panel()
	print("CrewPanel: DEBUG - Validation result: %s" % ("VALID" if validation_result else "INVALID"))
	
	if validation_result:
		print("CrewPanel: DEBUG - Crew validation PASSED - marking complete")
		is_crew_complete = true
		local_crew_data.is_complete = true

		# Generate crew flavor details (Core Rules p.30)
		_generate_crew_flavor()

		# CRITICAL FIX: Update coordinator IMMEDIATELY with crew data (don't wait for timer)
		var coord = get_coordinator()
		if coord and coord.has_method("update_crew_state"):
			coord.update_crew_state(local_crew_data)
			print("CrewPanel: ✅ IMMEDIATE coordinator update with %d crew members" % crew_members.size())
		else:
			print("CrewPanel: ⚠️ No coordinator for immediate update")

		print("CrewPanel: DEBUG - Emitting crew_data_complete signal...")
		crew_data_complete.emit(local_crew_data)

		print("CrewPanel: DEBUG - Emitting panel_completed signal...")
		panel_completed.emit(local_crew_data)
		print("CrewPanel: DEBUG - panel_completed signal emitted successfully")
		print("CrewPanel: CREW SETUP COMPLETE - progression enabled")
	else:
		print("CrewPanel: DEBUG - Crew validation FAILED")
		is_crew_complete = false
		local_crew_data.is_complete = false
	
	print("========== CrewPanel: CREW VALIDATION COMPLETE ==========")

func _update_local_crew_data() -> void:
	"""Update local crew data with patrons, rivals, and equipment - UNIFIED"""
	# NOTE: crew_members is now a getter for local_crew_data.members, no sync needed
	local_crew_data["captain"] = current_captain
	local_crew_data["size"] = crew_members.size()
	local_crew_data["has_captain"] = current_captain != null

	# Update patrons and rivals from generated lists
	local_crew_data["patrons"] = generated_patrons.duplicate()
	local_crew_data["rivals"] = generated_rivals.duplicate()

	# Generate enhanced starting equipment for the crew
	local_crew_data["starting_equipment"] = _generate_crew_starting_equipment()

	print("CrewPanel: Updated crew data - %d members, %d patrons, %d rivals, %d equipment items" % [
		crew_members.size(),
		local_crew_data.get("patrons", []).size(),
		local_crew_data.get("rivals", []).size(),
		local_crew_data.get("starting_equipment", []).size()
	])

func _update_crew_display() -> void:
	"""Update the crew list display using CharacterCard COMPACT variant"""
	print("CrewPanel: _update_crew_display called, crew_members count: %d" % crew_members.size())

	# Ensure crew_list is available with fallback
	if not crew_list:
		crew_list = crew_list_node
	if not crew_list:
		crew_list = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/ScrollContainer/VBoxContainer/CrewList")
	if not crew_list:
		push_error("CrewPanel: crew_list is null, cannot display crew!")
		return

	print("CrewPanel: crew_list found, clearing and rebuilding display")

	# Clear existing children
	for child in crew_list.get_children():
		child.queue_free()
	
	# Create responsive container for crew cards
	var crew_cards_container := _create_responsive_crew_container()
	crew_list.add_child(crew_cards_container)
	
	# Add CharacterCard for each crew member
	var cards_built := 0
	for member in crew_members:
		# Extract Character object from Dictionary if needed
		var character_obj: Character = null
		if member is Character:
			character_obj = member
		elif member is Dictionary:
			# First try to get preserved character_object
			if member.has("character_object"):
				character_obj = member.get("character_object")
			else:
				# FALLBACK: Reconstruct Character from dictionary data
				character_obj = _reconstruct_character_from_dict(member)

		if not character_obj:
			push_warning("CrewPanel: Skipping member without valid Character object: %s" % str(member))
			continue

		cards_built += 1
		var card_instance = CharacterCardScene.instantiate()
		card_instance.set_variant(CharacterCardScript.CardVariant.COMPACT)
		card_instance.set_character(character_obj)

		# Connect card signals (bind original member for data consistency)
		card_instance.card_tapped.connect(_on_crew_card_tapped.bind(member))
		card_instance.view_details_pressed.connect(_on_crew_card_view.bind(member))
		card_instance.edit_pressed.connect(_on_crew_card_edit.bind(member))
		card_instance.remove_pressed.connect(_on_crew_card_remove.bind(member))

		# Add hover effect for better interactivity
		card_instance.mouse_entered.connect(_on_crew_card_hover_start.bind(card_instance))
		card_instance.mouse_exited.connect(_on_crew_card_hover_end.bind(card_instance))

		crew_cards_container.add_child(card_instance)

	print("CrewPanel: Built %d CharacterCards from %d crew members" % [cards_built, crew_members.size()])

	# Add "Create Character" button for empty slots
	var empty_slots := maxi(0, selected_size - crew_members.size())
	for i in range(empty_slots):
		var add_slot_btn := _create_add_character_slot(i)
		crew_cards_container.add_child(add_slot_btn)
	
	# Update validation panel with crew count feedback
	_update_validation_panel()
	
	_update_crew_summary()
	_update_button_states()

func _update_crew_summary() -> void:
	"""Update crew summary display"""
	if not crew_summary:
		return
	
	var captain_name = current_captain.character_name if current_captain else "None"
	crew_summary.text = "Crew: %d members | Captain: %s" % [crew_members.size(), captain_name]

func _update_button_states() -> void:
	"""Update button enabled/disabled states"""
	var has_selection = false
	
	if crew_list:
		if crew_list is ItemList:
			has_selection = not crew_list.get_selected_items().is_empty()
		elif crew_list is VBoxContainer:
			# For VBoxContainer, check if any button is highlighted (modulate != WHITE)
			for child in crew_list.get_children():
				if child is Button and child.modulate != Color.WHITE:
					has_selection = true
					break
	
	if edit_button:
		edit_button.disabled = not has_selection
	
	if remove_button:
		remove_button.disabled = not has_selection or crew_members.size() <= 1
	
	if add_button:
		add_button.disabled = crew_members.size() >= MAX_CREW_SIZE

# UI Event Handlers
func _on_crew_size_value_changed(value: float) -> void:
	"""Handle crew size SpinBox value change"""
	selected_size = int(value)
	print("CrewPanel: Crew size changed to %d" % selected_size)
	_adjust_crew_size()
	_update_crew_display()
	_notify_coordinator_of_crew_update()

func _on_crew_size_selected(index: int) -> void:
	"""Handle crew size selection (legacy OptionButton handler)"""
	if not crew_size_option:
		return

	selected_size = crew_size_option.get_item_id(index)
	_adjust_crew_size()

func _adjust_crew_size() -> void:
	"""Adjust crew size to match selection"""
	var current_size = crew_members.size()
	
	if current_size < selected_size:
		# Add members
		for i in range(selected_size - current_size):
			var character = generate_random_character()
			if character:
				add_crew_member(character)
	elif current_size > selected_size:
		# Remove excess members (preserve captain if possible)
		while crew_members.size() > selected_size:
			var member_to_remove = crew_members.back()
			if member_to_remove != current_captain:
				remove_crew_member(member_to_remove)
			else:
				# Remove a different member instead
				if crew_members.size() > 1:
					remove_crew_member(crew_members[0])
				else:
					break
	
	_update_crew_display()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	"""Handle add crew member button"""
	if crew_members.size() >= MAX_CREW_SIZE:
		return
	
	var character = generate_random_character()
	if character:
		add_crew_member(character)

func _on_edit_member_pressed() -> void:
	"""Handle edit crew member button"""
	if not crew_list:
		return
	
	var selected_index = -1
	
	if crew_list is ItemList:
		if crew_list.get_selected_items().is_empty():
			return
		selected_index = crew_list.get_selected_items()[0]
	elif crew_list is VBoxContainer:
		# Find highlighted button in VBoxContainer
		for i in crew_list.get_child_count():
			var child = crew_list.get_child(i)
			if child is Button and child.modulate != Color.WHITE:
				selected_index = i
				break
		if selected_index == -1:
			return
	
	if selected_index >= 0 and selected_index < crew_members.size():
		var character = crew_members[selected_index]

		# Store character for editing using standardized keys
		if GameStateManager:
			GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER, character)
			GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_EDIT_MODE, true)
			GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_RETURN_SCREEN, "campaign_dashboard")

		# Navigate to character details with edit mode using standardized navigation
		GameStateManager.navigate_to_screen("character_details")

func _on_remove_member_pressed() -> void:
	"""Handle remove crew member button"""
	if not crew_list:
		return
	
	if crew_members.size() <= 1:
		return
	
	var selected_index = -1
	
	if crew_list is ItemList:
		if crew_list.get_selected_items().is_empty():
			return
		selected_index = crew_list.get_selected_items()[0]
	elif crew_list is VBoxContainer:
		# Find highlighted button in VBoxContainer
		for i in crew_list.get_child_count():
			var child = crew_list.get_child(i)
			if child is Button and child.modulate != Color.WHITE:
				selected_index = i
				break
		if selected_index == -1:
			return
	
	if selected_index >= 0 and selected_index < crew_members.size():
		var character = crew_members[selected_index]
		remove_crew_member(character)
		_update_crew_display()

func _on_randomize_pressed() -> void:
	"""Handle randomize crew button"""
	clear_crew()
	for i in range(selected_size):
		var character = generate_random_character()
		if character:
			add_crew_member(character)
	_update_crew_display()

func _on_crew_member_button_pressed(member_data: Dictionary) -> void:
	"""Handle crew member button press for selection (VBoxContainer mode)"""
	if crew_list is VBoxContainer:
		# Handle VBoxContainer selection by highlighting the selected button
		for child in crew_list.get_children():
			if child is Button:
				child.modulate = Color.WHITE  # Reset color
				if child.has_meta("crew_data"):
					var button_data = child.get_meta("crew_data")
					if DataValidator.safe_get_name(button_data) == DataValidator.safe_get_name(member_data):
						child.modulate = Color.LIGHT_BLUE  # Highlight selected
	
	# Update button states based on new selection
	_update_button_states()
	print("CrewPanel: Crew member selected: %s" % DataValidator.safe_get_name(member_data))

# ============ CREW PANEL WIZARD ENHANCEMENTS ============

func _create_responsive_crew_container() -> Control:
	"""Create responsive container for crew cards with glass morphism (mobile: scroll, tablet/desktop: grid)"""
	if should_use_single_column():
		# Mobile: Vertical scrollable list with glass background
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size.y = 400

		# Glass background for mobile scroll
		var scroll_bg := PanelContainer.new()
		scroll_bg.add_theme_stylebox_override("panel", _create_glass_card_subtle())

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", SPACING_MD)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		return scroll
	else:
		# Tablet/Desktop: 2-3 column grid with glass background
		var grid := GridContainer.new()
		grid.columns = get_optimal_column_count()
		grid.add_theme_constant_override("h_separation", SPACING_LG)
		grid.add_theme_constant_override("v_separation", SPACING_MD)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return grid

func _create_add_character_slot(slot_index: int) -> Button:
	"""Create 'Create Character' button for empty crew slot"""
	var btn := Button.new()
	btn.text = "+ Create Character"
	btn.custom_minimum_size = Vector2(0, 80)  # Match COMPACT card height
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Dashed border style
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_TEXT_SECONDARY
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	btn.add_theme_stylebox_override("normal", style)
	
	btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	
	btn.pressed.connect(_on_create_character_slot_pressed.bind(slot_index))
	
	return btn

func _update_validation_panel() -> void:
	"""Update validation panel with color-coded crew count feedback and glass morphism"""
	if not validation_panel or not validation_icon or not validation_text:
		return

	var crew_count := crew_members.size()
	var status_color: Color
	var status_icon: String
	var status_message: String

	# Validation logic (4-8 crew optimal)
	if crew_count < 4:
		status_color = COLOR_DANGER
		status_icon = "❌"
		status_message = "Need at least 4 crew members (%d/4)" % crew_count
	elif crew_count < 6:
		status_color = COLOR_WARNING
		status_icon = "⚠️"
		status_message = "4-6 crew (recommended) - %d members" % crew_count
	elif crew_count <= 8:
		status_color = COLOR_SUCCESS
		status_icon = "✅"
		status_message = "6-8 crew (optimal) - %d members" % crew_count
	else:
		status_color = COLOR_WARNING
		status_icon = "⚠️"
		status_message = "Over maximum (8) - %d members" % crew_count

	# Apply glass morphism with status color tint
	var style := _create_accent_card_style(status_color)
	style.border_color = status_color
	style.set_border_width_all(2)
	validation_panel.add_theme_stylebox_override("panel", style)

	# Update icon and text
	validation_icon.text = status_icon
	validation_icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)

	validation_text.text = status_message
	validation_text.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	validation_text.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	# Emit validation signal for wizard navigation
	var is_valid := crew_count >= 4 and crew_count <= 8
	emit_signal("panel_validation_changed", is_valid)

	print("CrewPanel: Validation updated - %d crew (%s)" % [crew_count, "VALID" if is_valid else "INVALID"])

# ============ CHARACTERCARD SIGNAL HANDLERS ============

func _on_crew_card_tapped(member: Character) -> void:
	"""Handle character card tap - select crew member"""
	crew_member_selected.emit(member)
	print("CrewPanel: Character card tapped: %s" % member.get_display_name())

func _on_crew_card_view(member: Character) -> void:
	"""Handle 'View' button on character card"""
	if GameStateManager:
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER, member)
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_EDIT_MODE, false)
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_RETURN_SCREEN, "campaign_creation")
		GameStateManager.navigate_to_screen("character_details")

func _on_crew_card_edit(member: Character) -> void:
	"""Handle 'Edit' button on character card"""
	if GameStateManager:
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER, member)
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_EDIT_MODE, true)
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_RETURN_SCREEN, "campaign_creation")
		GameStateManager.navigate_to_screen("character_details")

func _on_crew_card_remove(member: Character) -> void:
	"""Handle 'Remove' button on character card - Sprint D: with confirmation"""
	if crew_members.size() <= 1:
		push_warning("CrewPanel: Cannot remove last crew member")
		return

	# Sprint D: Show confirmation dialog before removing
	var display_name = member.get_display_name() if member.has_method("get_display_name") else member.character_name
	var confirmed = await _show_confirmation_dialog(
		"Remove Crew Member",
		"Are you sure you want to remove %s from your crew?\n\nThis action cannot be undone." % display_name,
		"Remove",
		true  # destructive
	)

	if not confirmed:
		print("CrewPanel: Crew removal cancelled for: %s" % display_name)
		return

	remove_crew_member(member)
	_update_crew_display()
	crew_updated.emit(crew_members)
	print("CrewPanel: Removed crew member: %s" % display_name)

## Sprint D: Show confirmation dialog and await response
func _show_confirmation_dialog(dialog_title: String, message: String, confirm_text: String = "Confirm", destructive: bool = false) -> bool:
	"""Show confirmation dialog and return true if confirmed"""
	var ConfirmationDialogScene = load("res://src/ui/components/common/ConfirmationDialog.tscn")
	if not ConfirmationDialogScene:
		push_warning("CrewPanel: ConfirmationDialog scene not found - proceeding without confirmation")
		return true

	var dialog = ConfirmationDialogScene.instantiate()
	add_child(dialog)

	var result = await dialog.await_confirmation(dialog_title, message, confirm_text, destructive)
	dialog.queue_free()

	return result

func _on_create_character_slot_pressed(slot_index: int) -> void:
	"""Handle 'Create Character' slot button - add new crew member"""
	var character = generate_random_character()
	if character:
		add_crew_member(character)
		_update_crew_display()
		crew_updated.emit(crew_members)
		print("CrewPanel: Created new character in slot %d" % slot_index)

func _on_crew_card_hover_start(card: Control) -> void:
	"""Apply hover effect to crew card"""
	if card and is_instance_valid(card):
		# Create tween for smooth hover animation
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "scale", Vector2(1.02, 1.02), 0.15)

func _on_crew_card_hover_end(card: Control) -> void:
	"""Remove hover effect from crew card"""
	if card and is_instance_valid(card):
		# Create tween for smooth return animation
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15)

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	_update_button_states()
	
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		crew_member_selected.emit(character)

# LEGACY FUNCTIONS REMOVED - Duplicate function caused parse error

func remove_crew_member(member) -> bool:
	"""Remove crew member - replacement for removed legacy function"""
	if member in crew_members:
		crew_members.erase(member)
		_validate_crew_setup()
		return true
	return false

func clear_crew() -> void:
	"""Clear all crew members - operates on unified local_crew_data"""
	local_crew_data["members"].clear()
	current_captain = null
	local_crew_data["captain"] = null
	_added_character_ids.clear()  # Reset deduplication tracking
	_emit_crew_updated()

func set_captain(character) -> void:
	"""Set a crew member as captain"""
	if character and character in crew_members:
		# Remove captain status from previous captain
		if current_captain:
			current_captain.character_name = current_captain.character_name.replace(" (Captain)", "")
		
		current_captain = character
		character.character_name = character.character_name.replace(" (Captain)", "") + " (Captain)"
		_emit_crew_updated()

func _emit_crew_updated() -> void:
	"""Emit crew updated signal"""
	crew_updated.emit(crew_members)

func generate_random_character():
	"""Generate a complete Five Parsecs character with backgrounds, motivations, and relationships"""
	print("CrewPanel: Generating complete Five Parsecs character...")
	
	# Collect existing crew names to prevent duplicates (Sprint 26.3: All members are Character)
	var existing_names: Array[String] = []
	for member in local_crew_data.members:
		if member is Character and member.character_name:
			existing_names.append(member.character_name)
	
	print("CrewPanel: Avoiding duplicate names: %s" % str(existing_names))
	
	# Use the complete Five Parsecs character generation system with existing names
	var config = {"existing_names": existing_names}
	var character = Character.generate_complete_character(config)
	
	if not character:
		push_warning("CrewPanel: Five Parsecs character generation failed, using fallback")
		character = _generate_fallback_character(existing_names)
	else:
		print("CrewPanel: Generated character '%s' - %s %s" % [
			character.character_name,
			_get_background_name(character.background),
			_get_motivation_name(character.motivation)
		])
		
		# Generate patrons and rivals for this character
		_generate_character_relationships(character)
	
	return character

func _reconstruct_character_from_dict(data: Dictionary) -> Character:
	"""Reconstruct a Character object from dictionary data (for display after serialization)"""
	if data.is_empty():
		return null

	var character = Character.new()

	# Set name
	character.character_name = data.get("character_name", data.get("name", "Unknown"))

	# Set background/motivation/origin
	if data.has("background"):
		character.background = data.background
	if data.has("motivation"):
		character.motivation = data.motivation
	if data.has("origin"):
		character.origin = data.origin
	elif data.has("species"):
		character.origin = data.species

	# Set character class
	if data.has("character_class"):
		character.character_class = data.character_class

	# Set stats
	if data.has("combat"):
		character.combat = data.combat
	if data.has("reactions"):
		character.reactions = data.reactions
	if data.has("toughness"):
		character.toughness = data.toughness
	if data.has("savvy"):
		character.savvy = data.savvy
	if data.has("tech"):
		character.tech = data.tech
	if data.has("speed"):
		character.speed = data.speed
	if data.has("luck"):
		character.luck = data.luck

	# Set XP
	if data.has("xp"):
		character.xp = data.xp
	elif data.has("experience"):
		character.xp = data.experience

	# Set captain flag
	if data.has("is_captain"):
		character.is_captain = data.is_captain

	return character

func _generate_fallback_character(existing_names: Array = []):
	"""Generate a basic fallback character if the full system fails"""
	var character = Character.new()
	
	# Generate random name from a pool, avoiding duplicates
	var first_names = ["Alex", "Casey", "Jordan", "Sam", "Taylor", "Morgan", "Riley", "Avery", "Blake", "Cameron"]
	var last_names = ["Smith", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Thomas"]
	
	# Try to generate unique name (up to 10 attempts)
	var attempts = 0
	var name = ""
	while attempts < 10:
		name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
		if not name in existing_names:
			break
		attempts += 1
	
	# Add suffix if still duplicate
	if name in existing_names:
		name += " " + str(randi() % 100 + 1)
	
	character.character_name = name
	
	# Generate Five Parsecs stats (2d6 divided by 3, rounded up)
	character.combat = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.toughness = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.savvy = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.tech = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.speed = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.luck = 1 # Base luck
	
	# Calculate health based on toughness
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Set basic defaults
	character.background = "MILITARY"
	character.motivation = "SURVIVAL"
	character.origin = "HUMAN"
	
	return character

func _generate_character_relationships(character) -> void:
	"""Generate patrons and rivals for a character based on background and motivation"""
	if not character:
		return
	
	print("CrewPanel: Generating relationships for %s..." % character.character_name)
	
	# Generate patrons based on character background (1-3 patrons per Five Parsecs rules)
	var patron_count = _calculate_starting_patrons(character)
	for i in range(patron_count):
		if patron_system:
			var patron = patron_system.generate_patron()
			if not patron.is_empty():
				# Link patron to character background
				_customize_patron_for_character(patron, character)
				generated_patrons.append(patron)
				print("CrewPanel: Generated patron '%s' for %s" % [patron.get("name", "Unknown"), character.character_name])
	
	# Generate rivals based on character background (0-2 rivals per Five Parsecs rules)
	var rival_count = _calculate_starting_rivals(character)
	for i in range(rival_count):
		if rival_system:
			var rival_params = _get_rival_params_for_character(character)
			var rival = rival_system.create_rival(rival_params)
			if not rival.is_empty():
				generated_rivals.append(rival)
				print("CrewPanel: Generated rival '%s' for %s" % [rival.get("name", "Unknown"), character.character_name])
	
	# Update local crew data with new relationships
	local_crew_data["patrons"] = generated_patrons
	local_crew_data["rivals"] = generated_rivals

	# Update UI displays
	call_deferred("refresh_all_displays")

func _generate_crew_flavor() -> void:
	"""Generate crew flavor details per Core Rules p.30 (Flavor Details section)
	Rolls on 'We Met Through' and 'Characterized As' tables"""
	if not crew_relationship_manager:
		push_warning("CrewPanel: CrewRelationshipManager not initialized")
		return

	# Only generate if not already generated (prevents re-rolling on re-validation)
	var existing_flavor = local_crew_data.get("crew_flavor", {})
	if existing_flavor.get("meeting_story", "") != "" and existing_flavor.get("characteristic", "") != "":
		print("CrewPanel: Crew flavor already generated, skipping")
		return

	print("CrewPanel: Generating crew flavor details (Core Rules p.30)...")

	# Generate the crew flavor using relationship manager
	crew_relationship_manager.generate_initial_relationships(crew_members)

	# Store in local crew data
	local_crew_data["crew_flavor"] = {
		"meeting_story": crew_relationship_manager.crew_meeting_story,
		"characteristic": crew_relationship_manager.crew_characteristic,
		"relationships": crew_relationship_manager.serialize().get("relationships", {})
	}

	print("CrewPanel: Crew Flavor - 'We Met Through': %s" % crew_relationship_manager.crew_meeting_story)
	print("CrewPanel: Crew Flavor - 'Characterized As': %s" % crew_relationship_manager.crew_characteristic)

	# Update the flavor display
	call_deferred("update_crew_flavor_display")

func _create_crew_flavor_section() -> void:
	"""Create the Crew Flavor UI section per Core Rules p.30"""
	if crew_flavor_container:
		return  # Already created

	# Find the form container to add the section
	var form_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer")
	if not form_container:
		push_warning("CrewPanel: FormContainer not found for crew flavor section")
		return

	# Create the flavor section card
	crew_flavor_container = VBoxContainer.new()
	crew_flavor_container.name = "CrewFlavorSection"
	crew_flavor_container.add_theme_constant_override("separation", SPACING_SM)

	# Section title
	var title_label = Label.new()
	title_label.text = "Crew Flavor (Core Rules p.30)"
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crew_flavor_container.add_child(title_label)

	# "We Met Through" display
	crew_flavor_meeting_label = Label.new()
	crew_flavor_meeting_label.text = "We Met Through: (not generated yet)"
	crew_flavor_meeting_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	crew_flavor_meeting_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	crew_flavor_meeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crew_flavor_container.add_child(crew_flavor_meeting_label)

	# "Characterized As" display
	crew_flavor_char_label = Label.new()
	crew_flavor_char_label.text = "Characterized As: (not generated yet)"
	crew_flavor_char_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	crew_flavor_char_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	crew_flavor_container.add_child(crew_flavor_char_label)

	# Reroll button
	var reroll_button = Button.new()
	reroll_button.text = "Reroll Crew Flavor"
	reroll_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	reroll_button.pressed.connect(_on_reroll_flavor_pressed)

	# Style the button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_INPUT
	btn_style.border_color = COLOR_BORDER
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(SPACING_SM)
	reroll_button.add_theme_stylebox_override("normal", btn_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(COLOR_INPUT.r + 0.05, COLOR_INPUT.g + 0.05, COLOR_INPUT.b + 0.05)
	hover_style.border_color = COLOR_ACCENT
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(SPACING_SM)
	reroll_button.add_theme_stylebox_override("hover", hover_style)

	crew_flavor_container.add_child(reroll_button)

	# Add separator for visual clarity
	var separator = HSeparator.new()
	crew_flavor_container.add_child(separator)

	# Insert at a good position (after crew list, before validation)
	form_container.add_child(crew_flavor_container)
	print("CrewPanel: Crew Flavor section created")

func update_crew_flavor_display() -> void:
	"""Update the Crew Flavor display with current values"""
	# Ensure the section exists
	if not crew_flavor_container:
		_create_crew_flavor_section()

	if not crew_flavor_meeting_label or not crew_flavor_char_label:
		return

	var flavor = local_crew_data.get("crew_flavor", {})
	var meeting_story = flavor.get("meeting_story", "")
	var characteristic = flavor.get("characteristic", "")

	if meeting_story.is_empty():
		crew_flavor_meeting_label.text = "We Met Through: (generate crew first)"
	else:
		crew_flavor_meeting_label.text = "We Met Through: %s" % meeting_story

	if characteristic.is_empty():
		crew_flavor_char_label.text = "Characterized As: (generate crew first)"
	else:
		crew_flavor_char_label.text = "Characterized As: %s" % characteristic

func _on_reroll_flavor_pressed() -> void:
	"""Handle reroll flavor button press - regenerate crew flavor"""
	if not crew_relationship_manager:
		push_warning("CrewPanel: Cannot reroll - CrewRelationshipManager not available")
		return

	print("CrewPanel: Rerolling crew flavor...")

	# Clear existing flavor to allow regeneration
	local_crew_data["crew_flavor"] = {
		"meeting_story": "",
		"characteristic": "",
		"relationships": {}
	}

	# Generate new flavor
	crew_relationship_manager.generate_crew_flavor()

	# Update local data
	local_crew_data["crew_flavor"] = {
		"meeting_story": crew_relationship_manager.crew_meeting_story,
		"characteristic": crew_relationship_manager.crew_characteristic,
		"relationships": crew_relationship_manager.serialize().get("relationships", {})
	}

	print("CrewPanel: New Flavor - 'We Met Through': %s" % crew_relationship_manager.crew_meeting_story)
	print("CrewPanel: New Flavor - 'Characterized As': %s" % crew_relationship_manager.crew_characteristic)

	# Update display
	update_crew_flavor_display()

	# Notify of data change
	emit_data_changed()

func _calculate_starting_patrons(character) -> int:
	"""Calculate number of starting patrons based on background and motivation"""
	var base_count = 1
	
	# Background modifiers per Five Parsecs rules
	if character.background == "Military":
		base_count += 1 # Military connections
	elif character.background == "Noble":
		base_count += 2 # Noble connections
	elif character.background == "Merchant":
		base_count += 1 # Trade connections
	
	# Motivation modifiers
	if character.motivation == "Wealth":
		base_count += 1 # Wealth seekers have more contacts
	elif character.motivation == "Power":
		base_count += 1 # Power seekers cultivate connections
	
	return clampi(base_count, 1, 3) # Five Parsecs limit: 1-3 patrons

func _calculate_starting_rivals(character) -> int:
	"""Calculate number of starting rivals based on background"""
	var base_count = 0
	
	# Background creates enemies per Five Parsecs rules
	if character.background == "Criminal":
		base_count += 2 # Law enforcement and rival criminals
	elif character.background == "Military":
		base_count += 1 # Deserters or enemy forces
	elif character.background == "Mercenary":
		base_count += 1 # Competing mercenaries
	elif character.background == "Outcast":
		base_count += 1 # Those who cast them out
	
	# Random chance for additional rival
	if randf() < 0.3:
		base_count += 1
	
	return clampi(base_count, 0, 2) # Five Parsecs limit: 0-2 rivals

func _customize_patron_for_character(patron: Dictionary, character) -> void:
	"""Customize patron based on character background"""
	if not patron or not character:
		return
	
	# Set patron type based on character background - now using string comparison
	match character.background:
		"MILITARY":
			patron["type"] = "MILITARY_COMMAND"
		"MERCHANT", "TRADER":
			patron["type"] = "TRADE_GUILD"
		"ACADEMIC":
			patron["type"] = "RESEARCH_INSTITUTE"
		"CRIMINAL":
			patron["type"] = "CRIME_SYNDICATE"
		"NOBLE":
			patron["type"] = "NOBLE_HOUSE"
		_:
			patron["type"] = "LOCAL_AUTHORITY"

func _get_rival_params_for_character(character) -> Dictionary:
	"""Get rival generation parameters based on character"""
	var params = {}
	
	# Set rival type based on character background - now using string comparison
	match character.background:
		"MILITARY":
			params["type"] = GlobalEnums.EnemyType.RAIDERS
			params["name"] = "Rogue Squadron"
		"CRIMINAL":
			params["type"] = GlobalEnums.EnemyType.GANGERS
			params["name"] = "Rival Gang"
		"MERCENARY":
			params["type"] = GlobalEnums.EnemyType.PIRATES
			params["name"] = "Competing Mercs"
		_:
			params["type"] = GlobalEnums.EnemyType.PUNKS
			params["name"] = "Local Hostiles"
	
	params["level"] = randi_range(1, 3) # Starting rival level
	params["reputation"] = randi_range(0, 2) # Starting reputation
	
	return params

func _get_background_name(background: Variant) -> String:
	"""Get human-readable background name - handles both int and String"""
	if background is String:
		return background.capitalize()
	elif background is int:
		var background_keys = GlobalEnums.Background.keys()
		if background >= 0 and background < background_keys.size():
			return background_keys[background].capitalize()
	return "Unknown"

func _get_motivation_name(motivation: Variant) -> String:
	"""Get human-readable motivation name - handles both int and String"""
	if motivation is String:
		return motivation.capitalize()
	elif motivation is int:
		var motivation_keys = GlobalEnums.Motivation.keys()
		if motivation >= 0 and motivation < motivation_keys.size():
			return motivation_keys[motivation].capitalize()
	return "Unknown"

func _generate_crew_starting_equipment() -> Array[Dictionary]:
	"""Generate enhanced starting equipment for the entire crew using Five Parsecs rules"""
	var crew_equipment: Array[Dictionary] = []
	
	print("CrewPanel: Generating starting equipment for %d crew members..." % crew_members.size())
	
	# Generate equipment for each crew member using the enhanced system
	for member in crew_members:
		if member and member.has_method("get_meta"):
			# Check if character already has equipment from generation
			var character_equipment = member.get_meta("personal_equipment", {})
			if not character_equipment.is_empty():
				crew_equipment.append({
					"character_name": member.character_name,
					"equipment": character_equipment
				})
				continue
		
		# Use Character to generate equipment for this character
		var equipment = Character.generate_starting_equipment_enhanced(member)
		crew_equipment.append({
			"character_name": member.character_name,
			"equipment": equipment
		})
	
	# Add crew-level starting equipment per Five Parsecs rules
	var crew_level_equipment = _generate_crew_level_equipment()
	if not crew_level_equipment.is_empty():
		crew_equipment.append({
			"character_name": "Crew Shared Equipment",
			"equipment": crew_level_equipment
		})
	
	print("CrewPanel: Generated equipment for %d crew members" % crew_equipment.size())
	
	# Update local crew data with generated equipment
	var equipment_items: Array[String] = []
	for crew_equip in crew_equipment:
		var equip_dict = crew_equip.get("equipment", {})
		for category in ["weapons", "armor", "gear"]:
			if equip_dict.has(category):
				var items = equip_dict[category]
				if typeof(items) == TYPE_ARRAY:
					for item in items:
						equipment_items.append(str(item))
	
	local_crew_data["starting_equipment"] = equipment_items
	
	# Update UI display
	call_deferred("update_equipment_display")
	
	return crew_equipment

func _generate_crew_level_equipment() -> Dictionary:
	"""Generate crew-level shared equipment per Five Parsecs starting rules"""
	var shared_equipment = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 1000
	}
	
	# Five Parsecs starting equipment: 3 military weapons, 3 low-tech weapons
	var military_weapons = ["Combat Rifle", "Assault Rifle", "Battle Dress"]
	var low_tech_weapons = ["Blade", "Pistol", "Hand Weapon"]
	
	# Add military weapons (crew gets 3)
	for i in range(3):
		if i < military_weapons.size():
			shared_equipment.weapons.append(military_weapons[i])
	
	# Add low-tech weapons (crew gets 3)  
	for i in range(3):
		if i < low_tech_weapons.size():
			shared_equipment.weapons.append(low_tech_weapons[i])
	
	# Add basic crew gear
	shared_equipment.gear.append("Comm Unit")
	shared_equipment.gear.append("Scanner")
	shared_equipment.gear.append("Repair Kit")
	
	# Starting credits based on crew size (more crew = more pooled resources)
	shared_equipment.credits = 1000 + (crew_members.size() * 200)
	
	return shared_equipment

func validate_panel() -> bool:
	"""Validate crew panel data - UNIFIED: crew_members is now a getter for local_crew_data.members"""
	# Clear previous errors
	last_validation_errors = []

	# Get actual crew size from unified data source
	var actual_crew_size = crew_members.size()
	print("CrewPanel: Validating crew size: %d" % actual_crew_size)

	# Business rule: Minimum crew size validation
	if actual_crew_size == 0:
		last_validation_errors.append("At least one crew member is required")
		return false

	# Check if crew is complete with required size
	var required_size = selected_size if selected_size > 0 else 4
	if actual_crew_size < required_size:
		last_validation_errors.append("Crew needs %d members (currently %d)" % [required_size, actual_crew_size])
		return false

	# Business rule: Maximum crew size validation
	if actual_crew_size > 8: # Five Parsecs maximum
		last_validation_errors.append("Crew cannot exceed 8 members")
		return false

	# Business rule: Captain validation - auto-assign if needed
	if not current_captain and not local_crew_data.get("captain"):
		if crew_members.size() > 0:
			current_captain = crew_members[0]
			local_crew_data["captain"] = current_captain
			print("CrewPanel: Auto-assigned first crew member as captain during validation")
		else:
			last_validation_errors.append("A captain must be designated")
			return false

	# Mark panel as complete
	local_crew_data["is_complete"] = true
	is_crew_complete = true
	print("CrewPanel: Validation PASSED - %d crew members with captain" % actual_crew_size)

	# All validations passed
	return true

func cleanup_panel() -> void:
	"""Clean up panel state when navigating away"""
	print("CrewPanel: Cleaning up panel state")

	# Clear modern crew UI container
	if crew_creation_container:
		crew_creation_container.queue_free()
		crew_creation_container = null

	# Legacy variable (kept for compatibility - same as crew_creation_container)
	crew_creation_instance = null
	
	# Reset local crew data (UNIFIED: crew_members getter will reflect this)
	local_crew_data = {
		"members": [],
		"size": 0,
		"captain": null,
		"has_captain": false,
		"patrons": [],
		"rivals": [],
		"starting_equipment": [],
		"is_complete": false
	}

	# Reset other state
	current_captain = null
	_added_character_ids.clear()

	print("CrewPanel: Panel cleanup completed")

## Five Parsecs UI Display Functions

func update_patron_display() -> void:
	"""Update patron display section in UI"""
	if not patron_list:
		return
	
	# Clear existing patron display
	for child in patron_list.get_children():
		child.queue_free()
	
	# Display current patrons
	var patrons = local_crew_data.get("patrons", [])
	if patrons.is_empty():
		var no_patrons_label = Label.new()
		no_patrons_label.text = "No patrons yet"
		no_patrons_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		no_patrons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		patron_list.add_child(no_patrons_label)
	else:
		for patron in patrons:
			var patron_container = HBoxContainer.new()
			
			# Patron name and type
			var patron_label = Label.new()
			patron_label.text = "%s (%s)" % [
				patron.get("name", "Unknown Patron"),
				patron.get("type", "Unknown")
			]
			patron_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			patron_container.add_child(patron_label)
			
			# Patron reputation indicator
			var reputation = patron.get("reputation", 0)
			var rep_label = Label.new()
			rep_label.text = "Rep: %d" % reputation
			rep_label.add_theme_color_override("font_color", Color.CYAN if reputation > 0 else Color.WHITE)
			patron_container.add_child(rep_label)
			
			patron_list.add_child(patron_container)

func update_rival_display() -> void:
	"""Update rival display section in UI"""
	if not rival_list:
		return
	
	# Clear existing rival display
	for child in rival_list.get_children():
		child.queue_free()
	
	# Display current rivals
	var rivals = local_crew_data.get("rivals", [])
	if rivals.is_empty():
		var no_rivals_label = Label.new()
		no_rivals_label.text = "No known rivals"
		no_rivals_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		no_rivals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rival_list.add_child(no_rivals_label)
	else:
		for rival in rivals:
			var rival_container = HBoxContainer.new()
			
			# Rival name and type
			var rival_label = Label.new()
			rival_label.text = "%s (%s)" % [
				rival.get("name", "Unknown Rival"),
				_get_enemy_type_name(rival.get("type", 0))
			]
			rival_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rival_container.add_child(rival_label)
			
			# Rival threat level indicator
			var level = rival.get("level", 1)
			var level_label = Label.new()
			level_label.text = "Lvl: %d" % level
			level_label.add_theme_color_override("font_color", Color.RED if level > 2 else Color.ORANGE)
			rival_container.add_child(level_label)
			
			rival_list.add_child(rival_container)

func update_equipment_display() -> void:
	"""Update equipment display section in UI"""
	if not equipment_list:
		return
	
	# Clear existing equipment display
	for child in equipment_list.get_children():
		child.queue_free()
	
	# Display starting equipment
	var equipment = local_crew_data.get("starting_equipment", [])
	if equipment.is_empty():
		var no_equipment_label = Label.new()
		no_equipment_label.text = "No starting equipment"
		no_equipment_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		no_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipment_list.add_child(no_equipment_label)
	else:
		for item in equipment:
			var item_label = Label.new()
			if typeof(item) == TYPE_STRING:
				item_label.text = "• %s" % item
			else:
				item_label.text = "• %s" % str(item)
			equipment_list.add_child(item_label)

func _get_enemy_type_name(type_id: int) -> String:
	"""Get human-readable name for enemy type"""
	var enemy_types = GlobalEnums.EnemyType
	if type_id >= 0 and type_id < enemy_types.size():
		return enemy_types.keys()[type_id]
	return "Unknown"

func refresh_all_displays() -> void:
	"""Refresh all Five Parsecs display sections"""
	update_patron_display()
	update_rival_display()
	update_equipment_display()
	update_crew_flavor_display()  # Core Rules p.30 - We Met Through + Characterized As

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: CrewPanel] INITIALIZATION ====")
	print("  Phase: 3 of 7 (Crew Generation)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# Check for coordinator access using new robust method
	var has_coordinator = get_coordinator() != null
	print("  Has Coordinator Access: %s" % str(has_coordinator))
	
	if not has_coordinator:
		print("    ⚠️  NO COORDINATOR ACCESS - Operating in standalone mode")
	else:
		print("    ✅ Coordinator connected successfully")
	
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
	
	# Check current crew data
	print("  === INITIAL CREW DATA ===")
	print("    Crew Members: %d" % crew_members.size())
	print("    Current Captain: %s" % (current_captain != null))
	print("    Local Crew Data Keys: %s" % str(local_crew_data.keys()))
	print("    Is Complete: %s" % local_crew_data.get("is_complete", false))
	print("    Generated Patrons: %d" % generated_patrons.size())
	print("    Generated Rivals: %d" % generated_rivals.size())
	
	# Check Five Parsecs systems
	print("  === FIVE PARSECS SYSTEMS ===")
	print("    Patron System: %s" % (patron_system != null))
	print("    Rival System: %s" % (rival_system != null))
	print("    Security Validator: %s" % (security_validator != null))
	
	# Check UI component availability (Modern UI)
	print("  === UI COMPONENTS (Modern Design System) ===")
	print("    Modern UI Container: %s" % (crew_creation_container != null))
	print("    Crew Size Option: %s" % (crew_size_option_node != null))
	print("    Crew List: %s" % (crew_list != null))
	print("    Generate Button: %s" % (add_button_node != null))
	print("    Validation Panel: %s" % (validation_panel != null))
	
	print("==== [PANEL: CrewPanel] INIT COMPLETE ====\n")

## Coordinator Integration (Modern UI)
func _on_coordinator_set() -> void:
	"""Handle coordinator assignment - modern UI doesn't need InitialCrewCreation"""
	print("CrewPanel: Coordinator received - modern UI uses direct integration")

# Completion logic with debouncing
var completion_check_timer: SceneTreeTimer = null

func _check_and_emit_completion() -> void:
	"""Debounced completion check"""
	# SceneTreeTimer doesn't need to be stopped, just replace it
	if is_inside_tree() and get_tree():
		completion_check_timer = get_tree().create_timer(0.5)
		await completion_check_timer.timeout
		_perform_completion_check()
	else:
		# If tree isn't available, perform check immediately
		_perform_completion_check()

func _perform_completion_check() -> void:
	"""Actual completion validation"""
	var member_count = local_crew_data.members.size()
	var required_size = selected_size if selected_size > 0 else 4
	
	if member_count >= required_size:
		is_crew_complete = true
		local_crew_data.is_complete = true

		# Update coordinator
		var coord = get_coordinator()
		if coord and coord.has_method("update_crew_state"):
			coord.update_crew_state(local_crew_data)
			print("CrewPanel: ✅ Updated coordinator with %d crew members" % member_count)

		# Finalize crew resources from table rolling (patrons, rivals, rumors, story points)
		# Sprint 26.3: Character-Everywhere - members should be Character objects
		var crew_members: Array = []
		for member in local_crew_data.members:
			if member is Character:
				crew_members.append(member)
			elif member is Dictionary and member.has("character_object"):
				# Legacy fallback for Dictionary-wrapped Character objects
				crew_members.append(member.character_object)

		if crew_members.size() > 0:
			var campaign = coord.get_campaign() if coord and coord.has_method("get_campaign") else null
			var total_resources = CharacterGeneration.finalize_crew_resources(crew_members, campaign)
			print("CrewPanel: ✅ Finalized crew resources - %d patrons, %d rivals, %d rumors, %d story points" % [
				total_resources.patrons, total_resources.rivals, total_resources.rumors, total_resources.story_points
			])
		
		# PHASE 3 FIX: Trigger BaseCampaignPanel validation and completion
		_validate_and_emit_completion()
		
		# Emit crew-specific signals
		crew_setup_complete.emit(local_crew_data)
		panel_data_changed.emit(local_crew_data)
		
		print("CrewPanel: ✅ Crew generation complete with %d/%d members" % [member_count, required_size])

# NOTE: _connect_to_initial_crew_creation() removed - modern UI handles character generation directly

func _on_character_generated(character) -> void:
	"""Handle character generation - Sprint 26.3: Character-Everywhere (always stores Character objects)"""
	print("CrewPanel: Character generated - processing type: %s" % type_string(typeof(character)))

	var character_object: Character = null

	# Convert to Character object if needed (Sprint 26.3: Character-Everywhere)
	if character is Character:
		character_object = character
	elif character is Dictionary:
		# Convert Dictionary to Character object
		character_object = _reconstruct_character_from_dict(character)
		if not character_object:
			push_error("CrewPanel: Failed to convert Dictionary to Character")
			return
		print("CrewPanel: Converted Dictionary to Character object")
	else:
		push_error("CrewPanel: Unknown character type received: %s" % type_string(typeof(character)))
		return

	var char_name: String = character_object.character_name

	# Check for duplicates using tracking system
	if _added_character_ids.has(char_name):
		print("CrewPanel: Duplicate character '%s' ignored (tracking system)" % char_name)
		return

	# Double-check against existing members (Sprint 26.3: All members are Character)
	for member in local_crew_data.members:
		if member is Character and member.character_name == char_name:
			print("CrewPanel: Duplicate character '%s' ignored (existing check)" % char_name)
			return

	# Mark as added to prevent future duplicates
	_added_character_ids[char_name] = true

	# Sprint 26.3: Always append Character object to local_crew_data.members
	local_crew_data["members"].append(character_object)

	# Auto-assign first member as captain if none assigned
	if not current_captain and crew_members.size() == 1:
		set_captain(character_object)
		print("CrewPanel: Auto-assigned '%s' as captain" % char_name)

	print("CrewPanel: Added '%s' - Total crew: %d" % [char_name, crew_members.size()])
	
	# Update coordinator if available
	if get_coordinator():
		if get_coordinator().has_method("update_crew_state"):
			get_coordinator().update_crew_state(local_crew_data)
	
	# Emit crew updated signal
	_emit_crew_updated()
	
	# Check if we have enough crew to enable progression
	if crew_members.size() >= 4:
		print("CrewPanel: Crew complete with %d members - enabling progression" % crew_members.size())
		local_crew_data["is_complete"] = true
		is_crew_complete = true
		emit_signal("panel_validation_changed", true)
		var current_panel_data = get_panel_data()
		print("CrewPanel: DEBUG - Emitting panel_completed with data keys: %s" % str(current_panel_data.keys()))
		print("CrewPanel: DEBUG - Crew count in data: %d" % current_panel_data.get("members", []).size())
		emit_signal("panel_completed", current_panel_data)
	
	# Check completion
	call_deferred("_check_and_emit_completion")

func _on_crew_created(crew_data: Dictionary) -> void:
	"""Handle complete crew creation"""
	print("CrewPanel: Complete crew created with %d members" % crew_data.get("members", []).size())
	local_crew_data = crew_data
	call_deferred("_check_and_emit_completion")

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	"""Mobile: Single column, 56dp targets, compact crew list"""
	super._apply_mobile_layout()

	# Mobile layouts for crew panels will have larger touch targets
	# Touch targets automatically adjusted via design system inheritance

func _apply_tablet_layout() -> void:
	"""Tablet: Two columns, 48dp targets, detailed crew list"""
	super._apply_tablet_layout()

	# Tablet layouts optimized for two-column crew display
	# Touch targets at standard 48dp via design system

func _apply_desktop_layout() -> void:
	"""Desktop: Multi-column, 48dp targets, full crew details"""
	super._apply_desktop_layout()

	# Desktop layouts with maximum information density
	# Standard touch targets via design system
