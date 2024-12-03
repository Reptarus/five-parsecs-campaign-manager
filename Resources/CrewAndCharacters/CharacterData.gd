class_name CharacterData
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const CharacterStats = preload("res://Resources/CrewAndCharacters/CharacterStats.gd")

# Basic Info
@export var character_name: String = ""
@export var origin: GlobalEnums.Origin = GlobalEnums.Origin.MILITARY
@export var background: GlobalEnums.Background = GlobalEnums.Background.SOLDIER
@export var motivation: GlobalEnums.Motivation = GlobalEnums.Motivation.WEALTH
@export var character_class: GlobalEnums.Class = GlobalEnums.Class.WARRIOR
@export var role: GlobalEnums.CrewRole = GlobalEnums.CrewRole.CAPTAIN

# Stats
@export var stats: CharacterStats
@export var skills: Dictionary = {}
@export var traits: Array[String] = []

# Status
@export var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.HEALTHY
@export var health: int = 10
@export var max_health: int = 10
@export var experience: int = 0
@export var level: int = 1

# Equipment
@export var inventory: CharacterInventory
@export var equipped_weapon: Weapon
@export var equipped_armor: Armor

func _init() -> void:
    stats = CharacterStats.new()
    inventory = CharacterInventory.new()
    _initialize_stats()

func _initialize_stats() -> void:
    for stat in GlobalEnums.CharacterStats.values():
        stats.set_stat(stat, 0)

func serialize() -> Dictionary:
    return {
        "character_name": character_name,
        "origin": GlobalEnums.Origin.keys()[origin],
        "background": GlobalEnums.Background.keys()[background],
        "motivation": GlobalEnums.Motivation.keys()[motivation],
        "character_class": GlobalEnums.Class.keys()[character_class],
        "role": GlobalEnums.CrewRole.keys()[role],
        "stats": stats.serialize(),
        "skills": skills,
        "traits": traits,
        "status": GlobalEnums.CharacterStatus.keys()[status],
        "health": health,
        "max_health": max_health,
        "experience": experience,
        "level": level,
        "inventory": inventory.serialize(),
        "equipped_weapon": equipped_weapon.serialize() if equipped_weapon else null,
        "equipped_armor": equipped_armor.serialize() if equipped_armor else null
    }

func deserialize(data: Dictionary) -> void:
    character_name = data.get("character_name", "")
    origin = GlobalEnums.Origin[data.get("origin", "MILITARY")]
    background = GlobalEnums.Background[data.get("background", "SOLDIER")]
    motivation = GlobalEnums.Motivation[data.get("motivation", "WEALTH")]
    character_class = GlobalEnums.Class[data.get("character_class", "WARRIOR")]
    role = GlobalEnums.CrewRole[data.get("role", "CAPTAIN")]
    
    if data.has("stats"):
        stats.deserialize(data.stats)
    skills = data.get("skills", {})
    traits = data.get("traits", [])
    
    status = GlobalEnums.CharacterStatus[data.get("status", "HEALTHY")]
    health = data.get("health", 10)
    max_health = data.get("max_health", 10)
    experience = data.get("experience", 0)
    level = data.get("level", 1)
    
    if data.has("inventory"):
        inventory.deserialize(data.inventory)
        
    if data.has("equipped_weapon") and data.equipped_weapon:
        equipped_weapon = Weapon.new()
        equipped_weapon.deserialize(data.equipped_weapon)
        
    if data.has("equipped_armor") and data.equipped_armor:
        equipped_armor = Armor.new()
        equipped_armor.deserialize(data.equipped_armor) 