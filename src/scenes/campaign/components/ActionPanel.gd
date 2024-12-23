@tool
extends Panel
class_name ActionPanel

# Signals
signal action_selected(action_name: String)
signal action_executed(action_name: String, result: Dictionary)
signal phase_action_completed(phase_name: String)

# Constants
const PHASE_CATEGORIES = {
	"upkeep": {
		"color": Color(0.2, 0.8, 0.2),  # Green
		"icon": "res://assets/icons/upkeep.png",
		"description": "Handle crew upkeep and ship maintenance"
	},
	"world_step": {
		"color": Color(0.4, 0.6, 0.9),  # Light Blue
		"icon": "res://assets/icons/world.png",
		"description": "Handle world events and local activities"
	},
	"travel": {
		"color": Color(0.8, 0.6, 0.2),  # Orange
		"icon": "res://assets/icons/travel.png",
		"description": "Travel between locations and handle travel events"
	},
	"patrons": {
		"color": Color(0.9, 0.8, 0.2),  # Gold
		"icon": "res://assets/icons/patron.png",
		"description": "Interact with patrons and handle job offers"
	},
	"battle": {
		"color": Color(0.8, 0.2, 0.2),  # Red
		"icon": "res://assets/icons/battle.png",
		"description": "Engage in tactical combat missions"
	},
	"post_battle": {
		"color": Color(0.6, 0.4, 0.8),  # Purple
		"icon": "res://assets/icons/post_battle.png",
		"description": "Handle post-battle resolution and rewards"
	},
	"management": {
		"color": Color(0.2, 0.6, 1.0),  # Blue
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

class ActionRequirement:
	var type: RequirementType
	var value: Variant
	var description: String
	
	func _init(p_type: RequirementType, p_value: Variant, p_description: String = "") -> void:
		type = p_type
		value = p_value
		description = p_description
	
	func is_met(campaign_state: Dictionary) -> bool:
		match type:
			RequirementType.CREDITS:
				return campaign_state.get("credits", 0) >= value
			RequirementType.STORY_POINTS:
				return campaign_state.get("story_points", 0) >= value
			RequirementType.REPUTATION:
				return campaign_state.get("reputation", 0) >= value
			RequirementType.SUPPLIES:
				return campaign_state.get("supplies", 0) >= value
			RequirementType.INTEL:
				return campaign_state.get("intel", 0) >= value
			RequirementType.SALVAGE:
				return campaign_state.get("salvage", 0) >= value
			RequirementType.CHARACTER_STAT:
				# Implement character stat check
				return true
			RequirementType.ITEM:
				# Implement item check
				return true
			RequirementType.LOCATION_TYPE:
				# Implement location type check
				return true
		return false

class ActionData:
	var name: String
	var description: String
	var requirements: Array[ActionRequirement]
	var costs: Dictionary  # Resource costs
	var category: String
	var enabled: bool
	var phase: String
	
	func _init(p_name: String, p_description: String, p_category: String, p_phase: String) -> void:
		name = p_name
		description = p_description
		category = p_category
		phase = p_phase
		requirements = []
		costs = {}
		enabled = true
	
	func add_requirement(requirement: ActionRequirement) -> void:
		requirements.append(requirement)
	
	func add_cost(resource: String, amount: int) -> void:
		costs[resource] = amount
	
	func can_execute(campaign_state: Dictionary) -> bool:
		for req in requirements:
			if not req.is_met(campaign_state):
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
			ActionRequirement.new(RequirementType.CREDITS, 10, "Requires credits for upkeep")
		],
		"world_step": [
			ActionRequirement.new(RequirementType.SUPPLIES, 1, "Requires supplies for local activities")
		],
		"travel": [
			ActionRequirement.new(RequirementType.SUPPLIES, 2, "Requires supplies for travel")
		],
		"patrons": [],  # No special requirements for patron interactions
		"battle": [
			ActionRequirement.new(RequirementType.SUPPLIES, 1, "Requires supplies for battle")
		],
		"post_battle": [],  # No special requirements for post-battle
		"management": [
			ActionRequirement.new(RequirementType.CREDITS, 50, "Requires credits for management actions")
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

func _get_phase_actions(phase: String) -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
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

func _create_upkeep_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var maintain = ActionData.new(
		"Maintain Equipment",
		"Perform routine maintenance on equipment",
		"maintenance",
		"upkeep"
	)
	maintain.add_cost("credits", 10)
	actions.append(maintain)
	
	var resupply = ActionData.new(
		"Resupply",
		"Purchase necessary supplies",
		"logistics",
		"upkeep"
	)
	resupply.add_cost("credits", 20)
	actions.append(resupply)
	
	return actions

func _create_world_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var explore = ActionData.new(
		"Explore Area",
		"Search the local area for opportunities",
		"exploration",
		"world_step"
	)
	explore.add_cost("supplies", 1)
	actions.append(explore)
	
	var gather = ActionData.new(
		"Gather Intel",
		"Collect information about the area",
		"information",
		"world_step"
	)
	gather.add_cost("credits", 10)
	actions.append(gather)
	
	return actions

func _create_travel_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var travel = ActionData.new(
		"Travel to Location",
		"Move to a new location",
		"travel",
		"travel"
	)
	travel.add_cost("supplies", 2)
	actions.append(travel)
	
	return actions

func _create_patron_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var meet = ActionData.new(
		"Meet Patron",
		"Discuss potential jobs and opportunities",
		"social",
		"patrons"
	)
	actions.append(meet)
	
	var negotiate = ActionData.new(
		"Negotiate Contract",
		"Negotiate terms for a new contract",
		"social",
		"patrons"
	)
	negotiate.add_requirement(ActionRequirement.new(
		RequirementType.REPUTATION,
		10,
		"Requires reputation to negotiate"
	))
	actions.append(negotiate)
	
	return actions

func _create_battle_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var combat = ActionData.new(
		"Enter Combat",
		"Engage in tactical combat",
		"combat",
		"battle"
	)
	combat.add_cost("supplies", 1)
	actions.append(combat)
	
	return actions

func _create_post_battle_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var loot = ActionData.new(
		"Collect Loot",
		"Search the battlefield for valuable items",
		"salvage",
		"post_battle"
	)
	actions.append(loot)
	
	var treat = ActionData.new(
		"Treat Injuries",
		"Provide medical treatment to injured crew",
		"medical",
		"post_battle"
	)
	treat.add_cost("credits", 20)
	actions.append(treat)
	
	return actions

func _create_management_actions() -> Array[ActionData]:
	var actions: Array[ActionData] = []
	
	var train = ActionData.new(
		"Train Crew",
		"Improve crew skills and abilities",
		"training",
		"management"
	)
	train.add_cost("credits", 50)
	actions.append(train)
	
	var upgrade = ActionData.new(
		"Upgrade Equipment",
		"Improve and modify equipment",
		"equipment",
		"management"
	)
	upgrade.add_cost("credits", 100)
	upgrade.add_cost("salvage", 2)
	actions.append(upgrade)
	
	return actions

func _add_action_button(action: ActionData) -> void:
	var button = action_button_scene.instantiate()
	action_container.add_child(button)
	button.setup(action.name, action.description, PHASE_CATEGORIES[action.phase].color)
	button.pressed.connect(_on_action_button_pressed.bind(action.name))
	button.disabled = not action.enabled

func _on_action_button_pressed(action_name: String) -> void:
	selected_action = action_name
	var action = available_actions[action_name]
	
	description_label.text = action.description
	_update_cost_display(action.costs)
	
	emit_signal("action_selected", action_name)

func _update_cost_display(costs: Dictionary) -> void:
	for child in cost_container.get_children():
		child.queue_free()
	
	for resource in costs:
		var cost_label = Label.new()
		cost_label.text = "%s: %d" % [resource.capitalize(), costs[resource]]
		cost_container.add_child(cost_label)

func execute_action(action_name: String, campaign_state: Dictionary) -> Dictionary:
	if not available_actions.has(action_name):
		return {"success": false, "message": "Invalid action"}
	
	var action = available_actions[action_name]
	if not action.can_execute(campaign_state):
		return {"success": false, "message": "Requirements not met"}
	
	# Execute action and return result
	var result = _execute_action_logic(action, campaign_state)
	emit_signal("action_executed", action_name, result)
	
	if result.success and action.phase == current_phase:
		emit_signal("phase_action_completed", current_phase)
	
	return result

func _execute_action_logic(action: ActionData, campaign_state: Dictionary) -> Dictionary:
	# Implement action execution logic
	return {"success": true, "message": "Action executed successfully"} 