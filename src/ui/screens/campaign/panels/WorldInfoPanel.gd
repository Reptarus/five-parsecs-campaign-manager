@tool
extends FiveParsecsCampaignPanel

## World Information Panel - Current world status and opportunities display
## Integrates with enhanced data manager following Digital Dice System visual patterns
## Provides comprehensive world information with contextual data display

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
var world_generator: Node = null
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

# Direct signal connections - production-ready pattern
var world_data_updated: bool = false
var world_generated: bool = false  # Track if world has been generated
var world_confirmed: bool = false  # Track if user confirmed the world

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
	
	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")
	
	# Initialize world generation system
	_initialize_world_generator()
	
	# Initialize world panel-specific functionality
	_setup_world_panel()
	
	# Defer button setup to ensure scene is fully loaded
	call_deferred("_setup_control_buttons")
	
	# Debug verification of button creation
	call_deferred("_verify_button_creation")
	
	_connect_campaign_signals()
	_apply_responsive_layout()

func _verify_button_creation() -> void:
	"""Verify buttons were created and added correctly"""
	print("\n🔍 BUTTON CREATION VERIFICATION")
	print("Generate Button Exists: %s" % (generate_button != null))
	print("Reroll Button Exists: %s" % (reroll_button != null))
	print("Confirm Button Exists: %s" % (confirm_button != null))
	
	if generate_button and generate_button.is_inside_tree():
		print("✅ Buttons successfully added to scene tree")
	else:
		print("❌ Buttons NOT in scene tree - check Content container path")
	print("")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup world panel-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_world_generator() -> void:
	"""Initialize WorldGenerator with defensive error handling"""
	if not WorldGenerator:
		push_error("WorldInfoPanel: WorldGenerator preload failed")
		return
	
	world_generator = WorldGenerator.new()
	if not world_generator:
		push_error("WorldInfoPanel: Failed to create WorldGenerator instance")
		return
		
	add_child(world_generator)
	
	# Connect world generation signal with defensive check
	if world_generator.has_signal("world_generated"):
		world_generator.world_generated.connect(_on_world_generated_from_generator)
		print("WorldInfoPanel: WorldGenerator initialized and connected")
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
	"""Create and setup control buttons for world generation"""
	print("WorldInfoPanel: Setting up control buttons")
	
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
	button_container.add_theme_constant_override("separation", 20)
	
	# Create Generate World button
	generate_button = Button.new()
	generate_button.text = "Generate World"
	generate_button.custom_minimum_size = Vector2(150, 40)
	generate_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	generate_button.pressed.connect(_on_generate_button_pressed)
	button_container.add_child(generate_button)
	
	# Create Reroll button (initially disabled)
	reroll_button = Button.new()
	reroll_button.text = "Reroll World"
	reroll_button.custom_minimum_size = Vector2(150, 40)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_button.disabled = true
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	button_container.add_child(reroll_button)
	
	# Create Confirm button (initially disabled)
	confirm_button = Button.new()
	confirm_button.text = "Confirm World"
	confirm_button.custom_minimum_size = Vector2(150, 40)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	button_container.add_child(confirm_button)
	
	# Add button container to the Content VBoxContainer
	content_container.add_child(button_container)
	
	# Move to bottom of content if possible
	content_container.move_child(button_container, content_container.get_child_count() - 1)
	
	print("WorldInfoPanel: Control buttons created and added to Content container")

func _on_generate_button_pressed() -> void:
	"""Handle generate world button press"""
	print("WorldInfoPanel: Generate button pressed")
	
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
	world_generated = true
	world_confirmed = false
	
	# Update validation
	_update_validation_state()

