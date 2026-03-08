@tool
extends FiveParsecsCampaignPanel

## World Information Panel - Current world status and opportunities display
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
const CampaignSignals = preload("res://src/core/signals/CampaignSignals.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
const DataValidator = preload("res://src/core/utils/DataValidator.gd")

# UI References
@onready var world_name_label: Label = %WorldNameLabel
@onready var world_traits_container: VBoxContainer = %WorldTraitsContainer
@onready var government_info: Label = %GovernmentInfo
@onready var tech_level_display: Label = %TechLevelDisplay
@onready var market_prices_container: VBoxContainer = %MarketPricesContainer
@onready var opportunities_container: VBoxContainer = %OpportunitiesContainer
@onready var threats_container: VBoxContainer = %ThreatsContainer
@onready var world_summary: Label = %WorldSummary

# World generation system
const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")
var world_generator = null  # WorldGenerator instance
var fallback_world_templates: Array = []

# Template-based fallback worlds for defensive programming
const WORLD_TEMPLATES = {
	"starter_friendly": {
		"name": "Haven Station",
		"type": "temperate",
		"type_name": "Temperate World",
		"danger_level": 1,
		"traits": ["trade_center", "free_port"],
		"tech_level": 4,
		"government_type": "Colonial Administration",
		"locations": [
			{"name": "Spaceport", "type": "spaceport", "danger_mod": 0, "explored": false},
			{"name": "Market District", "type": "market", "danger_mod": -1, "explored": false}
		],
		"special_features": ["safe_harbor", "established_trade_routes"]
	},
	"balanced": {
		"name": "Frontier Outpost",
		"type": "desert",
		"type_name": "Desert World",
		"danger_level": 2,
		"traits": ["frontier_world", "mining_world"],
		"tech_level": 3,
		"government_type": "Corporate Outpost",
		"locations": [
			{"name": "Mining Station", "type": "industrial", "danger_mod": 1, "explored": false},
			{"name": "Trading Post", "type": "commercial", "danger_mod": 0, "explored": false}
		],
		"special_features": ["mineral_deposits", "harsh_conditions"]
	},
	"challenging": {
		"name": "Contested Zone",
		"type": "volcanic",
		"type_name": "Volcanic World",
		"danger_level": 4,
		"traits": ["pirate_haven", "military_base"],
		"tech_level": 2,
		"government_type": "Military Occupation",
		"locations": [
			{"name": "Fortified Base", "type": "military", "danger_mod": 2, "explored": false},
			{"name": "Black Market", "type": "underground", "danger_mod": 3, "explored": false}
		],
		"special_features": ["high_danger", "active_conflicts", "valuable_resources"]
	}
}

# Data management
var current_world_data: Dictionary = {}
var world_opportunities: Array[Dictionary] = []
var world_threats: Array[Dictionary] = []
var selected_opportunity: String = ""
var campaign_signals: CampaignSignals

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
	set_panel_info("World Generation", "Generate your starting world and sector. This determines available missions and encounters.")

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
	
	_connect_campaign_signals()
	_apply_mobile_layout()

func _verify_button_creation() -> void:
	## Verify buttons were created and added correctly
	if not generate_button or not reroll_button or not confirm_button:
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
	
	world_generator = WorldGenerator.new()
	if not world_generator:
		push_error("WorldInfoPanel: Failed to create WorldGenerator instance")
		return

	# Connect world generation signal with defensive check
	if world_generator.has_signal("world_generated"):
		world_generator.world_generated.connect(_on_world_generated_from_generator)
	else:
		push_warning("WorldInfoPanel: WorldGenerator missing expected signal")

func _setup_world_panel() -> void:
	# Initialize world display components
	if not world_name_label:
		push_warning("WorldInfoPanel: World name label not found")
		return
	
	# Setup opportunity tracking
	_setup_opportunity_tracking()
	
	# Setup threat monitoring
	_setup_threat_monitoring()

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
	var button_container = HBoxContainer.new()
	button_container.name = "WorldControlButtons"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", SPACING_LG)
	
	# Create Generate World button
	generate_button = Button.new()
	generate_button.text = "Generate World"
	generate_button.custom_minimum_size = Vector2(150, TOUCH_TARGET_MIN)
	generate_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	generate_button.pressed.connect(_on_generate_button_pressed)
	button_container.add_child(generate_button)

	# Create Reroll button (initially disabled)
	reroll_button = Button.new()
	reroll_button.text = "Reroll World"
	reroll_button.custom_minimum_size = Vector2(150, TOUCH_TARGET_MIN)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_button.disabled = true
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	button_container.add_child(reroll_button)

	# Create Confirm button (initially disabled)
	confirm_button = Button.new()
	confirm_button.text = "Confirm World"
	confirm_button.custom_minimum_size = Vector2(150, TOUCH_TARGET_MIN)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	button_container.add_child(confirm_button)
	
	# Add button container to the Content VBoxContainer
	content_container.add_child(button_container)
	
	# Move to bottom of content if possible
	content_container.move_child(button_container, content_container.get_child_count() - 1)
	

func _on_generate_button_pressed() -> void:
	## Handle generate world button press
	
	# Generate a new world
	var campaign_name = _get_campaign_name_safe()
	_generate_world_with_fallback(campaign_name + " Prime")
	
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
	_generate_world_with_fallback(campaign_name + " " + world_suffix)
	
	# Keep confirm button enabled
	is_world_generated = true
	is_world_confirmed = false
	
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
	

func _connect_campaign_signals() -> void:
	# Connect to campaign signals - Framework Bible compliant
	campaign_signals = CampaignSignals.new()
	
	# Connect world-related signals
	campaign_signals.connect_signal_safely("world_discovered", self, "_on_world_discovered")
	campaign_signals.connect_signal_safely("location_explored", self, "_on_location_explored")
	campaign_signals.connect_signal_safely("patron_encountered", self, "_on_patron_encountered")
	campaign_signals.connect_signal_safely("rival_threat_identified", self, "_on_rival_threat_identified")
	campaign_signals.connect_signal_safely("trade_opportunity_identified", self, "_on_trade_opportunity_identified")

func _apply_mobile_layout() -> void:
	## Mobile-specific layout: Single column, large touch targets, compact info
	# Override from BaseCampaignPanel
	if world_traits_container:
		world_traits_container.custom_minimum_size.y = 80  # Compact on mobile
		world_traits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if world_summary:
		world_summary.text = _generate_compact_world_summary()

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
		world_summary.text = _generate_detailed_world_summary()

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
		world_summary.text = _generate_detailed_world_summary()

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
		_generate_world_with_fallback(world_name)
	else:
		_display_world_data(current_world_data)

func _generate_world_with_fallback(world_name: String) -> void:
	## Generate world using WorldGenerator with defensive fallback
	if world_generator:
		
		# Get campaign turn from state if available for difficulty scaling
		var campaign_turn = _get_campaign_turn_safe()
		var world_data = world_generator.generate_world(campaign_turn)
		
		# Check if world generation was successful
		if world_data and not world_data.is_empty():
			# Customize world name
			world_data["name"] = world_name if not world_name.is_empty() else world_data.get("name", "New World")
			
			# Add additional UI-specific data
			world_data["government_type"] = _determine_government_type(world_data)
			world_data["tech_level"] = _determine_tech_level(world_data)
			
			_on_world_generated_from_generator(world_data)
		else:
			push_warning("WorldInfoPanel: WorldGenerator returned empty data - using fallback template")
			_use_fallback_world_template(world_name)
	else:
		_use_fallback_world_template(world_name)

func _use_fallback_world_template(world_name: String) -> void:
	## Use predefined world template as fallback
	var template_key = _select_appropriate_template()
	
	# Ensure template key exists before accessing
	if not WORLD_TEMPLATES.has(template_key):
		template_key = "balanced"  # Safe fallback
	
	var fallback_world = WORLD_TEMPLATES[template_key].duplicate(true)
	
	# Customize template with provided name - safe property access
	var original_name = fallback_world.get("name", "Unknown World")
	fallback_world["name"] = world_name if not world_name.is_empty() else original_name
	fallback_world["id"] = "fallback_" + str(Time.get_unix_time_from_system())
	
	_on_world_generated_from_generator(fallback_world)

func _select_appropriate_template() -> String:
	## Select appropriate world template based on crew size/difficulty
	# Try to get crew data to adjust difficulty - with defensive null checks
	if get_parent() != null:
		var campaign_ui = owner if owner != null else get_parent().get_parent()
		if campaign_ui and campaign_ui.has_method("get_coordinator"):
			var coordinator = campaign_ui.get_coordinator()
			if coordinator and coordinator.has_method("get_unified_campaign_state"):
				var state = coordinator.get_unified_campaign_state()
				if state and state.has("crew"):
					var crew_size = state["crew"].get("members", []).size()
					
					# Scale template based on crew size
					if crew_size >= 6:
						return "challenging"  # Large crew can handle danger
					elif crew_size >= 4:
						return "balanced"     # Medium crew gets balanced challenge
					else:
						return "starter_friendly"  # Small crew needs easier start
	
	# Default to balanced if no data available
	return "balanced"

func _display_world_data(world_data: Dictionary) -> void:
	## Display world data in UI components with DataValidator safety
	# Use DataValidator for safe access to world data
	var safe_name = DataValidator.safe_get_string(world_data, "name", "Unknown World")
	var safe_traits = DataValidator.safe_get_array(world_data, "traits", [])
	var safe_government = DataValidator.safe_get_string(world_data, "government_type", "Independent Colony")
	var safe_tech_level = DataValidator.safe_get_int(world_data, "tech_level", 3)
	var safe_patrons = DataValidator.safe_get_array(world_data, "known_patrons", [])
	var safe_market_prices = DataValidator.safe_get_dict(world_data, "market_prices", {})
	var safe_threats = DataValidator.safe_get_array(world_data, "rival_threats", [])

	# Display world name (FIX: was never being updated)
	if world_name_label:
		world_name_label.text = "Current World: " + safe_name

	_display_world_traits(safe_traits)
	_display_government_info(safe_government, safe_tech_level)
	_display_opportunities(safe_patrons, safe_market_prices)
	_display_threats(safe_threats)
	_update_world_summary()
	

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
			# Legacy format - just display the trait ID
			var feature_label = Label.new()
			feature_label.text = "• %s" % feature_data
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
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	name_hbox.add_child(name_label)
	
	# Category badge
	var category_label = Label.new()
	var category = str(trait_data.get("category", "social"))
	category_label.text = "[%s]" % category.capitalize()
	category_label.add_theme_font_size_override("font_size", 11)
	category_label.add_theme_color_override("font_color", _get_category_color(category))
	name_hbox.add_child(category_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = trait_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(desc_label)
	
	# Mechanical effect (highlighted)
	var effect_label = Label.new()
	effect_label.text = "⚙ %s" % trait_data.get("mechanical_effect", "No mechanical effect")
	effect_label.add_theme_font_size_override("font_size", 11)
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

func _display_government_info(government_type: String, tech_level: int) -> void:
	if government_info:
		government_info.text = "Government: %s" % government_type
		government_info.add_theme_color_override("font_color", UIColors.NEUTRAL_COLOR)

	if tech_level_display:
		tech_level_display.text = "Tech Level: %d" % tech_level

		# Color coding based on tech level
		if tech_level >= 5:
			tech_level_display.add_theme_color_override("font_color", UIColors.SUCCESS_COLOR)
		elif tech_level >= 3:
			tech_level_display.add_theme_color_override("font_color", UIColors.INFO_COLOR)
		else:
			tech_level_display.add_theme_color_override("font_color", UIColors.WARNING_COLOR)

func _display_opportunities(known_patrons: Array, market_prices: Dictionary) -> void:
	if not opportunities_container:
		return

	# Clear existing opportunities
	var children = opportunities_container.get_children()
	for i in range(children.size()):
		children[i].queue_free()

	# Add section header
	var header = Label.new()
	header.text = "📋 Available Opportunities"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	opportunities_container.add_child(header)

	# Track if we have any content
	var has_content = false

	# Add patron opportunities
	if known_patrons.size() > 0:
		var patron_header = Label.new()
		patron_header.text = "Patrons:"
		patron_header.add_theme_font_size_override("font_size", 12)
		patron_header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		opportunities_container.add_child(patron_header)

		for i in range(known_patrons.size()):
			var patron_data = known_patrons[i]
			var patron_card = _create_opportunity_card(patron_data, "patron")
			if patron_card:
				opportunities_container.add_child(patron_card)
				has_content = true

	# Add trade opportunities
	if market_prices.size() > 0:
		var trade_header = Label.new()
		trade_header.text = "Market Prices:"
		trade_header.add_theme_font_size_override("font_size", 12)
		trade_header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		opportunities_container.add_child(trade_header)

		var commodity_keys = market_prices.keys()
		for i in range(commodity_keys.size()):
			var commodity_key = commodity_keys[i]
			var price_data = market_prices[commodity_key]
			var trade_card = _create_opportunity_card({
				"type": "trade",
				"commodity": commodity_key,
				"price": price_data.get("current", 0),
				"trend": price_data.get("trend", "stable")
			}, "trade")
			if trade_card:
				opportunities_container.add_child(trade_card)
				has_content = true

	# Show placeholder if no opportunities
	if not has_content:
		var empty_label = Label.new()
		empty_label.text = "No opportunities available yet"
		empty_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		opportunities_container.add_child(empty_label)

func _display_threats(rival_threats: Array) -> void:
	if not threats_container:
		return

	# Clear existing threats
	var children = threats_container.get_children()
	for i in range(children.size()):
		children[i].queue_free()

	# Add section header
	var header = Label.new()
	header.text = "⚠️ Known Threats"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	threats_container.add_child(header)

	# Add threat cards
	if rival_threats.size() > 0:
		for i in range(rival_threats.size()):
			var threat_data = rival_threats[i]
			var threat_card = _create_threat_card(threat_data)
			if threat_card:
				threats_container.add_child(threat_card)
	else:
		# Show placeholder if no threats
		var empty_label = Label.new()
		empty_label.text = "No known threats in this sector"
		empty_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		threats_container.add_child(empty_label)

func _create_opportunity_card(opportunity_data: Dictionary, opportunity_type: String) -> Control:
	# Create opportunity card using PanelContainer
	var opportunity_card = PanelContainer.new()

	# Create VBox for multi-line content
	var content_vbox = VBoxContainer.new()
	opportunity_card.add_child(content_vbox)

	# Create label for opportunity display
	var opportunity_label = Label.new()

	# Handle different opportunity types
	if opportunity_type == "trade":
		var commodity = str(opportunity_data.get("commodity", "Unknown"))
		var price = opportunity_data.get("price", 0)
		var trend = str(opportunity_data.get("trend", "stable"))
		var trend_icon = "→" if trend == "stable" else ("↑" if trend == "rising" else "↓")
		opportunity_label.text = "%s: %d credits %s" % [commodity.capitalize(), price, trend_icon]
	else:
		opportunity_label.text = opportunity_data.get("name", "Unknown Opportunity")

	opportunity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(opportunity_label)

	# Add description if available
	var description = opportunity_data.get("description", "")
	if not description.is_empty():
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_vbox.add_child(desc_label)

	# Apply visual styling
	_apply_opportunity_styling(opportunity_label, opportunity_data, opportunity_type)

	return opportunity_card

func _apply_opportunity_styling(opportunity_card: Control, opportunity_data: Dictionary, opportunity_type: String) -> void:
	var opportunity_level = opportunity_data.get("level", "normal")
	var risk_level = opportunity_data.get("risk", "low")

	# Color coding based on opportunity type and risk
	match opportunity_type:
		"patron":
			opportunity_card.add_theme_color_override("font_color", UIColors.SUCCESS_COLOR)
		"trade":
			opportunity_card.add_theme_color_override("font_color", UIColors.INFO_COLOR)
		_:
			opportunity_card.add_theme_color_override("font_color", UIColors.NEUTRAL_COLOR)

	# Additional styling for high-risk opportunities
	if risk_level == "high":
		opportunity_card.add_theme_color_override("font_color", UIColors.WARNING_COLOR)

func _create_threat_card(threat_data: Dictionary) -> Control:
	# Create threat card using PanelContainer
	var threat_card = PanelContainer.new()

	# Create VBox for multi-line content
	var content_vbox = VBoxContainer.new()
	threat_card.add_child(content_vbox)

	# Create label for threat display
	var threat_label = Label.new()
	threat_label.text = threat_data.get("name", "Unknown Threat")
	threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(threat_label)

	# Add description if available
	var description = threat_data.get("description", "")
	if not description.is_empty():
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_vbox.add_child(desc_label)

	# Apply visual styling
	_apply_threat_styling(threat_label, threat_data)

	return threat_card

func _apply_threat_styling(threat_card: Control, threat_data: Dictionary) -> void:
	var threat_level = threat_data.get("level", "low")
	var threat_type = threat_data.get("type", "unknown")

	# Color coding based on threat level
	match threat_level:
		"critical":
			threat_card.add_theme_color_override("font_color", UIColors.DANGER_COLOR)
		"high":
			threat_card.add_theme_color_override("font_color", UIColors.WARNING_COLOR)
		"medium":
			threat_card.add_theme_color_override("font_color", UIColors.INFO_COLOR)
		_:
			threat_card.add_theme_color_override("font_color", UIColors.NEUTRAL_COLOR)

func _show_unexplored_world_placeholder(world_name: String) -> void:
	if world_name_label:
		world_name_label.text = "World: %s (Unexplored)" % world_name
		world_name_label.add_theme_color_override("font_color", UIColors.WARNING_COLOR)
	
	if world_summary:
		world_summary.text = "This world has not been explored yet. Send a mission to discover its secrets."

func _update_world_summary() -> void:
	if not world_summary:
		return
	
	# Use DataValidator for safe access to world data
	var world_name = DataValidator.safe_get_string(current_world_data, "planet_name", 
		DataValidator.safe_get_string(current_world_data, "name", "Unknown World"))
	var tech_level = DataValidator.safe_get_int(current_world_data, "tech_level", 3)
	var opportunities_count = world_opportunities.size()
	var threats_count = world_threats.size()
	
	# Update summary with contextual information
	world_summary.text = "World: %s | Tech Level %d | %d Opportunities, %d Threats" % [
		world_name, tech_level, opportunities_count, threats_count
	]

func _get_campaign_turn_safe() -> int:
	## Safely get campaign turn for world generation difficulty scaling
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	if campaign_ui and campaign_ui.has_method("get_coordinator"):
		var coordinator = campaign_ui.get_coordinator()
		if coordinator and coordinator.has_method("get_unified_campaign_state"):
			var state = coordinator.get_unified_campaign_state()
			return state.get("campaign_turn", 1)
	return 1  # Default to turn 1

func _determine_government_type(world_data: Dictionary) -> String:
	## Determine government type based on world traits and danger level
	var traits = world_data.get("traits", [])
	var danger_level = world_data.get("danger_level", 2)
	
	if "military_base" in traits or danger_level >= 4:
		return "Military Occupation"
	elif "corporate_world" in traits or "industrial_hub" in traits:
		return "Corporate Control"
	elif "trade_center" in traits or "free_port" in traits:
		return "Trade Federation"
	elif "frontier_world" in traits:
		return "Colonial Administration"
	elif "pirate_haven" in traits:
		return "Anarchic"
	else:
		return "Independent Colony"

func _determine_tech_level(world_data: Dictionary) -> int:
	## Determine tech level based on world type and traits
	var traits = world_data.get("traits", [])
	var world_type = world_data.get("type", "")
	
	var base_tech = 3  # Standard tech level
	
	if "research_outpost" in traits:
		base_tech += 2
	elif "industrial_hub" in traits:
		base_tech += 1
	elif "frontier_world" in traits:
		base_tech -= 1
	
	# Adjust for world type
	match world_type:
		"urban":
			base_tech += 1
		"barren", "desert":
			base_tech -= 1
	
	return clamp(base_tech, 1, 6)

func _on_world_generated_from_generator(world_data: Dictionary) -> void:
	## Handle world generated from WorldGenerator or fallback template
	current_world_data = world_data
	_display_world_data(world_data)

	# Populate world_opportunities and world_threats arrays from generated data
	_populate_opportunities_and_threats_from_world_data(world_data)

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

## Signal handlers
func _on_world_discovered(world_data: Dictionary) -> void:
	current_world_data = world_data
	update_world_display(world_data.get("planet_name", "Unknown World"))

func _on_location_explored(location_name: String, discoveries: Array) -> void:
	# Update world data with new discoveries
	var discovered_locations = current_world_data.get("discovered_locations", [])
	if location_name not in discovered_locations:
		discovered_locations.append(location_name)
		current_world_data["discovered_locations"] = discovered_locations
	
	# Update display
	update_world_display(current_world_data.get("planet_name", "Unknown World"))

func _on_patron_encountered(patron_data: Dictionary) -> void:
	# Add new patron to opportunities
	world_opportunities.append(patron_data)
	_display_opportunities(current_world_data.get("known_patrons", []), current_world_data.get("market_prices", {}))

func _on_rival_threat_identified(threat_data: Dictionary) -> void:
	# Add new threat to threats list
	world_threats.append(threat_data)
	_display_threats(current_world_data.get("rival_threats", []))

func _on_trade_opportunity_identified(opportunity: Dictionary) -> void:
	# Add new trade opportunity
	world_opportunities.append(opportunity)
	_display_opportunities(current_world_data.get("known_patrons", []), current_world_data.get("market_prices", {}))

func _on_opportunity_card_selected(card_data: Dictionary) -> void:
	selected_opportunity = card_data.get("opportunity_id", "")
	campaign_signals.emit_safe_signal("opportunity_selected", [selected_opportunity])

func _on_opportunity_action_requested(action: String, data: Variant) -> void:
	campaign_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_threat_card_selected(card_data: Dictionary) -> void:
	var threat_id = card_data.get("threat_id", "")
	campaign_signals.emit_safe_signal("threat_selected", [threat_id])

func _on_threat_action_requested(action: String, data: Variant) -> void:
	campaign_signals.emit_safe_signal("quick_action_requested", [action, data])

## Opportunity tracking functionality
func _setup_opportunity_tracking() -> void:
	# Initialize opportunity tracking system
	world_opportunities = []

func get_world_opportunities() -> Array:
	return world_opportunities

func add_opportunity(opportunity_data: Dictionary) -> void:
	world_opportunities.append(opportunity_data)
	_display_opportunities(current_world_data.get("known_patrons", []), current_world_data.get("market_prices", {}))

## Threat monitoring functionality
func _setup_threat_monitoring() -> void:
	# Initialize threat monitoring system
	world_threats = []

func get_world_threats() -> Array:
	return world_threats

func add_threat(threat_data: Dictionary) -> void:
	world_threats.append(threat_data)
	_display_threats(current_world_data.get("rival_threats", []))

func _populate_opportunities_and_threats_from_world_data(world_data: Dictionary) -> void:
	## Populate world_opportunities and world_threats arrays from generated world data.
	## This ensures get_panel_data() returns the correct opportunities/threats for FinalPanel.
	pass
	## # Clear existing arrays
	## world_opportunities.clear()
	## world_threats.clear()
	##
	## # Populate opportunities from known_patrons
	## var known_patrons = world_data.get("known_patrons", [])
	## for patron in known_patrons:
	## if patron is Dictionary:
	## world_opportunities.append(patron)
	## elif patron is String:
	## # Legacy string format - wrap in dictionary
	## world_opportunities.append({"name": patron, "type": "patron"})
	##
	## # Add market opportunities if present
	## var market_prices = world_data.get("market_prices", {})
	## if not market_prices.is_empty():
	## world_opportunities.append({
	## "name": "Local Market",
	## "type": "trade",
	## "description": "Trading opportunities available at local market",
	## "market_data": market_prices
	## })
	##
	## # Populate threats from rival_threats
	## var rival_threats = world_data.get("rival_threats", [])
	## for threat in rival_threats:
	## if threat is Dictionary:
	## world_threats.append(threat)
	## elif threat is String:
	## # Legacy string format - wrap in dictionary
	## world_threats.append({"name": threat, "type": "rival"})
	##
	## print("WorldInfoPanel: Populated %d opportunities and %d threats from world data" % [world_opportunities.size(), world_threats.size()])
	##
	##

func _generate_compact_world_summary() -> String:
	var world_name = current_world_data.get("planet_name", "Unknown")
	var tech_level = current_world_data.get("tech_level", 3)
	return "World: %s (Tech %d)" % [world_name, tech_level]

func _generate_detailed_world_summary() -> String:
	var world_name = current_world_data.get("planet_name", "Unknown World")
	var tech_level = current_world_data.get("tech_level", 3)
	var government_type = current_world_data.get("government_type", "Unknown")
	var opportunities_count = world_opportunities.size()
	var threats_count = world_threats.size()
	return "World Status: %s | %s Government | Tech Level %d | %d Opportunities, %d Threats" % [
		world_name, government_type, tech_level, opportunities_count, threats_count
	]

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
	var panel_data = {
		"world": current_world_data,
		"opportunities": world_opportunities,
		"threats": world_threats,
		"selected_opportunity": selected_opportunity,
		"is_complete": is_world_confirmed
	}
	
	# Add metadata
	panel_data["metadata"] = {
		"generated_at": Time.get_unix_time_from_system(),
		"world_name": current_world_data.get("name", "Unknown"),
		"danger_level": current_world_data.get("danger_level", 0),
		"tech_level": current_world_data.get("tech_level", 0)
	}
	
	return panel_data

func reset_panel() -> void:
	current_world_data = {}
	world_opportunities = []
	world_threats = []
	selected_opportunity = ""
	
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

	# Restore opportunities
	if data.has("opportunities") and data.opportunities is Array:
		world_opportunities = data.opportunities.duplicate()

	# Restore threats
	if data.has("threats") and data.threats is Array:
		world_threats = data.threats.duplicate()

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
	
	# Always adjust world generation parameters based on campaign data
	_adjust_world_generation_parameters(campaign_data)
	
	# Update danger modifier display if we have crew data
	if campaign_data.has("crew"):
		var crew_data = campaign_data.get("crew", {})
		var crew_size = crew_data.get("members", []).size()
		var captain_data = campaign_data.get("captain", {})
		var captain_background = str(captain_data.get("background", ""))

		var danger_modifier = _calculate_danger_level(crew_size, captain_background)

func _generate_world_from_campaign_data(campaign_data: Dictionary) -> void:
	## Generate world based on accumulated campaign data from previous panels
	
	# Get campaign details
	var campaign_config = campaign_data.get("campaign_config", {})
	var crew_data = campaign_data.get("crew", {})
	var captain_data = campaign_data.get("captain", {})
	var ship_data = campaign_data.get("ship", {})
	
	# Create world name from campaign
	var campaign_name = campaign_config.get("campaign_name", "Unknown Campaign")
	var world_name = campaign_name + " Prime"
	
	# Determine world characteristics based on campaign data
	var crew_size = crew_data.get("members", []).size()
	var captain_background = str(captain_data.get("background", ""))
	var ship_type = str(ship_data.get("type", ""))

	# Generate appropriate world type and danger level
	var world_type = _determine_world_type_from_campaign(captain_background, ship_type)
	var danger_level = _calculate_danger_level(crew_size, captain_background)
	var tech_level = _determine_tech_level_from_campaign(campaign_data)
	
	# Create world data
	var world_data = {
		"name": world_name,
		"planet_name": world_name,
		"type": world_type,
		"type_name": _get_world_type_display_name(world_type),
		"danger_level": danger_level,
		"tech_level": tech_level,
		"government_type": _determine_government_type_from_campaign(world_type, danger_level),
		"traits": _generate_world_traits(world_type, danger_level),
		"locations": _generate_starting_locations(world_type, tech_level),
		"special_features": _generate_special_features(captain_background, crew_size),
		"known_patrons": _generate_starting_patrons(world_type, tech_level),
		"market_prices": _generate_market_prices(tech_level),
		"rival_threats": _generate_starting_threats(danger_level, world_type)
	}
	
	# Apply generated world
	current_world_data = world_data
	_display_world_data(world_data)

	# Populate world_opportunities and world_threats arrays from generated data
	# This ensures get_panel_data() returns the generated patrons/threats
	_populate_opportunities_and_threats_from_world_data(world_data)

	# Send to coordinator
	_send_world_data_to_coordinator(world_data)


func _adjust_world_generation_parameters(campaign_data: Dictionary) -> void:
	## Adjust world generator parameters based on campaign data
	if not world_generator:
		return
	
	var crew_data = campaign_data.get("crew", {})
	var captain_data = campaign_data.get("captain", {})
	
	# Adjust danger based on crew size
	var crew_size = crew_data.get("members", []).size()
	var danger_modifier = clamp(5 - crew_size, 0, 2)  # Smaller crews = higher danger
	
	# Adjust based on captain background
	var captain_background = str(captain_data.get("background", ""))
	if captain_background in ["military", "veteran"]:
		danger_modifier = max(0, danger_modifier - 1)  # Military reduces danger
	elif captain_background in ["academic", "diplomat"]:
		danger_modifier += 1  # Non-combat backgrounds increase danger
	
	# Apply adjustments if world generator supports them
	if world_generator.has_method("set_danger_level_modifier"):
		world_generator.set_danger_level_modifier(danger_modifier)

func _determine_world_type_from_campaign(captain_background: String, ship_type: String) -> String:
	## Determine appropriate world type based on campaign background
	match captain_background:
		"military", "veteran":
			return "industrial"  # Military prefers established worlds
		"academic", "explorer":
			return "frontier"  # Academics like unexplored areas
		"trader", "merchant":
			return "temperate"  # Traders prefer populated worlds
		"criminal", "outlaw":
			return "desert"  # Criminals prefer remote areas
		_:
			return "temperate"  # Default safe choice

func _calculate_danger_level(crew_size: int, captain_background: String) -> int:
	## Calculate appropriate danger level based on crew composition
	var base_danger = 2  # Standard danger
	
	# Adjust for crew size
	if crew_size <= 2:
		base_danger += 1  # Small crews face more danger
	elif crew_size >= 6:
		base_danger -= 1  # Large crews are safer
	
	# Adjust for captain background
	match captain_background:
		"military", "veteran":
			base_danger -= 1  # Combat experience reduces danger
		"criminal", "outlaw":
			base_danger += 1  # Criminal background increases danger
	
	return clamp(base_danger, 1, 4)

func _determine_tech_level_from_campaign(campaign_data: Dictionary) -> int:
	## Determine tech level based on campaign data
	var base_tech = 3  # Standard tech level
	
	var captain_data = campaign_data.get("captain", {})
	var captain_background = str(captain_data.get("background", ""))

	match captain_background:
		"academic", "scientist":
			base_tech += 1  # Academics prefer high-tech worlds
		"trader", "merchant":
			base_tech += 0  # Traders are neutral
		"frontier", "explorer":
			base_tech -= 1  # Frontier types prefer low-tech worlds
	
	return clamp(base_tech, 1, 6)

func _get_world_type_display_name(world_type: String) -> String:
	## Get display name for world type
	match world_type:
		"temperate":
			return "Temperate World"
		"desert":
			return "Desert World"
		"industrial":
			return "Industrial World"
		"frontier":
			return "Frontier World"
		"urban":
			return "Urban World"
		"volcanic":
			return "Volcanic World"
		_:
			return "Unknown World Type"

func _determine_government_type_from_campaign(world_type: String, danger_level: int) -> String:
	## Determine government type based on world characteristics
	if danger_level >= 4:
		return "Military Occupation"
	elif world_type == "industrial":
		return "Corporate Control"
	elif world_type == "temperate":
		return "Trade Federation"
	elif world_type == "frontier":
		return "Colonial Administration"
	else:
		return "Independent Colony"

func _generate_world_traits(world_type: String, danger_level: int) -> Array[String]:
	## Generate appropriate world traits
	var traits: Array[String] = []
	
	match world_type:
		"temperate":
			traits.append_array(["trade_center", "established_colony"])
		"desert":
			traits.append_array(["harsh_conditions", "mining_world"])
		"industrial":
			traits.append_array(["industrial_hub", "corporate_world"])
		"frontier":
			traits.append_array(["frontier_world", "unexplored_regions"])
	
	if danger_level >= 3:
		traits.append("high_danger")
	
	return traits

func _generate_starting_locations(world_type: String, tech_level: int) -> Array[Dictionary]:
	## Generate starting locations based on world characteristics
	var locations: Array[Dictionary] = []
	
	# Always have a spaceport
	locations.append({
		"name": "Spaceport",
		"type": "spaceport",
		"danger_mod": 0,
		"explored": true
	})
	
	# Add locations based on world type
	match world_type:
		"temperate":
			locations.append({
				"name": "Market District",
				"type": "commercial",
				"danger_mod": -1,
				"explored": false
			})
		"industrial":
			locations.append({
				"name": "Manufacturing Complex",
				"type": "industrial",
				"danger_mod": 1,
				"explored": false
			})
		"frontier":
			locations.append({
				"name": "Survey Station",
				"type": "research",
				"danger_mod": 0,
				"explored": false
			})
		"desert":
			locations.append({
				"name": "Mining Outpost",
				"type": "mining",
				"danger_mod": 2,
				"explored": false
			})
	
	return locations

func _generate_special_features(captain_background: String, crew_size: int) -> Array[String]:
	## Generate special features based on campaign characteristics
	var features: Array[String] = []
	
	match captain_background:
		"military":
			features.append("military_contacts")
		"trader":
			features.append("trade_connections")
		"academic":
			features.append("research_opportunities")
		"criminal":
			features.append("underworld_contacts")
	
	if crew_size >= 5:
		features.append("established_reputation")
	
	return features

func _generate_market_prices(tech_level: int) -> Dictionary:
	## Generate market prices based on tech level
	var prices = {}

	# Base prices modified by tech level
	var tech_modifier = (tech_level - 3) * 0.1  # +/- 10% per tech level from 3

	prices["food"] = {"current": int(10 * (1.0 + tech_modifier)), "trend": "stable"}
	prices["equipment"] = {"current": int(25 * (1.0 - tech_modifier)), "trend": "stable"}
	prices["fuel"] = {"current": int(15 * (1.0 + tech_modifier * 0.5)), "trend": "stable"}

	return prices

func _generate_starting_patrons(world_type: String, tech_level: int) -> Array[Dictionary]:
	## Generate starting patron opportunities based on world characteristics
	var patrons: Array[Dictionary] = []

	# Corporate patron for industrial/urban worlds
	if world_type in ["industrial", "urban", "temperate"]:
		patrons.append({
			"name": "Corporate Representative",
			"type": "corporate",
			"level": "standard",
			"risk": "low",
			"description": "Seeking freelancers for security and transport jobs"
		})

	# Government patron for established worlds
	if tech_level >= 3:
		patrons.append({
			"name": "Colonial Administrator",
			"type": "government",
			"level": "standard",
			"risk": "medium",
			"description": "Has contracts for system defense and patrol missions"
		})

	# Trader patron for frontier/desert worlds
	if world_type in ["frontier", "desert"]:
		patrons.append({
			"name": "Independent Merchant",
			"type": "merchant",
			"level": "standard",
			"risk": "medium",
			"description": "Looking for escorts and cargo haulers"
		})

	# Always at least one patron
	if patrons.is_empty():
		patrons.append({
			"name": "Local Contact",
			"type": "civilian",
			"level": "minor",
			"risk": "low",
			"description": "Has odd jobs and local work available"
		})

	return patrons

func _generate_starting_threats(danger_level: int, world_type: String) -> Array[Dictionary]:
	## Generate starting threats based on danger level and world type
	var threats: Array[Dictionary] = []

	# Base threat from danger level
	if danger_level >= 3:
		threats.append({
			"name": "Pirate Activity",
			"type": "criminal",
			"level": "high" if danger_level >= 4 else "medium",
			"description": "Raiders operating in the sector"
		})

	# World-type specific threats
	match world_type:
		"desert", "volcanic":
			threats.append({
				"name": "Harsh Environment",
				"type": "environmental",
				"level": "medium",
				"description": "Extreme conditions reduce crew recovery"
			})
		"frontier":
			threats.append({
				"name": "Unexplored Hazards",
				"type": "environmental",
				"level": "low",
				"description": "Unknown dangers in uncharted regions"
			})
		"industrial":
			if danger_level >= 2:
				threats.append({
					"name": "Corporate Rivals",
					"type": "faction",
					"level": "medium",
					"description": "Competing interests may cause conflicts"
				})

	# High danger always has rival presence
	if danger_level >= 4:
		threats.append({
			"name": "Rival Crew",
			"type": "rival",
			"level": "high",
			"description": "An established rival operates in this area"
		})

	# Ensure at least a minor threat for flavor
	if threats.is_empty():
		threats.append({
			"name": "Minor Criminal Element",
			"type": "criminal",
			"level": "low",
			"description": "Petty criminals and opportunists"
		})

	return threats

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
			if world_state is Dictionary and not world_state.is_empty():
				current_world_data = world_state
				_display_world_data(current_world_data)
				
				# Update generation state based on existing data
				is_world_generated = not current_world_data.is_empty()
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
	
	# Trigger initial sync
	sync_with_coordinator()

func sync_with_coordinator() -> void:
	## Sync panel with coordinator state
	if not coordinator:
		return
	
	
	# Get campaign state from coordinator
	var campaign_state = {}
	if coordinator.has_method("get_unified_campaign_state"):
		campaign_state = coordinator.get_unified_campaign_state()
	elif coordinator.has_method("get_state"):
		campaign_state = coordinator.get_state()
	
	# If we have campaign data and no world yet, generate one
	if not campaign_state.is_empty() and current_world_data.is_empty():
		_generate_world_from_campaign_data(campaign_state)
	
	# Update display with any existing world data
	var world_data = campaign_state.get("world", {})
	if not world_data.is_empty():
		current_world_data = world_data
		_display_world_data(world_data)
	elif current_world_data.is_empty():
		# Generate a default world if nothing exists
		_generate_default_world()
	

func _generate_default_world() -> void:
	## Generate a default world when no campaign data is available
	
	# Use the starter-friendly template
	var default_world = WORLD_TEMPLATES["starter_friendly"].duplicate(true)
	
	# Add some randomization
	var world_names = ["Haven Station", "Frontier Post", "New Horizon", "Liberty Station", "Echo Base"]
	default_world["name"] = world_names[randi() % world_names.size()]
	
	# Apply the world data
	current_world_data = default_world
	_display_world_data(default_world)
	
	# Update coordinator
	if coordinator and coordinator.has_method("update_world_state"):
		coordinator.update_world_state(default_world)


func _debug_button_state() -> void:
	## Debug function to verify button creation and state (output removed for release)
	pass

