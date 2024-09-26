# Crew.gd
class_name Crew
extends Resource

@export var characters: Array[Character] = []
@export var credits: int = 0
@export var ship: Ship
@export var reputation: int = 0
@export var current_location: Location
@export var name: String = ""


const MIN_CREW_SIZE: int = 3
const MAX_CREW_SIZE: int = 8

# Remove _init function as it's not needed for a Resource

func add_character(character: Character) -> void:
	if characters.size() < MAX_CREW_SIZE:
		characters.append(character)

func remove_character(character: Character) -> void:
	characters.erase(character)

func add_credits(amount: int) -> void:
	credits += amount

func remove_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		return true
	return false

func get_character_count() -> int:
	return characters.size()

func serialize() -> Dictionary:
	var serialized_data = {
		"name": name,
		"characters": [],
		"credits": credits,
		"ship": null,
		"reputation": reputation,
		"current_location": null
	}
	
	for character in characters:
		serialized_data["characters"].append(character.serialize())
	
	if ship:
		serialized_data["ship"] = ship.serialize()
	
	if current_location:
		serialized_data["current_location"] = current_location.serialize()
	
	return serialized_data

static func deserialize(data: Dictionary) -> Crew:
	var crew = Crew.new()
	
	crew.name = data.get("name", "Unnamed Crew")
	crew.credits = data.get("credits", 0)
	crew.reputation = data.get("reputation", 0)
	
	# Handle characters
	crew.characters = []
	for character_data in data.get("characters", []):
		if character_data is Dictionary:
			crew.characters.append(Character.deserialize(character_data, crew))

	
	# Handle ship
	var ship_data = data.get("ship")
	if ship_data is Dictionary:
		crew.ship = Ship.deserialize(ship_data)
	else:
		crew.ship = null
	
	# Handle current location
	var location_data = data.get("current_location")
	if location_data is Dictionary:
		crew.current_location = Location.deserialize(location_data)
	else:
		crew.current_location = null
	
	return crew

func is_valid() -> bool:
	return characters.size() >= MIN_CREW_SIZE and characters.size() <= MAX_CREW_SIZE

func get_size() -> int:
	return characters.size()

func get_character_by_name(character_name: String) -> Character:
	for character in characters:
		if character.name == character_name:
			return character
	return null

func set_ship(new_ship: Ship) -> void:
	ship = new_ship

func set_current_location(location: Location) -> void:
	current_location = location

func get_total_skill_level(skill: GlobalEnums.SkillType) -> int:
	var total: int = 0
	for character in characters:
		total += character.get_skill_level(skill)
	return total

func get_highest_skill_level(skill: GlobalEnums.SkillType) -> int:
	var highest: int = 0
	for character in characters:
		var skill_level = character.get_skill_level(skill)
		if skill_level > highest:
			highest = skill_level
	return highest
