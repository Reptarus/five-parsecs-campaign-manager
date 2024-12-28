extends Resource
class_name Campaign

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal campaign_started(campaign_data: Dictionary)
signal campaign_ended(result: Dictionary)
signal phase_changed(new_phase: GlobalEnums.CampaignPhase)
signal resource_changed(resource_type: GlobalEnums.ResourceType, amount: int)
signal world_event_triggered(event_type: GlobalEnums.GlobalEvent)
signal location_changed(new_location: String)
signal event_occurred(event_data: Dictionary)

# Campaign identification
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var creation_date: String = ""
@export var last_saved: String = ""

# Campaign state
@export var current_phase: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.SETUP
@export var current_turn: int = 1
@export var current_location: String = ""
@export var is_active: bool = true
@export var difficulty_mode: GlobalEnums.DifficultyMode = GlobalEnums.DifficultyMode.NORMAL

# Ship properties
var ship_hull_points: int = 10
var ship_max_hull_points: int = 10
var ship_condition: GlobalEnums.ShipCondition = GlobalEnums.ShipCondition.GOOD
var ship_components: Dictionary = {
	GlobalEnums.ShipComponentType.HULL_LIGHT: 1,
	GlobalEnums.ShipComponentType.ENGINE_BASIC: 1,
	GlobalEnums.ShipComponentType.MEDICAL_BASIC: 1
}

# Campaign resources
var resources: Dictionary = {
	GlobalEnums.ResourceType.CREDITS: 1000,
	GlobalEnums.ResourceType.SUPPLIES: 10,
	GlobalEnums.ResourceType.STORY_POINT: 3,
	GlobalEnums.ResourceType.PATRON: 0,
	GlobalEnums.ResourceType.RIVAL: 0,
	GlobalEnums.ResourceType.QUEST_RUMOR: 0,
	GlobalEnums.ResourceType.XP: 0,
	GlobalEnums.ResourceType.MINERALS: 0,
	GlobalEnums.ResourceType.TECHNOLOGY: 0,
	GlobalEnums.ResourceType.MEDICAL_SUPPLIES: 0,
	GlobalEnums.ResourceType.WEAPONS: 0,
	GlobalEnums.ResourceType.RARE_MATERIALS: 0,
	GlobalEnums.ResourceType.LUXURY_GOODS: 0,
	GlobalEnums.ResourceType.FUEL: 0
}

# Campaign debt tracking
var ship_debt: int = 0
var crew_debt: int = 0

# Campaign crew and jobs
@export var active_patrons: Array[Dictionary] = []
@export var crew_tasks: Dictionary = {} # Maps crew member ID to assigned task
@export var current_job_offers: Array[Dictionary] = []
@export var crew_members: Array[Character] = []

# World state
var world_state: Dictionary = {
	"strife_level": GlobalEnums.StrifeType.LOW,
	"instability": GlobalEnums.FringeWorldInstability.STABLE,
	"market_state": GlobalEnums.MarketState.NORMAL,
	"active_threats": [],
	"current_location": null,
	"available_missions": [],
	"active_quests": [],
	"completed_quests": [],
	"failed_quests": [],
	"pirate_activity": 0.0,
	"faction_tension": 0.0,
	"tech_level": 1.0,
	"resource_abundance": 0.0,
	"travel_hazard": false,
	"black_market_active": false,
	"mission_difficulty": 1.0
}

func _init() -> void:
	campaign_id = str(Time.get_unix_time_from_system())
	creation_date = Time.get_datetime_string_from_system()
	last_saved = creation_date

func start_campaign(campaign_data: Dictionary) -> void:
	current_phase = GlobalEnums.CampaignPhase.SETUP
	campaign_started.emit(campaign_data)

func end_campaign(result: Dictionary) -> void:
	campaign_ended.emit(result)

func advance_phase() -> void:
	var next_phase := _get_next_phase()
	current_phase = next_phase
	phase_changed.emit(next_phase)

func modify_resource(resource_type: GlobalEnums.ResourceType, amount: int) -> void:
	if resource_type in resources:
		resources[resource_type] += amount
		resource_changed.emit(resource_type, amount)

func trigger_world_event(event_type: GlobalEnums.GlobalEvent) -> void:
	world_event_triggered.emit(event_type)

func _get_next_phase() -> GlobalEnums.CampaignPhase:
	match current_phase:
		GlobalEnums.CampaignPhase.SETUP:
			return GlobalEnums.CampaignPhase.UPKEEP
		GlobalEnums.CampaignPhase.UPKEEP:
			return GlobalEnums.CampaignPhase.WORLD_STEP
		GlobalEnums.CampaignPhase.WORLD_STEP:
			return GlobalEnums.CampaignPhase.TRAVEL
		GlobalEnums.CampaignPhase.TRAVEL:
			return GlobalEnums.CampaignPhase.PATRONS
		GlobalEnums.CampaignPhase.PATRONS:
			return GlobalEnums.CampaignPhase.BATTLE
		GlobalEnums.CampaignPhase.BATTLE:
			return GlobalEnums.CampaignPhase.POST_BATTLE
		GlobalEnums.CampaignPhase.POST_BATTLE:
			return GlobalEnums.CampaignPhase.MANAGEMENT
		GlobalEnums.CampaignPhase.MANAGEMENT:
			return GlobalEnums.CampaignPhase.UPKEEP
		_:
			return GlobalEnums.CampaignPhase.SETUP

func get_resources() -> Dictionary:
	return resources.duplicate()

func serialize() -> Dictionary:
	var data = {
		"campaign_name": campaign_name,
		"campaign_id": campaign_id,
		"creation_date": creation_date,
		"last_saved": Time.get_datetime_string_from_system(),
		"current_phase": current_phase,
		"current_turn": current_turn,
		"current_location": current_location,
		"is_active": is_active,
		"difficulty_mode": difficulty_mode,
		"resources": resources.duplicate(),
		"ship_hull_points": ship_hull_points,
		"ship_max_hull_points": ship_max_hull_points,
		"ship_condition": ship_condition,
		"ship_components": ship_components.duplicate(),
		"ship_debt": ship_debt,
		"crew_debt": crew_debt,
		"world_state": world_state.duplicate()
	}
	return data

static func deserialize(data: Dictionary) -> Campaign:
	var campaign = Campaign.new()
	campaign.campaign_name = data.get("campaign_name", "")
	campaign.campaign_id = data.get("campaign_id", "")
	campaign.creation_date = data.get("creation_date", "")
	campaign.last_saved = data.get("last_saved", "")
	campaign.current_phase = data.get("current_phase", GlobalEnums.CampaignPhase.SETUP)
	campaign.current_turn = data.get("current_turn", 1)
	campaign.current_location = data.get("current_location", "")
	campaign.is_active = data.get("is_active", true)
	campaign.difficulty_mode = data.get("difficulty_mode", GlobalEnums.DifficultyMode.NORMAL)
	campaign.resources = data.get("resources", {}).duplicate()
	campaign.ship_hull_points = data.get("ship_hull_points", 10)
	campaign.ship_max_hull_points = data.get("ship_max_hull_points", 10)
	campaign.ship_condition = data.get("ship_condition", GlobalEnums.ShipCondition.GOOD)
	campaign.ship_components = data.get("ship_components", {}).duplicate()
	campaign.ship_debt = data.get("ship_debt", 0)
	campaign.crew_debt = data.get("crew_debt", 0)
	campaign.world_state = data.get("world_state", {}).duplicate()
	return campaign