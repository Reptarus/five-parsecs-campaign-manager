class_name LootManager
extends Resource

signal loot_generated(loot: Dictionary)
signal loot_collected(item: Dictionary)
signal rare_item_found(item: Dictionary)

var game_state: GameState
var loot_tables: Dictionary = {}
var rarity_weights: Dictionary = {
    "COMMON": 60,
    "UNCOMMON": 30,
    "RARE": 8,
    "EPIC": 2
}

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    _initialize_loot_tables()

func generate_loot(context: Dictionary) -> Array:
    var loot = []
    var num_items = _calculate_num_items(context)
    
    for i in range(num_items):
        var item = _generate_single_item(context)
        loot.append(item)
        
        if _is_rare_item(item):
            rare_item_found.emit(item)
    
    loot_generated.emit({"items": loot, "context": context})
    return loot

func collect_loot(item: Dictionary) -> bool:
    if not _can_collect_item(item):
        return false
    
    _add_item_to_inventory(item)
    loot_collected.emit(item)
    return true

func get_loot_table(table_name: String) -> Dictionary:
    return loot_tables.get(table_name, {})

func get_item_rarity(item: Dictionary) -> String:
    return item.get("rarity", "COMMON")

func calculate_item_value(item: Dictionary) -> int:
    var base_value = item.get("base_value", 10)
    var rarity_multiplier = _get_rarity_multiplier(item.get("rarity", "COMMON"))
    var condition_multiplier = item.get("condition", 1.0)
    
    return int(base_value * rarity_multiplier * condition_multiplier)

# Helper Functions
func _initialize_loot_tables() -> void:
    loot_tables = {
        "COMBAT": _create_combat_loot_table(),
        "SALVAGE": _create_salvage_loot_table(),
        "TRADE": _create_trade_loot_table(),
        "QUEST": _create_quest_loot_table(),
        "SPECIAL": _create_special_loot_table()
    }

func _create_combat_loot_table() -> Dictionary:
    return {
        "COMMON": {
            "WEAPON": {
                "weight": 30,
                "items": ["Pistol", "Rifle", "Blade"]
            },
            "ARMOR": {
                "weight": 30,
                "items": ["Light Armor", "Combat Vest", "Shield"]
            },
            "AMMO": {
                "weight": 40,
                "items": ["Standard Ammo", "Energy Cells", "Explosives"]
            }
        },
        "UNCOMMON": {
            "WEAPON": {
                "weight": 40,
                "items": ["Heavy Rifle", "Energy Pistol", "Power Blade"]
            },
            "ARMOR": {
                "weight": 40,
                "items": ["Medium Armor", "Shield Generator", "Combat Suit"]
            },
            "GEAR": {
                "weight": 20,
                "items": ["Combat Scanner", "Tactical Display", "Med Kit"]
            }
        },
        "RARE": {
            "WEAPON": {
                "weight": 50,
                "items": ["Plasma Rifle", "Quantum Pistol", "Phase Blade"]
            },
            "ARMOR": {
                "weight": 30,
                "items": ["Heavy Armor", "Energy Shield", "Power Armor"]
            },
            "SPECIAL": {
                "weight": 20,
                "items": ["Weapon Mod", "Armor Enhancer", "Combat Stims"]
            }
        },
        "EPIC": {
            "WEAPON": {
                "weight": 40,
                "items": ["Legendary Weapon", "Ancient Arsenal", "Prototype Gun"]
            },
            "ARMOR": {
                "weight": 40,
                "items": ["Legendary Armor", "Ancient Shield", "Prototype Suit"]
            },
            "ARTIFACT": {
                "weight": 20,
                "items": ["Combat Artifact", "War Relic", "Battle Trophy"]
            }
        }
    }

