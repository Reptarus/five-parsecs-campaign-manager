extends Node

# Preload all required resources
const GameEnums = preload("../Systems/GlobalEnums.gd")
const GameState = preload("./GameState.gd")
const StoryQuestData = preload("../Story/StoryQuestData.gd")

# Optional resources that may not exist in all configurations
var _character_script = FileAccess.file_exists("res://Resources/Core/Character/Base/Character.gd") if preload("../Character/Base/Character.gd") else null
var _character_creator_script = FileAccess.file_exists("res://Resources/Core/Character/Generation/CharacterCreator.gd") if preload("../Character/Generation/CharacterCreator.gd") else null
var _unified_story_script = FileAccess.file_exists("res://Resources/Core/Story/UnifiedStorySystem.gd") if preload("../Story/UnifiedStorySystem.gd") else null

signal game_started
signal game_ended
signal game_saved
signal game_loaded
signal state_changed(new_state: GameEnums.GameState)
signal campaign_phase_changed(new_phase: GameEnums.CampaignPhase)
signal battle_phase_changed(new_phase: GameEnums.BattlePhase)
signal campaign_victory_achieved(victory_type: GameEnums.CampaignVictoryType)

# Define manager classes first
class InternalCampaignManager extends Node:
	signal phase_changed(new_phase: GameEnums.CampaignPhase)
	signal character_created(character: Resource)
	signal character_updated(character: Resource)
	signal campaign_state_changed
	
	var active_characters: Array = []
	var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
	var story_system: Node
	var resource_system: Node
	var character_creator: Node
	
	func _init() -> void:
		name = "CampaignManager"
		
		if owner and owner._unified_story_script:
			story_system = owner._unified_story_script.new()
			add_child(story_system)
			
		if owner and owner._resource_system_script:
			resource_system = owner._resource_system_script.new()
			add_child(resource_system)
			
		if owner and owner._character_creator_script:
			character_creator = owner._character_creator_script.new()
			add_child(character_creator)
	
	func create_character(config: Dictionary = {}) -> Resource:
		if character_creator and character_creator.has_method("create_character"):
			var character = character_creator.create_character(config)
			if character:
				active_characters.append(character)
				character_created.emit(character)
				return character
		return null
	
	func get_active_characters() -> Array:
		return active_characters
	
	func start_tutorial_campaign() -> void:
		current_phase = GameEnums.CampaignPhase.SETUP
		story_system.initialize_tutorial()
		phase_changed.emit(current_phase)
	
	func start_campaign(config: Dictionary) -> void:
		current_phase = GameEnums.CampaignPhase.SETUP
		story_system.initialize(config)
		phase_changed.emit(current_phase)
	
	func change_phase(new_phase: GameEnums.CampaignPhase) -> void:
		if current_phase != new_phase:
			current_phase = new_phase
			phase_changed.emit(new_phase)
	
	func serialize() -> Dictionary:
		var data = {
			"current_phase": current_phase,
			"characters": [],
			"story_system": story_system.serialize() if story_system else {},
			"resource_system": resource_system.serialize() if resource_system else {}
		}
		for character in active_characters:
			data.characters.append(character.serialize())
		return data
	
	func deserialize(data: Dictionary) -> void:
		current_phase = data.get("current_phase", GameEnums.CampaignPhase.SETUP)
		active_characters.clear()
		
		if data.has("characters"):
			for char_data in data.characters:
				var character = Character.new()
				character.deserialize(char_data)
				active_characters.append(character)
		
		if data.has("story_system") and story_system:
			story_system.deserialize(data.story_system)
			
		if data.has("resource_system") and resource_system:
			resource_system.deserialize(data.resource_system)
	
	func cleanup() -> void:
		active_characters.clear()
		if story_system:
			story_system.queue_free()
		if resource_system:
			resource_system.queue_free()
		if character_creator:
			character_creator.queue_free()

