@tool
extends WorldPhaseComponent
class_name MissionPrepPanel

## Extracted Mission Prep Panel from WorldPhaseUI.gd Monolith
## Handles mission preparation, equipment selection, and crew assignment
## Part of the WorldPhaseUI component extraction strategy

# Mission prep specific signals
signal mission_prep_completed(prep_data: Dictionary)
signal equipment_selected(equipment: Resource, slot: String)
signal crew_assigned(crew_id: String, role: String)
signal mission_prep_automation_toggled(enabled: bool)
signal mission_ready_for_launch(mission_data: Dictionary)

# UI Components for mission prep
var mission_prep_container: Control = null
var equipment_panel: Control = null
var crew_assignment_panel: Control = null
var mission_summary_panel: Control = null
var automation_controls: Control = null

# Mission prep state
var selected_mission: Resource = null
var selected_equipment: Dictionary = {} # slot -> equipment
var crew_assignments: Dictionary = {} # role -> crew_id
var mission_prep_automation_enabled: bool = false
var prep_completion_status: Dictionary = {}

func _init():
	super._init("MissionPrepPanel")

func _setup_component_ui() -> void:
	"""Create the mission prep panel UI"""
	_create_mission_prep_container()
	_create_equipment_panel()
	_create_crew_assignment_panel()
	_create_mission_summary_panel()
	_create_automation_controls()

func _connect_component_signals() -> void:
	"""Connect mission prep specific signals"""
	if parent_ui:
		# Forward mission prep signals to parent WorldPhaseUI
		mission_prep_completed.connect(parent_ui._on_mission_prep_completed)
		equipment_selected.connect(parent_ui._on_equipment_selected)
		crew_assigned.connect(parent_ui._on_crew_assigned)
	
	# Connect to automation controller if available
	_connect_automation_controller_signals()

