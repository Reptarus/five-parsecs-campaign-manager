class_name CampaignManager
extends Resource

signal campaign_state_changed
signal location_changed
signal crew_updated
signal resources_updated
signal mission_completed
signal story_event_triggered

var current_location: Location
var available_locations: Array[Location] = []
var crew_members: Array[CrewMember] = []
var resources: Dictionary = {
    "credits": 1000,
    "fuel": 100,
    "supplies": 100,
    "reputation": 0
}

var active_missions: Array[Mission] = []
var completed_missions: Array[Mission] = []
var available_jobs: Array[Dictionary] = []

# Travel System
var travel_routes: Dictionary = {}
var current_route: Dictionary = {}
var travel_events: Array[Dictionary] = []
var route_hazards: Array[Dictionary] = []

# Campaign State
var campaign_day: int = 1
var story_progress: Dictionary = {}
var faction_relations: Dictionary = {}

func _init() -> void:
    _initialize_campaign()

func _initialize_campaign() -> void:
    _setup_initial_location()
    _initialize_travel_system()
    emit_signal("campaign_state_changed")

func _setup_initial_location() -> void:
    if current_location == null:
        # Create a default starting location
        current_location = Location.new(
            "Haven Prime",
            GlobalEnums.TerrainType.CITY,
            GlobalEnums.FactionType.NEUTRAL,
            1
        )
        available_locations.append(current_location)

func _initialize_travel_system() -> void:
    travel_routes.clear()
    route_hazards.clear()
    
    # Initialize basic travel events
    travel_events = [
        {
            "id": "pirate_encounter",
            "type": "combat",
            "probability": 0.2,
            "min_reputation": 0
        },
        {
            "id": "trade_opportunity",
            "type": "trade",
            "probability": 0.3,
            "min_reputation": 0
        },
        {
            "id": "distress_signal",
            "type": "rescue",
            "probability": 0.15,
            "min_reputation": 2
        },
        {
            "id": "salvage_opportunity",
            "type": "exploration",
            "probability": 0.25,
            "min_reputation": 1
        }
    ]

func travel_to_location(destination: Location) -> bool:
    if not can_travel_to(destination):
        return false
    
    var route = _calculate_route(current_location, destination)
    if route.is_empty():
        return false
    
    current_route = route
    _consume_travel_resources(route)
    _process_travel_events()
    
    current_location = destination
    _update_location_state()
    
    emit_signal("location_changed")
    return true

func can_travel_to(destination: Location) -> bool:
    if destination == current_location:
        return false
    
    var route = _calculate_route(current_location, destination)
    if route.is_empty():
        return false
    
    # Check if we have enough resources for the journey
    var required_resources = _calculate_required_resources(route)
    for resource in required_resources:
        if resources[resource] < required_resources[resource]:
            return false
    
    return true

func _calculate_route(start: Location, end: Location) -> Dictionary:
    # Simple direct route for now
    # TODO: Implement proper pathfinding between locations
    return {
        "distance": 1,  # Default distance unit
        "terrain_difficulty": _calculate_terrain_difficulty(start, end),
        "hazard_level": _calculate_hazard_level(start, end),
        "fuel_cost": 10,  # Base fuel cost
        "supply_cost": 5   # Base supply cost
    }

func _calculate_terrain_difficulty(start: Location, end: Location) -> int:
    var difficulty = 1
    
    # Increase difficulty based on terrain types
    if start.type != end.type:
        difficulty += 1
    
    # Factor in location threat levels
    difficulty += maxi(end.threat_level - start.threat_level, 0)
    
    return difficulty

func _calculate_hazard_level(start: Location, end: Location) -> int:
    var hazard_level = 0
    
    # Base hazard on location instability
    hazard_level += end.instability
    
    # Factor in faction hostility
    if end.faction == GlobalEnums.FactionType.HOSTILE:
        hazard_level += 2
    
    return hazard_level

func _calculate_required_resources(route: Dictionary) -> Dictionary:
    var requirements = {
        "fuel": route.fuel_cost,
        "supplies": route.supply_cost
    }
    
    # Adjust for terrain difficulty
    requirements.fuel *= (1.0 + route.terrain_difficulty * 0.1)
    requirements.supplies *= (1.0 + route.terrain_difficulty * 0.1)
    
    # Adjust for hazard level
    requirements.fuel *= (1.0 + route.hazard_level * 0.05)
    requirements.supplies *= (1.0 + route.hazard_level * 0.05)
    
    return requirements

