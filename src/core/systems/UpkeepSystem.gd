class_name UpkeepSystem
extends Resource

## Upkeep System for Five Parsecs Campaign Manager
## Handles crew maintenance, ship repairs, and campaign turn expenses

signal upkeep_calculated(cost: int, breakdown: Dictionary)
signal upkeep_paid(remaining_credits: int)
signal insufficient_funds(required: int, available: int)

# Upkeep costs from Five Parsecs rules
const BASE_CREW_UPKEEP = 1 # 1 credit per crew member
const SHIP_MAINTENANCE_BASE = 1 # Base ship maintenance cost
const INJURY_TREATMENT_COST = 2 # Cost per injured crew member
const LUXURY_UPKEEP_MODIFIER = 2 # Multiplier for luxury living

# Ship repair costs
const HULL_REPAIR_COST_PER_POINT = 3 # Credits per hull point to repair

func calculate_upkeep_costs(campaign_data: Resource) -> Dictionary:
	"""Calculate total upkeep costs for the campaign turn"""
	var breakdown = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"injury_treatment": 0,
		"luxury_costs": 0,
		"total": 0
	}
	
	# Get campaign data
	var crew_members = _get_crew_members(campaign_data)
	var ship_data = _get_ship_data(campaign_data)
	var living_standard = _get_living_standard(campaign_data)
	
	# Calculate crew upkeep
	breakdown.crew_upkeep = crew_members.size() * BASE_CREW_UPKEEP
	
	# Calculate ship maintenance
	if ship_data:
		breakdown.ship_maintenance = _calculate_ship_maintenance(ship_data)
	
	# Calculate injury treatment costs
	breakdown.injury_treatment = _calculate_injury_costs(crew_members)
	
	# Apply living standard modifiers
	if living_standard == "luxury":
		breakdown.luxury_costs = breakdown.crew_upkeep * LUXURY_UPKEEP_MODIFIER
	
	# Calculate total
	breakdown.total = breakdown.crew_upkeep + breakdown.ship_maintenance + breakdown.injury_treatment + breakdown.luxury_costs
	
	upkeep_calculated.emit(breakdown.total, breakdown)
	return breakdown

func pay_upkeep(campaign_data: Resource, upkeep_costs: Dictionary) -> bool:
	"""Attempt to pay upkeep costs"""
	var current_credits = _get_credits(campaign_data)
	var total_cost = upkeep_costs.total
	
	if current_credits >= total_cost:
		# Pay upkeep
		var remaining_credits = current_credits - total_cost
		_set_credits(campaign_data, remaining_credits)
		
		# Apply upkeep effects
		_apply_upkeep_effects(campaign_data, upkeep_costs)
		
		upkeep_paid.emit(remaining_credits)
		return true
	else:
		# Insufficient funds
		insufficient_funds.emit(total_cost, current_credits)
		return false

func _calculate_ship_maintenance(ship_data: Resource) -> int:
	"""Calculate ship maintenance costs"""
	var base_cost = SHIP_MAINTENANCE_BASE
	
	# Add costs for ship hull damage
	var hull_damage = ship_data.get_meta("hull_damage") if ship_data.has_method("get_meta") else 0
	var hull_repair_cost = hull_damage * HULL_REPAIR_COST_PER_POINT
	
	# Add costs for ship modifications
	var modifications = ship_data.get_meta("modifications") if ship_data.has_method("get_meta") else []
	var modification_maintenance = modifications.size() # 1 credit per modification
	
	return base_cost + hull_repair_cost + modification_maintenance

func _calculate_injury_costs(crew_members: Array[Resource]) -> int:
	"""Calculate costs for treating injured crew members"""
	var injury_cost = 0
	
	for crew_member in crew_members:
		var is_injured = crew_member.get_meta("injured") if crew_member.has_method("get_meta") else false
		if is_injured:
			injury_cost += INJURY_TREATMENT_COST
	
	return injury_cost

func handle_upkeep_failure(campaign_data: Resource) -> Dictionary:
	"""Handle what happens when upkeep cannot be paid"""
	var consequences = {
		"crew_morale_penalty": false,
		"ship_degradation": false,
		"crew_departure": false,
		"medical_complications": false
	}
	
	# Random consequences for failing upkeep (simplified Five Parsecs rules)
	var consequence_roll = randi_range(1, 6)
	
	match consequence_roll:
		1, 2: # Crew morale penalty
			consequences.crew_morale_penalty = true
			_apply_crew_morale_penalty(campaign_data)
		3, 4: # Ship degradation
			consequences.ship_degradation = true
			_apply_ship_degradation(campaign_data)
		5: # Crew member might leave
			consequences.crew_departure = true
			_check_crew_departure(campaign_data)
		6: # Medical complications for injured crew
			consequences.medical_complications = true
			_apply_medical_complications(campaign_data)
	
	return consequences

