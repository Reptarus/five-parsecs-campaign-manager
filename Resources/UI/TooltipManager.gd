class_name TooltipManager
extends Node

const TOOLTIPS = {
    "difficulty": {
        GlobalEnums.DifficultyMode.EASY: "Recommended for new players. Enemies are weaker and rewards are higher.",
        GlobalEnums.DifficultyMode.NORMAL: "The standard game experience. Balanced for most players.",
        GlobalEnums.DifficultyMode.CHALLENGING: "For experienced players. Enemies are smarter and resources are scarcer.",
        GlobalEnums.DifficultyMode.HARDCORE: "A true test of skill. Permanent death and limited resources.",
        GlobalEnums.DifficultyMode.INSANITY: "The ultimate challenge. Everything is trying to kill you."
    },
    "victory": {
        GlobalEnums.VictoryConditionType.TURNS: "Complete a set number of campaign turns.",
        GlobalEnums.VictoryConditionType.QUESTS: "Complete a specific number of story quests.",
        GlobalEnums.VictoryConditionType.BATTLES: "Win a certain number of battles.",
        GlobalEnums.VictoryConditionType.UNIQUE_KILLS: "Defeat powerful unique enemies.",
        GlobalEnums.VictoryConditionType.CHARACTER_UPGRADES: "Fully upgrade a character.",
        GlobalEnums.VictoryConditionType.MULTI_CHARACTER_UPGRADES: "Fully upgrade multiple characters."
    },
    "species": {
        GlobalEnums.Species.HUMAN: "Versatile and adaptable. +1 Luck.",
        GlobalEnums.Species.ENGINEER: "Technical experts. +1 Technical skill.",
        GlobalEnums.Species.KERIN: "Strong warriors. +1 Combat skill.",
        GlobalEnums.Species.SOULLESS: "Artificial beings. Immune to morale effects.",
        GlobalEnums.Species.PRECURSOR: "Ancient race. Access to unique abilities.",
        GlobalEnums.Species.FERAL: "Wild and unpredictable. +1 Survival skill.",
        GlobalEnums.Species.SWIFT: "Quick and agile. +1 Speed.",
        GlobalEnums.Species.BOT: "Robotic units. No need for life support.",
        GlobalEnums.Species.SKULKER: "Stealthy infiltrators. Better at sneaking.",
        GlobalEnums.Species.KRAG: "Tough warriors. +1 Toughness."
    },
    "background": {
        GlobalEnums.Background.HIGH_TECH_COLONY: "Advanced technological knowledge. +1 Technical.",
        GlobalEnums.Background.OVERCROWDED_CITY: "Street smarts. +1 Social.",
        GlobalEnums.Background.LOW_TECH_COLONY: "Resourceful. +1 Survival.",
        GlobalEnums.Background.MINING_COLONY: "Used to hard work. +1 Toughness.",
        GlobalEnums.Background.MILITARY_BRAT: "Combat training. +1 Combat.",
        GlobalEnums.Background.SPACE_STATION: "Zero-G experience. +1 Technical."
    },
    "motivation": {
        GlobalEnums.Motivation.WEALTH: "Seeking fortune. Bonus to trade actions.",
        GlobalEnums.Motivation.FAME: "Seeking recognition. Bonus to social actions.",
        GlobalEnums.Motivation.GLORY: "Seeking combat. Bonus to combat actions.",
        GlobalEnums.Motivation.SURVIVAL: "Just trying to live. Bonus to survival actions.",
        GlobalEnums.Motivation.ESCAPE: "Running from something. Bonus to stealth actions.",
        GlobalEnums.Motivation.ADVENTURE: "Seeking excitement. Bonus to exploration actions."
    },
    "class": {
        GlobalEnums.Class.WORKING_CLASS: "Jack of all trades. No penalties.",
        GlobalEnums.Class.TECHNICIAN: "Technical specialist. +1 Technical, -1 Combat.",
        GlobalEnums.Class.SCIENTIST: "Knowledge specialist. +1 Technical, -1 Social.",
        GlobalEnums.Class.HACKER: "Digital specialist. +1 Technical, -1 Survival.",
        GlobalEnums.Class.SOLDIER: "Combat specialist. +1 Combat, -1 Technical.",
        GlobalEnums.Class.MERCENARY: "Combat specialist. +1 Combat, -1 Social."
    },
    "weapon_type": {
        GlobalEnums.WeaponType.PISTOL: "One-handed ranged weapon. Can be used in close combat.",
        GlobalEnums.WeaponType.RIFLE: "Two-handed ranged weapon. Better accuracy.",
        GlobalEnums.WeaponType.HEAVY: "Heavy weapon. High damage but slow.",
        GlobalEnums.WeaponType.MELEE: "Close combat weapon. No ammo needed.",
        GlobalEnums.WeaponType.GRENADE: "Thrown weapon. Area effect damage."
    },
    "armor_type": {
        GlobalEnums.ArmorType.LIGHT: "Basic protection. Minimal movement penalty.",
        GlobalEnums.ArmorType.MEDIUM: "Good protection. Moderate movement penalty.",
        GlobalEnums.ArmorType.HEAVY: "Best protection. Significant movement penalty.",
        GlobalEnums.ArmorType.SCREEN: "Energy shield. No movement penalty but uses power."
    },
    "mission_type": {
        GlobalEnums.MissionType.PATROL: "Standard patrol mission. Low risk, low reward.",
        GlobalEnums.MissionType.RESCUE: "Save targets from danger. Time sensitive.",
        GlobalEnums.MissionType.SABOTAGE: "Destroy enemy assets. Stealth recommended.",
        GlobalEnums.MissionType.ESCORT: "Protect targets. Defensive mission.",
        GlobalEnums.MissionType.ASSASSINATION: "Eliminate specific targets. High risk.",
        GlobalEnums.MissionType.RETRIEVAL: "Recover items or data. Extraction required.",
        GlobalEnums.MissionType.FRINGE_WORLD_STRIFE: "Deal with local conflicts. Complex situation."
    },
    "terrain_type": {
        GlobalEnums.TerrainType.CITY: "Urban environment. Lots of cover.",
        GlobalEnums.TerrainType.FOREST: "Natural environment. Limited visibility.",
        GlobalEnums.TerrainType.SPACE_STATION: "Artificial environment. Confined spaces.",
        GlobalEnums.TerrainType.STARSHIP: "Ship interior. Tight corridors.",
        GlobalEnums.TerrainType.ALIEN_LANDSCAPE: "Unknown environment. Possible hazards."
    }
}

static func get_tooltip(category: String, key: Variant) -> String:
    if category in TOOLTIPS and key in TOOLTIPS[category]:
        return TOOLTIPS[category][key]
    return "" 