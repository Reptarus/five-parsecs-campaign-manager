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

func add_xp(amount: int) -> void:
    xp += amount
    # TODO: Implement level up logic if needed

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
        "equipped_weapon": equipped_weapon.serialize() if equipped_weapon else null,
        "equipped_items": equipped_items.map(func(item): return item.serialize()),
        "traits": traits,
        "medbay_turns_left": medbay_turns_left
    }

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
    character.equipped_weapon = Weapon.deserialize(data["equipped_weapon"]) if data["equipped_weapon"] else null
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
