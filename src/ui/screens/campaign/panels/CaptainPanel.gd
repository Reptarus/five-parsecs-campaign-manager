class_name CaptainPanel
extends FiveParsecsCampaignPanel

## Enhanced Captain Creation Panel for Five Parsecs Campaign Manager
## Uses FiveParsecsCampaignPanel base class for proper integration
## Implements complete captain generation with Five Parsecs rules

# Progress tracking
const STEP_NUMBER := 2  # Step 2 of 7 in campaign wizard

# Captain-specific imports
const Character = preload("res://src/core/character/Character.gd")
const SimpleCharacterCreator = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")

# Captain-specific signals
# Sprint 26.3: These signals emit panel state as Dictionary (from get_panel_data())
# The Dictionary contains captain data serialized for state management
signal captain_created(captain_data: Dictionary)
signal captain_customization_requested(captain: Character)
signal captain_data_updated(captain_data: Dictionary)
signal step_completed(step_name: String)

# State management
var captain: Character = null
var creation_method: String = ""
var captain_bonuses: Dictionary = {
	"leadership": 0,
	"experience": 100,
	"starting_gear": []
}

# UI References (safe access pattern with proper node paths)
@onready var captain_display_container: VBoxContainer = $"ContentMargin/MainContent/FormContent/FormContainer/Content"
@onready var main_form_container: VBoxContainer = $"ContentMargin/MainContent/FormContent/FormContainer/Content"

# UI Component references with unique names
@onready var captain_name_input: LineEdit = %CaptainNameInput
@onready var background_option: OptionButton = %BackgroundOption
@onready var motivation_option: OptionButton = %MotivationOption
@onready var advanced_creation_button: Button = %AdvancedCreationButton
@onready var continue_button: Button = %ContinueButton

var panel_data: Dictionary = {}
var character_creator: Node = null
var current_captain: Character = null

# Labels for better UX
var background_label: Label
var background_description: Label
var motivation_label: Label
var motivation_description: Label

# Store backgrounds/motivations for reference in descriptions
var _backgrounds_data: Array = []
var _motivations_data: Array = []

# Verbose mode for dice roll transparency
var verbose_mode_toggle: CheckBox
var roll_log_display: RichTextLabel
var _verbose_mode: bool = false
var _roll_log: Array[String] = []

# Sprint 26.7: Collapsible advanced options
var advanced_options_container: VBoxContainer
var advanced_options_toggle: Button
var advanced_options_visible: bool = false

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info(
		"Captain Creation",
		"Create your ship's captain. Stats: Combat, Reactions, Toughness, Savvy, Tech, Move."
	)

	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()

	# Apply design system styling to scene-defined inputs
	call_deferred("_apply_input_styling")

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display

	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")

	# Validate node references
	_validate_node_references()

	print("CaptainPanel: Enhanced captain creation ready")

	# SPRINT 5.1: Emit panel_ready after initialization complete
	call_deferred("emit_panel_ready")

# NOTE: _add_progress_indicator() removed - CampaignCreationUI handles progress display centrally

func _on_coordinator_set() -> void:
	"""Called when coordinator is set - sync initial state from coordinator (Sprint 26.20)"""
	print("CaptainPanel: Coordinator set, syncing initial state")

	var coordinator = get_coordinator_reference()
	if coordinator and coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		# Check for captain data in state - try multiple key locations
		var captain_data: Dictionary = {}
		if state.has("captain") and state.captain is Dictionary:
			captain_data = state.captain
		elif state.has("captain") and state.captain is Object and state.captain.has_method("to_dictionary"):
			captain_data = state.captain.to_dictionary()

		if not captain_data.is_empty():
			print("CaptainPanel: Restoring captain data from coordinator state")
			set_panel_data({"captain": captain_data})
		else:
			print("CaptainPanel: No existing captain data in coordinator state")
	else:
		print("CaptainPanel: Coordinator not available or missing get_unified_campaign_state")

func _validate_node_references() -> void:
	"""Validate all critical node references are available"""
	if OS.is_debug_build():
		assert(main_form_container != null, "main_form_container not found - check scene structure")
		if character_creator == null:
			push_warning("CaptainPanel: character_creator not found - advanced creation disabled")
		print("CaptainPanel: Node references validated")

func _apply_input_styling() -> void:
	"""Apply design system styling to scene-defined inputs (eliminates stretched teal bars)"""
	# Style OptionButtons
	if background_option:
		_style_option_button(background_option)
	if motivation_option:
		_style_option_button(motivation_option)

	# Style LineEdit
	if captain_name_input:
		_style_line_edit(captain_name_input)

	# Style Buttons with touch-friendly sizing
	if advanced_creation_button:
		_style_button(advanced_creation_button)
	if continue_button:
		_style_button(continue_button)
		# Make continue button more prominent
		continue_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	print("CaptainPanel: Design system styling applied to inputs")

