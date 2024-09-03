class_name Location
extends Resource

enum Type { STAR_SYSTEM, PLANET, CITY }

@export var name: String = ""
@export var type: Type = Type.STAR_SYSTEM
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

func add_trait(new_trait: String) -> void:
	if new_trait not in traits:
		traits.append(new_trait)

func remove_trait(old_trait: String) -> void:
	traits.erase(old_trait)

func has_trait(check_trait: String) -> bool:
	return check_trait in traits

func get_traits() -> Array[String]:
	return traits

# New deserialize function
static func deserialize(data: Dictionary) -> Location:
	var location = Location.new()
	location.name = data.get("name", "")
	location.type = Type[data.get("type", "STAR_SYSTEM")]  # Assuming type is stored as a string
	location.traits = data.get("traits", [])
	if data.has("parent"):
		location.parent = Location.deserialize(data["parent"])
	if data.has("children"):
		for child_data in data["children"]:
			var child_location = Location.deserialize(child_data)
			location.add_child(child_location)
	return location
