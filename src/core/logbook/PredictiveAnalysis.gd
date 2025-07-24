@tool
extends RefCounted
class_name PredictiveAnalysis

## Predictive Analysis System - Intelligent suggestions based on historical data
## Follows dice system context-aware suggestions patterns
## Provides data-driven recommendations for campaign decision-making

# Universal Safety patterns
const LogbookDataManager = preload("res://src/core/logbook/LogbookDataManager.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")

# Analysis components
var logbook_data_manager: LogbookDataManager
var prediction_models: Dictionary = {}
var confidence_thresholds: Dictionary = {}
var suggestion_cache: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _init() -> void:
	logbook_data_manager = LogbookDataManager.new()
	enhanced_signals = EnhancedCampaignSignals.new()
	_setup_prediction_models()
	_connect_signals()

func _setup_prediction_models() -> void:
	# Initialize prediction models with confidence thresholds
	prediction_models = {
		"trade_opportunities": 0.7,
		"patron_contacts": 0.8,
		"mission_risks": 0.6,
		"crew_development": 0.75,
		"ship_maintenance": 0.8,
		"world_exploration": 0.7
	}
	
	confidence_thresholds = {
		"high": 0.8,
		"medium": 0.6,
		"low": 0.4
	}

func _connect_signals() -> void:
	# Connect to enhanced campaign signals for automatic analysis
	enhanced_signals.connect_signal_safely("pattern_discovered", self, "_on_pattern_discovered")
	enhanced_signals.connect_signal_safely("mission_logged", self, "_on_mission_logged")
	enhanced_signals.connect_signal_safely("economic_data_updated", self, "_on_economic_data_updated")

## Main analysis functions
func analyze_trade_opportunities(current_world: String) -> Array[Dictionary]:
	var opportunities: Array[Dictionary] = []
	var world_data = logbook_data_manager.get_planet_profiles().get(current_world, {})
	var historical_prices = _get_price_history(current_world)
	
	# Analyze patterns and suggest opportunities
	for commodity in historical_prices:
		var suggestion = _calculate_trade_suggestion(commodity, world_data)
		if suggestion.confidence > prediction_models.trade_opportunities:
			opportunities.append(suggestion)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("predictive_suggestion_generated", ["trade_opportunities", opportunities])
	
	return opportunities

func suggest_patron_contacts(current_world: String) -> Array[Dictionary]:
	# Analyze successful past missions to suggest patron types
	var successful_missions = _filter_successful_missions(current_world)
	var patron_suggestions = _analyze_patron_patterns(successful_missions)
	
	# Filter by confidence threshold
	var high_confidence_suggestions: Array[Dictionary] = []
	for suggestion in patron_suggestions:
		if suggestion.confidence > prediction_models.patron_contacts:
			high_confidence_suggestions.append(suggestion)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("predictive_suggestion_generated", ["patron_contacts", high_confidence_suggestions])
	
	return high_confidence_suggestions

func assess_mission_risks(mission_type: String, crew_data: Array) -> Dictionary:
	# Assess mission risks based on historical data and crew capabilities
	var risk_assessment = {
		"overall_risk": "medium",
		"crew_risk": 0.0,
		"mission_type_risk": 0.0,
		"recommendations": []
	}
	
	# Calculate crew risk
	risk_assessment.crew_risk = _calculate_crew_risk(crew_data)
	
	# Calculate mission type risk
	risk_assessment.mission_type_risk = _calculate_mission_type_risk(mission_type)
	
	# Determine overall risk
	var overall_risk_score = (risk_assessment.crew_risk + risk_assessment.mission_type_risk) / 2.0
	risk_assessment.overall_risk = _categorize_risk_level(overall_risk_score)
	
	# Generate recommendations
	risk_assessment.recommendations = _generate_risk_recommendations(risk_assessment)
	
	# Emit risk assessment signal
	enhanced_signals.emit_safe_signal("risk_assessment", [risk_assessment.overall_risk, risk_assessment.recommendations])
	
	return risk_assessment

func predict_crew_development_needs(crew_data: Array) -> Array[Dictionary]:
	# Predict crew development needs based on performance patterns
	var development_suggestions: Array[Dictionary] = []
	
	for crew_member in crew_data:
		var performance_analysis = _analyze_crew_performance(crew_member)
		var development_needs = _identify_development_needs(performance_analysis)
		
		if development_needs.confidence > prediction_models.crew_development:
			development_suggestions.append(development_needs)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("predictive_suggestion_generated", ["crew_development", development_suggestions])
	
	return development_suggestions

