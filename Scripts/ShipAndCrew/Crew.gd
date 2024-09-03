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

func pay_upkeep(economy_manager: EconomyManager) -> bool:
	var upkeep_cost = economy_manager.calculate_upkeep_cost()
	return remove_credits(upkeep_cost)

func trade_item(item: Equipment, is_buying: bool, economy_manager: EconomyManager) -> bool:
	return economy_manager.trade_item(item, is_buying)

func serialize() -> Dictionary:
	return {
		"name": name,
		"members": members.map(func(m): return m.serialize()),
		"credits": credits,
		"ship": ship.serialize() if ship else null,
		"reputation": reputation,
		"current_location": current_location.serialize() if current_location else null
	}

static func deserialize(data: Dictionary) -> Crew:
	var crew = Crew.new(data["name"])
	crew.members = data["members"].map(func(m): return Character.deserialize(m))
	crew.credits = data["credits"]
	crew.ship = Ship.deserialize(data["ship"]) if data["ship"] else null
	crew.reputation = data["reputation"]
	crew.current_location = Location.deserialize(data["current_location"]) if data["current_location"] else null
	return crew
