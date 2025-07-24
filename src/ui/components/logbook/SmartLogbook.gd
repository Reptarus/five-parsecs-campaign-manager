@tool
extends Control
class_name SmartLogbook

## Smart Logbook UI Enhancement - Enhanced logbook with search, filtering, and prediction
## Follows Digital Dice System visual patterns and responsive design architecture
## Provides intelligent logbook interface with smart features

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
const LogbookDataManager = preload("res://src/core/logbook/LogbookDataManager.gd")

# Enhanced UI elements
@onready var search_bar: LineEdit = %SearchBar
@onready var filter_panel: Control = %FilterPanel
@onready var suggestions_panel: Control = %SuggestionsPanel
@onready var data_visualization: Control = %DataVisualization
@onready var logbook_entries: VBoxContainer = %LogbookEntries
@onready var search_results: VBoxContainer = %SearchResults
@onready var analysis_summary: Label = %AnalysisSummary

# Data management
var logbook_data_manager: LogbookDataManager
var current_search_results: Array = []
var active_filters: Dictionary = {}
var search_history: Array[String] = []
var suggestions_cache: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_smart_logbook()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_smart_logbook() -> void:
	# Initialize smart logbook components
	logbook_data_manager = LogbookDataManager.new()
	
	# Setup search and filtering
	_setup_search_features()
	_setup_filter_system()
	_setup_suggestion_system()
	_setup_visualization()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect logbook-related signals
	enhanced_signals.connect_signal_safely("logbook_search_performed", self, "_on_search_performed")
	enhanced_signals.connect_signal_safely("logbook_filter_applied", self, "_on_filter_applied")
	enhanced_signals.connect_signal_safely("predictive_suggestion_generated", self, "_on_suggestion_generated")
	enhanced_signals.connect_signal_safely("data_visualization_requested", self, "_on_visualization_requested")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if search_bar:
		search_bar.custom_minimum_size.y = 44 # Touch-friendly height
		search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if logbook_entries:
		logbook_entries.custom_minimum_size.y = 300
		logbook_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if search_bar:
		search_bar.custom_minimum_size.y = 32
		search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if logbook_entries:
		logbook_entries.custom_minimum_size.y = 400
		logbook_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Main logbook update function
func update_logbook_display() -> void:
	# Update logbook with current data
	_display_logbook_entries()
	_update_analysis_summary()
	_generate_suggestions()

func _display_logbook_entries() -> void:
	if not logbook_entries:
		return
	
	# Clear existing entries
	for child in logbook_entries.get_children():
		child.queue_free()
	
	# Get all logbook data
	var missions = logbook_data_manager.get_mission_archive()
	var planets = logbook_data_manager.get_planet_profiles()
	var relationships = logbook_data_manager.get_relationship_history()
	var economic_data = logbook_data_manager.get_economic_data()
	
	# Create entry cards for each data type
	_create_mission_entries(missions)
	_create_planet_entries(planets)
	_create_relationship_entries(relationships)
	_create_economic_entries(economic_data)

func _create_mission_entries(missions: Array) -> void:
	for mission in missions:
		var mission_card = _create_logbook_entry_card(mission, "mission")
		if mission_card:
			logbook_entries.add_child(mission_card)

func _create_planet_entries(planets: Dictionary) -> void:
	for planet_name in planets.keys():
		var planet = planets[planet_name]
		var planet_card = _create_logbook_entry_card(planet, "planet")
		if planet_card:
			logbook_entries.add_child(planet_card)

func _create_relationship_entries(relationships: Dictionary) -> void:
	for entity_name in relationships.keys():
		var entity_relationships = relationships[entity_name]
		for relationship in entity_relationships:
			var relationship_card = _create_logbook_entry_card(relationship, "relationship")
			if relationship_card:
				logbook_entries.add_child(relationship_card)

func _create_economic_entries(economic_data: Dictionary) -> void:
	for timestamp in economic_data.keys():
		var entry = economic_data[timestamp]
		var economic_card = _create_logbook_entry_card(entry, "economic")
		if economic_card:
			logbook_entries.add_child(economic_card)