func _create_salvage_loot_table() -> Dictionary:
    return {
        "COMMON": {
            "MATERIALS": {
                "weight": 40,
                "items": ["Scrap Metal", "Spare Parts", "Basic Components"]
            },
            "RESOURCES": {
                "weight": 40,
                "items": ["Fuel Cells", "Power Cores", "Raw Materials"]
            },
            "TOOLS": {
                "weight": 20,
                "items": ["Basic Tools", "Repair Kit", "Scanner"]
            }
        },
        "UNCOMMON": {
            "TECH": {
                "weight": 35,
                "items": ["Advanced Components", "Tech Parts", "Circuits"]
            },
            "EQUIPMENT": {
                "weight": 35,
                "items": ["Salvage Gear", "Analysis Tools", "Recovery Equipment"]
            },
            "SPECIAL": {
                "weight": 30,
                "items": ["Ship Parts", "Vehicle Components", "Machinery"]
            }
        },
        "RARE": {
            "ADVANCED": {
                "weight": 40,
                "items": ["Rare Tech", "Experimental Parts", "Prototype Components"]
            },
            "VALUABLE": {
                "weight": 40,
                "items": ["Precious Materials", "Rare Resources", "Exotic Matter"]
            },
            "UNIQUE": {
                "weight": 20,
                "items": ["Ancient Tech", "Lost Technology", "Mysterious Device"]
            }
        },
        "EPIC": {
            "ARTIFACTS": {
                "weight": 50,
                "items": ["Alien Artifact", "Precursor Tech", "Mysterious Relic"]
            },
            "TECHNOLOGY": {
                "weight": 30,
                "items": ["Advanced AI", "Quantum Device", "Reality Shifter"]
            },
            "SPECIAL": {
                "weight": 20,
                "items": ["Legendary Tech", "Universe Shard", "Time Fragment"]
            }
        }
    }

func _create_trade_loot_table() -> Dictionary:
    return {
        "COMMON": {
            "GOODS": {
                "weight": 40,
                "items": ["Trade Goods", "Basic Supplies", "Common Resources"]
            },
            "COMMODITIES": {
                "weight": 40,
                "items": ["Raw Materials", "Food Supplies", "Medical Supplies"]
            },
            "SUPPLIES": {
                "weight": 20,
                "items": ["Ship Supplies", "Crew Supplies", "Basic Equipment"]
            }
        },
        "UNCOMMON": {
            "SPECIALTY": {
                "weight": 40,
                "items": ["Luxury Goods", "Exotic Materials", "Rare Resources"]
            },
            "TECHNOLOGY": {
                "weight": 40,
                "items": ["Tech Goods", "Advanced Equipment", "Specialized Tools"]
            },
            "CONTRABAND": {
                "weight": 20,
                "items": ["Restricted Goods", "Black Market Items", "Illegal Tech"]
            }
        },
        "RARE": {
            "VALUABLE": {
                "weight": 40,
                "items": ["Precious Cargo", "Rare Artifacts", "Unique Items"]
            },
            "RESTRICTED": {
                "weight": 40,
                "items": ["Military Tech", "Experimental Gear", "Classified Items"]
            },
            "SPECIAL": {
                "weight": 20,
                "items": ["Collector's Items", "Ancient Relics", "Mysterious Goods"]
            }
        },
        "EPIC": {
            "LEGENDARY": {
                "weight": 50,
                "items": ["Legendary Items", "Mythical Artifacts", "Lost Treasures"]
            },
            "UNIQUE": {
                "weight": 30,
                "items": ["One-of-a-Kind", "Prototype Tech", "Ancient Wonders"]
            },
            "ARTIFACT": {
                "weight": 20,
                "items": ["Alien Technology", "Reality Fragments", "Time Crystals"]
            }
        }
    }