func predict_ship_maintenance_needs(ship_data: Dictionary) -> Dictionary:
	# Predict ship maintenance needs based on usage patterns
	var maintenance_prediction = {
		"next_maintenance": "unknown",
		"priority_repairs": [],
		"preventive_measures": [],
		"confidence": 0.0
	}
	
	# Analyze ship condition and usage
	var condition_analysis = _analyze_ship_condition(ship_data)
	var usage_patterns = _analyze_usage_patterns(ship_data)
	
	# Predict maintenance needs
	maintenance_prediction.next_maintenance = _predict_maintenance_timing(condition_analysis, usage_patterns)
	maintenance_prediction.priority_repairs = _identify_priority_repairs(condition_analysis)
	maintenance_prediction.preventive_measures = _suggest_preventive_measures(usage_patterns)
	maintenance_prediction.confidence = _calculate_maintenance_confidence(condition_analysis, usage_patterns)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("predictive_suggestion_generated", ["ship_maintenance", maintenance_prediction])
	
	return maintenance_prediction

func suggest_world_exploration_targets(explored_worlds: Array) -> Array[Dictionary]:
	# Suggest world exploration targets based on patterns and opportunities
	var exploration_suggestions: Array[Dictionary] = []
	var world_profiles = logbook_data_manager.get_planet_profiles()
	
	# Analyze exploration patterns
	var exploration_patterns = _analyze_exploration_patterns(explored_worlds)
	
	# Generate suggestions for unexplored worlds
	for world_name in world_profiles.keys():
		if world_name not in explored_worlds:
			var suggestion = _generate_exploration_suggestion(world_name, world_profiles[world_name], exploration_patterns)
			if suggestion.confidence > prediction_models.world_exploration:
				exploration_suggestions.append(suggestion)
	
	# Emit signal for UI updates
	enhanced_signals.emit_safe_signal("predictive_suggestion_generated", ["world_exploration", exploration_suggestions])
	
	return exploration_suggestions

## Helper analysis functions
func _get_price_history(world_name: String) -> Dictionary:
	# Get historical price data for trade analysis
	var economic_data = logbook_data_manager.get_economic_data()
	var price_history: Dictionary = {}
	
	# Analyze price trends from economic data
	for timestamp in economic_data.keys():
		var entry = economic_data[timestamp]
		if entry.context.has("commodity"):
			var commodity = entry.context.commodity
			if not price_history.has(commodity):
				price_history[commodity] = []
			price_history[commodity].append(entry.context.get("price", 0))
	
	return price_history

func _calculate_trade_suggestion(commodity: String, world_data: Dictionary) -> Dictionary:
	# Calculate trade suggestion based on price patterns
	var suggestion = {
		"commodity": commodity,
		"action": "unknown",
		"confidence": 0.0,
		"reasoning": ""
	}
	
	# Simple price trend analysis
	var prices = _get_price_history(world_data.get("planet_name", ""))
	if prices.has(commodity) and prices[commodity].size() >= 3:
		var recent_prices = prices[commodity].slice(-3)
		var price_trend = _calculate_price_trend(recent_prices)
		
		if price_trend > 0.1: # 10% increase
			suggestion.action = "buy"
			suggestion.confidence = 0.8
			suggestion.reasoning = "Price trend indicates upward movement"
		elif price_trend < -0.1: # 10% decrease
			suggestion.action = "sell"
			suggestion.confidence = 0.7
			suggestion.reasoning = "Price trend indicates downward movement"
		else:
			suggestion.action = "hold"
			suggestion.confidence = 0.6
			suggestion.reasoning = "Price trend is stable"
	
	return suggestion

func _filter_successful_missions(world_name: String) -> Array:
	# Filter successful missions for patron analysis
	var missions = logbook_data_manager.get_mission_archive()
	var successful_missions: Array = []
	
	for mission in missions:
		if mission.outcome == "success" and mission.mission_type != "unknown":
			successful_missions.append(mission)
	
	return successful_missions

func _analyze_patron_patterns(successful_missions: Array) -> Array[Dictionary]:
	# Analyze patron patterns from successful missions
	var patron_suggestions: Array[Dictionary] = []
	var mission_type_counts: Dictionary = {}
	
	# Count successful mission types
	for mission in successful_missions:
		var mission_type = mission.mission_type
		if not mission_type_counts.has(mission_type):
			mission_type_counts[mission_type] = 0
		mission_type_counts[mission_type] += 1
	
	# Generate patron suggestions based on successful mission types
	for mission_type in mission_type_counts.keys():
		var success_rate = float(mission_type_counts[mission_type]) / float(successful_missions.size())
		if success_rate > 0.3: # 30% success rate threshold
			var suggestion = {
				"patron_type": _map_mission_type_to_patron(mission_type),
				"confidence": success_rate,
				"reasoning": "High success rate with %s missions" % mission_type
			}
			patron_suggestions.append(suggestion)
	
	return patron_suggestions