func _on_reroll_button_pressed() -> void:
	"""Handle reroll world button press"""
	print("WorldInfoPanel: Reroll button pressed")
	
	# Generate a new world with different seed
	var campaign_name = _get_campaign_name_safe()
	var world_suffix = ["Alpha", "Beta", "Gamma", "Delta", "Prime", "Nova", "Echo", "Zeta"].pick_random()
	_generate_world_with_fallback(campaign_name + " " + world_suffix)
	
	# Keep confirm button enabled
	world_generated = true
	world_confirmed = false
	
	# Update validation
	_update_validation_state()

func _on_confirm_button_pressed() -> void:
	"""Handle confirm world button press"""
	print("WorldInfoPanel: Confirm button pressed")
	
	# Mark world as confirmed
	world_confirmed = true
	
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
	if world_confirmed and not current_world_data.is_empty():
		panel_completed.emit(get_panel_data())
		print("WorldInfoPanel: World confirmed and panel completed")

func _get_campaign_name_safe() -> String:
	"""Safely get campaign name from coordinator or use default"""
	if coordinator and coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		var campaign_config = state.get("campaign_config", {})
		return campaign_config.get("campaign_name", "New Campaign")
	return "New Campaign"

func _update_validation_state() -> void:
	"""Update validation state and emit signals"""
	var is_valid = validate_panel()
	panel_validation_changed.emit(is_valid)
	
	if is_valid:
		# Mark world data as complete
		current_world_data["is_complete"] = true
		
		# Update coordinator with world data
		if coordinator and coordinator.has_method("update_world_state"):
			coordinator.update_world_state(current_world_data)
	
	print("WorldInfoPanel: Validation state updated - Valid: %s" % is_valid)

func _connect_campaign_signals() -> void:
	# Connect to campaign signals - Framework Bible compliant
	campaign_signals = CampaignSignals.new()
	
	# Connect world-related signals
	campaign_signals.connect_signal_safely("world_discovered", self, "_on_world_discovered")
	campaign_signals.connect_signal_safely("location_explored", self, "_on_location_explored")
	campaign_signals.connect_signal_safely("patron_encountered", self, "_on_patron_encountered")
	campaign_signals.connect_signal_safely("rival_threat_identified", self, "_on_rival_threat_identified")
	campaign_signals.connect_signal_safely("trade_opportunity_identified", self, "_on_trade_opportunity_identified")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if world_traits_container:
		world_traits_container.custom_minimum_size.y = 100
		world_traits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if world_summary:
		world_summary.text = _generate_compact_world_summary()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if world_traits_container:
		world_traits_container.custom_minimum_size.y = 150
		world_traits_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if world_summary:
		world_summary.text = _generate_detailed_world_summary()

## Main world display update function
func update_world_display(world_name: String) -> void:
	"""Generate and display world data using WorldGenerator with fallback templates"""
	print("WorldInfoPanel: Updating world display for: %s" % world_name)
	
	# Generate world if not already generated
	if current_world_data.is_empty():
		print("WorldInfoPanel: No world data - generating new world")
		_generate_world_with_fallback(world_name)
	else:
		print("WorldInfoPanel: Using existing world data")
		_display_world_data(current_world_data)

func _generate_world_with_fallback(world_name: String) -> void:
	"""Generate world using WorldGenerator with defensive fallback"""
	if world_generator:
		print("WorldInfoPanel: Generating world using WorldGenerator")
		
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
		print("WorldInfoPanel: WorldGenerator not available - using fallback template")
		_use_fallback_world_template(world_name)

func _use_fallback_world_template(world_name: String) -> void:
	"""Use predefined world template as fallback"""
	var template_key = _select_appropriate_template()
	
	# Ensure template key exists before accessing
	if not WORLD_TEMPLATES.has(template_key):
		template_key = "balanced"  # Safe fallback
	
	var fallback_world = WORLD_TEMPLATES[template_key].duplicate(true)
	
	# Customize template with provided name - safe property access
	var original_name = fallback_world.get("name", "Unknown World")
	fallback_world["name"] = world_name if not world_name.is_empty() else original_name
	fallback_world["id"] = "fallback_" + str(Time.get_unix_time_from_system())
	
	print("WorldInfoPanel: Using fallback template: %s" % template_key)
	_on_world_generated_from_generator(fallback_world)