# NOTE: _style_button() now inherited from BaseCampaignPanel - removed duplicate

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup captain-specific content"""
	_create_captain_interface()
	_setup_ui()
	_connect_signals()
	_initialize_character_creator()

func _create_captain_interface() -> void:
	"""Create comprehensive captain creation interface using base panel structure"""
	if not content_container:
		push_error("CaptainPanel: FormContainer not found in base panel")
		return

	var main_container = VBoxContainer.new()
	main_container.name = "CaptainCreationContainer"
	content_container.add_child(main_container)

	# REMOVED: 4-button grid was confusing users - using scene's simple form instead
	# _add_creation_methods(main_container)

	# Captain preview area
	_add_captain_preview(main_container)

	# Advanced options
	_add_advanced_options(main_container)

# NOTE: _add_creation_methods() removed in Sprint 26.7 - was already not called (line 161 comment)
# The 4-button grid was confusing users; using simple form instead

func _add_captain_preview(container: VBoxContainer) -> void:
	"""Add captain preview display area"""
	var preview_label = Label.new()
	preview_label.text = "Captain Preview:"
	preview_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	preview_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(preview_label)

	captain_display_container = VBoxContainer.new()
	captain_display_container.name = "CaptainDisplay"
	captain_display_container.add_theme_constant_override("separation", SPACING_SM)
	container.add_child(captain_display_container)

	# Initial empty state
	var empty_label = Label.new()
	empty_label.text = "Choose a creation method to generate your captain"
	empty_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	captain_display_container.add_child(empty_label)

func _add_advanced_options(container: VBoxContainer) -> void:
	"""Add advanced captain options in a collapsible section (Sprint 26.7)"""
	# Create toggle button for collapsible section
	advanced_options_toggle = Button.new()
	advanced_options_toggle.text = "▶ Advanced Options (Optional)"
	advanced_options_toggle.flat = true
	advanced_options_toggle.custom_minimum_size.y = TOUCH_TARGET_MIN
	advanced_options_toggle.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	advanced_options_toggle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	advanced_options_toggle.pressed.connect(_on_advanced_options_toggled)
	container.add_child(advanced_options_toggle)

	# Create container for advanced options (hidden by default)
	advanced_options_container = VBoxContainer.new()
	advanced_options_container.visible = false
	advanced_options_container.add_theme_constant_override("separation", SPACING_SM)
	container.add_child(advanced_options_container)

	var options_container = HBoxContainer.new()
	options_container.add_theme_constant_override("separation", SPACING_MD)
	advanced_options_container.add_child(options_container)

	# Leadership bonus
	var leadership_check = CheckBox.new()
	leadership_check.text = "Natural Leader (+1 to crew morale)"
	leadership_check.custom_minimum_size.y = TOUCH_TARGET_MIN
	leadership_check.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	leadership_check.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	leadership_check.toggled.connect(_on_leadership_toggled)
	options_container.add_child(leadership_check)

	# Extra experience
	var xp_container = HBoxContainer.new()
	xp_container.add_theme_constant_override("separation", SPACING_SM)
	options_container.add_child(xp_container)

	var xp_label = Label.new()
	xp_label.text = "Starting XP:"
	xp_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	xp_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	xp_container.add_child(xp_label)

	var xp_spin = SpinBox.new()
	xp_spin.min_value = 100
	xp_spin.max_value = 500
	xp_spin.value = 100
	xp_spin.step = 50
	xp_spin.custom_minimum_size.y = TOUCH_TARGET_MIN
	xp_spin.value_changed.connect(_on_xp_changed)
	xp_container.add_child(xp_spin)

	# Verbose mode toggle for dice roll transparency
	var verbose_container = VBoxContainer.new()
	verbose_container.name = "VerboseModeContainer"
	advanced_options_container.add_child(verbose_container)

	var separator = HSeparator.new()
	verbose_container.add_child(separator)

	verbose_mode_toggle = CheckBox.new()
	verbose_mode_toggle.text = "🎲 Show Dice Rolls (Verbose Mode)"
	verbose_mode_toggle.tooltip_text = "Display the actual dice rolls used to generate captain stats"
	verbose_mode_toggle.toggled.connect(_on_verbose_mode_toggled)
	verbose_container.add_child(verbose_mode_toggle)

	# Roll log display (initially hidden)
	roll_log_display = RichTextLabel.new()
	roll_log_display.name = "RollLogDisplay"
	roll_log_display.bbcode_enabled = true
	roll_log_display.fit_content = true
	roll_log_display.scroll_active = false
	roll_log_display.custom_minimum_size = Vector2(0, 0)
	roll_log_display.add_theme_color_override("default_color", Color(0.7, 0.9, 0.7))
	roll_log_display.add_theme_font_size_override("normal_font_size", 11)
	roll_log_display.visible = false
	verbose_container.add_child(roll_log_display)

func _on_verbose_mode_toggled(pressed: bool) -> void:
	"""Handle verbose mode toggle"""
	_verbose_mode = pressed
	if roll_log_display:
		roll_log_display.visible = pressed
		if pressed and _roll_log.size() > 0:
			_update_roll_log_display()
		elif not pressed:
			roll_log_display.text = ""

func _on_advanced_options_toggled() -> void:
	"""Toggle visibility of advanced options section (Sprint 26.7)"""
	advanced_options_visible = not advanced_options_visible
	if advanced_options_container:
		advanced_options_container.visible = advanced_options_visible
	if advanced_options_toggle:
		advanced_options_toggle.text = ("▼ " if advanced_options_visible else "▶ ") + "Advanced Options (Optional)"

func _log_dice_roll(context: String, roll_value: int, result: int) -> void:
	"""Log a dice roll for verbose mode display"""
	var log_entry = "[color=#aaccaa]%s:[/color] Rolled %d → Stat: %d" % [context, roll_value, result]
	_roll_log.append(log_entry)
	if _verbose_mode:
		_update_roll_log_display()

func _update_roll_log_display() -> void:
	"""Update the roll log display with current logs"""
	if not roll_log_display:
		return

	var log_text = "[b]🎲 Dice Roll Log:[/b]\n"
	for entry in _roll_log:
		log_text += entry + "\n"
	roll_log_display.text = log_text

func _clear_roll_log() -> void:
	"""Clear the roll log for new generation"""
	_roll_log.clear()
	if roll_log_display:
		roll_log_display.text = ""

func _wrap_form_in_cards() -> void:
	"""Wrap form elements in glass morphism cards for visual consistency"""
	if not main_form_container:
		return

	# Create a new container to hold the cards
	var cards_container := VBoxContainer.new()
	cards_container.name = "CardsContainer"
	cards_container.add_theme_constant_override("separation", SPACING_LG)

	# === CAPTAIN NAME CARD ===
	var name_card := _create_form_section_card("CAPTAIN NAME", "Your captain's identity in the Fringe.")
	var name_content := name_card.get_node("CardMargin/CardContent")

	# Move captain name input into card (if exists)
	if captain_name_input and captain_name_input.get_parent():
		var old_parent = captain_name_input.get_parent()
		old_parent.remove_child(captain_name_input)
		name_content.add_child(captain_name_input)

	cards_container.add_child(name_card)

	# === BACKGROUND & MOTIVATION CARD ===
	var bg_mot_card := _create_form_section_card("BACKGROUND & MOTIVATION", "These shape your captain's history and drive.")
	var bg_mot_content := bg_mot_card.get_node("CardMargin/CardContent")

	# Move background elements into card
	if background_label and background_label.get_parent():
		background_label.get_parent().remove_child(background_label)
		bg_mot_content.add_child(background_label)
	if background_option and background_option.get_parent():
		background_option.get_parent().remove_child(background_option)
		bg_mot_content.add_child(background_option)
	if background_description and background_description.get_parent():
		background_description.get_parent().remove_child(background_description)
		bg_mot_content.add_child(background_description)

	# Add spacer between background and motivation
	var spacer := Control.new()
	spacer.custom_minimum_size.y = SPACING_MD
	bg_mot_content.add_child(spacer)

	# Move motivation elements into card
	if motivation_label and motivation_label.get_parent():
		motivation_label.get_parent().remove_child(motivation_label)
		bg_mot_content.add_child(motivation_label)
	if motivation_option and motivation_option.get_parent():
		motivation_option.get_parent().remove_child(motivation_option)
		bg_mot_content.add_child(motivation_option)
	if motivation_description and motivation_description.get_parent():
		motivation_description.get_parent().remove_child(motivation_description)
		bg_mot_content.add_child(motivation_description)

	cards_container.add_child(bg_mot_card)

	# === ACTION BUTTONS (no card, just styled) ===
	var button_container := HBoxContainer.new()
	button_container.name = "ActionButtons"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", SPACING_MD)

	if advanced_creation_button and advanced_creation_button.get_parent():
		advanced_creation_button.get_parent().remove_child(advanced_creation_button)
		button_container.add_child(advanced_creation_button)
	if continue_button and continue_button.get_parent():
		continue_button.get_parent().remove_child(continue_button)
		button_container.add_child(continue_button)

	cards_container.add_child(button_container)

	# Add cards container to form
	main_form_container.add_child(cards_container)
	main_form_container.move_child(cards_container, 0)

	print("CaptainPanel: Form elements wrapped in glass morphism cards")

func _create_form_section_card(title: String, description: String = "") -> PanelContainer:
	"""Create a glass morphism card for form sections"""
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_glass_card_style())

	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", SPACING_MD)
	margin.add_theme_constant_override("margin_right", SPACING_MD)
	margin.add_theme_constant_override("margin_top", SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", SPACING_MD)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.add_theme_constant_override("separation", SPACING_SM)
	margin.add_child(content)

	# Card header
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(header)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	content.add_child(sep)

	# Description (if provided)
	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		desc.add_theme_color_override("font_color", Color(COLOR_TEXT_SECONDARY, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)

	return card

func _create_glass_card_style(alpha: float = 0.8) -> StyleBoxFlat:
	"""Create glass morphism style for cards"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, alpha)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)  # Margin handled by MarginContainer
	return style

func _setup_ui() -> void:
	# Original setup preserved for compatibility
	_setup_background_options()
	_setup_motivation_options()
	_create_option_labels()
	_update_all_option_descriptions()
	# Wrap form elements in glass morphism cards
	call_deferred("_wrap_form_in_cards")

func _create_option_labels() -> void:
	"""Create labels above and descriptions below the OptionButtons"""
	# Add label and description for Background
	if background_option:
		var parent = background_option.get_parent()
		if parent:
			var bg_index = background_option.get_index()

			# Create label above
			background_label = Label.new()
			background_label.name = "BackgroundLabel"
			background_label.text = "Captain Background:"
			background_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			background_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			parent.add_child(background_label)
			parent.move_child(background_label, bg_index)

			# Create description below
			background_description = Label.new()
			background_description.name = "BackgroundDescription"
			background_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			background_description.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			background_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(background_description)
			parent.move_child(background_description, bg_index + 2)

	# Add label and description for Motivation
	if motivation_option:
		var parent = motivation_option.get_parent()
		if parent:
			var mot_index = motivation_option.get_index()

			# Create label above
			motivation_label = Label.new()
			motivation_label.name = "MotivationLabel"
			motivation_label.text = "Captain Motivation:"
			motivation_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			motivation_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			parent.add_child(motivation_label)
			parent.move_child(motivation_label, mot_index)

			# Create description below
			motivation_description = Label.new()
			motivation_description.name = "MotivationDescription"
			motivation_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			motivation_description.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			motivation_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(motivation_description)
			parent.move_child(motivation_description, mot_index + 2)

