class_name CrewTaskManagerSystem
extends Resource

signal task_assigned(crew_member: Character, task: GlobalEnums.CrewTask)
signal task_completed(crew_member: Character, task: GlobalEnums.CrewTask, result: Dictionary)
signal task_failed(crew_member: Character, task: GlobalEnums.CrewTask, reason: String)

var game_state: GameState
var active_tasks: Dictionary = {}  # crew_member_id -> task
var task_results: Dictionary = {}  # task_id -> result

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func assign_task(crew_member: Character, task: GlobalEnums.CrewTask) -> bool:
    if not can_assign_task(crew_member, task):
        return false
    
    # Remove any existing task
    if crew_member.id in active_tasks:
        cancel_task(crew_member)
    
    active_tasks[crew_member.id] = task
    crew_member.current_task = task
    task_assigned.emit(crew_member, task)
    return true

func cancel_task(crew_member: Character) -> void:
    if crew_member.id in active_tasks:
        var task = active_tasks[crew_member.id]
        active_tasks.erase(crew_member.id)
        crew_member.current_task = null
        task_failed.emit(crew_member, task, "Task cancelled")

func execute_task(crew_member: Character, task: GlobalEnums.CrewTask) -> Dictionary:
    if not can_execute_task(crew_member, task):
        task_failed.emit(crew_member, task, "Cannot execute task")
        return {"success": false, "reason": "Cannot execute task"}
    
    var result = _process_task(crew_member, task)
    
    if result.success:
        task_completed.emit(crew_member, task, result)
    else:
        task_failed.emit(crew_member, task, result.reason)
    
    task_results[task] = result
    return result

func can_assign_task(crew_member: Character, task: GlobalEnums.CrewTask) -> bool:
    # Check if crew member is available
    if crew_member.is_injured or crew_member.is_exhausted:
        return false
    
    # Check if crew member has required skills
    if not _has_required_skills(crew_member, task):
        return false
    
    # Check if task requirements are met
    if not _check_task_requirements(task):
        return false
    
    return true

func can_execute_task(crew_member: Character, task: GlobalEnums.CrewTask) -> bool:
    # Check if task is assigned to this crew member
    if crew_member.id not in active_tasks or active_tasks[crew_member.id] != task:
        return false
    
    # Check if crew member is still capable
    return can_assign_task(crew_member, task)

func get_available_tasks(crew_member: Character) -> Array[GlobalEnums.CrewTask]:
    var available_tasks: Array[GlobalEnums.CrewTask] = []
    
    # Get tasks based on location
    if game_state.current_world:
        available_tasks.append_array(_get_world_tasks())
    
    # Get ship-based tasks
    if game_state.ship:
        available_tasks.append_array(_get_ship_tasks())
    
    # Filter tasks based on crew member's capabilities
    return available_tasks.filter(func(task): return can_assign_task(crew_member, task))

func get_task_progress(crew_member: Character) -> float:
    if crew_member.id not in active_tasks:
        return 0.0
    
    var task = active_tasks[crew_member.id]
    return task.get("progress", 0.0)

func get_task_result(task: GlobalEnums.CrewTask) -> Dictionary:
    return task_results.get(task, {})

# Helper Functions
func _has_required_skills(crew_member: Character, task: GlobalEnums.CrewTask) -> bool:
    match task:
        GlobalEnums.CrewTask.TRADE:
            return crew_member.get_skill_level("negotiation") >= 1
        GlobalEnums.CrewTask.EXPLORE:
            return crew_member.get_skill_level("survival") >= 1
        GlobalEnums.CrewTask.TRAIN:
            return true  # Anyone can train
        GlobalEnums.CrewTask.RECRUIT:
            return crew_member.get_skill_level("leadership") >= 1
        GlobalEnums.CrewTask.FIND_PATRON:
            return crew_member.get_skill_level("negotiation") >= 2
        GlobalEnums.CrewTask.REPAIR_KIT:
            return crew_member.get_skill_level("tech") >= 1
        GlobalEnums.CrewTask.DECOY:
            return crew_member.get_skill_level("stealth") >= 1
        GlobalEnums.CrewTask.REST:
            return true  # Anyone can rest
        _:
            return false

