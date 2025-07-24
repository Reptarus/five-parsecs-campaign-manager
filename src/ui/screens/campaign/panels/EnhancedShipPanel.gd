@tool
extends Control
class_name EnhancedShipPanel

## Enhanced Ship Information Panel - Detailed ship status with visual indicators
## Replaces basic ship info with comprehensive status following Digital Dice System visual patterns
## Provides hull status bars, debt tracking, and modification management

# Universal Safety patterns
const BaseEnhancedComponents = preload("res://src/ui/components/enhanced/BaseEnhancedComponents.gd")
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")

# UI References
@onready var hull_display: ProgressBar = %HullDisplay
@onready var debt_display: Label = %DebtDisplay
@onready var modifications_container: VBoxContainer = %ModificationsContainer
@onready var ship_status_summary: Label = %ShipStatusSummary
@onready var ship_performance_chart: Control = %ShipPerformanceChart
@onready var maintenance_status: Control = %MaintenanceStatus

# Data management
var ship_data: Dictionary = {}
var selected_modification: String = ""
var ship_performance_data: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_ship_panel()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_ship_panel() -> void:
	# Initialize ship display components
	if not hull_display:
		push_warning("EnhancedShipPanel: Hull display not found")
		return
	
	# Setup performance tracking
	_setup_performance_tracking()
	
	# Setup maintenance tracking
	_setup_maintenance_tracking()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect ship-related signals
	enhanced_signals.connect_signal_safely("ship_status_updated", self, "_on_ship_status_updated")
	enhanced_signals.connect_signal_safely("ship_hull_damaged", self, "_on_ship_hull_damaged")
	enhanced_signals.connect_signal_safely("ship_repair_completed", self, "_on_ship_repair_completed")
	enhanced_signals.connect_signal_safely("ship_modification_added", self, "_on_ship_modification_added")
	enhanced_signals.connect_signal_safely("ship_debt_changed", self, "_on_ship_debt_changed")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if hull_display:
		hull_display.custom_minimum_size.y = 30
		hull_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if ship_status_summary:
		ship_status_summary.text = _generate_compact_ship_summary()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if hull_display:
		hull_display.custom_minimum_size.y = 40
		hull_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if ship_status_summary:
		ship_status_summary.text = _generate_detailed_ship_summary()

## Main ship display update function
func display_ship_status(new_ship_data: Dictionary) -> void:
	ship_data = new_ship_data
	
	# Update hull status with visual bar (like dice system animations)
	_update_hull_display()
	
	# Update debt status with color coding (dice system colors)
	_update_debt_display()
	
	# Update modifications list with context
	_update_modifications_display()
	
	# Update summary and performance data
	_update_ship_summary()
	_update_performance_chart()
	_update_maintenance_status()

func _update_hull_display() -> void:
	if not hull_display:
		return
	
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	
	# Animate to value like dice system animations
	hull_display.max_value = hull_max
	hull_display.value = hull_current
	
	# Apply color coding based on hull status
	var hull_ratio = float(hull_current) / float(hull_max) if hull_max > 0 else 0.0
	
	if hull_ratio > 0.7:
		hull_display.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
	elif hull_ratio > 0.4:
		hull_display.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
	else:
		hull_display.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
	
	# Update hull label
	hull_display.set_label_text("Hull: %d/%d" % [hull_current, hull_max])

func _update_debt_display() -> void:
	if not debt_display:
		return
	
	var debt_amount = ship_data.get("debt_amount", 0)
	debt_display.text = "Debt: %d credits" % debt_amount
	_apply_debt_color_coding(debt_display, debt_amount)

func _apply_debt_color_coding(debt_display: Label, debt_amount: int) -> void:
	var warning_level = _calculate_debt_warning(debt_amount)
	match warning_level:
		"critical":
			debt_display.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"warning":
			debt_display.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		_:
			debt_display.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)

func _calculate_debt_warning(debt_amount: int) -> String:
	if debt_amount > 10000:
		return "critical"
	elif debt_amount > 5000:
		return "warning"
	else:
		return "normal"

func _update_modifications_display() -> void:
	if not modifications_container:
		return
	
	# Clear existing modifications
	for child in modifications_container.get_children():
		child.queue_free()
	
	# Add modification cards
	var modifications = ship_data.get("modifications", [])
	for modification in modifications:
		var mod_card = _create_modification_card(modification)
		if mod_card:
			modifications_container.add_child(mod_card)

func _create_modification_card(modification_data: Dictionary) -> Control:
	# Create modification card following dice system design
	var mod_card = BaseInformationCard.new()
	
	# Setup with safety validation
	mod_card.setup_with_safety_validation(modification_data)
	
	# Apply visual styling
	_apply_modification_styling(mod_card, modification_data)
	
	# Connect modification card signals
	mod_card.card_selected.connect(_on_modification_card_selected)
	mod_card.card_action_requested.connect(_on_modification_action_requested)
	
	return mod_card