func _select_appropriate_template() -> String:
	"""Select appropriate world template based on crew size/difficulty"""
	# Try to get crew data to adjust difficulty - with defensive null checks
	if get_parent() != null:
		var campaign_ui = owner if owner != null else get_parent().get_parent()
		if campaign_ui and campaign_ui.has_method("get_coordinator"):
			var coordinator = campaign_ui.get_coordinator()
			if coordinator and coordinator.has_method("get_unified_campaign_state"):
				var state = coordinator.get_unified_campaign_state()
				if state and state.has("crew"):
					var crew_size = state.crew.get("members", []).size()
					
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
	"""Display world data in UI components with DataValidator safety"""
	# Use DataValidator for safe access to world data
	var safe_traits = DataValidator.safe_get_array(world_data, "traits", [])
	var safe_government = DataValidator.safe_get_string(world_data, "government_type", "Independent Colony")
	var safe_tech_level = DataValidator.safe_get_int(world_data, "tech_level", 3)
	var safe_patrons = DataValidator.safe_get_array(world_data, "known_patrons", [])
	var safe_market_prices = DataValidator.safe_get_dict(world_data, "market_prices", {})
	var safe_threats = DataValidator.safe_get_array(world_data, "rival_threats", [])
	
	_display_world_traits(safe_traits)
	_display_government_info(safe_government, safe_tech_level)
	_display_opportunities(safe_patrons, safe_market_prices)
	_display_threats(safe_threats)
	_update_world_summary()
	
	print("WorldInfoPanel: World data displayed successfully with DataValidator safety")

func _display_world_traits(world_features: Array) -> void:
	if not world_traits_container:
		return
	
	# Clear existing world features
	for child in world_traits_container.get_children():
		child.queue_free()
	
	# Add world feature displays
	for feature in world_features:
		var feature_label = Label.new()
		feature_label.text = "• %s" % feature
		feature_label.add_theme_color_override("font_color", UIColors.INFO_COLOR)
		world_traits_container.add_child(feature_label)

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
	for child in opportunities_container.get_children():
		child.queue_free()
	
	# Add patron opportunities
	for patron in known_patrons:
		var patron_card = _create_opportunity_card(patron, "patron")
		if patron_card:
			opportunities_container.add_child(patron_card)
	
	# Add trade opportunities
	for commodity in market_prices.keys():
		var price_data = market_prices[commodity]
		var trade_card = _create_opportunity_card({
			"type": "trade",
			"commodity": commodity,
			"price": price_data.get("current", 0),
			"trend": price_data.get("trend", "stable")
		}, "trade")
		if trade_card:
			opportunities_container.add_child(trade_card)

func _display_threats(rival_threats: Array) -> void:
	if not threats_container:
		return
	
	# Clear existing threats
	for child in threats_container.get_children():
		child.queue_free()
	
	# Add threat cards
	for threat in rival_threats:
		var threat_card = _create_threat_card(threat)
		if threat_card:
			threats_container.add_child(threat_card)

func _create_opportunity_card(opportunity_data: Dictionary, opportunity_type: String) -> Control:
	# Create opportunity card using PanelContainer
	var opportunity_card = PanelContainer.new()

	# Create label for opportunity display
	var opportunity_label = Label.new()
	opportunity_label.text = opportunity_data.get("name", "Unknown Opportunity")
	opportunity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opportunity_card.add_child(opportunity_label)

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

	# Create label for threat display
	var threat_label = Label.new()
	threat_label.text = threat_data.get("name", "Unknown Threat")
	threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	threat_card.add_child(threat_label)

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
	"""Safely get campaign turn for world generation difficulty scaling"""
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	if campaign_ui and campaign_ui.has_method("get_coordinator"):
		var coordinator = campaign_ui.get_coordinator()
		if coordinator and coordinator.has_method("get_unified_campaign_state"):
			var state = coordinator.get_unified_campaign_state()
			return state.get("campaign_turn", 1)
	return 1  # Default to turn 1

