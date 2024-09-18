# Crew.gd
class_name Crew
extends Resource

var characters: Array[Character] = []

@export var name: String
@export var members: Array = []
@export var credits: int = 0
@export var ship: Ship
@export var reputation: int = 0
@export var current_location: Location

func _init(_name: String = "", _ship: Ship = null):
	name = _name
	ship = _ship

func add_member(character):
	members.append(character)

func remove_member(character):
	members.erase(character)

func add_credits(amount: int):
	credits += amount

func remove_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		return true
	return false

func get_member_count() -> int:
	return members.size()

func serialize() -> Dictionary:
	var serialized_data = {
		"name": name,
		"members": [],
		"credits": credits,
		"ship": null,
		"reputation": reputation,
		"current_location": null
	}
	
	for member in members:
		serialized_data["members"].append(member.serialize())
	
	if ship:
		serialized_data["ship"] = ship.serialize()
	
	if current_location:
		serialized_data["current_location"] = current_location.serialize()
	
	return serialized_data

static func deserialize(data: Dictionary) -> Crew:
	var crew = Crew.new(data["name"])
	crew.members = data["members"].map(func(m): return load("res://Scripts/Character.gd").deserialize(m))
	crew.credits = data["credits"]
	crew.ship = Ship.new().deserialize(data["ship"]) if data["ship"] else null
	crew.reputation = data["reputation"]
	crew.current_location = Location.deserialize(data["current_location"]) if data["current_location"] else null
	return crew

func add_character(character: Character):
	characters.append(character)

func remove_character(character: Character):
	characters.erase(character)

func is_valid() -> bool:
	return characters.size() >= 3 and characters.size() <= 8

func get_size() -> int:
	return characters.size()

func get_character_by_name(name: String):
	for character in members:
		if character.name == name:
			return character
	return null
