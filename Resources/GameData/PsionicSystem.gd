class_name PsionicSystem
extends Resource

signal psionic_detected(character, ability: Dictionary)
signal psionic_manifested(character, ability: Dictionary)
signal psionic_failed(character, ability: Dictionary, reason: String)
signal illegal_usage_detected(character, ability: Dictionary)

var game_state: GameState
var active_psionics: Dictionary = {}  # character_id -> Array[Dictionary]
var psionic_cooldowns: Dictionary = {}  # character_id -> Dictionary[ability_id -> float]

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func check_for_psionic_potential(character) -> bool:
    if character.has_psionic_potential != null:
        return character.has_psionic_potential
    
    # Roll for psionic potential
    var base_chance = 0.1  # 10% base chance
    
    # Modify based on character attributes
    for characteristic in character.characteristics:
        base_chance += _get_characteristic_psionic_modifier(characteristic)
    
    # Modify based on background
    base_chance += _get_background_psionic_modifier(character.background)
    
    # Final roll
    var roll = randf()
    character.has_psionic_potential = roll <= base_chance
    
    if character.has_psionic_potential:
        _initialize_psionic_abilities(character)
    
    return character.has_psionic_potential

func manifest_ability(character, ability_id: String) -> bool:
    if not can_use_ability(character, ability_id):
        return false
    
    var ability = get_ability(character, ability_id)
    if not ability:
        return false
    
    if _attempt_ability_manifestation(character, ability):
        _apply_ability_effects(character, ability)
        _start_ability_cooldown(character, ability_id)
        psionic_manifested.emit(character, ability)
        return true
    else:
        psionic_failed.emit(character, ability, "Manifestation failed")
        return false

func can_use_ability(character, ability_id: String) -> bool:
    # Check if character has psionic potential
    if not character.has_psionic_potential:
        return false
    
    # Check if ability exists
    var ability = get_ability(character, ability_id)
    if not ability:
        return false
    
    # Check if on cooldown
    if is_ability_on_cooldown(character, ability_id):
        return false
    
    # Check if character has enough psi points
    if character.psi_points < ability.cost:
        return false
    
    # Check if ability is unlocked
    if not is_ability_unlocked(character, ability):
        return false
    
    return true

func is_ability_on_cooldown(character, ability_id: String) -> bool:
    if not character.id in psionic_cooldowns:
        return false
    
    var cooldown_end = psionic_cooldowns[character.id].get(ability_id, 0.0)
    return Time.get_unix_time_from_system() < cooldown_end

func get_ability(character, ability_id: String) -> Dictionary:
    if not character.id in active_psionics:
        return {}
    
    for ability in active_psionics[character.id]:
        if ability.id == ability_id:
            return ability
    
    return {}

func get_available_abilities(character) -> Array:
    if not character.id in active_psionics:
        return []
    
    return active_psionics[character.id].filter(func(ability): 
        return can_use_ability(character, ability.id)
    )

func get_cooldown_time(character, ability_id: String) -> float:
    if not character.id in psionic_cooldowns:
        return 0.0
    
    var cooldown_end = psionic_cooldowns[character.id].get(ability_id, 0.0)
    var current_time = Time.get_unix_time_from_system()
    return max(0.0, cooldown_end - current_time)

func train_ability(character, ability_id: String) -> bool:
    var ability = get_ability(character, ability_id)
    if not ability:
        return false
    
    if not can_train_ability(character, ability):
        return false
    
    _improve_ability(character, ability)
    return true

# Helper Functions
func _initialize_psionic_abilities(character) -> void:
    var initial_abilities = []
    
    # Grant basic abilities
    initial_abilities.append(_create_basic_ability("telepathy"))
    initial_abilities.append(_create_basic_ability("telekinesis"))
    
    # Add character-specific abilities based on attributes and background
    initial_abilities.append_array(_generate_specific_abilities(character))
    
    active_psionics[character.id] = initial_abilities
    psionic_cooldowns[character.id] = {}

func _create_basic_ability(type: String) -> Dictionary:
    match type:
        "telepathy":
            return {
                "id": "basic_telepathy",
                "name": "Basic Telepathy",
                "type": "TELEPATHY",
                "level": 1,
                "cost": 1,
                "cooldown": 60,  # 1 minute
                "range": 10,
                "effects": ["mind_read_surface"],
                "requirements": {"psi_level": 1}
            }
        "telekinesis":
            return {
                "id": "basic_telekinesis",
                "name": "Basic Telekinesis",
                "type": "TELEKINESIS",
                "level": 1,
                "cost": 1,
                "cooldown": 60,
                "range": 5,
                "effects": ["move_small_object"],
                "requirements": {"psi_level": 1}
            }
        _:
            return {}

func _generate_specific_abilities(character) -> Array:
    var specific_abilities = []
    
    # Check attributes for special abilities
    for characteristic in character.characteristics:
        var characteristic_abilities = _get_characteristic_specific_abilities(characteristic)
        specific_abilities.append_array(characteristic_abilities)
    
    # Check background for additional abilities
    var background_abilities = _get_background_specific_abilities(character.background)
    specific_abilities.append_array(background_abilities)
    
    return specific_abilities