func _determine_government_type(world_data: Dictionary) -> String:
	"""Determine government type based on world traits and danger level"""
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
	"""Determine tech level based on world type and traits"""
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
	"""Handle world generated from WorldGenerator or fallback template"""
	print("WorldInfoPanel: World generated: %s" % world_data.get("name", "Unknown"))
	current_world_data = world_data
	_display_world_data(world_data)
	
	# Mark world as generated
	world_generated = true
	
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
	
	# Emit enhanced signal for other systems
	if campaign_signals:
		campaign_signals.emit_safe_signal("world_generated", [world_data])

func _send_world_data_to_coordinator(world_data: Dictionary) -> void:
	"""Send world data to coordinator for campaign state management"""
	if not coordinator:
		push_warning("WorldInfoPanel: No coordinator available for world data update")
		return
	
	# Update coordinator with world state
	if coordinator.has_method("update_world_state"):
		coordinator.update_world_state(world_data)
		print("WorldInfoPanel: World data sent to coordinator")
	else:
		push_warning("WorldInfoPanel: Coordinator missing update_world_state method")
	
	# Also emit panel data changed for UI updates
	var panel_data = get_panel_data()
	panel_data_changed.emit(panel_data)

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

## Helper functions
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

## Public API for external access
func get_current_world_data() -> Dictionary:
	return current_world_data

func get_selected_opportunity() -> String:
	return selected_opportunity

func get_world_opportunities_data() -> Array:
	return world_opportunities

func get_world_threats_data() -> Array:
	return world_threats

func refresh_display() -> void:
	if current_world_data.has("planet_name"):
		update_world_display(current_world_data.get("planet_name"))

## Required ICampaignCreationPanel implementations
func validate_panel() -> bool:
	"""Validate that a world has been generated and confirmed"""
	# World must be generated and confirmed to proceed
	var is_valid = world_generated and world_confirmed and not current_world_data.is_empty()
	
	if not world_generated:
		print("WorldInfoPanel: Validation failed - No world generated")
		validation_failed.emit("Please generate a world before proceeding")
		return false
	elif not world_confirmed:
		print("WorldInfoPanel: Validation failed - World not confirmed")
		validation_failed.emit("Please confirm your world selection before proceeding")
		return false
	elif current_world_data.is_empty():
		print("WorldInfoPanel: Validation failed - World data is empty")
		validation_failed.emit("World data is missing, please regenerate")
		return false
	
	print("WorldInfoPanel: Validation passed - World ready")
	return true

