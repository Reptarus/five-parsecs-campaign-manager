class_name BattleStateTracker
extends Node

signal state_saved(checkpoint_data: Dictionary)
signal state_loaded(checkpoint_data: Dictionary)
signal validation_failed(reason: String)

const MAX_CHECKPOINTS := 3

var current_battle_state: Dictionary = {}
var checkpoints: Array[Dictionary] = []
var initial_state: Dictionary

# Add this class to handle character data validation
class CharacterState:
    var equipment_slots: Array[String]
    var skills: Array[String]
    var tutorial_progress: Dictionary
    
    func get_equipped_items() -> Array[String]:
        return equipment_slots
        
    func has_basic_skills() -> bool:
        var required_skills = ["move", "attack", "defend"]
        for skill in required_skills:
            if not skill in skills:
                return false
        return true
        
    func is_tutorial_completed() -> bool:
        return tutorial_progress.get("completed", false)

func initialize_battle_state(mission: Mission, battlefield_data: Dictionary) -> void:
    initial_state = {
        "mission": mission.serialize(),
        "battlefield": battlefield_data,
        "turn": 0,
        "units": {
            "player": _serialize_units(mission.player_units),
            "enemy": _serialize_units(mission.enemy_units)
        },
        "objectives": _serialize_objectives(mission.objectives),
        "resources": {
            "ammo": {},
            "items": {},
            "special_abilities": {}
        }
    }
    current_battle_state = initial_state.duplicate(true)

func save_checkpoint() -> void:
    var checkpoint = {
        "turn": current_battle_state.turn,
        "timestamp": Time.get_unix_time_from_system(),
        "units": {
            "player": _get_unit_states(current_battle_state.units.player),
            "enemy": _get_unit_states(current_battle_state.units.enemy)
        },
        "objectives": _get_objective_states(current_battle_state.objectives),
        "resources": current_battle_state.resources.duplicate(true)
    }
    
    if _validate_checkpoint(checkpoint):
        checkpoints.append(checkpoint)
        if checkpoints.size() > MAX_CHECKPOINTS:
            checkpoints.pop_front()
        state_saved.emit(checkpoint)
    else:
        validation_failed.emit("Invalid checkpoint state")

func load_checkpoint(index: int = -1) -> bool:
    if checkpoints.is_empty():
        return false
        
    var checkpoint = checkpoints[index if index >= 0 else checkpoints.size() - 1]
    if _validate_checkpoint(checkpoint):
        current_battle_state.turn = checkpoint.turn
        current_battle_state.units = checkpoint.units.duplicate(true)
        current_battle_state.objectives = checkpoint.objectives.duplicate(true)
        current_battle_state.resources = checkpoint.resources.duplicate(true)
        state_loaded.emit(checkpoint)
        return true
    return false

func _validate_checkpoint(checkpoint: Dictionary) -> bool:
    if not _validate_story_progress(checkpoint):
        return false
    
    return true

func _validate_story_progress(checkpoint: Dictionary) -> bool:
    if not current_battle_state.has("story_elements"):
        return true
        
    var story_elements = current_battle_state.story_elements
    
    # Validate story objectives
    for objective in story_elements.objectives:
        if objective.required and not objective.completed:
            var checkpoint_objective = checkpoint.objectives.find(
                func(obj): return obj.id == objective.id
            )
            if not checkpoint_objective or not checkpoint_objective.completed:
                return false
    
    # Validate story choices
    if story_elements.has("pending_choice") and story_elements.pending_choice:
        return false
    
    # Validate tutorial character progression
    if story_elements.has("tutorial_character"):
        var character_state = CharacterState.new()
        character_state.equipment_slots = story_elements.tutorial_character.equipment_slots
        character_state.skills = story_elements.tutorial_character.skills
        character_state.tutorial_progress = story_elements.tutorial_character.tutorial_progress
        
        if not _validate_tutorial_character_progress(character_state):
            return false
    
    return true

func _validate_tutorial_character_progress(character: CharacterState) -> bool:
    # Check if character has met minimum requirements for story progression
    var required_stats = {
        "combat_experience": 2,
        "missions_completed": 1,
        "skill_points_spent": 1
    }
    
    # Check if character has completed necessary tutorial objectives
    var required_objectives = ["basic_combat", "skill_usage", "equipment_management"]
    
    # Check equipment slots
    if character.get_equipped_items().size() < 2:
        return false
        
    # Check basic skills
    if not character.has_basic_skills():
        return false
        
    # Check tutorial completion
    if not character.is_tutorial_completed():
        return false
    
    return true

func validate_story_transition(character: Dictionary) -> bool:
    # Check if character is ready to transition from tutorial to main campaign
    var requirements = {
        "minimum_level": 2,
        "equipment_slots_filled": 2,
        "basic_skills_learned": true,
        "tutorial_completed": true
    }
    
    if character.level < requirements.minimum_level:
        return false
        
    if character.get("equipped_items", []).size() < requirements.equipment_slots_filled:
        return false
        
    if not character.get("basic_skills", false):
        return false
        
    if not character.tutorial_progress.is_completed():
        return false
    
    return true

func _validate_objective_progress(objectives: Array) -> bool:
    var initial_objectives = initial_state.objectives
    for i in range(objectives.size()):
        var current = objectives[i]
        var initial = initial_objectives[i]
        
        # Ensure progress doesn't exceed maximum
        if current.progress > current.max_progress:
            return false
            
        # Ensure completed objectives stay completed
        if initial.completed and not current.completed:
            return false
    
    return true

func _validate_resources(resources: Dictionary) -> bool:
    var initial_resources = initial_state.resources
    
    # Check ammo consumption
    for weapon_id in resources.ammo:
        if resources.ammo[weapon_id] > initial_resources.ammo.get(weapon_id, 0):
            return false
    
    # Check item usage
    for item_id in resources.items:
        if resources.items[item_id] > initial_resources.items.get(item_id, 0):
            return false
    
    # Check special ability usage
    for ability_id in resources.special_abilities:
        if resources.special_abilities[ability_id] > initial_resources.special_abilities.get(ability_id, 0):
            return false
    
    return true

func _serialize_units(units: Array) -> Array:
    var serialized = []
    for unit in units:
        serialized.append({
            "id": unit.id,
            "position": unit.position,
            "health": unit.health,
            "status": unit.status,
            "ammo": unit.get_ammo_counts(),
            "items": unit.get_item_counts(),
            "abilities": unit.get_ability_charges()
        })
    return serialized

func _serialize_objectives(objectives: Array) -> Array:
    var serialized = []
    for objective in objectives:
        serialized.append({
            "id": objective.id,
            "type": objective.type,
            "progress": 0,
            "max_progress": objective.required_progress,
            "completed": false,
            "position": objective.position if objective.has("position") else null
        })
    return serialized

func _get_unit_states(units: Array) -> Array:
    var states = []
    for unit in units:
        if unit.status != GlobalEnums.CharacterStatus.DEAD:
            states.append({
                "id": unit.id,
                "position": unit.position,
                "health": unit.health,
                "status": unit.status,
                "ammo": unit.get_ammo_counts(),
                "items": unit.get_item_counts(),
                "abilities": unit.get_ability_charges()
            })
    return states

func _get_objective_states(objectives: Array) -> Array:
    var states = []
    for objective in objectives:
        states.append({
            "id": objective.id,
            "progress": objective.progress,
            "completed": objective.completed,
            "position": objective.position if objective.has("position") else null
        })
    return states

func _count_active_units(units: Array) -> int:
    return units.filter(func(u): return u.status != GlobalEnums.CharacterStatus.DEAD).size() 