func _create_logbook_entry_card(data: Variant, entry_type: String) -> Control:
	# Create logbook entry card following dice system design
	var entry_card = BaseInformationCard.new()
	
	# Setup with safety validation
	entry_card.setup_with_safety_validation(data)
	
	# Apply visual styling based on entry type
	_apply_entry_styling(entry_card, data, entry_type)
	
	# Set context information
	_set_entry_context(entry_card, data, entry_type)
	
	# Connect entry card signals
	entry_card.card_selected.connect(_on_entry_card_selected)
	entry_card.card_action_requested.connect(_on_entry_action_requested)
	
	return entry_card

func _apply_entry_styling(entry_card: Control, data: Variant, entry_type: String) -> void:
	# Apply color coding based on entry type (dice system colors)
	match entry_type:
		"mission":
			var outcome = data.get("outcome", "unknown")
			match outcome:
				"success":
					entry_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
				"failure":
					entry_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
				_:
					entry_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
		"planet":
			var tech_level = data.get("tech_level", 3)
			if tech_level >= 5:
				entry_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
			elif tech_level >= 3:
				entry_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
			else:
				entry_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"relationship":
			entry_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		"economic":
			var credits = data.get("credits", 0)
			var debt = data.get("debt", 0)
			if credits > debt:
				entry_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
			elif debt > credits * 2:
				entry_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
			else:
				entry_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)

func _set_entry_context(entry_card: Control, data: Variant, entry_type: String) -> void:
	# Set contextual information for the entry
	match entry_type:
		"mission":
			entry_card.set_context_label("Mission: %s (%s)" % [
				data.get("mission_id", "Unknown"),
				data.get("outcome", "Unknown")
			])
		"planet":
			entry_card.set_context_label("Planet: %s (Tech %d)" % [
				data.get("planet_name", "Unknown"),
				data.get("tech_level", 3)
			])
		"relationship":
			entry_card.set_context_label("Relationship: %s" % data.get("entity", "Unknown"))
		"economic":
			entry_card.set_context_label("Economic: %d Credits, %d Debt" % [
				data.get("credits", 0),
				data.get("debt", 0)
			])

## Search functionality
func _setup_search_features() -> void:
	if search_bar:
		search_bar.placeholder_text = "Search missions, planets, contacts..."
		search_bar.text_submitted.connect(_on_search_submitted)

func _on_search_submitted(search_term: String) -> void:
	if search_term.is_empty():
		return
	
	# Add to search history
	if search_term not in search_history:
		search_history.append(search_term)
	
	# Perform search
	var results = logbook_data_manager.search_logbook(search_term)
	current_search_results = results
	
	# Display search results
	_display_search_results(results)
	
	# Generate suggestions based on search
	_generate_search_suggestions(search_term)

func _display_search_results(results: Array) -> void:
	if not search_results:
		return
	
	# Clear existing results
	for child in search_results.get_children():
		child.queue_free()
	
	# Display results
	for result in results:
		var result_card = _create_logbook_entry_card(result, _determine_entry_type(result))
		if result_card:
			search_results.add_child(result_card)

func _determine_entry_type(data: Variant) -> String:
	# Determine the type of logbook entry
	if data.has("mission_id"):
		return "mission"
	elif data.has("planet_name"):
		return "planet"
	elif data.has("entity"):
		return "relationship"
	elif data.has("credits"):
		return "economic"
	else:
		return "unknown"

## Filter functionality
func _setup_filter_system() -> void:
	if filter_panel:
		_setup_filter_buttons()

func _setup_filter_buttons() -> void:
	# Setup filter buttons following touch-friendly patterns
	var filter_types = ["missions", "planets", "relationships", "economic"]
	
	for filter_type in filter_types:
		var filter_button = Button.new()
		filter_button.text = filter_type.capitalize()
		filter_button.custom_minimum_size = Vector2(80, 44) # Touch-friendly
		filter_button.pressed.connect(_on_filter_button_pressed.bind(filter_type))
		filter_panel.add_child(filter_button)

func _on_filter_button_pressed(filter_type: String) -> void:
	# Toggle filter
	if active_filters.has(filter_type):
		active_filters.erase(filter_type)
	else:
		active_filters[filter_type] = true
	
	# Apply filters
	_apply_active_filters()

