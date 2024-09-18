class_name ExpandedMissionsManager
extends Node

var game_state: GameState

const EXPANDED_MISSION_TYPES = [
    "Corporate Espionage",
    "Faction Warfare",
    "Technological Heist",
    "Political Intrigue",
    "Underworld Contract"
]

func _init(_game_state: GameState):
    game_state = _game_state

func generate_expanded_mission() -> Mission:
    var mission = Mission.new()
    mission.type = Mission.Type.EXPANDED
    mission.objective = _generate_expanded_objective()
    mission.location = game_state.get_random_location()
    mission.difficulty = randi() % 5 + 1  # 1 to 5
    mission.rewards = _generate_expanded_rewards(mission.difficulty)
    mission.special_rules = _generate_expanded_special_rules()
    mission.faction = _select_random_faction()
    mission.quest_progression = _generate_quest_progression()
    return mission

func _generate_expanded_objective() -> String:
    return EXPANDED_MISSION_TYPES[randi() % EXPANDED_MISSION_TYPES.size()]

func _generate_expanded_rewards(difficulty: int) -> Dictionary:
    var base_rewards = {
        "credits": 1000 * difficulty,
        "reputation": difficulty + 2,
        "faction_influence": randf() * difficulty
    }
    
    if randf() < 0.3:  # 30% chance for special reward
        base_rewards["special_item"] = _generate_special_item()
    
    return base_rewards

func _generate_expanded_special_rules() -> Array:
    var rules = []
    if randf() < 0.4:
        rules.append("Time Sensitive")
    if randf() < 0.3:
        rules.append("Stealth Required")
    if randf() < 0.2:
        rules.append("High Security")
    return rules

func _select_random_faction() -> Dictionary:
    return game_state.expanded_faction_manager.factions[randi() % game_state.expanded_faction_manager.factions.size()]

func _generate_quest_progression() -> Dictionary:
    return game_state.expanded_quest_progression_manager.generate_quest_stage()

func _generate_special_item() -> Equipment:
    # Similar to ExpandedQuestProgressionManager's _generate_gear function
    var gear_type = ["weapon", "armor", "gadget"][randi() % 3]
    var rarity = _determine_gear_rarity()
    var quality = _determine_gear_quality()
    var base_value = _calculate_base_value(gear_type, rarity, quality)
    var modifiers = _generate_modifiers(gear_type, rarity)
    
    var equipment = Equipment.new(gear_type, rarity, base_value)
    equipment.set_quality(quality)
    
    for modifier in modifiers:
        equipment.add_modifier(modifier)
    
    return equipment

func _determine_gear_rarity() -> int:
    var roll = randf()
    if roll < 0.60:
        return 0  # Common
    elif roll < 0.85:
        return 1  # Uncommon
    elif roll < 0.95:
        return 2  # Rare
    else:
        return 3  # Legendary

func _determine_gear_quality() -> int:
    var roll = randf()
    if roll < 0.20:
        return 1  # Poor
    elif roll < 0.60:
        return 2  # Standard
    elif roll < 0.90:
        return 3  # Superior
    else:
        return 4  # Exceptional

func _calculate_base_value(gear_type: String, rarity: int, quality: int) -> int:
    var base_value = 100
    base_value *= (rarity + 1) * 2
    base_value *= quality
    
    match gear_type:
        "weapon":
            base_value *= 1.2
        "armor":
            base_value *= 1.5
        "gadget":
            base_value *= 1.0
    
    return int(base_value)

func _generate_modifiers(gear_type: String, rarity: int) -> Array:
    var modifiers = []
    var num_modifiers = rarity + 1
    
    for i in range(num_modifiers):
        var modifier = {}
        match gear_type:
            "weapon":
                modifier["type"] = ["damage", "accuracy", "rate_of_fire"][randi() % 3]
            "armor":
                modifier["type"] = ["defense", "mobility", "stealth"][randi() % 3]
            "gadget":
                modifier["type"] = ["utility", "hacking", "scanning"][randi() % 3]
        
        modifier["value"] = (randi() % 5 + 1) * (rarity + 1)
        modifiers.append(modifier)
    
    return modifiers

func setup_expanded_mission(mission: Mission):
    mission.special_rules = _generate_expanded_special_rules()
    mission.involved_factions = [mission.faction]
    if randf() < 0.3:
        mission.involved_factions.append(_select_random_faction())
    
    mission.strife_intensity = randi() % 5 + 1
    mission.key_npcs = _generate_key_npcs(mission)
    mission.environmental_factors = _generate_environmental_factors()
    mission.available_resources = _generate_available_resources(mission.difficulty)
    mission.time_pressure = randi() % 5 + 1

func resolve_expanded_mission(mission: Mission) -> bool:
    var success_chance = 0.5
    success_chance += 0.1 * (game_state.player_ship.crew.size() - mission.required_crew_size)
    success_chance -= 0.1 * (mission.difficulty - 3)
    
    for rule in mission.special_rules:
        if rule == "Time Sensitive":
            success_chance -= 0.1
        elif rule == "High Security":
            success_chance -= 0.15
    
    success_chance = clamp(success_chance, 0.1, 0.9)
    
    var roll = randf()
    var success = roll < success_chance
    
    if success:
        _apply_mission_rewards(mission)
    else:
        _apply_mission_penalties(mission)
    
    return success

func generate_expanded_mission_aftermath(mission: Mission) -> Dictionary:
    # Generate aftermath effects based on mission outcome
    var aftermath = {}
    aftermath["faction_influence_change"] = randf() * 2 - 1  # -1 to 1
    aftermath["quest_progression"] = _update_quest_progression(mission)
    aftermath["new_connections"] = _generate_new_connections(mission)
    return aftermath

