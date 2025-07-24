@tool
extends RefCounted
class_name LogbookDataManager

## Enhanced Logbook Data Manager - Intelligent data storage with search and analysis capabilities
## Follows proven data management patterns from successful existing systems
## Provides comprehensive data storage, validation, and analysis for campaign logbook

# Universal Safety patterns
const UniversalResourceLoader = preload("res://src/core/systems/UniversalResourceLoader.gd")
const CampaignDataStructures = preload("res://src/core/data/CampaignDataStructures.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")

# Enhanced data storage following established patterns
var planet_profiles: Dictionary = {}
var mission_archive: Array[CampaignDataStructures.MissionHistoryEntry] = []
var relationship_history: Dictionary = {}
var economic_data_cache: Dictionary = {}
var crew_performance_log: Dictionary = {}
var ship_maintenance_log: Dictionary = {}

# Search and analysis capabilities
var search_index: Dictionary = {}
var analysis_cache: Dictionary = {}
var pattern_recognition: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _init() -> void:
	enhanced_signals = EnhancedCampaignSignals.new()
	_setup_data_structures()
	_connect_signals()

func _setup_data_structures() -> void:
	# Initialize data structures with validation
	planet_profiles = {}
	mission_archive = []
	relationship_history = {}
	economic_data_cache = {}
	crew_performance_log = {}
	ship_maintenance_log = {}
	
	# Initialize search and analysis systems
	search_index = {}
	analysis_cache = {}
	pattern_recognition = {}

func _connect_signals() -> void:
	# Connect to enhanced campaign signals for automatic logging
	enhanced_signals.connect_signal_safely("mission_logged", self, "_on_mission_logged")
	enhanced_signals.connect_signal_safely("planet_data_updated", self, "_on_planet_data_updated")
	enhanced_signals.connect_signal_safely("relationship_changed", self, "_on_relationship_changed")
	enhanced_signals.connect_signal_safely("economic_data_updated", self, "_on_economic_data_updated")

## Main data storage functions
func store_mission_result(mission_data: Dictionary) -> void:
	# Automatic logging following universal safety patterns
	var entry = CampaignDataStructures.MissionHistoryEntry.new()
	entry.populate_from_dictionary(mission_data) # Validation included
	mission_archive.append(entry)
	
	# Update search index
	_update_search_index("mission", entry)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("mission_logged", [entry])

func store_planet_data(planet_data: CampaignDataStructures.PlanetProfile) -> void:
	# Store planet profile with validation
	if _validate_planet_data(planet_data):
		planet_profiles[planet_data.planet_name] = planet_data
		
		# Update search index
		_update_search_index("planet", planet_data)
		
		# Emit signal for UI updates
		enhanced_signals.emit_safe_signal("planet_data_updated", [planet_data.planet_name, planet_data])

func store_relationship_data(entity_name: String, relationship_data: Dictionary) -> void:
	# Store relationship information
	if not relationship_history.has(entity_name):
		relationship_history[entity_name] = []
	
	relationship_history[entity_name].append(relationship_data)
	
	# Update search index
	_update_search_index("relationship", {"entity": entity_name, "data": relationship_data})
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("relationship_changed", [entity_name, relationship_data])

func store_economic_data(credits: int, debt: int, context: Dictionary = {}) -> void:
	# Store economic data with timestamp
	var economic_entry = {
		"credits": credits,
		"debt": debt,
		"timestamp": Time.get_datetime_string_from_system(),
		"context": context
	}
	
	economic_data_cache[Time.get_datetime_string_from_system()] = economic_entry
	
	# Update search index
	_update_search_index("economic", economic_entry)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("economic_data_updated", [credits, debt])

