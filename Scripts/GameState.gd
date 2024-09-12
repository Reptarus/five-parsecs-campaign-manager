# GameState.gd
class_name GameState
extends Resource

signal state_changed(new_state: State)

enum State {MAIN_MENU, CREW_CREATION, CAMPAIGN_TURN, MISSION, POST_MISSION}

@export var current_state: State = State.MAIN_MENU
@export var current_crew: Resource
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

var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle

func _init() -> void:
	mission_generator = MissionGenerator.new(self)
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new()
	
	call_deferred("_post_init")

func _post_init() -> void:
	mission_generator.set_game_state(self)
	equipment_manager.initialize(self)
	patron_job_manager.initialize(self)

func get_current_battle() -> Battle:
	return current_battle

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

func add_story_point() -> void:
	story_points += 1

func use_story_point() -> bool:
	if story_points > 0:
		story_points -= 1
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

func serialize() -> Dictionary:
	var data = {
		"current_state": current_state,
		"credits": credits,
		"story_points": story_points,
		"campaign_turn": campaign_turn,
		"current_location": null,
		"available_locations": available_locations.map(func(loc): return loc.serialize()),
		"available_missions": available_missions.map(func(mission): return mission.serialize()),
		"active_quests": active_quests.map(func(quest): return quest.serialize()),
		"patrons": patrons.map(func(patron): return patron.serialize()),
		"rivals": rivals.map(func(rival): return rival.serialize())
	}
	if current_crew:
		data["current_crew"] = current_crew.serialize()
	if current_mission:
		data["current_mission"] = current_mission.serialize()
	return data

static func deserialize(data: Dictionary) -> GameState:
	var game_state = GameState.new()
	game_state.current_state = data.get("current_state", State.MAIN_MENU)
	game_state.credits = data.get("credits", 0)
	game_state.story_points = data.get("story_points", 0)
	game_state.campaign_turn = data.get("campaign_turn", 0)
	if data.has("current_location") and data["current_location"] != null:
		game_state.current_location = Location.deserialize(data["current_location"])
	game_state.available_locations = data.get("available_locations", []).map(func(loc_data): return Location.deserialize(loc_data))
	if data.has("current_crew"):
		game_state.current_crew = Crew.deserialize(data["current_crew"])
	if data.has("current_mission"):
		game_state.current_mission = Mission.deserialize(data["current_mission"])
	game_state.available_missions = data.get("available_missions", []).map(func(mission_data): return Mission.deserialize(mission_data))
	game_state.active_quests = data.get("active_quests", []).map(func(quest_data): return Quest.deserialize(quest_data))
	game_state.patrons = data.get("patrons", []).map(func(patron_data): return Patron.deserialize(patron_data))
	game_state.rivals = data.get("rivals", []).map(func(rival_data): return Rival.deserialize(rival_data))
	return game_state