func _update_all_option_descriptions() -> void:
	"""Update all option descriptions with current selection info"""
	_update_background_description()
	_update_motivation_description()

func _update_background_description() -> void:
	"""Update background description with bonuses"""
	if not background_description or not background_option:
		return

	var index = background_option.selected
	if index < 0 or index >= _backgrounds_data.size():
		return

	var bg = _backgrounds_data[index]
	var desc_parts: Array[String] = []

	# Build description from bonuses
	if bg.has("bonus"):
		for stat in bg.bonus.keys():
			desc_parts.append("+1 %s" % stat.capitalize())

	if bg.has("credits"):
		desc_parts.append("+ %s credits" % bg.credits)

	if bg.has("gear"):
		for item in bg.gear:
			desc_parts.append("+ %s" % item)

	if bg.has("patron"):
		desc_parts.append("+ Starting Patron")

	if bg.has("story_points"):
		desc_parts.append("+ %d Story Point(s)" % bg.story_points)

	if bg.has("rumors"):
		desc_parts.append("+ %d Quest Rumor(s)" % bg.rumors)

	if desc_parts.size() > 0:
		background_description.text = "→ " + ", ".join(desc_parts)
	else:
		background_description.text = "→ No special bonuses"

func _update_motivation_description() -> void:
	"""Update motivation description with bonuses"""
	if not motivation_description or not motivation_option:
		return

	var index = motivation_option.selected
	if index < 0 or index >= _motivations_data.size():
		return

	var mot = _motivations_data[index]
	var desc_parts: Array[String] = []

	# Build description from bonuses
	if mot.has("bonus"):
		for stat in mot.bonus.keys():
			desc_parts.append("+1 %s" % stat.capitalize())

	if mot.has("credits"):
		desc_parts.append("+ %s credits" % mot.credits)

	if mot.has("gear"):
		for item in mot.gear:
			desc_parts.append("+ %s" % item)

	if mot.has("patron"):
		desc_parts.append("+ Starting Patron")

	if mot.has("story_points"):
		desc_parts.append("+ %d Story Point(s)" % mot.story_points)

	if mot.has("rumors"):
		desc_parts.append("+ %d Quest Rumor(s)" % mot.rumors)

	if mot.has("rival"):
		desc_parts.append("+ Starting Rival")

	if mot.has("xp_bonus"):
		desc_parts.append("+ %d XP bonus" % mot.xp_bonus)

	if desc_parts.size() > 0:
		motivation_description.text = "→ " + ", ".join(desc_parts)
	else:
		motivation_description.text = "→ No special bonuses"

func _setup_background_options() -> void:
	"""Setup background options from Five Parsecs rules"""
	if not background_option:
		return

	background_option.clear()

	# Five Parsecs Background Table (from core rules)
	_backgrounds_data = [
		{"name": "Peaceful, High-Tech Colony", "bonus": {"savvy": 1}, "credits": "1D6"},
		{"name": "Giant, Overcrowded, Dystopian City", "bonus": {"speed": 1}},
		{"name": "Low-Tech Colony", "gear": ["Low-tech Weapon"]},
		{"name": "Mining Colony", "bonus": {"toughness": 1}},
		{"name": "Military Brat", "bonus": {"combat": 1}},
		{"name": "Space Station", "gear": ["Gear"]},
		{"name": "Military Outpost", "bonus": {"reactions": 1}},
		{"name": "Drifter", "gear": ["Gear"]},
		{"name": "Lower Megacity Class", "gear": ["Low-tech Weapon"]},
		{"name": "Wealthy Merchant Family", "credits": "2D6"},
		{"name": "Frontier Gang", "bonus": {"combat": 1}},
		{"name": "Religious Cult", "patron": true, "story_points": 1},
		{"name": "War-Torn Hell-Hole", "bonus": {"reactions": 1}, "gear": ["Military Weapon"]},
		{"name": "Tech Guild", "bonus": {"savvy": 1}, "credits": "1D6", "gear": ["High-tech Weapon"]},
		{"name": "Subjugated Colony on Alien World", "gear": ["Gadget"]},
		{"name": "Long-Term Space Mission", "bonus": {"savvy": 1}},
		{"name": "Research Outpost", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"name": "Primitive or Regressed World", "bonus": {"toughness": 1}, "gear": ["Low-tech Weapon"]},
		{"name": "Orphan Utility Program", "patron": true, "story_points": 1},
		{"name": "Isolationist Enclave", "rumors": 2},
		{"name": "Comfortable Megacity Class", "credits": "1D6"},
		{"name": "Industrial World", "gear": ["Gear"]},
		{"name": "Bureaucrat", "credits": "1D6"},
		{"name": "Wasteland Nomads", "bonus": {"reactions": 1}, "gear": ["Low-tech Weapon"]},
		{"name": "Alien Culture", "gear": ["High-tech Weapon"]}
	]

	for i in range(_backgrounds_data.size()):
		var background = _backgrounds_data[i]
		background_option.add_item(background.name, i)

	background_option.select(0) # Default to first option

func _setup_motivation_options() -> void:
	"""Setup motivation options from Five Parsecs rules"""
	if not motivation_option:
		return

	motivation_option.clear()

	# Five Parsecs Motivation Table (from core rules)
	_motivations_data = [
		{"name": "Wealth", "credits": "1D6"},
		{"name": "Fame", "story_points": 1},
		{"name": "Glory", "bonus": {"combat": 1}, "gear": ["Military Weapon"]},
		{"name": "Survival", "bonus": {"toughness": 1}},
		{"name": "Escape", "bonus": {"speed": 1}},
		{"name": "Adventure", "credits": "1D6", "gear": ["Low-tech Weapon"]},
		{"name": "Truth", "rumors": 1, "story_points": 1},
		{"name": "Technology", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"name": "Discovery", "bonus": {"savvy": 1}, "gear": ["Gear"]},
		{"name": "Loyalty", "patron": true, "story_points": 1},
		{"name": "Revenge", "xp_bonus": 2, "rival": true},
		{"name": "Romance", "rumors": 1, "story_points": 1},
		{"name": "Faith", "rumors": 1, "story_points": 1},
		{"name": "Political", "patron": true, "story_points": 1},
		{"name": "Power", "xp_bonus": 2, "rival": true},
		{"name": "Order", "patron": true, "story_points": 1},
		{"name": "Freedom", "xp_bonus": 2}
	]

	for i in range(_motivations_data.size()):
		var motivation = _motivations_data[i]
		motivation_option.add_item(motivation.name, i)

	motivation_option.select(0) # Default to first option

func _connect_signals() -> void:
	if captain_name_input:
		captain_name_input.text_changed.connect(_on_captain_name_changed)
	if background_option:
		background_option.item_selected.connect(_on_background_changed)
	if motivation_option:
		motivation_option.item_selected.connect(_on_motivation_changed)
	if continue_button and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if advanced_creation_button and not advanced_creation_button.pressed.is_connected(_on_advanced_creation_pressed):
		advanced_creation_button.pressed.connect(_on_advanced_creation_pressed)

