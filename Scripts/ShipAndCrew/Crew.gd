class_name Crew
extends Resource

signal member_added(character: Character)
signal member_removed(character: Character)

@export var name: String = ""
@export var credits: int = 0
@export var reputation: int = 0
@export var story_points: int = 0
@export var members: Array[Character] = []
@export var ship: Ship
@export var equipment: Array[Equipment] = []
@export var active_loans: Array[Dictionary] = []

const MAX_MEMBERS: int = 8
const MIN_MEMBERS: int = 3

func _init(_name: String = "", _ship: Ship = null, initial_members: int = MIN_MEMBERS) -> void:
	name = _name
	ship = _ship if _ship else Ship.new()
	generate_random_crew(initial_members)

func add_member(character: Character) -> bool:
	if members.size() < MAX_MEMBERS:
		members.append(character)
		member_added.emit(character)
		return true
	return false

func remove_member(character: Character) -> bool:
	var index = members.find(character)
	if index != -1:
		members.remove_at(index)
		member_removed.emit(character)
		return true
	return false

func get_member(index: int) -> Character:
	if index >= 0 and index < members.size():
		return members[index]
	return null

func get_member_count() -> int:
	return members.size()

func generate_random_crew(size: int) -> void:
	for i in range(size):
		var new_character = Character.new()
		new_character.generate_random()
		add_member(new_character)

func reroll_member(index: int) -> void:
	var member = get_member(index)
	if member:
		member.generate_random()

func customize_member(index: int, new_data: Dictionary) -> void:
	var member = get_member(index)
	if member:
		member.update_from_dictionary(new_data)

func is_valid() -> bool:
	return get_member_count() >= MIN_MEMBERS and get_member_count() <= MAX_MEMBERS and ship != null

func add_credits(amount: int) -> void:
	credits += amount

func remove_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		return true
	return false

func add_reputation(amount: int) -> void:
	reputation += amount

func add_story_point() -> void:
	story_points += 1

func use_story_point() -> bool:
	if story_points > 0:
		story_points -= 1
		return true
	return false

func add_equipment(item: Equipment) -> void:
	equipment.append(item)

func remove_equipment(item: Equipment) -> bool:
	var index = equipment.find(item)
	if index != -1:
		equipment.remove_at(index)
		return true
	return false

func get_all_items() -> Array[Equipment]:
	var all_items: Array[Equipment] = []
	all_items.append_array(equipment)
	for member in members:
		all_items.append_array(member.inventory.items)
	return all_items

func calculate_upkeep_cost() -> int:
	var base_cost = 1  # Base cost for crews of 4-6 members
	var additional_cost = max(0, get_member_count() - 6)
	return base_cost + additional_cost

func pay_upkeep(amount: int) -> bool:
	return remove_credits(amount)

func decrease_morale() -> void:
	for member in members:
		member.decrease_morale()

func update_experience(xp: int) -> void:
	for member in members:
		member.add_xp(xp)

func has_broker() -> bool:
	for member in members:
		if member.has_skill("Broker"):
			return true
	return false

func get_max_allowed_debt() -> int:
	return 50 + (reputation * 10)  # Example formula, adjust as needed

func serialize() -> Dictionary:
	return {
		"name": name,
		"credits": credits,
		"reputation": reputation,
		"story_points": story_points,
		"members": members.map(func(m): return m.serialize()),
		"ship": ship.serialize(),
		"equipment": equipment.map(func(e): return e.serialize()),
		"active_loans": active_loans
	}

static func deserialize(data: Dictionary) -> Crew:
	var crew = Crew.new()
	crew.name = data.get("name", "")
	crew.credits = data.get("credits", 0)
	crew.reputation = data.get("reputation", 0)
	crew.story_points = data.get("story_points", 0)
	crew.members = data.get("members", []).map(func(m): return Character.deserialize(m))
	crew.ship = Ship.deserialize(data.get("ship", {}))
	crew.equipment = data.get("equipment", []).map(func(e): return Equipment.deserialize(e))
	crew.active_loans = data.get("active_loans", [])
	return crew
