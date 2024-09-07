# Crew.gd
class_name Crew
extends Resource

@export var name: String
@export var members: Array[Character] = []
@export var credits: int = 0
@export var ship: Ship
@export var reputation: int = 0
@export var current_location: Location

func _init(_name: String = "", _ship: Ship = null):
	name = _name
	ship = _ship

func add_member(character: Character):
	members.append(character)

func remove_member(character: Character):
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
	return {
		"name": name,
		"members": members.map(func(m): return m.serialize()),
		"credits": credits,
		"ship": {"data": ship.serialize()} if ship else null,
		"reputation": reputation,
		"current_location": {"data": current_location.serialize()} if current_location else null
	}

static func deserialize(data: Dictionary) -> Crew:
	var crew = Crew.new(data["name"])
	crew.members = data["members"].map(func(m): return Character.deserialize(m))
	crew.credits = data["credits"]
	crew.ship = Ship.deserialize(data["ship"]) if data["ship"] else null
	crew.reputation = data["reputation"]
	crew.current_location = Location.deserialize(data["current_location"]) if data["current_location"] else null
	return crew
