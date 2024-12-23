class_name Crew
extends Resource

const Character = preload("res://src/core/character/Base/Character.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal member_added(character: Character)
signal member_removed(character: Character)
signal credits_changed(new_amount: int)

const MAX_CREW_SIZE = 8
const MIN_CREW_SIZE = 3

@export var members: Array[Character] = []
@export var credits: int = 1000
@export var name: String = ""
@export var characteristic: String = ""
@export var meeting_story: String = ""

func _init() -> void:
	members = []
	credits = 1000

func add_member(character: Character) -> bool:
	if members.size() >= MAX_CREW_SIZE:
		push_error("Cannot add member: Crew is at maximum capacity")
		return false
	
	if character in members:
		push_error("Cannot add member: Character is already in crew")
		return false
	
	members.append(character)
	member_added.emit(character)
	return true

func remove_member(character: Character) -> bool:
	if not character in members:
		push_error("Cannot remove member: Character is not in crew")
		return false
	
	if members.size() <= MIN_CREW_SIZE:
		push_error("Cannot remove member: Crew is at minimum size")
		return false
	
	members.erase(character)
	member_removed.emit(character)
	return true

func get_member_count() -> int:
	return members.size()

func get_member(index: int) -> Character:
	if index < 0 or index >= members.size():
		return null
	return members[index]

func get_members() -> Array[Character]:
	return members

func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)

func remove_credits(amount: int) -> bool:
	if amount > credits:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true

func has_credits(amount: int) -> bool:
	return credits >= amount

func serialize() -> Dictionary:
	return {
		"name": name,
		"credits": credits,
		"characteristic": characteristic,
		"meeting_story": meeting_story,
		"members": members.map(func(m): return m.serialize())
	}

func deserialize(data: Dictionary) -> void:
	name = data.get("name", "")
	credits = data.get("credits", 1000)
	characteristic = data.get("characteristic", "")
	meeting_story = data.get("meeting_story", "")
	
	members.clear()
	for member_data in data.get("members", []):
		var character = Character.new()
		character.deserialize(member_data)
		add_member(character)

func get_total_combat_effectiveness() -> float:
	var total = 0.0
	for member in members:
		if member.has_method("get_combat_effectiveness"):
			total += member.get_combat_effectiveness()
	return total

func get_total_survival_chance() -> float:
	var total = 0.0
	for member in members:
		if member.has_method("get_survival_chance"):
			total += member.get_survival_chance()
	return total / max(members.size(), 1) 