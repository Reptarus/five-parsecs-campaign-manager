class_name ExpandedQuestProgressionManager
extends Node

@export var game_state: GameState
var quest_stages: Dictionary
var active_quests: Array[Quest] = []
var active_rumors: Array[QuestRumor] = []

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    load_quest_stages()

func load_quest_stages() -> void:
    const QUEST_STAGES_PATH = "res://Data/quest_stages.json"
    if not FileAccess.file_exists(QUEST_STAGES_PATH):
        push_error("Quest stages file not found: " + QUEST_STAGES_PATH)
        return
    
    var file = FileAccess.open(QUEST_STAGES_PATH, FileAccess.READ)
    if file == null:
        push_error("Failed to open quest stages file: " + QUEST_STAGES_PATH)
        return
    
    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    file.close()
    
    if error == OK:
        var data = json.get_data()
        if typeof(data) == TYPE_DICTIONARY:
            quest_stages = data
        else:
            push_error("Invalid quest stages data format")
    else:
        push_error("Failed to parse quest stages JSON: " + json.get_error_message())


func generate_new_quest() -> Quest:
    var quest_generator = QuestGenerator.new(game_state)
    var new_quest = quest_generator.generate_quest()
    new_quest.current_stage = 1
    new_quest.current_requirements = quest_stages["quest_stages"][0]["requirements"]
    active_quests.append(new_quest)
    return new_quest

func generate_new_rumor() -> QuestRumor:
    var quest_generator = QuestGenerator.new(game_state)
    var new_quest = generate_new_quest()
    var new_rumor = quest_generator.generate_quest_rumor(new_quest)
    active_rumors.append(new_rumor)
    return new_rumor

func update_rumors(current_turn: int) -> void:
    for rumor in active_rumors:
        if rumor.is_expired(current_turn):
            active_rumors.erase(rumor)

func discover_rumor(rumor: QuestRumor) -> void:
    rumor.discover()
    if rumor.associated_quest not in active_quests:
        active_quests.append(rumor.associated_quest)

func add_mission_followup_quest(mission: Mission) -> Quest:
    var mission_generator = MissionGenerator.new()
    var new_quest = mission_generator.mission_to_quest(mission)
    active_quests.append(new_quest)
    return new_quest

func update_quests() -> void:
    for quest in active_quests:
        if _check_quest_requirements(quest):
            _advance_quest_stage(quest)

func _check_quest_requirements(quest: Quest) -> bool:
    for requirement in quest.current_requirements:
        if not _is_requirement_met(requirement, quest):
            return false
    return true

func _is_requirement_met(_requirement: String, _quest: Quest) -> bool:
    # This function would check if the requirement is met based on the game state
    # For now, we'll use a placeholder implementation
    return randf() > 0.5

func _advance_quest_stage(quest: Quest) -> void:
    quest.current_stage += 1
    if quest.current_stage > quest_stages["quest_stages"].size():
        _complete_quest(quest)
    else:
        var stage_data = quest_stages["quest_stages"][quest.current_stage - 1]
        quest.current_requirements = stage_data["requirements"]
        _apply_stage_rewards(quest, stage_data["rewards"])

func _complete_quest(quest: Quest) -> void:
    quest.complete()
    active_quests.erase(quest)
    game_state.completed_quests.append(quest)
    _apply_final_rewards(quest)

func _apply_stage_rewards(_quest: Quest, rewards: Dictionary) -> void:
    if "credits" in rewards:
        var credits = _roll_dice(rewards["credits"])
        game_state.credits += credits
    if "story_points" in rewards:
        game_state.story_points += rewards["story_points"]
    if "gear" in rewards:
        var new_gear = _generate_gear(rewards["gear"])
        game_state.add_item(new_gear)

func _apply_final_rewards(quest: Quest) -> void:
    game_state.credits += quest.reward["credits"]
    game_state.reputation += quest.reward["reputation"]
    if "item" in quest.reward:
        game_state.add_item(quest.reward["item"])

func _roll_dice(dice_string: String) -> int:
    var parts = dice_string.split("D")
    var num_dice = int(parts[0])
    var dice_size = int(parts[1].split(" x ")[0])
    var multiplier = int(parts[1].split(" x ")[1])
    var total = 0
    for i in range(num_dice):
        total += randi() % dice_size + 1
    return total * multiplier

func _generate_gear(gear_type: String) -> Equipment:
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
    var roll = randi() % 100 + 1
    if roll <= 60:
        return 0  # Common
    elif roll <= 85:
        return 1  # Uncommon
    elif roll <= 95:
        return 2  # Rare
    else:
        return 3  # Legendary