func _get_characteristic_specific_abilities(characteristic: String) -> Array:
    match characteristic:
        "psychic_sensitivity":
            return [{
                "id": "enhanced_sensing",
                "name": "Enhanced Sensing",
                "type": "SENSING",
                "level": 1,
                "cost": 2,
                "cooldown": 300,  # 5 minutes
                "range": 20,
                "effects": ["detect_life", "sense_emotions"],
                "requirements": {"psi_level": 2}
            }]
        "mental_fortitude":
            return [{
                "id": "mind_shield",
                "name": "Mind Shield",
                "type": "DEFENSE",
                "level": 1,
                "cost": 3,
                "cooldown": 600,  # 10 minutes
                "range": 0,
                "effects": ["mental_protection"],
                "requirements": {"psi_level": 2}
            }]
        _:
            return []

func _get_background_specific_abilities(background: String) -> Array:
    match background:
        "mystic":
            return [{
                "id": "energy_manipulation",
                "name": "Energy Manipulation",
                "type": "ENERGY",
                "level": 1,
                "cost": 3,
                "cooldown": 300,
                "range": 8,
                "effects": ["energy_bolt"],
                "requirements": {"psi_level": 2}
            }]
        "scholar":
            return [{
                "id": "memory_enhancement",
                "name": "Memory Enhancement",
                "type": "COGNITIVE",
                "level": 1,
                "cost": 2,
                "cooldown": 900,  # 15 minutes
                "range": 0,
                "effects": ["recall_boost"],
                "requirements": {"psi_level": 2}
            }]
        _:
            return []

func _get_characteristic_psionic_modifier(characteristic: String) -> float:
    match characteristic:
        "psychic_sensitivity":
            return 0.15
        "mental_fortitude":
            return 0.10
        "focused_mind":
            return 0.05
        _:
            return 0.0

func _get_background_psionic_modifier(background: String) -> float:
    match background:
        "mystic":
            return 0.20
        "scholar":
            return 0.10
        "explorer":
            return 0.05
        _:
            return 0.0

func _attempt_ability_manifestation(character, ability: Dictionary) -> bool:
    # Calculate success chance
    var base_chance = 0.7  # 70% base chance
    
    # Modify based on character's psi level vs ability level
    var level_difference = character.psi_level - ability.level
    base_chance += level_difference * 0.1
    
    # Modify based on character's current condition
    if character.is_injured:
        base_chance *= 0.7
    if character.is_exhausted:
        base_chance *= 0.8
    
    # Roll for success
    return randf() <= base_chance

func _apply_ability_effects(character, ability: Dictionary) -> void:
    # Consume psi points
    character.psi_points -= ability.cost
    
    # Apply effects
    for effect in ability.effects:
        _apply_single_effect(character, effect, ability)
    
    # Check for illegal usage
    if _is_illegal_usage(character, ability):
        illegal_usage_detected.emit(character, ability)

func _apply_single_effect(character, effect: String, ability: Dictionary) -> void:
    match effect:
        "mind_read_surface":
            _apply_mind_read_effect(character, ability)
        "move_small_object":
            _apply_telekinesis_effect(character, ability)
        "detect_life":
            _apply_detection_effect(character, ability)
        "sense_emotions":
            _apply_emotion_sensing_effect(character, ability)
        "mental_protection":
            _apply_protection_effect(character, ability)
        "energy_bolt":
            _apply_energy_effect(character, ability)
        "recall_boost":
            _apply_recall_effect(character, ability)

func _start_ability_cooldown(character, ability_id: String) -> void:
    var ability = get_ability(character, ability_id)
    if not ability:
        return
    
    if not character.id in psionic_cooldowns:
        psionic_cooldowns[character.id] = {}
    
    var cooldown_time = ability.cooldown
    if character.has_trait("quick_recovery"):
        cooldown_time *= 0.8
    
    psionic_cooldowns[character.id][ability_id] = Time.get_unix_time_from_system() + cooldown_time

func is_ability_unlocked(character, ability: Dictionary) -> bool:
    var requirements = ability.get("requirements", {})
    
    # Check psi level requirement
    if "psi_level" in requirements:
        if character.psi_level < requirements.psi_level:
            return false
    
    # Check attribute requirements
    if "characteristics" in requirements:
        for characteristic in requirements.characteristics:
            if not character.has_characteristic(characteristic):
                return false
    
    return true

func can_train_ability(character, ability: Dictionary) -> bool:
    # Check if ability can be improved
    if ability.level >= character.psi_level:
        return false
    
    # Check if character has enough experience
    var training_cost = _calculate_training_cost(ability)
    if character.psi_experience < training_cost:
        return false
    
    return true

func _improve_ability(character, ability: Dictionary) -> void:
    var training_cost = _calculate_training_cost(ability)
    character.psi_experience -= training_cost
    
    ability.level += 1
    
    # Improve ability effects based on new level
    _upgrade_ability_effects(ability)

