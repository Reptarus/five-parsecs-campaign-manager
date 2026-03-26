@tool
extends RefCounted
class_name CampaignDataStructures

## Campaign Data Structures for Enhanced Dashboard & Smart Logbook System
## Follows proven patterns from Campaign Creation State Manager
## Provides comprehensive data models for campaign tracking and analysis

# Planet profile data (for logbook)
class PlanetProfile extends Resource:
	@export var planet_name: String = ""
	@export var world_traits: Array[String] = []
	@export var government_type: String = ""
	@export var tech_level: int = 3
	@export var market_prices: Dictionary = {}
	@export var discovered_locations: Array[String] = []
	@export var known_patrons: Array[Dictionary] = []
	@export var rival_threats: Array[Dictionary] = []
	@export var last_visited: String = ""
	@export var visit_count: int = 0
	@export var trade_opportunities: Array[Dictionary] = []
	@export var security_level: int = 2
	@export var population_density: String = "Medium"
	@export var economic_status: String = "Stable"
	
	func _init(p_planet_name: String = "") -> void:
		planet_name = p_planet_name
		last_visited = Time.get_datetime_string_from_system()
	
	func add_discovered_location(location: String) -> void:
		if not location in discovered_locations:
			discovered_locations.append(location)
	
	func add_known_patron(patron_data: Dictionary) -> void:
		known_patrons.append(patron_data)
	
	func update_market_prices(prices: Dictionary) -> void:
		market_prices.merge(prices)
	
	func increment_visit_count() -> void:
		visit_count += 1
		last_visited = Time.get_datetime_string_from_system()

# Mission history entry (for logbook)
class MissionHistoryEntry extends Resource:
	@export var mission_id: String = ""
	@export var mission_type: String = ""
	@export var mission_name: String = ""
	@export var outcome: String = ""
	@export var rewards_gained: Dictionary = {}
	@export var crew_performance: Dictionary = {}
	@export var date_completed: String = ""
	@export var duration_minutes: int = 0
	@export var difficulty_level: int = 2
	@export var enemy_types: Array[String] = []
	@export var terrain_type: String = ""
	@export var special_events: Array[Dictionary] = []
	@export var casualties: Array[Dictionary] = []
	@export var experience_gained: Dictionary = {}
	@export var loot_acquired: Array[Dictionary] = []
	@export var mission_notes: String = ""
	
	func _init(p_mission_id: String = "") -> void:
		mission_id = p_mission_id
		date_completed = Time.get_datetime_string_from_system()
	
	func add_crew_performance(crew_id: String, performance_data: Dictionary) -> void:
		crew_performance[crew_id] = performance_data
	
	func add_special_event(event_data: Dictionary) -> void:
		special_events.append(event_data)
	
	func add_casualty(casualty_data: Dictionary) -> void:
		casualties.append(casualty_data)
	
	func add_loot(loot_data: Dictionary) -> void:
		loot_acquired.append(loot_data)

# Character relationship tracking
class CharacterRelationship extends Resource:
	@export var character_id: String = ""
	@export var relationship_type: String = "" # "patron", "rival", "ally", "neutral"
	@export var relationship_level: int = 0 # -5 to +5 scale
	@export var first_encounter: String = ""
	@export var last_encounter: String = ""
	@export var encounter_count: int = 0
	@export var relationship_notes: String = ""
	@export var favors_owed: int = 0
	@export var favors_given: int = 0
	@export var known_locations: Array[String] = []
	@export var contact_preferences: Dictionary = {}
	
	func _init(p_character_id: String = "") -> void:
		character_id = p_character_id
		first_encounter = Time.get_datetime_string_from_system()
		last_encounter = first_encounter
	
	func update_relationship_level(change: int) -> void:
		relationship_level = clampi(relationship_level + change, -5, 5)
		last_encounter = Time.get_datetime_string_from_system()
		encounter_count += 1
	
	func add_known_location(location: String) -> void:
		if not location in known_locations:
			known_locations.append(location)