class InternalBattleManager extends Node:
	signal phase_changed(new_phase: GameEnums.BattlePhase)
	signal battle_completed(results: Dictionary)
	
	var current_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
	var battle_system: Node
	
	func _init() -> void:
		name = "BattleManager"
		
		if owner and owner._battle_system_script:
			battle_system = owner._battle_system_script.new()
			add_child(battle_system)
	
	func change_phase(new_phase: GameEnums.BattlePhase) -> void:
		if current_phase != new_phase:
			current_phase = new_phase
			phase_changed.emit(new_phase)
	
	func serialize() -> Dictionary:
		return {
			"current_phase": current_phase,
			"battle_system": battle_system.serialize() if battle_system else {}
		}
	
	func deserialize(data: Dictionary) -> void:
		current_phase = data.get("current_phase", GameEnums.BattlePhase.SETUP)
		if data.has("battle_system") and battle_system:
			battle_system.deserialize(data.battle_system)
	
	func cleanup() -> void:
		if battle_system:
			battle_system.queue_free()

class InternalMissionManager extends Node:
	signal mission_available(mission: StoryQuestData)
	signal mission_completed(mission: StoryQuestData)
	
	var available_missions: Array[StoryQuestData] = []
	var completed_missions: Array[StoryQuestData] = []
	var current_mission: StoryQuestData = null
	
	func _init() -> void:
		name = "MissionManager"
	
	func add_mission(mission: StoryQuestData) -> void:
		if not mission:
			push_error("Cannot add null mission")
			return
			
		if not available_missions.has(mission):
			available_missions.append(mission)
			mission_available.emit(mission)
	
	func complete_mission(mission: StoryQuestData) -> void:
		if not mission:
			push_error("Cannot complete null mission")
			return
			
		if available_missions.has(mission):
			available_missions.erase(mission)
			completed_missions.append(mission)
			mission_completed.emit(mission)
	
	func get_current_mission() -> StoryQuestData:
		return current_mission
	
	func set_current_mission(mission: StoryQuestData) -> void:
		current_mission = mission
	
	func serialize() -> Dictionary:
		var data = {
			"available_missions": [],
			"completed_missions": [],
			"current_mission": current_mission.serialize() if current_mission else null
		}
		for mission in available_missions:
			data.available_missions.append(mission.serialize())
		for mission in completed_missions:
			data.completed_missions.append(mission.serialize())
		return data
	
	func deserialize(data: Dictionary) -> void:
		available_missions.clear()
		completed_missions.clear()
		current_mission = null
		
		if data.has("available_missions"):
			for mission_data in data.available_missions:
				var mission = StoryQuestData.new()
				mission.deserialize(mission_data)
				available_missions.append(mission)
				
		if data.has("completed_missions"):
			for mission_data in data.completed_missions:
				var mission = StoryQuestData.new()
				mission.deserialize(mission_data)
				completed_missions.append(mission)
				
		if data.has("current_mission") and data.current_mission:
			current_mission = StoryQuestData.new()
			current_mission.deserialize(data.current_mission)
	
	func cleanup() -> void:
		available_missions.clear()
		completed_missions.clear()
		current_mission = null

class InternalEquipmentManager extends Node:
	signal equipment_changed
	
	var equipment_system: ResourceSystem
	
	func _init() -> void:
		name = "EquipmentManager"
		equipment_system = ResourceSystem.new()
		add_child(equipment_system)
	
	func serialize() -> Dictionary:
		return {
			"equipment_system": equipment_system.serialize() if equipment_system else {}
		}
	
	func deserialize(data: Dictionary) -> void:
		if data.has("equipment_system") and equipment_system:
			equipment_system.deserialize(data.equipment_system)
	
	func cleanup() -> void:
		if equipment_system:
			equipment_system.queue_free()