func _update_quest_progression(mission: Mission) -> Dictionary:
    return game_state.expanded_quest_progression_manager.update_quest_stage(mission.quest_progression)

func _generate_new_connections(mission: Mission) -> Array:
    var connections = []
    if randf() < 0.3:
        connections.append({
            "type": "New Contact",
            "details": _generate_random_contact()
        })
    if randf() < 0.2:
        connections.append({
            "type": "Rival",
            "details": _generate_random_rival()
        })
    return connections

func _generate_random_contact() -> Dictionary:
    var contact = {
        "name": _generate_random_name(),
        "faction": game_state.faction_manager.get_random_faction(),
        "influence": randi() % 5 + 1,  # 1 to 5
        "speciality": _get_random_speciality(),
        "location": game_state.get_random_location()
    }
    return contact

func _generate_random_rival() -> Dictionary:
    var rival = {
        "name": _generate_random_name(),
        "faction": game_state.faction_manager.get_random_faction(),
        "threat_level": randi() % 5 + 1,  # 1 to 5
        "motivation": _get_random_motivation(),
        "last_known_location": game_state.get_random_location()
    }
    return rival

func _generate_random_name() -> String:
    var first_names = ["Alex", "Sam", "Jordan", "Casey", "Morgan", "Taylor", "Quinn", "Riley", "Avery", "Skyler"]
    var last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]
    return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _get_random_speciality() -> String:
    var specialities = ["Hacking", "Smuggling", "Information Broker", "Arms Dealer", "Medic", "Engineer", "Pilot", "Diplomat"]
    return specialities[randi() % specialities.size()]

func _get_random_motivation() -> String:
    var motivations = ["Revenge", "Power", "Money", "Ideology", "Territory", "Recognition", "Resources", "Survival"]
    return motivations[randi() % motivations.size()]

func adjust_mission_difficulty(mission: Mission, adjustment: String):
    match adjustment:
        "easier":
            mission.difficulty = max(1, mission.difficulty - 1)
        "harder":
            mission.difficulty = min(5, mission.difficulty + 1)
    
    mission.rewards = _generate_expanded_rewards(mission.difficulty)

func get_mission_summary(mission: Mission) -> String:
    var summary = "Expanded Mission: {type}\n".format({"type": Mission.Objective.keys()[mission.objective]})
    summary += "Location: {location}\n".format({"location": mission.location.name})
    summary += "Difficulty: {difficulty}\n".format({"difficulty": mission.difficulty})
    summary += "Faction: {faction}\n".format({"faction": mission.faction.name})
    summary += "Special Rules:\n"
    for rule in mission.special_rules:
        summary += "- {rule}\n".format({"rule": rule})
    summary += "Rewards:\n"
    for reward_type in mission.rewards:
        summary += "- {type}: {value}\n".format({"type": reward_type, "value": mission.rewards[reward_type]})
    return summary

func serialize_mission(mission: Mission) -> Dictionary:
    return {
        "type": mission.type,
        "objective": mission.objective,
        "location": mission.location.serialize(),
        "difficulty": mission.difficulty,
        "rewards": mission.rewards,
        "special_rules": mission.special_rules,
        "faction": {
            "name": mission.faction.name,
            "id": mission.faction.id
            # Add other relevant faction properties
        },
        "quest_progression": mission.quest_progression
    }

static func deserialize_mission(data: Dictionary, game_state: GameState) -> Mission:
    var mission = Mission.new()
    mission.type = data.type
    mission.objective = data.objective
    mission.location = Location.deserialize(data.location)
    mission.difficulty = data.difficulty
    mission.rewards = data.rewards
    mission.special_rules = data.special_rules
    mission.faction = game_state.expanded_faction_manager.deserialize_faction(data.faction)
    mission.quest_progression = data.quest_progression
    return mission

func _generate_key_npcs(mission: Mission) -> Array:
    var npcs = []
    var num_npcs = randi() % 3 + 1  # 1 to 3 NPCs
    for i in range(num_npcs):
        npcs.append({
            "name": _generate_random_name(),
            "role": _get_random_speciality(),
            "faction": mission.faction.name if randf() < 0.7 else _select_random_faction().name
        })
    return npcs

func _generate_available_resources(difficulty: int) -> Dictionary:
    var resources = {
        "credits": 500 * difficulty,
        "equipment": randi() % (difficulty + 1),
        "intel": randi() % (difficulty + 1)
    }
    return resources

func _generate_environmental_factors() -> Array:
    var factors = ["Weather", "Terrain", "Security", "Population", "Technology"]
    var selected_factors = []
    for factor in factors:
        if randf() < 0.4:  # 40% chance to include each factor
            selected_factors.append({
                "type": factor,
                "intensity": randi() % 5 + 1  # 1 to 5
            })
    return selected_factors

func _apply_mission_rewards(mission: Mission):
    for reward_type in mission.rewards:
        match reward_type:
            "credits":
                game_state.player.credits += mission.rewards[reward_type]
            "reputation":
                game_state.player.reputation += mission.rewards[reward_type]
            "faction_influence":
                mission.faction.influence += mission.rewards[reward_type]
            "special_item":
                game_state.player.inventory.add_item(mission.rewards[reward_type])

func _apply_mission_penalties(mission: Mission):
    game_state.player.reputation -= mission.difficulty
    if "credits" in mission.rewards:
        game_state.player.credits -= mission.rewards["credits"] * 0.1
