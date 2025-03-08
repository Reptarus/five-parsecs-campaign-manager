@tool
extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/character/Equipment/ConsolidatedArmor.gd")

## Consolidated Armor Implementation
##
## Combines core, game-specific, and data management functionalities.

# Import required resources
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Basic armor properties
@export var armor_id: String = ""
@export var armor_name: String = ""
@export var armor_description: String = ""
@export var armor_save: int = 0

# Consolidated properties
var damage_resistance: int = 0
var movement_penalty: int = 0
var repair_cost: int = 0
var environmental_protection: bool = false
var defense: int = 1
var armor_type: int = GlobalEnums.ArmorType.LIGHT
var characteristics: Array[int] = []
var durability: int = 100
var current_durability: int = 100
var cost: int = 0

func _init() -> void:
    pass

func get_effective_armor_value() -> int:
    return armor_save + damage_resistance

func apply_modifiers(character) -> void:
    # Base implementation - can be overridden
    pass

func apply_additional_modifiers(character) -> void:
    if movement_penalty > 0 and character.has_method("modify_movement"):
        character.modify_movement(- movement_penalty)
    apply_modifiers(character)

func get_display_name() -> String:
    var display = armor_name if armor_name else "Unnamed Armor"
    if environmental_protection:
        display += " (Environmental)"
    if is_damaged():
        display += " (Damaged)"
    return display

func get_description() -> String:
    var desc = armor_description if armor_description else "Standard armor."
    desc += "\nDurability: %d/100" % durability
    if environmental_protection:
        desc += "\nProvides Environmental Protection"
    if is_damaged():
        desc += "\nNeeds Repair (Cost: %d credits)" % calculate_repair_cost()
    return desc

func is_damaged() -> bool:
    return current_durability < durability

func repair(amount: int) -> void:
    current_durability = min(current_durability + amount, durability)

func take_damage(amount: int) -> void:
    current_durability = max(0, current_durability - amount)

func is_broken() -> bool:
    return current_durability <= 0

func get_characteristics() -> Array[int]:
    return characteristics

func has_characteristic(characteristic: int) -> bool:
    return characteristic in characteristics

func add_characteristic(characteristic: int) -> void:
    if not has_characteristic(characteristic):
        characteristics.append(characteristic)

func remove_characteristic(characteristic: int) -> void:
    characteristics.erase(characteristic)

func calculate_repair_cost() -> int:
    return (100 - durability) * cost / 100

func serialize() -> Dictionary:
    var data = {
        "armor_id": armor_id,
        "armor_name": armor_name,
        "armor_description": armor_description,
        "armor_save": armor_save,
        "damage_resistance": damage_resistance,
        "movement_penalty": movement_penalty,
        "repair_cost": repair_cost,
        "environmental_protection": environmental_protection,
        "defense": defense,
        "armor_type": armor_type,
        "characteristics": characteristics.duplicate(),
        "durability": durability,
        "current_durability": current_durability,
        "cost": cost
    }
    return data

func deserialize(data: Dictionary) -> Resource:
    armor_id = data.get("armor_id", "")
    armor_name = data.get("armor_name", "")
    armor_description = data.get("armor_description", "")
    armor_save = data.get("armor_save", 0)
    damage_resistance = data.get("damage_resistance", 0)
    movement_penalty = data.get("movement_penalty", 0)
    repair_cost = data.get("repair_cost", 0)
    environmental_protection = data.get("environmental_protection", false)
    defense = data.get("defense", 1)
    armor_type = data.get("armor_type", GlobalEnums.ArmorType.LIGHT)
    characteristics = data.get("characteristics", [])
    durability = data.get("durability", 100)
    current_durability = data.get("current_durability", durability)
    cost = data.get("cost", 0)
    return self