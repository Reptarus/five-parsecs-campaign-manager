@tool
extends WorldPhaseComponent
class_name UpkeepPanel

## Extracted Upkeep Panel from WorldPhaseUI.gd Monolith
## Handles upkeep calculations, ship maintenance, and cost tracking
## Part of the WorldPhaseUI component extraction strategy

# Upkeep specific signals
signal upkeep_calculated(total_cost: int, breakdown: Dictionary)
signal ship_maintenance_completed(maintenance_type: String, cost: int)
signal upkeep_automation_toggled(enabled: bool)
signal upkeep_step_completed(results: Dictionary)

# UI Components for upkeep
var upkeep_container: Control = null
var cost_breakdown_display: Control = null
var maintenance_panel: Control = null
var automation_controls: Control = null

# Upkeep state
var total_upkeep_cost: int = 0
var cost_breakdown: Dictionary = {}
var maintenance_items: Array[Dictionary] = []
var upkeep_automation_enabled: bool = false

func _init():
	super._init("UpkeepPanel")

func _setup_component_ui() -> void:
	"""Create the upkeep panel UI"""
	_create_upkeep_container()
	_create_cost_breakdown_display()
	_create_maintenance_panel()
	_create_automation_controls()

func _connect_component_signals() -> void:
	"""Connect upkeep specific signals"""
	if parent_ui:
		# Forward upkeep signals to parent WorldPhaseUI
		upkeep_calculated.connect(parent_ui._on_upkeep_calculated)
		ship_maintenance_completed.connect(parent_ui._on_ship_maintenance_completed)
	
	# Connect to automation controller if available
	_connect_automation_controller_signals()