func _apply_active_filters() -> void:
	var filtered_results: Array = []
	
	for filter_type in active_filters.keys():
		var results = logbook_data_manager.search_logbook("", filter_type)
		filtered_results.append_array(results)
	
	# Display filtered results
	_display_search_results(filtered_results)
	
	# Emit filter signal
	enhanced_signals.emit_safe_signal("logbook_filter_applied", ["type", active_filters])

## Suggestion system
func _setup_suggestion_system() -> void:
	if suggestions_panel:
		_setup_suggestion_buttons()

func _setup_suggestion_buttons() -> void:
	# Setup suggestion buttons
	pass

func _generate_suggestions() -> void:
	# Generate intelligent suggestions based on current data
	var analysis = logbook_data_manager.analyze_campaign_patterns()
	
	# Generate suggestions based on analysis
	var suggestions: Array = []
	
	if analysis.has("mission_success_rate"):
		var success_rate = analysis.mission_success_rate
		if success_rate.success_rate < 0.5:
			suggestions.append("Consider improving crew training")
	
	if analysis.has("economic_trends"):
		var trends = analysis.economic_trends
		if trends.trend == "declining":
			suggestions.append("Focus on profitable missions")
	
	# Display suggestions
	_display_suggestions(suggestions)

func _generate_search_suggestions(search_term: String) -> void:
	# Generate suggestions based on search term
	var suggestions: Array = []
	
	# Simple suggestion logic based on search term
	if "mission" in search_term.to_lower():
		suggestions.append("Try filtering by mission type")
	elif "planet" in search_term.to_lower():
		suggestions.append("Explore world details")
	elif "credit" in search_term.to_lower():
		suggestions.append("Check economic trends")
	
	# Display suggestions
	_display_suggestions(suggestions)

func _display_suggestions(suggestions: Array) -> void:
	if not suggestions_panel:
		return
	
	# Clear existing suggestions
	for child in suggestions_panel.get_children():
		child.queue_free()
	
	# Display suggestions
	for suggestion in suggestions:
		var suggestion_label = Label.new()
		suggestion_label.text = "💡 %s" % suggestion
		suggestion_label.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		suggestions_panel.add_child(suggestion_label)

## Visualization functionality
func _setup_visualization() -> void:
	if data_visualization:
		_setup_visualization_components()

func _setup_visualization_components() -> void:
	# Setup data visualization components
	pass

func _update_analysis_summary() -> void:
	if not analysis_summary:
		return
	
	# Update analysis summary
	var analysis = logbook_data_manager.analyze_campaign_patterns()
	
	var summary_text = "Analysis: "
	if analysis.has("mission_success_rate"):
		var success_rate = analysis.mission_success_rate
		summary_text += "%.1f%% Success Rate | " % (success_rate.success_rate * 100)
	
	if analysis.has("economic_trends"):
		var trends = analysis.economic_trends
		summary_text += "%s Economic Trend" % trends.trend.capitalize()
	
	analysis_summary.text = summary_text

## Signal handlers
func _on_search_performed(search_term: String, results: Array) -> void:
	current_search_results = results
	_display_search_results(results)

func _on_filter_applied(filter_type: String, filter_value: Variant) -> void:
	_apply_active_filters()

func _on_suggestion_generated(suggestion_type: String, data: Dictionary) -> void:
	# Handle generated suggestions
	_generate_suggestions()

func _on_visualization_requested(chart_type: String, data: Array) -> void:
	# Handle visualization requests
	pass

func _on_entry_card_selected(card_data: Dictionary) -> void:
	# Handle entry card selection
	var entry_id = card_data.get("entry_id", "")
	enhanced_signals.emit_safe_signal("logbook_entry_selected", [entry_id])

func _on_entry_action_requested(action: String, data: Variant) -> void:
	# Handle entry action requests
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

## Public API for external access
func get_logbook_data_manager() -> LogbookDataManager:
	return logbook_data_manager

func get_current_search_results() -> Array:
	return current_search_results

func get_active_filters() -> Dictionary:
	return active_filters

func refresh_display() -> void:
	update_logbook_display()