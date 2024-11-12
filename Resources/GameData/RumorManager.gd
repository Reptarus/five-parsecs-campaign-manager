class_name RumorManager
extends Resource

var game_state: GameState

func _init() -> void:
    pass

func initialize(state: GameState) -> void:
    game_state = state

func generate_rumors() -> void:
    var available_rumors = _get_available_rumors()
    var selected_rumors = _select_rumors(available_rumors)
    _apply_rumors(selected_rumors)

func _get_available_rumors() -> Array[Dictionary]:
    var rumors: Array[Dictionary] = []
    
    # Generate rumors based on current world state
    if game_state.current_location:
        # Location-based rumors
        rumors.append_array(_generate_location_rumors())
    
    # Faction-based rumors
    for faction in game_state.faction_standings.keys():
        if game_state.faction_standings[faction] >= 0:
            rumors.append_array(_generate_faction_rumors(faction))
    
    # Special condition rumors
    if game_state.current_strife_level > 2:
        rumors.append_array(_generate_strife_rumors())
    
    return rumors

func _generate_location_rumors() -> Array[Dictionary]:
    var location_rumors: Array[Dictionary] = []
    
    match game_state.current_location.type:
        GlobalEnums.TerrainType.CITY:
            location_rumors.append({
                "type": "urban",
                "description": "Word of underground markets...",
                "mission_type": GlobalEnums.Type.OPPORTUNITY,
                "probability": 0.7
            })
        GlobalEnums.TerrainType.WILDERNESS:
            location_rumors.append({
                "type": "exploration",
                "description": "Tales of hidden resources...",
                "mission_type": GlobalEnums.Type.QUEST,
                "probability": 0.6
            })
        GlobalEnums.TerrainType.SPACE:
            location_rumors.append({
                "type": "salvage",
                "description": "Distress beacon detected...",
                "mission_type": GlobalEnums.Type.RESCUE,
                "probability": 0.5
            })
    
    return location_rumors

func _generate_faction_rumors(faction: GlobalEnums.Faction) -> Array[Dictionary]:
    var faction_rumors: Array[Dictionary] = []
    
    match faction:
        GlobalEnums.Faction.CORPORATE:
            faction_rumors.append({
                "type": "corporate",
                "description": "Corporate intrigue brewing...",
                "mission_type": GlobalEnums.Type.SABOTAGE,
                "probability": 0.6
            })
        GlobalEnums.Faction.MILITARY:
            faction_rumors.append({
                "type": "military",
                "description": "Military operation pending...",
                "mission_type": GlobalEnums.Type.DEFENSE,
                "probability": 0.7
            })
        GlobalEnums.Faction.CRIMINAL:
            faction_rumors.append({
                "type": "criminal",
                "description": "Underground job available...",
                "mission_type": GlobalEnums.Type.ASSASSINATION,
                "probability": 0.5
            })
    
    return faction_rumors

func _generate_strife_rumors() -> Array[Dictionary]:
    return [{
        "type": "strife",
        "description": "Conflict intensifying...",
        "mission_type": GlobalEnums.Type.RED_ZONE,
        "probability": 0.8
    }]

func _select_rumors(available_rumors: Array[Dictionary]) -> Array[Dictionary]:
    var selected: Array[Dictionary] = []
    
    for rumor in available_rumors:
        if randf() < rumor.probability:
            selected.append(rumor)
    
    # Limit to maximum 3 rumors at a time
    if selected.size() > 3:
        selected = selected.slice(0, 3)
    
    return selected

func _apply_rumors(rumors: Array[Dictionary]) -> void:
    for rumor in rumors:
        match rumor.type:
            "urban", "exploration", "salvage":
                _generate_location_mission(rumor)
            "corporate", "military", "criminal":
                _generate_faction_mission(rumor)
            "strife":
                _generate_strife_mission(rumor)

func _generate_location_mission(rumor: Dictionary) -> void:
    var mission = game_state.mission_generator.generate_mission()
    mission.type = rumor.mission_type
    mission.description = rumor.description
    game_state.add_available_mission(mission)

func _generate_faction_mission(rumor: Dictionary) -> void:
    var mission = game_state.mission_generator.generate_mission()
    mission.type = rumor.mission_type
    mission.description = rumor.description
    game_state.add_available_mission(mission)

func _generate_strife_mission(rumor: Dictionary) -> void:
    var mission = game_state.mission_generator.generate_mission()
    mission.type = rumor.mission_type
    mission.description = rumor.description
    mission.difficulty += 1
    game_state.add_available_mission(mission) 