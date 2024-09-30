class_name Location
extends Resource

enum Type { STAR_SYSTEM, PLANET, CITY, SPACE_STATION, ALIEN_LANDSCAPE }

@export var name: String = ""
@export var type: Type = Type.STAR_SYSTEM
@export var traits: Array[GlobalEnums.WorldTrait] = []
@export var parent: Location = null
@export var children: Array[Location] = []
@export var strife_level: GlobalEnums.FringeWorldInstability = GlobalEnums.FringeWorldInstability.STABLE
@export var faction: GlobalEnums.Faction = GlobalEnums.Faction.FRINGE

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

func add_trait(new_trait: GlobalEnums.WorldTrait) -> void:
	if not traits.has(new_trait):
		traits.append(new_trait)

func remove_trait(trait_to_remove: GlobalEnums.WorldTrait) -> void:
	traits.erase(trait_to_remove)

func has_trait(trait_to_check: GlobalEnums.WorldTrait) -> bool:
	return traits.has(trait_to_check)

func get_traits() -> Array[GlobalEnums.WorldTrait]:
	return traits

func update_strife_level(new_level: GlobalEnums.FringeWorldInstability) -> void:
	strife_level = new_level

func get_strife_level() -> GlobalEnums.FringeWorldInstability:
	return strife_level

func set_faction(new_faction: GlobalEnums.Faction) -> void:
	faction = new_faction

func get_faction() -> GlobalEnums.Faction:
	return faction

func generate_random_traits() -> void:
	var num_traits = randi() % 3 + 1  # 1 to 3 traits
	for i in range(num_traits):
		var random_trait = GlobalEnums.WorldTrait.values()[randi() % GlobalEnums.WorldTrait.size()]
		add_trait(random_trait)

func serialize() -> Dictionary:
	var serialized_parent = null
	if parent:
		serialized_parent = parent.serialize()
	
	return {
		"name": name,
		"type": Type.keys()[type],
		"traits": traits.map(func(t): return GlobalEnums.WorldTrait.keys()[t]),
		"parent": serialized_parent,
		"children": children.map(func(c): return c.serialize()),
		"strife_level": GlobalEnums.FringeWorldInstability.keys()[strife_level],
		"faction": GlobalEnums.Faction.keys()[faction]
	}

static func deserialize(data: Dictionary) -> Location:
	var location := Location.new(data["name"], Type[data["type"]])
	location.traits = data["traits"].map(func(t): return GlobalEnums.WorldTrait[t])
	location.strife_level = GlobalEnums.FringeWorldInstability[data["strife_level"]]
	location.faction = GlobalEnums.Faction[data["faction"]]
	if data["parent"]:
		location.parent = Location.deserialize(data["parent"])
	for child_data in data["children"]:
		var child := Location.deserialize(child_data)
		child.parent = location
		location.children.append(child)
	return location
