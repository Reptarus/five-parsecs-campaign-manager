@tool
extends Panel
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/components/ActionPanel.gd")

# Signals
signal action_selected(action_name: String)
signal action_executed(action_name: String, result: Dictionary)
signal phase_action_completed(phase_name: String)

# Constants
const PHASE_CATEGORIES = {
	"upkeep": {
		"color": Color(0.2, 0.8, 0.2), # Green
		"icon": "res://assets/icons/upkeep.png",
		"description": "Handle crew upkeep and ship maintenance"
	},
	"world_step": {
		"color": Color(0.4, 0.6, 0.9), # Light Blue
		"icon": "res://assets/icons/world.png",
		"description": "Handle world events and local activities"
	},
	"travel": {
		"color": Color(0.8, 0.6, 0.2), # Orange
		"icon": "res://assets/icons/travel.png",
		"description": "Travel between locations and handle travel events"
	},
	"patrons": {
		"color": Color(0.9, 0.8, 0.2), # Gold
		"icon": "res://assets/icons/patron.png",
		"description": "Interact with patrons and handle job offers"
	},
	"battle": {
		"color": Color(0.8, 0.2, 0.2), # Red
		"icon": "res://assets/icons/battle.png",
		"description": "Engage in tactical combat missions"
	},
	"post_battle": {
		"color": Color(0.6, 0.4, 0.8), # Purple
		"icon": "res://assets/icons/post_battle.png",
		"description": "Handle post-battle resolution and rewards"
	},
	"management": {
		"color": Color(0.2, 0.6, 1.0), # Blue
		"icon": "res://assets/icons/management.png",
		"description": "Manage crew, equipment, and resources"
	}
}

# Action requirement types
enum RequirementType {
	CREDITS,
	STORY_POINTS,
	REPUTATION,
	SUPPLIES,
	INTEL,
	SALVAGE,
	CHARACTER_STAT,
	ITEM,
	LOCATION_TYPE
}

# Node references
@onready var category_tabs: TabContainer = $VBoxContainer/CategoryTabs
@onready var action_container: VBoxContainer = $VBoxContainer/ScrollContainer/ActionContainer
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionPanel/MarginContainer/Description
@onready var cost_container: VBoxContainer = $VBoxContainer/CostPanel/MarginContainer/CostContainer

# Properties
var current_phase: String = ""
var available_actions: Dictionary = {}
var selected_action: String = ""
var phase_requirements: Dictionary = {}

# Action button scene
var action_button_scene = preload("res://src/scenes/campaign/components/ActionButton.tscn")

# Factory functions for creating objects instead of classes

# Create an action requirement
static func create_requirement(p_type: int, p_value: Variant, p_description: String = "") -> Dictionary:
	return {
		"type": p_type,
		"value": p_value,
		"description": p_description
	}

# Check if a requirement is met by the given state
static func requirement_is_met(requirement: Dictionary, state: Dictionary) -> bool:
	match requirement.type:
		RequirementType.CREDITS:
			return state.get("credits", 0) >= requirement.value
		RequirementType.STORY_POINTS:
			return state.get("story_points", 0) >= requirement.value
		RequirementType.REPUTATION:
			return state.get("reputation", 0) >= requirement.value
		RequirementType.SUPPLIES:
			return state.get("supplies", 0) >= requirement.value
		RequirementType.INTEL:
			return state.get("intel", 0) >= requirement.value
		RequirementType.SALVAGE:
			return state.get("salvage", 0) >= requirement.value
		# Add other types as needed
	return false

# Create an action data object
static func create_action(p_name: String, p_description: String, p_icon: String, p_category: String) -> Dictionary:
	return {
		"name": p_name,
		"description": p_description,
		"icon": p_icon,
		"category": p_category,
		"requirements": []
	}

# Add a requirement to an action
static func add_requirement(action: Dictionary, requirement: Dictionary) -> void:
	action.requirements.append(requirement)

# Check if an action meets all requirements
static func meets_requirements(action: Dictionary, state: Dictionary) -> bool:
	for req in action.requirements:
		if not requirement_is_met(req, state):
			return false
	return true

