# GameState.gd
class_name GameState
extends Node

signal state_changed(new_state: State)

enum State {MAIN_MENU, CREW_CREATION, CAMPAIGN_TURN, MISSION, POST_MISSION}
enum DamageType {HULL, SYSTEMS, CREW}

@export var current_state: State = State.MAIN_MENU
@export var current_crew: Crew
@export var current_ship: Ship
@export var current_location: Resource
@export var available_locations: Array[Resource] = []
@export var current_mission: Mission
@export var credits: int = 0
@export var story_points: int = 0
@export var campaign_turn: int = 0
@export var available_missions: Array[Mission] = []
@export var active_quests: Array[Quest] = []
@export var patrons: Array[Patron] = []
@export var rivals: Array[Rival] = []
@export var character_connections: Array = []

var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle

var ship_stash: Array[Item] = []
var last_mission_results: String = ""

# New managers
const FringeWorldStrifeManagerScript = preload("res://Scripts/Missions/FringeWorldStrifeManager.gd")
const SalvageJobsManagerScript = preload("res://Scripts/Missions/SalvageJobsManager.gd")
const StealthMissionsManagerScript = preload("res://Scripts/Missions/StealthMissionsManager.gd")
const CharacterScript = preload("res://Scripts/Characters/Character.gd")
const MissionScript = preload("res://Scripts/Missions/Mission.gd")

var fringe_world_strife_manager: FringeWorldStrifeManagerScript
var salvage_jobs_manager: SalvageJobsManagerScript
var stealth_missions_manager: StealthMissionsManagerScript
var street_fights_manager: StreetFightsManager
var psionic_manager: PsionicManager

# New properties
var crew_size: int = 0
var table_size: Vector2 = Vector2(48, 48)  # Default table size in inches
var completed_patron_job_this_turn: bool = false
var held_the_field_against_roving_threat: bool = false
var active_rivals: Array[Rival] = []

var story_track: StoryTrack
var is_tutorial_active: bool = false

var trade_actions_blocked: bool = false
var mission_payout_reduction: int = 0

var quest_rumors: Array[QuestRumor] = []

static var instance: GameState

func _ready():
	instance = self

func _init() -> void:
	mission_generator = MissionGenerator.new()
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new()
	
	fringe_world_strife_manager = FringeWorldStrifeManagerScript.new(self)
	salvage_jobs_manager = SalvageJobsManagerScript.new(self)
	stealth_missions_manager = StealthMissionsManagerScript.new(self)
	street_fights_manager = StreetFightsManager.new(self)
	psionic_manager = PsionicManager.new()
	
	call_deferred("_post_init")

func _post_init() -> void:
	mission_generator.initialize(self)
	patron_job_manager.initialize(self)
	equipment_manager.initialize(self)

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
	completed_patron_job_this_turn = false
	held_the_field_against_roving_threat = false
	update_quest_rumors()
	# Potentially generate new quest rumors here
	if randf() < 0.3:  # 30% chance each turn
		add_quest_rumor()

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

func remove_rival(rival: Rival) -> void:
	rivals.erase(rival)
	active_rivals.erase(rival)

func set_current_crew(crew: Crew):
	current_crew = crew
	crew_size = crew.members.size()

func get_current_crew() -> Crew:
	return current_crew

func add_to_ship_stash(item: Item):
	ship_stash.append(item)

func remove_from_ship_stash(item: Item):
	ship_stash.erase(item)

func get_ship_stash() -> Array[Item]:
	return ship_stash

func sort_ship_stash(sort_type: String):
	match sort_type:
		"name":
			ship_stash.sort_custom(func(a, b): return a.name < b.name)
		"recency":
			ship_stash.sort_custom(func(a, b): return a.acquisition_time > b.acquisition_time)
		"type":
			ship_stash.sort_custom(func(a, b): return a.type < b.type)

func set_last_mission_results(results: String):
	last_mission_results = results

func get_random_location() -> Resource:
	if available_locations.size() > 0:
		return available_locations[randi() % available_locations.size()]
	return null

func damage_ship(amount: int) -> void:
	if current_ship:
		if current_ship.has_method("take_damage"):
			current_ship.call("take_damage", amount)
		else:
			push_warning("Ship does not have a take_damage method")
	else:
		push_warning("No current ship to damage")

func repair_ship(amount: int = 100) -> void:
	if current_ship:
		current_ship.repair(amount)

