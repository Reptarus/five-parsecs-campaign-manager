class_name GameStateManager
extends Resource

signal state_changed(new_state: State)
signal tutorial_ended
signal battle_processed(battle_won: bool)

enum State {MAIN_MENU, CREW_CREATION, CAMPAIGN_TURN, MISSION, POST_MISSION}

@export var current_state: State = State.MAIN_MENU
@export var current_crew: Resource = null
@export var current_ship: Resource
@export var current_location: Resource
@export var available_locations: Array[Resource] = []
@export var current_mission: Resource
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
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle
var fringe_world_strife_manager: FringeWorldStrifeManager
var salvage_jobs_manager: SalvageJobsManager
var stealth_missions_manager: StealthMissionsManager
var street_fights_manager: StreetFightsManager
var psionic_manager: PsionicManager
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager

var last_mission_results: String = ""
var crew_size: int = 0
var completed_patron_job_this_turn: bool = false
var held_the_field_against_roving_threat: bool = false
var active_rivals: Array[Rival] = []
var is_tutorial_active: bool = false
var trade_actions_blocked: bool = false
var mission_payout_reduction: int = 0

func _init() -> void:
    pass  # We'll initialize in _ready() instead

func _ready() -> void:
    initialize_managers()

func initialize_managers() -> void:
    mission_generator = MissionGenerator.new()
    expanded_faction_manager = ExpandedFactionManager.new()
    equipment_manager = EquipmentManager.new()
    patron_job_manager = PatronJobManager.new()
    fringe_world_strife_manager = FringeWorldStrifeManager.new()
    salvage_jobs_manager = SalvageJobsManager.new()
    stealth_missions_manager = StealthMissionsManager.new()
    street_fights_manager = StreetFightsManager.new()
    psionic_manager = PsionicManager.new()
    world_generator = WorldGenerator.new()

    # Initialize managers that require a reference to GameStateManager
    var managers_to_initialize = [
        mission_generator, expanded_faction_manager, equipment_manager,
        patron_job_manager, fringe_world_strife_manager, salvage_jobs_manager,
        stealth_missions_manager, street_fights_manager, psionic_manager,
        world_generator
    ]

    for manager in managers_to_initialize:
        if manager.has_method("initialize"):
            manager.initialize(self)

func serialize() -> Dictionary:
    return {
        "current_state": current_state,
        "credits": credits,
        "reputation": reputation,
        "current_crew": current_crew.serialize() if current_crew else null,
        "current_ship": current_ship.serialize() if current_ship else {},
        "current_location": current_location.serialize() if current_location else null,
        "available_locations": available_locations.map(func(loc): return loc.serialize()),
        "current_mission": current_mission.serialize() if current_mission else null,
        "story_points": story_points,
        "campaign_turn": campaign_turn,
        "available_missions": available_missions.map(func(mission): return mission.serialize()),
        "active_quests": active_quests.map(func(quest): return quest.serialize()),
        "patrons": patrons.map(func(patron): return patron.serialize()),
        "rivals": rivals.map(func(rival): return rival.serialize()),
        "character_connections": character_connections,
        "difficulty_settings": difficulty_settings.serialize(),
        "victory_condition": victory_condition,
        "last_mission_results": last_mission_results,
        "crew_size": crew_size,
        "completed_patron_job_this_turn": completed_patron_job_this_turn,
        "held_the_field_against_roving_threat": held_the_field_against_roving_threat,
        "active_rivals": active_rivals.map(func(rival): return rival.serialize()),
        "is_tutorial_active": is_tutorial_active,
        "trade_actions_blocked": trade_actions_blocked,
        "mission_payout_reduction": mission_payout_reduction,
        "fringe_world_strife": fringe_world_strife_manager.serialize(),
        "salvage_jobs": salvage_jobs_manager.serialize(),
        "stealth_missions": stealth_missions_manager.serialize(),
        "street_fights": street_fights_manager.serialize(),
        "psionic_data": psionic_manager.serialize(),
        "story_track": story_track.serialize() if story_track else null,
        "world_data": world_generator.serialize()
    }