func _ready() -> void:
	_setup_ui()
	_setup_phase_requirements()

func _setup_ui() -> void:
	# Set up phase tabs
	for phase in PHASE_CATEGORIES:
		var tab = VBoxContainer.new()
		tab.name = phase.capitalize()
		category_tabs.add_child(tab)
		
		# Add phase description
		var description = Label.new()
		description.text = PHASE_CATEGORIES[phase].description
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tab.add_child(description)

func _setup_phase_requirements() -> void:
	phase_requirements = {
		"upkeep": [
			create_requirement(RequirementType.CREDITS, 10, "Requires credits for upkeep")
		],
		"world_step": [
			create_requirement(RequirementType.SUPPLIES, 1, "Requires supplies for local activities")
		],
		"travel": [
			create_requirement(RequirementType.SUPPLIES, 2, "Requires supplies for travel")
		],
		"patrons": [], # No special requirements for patron interactions
		"battle": [
			create_requirement(RequirementType.SUPPLIES, 1, "Requires supplies for battle")
		],
		"post_battle": [], # No special requirements for post-battle
		"management": [
			create_requirement(RequirementType.CREDITS, 50, "Requires credits for management actions")
		]
	}

func set_phase(phase_name: String) -> void:
	if phase_name == current_phase:
		return
		
	current_phase = phase_name
	_update_available_actions()
	
	# Select the appropriate tab
	for i in category_tabs.get_tab_count():
		if category_tabs.get_tab_title(i).to_lower() == phase_name:
			category_tabs.current_tab = i
			break

func _update_available_actions() -> void:
	# Clear existing actions
	for child in action_container.get_children():
		child.queue_free()
	
	# Add phase-specific actions
	var phase_actions = _get_phase_actions(current_phase)
	for action in phase_actions:
		_add_action_button(action)

func _get_phase_actions(phase: String) -> Array:
	var actions: Array = []
	
	match phase:
		"upkeep":
			actions.append_array(_create_upkeep_actions())
		"world_step":
			actions.append_array(_create_world_actions())
		"travel":
			actions.append_array(_create_travel_actions())
		"patrons":
			actions.append_array(_create_patron_actions())
		"battle":
			actions.append_array(_create_battle_actions())
		"post_battle":
			actions.append_array(_create_post_battle_actions())
		"management":
			actions.append_array(_create_management_actions())
	
	return actions

func _create_upkeep_actions() -> Array:
	var actions: Array = []
	
	var maintain = create_action(
		"Maintain Equipment",
		"Perform routine maintenance on equipment",
		"res://assets/icons/upkeep.png",
		"maintenance"
	)
	add_requirement(maintain, create_requirement(RequirementType.CREDITS, 10, "Requires credits for upkeep"))
	actions.append(maintain)
	
	var resupply = create_action(
		"Resupply",
		"Purchase necessary supplies",
		"res://assets/icons/upkeep.png",
		"logistics"
	)
	add_requirement(resupply, create_requirement(RequirementType.CREDITS, 20, "Requires credits for resupply"))
	actions.append(resupply)
	
	return actions

func _create_world_actions() -> Array:
	var actions: Array = []
	
	var explore = create_action(
		"Explore Area",
		"Search the local area for opportunities",
		"res://assets/icons/world.png",
		"exploration"
	)
	add_requirement(explore, create_requirement(RequirementType.SUPPLIES, 1, "Requires supplies for exploration"))
	actions.append(explore)
	
	var gather = create_action(
		"Gather Intel",
		"Collect information about the area",
		"res://assets/icons/world.png",
		"information"
	)
	add_requirement(gather, create_requirement(RequirementType.CREDITS, 10, "Requires credits for gathering intel"))
	actions.append(gather)
	
	return actions

func _create_travel_actions() -> Array:
	var actions: Array = []
	
	var travel = create_action(
		"Travel to Location",
		"Move to a new location",
		"res://assets/icons/travel.png",
		"travel"
	)
	add_requirement(travel, create_requirement(RequirementType.SUPPLIES, 2, "Requires supplies for travel"))
	actions.append(travel)
	
	return actions

