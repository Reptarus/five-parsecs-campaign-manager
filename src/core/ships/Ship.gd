extends RefCounted

signal component_added(component)
signal component_removed(component)
signal properties_changed()

# Basic ship properties
var _name: String = ""
var _ship_class: String = ""
var _hull_points: int = 0
var _shield_points: int = 0
var _max_hull_points: int = 0
var _max_shield_points: int = 0
var _description: String = ""
var _components: Array = []

# Getter and setter methods for properties
func get_name() -> String:
	return _name

func set_name(value: String) -> bool:
	_name = value
	properties_changed.emit()
	return true
	
func get_description() -> String:
	return _description
	
func set_description(value: String) -> bool:
	_description = value
	properties_changed.emit()
	return true
	
func get_ship_class() -> String:
	return _ship_class
	
func set_ship_class(value: String) -> bool:
	_ship_class = value
	properties_changed.emit()
	return true
	
func get_hull_points() -> int:
	return _hull_points
	
func set_hull_points(value: int) -> bool:
	_hull_points = value
	properties_changed.emit()
	return true

func get_shield_points() -> int:
	return _shield_points
	
func set_shield_points(value: int) -> bool:
	_shield_points = value
	properties_changed.emit()
	return true

func get_max_hull_points() -> int:
	return _max_hull_points
	
func set_max_hull_points(value: int) -> bool:
	_max_hull_points = value
	_hull_points = min(_hull_points, _max_hull_points)
	properties_changed.emit()
	return true

func get_max_shield_points() -> int:
	return _max_shield_points
	
func set_max_shield_points(value: int) -> bool:
	_max_shield_points = value
	_shield_points = min(_shield_points, _max_shield_points)
	properties_changed.emit()
	return true

# Component management
func get_components() -> Array:
	return _components.duplicate()
	
func add_component(component) -> bool:
	if component == null:
		return false
		
	if not component in _components:
		_components.append(component)
		component_added.emit(component)
		return true
	
	return false
	
func remove_component(component) -> bool:
	if component == null:
		return false
		
	if component in _components:
		_components.erase(component)
		component_removed.emit(component)
		return true
		
	return false
	
func get_component_by_id(id: String):
	for component in _components:
		if component.has_method("get_id") and component.get_id() == id:
			return component
		elif "id" in component and component.id == id:
			return component
	
	return null
	
func get_component_by_type(type):
	for component in _components:
		if component.has_method("get_type") and component.get_type() == type:
			return component
		elif "type" in component and component.type == type:
			return component
			
	return null
	
# Calculate combined statistics from all components
func calculate_stats() -> Dictionary:
	var stats = {}
	
	for component in _components:
		var component_stats = {}
		
		if component.has_method("get_stats"):
			component_stats = component.get_stats()
		elif component.has_method("get_stat_modifiers"):
			component_stats = component.get_stat_modifiers()
			
		for stat_name in component_stats:
			var value = component_stats[stat_name]
			if stat_name in stats:
				stats[stat_name] += value
			else:
				stats[stat_name] = value
				
	return stats
	
# Serialization
func to_dict() -> Dictionary:
	var data = {
		"name": _name,
		"ship_class": _ship_class,
		"hull_points": _hull_points,
		"shield_points": _shield_points,
		"max_hull_points": _max_hull_points,
		"max_shield_points": _max_shield_points,
		"description": _description,
		"components": []
	}
	
	for component in _components:
		if component.has_method("to_dict"):
			data["components"].append(component.to_dict())
			
	return data
	
func from_dict(data: Dictionary) -> bool:
	set_name(data.get("name", ""))
	set_ship_class(data.get("ship_class", ""))
	set_hull_points(data.get("hull_points", 0))
	set_shield_points(data.get("shield_points", 0))
	set_max_hull_points(data.get("max_hull_points", 0))
	set_max_shield_points(data.get("max_shield_points", 0))
	set_description(data.get("description", ""))
	
	# Clear current components
	_components.clear()
	
	return true
