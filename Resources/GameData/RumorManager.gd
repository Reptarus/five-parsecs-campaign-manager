class_name RumorManager
extends Resource

signal rumor_discovered(rumor: Dictionary)
signal rumor_verified(rumor: Dictionary)
signal rumor_expired(rumor: Dictionary)
signal information_gathered(info: Dictionary)

var game_state: GameState
var active_rumors: Array = []
var verified_rumors: Array = []
var expired_rumors: Array = []
var information_cache: Dictionary = {}

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func generate_rumors() -> Array:
    var rumors = []
    var world = game_state.current_world
    
    if not world:
        return rumors
    
    # Generate different types of rumors
    rumors.append_array(_generate_location_rumors(world))
    rumors.append_array(_generate_faction_rumors(world))
    rumors.append_array(_generate_mission_rumors(world))
    rumors.append_array(_generate_market_rumors(world))
    
    # Filter and process rumors
    rumors = rumors.filter(func(rumor): return _validate_rumor(rumor))
    
    for rumor in rumors:
        if not rumor in active_rumors:
            active_rumors.append(rumor)
            rumor_discovered.emit(rumor)
    
    return rumors

func verify_rumor(rumor: Dictionary) -> bool:
    if not rumor in active_rumors:
        return false
    
    var verification_result = _verify_rumor_information(rumor)
    if verification_result.success:
        active_rumors.erase(rumor)
        verified_rumors.append(rumor)
        rumor_verified.emit(rumor)
        return true
    
    return false

func expire_rumor(rumor: Dictionary) -> void:
    if rumor in active_rumors:
        active_rumors.erase(rumor)
        expired_rumors.append(rumor)
        rumor_expired.emit(rumor)

func gather_information(location: String, topic: String) -> Dictionary:
    var info = _generate_information(location, topic)
    if not info.is_empty():
        var cache_key = location + "_" + topic
        information_cache[cache_key] = info
        information_gathered.emit(info)
    return info

func get_active_rumors() -> Array:
    return active_rumors

func get_verified_rumors() -> Array:
    return verified_rumors

func get_expired_rumors() -> Array:
    return expired_rumors

func get_cached_information(location: String, topic: String) -> Dictionary:
    var cache_key = location + "_" + topic
    return information_cache.get(cache_key, {})

func clear_expired_rumors() -> void:
    var current_time = Time.get_unix_time_from_system()
    var to_expire = []
    
    for rumor in active_rumors:
        if current_time > rumor.expiry_time:
            to_expire.append(rumor)
    
    for rumor in to_expire:
        expire_rumor(rumor)

# Helper Functions
func _generate_location_rumors(world) -> Array:
    var rumors = []
    
    # Generate rumors about points of interest
    for poi in world.points_of_interest:
        if randf() <= 0.3:  # 30% chance for each POI
            rumors.append({
                "id": "poi_" + str(randi()),
                "type": "LOCATION",
                "subtype": "POI",
                "title": "Rumors of " + poi.name,
                "description": _generate_poi_description(poi),
                "location": poi.coordinates,
                "reliability": randf_range(0.6, 0.9),
                "expiry_time": _calculate_expiry_time(),
                "verification_requirements": {
                    "distance": 10,  # Must be within 10 units to verify
                    "skills": {"exploration": 1}
                }
            })
    
    # Generate rumors about hidden locations
    var hidden_locations = world.get_hidden_locations()
    for location in hidden_locations:
        if randf() <= 0.2:  # 20% chance for each hidden location
            rumors.append({
                "id": "hidden_" + str(randi()),
                "type": "LOCATION",
                "subtype": "HIDDEN",
                "title": "Whispers of a Secret Place",
                "description": _generate_hidden_location_description(location),
                "location": location.coordinates,
                "reliability": randf_range(0.4, 0.7),
                "expiry_time": _calculate_expiry_time(),
                "verification_requirements": {
                    "distance": 5,
                    "skills": {"exploration": 2}
                }
            })
    
    return rumors

