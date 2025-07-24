@tool
extends Control
class_name BaseEnhancedComponents

## Base Enhanced Components - Reusable UI components following dice system visual patterns
## Provides consistent visual language and responsive design across all enhanced features
## Follows Digital Dice System color coding and animation patterns

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

# Crew stats card following dice system design
class CrewStatsCard extends BaseInformationCard:
	@onready var health_bar: ProgressBar = %HealthBar
	@onready var stats_container: VBoxContainer = %StatsContainer
	@onready var status_indicator: Control = %StatusIndicator
	
	func display_data(crew_data: Dictionary) -> void:
		# Copy dice system visual patterns
		_apply_health_color_coding(crew_data.get("health_ratio", 1.0))
		set_context_label("Crew Member: %s" % crew_data.get("name", "Unknown"))
		_display_stats_with_context(crew_data.get("stats", {}))
		_update_status_indicator(crew_data.get("status", "active"))
	
	func _apply_health_color_coding(health_ratio: float) -> void:
		if not health_bar:
			return
		
		health_bar.value = health_ratio * 100
		
		# Color coding from dice system
		if health_ratio > 0.7:
			health_bar.modulate = BaseInformationCard.SUCCESS_COLOR
		elif health_ratio > 0.3:
			health_bar.modulate = BaseInformationCard.WARNING_COLOR
		else:
			health_bar.modulate = BaseInformationCard.DANGER_COLOR
	
	func _display_stats_with_context(stats: Dictionary) -> void:
		if not stats_container:
			return
		
		# Clear existing stats
		for child in stats_container.get_children():
			child.queue_free()
		
		# Add stat displays with context
		for stat_name in stats:
			var stat_label = Label.new()
			stat_label.text = "%s: %s" % [stat_name.capitalize(), str(stats[stat_name])]
			stat_label.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
			stats_container.add_child(stat_label)
	
	func _update_status_indicator(status: String) -> void:
		if not status_indicator:
			return
		
		match status.to_lower():
			"active", "healthy":
				status_indicator.modulate = BaseInformationCard.SUCCESS_COLOR
			"wounded", "injured":
				status_indicator.modulate = BaseInformationCard.WARNING_COLOR
			"critical", "unconscious":
				status_indicator.modulate = BaseInformationCard.DANGER_COLOR
			_:
				status_indicator.modulate = BaseInformationCard.NEUTRAL_COLOR
	
	func get_context_label() -> String:
		return "Crew Member"
	
	func get_card_type() -> String:
		return "crew"

# Ship status panel with responsive design
class ShipStatusPanel extends FPCM_CampaignResponsiveLayout:
	@onready var hull_display: ProgressBar = %HullDisplay
	@onready var fuel_display: ProgressBar = %FuelDisplay
	@onready var cargo_display: ProgressBar = %CargoDisplay
	@onready var debt_display: Label = %DebtDisplay
	@onready var modifications_list: VBoxContainer = %ModificationsList
	
	func display_ship_status(ship_data: Dictionary) -> void:
		# Hull status with visual bar (like dice system animations)
		if hull_display:
			hull_display.animate_to_value(ship_data.get("hull_current", 100), ship_data.get("hull_max", 100))
		
		# Fuel status
		if fuel_display:
			fuel_display.animate_to_value(ship_data.get("fuel_current", 100), ship_data.get("fuel_max", 100))
		
		# Cargo status
		if cargo_display:
			cargo_display.animate_to_value(ship_data.get("cargo_used", 0), ship_data.get("cargo_capacity", 100))
		
		# Debt status with color coding (dice system colors)
		if debt_display:
			var debt_amount = ship_data.get("debt_amount", 0)
			debt_display.text = "Debt: %d credits" % debt_amount
			_apply_debt_color_coding(debt_display, debt_amount)
		
		# Modifications list with context
		_update_modifications_display(ship_data.get("modifications", []))
	
	func _calculate_debt_warning(debt_amount: int) -> String:
		if debt_amount > 10000:
			return "critical"
		elif debt_amount > 5000:
			return "warning"
		else:
			return "normal"
	
	func _apply_debt_color_coding(debt_display: Label, debt_amount: int) -> void:
		var warning_level = _calculate_debt_warning(debt_amount)
		match warning_level:
			"critical":
				debt_display.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
			"warning":
				debt_display.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
			_:
				debt_display.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
	
	func _update_modifications_display(modifications: Array) -> void:
		if not modifications_list:
			return
		
		# Clear existing modifications
		for child in modifications_list.get_children():
			child.queue_free()
		
		# Add modification entries
		for mod in modifications:
			var mod_label = Label.new()
			mod_label.text = "• %s" % mod.get("name", "Unknown Modification")
			mod_label.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
			modifications_list.add_child(mod_label)
	
	func _apply_portrait_layout() -> void:
		# Mobile-first compact layout
		_switch_to_compact_mode()
	
	func _apply_landscape_layout() -> void:
		# Desktop detailed layout
		_switch_to_detailed_mode()
	
	func _switch_to_compact_mode() -> void:
		# Compact layout for mobile
		if hull_display:
			hull_display.custom_minimum_size.y = 20
		if fuel_display:
			fuel_display.custom_minimum_size.y = 20
		if cargo_display:
			cargo_display.custom_minimum_size.y = 20
	
	func _switch_to_detailed_mode() -> void:
		# Detailed layout for desktop
		if hull_display:
			hull_display.custom_minimum_size.y = 30
		if fuel_display:
			fuel_display.custom_minimum_size.y = 30
		if cargo_display:
			cargo_display.custom_minimum_size.y = 30

