class_name Location
extends Resource

enum Type { STAR_SYSTEM, PLANET, CITY }

@export var name: String
@export var type: Type
@export var traits: Array[String] = []
@export var parent: Location  # null for star systems
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

func add_trait(trait: String) -> void:
	if trait not in traits:
		traits.append(trait)

func remove_trait(trait: String) -> void:
	traits.erase(trait)

func has_trait(trait: String) -> bool:
	return trait in traits

func get_traits() -> Array[String]:
	return traits

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": Type.keys()[type],
		"traits": traits,
		"parent": parent.serialize() if parent else null,
		"children": children.map(func(c: Location) -> Dictionary: return c.serialize())
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
