class_name GameState
extends Resource

signal state_changed(new_state: State)
signal credits_changed(new_amount: int)
signal story_points_changed(new_amount: int)

enum State { MAIN_MENU, CREW_CREATION, CAMPAIGN_TURN, MISSION, POST_MISSION }

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

var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var campaign_event_generator: CampaignEvent
var loot_generator: LootGenerator
var economy_manager: EconomyManager
var difficulty_settings: DifficultySettings

func _init():
	mission_generator = MissionGenerator.new()
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new(self)
	campaign_event_generator = CampaignEvent.new()
	loot_generator = LootGenerator.new(self)
	economy_manager = EconomyManager.new(self)
	difficulty_settings = DifficultySettings.new()

func change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)

func remove_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		credits_changed.emit(credits)
		return true
	return false

func add_story_points(amount: int) -> void:
	story_points += amount
	story_points_changed.emit(story_points)

func remove_story_points(amount: int) -> bool:
	if story_points >= amount:
		story_points -= amount
		story_points_changed.emit(story_points)
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
	# This method should return all available locations
	# Implement the logic to generate or retrieve locations
	return []

func serialize() -> Dictionary:
	return {
		"current_state": current_state,
		"current_crew": current_crew.serialize() if current_crew else null,
		"current_location": current_location.serialize() if current_location else null,
		"current_mission": current_mission.serialize() if current_mission else null,
		"credits": credits,
		"story_points": story_points,
		"campaign_turn": campaign_turn,
		"available_missions": available_missions.map(func(m): return m.serialize()),
		"active_quests": active_quests.map(func(q): return q.serialize()),
		"patrons": patrons.map(func(p): return p.serialize()),
		"rivals": rivals.map(func(r): return r.serialize()),
	}

static func deserialize(data: Dictionary) -> GameState:
	var game_state = GameState.new()
	game_state.current_state = data["current_state"]
	game_state.current_crew = Crew.deserialize(data["current_crew"]) if data["current_crew"] else null
	game_state.current_location = Location.deserialize(data["current_location"]) if data["current_location"] else null
	game_state.current_mission = Mission.deserialize(data["current_mission"]) if data["current_mission"] else null
	game_state.credits = data["credits"]
	game_state.story_points = data["story_points"]
	game_state.campaign_turn = data["campaign_turn"]
	game_state.available_missions = data["available_missions"].map(func(m): return Mission.deserialize(m))
	game_state.active_quests = data["active_quests"].map(func(q): return Quest.deserialize(q))
	game_state.patrons = data["patrons"].map(func(p): return Patron.deserialize(p))
	game_state.rivals = data["rivals"].map(func(r): return Rival.deserialize(r))
	return game_state
