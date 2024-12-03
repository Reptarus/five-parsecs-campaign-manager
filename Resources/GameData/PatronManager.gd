class_name PatronManager
extends Resource

signal patron_encountered(patron: Dictionary)
signal patron_reputation_changed(patron: Dictionary, change: int)
signal patron_quest_offered(patron: Dictionary, quest: Dictionary)
signal patron_quest_completed(patron: Dictionary, quest: Dictionary)
signal patron_quest_failed(patron: Dictionary, quest: Dictionary)

var game_state: GameState
var active_patrons: Array = []
var patron_reputations: Dictionary = {}  # patron_id -> reputation
var active_quests: Dictionary = {}  # quest_id -> quest
var completed_quests: Array = []

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func generate_patron() -> Dictionary:
    var patron = {
        "id": "patron_" + str(randi()),
        "name": _generate_patron_name(),
        "type": _select_patron_type(),
        "influence": randi_range(1, 5),
        "resources": {
            "credits": randi_range(5000, 20000),
            "connections": randi_range(1, 5),
            "specialization": _select_specialization()
        },
        "preferences": _generate_patron_preferences()
    }
    
    active_patrons.append(patron)
    patron_reputations[patron.id] = 0
    
    patron_encountered.emit(patron)
    return patron

func update_patron_reputation(patron_id: String, change: int) -> void:
    if not patron_id in patron_reputations:
        return
    
    patron_reputations[patron_id] = clamp(patron_reputations[patron_id] + change, -100, 100)
    var patron = get_patron(patron_id)
    
    patron_reputation_changed.emit(patron, change)

func get_patron(patron_id: String) -> Dictionary:
    for patron in active_patrons:
        if patron.id == patron_id:
            return patron
    return {}

func get_patron_reputation(patron_id: String) -> int:
    return patron_reputations.get(patron_id, 0)

func get_active_patrons() -> Array:
    return active_patrons

func get_available_quests(patron_id: String) -> Array:
    var patron = get_patron(patron_id)
    if patron.is_empty():
        return []
    
    var quests = []
    var num_quests = randi_range(1, 3)
    
    for i in range(num_quests):
        var quest = _generate_quest(patron)
        if _validate_quest(quest):
            quests.append(quest)
    
    return quests

func accept_quest(quest_id: String) -> bool:
    if quest_id in active_quests:
        return false
    
    var quest = _find_quest_by_id(quest_id)
    if quest.is_empty():
        return false
    
    active_quests[quest_id] = quest
    return true

func complete_quest(quest_id: String, success: bool) -> void:
    if not quest_id in active_quests:
        return
    
    var quest = active_quests[quest_id]
    var patron = get_patron(quest.patron_id)
    
    if success:
        _apply_quest_rewards(quest)
        patron_quest_completed.emit(patron, quest)
    else:
        _apply_quest_penalties(quest)
        patron_quest_failed.emit(patron, quest)
    
    active_quests.erase(quest_id)
    completed_quests.append(quest)

func get_active_quest_count() -> int:
    return active_quests.size()

func can_accept_more_quests() -> bool:
    return get_active_quest_count() < game_state.max_active_quests

# Helper Functions
func _generate_patron_name() -> String:
    var titles = ["Director", "Baron", "Councilor", "Minister", "Admiral"]
    var names = ["Blackwood", "Chen", "Rodriguez", "Patel", "Volkov"]
    
    return titles[randi() % titles.size()] + " " + names[randi() % names.size()]

func _select_patron_type() -> String:
    var types = ["CORPORATE", "NOBLE", "MILITARY", "POLITICAL", "CRIMINAL"]
    return types[randi() % types.size()]

func _select_specialization() -> String:
    var specializations = ["TRADE", "TECHNOLOGY", "WARFARE", "INTELLIGENCE", "RESEARCH"]
    return specializations[randi() % specializations.size()]

func _generate_patron_preferences() -> Dictionary:
    return {
        "mission_types": _select_preferred_mission_types(),
        "reward_types": _select_preferred_reward_types(),
        "risk_tolerance": randf_range(0.3, 0.8),
        "loyalty_importance": randf_range(0.4, 0.9)
    }

func _select_preferred_mission_types() -> Array:
    var all_types = ["COMBAT", "ESPIONAGE", "TRANSPORT", "DIPLOMACY", "EXPLORATION"]
    var num_preferences = randi_range(2, 3)
    var selected = []
    
    for i in range(num_preferences):
        var type = all_types[randi() % all_types.size()]
        if not type in selected:
            selected.append(type)
    
    return selected