func _generate_faction_rumors(world) -> Array:
    var rumors = []
    
    for faction in world.active_factions:
        if randf() <= 0.4:  # 40% chance for each faction
            rumors.append({
                "id": "faction_" + str(randi()),
                "type": "FACTION",
                "subtype": _select_faction_rumor_type(),
                "title": _generate_faction_rumor_title(faction),
                "description": _generate_faction_description(faction),
                "faction": faction.id,
                "reliability": randf_range(0.5, 0.8),
                "expiry_time": _calculate_expiry_time(),
                "verification_requirements": {
                    "reputation": faction.get_required_reputation(),
                    "skills": {"negotiation": 1}
                }
            })
    
    return rumors

func _generate_mission_rumors(world) -> Array:
    var rumors = []
    
    # Generate rumors about potential missions
    var potential_missions = world.get_potential_missions()
    for mission in potential_missions:
        if randf() <= 0.25:  # 25% chance for each potential mission
            rumors.append({
                "id": "mission_" + str(randi()),
                "type": "MISSION",
                "subtype": mission.type,
                "title": _generate_mission_rumor_title(mission),
                "description": _generate_mission_description(mission),
                "mission_data": mission,
                "reliability": randf_range(0.7, 1.0),
                "expiry_time": _calculate_expiry_time(),
                "verification_requirements": {
                    "skills": {"negotiation": 1},
                    "location": mission.location
                }
            })
    
    return rumors

func _generate_market_rumors(world) -> Array:
    var rumors = []
    
    # Generate rumors about market opportunities
    var market_events = world.get_market_events()
    for event in market_events:
        if randf() <= 0.35:  # 35% chance for each market event
            rumors.append({
                "id": "market_" + str(randi()),
                "type": "MARKET",
                "subtype": event.type,
                "title": _generate_market_rumor_title(event),
                "description": _generate_market_description(event),
                "market_data": event,
                "reliability": randf_range(0.6, 0.9),
                "expiry_time": _calculate_expiry_time(),
                "verification_requirements": {
                    "skills": {"negotiation": 1},
                    "location": event.location
                }
            })
    
    return rumors

func _validate_rumor(rumor: Dictionary) -> bool:
    # Check required fields
    var required_fields = ["id", "type", "title", "description", "reliability", "expiry_time"]
    for field in required_fields:
        if not field in rumor:
            return false
    
    # Validate type-specific fields
    match rumor.type:
        "LOCATION":
            if not "location" in rumor:
                return false
        "FACTION":
            if not "faction" in rumor:
                return false
        "MISSION":
            if not "mission_data" in rumor:
                return false
        "MARKET":
            if not "market_data" in rumor:
                return false
    
    return true

func _verify_rumor_information(rumor: Dictionary) -> Dictionary:
    var result = {
        "success": false,
        "reason": "",
        "additional_info": {}
    }
    
    # Check if rumor has expired
    if Time.get_unix_time_from_system() > rumor.expiry_time:
        result.reason = "Rumor has expired"
        return result
    
    # Check verification requirements
    var requirements = rumor.get("verification_requirements", {})
    
    # Check distance requirement
    if "distance" in requirements:
        var current_location = game_state.get_current_location()
        if current_location.distance_to(rumor.location) > requirements.distance:
            result.reason = "Too far to verify"
            return result
    
    # Check skill requirements
    if "skills" in requirements:
        for skill in requirements.skills:
            if not game_state.crew.has_skill_level(skill, requirements.skills[skill]):
                result.reason = "Missing required skills"
                return result
    
    # Check reputation requirement
    if "reputation" in requirements:
        if game_state.reputation < requirements.reputation:
            result.reason = "Insufficient reputation"
            return result
    
    # Verify based on rumor type
    match rumor.type:
        "LOCATION":
            result = _verify_location_rumor(rumor)
        "FACTION":
            result = _verify_faction_rumor(rumor)
        "MISSION":
            result = _verify_mission_rumor(rumor)
        "MARKET":
            result = _verify_market_rumor(rumor)
    
    return result

