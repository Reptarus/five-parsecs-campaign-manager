class_name Location
extends Resource

enum Type { STAR_SYSTEM, PLANET, CITY }

@export var name: String
@export var type: Type
@export var parent: Location  # null for star systems
@export var children: Array = []

func _init(_name: String = "", _type: Type = Type.STAR_SYSTEM, _parent: Location = null):
	name = _name
	type = _type
	parent = _parent
	if parent:
		parent.add_child(self)

func add_child(child: Location):
	children.append(child)

func remove_child(child: Location):
	children.erase(child)

func get_full_name() -> String:
	if parent:
		return parent.get_full_name() + " - " + name
	return name

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": type,
		"parent": parent.serialize() if parent else null,
		"children": children.map(func(c): return c.serialize())
	}

static func deserialize(data: Dictionary) -> Location:
	var location = Location.new(data["name"], data["type"])
	if data["parent"]:
		location.parent = Location.deserialize(data["parent"])
	for child_data in data["children"]:
		var child = Location.deserialize(child_data)
		child.parent = location
		location.children.append(child)
	return location