func _create_quest_loot_table() -> Dictionary:
    return {
        "COMMON": {
            "REWARD": {
                "weight": 50,
                "items": ["Basic Reward", "Standard Payment", "Common Prize"]
            },
            "BONUS": {
                "weight": 30,
                "items": ["Extra Supplies", "Bonus Resources", "Additional Gear"]
            },
            "SPECIAL": {
                "weight": 20,
                "items": ["Quest Item", "Mission Object", "Target Item"]
            }
        },
        "UNCOMMON": {
            "VALUABLE": {
                "weight": 40,
                "items": ["Valuable Reward", "Special Payment", "Unique Prize"]
            },
            "EQUIPMENT": {
                "weight": 40,
                "items": ["Special Gear", "Advanced Equipment", "Rare Tools"]
            },
            "BONUS": {
                "weight": 20,
                "items": ["Extra Reward", "Bonus Payment", "Additional Prize"]
            }
        },
        "RARE": {
            "SPECIAL": {
                "weight": 50,
                "items": ["Rare Reward", "Unique Item", "Special Prize"]
            },
            "ARTIFACT": {
                "weight": 30,
                "items": ["Ancient Item", "Lost Artifact", "Mysterious Object"]
            },
            "TECHNOLOGY": {
                "weight": 20,
                "items": ["Advanced Tech", "Rare Device", "Experimental Item"]
            }
        },
        "EPIC": {
            "LEGENDARY": {
                "weight": 40,
                "items": ["Legendary Reward", "Epic Prize", "Ultimate Item"]
            },
            "UNIQUE": {
                "weight": 40,
                "items": ["One-of-a-Kind", "Mythical Object", "Lost Treasure"]
            },
            "ARTIFACT": {
                "weight": 20,
                "items": ["Ancient Power", "Reality Shard", "Time Crystal"]
            }
        }
    }

func _create_special_loot_table() -> Dictionary:
    return {
        "COMMON": {
            "EVENT": {
                "weight": 50,
                "items": ["Event Item", "Special Drop", "Unique Find"]
            },
            "SEASONAL": {
                "weight": 30,
                "items": ["Season Reward", "Holiday Item", "Special Gift"]
            },
            "ACHIEVEMENT": {
                "weight": 20,
                "items": ["Achievement Reward", "Milestone Prize", "Special Token"]
            }
        },
        "UNCOMMON": {
            "LIMITED": {
                "weight": 40,
                "items": ["Limited Item", "Special Edition", "Rare Find"]
            },
            "COLLECTION": {
                "weight": 40,
                "items": ["Collector's Item", "Set Piece", "Rare Token"]
            },
            "UNIQUE": {
                "weight": 20,
                "items": ["Unique Item", "Special Prize", "Rare Reward"]
            }
        },
        "RARE": {
            "LEGENDARY": {
                "weight": 50,
                "items": ["Legendary Item", "Epic Find", "Rare Treasure"]
            },
            "ARTIFACT": {
                "weight": 30,
                "items": ["Ancient Artifact", "Lost Relic", "Mysterious Item"]
            },
            "SPECIAL": {
                "weight": 20,
                "items": ["Special Reward", "Unique Prize", "Rare Token"]
            }
        },
        "EPIC": {
            "MYTHICAL": {
                "weight": 40,
                "items": ["Mythical Item", "Ultimate Prize", "Supreme Reward"]
            },
            "UNIQUE": {
                "weight": 40,
                "items": ["One-of-a-Kind", "Ultimate Find", "Supreme Item"]
            },
            "LEGENDARY": {
                "weight": 20,
                "items": ["Supreme Artifact", "Ultimate Relic", "Mythical Power"]
            }
        }
    }

func _calculate_num_items(context: Dictionary) -> int:
    var base_items = context.get("base_items", 1)
    var bonus_items = context.get("bonus_items", 0)
    
    # Apply modifiers
    var luck_modifier = game_state.get_luck_modifier()
    var event_modifier = context.get("event_modifier", 1.0)
    
    return base_items + bonus_items + int(luck_modifier * event_modifier)

func _generate_single_item(context: Dictionary) -> Dictionary:
    var rarity = _select_rarity(context)
    var table_name = context.get("table", "COMBAT")
    var table = loot_tables[table_name][rarity]
    
    var category = _select_weighted_category(table)
    var item_name = _select_random_item(table[category].items)
    
    return {
        "id": "item_" + str(randi()),
        "name": item_name,
        "type": category,
        "rarity": rarity,
        "condition": randf_range(0.7, 1.0),
        "base_value": _calculate_base_value(rarity, category),
        "properties": _generate_item_properties(rarity, category)
    }

func _select_rarity(context: Dictionary) -> String:
    var weights = rarity_weights.duplicate()
    
    # Apply context modifiers
    if context.get("is_boss", false):
        weights["RARE"] += 12
        weights["EPIC"] += 8
    
    if context.get("is_special_event", false):
        weights["UNCOMMON"] += 10
        weights["RARE"] += 5
        weights["EPIC"] += 5
    
    # Apply luck modifier
    var luck_modifier = game_state.get_luck_modifier()
    weights["UNCOMMON"] += int(luck_modifier * 5)
    weights["RARE"] += int(luck_modifier * 2)
    weights["EPIC"] += int(luck_modifier)
    
    return _select_weighted(weights)