func _initialize_character_creator() -> void:
	"""Initialize character creator for advanced captain creation"""
	print("CaptainPanel: Starting character creator initialization")
	
	# Try to load the SimpleCharacterCreator scene
	var character_creator_scene = preload("res://src/ui/screens/character/SimpleCharacterCreator.tscn")
	print("CaptainPanel: Scene preloaded: ", character_creator_scene != null)
	
	if character_creator_scene:
		character_creator = character_creator_scene.instantiate()
		print("CaptainPanel: Scene instantiated: ", character_creator != null)
		
		if character_creator:
			print("CaptainPanel: Character creator class: ", character_creator.get_class())
			print("CaptainPanel: Character creator script: ", character_creator.get_script())
			
			# Add as child but keep hidden
			add_child(character_creator)
			character_creator.visible = false
			
			# Connect character creator signals
			if character_creator.has_signal("character_created"):
				character_creator.character_created.connect(_on_character_created)
				print("CaptainPanel: Connected character_created signal")
			if character_creator.has_signal("character_edited"):
				character_creator.character_edited.connect(_on_character_edited)
				print("CaptainPanel: Connected character_edited signal")
			if character_creator.has_signal("creation_cancelled"):
				character_creator.creation_cancelled.connect(_on_character_creation_cancelled)
				print("CaptainPanel: Connected creation_cancelled signal")
			
			print("CaptainPanel: Character creator initialized successfully")
		else:
			push_warning("CaptainPanel: Failed to instantiate character creator")
	else:
		push_warning("CaptainPanel: Character creator scene not found")

func _on_captain_name_changed(new_text: String) -> void:
	panel_data["captain_name"] = new_text

	# Create captain object if it doesn't exist to enable validation
	if not current_captain:
		current_captain = Character.new()
		current_captain.is_captain = true
		# SPRINT 26.20 FIX: Initialize stats to valid Five Parsecs defaults (1-6 range)
		# Without this, stats default to 0 which fails validation
		current_captain.combat = 1
		current_captain.reactions = 1
		current_captain.savvy = 1
		current_captain.toughness = 3
		current_captain.tech = 1
		current_captain.speed = 4
		current_captain.is_human = true
		print("CaptainPanel: Created new captain with default stats")
	current_captain.character_name = new_text

	panel_data_changed.emit(get_panel_data())

func _on_background_changed(index: int) -> void:
	"""Handle background selection with Five Parsecs rules"""
	var backgrounds = [
		{"id": "peaceful_high_tech", "name": "Peaceful, High-Tech Colony", "bonus": {"savvy": 1}, "credits": "1D6"},
		{"id": "dystopian_city", "name": "Giant, Overcrowded, Dystopian City", "bonus": {"speed": 1}},
		{"id": "low_tech_colony", "name": "Low-Tech Colony", "gear": ["Low-tech Weapon"]},
		{"id": "mining_colony", "name": "Mining Colony", "bonus": {"toughness": 1}},
		{"id": "military_brat", "name": "Military Brat", "bonus": {"combat": 1}},
		{"id": "space_station", "name": "Space Station", "gear": ["Gear"]},
		{"id": "military_outpost", "name": "Military Outpost", "bonus": {"reactions": 1}},
		{"id": "drifter", "name": "Drifter", "gear": ["Gear"]},
		{"id": "lower_megacity", "name": "Lower Megacity Class", "gear": ["Low-tech Weapon"]},
		{"id": "wealthy_merchant", "name": "Wealthy Merchant Family", "credits": "2D6"},
		{"id": "frontier_gang", "name": "Frontier Gang", "bonus": {"combat": 1}},
		{"id": "religious_cult", "name": "Religious Cult", "patron": true, "story_points": 1},
		{"id": "war_torn", "name": "War-Torn Hell-Hole", "bonus": {"reactions": 1}, "gear": ["Military Weapon"]},
		{"id": "tech_guild", "name": "Tech Guild", "bonus": {"savvy": 1}, "credits": "1D6", "gear": ["High-tech Weapon"]},
		{"id": "alien_colony", "name": "Subjugated Colony on Alien World", "gear": ["Gadget"]},
		{"id": "space_mission", "name": "Long-Term Space Mission", "bonus": {"savvy": 1}},
		{"id": "research_outpost", "name": "Research Outpost", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"id": "primitive_world", "name": "Primitive or Regressed World", "bonus": {"toughness": 1}, "gear": ["Low-tech Weapon"]},
		{"id": "orphan_program", "name": "Orphan Utility Program", "patron": true, "story_points": 1},
		{"id": "isolationist", "name": "Isolationist Enclave", "rumors": 2},
		{"id": "comfortable_megacity", "name": "Comfortable Megacity Class", "credits": "1D6"},
		{"id": "industrial_world", "name": "Industrial World", "gear": ["Gear"]},
		{"id": "bureaucrat", "name": "Bureaucrat", "credits": "1D6"},
		{"id": "wasteland_nomads", "name": "Wasteland Nomads", "bonus": {"reactions": 1}, "gear": ["Low-tech Weapon"]},
		{"id": "alien_culture", "name": "Alien Culture", "gear": ["High-tech Weapon"]}
	]
	
	if index >= 0 and index < backgrounds.size():
		var background = backgrounds[index]
		panel_data["captain_background"] = background.id
		panel_data["captain_background_name"] = background.name
		panel_data["captain_background_data"] = background
		
		# Update captain object if it exists
		if current_captain:
			current_captain.background = background.id

		print("CaptainPanel: Selected background: %s" % background.name)
		_update_background_description()
		panel_data_changed.emit(get_panel_data())

func _on_motivation_changed(index: int) -> void:
	"""Handle motivation selection with Five Parsecs rules"""
	var motivations = [
		{"id": "wealth", "name": "Wealth", "credits": "1D6"},
		{"id": "fame", "name": "Fame", "story_points": 1},
		{"id": "glory", "name": "Glory", "bonus": {"combat": 1}, "gear": ["Military Weapon"]},
		{"id": "survival", "name": "Survival", "bonus": {"toughness": 1}},
		{"id": "escape", "name": "Escape", "bonus": {"speed": 1}},
		{"id": "adventure", "name": "Adventure", "credits": "1D6", "gear": ["Low-tech Weapon"]},
		{"id": "truth", "name": "Truth", "rumors": 1, "story_points": 1},
		{"id": "technology", "name": "Technology", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"id": "discovery", "name": "Discovery", "bonus": {"savvy": 1}, "gear": ["Gear"]},
		{"id": "loyalty", "name": "Loyalty", "patron": true, "story_points": 1},
		{"id": "revenge", "name": "Revenge", "xp_bonus": 2, "rival": true},
		{"id": "romance", "name": "Romance", "rumors": 1, "story_points": 1},
		{"id": "faith", "name": "Faith", "rumors": 1, "story_points": 1},
		{"id": "political", "name": "Political", "patron": true, "story_points": 1},
		{"id": "power", "name": "Power", "xp_bonus": 2, "rival": true},
		{"id": "order", "name": "Order", "patron": true, "story_points": 1},
		{"id": "freedom", "name": "Freedom", "xp_bonus": 2}
	]
	
	if index >= 0 and index < motivations.size():
		var motivation = motivations[index]
		panel_data["captain_motivation"] = motivation.id
		panel_data["captain_motivation_name"] = motivation.name
		panel_data["captain_motivation_data"] = motivation
		
		# Update captain object if it exists
		if current_captain:
			current_captain.motivation = motivation.id

		print("CaptainPanel: Selected motivation: %s" % motivation.name)
		_update_motivation_description()
		panel_data_changed.emit(get_panel_data())

func _on_continue_pressed() -> void:
	print("CaptainPanel: Continue button pressed")
	_validate_and_complete()

