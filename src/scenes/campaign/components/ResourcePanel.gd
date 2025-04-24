@tool
extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/components/ResourcePanel.gd")

# Signals
signal resource_clicked(resource_name: String, current_value: int)

# Constants
const ResourceItem = preload("res://src/scenes/campaign/components/ResourceItem.gd")
const ResourceItemScene = preload("res://src/scenes/campaign/components/ResourceItem.tscn")

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
	var trend: int # -1 for decreasing, 0 for stable, 1 for increasing
	var icon: Texture
	var color: Color
	var description: String
	
	func _init(p_name: String, p_current: int = 0, p_max: int = -1, p_trend: int = 0) -> void:
		name = p_name
		current_value = p_current
		max_value = p_max # -1 means no maximum
		trend = p_trend
		
		if RESOURCE_DESCRIPTIONS.has(p_name):
			description = RESOURCE_DESCRIPTIONS[p_name]
		else:
			description = "Resource: " + p_name
			
		color = _get_resource_color(p_name)
		
	func _get_resource_color(res_name: String) -> Color:
		match res_name:
			"credits": return Color(0.9, 0.8, 0.2) # Gold
			"story_points": return Color(0.8, 0.4, 1.0) # Purple
			"reputation": return Color(0.2, 0.6, 1.0) # Blue
			"supplies": return Color(0.2, 0.8, 0.2) # Green
			"intel": return Color(0.4, 0.8, 0.8) # Cyan
			"salvage": return Color(0.8, 0.6, 0.2) # Orange
			_: return Color.WHITE

# Node references
@onready var item_container: VBoxContainer = $ScrollContainer/VBoxContainer if has_node("ScrollContainer/VBoxContainer") else null
@onready var title_label: Label = $TitleLabel if has_node("TitleLabel") else null

# Properties
var title: String = "Resources"
var resources: Dictionary = {}
var resource_items: Dictionary = {}
var resource_colors: Dictionary = {
	"credits": Color(0.9, 0.78, 0.1),
	"fuel": Color(0.2, 0.6, 1.0),
	"morale": Color(0.2, 0.8, 0.2),
	"reputation": Color(0.8, 0.2, 0.6)
}

func _ready() -> void:
	if not is_inside_tree():
		return
		
	if is_instance_valid(title_label):
		title_label.text = title
		
	_update_display()

func _update_display() -> void:
	if not is_inside_tree() or not is_instance_valid(item_container):
		return
		
	# Clear existing items
	for child in item_container.get_children():
		if is_instance_valid(child):
			item_container.remove_child(child)
			child.queue_free()
	
	resource_items.clear()
	
	# Add resource items
	for resource_name in resources.keys():
		if resource_name.is_empty() or not resources[resource_name] is Dictionary:
			continue
			
		var resource_data = resources[resource_name]
		_add_resource_item(
			resource_name,
			resource_data.get("current_value", 0),
			resource_data.get("max_value", -1),
			resource_data.get("trend", 0),
			resource_colors.get(resource_name, Color.WHITE)
		)

func _add_resource_item(
	name: String,
	current_value: int,
	max_value: int,
	trend: int,
	color: Color
) -> void:
	if not is_instance_valid(item_container) or name.is_empty():
		return
		
	var resource_item = ResourceItemScene.instantiate()
	if not is_instance_valid(resource_item):
		push_error("Failed to instantiate ResourceItemScene")
		return
		
	item_container.add_child(resource_item)
	resource_items[name] = resource_item
	
	# Connect signal if not already connected
	if resource_item.has_signal("resource_clicked") and not resource_item.resource_clicked.is_connected(_on_resource_clicked):
		resource_item.resource_clicked.connect(_on_resource_clicked)
	
	# Set up resource item
	if resource_item.has_method("setup"):
		resource_item.setup(name, current_value, max_value, trend, color)

# Public methods
func set_title(new_title: String) -> void:
	if new_title.is_empty():
		return
		
	title = new_title
	if is_instance_valid(title_label):
		title_label.text = title

func set_resources(resource_data: Dictionary) -> void:
	if resource_data.is_empty():
		return
		
	resources = resource_data
	_update_display()

func update_resource(name: String, current_value: int, max_value: int = -1, trend: int = 0) -> void:
	if name.is_empty():
		return
		
	if not resources.has(name):
		resources[name] = {
			"current_value": current_value,
			"max_value": max_value if max_value > 0 else 100,
			"trend": trend
		}
	else:
		resources[name].current_value = current_value
		if max_value > 0:
			resources[name].max_value = max_value
		resources[name].trend = trend
	
	if resource_items.has(name) and resource_items[name] is ResourceItem:
		var item = resource_items[name]
		if not is_instance_valid(item):
			_update_display()
			return
			
		var color = resource_colors.get(name, Color.WHITE)
		
		if item.has_method("setup"):
			item.setup(
				name,
				current_value,
				resources[name].max_value,
				trend,
				color
			)
	else:
		_update_display()

func highlight_resource(name: String) -> void:
	if name.is_empty():
		return
		
	if resource_items.has(name) and resource_items[name] is ResourceItem:
		var item = resource_items[name]
		if is_instance_valid(item) and item.has_method("highlight"):
			item.highlight()

func animate_resource_change(name: String, new_value: int) -> void:
	if name.is_empty():
		return
		
	if not resource_items.has(name) or not resource_items[name] is ResourceItem:
		return
		
	var item = resource_items[name]
	if not is_instance_valid(item) or not item.has_method("animate_value_change"):
		return
		
	item.animate_value_change(new_value)
	
	if resources.has(name) and resources[name] is Dictionary:
		resources[name].current_value = new_value

# Signal handlers
func _on_resource_clicked(resource_name: String, current_value: int) -> void:
	if resource_name.is_empty():
		return
		
	if has_signal("resource_clicked"):
		resource_clicked.emit(resource_name, current_value)
