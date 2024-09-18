# Character.gd
class_name Character
extends Resource

const ArmorResource = preload("res://Resources/Armor.gd")

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

@export var equipped_weapon: Weapon
@export var equipped_items: Array[Item]
@export var traits: Array[String]

var medbay_turns_left: int = 0

func is_in_medbay() -> bool:
	return medbay_turns_left > 0

func recover() -> void:
	if medbay_turns_left > 0:
		medbay_turns_left -= 1

func apply_tutorial_modifications(modifications: Dictionary) -> void:
	for stat in modifications:
		if stat in ["reactions", "speed", "combat_skill", "toughness", "savvy", "luck"]:
			set(stat, get(stat) + modifications[stat])

func level_up(game_state: GameState) -> void:
	if game_state.is_tutorial_active:
		# Simplified leveling for tutorial
		var stats = ["reactions", "speed", "combat_skill", "toughness", "savvy"]
		var stat_to_increase = stats[randi() % stats.size()]
		set(stat_to_increase, get(stat_to_increase) + 1)
	else:
		# Regular level up logic
		var upgrade_options = [
			"Increase Reactions by 1",
			"Increase Speed by 1",
			"Increase Combat Skill by 1",
			"Increase Toughness by 1",
			"Increase Savvy by 1",
			"Increase Luck by 1",
			"Gain a new Trait"
		]
		
		# Present options to player and get choice
		var choice = game_state.present_upgrade_options(upgrade_options)
		
		match choice:
			"Increase Reactions by 1":
				reactions += 1
			"Increase Speed by 1":
				speed += 1
			"Increase Combat Skill by 1":
				combat_skill += 1
			"Increase Toughness by 1":
				toughness += 1
			"Increase Savvy by 1":
				savvy += 1
			"Increase Luck by 1":
				luck += 1
			"Gain a new Trait":
				var new_trait = game_state.select_new_trait()
				traits.append(new_trait)
		
		xp -= 5 # Deduct XP cost for upgrade

func equip_weapon(weapon: Weapon) -> void:
	if equipped_weapon:
		equipped_items.append(equipped_weapon)
	equipped_weapon = weapon
	equipped_items.erase(weapon)

func equip_item(item: Item) -> void:
	if item not in equipped_items:
		equipped_items.append(item)

func unequip_item(item: Item) -> void:
	equipped_items.erase(item)

func get_armor_save() -> int:
	var armor_save = 0
	for item in equipped_items:
		if "armor_save" in item:
			armor_save = max(armor_save, item.armor_save)
	return armor_save

func serialize() -> Dictionary:
	var data = {
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
		"traits": traits,
		"medbay_turns_left": medbay_turns_left
	}
	if equipped_weapon:
		data["equipped_weapon"] = equipped_weapon.serialize()
	data["equipped_items"] = equipped_items.map(func(item): return item.serialize())
	return data

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	character.name = data["name"]
	character.species = data["species"]
	character.background = data["background"]
	character.character_class = data["character_class"]
	character.motivation = data["motivation"]
	character.reactions = data["reactions"]
	character.speed = data["speed"]
	character.combat_skill = data["combat_skill"]
	character.toughness = data["toughness"]
	character.savvy = data["savvy"]
	character.luck = data["luck"]
	character.xp = data["xp"]
	character.equipped_weapon = Weapon.deserialize(data["equipped_weapon"]) if "equipped_weapon" in data else null
	character.equipped_items = data["equipped_items"].map(func(item_data): return Item.deserialize(item_data))
	character.traits = data["traits"]
	character.medbay_turns_left = data["medbay_turns_left"]
	return character

func enter_medbay(medical_bay: MedicalBayComponent) -> bool:
	if medical_bay.admit_patient(self):
		medbay_turns_left = 3  # Or however many turns it takes to heal
		return true
	return false

func leave_medbay(medical_bay: MedicalBayComponent) -> bool:
	if medical_bay.discharge_patient(self):
		medbay_turns_left = 0
		return true
	return false