func _determine_gear_quality() -> int:
    var roll = randi() % 100 + 1
    if roll <= 10:
        return 0  # Poor
    elif roll <= 70:
        return 1  # Standard
    elif roll <= 90:
        return 2  # Good
    else:
        return 3  # Excellent

func _calculate_base_value(gear_type: String, rarity: int, quality: int) -> int:
    var base_value = 100  # Default base value
   
    # Adjust base value based on gear type
    match gear_type:
        "weapon":
            base_value = 200
        "armor":
            base_value = 150
        "gadget":
            base_value = 100
   
    # Apply rarity multiplier
    var rarity_multiplier = 1.0
    match rarity:
        1:  # Uncommon
            rarity_multiplier = 1.5
        2:  # Rare
            rarity_multiplier = 2.5
        3:  # Legendary
            rarity_multiplier = 5.0
   
    base_value *= rarity_multiplier
   
    # Apply quality modifier
    match quality:
        0:  # Poor
            base_value *= 0.7
        2:  # Good
            base_value *= 1.3
        3:  # Excellent
            base_value *= 1.8

    return int(base_value)

func _generate_modifiers(gear_type: String, rarity: int) -> Array:
    var modifiers = []
    var num_modifiers = 1 if rarity > 0 else 0
   
    if rarity >= 2:  # Rare or Legendary
        num_modifiers += 1
   
    for _i in range(num_modifiers):
        var modifier = _get_random_modifier(gear_type)
        modifiers.append(modifier)
   
    return modifiers

func _get_random_modifier(gear_type: String) -> String:
    var possible_modifiers = []
   
    match gear_type:
        "weapon":
            possible_modifiers = ["damage_boost", "accuracy_boost", "critical_chance"]
        "armor":
            possible_modifiers = ["defense_boost", "damage_reduction", "stealth_boost"]
        "gadget":
            possible_modifiers = ["utility_boost", "recharge_rate", "range_increase"]

    return possible_modifiers[randi() % possible_modifiers.size()]

func get_active_quests() -> Array[Quest]:
    return active_quests

func get_quest_stage_description(quest: Quest) -> String:
    return quest_stages["quest_stages"][quest.current_stage - 1]["description"]

func fail_quest(quest: Quest) -> void:
    quest.fail()
    active_quests.erase(quest)

func add_psionic_quest() -> Quest:
    var psionic_quest = generate_new_quest()
    psionic_quest.quest_type = "PSIONIC"
    psionic_quest.objective = "Master a new psionic ability"
    return psionic_quest

func update_quest_for_new_location(new_location: Location) -> void:
    for quest in active_quests:
        if quest.location != new_location:
            quest.location = new_location
            quest.objective = _generate_new_objective_for_location(quest, new_location)

func _generate_new_objective_for_location(quest: Quest, _location: Location) -> String:
    var quest_generator = QuestGenerator.new(game_state)
    var quest_type = QuestGenerator.QuestType[quest.quest_type]
    return quest_generator.generate_objective(quest_type)

func get_quest_summary(quest: Quest) -> String:
    var summary = "Quest: {type}\n".format({"type": quest.quest_type})
    summary += "Location: {location}\n".format({"location": quest.location.name})
    summary += "Objective: {objective}\n".format({"objective": quest.objective})
    summary += "Current Stage: {stage}\n".format({"stage": quest.current_stage})
    summary += "Stage Description: {description}\n".format({"description": get_quest_stage_description(quest)})
    summary += "Requirements:\n"
    for requirement in quest.current_requirements:
        summary += "- {req}\n".format({"req": requirement})
    return summary

func serialize_quests_and_rumors() -> Dictionary:
    var serialized_data = {
        "quests": serialize_quests(),
        "rumors": serialize_rumors()
    }
    return serialized_data

func deserialize_quests_and_rumors(data: Dictionary) -> void:
    deserialize_quests(data["quests"])
    deserialize_rumors(data["rumors"])

func serialize_quests() -> Array:
    var serialized_quests = []
    for quest in active_quests:
        serialized_quests.append(quest.serialize())
    return serialized_quests

func deserialize_quests(data: Array) -> void:
    active_quests.clear()
    for quest_data in data:
        var quest = Quest.deserialize(quest_data)
        active_quests.append(quest)

func serialize_rumors() -> Array:
    var serialized_rumors = []
    for rumor in active_rumors:
        serialized_rumors.append(rumor.serialize())
    return serialized_rumors

func deserialize_rumors(data: Array) -> void:
    active_rumors.clear()
    for rumor_data in data:
        var rumor = QuestRumor.deserialize(rumor_data)
        active_rumors.append(rumor)