## Search and retrieval functions
func search_logbook(search_term: String, search_type: String = "all") -> Array:
	# Intelligent search with pattern matching
	var results: Array = []
	
	match search_type:
		"missions":
			results = _search_missions(search_term)
		"planets":
			results = _search_planets(search_term)
		"relationships":
			results = _search_relationships(search_term)
		"economic":
			results = _search_economic_data(search_term)
		_:
			# Search all categories
			results.append_array(_search_missions(search_term))
			results.append_array(_search_planets(search_term))
			results.append_array(_search_relationships(search_term))
			results.append_array(_search_economic_data(search_term))
	
	# Emit search results signal
	enhanced_signals.emit_safe_signal("logbook_search_performed", [search_term, results])
	
	return results

func _search_missions(search_term: String) -> Array:
	var results: Array = []
	var term_lower = search_term.to_lower()
	
	for mission in mission_archive:
		if term_lower in mission.mission_id.to_lower() or \
		   term_lower in mission.mission_type.to_lower() or \
		   term_lower in mission.outcome.to_lower():
			results.append(mission)
	
	return results

func _search_planets(search_term: String) -> Array:
	var results: Array = []
	var term_lower = search_term.to_lower()
	
	for planet_name in planet_profiles.keys():
		var planet = planet_profiles[planet_name]
		if term_lower in planet.planet_name.to_lower() or \
		   term_lower in planet.government_type.to_lower():
			results.append(planet)
	
	return results

func _search_relationships(search_term: String) -> Array:
	var results: Array = []
	var term_lower = search_term.to_lower()
	
	for entity_name in relationship_history.keys():
		if term_lower in entity_name.to_lower():
			results.append_array(relationship_history[entity_name])
	
	return results

func _search_economic_data(search_term: String) -> Array:
	var results: Array = []
	var term_lower = search_term.to_lower()
	
	for timestamp in economic_data_cache.keys():
		var entry = economic_data_cache[timestamp]
		if term_lower in str(entry.credits) or \
		   term_lower in str(entry.debt) or \
		   term_lower in entry.context.get("reason", ""):
			results.append(entry)
	
	return results

## Analysis and pattern recognition
func analyze_campaign_patterns() -> Dictionary:
	# Analyze patterns in campaign data
	var analysis = {
		"mission_success_rate": _calculate_mission_success_rate(),
		"economic_trends": _analyze_economic_trends(),
		"crew_performance": _analyze_crew_performance(),
		"world_exploration": _analyze_world_exploration(),
		"relationship_network": _analyze_relationship_network()
	}
	
	# Cache analysis results
	analysis_cache = analysis
	
	# Emit pattern discovery signals
	for pattern_type in analysis.keys():
		if analysis[pattern_type].has("confidence"):
			enhanced_signals.emit_safe_signal("pattern_discovered", [pattern_type, analysis[pattern_type].confidence])
	
	return analysis

func _calculate_mission_success_rate() -> Dictionary:
	var total_missions = mission_archive.size()
	var successful_missions = 0
	
	for mission in mission_archive:
		if mission.outcome == "success":
			successful_missions += 1
	
	var success_rate = float(successful_missions) / float(total_missions) if total_missions > 0 else 0.0
	
	return {
		"total_missions": total_missions,
		"successful_missions": successful_missions,
		"success_rate": success_rate,
		"confidence": 0.9
	}

func _analyze_economic_trends() -> Dictionary:
	var entries = economic_data_cache.values()
	if entries.size() < 2:
		return {"trend": "insufficient_data", "confidence": 0.0}
	
	# Calculate trend
	var first_entry = entries[0]
	var last_entry = entries[-1]
	var credit_change = last_entry.credits - first_entry.credits
	var debt_change = last_entry.debt - first_entry.debt
	
	var trend = "stable"
	if credit_change > 1000:
		trend = "improving"
	elif credit_change < -1000:
		trend = "declining"
	
	return {
		"trend": trend,
		"credit_change": credit_change,
		"debt_change": debt_change,
		"confidence": 0.8
	}