func _create_upkeep_container() -> Control:
	"""Create the main container for upkeep UI"""
	upkeep_container = VBoxContainer.new()
	upkeep_container.name = "UpkeepContainer"
	add_child(upkeep_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Upkeep Phase"
	title_label.add_theme_font_size_override("font_size", 18)
	upkeep_container.add_child(title_label)
	
	return upkeep_container

func _create_cost_breakdown_display() -> Control:
	"""Create the cost breakdown display"""
	cost_breakdown_display = VBoxContainer.new()
	cost_breakdown_display.name = "CostBreakdownDisplay"
	upkeep_container.add_child(cost_breakdown_display)
	
	var breakdown_title = Label.new()
	breakdown_title.text = "Cost Breakdown"
	breakdown_title.add_theme_font_size_override("font_size", 16)
	cost_breakdown_display.add_child(breakdown_title)
	
	var total_cost_label = Label.new()
	total_cost_label.name = "TotalCostLabel"
	total_cost_label.text = "Total Cost: 0 credits"
	total_cost_label.add_theme_font_size_override("font_size", 14)
	cost_breakdown_display.add_child(total_cost_label)
	
	return cost_breakdown_display

func _create_maintenance_panel() -> Control:
	"""Create the ship maintenance panel"""
	maintenance_panel = VBoxContainer.new()
	maintenance_panel.name = "MaintenancePanel"
	upkeep_container.add_child(maintenance_panel)
	
	var maintenance_title = Label.new()
	maintenance_title.text = "Ship Maintenance"
	maintenance_title.add_theme_font_size_override("font_size", 16)
	maintenance_panel.add_child(maintenance_title)
	
	# Add maintenance options
	var maintenance_types = ["Engine Repair", "Hull Repair", "Weapon Maintenance", "Life Support"]
	for maintenance_type in maintenance_types:
		var maintenance_button = Button.new()
		maintenance_button.text = maintenance_type
		maintenance_button.pressed.connect(_on_maintenance_pressed.bind(maintenance_type))
		maintenance_panel.add_child(maintenance_button)
	
	return maintenance_panel

func _create_automation_controls() -> Control:
	"""Create automation controls for upkeep"""
	automation_controls = HBoxContainer.new()
	automation_controls.name = "UpkeepAutomationControls"
	upkeep_container.add_child(automation_controls)
	
	var automation_toggle = Button.new()
	automation_toggle.text = "Enable Upkeep Automation"
	automation_toggle.toggle_mode = true
	automation_toggle.toggled.connect(_on_automation_toggled)
	automation_controls.add_child(automation_toggle)
	
	var auto_calculate_button = Button.new()
	auto_calculate_button.text = "Auto-Calculate Upkeep"
	auto_calculate_button.pressed.connect(_on_auto_calculate_upkeep)
	automation_controls.add_child(auto_calculate_button)
	
	return automation_controls

func _connect_automation_controller_signals() -> void:
	"""Connect to the automation controller"""
	if parent_ui and parent_ui.automation_controller:
		var automation_controller = parent_ui.automation_controller
		
		if automation_controller.has_signal("upkeep_calculation_completed"):
			automation_controller.upkeep_calculation_completed.connect(_on_automation_upkeep_completed)

# Upkeep calculation functions
func calculate_upkeep_costs() -> Dictionary:
	"""Calculate all upkeep costs"""
	var costs = {
		"ship_maintenance": _calculate_ship_maintenance_cost(),
		"crew_salaries": _calculate_crew_salaries(),
		"supplies": _calculate_supplies_cost(),
		"insurance": _calculate_insurance_cost(),
		"total": 0
	}
	
	costs.total = costs.ship_maintenance + costs.crew_salaries + costs.supplies + costs.insurance
	total_upkeep_cost = costs.total
	cost_breakdown = costs
	
	_update_cost_display()
	upkeep_calculated.emit(total_upkeep_cost, cost_breakdown)
	
	_log_info("Calculated upkeep costs: %d credits" % total_upkeep_cost)
	return costs

func _calculate_ship_maintenance_cost() -> int:
	"""Calculate ship maintenance costs"""
	# Simplified calculation - in production, this would check ship condition
	var base_cost = 50
	var condition_modifier = 1.0  # Would be based on actual ship condition
	
	# Add costs for completed maintenance items
	for maintenance in maintenance_items:
		if maintenance.get("completed", false):
			base_cost += maintenance.get("cost", 0)
	
	return int(base_cost * condition_modifier)

func _calculate_crew_salaries() -> int:
	"""Calculate crew salary costs"""
	# Simplified calculation - in production, this would count actual crew
	var crew_count = _get_crew_count()
	var base_salary = 20
	return crew_count * base_salary

func _calculate_supplies_cost() -> int:
	"""Calculate supplies cost"""
	# Simplified calculation
	var base_supplies = 30
	var crew_count = _get_crew_count()
	return base_supplies + (crew_count * 5)

func _calculate_insurance_cost() -> int:
	"""Calculate insurance costs"""
	# Simplified calculation
	var base_insurance = 25
	var ship_value = _get_ship_value()
	return base_insurance + int(ship_value * 0.01)

func _get_crew_count() -> int:
	"""Get current crew count"""
	# Simplified - in production, this would query the actual crew manager
	if parent_ui and parent_ui.has_method("get_crew_count"):
		return parent_ui.get_crew_count()
	return 4  # Mock value

func _get_ship_value() -> int:
	"""Get current ship value"""
	# Simplified - in production, this would calculate actual ship value
	return 5000  # Mock value

func _update_cost_display() -> void:
	"""Update the cost breakdown display"""
	if not cost_breakdown_display:
		return
	
	# Update total cost label
	var total_cost_label = cost_breakdown_display.get_node("TotalCostLabel")
	if total_cost_label:
		total_cost_label.text = "Total Cost: %d credits" % total_upkeep_cost
	
	# Clear existing breakdown items
	for child in cost_breakdown_display.get_children():
		if child.name.begins_with("CostItem"):
			child.queue_free()
	
	# Add breakdown items
	for cost_type in cost_breakdown.keys():
		if cost_type != "total":
			var cost_item = Label.new()
			cost_item.name = "CostItem_" + cost_type
			cost_item.text = "%s: %d credits" % [cost_type.replace("_", " ").capitalize(), cost_breakdown[cost_type]]
			cost_item.add_theme_font_size_override("font_size", 12)
			cost_breakdown_display.add_child(cost_item)

# Signal handlers
func _on_maintenance_pressed(maintenance_type: String) -> void:
	"""Handle maintenance button press"""
	var maintenance_cost = _calculate_maintenance_cost(maintenance_type)
	
	var maintenance_data = {
		"type": maintenance_type,
		"cost": maintenance_cost,
		"completed": true,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	maintenance_items.append(maintenance_data)
	ship_maintenance_completed.emit(maintenance_type, maintenance_cost)
	
	# Recalculate total costs
	calculate_upkeep_costs()
	
	_log_info("Completed maintenance: %s (Cost: %d credits)" % [maintenance_type, maintenance_cost])

func _calculate_maintenance_cost(maintenance_type: String) -> int:
	"""Calculate cost for specific maintenance type"""
	match maintenance_type:
		"Engine Repair":
			return randi_range(20, 40)
		"Hull Repair":
			return randi_range(30, 60)
		"Weapon Maintenance":
			return randi_range(15, 35)
		"Life Support":
			return randi_range(10, 25)
		_:
			return randi_range(20, 40)

func _on_automation_toggled(enabled: bool) -> void:
	"""Handle automation toggle"""
	upkeep_automation_enabled = enabled
	upkeep_automation_toggled.emit(enabled)
	_log_info("Upkeep automation %s" % ("enabled" if enabled else "disabled"))

func _on_auto_calculate_upkeep() -> void:
	"""Handle auto-calculate upkeep button"""
	if not upkeep_automation_enabled:
		_handle_error("Upkeep automation must be enabled for auto-calculation")
		return
	
	# Auto-calculate all upkeep costs
	var results = calculate_upkeep_costs()
	
	# Auto-complete basic maintenance if automation is enabled
	if upkeep_automation_enabled:
		_auto_complete_basic_maintenance()
	
	upkeep_step_completed.emit(results)
	_log_info("Auto-calculated upkeep costs: %d credits" % results.total)

func _auto_complete_basic_maintenance() -> void:
	"""Auto-complete basic maintenance items"""
	var basic_maintenance = ["Life Support", "Weapon Maintenance"]
	
	for maintenance_type in basic_maintenance:
		var cost = _calculate_maintenance_cost(maintenance_type)
		var maintenance_data = {
			"type": maintenance_type,
			"cost": cost,
			"completed": true,
			"timestamp": Time.get_unix_time_from_system(),
			"auto_completed": true
		}
		maintenance_items.append(maintenance_data)
		ship_maintenance_completed.emit(maintenance_type, cost)
	
	_log_info("Auto-completed basic maintenance items")

func _on_automation_upkeep_completed(results: Dictionary) -> void:
	"""Handle automation controller upkeep completion"""
	_log_info("Upkeep completed via automation controller")
	upkeep_step_completed.emit(results)

# Component interface methods
func get_upkeep_costs() -> Dictionary:
	"""Get current upkeep cost breakdown"""
	return cost_breakdown.duplicate()

func get_maintenance_items() -> Array[Dictionary]:
	"""Get completed maintenance items"""
	return maintenance_items.duplicate()

func clear_upkeep_data() -> void:
	"""Clear all upkeep data (for new world phase)"""
	total_upkeep_cost = 0
	cost_breakdown.clear()
	maintenance_items.clear()
	_update_cost_display()
	_log_info("Cleared all upkeep data")

func get_upkeep_automation_status() -> Dictionary:
	"""Get upkeep automation status"""
	return {
		"automation_enabled": upkeep_automation_enabled,
		"total_cost": total_upkeep_cost,
		"maintenance_items_count": maintenance_items.size()
	}

func get_component_state() -> Dictionary:
	"""Return component state for monitoring"""
	var base_state = super.get_component_state()
	base_state.merge({
		"total_upkeep_cost": total_upkeep_cost,
		"maintenance_items_count": maintenance_items.size(),
		"upkeep_automation_enabled": upkeep_automation_enabled,
		"cost_breakdown_keys": cost_breakdown.keys()
	})
	return base_state 