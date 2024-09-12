class_name Location
extends Resource

enum Type { STAR_SYSTEM, PLANET, CITY }

@export var name: String = ""
@export var type: Type = Type.STAR_SYSTEM
@export var traits: Array[String] = []
@export var parent: Location = null
@export var children: Array[Location] = []

func _init(_name: String = "", _type: Type = Type.STAR_SYSTEM, _parent: Location = null) -> void:
	name = _name
	type = _type
	parent = _parent
	if parent:
		parent.add_child(self)

func add_child(child: Location) -> void:
	children.append(child)

func remove_child(child: Location) -> void:
	children.erase(child)

func get_full_name() -> String:
	if parent:
		return parent.get_full_name() + " - " + name
	return name

func add_trait(new_trait: String) -> void:
	if not traits.has(new_trait):
		traits.append(new_trait)

func remove_trait(trait_to_remove: String) -> void:
	traits.erase(trait_to_remove)

func has_trait(trait_to_check: String) -> bool:
	return traits.has(trait_to_check)

func get_traits() -> Array[String]:
	return traits

func serialize() -> Dictionary:
	var serialized_parent = null
	if parent:
		serialized_parent = parent.serialize()
	
	return {
		"name": name,
		"type": Type.keys()[type],
		"traits": traits,
		"parent": serialized_parent,
		"children": children.map(func(c): return c.serialize())
	}

static func deserialize(data: Dictionary) -> Location:
	var location := Location.new(data["name"], Type[data["type"]])
	location.traits = data["traits"]
	if data["parent"]:
		location.parent = Location.deserialize(data["parent"])
	for child_data in data["children"]:
		var child := Location.deserialize(child_data)
		child.parent = location
		location.children.append(child)
	return location