func _calculate_training_cost(ability: Dictionary) -> int:
    return ability.level * 100  # Base cost of 100 per level

func _upgrade_ability_effects(ability: Dictionary) -> void:
    match ability.type:
        "TELEPATHY":
            ability.range += 5
        "TELEKINESIS":
            ability.range += 3
        "SENSING":
            ability.range += 10
        "DEFENSE":
            ability.cooldown = max(60, ability.cooldown - 60)  # Reduce cooldown by 1 minute
        "ENERGY":
            ability.cost = max(1, ability.cost - 1)  # Reduce cost
        "COGNITIVE":
            ability.cooldown = max(300, ability.cooldown - 120)  # Reduce cooldown by 2 minutes

func _is_illegal_usage(character, ability: Dictionary) -> bool:
    var world = game_state.current_world
    if not world:
        return false
    
    # Check if psionics are illegal in this world
    if world.has_law("ANTI_PSIONIC"):
        return true
    
    # Check if specific ability types are restricted
    if ability.type in world.restricted_psionic_types:
        return true
    
    # Check if in a restricted area
    var current_location = game_state.get_current_location()
    if current_location in world.psionic_restricted_zones:
        return true
    
    return false

# Effect Application Functions
func _apply_mind_read_effect(character, ability: Dictionary) -> void:
    var targets = _get_valid_targets(character, ability)
    for target in targets:
        if target.has_method("get_surface_thoughts"):
            var thoughts = target.get_surface_thoughts()
            character.receive_telepathic_information(thoughts)

func _apply_telekinesis_effect(character, ability: Dictionary) -> void:
    var target_object = _get_valid_object_target(character, ability)
    if target_object and target_object.has_method("apply_telekinetic_force"):
        var force = ability.level * 10.0
        target_object.apply_telekinetic_force(force)

func _apply_detection_effect(character, ability: Dictionary) -> void:
    var area = _get_detection_area(character, ability)
    var detected_entities = game_state.get_entities_in_area(area)
    character.receive_detection_results(detected_entities)

func _apply_emotion_sensing_effect(character, ability: Dictionary) -> void:
    var targets = _get_valid_targets(character, ability)
    for target in targets:
        if target.has_method("get_emotional_state"):
            var emotions = target.get_emotional_state()
            character.receive_emotional_information(target, emotions)

func _apply_protection_effect(character, ability: Dictionary) -> void:
    var protection_value = ability.level * 20
    var duration = 60.0 * ability.level  # Duration in seconds
    character.apply_mental_protection(protection_value, duration)

func _apply_energy_effect(character, ability: Dictionary) -> void:
    var target = _get_valid_combat_target(character, ability)
    if target and target.has_method("receive_energy_damage"):
        var damage = ability.level * 15
        target.receive_energy_damage(damage, "psionic")

func _apply_recall_effect(character, ability: Dictionary) -> void:
    var boost_value = ability.level * 25  # Percentage boost
    var duration = 300.0 * ability.level  # Duration in seconds
    character.apply_recall_boost(boost_value, duration)

# Target Selection Helpers
func _get_valid_targets(character, ability: Dictionary) -> Array:
    var potential_targets = game_state.get_characters_in_range(character.position, ability.range)
    return potential_targets.filter(func(target): return _can_target_character(character, target, ability))

func _get_valid_object_target(character, ability: Dictionary) -> Object:
    var potential_objects = game_state.get_objects_in_range(character.position, ability.range)
    potential_objects = potential_objects.filter(func(obj): return _can_target_object(obj, ability))
    
    if potential_objects.is_empty():
        return null
    
    return potential_objects[0]  # Return closest valid object

func _get_valid_combat_target(character, ability: Dictionary) -> Object:
    var potential_targets = game_state.get_combat_targets_in_range(character.position, ability.range)
    potential_targets = potential_targets.filter(func(target): return _can_target_character(character, target, ability))
    
    if potential_targets.is_empty():
        return null
    
    return potential_targets[0]  # Return closest valid target

func _get_detection_area(character, ability: Dictionary) -> Dictionary:
    return {
        "center": character.position,
        "radius": ability.range,
        "angle": 360  # Full circle detection
    }

func _can_target_character(character, target, ability: Dictionary) -> bool:
    # Check if target has mental resistance
    if target.has_method("get_mental_resistance"):
        var resistance = target.get_mental_resistance()
        if resistance >= ability.level * 50:  # Arbitrary threshold
            return false
    
    # Check line of sight for certain ability types
    if ability.type in ["TELEPATHY", "ENERGY"]:
        if not game_state.has_line_of_sight(character.position, target.position):
            return false
    
    return true

func _can_target_object(object, ability: Dictionary) -> bool:
    # Check object weight/size for telekinesis
    if ability.type == "TELEKINESIS":
        var weight = object.get("weight", 999999)
        var max_weight = ability.level * 10  # 10 units per level
        return weight <= max_weight
    
    return true