func get_panel_data() -> Dictionary:
	"""Return complete world data for campaign"""
	var panel_data = {
		"world": current_world_data,
		"opportunities": world_opportunities,
		"threats": world_threats,
		"selected_opportunity": selected_opportunity,
		"is_complete": world_confirmed
	}
	
	# Add metadata
	panel_data["metadata"] = {
		"generated_at": Time.get_unix_time_from_system(),
		"world_name": current_world_data.get("name", "Unknown"),
		"danger_level": current_world_data.get("danger_level", 0),
		"tech_level": current_world_data.get("tech_level", 0)
	}
	
	print("WorldInfoPanel: Returning panel data with world: %s" % current_world_data.get("name", "Unknown"))
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
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("WorldInfoPanel: No data to restore")
		return
	
	print("WorldInfoPanel: Restoring panel data: ", data.keys())
	
	# Restore world data
	if data.has("current_world") and data.current_world is Dictionary:
		current_world_data = data.current_world.duplicate()
		print("WorldInfoPanel: Restored world: ", current_world_data.get("name", "Unknown World"))
	
	# Restore opportunities
	if data.has("opportunities") and data.opportunities is Array:
		world_opportunities = data.opportunities.duplicate()
		print("WorldInfoPanel: Restored %d opportunities" % world_opportunities.size())
	
	# Restore threats
	if data.has("threats") and data.threats is Array:
		world_threats = data.threats.duplicate()
		print("WorldInfoPanel: Restored %d threats" % world_threats.size())
	
	# Update display with restored data
	if current_world_data.has("name"):
		update_world_display(current_world_data.get("name", "Unknown World"))
	
	print("WorldInfoPanel: Panel data restoration complete")

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""React to campaign state updates - setup initial world display"""
	print("WorldInfoPanel: Campaign state updated")
	
	# Store campaign data for world generation
	var campaign_data = state_data.duplicate()
	
	# Extract any existing world data
	if state_data.has("world") and state_data.world is Dictionary and not state_data.world.is_empty():
		var existing_world = state_data.world
		if existing_world.has("name") and not existing_world.name.is_empty():
			print("WorldInfoPanel: Found existing world data: %s" % existing_world.get("name"))
			current_world_data = existing_world
			_display_world_data(current_world_data)
			
			# Update button states for existing world
			world_generated = true
			world_confirmed = existing_world.get("is_complete", false)
			
			if generate_button:
				generate_button.disabled = true
			if reroll_button:
				reroll_button.disabled = not world_confirmed
			if confirm_button:
				confirm_button.disabled = world_confirmed
				confirm_button.text = "✓ World Confirmed" if world_confirmed else "Confirm World"
			
			_update_validation_state()
			return
	
	# Always adjust world generation parameters based on campaign data
	_adjust_world_generation_parameters(campaign_data)
	
	# Update danger modifier display if we have crew data
	if campaign_data.has("crew"):
		var crew_data = campaign_data.get("crew", {})
		var crew_size = crew_data.get("members", []).size()
		var captain_data = campaign_data.get("captain", {})
		var captain_background = captain_data.get("background", "")
		
		var danger_modifier = _calculate_danger_level(crew_size, captain_background)
		print("WorldInfoPanel: Set danger modifier to %d based on crew size %d and captain %s" % [danger_modifier, crew_size, captain_background])

func _generate_world_from_campaign_data(campaign_data: Dictionary) -> void:
	"""Generate world based on accumulated campaign data from previous panels"""
	print("WorldInfoPanel: Generating world from campaign data")
	
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
	var captain_background = captain_data.get("background", "")
	var ship_type = ship_data.get("type", "")
	
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
		"known_patrons": [],
		"market_prices": _generate_market_prices(tech_level),
		"rival_threats": []
	}
	
	# Apply generated world
	current_world_data = world_data
	_display_world_data(world_data)
	
	# Send to coordinator
	_send_world_data_to_coordinator(world_data)
	
	print("WorldInfoPanel: World generation complete: %s" % world_name)

func _adjust_world_generation_parameters(campaign_data: Dictionary) -> void:
	"""Adjust world generator parameters based on campaign data"""
	if not world_generator:
		return
	
	var crew_data = campaign_data.get("crew", {})
	var captain_data = campaign_data.get("captain", {})
	
	# Adjust danger based on crew size
	var crew_size = crew_data.get("members", []).size()
	var danger_modifier = clamp(5 - crew_size, 0, 2)  # Smaller crews = higher danger
	
	# Adjust based on captain background
	var captain_background = captain_data.get("background", "")
	if captain_background in ["military", "veteran"]:
		danger_modifier = max(0, danger_modifier - 1)  # Military reduces danger
	elif captain_background in ["academic", "diplomat"]:
		danger_modifier += 1  # Non-combat backgrounds increase danger
	
	# Apply adjustments if world generator supports them
	if world_generator.has_method("set_danger_level_modifier"):
		world_generator.set_danger_level_modifier(danger_modifier)
		print("WorldInfoPanel: Set danger modifier to %d based on crew size %d and captain %s" % [danger_modifier, crew_size, captain_background])

func _determine_world_type_from_campaign(captain_background: String, ship_type: String) -> String:
	"""Determine appropriate world type based on campaign background"""
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
	"""Calculate appropriate danger level based on crew composition"""
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
	"""Determine tech level based on campaign data"""
	var base_tech = 3  # Standard tech level
	
	var captain_data = campaign_data.get("captain", {})
	var captain_background = captain_data.get("background", "")
	
	match captain_background:
		"academic", "scientist":
			base_tech += 1  # Academics prefer high-tech worlds
		"trader", "merchant":
			base_tech += 0  # Traders are neutral
		"frontier", "explorer":
			base_tech -= 1  # Frontier types prefer low-tech worlds
	
	return clamp(base_tech, 1, 6)

func _get_world_type_display_name(world_type: String) -> String:
	"""Get display name for world type"""
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
	"""Determine government type based on world characteristics"""
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
	"""Generate appropriate world traits"""
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
	"""Generate starting locations based on world characteristics"""
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
	"""Generate special features based on campaign characteristics"""
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
	"""Generate market prices based on tech level"""
	var prices = {}
	
	# Base prices modified by tech level
	var tech_modifier = (tech_level - 3) * 0.1  # +/- 10% per tech level from 3
	
	prices["food"] = {"current": int(10 * (1.0 + tech_modifier)), "trend": "stable"}
	prices["equipment"] = {"current": int(25 * (1.0 - tech_modifier)), "trend": "stable"}
	prices["fuel"] = {"current": int(15 * (1.0 + tech_modifier * 0.5)), "trend": "stable"}
	
	return prices

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: WorldInfoPanel] INITIALIZATION ====")
	print("  Phase: 6 of 7 (World Generation)")
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
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var sector_manager = get_node_or_null("/root/SectorManager")
	
	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    SectorManager: %s" % (sector_manager != null))
	
	# Check current world data
	print("  === INITIAL WORLD DATA ===")
	print("    Current World Data Keys: %s" % str(current_world_data.keys()))
	print("    World Opportunities: %d" % world_opportunities.size())
	print("    World Threats: %d" % world_threats.size())
	print("    Selected Opportunity: '%s'" % selected_opportunity)
	print("    World Data Updated: %s" % world_data_updated)
	
	# Check UI component availability  
	print("  === UI COMPONENTS ===")
	print("    World Name Label: %s" % (world_name_label != null))
	print("    Government Info: %s" % (government_info != null))
	print("    Tech Level Display: %s" % (tech_level_display != null))
	print("    Campaign Signals: %s" % (campaign_signals != null))
	
	print("==== [PANEL: WorldInfoPanel] INIT COMPLETE ====\n")

## Coordinator Integration Methods

func set_coordinator(coord: Node) -> void:
	"""Set coordinator reference with robust error handling and signal connections"""
	if not coord:
		push_error("WorldInfoPanel: Attempted to set null coordinator")
		return
		
	coordinator = coord
	print("WorldInfoPanel: Coordinator set")
	
	# Connect to coordinator's campaign state updates with safety checks
	if coordinator.has_signal("campaign_state_updated"):
		if not coordinator.campaign_state_updated.is_connected(_on_campaign_state_updated):
			coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
			print("WorldInfoPanel: Connected to coordinator campaign_state_updated signal")
	else:
		push_warning("WorldInfoPanel: Coordinator missing campaign_state_updated signal")
	
	# Sync with phase key for state management
	if panel_phase_key.is_empty():
		panel_phase_key = "world"
	
	# Sync existing state if available
	_sync_with_coordinator()
	
	print("WorldInfoPanel: Syncing with coordinator - phase key: %s" % panel_phase_key)

func _sync_with_coordinator() -> void:
	"""Synchronize with coordinator's current state"""
	if not coordinator:
		return
		
	if coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		if state and state.has("world"):
			var world_state = state.get("world", {})
			if world_state is Dictionary and not world_state.is_empty():
				print("WorldInfoPanel: Received world state update with keys: %s" % str(world_state.keys()))
				current_world_data = world_state
				_display_world_data(current_world_data)
				
				# Update generation state based on existing data
				world_generated = not current_world_data.is_empty()
				world_confirmed = world_state.get("is_complete", false)
				
				# Update button states
				_update_button_states()
	
	print("WorldInfoPanel: Synced with coordinator - phase key: %s" % panel_phase_key)