func _calculate_crew_risk(crew_data: Array) -> float:
	# Calculate crew risk based on health and performance
	var total_risk = 0.0
	
	for crew_member in crew_data:
		var health_risk = 1.0 - crew_member.get("health_ratio", 1.0)
		var performance_risk = 1.0 - crew_member.get("performance_rating", 1.0)
		var member_risk = (health_risk + performance_risk) / 2.0
		total_risk += member_risk
	
	return total_risk / crew_data.size() if crew_data.size() > 0 else 0.0

func _calculate_mission_type_risk(mission_type: String) -> float:
	# Calculate risk based on mission type from historical data
	var missions = logbook_data_manager.get_mission_archive()
	var mission_type_missions: Array = []
	
	for mission in missions:
		if mission.mission_type == mission_type:
			mission_type_missions.append(mission)
	
	if mission_type_missions.size() == 0:
		return 0.5 # Default medium risk for unknown mission types
	
	var success_count = 0
	for mission in mission_type_missions:
		if mission.outcome == "success":
			success_count += 1
	
	var success_rate = float(success_count) / float(mission_type_missions.size())
	return 1.0 - success_rate # Risk is inverse of success rate

func _categorize_risk_level(risk_score: float) -> String:
	if risk_score < 0.3:
		return "low"
	elif risk_score < 0.7:
		return "medium"
	else:
		return "high"

func _generate_risk_recommendations(risk_assessment: Dictionary) -> Array:
	# Generate recommendations based on risk assessment
	var recommendations: Array = []
	
	if risk_assessment.crew_risk > 0.5:
		recommendations.append("Consider crew training or healing before mission")
	
	if risk_assessment.mission_type_risk > 0.6:
		recommendations.append("This mission type has historically high failure rate")
	
	if risk_assessment.overall_risk == "high":
		recommendations.append("Consider upgrading equipment or hiring additional crew")
	
	return recommendations

func _analyze_crew_performance(crew_member: Dictionary) -> Dictionary:
	# Analyze individual crew member performance
	var analysis = {
		"combat_rating": crew_member.get("combat", 0),
		"health_status": crew_member.get("health_ratio", 1.0),
		"mission_count": crew_member.get("missions_completed", 0),
		"success_rate": crew_member.get("success_rate", 0.0)
	}
	
	return analysis

func _identify_development_needs(performance_analysis: Dictionary) -> Dictionary:
	# Identify crew development needs
	var development_needs = {
		"crew_id": "",
		"priority_skill": "unknown",
		"confidence": 0.0,
		"reasoning": ""
	}
	
	# Simple development logic
	if performance_analysis.combat_rating < 2:
		development_needs.priority_skill = "combat"
		development_needs.confidence = 0.8
		development_needs.reasoning = "Low combat rating suggests need for training"
	elif performance_analysis.health_status < 0.7:
		development_needs.priority_skill = "health"
		development_needs.confidence = 0.9
		development_needs.reasoning = "Poor health status requires attention"
	elif performance_analysis.success_rate < 0.5:
		development_needs.priority_skill = "general"
		development_needs.confidence = 0.7
		development_needs.reasoning = "Low success rate indicates need for improvement"
	
	return development_needs

func _analyze_ship_condition(ship_data: Dictionary) -> Dictionary:
	# Analyze ship condition
	var condition = {
		"hull_condition": float(ship_data.get("hull_current", 0)) / float(ship_data.get("hull_max", 100)),
		"modification_count": ship_data.get("modifications", []).size(),
		"debt_ratio": float(ship_data.get("debt_amount", 0)) / 10000.0
	}
	
	return condition

func _analyze_usage_patterns(ship_data: Dictionary) -> Dictionary:
	# Analyze ship usage patterns
	var usage = {
		"missions_since_repair": ship_data.get("missions_since_repair", 0),
		"average_damage_per_mission": ship_data.get("average_damage", 0),
		"last_maintenance": ship_data.get("last_maintenance", "unknown")
	}
	
	return usage

func _predict_maintenance_timing(condition: Dictionary, usage: Dictionary) -> String:
	# Predict when next maintenance is needed
	var hull_condition = condition.hull_condition
	var missions_since_repair = usage.missions_since_repair
	
	if hull_condition < 0.5:
		return "immediate"
	elif hull_condition < 0.7 or missions_since_repair > 5:
		return "soon"
	else:
		return "scheduled"