func _on_advanced_creation_pressed() -> void:
	"""Enhanced advanced creation with comprehensive error handling and null safety"""
	print("CaptainPanel: Advanced creation button pressed")
	
	# Validate critical dependencies with specific error messaging
	if not character_creator:
		push_error("CaptainPanel: Character creator not initialized - cannot start advanced creation")
		_show_error_fallback("Character creator unavailable. Please try reloading the panel.")
		return
	
	# Use null-safe container reference with multiple fallback strategies
	var form_container = main_form_container
	if not form_container or not is_instance_valid(form_container):
		# Fallback 1: Try alternative node paths
		var fallback_paths = [
			"ContentMargin/MainContent/FormContent/FormContainer/Content",
			"Content",
			"FormContainer/Content"
		]
		
		for path in fallback_paths:
			form_container = get_node_or_null(path)
			if form_container and is_instance_valid(form_container):
				print("CaptainPanel: Found form container via fallback path: %s" % path)
				break
		
		# Fallback 2: Hide individual elements if no container found
		if not form_container:
			push_warning("CaptainPanel: No form container found - using individual element strategy")
			_hide_form_elements_individually()
		else:
			form_container.visible = false
	else:
		form_container.visible = false
	
	# Initialize character creator with validation and error recovery
	character_creator.visible = true
	print("CaptainPanel: Initializing character creator...")
	
	# Prepare captain data with validation
	var captain_data = null
	if current_captain and is_instance_valid(current_captain):
		if current_captain.has_method("to_dictionary"):
			captain_data = current_captain.to_dictionary()
			print("CaptainPanel: Passing existing captain data for editing")
		else:
			push_warning("CaptainPanel: Current captain exists but lacks serialization method")
	
	# Execute character creation with comprehensive error handling
	var creation_success = false
	
	# Use Godot's error handling pattern
	if character_creator.has_method("start_creation"):
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN)
		if captain_data:
			# Pass existing data for editing if available
			if character_creator.has_method("load_character_data"):
				character_creator.load_character_data(captain_data)
			elif character_creator.has_method("edit_character") and current_captain:
				character_creator.edit_character(current_captain)
		creation_success = true
		print("CaptainPanel: Advanced creation started successfully")
	else:
		push_error("CaptainPanel: Character creator missing start_creation method")
		creation_success = false
	
	# Handle creation failure with graceful recovery
	if not creation_success:
		_restore_simple_form()
		_show_error_fallback("Advanced creation failed. Falling back to simple form.")

func _hide_form_elements_individually() -> void:
	"""Fallback strategy: Hide form elements when container is unavailable"""
	var elements_to_hide = [
		captain_name_input,
		background_option,
		motivation_option,
		advanced_creation_button,
		continue_button
	]
	
	var hidden_count = 0
	for element in elements_to_hide:
		if element and is_instance_valid(element):
			element.visible = false
			hidden_count += 1
	
	print("CaptainPanel: Hidden %d form elements individually" % hidden_count)

func _restore_simple_form() -> void:
	"""Restore simple form with comprehensive error recovery"""
	print("CaptainPanel: Restoring simple form visibility")
	
	# Try to restore main container first
	var form_container = main_form_container
	if form_container and is_instance_valid(form_container):
		form_container.visible = true
	else:
		# Fallback: show individual elements
		print("CaptainPanel: Using individual element restoration")
		_show_form_elements_individually()
	
	# Safely hide character creator
	if character_creator and is_instance_valid(character_creator):
		character_creator.visible = false

func _show_form_elements_individually() -> void:
	"""Fallback strategy: Show form elements when container is unavailable"""
	var elements_to_show = [
		captain_name_input,
		background_option,
		motivation_option,
		advanced_creation_button,
		continue_button
	]
	
	var shown_count = 0
	for element in elements_to_show:
		if element and is_instance_valid(element):
			element.visible = true
			shown_count += 1
	
	print("CaptainPanel: Showed %d form elements individually" % shown_count)

func _show_error_fallback(message: String) -> void:
	"""Display error message with multiple notification strategies"""
	print("CaptainPanel: Error fallback - %s" % message)
	
	# Strategy 1: Use validation_failed signal if available
	if has_signal("validation_failed"):
		validation_failed.emit(["Advanced creation error: " + message])
	
	# Strategy 2: Use validation_failed signal if available (from base panel)
	if has_signal("validation_failed"):
		validation_failed.emit([message])
	
	# Strategy 3: Fallback to console warning
	push_warning("CaptainPanel: " + message)

func _on_character_created(character: Character) -> void:
	"""Handle character creation completion"""
	print("CaptainPanel: Character created: %s" % character.character_name)
	current_captain = character

	# Update panel data with character info
	panel_data["captain_character"] = character
	panel_data["captain_name"] = character.character_name

	# Extract captain stats for data handoff to coordinator/FinalPanel
	panel_data["captain_stats"] = _extract_character_stats(character)
	print("CaptainPanel: Extracted stats: %s" % str(panel_data["captain_stats"]))

	# Hide character creator and show simple form
	character_creator.visible = false
	main_form_container.visible = true

	# Update UI with character data
	_update_ui_from_character()

	# Emit data change
	panel_data_changed.emit(get_panel_data())

func _on_character_edited(character: Character) -> void:
	"""Handle character editing completion"""
	print("CaptainPanel: Character edited: %s" % character.character_name)
	current_captain = character

	# Update panel data
	panel_data["captain_character"] = character
	panel_data["captain_name"] = character.character_name

	# Extract captain stats for data handoff to coordinator/FinalPanel
	panel_data["captain_stats"] = _extract_character_stats(character)
	print("CaptainPanel: Extracted stats after edit: %s" % str(panel_data["captain_stats"]))

	# Hide character creator and show simple form
	character_creator.visible = false
	main_form_container.visible = true

	# Update UI with character data
	_update_ui_from_character()

	# Emit data change
	panel_data_changed.emit(get_panel_data())

func _on_character_creation_cancelled() -> void:
	"""Handle character creation cancellation"""
	print("CaptainPanel: Character creation cancelled")

	# Hide character creator and show simple form
	character_creator.visible = false
	main_form_container.visible = true

func _extract_character_stats(character: Character) -> Dictionary:
	"""Extract stats from Character object for data handoff to coordinator/FinalPanel.
	Uses Godot4Utils.safe_get_property for consistent null-safe property access."""
	if not character:
		return {}

	# Use Godot4Utils.safe_get_property for consistent, null-safe property access
	return {
		"combat": Godot4Utils.safe_get_property(character, "combat", 0),
		"reactions": Godot4Utils.safe_get_property(character, "reactions", 0),
		"toughness": Godot4Utils.safe_get_property(character, "toughness", 0),
		"savvy": Godot4Utils.safe_get_property(character, "savvy", 0),
		"speed": Godot4Utils.safe_get_property(character, "speed", 0),
		"luck": Godot4Utils.safe_get_property(character, "luck", 0),
		"experience": Godot4Utils.safe_get_property(character, "experience", 0)
	}

func _update_ui_from_character() -> void:
	"""Update UI elements with character data"""
	if not current_captain:
		return
	
	# Update name input
	if captain_name_input:
		captain_name_input.text = current_captain.character_name
	
	# Update background and motivation if available
	if current_captain.has_method("get_background"):
		var background = current_captain.get_background()
		var backgrounds = ["SOLDIER", "SCOUT", "SCOUNDREL", "SCHOLAR", "SCIENTIST", "STRANGE"]
		var index = backgrounds.find(background)
		if index >= 0 and background_option:
			background_option.select(index)
	
	if current_captain.has_method("get_motivation"):
		var motivation = current_captain.get_motivation()
		var motivations = ["REVENGE", "WEALTH", "KNOWLEDGE", "POWER", "SURVIVAL"]
		var index = motivations.find(motivation)
		if index >= 0 and motivation_option:
			motivation_option.select(index)

func _validate_and_complete() -> void:
	"""Validate captain data and complete step"""
	var errors = []
	
	# Check if we have a captain (either from simple form or character creator)
	if not current_captain and panel_data.get("captain_name", "").strip_edges().is_empty():
		errors.append("Captain name is required")
	
	# If we have a character creator captain, use that
	if current_captain:
		panel_data["captain_character"] = current_captain
		panel_data["captain_name"] = current_captain.character_name
		print("CaptainPanel: Using character creator captain")
	elif not panel_data.get("captain_name", "").strip_edges().is_empty():
		# Create a basic captain from form data
		_create_basic_captain()
		print("CaptainPanel: Created basic captain from form")
	
	if errors.is_empty():
		print("CaptainPanel: Captain validation passed")
		panel_completed.emit(get_panel_data())
	else:
		print("CaptainPanel: Captain validation failed: %s" % str(errors))
		# Could show errors in UI here