func deserialize(data: Dictionary) -> void:
    current_state = data.get("current_state", State.MAIN_MENU)
    credits = data.get("credits", 0)
    reputation = data.get("reputation", 0)
    current_crew = Crew.deserialize(data.get("current_crew", {})) if data.get("current_crew") else null
    current_ship = Ship.deserialize(data.get("current_ship", {})) if data.get("current_ship") else null
    current_location = load(data.get("current_location", "")).new().deserialize(data.get("current_location", {})) if data.get("current_location") else null
    available_locations = data.get("available_locations", []).map(func(loc_data): return load(loc_data.get("resource_path", "")).new().deserialize(loc_data))
    current_mission = Mission.deserialize(data.get("current_mission", {})) if data.get("current_mission") else null
    story_points = data.get("story_points", 0)
    campaign_turn = data.get("campaign_turn", 0)
    available_missions = data.get("available_missions", []).map(func(mission_data): return Mission.deserialize(mission_data))
    active_quests = data.get("active_quests", []).map(func(quest_data): return Quest.deserialize(quest_data))
    patrons = data.get("patrons", []).map(func(patron_data): return Patron.deserialize(patron_data))
    rivals = data.get("rivals", []).map(func(rival_data): return Rival.deserialize(rival_data))
    character_connections = data.get("character_connections", [])
    difficulty_settings = DifficultySettings.deserialize(data.get("difficulty_settings", {}))
    victory_condition = data.get("victory_condition", {})
    last_mission_results = data.get("last_mission_results", "")
    crew_size = data.get("crew_size", 0)
    completed_patron_job_this_turn = data.get("completed_patron_job_this_turn", false)
    held_the_field_against_roving_threat = data.get("held_the_field_against_roving_threat", false)
    active_rivals = data.get("active_rivals", []).map(func(rival_data): return Rival.deserialize(rival_data))
    is_tutorial_active = data.get("is_tutorial_active", false)
    trade_actions_blocked = data.get("trade_actions_blocked", false)
    mission_payout_reduction = data.get("mission_payout_reduction", 0)
    
    fringe_world_strife_manager.deserialize(data.get("fringe_world_strife", {}))
    salvage_jobs_manager.deserialize(data.get("salvage_jobs", {}))
    stealth_missions_manager.deserialize(data.get("stealth_missions", {}))
    street_fights_manager.deserialize(data.get("street_fights", {}))
    psionic_manager = PsionicManager.deserialize(data.get("psionic_data", {}))
    story_track = StoryTrack.deserialize(data.get("story_track", {})) if data.get("story_track") else null
    world_generator.deserialize(data.get("world_data", {}))

func transition_to_state(new_state: State) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func update_mission_list() -> void:
    available_missions = mission_generator.generate_missions(self)

func get_current_location() -> Location:
    return current_location

func get_current_state() -> GameStateManager:
    return self

func set_victory_condition(condition: Dictionary) -> void:
    victory_condition = condition
    # You might want to emit a signal here if other parts of your game need to react to this change
    # emit_signal("victory_condition_changed", victory_condition)

# Add these functions to match CrewManagement.gd functionality
func get_ship_stash() -> Array[Gear]:
    if current_ship and current_ship.inventory:
        return current_ship.inventory.get_items()
    return []

func sort_ship_stash(sort_type: String) -> void:
    if current_ship and current_ship.inventory:
        current_ship.inventory.sort_items(sort_type)

func set_crew_size(size: int) -> void:
    crew_size = size
    if current_crew:
        current_crew.set_max_size(size)

func get_current_crew() -> Crew:
    return current_crew

func add_to_ship_stash(item: Gear) -> bool:
    if current_ship and current_ship.inventory:
        return current_ship.inventory.add_item(item)
    return false

func remove_from_ship_stash(item: Gear) -> bool:
    if current_ship and current_ship.inventory:
        return current_ship.inventory.remove_item(item)
    return false
