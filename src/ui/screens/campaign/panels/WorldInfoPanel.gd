@tool
extends FiveParsecsCampaignPanel

## World Information Panel - the starting world: its name and World Trait (Core Rules p.72)
## Integrates with enhanced data manager following Digital Dice System visual patterns
## Provides comprehensive world information with contextual data display

# Progress tracking
const STEP_NUMBER := 6  # Step 6 of 7 in campaign wizard

# Signals for CampaignCreationUI integration
signal world_generated(world_data: Dictionary)
signal world_updated(world_data: Dictionary)
signal world_created(world_data: Dictionary)

# Dependencies - all files exist and are required
const UIColors = preload("res://src/ui/components/base/UIColors.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
const DataValidator = preload("res://src/core/utils/DataValidator.gd")

# UI References
@onready var world_name_label: Label = %WorldNameLabel
@onready var world_traits_container: VBoxContainer = %WorldTraitsContainer
@onready var world_summary: Label = %WorldSummary

# World generation system
const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")
var world_generator = null  # WorldGenerator instance

# Data management
var current_world_data: Dictionary = {}

# State flags
var is_world_data_updated: bool = false
var is_world_generated: bool = false   # Track if world has been generated
var is_world_confirmed: bool = false   # Track if user confirmed the world

# UI Control buttons
var generate_button: Button = null
var reroll_button: Button = null
var confirm_button: Button = null

# Coordinator integration (consistent with other panels)
var coordinator: Node = null

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("World Generation", "Roll your starting world. Its World Trait changes how the campaign plays there (Core Rules p.72).")

	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display

	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")

	# Initialize world generation system
	_initialize_world_generator()

	# Initialize world panel-specific functionality
	_setup_world_panel()

	# Defer button setup to ensure scene is fully loaded
	call_deferred("_setup_control_buttons")

	# Apply design system styling after buttons are created
	call_deferred("_apply_input_styling")

	# SPRINT 5.1: Emit panel_ready after initialization complete
	call_deferred("emit_panel_ready")

	# Debug verification of button creation
	call_deferred("_verify_button_creation")

	_apply_mobile_layout()

	# BUG-018/019/020/023: Auto-generate and confirm world on panel entry
	# so Next is immediately available. User can still reroll for a different world.
	call_deferred("_auto_generate_if_needed")

func _verify_button_creation() -> void:
	## Verify buttons were created and added correctly
	if not reroll_button or not confirm_button:
		push_warning("WorldInfoPanel: One or more control buttons failed to create")

func _apply_input_styling() -> void:
	## Apply design system styling to programmatically-created buttons (eliminates stretched teal bars)
	# Style Buttons with touch-friendly sizing and consistent appearance
	if generate_button:
		_style_button(generate_button)
	if reroll_button:
		_style_button(reroll_button)
	if confirm_button:
		_style_button(confirm_button)
		confirm_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)


# NOTE: _style_button() now inherited from BaseCampaignPanel - removed duplicate

# NOTE: _add_progress_indicator() removed - CampaignCreationUI handles progress display centrally

func _initialize_world_generator() -> void:
	## Initialize WorldGenerator with defensive error handling
	if not WorldGenerator:
		push_error("WorldInfoPanel: WorldGenerator preload failed")
		return
	
	if is_instance_valid(world_generator):
		world_generator.free()
	world_generator = WorldGenerator.new()
	if not world_generator:
		push_error("WorldInfoPanel: Failed to create WorldGenerator instance")
		return

	# NOTE: Do NOT connect world_generated signal here. WorldGenerator.generate_world()
	# emits it before the world is given its Compendium name. _generate_world() calls
	# _on_world_generated_from_generator() directly, AFTER naming it.
	# Connecting the signal caused a double-call bug where the first display showed
	# incomplete data (BUG-018/021).

## WorldGenerator extends Node and is never added to the tree, so nothing frees it
## with the panel: one Node leaked per visit to creation step 6. PREDELETE, not
## _exit_tree(), so a panel the wizard detaches and re-attaches keeps its generator.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(world_generator):
		world_generator.free()
		world_generator = null

func _setup_world_panel() -> void:
	# Initialize world display components
	if not world_name_label:
		push_warning("WorldInfoPanel: World name label not found")
		return
	
	

