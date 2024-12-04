class_name CrewSystem
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal crew_updated
signal member_added(character: Character)
signal member_removed(character: Character)
signal task_assigned(character: Character, task: GlobalEnums.CrewTask)
signal task_completed(character: Character, task: GlobalEnums.CrewTask)

const MAX_CREW_SIZE := 8
const MIN_CREW_SIZE := 3

var game_state: GameState
var active_tasks: Dictionary = {} # Character: GlobalEnums.CrewTask
var members: Array[Character] = []

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func add_member(character: Character) -> bool:
    if members.size() >= MAX_CREW_SIZE:
        return false
    members.append(character)
    member_added.emit(character)
    crew_updated.emit()
    return true

func remove_member(character: Character) -> bool:
    if members.size() <= MIN_CREW_SIZE:
        return false
    var index = members.find(character)
    if index != -1:
        members.remove_at(index)
        if active_tasks.has(character):
            active_tasks.erase(character)
        member_removed.emit(character)
        crew_updated.emit()
        return true
    return false

func assign_task(character: Character, task: GlobalEnums.CrewTask) -> bool:
    if not character in members or active_tasks.has(character):
        return false
    active_tasks[character] = task
    task_assigned.emit(character, task)
    return true

func complete_task(character: Character) -> void:
    if not active_tasks.has(character):
        return
    var completed_task = active_tasks[character]
    active_tasks.erase(character)
    task_completed.emit(character, completed_task)

func get_available_members() -> Array[Character]:
    return members.filter(func(member: Character) -> bool: 
        return not active_tasks.has(member))

func get_task_description(task: int) -> String:
    match task:
        GlobalEnums.CrewTask.TRADE: 
            return "Search for profitable trade opportunities"
        GlobalEnums.CrewTask.EXPLORE: 
            return "Scout the local area for opportunities"
        GlobalEnums.CrewTask.TRAIN: 
            return "Improve skills through training"
        GlobalEnums.CrewTask.RECRUIT: 
            return "Search for potential crew members"
        GlobalEnums.CrewTask.FIND_PATRON: 
            return "Look for work opportunities"
        GlobalEnums.CrewTask.REPAIR_KIT: 
            return "Repair and maintain equipment"
        GlobalEnums.CrewTask.DECOY: 
            return "Create a diversion"
        GlobalEnums.CrewTask.REST: 
            return "Recover from injuries or stress"
        _: 
            return "Unknown task"

func process_task_results() -> void:
    for character in active_tasks:
        var task = active_tasks[character]
        var result = _generate_task_result(character, task)
        _apply_task_result(character, task, result)

func _generate_task_result(character: Character, task: GlobalEnums.CrewTask) -> Dictionary:
    var success = randf() < _calculate_success_chance(character, task)
    var rewards = {}
    var consequences = {}

    if success:
        rewards = _generate_task_rewards(task)
    else:
        consequences = _generate_task_consequences(task)

    return {
        "success": success,
        "rewards": rewards,
        "consequences": consequences
    }

func _calculate_success_chance(character: Character, task: GlobalEnums.CrewTask) -> float:
    var base_chance = 0.5
    
    # Add skill bonuses
    match task:
        GlobalEnums.CrewTask.TRADE:
            base_chance += character.stats.get_stat(GlobalEnums.CharacterStats.TECHNICAL) * 0.1
        GlobalEnums.CrewTask.EXPLORE:
            base_chance += character.stats.get_stat(GlobalEnums.CharacterStats.SURVIVAL) * 0.1
        GlobalEnums.CrewTask.TRAIN:
            base_chance += character.stats.get_stat(GlobalEnums.CharacterStats.INTELLIGENCE) * 0.1
        GlobalEnums.CrewTask.REPAIR_KIT:
            base_chance += character.stats.get_stat(GlobalEnums.CharacterStats.TECHNICAL) * 0.1
        GlobalEnums.CrewTask.DECOY:
            base_chance += character.stats.get_stat(GlobalEnums.CharacterStats.COMBAT_SKILL) * 0.1
        GlobalEnums.CrewTask.REST:
            base_chance += character.stats.get_stat(GlobalEnums.CharacterStats.AGILITY) * 0.1
            
    return clampf(base_chance, 0.1, 0.9)

func _generate_task_rewards(task: GlobalEnums.CrewTask) -> Dictionary:
    var rewards = {}
    match task:
        GlobalEnums.CrewTask.TRADE:
            rewards["credits"] = randi_range(50, 200)
        GlobalEnums.CrewTask.EXPLORE:
            rewards["story_points"] = 1
        GlobalEnums.CrewTask.TRAIN:
            rewards["experience"] = randi_range(10, 30)
        GlobalEnums.CrewTask.REPAIR_KIT:
            rewards["repaired_items"] = randi_range(1, 3)
        GlobalEnums.CrewTask.DECOY:
            rewards["credits"] = randi_range(30, 100)
    return rewards

func _generate_task_consequences(task: GlobalEnums.CrewTask) -> Dictionary:
    var consequences = {}
    match task:
        GlobalEnums.CrewTask.TRADE:
            consequences["credits_lost"] = randi_range(10, 50)
        GlobalEnums.CrewTask.EXPLORE:
            consequences["injury_chance"] = 0.2
        GlobalEnums.CrewTask.TRAIN:
            consequences["fatigue"] = 1
    return consequences

func _apply_task_result(character: Character, task: GlobalEnums.CrewTask, result: Dictionary) -> void:
    if result.success:
        for reward_type in result.rewards:
            match reward_type:
                "credits":
                    game_state.add_credits(result.rewards[reward_type])
                "story_points":
                    game_state.add_story_points(result.rewards[reward_type])
                "experience":
                    character.add_experience(result.rewards[reward_type])
    else:
        for consequence_type in result.consequences:
            match consequence_type:
                "credits_lost":
                    game_state.remove_credits(result.consequences[consequence_type])
                "injury_chance":
                    if randf() < result.consequences[consequence_type]:
                        character.status = GlobalEnums.CharacterStatus.INJURED
                "fatigue":
                    character.add_fatigue(result.consequences[consequence_type]) 