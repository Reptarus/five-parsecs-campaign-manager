class_name PlanetNameGenerator
extends RefCounted

const PREFIXES = [
    "New", "Alpha", "Beta", "Gamma", "Nova", "Proxima", "Terra", "Neo",
    "Far", "Deep", "Lost", "Hidden", "Ancient", "Prime", "Core"
]

const BASES = [
    "Haven", "Port", "World", "Colony", "Station", "Outpost", "Base",
    "Reach", "Point", "Hub", "Gate", "Nexus", "Core", "Edge", "Rim"
]

const SUFFIXES = [
    "Prime", "Minor", "Major", "Alpha", "Beta", "Gamma", "I", "II", "III",
    "IV", "V", "A", "B", "C", "Zero"
]

# Planet type specific words
const TYPE_SPECIFIC = {
    "mining": ["Lode", "Quarry", "Dig", "Mine", "Ore", "Mineral", "Crystal"],
    "industrial": ["Forge", "Factory", "Works", "Industry", "Production"],
    "agricultural": ["Garden", "Farm", "Grove", "Field", "Harvest"],
    "research": ["Lab", "Research", "Study", "Archive", "Institute"],
    "military": ["Fort", "Base", "Garrison", "Post", "Command"],
    "trade": ["Market", "Trade", "Exchange", "Commerce", "Port"]
}

func generate_name() -> String:
    var name_parts = []
    
    # 50% chance to add a prefix
    if randf() < 0.5:
        name_parts.append(PREFIXES[randi() % PREFIXES.size()])
    
    # Always add a base name
    name_parts.append(BASES[randi() % BASES.size()])
    
    # 30% chance to add a type-specific word
    if randf() < 0.3:
        var type_keys = TYPE_SPECIFIC.keys()
        var type_key = type_keys[randi() % type_keys.size()]
        var type_words = TYPE_SPECIFIC[type_key]
        name_parts.append(type_words[randi() % type_words.size()])
    
    # 40% chance to add a suffix
    if randf() < 0.4:
        name_parts.append(SUFFIXES[randi() % SUFFIXES.size()])
    
    return " ".join(name_parts)

func generate_sector_name() -> String:
    var sector_bases = [
        "Sector", "Quadrant", "Region", "Zone", "Territory",
        "Expanse", "Reach", "Space", "Area", "District"
    ]
    
    var sector_prefixes = [
        "Outer", "Inner", "Central", "Frontier", "Border",
        "Core", "Rim", "Deep", "Far", "Near"
    ]
    
    var name_parts = []
    
    # 70% chance to add a prefix
    if randf() < 0.7:
        name_parts.append(sector_prefixes[randi() % sector_prefixes.size()])
    
    # Always add a base name
    name_parts.append(sector_bases[randi() % sector_bases.size()])
    
    # 50% chance to add a designation
    if randf() < 0.5:
        name_parts.append(str(randi() % 999).pad_zeros(3))
    
    return " ".join(name_parts) 