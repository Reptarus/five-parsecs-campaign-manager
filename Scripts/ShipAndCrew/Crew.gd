class_name Crew
extends Resource

@export var name: String
@export var members: Array[Character] = []
@export var credits: int = 0
@export var ship: Ship
@export var reputation: int = 0
@export var current_location: Location

<<<<<<< HEAD
func _init(_name: String = "", _ship: Ship = null):
	name = _name
	ship = _ship
=======
var _characters: Array[CrewMember] = []
>>>>>>> parent of 1efa334 (worldphase functionality)

func add_member(character: Character):
	members.append(character)

func remove_member(character: Character):
	members.erase(character)

<<<<<<< HEAD
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
=======
func add_character(new_character: CrewMember) -> void:
	if _characters.size() < MAX_CREW_SIZE:
		_characters.append(new_character)
		print("Character added successfully: ", new_character.name)
	else:
		print("Maximum crew size reached (%d characters)" % MAX_CREW_SIZE)

func remove_character(index: int) -> void:
	if index >= 0 and index < _characters.size():
		_characters.remove_at(index)

func get_character(index: int) -> CrewMember:
	if index >= 0 and index < _characters.size():
		return _characters[index]
	return null

func get_characters() -> Array[CrewMember]:
	return _characters

func get_crew_size() -> int:
	return _characters.size()

func is_full() -> bool:
	return _characters.size() >= MAX_CREW_SIZE

func serialize() -> Dictionary:
	return {
		"characters": _characters.map(func(member): return member.serialize())
	}

func deserialize(data: Dictionary) -> void:
	_characters = []
	for member_data in data.get("characters", []):
		var crew_member = CrewMember.new()
		crew_member.deserialize(member_data)
		_characters.append(crew_member)

func assign_task(character_index: int, task: GlobalEnums.CrewTask) -> void:
	if character_index >= 0 and character_index < _characters.size():
		_characters[character_index].assign_task(task)

func resolve_tasks() -> void:
	for character in _characters:
		character.resolve_task()

func train_character(character_index: int, training_type: GlobalEnums.TrainingType, course: int) -> bool:
	if character_index >= 0 and character_index < _characters.size():
		return _characters[character_index].train(training_type, course)
	return false

func heal_characters() -> void:
	for character in _characters:
		character.heal()

func apply_experience() -> void:
	for character in _characters:
		character.apply_experience()

func check_for_level_ups() -> void:
	for character in _characters:
		character.check_for_level_up()

func equip_item(character_index: int, item: Item) -> bool:
	if character_index >= 0 and character_index < _characters.size():
		return _characters[character_index].equip_item(item)
	return false

func unequip_item(character_index: int, item: Item) -> bool:
	if character_index >= 0 and character_index < _characters.size():
		return _characters[character_index].unequip_item(item)
	return false

func get_total_combat_skill() -> int:
	var total_skill = 0
	for character in _characters:
		total_skill += character.combat_skill
	return total_skill

func get_total_savvy() -> int:
	var total_savvy = 0
	for character in _characters:
		total_savvy += character.savvy
	return total_savvy

func get_average_toughness() -> float:
	if _characters.is_empty():
		return 0.0
	var total_toughness = 0
	for character in _characters:
		total_toughness += character.toughness
	return float(total_toughness) / _characters.size()

func get_fastest_speed() -> int:
	var max_speed = 0
	for character in _characters:
		max_speed = max(max_speed, character.speed)
	return max_speed

func get_active_characters() -> Array[CrewMember]:
	return _characters.filter(func(character): return character.status == GlobalEnums.CharacterStatus.ACTIVE)

func get_injured_characters() -> Array[CrewMember]:
	return _characters.filter(func(character): return character.status == GlobalEnums.CharacterStatus.INJURED)

func has_psionic_character() -> bool:
	for character in _characters:
		if character.has_psionic_power():
			return true
	return false

func get_crew_morale() -> float:
	if _characters.is_empty():
		return 0.0
	var total_morale = 0.0
	for character in _characters:
		total_morale += character.get_morale()
	return total_morale / _characters.size()

func update_crew_status(battle_outcome: GlobalEnums.BattleOutcome) -> void:
	for character in _characters:
		character.update_status(battle_outcome)

func get_crew_reputation() -> GlobalEnums.ReputationLevel:
	var total_reputation = 0
	for character in _characters:
		total_reputation += character.get_reputation_value()
	var average_reputation = total_reputation / _characters.size()
	
	if average_reputation >= 90:
		return GlobalEnums.ReputationLevel.LEGENDARY
	elif average_reputation >= 70:
		return GlobalEnums.ReputationLevel.RESPECTED
	elif average_reputation >= 40:
		return GlobalEnums.ReputationLevel.NOTORIOUS
	else:
		return GlobalEnums.ReputationLevel.UNKNOWN
>>>>>>> parent of 1efa334 (worldphase functionality)