func _update_button_states() -> void:
	"""Update control button states based on current world status"""
	if generate_button:
		generate_button.disabled = world_generated
	
	if reroll_button:
		reroll_button.disabled = not world_generated or world_confirmed
	
	if confirm_button:
		confirm_button.disabled = not world_generated or world_confirmed
		confirm_button.text = "✓ World Confirmed" if world_confirmed else "Confirm World"
	
	# Trigger initial sync
	sync_with_coordinator()

func sync_with_coordinator() -> void:
	"""Sync panel with coordinator state"""
	if not coordinator:
		print("WorldInfoPanel: No coordinator available for sync")
		return
	
	print("WorldInfoPanel: Syncing with coordinator - phase key: %s" % panel_phase_key)
	
	# Get campaign state from coordinator
	var campaign_state = {}
	if coordinator.has_method("get_unified_campaign_state"):
		campaign_state = coordinator.get_unified_campaign_state()
	elif coordinator.has_method("get_state"):
		campaign_state = coordinator.get_state()
	
	# If we have campaign data and no world yet, generate one
	if not campaign_state.is_empty() and current_world_data.is_empty():
		print("WorldInfoPanel: Generating world from campaign state")
		_generate_world_from_campaign_data(campaign_state)
	
	# Update display with any existing world data
	var world_data = campaign_state.get("world", {})
	if not world_data.is_empty():
		print("WorldInfoPanel: Received world state update with keys: %s" % str(world_data.keys()))
		current_world_data = world_data
		_display_world_data(world_data)
	elif current_world_data.is_empty():
		# Generate a default world if nothing exists
		print("WorldInfoPanel: No world data found - generating default world")
		_generate_default_world()
	
	print("WorldInfoPanel: Synced with coordinator - phase key: %s" % panel_phase_key)

