extends Resource
class_name Character

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const CharacterStats = preload("res://Resources/CrewAndCharacters/CharacterStats.gd")

signal stats_changed
signal status_changed
signal equipment_changed
signal advancement_options_available(options: Array)

# Basic Info
@export var character_name: String = ""
@export var origin: GlobalEnums.Origin = GlobalEnums.Origin.MILITARY
@export var background: GlobalEnums.Background = GlobalEnums.Background.SOLDIER
@export var motivation: GlobalEnums.Motivation = GlobalEnums.Motivation.WEALTH
@export var character_class: GlobalEnums.Class = GlobalEnums.Class.WARRIOR
@export var role: GlobalEnums.CrewRole = GlobalEnums.CrewRole.CAPTAIN

# Core components
@export var stats: CharacterStats
@export var inventory: CharacterInventory
@export var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.HEALTHY

# Equipment
@export var equipped_weapon: Weapon
@export var equipped_armor: Armor
@export var equipped_gear: Array[Equipment] = []

# Flags
var is_captain: bool = false
var has_acted_this_turn: bool = false
var is_in_cover: bool = false

func _init() -> void:
    stats = CharacterStats.new()
    inventory = CharacterInventory.new()

# Core Rules character methods
func can_act() -> bool:
    return status != GlobalEnums.CharacterStatus.CRITICAL and not has_acted_this_turn

func take_damage(amount: int) -> void:
    stats.take_damage(amount)
    _check_status_change()

func heal(amount: int) -> void:
    stats.heal(amount)
    _check_status_change()

func _check_status_change() -> void:
    var new_status = GlobalEnums.CharacterStatus.HEALTHY
    
    if stats.current_health <= 0:
        new_status = GlobalEnums.CharacterStatus.CRITICAL
    elif stats.current_health <= stats.max_health * 0.3:
        new_status = GlobalEnums.CharacterStatus.INJURED
    
    if status != new_status:
        status = new_status
        status_changed.emit(status)

func add_experience(amount: int) -> void:
    stats.add_experience(amount)
    stats_changed.emit()

func can_advance() -> bool:
    return stats.advances_available > 0

func process_advancement() -> void:
    if not can_advance():
        return
    
    # Core Rules advancement options
    var available_improvements = []
    
    # Check stats that can be improved
    for stat in ["reactions", "speed", "combat_skill", "toughness", "savvy"]:
        if stats.can_improve_stat(stat):
            available_improvements.append({
                "type": "stat",
                "name": stat,
                "cost": 1
            })
    
    # Check skills that can be improved
    for skill in ["combat_training", "technical_skill", "survival_skill", "medical_skill", "leadership"]:
        if stats.can_improve_skill(skill):
            available_improvements.append({
                "type": "skill",
                "name": skill,
                "cost": 1
            })
    
    # Emit signal with available improvements
    advancement_options_available.emit(available_improvements)

# Equipment methods
func equip_weapon(weapon: Weapon) -> void:
    if equipped_weapon:
        inventory.add_item(equipped_weapon)
    equipped_weapon = weapon
    inventory.remove_item(weapon)
    equipment_changed.emit()

func equip_armor(armor: Armor) -> void:
    if equipped_armor:
        inventory.add_item(equipped_armor)
    equipped_armor = armor
    inventory.remove_item(armor)
    equipment_changed.emit()

func equip_gear(gear: Equipment) -> void:
    if equipped_gear.size() >= 2:  # Core Rules: 2 gear items max
        return
    equipped_gear.append(gear)
    inventory.remove_item(gear)
    equipment_changed.emit()

# Serialization
func serialize() -> Dictionary:
    return {
        "character_name": character_name,
        "background": GlobalEnums.Background.keys()[background],
        "motivation": GlobalEnums.Motivation.keys()[motivation],
        "character_class": GlobalEnums.Class.keys()[character_class],
        "role": GlobalEnums.CrewRole.keys()[role],
        "stats": stats.serialize(),
        "inventory": inventory.serialize(),
        "status": GlobalEnums.CharacterStatus.keys()[status],
        "equipped_weapon": equipped_weapon.serialize() if equipped_weapon else null,
        "equipped_armor": equipped_armor.serialize() if equipped_armor else null,
        "equipped_gear": equipped_gear.map(func(g): return g.serialize()),
        "is_captain": is_captain
    }

func deserialize(data: Dictionary) -> void:
    character_name = data.get("character_name", "")
    background = GlobalEnums.Background[data.get("background", "SOLDIER")]
    motivation = GlobalEnums.Motivation[data.get("motivation", "WEALTH")]
    character_class = GlobalEnums.Class[data.get("character_class", "WARRIOR")]
    role = GlobalEnums.CrewRole[data.get("role", "SOLDIER")]
    
    stats.deserialize(data.get("stats", {}))
    inventory.deserialize(data.get("inventory", {}))
    status = GlobalEnums.CharacterStatus[data.get("status", "HEALTHY")]
    
    if data.has("equipped_weapon"):
        equipped_weapon = Weapon.new()
        equipped_weapon.deserialize(data.equipped_weapon)
        
    if data.has("equipped_armor"):
        equipped_armor = Armor.new()
        equipped_armor.deserialize(data.equipped_armor)
        
    equipped_gear.clear()
    for gear_data in data.get("equipped_gear", []):
        var gear = Equipment.new()
        gear.deserialize(gear_data)
        equipped_gear.append(gear)
    
    is_captain = data.get("is_captain", false)