func _consume_travel_resources(route: Dictionary) -> void:
    var required = _calculate_required_resources(route)
    
    for resource in required:
        resources[resource] -= required[resource]
    
    emit_signal("resources_updated")

func _process_travel_events() -> void:
    var event_count = _calculate_event_count()
    
    for i in range(event_count):
        var event = _generate_travel_event()
        if event != null:
            _handle_travel_event(event)

func _calculate_event_count() -> int:
    var base_count = 1
    base_count += floori(current_route.distance / 2.0)
    base_count += floori(current_route.hazard_level / 2.0)
    
    return base_count

func _generate_travel_event() -> Dictionary:
    var available_events = travel_events.filter(
        func(event): return resources.reputation >= event.min_reputation
    )
    
    if available_events.is_empty():
        return {}
    
    var total_probability = 0.0
    for event in available_events:
        total_probability += event.probability
    
    var roll = randf() * total_probability
    var current_sum = 0.0
    
    for event in available_events:
        current_sum += event.probability
        if roll <= current_sum:
            return event
    
    return available_events[-1]  # Fallback to last event

func _handle_travel_event(event: Dictionary) -> void:
    match event.type:
        "combat":
            _handle_combat_event(event)
        "trade":
            _handle_trade_event(event)
        "rescue":
            _handle_rescue_event(event)
        "exploration":
            _handle_exploration_event(event)

func _handle_combat_event(event: Dictionary) -> void:
    # Generate a combat encounter
    var mission = MissionGenerator.new().generate_mission(
        current_location,
        1 + floori(resources.reputation / 3.0)
    )
    active_missions.append(mission)
    emit_signal("story_event_triggered", "combat_encounter", mission)

func _handle_trade_event(event: Dictionary) -> void:
    var trade_opportunity = {
        "type": "trade",
        "offers": _generate_trade_offers(),
        "duration": 1  # Available for 1 day
    }
    emit_signal("story_event_triggered", "trade_opportunity", trade_opportunity)

func _handle_rescue_event(event: Dictionary) -> void:
    var rescue_mission = MissionGenerator.new().generate_mission(
        current_location,
        1 + floori(resources.reputation / 2.0)
    )
    rescue_mission.type = "rescue"
    active_missions.append(rescue_mission)
    emit_signal("story_event_triggered", "distress_signal", rescue_mission)

func _handle_exploration_event(event: Dictionary) -> void:
    var exploration = {
        "type": "exploration",
        "rewards": _generate_exploration_rewards(),
        "risks": _generate_exploration_risks()
    }
    emit_signal("story_event_triggered", "exploration_opportunity", exploration)

func _generate_trade_offers() -> Array:
    var offers = []
    var possible_items = ["fuel", "supplies", "weapons", "equipment"]
    
    for i in range(1 + randi() % 3):
        var item = possible_items[randi() % possible_items.size()]
        offers.append({
            "item": item,
            "quantity": 5 + randi() % 16,
            "price": (50 + randi() % 151) * (1.0 - resources.reputation * 0.05)
        })
    
    return offers

func _generate_exploration_rewards() -> Array:
    var rewards = []
    var possible_rewards = ["credits", "fuel", "supplies", "equipment", "information"]
    
    for i in range(1 + randi() % 3):
        var reward_type = possible_rewards[randi() % possible_rewards.size()]
        rewards.append({
            "type": reward_type,
            "value": 100 + randi() % 401
        })
    
    return rewards

func _generate_exploration_risks() -> Array:
    var risks = []
    var possible_risks = ["damage", "resource_loss", "crew_injury", "equipment_loss"]
    
    for i in range(1 + randi() % 2):
        var risk_type = possible_risks[randi() % possible_risks.size()]
        risks.append({
            "type": risk_type,
            "probability": 0.2 + randf() * 0.3,
            "severity": 1 + randi() % 3
        })
    
    return risks

func _update_location_state() -> void:
    # Update available missions
    _refresh_available_missions()
    
    # Update available jobs
    _refresh_available_jobs()
    
    # Update local events
    _process_local_events()
    
    # Update crew state
    _update_crew_state()
    
    emit_signal("campaign_state_changed")