func _apply_modification_styling(mod_card: Control, modification_data: Dictionary) -> void:
	var mod_type = modification_data.get("type", "unknown")
	var status = modification_data.get("status", "active")
	
	match status:
		"damaged":
			mod_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"maintenance":
			mod_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"active":
			mod_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			mod_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_ship_summary() -> void:
	if not ship_status_summary:
		return
	
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	var debt_amount = ship_data.get("debt_amount", 0)
	var modifications_count = ship_data.get("modifications", []).size()
	
	# Update summary with contextual information
	ship_status_summary.text = "Ship: %d%% Hull, %d Debt, %d Mods" % [
		(hull_current * 100) / hull_max if hull_max > 0 else 0,
		debt_amount,
		modifications_count
	]

func _update_performance_chart() -> void:
	if not ship_performance_chart:
		return
	
	# Update performance visualization
	var performance_data = _calculate_ship_performance()
	ship_performance_chart.update_performance_display(performance_data)

func _update_maintenance_status() -> void:
	if not maintenance_status:
		return
	
	# Update maintenance status
	var maintenance_data = _calculate_maintenance_status()
	maintenance_status.update_maintenance_display(maintenance_data)

func _calculate_ship_performance() -> Dictionary:
	var performance = {
		"hull_efficiency": 0.0,
		"debt_ratio": 0.0,
		"modification_bonus": 0.0,
		"overall_rating": 0.0
	}
	
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	var debt_amount = ship_data.get("debt_amount", 0)
	var modifications = ship_data.get("modifications", [])
	
	# Calculate hull efficiency
	performance.hull_efficiency = float(hull_current) / float(hull_max) if hull_max > 0 else 0.0
	
	# Calculate debt ratio (lower is better)
	performance.debt_ratio = min(float(debt_amount) / 10000.0, 1.0)
	
	# Calculate modification bonus
	var total_bonus = 0.0
	for modification in modifications:
		if modification.get("status") == "active":
			total_bonus += modification.get("bonus", 0.0)
	performance.modification_bonus = total_bonus
	
	# Calculate overall rating
	performance.overall_rating = (
		performance.hull_efficiency * 0.4 +
		(1.0 - performance.debt_ratio) * 0.3 +
		min(performance.modification_bonus / 10.0, 1.0) * 0.3
	)
	
	return performance

func _calculate_maintenance_status() -> Dictionary:
	var maintenance = {
		"needs_repair": false,
		"needs_maintenance": false,
		"upcoming_maintenance": false,
		"maintenance_cost": 0
	}
	
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	var modifications = ship_data.get("modifications", [])
	
	# Check hull status
	if float(hull_current) / float(hull_max) < 0.5:
		maintenance.needs_repair = true
		maintenance.maintenance_cost += 500
	
	# Check modifications status
	for modification in modifications:
		if modification.get("status") == "damaged":
			maintenance.needs_repair = true
			maintenance.maintenance_cost += 200
		elif modification.get("status") == "maintenance":
			maintenance.needs_maintenance = true
			maintenance.maintenance_cost += 100
	
	return maintenance

## Signal handlers
func _on_ship_status_updated(ship_data: Dictionary) -> void:
	display_ship_status(ship_data)

func _on_ship_hull_damaged(damage_amount: int) -> void:
	var current_hull = ship_data.get("hull_current", 0)
	ship_data["hull_current"] = max(0, current_hull - damage_amount)
	_update_hull_display()

func _on_ship_repair_completed(repair_amount: int) -> void:
	var current_hull = ship_data.get("hull_current", 0)
	var max_hull = ship_data.get("hull_max", 100)
	ship_data["hull_current"] = min(max_hull, current_hull + repair_amount)
	_update_hull_display()

func _on_ship_modification_added(modification: Dictionary) -> void:
	var modifications = ship_data.get("modifications", [])
	modifications.append(modification)
	ship_data["modifications"] = modifications
	_update_modifications_display()

func _on_ship_debt_changed(new_debt: int) -> void:
	ship_data["debt_amount"] = new_debt
	_update_debt_display()

func _on_modification_card_selected(card_data: Dictionary) -> void:
	selected_modification = card_data.get("modification_id", "")
	enhanced_signals.emit_safe_signal("ship_modification_selected", [selected_modification])

func _on_modification_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

## Helper functions
func _generate_compact_ship_summary() -> String:
	var hull_ratio = float(ship_data.get("hull_current", 0)) / float(ship_data.get("hull_max", 100))
	var debt = ship_data.get("debt_amount", 0)
	
	return "Ship: %.0f%% Hull, %d Debt" % [hull_ratio * 100, debt]

func _generate_detailed_ship_summary() -> String:
	var hull_current = ship_data.get("hull_current", 0)
	var hull_max = ship_data.get("hull_max", 100)
	var debt_amount = ship_data.get("debt_amount", 0)
	var modifications_count = ship_data.get("modifications", []).size()
	
	return "Ship Status: %d/%d Hull | %d Debt | %d Modifications" % [
		hull_current, hull_max, debt_amount, modifications_count
	]

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	ship_performance_data = {}

func _setup_maintenance_tracking() -> void:
	# Initialize maintenance tracking system
	pass

## Public API for external access
func get_ship_data() -> Dictionary:
	return ship_data

func get_selected_modification() -> String:
	return selected_modification

func get_ship_performance_data() -> Dictionary:
	return ship_performance_data

func refresh_display() -> void:
	display_ship_status(ship_data)