func _create_basic_captain() -> void:
	"""Create a basic captain from form data with Five Parsecs rules"""
	var Character = preload("res://src/core/character/Character.gd")
	current_captain = Character.new()
	
	# Set basic properties from form
	current_captain.character_name = panel_data.get("captain_name", "Captain")
	current_captain.background = panel_data.get("captain_background", "military_brat")
	current_captain.motivation = panel_data.get("captain_motivation", "revenge")
	
	# Generate base stats using Five Parsecs method (2d6/3 rounded up)
	current_captain.combat = _generate_five_parsecs_stat()
	current_captain.toughness = _generate_five_parsecs_stat()
	current_captain.savvy = _generate_five_parsecs_stat()
	current_captain.tech = _generate_five_parsecs_stat()
	current_captain.speed = _generate_five_parsecs_stat()
	current_captain.reactions = _generate_five_parsecs_stat()
	current_captain.luck = 2 # Captains start with 2 luck
	
	# Apply background bonuses
	_apply_background_bonuses(current_captain)
	
	# Apply motivation bonuses
	_apply_motivation_bonuses(current_captain)
	
	# Set health based on toughness (Five Parsecs rules)
	current_captain.max_health = current_captain.toughness + 3 # Captains get +1 extra
	current_captain.health = current_captain.max_health
	
	# Store captain data
	panel_data["captain_character"] = current_captain
	panel_data["captain_stats"] = {
		"combat": current_captain.combat,
		"toughness": current_captain.toughness,
		"savvy": current_captain.savvy,
		"tech": current_captain.tech,
		"speed": current_captain.speed,
		"reactions": current_captain.reactions,
		"luck": current_captain.luck,
		"health": current_captain.health,
		"max_health": current_captain.max_health
	}
	
	print("CaptainPanel: Created captain with stats: %s" % str(panel_data["captain_stats"]))

func _generate_five_parsecs_stat() -> int:
	"""Generate a stat using Five Parsecs method (2d6/3 rounded up)"""
	var roll = _roll_2d6()
	return ceili(float(roll) / 3.0)

func _apply_background_bonuses(character: Character) -> void:
	"""Apply background bonuses from Five Parsecs rules"""
	var background_data = panel_data.get("captain_background_data", {})
	var bonuses = background_data.get("bonus", {})
	
	for stat in bonuses:
		var bonus_value = bonuses[stat]
		match stat:
			"combat":
				character.combat += bonus_value
			"toughness":
				character.toughness += bonus_value
			"savvy":
				character.savvy += bonus_value
			"tech":
				character.tech += bonus_value
			"speed":
				character.speed += bonus_value
			"reactions":
				character.reactions += bonus_value
	
	print("CaptainPanel: Applied background bonuses: %s" % str(bonuses))

func _apply_motivation_bonuses(character: Character) -> void:
	"""Apply motivation bonuses from Five Parsecs rules"""
	var motivation_data = panel_data.get("captain_motivation_data", {})
	var bonuses = motivation_data.get("bonus", {})
	
	for stat in bonuses:
		var bonus_value = bonuses[stat]
		match stat:
			"combat":
				character.combat += bonus_value
			"toughness":
				character.toughness += bonus_value
			"savvy":
				character.savvy += bonus_value
			"tech":
				character.tech += bonus_value
			"speed":
				character.speed += bonus_value
			"reactions":
				character.reactions += bonus_value
	
	print("CaptainPanel: Applied motivation bonuses: %s" % str(bonuses))

func _roll_2d6() -> int:
	"""Roll 2d6 for Five Parsecs stats"""
	return randi_range(1, 6) + randi_range(1, 6)

func _update_ui_from_data() -> void:
	if captain_name_input and panel_data.has("captain_name"):
		captain_name_input.text = panel_data["captain_name"]
	
	if background_option and panel_data.has("captain_background"):
		var backgrounds = ["SOLDIER", "SCOUT", "SCOUNDREL", "SCHOLAR", "SCIENTIST", "STRANGE"]
		var index = backgrounds.find(panel_data["captain_background"])
		if index >= 0:
			background_option.select(index)
	
	if motivation_option and panel_data.has("captain_motivation"):
		var motivations = ["REVENGE", "WEALTH", "KNOWLEDGE", "POWER", "SURVIVAL"]
		var index = motivations.find(panel_data["captain_motivation"])
		if index >= 0:
			motivation_option.select(index)
	
	# Restore character if available
	if panel_data.has("captain_character") and panel_data["captain_character"]:
		current_captain = panel_data["captain_character"]
		_update_ui_from_character()

func cleanup_panel() -> void:
	"""Clean up panel state when navigating away"""
	print("CaptainPanel: Cleaning up panel state")
	
	# Clear character creator
	if character_creator:
		if character_creator.has_method("cleanup"):
			character_creator.cleanup()
		character_creator.visible = false
	
	# Reset panel data
	panel_data = {
		"captain_name": "",
		"captain_background": "",
		"captain_motivation": "",
		"captain_character": null,
		"captain_stats": {},
		"is_complete": false
	}
	
	# Clear current captain
	current_captain = null
	
	# Reset UI components if available
	if captain_name_input:
		captain_name_input.text = ""
	if background_option:
		background_option.select(0)
	if motivation_option:
		motivation_option.select(0)
	
	# Show simple form, hide character creator
	if main_form_container:
		main_form_container.visible = true
	if character_creator:
		character_creator.visible = false
	
	print("CaptainPanel: Panel cleanup completed")

# Enhanced Captain Generation Methods - Production Ready
func _generate_random_captain() -> void:
	"""Generate random captain with Five Parsecs rules and captain bonuses"""
	creation_method = "random"

	# Clear previous roll log
	_clear_roll_log()

	captain = Character.new()

	# Five Parsecs captain generation (enhanced stats)
	captain.character_name = _generate_captain_name()

	# Roll stats with logging
	captain.combat = _roll_captain_stat_with_bonus("Combat", 1)
	captain.reactions = _roll_captain_stat_with_bonus("Reactions", 1)
	captain.toughness = _roll_captain_stat_logged("Toughness")
	captain.savvy = _roll_captain_stat_with_bonus("Savvy", 1)
	captain.tech = _roll_captain_stat_logged("Tech")
	captain.speed = 4 # Standard movement
	captain.luck = 2 # Captain gets extra luck
	
	# Set captain-specific properties
	captain.is_captain = true
	captain.experience = captain_bonuses.experience
	
	# Generate background and motivation using existing system
	_apply_background_and_motivation()
	
	# Update display
	_update_captain_display()
	
	# COMPREHENSIVE DEBUG OUTPUT - Captain Data Creation
	print("\n==== [PANEL: CaptainPanel] CAPTAIN DATA CREATED ====")
	print("  Panel Phase: 2 of 7 (Captain Creation)")
	print("  Creation Method: %s" % creation_method)
	print("  === CAPTAIN DATA BEING SAVED ===")
	print("    Captain Name: '%s'" % captain.character_name)
	print("    Stats: Combat:%d Reactions:%d Toughness:%d Savvy:%d Tech:%d Speed:%d" % [
		captain.combat, captain.reactions, captain.toughness, captain.savvy, captain.tech, captain.speed
	])
	print("    Experience: %d XP" % captain.experience)
	print("    Background: '%s'" % captain.background)
	print("    Motivation: '%s'" % captain.motivation)
	print("    Is Captain: %s" % captain.is_captain)
	print("    Captain Bonuses: %s" % captain_bonuses)
	
	var panel_data_result = get_panel_data()
	print("  === FORMATTED PANEL DATA ===")
	print("    Panel Data Keys: %s" % str(panel_data_result.keys()))
	print("    Is Complete: %s" % panel_data_result.get("is_complete", false))
	print("    Validation Status: %s" % validate_panel())
	
	# Emit both data changed and captain created signals
	panel_data_changed.emit(panel_data_result)
	captain_created.emit(panel_data_result)
	captain_data_updated.emit(panel_data_result)
	
	print("  === SIGNAL EMISSIONS ===")
	print("    panel_data_changed signal emitted")
	print("    captain_created signal emitted")
	print("    captain_data_updated signal emitted")
	print("==== [PANEL: CaptainPanel] CAPTAIN CREATION COMPLETE ====\n")
	
	print("CaptainPanel: Random captain generated - %s" % captain.character_name)

