class_name GameState
extends Resource

signal credits_changed(new_amount: int)
signal story_points_changed(new_amount: int)
signal mission_added(mission: Mission)
signal mission_removed(mission: Mission)
signal state_changed(new_state: State)

enum State { MAIN_MENU, CREW_CREATION, CAMPAIGN_TURN, MISSION, COMBAT }
enum DifficultyMode { NORMAL, HARDCORE, INSANITY }

const INITIAL_CREDITS: int = 1000
const INITIAL_STORY_POINTS: int = 3
const MAX_ACTIVE_MISSIONS: int = 5

@export var campaign_name: String
@export var current_crew: Crew = Crew.new(&"Default Crew")
@export var current_ship: Ship
@export var patrons: Array[Patron] = []
@export var available_missions: Array[Mission] = []
@export var current_mission: Mission
@export var current_turn: int = 0
@export var credits: int = INITIAL_CREDITS:
	set(value):
		credits = value
		credits_changed.emit(credits)
@export var story_points: int = INITIAL_STORY_POINTS:
	set(value):
		story_points = value
		story_points_changed.emit(story_points)
@export var current_state: State = State.MAIN_MENU:
	set(value):
		current_state = value
		state_changed.emit(current_state)
@export var difficulty_mode: DifficultyMode = DifficultyMode.NORMAL
@export var current_location: Location
@export var victory_condition: VictoryConditionSelection
@export var flavor_details: Dictionary

# Campaign setup options
@export var use_introductory_campaign: bool = false
@export var use_loans: bool = false
@export var use_story_track: bool = false
@export var use_expanded_factions: bool = false
@export var use_progressive_difficulty: bool = false
@export var use_fringe_world_strife: bool = false
@export var use_dramatic_combat: bool = false
@export var use_casualty_tables: bool = false
@export var use_detailed_post_battle_injuries: bool = false
@export var use_ai_variations: bool = false
@export var use_enemy_deployment_variables: bool = false
@export var use_escalating_battles: bool = false
@export var use_elite_level_enemies: bool = false
@export var use_expanded_missions: bool = false
@export var use_expanded_quest_progression: bool = false
@export var use_expanded_connections: bool = false

var patron_job_manager: PatronJobManager
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var combat_manager: CombatManager

func _init() -> void:
	patron_job_manager = PatronJobManager.new(self)
	mission_generator = MissionGenerator.new(self)
	equipment_manager = EquipmentManager.new()
	combat_manager = CombatManager.new()

func start_new_campaign(crew_name: String, ship: Ship) -> void:
	campaign_name = crew_name
	current_crew = Crew.new(crew_name)
	current_ship = ship
	credits = INITIAL_CREDITS
	story_points = INITIAL_STORY_POINTS
	current_turn = 0
	
	apply_difficulty_settings()
	initialize_systems()

func apply_difficulty_settings() -> void:
	match difficulty_mode:
		DifficultyMode.NORMAL:
			# Apply normal difficulty settings
			pass
		DifficultyMode.HARDCORE:
			# Apply hardcore difficulty settings
			pass
		DifficultyMode.INSANITY:
			# Apply insanity difficulty settings
			pass

func initialize_systems() -> void:
	patron_job_manager.initialize()
	mission_generator.initialize()
	combat_manager.initialize()

func add_patron(patron: Patron) -> void:
	patrons.append(patron)

func remove_patron(patron: Patron) -> void:
	patrons.erase(patron)

func add_available_mission(mission: Mission) -> void:
	if available_missions.size() < MAX_ACTIVE_MISSIONS:
		available_missions.append(mission)
		mission_added.emit(mission)
	else:
		push_warning("Maximum number of active missions reached. Cannot add more.")

func remove_available_mission(mission: Mission) -> void:
	if available_missions.has(mission):
		available_missions.erase(mission)
		mission_removed.emit(mission)

func add_credits(amount: int) -> void:
	credits += amount

func remove_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		return true
	return false

func add_story_points(amount: int) -> void:
	story_points += amount

func remove_story_points(amount: int) -> bool:
	if story_points >= amount:
		story_points -= amount
		return true
	return false

