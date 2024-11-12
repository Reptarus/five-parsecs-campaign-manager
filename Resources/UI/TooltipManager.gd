class_name TooltipManager
extends Node

const TOOLTIPS = {
    "difficulty": {
        &"easy": "Recommended for new players. Enemies are weaker and rewards are higher.",
        &"normal": "The standard game experience. Balanced for most players.",
        &"challenging": "For experienced players. Enemies are smarter and resources are scarcer.",
        &"hardcore": "A true test of skill. Permanent death and limited resources.",
        &"insanity": "The ultimate challenge. Everything is trying to kill you."
    },
    "victory": {
        &"turns": "Complete a set number of campaign turns.",
        &"quests": "Complete a specific number of story quests.",
        &"battles": "Win a certain number of battles.",
        &"unique_kills": "Defeat powerful unique enemies.",
        &"character_upgrades": "Fully upgrade a character.",
        &"multi_character_upgrades": "Fully upgrade multiple characters."
    },
    "species": {
        &"human": "Versatile and adaptable. +1 Luck.",
        &"engineer": "Technical experts. +1 Technical skill.",
        &"kerin": "Strong warriors. +1 Combat skill.",
        &"soulless": "Artificial beings. Immune to morale effects.",
        &"precursor": "Ancient race. Access to unique abilities.",
        &"feral": "Wild and unpredictable. +1 Survival skill.",
        &"swift": "Quick and agile. +1 Speed.",
        &"bot": "Robotic units. No need for life support.",
        &"skulker": "Stealthy infiltrators. Better at sneaking.",
        &"krag": "Tough warriors. +1 Toughness."
    },
    "background": {
        &"high_tech_colony": "Advanced technological knowledge. +1 Technical.",
        &"overcrowded_city": "Street smarts. +1 Social.",
        &"low_tech_colony": "Resourceful. +1 Survival.",
        &"mining_colony": "Used to hard work. +1 Toughness.",
        &"military_brat": "Combat training. +1 Combat.",
        &"space_station": "Zero-G experience. +1 Technical."
    },
    "motivation": {
        &"wealth": "Seeking fortune. Bonus to trade actions.",
        &"fame": "Seeking recognition. Bonus to social actions.",
        &"glory": "Seeking combat. Bonus to combat actions.",
        &"survival": "Just trying to live. Bonus to survival actions.",
        &"escape": "Running from something. Bonus to stealth actions.",
        &"adventure": "Seeking excitement. Bonus to exploration actions."
    },
    "class": {
        &"working_class": "Jack of all trades. No penalties.",
        &"technician": "Technical specialist. +1 Technical, -1 Combat.",
        &"scientist": "Knowledge specialist. +1 Technical, -1 Social.",
        &"hacker": "Digital specialist. +1 Technical, -1 Survival.",
        &"soldier": "Combat specialist. +1 Combat, -1 Technical.",
        &"mercenary": "Combat specialist. +1 Combat, -1 Social."
    }
}

static func get_tooltip(category: String, key: Variant) -> String:
    if not category in TOOLTIPS:
        return ""
    
    var tooltip_category = TOOLTIPS[category]
    
    # Handle string input
    if key is String:
        var string_key = key.to_lower()
        if string_key in tooltip_category:
            return tooltip_category[string_key]
    
    # Handle enum input
    if key is int:
        var enum_name = GlobalEnums.get_enum_name(category, key)
        if enum_name:
            var string_key = enum_name.to_lower()
            if string_key in tooltip_category:
                return tooltip_category[string_key]
    
    return ""