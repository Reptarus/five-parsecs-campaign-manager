class_name TrainingManager
extends Resource

signal training_started(crew_member: Dictionary, skill: String)
signal training_completed(crew_member: Dictionary, skill: String)
signal training_failed(crew_member: Dictionary, skill: String, reason: String)
signal skill_improved(crew_member: Dictionary, skill: String, new_level: int)

var game_state: GameState
var active_training: Dictionary = {}  # crew_id -> training_data
var training_history: Array = []
var skill_requirements: Dictionary = {}

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    _initialize_skill_requirements()

func start_training(crew_member: Dictionary, skill: String) -> bool:
    if not _can_start_training(crew_member, skill):
        return false
    
    var training_data = _create_training_data(crew_member, skill)
    active_training[crew_member.id] = training_data
    
    training_started.emit(crew_member, skill)
    return true

func update_training() -> void:
    var completed_training = []
    
    for crew_id in active_training:
        var training = active_training[crew_id]
        var progress = _update_training_progress(training)
        
        if progress >= 1.0:
            _complete_training(training)
            completed_training.append(crew_id)
    
    for crew_id in completed_training:
        active_training.erase(crew_id)

func cancel_training(crew_member: Dictionary) -> void:
    if not crew_member.id in active_training:
        return
    
    var training = active_training[crew_member.id]
    training_failed.emit(crew_member, training.skill, "Training cancelled")
    active_training.erase(crew_member.id)

func get_training_progress(crew_member: Dictionary) -> float:
    if not crew_member.id in active_training:
        return 0.0
    
    return active_training[crew_member.id].progress

func get_available_skills(crew_member: Dictionary) -> Array:
    var available = []
    
    for skill in skill_requirements:
        if _meets_skill_requirements(crew_member, skill):
            available.append(skill)
    
    return available

func get_skill_cost(crew_member: Dictionary, skill: String) -> int:
    var base_cost = skill_requirements.get(skill, {}).get("base_cost", 100)
    var current_level = crew_member.get("skills", {}).get(skill, 0)
    
    return int(base_cost * pow(1.5, current_level))

func get_training_time(crew_member: Dictionary, skill: String) -> int:
    var base_time = skill_requirements.get(skill, {}).get("base_time", 3600)  # 1 hour in seconds
    var current_level = crew_member.get("skills", {}).get(skill, 0)
    
    return int(base_time * pow(1.2, current_level))

func get_active_training() -> Array:
    var training_list = []
    for crew_id in active_training:
        training_list.append(active_training[crew_id])
    return training_list

# Helper Functions
func _initialize_skill_requirements() -> void:
    skill_requirements = {
        "combat": {
            "base_cost": 100,
            "base_time": 3600,
            "prerequisites": [],
            "max_level": 5
        },
        "piloting": {
            "base_cost": 150,
            "base_time": 4800,
            "prerequisites": [],
            "max_level": 5
        },
        "engineering": {
            "base_cost": 200,
            "base_time": 7200,
            "prerequisites": ["technical"],
            "max_level": 5
        },
        "technical": {
            "base_cost": 100,
            "base_time": 3600,
            "prerequisites": [],
            "max_level": 5
        },
        "medical": {
            "base_cost": 200,
            "base_time": 7200,
            "prerequisites": ["science"],
            "max_level": 5
        },
        "science": {
            "base_cost": 150,
            "base_time": 4800,
            "prerequisites": [],
            "max_level": 5
        },
        "negotiation": {
            "base_cost": 100,
            "base_time": 3600,
            "prerequisites": [],
            "max_level": 5
        },
        "leadership": {
            "base_cost": 250,
            "base_time": 9600,
            "prerequisites": ["negotiation"],
            "max_level": 5
        },
        "stealth": {
            "base_cost": 150,
            "base_time": 4800,
            "prerequisites": [],
            "max_level": 5
        },
        "survival": {
            "base_cost": 100,
            "base_time": 3600,
            "prerequisites": [],
            "max_level": 5
        }
    }

func _can_start_training(crew_member: Dictionary, skill: String) -> bool:
    # Check if already training
    if crew_member.id in active_training:
        return false
    
    # Check if skill exists
    if not skill in skill_requirements:
        return false
    
    # Check prerequisites
    if not _meets_skill_requirements(crew_member, skill):
        return false
    
    # Check if at max level
    var current_level = crew_member.get("skills", {}).get(skill, 0)
    var max_level = skill_requirements[skill].max_level
    if current_level >= max_level:
        return false
    
    # Check if can afford training
    var cost = get_skill_cost(crew_member, skill)
    if not game_state.can_afford(cost):
        return false
    
    return true

func _meets_skill_requirements(crew_member: Dictionary, skill: String) -> bool:
    var requirements = skill_requirements.get(skill, {}).get("prerequisites", [])
    
    for required_skill in requirements:
        var required_level = 1  # Base requirement level
        var current_level = crew_member.get("skills", {}).get(required_skill, 0)
        if current_level < required_level:
            return false
    
    return true

func _create_training_data(crew_member: Dictionary, skill: String) -> Dictionary:
    var cost = get_skill_cost(crew_member, skill)
    game_state.spend_credits(cost)
    
    return {
        "crew_id": crew_member.id,
        "crew_member": crew_member,
        "skill": skill,
        "start_time": Time.get_unix_time_from_system(),
        "duration": get_training_time(crew_member, skill),
        "progress": 0.0,
        "cost": cost
    }

func _update_training_progress(training: Dictionary) -> float:
    var elapsed_time = Time.get_unix_time_from_system() - training.start_time
    training.progress = float(elapsed_time) / training.duration
    
    return training.progress

func _complete_training(training: Dictionary) -> void:
    var crew_member = training.crew_member
    var skill = training.skill
    
    # Update skill level
    var current_level = crew_member.get("skills", {}).get(skill, 0)
    var new_level = current_level + 1
    
    if not "skills" in crew_member:
        crew_member["skills"] = {}
    crew_member.skills[skill] = new_level
    
    # Record training
    training_history.append({
        "crew_id": crew_member.id,
        "skill": skill,
        "old_level": current_level,
        "new_level": new_level,
        "completion_time": Time.get_unix_time_from_system()
    })
    
    # Emit signals
    training_completed.emit(crew_member, skill)
    skill_improved.emit(crew_member, skill, new_level) 