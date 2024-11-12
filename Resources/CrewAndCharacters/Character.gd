class_name Character
extends Node

@export var role: GlobalEnums.CrewRole
@export var character_name: String
@export var level: int = 1
@export var health: int = 100
@export var max_health: int = 100

var origin: GlobalEnums.Origin
var background: GlobalEnums.Background
var motivation: GlobalEnums.Motivation
var class_type: GlobalEnums.Class
var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.READY
var equipment_slots: Array[String] = []
var skills: Array[String] = []
var tutorial_progress: Dictionary = {}

func _init() -> void:
    status = GlobalEnums.CharacterStatus.READY

func initialize(origin_type: GlobalEnums.Origin, bg: GlobalEnums.Background, 
                motiv: GlobalEnums.Motivation, char_class: GlobalEnums.Class) -> void:
    origin = origin_type
    background = bg
    motivation = motiv
    class_type = char_class
    _apply_origin_bonuses()

func _apply_origin_bonuses() -> void:
    match origin:
        GlobalEnums.Origin.HUMAN:
            # Balanced stats
            pass
        GlobalEnums.Origin.SYNTHETIC:
            # Enhanced technical abilities
            pass
        GlobalEnums.Origin.HYBRID:
            # Enhanced survival abilities
            pass
        GlobalEnums.Origin.MUTANT:
            # Enhanced physical abilities
            pass
        GlobalEnums.Origin.UPLIFTED:
            # Enhanced social abilities
            pass

static func deserialize(data: Dictionary) -> Character:
    var character = Character.new()
    character.role = data.get("role", GlobalEnums.CrewRole.SECURITY)
    character.character_name = data.get("name", "Unknown")
    character.level = data.get("level", 1)
    character.health = data.get("health", 100)
    character.max_health = data.get("max_health", 100)
    character.status = data.get("status", GlobalEnums.CharacterStatus.READY)
    character.origin = data.get("origin", GlobalEnums.Origin.HUMAN)
    character.background = data.get("background", GlobalEnums.Background.MILITARY)
    character.motivation = data.get("motivation", GlobalEnums.Motivation.SURVIVAL)
    character.class_type = data.get("class_type", GlobalEnums.Class.SOLDIER)
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
        "tutorial_progress": tutorial_progress
    }