func add_ship_module() -> void:
	if current_ship:
		var new_component = ShipComponent.new("New Component", "A new ship component", GlobalEnums.ComponentType.ENGINE, 1, 1)
		current_ship.add_component(new_component)

func upgrade_bot() -> void:
	var bot = current_crew.get_bot() if current_crew else null
	if bot:
		var upgrade_options = ["Armor", "Weapon", "Mobility", "Sensors"]
		var chosen_upgrade = upgrade_options[randi() % upgrade_options.size()]
		bot.apply_upgrade(chosen_upgrade)
		print_debug("Bot upgraded: %s" % chosen_upgrade)

func add_quest_rumor() -> void:
	var rumor_type = QuestRumor.RumorType.values()[randi() % QuestRumor.RumorType.size()]
	var title = "Mysterious " + ["Artifact", "Signal", "Distress Call", "Anomaly"][randi() % 4]
	var description = "Reports of a " + title.to_lower() + " in a nearby sector."
	var difficulty = randi() % 5 + 1  # 1 to 5
	var reward_estimate = difficulty * 100  # Simple scaling based on difficulty
	var expiration_turns = randi() % 5 + 3  # 3 to 7 turns
	
	var new_rumor = QuestRumor.new(rumor_type, title, description, difficulty, reward_estimate, expiration_turns)
	quest_rumors.append(new_rumor)
	print_debug("New quest rumor added: " + title)

func remove_quest_rumor(rumor: QuestRumor) -> void:
	quest_rumors.erase(rumor)

func update_quest_rumors() -> void:
	for rumor in quest_rumors:
		if rumor.is_expired(campaign_turn):
			remove_quest_rumor(rumor)

func generate_quest_from_rumor(rumor: QuestRumor) -> void:
	var new_quest = rumor.generate_quest(self)
	if new_quest:
		add_quest(new_quest)
		remove_quest_rumor(rumor)

func discover_quest_rumor(rumor: QuestRumor) -> void:
	rumor.discover()
	# Potentially trigger UI update or notification here

const BattleScene = preload("res://Scenes/Scene Container/Battle.tscn")

func setup_rival_attack_raid() -> void:
	if active_rivals.is_empty():
		return
	
	var attacking_rival = active_rivals[randi() % active_rivals.size()]
	# Instantiate the Battle scene
	var battle_instance = BattleScene.instantiate()
	current_battle = battle_instance
	# Setup the battle with the attacking rival
	current_battle.setup(attacking_rival, current_crew)
	print_debug("Rival attack raid set up by: %s" % attacking_rival.name)

func apply_upkeep_penalties() -> void:
	var upkeep_cost: int = crew_size * 2  # 2 credits per crew member
	if credits < upkeep_cost:
		match randi() % 3:
			0: reduce_mission_payouts(1)
			1: block_trade_actions()
			2: damage_ship(1)

func block_trade_actions() -> void:
	trade_actions_blocked = true
	print_debug("Trade actions blocked due to upkeep penalty")

func reduce_mission_payouts(amount: int) -> void:
	mission_payout_reduction += amount
	print_debug("Mission payouts reduced by %d credits" % amount)

func schedule_world_invasion() -> void:
	if current_location:
		var invasion_turns: int = randi() % 3 + 1  # 1 to 3 turns
		current_location.schedule_invasion(invasion_turns)
		print_debug("World invasion scheduled in %d turns" % invasion_turns)

func attempt_emergency_departure() -> bool:
	var success_chance: int = 50  # 50% base chance
	if current_ship:
		success_chance += current_ship.get_emergency_departure_bonus()
	
	var success: bool = randf() <= success_chance / 100.0
	print_debug("Emergency departure %s!" % ("successful" if success else "failed"))
	return success

func confiscate_ship_and_credits() -> void:
	credits = 0
	current_ship = null

func prompt_player_decision(question: String) -> bool:
	# This function cannot be fully implemented based on the provided context.
	# It requires user interaction, which is not covered in the rulebook or compendium.
	# A placeholder implementation is provided.
	print("Player Decision: " + question)
	# In a real implementation, this would wait for player input
	return false

func prompt_player_choice(question: String, options: Array) -> String:
	# This function cannot be fully implemented based on the provided context.
	# It requires user interaction, which is not covered in the rulebook or compendium.
	# A placeholder implementation is provided.
	print("Player Choice: " + question)
	print("Options: ", options)
	# In a real implementation, this would wait for player input
	return ""

