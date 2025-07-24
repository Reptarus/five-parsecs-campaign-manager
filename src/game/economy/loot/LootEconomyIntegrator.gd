@tool
class_name LootEconomyIntegrator
extends RefCounted

## Loot Economy Integration for Five Parsecs Campaign Manager
##
## Integrates generated enemy loot with the existing economy system,
## handling market values, trade goods processing, and economic impacts.

const GameItem = preload("res://src/core/economy/loot/GameItem.gd")
const EconomySystem = preload("res://src/core/systems/EconomySystem.gd")
const EnemyLootGenerator = preload("res://src/game/economy/loot/EnemyLootGenerator.gd")

# Economic integration settings
@export var market_fluctuation_enabled: bool = true
@export var illegal_goods_penalty: float = 0.6  # Value reduction for illegal goods
@export var bulk_sale_bonus: float = 1.15  # Bonus for selling multiple items
@export var reputation_value_modifier: float = 1.0  # Player reputation affects prices

# Market demand tracking
var market_demand: Dictionary = {}
var contraband_heat_level: int = 1  # 1-5, affects illegal goods trading
var trade_routes: Array[String] = []

# Economic signals
signal loot_processed(processed_items: Array[GameItem], market_value: int)
signal contraband_detected(item: GameItem, heat_increase: int)
signal market_fluctuation(item_type: String, price_change: float)
signal bulk_bonus_applied(item_count: int, bonus_value: int)

## Process battle loot and integrate with economy
func process_battle_loot(battle_loot: Dictionary, location_context: Dictionary = {}) -> Dictionary:
	var processed_result: Dictionary = {
		"immediate_credits": 0,
		"trade_goods": [],
		"contraband_items": [],
		"equipment_items": [],
		"biological_samples": [],
		"data_items": [],
		"market_report": {},
		"economic_impact": {}
	}
	
	var all_items: Array[GameItem] = battle_loot.get("combined_items", [])
	var total_market_value: int = 0
	
	# Process immediate credits
	processed_result.immediate_credits = battle_loot.get("total_credits", 0)
	
	# Categorize and process items
	for item in all_items:
		match item.item_type:
			GameItem.ItemType.CREDITS:
				processed_result.immediate_credits += item.value
			
			GameItem.ItemType.TRADE_GOOD:
				var trade_value: int = _process_trade_good(item, location_context)
				processed_result.trade_goods.append({"item": item, "market_value": trade_value})
				total_market_value += trade_value
			
			GameItem.ItemType.CONTRABAND:
				var contraband_result: Dictionary = _process_contraband(item, location_context)
				processed_result.contraband_items.append(contraband_result)
				total_market_value += contraband_result.market_value
			
			GameItem.ItemType.EQUIPMENT, GameItem.ItemType.WEAPON, GameItem.ItemType.ARMOR:
				var equipment_value: int = _process_equipment(item, location_context)
				processed_result.equipment_items.append({"item": item, "market_value": equipment_value})
				total_market_value += equipment_value
			
			GameItem.ItemType.BIOLOGICAL:
				var bio_value: int = _process_biological_sample(item, location_context)
				processed_result.biological_samples.append({"item": item, "research_value": bio_value})
				total_market_value += bio_value
			
			GameItem.ItemType.DATA:
				var data_result: Dictionary = _process_data_item(item, location_context)
				processed_result.data_items.append(data_result)
				total_market_value += data_result.information_value
	
	# Generate market report
	processed_result.market_report = _generate_market_report(all_items, location_context)
	
	# Calculate economic impact
	processed_result.economic_impact = _calculate_economic_impact(all_items, total_market_value, location_context)
	
	# Apply bulk processing bonuses
	if all_items.size() >= 5:
		var bulk_bonus: int = _apply_bulk_processing_bonus(processed_result, all_items.size())
		processed_result.economic_impact["bulk_bonus"] = bulk_bonus
		bulk_bonus_applied.emit(all_items.size(), bulk_bonus)
	
	loot_processed.emit(all_items, total_market_value)
	return processed_result

