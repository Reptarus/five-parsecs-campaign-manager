class_name SpecialMissionGenerator
extends MissionGeneratorBase

enum MissionTier {NORMAL, RED_ZONE, BLACK_ZONE}

const RED_ZONE_REWARD_MULTIPLIER := 1.5
const BLACK_ZONE_REWARD_MULTIPLIER := 2.0
const RED_ZONE_DIFFICULTY_INCREASE := 2
const BLACK_ZONE_DIFFICULTY_INCREASE := 4

func generate_special_mission(tier: MissionTier, params: Dictionary = {}) -> Mission:
    var mission = _create_base_mission()
    
    match tier:
        MissionTier.RED_ZONE:
            _apply_red_zone_modifiers(mission)
        MissionTier.BLACK_ZONE:
            _apply_black_zone_modifiers(mission)
    
    if params.has("patron"):
        _apply_patron_modifiers(mission, params.patron)
    
    return mission if _validate_mission_requirements(mission) else null

func _apply_red_zone_modifiers(mission: Mission) -> void:
    mission.difficulty += RED_ZONE_DIFFICULTY_INCREASE
    mission.threat_condition = _generate_threat_condition()
    mission.time_constraint = _generate_time_constraint()
    _modify_rewards(mission, RED_ZONE_REWARD_MULTIPLIER)
    mission.increased_opposition()

func _apply_black_zone_modifiers(mission: Mission) -> void:
    mission.difficulty += BLACK_ZONE_DIFFICULTY_INCREASE
    mission.enemy_type = "Roving Threats"
    mission.objective = GlobalEnums.MissionObjective.ELIMINATE
    _modify_rewards(mission, BLACK_ZONE_REWARD_MULTIPLIER)
    mission.setup_black_zone_opposition()

func _apply_patron_modifiers(mission: Mission, patron: Patron) -> void:
    var benefits_hazards = _generate_patron_conditions(patron)
    mission.benefits = benefits_hazards.benefits
    mission.hazards = benefits_hazards.hazards
    mission.conditions = benefits_hazards.conditions
    mission.patron = patron
    mission.type = GlobalEnums.Type.PATRON

func _generate_patron_conditions(patron: Patron) -> Dictionary:
    return {
        "benefits": [generate_benefit()] if _should_generate_benefit(patron) else [],
        "hazards": [generate_hazard()] if _should_generate_hazard(patron) else [],
        "conditions": [generate_condition()] if _should_generate_condition(patron) else []
    }

func _should_generate_benefit(patron: Patron) -> bool:
    var chance: float = 0.8 if patron.type in [GlobalEnums.Faction.CORPORATE, GlobalEnums.Faction.UNITY] else 0.5
    return randf() < chance

func _should_generate_hazard(patron: Patron) -> bool:
    var chance: float = 0.5 if patron.type == GlobalEnums.Faction.FRINGE else 0.8
    return randf() < chance

func _should_generate_condition(patron: Patron) -> bool:
    var chance: float = 0.5 if patron.type == GlobalEnums.Faction.CORPORATE else 0.8
    return randf() < chance

func _generate_threat_condition() -> String:
    var conditions := [
        "Comms Interference",
        "Elite Opposition",
        "Pitch Black",
        "Heavy Opposition",
        "Armored Opponents",
        "Enemy Captain"
    ]
    return conditions.pick_random()

func _generate_time_constraint() -> String:
    var constraints := [
        "None",
        "Reinforcements",
        "Significant reinforcements",
        "Count down",
        "Evac now!",
        "Elite reinforcements"
    ]
    return constraints.pick_random()
