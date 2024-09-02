class_name GameState
extends Resource

signal state_changed(new_state: State)

enum State { MAIN_MENU, CREW_CREATION, CAMPAIGN_TURN, MISSION, POST_MISSION }
enum DifficultyMode { NORMAL, HARDCORE, INSANITY }

@export var current_state: State = State.MAIN_MENU
@export var current_crew: Crew
@export var current_location: Location
@export var current_mission: Mission
@export var credits: int = 0
@export var story_points: int = 0
@export var campaign_turn: int = 0
@export var available_missions: Array[Mission] = []
@export var active_quests: Array[Quest] = []
@export var patrons: Array[Patron] = []
@export var rivals: Array[Rival] = []
@export var difficulty_mode: DifficultyMode = DifficultyMode.NORMAL

var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var campaign_event_generator: CampaignEventGenerator
var loot_generator: LootGenerator
var economy_manager: EconomyManager
var terrain_generator: TerrainGenerator

func _init() -> void:
	mission_generator = MissionGenerator.new()
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new(self)
	campaign_event_generator = CampaignEventGenerator.new()
	loot_generator = LootGenerator.new(self)
	economy_manager = EconomyManager.new(self)
	terrain_generator = TerrainGenerator.new()

func change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)

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

func advance_turn() -> void:
	campaign_turn += 1

func add_mission(mission: Mission) -> void:
	available_missions.append(mission)

func remove_mission(mission: Mission) -> void:
	available_missions.erase(mission)

func add_quest(quest: Quest) -> void:
	active_quests.append(quest)

func remove_quest(quest: Quest) -> void:
	active_quests.erase(quest)

func add_patron(patron: Patron) -> void:
	patrons.append(patron)

func remove_patron(patron: Patron) -> void:
	patrons.erase(patron)

func add_rival(rival: Rival) -> void:
	rivals.append(rival)

func remove_rival(rival: Rival) -> void:
	rivals.erase(rival)

func get_all_locations() -> Array[Location]:
	# Implement logic to return all available locations
	return []

func generate_battlefield() -> Dictionary:
	return terrain_generator.generate_battlefield()

func get_terrain_placement_suggestions() -> String:
	return terrain_generator.get_terrain_placement_suggestions()

func get_setup_instructions() -> String:
	return terrain_generator.get_setup_instructions()

# Serialization methods
func serialize() -> Dictionary:
	var data := {
		"current_state": current_state,
		"credits": credits,
		"story_points": story_points,
		"campaign_turn": campaign_turn,
		"difficulty_mode": difficulty_mode,
		# Add other properties as needed
	}
	if current_crew:
		data["current_crew"] = current_crew.serialize()
	if current_location:
		data["current_location"] = current_location.serialize()
	if current_mission:
		data["current_mission"] = current_mission.serialize()
	data["available_missions"] = available_missions.map(func(m): return m.serialize())
	data["active_quests"] = active_quests.map(func(q): return q.serialize())
	data["patrons"] = patrons.map(func(p): return p.serialize())
	data["rivals"] = rivals.map(func(r): return r.serialize())
	return data

static func deserialize(data: Dictionary) -> GameState:
	var game_state := GameState.new()
	game_state.current_state = data["current_state"]
	game_state.credits = data["credits"]
	game_state.story_points = data["story_points"]
	game_state.campaign_turn = data["campaign_turn"]
	game_state.difficulty_mode = data["difficulty_mode"]
	if data.has("current_crew"):
		game_state.current_crew = Crew.deserialize(data["current_crew"])
	if data.has("current_location"):
		game_state.current_location = Location.deserialize(data["current_location"])
	if data.has("current_mission"):
		game_state.current_mission = Mission.deserialize(data["current_mission"])
	game_state.available_missions = data["available_missions"].map(func(m): return Mission.deserialize(m))
	game_state.active_quests = data["active_quests"].map(func(q): return Quest.deserialize(q))
	game_state.patrons = data["patrons"].map(func(p): return Patron.deserialize(p))
	game_state.rivals = data["rivals"].map(func(r): return Rival.deserialize(r))
	return game_state