func _generate_information(location: String, topic: String) -> Dictionary:
    var info = {
        "location": location,
        "topic": topic,
        "timestamp": Time.get_unix_time_from_system(),
        "data": {},
        "reliability": 0.0
    }
    
    match topic:
        "FACTIONS":
            info.data = _gather_faction_information(location)
        "MARKET":
            info.data = _gather_market_information(location)
        "MISSIONS":
            info.data = _gather_mission_information(location)
        "THREATS":
            info.data = _gather_threat_information(location)
    
    info.reliability = _calculate_information_reliability(info)
    return info

func _calculate_expiry_time() -> float:
    var base_duration = 3 * 24 * 60 * 60  # 3 days in seconds
    var random_variation = randf_range(-0.5, 0.5) * base_duration  # ±50% variation
    return Time.get_unix_time_from_system() + base_duration + random_variation

func _generate_poi_description(poi) -> String:
    var descriptions = [
        "People speak of %s in hushed tones.",
        "Travelers mention strange sights at %s.",
        "Local legends surround the area known as %s.",
        "Merchants avoid the route near %s.",
        "Strange occurrences have been reported at %s."
    ]
    return descriptions[randi() % descriptions.size()] % poi.name

func _generate_hidden_location_description(location) -> String:
    var descriptions = [
        "A well-hidden location that might hold valuable secrets.",
        "A mysterious place that few have ventured to explore.",
        "An unmarked location with unusual activity reported nearby.",
        "A secretive spot that could be worth investigating.",
        "A concealed area with potential strategic value."
    ]
    return descriptions[randi() % descriptions.size()]

func _select_faction_rumor_type() -> String:
    var types = ["CONFLICT", "ALLIANCE", "MOVEMENT", "OPERATION", "LEADERSHIP"]
    return types[randi() % types.size()]

func _generate_faction_rumor_title(faction) -> String:
    var templates = {
        "CONFLICT": "Conflict Brewing in %s",
        "ALLIANCE": "New Alliances Within %s",
        "MOVEMENT": "Movement of %s Forces",
        "OPERATION": "Secret Operations of %s",
        "LEADERSHIP": "Leadership Changes in %s"
    }
    return templates[faction.type] % faction.name

func _generate_faction_description(faction) -> String:
    var descriptions = {
        "CONFLICT": "Reports suggest internal strife within the faction.",
        "ALLIANCE": "Word of new partnerships being formed.",
        "MOVEMENT": "Unusual movement patterns observed recently.",
        "OPERATION": "Whispers of covert operations in progress.",
        "LEADERSHIP": "Signs of power shifts in the hierarchy."
    }
    return descriptions[faction.type]

func _generate_mission_rumor_title(mission) -> String:
    var templates = {
        "COMBAT": "Combat Operation: %s",
        "EXPLORATION": "Exploration Opportunity: %s",
        "ESCORT": "Escort Mission: %s",
        "RECOVERY": "Recovery Operation: %s",
        "INVESTIGATION": "Investigation Required: %s"
    }
    return templates[mission.type] % mission.name

func _generate_mission_description(mission) -> String:
    return mission.get_rumor_description()

func _generate_market_rumor_title(event) -> String:
    var templates = {
        "SHORTAGE": "Resource Shortage: %s",
        "SURPLUS": "Market Surplus: %s",
        "OPPORTUNITY": "Trading Opportunity: %s",
        "CRISIS": "Market Crisis: %s"
    }
    return templates[event.type] % event.commodity

func _generate_market_description(event) -> String:
    return event.get_rumor_description()

func _verify_location_rumor(rumor: Dictionary) -> Dictionary:
    var world = game_state.current_world
    var result = {"success": false, "reason": "", "additional_info": {}}
    
    match rumor.subtype:
        "POI":
            var poi = world.get_poi_at_location(rumor.location)
            if poi:
                result.success = true
                result.additional_info = poi.get_public_info()
            else:
                result.reason = "Point of interest not found"
        "HIDDEN":
            var location = world.get_location_at_coordinates(rumor.location)
            if location and location.is_hidden:
                result.success = true
                result.additional_info = location.get_public_info()
            else:
                result.reason = "Hidden location not found"
    
    return result