func start_opportunity_missions(faction: String) -> void:
	var new_mission = mission_generator.generate_opportunity_mission(faction)
	
	if new_mission:
		available_missions.append(new_mission)
		print_debug("New opportunity mission added: %s for %s faction" % [new_mission.type, new_mission.faction])
	else:
		print_debug("Failed to generate opportunity mission for faction: %s" % faction)

func remove_random_rival() -> void:
	if active_rivals.size() > 0:
		var rival_to_remove = active_rivals[randi() % active_rivals.size()]
		remove_rival(rival_to_remove)

func get_completed_missions_count() -> int:
	var completed_count = 0
	for mission in available_missions:
		if mission.status == Mission.Status.COMPLETED:
			completed_count += 1
	return completed_count

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
		"rivals": rivals.map(func(rival): return rival.serialize()),
		"current_battle": current_battle.serialize() if current_battle else null,
		"ship_stash": ship_stash.map(func(item): return item.serialize()),
		"last_mission_results": last_mission_results,
		"crew_size": crew_size,
		"table_size": {"x": table_size.x, "y": table_size.y},
		"completed_patron_job_this_turn": completed_patron_job_this_turn,
		"held_the_field_against_roving_threat": held_the_field_against_roving_threat,
		"active_rivals": active_rivals.map(func(rival): return rival.serialize()),
		"character_connections": character_connections.map(func(conn): return {
			"character1": conn.character1.name,
			"character2": conn.character2.name,
			"relationship": conn.relationship
		}),
		"quest_rumors": quest_rumors.map(func(rumor): return rumor.serialize()),
	}
	if current_crew:
		data["current_crew"] = current_crew.serialize()
	if current_ship:
		data["current_ship"] = current_ship.serialize()
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
	if data.has("current_ship"):
		game_state.current_ship = Ship.deserialize(data["current_ship"])
	if data.has("current_mission"):
		game_state.current_mission = Mission.deserialize(data["current_mission"])
	game_state.available_missions = data.get("available_missions", []).map(func(mission_data): return Mission.deserialize(mission_data))
	game_state.active_quests = data.get("active_quests", []).map(func(quest_data): return Quest.deserialize(quest_data))
	game_state.patrons = data.get("patrons", []).map(func(patron_data): return Patron.deserialize(patron_data))
	game_state.rivals = data.get("rivals", []).map(func(rival_data): return Rival.deserialize(rival_data))
	if data.has("current_battle") and data["current_battle"] != null:
		game_state.current_battle = Battle.new(game_state).deserialize(data["current_battle"])
	game_state.ship_stash = data.get("ship_stash", []).map(func(item_data): return Item.deserialize(item_data))
	game_state.last_mission_results = data.get("last_mission_results", "")
	game_state.crew_size = data.get("crew_size", 0)
	game_state.table_size = Vector2(data.get("table_size", {}).get("x", 48), data.get("table_size", {}).get("y", 48))
	game_state.completed_patron_job_this_turn = data.get("completed_patron_job_this_turn", false)
	game_state.held_the_field_against_roving_threat = data.get("held_the_field_against_roving_threat", false)
	game_state.active_rivals = data.get("active_rivals", []).map(func(rival_data): return Rival.deserialize(rival_data))
	
	# Deserialize character connections
	if data.has("character_connections"):
		game_state.character_connections = data["character_connections"].map(func(conn):
			return {
				"character1": game_state.current_crew.get_character_by_name(conn.character1),
				"character2": game_state.current_crew.get_character_by_name(conn.character2),
				"relationship": conn.relationship
			}
		)
	
	game_state.quest_rumors = data.get("quest_rumors", []).map(func(rumor_data): return QuestRumor.deserialize(rumor_data))
	
	return game_state

func start_story_track_tutorial():
	story_track = StoryTrack.new()
	is_tutorial_active = true
	story_track.start_tutorial()

func end_tutorial():
	is_tutorial_active = false
	# Transition to normal gameplay

func _on_battle_completed(battle_won: bool):
	if is_tutorial_active:
		story_track.progress_story(self, battle_won)
	else:
		# Normal post-battle processing
		pass

# Add methods to handle campaign turn modifications, rewards, etc.
func add_rival(rival_name: String) -> void:
	var new_rival = Rival.new()
	new_rival.name = rival_name
	rivals.append(new_rival)

func set_character_connections(connections: Array) -> void:
	character_connections = connections

func get_character_connections() -> Array:
	return character_connections

func get_character_by_name(character_name: String):
	if current_crew:
		return current_crew.get_character_by_name(character_name)
	return null
