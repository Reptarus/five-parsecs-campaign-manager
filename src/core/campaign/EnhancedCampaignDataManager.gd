@tool
extends RefCounted
class_name EnhancedCampaignDataManager

## Enhanced Campaign Data Manager - Central data management with validation and persistence
## Follows proven patterns from Campaign Creation State Manager
## Provides comprehensive data storage, validation, and analysis capabilities

# Universal Safety patterns
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const CampaignDataStructures = preload("res://src/core/data/CampaignDataStructures.gd")

# Data storage
var planet_database: Dictionary = {}
var mission_history: Array[CampaignDataStructures.MissionHistoryEntry] = []
var relationship_tracker: Dictionary = {}
var economic_data: CampaignDataStructures.EconomicData
var crew_performance_data: Dictionary = {}
var ship_status_data: CampaignDataStructures.ShipStatusData
var campaign_analytics: CampaignDataStructures.CampaignAnalytics

# Validation and error handling
var validation_errors: Array[String] = []
var data_integrity_checks: Array[String] = []

# Signals for data updates
signal planet_data_updated(planet_name: String, data: Dictionary)
signal mission_logged(mission_data: Dictionary)
signal relationship_changed(entity_name: String, change: Dictionary)
signal economic_data_updated(credits: int, change: int)
signal crew_performance_updated(crew_id: String, performance: Dictionary)
signal ship_status_updated(ship_data: Dictionary)
signal analytics_updated(analytics: Dictionary)
signal data_validation_failed(errors: Array[String])
signal data_integrity_warning(warnings: Array[String])

func _init() -> void:
	_initialize_data_structures()
	_setup_validation_rules()

## Initialize all data structures
func _initialize_data_structures() -> void:
	economic_data = CampaignDataStructures.create_economic_data()
	ship_status_data = CampaignDataStructures.create_ship_status("Default Ship")
	campaign_analytics = CampaignDataStructures.create_campaign_analytics()
	
	print("EnhancedCampaignDataManager: Data structures initialized")

## Setup validation rules following Campaign Creation State Manager patterns
func _setup_validation_rules() -> void:
	data_integrity_checks = [
		"validate_planet_data",
		"validate_mission_data",
		"validate_relationship_data",
		"validate_economic_data",
		"validate_crew_performance",
		"validate_ship_status"
	]

## Planet data management with validation
func store_planet_data(planet_data: CampaignDataStructures.PlanetProfile) -> bool:
	if not _validate_planet_data(planet_data):
		return false
	
	planet_database[planet_data.planet_name] = planet_data
	planet_data_updated.emit(planet_data.planet_name, planet_data.to_dict())
	return true

func get_planet_data(planet_name: String) -> CampaignDataStructures.PlanetProfile:
	return planet_database.get(planet_name, null)

func update_planet_visit(planet_name: String) -> void:
	var planet_data = get_planet_data(planet_name)
	if planet_data:
		planet_data.increment_visit_count()
		planet_data_updated.emit(planet_name, planet_data.to_dict())

func get_all_planets() -> Array[String]:
	return planet_database.keys()

## Mission history management
func log_mission_result(mission_data: Dictionary) -> bool:
	if not _validate_mission_data(mission_data):
		return false
	
	var mission_entry = CampaignDataStructures.create_mission_entry(mission_data.get("mission_id", ""))
	mission_entry.populate_from_dictionary(mission_data)
	
	mission_history.append(mission_entry)
	mission_logged.emit(mission_data)
	
	# Update analytics
	campaign_analytics.update_mission_statistics(mission_data)
	analytics_updated.emit(campaign_analytics.to_dict())
	
	return true

func get_mission_history(limit: int = -1) -> Array[CampaignDataStructures.MissionHistoryEntry]:
	if limit > 0:
		return mission_history.slice(-limit)
	return mission_history

func get_missions_by_type(mission_type: String) -> Array[CampaignDataStructures.MissionHistoryEntry]:
	var filtered_missions: Array[CampaignDataStructures.MissionHistoryEntry] = []
	for mission in mission_history:
		if mission.mission_type == mission_type:
			filtered_missions.append(mission)
	return filtered_missions

## Relationship tracking
func update_relationship(character_id: String, relationship_data: Dictionary) -> bool:
	if not _validate_relationship_data(relationship_data):
		return false
	
	if not relationship_tracker.has(character_id):
		relationship_tracker[character_id] = CampaignDataStructures.create_relationship(character_id)
	
	var relationship = relationship_tracker[character_id]
	relationship.update_relationship_level(relationship_data.get("change", 0))
	
	relationship_changed.emit(character_id, relationship_data)
	return true