func _analyze_crew_performance() -> Dictionary:
	# Analyze crew performance patterns
	var performance_data = crew_performance_log.values()
	var total_performance = 0.0
	
	for performance in performance_data:
		total_performance += performance.get("rating", 0.0)
	
	var avg_performance = total_performance / performance_data.size() if performance_data.size() > 0 else 0.0
	
	return {
		"average_performance": avg_performance,
		"crew_count": performance_data.size(),
		"confidence": 0.7
	}

func _analyze_world_exploration() -> Dictionary:
	var explored_worlds = planet_profiles.size()
	var total_locations = 0
	
	for planet in planet_profiles.values():
		total_locations += planet.discovered_locations.size()
	
	return {
		"explored_worlds": explored_worlds,
		"total_locations": total_locations,
		"exploration_rate": float(total_locations) / float(explored_worlds) if explored_worlds > 0 else 0.0,
		"confidence": 0.9
	}

func _analyze_relationship_network() -> Dictionary:
	var total_relationships = relationship_history.size()
	var active_relationships = 0
	
	for entity_relationships in relationship_history.values():
		if entity_relationships.size() > 0:
			active_relationships += 1
	
	return {
		"total_entities": total_relationships,
		"active_relationships": active_relationships,
		"network_density": float(active_relationships) / float(total_relationships) if total_relationships > 0 else 0.0,
		"confidence": 0.8
	}

## Data validation functions
func _validate_planet_data(planet_data: CampaignDataStructures.PlanetProfile) -> bool:
	# Validate planet data following universal safety patterns
	if planet_data.planet_name.is_empty():
		push_warning("LogbookDataManager: Planet name is empty")
		return false
	
	if planet_data.tech_level < 1 or planet_data.tech_level > 6:
		push_warning("LogbookDataManager: Invalid tech level: %d" % planet_data.tech_level)
		return false
	
	return true

func _validate_mission_data(mission_data: Dictionary) -> bool:
	# Validate mission data
	if not mission_data.has("mission_id"):
		push_warning("LogbookDataManager: Mission data missing mission_id")
		return false
	
	if not mission_data.has("outcome"):
		push_warning("LogbookDataManager: Mission data missing outcome")
		return false
	
	return true

## Search index management
func _update_search_index(category: String, data: Variant) -> void:
	# Update search index for efficient searching
	if not search_index.has(category):
		search_index[category] = []
	
	search_index[category].append(data)

## Signal handlers
func _on_mission_logged(mission_data: Dictionary) -> void:
	store_mission_result(mission_data)

func _on_planet_data_updated(planet_name: String, data: Dictionary) -> void:
	var planet_profile = CampaignDataStructures.PlanetProfile.new()
	planet_profile.populate_from_dictionary(data)
	store_planet_data(planet_profile)

func _on_relationship_changed(entity_name: String, change: Dictionary) -> void:
	store_relationship_data(entity_name, change)

func _on_economic_data_updated(credits: int, debt: int) -> void:
	store_economic_data(credits, debt)

## Public API for external access
func get_mission_archive() -> Array:
	return mission_archive

func get_planet_profiles() -> Dictionary:
	return planet_profiles

func get_relationship_history() -> Dictionary:
	return relationship_history

func get_economic_data() -> Dictionary:
	return economic_data_cache

func get_analysis_cache() -> Dictionary:
	return analysis_cache

func clear_old_data(days_to_keep: int = 30) -> void:
	# Clear old data to prevent memory bloat
	var cutoff_time = Time.get_unix_time_from_system() - (days_to_keep * 24 * 60 * 60)
	
	# Clear old economic data
	var keys_to_remove: Array = []
	for timestamp in economic_data_cache.keys():
		var entry_time = Time.get_unix_time_from_datetime_string(timestamp)
		if entry_time < cutoff_time:
			keys_to_remove.append(timestamp)
	
	for key in keys_to_remove:
		economic_data_cache.erase(key)