# Economic tracking data
class EconomicData extends Resource:
	@export var current_credits: int = 0  # Set during campaign creation (Core Rules p.28)
	@export var credit_history: Array[Dictionary] = []
	@export var trade_history: Array[Dictionary] = []
	@export var debt_amount: int = 0
	@export var debt_due_date: String = ""
	@export var monthly_expenses: Dictionary = {}
	@export var investment_portfolio: Dictionary = {}
	@export var market_knowledge: Dictionary = {}
	@export var profitable_routes: Array[Dictionary] = []
	
	func _init() -> void:
		add_credit_entry("Starting funds", 1000)
	
	func add_credit_entry(reason: String, amount: int) -> void:
		var entry = {
			"timestamp": Time.get_datetime_string_from_system(),
			"reason": reason,
			"amount": amount,
			"balance": current_credits + amount
		}
		credit_history.append(entry)
		current_credits += amount
	
	func add_trade_entry(trade_data: Dictionary) -> void:
		trade_data["timestamp"] = Time.get_datetime_string_from_system()
		trade_history.append(trade_data)
	
	func update_market_knowledge(world: String, commodity: String, price: int) -> void:
		if not market_knowledge.has(world):
			market_knowledge[world] = {}
		market_knowledge[world][commodity] = price

# Crew performance tracking
class CrewPerformanceData extends Resource:
	@export var crew_id: String = ""
	@export var missions_completed: int = 0
	@export var missions_survived: int = 0
	@export var enemies_defeated: int = 0
	@export var damage_dealt: int = 0
	@export var damage_taken: int = 0
	@export var healing_provided: int = 0
	@export var support_actions: int = 0
	@export var critical_hits: int = 0
	@export var critical_failures: int = 0
	@export var experience_gained: int = 0
	@export var skills_improved: Array[String] = []
	@export var injuries_sustained: Array[Dictionary] = []
	@export var achievements: Array[String] = []
	@export var performance_rating: float = 0.0
	
	func _init(p_crew_id: String = "") -> void:
		crew_id = p_crew_id
	
	func add_mission_result(mission_data: Dictionary) -> void:
		missions_completed += 1
		if mission_data.get("survived", false):
			missions_survived += 1
		
		enemies_defeated += mission_data.get("enemies_defeated", 0)
		damage_dealt += mission_data.get("damage_dealt", 0)
		damage_taken += mission_data.get("damage_taken", 0)
		healing_provided += mission_data.get("healing_provided", 0)
		support_actions += mission_data.get("support_actions", 0)
		critical_hits += mission_data.get("critical_hits", 0)
		critical_failures += mission_data.get("critical_failures", 0)
		experience_gained += mission_data.get("experience_gained", 0)
		
		_update_performance_rating()
	
	func add_injury(injury_data: Dictionary) -> void:
		injuries_sustained.append(injury_data)
	
	func add_achievement(achievement: String) -> void:
		if not achievement in achievements:
			achievements.append(achievement)
	
	func _update_performance_rating() -> void:
		# Calculate performance rating based on various factors
		var base_rating = float(missions_survived) / max(missions_completed, 1)
		var combat_rating = float(enemies_defeated) / max(missions_completed, 1)
		var efficiency_rating = float(damage_dealt) / max(damage_taken, 1)
		
		performance_rating = (base_rating + combat_rating + efficiency_rating) / 3.0