class InternalPatronJobManager extends Node:
	signal patron_job_available(job: StoryQuestData)
	signal patron_job_completed(job: StoryQuestData)
	signal patron_job_failed(job: StoryQuestData)
	
	var available_jobs: Array[StoryQuestData] = []
	var completed_jobs: Array[StoryQuestData] = []
	var failed_jobs: Array[StoryQuestData] = []
	var current_job: StoryQuestData = null
	
	func _init() -> void:
		name = "PatronJobManager"
	
	func add_job(job: StoryQuestData) -> void:
		if not job:
			push_error("Cannot add null job")
			return
			
		if not available_jobs.has(job):
			available_jobs.append(job)
			patron_job_available.emit(job)
	
	func complete_job(job: StoryQuestData) -> void:
		if not job:
			push_error("Cannot complete null job")
			return
			
		if available_jobs.has(job):
			available_jobs.erase(job)
			completed_jobs.append(job)
			patron_job_completed.emit(job)
	
	func fail_job(job: StoryQuestData) -> void:
		if not job:
			push_error("Cannot fail null job")
			return
			
		if available_jobs.has(job):
			available_jobs.erase(job)
			failed_jobs.append(job)
			patron_job_failed.emit(job)
	
	func get_current_job() -> StoryQuestData:
		return current_job
	
	func set_current_job(job: StoryQuestData) -> void:
		current_job = job
	
	func serialize() -> Dictionary:
		var data = {
			"available_jobs": [],
			"completed_jobs": [],
			"failed_jobs": [],
			"current_job": current_job.serialize() if current_job else null
		}
		for job in available_jobs:
			data.available_jobs.append(job.serialize())
		for job in completed_jobs:
			data.completed_jobs.append(job.serialize())
		for job in failed_jobs:
			data.failed_jobs.append(job.serialize())
		return data
	
	func deserialize(data: Dictionary) -> void:
		available_jobs.clear()
		completed_jobs.clear()
		failed_jobs.clear()
		current_job = null
		
		if data.has("available_jobs"):
			for job_data in data.available_jobs:
				var job = StoryQuestData.new()
				job.deserialize(job_data)
				available_jobs.append(job)
				
		if data.has("completed_jobs"):
			for job_data in data.completed_jobs:
				var job = StoryQuestData.new()
				job.deserialize(job_data)
				completed_jobs.append(job)
				
		if data.has("failed_jobs"):
			for job_data in data.failed_jobs:
				var job = StoryQuestData.new()
				job.deserialize(job_data)
				failed_jobs.append(job)
				
		if data.has("current_job") and data.current_job:
			current_job = StoryQuestData.new()
			current_job.deserialize(data.current_job)
	
	func cleanup() -> void:
		available_jobs.clear()
		completed_jobs.clear()
		failed_jobs.clear()
		current_job = null

# Manager instances
var campaign_manager: InternalCampaignManager
var battle_manager: InternalBattleManager
var mission_manager: InternalMissionManager
var equipment_manager: InternalEquipmentManager
var patron_job_manager: InternalPatronJobManager

# Game state
var game_state: GameState
var current_save_slot: int = -1
var is_tutorial: bool = false
var current_state: GameEnums.GameState = GameEnums.GameState.SETUP
var current_campaign_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
var current_battle_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var difficulty_mode: GameEnums.DifficultyMode = GameEnums.DifficultyMode.NORMAL

func _init() -> void:
	_initialize_managers()
	_connect_signals()

func _initialize_managers() -> void:
	campaign_manager = InternalCampaignManager.new()
	battle_manager = InternalBattleManager.new()
	mission_manager = InternalMissionManager.new()
	equipment_manager = InternalEquipmentManager.new()
	patron_job_manager = InternalPatronJobManager.new()
	
	add_child(campaign_manager)
	add_child(battle_manager)
	add_child(mission_manager)
	add_child(equipment_manager)
	add_child(patron_job_manager)

func _connect_signals() -> void:
	if campaign_manager:
		campaign_manager.phase_changed.connect(_on_campaign_phase_changed)
		campaign_manager.character_created.connect(_on_character_created)
	
	if battle_manager:
		battle_manager.phase_changed.connect(_on_battle_phase_changed)

func start_new_game(config: Dictionary = {}) -> void:
	game_state = GameState.new()
	game_state.initialize(config)
	
	if config.get("tutorial", false):
		is_tutorial = true
		start_tutorial()
	else:
		start_campaign(config)
	
	game_started.emit()

