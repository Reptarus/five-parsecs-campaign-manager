@tool
extends BaseCrewComponent
class_name EnhancedCrewPanel

## Enhanced Crew Display Panel - Comprehensive crew management with detailed stats and status
## Now extends BaseCrewComponent for shared crew management functionality
## Provides rich information cards with enhanced visual features

# Universal Safety patterns
const BaseEnhancedComponents = preload("res://src/ui/components/enhanced/BaseEnhancedComponents.gd")
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const FPCM_CampaignResponsiveLayout = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")

# UI References
@onready var crew_container: VBoxContainer = %CrewContainer
@onready var crew_summary: Label = %CrewSummary
@onready var crew_status_overview: Control = %CrewStatusOverview
@onready var crew_performance_chart: Control = %CrewPerformanceChart
@onready var crew_equipment_summary: Control = %CrewEquipmentSummary

# Enhanced display data (BaseCrewComponent handles core crew data)
var crew_display_data: Array[Dictionary] = []
var selected_crew_member: String = ""
var crew_performance_data: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	# Call parent initialization first
	super._ready()
	
	print("EnhancedCrewPanel: Initializing enhanced crew display panel...")
	call_deferred("_setup_enhanced_panel")

func _setup_enhanced_panel() -> void:
	_setup_crew_panel()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_crew_panel() -> void:
	# Initialize crew display components
	if not crew_container:
		push_warning("EnhancedCrewPanel: Crew container not found")
		return
	
	# Setup performance tracking
	_setup_performance_tracking()
	
	# Setup equipment summary
	_setup_equipment_summary()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect crew-related signals
	enhanced_signals.connect_signal_safely("crew_status_changed", self, "_on_crew_status_changed")
	enhanced_signals.connect_signal_safely("crew_performance_updated", self, "_on_crew_performance_updated")
	enhanced_signals.connect_signal_safely("crew_equipment_changed", self, "_on_crew_equipment_changed")
	enhanced_signals.connect_signal_safely("crew_health_changed", self, "_on_crew_health_changed")
	
	# Connect to base component signals for crew updates
	crew_updated.connect(_on_base_crew_updated)
	crew_member_selected.connect(_on_base_crew_member_selected)

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

## Main crew display update function - uses BaseCrewComponent crew data
func update_crew_display(display_data: Array = []) -> void:
	# Use base component crew members if no display data provided
	var display_crew = display_data if not display_data.is_empty() else _convert_crew_to_display_data()
	crew_display_data = display_crew
	
	# Clear existing crew cards
	_clear_crew_cards()
	
	# Create enhanced crew cards following dice system patterns
	for member in crew_display_data:
		var crew_card = _create_enhanced_crew_card(member)
		if crew_card:
			crew_container.add_child(crew_card)
	
	# Update summary and performance data
	_update_crew_summary()
	_update_performance_chart()
	_update_equipment_summary()

func _convert_crew_to_display_data() -> Array[Dictionary]:
	"""Convert BaseCrewComponent Character objects to display data format"""
	var display_data: Array[Dictionary] = []
	
	for character in crew_members:
		if not character or not is_instance_valid(character):
			continue
			
		var display_member = {
			"id": character.character_name,
			"name": character.character_name,
			"status": "active",  # Default status
			"health_ratio": float(character.health) / float(character.max_health) if character.max_health > 0 else 1.0,
			"stats": {
				"combat": character.combat,
				"reaction": character.reaction,
				"toughness": character.toughness,
				"savvy": character.savvy,
				"tech": character.tech,
				"speed": character.speed,
				"survival_rate": float(character.health) / float(character.max_health) if character.max_health > 0 else 1.0
			},
			"equipment": {
				"weapons": [],
				"armor": [],
				"gear": [],
				"upgrades": []
			},
			"missions": {
				"total": 0,
				"successful": 0
			}
		}
		
		display_data.append(display_member)
	
	return display_data

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
	
	var total_crew = crew_display_data.size()
	var active_crew = 0
	var injured_crew = 0
	var total_health = 0.0
	
	for member in crew_display_data:
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
	var crew_count = crew_display_data.size()
	
	for member in crew_display_data:
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
	
	for member in crew_display_data:
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
	# Update crew member status in local display data
	for member in crew_display_data:
		if member.get("id") == crew_member:
			member.merge(status)
			break
	
	# Refresh display
	update_crew_display(crew_display_data)

func _on_crew_performance_updated(crew_id: String, performance: Dictionary) -> void:
	crew_performance_data[crew_id] = performance
	_update_performance_chart()

func _on_crew_equipment_changed(crew_id: String, equipment: Dictionary) -> void:
	# Update crew member equipment in display data
	for member in crew_display_data:
		if member.get("id") == crew_id:
			member["equipment"] = equipment
			break
	
	_update_equipment_summary()

func _on_crew_health_changed(crew_id: String, health_ratio: float) -> void:
	# Update crew member health in display data
	for member in crew_display_data:
		if member.get("id") == crew_id:
			member["health_ratio"] = health_ratio
			break
	
	# Refresh display with updated health
	update_crew_display(crew_display_data)

## Base component signal handlers
func _on_base_crew_updated(crew: Array) -> void:
	"""Handle crew updates from BaseCrewComponent"""
	print("EnhancedCrewPanel: Crew updated from base component, refreshing enhanced display...")
	update_crew_display()  # Will auto-convert base crew data to display format

func _on_base_crew_member_selected(member: Character) -> void:
	"""Handle crew member selection from BaseCrewComponent"""
	if member and is_instance_valid(member):
		selected_crew_member = member.character_name
		enhanced_signals.emit_safe_signal("crew_member_selected", [selected_crew_member])

## Helper functions
func _generate_compact_crew_summary() -> String:
	var active_count = 0
	for member in crew_display_data:
		if member.get("status") == "active":
			active_count += 1
	
	return "Crew: %d/%d Active" % [active_count, crew_display_data.size()]

func _generate_detailed_crew_summary() -> String:
	var active_count = 0
	var injured_count = 0
	var total_health = 0.0
	
	for member in crew_display_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_count += 1
		elif status == "injured":
			injured_count += 1
		
		total_health += health
	
	var avg_health = total_health / crew_display_data.size() if crew_display_data.size() > 0 else 0.0
	
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
	# Return base component crew members (Character objects)
	return get_crew_members()

func get_crew_display_data() -> Array:
	# Return enhanced display data (Dictionary format)
	return crew_display_data

func get_selected_crew_member() -> String:
	return selected_crew_member

func get_crew_performance_data() -> Dictionary:
	return crew_performance_data

func refresh_display() -> void:
	update_crew_display()  # Will auto-refresh from base component data

## Additional public methods for enhanced functionality
func add_crew_member_enhanced(character: Character) -> bool:
	"""Add crew member using base component with enhanced display refresh"""
	var success = add_crew_member(character)  # Use BaseCrewComponent method
	if success:
		update_crew_display()  # Refresh enhanced display
	return success

func remove_crew_member_enhanced(character: Character) -> bool:
	"""Remove crew member using base component with enhanced display refresh"""
	var success = remove_crew_member(character)  # Use BaseCrewComponent method
	if success:
		update_crew_display()  # Refresh enhanced display
	return success