func _select_weighted_category(table: Dictionary) -> String:
    var weights = {}
    for category in table:
        weights[category] = table[category].weight
    
    return _select_weighted(weights)

func _select_random_item(items: Array) -> String:
    return items[randi() % items.size()]

func _calculate_base_value(rarity: String, category: String) -> int:
    var base_value = 10
    
    # Rarity multiplier
    base_value *= _get_rarity_multiplier(rarity)
    
    # Category modifier
    match category:
        "WEAPON", "ARMOR":
            base_value *= 2
        "ARTIFACT", "LEGENDARY":
            base_value *= 3
        "SPECIAL", "UNIQUE":
            base_value *= 2.5
    
    return base_value

func _generate_item_properties(rarity: String, category: String) -> Dictionary:
    var properties = {}
    
    # Add basic properties
    properties["durability"] = _generate_durability(rarity)
    properties["weight"] = _generate_weight(category)
    
    # Add special properties based on rarity
    var num_special_props = _get_num_special_properties(rarity)
    for i in range(num_special_props):
        var prop = _generate_special_property(category)
        properties[prop.name] = prop.value
    
    return properties

func _generate_durability(rarity: String) -> int:
    var base_durability = 100
    match rarity:
        "UNCOMMON":
            base_durability = 150
        "RARE":
            base_durability = 200
        "EPIC":
            base_durability = 300
    
    return base_durability + randi_range(-20, 20)

func _generate_weight(category: String) -> float:
    var base_weight = 1.0
    match category:
        "WEAPON":
            base_weight = 3.0
        "ARMOR":
            base_weight = 5.0
        "TOOL":
            base_weight = 2.0
    
    return base_weight * randf_range(0.8, 1.2)

func _get_num_special_properties(rarity: String) -> int:
    match rarity:
        "COMMON":
            return 0
        "UNCOMMON":
            return 1
        "RARE":
            return 2
        "EPIC":
            return 3
        _:
            return 0

func _generate_special_property(category: String) -> Dictionary:
    var properties = {
        "WEAPON": ["damage", "accuracy", "range", "fire_rate"],
        "ARMOR": ["protection", "mobility", "durability", "resistance"],
        "TOOL": ["efficiency", "range", "power", "precision"]
    }
    
    var prop_list = properties.get(category, ["quality", "effectiveness", "power"])
    var prop_name = prop_list[randi() % prop_list.size()]
    
    return {
        "name": prop_name,
        "value": randf_range(1.0, 2.0)
    }

func _get_rarity_multiplier(rarity: String) -> float:
    match rarity:
        "COMMON":
            return 1.0
        "UNCOMMON":
            return 2.0
        "RARE":
            return 5.0
        "EPIC":
            return 10.0
        _:
            return 1.0

func _select_weighted(weights: Dictionary) -> String:
    var total_weight = 0
    for weight in weights.values():
        total_weight += weight
    
    var roll = randi_range(1, total_weight)
    var current_weight = 0
    
    for key in weights:
        current_weight += weights[key]
        if roll <= current_weight:
            return key
    
    return weights.keys()[0]  # Fallback

func _is_rare_item(item: Dictionary) -> bool:
    return item.rarity in ["RARE", "EPIC"]

func _can_collect_item(item: Dictionary) -> bool:
    # Check inventory space
    if not game_state.has_inventory_space():
        return false
    
    # Check item requirements
    if "requirements" in item:
        if not _meet_item_requirements(item.requirements):
            return false
    
    return true

func _meet_item_requirements(requirements: Dictionary) -> bool:
    # Check level requirement
    if "level" in requirements:
        if game_state.get_player_level() < requirements.level:
            return false
    
    # Check skill requirements
    if "skills" in requirements:
        for skill in requirements.skills:
            if not game_state.has_skill_level(skill, requirements.skills[skill]):
                return false
    
    return true

func _add_item_to_inventory(item: Dictionary) -> void:
    game_state.add_inventory_item(item) 