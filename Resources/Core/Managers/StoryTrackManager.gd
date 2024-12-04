class_name StoryTrackManager
extends Resource

signal story_updated
signal rumor_discovered
signal story_milestone_reached

const STORY_TRACKS = {
    "main_plot": {
        "name": "Main Campaign",
        "stages": 5,
        "requirements": {
            "reputation": 5,
            "missions_completed": 10
        }
    },
    "faction_war": {
        "name": "Faction Conflict",
        "stages": 3,
        "requirements": {
            "reputation": 3,
            "faction_missions": 5
        }
    },
    "tech_discovery": {
        "name": "Ancient Technology",
        "stages": 4,
        "requirements": {
            "reputation": 4,
            "exploration_missions": 8
        }
    }
}

# Story State
var active_tracks: Dictionary = {}
var completed_tracks: Array[String] = []
var current_objectives: Dictionary = {}
var story_flags: Dictionary = {}

# Rumor System
var active_rumors: Array[Dictionary] = []
var verified_rumors: Array[Dictionary] = []
var rumor_sources: Dictionary = {}
var rumor_connections: Dictionary = {}

func _init() -> void:
    _initialize_story_system()

func _initialize_story_system() -> void:
    # Initialize story tracks
    for track_id in STORY_TRACKS:
        active_tracks[track_id] = {
            "progress": 0,
            "current_stage": 0,
            "unlocked": false
        }
    
    # Initialize rumor sources
    rumor_sources = {
        "tavern": {
            "reliability": 0.7,
            "cost": 50,
            "cooldown": 3
        },
        "informant": {
            "reliability": 0.9,
            "cost": 100,
            "cooldown": 5
        },
        "street": {
            "reliability": 0.5,
            "cost": 0,
            "cooldown": 1
        },
        "merchant": {
            "reliability": 0.8,
            "cost": 75,
            "cooldown": 4
        }
    }

func check_story_progress(campaign_state: Dictionary) -> void:
    for track_id in active_tracks:
        if not active_tracks[track_id].unlocked:
            _check_track_requirements(track_id, campaign_state)
        else:
            _update_track_progress(track_id, campaign_state)

func _check_track_requirements(track_id: String, campaign_state: Dictionary) -> void:
    var track = STORY_TRACKS[track_id]
    var requirements = track.requirements
    
    var meets_requirements = true
    for req in requirements:
        match req:
            "reputation":
                if campaign_state.get("reputation", 0) < requirements[req]:
                    meets_requirements = false
            "missions_completed":
                if campaign_state.get("completed_missions", []).size() < requirements[req]:
                    meets_requirements = false
            "faction_missions":
                var faction_missions = campaign_state.get("completed_missions", []).filter(
                    func(mission): return mission.type == "faction"
                )
                if faction_missions.size() < requirements[req]:
                    meets_requirements = false
            "exploration_missions":
                var exploration_missions = campaign_state.get("completed_missions", []).filter(
                    func(mission): return mission.type == "exploration"
                )
                if exploration_missions.size() < requirements[req]:
                    meets_requirements = false
    
    if meets_requirements:
        active_tracks[track_id].unlocked = true
        emit_signal("story_updated")

func _update_track_progress(track_id: String, campaign_state: Dictionary) -> void:
    var track = active_tracks[track_id]
    var track_data = STORY_TRACKS[track_id]
    
    # Check for progress triggers
    var new_progress = _calculate_track_progress(track_id, campaign_state)
    
    if new_progress > track.progress:
        track.progress = new_progress
        
        # Check for stage completion
        var new_stage = floori(track.progress / (100.0 / track_data.stages))
        if new_stage > track.current_stage:
            track.current_stage = new_stage
            emit_signal("story_milestone_reached", track_id, new_stage)
        
        emit_signal("story_updated")

func _calculate_track_progress(track_id: String, campaign_state: Dictionary) -> int:
    var progress = active_tracks[track_id].progress
    
    # Calculate progress based on track-specific conditions
    match track_id:
        "main_plot":
            progress = _calculate_main_plot_progress(campaign_state)
        "faction_war":
            progress = _calculate_faction_war_progress(campaign_state)
        "tech_discovery":
            progress = _calculate_tech_discovery_progress(campaign_state)
    
    return progress