func start_tutorial() -> void:
	is_tutorial = true
	game_state.set_tutorial_mode(true)
	campaign_manager.start_tutorial_campaign()

func start_campaign(config: Dictionary) -> void:
	is_tutorial = false
	game_state.set_tutorial_mode(false)
	campaign_manager.start_campaign(config)

func save_game(slot: int) -> void:
	if not game_state:
		push_error("No game state to save")
		return
	
	var save_data = {
		"game_state": game_state.serialize(),
		"campaign": campaign_manager.serialize(),
		"mission": mission_manager.serialize(),
		"equipment": equipment_manager.serialize(),
		"patron_jobs": patron_job_manager.serialize(),
		"is_tutorial": is_tutorial,
		"difficulty_mode": difficulty_mode
	}
	
	# Save to file logic here
	current_save_slot = slot
	game_saved.emit()

func load_game(slot: int) -> void:
	# Load from file logic here
	var save_data = {}  # Load data from file
	
	if save_data.is_empty():
		push_error("No save data found in slot %d" % slot)
		return
	
	game_state = GameState.new()
	game_state.deserialize(save_data.game_state)
	
	campaign_manager.deserialize(save_data.campaign)
	mission_manager.deserialize(save_data.mission)
	equipment_manager.deserialize(save_data.equipment)
	patron_job_manager.deserialize(save_data.patron_jobs)
	
	is_tutorial = save_data.is_tutorial
	difficulty_mode = save_data.difficulty_mode
	
	current_save_slot = slot
	game_loaded.emit()

func end_game() -> void:
	if game_state:
		game_state.cleanup()
	
	campaign_manager.cleanup()
	mission_manager.cleanup()
	equipment_manager.cleanup()
	patron_job_manager.cleanup()
	
	game_state = null
	current_save_slot = -1
	is_tutorial = false
	
	game_ended.emit()

func _on_campaign_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	current_campaign_phase = new_phase
	campaign_phase_changed.emit(new_phase)
	if game_state:
		game_state.current_phase = new_phase

func _on_battle_phase_changed(new_phase: GameEnums.BattlePhase) -> void:
	current_battle_phase = new_phase
	battle_phase_changed.emit(new_phase)
	if game_state:
		game_state.current_battle_phase = new_phase

func get_game_state() -> GameState:
	return game_state

func create_new_game_state() -> GameState:
	game_state = GameState.new()
	game_state.initialize({})
	current_state = GameEnums.GameState.SETUP
	current_campaign_phase = GameEnums.CampaignPhase.SETUP
	current_battle_phase = GameEnums.BattlePhase.SETUP
	return game_state

func is_game_active() -> bool:
	return game_state != null

func get_difficulty_mode() -> GameEnums.DifficultyMode:
	return difficulty_mode

func set_difficulty_mode(mode: GameEnums.DifficultyMode) -> void:
	difficulty_mode = mode
	if game_state:
		game_state.update_difficulty(mode)

func create_character(config: Dictionary = {}) -> Resource:
	if campaign_manager:
		return campaign_manager.create_character(config)
	return null

func get_active_characters() -> Array:
	if campaign_manager:
		return campaign_manager.get_active_characters()
	return []

func _on_character_created(character: Resource) -> void:
	if game_state and character:
		game_state.add_character(character)

func set_captain(captain: Resource) -> void:
	if not game_state:
		push_error("Cannot set captain: game state is null")
		return
	
	game_state.captain = captain
	
func get_captain() -> Resource:
	if not game_state:
		push_error("Cannot get captain: game state is null")
		return null
	
	return game_state.captain
	
func add_crew_member(character: Resource) -> void:
	if not game_state:
		push_error("Cannot add crew member: game state is null")
		return
		
	if not game_state.crew:
		game_state.crew = []
	
	game_state.crew.append(character)
	
func get_crew() -> Array:
	if not game_state:
		push_error("Cannot get crew: game state is null")
		return []
		
	if not game_state.crew:
		game_state.crew = []
		
	return game_state.crew
