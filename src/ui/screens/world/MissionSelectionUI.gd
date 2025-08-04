class_name MissionSelectionUI
extends Control

## Mission Selection UI for Five Parsecs Campaign Manager
## Handles mission selection with Five Parsecs mission generation rules
## Integrates with AlphaGameManager and MissionGenerator for proper gameplay

signal mission_selected(mission: Resource)
signal mission_generation_requested()
signal mission_selection_cancelled()

# UI nodes - Updated to match actual scene structure
@onready var popup_panel: PopupPanel = $PopupPanel
@onready var mission_container: HBoxContainer = $PopupPanel/MarginContainer/VBoxContainer/HBoxContainer
@onready var mission_title: Label = $PopupPanel/MarginContainer/VBoxContainer/Label
@onready var close_button: Button = $PopupPanel/MarginContainer/VBoxContainer/CloseButton

# Mission buttons from actual scene
@onready var mission1_button: Button = $PopupPanel/MarginContainer/VBoxContainer/HBoxContainer/Mission1/Button
@onready var mission2_button: Button = $PopupPanel/MarginContainer/VBoxContainer/HBoxContainer/Mission2/Button
@onready var mission3_button: Button = $PopupPanel/MarginContainer/VBoxContainer/HBoxContainer/Mission3/Button

# Additional UI elements referenced in code
@onready var generate_button: Button = get_node_or_null("PopupPanel/MarginContainer/VBoxContainer/GenerateButton")
@onready var cancel_button: Button = get_node_or_null("PopupPanel/MarginContainer/VBoxContainer/CancelButton")
@onready var status_label: Label = get_node_or_null("PopupPanel/MarginContainer/VBoxContainer/StatusLabel")

# Mission data
var available_missions: Array[Resource] = []
var selected_mission: Resource = null
var mission_type: String = "standard"

# Manager references
var alpha_manager: Node = null
var mission_generator: Node = null

func _ready() -> void:
	print("MissionSelectionUI: Initializing...")
	_initialize_managers()
	_connect_signals()
	_setup_ui()

func _initialize_managers() -> void:
	"""Initialize manager references"""
	alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
	if alpha_manager and alpha_manager.has_method("get_mission_generator"):
		mission_generator = alpha_manager.get_mission_generator()
	
	if not mission_generator:
		push_warning("MissionSelectionUI: Mission generator not available")

func _connect_signals() -> void:
	"""Connect UI signals"""
	# Check if nodes exist before connecting
	if generate_button:
		generate_button.pressed.connect(_on_generate_missions)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect mission buttons if they exist
	if mission1_button:
		mission1_button.pressed.connect(_on_mission_selected_by_index.bind(0))
	if mission2_button:
		mission2_button.pressed.connect(_on_mission_selected_by_index.bind(1))
	if mission3_button:
		mission3_button.pressed.connect(_on_mission_selected_by_index.bind(2))

func _setup_ui() -> void:
	"""Setup initial UI state"""
	if popup_panel:
		popup_panel.hide()
	if mission_title:
		mission_title.text = "Available Missions"
	if status_label:
		status_label.text = "Select a mission to begin"

func popup_missions(missions: Array, type: String = "standard") -> void:
	"""Display missions for selection with Five Parsecs formatting"""
	mission_type = type
	available_missions.clear()
	
	# Convert input missions to Resources if needed
	for mission in missions:
		var mission_resource: Resource
		if mission is Resource:
			mission_resource = mission
		else:
			mission_resource = _convert_mission_to_resource(mission)
		available_missions.append(mission_resource)
	
	_update_mission_display()
	if popup_panel:
		popup_panel.popup_centered()
	print("MissionSelectionUI: Displaying %d missions of type: %s" % [available_missions.size(), type])

func _convert_mission_to_resource(mission_data: Variant) -> Resource:
	"""Convert mission data to Resource format"""
	var mission_resource := Resource.new()
	
	if mission_data is Dictionary:
		var mission_dict = mission_data as Dictionary
		for key in mission_dict.keys():
			mission_resource.set_meta(key, mission_dict[key])
	else:
		# Default mission if conversion fails
		mission_resource.set_meta("name", "Unknown Mission")
		mission_resource.set_meta("difficulty", 1)
		mission_resource.set_meta("reward", 300)
		mission_resource.set_meta("description", "Mission details unavailable")
	
	return mission_resource

func _update_mission_display() -> void:
	"""Update the mission list display with Five Parsecs styling"""
	if not mission_container:
		push_warning("MissionSelectionUI: Mission container not found")
		return
	
	# Clear existing missions
	for child in mission_container.get_children():
		child.queue_free()
	
	# Update header - use defensive null check for mission_count_label
	var mission_count_label = get_node_or_null("PopupPanel/MarginContainer/VBoxContainer/MissionCountLabel")
	if mission_count_label and mission_count_label is Label:
		mission_count_label.text = "%d Available" % available_missions.size()
	
	if available_missions.is_empty():
		var no_missions_label := Label.new()
		no_missions_label.text = "No missions available. Generate new missions?"
		no_missions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_missions_label.add_theme_color_override("font_color", Color.GRAY)
		mission_container.add_child(no_missions_label)
		return
	
	# Create mission cards
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var mission_card = _create_mission_card(mission, i)
		mission_container.add_child(mission_card)

