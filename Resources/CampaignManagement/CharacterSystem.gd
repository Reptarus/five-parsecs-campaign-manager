class_name CharacterSystem
extends Node



enum CharacterStatType {
    REACTIONS,
    SPEED,
    COMBAT_SKILL,
    AGILITY,
    STRENGTH,
    INTELLIGENCE,
    SURVIVAL,
    TECHNICAL,
    LUCK
}

enum Origin {
    HUMAN,
    ENGINEER,
    KERIN,
    SOULLESS,
    PRECURSOR,
    FERAL,
    SWIFT,
    BOT
}

# Constants for character creation
const BASE_STATS = {
    CharacterStatType.REACTIONS: 1,
    CharacterStatType.SPEED: 4,
    CharacterStatType.COMBAT_SKILL: 0,
    CharacterStatType.AGILITY: 1,
    CharacterStatType.STRENGTH: 1,
    CharacterStatType.INTELLIGENCE: 1
}

const MAX_STATS = {
    CharacterStatType.REACTIONS: 6,
    CharacterStatType.SPEED: 8,
    CharacterStatType.COMBAT_SKILL: 3,
    CharacterStatType.AGILITY: 6,
    CharacterStatType.STRENGTH: 6,
    CharacterStatType.INTELLIGENCE: 6
}

var name_generator: CharacterNameGenerator
var advancement_manager: CharacterAdvancement

func _init() -> void:
    name_generator = CharacterNameGenerator.new()
    advancement_manager = CharacterAdvancement.new()

func create_character() -> Character:
    var character = Character.new()
    _randomize_character(character)
    return character

func _randomize_character(character: Character) -> void:
    character.species = _random_species()
    character.background = _random_background()
    character.character_class = _random_class()
    character.motivation = _random_motivation()
    
    _apply_species_bonuses(character)
    _apply_background_effects(character)
    _apply_class_bonuses(character)

# Helper methods for character creation and advancement
func _random_species() -> Origin:
    return Origin.values()[randi() % Origin.size()]

func _random_background() -> int:
    return randi() % 6  # Assuming 6 background types

func _random_class() -> int:
    return randi() % 5  # Assuming 5 class types

func _random_motivation() -> int:
    return randi() % 5  # Assuming 5 motivation types

func _apply_species_bonuses(character: Character) -> void:
    match character.species:
        Origin.HUMAN:
            character.stats.set_stat(CharacterStatType.LUCK, character.stats.get_stat(CharacterStatType.LUCK) + 1)
        Origin.ENGINEER:
            character.stats.set_stat(CharacterStatType.TECHNICAL, character.stats.get_stat(CharacterStatType.TECHNICAL) + 1)
        Origin.KERIN:
            character.stats.set_stat(CharacterStatType.AGILITY, character.stats.get_stat(CharacterStatType.AGILITY) + 1)
        Origin.SOULLESS:
            character.stats.set_stat(CharacterStatType.STRENGTH, character.stats.get_stat(CharacterStatType.STRENGTH) + 1)
        Origin.PRECURSOR:
            character.stats.set_stat(CharacterStatType.INTELLIGENCE, character.stats.get_stat(CharacterStatType.INTELLIGENCE) + 1)
        Origin.FERAL:
            character.stats.set_stat(CharacterStatType.SURVIVAL, character.stats.get_stat(CharacterStatType.SURVIVAL) + 1)
        Origin.SWIFT:
            character.stats.set_stat(CharacterStatType.SPEED, character.stats.get_stat(CharacterStatType.SPEED) + 1)
        Origin.BOT:
            character.stats.set_stat(CharacterStatType.TECHNICAL, character.stats.get_stat(CharacterStatType.TECHNICAL) + 1)

func _apply_background_effects(character: Character) -> void:
    match character.background:
        GlobalEnums.Background.SOLDIER:
            character.stats.set_stat(GlobalEnums.CharacterStats.COMBAT_SKILL, character.stats.get_stat(GlobalEnums.CharacterStats.COMBAT_SKILL) + 1)
        GlobalEnums.Background.MERCHANT:
            character.stats.set_stat(GlobalEnums.CharacterStats.SAVVY, character.stats.get_stat(GlobalEnums.CharacterStats.SAVVY) + 1)
        GlobalEnums.Background.SCIENTIST:
            character.stats.set_stat(GlobalEnums.CharacterStats.INTELLIGENCE, character.stats.get_stat(GlobalEnums.CharacterStats.INTELLIGENCE) + 1)
        GlobalEnums.Background.EXPLORER:
            character.stats.set_stat(GlobalEnums.CharacterStats.SURVIVAL, character.stats.get_stat(GlobalEnums.CharacterStats.SURVIVAL) + 1)
        GlobalEnums.Background.OUTLAW:
            character.stats.set_stat(GlobalEnums.CharacterStats.STEALTH, character.stats.get_stat(GlobalEnums.CharacterStats.STEALTH) + 1)
        GlobalEnums.Background.DIPLOMAT:
            character.stats.set_stat(GlobalEnums.CharacterStats.LEADERSHIP, character.stats.get_stat(GlobalEnums.CharacterStats.LEADERSHIP) + 1)

func _apply_class_bonuses(character: Character) -> void:
    var equipment_manager = game_state.equipment_manager
    if not equipment_manager:
        push_error("Equipment manager not found")
        return
        
    match character.character_class:
        GlobalEnums.Class.WARRIOR:
            equipment_manager.equip_starting_gear(character, ["combat_armor", "auto_rifle"])
        GlobalEnums.Class.SCOUT:
            equipment_manager.equip_starting_gear(character, ["light_armor", "hunting_rifle"])
        GlobalEnums.Class.TECH:
            equipment_manager.equip_starting_gear(character, ["utility_vest", "hand_laser"])
        GlobalEnums.Class.MEDIC:
            equipment_manager.equip_starting_gear(character, ["med_kit", "pistol"])
        GlobalEnums.Class.LEADER:
            equipment_manager.equip_starting_gear(character, ["command_armor", "hand_gun"])
        GlobalEnums.Class.SPECIALIST:
            equipment_manager.equip_starting_gear(character, ["stealth_suit", "sniper_rifle"])
        GlobalEnums.Class.SUPPORT:
            equipment_manager.equip_starting_gear(character, ["light_armor", "support_weapon"])
        GlobalEnums.Class.GUNNER:
            equipment_manager.equip_starting_gear(character, ["heavy_armor", "heavy_weapon"])

# Character advancement methods
func advance_character(character: Character) -> void:
    advancement_manager.character = character
    var available_upgrades = advancement_manager.get_available_upgrades()
    if available_upgrades.size() > 0:
        character_advanced.emit(character)

func handle_character_death(character: Character) -> void:
    character.status = GlobalEnums.CharacterStatus.DEAD
    character_died.emit(character)