## Calculate market value for a specific item
func calculate_market_value(item: GameItem, market_context: Dictionary = {}) -> int:
	var base_value: int = item.value
	var market_modifier: float = 1.0
	
	# Apply quality modifiers
	match item.quality:
		GameItem.Quality.POOR: market_modifier *= 0.6
		GameItem.Quality.STANDARD: market_modifier *= 1.0
		GameItem.Quality.GOOD: market_modifier *= 1.3
		GameItem.Quality.EXCELLENT: market_modifier *= 1.7
		GameItem.Quality.MASTERWORK: market_modifier *= 2.5
	
	# Apply condition modifiers
	match item.condition:
		GameItem.Condition.BROKEN: market_modifier *= 0.2
		GameItem.Condition.POOR: market_modifier *= 0.5
		GameItem.Condition.DAMAGED: market_modifier *= 0.8
		GameItem.Condition.GOOD: market_modifier *= 1.0
		GameItem.Condition.EXCELLENT: market_modifier *= 1.2
	
	# Market demand adjustments
	var demand_level: float = _get_market_demand(item, market_context)
	market_modifier *= demand_level
	
	# Location-specific modifiers
	var location_modifier: float = _get_location_modifier(item, market_context)
	market_modifier *= location_modifier
	
	# Apply reputation modifier
	market_modifier *= reputation_value_modifier
	
	return roundi(base_value * market_modifier)

## Process contraband trade with risk/reward mechanics
func process_contraband_trade(contraband_items: Array[GameItem], trade_context: Dictionary) -> Dictionary:
	var trade_result: Dictionary = {
		"total_value": 0,
		"risk_level": 0,
		"heat_increase": 0,
		"successful_trades": [],
		"failed_trades": [],
		"complications": []
	}
	
	var base_risk: int = contraband_heat_level
	var location_risk: int = trade_context.get("law_enforcement_level", 3)
	
	for item in contraband_items:
		var item_trade_result: Dictionary = _attempt_contraband_trade(item, base_risk + location_risk, trade_context)
		
		if item_trade_result.success:
			trade_result.successful_trades.append(item_trade_result)
			trade_result.total_value += item_trade_result.value
		else:
			trade_result.failed_trades.append(item_trade_result)
			trade_result.complications.append_array(item_trade_result.complications)
		
		trade_result.risk_level += item_trade_result.risk_added
		trade_result.heat_increase += item_trade_result.heat_increase
	
	# Update heat level
	contraband_heat_level = mini(contraband_heat_level + trade_result.heat_increase, 5)
	
	return trade_result

## Update market demand based on recent activities
func update_market_demand(items_traded: Array[GameItem], location: String) -> void:
	if not market_fluctuation_enabled:
		return
	
	for item in items_traded:
		var item_key: String = _get_item_market_key(item)
		
		# Increase supply (decreases demand)
		if not market_demand.has(item_key):
			market_demand[item_key] = 1.0
		
		market_demand[item_key] -= 0.1  # Supply increase reduces price
		market_demand[item_key] = maxf(market_demand[item_key], 0.3)  # Minimum 30% value
		
		market_fluctuation.emit(item_key, market_demand[item_key] - 1.0)
	
	# Gradual market recovery over time
	_apply_market_recovery()

## Get current market conditions for planning
func get_market_intelligence(location: String) -> Dictionary:
	var intelligence: Dictionary = {
		"high_demand_items": [],
		"oversupplied_items": [],
		"contraband_risk": contraband_heat_level,
		"trade_opportunities": [],
		"market_trends": {}
	}
	
	# Analyze current market demand
	for item_key in market_demand.keys():
		var demand: float = market_demand[item_key]
		if demand >= 1.3:
			intelligence.high_demand_items.append({"item_type": item_key, "demand_level": demand})
		elif demand <= 0.7:
			intelligence.oversupplied_items.append({"item_type": item_key, "supply_level": demand})
	
	# Identify trade opportunities
	intelligence.trade_opportunities = _identify_trade_opportunities(location)
	
	# Market trend analysis
	intelligence.market_trends = _analyze_market_trends()
	
	return intelligence

## Private Methods

func _process_trade_good(item: GameItem, context: Dictionary) -> int:
	var market_value: int = calculate_market_value(item, context)
	
	# Trade goods benefit from trade route bonuses
	var location: String = context.get("location", "")
	if location in trade_routes:
		market_value = roundi(market_value * 1.2)
	
	return market_value

func _process_contraband(item: GameItem, context: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"item": item,
		"base_value": item.value,
		"market_value": 0,
		"risk_level": 0,
		"potential_complications": []
	}
	
	# Contraband has high value but significant risks
	var base_market_value: int = calculate_market_value(item, context)
	result.market_value = roundi(base_market_value * 1.5)  # 50% premium for contraband
	
	# Calculate risk based on item danger level and local law enforcement
	var danger_level: int = _extract_danger_level(item)
	var law_enforcement: int = context.get("law_enforcement_level", 3)
	result.risk_level = danger_level + law_enforcement
	
	# Add potential complications
	result.potential_complications = _generate_contraband_complications(item, result.risk_level)
	
	contraband_detected.emit(item, danger_level)
	return result