func _verify_faction_rumor(rumor: Dictionary) -> Dictionary:
    var world = game_state.current_world
    var result = {"success": false, "reason": "", "additional_info": {}}
    
    var faction = world.get_faction(rumor.faction)
    if faction:
        result.success = true
        result.additional_info = faction.get_public_info()
    else:
        result.reason = "Faction information not available"
    
    return result

func _verify_mission_rumor(rumor: Dictionary) -> Dictionary:
    var result = {"success": false, "reason": "", "additional_info": {}}
    
    var mission = rumor.mission_data
    if mission and mission.is_valid():
        result.success = true
        result.additional_info = mission.get_public_info()
    else:
        result.reason = "Mission no longer available"
    
    return result

func _verify_market_rumor(rumor: Dictionary) -> Dictionary:
    var result = {"success": false, "reason": "", "additional_info": {}}
    
    var market_data = rumor.market_data
    if market_data and market_data.is_active:
        result.success = true
        result.additional_info = market_data.get_public_info()
    else:
        result.reason = "Market conditions have changed"
    
    return result

func _gather_faction_information(location: String) -> Dictionary:
    var world = game_state.current_world
    var info = {}
    
    if world:
        var factions = world.get_factions_in_location(location)
        for faction in factions:
            info[faction.id] = {
                "presence": faction.get_presence_level(location),
                "activity": faction.get_recent_activities(location),
                "relations": faction.get_relations_with_others()
            }
    
    return info

func _gather_market_information(location: String) -> Dictionary:
    var world = game_state.current_world
    var info = {}
    
    if world:
        var market = world.get_market_at_location(location)
        if market:
            info = {
                "prices": market.get_current_prices(),
                "trends": market.get_price_trends(),
                "opportunities": market.get_trading_opportunities()
            }
    
    return info

func _gather_mission_information(location: String) -> Dictionary:
    var world = game_state.current_world
    var info = {}
    
    if world:
        var missions = world.get_available_missions_at_location(location)
        info = {
            "available": missions.size(),
            "types": _categorize_missions(missions),
            "difficulty_range": _get_mission_difficulty_range(missions)
        }
    
    return info

func _gather_threat_information(location: String) -> Dictionary:
    var world = game_state.current_world
    var info = {}
    
    if world:
        var threats = world.get_active_threats_at_location(location)
        info = {
            "level": world.get_threat_level(location),
            "types": _categorize_threats(threats),
            "warnings": world.get_threat_warnings(location)
        }
    
    return info

func _calculate_information_reliability(info: Dictionary) -> float:
    var base_reliability = 0.7  # Base 70% reliability
    
    # Adjust based on information age
    var age = Time.get_unix_time_from_system() - info.timestamp
    var age_factor = 1.0 - (age / (7 * 24 * 60 * 60))  # Decay over a week
    
    # Adjust based on information type
    match info.topic:
        "FACTIONS":
            base_reliability *= 0.9  # Faction info is generally reliable
        "MARKET":
            base_reliability *= 0.8  # Market info changes frequently
        "MISSIONS":
            base_reliability *= 0.7  # Mission availability can change
        "THREATS":
            base_reliability *= 0.6  # Threat information is least reliable
    
    return clamp(base_reliability * age_factor, 0.1, 0.9)

func _categorize_missions(missions: Array) -> Dictionary:
    var categories = {}
    for mission in missions:
        if mission.type in categories:
            categories[mission.type] += 1
        else:
            categories[mission.type] = 1
    return categories

func _get_mission_difficulty_range(missions: Array) -> Dictionary:
    if missions.is_empty():
        return {"min": 0, "max": 0}
    
    var difficulties = missions.map(func(m): return m.difficulty)
    return {
        "min": difficulties.min(),
        "max": difficulties.max()
    }

func _categorize_threats(threats: Array) -> Dictionary:
    var categories = {}
    for threat in threats:
        if threat.type in categories:
            categories[threat.type] += 1
        else:
            categories[threat.type] = 1
    return categories