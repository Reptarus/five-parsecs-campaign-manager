@tool
extends Panel
class_name ResourcePanel

# Signals
signal resource_clicked(resource_name: String, current_value: int)

# Constants
const RESOURCE_ICONS = {
	"credits": "res://assets/icons/credit.png",
	"story_points": "res://assets/icons/story_point.png",
	"reputation": "res://assets/icons/reputation.png",
	"supplies": "res://assets/icons/supplies.png",
	"intel": "res://assets/icons/intel.png",
	"salvage": "res://assets/icons/salvage.png"
}

const RESOURCE_DESCRIPTIONS = {
	"credits": "Universal currency for purchasing equipment, supplies, and services",
	"story_points": "Used for rerolls and influencing campaign events",
	"reputation": "Influences job offers, prices, and NPC interactions",
	"supplies": "Required for crew survival and ship maintenance",
	"intel": "Information about missions, threats, and opportunities",
	"salvage": "Scavenged materials that can be sold or used for repairs"
}

# Resource data structure
class ResourceData:
	var name: String
	var current_value: int
	var max_value: int
	var trend: int  # -1 for decreasing, 0 for stable, 1 for increasing
	var icon: Texture
	var color: Color
	var description: String
	
	func _init(p_name: String, p_current: int = 0, p_max: int = -1, p_trend: int = 0) -> void:
		name = p_name
		current_value = p_current
		max_value = p_max  # -1 means no maximum
		trend = p_trend
		color = _get_resource_color(p_name)
		description = RESOURCE_DESCRIPTIONS[p_name]
		
	func _get_resource_color(res_name: String) -> Color:
		match res_name:
			"credits": return Color(0.9, 0.8, 0.2)  # Gold
			"story_points": return Color(0.8, 0.4, 1.0)  # Purple
			"reputation": return Color(0.2, 0.6, 1.0)  # Blue
			"supplies": return Color(0.2, 0.8, 0.2)  # Green
			"intel": return Color(0.4, 0.8, 0.8)  # Cyan
			"salvage": return Color(0.8, 0.6, 0.2)  # Orange
			_: return Color.WHITE

# Node references
@onready var resources_container: VBoxContainer = $MarginContainer/ResourcesContainer
@onready var resource_item_scene = preload("res://src/scenes/campaign/components/ResourceItem.tscn")

# Properties
var _resources: Dictionary = {}

func _ready() -> void:
	_setup_ui()
	
func _setup_ui() -> void:
	# Set up the panel style
	custom_minimum_size = Vector2(250, 0)
	
	# Initialize default resources if empty
	if _resources.is_empty():
		_initialize_default_resources()
	
	_update_display()

func _initialize_default_resources() -> void:
	add_resource("credits", 1000)  # Starting credits
	add_resource("story_points", 3)  # Starting story points
	add_resource("reputation", 0)  # Starting reputation
	add_resource("supplies", 10)  # Starting supplies
	add_resource("intel", 0)  # Starting intel
	add_resource("salvage", 0)  # Starting salvage

func _update_display() -> void:
	if not is_inside_tree() or not resources_container:
		return
		
	# Clear existing resource displays
	for child in resources_container.get_children():
		child.queue_free()
	
	# Add resource displays in order
	var resource_order = ["credits", "story_points", "reputation", "supplies", "intel", "salvage"]
	for resource_name in resource_order:
		if _resources.has(resource_name):
			_add_resource_display(resource_name)

func _add_resource_display(resource_name: String) -> void:
	var resource = _resources[resource_name]
	var resource_item = resource_item_scene.instantiate()
	resources_container.add_child(resource_item)
	
	resource_item.setup(
		resource_name,
		resource.current_value,
		resource.max_value,
		resource.trend,
		resource.color,
		resource.description
	)
	
	resource_item.resource_clicked.connect(_on_resource_clicked)

func _on_resource_clicked(resource_name: String) -> void:
	if _resources.has(resource_name):
		emit_signal("resource_clicked", resource_name, _resources[resource_name].current_value)

# Public methods
func add_resource(name: String, initial_value: int = 0, max_value: int = -1) -> void:
	_resources[name] = ResourceData.new(name, initial_value, max_value)
	_update_display()

func set_resource_value(name: String, value: int) -> void:
	if _resources.has(name):
		var old_value = _resources[name].current_value
		_resources[name].current_value = value
		_resources[name].trend = sign(value - old_value)
		_update_display()

func get_resource_value(name: String) -> int:
	return _resources.get(name, ResourceData.new(name)).current_value

func modify_resource(name: String, amount: int) -> void:
	if _resources.has(name):
		var new_value = _resources[name].current_value + amount
		if _resources[name].max_value >= 0:
			new_value = mini(new_value, _resources[name].max_value)
		new_value = maxi(0, new_value)
		set_resource_value(name, new_value)

func set_resource_max(name: String, max_value: int) -> void:
	if _resources.has(name):
		_resources[name].max_value = max_value
		if _resources[name].current_value > max_value and max_value >= 0:
			set_resource_value(name, max_value)
		_update_display()

func get_resource_max(name: String) -> int:
	return _resources.get(name, ResourceData.new(name)).max_value

func has_resource(name: String) -> bool:
	return _resources.has(name)

func get_all_resources() -> Dictionary:
	var resources = {}
	for name in _resources:
		resources[name] = _resources[name].current_value
	return resources 