func _select_preferred_reward_types() -> Array:
    var all_types = ["CREDITS", "EQUIPMENT", "INFORMATION", "INFLUENCE", "TECHNOLOGY"]
    var num_preferences = randi_range(2, 3)
    var selected = []
    
    for i in range(num_preferences):
        var type = all_types[randi() % all_types.size()]
        if not type in selected:
            selected.append(type)
    
    return selected

func _generate_quest(patron: Dictionary) -> Dictionary:
    var quest_type = patron.preferences.mission_types[randi() % patron.preferences.mission_types.size()]
    
    return {
        "id": "quest_" + str(randi()),
        "patron_id": patron.id,
        "type": quest_type,
        "name": _generate_quest_name(quest_type),
        "description": _generate_quest_description(quest_type),
        "difficulty": _calculate_quest_difficulty(patron),
        "rewards": _generate_quest_rewards(patron),
        "requirements": _generate_quest_requirements(quest_type),
        "time_limit": _calculate_time_limit(quest_type),
        "risk_level": _calculate_risk_level(patron)
    }

func _generate_quest_name(quest_type: String) -> String:
    var prefixes = {
        "COMBAT": ["Assault on ", "Defense of ", "Strike at "],
        "ESPIONAGE": ["Infiltration of ", "Intelligence from ", "Secrets of "],
        "TRANSPORT": ["Delivery to ", "Shipment for ", "Cargo Run to "],
        "DIPLOMACY": ["Negotiations with ", "Peace Mission to ", "Alliance with "],
        "EXPLORATION": ["Survey of ", "Exploration of ", "Discovery in "]
    }
    
    var locations = ["New Eden", "Starfall", "The Reach", "Deep Space", "The Frontier"]
    var prefix_list = prefixes.get(quest_type, ["Mission to "])
    
    return prefix_list[randi() % prefix_list.size()] + locations[randi() % locations.size()]

func _generate_quest_description(quest_type: String) -> String:
    var descriptions = {
        "COMBAT": "Engage hostile forces and secure the objective.",
        "ESPIONAGE": "Gather critical information while maintaining secrecy.",
        "TRANSPORT": "Safely deliver valuable cargo to its destination.",
        "DIPLOMACY": "Navigate complex negotiations and secure an agreement.",
        "EXPLORATION": "Chart unknown territory and document findings."
    }
    
    return descriptions.get(quest_type, "Complete the assigned mission objectives.")

func _calculate_quest_difficulty(patron: Dictionary) -> int:
    var base_difficulty = patron.influence
    var reputation = get_patron_reputation(patron.id)
    
    # Modify based on reputation
    if reputation >= 50:
        base_difficulty += 1
    elif reputation <= -50:
        base_difficulty -= 1
    
    return clamp(base_difficulty, 1, 5)

func _generate_quest_rewards(patron: Dictionary) -> Dictionary:
    var reward_type = patron.preferences.reward_types[randi() % patron.preferences.reward_types.size()]
    var base_value = 1000 * patron.influence
    
    var rewards = {
        "credits": base_value,
        "reputation": 10,
        "bonus_type": reward_type,
        "bonus_value": _calculate_bonus_reward(reward_type, patron)
    }
    
    return rewards

func _generate_quest_requirements(quest_type: String) -> Dictionary:
    var requirements = {
        "min_crew": 1,
        "required_skills": {},
        "required_equipment": []
    }
    
    match quest_type:
        "COMBAT":
            requirements.min_crew = 3
            requirements.required_skills = {"combat": 2}
            requirements.required_equipment = ["weapons", "armor"]
        "ESPIONAGE":
            requirements.min_crew = 1
            requirements.required_skills = {"stealth": 2, "hacking": 1}
            requirements.required_equipment = ["stealth_gear"]
        "TRANSPORT":
            requirements.min_crew = 2
            requirements.required_skills = {"piloting": 2}
            requirements.required_equipment = ["cargo_hold"]
        "DIPLOMACY":
            requirements.min_crew = 2
            requirements.required_skills = {"negotiation": 2}
            requirements.required_equipment = []
        "EXPLORATION":
            requirements.min_crew = 2
            requirements.required_skills = {"survival": 1, "science": 1}
            requirements.required_equipment = ["scanner"]
    
    return requirements

