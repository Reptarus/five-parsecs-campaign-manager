class_name InstabilitySystem
extends Resource

signal instability_increased(amount: int, reason: String)
signal instability_decreased(amount: int, reason: String)
signal critical_event_triggered(event: Dictionary)
signal stability_restored(location: String)

var game_state: GameState
var instability_levels: Dictionary = {}  # location -> level
var active_effects: Dictionary = {}  # location -> Array[Dictionary]
var critical_events: Array = []

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func increase_instability(location: String, amount: int, reason: String) -> void:
    if not location in instability_levels:
        instability_levels[location] = 0
    
    instability_levels[location] = min(instability_levels[location] + amount, 100)
    _update_instability_effects(location)
    
    instability_increased.emit(amount, reason)
    
    # Check for critical events
    if _should_trigger_critical_event(location):
        var event = _generate_critical_event(location)
        critical_events.append(event)
        critical_event_triggered.emit(event)

func decrease_instability(location: String, amount: int, reason: String) -> void:
    if not location in instability_levels:
        return
    
    instability_levels[location] = max(instability_levels[location] - amount, 0)
    _update_instability_effects(location)
    
    instability_decreased.emit(amount, reason)
    
    if instability_levels[location] == 0:
        stability_restored.emit(location)

func get_instability_level(location: String) -> int:
    return instability_levels.get(location, 0)

func get_active_effects(location: String) -> Array:
    return active_effects.get(location, [])

func get_critical_events() -> Array:
    return critical_events

func get_stability_status(location: String) -> String:
    var level = get_instability_level(location)
    
    if level < 20:
        return "STABLE"
    elif level < 40:
        return "UNSETTLED"
    elif level < 60:
        return "UNSTABLE"
    elif level < 80:
        return "DANGEROUS"
    else:
        return "CRITICAL"

func can_restore_stability(location: String) -> bool:
    var level = get_instability_level(location)
    if level == 0:
        return false
    
    # Check if we have the means to restore stability
    if not _has_stability_resources(location):
        return false
    
    # Check if there are any blocking critical events
    if _has_blocking_critical_events(location):
        return false
    
    return true

func attempt_stability_restoration(location: String) -> bool:
    if not can_restore_stability(location):
        return false
    
    var resources_used = _consume_stability_resources(location)
    if resources_used:
        var reduction = _calculate_stability_reduction(location)
        decrease_instability(location, reduction, "Stability restoration")
        return true
    
    return false

# Helper Functions
func _update_instability_effects(location: String) -> void:
    var level = get_instability_level(location)
    var new_effects = []
    
    # Clear existing effects
    active_effects[location] = []
    
    # Add effects based on instability level
    if level >= 20:
        new_effects.append(_generate_minor_effect(location))
    if level >= 40:
        new_effects.append(_generate_moderate_effect(location))
    if level >= 60:
        new_effects.append(_generate_major_effect(location))
    if level >= 80:
        new_effects.append(_generate_severe_effect(location))
    
    active_effects[location] = new_effects

func _should_trigger_critical_event(location: String) -> bool:
    var level = get_instability_level(location)
    var base_chance = level / 200.0  # 0.5 at max instability
    
    # Modify based on active effects
    for effect in get_active_effects(location):
        if effect.type == "CATALYST":
            base_chance *= 1.5
    
    # Modify based on world conditions
    var world = game_state.current_world
    if world and world.has_trait("VOLATILE"):
        base_chance *= 1.3
    
    return randf() <= base_chance

func _generate_critical_event(location: String) -> Dictionary:
    var event_types = _get_available_event_types(location)
    var selected_type = event_types[randi() % event_types.size()]
    
    return {
        "id": "critical_" + str(randi()),
        "type": selected_type,
        "location": location,
        "severity": _calculate_event_severity(location),
        "duration": _calculate_event_duration(selected_type),
        "effects": _generate_event_effects(selected_type),
        "resolution_requirements": _generate_resolution_requirements(selected_type)
    }

func _get_available_event_types(location: String) -> Array:
    var types = ["TEMPORAL", "SPATIAL", "DIMENSIONAL"]
    
    # Add location-specific types
    var world = game_state.current_world
    if world:
        match world.type:
            "INDUSTRIAL":
                types.append("TECHNOLOGICAL")
            "RESEARCH":
                types.append("EXPERIMENTAL")
            "MILITARY":
                types.append("TACTICAL")
    
    return types

func _calculate_event_severity(location: String) -> int:
    var base_severity = get_instability_level(location) / 20  # 0-5 scale
    return clamp(base_severity, 1, 5)

func _calculate_event_duration(event_type: String) -> int:
    var base_duration = 3600  # 1 hour in seconds
    
    match event_type:
        "TEMPORAL":
            return base_duration * randi_range(2, 6)
        "SPATIAL":
            return base_duration * randi_range(4, 8)
        "DIMENSIONAL":
            return base_duration * randi_range(6, 12)
        _:
            return base_duration * randi_range(3, 7)

func _generate_event_effects(event_type: String) -> Array:
    var effects = []
    
    match event_type:
        "TEMPORAL":
            effects.append({
                "type": "TIME_DISTORTION",
                "magnitude": randi_range(1, 3),
                "area_of_effect": randi_range(10, 30)
            })
        "SPATIAL":
            effects.append({
                "type": "SPACE_WARPING",
                "magnitude": randi_range(1, 3),
                "area_of_effect": randi_range(15, 45)
            })
        "DIMENSIONAL":
            effects.append({
                "type": "REALITY_BREACH",
                "magnitude": randi_range(2, 4),
                "area_of_effect": randi_range(20, 60)
            })
        "TECHNOLOGICAL":
            effects.append({
                "type": "TECH_MALFUNCTION",
                "magnitude": randi_range(1, 3),
                "affected_systems": _select_affected_systems()
            })
        "EXPERIMENTAL":
            effects.append({
                "type": "CONTAINMENT_BREACH",
                "magnitude": randi_range(2, 4),
                "hazard_type": _select_hazard_type()
            })
        "TACTICAL":
            effects.append({
                "type": "STRATEGIC_DISRUPTION",
                "magnitude": randi_range(1, 3),
                "affected_operations": _select_affected_operations()
            })
    
    return effects