func _check_task_requirements(task: GlobalEnums.CrewTask) -> bool:
    match task:
        GlobalEnums.CrewTask.TRADE:
            return game_state.current_world != null and game_state.current_world.has_marketplace()
        GlobalEnums.CrewTask.EXPLORE:
            return game_state.current_world != null
        GlobalEnums.CrewTask.TRAIN:
            return game_state.has_training_facilities()
        GlobalEnums.CrewTask.RECRUIT:
            return game_state.current_world != null and game_state.current_world.has_recruitment_center()
        GlobalEnums.CrewTask.FIND_PATRON:
            return game_state.current_world != null and game_state.current_world.has_patrons()
        GlobalEnums.CrewTask.REPAIR_KIT:
            return game_state.has_repair_facilities()
        GlobalEnums.CrewTask.DECOY:
            return true  # Can be done anywhere
        GlobalEnums.CrewTask.REST:
            return true  # Can be done anywhere
        _:
            return false

func _process_task(crew_member: Character, task: GlobalEnums.CrewTask) -> Dictionary:
    var result = {
        "success": false,
        "reason": "",
        "rewards": {},
        "consequences": {}
    }
    
    # Calculate base success chance
    var success_chance = _calculate_success_chance(crew_member, task)
    
    # Roll for success
    if randf() <= success_chance:
        result.success = true
        result.rewards = _generate_task_rewards(task)
        _apply_task_rewards(crew_member, result.rewards)
    else:
        result.success = false
        result.reason = "Failed skill check"
        result.consequences = _generate_task_consequences(task)
        _apply_task_consequences(crew_member, result.consequences)
    
    # Apply experience regardless of success
    _apply_task_experience(crew_member, task)
    
    return result

func _calculate_success_chance(crew_member: Character, task: GlobalEnums.CrewTask) -> float:
    var base_chance = 0.5
    
    # Modify based on relevant skill
    var skill_level: int
    match task:
        GlobalEnums.CrewTask.TRADE:
            skill_level = crew_member.get_skill_level("negotiation")
        GlobalEnums.CrewTask.EXPLORE:
            skill_level = crew_member.get_skill_level("survival")
        GlobalEnums.CrewTask.TRAIN:
            skill_level = crew_member.get_skill_level("learning")
        GlobalEnums.CrewTask.RECRUIT:
            skill_level = crew_member.get_skill_level("leadership")
        GlobalEnums.CrewTask.FIND_PATRON:
            skill_level = crew_member.get_skill_level("negotiation")
        GlobalEnums.CrewTask.REPAIR_KIT:
            skill_level = crew_member.get_skill_level("tech")
        GlobalEnums.CrewTask.DECOY:
            skill_level = crew_member.get_skill_level("stealth")
        GlobalEnums.CrewTask.REST:
            skill_level = 5  # Always high chance of successful rest
        _:
            skill_level = 0
    
    base_chance += skill_level * 0.1
    
    # Modify based on conditions
    if crew_member.is_tired:
        base_chance *= 0.8
    
    return clamp(base_chance, 0.1, 0.9)  # Always leave some chance of failure/success

func _get_world_tasks() -> Array[GlobalEnums.CrewTask]:
    var tasks: Array[GlobalEnums.CrewTask] = []
    
    if game_state.current_world:
        if game_state.current_world.has_marketplace():
            tasks.append(GlobalEnums.CrewTask.TRADE)
        tasks.append(GlobalEnums.CrewTask.EXPLORE)
        if game_state.current_world.has_recruitment_center():
            tasks.append(GlobalEnums.CrewTask.RECRUIT)
        if game_state.current_world.has_patrons():
            tasks.append(GlobalEnums.CrewTask.FIND_PATRON)
    
    return tasks

func _get_ship_tasks() -> Array[GlobalEnums.CrewTask]:
    var tasks: Array[GlobalEnums.CrewTask] = []
    
    tasks.append(GlobalEnums.CrewTask.REST)  # Always available
    
    if game_state.ship:
        if game_state.ship.has_training_room:
            tasks.append(GlobalEnums.CrewTask.TRAIN)
        if game_state.ship.has_repair_bay:
            tasks.append(GlobalEnums.CrewTask.REPAIR_KIT)
    
    return tasks