func _process_equipment(item: GameItem, context: Dictionary) -> int:
	var market_value: int = calculate_market_value(item, context)
	
	# Military equipment has restricted markets
	if item.tags.has("military"):
		market_value = roundi(market_value * 0.8)  # Harder to sell legally
	
	# Illegal equipment is treated as contraband
	if item.tags.has("illegal"):
		market_value = roundi(market_value * illegal_goods_penalty)
	
	return market_value

func _process_biological_sample(item: GameItem, context: Dictionary) -> int:
	var base_value: int = calculate_market_value(item, context)
	
	# Biological samples have research value
	var research_modifier: float = 1.0
	
	# Rare species or special abilities increase value
	if item.tags.has("apex_predator") or item.tags.has("rare"):
		research_modifier *= 2.0
	
	# Environmental adaptation has scientific value
	for tag in item.tags:
		if tag.begins_with("environment_"):
			research_modifier *= 1.3
			break
	
	return roundi(base_value * research_modifier)

func _process_data_item(item: GameItem, context: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"item": item,
		"information_value": 0,
		"intelligence_type": "general",
		"security_risk": 0,
		"potential_buyers": []
	}
	
	var base_value: int = calculate_market_value(item, context)
	
	# Determine intelligence type and value
	if item.tags.has("tactical_data"):
		result.intelligence_type = "tactical"
		result.information_value = roundi(base_value * 1.5)
		result.potential_buyers.append("mercenaries")
		result.potential_buyers.append("military")
	elif item.tags.has("classified"):
		result.intelligence_type = "classified"
		result.information_value = roundi(base_value * 2.0)
		result.security_risk = 3
		result.potential_buyers.append("corporations")
		result.potential_buyers.append("criminals")
	else:
		result.intelligence_type = "general"
		result.information_value = base_value
		result.potential_buyers.append("traders")
	
	return result

func _get_market_demand(item: GameItem, context: Dictionary) -> float:
	var item_key: String = _get_item_market_key(item)
	return market_demand.get(item_key, 1.0)

func _get_location_modifier(item: GameItem, context: Dictionary) -> float:
	var location_type: String = context.get("location_type", "standard")
	var modifier: float = 1.0
	
	match location_type:
		"corporate_world":
			if item.item_type in [GameItem.ItemType.EQUIPMENT, GameItem.ItemType.DATA]:
				modifier = 1.3
		"frontier":
			if item.item_type in [GameItem.ItemType.WEAPON, GameItem.ItemType.ARMOR]:
				modifier = 1.2
		"research_station":
			if item.item_type == GameItem.ItemType.BIOLOGICAL:
				modifier = 1.5
		"trading_hub":
			modifier = 1.1  # General bonus for all items
		"lawless":
			if item.tags.has("illegal") or item.item_type == GameItem.ItemType.CONTRABAND:
				modifier = 1.4
	
	return modifier

func _get_item_market_key(item: GameItem) -> String:
	var key: String = GameItem.ItemType.find_key(item.item_type)
	if item.tags.size() > 0:
		key += "_" + item.tags[0]
	return key

func _extract_danger_level(item: GameItem) -> int:
	for tag in item.tags:
		if tag.begins_with("danger_"):
			return int(tag.split("_")[1])
	return 1

func _generate_contraband_complications(item: GameItem, risk_level: int) -> Array[String]:
	var complications: Array[String] = []
	
	if risk_level >= 6:
		complications.append("law_enforcement_investigation")
		complications.append("reputation_damage")
	elif risk_level >= 4:
		complications.append("market_scrutiny")
		complications.append("reduced_access")
	elif risk_level >= 2:
		complications.append("price_penalty")
	
	return complications

func _attempt_contraband_trade(item: GameItem, total_risk: int, context: Dictionary) -> Dictionary:
	var trade_result: Dictionary = {
		"item": item,
		"success": false,
		"value": 0,
		"risk_added": 1,
		"heat_increase": 0,
		"complications": []
	}
	
	# Calculate success chance
	var success_chance: float = maxf(0.9 - (total_risk * 0.1), 0.1)
	var crew_skill: float = context.get("crew_trade_skill", 0.0)
	success_chance += crew_skill * 0.1
	
	if randf() < success_chance:
		trade_result.success = true
		trade_result.value = roundi(item.value * 1.8)  # High premium for successful contraband trade
		trade_result.heat_increase = 1
	else:
		trade_result.success = false
		trade_result.complications = ["failed_trade", "increased_suspicion"]
		trade_result.heat_increase = 2
		trade_result.risk_added = 2
	
	return trade_result