# Quest tracker widget following dice system patterns
class FPCM_QuestTrackerWidget extends Control:
	@onready var quest_container: VBoxContainer = %QuestContainer
	@onready var progress_indicator: ProgressBar = %ProgressIndicator
	
	func update_quest_display(active_quests: Array) -> void:
		# Clear existing quest cards
		for child in quest_container.get_children():
			child.queue_free()
		
		for quest in active_quests:
			var quest_card = _create_quest_card(quest)
			quest_container.add_child(quest_card)
	
	func _create_quest_card(quest_data: Dictionary) -> Control:
		var card = BaseInformationCard.new()
		card.set_context_label("Quest: %s" % quest_data.get("name", "Unknown Quest"))
		card.display_data(quest_data)
		return card

# World information panel with enhanced data display
class FPCM_WorldInfoPanel extends FPCM_CampaignResponsiveLayout:
	@onready var world_traits_container: VBoxContainer = %WorldTraitsContainer
	@onready var government_info: Label = %GovernmentInfo
	@onready var opportunities_list: VBoxContainer = %OpportunitiesList
	@onready var market_prices: VBoxContainer = %MarketPrices
	
	func update_world_display(world_name: String) -> void:
		# TODO: Replace with actual data manager reference
		var world_data = {} # Placeholder for enhanced_data_manager.get_planet_data(world_name)
		
		if world_data:
			_display_world_traits(world_data.world_traits)
			_display_government_info(world_data.government_type, world_data.tech_level)
			_display_opportunities(world_data.known_patrons, world_data.market_prices)
		else:
			_show_unexplored_world_placeholder()
	
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
		if not government_info:
			return
		
		government_info.text = "Government: %s (Tech Level %d)" % [government_type, tech_level]
		government_info.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
	
	func _display_opportunities(patrons: Array[Dictionary], prices: Dictionary) -> void:
		if not opportunities_list:
			return
		
		# Clear existing opportunities
		for child in opportunities_list.get_children():
			child.queue_free()
		
		# Add patron opportunities
		for patron in patrons:
			var patron_label = Label.new()
			patron_label.text = "Patron: %s" % patron.get("name", "Unknown")
			patron_label.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
			opportunities_list.add_child(patron_label)
	
	func _show_unexplored_world_placeholder() -> void:
		if not world_traits_container:
			return
		
		# Clear existing content
		for child in world_traits_container.get_children():
			child.queue_free()
		
		# Show placeholder
		var placeholder_label = Label.new()
		placeholder_label.text = "World not yet explored"
		placeholder_label.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		world_traits_container.add_child(placeholder_label)

# Enhanced progress bar with dice system animations
class EnhancedProgressBar extends ProgressBar:
	@export var animation_duration: float = 0.5
	@export var show_percentage_label: bool = true
	@export var color_coding_enabled: bool = true
	
	func animate_to_value(new_value: float, max_value: float = 100.0) -> void:
		max_value = max_value
		var tween = create_tween()
		tween.tween_property(self, "value", new_value, animation_duration)
		
		if color_coding_enabled:
			_apply_color_coding(new_value / max_value)
	
	func _apply_color_coding(ratio: float) -> void:
		if ratio > 0.7:
			modulate = BaseInformationCard.SUCCESS_COLOR
		elif ratio > 0.3:
			modulate = BaseInformationCard.WARNING_COLOR
		else:
			modulate = BaseInformationCard.DANGER_COLOR

# Context-aware label following dice system patterns
class ContextLabel extends Label:
	@export var context_type: String = "info"
	@export var auto_color: bool = true
	
	func _ready() -> void:
		if auto_color:
			_apply_context_color()
	
	func _apply_context_color() -> void:
		match context_type.to_lower():
			"success", "positive":
				add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
			"warning", "caution":
				add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
			"danger", "negative":
				add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
			"info", "neutral":
				add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
			"highlight":
				add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
	
	func set_context_type(new_type: String) -> void:
		context_type = new_type
		_apply_context_color()

# Touch-friendly button following responsive design patterns
class TouchButton extends Button:
	@export var touch_target_size: Vector2 = Vector2(44, 44)
	@export var show_feedback: bool = true
	
	func _ready() -> void:
		add_to_group("touch_buttons")
		custom_minimum_size = touch_target_size
		
		if show_feedback:
			pressed.connect(_on_pressed_feedback)
	
	func _on_pressed_feedback() -> void:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# Utility functions for component creation
static func create_crew_stats_card() -> CrewStatsCard:
	return CrewStatsCard.new()

static func create_ship_status_panel() -> ShipStatusPanel:
	return ShipStatusPanel.new()

static func create_quest_tracker() -> FPCM_QuestTrackerWidget:
	return FPCM_QuestTrackerWidget.new()

static func create_world_info_panel() -> FPCM_WorldInfoPanel:
	return FPCM_WorldInfoPanel.new()

static func create_enhanced_progress_bar() -> EnhancedProgressBar:
	return EnhancedProgressBar.new()

static func create_context_label() -> ContextLabel:
	return ContextLabel.new()

static func create_touch_button() -> TouchButton:
	return TouchButton.new()