@tool
extends Control
class_name WorldInfoPanel

## World Information Panel - Current world status and opportunities display
## Integrates with enhanced data manager following Digital Dice System visual patterns
## Provides comprehensive world information with contextual data display

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

# UI References
@onready var world_name_label: Label = %WorldNameLabel
@onready var world_traits_container: VBoxContainer = %WorldTraitsContainer
@onready var government_info: Label = %GovernmentInfo
@onready var tech_level_display: Label = %TechLevelDisplay
@onready var market_prices_container: VBoxContainer = %MarketPricesContainer
@onready var opportunities_container: VBoxContainer = %OpportunitiesContainer
@onready var threats_container: VBoxContainer = %ThreatsContainer
@onready var world_summary: Label = %WorldSummary

# Data management
var current_world_data: Dictionary = {}
var world_opportunities: Array[Dictionary] = []
var world_threats: Array[Dictionary] = []
var selected_opportunity: String = ""

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_world_panel()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_world_panel() -> void:
	# Initialize world display components
	if not world_name_label:
		push_warning("WorldInfoPanel: World name label not found")
		return
	
	# Setup opportunity tracking
	_setup_opportunity_tracking()
	
	# Setup threat monitoring
	_setup_threat_monitoring()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect world-related signals
	enhanced_signals.connect_signal_safely("world_discovered", self, "_on_world_discovered")
	enhanced_signals.connect_signal_safely("location_explored", self, "_on_location_explored")
	enhanced_signals.connect_signal_safely("patron_encountered", self, "_on_patron_encountered")
	enhanced_signals.connect_signal_safely("rival_threat_identified", self, "_on_rival_threat_identified")
	enhanced_signals.connect_signal_safely("trade_opportunity_identified", self, "_on_trade_opportunity_identified")

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
	# TODO: Replace with actual data manager reference
	var world_data = {} # Placeholder for enhanced_data_manager.get_planet_data(world_name)
	
	if world_data:
		current_world_data = world_data
		_display_world_traits(world_data.get("world_traits", []))
		_display_government_info(world_data.get("government_type", ""), world_data.get("tech_level", 3))
		_display_opportunities(world_data.get("known_patrons", []), world_data.get("market_prices", {}))
		_display_threats(world_data.get("rival_threats", []))
	else:
		_show_unexplored_world_placeholder(world_name)
	
	_update_world_summary()

func _display_world_traits(world_features: Array[String]) -> void:
	if not world_traits_container:
		return
	
	# Clear existing world features
	for child in world_traits_container.get_children():
		child.queue_free()
	
	# Add world feature displays
	for feature in world_features:
		var feature_label = Label.new()
		feature_label.text = "• %s" % feature
		feature_label.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		world_traits_container.add_child(feature_label)

func _display_government_info(government_type: String, tech_level: int) -> void:
	if government_info:
		government_info.text = "Government: %s" % government_type
		government_info.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
	
	if tech_level_display:
		tech_level_display.text = "Tech Level: %d" % tech_level
		
		# Color coding based on tech level
		if tech_level >= 5:
			tech_level_display.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		elif tech_level >= 3:
			tech_level_display.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		else:
			tech_level_display.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)

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
	# Create opportunity card following dice system design
	var opportunity_card = BaseInformationCard.new()
	
	# Setup with safety validation
	opportunity_card.setup_with_safety_validation(opportunity_data)
	
	# Apply visual styling
	_apply_opportunity_styling(opportunity_card, opportunity_data, opportunity_type)
	
	# Connect opportunity card signals
	opportunity_card.card_selected.connect(_on_opportunity_card_selected)
	opportunity_card.card_action_requested.connect(_on_opportunity_action_requested)
	
	return opportunity_card

func _apply_opportunity_styling(opportunity_card: Control, opportunity_data: Dictionary, opportunity_type: String) -> void:
	var opportunity_level = opportunity_data.get("level", "normal")
	var risk_level = opportunity_data.get("risk", "low")
	
	# Color coding based on opportunity type and risk
	match opportunity_type:
		"patron":
			opportunity_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		"trade":
			opportunity_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		_:
			opportunity_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
	
	# Additional styling for high-risk opportunities
	if risk_level == "high":
		opportunity_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)

func _create_threat_card(threat_data: Dictionary) -> Control:
	# Create threat card following dice system design
	var threat_card = BaseInformationCard.new()
	
	# Setup with safety validation
	threat_card.setup_with_safety_validation(threat_data)
	
	# Apply visual styling
	_apply_threat_styling(threat_card, threat_data)
	
	# Connect threat card signals
	threat_card.card_selected.connect(_on_threat_card_selected)
	threat_card.card_action_requested.connect(_on_threat_action_requested)
	
	return threat_card

func _apply_threat_styling(threat_card: Control, threat_data: Dictionary) -> void:
	var threat_level = threat_data.get("level", "low")
	var threat_type = threat_data.get("type", "unknown")
	
	# Color coding based on threat level
	match threat_level:
		"critical":
			threat_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"high":
			threat_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"medium":
			threat_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		_:
			threat_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _show_unexplored_world_placeholder(world_name: String) -> void:
	if world_name_label:
		world_name_label.text = "World: %s (Unexplored)" % world_name
		world_name_label.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
	
	if world_summary:
		world_summary.text = "This world has not been explored yet. Send a mission to discover its secrets."

func _update_world_summary() -> void:
	if not world_summary:
		return
	
	var world_name = current_world_data.get("planet_name", "Unknown World")
	var tech_level = current_world_data.get("tech_level", 3)
	var opportunities_count = world_opportunities.size()
	var threats_count = world_threats.size()
	
	# Update summary with contextual information
	world_summary.text = "World: %s | Tech Level %d | %d Opportunities, %d Threats" % [
		world_name, tech_level, opportunities_count, threats_count
	]

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
	enhanced_signals.emit_safe_signal("opportunity_selected", [selected_opportunity])

func _on_opportunity_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_threat_card_selected(card_data: Dictionary) -> void:
	var threat_id = card_data.get("threat_id", "")
	enhanced_signals.emit_safe_signal("threat_selected", [threat_id])

func _on_threat_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

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