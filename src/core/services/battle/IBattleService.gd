class_name IBattleService
extends RefCounted

## IBattleService - Interface for Five Parsecs Battle System Integration
## Defines the contract for battle system implementations (stub, companion app, integrated)

## Battle Context Data Structures

class BattleContext:
	## Complete context data for battle initialization
	var mission_data: Dictionary = {}
	var crew_data: Array = []
	var equipment_data: Dictionary = {}
	var enemy_data: Dictionary = {}  
	var battlefield_data: Dictionary = {}
	var special_conditions: Array = []
	var campaign_turn: int = 1
	var difficulty_modifiers: Dictionary = {}
	
	func _init(data: Dictionary = {}):
		if data.has("mission_data"):
			mission_data = data.mission_data
		if data.has("crew_data"):
			crew_data = data.crew_data
		if data.has("equipment_data"):
			equipment_data = data.equipment_data
		if data.has("enemy_data"):
			enemy_data = data.enemy_data
		if data.has("battlefield_data"):
			battlefield_data = data.battlefield_data
		if data.has("special_conditions"):
			special_conditions = data.special_conditions
		if data.has("campaign_turn"):
			campaign_turn = data.campaign_turn
		if data.has("difficulty_modifiers"):
			difficulty_modifiers = data.difficulty_modifiers

class BattleSession:
	## Active battle session data
	var session_id: String = ""
	var context: BattleContext
	var status: BattleStatus = BattleStatus.INITIALIZING
	var current_turn: int = 1
	var participants: Array = []
	var battlefield_state: Dictionary = {}
	var events_log: Array = []
	var start_time: String = ""
	var end_time: String = ""
	
	func _init(battle_context: BattleContext):
		session_id = "battle_" + str(Time.get_unix_time_from_system())
		context = battle_context
		start_time = Time.get_datetime_string_from_system()

class IBattleResults:
	## Complete battle outcome data (prefixed to avoid conflict with global BattleResults)
	var session_id: String = ""
	var victory: bool = false
	var mission_completed: bool = false
	var crew_casualties: Array = []
	var crew_experience: Dictionary = {}
	var loot_acquired: Array = []
	var credits_earned: int = 0
	var story_developments: Array = []
	var rival_encounters: Dictionary = {}
	var patron_relationships: Dictionary = {}
	var equipment_lost: Array = []
	var injuries_sustained: Array = []
	var battle_duration: float = 0.0
	var tactical_summary: Dictionary = {}
	
	func _init(data: Dictionary = {}):
		for key in data:
			if key in self:
				set(key, data[key])

## Enums

enum BattleStatus {
	INITIALIZING,
	READY_TO_START,
	IN_PROGRESS,
	PAUSED,
	COMPLETED,
	CANCELLED,
	ERROR
}

enum BattleType {
	OPPORTUNITY_MISSION,
	PATRON_JOB,
	RIVAL_ENCOUNTER,
	INVESTIGATION,
	ESCORT_MISSION,
	RAID_MISSION,
	RANDOM_ENCOUNTER
}

## Abstract Interface Methods

func initialize_battle_system() -> bool:
	## Initialize the battle system - override in implementation
	push_error("IBattleService.initialize_battle_system() must be implemented")
	return false

func validate_battle_context(context: BattleContext) -> Dictionary:
	## Validate battle context data - override in implementation
	push_error("IBattleService.validate_battle_context() must be implemented") 
	return {"valid": false, "errors": ["Not implemented"]}

func create_battle_session(context: BattleContext) -> BattleSession:
	## Create new battle session - override in implementation
	push_error("IBattleService.create_battle_session() must be implemented")
	return null

func start_battle(session: BattleSession) -> bool:
	## Start battle execution - override in implementation
	push_error("IBattleService.start_battle() must be implemented")
	return false

func get_battle_status(session_id: String) -> BattleStatus:
	## Get current battle status - override in implementation
	push_error("IBattleService.get_battle_status() must be implemented")
	return BattleStatus.ERROR

func get_battle_results(session_id: String) -> IBattleResults:
	## Get battle results - override in implementation
	push_error("IBattleService.get_battle_results() must be implemented")
	return null

func cancel_battle(session_id: String) -> bool:
	## Cancel ongoing battle - override in implementation
	push_error("IBattleService.cancel_battle() must be implemented")
	return false

func cleanup_battle_session(session_id: String) -> void:
	## Clean up battle session resources - override in implementation
	push_error("IBattleService.cleanup_battle_session() must be implemented")

## Utility Methods (Can be overridden)

func create_default_context() -> BattleContext:
	## Create a default battle context for testing
	var default_data = {
		"mission_data": {
			"type": "opportunity_mission",
			"title": "Test Mission",
			"difficulty": "standard",
			"objectives": ["Defeat all enemies"]
		},
		"crew_data": [
			{"name": "Captain", "class": "Leader", "reactions": 1, "speed": 4},
			{"name": "Marine", "class": "Soldier", "reactions": 1, "speed": 4},
			{"name": "Medic", "class": "Medic", "reactions": 1, "speed": 4}
		],
		"equipment_data": {
			"weapons": ["Colony Rifle", "Handgun"],
			"armor": ["Combat Armor"],
			"equipment": ["Med-Kit"]
		},
		"enemy_data": {
			"type": "criminals",
			"count": 4,
			"difficulty": "standard"
		},
		"battlefield_data": {
			"type": "urban",
			"size": "medium",
			"terrain_features": ["cover", "elevation"]
		},
		"campaign_turn": 1
	}
	
	return BattleContext.new(default_data)

func validate_crew_data(crew_data: Array) -> Dictionary:
	## Validate crew data structure
	if crew_data.is_empty():
		return {"valid": false, "error": "No crew members provided"}
	
	if crew_data.size() > 6:
		return {"valid": false, "error": "Too many crew members (max 6)"}
	
	for crew_member in crew_data:
		if not crew_member is Dictionary:
			return {"valid": false, "error": "Invalid crew member data format"}
		
		if not crew_member.has("name") or not crew_member.has("class"):
			return {"valid": false, "error": "Crew member missing required fields"}
	
	return {"valid": true}

func validate_mission_data(mission_data: Dictionary) -> Dictionary:
	## Validate mission data structure
	var required_fields = ["type", "title", "objectives"]
	
	for field in required_fields:
		if not mission_data.has(field):
			return {"valid": false, "error": "Missing required field: " + field}
	
	if not mission_data.objectives is Array or mission_data.objectives.is_empty():
		return {"valid": false, "error": "Mission must have at least one objective"}
	
	return {"valid": true}

func create_error_result(error_message: String, session_id: String = "") -> IBattleResults:
	## Create error result for failed battles
	var error_result = IBattleResults.new()
	error_result.session_id = session_id
	error_result.victory = false
	error_result.mission_completed = false
	error_result.tactical_summary = {"error": error_message, "status": "failed"}
	
	return error_result

## Signal Definitions (For implementations to connect to)

# Override in implementations and emit these signals as appropriate:
# signal battle_initialized(session_id: String)
# signal battle_started(session_id: String) 
# signal battle_completed(session_id: String, results: IBattleResults)
# signal battle_cancelled(session_id: String)
# signal battle_error(session_id: String, error: String)