func get_relationship(character_id: String) -> CampaignDataStructures.CharacterRelationship:
	return relationship_tracker.get(character_id, null)

func get_all_relationships() -> Dictionary:
	return relationship_tracker

## Economic data management
func update_credits(amount: int, reason: String) -> bool:
	if not _validate_economic_data({"amount": amount, "reason": reason}):
		return false
	
	economic_data.add_credit_entry(reason, amount)
	economic_data_updated.emit(economic_data.current_credits, amount)
	return true

func get_current_credits() -> int:
	return economic_data.current_credits

func get_credit_history() -> Array[Dictionary]:
	return economic_data.credit_history

func add_trade_record(trade_data: Dictionary) -> void:
	economic_data.add_trade_entry(trade_data)

## Crew performance tracking
func update_crew_performance(crew_id: String, performance_data: Dictionary) -> bool:
	if not _validate_crew_performance(performance_data):
		return false
	
	if not crew_performance_data.has(crew_id):
		crew_performance_data[crew_id] = CampaignDataStructures.create_crew_performance(crew_id)
	
	var crew_data = crew_performance_data[crew_id]
	crew_data.add_mission_result(performance_data)
	
	crew_performance_updated.emit(crew_id, performance_data)
	return true

func get_crew_performance(crew_id: String) -> CampaignDataStructures.CrewPerformanceData:
	return crew_performance_data.get(crew_id, null)

func get_best_performing_crew() -> String:
	var best_crew_id = ""
	var best_rating = 0.0
	
	for crew_id in crew_performance_data:
		var crew_data = crew_performance_data[crew_id]
		if crew_data.performance_rating > best_rating:
			best_rating = crew_data.performance_rating
			best_crew_id = crew_id
	
	return best_crew_id

## Ship status management
func update_ship_status(ship_data: Dictionary) -> bool:
	if not _validate_ship_status(ship_data):
		return false
	
	# Update ship status based on provided data
	if ship_data.has("hull_damage"):
		ship_status_data.take_damage(ship_data.hull_damage)
	
	if ship_data.has("repair_amount"):
		ship_status_data.repair_damage(ship_data.repair_amount)
	
	if ship_data.has("modification"):
		ship_status_data.add_modification(ship_data.modification)
	
	ship_status_updated.emit(ship_status_data.to_dict())
	return true

func get_ship_status() -> CampaignDataStructures.ShipStatusData:
	return ship_status_data

## Analytics and reporting
func get_campaign_analytics() -> CampaignDataStructures.CampaignAnalytics:
	return campaign_analytics

func get_success_rate() -> float:
	return campaign_analytics.get_success_rate()

func get_profit_margin() -> int:
	return campaign_analytics.get_profit_margin()

func get_campaign_efficiency() -> float:
	return campaign_analytics.get_campaign_efficiency()

## Validation methods following Campaign Creation State Manager patterns
func _validate_planet_data(planet_data: CampaignDataStructures.PlanetProfile) -> bool:
	validation_errors.clear()
	
	if planet_data.planet_name.is_empty():
		validation_errors.append("Planet name cannot be empty")
	
	if planet_data.tech_level < 1 or planet_data.tech_level > 5:
		validation_errors.append("Tech level must be between 1 and 5")
	
	if validation_errors.size() > 0:
		data_validation_failed.emit(validation_errors)
		return false
	
	return true

func _validate_mission_data(mission_data: Dictionary) -> bool:
	validation_errors.clear()
	
	if not mission_data.has("mission_id"):
		validation_errors.append("Mission data must include mission_id")
	
	if not mission_data.has("mission_type"):
		validation_errors.append("Mission data must include mission_type")
	
	if validation_errors.size() > 0:
		data_validation_failed.emit(validation_errors)
		return false
	
	return true

func _validate_relationship_data(relationship_data: Dictionary) -> bool:
	validation_errors.clear()
	
	if not relationship_data.has("change"):
		validation_errors.append("Relationship data must include change value")
	
	var change = relationship_data.get("change", 0)
	if change < -5 or change > 5:
		validation_errors.append("Relationship change must be between -5 and +5")
	
	if validation_errors.size() > 0:
		data_validation_failed.emit(validation_errors)
		return false
	
	return true

func _validate_economic_data(economic_data: Dictionary) -> bool:
	validation_errors.clear()
	
	if not economic_data.has("amount"):
		validation_errors.append("Economic data must include amount")
	
	if not economic_data.has("reason"):
		validation_errors.append("Economic data must include reason")
	
	if validation_errors.size() > 0:
		data_validation_failed.emit(validation_errors)
		return false
	
	return true