func _create_mission_prep_container() -> Control:
	"""Create the main container for mission prep UI"""
	mission_prep_container = VBoxContainer.new()
	mission_prep_container.name = "MissionPrepContainer"
	add_child(mission_prep_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Mission Preparation"
	title_label.add_theme_font_size_override("font_size", 18)
	mission_prep_container.add_child(title_label)
	
	return mission_prep_container

func _create_equipment_panel() -> Control:
	"""Create the equipment selection panel"""
	equipment_panel = VBoxContainer.new()
	equipment_panel.name = "EquipmentPanel"
	mission_prep_container.add_child(equipment_panel)
	
	var equipment_title = Label.new()
	equipment_title.text = "Equipment Selection"
	equipment_title.add_theme_font_size_override("font_size", 16)
	equipment_panel.add_child(equipment_title)
	
	# Equipment slots
	var equipment_slots = ["Primary Weapon", "Secondary Weapon", "Armor", "Medical Kit", "Tech Kit"]
	for slot in equipment_slots:
		var slot_container = HBoxContainer.new()
		slot_container.name = "Slot_" + slot.replace(" ", "_")
		
		var slot_label = Label.new()
		slot_label.text = slot + ":"
		slot_label.custom_minimum_size = Vector2(120, 0)
		slot_container.add_child(slot_label)
		
		var equipment_button = Button.new()
		equipment_button.text = "Select Equipment"
		equipment_button.pressed.connect(_on_equipment_slot_pressed.bind(slot))
		slot_container.add_child(equipment_button)
		
		equipment_panel.add_child(slot_container)
	
	return equipment_panel

func _create_crew_assignment_panel() -> Control:
	"""Create the crew assignment panel"""
	crew_assignment_panel = VBoxContainer.new()
	crew_assignment_panel.name = "CrewAssignmentPanel"
	mission_prep_container.add_child(crew_assignment_panel)
	
	var crew_title = Label.new()
	crew_title.text = "Crew Assignment"
	crew_title.add_theme_font_size_override("font_size", 16)
	crew_assignment_panel.add_child(crew_title)
	
	# Crew roles
	var crew_roles = ["Captain", "Pilot", "Engineer", "Medic", "Gunner"]
	for role in crew_roles:
		var role_container = HBoxContainer.new()
		role_container.name = "Role_" + role
		
		var role_label = Label.new()
		role_label.text = role + ":"
		role_label.custom_minimum_size = Vector2(120, 0)
		role_container.add_child(role_label)
		
		var crew_button = Button.new()
		crew_button.text = "Assign Crew"
		crew_button.pressed.connect(_on_crew_role_pressed.bind(role))
		role_container.add_child(crew_button)
		
		crew_assignment_panel.add_child(role_container)
	
	return crew_assignment_panel

func _create_mission_summary_panel() -> Control:
	"""Create the mission summary panel"""
	mission_summary_panel = VBoxContainer.new()
	mission_summary_panel.name = "MissionSummaryPanel"
	mission_prep_container.add_child(mission_summary_panel)
	
	var summary_title = Label.new()
	summary_title.text = "Mission Summary"
	summary_title.add_theme_font_size_override("font_size", 16)
	mission_summary_panel.add_child(summary_title)
	
	var summary_text = RichTextLabel.new()
	summary_text.name = "SummaryText"
	summary_text.custom_minimum_size = Vector2(400, 150)
	summary_text.bbcode_enabled = true
	mission_summary_panel.add_child(summary_text)
	
	var launch_button = Button.new()
	launch_button.name = "LaunchMissionButton"
	launch_button.text = "Launch Mission"
	launch_button.pressed.connect(_on_launch_mission)
	launch_button.disabled = true
	mission_summary_panel.add_child(launch_button)
	
	return mission_summary_panel

func _create_automation_controls() -> Control:
	"""Create automation controls for mission prep"""
	automation_controls = HBoxContainer.new()
	automation_controls.name = "MissionPrepAutomationControls"
	mission_prep_container.add_child(automation_controls)
	
	var automation_toggle = Button.new()
	automation_toggle.text = "Enable Prep Automation"
	automation_toggle.toggle_mode = true
	automation_toggle.toggled.connect(_on_automation_toggled)
	automation_controls.add_child(automation_toggle)
	
	var auto_prep_button = Button.new()
	auto_prep_button.text = "Auto-Prepare Mission"
	auto_prep_button.pressed.connect(_on_auto_prepare_mission)
	automation_controls.add_child(auto_prep_button)
	
	return automation_controls

func _connect_automation_controller_signals() -> void:
	"""Connect to the automation controller"""
	if parent_ui and parent_ui.automation_controller:
		var automation_controller = parent_ui.automation_controller
		
		if automation_controller.has_signal("mission_prep_completed"):
			automation_controller.mission_prep_completed.connect(_on_automation_mission_prep_completed)

# Mission prep functions
func set_mission(mission: Resource) -> void:
	"""Set the mission to prepare for"""
	selected_mission = mission
	_update_mission_summary()
	_log_info("Set mission for preparation: %s" % mission.get_meta("title", "Unknown"))

func _update_mission_summary() -> void:
	"""Update the mission summary display"""
	if not mission_summary_panel:
		return
	
	var summary_text = mission_summary_panel.get_node("SummaryText")
	if not summary_text:
		return
	
	var summary = "[b]Mission:[/b] %s\n" % selected_mission.get_meta("title", "Unknown")
	summary += "[b]Type:[/b] %s\n" % selected_mission.get_meta("type", "Standard")
	summary += "[b]Difficulty:[/b] %d\n" % selected_mission.get_meta("difficulty", 1)
	summary += "[b]Reward:[/b] %d credits\n\n" % selected_mission.get_meta("reward", 0)
	
	summary += "[b]Equipment Slots:[/b] %d/%d filled\n" % [selected_equipment.size(), 5]
	summary += "[b]Crew Assignments:[/b] %d/%d assigned\n" % [crew_assignments.size(), 5]
	
	# Check completion status
	var completion_percentage = _calculate_prep_completion()
	summary += "[b]Preparation:[/b] %d%% complete" % completion_percentage
	
	summary_text.text = summary
	
	# Enable/disable launch button based on completion
	var launch_button = mission_summary_panel.get_node("LaunchMissionButton")
	if launch_button:
		launch_button.disabled = completion_percentage < 100

func _calculate_prep_completion() -> int:
	"""Calculate mission preparation completion percentage"""
	var total_requirements = 10  # 5 equipment slots + 5 crew roles
	var completed_requirements = selected_equipment.size() + crew_assignments.size()
	return int((float(completed_requirements) / float(total_requirements)) * 100)

# Signal handlers
func _on_equipment_slot_pressed(slot: String) -> void:
	"""Handle equipment slot button press"""
	var available_equipment = _get_available_equipment()
	if available_equipment.is_empty():
		_handle_error("No equipment available for selection")
		return
	
	# Auto-select best equipment for slot
	var best_equipment = _select_best_equipment_for_slot(slot, available_equipment)
	if best_equipment:
		selected_equipment[slot] = best_equipment
		equipment_selected.emit(best_equipment, slot)
		_update_mission_summary()
		_log_info("Selected equipment for %s: %s" % [slot, best_equipment.get_meta("name", "Unknown")])

func _on_crew_role_pressed(role: String) -> void:
	"""Handle crew role button press"""
	var available_crew = _get_available_crew()
	if available_crew.is_empty():
		_handle_error("No crew available for assignment")
		return
	
	# Auto-assign best crew for role
	var best_crew = _select_best_crew_for_role(role, available_crew)
	if best_crew:
		crew_assignments[role] = best_crew.id
		crew_assigned.emit(best_crew.id, role)
		_update_mission_summary()
		_log_info("Assigned crew for %s: %s" % [role, best_crew.name])

func _on_launch_mission() -> void:
	"""Handle launch mission button press"""
	if _calculate_prep_completion() < 100:
		_handle_error("Mission preparation incomplete - cannot launch")
		return
	
	var mission_data = {
		"mission": selected_mission,
		"equipment": selected_equipment.duplicate(),
		"crew_assignments": crew_assignments.duplicate(),
		"prep_completion": _calculate_prep_completion(),
		"launch_time": Time.get_unix_time_from_system()
	}
	
	mission_prep_completed.emit(mission_data)
	mission_ready_for_launch.emit(mission_data)
	_log_info("Mission launched successfully")

func _on_automation_toggled(enabled: bool) -> void:
	"""Handle automation toggle"""
	mission_prep_automation_enabled = enabled
	mission_prep_automation_toggled.emit(enabled)
	_log_info("Mission prep automation %s" % ("enabled" if enabled else "disabled"))

func _on_auto_prepare_mission() -> void:
	"""Handle auto-prepare mission button"""
	if not mission_prep_automation_enabled:
		_handle_error("Mission prep automation must be enabled for auto-preparation")
		return
	
	if not selected_mission:
		_handle_error("No mission selected for preparation")
		return
	
	# Auto-select equipment for all slots
	_auto_select_equipment()
	
	# Auto-assign crew for all roles
	_auto_assign_crew()
	
	# Update summary
	_update_mission_summary()
	
	_log_info("Auto-prepared mission: %s" % selected_mission.get_meta("title", "Unknown"))

func _auto_select_equipment() -> void:
	"""Auto-select equipment for all slots"""
	var equipment_slots = ["Primary Weapon", "Secondary Weapon", "Armor", "Medical Kit", "Tech Kit"]
	var available_equipment = _get_available_equipment()
	
	for slot in equipment_slots:
		if slot not in selected_equipment:
			var best_equipment = _select_best_equipment_for_slot(slot, available_equipment)
			if best_equipment:
				selected_equipment[slot] = best_equipment
				equipment_selected.emit(best_equipment, slot)

func _auto_assign_crew() -> void:
	"""Auto-assign crew for all roles"""
	var crew_roles = ["Captain", "Pilot", "Engineer", "Medic", "Gunner"]
	var available_crew = _get_available_crew()
	
	for role in crew_roles:
		if role not in crew_assignments:
			var best_crew = _select_best_crew_for_role(role, available_crew)
			if best_crew:
				crew_assignments[role] = best_crew.id
				crew_assigned.emit(best_crew.id, role)

func _on_automation_mission_prep_completed(prep_data: Dictionary) -> void:
	"""Handle automation controller mission prep completion"""
	_log_info("Mission prep completed via automation controller")
	mission_prep_completed.emit(prep_data)

# Helper functions
func _get_available_equipment() -> Array[Resource]:
	"""Get list of available equipment"""
	# Simplified - in production, this would query the actual equipment manager
	var equipment = []
	for i in range(10):
		var item = Resource.new()
		item.set_meta("name", "Equipment %d" % (i + 1))
		item.set_meta("type", ["weapon", "armor", "medical", "tech"][i % 4])
		item.set_meta("quality", randi_range(1, 5))
		equipment.append(item)
	return equipment

func _get_available_crew() -> Array:
	"""Get list of available crew"""
	# Simplified - in production, this would query the actual crew manager
	return [
		{"id": "crew_001", "name": "Captain Smith", "skills": ["leadership", "combat"]},
		{"id": "crew_002", "name": "Pilot Jones", "skills": ["piloting", "navigation"]},
		{"id": "crew_003", "name": "Engineer Davis", "skills": ["engineering", "repair"]},
		{"id": "crew_004", "name": "Medic Wilson", "skills": ["medical", "science"]},
		{"id": "crew_005", "name": "Gunner Brown", "skills": ["combat", "weapons"]}
	]

func _select_best_equipment_for_slot(slot: String, available_equipment: Array[Resource]) -> Resource:
	"""Select the best equipment for a specific slot"""
	if available_equipment.is_empty():
		return null
	
	# Simple selection - first available equipment of appropriate type
	var slot_type = _get_slot_type(slot)
	for equipment in available_equipment:
		var equipment_type = equipment.get_meta("type", "")
		if equipment_type == slot_type:
			return equipment
	
	# Fallback to first available equipment
	return available_equipment[0] if available_equipment.size() > 0 else null

func _select_best_crew_for_role(role: String, available_crew: Array) -> Dictionary:
	"""Select the best crew member for a specific role"""
	if available_crew.is_empty():
		return {}
	
	# Simple selection - first available crew member
	# In production, this would evaluate skills and experience
	return available_crew[0]

func _get_slot_type(slot: String) -> String:
	"""Get the equipment type for a slot"""
	match slot:
		"Primary Weapon", "Secondary Weapon":
			return "weapon"
		"Armor":
			return "armor"
		"Medical Kit":
			return "medical"
		"Tech Kit":
			return "tech"
		_:
			return "general"

# Component interface methods
func get_selected_equipment() -> Dictionary:
	"""Get currently selected equipment"""
	return selected_equipment.duplicate()

func get_crew_assignments() -> Dictionary:
	"""Get current crew assignments"""
	return crew_assignments.duplicate()

func get_prep_completion_status() -> Dictionary:
	"""Get mission preparation completion status"""
	return {
		"completion_percentage": _calculate_prep_completion(),
		"equipment_slots_filled": selected_equipment.size(),
		"crew_roles_assigned": crew_assignments.size(),
		"mission_ready": _calculate_prep_completion() >= 100
	}

func clear_prep_data() -> void:
	"""Clear all mission prep data (for new mission)"""
	selected_mission = null
	selected_equipment.clear()
	crew_assignments.clear()
	_update_mission_summary()
	_log_info("Cleared all mission prep data")

func get_mission_prep_automation_status() -> Dictionary:
	"""Get mission prep automation status"""
	return {
		"automation_enabled": mission_prep_automation_enabled,
		"mission_selected": selected_mission != null,
		"prep_completion": _calculate_prep_completion()
	}

func get_component_state() -> Dictionary:
	"""Return component state for monitoring"""
	var base_state = super.get_component_state()
	base_state.merge({
		"selected_equipment_count": selected_equipment.size(),
		"crew_assignments_count": crew_assignments.size(),
		"mission_prep_automation_enabled": mission_prep_automation_enabled,
		"prep_completion_percentage": _calculate_prep_completion()
	})
	return base_state 