func _refresh_available_missions() -> void:
    var generator = MissionGenerator.new()
    var mission_count = 2 + randi() % 3  # 2-4 missions
    
    active_missions.clear()
    for i in range(mission_count):
        var mission = generator.generate_mission(
            current_location,
            1 + floori(resources.reputation / 3.0)
        )
        active_missions.append(mission)

func _refresh_available_jobs() -> void:
    var generator = MissionGenerator.new()
    var job_count = 1 + randi() % 3  # 1-3 jobs
    
    available_jobs.clear()
    for i in range(job_count):
        var job = generator.generate_job(
            current_location,
            resources.reputation
        )
        available_jobs.append(job)

func _process_local_events() -> void:
    # Process any location-specific events
    for event in current_location.local_events:
        if event.has("duration"):
            event.duration -= 1
    
    # Remove expired events
    current_location.local_events = current_location.local_events.filter(
        func(event): return !event.has("duration") or event.duration > 0
    )

func _update_crew_state() -> void:
    for crew_member in crew_members:
        # Update crew member status
        if crew_member.is_injured:
            crew_member.heal_time -= 1
            if crew_member.heal_time <= 0:
                crew_member.is_injured = false
        
        # Process crew member activities
        if crew_member.current_task != null:
            _process_crew_task(crew_member)
    
    emit_signal("crew_updated")

func _process_crew_task(crew_member: CrewMember) -> void:
    if crew_member.current_task == null:
        return
    
    match crew_member.current_task.type:
        "training":
            _process_training_task(crew_member)
        "maintenance":
            _process_maintenance_task(crew_member)
        "research":
            _process_research_task(crew_member)

func _process_training_task(crew_member: CrewMember) -> void:
    crew_member.current_task.progress += 1
    
    if crew_member.current_task.progress >= crew_member.current_task.duration:
        # Complete training
        var skill = crew_member.current_task.skill
        crew_member.skills[skill] = crew_member.skills.get(skill, 0) + 1
        crew_member.current_task = null

func _process_maintenance_task(crew_member: CrewMember) -> void:
    crew_member.current_task.progress += 1
    
    if crew_member.current_task.progress >= crew_member.current_task.duration:
        # Complete maintenance
        resources.supplies += crew_member.current_task.efficiency
        crew_member.current_task = null

func _process_research_task(crew_member: CrewMember) -> void:
    crew_member.current_task.progress += 1
    
    if crew_member.current_task.progress >= crew_member.current_task.duration:
        # Complete research
        story_progress[crew_member.current_task.topic] = true
        crew_member.current_task = null

func advance_time() -> void:
    campaign_day += 1
    _update_location_state()
    emit_signal("campaign_state_changed")

func serialize() -> Dictionary:
    var crew_data = []
    for crew_member in crew_members:
        crew_data.append(crew_member.serialize())
    
    var mission_data = []
    for mission in active_missions:
        mission_data.append(mission.serialize())
    
    var completed_mission_data = []
    for mission in completed_missions:
        completed_mission_data.append(mission.serialize())
    
    return {
        "campaign_day": campaign_day,
        "current_location": current_location.serialize() if current_location else null,
        "available_locations": available_locations.map(func(loc): return loc.serialize()),
        "crew_members": crew_data,
        "resources": resources,
        "active_missions": mission_data,
        "completed_missions": completed_mission_data,
        "available_jobs": available_jobs,
        "story_progress": story_progress,
        "faction_relations": faction_relations
    }

static func deserialize(data: Dictionary) -> CampaignManager:
    var campaign = CampaignManager.new()
    
    campaign.campaign_day = data.get("campaign_day", 1)
    
    if data.has("current_location") and data.current_location != null:
        campaign.current_location = Location.deserialize(data.current_location)
    
    for location_data in data.get("available_locations", []):
        campaign.available_locations.append(Location.deserialize(location_data))
    
    for crew_data in data.get("crew_members", []):
        campaign.crew_members.append(CrewMember.deserialize(crew_data))
    
    campaign.resources = data.get("resources", campaign.resources)
    
    for mission_data in data.get("active_missions", []):
        campaign.active_missions.append(Mission.deserialize(mission_data))
    
    for mission_data in data.get("completed_missions", []):
        campaign.completed_missions.append(Mission.deserialize(mission_data))
    
    campaign.available_jobs = data.get("available_jobs", [])
    campaign.story_progress = data.get("story_progress", {})
    campaign.faction_relations = data.get("faction_relations", {})
    
    return campaign