func _use_veteran_template() -> void:
	"""Apply veteran captain template with superior stats"""
	creation_method = "veteran"
	
	captain = Character.new()
	captain.character_name = _generate_captain_name()
	
	# Veteran stats (higher baseline for experienced captains)
	captain.combat = 4
	captain.reactions = 4
	captain.toughness = 3
	captain.savvy = 5 # High savvy for leadership
	captain.tech = 3
	captain.speed = 4
	captain.luck = 3 # Higher luck from experience
	
	# Veteran bonuses
	captain.is_captain = true
	captain.experience = 250 # More starting XP
	# Note: skills stored in panel_data, not Character resource
	
	_update_captain_display()
	
	# Emit both data changed and captain created signals
	panel_data_changed.emit(get_panel_data())
	captain_created.emit(get_panel_data())
	captain_data_updated.emit(get_panel_data())
	
	print("CaptainPanel: Veteran captain created - %s" % captain.character_name)

func _create_custom_captain() -> void:
	"""Open custom captain builder interface - delegates to advanced creation flow"""
	creation_method = "custom"
	# Use the same flow as the Advanced Creation button
	_on_advanced_creation_pressed()

# NOTE: _import_character() removed in Sprint 26.7 - was dead-end (never implemented)

func _roll_captain_stat() -> int:
	"""Roll captain stat using Five Parsecs rules (2d6/3)"""
	randomize()
	var roll = randi_range(2, 12) # 2d6
	return max(1, int(ceil(float(roll) / 3.0)))

func _roll_captain_stat_logged(stat_name: String) -> int:
	"""Roll captain stat with logging for verbose mode"""
	randomize()
	var roll = randi_range(2, 12) # 2d6
	var result = max(1, int(ceil(float(roll) / 3.0)))
	_log_dice_roll(stat_name, roll, result)
	return result

func _roll_captain_stat_with_bonus(stat_name: String, bonus: int) -> int:
	"""Roll captain stat with bonus and logging for verbose mode"""
	randomize()
	var roll = randi_range(2, 12) # 2d6
	var base_result = max(1, int(ceil(float(roll) / 3.0)))
	var final_result = base_result + bonus
	var log_entry = "[color=#aaccaa]%s:[/color] Rolled %d → Base: %d + %d bonus = [b]%d[/b]" % [stat_name, roll, base_result, bonus, final_result]
	_roll_log.append(log_entry)
	if _verbose_mode:
		_update_roll_log_display()
	return final_result

