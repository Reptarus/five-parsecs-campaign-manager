@tool
extends Resource
class_name BaseCharacter

## Base character class for all character types in the game
##
## This class provides the foundational properties and methods that all
## character types will inherit. It defines common attributes, stat handling,
## and basic character functionality.

# Basic Info
var character_id: String = ""
var character_name: String = ""
var character_type: int = 0 # Should be defined in GameEnums

# Core Stats
var level: int = 1
var experience: int = 0
var health: int = 10
var max_health: int = 10

# Base character stats
var _reaction: int = 0
var _combat: int = 0
var _toughness: int = 0
var _speed: int = 0

# Status
var is_active: bool = true
var is_wounded: bool = false
var is_dead: bool = false
var status_effects: Array = []

# Equipment slots
var equipment_slots: Dictionary = {
    "weapon": null,
    "armor": null,
    "gear": []
}

# Skills and Abilities
var skills: Array = []
var abilities: Array = []

func _init() -> void:
    character_id = str(Time.get_unix_time_from_system())

## Getters and setters for core stats with validation
var reaction: int:
    get: return _reaction
    set(value):
        _reaction = clampi(value, 0, 6)

var combat: int:
    get: return _combat
    set(value):
        _combat = clampi(value, 0, 5)
        
var toughness: int:
    get: return _toughness
    set(value):
        _toughness = clampi(value, 0, 6)
        
var speed: int:
    get: return _speed
    set(value):
        _speed = clampi(value, 0, 8)

## Core character methods

## Apply damage to the character
func take_damage(amount: int) -> void:
    health = maxi(0, health - amount)
    if health <= 0:
        is_wounded = true
        if health <= - toughness:
            is_dead = true

## Heal the character
func heal(amount: int) -> void:
    health = mini(max_health, health + amount)
    if health > 0:
        is_wounded = false

## Add experience points and handle level up
func add_experience(amount: int) -> bool:
    experience += amount
    var leveled_up = check_level_up()
    return leveled_up
    
## Check if character should level up based on experience
func check_level_up() -> bool:
    var xp_needed = level * 100
    if experience >= xp_needed:
        level += 1
        return true
    return false
    
## Add a skill to the character
func add_skill(skill_name: String) -> void:
    if not skill_name in skills:
        skills.append(skill_name)
        
## Add an ability to the character
func add_ability(ability_name: String) -> void:
    if not ability_name in abilities:
        abilities.append(ability_name)
        
## Check if character has a specific skill
func has_skill(skill_name: String) -> bool:
    return skill_name in skills
    
## Check if character has a specific ability
func has_ability(ability_name: String) -> bool:
    return ability_name in abilities
    
## Apply a status effect to the character
func apply_status_effect(effect: Dictionary) -> void:
    status_effects.append(effect)
    
## Remove a status effect from the character
func remove_status_effect(effect_id: String) -> void:
    for i in range(status_effects.size() - 1, -1, -1):
        if status_effects[i].id == effect_id:
            status_effects.remove_at(i)
            break
            
## Equip an item in the specified slot
func equip_item(item, slot: String) -> bool:
    if slot == "gear":
        equipment_slots.gear.append(item)
        return true
    elif slot in equipment_slots:
        equipment_slots[slot] = item
        return true
    return false
    
## Unequip an item from the specified slot
func unequip_item(slot: String, index: int = 0) -> Variant:
    if slot == "gear" and index < equipment_slots.gear.size():
        return equipment_slots.gear.pop_at(index)
    elif slot in equipment_slots:
        var item = equipment_slots[slot]
        equipment_slots[slot] = null
        return item
    return null