func _create_mission_card(mission: Resource, index: int) -> Control:
	"""Create a mission display card with Five Parsecs styling"""
	var card := VBoxContainer.new()
	card.name = "MissionCard_%d" % index
	
	# Mission header
	var header := HBoxContainer.new()
	card.add_child(header)
	
	var name_label := Label.new()
	name_label.text = mission.get_meta("name", "Mission %d" % (index + 1))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(name_label)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var difficulty_label := Label.new()
	var difficulty = mission.get_meta("difficulty", 1)
	difficulty_label.text = "Difficulty: %d" % difficulty
	_apply_difficulty_color(difficulty_label, difficulty)
	header.add_child(difficulty_label)
	
	# Mission type
	var type_label := Label.new()
	type_label.text = "Type: %s" % mission.get_meta("mission_type", "Standard")
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color.CYAN)
	card.add_child(type_label)
	
	# Mission description
	var description_label := Label.new()
	description_label.text = mission.get_meta("description", "No description available")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 11)
	card.add_child(description_label)
	
	# Mission details
	var details_container := HBoxContainer.new()
	card.add_child(details_container)
	
	# Reward
	var reward_label := Label.new()
	var reward = mission.get_meta("reward", 0)
	reward_label.text = "Reward: %d credits" % reward
	_apply_reward_color(reward_label, reward)
	details_container.add_child(reward_label)
	
	var detail_spacer := Control.new()
	detail_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_container.add_child(detail_spacer)
	
	# Enemy count (if available)
	var enemy_count = mission.get_meta("enemy_count", 0)
	if enemy_count > 0:
		var enemy_label := Label.new()
		enemy_label.text = "Enemies: %d" % enemy_count
		enemy_label.add_theme_color_override("font_color", Color.ORANGE)
		enemy_label.add_theme_font_size_override("font_size", 11)
		details_container.add_child(enemy_label)
	
	# Special conditions (if any)
	var conditions = mission.get_meta("special_conditions", [])
	if not conditions.is_empty():
		var conditions_label := Label.new()
		conditions_label.text = "Special: %s" % ", ".join(conditions)
		conditions_label.add_theme_color_override("font_color", Color.YELLOW)
		conditions_label.add_theme_font_size_override("font_size", 10)
		card.add_child(conditions_label)
	
	# Patron information (if available)
	var patron = mission.get_meta("patron", "")
	if not patron.is_empty():
		var patron_label := Label.new()
		patron_label.text = "Patron: %s" % patron
		patron_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		patron_label.add_theme_font_size_override("font_size", 11)
		card.add_child(patron_label)
	
	# Select button
	var select_button := Button.new()
	select_button.text = "Select Mission"
	select_button.pressed.connect(_on_mission_selected.bind(mission))
	_apply_difficulty_button_style(select_button, difficulty)
	card.add_child(select_button)
	
	# Separator
	var separator := HSeparator.new()
	card.add_child(separator)
	
	return card

func _apply_difficulty_color(label: Label, difficulty: int) -> void:
	"""Apply color coding based on difficulty"""
	match difficulty:
		1:
			label.add_theme_color_override("font_color", Color.GREEN)
		2:
			label.add_theme_color_override("font_color", Color.YELLOW)
		3:
			label.add_theme_color_override("font_color", Color.ORANGE)
		4, 5:
			label.add_theme_color_override("font_color", Color.RED)
		_:
			label.add_theme_color_override("font_color", Color.WHITE)

func _apply_reward_color(label: Label, reward: int) -> void:
	"""Apply color coding based on reward amount"""
	if reward >= 800:
		label.add_theme_color_override("font_color", Color.GOLD)
	elif reward >= 500:
		label.add_theme_color_override("font_color", Color.GREEN)
	elif reward >= 300:
		label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

func _apply_difficulty_button_style(button: Button, difficulty: int) -> void:
	"""Apply button styling based on mission difficulty"""
	match difficulty:
		1:
			button.modulate = Color.WHITE
		2:
			button.modulate = Color.LIGHT_GOLDENROD
		3:
			button.modulate = Color.LIGHT_SALMON
		4, 5:
			button.modulate = Color.LIGHT_CORAL
		_:
			button.modulate = Color.WHITE

func _on_mission_selected(mission: Resource) -> void:
	"""Handle mission selection"""
	if not mission:
		print("MissionSelectionUI: Error - null mission selected")
		return
		
	selected_mission = mission
	mission_selected.emit(selected_mission)
	
	# Update UI with mission info
	var mission_name = selected_mission.get_meta("name", "Unknown Mission")
	print("MissionSelectionUI: Mission selected - %s" % mission_name)
	
	if popup_panel:
		popup_panel.hide()