func _setup_control_buttons() -> void:
	## Create and setup control buttons for world generation
	
	# Find the Content container where we should add buttons
	var content_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content_container:
		# Fallback: try to find any Content node
		content_container = find_child("Content", true, false)
	
	if not content_container:
		push_error("WorldInfoPanel: Cannot find Content container for buttons")
		return
	
	# Add a separator before buttons
	var separator = HSeparator.new()
	content_container.add_child(separator)

	# Create button container
	# HFlow so Reroll + Confirm wrap to a second row in portrait (2x150 + gap > 321). r26
	var button_container = HFlowContainer.new()
	button_container.name = "WorldControlButtons"
	button_container.alignment = FlowContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("h_separation", SPACING_LG)
	button_container.add_theme_constant_override("v_separation", SPACING_SM)
	
	# Single Reroll button — auto-generation handles initial world creation,
	# so only a re-roll action is needed (removes redundant "Re-generate World" button)
	reroll_button = Button.new()
	reroll_button.text = "Reroll World"
	reroll_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_button.disabled = true
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	_style_button(reroll_button, false)
	button_container.add_child(reroll_button)

	# Create Confirm button (initially disabled)
	confirm_button = Button.new()
	confirm_button.text = "Confirm World"
	confirm_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	_style_button(confirm_button, true)
	button_container.add_child(confirm_button)
	
	# Add button container to the Content VBoxContainer
	content_container.add_child(button_container)
	
	# Move to bottom of content if possible
	content_container.move_child(button_container, content_container.get_child_count() - 1)
	

func _auto_generate_if_needed() -> void:
	## BUG-018/019/020/023: Auto-generate world on panel entry if none exists.
	## Eliminates the dead-end where panel is blank and Next is hidden.
	if not is_world_generated:
		_on_generate_button_pressed()
		# Also auto-confirm so Next is enabled immediately
		_on_confirm_button_pressed()

	# Enable reroll for users who want a different world
	if reroll_button:
		reroll_button.disabled = false

	# Direct coordinator notification as fallback (signals may debounce)
	if coordinator and coordinator.has_method("mark_phase_complete"):
		coordinator.mark_phase_complete(5, true)  # 5 = WORLD_GENERATION

func _on_generate_button_pressed() -> void:
	## Handle generate world button press
	
	# Generate a new world
	var campaign_name = _get_campaign_name_safe()
	_generate_world(campaign_name + " Prime")
	
	# Enable reroll and confirm buttons
	if reroll_button:
		reroll_button.disabled = false
	if confirm_button:
		confirm_button.disabled = false
	
	# Disable generate button after first generation
	if generate_button:
		generate_button.disabled = true
	
	# Mark world as generated but not confirmed
	is_world_generated = true
	is_world_confirmed = false
	
	# Update validation
	_update_validation_state()

func _on_reroll_button_pressed() -> void:
	## Handle reroll world button press

	# Generate a new world with different seed
	var campaign_name = _get_campaign_name_safe()
	var world_suffix = ["Alpha", "Beta", "Gamma", "Delta", "Prime", "Nova", "Echo", "Zeta"].pick_random()
	_generate_world(campaign_name + " " + world_suffix)

	# Reset confirm state — user needs to re-confirm the new world
	is_world_generated = true
	is_world_confirmed = false
	if confirm_button:
		confirm_button.text = "Confirm World"
		confirm_button.disabled = false

	# Update validation
	_update_validation_state()

func _on_confirm_button_pressed() -> void:
	## Handle confirm world button press
	
	# Mark world as confirmed
	is_world_confirmed = true
	
	# Disable reroll button
	if reroll_button:
		reroll_button.disabled = true
	
	# Update confirm button text
	if confirm_button:
		confirm_button.text = "✓ World Confirmed"
		confirm_button.disabled = true
	
	# Update validation and emit completion
	_update_validation_state()

	# Emit panel completed signal
	if is_world_confirmed and not current_world_data.is_empty():
		panel_completed.emit(get_panel_data())

	# Emit world_created signal for CampaignCreationUI
	world_created.emit(current_world_data)

func _get_campaign_name_safe() -> String:
	## Safely get campaign name from coordinator or use default
	if coordinator and coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		var campaign_config = state.get("campaign_config", {})
		var name = campaign_config.get("campaign_name", "")
		# Return default if name is empty or only whitespace
		if name.strip_edges().is_empty():
			return "New Campaign"
		return name.strip_edges()
	return "New Campaign"

