extends Control

## Five Parsecs Campaign Creation Crew Panel
## Production-ready implementation with hybrid data architecture integration

const Character = preload("res://src/core/character/Character.gd")
const UniversalResourceLoader = preload("res://src/core/systems/UniversalResourceLoader.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

signal crew_updated(crew: Array)
signal crew_setup_complete(crew_data: Dictionary)

# UI Components using safe access pattern
var crew_size_option: OptionButton
var crew_list: ItemList
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

## UI References
@onready var crew_container: VBoxContainer = %CrewContainer
@onready var crew_summary: Label = %CrewSummary
@onready var crew_status_overview: Control = %CrewStatusOverview
@onready var crew_performance_chart: Control = %CrewPerformanceChart
@onready var crew_equipment_summary: Control = %CrewEquipmentSummary

var crew_data: Array[Dictionary] = []
var selected_crew_member: String = ""
var crew_performance_data: Dictionary = {}
var selected_size: int = 4
var is_initialized: bool = false
var current_captain: Character = null
var character_creator: Node = null # Store reference to currently open character creator



# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	print("CrewPanel: Initializing with hybrid data architecture...")
	
	# Initialize data system if not already loaded
	if not DataManager._is_data_loaded:
		var success = DataManager.initialize_data_system()
		if not success:
			push_error("CrewPanel: Failed to initialize data system, using fallback mode")
	
	_setup_crew_panel()
	_connect_enhanced_signals()
	_apply_responsive_layout()
	
	call_deferred("_initialize_components")

func _setup_crew_panel() -> void:
	# Initialize crew display components
	if not crew_container:
		push_warning("CrewPanel: Crew container not found")
		return
	
	# Setup performance tracking
	_setup_performance_tracking()
	
	# Setup equipment summary
	_setup_equipment_summary()

## Main crew display update function
func update_crew_display(new_crew_data: Array) -> void:
	crew_data = new_crew_data
	
	# Clear existing crew cards
	_clear_crew_cards()
	
	# Create enhanced crew cards following dice system patterns
	for member in crew_data:
		var crew_card = _create_enhanced_crew_card(member)
		if crew_card:
			crew_container.add_child(crew_card)
	
	# Update summary and performance data
	_update_crew_summary()
	_update_performance_chart()
	_update_equipment_summary()

func _clear_crew_cards() -> void:
	if not crew_container:
		return
	
	# Clear existing crew cards safely
	for child in crew_container.get_children():
		child.queue_free()

func _create_enhanced_crew_card(member_data: Dictionary) -> Control:
	# Create crew stats card following dice system design
	var crew_card = BaseEnhancedComponents.CrewStatsCard.new()
	
	# Setup with safety validation (Universal safety pattern)
	crew_card.setup_with_safety_validation(member_data)
	
	# Apply visual styling from dice system
	_apply_crew_card_styling(crew_card, member_data)
	
	# Connect crew card signals
	crew_card.card_selected.connect(_on_crew_card_selected)
	crew_card.card_action_requested.connect(_on_crew_action_requested)
	
	return crew_card

func _apply_crew_card_styling(crew_card: Control, member_data: Dictionary) -> void:
	# Apply color coding based on crew status (dice system colors)
	var health_ratio = member_data.get("health_ratio", 1.0)
	var status = member_data.get("status", "active")
	
	match status:
		"injured":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"recovering":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"active":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			crew_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_crew_summary() -> void:
	if not crew_summary:
		return
	
	var total_crew = crew_data.size()
	var active_crew = 0
	var injured_crew = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_crew += 1
		elif status == "injured":
			injured_crew += 1
		
		total_health += health
	
	var avg_health = total_health / total_crew if total_crew > 0 else 0.0
	
	# Update summary with contextual information
	crew_summary.text = "Crew: %d Active, %d Injured (Avg Health: %.1f%%)" % [
		active_crew, injured_crew, avg_health * 100
	]

func _update_performance_chart() -> void:
	if not crew_performance_chart:
		return
	
	# Update performance visualization
	var performance_data = _calculate_crew_performance()
	crew_performance_chart.update_performance_display(performance_data)

func _update_equipment_summary() -> void:
	if not crew_equipment_summary:
		return
	
	# Update equipment summary
	var equipment_data = _calculate_equipment_summary()
	crew_equipment_summary.update_equipment_display(equipment_data)

func _calculate_crew_performance() -> Dictionary:
	var performance = {
		"total_missions": 0,
		"successful_missions": 0,
		"average_combat_rating": 0.0,
		"average_survival_rate": 0.0
	}
	
	var total_combat = 0.0
	var total_survival = 0.0
	var crew_count = crew_data.size()
	
	for member in crew_data:
		var stats = member.get("stats", {})
		total_combat += stats.get("combat", 0)
		total_survival += stats.get("survival_rate", 0.0)
		
		var missions = member.get("missions", {})
		performance.total_missions += missions.get("total", 0)
		performance.successful_missions += missions.get("successful", 0)
	
	if crew_count > 0:
		performance.average_combat_rating = total_combat / crew_count
		performance.average_survival_rate = total_survival / crew_count
	
	return performance

func _calculate_equipment_summary() -> Dictionary:
	var equipment_summary = {
		"total_weapons": 0,
		"total_armor": 0,
		"total_gear": 0,
		"upgraded_items": 0
	}
	
	for member in crew_data:
		var equipment = member.get("equipment", {})
		equipment_summary.total_weapons += equipment.get("weapons", []).size()
		equipment_summary.total_armor += equipment.get("armor", []).size()
		equipment_summary.total_gear += equipment.get("gear", []).size()
		
		# Count upgraded items
		var upgrades = equipment.get("upgrades", [])
		equipment_summary.upgraded_items += upgrades.size()
	
	return equipment_summary

## Signal handlers
func _on_crew_card_selected(card_data: Dictionary) -> void:
	selected_crew_member = card_data.get("crew_id", "")
	enhanced_signals.emit_safe_signal("crew_member_selected", [selected_crew_member])

func _on_crew_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_crew_status_changed(crew_member: String, status: Dictionary) -> void:
	# Update crew member status in local data
	for member in crew_data:
		if member.get("id") == crew_member:
			member.merge(status)
			break
	
	# Refresh display
	update_crew_display(crew_data)

func _on_crew_performance_updated(crew_id: String, performance: Dictionary) -> void:
	crew_performance_data[crew_id] = performance
	_update_performance_chart()

func _on_crew_equipment_changed(crew_id: String, equipment: Dictionary) -> void:
	# Update crew member equipment
	for member in crew_data:
		if member.get("id") == crew_id:
			member["equipment"] = equipment
			break
	
	_update_equipment_summary()

func _on_crew_health_changed(crew_id: String, health_ratio: float) -> void:
	# Update crew member health
	for member in crew_data:
		if member.get("id") == crew_id:
			member["health_ratio"] = health_ratio
			break
	
	# Refresh display with updated health
	update_crew_display(crew_data)

## Helper functions
func _generate_compact_crew_summary() -> String:
	var active_count = 0
	for member in crew_data:
		if member.get("status") == "active":
			active_count += 1
	
	return "Crew: %d/%d Active" % [active_count, crew_data.size()]

func _generate_detailed_crew_summary() -> String:
	var active_count = 0
	var injured_count = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_count += 1
		elif status == "injured":
			injured_count += 1
		
		total_health += health
	
	var avg_health = total_health / crew_data.size() if crew_data.size() > 0 else 0.0
	
	return "Crew Status: %d Active, %d Injured | Avg Health: %.1f%%" % [
		active_count, injured_count, avg_health * 100
	]

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	crew_performance_data = {}

func _setup_equipment_summary() -> void:
	# Initialize equipment summary system
	pass

## Public API for external access
func get_crew_data() -> Array:
	return crew_data

func get_selected_crew_member() -> String:
	return selected_crew_member

func get_crew_performance_data() -> Dictionary:
	return crew_performance_data

func refresh_display() -> void:
	update_crew_display(crew_data)

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect crew-related signals
	enhanced_signals.connect_signal_safely("crew_status_changed", self, "_on_crew_status_changed")
	enhanced_signals.connect_signal_safely("crew_performance_updated", self, "_on_crew_performance_updated")
	enhanced_signals.connect_signal_safely("crew_equipment_changed", self, "_on_crew_equipment_changed")
	enhanced_signals.connect_signal_safely("crew_health_changed", self, "_on_crew_health_changed")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if crew_container:
		crew_container.custom_minimum_size.y = 200
		crew_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if crew_summary:
		crew_summary.text = _generate_compact_crew_summary()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if crew_container:
		crew_container.custom_minimum_size.y = 300
		crew_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if crew_summary:
		crew_summary.text = _generate_detailed_crew_summary()

## Main crew display update function
func update_crew_display(new_crew_data: Array) -> void:
	crew_data = new_crew_data
	
	# Clear existing crew cards
	_clear_crew_cards()
	
	# Create enhanced crew cards following dice system patterns
	for member in crew_data:
		var crew_card = _create_enhanced_crew_card(member)
		if crew_card:
			crew_container.add_child(crew_card)
	
	# Update summary and performance data
	_update_crew_summary()
	_update_performance_chart()
	_update_equipment_summary()

func _clear_crew_cards() -> void:
	if not crew_container:
		return
	
	# Clear existing crew cards safely
	for child in crew_container.get_children():
		child.queue_free()

func _create_enhanced_crew_card(member_data: Dictionary) -> Control:
	# Create crew stats card following dice system design
	var crew_card = BaseEnhancedComponents.CrewStatsCard.new()
	
	# Setup with safety validation (Universal safety pattern)
	crew_card.setup_with_safety_validation(member_data)
	
	# Apply visual styling from dice system
	_apply_crew_card_styling(crew_card, member_data)
	
	# Connect crew card signals
	crew_card.card_selected.connect(_on_crew_card_selected)
	crew_card.card_action_requested.connect(_on_crew_action_requested)
	
	return crew_card

func _apply_crew_card_styling(crew_card: Control, member_data: Dictionary) -> void:
	# Apply color coding based on crew status (dice system colors)
	var health_ratio = member_data.get("health_ratio", 1.0)
	var status = member_data.get("status", "active")
	
	match status:
		"injured":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"recovering":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"active":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			crew_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_crew_summary() -> void:
	if not crew_summary:
		return
	
	var total_crew = crew_data.size()
	var active_crew = 0
	var injured_crew = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_crew += 1
		elif status == "injured":
			injured_crew += 1
		
		total_health += health
	
	var avg_health = total_health / total_crew if total_crew > 0 else 0.0
	
	# Update summary with contextual information
	crew_summary.text = "Crew: %d Active, %d Injured (Avg Health: %.1f%%)" % [
		active_crew, injured_crew, avg_health * 100
	]

func _update_performance_chart() -> void:
	if not crew_performance_chart:
		return
	
	# Update performance visualization
	var performance_data = _calculate_crew_performance()
	crew_performance_chart.update_performance_display(performance_data)

func _update_equipment_summary() -> void:
	if not crew_equipment_summary:
		return
	
	# Update equipment summary
	var equipment_data = _calculate_equipment_summary()
	crew_equipment_summary.update_equipment_display(equipment_data)

func _calculate_crew_performance() -> Dictionary:
	var performance = {
		"total_missions": 0,
		"successful_missions": 0,
		"average_combat_rating": 0.0,
		"average_survival_rate": 0.0
	}
	
	var total_combat = 0.0
	var total_survival = 0.0
	var crew_count = crew_data.size()
	
	for member in crew_data:
		var stats = member.get("stats", {})
		total_combat += stats.get("combat", 0)
		total_survival += stats.get("survival_rate", 0.0)
		
		var missions = member.get("missions", {})
		performance.total_missions += missions.get("total", 0)
		performance.successful_missions += missions.get("successful", 0)
	
	if crew_count > 0:
		performance.average_combat_rating = total_combat / crew_count
		performance.average_survival_rate = total_survival / crew_count
	
	return performance

func _calculate_equipment_summary() -> Dictionary:
	var equipment_summary = {
		"total_weapons": 0,
		"total_armor": 0,
		"total_gear": 0,
		"upgraded_items": 0
	}
	
	for member in crew_data:
		var equipment = member.get("equipment", {})
		equipment_summary.total_weapons += equipment.get("weapons", []).size()
		equipment_summary.total_armor += equipment.get("armor", []).size()
		equipment_summary.total_gear += equipment.get("gear", []).size()
		
		# Count upgraded items
		var upgrades = equipment.get("upgrades", [])
		equipment_summary.upgraded_items += upgrades.size()
	
	return equipment_summary

## Signal handlers
func _on_crew_card_selected(card_data: Dictionary) -> void:
	selected_crew_member = card_data.get("crew_id", "")
	enhanced_signals.emit_safe_signal("crew_member_selected", [selected_crew_member])

func _on_crew_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_crew_status_changed(crew_member: String, status: Dictionary) -> void:
	# Update crew member status in local data
	for member in crew_data:
		if member.get("id") == crew_member:
			member.merge(status)
			break
	
	# Refresh display
	update_crew_display(crew_data)

func _on_crew_performance_updated(crew_id: String, performance: Dictionary) -> void:
	crew_performance_data[crew_id] = performance
	_update_performance_chart()

func _on_crew_equipment_changed(crew_id: String, equipment: Dictionary) -> void:
	# Update crew member equipment
	for member in crew_data:
		if member.get("id") == crew_id:
			member["equipment"] = equipment
			break
	
	_update_equipment_summary()

func _on_crew_health_changed(crew_id: String, health_ratio: float) -> void:
	# Update crew member health
	for member in crew_data:
		if member.get("id") == crew_id:
			member["health_ratio"] = health_ratio
			break
	
	# Refresh display with updated health
	update_crew_display(crew_data)

## Helper functions
func _generate_compact_crew_summary() -> String:
	var active_count = 0
	for member in crew_data:
		if member.get("status") == "active":
			active_count += 1
	
	return "Crew: %d/%d Active" % [active_count, crew_data.size()]

func _generate_detailed_crew_summary() -> String:
	var active_count = 0
	var injured_count = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_count += 1
		elif status == "injured":
			injured_count += 1
		
		total_health += health
	
	var avg_health = total_health / crew_data.size() if crew_data.size() > 0 else 0.0
	
	return "Crew Status: %d Active, %d Injured | Avg Health: %.1f%%" % [
		active_count, injured_count, avg_health * 100
	]

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	crew_performance_data = {}

func _setup_equipment_summary() -> void:
	# Initialize equipment summary system
	pass

## Public API for external access
func get_crew_data() -> Array:
	return crew_data

func get_selected_crew_member() -> String:
	return selected_crew_member

func get_crew_performance_data() -> Dictionary:
	return crew_performance_data

func refresh_display() -> void:
	update_crew_display(crew_data)

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect crew-related signals
	enhanced_signals.connect_signal_safely("crew_status_changed", self, "_on_crew_status_changed")
	enhanced_signals.connect_signal_safely("crew_performance_updated", self, "_on_crew_performance_updated")
	enhanced_signals.connect_signal_safely("crew_equipment_changed", self, "_on_crew_equipment_changed")
	enhanced_signals.connect_signal_safely("crew_health_changed", self, "_on_crew_health_changed")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if crew_container:
		crew_container.custom_minimum_size.y = 200
		crew_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if crew_summary:
		crew_summary.text = _generate_compact_crew_summary()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if crew_container:
		crew_container.custom_minimum_size.y = 300
		crew_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if crew_summary:
		crew_summary.text = _generate_detailed_crew_summary()

## Main crew display update function
func update_crew_display(new_crew_data: Array) -> void:
	crew_data = new_crew_data
	
	# Clear existing crew cards
	_clear_crew_cards()
	
	# Create enhanced crew cards following dice system patterns
	for member in crew_data:
		var crew_card = _create_enhanced_crew_card(member)
		if crew_card:
			crew_container.add_child(crew_card)
	
	# Update summary and performance data
	_update_crew_summary()
	_update_performance_chart()
	_update_equipment_summary()

func _clear_crew_cards() -> void:
	if not crew_container:
		return
	
	# Clear existing crew cards safely
	for child in crew_container.get_children():
		child.queue_free()

func _create_enhanced_crew_card(member_data: Dictionary) -> Control:
	# Create crew stats card following dice system design
	var crew_card = BaseEnhancedComponents.CrewStatsCard.new()
	
	# Setup with safety validation (Universal safety pattern)
	crew_card.setup_with_safety_validation(member_data)
	
	# Apply visual styling from dice system
	_apply_crew_card_styling(crew_card, member_data)
	
	# Connect crew card signals
	crew_card.card_selected.connect(_on_crew_card_selected)
	crew_card.card_action_requested.connect(_on_crew_action_requested)
	
	return crew_card

func _apply_crew_card_styling(crew_card: Control, member_data: Dictionary) -> void:
	# Apply color coding based on crew status (dice system colors)
	var health_ratio = member_data.get("health_ratio", 1.0)
	var status = member_data.get("status", "active")
	
	match status:
		"injured":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"recovering":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"active":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			crew_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_crew_summary() -> void:
	if not crew_summary:
		return
	
	var total_crew = crew_data.size()
	var active_crew = 0
	var injured_crew = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_crew += 1
		elif status == "injured":
			injured_crew += 1
		
		total_health += health
	
	var avg_health = total_health / total_crew if total_crew > 0 else 0.0
	
	# Update summary with contextual information
	crew_summary.text = "Crew: %d Active, %d Injured (Avg Health: %.1f%%)" % [
		active_crew, injured_crew, avg_health * 100
	]

func _update_performance_chart() -> void:
	if not crew_performance_chart:
		return
	
	# Update performance visualization
	var performance_data = _calculate_crew_performance()
	crew_performance_chart.update_performance_display(performance_data)

func _update_equipment_summary() -> void:
	if not crew_equipment_summary:
		return
	
	# Update equipment summary
	var equipment_data = _calculate_equipment_summary()
	crew_equipment_summary.update_equipment_display(equipment_data)

func _calculate_crew_performance() -> Dictionary:
	var performance = {
		"total_missions": 0,
		"successful_missions": 0,
		"average_combat_rating": 0.0,
		"average_survival_rate": 0.0
	}
	
	var total_combat = 0.0
	var total_survival = 0.0
	var crew_count = crew_data.size()
	
	for member in crew_data:
		var stats = member.get("stats", {})
		total_combat += stats.get("combat", 0)
		total_survival += stats.get("survival_rate", 0.0)
		
		var missions = member.get("missions", {})
		performance.total_missions += missions.get("total", 0)
		performance.successful_missions += missions.get("successful", 0)
	
	if crew_count > 0:
		performance.average_combat_rating = total_combat / crew_count
		performance.average_survival_rate = total_survival / crew_count
	
	return performance

func _calculate_equipment_summary() -> Dictionary:
	var equipment_summary = {
		"total_weapons": 0,
		"total_armor": 0,
		"total_gear": 0,
		"upgraded_items": 0
	}
	
	for member in crew_data:
		var equipment = member.get("equipment", {})
		equipment_summary.total_weapons += equipment.get("weapons", []).size()
		equipment_summary.total_armor += equipment.get("armor", []).size()
		equipment_summary.total_gear += equipment.get("gear", []).size()
		
		# Count upgraded items
		var upgrades = equipment.get("upgrades", [])
		equipment_summary.upgraded_items += upgrades.size()
	
	return equipment_summary

## Signal handlers
func _on_crew_card_selected(card_data: Dictionary) -> void:
	selected_crew_member = card_data.get("crew_id", "")
	enhanced_signals.emit_safe_signal("crew_member_selected", [selected_crew_member])

func _on_crew_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_crew_status_changed(crew_member: String, status: Dictionary) -> void:
	# Update crew member status in local data
	for member in crew_data:
		if member.get("id") == crew_member:
			member.merge(status)
			break
	
	# Refresh display
	update_crew_display(crew_data)

func _on_crew_performance_updated(crew_id: String, performance: Dictionary) -> void:
	crew_performance_data[crew_id] = performance
	_update_performance_chart()

func _on_crew_equipment_changed(crew_id: String, equipment: Dictionary) -> void:
	# Update crew member equipment
	for member in crew_data:
		if member.get("id") == crew_id:
			member["equipment"] = equipment
			break
	
	_update_equipment_summary()

func _on_crew_health_changed(crew_id: String, health_ratio: float) -> void:
	# Update crew member health
	for member in crew_data:
		if member.get("id") == crew_id:
			member["health_ratio"] = health_ratio
			break
	
	# Refresh display with updated health
	update_crew_display(crew_data)

## Helper functions
func _generate_compact_crew_summary() -> String:
	var active_count = 0
	for member in crew_data:
		if member.get("status") == "active":
			active_count += 1
	
	return "Crew: %d/%d Active" % [active_count, crew_data.size()]

func _generate_detailed_crew_summary() -> String:
	var active_count = 0
	var injured_count = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_count += 1
		elif status == "injured":
			injured_count += 1
		
		total_health += health
	
	var avg_health = total_health / crew_data.size() if crew_data.size() > 0 else 0.0
	
	return "Crew Status: %d Active, %d Injured | Avg Health: %.1f%%" % [
		active_count, injured_count, avg_health * 100
	]

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	crew_performance_data = {}

func _setup_equipment_summary() -> void:
	# Initialize equipment summary system
	pass

## Public API for external access
func get_crew_data() -> Array:
	return crew_data

func get_selected_crew_member() -> String:
	return selected_crew_member

func get_crew_performance_data() -> Dictionary:
	return crew_performance_data

func refresh_display() -> void:
	update_crew_display(crew_data)

func _show_error_state() -> void:
	"""Display error state when components are missing"""
	# Create a simple error label if the main components are missing
	var error_label: Label = Label.new()
	error_label.text = "Crew setup components not available. Please check scene configuration."
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(error_label)

func _setup_crew_size_options() -> void:
	"""Configure crew size options with Five Parsecs defaults"""
	if not crew_size_option:
		return

	crew_size_option.clear()
	crew_size_option.add_item("4 Members (Standard)", 4)
	crew_size_option.add_item("5 Members (Expanded)", 5)
	crew_size_option.add_item("6 Members (Large)", 6)

	crew_size_option.select(0) # Default to standard 4-member crew
	selected_size = 4

func _connect_signals() -> void:
	"""Establish signal connections with error handling and duplicate prevention"""
	print("CrewPanel: Connecting signals...")
	
	# Disconnect existing signals first to prevent duplicates
	_disconnect_signals()
	
	if crew_size_option:
		if not crew_size_option.item_selected.is_connected(_on_crew_size_selected):
			crew_size_option.item_selected.connect(_on_crew_size_selected)
		print("  - crew_size_option signals connected")

	if add_button:
		if not add_button.pressed.is_connected(_on_add_member_pressed):
			add_button.pressed.connect(_on_add_member_pressed)
		print("  - add_button signal connected")
	if edit_button:
		if not edit_button.pressed.is_connected(_on_edit_member_pressed):
			edit_button.pressed.connect(_on_edit_member_pressed)
		print("  - edit_button signal connected")
	if remove_button:
		if not remove_button.pressed.is_connected(_on_remove_member_pressed):
			remove_button.pressed.connect(_on_remove_member_pressed)
		print("  - remove_button signal connected")
	if randomize_button:
		if not randomize_button.pressed.is_connected(_on_randomize_pressed):
			randomize_button.pressed.connect(_on_randomize_pressed)
		print("  - randomize_button signal connected")

	if crew_list:
		if not crew_list.item_selected.is_connected(_on_crew_member_selected):
			crew_list.item_selected.connect(_on_crew_member_selected)
		print("  - crew_list signal connected")
	
	print("CrewPanel: Signal connections complete")

func _disconnect_signals() -> void:
	"""Disconnect all signals to prevent duplicates"""
	if crew_size_option and crew_size_option.item_selected.is_connected(_on_crew_size_selected):
		crew_size_option.item_selected.disconnect(_on_crew_size_selected)
	
	if add_button and add_button.pressed.is_connected(_on_add_member_pressed):
		add_button.pressed.disconnect(_on_add_member_pressed)
	
	if edit_button and edit_button.pressed.is_connected(_on_edit_member_pressed):
		edit_button.pressed.disconnect(_on_edit_member_pressed)
	
	if remove_button and remove_button.pressed.is_connected(_on_remove_member_pressed):
		remove_button.pressed.disconnect(_on_remove_member_pressed)
	
	if randomize_button and randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.disconnect(_on_randomize_pressed)
	
	if crew_list and crew_list.item_selected.is_connected(_on_crew_member_selected):
		crew_list.item_selected.disconnect(_on_crew_member_selected)

func _generate_initial_crew() -> void:
	"""Generate initial crew members based on Five Parsecs rules with enhanced data"""
	crew_members.clear()

	for i: int in range(selected_size):
		var character: Character = _create_random_character_enhanced()
		if character:
			crew_members.append(character)

	_update_crew_list()
	crew_updated.emit(crew_members)

func _create_random_character_enhanced() -> Character:
	"""Create random character with enhanced data-driven generation"""
	var character: Character = null
	
	# Primary method: Use FiveParsecsCharacterGeneration system with enhanced features
	if FiveParsecsCharacterGeneration:
		print("CrewPanel: Attempting to generate character using FiveParsecsCharacterGeneration...")
		character = FiveParsecsCharacterGeneration.generate_complete_character()
		if character and is_instance_valid(character):
			print("CrewPanel: Generated character using FiveParsecsCharacterGeneration: ", character.character_name)
			return character
		else:
			print("CrewPanel: FiveParsecsCharacterGeneration returned invalid character, using fallback")
			if not character:
				print("CrewPanel: FiveParsecsCharacterGeneration returned null character")
			elif not is_instance_valid(character):
				print("CrewPanel: FiveParsecsCharacterGeneration returned invalid character instance")
	
	# Enhanced fallback method: Create character with rich data integration
	print("CrewPanel: Using enhanced fallback character creation...")
	character = _create_enhanced_fallback_character()
	
	if character and is_instance_valid(character):
		print("CrewPanel: Generated enhanced fallback character: ", character.character_name)
		return character
	else:
		push_error("CrewPanel: Enhanced fallback character creation failed, trying simple creation")
		# Final fallback: Create simple character
		return _create_simple_character()

func _create_enhanced_fallback_character() -> Character:
	"""Create character with enhanced data integration"""
	if not Character:
		push_error("CrewPanel: Character class not available")
		return null
	
	var character: Character = Character.new()
	if not character:
		push_error("CrewPanel: Failed to create Character instance")
		return null
	
	print("CrewPanel: Successfully created fallback character instance")
	
	# Set basic character properties first
	character.character_name = _generate_fallback_name()
	character.origin = GlobalEnums.Origin.HUMAN
	character.background = GlobalEnums.Background.SOLDIER
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Generate basic attributes manually (Five Parsecs rules: 2d6/3 rounded up)
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute() - 1 # Combat skill bonus format
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute() - 1 # Savvy bonus format
	character.speed = _generate_five_parsecs_attribute() + 2 # Speed in inches
	character.luck = 1 if character.origin == GlobalEnums.Origin.HUMAN else 0
	
	# Clamp to Five Parsecs ranges
	character.reaction = clampi(character.reaction, 1, 6)
	character.combat = clampi(character.combat, 0, 3)
	character.toughness = clampi(character.toughness, 3, 6)
	character.savvy = clampi(character.savvy, 0, 3)
	character.speed = clampi(character.speed, 4, 8)
	
	# Set health (Five Parsecs rule: Toughness + 2)
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Enhanced background and motivation selection using rich data
	var background_data = _get_enhanced_background_selection()
	var motivation_data = _get_enhanced_motivation_selection()
	var class_data = _get_enhanced_class_selection()
	
	character.background = background_data.background
	character.motivation = motivation_data.motivation
	character.character_class = class_data.class
	character.origin = GlobalEnums.Origin.HUMAN # Default to human
	
	# Generate name based on origin
	character.character_name = _generate_fallback_name()
	
	# Apply origin bonuses using rich data
	_apply_enhanced_origin_bonuses(character)
	
	# Apply background bonuses using rich data
	_apply_enhanced_background_bonuses(character, background_data)
	
	print("CrewPanel: Generated enhanced fallback character: ", character.character_name)
	return character

func _get_enhanced_background_selection() -> Dictionary:
	"""Get background selection using ALL available backgrounds"""
	# Use ALL available backgrounds from GlobalEnums
	var all_backgrounds = [
		GlobalEnums.Background.MILITARY,
		GlobalEnums.Background.MERCENARY,
		GlobalEnums.Background.CRIMINAL,
		GlobalEnums.Background.COLONIST,
		GlobalEnums.Background.ACADEMIC,
		GlobalEnums.Background.EXPLORER,
		GlobalEnums.Background.TRADER,
		GlobalEnums.Background.NOBLE,
		GlobalEnums.Background.OUTCAST,
		GlobalEnums.Background.SOLDIER,
		GlobalEnums.Background.MERCHANT
	]
	var selected_bg = all_backgrounds[randi() % all_backgrounds.size()]
	
	# Get rich background data if available
	var background_data = DataManager.get_background_data(_get_background_id_from_enum(selected_bg))
	if background_data.is_empty():
		# Fallback to basic background info
		background_data = {
			"name": GlobalEnums.get_background_display_name(selected_bg),
			"description": "Background description not available"
		}
	
	return {
		"background": selected_bg,
		"background_data": background_data
	}

func _get_enhanced_class_selection() -> Dictionary:
	"""Get class selection using ALL available classes"""
	# Use ALL available classes from GlobalEnums
	var all_classes = [
		GlobalEnums.CharacterClass.SOLDIER,
		GlobalEnums.CharacterClass.SCOUT,
		GlobalEnums.CharacterClass.MEDIC,
		GlobalEnums.CharacterClass.ENGINEER,
		GlobalEnums.CharacterClass.PILOT,
		GlobalEnums.CharacterClass.MERCHANT,
		GlobalEnums.CharacterClass.SECURITY,
		GlobalEnums.CharacterClass.BROKER,
		GlobalEnums.CharacterClass.BOT_TECH,
		GlobalEnums.CharacterClass.ROGUE,
		GlobalEnums.CharacterClass.PSIONICIST,
		GlobalEnums.CharacterClass.TECH,
		GlobalEnums.CharacterClass.BRUTE,
		GlobalEnums.CharacterClass.GUNSLINGER,
		GlobalEnums.CharacterClass.ACADEMIC
	]
	var selected_class = all_classes[randi() % all_classes.size()]
	
	# Get rich class data if available using the correct method name
	var class_data = DataManager.get_character_class_data(_get_class_id_from_enum(selected_class))
	if class_data.is_empty():
		# Fallback to basic class info
		class_data = {
			"name": GlobalEnums.get_class_display_name(selected_class),
			"description": "Class description not available"
		}
	
	return {
		"class": selected_class,
		"class_data": class_data
	}

func _get_enhanced_motivation_selection() -> Dictionary:
	"""Get motivation selection using ALL available motivations"""
	# Use ALL available motivations from GlobalEnums
	var all_motivations = [
		GlobalEnums.Motivation.WEALTH,
		GlobalEnums.Motivation.REVENGE,
		GlobalEnums.Motivation.GLORY,
		GlobalEnums.Motivation.KNOWLEDGE,
		GlobalEnums.Motivation.POWER,
		GlobalEnums.Motivation.JUSTICE,
		GlobalEnums.Motivation.SURVIVAL,
		GlobalEnums.Motivation.LOYALTY,
		GlobalEnums.Motivation.FREEDOM,
		GlobalEnums.Motivation.DISCOVERY,
		GlobalEnums.Motivation.REDEMPTION,
		GlobalEnums.Motivation.DUTY
	]
	var selected_motivation = all_motivations[randi() % all_motivations.size()]
	
	return {
		"motivation": selected_motivation,
		"motivation_name": GlobalEnums.get_motivation_display_name(selected_motivation)
	}

func _get_enhanced_origin_selection() -> Dictionary:
	"""Get origin selection using ALL available origins"""
	# Use ALL available origins from GlobalEnums
	var all_origins = [
		GlobalEnums.Origin.HUMAN,
		GlobalEnums.Origin.ENGINEER,
		GlobalEnums.Origin.KERIN,
		GlobalEnums.Origin.SOULLESS,
		GlobalEnums.Origin.PRECURSOR,
		GlobalEnums.Origin.FERAL,
		GlobalEnums.Origin.SWIFT,
		GlobalEnums.Origin.BOT,
		GlobalEnums.Origin.CORE_WORLDS,
		GlobalEnums.Origin.FRONTIER,
		GlobalEnums.Origin.DEEP_SPACE,
		GlobalEnums.Origin.COLONY,
		GlobalEnums.Origin.HIVE_WORLD,
		GlobalEnums.Origin.FORGE_WORLD
	]
	var selected_origin = all_origins[randi() % all_origins.size()]
	
	return {
		"origin": selected_origin,
		"origin_name": GlobalEnums.get_origin_display_name(selected_origin)
	}

func _generate_random_full_name() -> String:
	"""Generate a full name with first and last name"""
	var first_names = ["Alex", "Morgan", "Casey", "Taylor", "Jordan", "Riley", "Avery", "Quinn", "Blake", "Cameron", "Jamie", "Sage", "Rowan", "Kai", "Drew", "Sam", "Parker", "Reese", "Dakota", "Skyler"]
	var last_names = ["Vega", "Cruz", "Stone", "Hunter", "Fox", "Storm", "Reeves", "Cross", "Vale", "Kane", "Steele", "Raven", "Wolf", "Shaw", "Grey", "Black", "White", "Brown", "Green", "Blue"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

func _apply_enhanced_origin_bonuses(character: Character) -> void:
	"""Apply origin bonuses using rich data"""
	var origin_name = GlobalEnums.get_origin_name(character.origin)
	
	# Skip if origin is NONE or UNKNOWN
	if origin_name == "NONE" or origin_name == "UNKNOWN":
		print("CrewPanel: Skipping origin bonuses for invalid origin: ", origin_name)
		return
	
	var origin_data = {}
	
	if DataManager._is_data_loaded:
		origin_data = DataManager.get_origin_data(origin_name)
	
	if not origin_data.is_empty():
		# Apply base stat bonuses from JSON
		var base_stats = origin_data.get("base_stats", {})
		for stat_name in base_stats.keys():
			var bonus = base_stats[stat_name]
			_apply_stat_bonus(character, stat_name, bonus)
		
		# Add characteristics as traits
		var characteristics = origin_data.get("characteristics", [])
		for characteristic in characteristics:
			if character.has_method("add_trait"):
				# Ensure characteristic is a string
				var trait_text = str(characteristic)
				character.add_trait("Origin: " + trait_text)
	else:
		print("CrewPanel: No origin data found for %s, using default origin effects" % origin_name)
	
	# Apply origin effects using existing system
	FiveParsecsCharacterGeneration.set_character_flags(character)

func _apply_enhanced_background_bonuses(character: Character, background_data: Dictionary) -> void:
	"""Apply background bonuses using rich data"""
	var rich_data = background_data.get("background_data", {})
	
	if not rich_data.is_empty():
		# Apply stat bonuses
		var stat_bonuses = rich_data.get("stat_bonuses", {})
		for stat_name in stat_bonuses.keys():
			var bonus = stat_bonuses[stat_name]
			_apply_stat_bonus(character, stat_name, bonus)
		
		# Apply stat penalties
		var stat_penalties = rich_data.get("stat_penalties", {})
		for stat_name in stat_penalties.keys():
			var penalty = stat_penalties[stat_name]
			_apply_stat_bonus(character, stat_name, penalty) # Penalty is negative bonus
		
		# Add starting skills as traits
		var starting_skills = rich_data.get("starting_skills", [])
		for skill in starting_skills:
			if character.has_method("add_trait"):
				# Ensure skill is a string
				var skill_text = str(skill)
				character.add_trait("Skill: " + skill_text)
		
		# Add special abilities as traits
		var special_abilities = rich_data.get("special_abilities", [])
		for ability in special_abilities:
			var ability_name = ability.get("name", "Unknown Ability")
			var ability_desc = ability.get("description", "")
			if character.has_method("add_trait"):
				# Ensure ability name and description are strings
				var ability_text = str(ability_name)
				var desc_text = str(ability_desc)
				character.add_trait("Ability: %s - %s" % [ability_text, desc_text])
	else:
		print("CrewPanel: No rich background data available, using default background effects")

func _apply_stat_bonus(character: Character, stat_name: String, bonus: int) -> void:
	"""Apply stat bonus using correct property mapping"""
	match stat_name.to_lower():
		"combat", "combat_skill":
			character.combat = clampi(character.combat + bonus, 0, 3)
		"reactions", "reaction":
			character.reaction = clampi(character.reaction + bonus, 1, 6)
		"toughness":
			character.toughness = clampi(character.toughness + bonus, 1, 6)
		"speed":
			character.speed = clampi(character.speed + bonus, 4, 8)
		"savvy":
			character.savvy = clampi(character.savvy + bonus, 0, 3)

func _get_background_id_from_enum(background_enum: int) -> String:
	"""Convert enum background to JSON background ID"""
	match background_enum:
		GlobalEnums.Background.MILITARY: return "military"
		GlobalEnums.Background.CRIMINAL: return "criminal"
		GlobalEnums.Background.ACADEMIC: return "scientist"
		GlobalEnums.Background.MERCENARY: return "mercenary"
		GlobalEnums.Background.COLONIST: return "colonist"
		GlobalEnums.Background.EXPLORER: return "pilot"
		GlobalEnums.Background.TRADER: return "corporate"
		GlobalEnums.Background.OUTCAST: return "drifter"
		GlobalEnums.Background.NOBLE: return "noble"
		GlobalEnums.Background.SOLDIER: return "military" # Map soldier to military
		GlobalEnums.Background.MERCHANT: return "corporate" # Map merchant to corporate
		_: return "drifter" # Safe default

func _get_class_id_from_enum(class_enum: int) -> String:
	"""Convert enum class to JSON class ID"""
	match class_enum:
		GlobalEnums.CharacterClass.SOLDIER: return "soldier"
		GlobalEnums.CharacterClass.SCOUT: return "scout"
		GlobalEnums.CharacterClass.MEDIC: return "medic"
		GlobalEnums.CharacterClass.ENGINEER: return "engineer"
		GlobalEnums.CharacterClass.PILOT: return "pilot"
		GlobalEnums.CharacterClass.MERCHANT: return "merchant"
		GlobalEnums.CharacterClass.SECURITY: return "security"
		GlobalEnums.CharacterClass.BROKER: return "broker"
		GlobalEnums.CharacterClass.BOT_TECH: return "bot_tech"
		GlobalEnums.CharacterClass.ROGUE: return "rogue"
		GlobalEnums.CharacterClass.PSIONICIST: return "psionicist"
		GlobalEnums.CharacterClass.TECH: return "tech"
		GlobalEnums.CharacterClass.BRUTE: return "brute"
		GlobalEnums.CharacterClass.GUNSLINGER: return "gunslinger"
		GlobalEnums.CharacterClass.ACADEMIC: return "academic"
		_: return "soldier" # Safe default

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute using 2d6/3 rounded up"""
	var roll = randi_range(2, 12) # 2d6
	return ceili(float(roll) / 3.0)

func _generate_fallback_name() -> String:
	"""Generate a random character name for fallback creation"""
	var first_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake", "Cameron", "Jamie", "Sage", "Rowan", "Kai"]
	var last_names = ["Vega", "Cruz", "Stone", "Hunter", "Fox", "Storm", "Reeves", "Cross", "Vale", "Kane", "Steele", "Raven", "Wolf", "Shaw", "Grey"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

## Main crew display update function
func update_crew_display(new_crew_data: Array) -> void:
	crew_data = new_crew_data
	
	# Clear existing crew cards
	_clear_crew_cards()
	
	# Create enhanced crew cards following dice system patterns
	for member in crew_data:
		var crew_card = _create_enhanced_crew_card(member)
		if crew_card:
			crew_container.add_child(crew_card)
	
	# Update summary and performance data
	_update_crew_summary()
	_update_performance_chart()
	_update_equipment_summary()

func _clear_crew_cards() -> void:
	if not crew_container:
		return
	
	# Clear existing crew cards safely
	for child in crew_container.get_children():
		child.queue_free()

func _create_enhanced_crew_card(member_data: Dictionary) -> Control:
	# Create crew stats card following dice system design
	var crew_card = BaseEnhancedComponents.CrewStatsCard.new()
	
	# Setup with safety validation (Universal safety pattern)
	crew_card.setup_with_safety_validation(member_data)
	
	# Apply visual styling from dice system
	_apply_crew_card_styling(crew_card, member_data)
	
	# Connect crew card signals
	crew_card.card_selected.connect(_on_crew_card_selected)
	crew_card.card_action_requested.connect(_on_crew_action_requested)
	
	return crew_card

func _apply_crew_card_styling(crew_card: Control, member_data: Dictionary) -> void:
	# Apply color coding based on crew status (dice system colors)
	var health_ratio = member_data.get("health_ratio", 1.0)
	var status = member_data.get("status", "active")
	
	match status:
		"injured":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"recovering":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"active":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			crew_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_crew_summary() -> void:
	if not crew_summary:
		return
	
	var total_crew = crew_data.size()
	var active_crew = 0
	var injured_crew = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_crew += 1
		elif status == "injured":
			injured_crew += 1
		
		total_health += health
	
	var avg_health = total_health / total_crew if total_crew > 0 else 0.0
	
	# Update summary with contextual information
	crew_summary.text = "Crew: %d Active, %d Injured (Avg Health: %.1f%%)" % [
		active_crew, injured_crew, avg_health * 100
	]

func _update_performance_chart() -> void:
	if not crew_performance_chart:
		return
	
	# Update performance visualization
	var performance_data = _calculate_crew_performance()
	crew_performance_chart.update_performance_display(performance_data)

func _update_equipment_summary() -> void:
	if not crew_equipment_summary:
		return
	
	# Update equipment summary
	var equipment_data = _calculate_equipment_summary()
	crew_equipment_summary.update_equipment_display(equipment_data)

func _calculate_crew_performance() -> Dictionary:
	var performance = {
		"total_missions": 0,
		"successful_missions": 0,
		"average_combat_rating": 0.0,
		"average_survival_rate": 0.0
	}
	
	var total_combat = 0.0
	var total_survival = 0.0
	var crew_count = crew_data.size()
	
	for member in crew_data:
		var stats = member.get("stats", {})
		total_combat += stats.get("combat", 0)
		total_survival += stats.get("survival_rate", 0.0)
		
		var missions = member.get("missions", {})
		performance.total_missions += missions.get("total", 0)
		performance.successful_missions += missions.get("successful", 0)
	
	if crew_count > 0:
		performance.average_combat_rating = total_combat / crew_count
		performance.average_survival_rate = total_survival / crew_count
	
	return performance

func _calculate_equipment_summary() -> Dictionary:
	var equipment_summary = {
		"total_weapons": 0,
		"total_armor": 0,
		"total_gear": 0,
		"upgraded_items": 0
	}
	
	for member in crew_data:
		var equipment = member.get("equipment", {})
		equipment_summary.total_weapons += equipment.get("weapons", []).size()
		equipment_summary.total_armor += equipment.get("armor", []).size()
		equipment_summary.total_gear += equipment.get("gear", []).size()
		
		# Count upgraded items
		var upgrades = equipment.get("upgrades", [])
		equipment_summary.upgraded_items += upgrades.size()
	
	return equipment_summary

## Signal handlers
func _on_crew_card_selected(card_data: Dictionary) -> void:
	selected_crew_member = card_data.get("crew_id", "")
	enhanced_signals.emit_safe_signal("crew_member_selected", [selected_crew_member])

func _on_crew_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_crew_status_changed(crew_member: String, status: Dictionary) -> void:
	# Update crew member status in local data
	for member in crew_data:
		if member.get("id") == crew_member:
			member.merge(status)
			break
	
	# Refresh display
	update_crew_display(crew_data)

func _on_crew_performance_updated(crew_id: String, performance: Dictionary) -> void:
	crew_performance_data[crew_id] = performance
	_update_performance_chart()

func _on_crew_equipment_changed(crew_id: String, equipment: Dictionary) -> void:
	# Update crew member equipment
	for member in crew_data:
		if member.get("id") == crew_id:
			member["equipment"] = equipment
			break
	
	_update_equipment_summary()

func _on_crew_health_changed(crew_id: String, health_ratio: float) -> void:
	# Update crew member health
	for member in crew_data:
		if member.get("id") == crew_id:
			member["health_ratio"] = health_ratio
			break
	
	# Refresh display with updated health
	update_crew_display(crew_data)

## Helper functions
func _generate_compact_crew_summary() -> String:
	var active_count = 0
	for member in crew_data:
		if member.get("status") == "active":
			active_count += 1
	
	return "Crew: %d/%d Active" % [active_count, crew_data.size()]

func _generate_detailed_crew_summary() -> String:
	var active_count = 0
	var injured_count = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_count += 1
		elif status == "injured":
			injured_count += 1
		
		total_health += health
	
	var avg_health = total_health / crew_data.size() if crew_data.size() > 0 else 0.0
	
	return "Crew Status: %d Active, %d Injured | Avg Health: %.1f%%" % [
		active_count, injured_count, avg_health * 100
	]

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	crew_performance_data = {}

func _setup_equipment_summary() -> void:
	# Initialize equipment summary system
	pass

## Public API for external access
func get_crew_data() -> Array:
	return crew_data

func get_selected_crew_member() -> String:
	return selected_crew_member

func get_crew_performance_data() -> Dictionary:
	return crew_performance_data

func refresh_display() -> void:
	update_crew_display(crew_data)

# Signal handlers
func _on_crew_size_selected(index: int) -> void:
	if not crew_size_option:
		return

	selected_size = crew_size_option.get_item_id(index)
	_adjust_crew_size()
	_update_crew_list()
	crew_updated.emit(crew_members)

func _adjust_crew_size() -> void:
	"""Adjust crew to match selected size"""
	while crew_members.size() < selected_size:
		var character: Character = _create_random_character_enhanced()
		if character:
			crew_members.append(character)

	while crew_members.size() > selected_size:
		crew_members.pop_back()

	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	if crew_members.size() >= 6: # Five Parsecs maximum
		_show_error_message("Maximum crew size reached (6 members)")
		return

	# Create a new character and open customization
	_create_new_character_for_customization()

func _create_new_character_for_customization() -> void:
	"""Create a new character using CharacterCreator"""
	# Open the CharacterCreator directly for new character creation
	_open_character_creator_for_new_member()

func _open_character_creator_for_new_member() -> void:
	"""Open CharacterCreator for creating a new crew member"""
	var creator_scene = preload("res://src/ui/screens/character/CharacterCreator.tscn")
	if not creator_scene:
		push_error("CrewPanel: Could not load CharacterCreator")
		_show_error_message("Character creator is not available")
		return
	
	var creator_screen = creator_scene.instantiate()
	if not creator_screen:
		push_error("CrewPanel: Could not instantiate CharacterCreator")
		_show_error_message("Failed to open character creator")
		return
	
	# Connect signals for new character creation
	creator_screen.character_created.connect(_on_new_character_created)
	creator_screen.creation_cancelled.connect(_on_new_character_creation_cancelled)
	
	# Store reference to close it when cancelled
	character_creator = creator_screen
	
	# Add to scene tree
	get_viewport().add_child(creator_screen)
	
	print("CrewPanel: Character creator opened for new member")

func _show_simple_character_creator():
	"""Show simple character creation dialog for MVP"""
	# Load our simple character creation dialog
	var dialog_scene = load("res://src/ui/screens/campaign/panels/CharacterCreationDialog.tscn")
	if not dialog_scene:
		print("CrewPanel: Could not load CharacterCreationDialog, falling back to random generation")
		_on_add_member_fallback()
		return

	var dialog = dialog_scene.instantiate()
	get_viewport().add_child(dialog)

	# Connect to character creation signal
	if dialog.has_signal("character_created"):
		dialog.character_created.connect(_on_simple_character_created)

	dialog.popup_centered()

func _on_simple_character_created(character_data: Dictionary):
	"""Handle character creation from simple dialog"""
	# Enhanced validation and error handling
	var character_name_str: String = character_data.get("name", "").strip_edges()

	# Prevent empty names
	if character_name_str.is_empty():
		_show_error_message("Character name cannot be empty")
		return

	# Prevent duplicate names
	if _is_duplicate_name(character_name_str):
		_show_error_message("A character with the name '%s' already exists" % character_name_str)
		return

	# Check crew size limits
	if crew_members.size() >= 6:
		_show_error_message("Maximum crew size reached (6 members)")
		return

	# Convert simple character data to Character object for compatibility
	var character: Character = Character.new()

	# Map basic data with enhanced validation
	character.character_name = character_name_str
	character.combat = max(1, character_data.get("combat", 3))
	character.reaction = max(1, character_data.get("reaction", 2))
	character.toughness = max(1, character_data.get("toughness", 3))
	character.savvy = max(1, character_data.get("savvy", 2))
	character.tech = max(1, character_data.get("tech", 2))
	character.move = max(1, character_data.get("move", 4))
	character.is_captain = character_data.get("is_captain", false)

	# Enhanced background/motivation mapping
	var bg_string = character_data.get("background", "soldier")
	var mot_string = character_data.get("motivation", "survival")

	character.background = _map_background_string(bg_string)
	character.motivation = _map_motivation_string(mot_string)
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.origin = GlobalEnums.Origin.HUMAN

	crew_members.append(character)

	# Auto-assign first character as captain for better UX
	if crew_members.size() == 1 and not has_captain():
		_make_captain(character)
		print("CrewPanel: Auto-assigned first character as captain: ", character.character_name)

	_update_crew_list()
	crew_updated.emit(crew_members)

	print("CrewPanel: Added character via enhanced dialog: ", character.character_name)

func _is_duplicate_name(name: String) -> bool:
	"""Check if character name already exists"""
	for character in crew_members:
		var typed_character: Character = character as Character
		if typed_character.character_name.to_lower() == name.to_lower():
			return true
	return false

func _map_background_string(bg_string: String) -> GlobalEnums.Background:
	"""Map background string to enum using available Background values"""
	match bg_string.to_lower():
		"soldier":
			return GlobalEnums.Background.SOLDIER
		"scavenger":
			return GlobalEnums.Background.EXPLORER # Map scavenger to explorer (closest match)
		"colonist":
			return GlobalEnums.Background.COLONIST
		"techie":
			return GlobalEnums.Background.ACADEMIC # Map techie to academic (closest match)
		"merchant":
			return GlobalEnums.Background.MERCHANT
		"pilot":
			return GlobalEnums.Background.SOLDIER # Pilot is a CharacterClass, default to soldier background
		"military":
			return GlobalEnums.Background.MILITARY
		"mercenary":
			return GlobalEnums.Background.MERCENARY
		"criminal":
			return GlobalEnums.Background.CRIMINAL
		"academic":
			return GlobalEnums.Background.ACADEMIC
		"explorer":
			return GlobalEnums.Background.EXPLORER
		"trader":
			return GlobalEnums.Background.TRADER
		"noble":
			return GlobalEnums.Background.NOBLE
		"outcast":
			return GlobalEnums.Background.OUTCAST
		_:
			return GlobalEnums.Background.SOLDIER

func _map_motivation_string(mot_string: String) -> GlobalEnums.Motivation:
	"""Map motivation string to enum"""
	match mot_string.to_lower():
		"revenge":
			return GlobalEnums.Motivation.REVENGE
		"glory":
			return GlobalEnums.Motivation.GLORY
		"survival":
			return GlobalEnums.Motivation.SURVIVAL
		"wealth":
			return GlobalEnums.Motivation.WEALTH
		"freedom":
			return GlobalEnums.Motivation.FREEDOM
		"justice":
			return GlobalEnums.Motivation.JUSTICE
		_:
			return GlobalEnums.Motivation.SURVIVAL

func _show_error_message(message: String):
	"""Show user-friendly error message"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Crew Management Error"
	get_viewport().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

func _on_add_member_fallback() -> void:
	"""Fallback to random character generation if dialog fails"""
	var character: Character = _create_random_character_enhanced()
	if character:
		crew_members.append(character)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_edit_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		_show_error_message("Please select a crew member to edit")
		return

	var index = selected[0]
	# Account for status header, summary, and separator (first 3 items)
	var crew_index = index - 3
	if crew_index < 0 or crew_index >= crew_members.size():
		_show_error_message("Invalid crew member selection")
		return
	
	var character = crew_members[crew_index]
	if not character or not is_instance_valid(character):
		_show_error_message("Cannot edit: Invalid character selected")
		return
	
	_show_character_editor(character)

func _on_remove_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return

	var index = selected[0]
	# Account for status header, summary, and separator (first 3 items)
	var crew_index = index - 3
	if crew_index >= 0 and crew_index < crew_members.size():
		crew_members.remove_at(crew_index)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_randomize_pressed() -> void:
	"""Handle randomize all button press with enhanced safety"""
	print("CrewPanel: Randomize all requested")
	
	# Clear existing crew
	crew_members.clear()
	current_captain = null
	
	# Generate new crew members
	for i in range(selected_size):
		var character: Character = _create_random_character_enhanced()
		if character:
			crew_members.append(character)
			print("CrewPanel: Generated crew member %d: %s" % [i + 1, character.character_name])
		else:
			push_error("CrewPanel: Failed to generate crew member %d" % [i + 1])
	
	# Select first crew member as captain if we have crew
	if not crew_members.is_empty():
		current_captain = crew_members[0]
		_assign_captain_title(current_captain)
		print("CrewPanel: Assigned captain: %s" % current_captain.character_name)
	
	# Update UI
	_update_crew_list()
	crew_updated.emit(crew_members)
	
	print("CrewPanel: Randomization completed successfully")

func _on_character_created(character: Character) -> void:
	crew_members.append(character)
	_update_crew_list()
	crew_updated.emit(crew_members)

func _show_character_editor(character: Character) -> void:
	"""Show character editor using the new CharacterCustomizationScreen"""
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Cannot edit invalid character")
		_show_error_message("Cannot edit character: Invalid character selected")
		return
	
	print("CrewPanel: Opening character editor for: ", character.character_name)
	_open_character_customization(character)

func _open_character_customization(character: Character) -> void:
	"""Open the character creation/editing screen using CharacterCreator"""
	var creator_scene = preload("res://src/ui/screens/character/CharacterCreator.tscn")
	if not creator_scene:
		push_error("CrewPanel: Could not load CharacterCreator")
		_show_error_message("Character editor is not available")
		return
	
	var creator_screen = creator_scene.instantiate()
	if not creator_screen:
		push_error("CrewPanel: Could not instantiate CharacterCreator")
		_show_error_message("Failed to open character editor")
		return
	
	# CRITICAL FIX: Set up character for editing BEFORE connecting signals
	creator_screen.set_character_for_editing(character)
	
	# Connect both creation and editing signals
	creator_screen.character_created.connect(_on_character_created_or_edited)
	creator_screen.character_updated.connect(_on_character_updated)
	creator_screen.creation_cancelled.connect(_on_character_customization_cancelled)
	
	# Store reference to close it when cancelled
	character_creator = creator_screen
	
	# Add to scene tree as popup
	get_viewport().add_child(creator_screen)
	
	print("CrewPanel: Character editor opened for: ", character.character_name)

func _on_character_updated(character: Character) -> void:
	"""Handle character editing completion from CharacterCreator"""
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Invalid character returned from editor")
		return
	
	print("CrewPanel: Character updated: ", character.character_name)
	
	# Close the character creator window
	if character_creator and is_instance_valid(character_creator):
		character_creator.queue_free()
		character_creator = null
	
	# The character object has been modified in place, just update display
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_character_created_or_edited(character: Character) -> void:
	"""Handle character creation/editing completion from CharacterCreator"""
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Invalid character returned from creator")
		return
	
	print("CrewPanel: Character created/edited: ", character.character_name)
	
	# Close the character creator window
	if character_creator and is_instance_valid(character_creator):
		character_creator.queue_free()
		character_creator = null
	
	# Ensure captain title is properly assigned if this is the captain
	if character.is_captain:
		_assign_captain_title(character)
	
	# Update the crew list display to reflect changes
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_new_character_created(character: Character) -> void:
	"""Handle new character creation completion"""
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Invalid character returned from creator")
		return
	
	print("CrewPanel: New character created: ", character.character_name)
	
	# Close the character creator window
	if character_creator and is_instance_valid(character_creator):
		character_creator.queue_free()
		character_creator = null
	
	# Add the new character to the crew
	crew_members.append(character)
	
	# Auto-assign as captain if this is the first character
	if crew_members.size() == 1 and not has_captain():
		_make_captain(character)
		print("CrewPanel: Auto-assigned first character as captain: ", character.character_name)
	
	# Update display
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_new_character_creation_cancelled() -> void:
	"""Handle new character creation cancellation and close the window"""
	print("CrewPanel: New character creation cancelled - closing window")
	
	# Close the character creator window
	if character_creator and is_instance_valid(character_creator):
		character_creator.queue_free()
		character_creator = null

func _on_character_creation_cancelled() -> void:
	"""Handle character creation cancellation from CharacterCreator"""
	print("CrewPanel: Character creation cancelled")
	
	# Just update display
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_character_customization_complete(character: Character) -> void:
	"""Handle character customization completion"""
	print("CrewPanel: Character customization completed for: ", character.character_name)
	
	# Update the crew list display to reflect changes
	_update_crew_list()
	crew_updated.emit(crew_members)
	
	# Remove the customization screen (it will queue_free itself)

func _on_character_customization_cancelled() -> void:
	"""Handle character customization cancellation and close the window"""
	print("CrewPanel: Character customization cancelled - closing window")
	
	# Close the character creator window
	if character_creator and is_instance_valid(character_creator):
		character_creator.queue_free()
		character_creator = null
	
	# Update display
	_update_crew_list()
	crew_updated.emit(crew_members)

func get_crew_data() -> Dictionary:
	"""Return crew data for campaign creation"""
	return {
		"size": selected_size,
		"members": crew_members.duplicate(),
		"captain": current_captain,
		"has_captain": has_captain(),
		"is_complete": crew_members.size() == selected_size and has_captain()
	}

	if crew_list:
		crew_list.item_selected.connect(_on_crew_member_selected)


func _on_crew_member_selected(index: int) -> void:
	if edit_button:
		edit_button.disabled = false
	if remove_button:
		remove_button.disabled = false

	# Show captain assignment option for selected character
	_show_captain_assignment_option(index)

func _show_captain_assignment_option(index: int) -> void:
	"""Show option to make selected character captain with enhanced validation"""
	# Account for status header, summary, and separator (first 3 items)
	var crew_index = index - 3
	if crew_index < 0 or crew_index >= crew_members.size():
		push_warning("CrewPanel: Invalid crew member selection for captain assignment")
		return

	var character: Character = crew_members[crew_index]
	
	# Validate character before showing dialog
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Invalid character selected for captain assignment")
		_show_error_message("Cannot assign captain: Invalid character selected")
		return
	
	if not character.character_name or character.character_name.is_empty():
		push_error("CrewPanel: Cannot assign unnamed character as captain")
		_show_error_message("Cannot assign captain: Character must have a name")
		return
	
	# Check if character is already captain - show different dialog
	if character == current_captain:
		_show_captain_info_dialog(character)
		return

	# Create a detailed popup for captain assignment
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Make %s the captain?\n\nThis will:\n• Assign the 'Captain' title\n• Grant leadership authority\n• Update crew status display" % character.character_name
	confirmation.title = "Assign Captain"
	get_viewport().add_child(confirmation)

	confirmation.confirmed.connect(func(): _make_captain(character))
	confirmation.tree_exited.connect(func(): confirmation.queue_free())

	confirmation.popup_centered()

func _show_captain_info_dialog(character: Character) -> void:
	"""Show information dialog for current captain"""
	var info_dialog = AcceptDialog.new()
	info_dialog.dialog_text = "%s ⭐ is currently the captain.\n\nThis character has the 'Captain' title and leadership authority.\n\nClick 'Edit Member' to customize this character." % character.character_name
	info_dialog.title = "Current Captain"
	get_viewport().add_child(info_dialog)
	info_dialog.confirmed.connect(func(): info_dialog.queue_free())
	info_dialog.popup_centered()

func _make_captain(character: Character) -> void:
	"""Make the specified character the captain with enhanced validation and title assignment"""
	# Enhanced validation first
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Cannot assign invalid character as captain")
		_show_error_message("Cannot assign captain: Invalid character")
		return
	
	if not character.character_name or character.character_name.is_empty():
		push_error("CrewPanel: Cannot assign unnamed character as captain")
		_show_error_message("Cannot assign captain: Character must have a name")
		return
	
	if character not in crew_members:
		push_error("CrewPanel: Character not found in crew roster")
		_show_error_message("Cannot assign captain: Character not in crew")
		return

	# Remove captain status and title from previous captain with validation
	if current_captain and is_instance_valid(current_captain):
		current_captain.is_captain = false
		_remove_captain_title(current_captain)
		print("CrewPanel: Removed captain status from: ", current_captain.character_name)

	# Assign new captain with title
	current_captain = character
	character.is_captain = true
	_assign_captain_title(character)

	print("CrewPanel: Successfully assigned captain: ", character.character_name)

	# Update display and notify
	_update_crew_list()
	crew_updated.emit(crew_members)

func get_captain() -> Character:
	"""Get the current captain"""
	return current_captain


func _assign_captain_title(character: Character) -> void:
	"""Assign the 'Captain' title to a character"""
	if not character or not is_instance_valid(character):
		return
	
	# Add captain title as a trait if not already present
	var captain_trait = "Captain"
	if character.has_method("add_trait"):
		# Check if captain trait already exists
		var traits = safe_get_property(character, "traits", [])
		if not traits.has(captain_trait):
			character.add_trait(captain_trait)
	elif character.has_property("traits"):
		# Fallback for characters without add_trait method
		var traits = character.traits
		if not traits.has(captain_trait):
			traits.append(captain_trait)
			character.traits = traits
	
	print("CrewPanel: Assigned captain title to: ", character.character_name)

func _remove_captain_title(character: Character) -> void:
	"""Remove the 'Captain' title from a character"""
	if not character or not is_instance_valid(character):
		return
	
	var captain_trait = "Captain"
	if character.has_method("remove_trait"):
		character.remove_trait(captain_trait)
	elif character.has_property("traits"):
		# Fallback for characters without remove_trait method
		var traits = character.traits
		traits.erase(captain_trait)
		character.traits = traits
	
	print("CrewPanel: Removed captain title from: ", character.character_name)


func is_valid() -> bool:
	"""Enhanced validation for crew completeness"""
	return crew_members.size() >= selected_size and has_captain()

func validate() -> Array[String]:
	"""Validate crew data and return error messages"""
	var errors: Array[String] = []
	
	if crew_members.size() < selected_size:
		errors.append("Need %d more crew members" % (selected_size - crew_members.size()))
	
	if not has_captain():
		errors.append("Captain is required")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return get_crew_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("size"):
		selected_size = data.size
		_update_crew_size_selector()
	if data.has("members"):
		crew_members = data.members.duplicate()
		_update_crew_list()
	if data.has("captain"):
		current_captain = data.captain
		_update_crew_list()

func get_crew_summary() -> Dictionary:
	"""Get comprehensive crew summary for campaign integration"""
	var summary = {
		"total_members": crew_members.size(),
		"required_members": selected_size,
		"captain": _get_captain_summary(),
		"crew_list": _get_crew_member_summaries(),
		"average_combat": _calculate_average_stat("combat"),
		"average_toughness": _calculate_average_stat("toughness"),
		"total_health": _calculate_total_health(),
		"crew_backgrounds": _get_background_distribution(),
		"crew_motivations": _get_motivation_distribution(),
		"is_complete": is_valid(),
		"completion_percentage": float(crew_members.size()) / float(selected_size) * 100.0
	}
	return summary

func _get_captain_summary() -> Dictionary:
	"""Get captain information summary"""
	if not current_captain:
		return {"exists": false}

	return {
		"exists": true,
		"name": current_captain.character_name,
		"background": GlobalEnums.get_background_display_name(current_captain.background),
		"motivation": GlobalEnums.get_motivation_display_name(current_captain.motivation),
		"combat": current_captain.combat,
		"toughness": current_captain.toughness,
		"health": current_captain.max_health
	}

func _get_crew_member_summaries() -> Array:
	"""Get summary of all crew members"""
	var summaries: Array = []
	for character in crew_members:
		summaries.append({
			"name": character.character_name,
			"background": GlobalEnums.get_background_display_name(character.background),
			"motivation": GlobalEnums.get_motivation_display_name(character.motivation),
			"combat": character.combat,
			"toughness": character.toughness,
			"health": character.max_health,
			"is_captain": character == current_captain
		})
	return summaries

func _calculate_average_stat(stat_name: String) -> float:
	"""Calculate average value for a specific stat"""
	if crew_members.is_empty():
		return 0.0

	var total: int = 0
	for character in crew_members:
		match stat_name:
			"combat":
				total += character.combat
			"toughness":
				total += character.toughness
			"reaction":
				total += character.reaction
			"savvy":
				total += character.savvy
			"tech":
				total += character.tech
			"move":
				total += character.move

	return float(total) / float(crew_members.size())

func _calculate_total_health() -> int:
	"""Calculate total crew health"""
	var total: int = 0
	for character in crew_members:
		total += character.max_health if character.max_health > 0 else (character.toughness + 2)
	return total

func _get_background_distribution() -> Dictionary:
	"""Get distribution of crew backgrounds"""
	var distribution: Dictionary = {}
	for character in crew_members:
		var bg_name = GlobalEnums.get_background_display_name(character.background)
		distribution[bg_name] = distribution.get(bg_name, 0) + 1
	return distribution

func _get_motivation_distribution() -> Dictionary:
	"""Get distribution of crew motivations"""
	var distribution: Dictionary = {}
	for character in crew_members:
		var mot_name = GlobalEnums.get_motivation_display_name(character.motivation)
		distribution[mot_name] = distribution.get(mot_name, 0) + 1
	return distribution

func debug_crew_status():
	"""Debug method to print crew status"""
	print("=== CREW PANEL DEBUG ===")
	print("Crew members: ", crew_members.size(), "/", selected_size)
	print("Has captain: ", has_captain())
	print("Is valid: ", is_valid())
	if current_captain:
		print("Captain: ", current_captain.character_name)
	else:
		print("Captain: None assigned")

	var summary = get_crew_summary()
	print("Average combat: ", summary.average_combat)
	print("Total health: ", summary.total_health)
	print("Completion: ", summary.completion_percentage, "%")
	print("========================")

func _create_five_parsecs_character() -> void:
	"""Create a character using official Five Parsecs generation system"""
	# Use the sophisticated FiveParsecsCharacterGeneration system
	var character: Character = FiveParsecsCharacterGeneration.generate_random_character()

	if character:
		crew_members.append(character)
		print("CrewPanel: Generated Five Parsecs character: ", character.character_name)
	else:
		# Fallback to manual creation if needed
		_create_manual_character()

func _create_manual_character() -> void:
	"""Fallback manual character creation following Five Parsecs crew generation rules"""
	var character: Character = _create_simple_character()
	if character:
		crew_members.append(character)
		_update_crew_list()
		self.crew_updated.emit(crew_members)
	else:
		push_error("CrewPanel: Failed to create manual character")

func _create_simple_character() -> Character:
	"""Create a simple character with minimal dependencies"""
	if not Character:
		push_error("CrewPanel: Character class not available for simple creation")
		return null
	
	var character: Character = Character.new()
	if not character:
		push_error("CrewPanel: Failed to create simple character instance")
		return null
	
	# Set basic properties
	character.character_name = _generate_fallback_name()
	character.origin = GlobalEnums.Origin.HUMAN
	character.background = GlobalEnums.Background.SOLDIER
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Set basic stats (Five Parsecs defaults)
	character.reaction = 2
	character.combat = 1
	character.toughness = 3
	character.savvy = 1
	character.speed = 4
	character.luck = 1
	
	# Set health
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	print("CrewPanel: Created simple character: ", character.character_name)
	return character

func _generate_name_for_origin(origin: GlobalEnums.Origin) -> String:
	"""Generate appropriate names for different character origins"""
	match origin:
		GlobalEnums.Origin.HUMAN:
			var human_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake"]
			return human_names[randi() % human_names.size()]
		GlobalEnums.Origin.ENGINEER:
			var engineer_names = ["Zyx-7", "Klet-Prime", "Vel-9", "Nix-Alpha", "Qor-Beta"]
			return engineer_names[randi() % engineer_names.size()]
		GlobalEnums.Origin.KERIN:
			var kerin_names = ["Thrakk", "Gorvak", "Zarneth", "Kromax", "Balthon"]
			return kerin_names[randi() % kerin_names.size()]
		GlobalEnums.Origin.SOULLESS:
			var soulless_names = ["Unit-47", "Nexus-12", "Prime-3", "Node-89", "Link-156"]
			return soulless_names[randi() % soulless_names.size()]
		GlobalEnums.Origin.PRECURSOR:
			var precursor_names = ["Ethereal-One", "Ancient-Sage", "Star-Walker", "Void-Singer", "Time-Keeper"]
			return precursor_names[randi() % precursor_names.size()]
		GlobalEnums.Origin.SWIFT:
			var swift_names = ["Chirp-Quick", "Dash-Wing", "Fleet-Scale", "Rapid-Tail", "Quick-Dart"]
			return swift_names[randi() % swift_names.size()]
		GlobalEnums.Origin.BOT:
			var bot_names = ["Bot-" + str(randi_range(100, 999)), "Droid-" + str(randi_range(10, 99)), "Mech-" + str(randi_range(1, 50))]
			return bot_names[randi() % bot_names.size()]
		_:
			return "Crew"

func _get_class_for_origin(origin: GlobalEnums.Origin) -> int:
	"""Get appropriate class for character origin"""
	match origin:
		GlobalEnums.Origin.ENGINEER:
			return GlobalEnums.CharacterClass.ENGINEER
		GlobalEnums.Origin.KERIN:
			return GlobalEnums.CharacterClass.SOLDIER
		GlobalEnums.Origin.SOULLESS:
			return GlobalEnums.CharacterClass.SECURITY
		GlobalEnums.Origin.PRECURSOR:
			return GlobalEnums.CharacterClass.PILOT
		GlobalEnums.Origin.FERAL:
			return GlobalEnums.CharacterClass.SECURITY
		GlobalEnums.Origin.SWIFT:
			return GlobalEnums.CharacterClass.PILOT
		GlobalEnums.Origin.BOT:
			return GlobalEnums.CharacterClass.BOT_TECH
		_:
			return GlobalEnums.CharacterClass.SOLDIER

func _update_crew_size_selector() -> void:
	"""Update the crew size selector to reflect the current selected_size"""
	if not crew_size_option:
		return
	
	# Find and select the appropriate crew size option
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == selected_size:
			crew_size_option.select(i)
			break

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object:
		# Handle Resource objects properly - they don't have has() method
		if obj.has_method("get"):
			var value = obj.get(property)
			return value if value != null else default_value
		else:
			return default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
