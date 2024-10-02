class_name GameState
extends Resource

@export var current_state: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.MAIN_MENU
@export var current_crew: Crew
@export var current_ship: Ship
@export var current_location: Location
@export var available_locations: Array[Location] = []
@export var current_mission: Mission
@export var credits: int = 0
@export var story_points: int = 0
@export var campaign_turn: int = 0
@export var available_missions: Array[Mission] = []
@export var active_quests: Array[Quest] = []
@export var patrons: Array[Patron] = []
@export var rivals: Array[Rival] = []
@export var character_connections: Array = []
@export var difficulty_settings: DifficultySettings
@export var victory_condition: Dictionary

var reputation: int = 0
var last_mission_results: String = ""
var crew_size: int = 0
var completed_patron_job_this_turn: bool = false
var held_the_field_against_roving_threat: bool = false
var active_rivals: Array[Rival] = []
var is_tutorial_active: bool = false
var trade_actions_blocked: bool = false
var mission_payout_reduction: int = 0

func serialize() -> Dictionary:
    var serialized_data = {
        "current_state": current_state,
        "credits": credits,
        "story_points": story_points,
        "campaign_turn": campaign_turn,
        "reputation": reputation,
        "last_mission_results": last_mission_results,
        "crew_size": crew_size,
        "completed_patron_job_this_turn": completed_patron_job_this_turn,
        "held_the_field_against_roving_threat": held_the_field_against_roving_threat,
        "is_tutorial_active": is_tutorial_active,
        "trade_actions_blocked": trade_actions_blocked,
        "mission_payout_reduction": mission_payout_reduction,
    }
    
    # Serialize complex objects
    if current_crew:
        serialized_data["current_crew"] = current_crew.serialize()
    if current_ship:
        serialized_data["current_ship"] = current_ship.serialize()
    if current_location:
        serialized_data["current_location"] = current_location.serialize()
    if current_mission:
        serialized_data["current_mission"] = current_mission.serialize()
    
    # Serialize arrays of complex objects
    serialized_data["available_locations"] = [loc.serialize() for loc in available_locations]
    serialized_data["available_missions"] = [mission.serialize() for mission in available_missions]
    serialized_data["active_quests"] = [quest.serialize() for quest in active_quests]
    serialized_data["patrons"] = [patron.serialize() for patron in patrons]
    serialized_data["rivals"] = [rival.serialize() for rival in rivals]
    serialized_data["active_rivals"] = [rival.serialize() for rival in active_rivals]
    
    # Serialize other complex types
    if difficulty_settings:
        serialized_data["difficulty_settings"] = difficulty_settings.serialize()
    serialized_data["victory_condition"] = victory_condition.duplicate()
    serialized_data["character_connections"] = character_connections.duplicate()
    
    return serialized_data

func deserialize(data: Dictionary) -> void:
    current_state = data.get("current_state", GlobalEnums.CampaignPhase.MAIN_MENU)
    credits = data.get("credits", 0)
    story_points = data.get("story_points", 0)
    campaign_turn = data.get("campaign_turn", 0)
    reputation = data.get("reputation", 0)
    last_mission_results = data.get("last_mission_results", "")
    crew_size = data.get("crew_size", 0)
    completed_patron_job_this_turn = data.get("completed_patron_job_this_turn", false)
    held_the_field_against_roving_threat = data.get("held_the_field_against_roving_threat", false)
    is_tutorial_active = data.get("is_tutorial_active", false)
    trade_actions_blocked = data.get("trade_actions_blocked", false)
    mission_payout_reduction = data.get("mission_payout_reduction", 0)
    
    # Deserialize complex objects
    if "current_crew" in data:
        current_crew = Crew.new()
        current_crew.deserialize(data["current_crew"])
    if "current_ship" in data:
        current_ship = Ship.new()
        current_ship.deserialize(data["current_ship"])
    if "current_location" in data:
        current_location = Location.new()
        current_location.deserialize(data["current_location"])
    if "current_mission" in data:
        current_mission = Mission.new()
        current_mission.deserialize(data["current_mission"])
    
    # Deserialize arrays of complex objects
    available_locations = []
    for loc_data in data.get("available_locations", []):
        var loc = Location.new()
        loc.deserialize(loc_data)
        available_locations.append(loc)
    
    available_missions = []
    for mission_data in data.get("available_missions", []):
        var mission = Mission.new()
        mission.deserialize(mission_data)
        available_missions.append(mission)
    
    active_quests = []
    for quest_data in data.get("active_quests", []):
        var quest = Quest.new()
        quest.deserialize(quest_data)
        active_quests.append(quest)
    
    patrons = []
    for patron_data in data.get("patrons", []):
        var patron = Patron.new()
        patron.deserialize(patron_data)
        patrons.append(patron)
    
    rivals = []
    for rival_data in data.get("rivals", []):
        var rival = Rival.new()
        rival.deserialize(rival_data)
        rivals.append(rival)
    
    active_rivals = []
    for rival_data in data.get("active_rivals", []):
        var rival = Rival.new()
        rival.deserialize(rival_data)
        active_rivals.append(rival)
    
    # Deserialize other complex types
    if "difficulty_settings" in data:
        difficulty_settings = DifficultySettings.new()
        difficulty_settings.deserialize(data["difficulty_settings"])
    victory_condition = data.get("victory_condition", {})
    character_connections = data.get("character_connections", [])