func _identify_priority_repairs(condition: Dictionary) -> Array:
	# Identify priority repairs needed
	var repairs: Array = []
	
	if condition.hull_condition < 0.5:
		repairs.append("Hull damage requires immediate repair")
	
	if condition.debt_ratio > 0.8:
		repairs.append("High debt may limit repair options")
	
	return repairs

func _suggest_preventive_measures(usage: Dictionary) -> Array:
	# Suggest preventive measures
	var measures: Array = []
	
	if usage.average_damage_per_mission > 10:
		measures.append("Consider upgrading ship armor")
	
	if usage.missions_since_repair > 3:
		measures.append("Schedule regular maintenance")
	
	return measures

func _calculate_maintenance_confidence(condition: Dictionary, usage: Dictionary) -> float:
	# Calculate confidence in maintenance prediction
	var confidence = 0.5 # Base confidence
	
	if condition.hull_condition < 0.7:
		confidence += 0.3
	
	if usage.missions_since_repair > 3:
		confidence += 0.2
	
	return min(confidence, 1.0)

func _analyze_exploration_patterns(explored_worlds: Array) -> Dictionary:
	# Analyze exploration patterns
	var patterns = {
		"preferred_tech_levels": [],
		"successful_government_types": [],
		"exploration_frequency": explored_worlds.size()
	}
	
	# Analyze patterns from explored worlds
	var world_profiles = logbook_data_manager.get_planet_profiles()
	for world_name in explored_worlds:
		if world_profiles.has(world_name):
			var world = world_profiles[world_name]
			patterns.preferred_tech_levels.append(world.tech_level)
			patterns.successful_government_types.append(world.government_type)
	
	return patterns

func _generate_exploration_suggestion(world_name: String, world_data: Dictionary, patterns: Dictionary) -> Dictionary:
	# Generate exploration suggestion
	var suggestion = {
		"world_name": world_name,
		"priority": "medium",
		"confidence": 0.5,
		"reasoning": ""
	}
	
	# Calculate priority based on patterns
	var tech_level = world_data.get("tech_level", 3)
	var government_type = world_data.get("government_type", "unknown")
	
	# Check if tech level matches preferences
	if patterns.preferred_tech_levels.has(tech_level):
		suggestion.priority = "high"
		suggestion.confidence += 0.2
		suggestion.reasoning += "Matches preferred tech level. "
	
	# Check if government type matches successful patterns
	if patterns.successful_government_types.has(government_type):
		suggestion.priority = "high"
		suggestion.confidence += 0.2
		suggestion.reasoning += "Matches successful government type. "
	
	if suggestion.reasoning.is_empty():
		suggestion.reasoning = "Standard exploration opportunity"
	
	return suggestion

func _calculate_price_trend(prices: Array) -> float:
	# Calculate price trend from recent prices
	if prices.size() < 2:
		return 0.0
	
	var first_price = float(prices[0])
	var last_price = float(prices[-1])
	
	return (last_price - first_price) / first_price

func _map_mission_type_to_patron(mission_type: String) -> String:
	# Map mission type to patron type
	match mission_type:
		"combat":
			return "military"
		"recovery":
			return "corporate"
		"exploration":
			return "academic"
		"trade":
			return "merchant"
		_:
			return "general"

## Signal handlers
func _on_pattern_discovered(pattern_type: String, confidence: float) -> void:
	# Handle pattern discovery
	if confidence > confidence_thresholds.high:
		_generate_high_confidence_suggestions(pattern_type)

func _on_mission_logged(mission_data: Dictionary) -> void:
	# Update prediction models based on new mission data
	_update_prediction_models(mission_data)

func _on_economic_data_updated(credits: int, debt: int) -> void:
	# Update economic predictions based on new data
	_update_economic_predictions(credits, debt)

func _generate_high_confidence_suggestions(pattern_type: String) -> void:
	# Generate high confidence suggestions based on discovered patterns
	pass

func _update_prediction_models(mission_data: Dictionary) -> void:
	# Update prediction models with new mission data
	pass

func _update_economic_predictions(credits: int, debt: int) -> void:
	# Update economic predictions with new data
	pass

## Public API for external access
func get_prediction_models() -> Dictionary:
	return prediction_models

func get_confidence_thresholds() -> Dictionary:
	return confidence_thresholds

func get_suggestion_cache() -> Dictionary:
	return suggestion_cache