func _calculate_main_plot_progress(campaign_state: Dictionary) -> int:
    var progress = 0
    
    # Factor in story flags
    for flag in story_flags:
        if flag.begins_with("main_plot_"):
            progress += 10
    
    # Factor in reputation
    progress += mini(campaign_state.get("reputation", 0) * 5, 25)
    
    # Factor in completed missions
    progress += mini(campaign_state.get("completed_missions", []).size() * 2, 25)
    
    return mini(progress, 100)

func _calculate_faction_war_progress(campaign_state: Dictionary) -> int:
    var progress = 0
    
    # Factor in faction missions
    var faction_missions = campaign_state.get("completed_missions", []).filter(
        func(mission): return mission.type == "faction"
    )
    progress += mini(faction_missions.size() * 10, 50)
    
    # Factor in faction relations
    for faction in campaign_state.get("faction_relations", {}):
        if campaign_state.faction_relations[faction] >= 5:
            progress += 10
    
    return mini(progress, 100)

func _calculate_tech_discovery_progress(campaign_state: Dictionary) -> int:
    var progress = 0
    
    # Factor in exploration missions
    var exploration_missions = campaign_state.get("completed_missions", []).filter(
        func(mission): return mission.type == "exploration"
    )
    progress += mini(exploration_missions.size() * 8, 40)
    
    # Factor in discovered artifacts
    progress += mini(story_flags.get("artifacts_found", 0) * 15, 60)
    
    return mini(progress, 100)

# Rumor Management
func gather_rumors(source: String, campaign_state: Dictionary) -> Array[Dictionary]:
    if not rumor_sources.has(source):
        return []
    
    var source_data = rumor_sources[source]
    var new_rumors: Array[Dictionary] = []
    
    # Check if we can gather rumors from this source
    if source_data.get("last_used", 0) + source_data.cooldown > campaign_state.campaign_day:
        return []
    
    # Generate new rumors
    var rumor_count = 1 + randi() % 3  # 1-3 rumors per gathering
    for i in range(rumor_count):
        var rumor = _generate_rumor(source, campaign_state)
        if rumor != null:
            new_rumors.append(rumor)
            active_rumors.append(rumor)
            emit_signal("rumor_discovered", rumor)
    
    # Update source cooldown
    rumor_sources[source].last_used = campaign_state.campaign_day
    
    return new_rumors

func _generate_rumor(source: String, campaign_state: Dictionary) -> Dictionary:
    var source_data = rumor_sources[source]
    var rumor_types = ["story", "location", "resource", "threat"]
    var selected_type = rumor_types[randi() % rumor_types.size()]
    
    var rumor = {
        "id": "rumor_" + str(randi()),
        "type": selected_type,
        "source": source,
        "reliability": source_data.reliability,
        "verified": false,
        "discovered_day": campaign_state.campaign_day
    }
    
    # Generate rumor content based on type
    match selected_type:
        "story":
            rumor.merge(_generate_story_rumor(campaign_state))
        "location":
            rumor.merge(_generate_location_rumor(campaign_state))
        "resource":
            rumor.merge(_generate_resource_rumor(campaign_state))
        "threat":
            rumor.merge(_generate_threat_rumor(campaign_state))
    
    return rumor

func _generate_story_rumor(campaign_state: Dictionary) -> Dictionary:
    var active_track_ids = active_tracks.keys().filter(
        func(track_id): return active_tracks[track_id].unlocked
    )
    
    if active_track_ids.is_empty():
        return {}
    
    var track_id = active_track_ids[randi() % active_track_ids.size()]
    var track = active_tracks[track_id]
    
    return {
        "track_id": track_id,
        "content": "Information about " + STORY_TRACKS[track_id].name,
        "value": 100 + track.current_stage * 50,
        "leads_to": _generate_story_leads(track_id)
    }

