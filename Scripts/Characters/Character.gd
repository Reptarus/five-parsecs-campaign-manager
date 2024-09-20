# Character.gd
class_name Character
extends Resource

const ArmorResource = preload("res://Resources/Armor.gd")

signal experience_gained(amount: int)
signal leveled_up
signal request_new_trait
signal request_upgrade_choice(upgrade_options)

@export var name: String
@export var species: String
@export var background: String
@export var character_class: String
@export var motivation: String

@export var reactions: int
@export var speed: int
@export var combat_skill: int
@export var toughness: int
@export var savvy: int
@export var luck: int
@export var xp: int
@export var level: int = 1

@export var inventory: CharacterInventory
@export var traits: Array[String]

var medbay_turns_left: int = 0
var injuries: Array[String] = []

func _init() -> void:
	inventory = CharacterInventory.new()

func is_in_medbay() -> bool:
	return medbay_turns_left > 0

func recover() -> void:
	if medbay_turns_left > 0:
		medbay_turns_left -= 1

func apply_tutorial_modifications(modifications: Dictionary) -> void:
	for stat in modifications:
		if stat in ["reactions", "speed", "combat_skill", "toughness", "savvy", "luck"]:
			set(stat, get(stat) + modifications[stat])

func level_up() -> void:
	level += 1
	var upgrade_options = [
		"Increase Reactions by 1",
		"Increase Speed by 1",
		"Increase Combat Skill by 1",
		"Increase Toughness by 1",
		"Increase Savvy by 1",
		"Increase Luck by 1",
		"Gain a new Trait"
	]
	
	var choice = await request_upgrade_choice.emit(upgrade_options)
	
	match choice:
		"Increase Reactions by 1": reactions += 1
		"Increase Speed by 1": speed += 1
		"Increase Combat Skill by 1": combat_skill += 1
		"Increase Toughness by 1": toughness += 1
		"Increase Savvy by 1": savvy += 1
		"Increase Luck by 1": luck += 1
		"Gain a new Trait":
			request_new_trait.emit()
			var new_trait = await request_new_trait
			traits.append(new_trait)
	
	xp -= get_xp_for_next_level()
	leveled_up.emit()

func get_xp_for_next_level() -> int:
	return level * 5  # Simple XP curve, adjust as needed

func can_level_up() -> bool:
	return xp >= get_xp_for_next_level()

func get_armor_save() -> int:
	return inventory.get_items().reduce(func(acc, item): 
		return max(acc, item.armor_save if "armor_save" in item else 0), 0)

func serialize() -> Dictionary:
	return {
		"name": name,
		"species": species,
		"background": background,
		"character_class": character_class,
		"motivation": motivation,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"luck": luck,
		"xp": xp,
		"level": level,
		"traits": traits,
		"medbay_turns_left": medbay_turns_left,
		"injuries": injuries,
		"inventory": inventory.serialize()
	}

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	for key in data.keys():
		if key != "inventory":
			character.set(key, data[key])
	character.inventory = CharacterInventory.deserialize(data["inventory"])
	return character

func enter_medbay(medical_bay: MedicalBayComponent) -> bool:
	if medical_bay.admit_patient(self):
		medbay_turns_left = 3
		return true
	return false

func leave_medbay(medical_bay: MedicalBayComponent) -> bool:
	if medical_bay.discharge_patient(self):
		medbay_turns_left = 0
		return true
	return false

func apply_injury(injury: String) -> void:
	injuries.append(injury)
	# Implement stat penalties or other effects based on injury

func heal_injury(injury: String) -> void:
	injuries.erase(injury)
	# Reverse any stat penalties or effects

func add_experience(amount: int) -> void:
	xp += amount
	experience_gained.emit(amount)
	while can_level_up():
		level_up()