func _update_validation_state() -> void:
	## Update validation state and emit signals
	var is_valid = validate_panel()
	panel_validation_changed.emit(is_valid)
	
	if is_valid:
		# Mark world data as complete
		current_world_data["is_complete"] = true
		
		# Update coordinator with world data
		if coordinator and coordinator.has_method("update_world_state"):
			coordinator.update_world_state(current_world_data)
	

func _apply_mobile_layout() -> void:
	## Mobile-specific layout: Single column, large touch targets, compact info
	# Override from BaseCampaignPanel
	if world_traits_container:
		world_traits_container.custom_minimum_size.y = 80  # Compact on mobile
		world_traits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if world_summary:
		world_summary.text = _world_summary_text()

	# Update control buttons for mobile (comfortable touch targets)
	if generate_button:
		generate_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if reroll_button:
		reroll_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if confirm_button:
		confirm_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT


func _apply_tablet_layout() -> void:
	## Tablet-specific layout: Two-column where appropriate
	# Override from BaseCampaignPanel
	if world_traits_container:
		world_traits_container.custom_minimum_size.y = 100  # Medium on tablet
		world_traits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if world_summary:
		world_summary.text = _world_summary_text()

	# Standard touch targets for tablet
	if generate_button:
		generate_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if reroll_button:
		reroll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if confirm_button:
		confirm_button.custom_minimum_size.y = TOUCH_TARGET_MIN


func _apply_desktop_layout() -> void:
	## Desktop-specific layout: Full data visibility, multi-column
	# Override from BaseCampaignPanel
	if world_traits_container:
		world_traits_container.custom_minimum_size.y = 150  # Generous on desktop
		world_traits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if world_summary:
		world_summary.text = _world_summary_text()

	# Minimum touch targets for desktop (mouse precision)
	if generate_button:
		generate_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if reroll_button:
		reroll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if confirm_button:
		confirm_button.custom_minimum_size.y = TOUCH_TARGET_MIN


## Main world display update function
func update_world_display(world_name: String) -> void:
	## Generate and display world data using WorldGenerator with fallback templates
	
	# Generate world if not already generated
	if current_world_data.is_empty():
		_generate_world(world_name)
	else:
		_display_world_data(current_world_data)

func _generate_world(world_name: String) -> void:
	## Roll the starting world through WorldGenerator (Core Rules p.72). There is no
	## template fallback any more: the three WORLD_TEMPLATES were invented worlds
	## carrying invented traits ("trade_center", "pirate_haven"), so a failed roll
	## now says so instead of handing the player a fabricated world.
	if not world_generator:
		_initialize_world_generator()
	var world_data: Dictionary = {}
	if world_generator:
		world_data = world_generator.generate_world(_get_campaign_turn_safe())
	if world_data.is_empty():
		push_error("WorldInfoPanel: WorldGenerator returned no world")
		return
	# Generate world name from Compendium name tables (pp.157-162)
	var generated_name: String = _generate_canonical_world_name(world_data.get("type", ""))
	if not generated_name.is_empty():
		world_data["name"] = generated_name
	elif not world_name.is_empty():
		world_data["name"] = world_name
	else:
		world_data["name"] = world_data.get("name", "New World")
	_on_world_generated_from_generator(world_data)

func _display_world_data(world_data: Dictionary) -> void:
	## A world is its name and its World Trait (Core Rules p.72). Government, tech
	## level, market prices, opportunities and threats were shown here until
	## 2026-10-29. None is in either book, and the last three could only ever print
	## a placeholder ("No known threats in this sector", even for a crew that rolled
	## a Rival at creation) because nothing produced them.
	var safe_name = DataValidator.safe_get_string(
		world_data, "name", "Unknown World")
	var safe_traits = DataValidator.safe_get_array(
		world_data, "traits", [])

	# Display world name
	if world_name_label:
		world_name_label.text = "Current World: " + safe_name
		world_name_label.add_theme_font_size_override(
			"font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_XL))
		world_name_label.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_PRIMARY)

	# Wrap section containers in cards (once)
	_ensure_section_cards()

	_display_world_traits(safe_traits)
	_update_world_summary()

