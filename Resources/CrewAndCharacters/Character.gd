class_name Character
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const CharacterInventory = preload("res://Resources/CrewAndCharacters/CharacterInventory.gd")

signal stats_changed
signal equipment_changed
signal traits_changed
signal status_changed(new_status: GlobalEnums.CharacterStatus)

@export_group("Basic Stats")
@export_enum("BROKER", "SOLDIER", "MEDIC", "ENGINEER", "PILOT", "SCOUT") var role: int = GlobalEnums.CrewRole.SOLDIER
@export var character_name: String
@export var level: int = 1
@export var health: int = 100
@export var max_health: int = 100

@export_group("Character Traits")
@export_enum("MILITARY", "CORPORATE", "CRIMINAL", "COLONIST", "NOMAD", "ACADEMIC", "MUTANT", "HYBRID") var origin: int = GlobalEnums.Origin.MILITARY
@export_enum("SOLDIER", "MERCHANT", "SCIENTIST", "EXPLORER", "OUTLAW", "DIPLOMAT") var background: int = GlobalEnums.Background.SOLDIER
@export_enum("WEALTH", "REVENGE", "DISCOVERY", "POWER", "REDEMPTION", "SURVIVAL") var motivation: int = GlobalEnums.Motivation.SURVIVAL
@export_enum("WARRIOR", "TECH", "SCOUT", "LEADER", "SPECIALIST", "SUPPORT") var class_type: int = GlobalEnums.Class.WARRIOR

var status: int = GlobalEnums.CharacterStatus.HEALTHY
var equipment_slots: Array[String] = []
var skills: Array[String] = []
var tutorial_progress: Dictionary = {}
var inventory: CharacterInventory
var traits: Array[String] = []
var portrait_path: String
var equipment: Array = []
var stats: Dictionary = {}

func _init() -> void:
    inventory = CharacterInventory.new()
    _reset_state()
    _initialize_stats()

func _reset_state() -> void:
    status = GlobalEnums.CharacterStatus.HEALTHY
    equipment_slots.clear()
    skills.clear()
    tutorial_progress.clear()
    traits.clear()
    equipment.clear()

func _initialize_stats() -> void:
    stats = {
        GlobalEnums.CharacterStats.REACTIONS: 0,
        GlobalEnums.CharacterStats.SPEED: 0,
        GlobalEnums.CharacterStats.COMBAT_SKILL: 0,
        GlobalEnums.CharacterStats.TOUGHNESS: 0,
        GlobalEnums.CharacterStats.SAVVY: 0,
        GlobalEnums.CharacterStats.LUCK: 0
    }
    

func initialize(init_data: Dictionary) -> void:
    origin = init_data.get("origin", GlobalEnums.Origin.MILITARY)
    background = init_data.get("background", GlobalEnums.Background.SOLDIER)
    motivation = init_data.get("motivation", GlobalEnums.Motivation.SURVIVAL)
    class_type = init_data.get("class_type", GlobalEnums.Class.WARRIOR)
    _apply_origin_bonuses()

func _apply_origin_bonuses() -> void:
    var bonus_data := {
        GlobalEnums.Origin.MILITARY: _apply_military_bonuses,
        GlobalEnums.Origin.CORPORATE: _apply_corporate_bonuses,
        GlobalEnums.Origin.CRIMINAL: _apply_criminal_bonuses,
        GlobalEnums.Origin.COLONIST: _apply_colonist_bonuses,
        GlobalEnums.Origin.NOMAD: _apply_nomad_bonuses,
        GlobalEnums.Origin.ACADEMIC: _apply_academic_bonuses,
        GlobalEnums.Origin.MUTANT: _apply_mutant_bonuses,
        GlobalEnums.Origin.HYBRID: _apply_hybrid_bonuses
    }
    
    if bonus_data.has(origin):
        bonus_data[origin].call()

# Bonus application methods
func _apply_military_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.LUCK] += 1

func _apply_corporate_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.SAVVY] += 2

func _apply_criminal_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.SPEED] += 2

func _apply_colonist_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.TOUGHNESS] += 2

func _apply_nomad_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.REACTIONS] += 2

func _apply_academic_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.COMBAT_SKILL] += 2

func _apply_mutant_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.TOUGHNESS] += 2

func _apply_hybrid_bonuses() -> void:
    stats[GlobalEnums.CharacterStats.SPEED] += 2

static func deserialize(data: Dictionary) -> Character:
    var character = Character.new()
    character.role = data.get("role", GlobalEnums.CrewRole.SOLDIER)
    character.character_name = data.get("name", "Unknown")
    character.level = data.get("level", 1)
    character.health = data.get("health", 100)
    character.max_health = data.get("max_health", 100)
    character.status = data.get("status", GlobalEnums.CharacterStatus.HEALTHY)
    character.initialize({
        "origin": data.get("origin", GlobalEnums.Origin.MILITARY),
        "background": data.get("background", GlobalEnums.Background.SOLDIER),
        "motivation": data.get("motivation", GlobalEnums.Motivation.SURVIVAL),
        "class_type": data.get("class_type", GlobalEnums.Class.WARRIOR)
    })
    character.equipment_slots = data.get("equipment_slots", [])
    character.skills = data.get("skills", [])
    character.tutorial_progress = data.get("tutorial_progress", {})
    return character

func serialize() -> Dictionary:
    return {
        "role": role,
        "name": character_name,
        "level": level,
        "health": health,
        "max_health": max_health,
        "status": status,
        "origin": origin,
        "background": background,
        "motivation": motivation,
        "class_type": class_type,
        "equipment_slots": equipment_slots,
        "skills": skills,
        "tutorial_progress": tutorial_progress,
        "inventory": inventory.serialize()
    }