func calculate_optional_expenses(campaign_data: Resource) -> Dictionary:
	"""Calculate optional expenses crew can pay for benefits"""
	var options = {
		"luxury_living": {
			"cost": _get_crew_members(campaign_data).size() * 2,
			"benefit": "+1 to next campaign event roll"
		},
		"medical_care": {
			"cost": 4,
			"benefit": "Reduce injury recovery time by 1 turn"
		},
		"ship_upgrades": {
			"cost": 10,
			"benefit": "Minor ship modification or repair"
		},
		"training": {
			"cost": 8,
			"benefit": "Extra experience point for one crew member"
		}
	}
	
	return options

func _get_crew_members(campaign_data: Resource) -> Array[Resource]:
	"""Get crew members from campaign data"""
	if campaign_data and campaign_data.has_method("get_meta"):
		return campaign_data.get_meta("crew_members")
	return []

func _get_ship_data(campaign_data: Resource) -> Resource:
	"""Get ship data from campaign"""
	if campaign_data and campaign_data.has_method("get_meta"):
		return campaign_data.get_meta("ship_data")
	return null

func _get_living_standard(campaign_data: Resource) -> String:
	"""Get current living standard"""
	if campaign_data and campaign_data.has_method("get_meta"):
		return campaign_data.get_meta("living_standard")
	return "normal"

func _get_credits(campaign_data: Resource) -> int:
	"""Get current credits"""
	if campaign_data and campaign_data.has_method("get_meta"):
		return campaign_data.get_meta("credits")
	return 0

func _set_credits(campaign_data: Resource, credits: int) -> void:
	"""Set current credits"""
	if campaign_data and campaign_data.has_method("set_meta"):
		campaign_data.set_meta("credits", credits)

func _apply_upkeep_effects(campaign_data: Resource, upkeep_costs: Dictionary) -> void:
	"""Apply positive effects of paying upkeep"""
	# Remove injury recovery time if medical costs were paid
	if upkeep_costs.injury_treatment > 0:
		_reduce_injury_recovery_time(campaign_data)
	
	# Apply luxury living benefits
	if upkeep_costs.luxury_costs > 0:
		_apply_luxury_benefits(campaign_data)

func _apply_crew_morale_penalty(campaign_data: Resource) -> void:
	"""Apply morale penalty for poor upkeep"""
	var crew_members = _get_crew_members(campaign_data)
	for crew_member in crew_members:
		if crew_member.has_method("set_meta"):
			crew_member.set_meta("morale_penalty", true)

func _apply_ship_degradation(campaign_data: Resource) -> void:
	"""Apply ship degradation for poor maintenance"""
	var ship_data = _get_ship_data(campaign_data)
	if ship_data and ship_data.has_method("get_meta") and ship_data.has_method("set_meta"):
		var current_damage = ship_data.get_meta("hull_damage")
		ship_data.set_meta("hull_damage", current_damage + 1)

func _check_crew_departure(campaign_data: Resource) -> void:
	"""Check if crew member leaves due to poor treatment"""
	var crew_members = _get_crew_members(campaign_data)
	if crew_members.size() > 1: # Don't let the last crew member leave
		var departure_chance = randi_range(1, 6)
		if departure_chance <= 2: # 33% chance
			var leaving_member = crew_members.pick_random()
			crew_members.erase(leaving_member)
			campaign_data.set_meta("crew_members", crew_members)

func _apply_medical_complications(campaign_data: Resource) -> void:
	"""Apply medical complications to injured crew"""
	var crew_members = _get_crew_members(campaign_data)
	for crew_member in crew_members:
		var is_injured = crew_member.get_meta("injured") if crew_member.has_method("get_meta") else false
		if is_injured:
			var recovery_time = crew_member.get_meta("recovery_time") if crew_member.has_method("get_meta") else 1
			crew_member.set_meta("recovery_time", recovery_time + 1)

func _reduce_injury_recovery_time(campaign_data: Resource) -> void:
	"""Reduce injury recovery time with medical care"""
	var crew_members = _get_crew_members(campaign_data)
	for crew_member in crew_members:
		var recovery_time = crew_member.get_meta("recovery_time") if crew_member.has_method("get_meta") else 0
		if recovery_time > 0:
			crew_member.set_meta("recovery_time", max(0, recovery_time - 1))

func _apply_luxury_benefits(campaign_data: Resource) -> void:
	"""Apply benefits of luxury living"""
	if campaign_data.has_method("set_meta"):
		campaign_data.set_meta("luxury_bonus", true) # +1 to next event roll