## Wrap each section container in a styled card, if not done.
func _ensure_section_cards() -> void:
	# Remove bare HSeparators (replaced by card borders)
	_remove_separators()
	_wrap_in_card(world_traits_container, "WORLD TRAITS")
	# Hide redundant summary label (card content replaces it)
	if world_summary:
		world_summary.visible = false
	# Reparent card panels into HFlowContainer for responsive columns
	_ensure_flow_layout()

func _remove_separators() -> void:
	## Remove bare HSeparators from Content (replaced by card styling)
	var content = get_node_or_null(
		"ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content:
		return
	var to_remove: Array[Node] = []
	for child in content.get_children():
		if child is HSeparator:
			to_remove.append(child)
	for sep in to_remove:
		sep.queue_free()

func _ensure_flow_layout() -> void:
	## Reparent __card_ panels into HFlowContainer for responsive columns
	var content = get_node_or_null(
		"ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content:
		return
	# Skip if already done
	if content.get_node_or_null("CardFlow"):
		return
	var flow := HFlowContainer.new()
	flow.name = "CardFlow"
	flow.add_theme_constant_override("h_separation", SPACING_LG)
	flow.add_theme_constant_override("v_separation", SPACING_LG)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Collect card panels (named __card_*)
	var cards_to_move: Array[Control] = []
	for child in content.get_children():
		if child.name.begins_with("__card_"):
			cards_to_move.append(child)
	# Reparent cards into flow
	for card in cards_to_move:
		content.remove_child(card)
		# Portrait: shrink cards to a single full-width column instead of forcing
		# 450px (a card wider than the container suppresses HFlow wrapping). (r11)
		card.custom_minimum_size.x = 0 if should_use_single_column() else 450
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_child(card)
	content.add_child(flow)

func _wrap_in_card(
	container: Control, title: String
) -> void:
	if not container:
		return
	# Skip if already wrapped — walk up ancestors looking for __card_ wrapper
	var ancestor: Node = container.get_parent()
	while ancestor:
		if ancestor.name.begins_with("__card_"):
			return
		ancestor = ancestor.get_parent()
	var card_inner := VBoxContainer.new()
	card_inner.add_theme_constant_override("separation", 4)
	# Title label
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override(
		"font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_LG))
	title_lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY)
	card_inner.add_child(title_lbl)
	var sep := HSeparator.new()
	sep.modulate = UIColors.COLOR_BORDER
	card_inner.add_child(sep)
	# Reparent the container into the card
	var orig_parent = container.get_parent()
	var idx = container.get_index()
	_reparent(container, orig_parent, card_inner)
	# Wrap in PanelContainer
	var panel := PanelContainer.new()
	panel.name = "__card_%s" % title.to_lower().replace(
		" ", "_")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		UIColors.COLOR_SECONDARY.r,
		UIColors.COLOR_SECONDARY.g,
		UIColors.COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(
		UIColors.COLOR_BORDER.r,
		UIColors.COLOR_BORDER.g,
		UIColors.COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(UIColors.SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(card_inner)
	orig_parent.add_child(panel)
	orig_parent.move_child(panel, idx)
	

func _display_world_traits(world_features: Array) -> void:
	if not world_traits_container:
		return
	
	# Clear existing world features
	var children = world_traits_container.get_children()
	for i in range(children.size()):
		children[i].queue_free()
	
	# Add world trait displays with enhanced information
	for i in range(world_features.size()):
		var feature_data = world_features[i]
		
		# Feature can be either a Dictionary (new format) or String (legacy format)
		if feature_data is Dictionary:
			_create_trait_card(feature_data)
		elif feature_data is String:
			# Legacy format - convert snake_case ID to Title Case display name
			var feature_label = Label.new()
			feature_label.text = "• %s" % feature_data.replace("_", " ").capitalize()
			feature_label.add_theme_color_override("font_color", UIColors.INFO_COLOR)
			world_traits_container.add_child(feature_label)

func _create_trait_card(trait_data: Dictionary) -> void:
	## Create an enhanced trait card showing name, description, and mechanical effect
	# Container for the entire trait card
	var card_container = PanelContainer.new()
	card_container.add_theme_stylebox_override("panel", _create_trait_card_style(trait_data.get("category", "social")))
	
	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", SPACING_MD)
	card_margin.add_theme_constant_override("margin_right", SPACING_MD)
	card_margin.add_theme_constant_override("margin_top", SPACING_SM)
	card_margin.add_theme_constant_override("margin_bottom", SPACING_SM)
	card_container.add_child(card_margin)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", SPACING_XS)
	card_margin.add_child(card_vbox)
	
	# Trait name with category badge
	var name_hbox = HBoxContainer.new()
	card_vbox.add_child(name_hbox)
	
	var name_label = Label.new()
	name_label.text = trait_data.get("name", "Unknown Trait")
	name_label.add_theme_font_size_override("font_size", get_responsive_font_size(14))
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	name_hbox.add_child(name_label)
	
	# Category badge
	var category_label = Label.new()
	var category = str(trait_data.get("category", "social"))
	category_label.text = "[%s]" % category.capitalize()
	category_label.add_theme_font_size_override("font_size", get_responsive_font_size(11))
	category_label.add_theme_color_override("font_color", _get_category_color(category))
	name_hbox.add_child(category_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = trait_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", get_responsive_font_size(12))
	desc_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(desc_label)
	
	# Mechanical effect (highlighted)
	var effect_label = Label.new()
	effect_label.text = "⚙ %s" % trait_data.get("mechanical_effect", "No mechanical effect")
	effect_label.add_theme_font_size_override("font_size", get_responsive_font_size(11))
	effect_label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(effect_label)
	
	world_traits_container.add_child(card_container)

func _create_trait_card_style(category: String) -> StyleBoxFlat:
	## Create a styled box for trait cards with category-specific accent
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_width_left = 3
	style.border_color = _get_category_color(category)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _get_category_color(category: String) -> Color:
	## Get color coding for trait categories
	match category:
		"environmental":
			return Color(0.4, 0.7, 1.0)  # Blue
		"economic":
			return Color(0.4, 1.0, 0.5)  # Green
		"social":
			return Color(1.0, 0.8, 0.2)  # Yellow
		"military":
			return Color(1.0, 0.3, 0.3)  # Red
		"technical":
			return Color(0.7, 0.4, 1.0)  # Purple
		_:
			return Color(0.7, 0.7, 0.7)  # Gray default

func _update_world_summary() -> void:
	if world_summary:
		world_summary.text = _world_summary_text()

func _world_summary_text() -> String:
	return "World: %s" % DataValidator.safe_get_string(current_world_data, "name", "Unknown World")

func _get_campaign_turn_safe() -> int:
	## Turn number for world generation. During CREATION this is 0: the starting
	## world is where the crew begins, before turn 1 has been played.
	##
	## It defaulted to 1 — and the unified creation state has no "campaign_turn"
	## key, so the default was always what got used. WorldGenerator stamps
	## `discovered_on_turn: campaign_turn` into the world dict, and
	## PlanetDataManager.upsert_current_world() only substitutes its own turn
	## argument when the stamped value is <= 0. A 1 therefore beat the explicit 0
	## that CampaignFinalizationService passes, and every save on disk records the
	## STARTING world as discovered on turn 1 — including the ones whose docblocks
	## promise 0. The Galaxy Log's starting-world anchor is min(discovered_on_turn),
	## so it survived only by insertion order rather than by being correct.
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	if campaign_ui and campaign_ui.has_method("get_coordinator"):
		var coordinator = campaign_ui.get_coordinator()
		if coordinator and coordinator.has_method("get_unified_campaign_state"):
			var state = coordinator.get_unified_campaign_state()
			return int(state.get("campaign_turn", 0))
	return 0  # Creation time: the campaign has not played a turn yet.

## Cached name table data from world_options.json.
##
## Per INSTANCE, not static. As `static var`s these made the process fault at
## EXIT (0xC0000005) whenever this scene had been loaded: the test passed,
## gdUnit4 printed "Exit code: 0", and Godot then crashed in teardown after
## reporting ~190 GDScripts still in use. Measured 2026-10-30 on a one-line
## suite that only load()s WorldInfoPanel.tscn: crash at HEAD and at 6d27ea10c
## (so it predates the suite that found it), rc=0 with these two lines made
## instance members and nothing else changed. Loading the .gd alone, or the
## base scene alone, did not crash; the base scene THEN this script did. One
## panel exists per wizard visit, so re-reading the file per instance is free.
var _name_data: Dictionary = {}
var _name_data_loaded: bool = false

func _ensure_name_data() -> void:
	if _name_data_loaded:
		return
	_name_data_loaded = true
	var file := FileAccess.open(
		"res://data/compendium/world_options.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_name_data = json.data
	file.close()

static func _pick_d100(arr: Array) -> String:
	if arr.is_empty():
		return ""
	var roll := randi_range(1, 100)
	var index := clampi((roll - 1) / 4, 0, arr.size() - 1)
	return arr[index]

func _generate_canonical_world_name(world_type: String) -> String:
	## Generate a world name from Compendium name tables (pp.157-162)
	## Not DLC-gated — name tables are core app data
	_ensure_name_data()
	if world_type == "colony" or world_type == "mining_colony":
		var p1: Array = _name_data.get("colony_part1", [])
		var p2: Array = _name_data.get("colony_part2", [])
		if not p1.is_empty() and not p2.is_empty():
			return _pick_d100(p1) + " " + _pick_d100(p2)
	var world_names: Array = _name_data.get("world_names", [])
	if world_names.is_empty():
		return ""
	var roman := ["I", "II", "III", "IV", "V", "VI"]
	return _pick_d100(world_names) + " " + roman[randi_range(0, 5)]

func _on_world_generated_from_generator(world_data: Dictionary) -> void:
	## Handle world generated from WorldGenerator or fallback template
	current_world_data = world_data
	_display_world_data(world_data)

	# Mark world as generated
	is_world_generated = true
	
	# Update button states if they exist
	if generate_button:
		generate_button.disabled = true
	if reroll_button:
		reroll_button.disabled = false
	if confirm_button:
		confirm_button.disabled = false
		confirm_button.text = "Confirm World"
	
	# Update coordinator with world data
	_send_world_data_to_coordinator(world_data)
	
	# Emit panel data changed signal
	var panel_data = get_panel_data()
	panel_data_changed.emit(panel_data)
	
	# Update validation state
	_update_validation_state()

	# Emit panel signal for CampaignCreationUI (and coordinator via CampaignCreationUI wiring)
	world_generated.emit(world_data)

func _send_world_data_to_coordinator(world_data: Dictionary) -> void:
	## Send world data to coordinator for campaign state management
	if not coordinator:
		push_warning("WorldInfoPanel: No coordinator available for world data update")
		return
	
	# Update coordinator with world state
	if coordinator.has_method("update_world_state"):
		coordinator.update_world_state(world_data)
	else:
		push_warning("WorldInfoPanel: Coordinator missing update_world_state method")

	# Also emit panel data changed for UI updates
	var panel_data = get_panel_data()
	panel_data_changed.emit(panel_data)

	# Emit world_updated signal for CampaignCreationUI
	world_updated.emit(world_data)

func validate_panel() -> bool:
	# World must be generated and confirmed to proceed
	var is_valid: bool = is_world_generated and is_world_confirmed and not current_world_data.is_empty()
	
	if not is_world_generated:
		var errors: Array[String] = ["Please generate a world before proceeding"]
		validation_failed.emit(errors)
		return false
	elif not is_world_confirmed:
		var errors: Array[String] = ["Please confirm your world selection before proceeding"]
		validation_failed.emit(errors)
		return false
	elif current_world_data.is_empty():
		var errors: Array[String] = ["World data is missing, please regenerate"]
		validation_failed.emit(errors)
		return false
	
	return true

func get_panel_data() -> Dictionary:
	## Return complete world data for campaign
	return {
		"world": current_world_data,
		"is_complete": is_world_confirmed,
		"metadata": {
			"generated_at": Time.get_unix_time_from_system(),
			"world_name": current_world_data.get("name", "Unknown"),
		},
	}

func reset_panel() -> void:
	current_world_data = {}
	
	# Clear UI elements
	if world_name_label:
		world_name_label.text = ""
	if world_summary:
		world_summary.text = ""

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	## Restore panel data from persistence system
	if data.is_empty():
		return

	# Restore world data - handle both "current_world" and "world" keys
	if data.has("current_world") and data.current_world is Dictionary:
		current_world_data = data.current_world.duplicate()
	elif data.has("world") and data.world is Dictionary:
		current_world_data = data.world.duplicate()

	# Restore state flags
	if data.has("is_complete"):
		is_world_confirmed = data.is_complete
		is_world_generated = not current_world_data.is_empty()

	# Update display with restored data
	if current_world_data.has("name"):
		update_world_display(current_world_data.get("name", "Unknown World"))


func set_panel_data(data: Dictionary) -> void:
	## Required panel contract method - delegates to restore_panel_data
	restore_panel_data(data)

func _on_coordinator_set() -> void:
	## Called when coordinator is assigned - sync initial world state
	var coord = get_coordinator_reference()
	if coord and coord.has_method("get_unified_campaign_state"):
		var state = coord.get_unified_campaign_state()
		if state.has("world") and state.world is Dictionary and not state.world.is_empty():
			restore_panel_data({"world": state.world})

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	## React to campaign state updates - setup initial world display

	# BUG-018 GUARD: If we already have valid auto-generated world data, don't let
	# provide_initial_state_to_panel() overwrite it. The display and button states
	# are already correct from _auto_generate_if_needed().
	if is_world_generated and not current_world_data.is_empty() and current_world_data.has("name"):
		return

	# Store campaign data for world generation
	var campaign_data = state_data.duplicate()

	# Extract any existing world data
	if state_data.has("world") and state_data.world is Dictionary and not state_data.world.is_empty():
		var existing_world = state_data.world
		if existing_world.has("name") and not existing_world.name.is_empty():
			current_world_data = existing_world
			_display_world_data(current_world_data)
			
			# Update button states for existing world
			is_world_generated = true
			is_world_confirmed = existing_world.get("is_complete", false)
			
			if generate_button:
				generate_button.disabled = true
			if reroll_button:
				reroll_button.disabled = not is_world_confirmed
			if confirm_button:
				confirm_button.disabled = is_world_confirmed
				confirm_button.text = "✓ World Confirmed" if is_world_confirmed else "Confirm World"
			
			_update_validation_state()
			return
	
## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	## Panel initialization verification (debug output removed for release)
	pass
	

## Coordinator Integration Methods

func set_coordinator(coord: Node) -> void:
	## Set coordinator reference with robust error handling and signal connections
	if not coord:
		push_error("WorldInfoPanel: Attempted to set null coordinator")
		return

	coordinator = coord
	_coordinator = coord  # BUGFIX: Also set base class variable for get_coordinator_reference()
	
	# Connect to coordinator's campaign state updates with safety checks
	if coordinator.has_signal("campaign_state_updated"):
		if not coordinator.campaign_state_updated.is_connected(_on_campaign_state_updated):
			coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
	else:
		push_warning("WorldInfoPanel: Coordinator missing campaign_state_updated signal")
	
	# Sync with phase key for state management
	if panel_phase_key.is_empty():
		panel_phase_key = "world"
	
	# Sync existing state if available
	_sync_with_coordinator()
	

func _sync_with_coordinator() -> void:
	## Synchronize with coordinator's current state
	if not coordinator:
		return

	if coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		if state and state.has("world"):
			var world_state = state.get("world", {})
			# BUG-018 FIX: Only treat as valid world data if it has a non-empty name.
			# The coordinator initializes world with empty-string defaults (name="",
			# type="", etc.) — a non-empty dict but NOT real world data.
			var world_name = world_state.get("name", "") if world_state is Dictionary else ""
			if world_state is Dictionary and not world_state.is_empty() and world_name != "":
				current_world_data = world_state
				_display_world_data(current_world_data)

				# Update generation state based on existing data
				is_world_generated = true
				is_world_confirmed = world_state.get("is_complete", false)

				# Update button states
				_update_button_states()
	

func _update_button_states() -> void:
	## Update control button states based on current world status
	if generate_button:
		generate_button.disabled = is_world_generated

	if reroll_button:
		reroll_button.disabled = not is_world_generated or is_world_confirmed

	if confirm_button:
		confirm_button.disabled = not is_world_generated or is_world_confirmed
		confirm_button.text = "✓ World Confirmed" if is_world_confirmed else "Confirm World"

func sync_with_coordinator() -> void:
	## Sync panel display with coordinator state (read-only — does NOT generate worlds).
	## Initial generation is handled exclusively by _auto_generate_if_needed().
	if not coordinator:
		return

	var campaign_state = {}
	if coordinator.has_method("get_unified_campaign_state"):
		campaign_state = coordinator.get_unified_campaign_state()
	elif coordinator.has_method("get_state"):
		campaign_state = coordinator.get_state()

	# Only update display if coordinator has valid world data with a name
	var world_data = campaign_state.get("world", {})
	if not world_data.is_empty() and world_data.get("name", "") != "":
		current_world_data = world_data
		_display_world_data(world_data)
	