func get_all_locations() -> Array[Location]:
	# TODO: Implement this method to return all available locations in the game
	push_warning("get_all_locations() not implemented yet")
	return []

func advance_turn() -> void:
	current_turn += 1
	patron_job_manager.update_job_timers()
	patron_job_manager.generate_patron_jobs()
	current_ship.process_turn()
	
	if use_progressive_difficulty:
		apply_difficulty_settings()

func change_state(new_state: State) -> void:
	current_state = new_state

func serialize() -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"current_crew": current_crew.serialize(),
		"current_ship": current_ship.serialize(),
		"patrons": patrons.map(func(p): return p.serialize()),
		"available_missions": available_missions.map(func(m): return m.serialize()),
		"current_mission": current_mission.serialize() if current_mission else null,
		"current_turn": current_turn,
		"credits": credits,
		"story_points": story_points,
		"current_state": current_state,
		"difficulty_mode": difficulty_mode,
		"current_location": current_location.serialize() if current_location else null,
		"victory_condition": victory_condition.serialize(),
		"flavor_details": flavor_details,
		"use_introductory_campaign": use_introductory_campaign,
		"use_loans": use_loans,
		"use_story_track": use_story_track,
		"use_expanded_factions": use_expanded_factions,
		"use_progressive_difficulty": use_progressive_difficulty,
		"use_fringe_world_strife": use_fringe_world_strife,
		"use_dramatic_combat": use_dramatic_combat,
		"use_casualty_tables": use_casualty_tables,
		"use_detailed_post_battle_injuries": use_detailed_post_battle_injuries,
		"use_ai_variations": use_ai_variations,
		"use_enemy_deployment_variables": use_enemy_deployment_variables,
		"use_escalating_battles": use_escalating_battles,
		"use_elite_level_enemies": use_elite_level_enemies,
		"use_expanded_missions": use_expanded_missions,
		"use_expanded_quest_progression": use_expanded_quest_progression,
		"use_expanded_connections": use_expanded_connections
	}

static func deserialize(data: Dictionary) -> GameState:
	var game_state = GameState.new()
	game_state.campaign_name = data["campaign_name"]
	game_state.current_crew = Crew.new().deserialize(data["current_crew"])
	game_state.current_ship = Ship.new().deserialize(data["current_ship"])
	game_state.patrons = data["patrons"].map(func(p): return Patron.new().deserialize(p))
	game_state.available_missions = data["available_missions"].map(func(m): return Mission.new().deserialize(m))
	game_state.current_mission = Mission.new().deserialize(data["current_mission"]) if data["current_mission"] else null
	game_state.current_turn = data["current_turn"]
	game_state.credits = data["credits"]
	game_state.story_points = data["story_points"]
	game_state.current_state = data["current_state"]
	game_state.difficulty_mode = data["difficulty_mode"]
	game_state.current_location = Location.new().deserialize(data["current_location"]) if data["current_location"] else null
	game_state.victory_condition = VictoryConditionSelection.new().deserialize(data["victory_condition"])
	game_state.flavor_details = data["flavor_details"]
	game_state.use_introductory_campaign = data["use_introductory_campaign"]
	game_state.use_loans = data["use_loans"]
	game_state.use_story_track = data["use_story_track"]
	game_state.use_expanded_factions = data["use_expanded_factions"]
	game_state.use_progressive_difficulty = data["use_progressive_difficulty"]
	game_state.use_fringe_world_strife = data["use_fringe_world_strife"]
	game_state.use_dramatic_combat = data["use_dramatic_combat"]
	game_state.use_casualty_tables = data["use_casualty_tables"]
	game_state.use_detailed_post_battle_injuries = data["use_detailed_post_battle_injuries"]
	game_state.use_ai_variations = data["use_ai_variations"]
	game_state.use_enemy_deployment_variables = data["use_enemy_deployment_variables"]
	game_state.use_escalating_battles = data["use_escalating_battles"]
	game_state.use_elite_level_enemies = data["use_elite_level_enemies"]
	game_state.use_expanded_missions = data["use_expanded_missions"]
	game_state.use_expanded_quest_progression = data["use_expanded_quest_progression"]
	game_state.use_expanded_connections = data["use_expanded_connections"]
	return game_state