func _calculate_time_limit(quest_type: String) -> int:
    var base_time = 24 * 3600  # 24 hours in seconds
    
    match quest_type:
        "COMBAT":
            return base_time
        "ESPIONAGE":
            return base_time * 2
        "TRANSPORT":
            return base_time * 3
        "DIPLOMACY":
            return base_time * 4
        "EXPLORATION":
            return base_time * 5
        _:
            return base_time * 2

func _calculate_risk_level(patron: Dictionary) -> float:
    return patron.preferences.risk_tolerance

func _calculate_bonus_reward(reward_type: String, patron: Dictionary) -> Dictionary:
    match reward_type:
        "CREDITS":
            return {"amount": 500 * patron.influence}
        "EQUIPMENT":
            return {"item": _select_equipment_reward(patron)}
        "INFORMATION":
            return {"data": _select_information_reward(patron)}
        "INFLUENCE":
            return {"faction": _select_faction_influence(patron)}
        "TECHNOLOGY":
            return {"tech": _select_technology_reward(patron)}
        _:
            return {}

func _select_equipment_reward(patron: Dictionary) -> Dictionary:
    return {
        "type": "EQUIPMENT",
        "category": _select_equipment_category(patron),
        "quality": clamp(patron.influence - 1, 1, 4)
    }

func _select_information_reward(patron: Dictionary) -> Dictionary:
    return {
        "type": "INFORMATION",
        "category": _select_information_category(patron),
        "value": patron.influence * 100
    }

func _select_faction_influence(patron: Dictionary) -> Dictionary:
    return {
        "faction": patron.type,
        "amount": patron.influence * 5
    }

func _select_technology_reward(patron: Dictionary) -> Dictionary:
    return {
        "type": "TECHNOLOGY",
        "category": patron.resources.specialization,
        "level": clamp(patron.influence - 1, 1, 4)
    }

func _select_equipment_category(patron: Dictionary) -> String:
    var categories = ["WEAPONS", "ARMOR", "TOOLS", "DEVICES"]
    return categories[randi() % categories.size()]

func _select_information_category(patron: Dictionary) -> String:
    var categories = ["TRADE", "MILITARY", "POLITICAL", "SCIENTIFIC"]
    return categories[randi() % categories.size()]

func _validate_quest(quest: Dictionary) -> bool:
    # Check required fields
    var required_fields = ["id", "patron_id", "type", "name", "description", "rewards", "requirements"]
    for field in required_fields:
        if not field in quest:
            return false
    
    # Validate rewards
    if not "credits" in quest.rewards or quest.rewards.credits <= 0:
        return false
    
    # Validate requirements
    if not "min_crew" in quest.requirements or quest.requirements.min_crew <= 0:
        return false
    
    return true

func _find_quest_by_id(quest_id: String) -> Dictionary:
    for patron in active_patrons:
        var available_quests = get_available_quests(patron.id)
        for quest in available_quests:
            if quest.id == quest_id:
                return quest
    return {}

func _apply_quest_rewards(quest: Dictionary) -> void:
    # Apply base rewards
    game_state.add_credits(quest.rewards.credits)
    update_patron_reputation(quest.patron_id, quest.rewards.reputation)
    
    # Apply bonus rewards
    match quest.rewards.bonus_type:
        "CREDITS":
            game_state.add_credits(quest.rewards.bonus_value.amount)
        "EQUIPMENT":
            game_state.add_equipment(quest.rewards.bonus_value.item)
        "INFORMATION":
            game_state.add_information(quest.rewards.bonus_value.data)
        "INFLUENCE":
            game_state.add_faction_reputation(quest.rewards.bonus_value.faction, quest.rewards.bonus_value.amount)
        "TECHNOLOGY":
            game_state.add_technology(quest.rewards.bonus_value.tech)

func _apply_quest_penalties(quest: Dictionary) -> void:
    # Reputation penalty
    update_patron_reputation(quest.patron_id, -quest.rewards.reputation)
    
    # Additional penalties based on quest type
    match quest.type:
        "COMBAT":
            game_state.add_combat_failure()
        "ESPIONAGE":
            game_state.add_stealth_failure()
        "TRANSPORT":
            game_state.add_delivery_failure()
        "DIPLOMACY":
            game_state.add_negotiation_failure()
        "EXPLORATION":
            game_state.add_exploration_failure() 