func _generate_captain_name() -> String:
	"""Generate appropriate captain name"""
	var first_names = [
		"Marcus", "Sarah", "Chen", "Alexei", "Zara", "Diego", "Naomi", "Viktor",
		"Elena", "Kai", "Juno", "Rex", "Nova", "Phoenix", "Orion", "Vega"
	]
	var last_names = [
		"Steele", "Vega", "Cross", "Raven", "Storm", "Hunter", "Wolf", "Hawk",
		"Kane", "Stone", "Drake", "Frost", "Vale", "Quinn", "Sharp", "Black"
	]
	
	randomize()
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _update_captain_display() -> void:
	"""Update captain preview display with glass morphism and stat badges"""
	if not captain or not captain_display_container:
		return

	# Clear previous display
	for child in captain_display_container.get_children():
		child.queue_free()

	# === GLASS CARD WRAPPER ===
	var captain_card := PanelContainer.new()
	captain_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	captain_card.add_theme_stylebox_override("panel", _create_glass_card_elevated())
	captain_display_container.add_child(captain_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", SPACING_MD)
	captain_card.add_child(card_vbox)

	# === CAPTAIN HEADER (Portrait + Name) ===
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", SPACING_MD)
	card_vbox.add_child(header_hbox)

	# Portrait frame with glass background
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(80, 80)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = COLOR_INPUT
	portrait_style.border_color = COLOR_ACCENT
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(8)
	portrait_style.set_content_margin_all(SPACING_SM)
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	header_hbox.add_child(portrait_frame)

	# Portrait placeholder (future: character portrait)
	var portrait_label := Label.new()
	portrait_label.text = "👤"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_size_override("font_size", 48)
	portrait_frame.add_child(portrait_label)

	# Captain info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", SPACING_XS)
	header_hbox.add_child(info_vbox)

	# Name
	var name_label := Label.new()
	name_label.text = "Captain %s" % captain.character_name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	name_label.add_theme_color_override("font_color", COLOR_ACCENT)
	info_vbox.add_child(name_label)

	# Creation method badge
	var method_badge := PanelContainer.new()
	var method_style := StyleBoxFlat.new()
	method_style.bg_color = Color(COLOR_ACCENT, 0.2)
	method_style.border_color = COLOR_ACCENT
	method_style.set_border_width_all(1)
	method_style.set_corner_radius_all(4)
	method_style.set_content_margin_all(SPACING_XS)
	method_badge.add_theme_stylebox_override("panel", method_style)
	var method_label := Label.new()
	method_label.text = "Created via: %s" % creation_method.capitalize()
	method_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	method_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	method_badge.add_child(method_label)
	info_vbox.add_child(method_badge)

	# === STATS SECTION (Using Stat Badges) ===
	var stats_label := Label.new()
	stats_label.text = "STATS"
	stats_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	stats_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	card_vbox.add_child(stats_label)

	var stats_grid := GridContainer.new()
	stats_grid.columns = get_optimal_column_count() + 1  # Adaptive columns
	stats_grid.add_theme_constant_override("h_separation", SPACING_SM)
	stats_grid.add_theme_constant_override("v_separation", SPACING_SM)
	card_vbox.add_child(stats_grid)

	# Create stat badges with color coding
	var stats := {
		"Combat": captain.combat,
		"Reactions": captain.reactions,
		"Toughness": captain.toughness,
		"Savvy": captain.savvy,
		"Tech": captain.tech,
		"Speed": captain.speed,
		"Luck": captain.luck
	}

	for stat_name in stats:
		var badge := _create_stat_badge(stat_name, stats[stat_name])
		stats_grid.add_child(badge)

	# === EXPERIENCE SECTION (If bonus XP) ===
	if captain.experience > 100:
		var xp_section := HBoxContainer.new()
		xp_section.add_theme_constant_override("separation", SPACING_SM)
		card_vbox.add_child(xp_section)

		var xp_icon := Label.new()
		xp_icon.text = "⭐"
		xp_icon.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		xp_section.add_child(xp_icon)

		var xp_label := Label.new()
		xp_label.text = "Experience: %d XP" % captain.experience
		xp_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		xp_label.add_theme_color_override("font_color", COLOR_PURPLE)
		xp_section.add_child(xp_label)

func _apply_background_and_motivation() -> void:
	"""Apply Five Parsecs background and motivation using existing data"""
	if not captain:
		return
	
	var backgrounds = [
		"Mining Colony", "High-Tech Colony", "Military Family", "Merchant Family",
		"Space Station", "Frontier World", "Corporate Sector", "Academic Institution"
	]
	
	randomize()
	captain.background = backgrounds[randi() % backgrounds.size()]

# Event handlers for advanced options
func _on_leadership_toggled(enabled: bool) -> void:
	"""Handle leadership bonus toggle"""
	captain_bonuses.leadership = 1 if enabled else 0
	if captain:
		_update_captain_display()

func _on_xp_changed(value: float) -> void:
	"""Handle experience change"""
	captain_bonuses.experience = int(value)
	if captain:
		captain.experience = int(value)
		_update_captain_display()

# Panel validation and data methods (FiveParsecsCampaignPanel interface)
func validate_panel() -> bool:
	"""Validate captain creation (overrides base class)"""
	# Accept either a created captain OR filled form data
	if current_captain and not current_captain.character_name.is_empty():
		print("CaptainPanel: Validation passed for captain: %s" % current_captain.character_name)
		return true
	
	# Check form data as fallback
	if panel_data.has("captain_name") and not panel_data["captain_name"].strip_edges().is_empty():
		print("CaptainPanel: Validation passed for form data with name: %s" % panel_data["captain_name"])
		return true
	
	print("CaptainPanel: Validation failed - no captain name provided")
	return false

func get_panel_data() -> Dictionary:
	"""Get captain data for campaign (overrides base class)"""
	if not current_captain:
		var input_name = captain_name_input.text if captain_name_input else ""
		return {
			"is_complete": false,
			"name": input_name,  # COMPATIBILITY: FinalPanel looks for 'name' first
			"character_name": input_name,
			"captain_character": null
		}

	return {
		"captain": {
			"id": current_captain.character_id,  # SPRINT 5.2: Include captain ID for crew matching
			"character_id": current_captain.character_id,  # COMPATIBILITY: Both id forms
			"name": current_captain.character_name,  # COMPATIBILITY: Both keys for different consumers
			"character_name": current_captain.character_name,
			"combat": current_captain.combat,
			"reactions": current_captain.reactions,
			"toughness": current_captain.toughness,
			"savvy": current_captain.savvy,
			"tech": current_captain.tech,
			"speed": current_captain.speed,
			"experience": current_captain.experience,
			"background": current_captain.background,
			"motivation": current_captain.motivation,
			"is_captain": true,
			"creation_method": creation_method if creation_method else "manual",
			"bonuses": captain_bonuses
		},
		"name": current_captain.character_name,  # COMPATIBILITY: Some consumers expect 'name'
		"character_name": current_captain.character_name,
		"captain_character": current_captain,
		"is_complete": validate_panel()
	}

func set_panel_data(data: Dictionary) -> void:
	"""Set captain data from campaign state (overrides base class)"""
	if data.has("captain") and data.captain is Dictionary:
		var captain_data = data.captain
		# Load existing captain data if available
		if captain_data.has("character_name") and not captain_data.character_name.is_empty():
			captain = Character.new()
			captain.character_name = captain_data.get("character_name", "")
			captain.combat = captain_data.get("combat", 1)
			captain.reactions = captain_data.get("reactions", 1)
			captain.toughness = captain_data.get("toughness", 1)
			captain.savvy = captain_data.get("savvy", 1)
			captain.tech = captain_data.get("tech", 1)
			captain.speed = captain_data.get("speed", 4)
			captain.luck = captain_data.get("luck", 1)
			captain.experience = captain_data.get("experience", 100)
			captain.background = captain_data.get("background", "")
			captain.is_captain = true
			creation_method = captain_data.get("creation_method", "loaded")
			captain_bonuses = captain_data.get("bonuses", captain_bonuses)
			
			_update_captain_display()

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: CaptainPanel] INITIALIZATION ====")
	print("  Phase: 2 of 7 (Captain Creation)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# PHASE 4 FIX: Defer coordinator check until coordinator is actually set
	print("  Coordinator Access: [Will check after coordinator is set]")
	
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
	
	# Check current captain data
	print("  === INITIAL CAPTAIN DATA ===")
	print("    Current Captain: %s" % (current_captain != null))
	if current_captain:
		print("      Captain Name: '%s'" % current_captain.character_name)
		print("      Captain Stats: C:%d R:%d T:%d S:%d T:%d Spd:%d" % [
			current_captain.combat, current_captain.reactions, current_captain.toughness,
			current_captain.savvy, current_captain.tech, current_captain.speed
		])
	print("    Panel Data Keys: %s" % str(panel_data.keys()))
	print("    Creation Method: '%s'" % creation_method)
	print("    Captain Bonuses: %s" % captain_bonuses)
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Captain Name Input: %s" % (captain_name_input != null))
	print("    Background Option: %s" % (background_option != null))
	print("    Motivation Option: %s" % (motivation_option != null))
	print("    Advanced Creation Button: %s" % (advanced_creation_button != null))
	print("    Continue Button: %s" % (continue_button != null))
	print("    Character Creator: %s" % (character_creator != null))
	
	print("==== [PANEL: CaptainPanel] INIT COMPLETE ====\n")

# ============ SIGNAL BRIDGE COMPATIBILITY ============
# CRITICAL FIX: Add missing _on_campaign_state_updated method for signal bridge

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Handle campaign state updates from coordinator - CRITICAL for signal bridge"""
	print("CaptainPanel: Received campaign state update with keys: %s" % str(state_data.keys()))

	# CRITICAL FIX: Ignore updates that originated from this panel to prevent double-loading
	# This prevents the panel from overwriting user input with its own data
	var source = state_data.get("source", "")
	if source == "captain_panel":
		print("CaptainPanel: Ignoring update from self (source: captain_panel)")
		return

	# Also ignore if this is a captain_update phase - we're the source
	var phase = state_data.get("phase", "")
	if phase == "captain_update":
		print("CaptainPanel: Ignoring captain_update phase (self-update)")
		return

	# Handle captain phase specific data if available - but only if we don't have data yet
	var captain_data = state_data.get("captain", {})
	if captain_data.has("character_name") or captain_data.has("name"):
		# Only sync if we don't already have captain data (initial load)
		var current_name = captain_name_input.text if captain_name_input else ""
		if current_name.is_empty():
			print("CaptainPanel: Captain data found in state - syncing (no existing data)...")
			_sync_with_state_data(captain_data)
		else:
			print("CaptainPanel: Skipping sync - user has already entered data")

	# Handle config data that might affect captain creation
	var config_data = state_data.get("config", {})
	if config_data.size() > 0:
		print("CaptainPanel: Config data found - checking for captain-relevant settings...")
		# Could be used for difficulty settings, custom rules, etc.

func _sync_with_state_data(captain_data: Dictionary) -> void:
	"""Sync captain panel with campaign state data"""
	if captain_data.has("character_name") and captain_name_input:
		captain_name_input.text = captain_data.get("character_name", "")
		print("CaptainPanel: Synced captain name from state")
	
	if captain_data.has("background") and background_option:
		var background = captain_data.get("background", "")
		# Set background option if it exists
		print("CaptainPanel: Background data available: %s" % background)
	
	if captain_data.has("motivation") and motivation_option:
		var motivation = captain_data.get("motivation", "")
		print("CaptainPanel: Motivation data available: %s" % motivation)

func _refresh_panel_state() -> void:
	"""Refresh the panel state after receiving updates"""
	if is_inside_tree():
		validate_panel()
		print("CaptainPanel: State refreshed after campaign update")

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	"""Mobile: Single column, 56dp targets, compact roll log"""
	super._apply_mobile_layout()

	# Increase touch targets to TOUCH_TARGET_COMFORT (56dp)
	if captain_name_input:
		captain_name_input.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if background_option:
		background_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if motivation_option:
		motivation_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if advanced_creation_button:
		advanced_creation_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if continue_button:
		continue_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT

	# Compact roll log for mobile
	if roll_log_display:
		roll_log_display.custom_minimum_size.y = 80

func _apply_tablet_layout() -> void:
	"""Tablet: Two columns, 48dp targets, detailed roll log"""
	super._apply_tablet_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if captain_name_input:
		captain_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN
	if background_option:
		background_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if motivation_option:
		motivation_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if advanced_creation_button:
		advanced_creation_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if continue_button:
		continue_button.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Detailed roll log for tablet
	if roll_log_display:
		roll_log_display.custom_minimum_size.y = 120

func _apply_desktop_layout() -> void:
	"""Desktop: Multi-column, 48dp targets, full roll log"""
	super._apply_desktop_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if captain_name_input:
		captain_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN
	if background_option:
		background_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if motivation_option:
		motivation_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if advanced_creation_button:
		advanced_creation_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if continue_button:
		continue_button.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Full roll log for desktop
	if roll_log_display:
		roll_log_display.custom_minimum_size.y = 150