func _on_mission_selected_by_index(mission_index: int) -> void:
	"""Handle mission selection by index (legacy support)"""
	if mission_index < 0 or mission_index >= available_missions.size():
		# Create default missions if none exist
		if available_missions.is_empty():
			_create_default_missions()
		# Clamp to valid range
		mission_index = clampi(mission_index, 0, available_missions.size() - 1)
	
	if mission_index < available_missions.size():
		_on_mission_selected(available_missions[mission_index])

func _on_generate_missions() -> void:
	"""Generate new missions using Five Parsecs rules"""
	if mission_generator:
		var new_missions = mission_generator.generate_missions_for_world(mission_type)
		if not new_missions.is_empty():
			popup_missions(new_missions, mission_type)
			if status_label:
				status_label.text = "Generated %d new missions" % new_missions.size()
		else:
			if status_label:
				status_label.text = "Failed to generate missions"
	else:
		# Fallback mission generation
		_generate_fallback_missions()
	
	mission_generation_requested.emit()

func _generate_fallback_missions() -> void:
	"""Generate missions using fallback system"""
	var fallback_missions: Array[Resource] = []
	var mission_count = randi_range(3, 6)
	
	for i in range(mission_count):
		var mission = _create_fallback_mission(i + 1)
		fallback_missions.append(mission)
	
	available_missions = fallback_missions
	_update_mission_display()
	if status_label:
		status_label.text = "Generated %d fallback missions" % mission_count

func _create_fallback_mission(index: int) -> Resource:
	"""Create a fallback mission using Five Parsecs templates"""
	var mission := Resource.new()
	var mission_types = ["Patrol", "Delivery", "Bounty", "Investigation", "Escort"]
	var mission_type_selected = mission_types[randi() % mission_types.size()]
	var difficulty = randi_range(1, 3)
	
	mission.set_meta("name", "%s Mission %d" % [mission_type_selected, index])
	mission.set_meta("mission_type", mission_type_selected)
	mission.set_meta("difficulty", difficulty)
	mission.set_meta("reward", (200 + (difficulty * 150)) + randi_range(-50, 100))
	mission.set_meta("description", _generate_mission_description(mission_type_selected, difficulty))
	mission.set_meta("enemy_count", randi_range(2, 6))
	
	# Add special conditions for harder missions
	if difficulty >= 3:
		var conditions = ["Night Operations", "Hostile Environment", "Time Pressure"]
		mission.set_meta("special_conditions", [conditions[randi() % conditions.size()]])
	
	# Add patron for some missions
	if randi() % 3 == 0:
		var patrons = ["Corporate Client", "Local Authority", "Independent Trader", "Military Contact"]
		mission.set_meta("patron", patrons[randi() % patrons.size()])
	
	return mission

func _generate_mission_description(mission_type: String, difficulty: int) -> String:
	"""Generate mission description based on type and difficulty"""
	var descriptions = {
		"Patrol": "Secure the perimeter and eliminate hostile contacts",
		"Delivery": "Transport priority cargo to designated coordinates",
		"Bounty": "Locate and neutralize specified targets",
		"Investigation": "Gather intelligence on suspicious activities",
		"Escort": "Provide protection for client during transit"
	}
	
	var base_description = descriptions.get(mission_type, "Complete the assigned objectives")
	var difficulty_modifiers = ["routine", "challenging", "dangerous"]
	var modifier = difficulty_modifiers[min(difficulty - 1, 2)]
	
	return "%s. This is a %s assignment." % [base_description, modifier]

func _create_default_missions() -> void:
	"""Create default missions for testing"""
	available_missions.clear()
	
	# Create 3 simple mission resources to match the scene buttons
	for i in range(3):
		var mission = Resource.new()
		mission.set_meta("name", "Mission %d" % (i + 1))
		mission.set_meta("description", "Default test mission %d" % (i + 1))
		mission.set_meta("reward", 300 + (i * 100))
		mission.set_meta("difficulty", i + 1)
		available_missions.append(mission)
	
	print("MissionSelectionUI: Created %d default missions" % available_missions.size())

func _on_cancel_pressed() -> void:
	"""Handle cancel button press"""
	mission_selection_cancelled.emit()
	if popup_panel:
		popup_panel.hide()
	print("MissionSelectionUI: Mission selection cancelled")

# Legacy support for existing code
func _on_close_pressed() -> void:
	"""Handle close button press - legacy support"""
	_on_cancel_pressed()

func get_selected_mission() -> Resource:
	"""Get the currently selected mission"""
	return selected_mission

func get_available_missions() -> Array[Resource]:
	"""Get all available missions"""
	return available_missions

func set_mission_type(type: String) -> void:
	"""Set the mission type for generation"""
	mission_type = type

func show_mission_selection() -> void:
	"""Show the mission selection popup"""
	if popup_panel:
		popup_panel.popup_centered()

func hide_mission_selection() -> void:
	"""Hide the mission selection popup"""
	if popup_panel:
		popup_panel.hide()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
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