func _generate_task_rewards(task: GlobalEnums.CrewTask) -> Dictionary:
    var rewards = {
        "credits": 0,
        "experience": 0,
        "skill_progress": {},
        "items": []
    }
    
    match task:
        GlobalEnums.CrewTask.TRADE:
            rewards.credits = 100 + randi() % 100
            rewards.skill_progress["negotiation"] = 10
        GlobalEnums.CrewTask.EXPLORE:
            rewards.credits = 50 + randi() % 50
            rewards.skill_progress["survival"] = 10
        GlobalEnums.CrewTask.TRAIN:
            rewards.experience = 50
            rewards.skill_progress["learning"] = 15
        GlobalEnums.CrewTask.RECRUIT:
            rewards.experience = 30
            rewards.skill_progress["leadership"] = 10
        GlobalEnums.CrewTask.FIND_PATRON:
            rewards.credits = 200 + randi() % 200
            rewards.skill_progress["negotiation"] = 15
        GlobalEnums.CrewTask.REPAIR_KIT:
            rewards.credits = 75 + randi() % 75
            rewards.skill_progress["tech"] = 10
        GlobalEnums.CrewTask.DECOY:
            rewards.credits = 150 + randi() % 150
            rewards.skill_progress["stealth"] = 10
        GlobalEnums.CrewTask.REST:
            rewards.experience = 10
    
    return rewards

func _generate_task_consequences(task: GlobalEnums.CrewTask) -> Dictionary:
    var consequences = {
        "fatigue": 0,
        "injury": false,
        "morale": 0,
        "equipment_damage": []
    }
    
    match task:
        GlobalEnums.CrewTask.TRADE:
            consequences.fatigue = 1
            consequences.morale = -1
        GlobalEnums.CrewTask.EXPLORE:
            consequences.fatigue = 2
            consequences.injury = randf() < 0.2  # 20% chance of injury
        GlobalEnums.CrewTask.TRAIN:
            consequences.fatigue = 2
        GlobalEnums.CrewTask.RECRUIT:
            consequences.fatigue = 1
        GlobalEnums.CrewTask.FIND_PATRON:
            consequences.morale = -2
        GlobalEnums.CrewTask.REPAIR_KIT:
            consequences.fatigue = 1
            consequences.equipment_damage = ["tools"]
        GlobalEnums.CrewTask.DECOY:
            consequences.fatigue = 2
            consequences.injury = randf() < 0.3  # 30% chance of injury
        GlobalEnums.CrewTask.REST:
            consequences.fatigue = -2  # Reduces fatigue
            consequences.morale = 1
    
    return consequences

func _apply_task_rewards(crew_member: Character, rewards: Dictionary) -> void:
    if rewards.credits > 0:
        game_state.add_credits(rewards.credits)
    
    if rewards.experience > 0:
        crew_member.add_experience(rewards.experience)
    
    for skill in rewards.skill_progress:
        crew_member.add_skill_progress(skill, rewards.skill_progress[skill])
    
    for item in rewards.items:
        game_state.inventory.add_item(item)

func _apply_task_consequences(crew_member: Character, consequences: Dictionary) -> void:
    if consequences.fatigue != 0:
        crew_member.add_fatigue(consequences.fatigue)
    
    if consequences.injury:
        crew_member.apply_injury("minor")  # Default to minor injury
    
    if consequences.morale != 0:
        crew_member.adjust_morale(consequences.morale)
    
    for equipment in consequences.equipment_damage:
        game_state.damage_equipment(equipment)

func _apply_task_experience(crew_member: Character, task: GlobalEnums.CrewTask) -> void:
    # Base experience for attempting the task
    var base_xp = 10
    
    # Additional experience based on task difficulty
    match task:
        GlobalEnums.CrewTask.TRADE, GlobalEnums.CrewTask.EXPLORE:
            base_xp += 15
        GlobalEnums.CrewTask.TRAIN, GlobalEnums.CrewTask.RECRUIT:
            base_xp += 10
        GlobalEnums.CrewTask.FIND_PATRON, GlobalEnums.CrewTask.REPAIR_KIT:
            base_xp += 20
        GlobalEnums.CrewTask.DECOY:
            base_xp += 25
        GlobalEnums.CrewTask.REST:
            base_xp += 5
    
    crew_member.add_experience(base_xp) 