# Ship status and maintenance tracking
class ShipStatusData extends Resource:
	@export var ship_name: String = ""
	@export var hull_integrity: int = 100
	@export var max_hull_integrity: int = 100
	@export var systems_status: Dictionary = {}
	@export var modifications: Array[Dictionary] = []
	@export var maintenance_history: Array[Dictionary] = []
	@export var fuel_level: int = 100
	@export var max_fuel_level: int = 100
	@export var cargo_capacity: int = 100
	@export var cargo_used: int = 0
	@export var crew_capacity: int = 6
	@export var current_crew_size: int = 0
	@export var ship_class: String = "Frigate"
	@export var ship_value: int = 50000
	@export var insurance_status: String = "Active"
	
	func _init(p_ship_name: String = "") -> void:
		ship_name = p_ship_name
	
	func take_damage(damage_amount: int) -> void:
		hull_integrity = max(0, hull_integrity - damage_amount)
	
	func repair_damage(repair_amount: int) -> void:
		hull_integrity = min(max_hull_integrity, hull_integrity + repair_amount)
	
	func add_modification(mod_data: Dictionary) -> void:
		modifications.append(mod_data)
	
	func add_maintenance_record(maintenance_data: Dictionary) -> void:
		maintenance_data["timestamp"] = Time.get_datetime_string_from_system()
		maintenance_history.append(maintenance_data)
	
	func get_hull_percentage() -> float:
		return float(hull_integrity) / float(max_hull_integrity)
	
	func get_fuel_percentage() -> float:
		return float(fuel_level) / float(max_fuel_level)
	
	func get_cargo_percentage() -> float:
		return float(cargo_used) / float(cargo_capacity)

# Campaign statistics and analytics
class _CampaignAnalytics extends Resource:
	@export var total_missions: int = 0
	@export var successful_missions: int = 0
	@export var failed_missions: int = 0
	@export var total_credits_earned: int = 0
	@export var total_credits_spent: int = 0
	@export var planets_visited: int = 0
	@export var unique_enemies_encountered: int = 0
	@export var crew_members_lost: int = 0
	@export var campaign_duration_days: int = 0
	@export var average_mission_duration: float = 0.0
	@export var most_common_mission_type: String = ""
	@export var most_profitable_planet: String = ""
	@export var best_performing_crew_member: String = ""
	@export var worst_performing_crew_member: String = ""
	@export var total_experience_gained: int = 0
	@export var story_progress_percentage: float = 0.0
	
	func _init() -> void:
		pass
	
	func update_mission_statistics(mission_data: Dictionary) -> void:
		total_missions += 1
		
		if mission_data.get("successful", false):
			successful_missions += 1
		else:
			failed_missions += 1
		
		total_credits_earned += mission_data.get("credits_earned", 0)
		total_credits_spent += mission_data.get("credits_spent", 0)
		total_experience_gained += mission_data.get("experience_gained", 0)
		
		# Update average mission duration
		var mission_duration = mission_data.get("duration_minutes", 0)
		average_mission_duration = ((average_mission_duration * (total_missions - 1)) + mission_duration) / total_missions
	
	func get_success_rate() -> float:
		return float(successful_missions) / max(total_missions, 1)
	
	func get_profit_margin() -> int:
		return total_credits_earned - total_credits_spent
	
	func get_campaign_efficiency() -> float:
		var efficiency = 0.0
		efficiency += get_success_rate() * 0.4
		efficiency += min(float(get_profit_margin()) / 10000.0, 1.0) * 0.3
		efficiency += min(float(total_experience_gained) / 1000.0, 1.0) * 0.3
		return efficiency

# Utility functions for data management
static func create_planet_profile(planet_name: String) -> PlanetProfile:
	return PlanetProfile.new(planet_name)

static func create_mission_entry(mission_id: String) -> MissionHistoryEntry:
	return MissionHistoryEntry.new(mission_id)

static func create_relationship(character_id: String) -> CharacterRelationship:
	return CharacterRelationship.new(character_id)

static func create_economic_data() -> EconomicData:
	return EconomicData.new()

static func create_crew_performance(crew_id: String) -> CrewPerformanceData:
	return CrewPerformanceData.new(crew_id)

static func create_ship_status(ship_name: String) -> ShipStatusData:
	return ShipStatusData.new(ship_name)

static func create_campaign_analytics() -> _CampaignAnalytics:
	return _CampaignAnalytics.new()