func _generate_default_world() -> void:
	"""Generate a default world when no campaign data is available"""
	print("WorldInfoPanel: Generating default starter world")
	
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
		print("WorldInfoPanel: ✅ Updated coordinator with default world data")


func _debug_button_state() -> void:
	"""Debug function to verify button creation and state"""
	print("\n==== WORLD PANEL BUTTON DEBUG ====")
	print("Generate Button: %s (Disabled: %s)" % [generate_button != null, 
	generate_button.disabled if generate_button else "N/A"])
	print("Reroll Button: %s (Disabled: %s)" % [reroll_button != null, 
	reroll_button.disabled if reroll_button else "N/A"])
	print("Confirm Button: %s (Disabled: %s)" % [confirm_button != null, 
	confirm_button.disabled if confirm_button else "N/A"])
	
	# Check if buttons are in scene tree
	if generate_button and generate_button.is_inside_tree():
		print("Generate button is in scene tree at: %s" % generate_button.get_path())                                                                                                 
	
	# Check Content container
	var content = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")        
	if content:
		print("Content container has %d children" % content.get_child_count())     
		for i in range(content.get_child_count()):
			var child = content.get_child(i)
			print("  Child %d: %s (%s)" % [i, child.name, child.get_class()])
	else:
		print("Content container not found!")

	print("World Generated: %s, World Confirmed: %s" % [world_generated, world_confirmed])
	print("==== END DEBUG ====\n")