func _generate_resolution_requirements(event_type: String) -> Dictionary:
    var base_requirements = {
        "resources": [],
        "equipment": [],
        "skills": {},
        "time": 0
    }
    
    match event_type:
        "TEMPORAL":
            base_requirements.resources.append({"type": "TEMPORAL_STABILIZER", "amount": 2})
            base_requirements.skills["temporal_physics"] = 2
            base_requirements.time = 3600
        "SPATIAL":
            base_requirements.resources.append({"type": "SPATIAL_ANCHOR", "amount": 3})
            base_requirements.skills["spatial_manipulation"] = 2
            base_requirements.time = 7200
        "DIMENSIONAL":
            base_requirements.resources.append({"type": "REALITY_SHARD", "amount": 4})
            base_requirements.skills["dimensional_theory"] = 3
            base_requirements.time = 10800
        "TECHNOLOGICAL":
            base_requirements.resources.append({"type": "TECH_COMPONENTS", "amount": 5})
            base_requirements.skills["technical"] = 2
            base_requirements.time = 5400
        "EXPERIMENTAL":
            base_requirements.resources.append({"type": "CONTAINMENT_UNIT", "amount": 3})
            base_requirements.skills["research"] = 2
            base_requirements.time = 7200
        "TACTICAL":
            base_requirements.resources.append({"type": "TACTICAL_GEAR", "amount": 4})
            base_requirements.skills["tactics"] = 2
            base_requirements.time = 3600
    
    return base_requirements

func _generate_minor_effect(location: String) -> Dictionary:
    return {
        "type": "MINOR",
        "effects": ["reduced_visibility", "equipment_malfunction"],
        "magnitude": 1,
        "duration": 3600  # 1 hour
    }

func _generate_moderate_effect(location: String) -> Dictionary:
    return {
        "type": "MODERATE",
        "effects": ["environmental_hazards", "communication_interference"],
        "magnitude": 2,
        "duration": 7200  # 2 hours
    }

func _generate_major_effect(location: String) -> Dictionary:
    return {
        "type": "MAJOR",
        "effects": ["reality_distortion", "temporal_anomalies"],
        "magnitude": 3,
        "duration": 14400  # 4 hours
    }

func _generate_severe_effect(location: String) -> Dictionary:
    return {
        "type": "SEVERE",
        "effects": ["dimensional_breach", "space_time_rupture"],
        "magnitude": 4,
        "duration": 28800  # 8 hours
    }

func _has_stability_resources(location: String) -> bool:
    var required_resources = _get_required_stability_resources(location)
    
    for resource in required_resources:
        if not game_state.has_resource(resource.type, resource.amount):
            return false
    
    return true

func _has_blocking_critical_events(location: String) -> bool:
    for event in critical_events:
        if event.location == location and event.type == "DIMENSIONAL":
            return true
    return false

func _consume_stability_resources(location: String) -> bool:
    var required_resources = _get_required_stability_resources(location)
    
    # Verify resources again
    for resource in required_resources:
        if not game_state.has_resource(resource.type, resource.amount):
            return false
    
    # Consume resources
    for resource in required_resources:
        game_state.consume_resource(resource.type, resource.amount)
    
    return true

func _calculate_stability_reduction(location: String) -> int:
    var base_reduction = 20
    
    # Modify based on crew skills
    for crew_member in game_state.crew.active_members:
        if crew_member.has_skill("stability_control"):
            base_reduction += crew_member.get_skill_level("stability_control") * 5
    
    # Modify based on equipment
    if game_state.has_equipment("stability_enhancer"):
        base_reduction *= 1.5
    
    return int(base_reduction)

func _get_required_stability_resources(location: String) -> Array:
    var level = get_instability_level(location)
    var resources = []
    
    if level >= 80:
        resources.append({"type": "STABILITY_CORE", "amount": 2})
    if level >= 60:
        resources.append({"type": "REALITY_ANCHOR", "amount": 3})
    if level >= 40:
        resources.append({"type": "STABILIZING_COMPOUND", "amount": 4})
    if level >= 20:
        resources.append({"type": "BASIC_STABILIZER", "amount": 5})
    
    return resources

func _select_affected_systems() -> Array:
    var systems = ["POWER", "COMMUNICATIONS", "DEFENSE", "LIFE_SUPPORT"]
    var num_affected = randi_range(1, 3)
    var selected = []
    
    for i in range(num_affected):
        var system = systems[randi() % systems.size()]
        if not system in selected:
            selected.append(system)
    
    return selected

func _select_hazard_type() -> String:
    var types = ["BIOLOGICAL", "CHEMICAL", "RADIOLOGICAL", "QUANTUM"]
    return types[randi() % types.size()]

func _select_affected_operations() -> Array:
    var operations = ["MOVEMENT", "COMBAT", "LOGISTICS", "INTELLIGENCE"]
    var num_affected = randi_range(1, 3)
    var selected = []
    
    for i in range(num_affected):
        var operation = operations[randi() % operations.size()]
        if not operation in selected:
            selected.append(operation)
    
    return selected