func _validate_crew_performance(performance_data: Dictionary) -> bool:
	validation_errors.clear()
	
	if not performance_data.has("enemies_defeated"):
		validation_errors.append("Crew performance must include enemies_defeated")
	
	if not performance_data.has("damage_dealt"):
		validation_errors.append("Crew performance must include damage_dealt")
	
	if validation_errors.size() > 0:
		data_validation_failed.emit(validation_errors)
		return false
	
	return true

func _validate_ship_status(ship_data: Dictionary) -> bool:
	validation_errors.clear()
	
	# Ship status validation is optional - allow empty updates
	return true

## Data integrity checks
func run_data_integrity_checks() -> bool:
	var warnings: Array[String] = []
	
	for check_method in data_integrity_checks:
		if has_method(check_method):
			var result = call(check_method)
			if not result:
				warnings.append("Data integrity check failed: " + check_method)
	
	if warnings.size() > 0:
		data_integrity_warning.emit(warnings)
		return false
	
	return true

## Persistence methods
func save_campaign_data() -> Dictionary:
	var save_data = {
		"planet_database": _serialize_planet_database(),
		"mission_history": _serialize_mission_history(),
		"relationship_tracker": _serialize_relationship_tracker(),
		"economic_data": economic_data.to_dict(),
		"crew_performance_data": _serialize_crew_performance(),
		"ship_status_data": ship_status_data.to_dict(),
		"campaign_analytics": campaign_analytics.to_dict(),
		"save_timestamp": Time.get_datetime_string_from_system()
	}
	
	return save_data

func load_campaign_data(save_data: Dictionary) -> bool:
	if not _validate_save_data(save_data):
		return false
	
	_deserialize_planet_database(save_data.get("planet_database", {}))
	_deserialize_mission_history(save_data.get("mission_history", []))
	_deserialize_relationship_tracker(save_data.get("relationship_tracker", {}))
	
	# Load other data structures
	if save_data.has("economic_data"):
		economic_data = CampaignDataStructures.create_economic_data()
		economic_data.from_dict(save_data.economic_data)
	
	if save_data.has("ship_status_data"):
		ship_status_data = CampaignDataStructures.create_ship_status("")
		ship_status_data.from_dict(save_data.ship_status_data)
	
	if save_data.has("campaign_analytics"):
		campaign_analytics = CampaignDataStructures.create_campaign_analytics()
		campaign_analytics.from_dict(save_data.campaign_analytics)
	
	return true

## Serialization helpers
func _serialize_planet_database() -> Dictionary:
	var serialized = {}
	for planet_name in planet_database:
		serialized[planet_name] = planet_database[planet_name].to_dict()
	return serialized

func _serialize_mission_history() -> Array:
	var serialized = []
	for mission in mission_history:
		serialized.append(mission.to_dict())
	return serialized

func _serialize_relationship_tracker() -> Dictionary:
	var serialized = {}
	for character_id in relationship_tracker:
		serialized[character_id] = relationship_tracker[character_id].to_dict()
	return serialized

func _serialize_crew_performance() -> Dictionary:
	var serialized = {}
	for crew_id in crew_performance_data:
		serialized[crew_id] = crew_performance_data[crew_id].to_dict()
	return serialized

## Deserialization helpers
func _deserialize_planet_database(serialized_data: Dictionary) -> void:
	planet_database.clear()
	for planet_name in serialized_data:
		var planet_data = CampaignDataStructures.create_planet_profile(planet_name)
		planet_data.from_dict(serialized_data[planet_name])
		planet_database[planet_name] = planet_data

func _deserialize_mission_history(serialized_data: Array) -> void:
	mission_history.clear()
	for mission_data in serialized_data:
		var mission = CampaignDataStructures.create_mission_entry(mission_data.get("mission_id", ""))
		mission.from_dict(mission_data)
		mission_history.append(mission)

func _deserialize_relationship_tracker(serialized_data: Dictionary) -> void:
	relationship_tracker.clear()
	for character_id in serialized_data:
		var relationship = CampaignDataStructures.create_relationship(character_id)
		relationship.from_dict(serialized_data[character_id])
		relationship_tracker[character_id] = relationship

## Save data validation
func _validate_save_data(save_data: Dictionary) -> bool:
	validation_errors.clear()
	
	if not save_data.has("save_timestamp"):
		validation_errors.append("Save data must include timestamp")
	
	if validation_errors.size() > 0:
		data_validation_failed.emit(validation_errors)
		return false
	
	return true