func _generate_market_report(items: Array[GameItem], context: Dictionary) -> Dictionary:
	var report: Dictionary = {
		"total_items_processed": items.size(),
		"item_type_breakdown": {},
		"average_quality": 0.0,
		"market_sentiment": "neutral",
		"recommendations": []
	}
	
	var total_quality: int = 0
	var quality_items: int = 0
	
	# Analyze item composition
	for item in items:
		var type_key: String = GameItem.ItemType.find_key(item.item_type)
		report.item_type_breakdown[type_key] = report.item_type_breakdown.get(type_key, 0) + 1
		
		total_quality += item.quality
		quality_items += 1
	
	# Calculate average quality
	if quality_items > 0:
		report.average_quality = float(total_quality) / quality_items
	
	# Determine market sentiment
	if report.average_quality >= GameItem.Quality.GOOD:
		report.market_sentiment = "positive"
		report.recommendations.append("Hold for better prices")
	elif report.average_quality <= GameItem.Quality.POOR:
		report.market_sentiment = "negative"
		report.recommendations.append("Sell quickly before further devaluation")
	
	return report

func _calculate_economic_impact(items: Array[GameItem], total_value: int, context: Dictionary) -> Dictionary:
	var impact: Dictionary = {
		"crew_wealth_increase": total_value,
		"market_disruption": 0,
		"reputation_change": 0,
		"economic_activity": "low"
	}
	
	# Large value trades have market impact
	if total_value >= 5000:
		impact.market_disruption = 1
		impact.economic_activity = "high"
	elif total_value >= 2000:
		impact.economic_activity = "moderate"
	
	# High-quality items boost reputation
	var high_quality_count: int = 0
	for item in items:
		if item.quality >= GameItem.Quality.EXCELLENT:
			high_quality_count += 1
	
	if high_quality_count >= 3:
		impact.reputation_change = 1
	
	return impact

func _apply_bulk_processing_bonus(result: Dictionary, item_count: int) -> int:
	var bonus_percentage: float = mini(item_count * 0.02, 0.3)  # Max 30% bonus
	var current_value: int = 0
	
	# Calculate current total value
	for trade_good in result.trade_goods:
		current_value += trade_good.market_value
	for equipment in result.equipment_items:
		current_value += equipment.market_value
	
	var bonus_value: int = roundi(current_value * bonus_percentage)
	
	# Apply bonus to immediate credits
	result.immediate_credits += bonus_value
	
	return bonus_value

func _apply_market_recovery() -> void:
	# Gradually recover market demand over time
	for item_key in market_demand.keys():
		var current_demand: float = market_demand[item_key]
		if current_demand < 1.0:
			market_demand[item_key] = minf(current_demand + 0.05, 1.0)
		elif current_demand > 1.0:
			market_demand[item_key] = maxf(current_demand - 0.03, 1.0)

func _identify_trade_opportunities(location: String) -> Array[Dictionary]:
	var opportunities: Array[Dictionary] = []
	
	# High demand items represent opportunities
	for item_key in market_demand.keys():
		var demand: float = market_demand[item_key]
		if demand >= 1.2:
			opportunities.append({
				"item_type": item_key,
				"opportunity_type": "high_demand",
				"profit_potential": roundi((demand - 1.0) * 100)
			})
	
	return opportunities

func _analyze_market_trends() -> Dictionary:
	var trends: Dictionary = {
		"rising_markets": [],
		"declining_markets": [],
		"stable_markets": [],
		"volatility_level": "low"
	}
	
	var volatile_count: int = 0
	
	for item_key in market_demand.keys():
		var demand: float = market_demand[item_key]
		
		if demand >= 1.15:
			trends.rising_markets.append(item_key)
			volatile_count += 1
		elif demand <= 0.85:
			trends.declining_markets.append(item_key)
			volatile_count += 1
		else:
			trends.stable_markets.append(item_key)
	
	# Determine volatility
	var total_markets: int = market_demand.size()
	if total_markets > 0:
		var volatility_ratio: float = float(volatile_count) / total_markets
		if volatility_ratio >= 0.4:
			trends.volatility_level = "high"
		elif volatility_ratio >= 0.2:
			trends.volatility_level = "moderate"
	
	return trends