func _create_patron_actions() -> Array:
	var actions: Array = []
	
	var meet = create_action(
		"Meet Patron",
		"Discuss potential jobs and opportunities",
		"res://assets/icons/patron.png",
		"social"
	)
	actions.append(meet)
	
	var negotiate = create_action(
		"Negotiate Contract",
		"Negotiate terms for a new contract",
		"res://assets/icons/patron.png",
		"social"
	)
	add_requirement(negotiate, create_requirement(RequirementType.REPUTATION, 10, "Requires reputation to negotiate"))
	actions.append(negotiate)
	
	return actions

func _create_battle_actions() -> Array:
	var actions: Array = []
	
	var combat = create_action(
		"Enter Combat",
		"Engage in tactical combat",
		"res://assets/icons/battle.png",
		"combat"
	)
	add_requirement(combat, create_requirement(RequirementType.SUPPLIES, 1, "Requires supplies for combat"))
	actions.append(combat)
	
	return actions

func _create_post_battle_actions() -> Array:
	var actions: Array = []
	
	var loot = create_action(
		"Collect Loot",
		"Search the battlefield for valuable items",
		"res://assets/icons/post_battle.png",
		"salvage"
	)
	actions.append(loot)
	
	var treat = create_action(
		"Treat Injuries",
		"Provide medical treatment to injured crew",
		"res://assets/icons/post_battle.png",
		"medical"
	)
	add_requirement(treat, create_requirement(RequirementType.CREDITS, 20, "Requires credits for medical treatment"))
	actions.append(treat)
	
	return actions

func _create_management_actions() -> Array:
	var actions: Array = []
	
	var train = create_action(
		"Train Crew",
		"Improve crew skills and abilities",
		"res://assets/icons/management.png",
		"training"
	)
	add_requirement(train, create_requirement(RequirementType.CREDITS, 50, "Requires credits for training"))
	actions.append(train)
	
	var upgrade = create_action(
		"Upgrade Equipment",
		"Improve and modify equipment",
		"res://assets/icons/management.png",
		"equipment"
	)
	add_requirement(upgrade, create_requirement(RequirementType.CREDITS, 100, "Requires credits for equipment upgrade"))
	add_requirement(upgrade, create_requirement(RequirementType.SALVAGE, 2, "Requires salvage for equipment upgrade"))
	actions.append(upgrade)
	
	return actions

func _add_action_button(action: Dictionary) -> void:
	var button = action_button_scene.instantiate()
	action_container.add_child(button)
	button.setup(action.name, action.description, PHASE_CATEGORIES[action.category].color)
	button.pressed.connect(_on_action_button_pressed.bind(action.name))
	button.disabled = not meets_requirements(action, available_actions.get(action.name, {}))

func _on_action_button_pressed(action_name: String) -> void:
	selected_action = action_name
	var action = available_actions[action_name]
	
	description_label.text = action.description
	_update_cost_display(action.requirements)
	
	emit_signal("action_selected", action_name)

func _update_cost_display(requirements: Array) -> void:
	for child in cost_container.get_children():
		child.queue_free()
	
	for req in requirements:
		var cost_label = Label.new()
		cost_label.text = "%s: %d" % [req.description, req.value]
		cost_container.add_child(cost_label)

func execute_action(action_name: String, campaign_state: Dictionary) -> Dictionary:
	if not available_actions.has(action_name):
		return {"success": false, "message": "Invalid action"}
	
	var action = available_actions[action_name]
	if not meets_requirements(action, campaign_state):
		return {"success": false, "message": "Requirements not met"}
	
	# Execute action and return result
	var result = _execute_action_logic(action, campaign_state)
	emit_signal("action_executed", action_name, result)
	
	if result.success and action.category == current_phase:
		emit_signal("phase_action_completed", current_phase)
	
	return result

func _execute_action_logic(action: Dictionary, campaign_state: Dictionary) -> Dictionary:
	# Implement action execution logic
	return {"success": true, "message": "Action executed successfully"}