func _generate_location_rumor(campaign_state: Dictionary) -> Dictionary:
    var location_types = ["resource_rich", "dangerous", "mysterious", "populated"]
    var location_type = location_types[randi() % location_types.size()]
    
    return {
        "location_type": location_type,
        "content": "Rumors of a " + location_type + " location",
        "value": 75 + randi() % 76,
        "coordinates": Vector2(randi() % 100, randi() % 100)
    }

func _generate_resource_rumor(campaign_state: Dictionary) -> Dictionary:
    var resource_types = ["fuel", "supplies", "credits", "equipment"]
    var resource_type = resource_types[randi() % resource_types.size()]
    
    return {
        "resource_type": resource_type,
        "content": "Information about valuable " + resource_type,
        "value": 50 + randi() % 151,
        "quantity": 10 + randi() % 91
    }

func _generate_threat_rumor(campaign_state: Dictionary) -> Dictionary:
    var threat_types = ["pirates", "hostile_faction", "natural_hazard", "unknown"]
    var threat_type = threat_types[randi() % threat_types.size()]
    
    return {
        "threat_type": threat_type,
        "content": "Warning about " + threat_type,
        "value": 100 + randi() % 201,
        "severity": 1 + randi() % 5
    }

func _generate_story_leads(track_id: String) -> Array:
    var leads = []
    var possible_leads = ["location", "character", "item", "event"]
    
    var lead_count = 1 + randi() % 3
    for i in range(lead_count):
        var lead_type = possible_leads[randi() % possible_leads.size()]
        leads.append({
            "type": lead_type,
            "importance": 1 + randi() % 3
        })
    
    return leads

func verify_rumor(rumor_id: String, campaign_state: Dictionary) -> bool:
    var rumor = active_rumors.filter(func(r): return r.id == rumor_id)
    if rumor.is_empty():
        return false
    
    rumor = rumor[0]
    var verification_chance = rumor.reliability
    
    # Adjust based on crew skills
    for crew_member in campaign_state.get("crew_members", []):
        if crew_member.has_skill("investigation"):
            verification_chance += 0.1
    
    # Attempt verification
    if randf() <= verification_chance:
        rumor.verified = true
        verified_rumors.append(rumor)
        active_rumors.erase(rumor)
        
        # Add to story progress if relevant
        if rumor.type == "story":
            story_flags["verified_rumor_" + rumor.track_id] = true
        
        emit_signal("story_updated")
        return true
    
    return false

func get_connected_rumors(rumor_id: String) -> Array:
    if not rumor_connections.has(rumor_id):
        return []
    
    return rumor_connections[rumor_id]

func connect_rumors(rumor_id1: String, rumor_id2: String) -> void:
    if not rumor_connections.has(rumor_id1):
        rumor_connections[rumor_id1] = []
    if not rumor_connections.has(rumor_id2):
        rumor_connections[rumor_id2] = []
    
    if not rumor_id2 in rumor_connections[rumor_id1]:
        rumor_connections[rumor_id1].append(rumor_id2)
    if not rumor_id1 in rumor_connections[rumor_id2]:
        rumor_connections[rumor_id2].append(rumor_id1)

func serialize() -> Dictionary:
    return {
        "active_tracks": active_tracks,
        "completed_tracks": completed_tracks,
        "current_objectives": current_objectives,
        "story_flags": story_flags,
        "active_rumors": active_rumors,
        "verified_rumors": verified_rumors,
        "rumor_sources": rumor_sources,
        "rumor_connections": rumor_connections
    }

static func deserialize(data: Dictionary) -> StoryTrackManager:
    var manager = StoryTrackManager.new()
    
    manager.active_tracks = data.get("active_tracks", {})
    manager.completed_tracks = data.get("completed_tracks", [])
    manager.current_objectives = data.get("current_objectives", {})
    manager.story_flags = data.get("story_flags", {})
    manager.active_rumors = data.get("active_rumors", [])
    manager.verified_rumors = data.get("verified_rumors", [])
    manager.rumor_sources = data.get("rumor_sources", {})
    manager.rumor_connections = data.get("rumor_connections", {})
    
    return manager