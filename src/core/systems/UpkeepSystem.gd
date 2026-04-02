class_name UpkeepSystem
extends Resource

## Upkeep System for Five Parsecs Campaign Manager
## Handles crew maintenance, ship repairs, and campaign turn expenses

signal upkeep_calculated(cost: int, breakdown: Dictionary)
signal upkeep_paid(remaining_credits: int)
signal insufficient_funds(required: int, available: int)

# Economy system reference for credit management
var economy_system: Node = null

# Upkeep costs loaded from res://data/campaign_config.json "economy" section
# Canonical source: Five Parsecs Core Rules p.76
static var _economy_data: Dictionary = {}
static var _economy_loaded: bool = false

static func _ensure_economy_loaded() -> void:
	if _economy_loaded:
		return
	_economy_loaded = true
	var file := FileAccess.open("res://data/campaign_config.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_economy_data = json.data.get("economy", {})
	file.close()

static func _get_economy_val(key: String, default_val: int) -> int:
	_ensure_economy_loaded()
	return int(_economy_data.get(key, default_val))

# Backward-compatible accessors (loaded from economy section of campaign_config.json)
# Core Rules p.76: Upkeep = 1 credit for 4-6 crew, +1 per crew past 6
static var CREW_UPKEEP_THRESHOLD: int: # @no-lint:variable-name
	get: return _get_economy_val("upkeep_threshold", 4)
static var CREW_UPKEEP_CAP: int: # @no-lint:variable-name
	get: return _get_economy_val("upkeep_cap", 6)
static var SHIP_MAINTENANCE_BASE: int: # @no-lint:variable-name
	get: return _get_economy_val("ship_maintenance_base", 0)
# Core Rules p.76: "pay 4 credits to remove 1 campaign turn from recovery"
static var INJURY_TREATMENT_COST: int: # @no-lint:variable-name
	get: return _get_economy_val("injury_treatment_cost", 4)
# Core Rules p.76: "Every credit spent on repairs will fix 1 point of damage"
static var HULL_REPAIR_COST_PER_POINT: int: # @no-lint:variable-name
	get: return _get_economy_val("hull_repair_cost_per_point", 1)

func calculate_upkeep_costs(campaign_data: Resource) -> Dictionary:
	## Calculate total upkeep costs for the campaign turn
	var breakdown = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"injury_treatment": 0,
		"total": 0
	}

	# Get campaign _data
	var crew_members = _get_crew_members(campaign_data)
	var ship_data = _get_ship_data(campaign_data)

	# Calculate crew upkeep (rulebook p.76: 1 credit for 4-6 crew, +1 per crew past 6)
	var crew_size: int = crew_members.size()
	if crew_size >= CREW_UPKEEP_THRESHOLD:
		breakdown.crew_upkeep = 1 + max(0, crew_size - CREW_UPKEEP_CAP)
	else:
		breakdown.crew_upkeep = 0

	# Calculate ship maintenance
	if ship_data:
		breakdown.ship_maintenance = _calculate_ship_maintenance(ship_data)

	# Calculate injury treatment costs
	breakdown.injury_treatment = _calculate_injury_costs(crew_members)

	# Calculate total (Core Rules p.76: crew upkeep + ship maintenance + injury treatment)
	breakdown.total = breakdown.crew_upkeep + breakdown.ship_maintenance + breakdown.injury_treatment

	upkeep_calculated.emit(breakdown.total, breakdown) # warning: return value discarded (intentional)
	return breakdown

func pay_upkeep(campaign_data: Resource, upkeep_costs: Dictionary) -> bool:
	## Attempt to pay upkeep _costs
	var current_credits = _get_credits(campaign_data)
	var total_cost = upkeep_costs.get("total", 0)

	if current_credits >= total_cost:
		# Pay upkeep
		var remaining_credits = current_credits - total_cost
		_set_credits(campaign_data, remaining_credits)

		# Apply upkeep effects
		_apply_upkeep_effects(campaign_data, upkeep_costs)

		upkeep_paid.emit(remaining_credits) # warning: return value discarded (intentional)
		return true
	else:
		# Insufficient funds
		insufficient_funds.emit(total_cost, current_credits) # warning: return value discarded (intentional)
		return false

func _calculate_ship_maintenance(ship_data: Resource) -> int:
	## Calculate ship maintenance costs
	var base_cost = SHIP_MAINTENANCE_BASE

	# Add costs for ship hull damage
	var hull_damage = ship_data.get_meta("hull_damage") if ship_data and ship_data.has_method("get_meta") else 0
	var hull_repair_cost = hull_damage * HULL_REPAIR_COST_PER_POINT

	# Add costs for ship modifications
	var modifications = ship_data.get_meta("modifications") if ship_data and ship_data.has_method("get_meta") else []
	var modification_maintenance: int = modifications.size()  # 1 credit per modification

	return base_cost + hull_repair_cost + modification_maintenance

func _calculate_injury_costs(crew_members: Array) -> int:
	## Calculate costs for treating injured crew _members
	var injury_cost: int = 0

	for crew_member in crew_members:
		var typed_crew_member: Variant = crew_member
		var is_injured = crew_member.get_meta("injured") if crew_member and crew_member.has_method("get_meta") else false
		if is_injured:
			injury_cost += INJURY_TREATMENT_COST

	return injury_cost

func handle_upkeep_failure(campaign_data: Resource, credits_short: int = 1) -> Dictionary:
	## Handle what happens when upkeep cannot be paid
	## Rulebook p.76: Each credit short = 1 crew member refuses jobs this turn
	var consequences = {
		"crew_locked_out": 0,
		"locked_out_members": [] as Array[String]
	}

	var crew_members = _get_crew_members(campaign_data)
	var lockout_count: int = min(credits_short, crew_members.size())
	consequences.crew_locked_out = lockout_count

	# Lock out crew members (random selection per rulebook)
	var available_crew: Array = crew_members.duplicate()
	for i in range(lockout_count):
		if available_crew.is_empty():
			break
		var locked_member = available_crew.pick_random()
		available_crew.erase(locked_member)
		var member_name: String = ""
		if locked_member is Resource and locked_member.has_method("get"):
			member_name = locked_member.get("character_name") if locked_member.get("character_name") else "Unknown"
		elif locked_member is Dictionary:
			member_name = locked_member.get("character_name", locked_member.get("name", "Unknown"))
		consequences.locked_out_members.append(member_name)
		# Mark as locked out for this turn
		if locked_member is Resource and locked_member.has_method("set_meta"):
			locked_member.set_meta("locked_out_this_turn", true)

	return consequences

func calculate_optional_expenses(campaign_data: Resource) -> Dictionary:
	## Calculate optional expenses crew can pay for benefits
	var options = {
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

func _get_crew_members(campaign_data: Resource) -> Array:
	## Get crew members from campaign data
	if not campaign_data:
		return []
	
	# Try get_crew_members() method first (standard API)
	if campaign_data.has_method("get_crew_members"):
		var crew = campaign_data.get_crew_members()
		return crew if crew is Array else []
	
	# Try direct property access
	if "crew_members" in campaign_data:
		var crew = campaign_data.get("crew_members")
		return crew if crew is Array else []
	
	return []

func _get_ship_data(campaign_data: Resource) -> Resource:
	## Get ship _data from campaign
	if not campaign_data:
		return null

	# Try get_meta method first (standard Godot API)
	if campaign_data.has_method("has_meta") and campaign_data.has_meta("ship_data"):
		var value = campaign_data.get_meta("ship_data")
		if value != null and value is Resource:
			return value

	# Try direct property access
	if "ship_data" in campaign_data:
		var value = campaign_data.get("ship_data")
		if value is Resource:
			return value

	return null

func _get_credits(campaign_data: Resource) -> int:
	## Get current credits from EconomySystem or campaign data
	# PRIORITY 1: Use EconomySystem if available (proper integration)
	if economy_system and economy_system.has_method("get_resource"):
		if GlobalEnums and "ResourceType" in GlobalEnums:
			return economy_system.get_resource(GlobalEnums.ResourceType.CREDITS)

	# FALLBACK: Try campaign_data for backwards compatibility
	if not campaign_data:
		return 0

	# Try get_meta method first (standard Godot API)
	if campaign_data.has_method("has_meta") and campaign_data.has_meta("credits"):
		var value = campaign_data.get_meta("credits")
		if value != null and value is int:
			return value

	# Try direct property access
	if "credits" in campaign_data:
		var value = campaign_data.get("credits")
		if value is int:
			return value

	return 0

func _set_credits(campaign_data: Resource, credits: int) -> void:
	## Set current credits via EconomySystem or campaign data
	# PRIORITY 1: Use EconomySystem if available (proper integration)
	if economy_system and economy_system.has_method("set_resource"):
		if GlobalEnums and "ResourceType" in GlobalEnums:
			economy_system.set_resource(GlobalEnums.ResourceType.CREDITS, credits, "upkeep_payment")
			return

	# FALLBACK: Update campaign_data directly for backwards compatibility
	# Try direct property access first (works with MockCampaignData and similar)
	if campaign_data and "credits" in campaign_data:
		campaign_data.set("credits", credits)
		return

	# Then try set_meta as last resort
	if campaign_data and campaign_data.has_method("set_meta"):
		campaign_data.set_meta("credits", credits)

func _apply_upkeep_effects(campaign_data: Resource, upkeep_costs: Dictionary) -> void:
	## Apply positive effects of paying upkeep
	# Remove injury recovery time if medical _costs were paid
	if upkeep_costs.injury_treatment > 0:
		_reduce_injury_recovery_time(campaign_data)


func _apply_crew_morale_penalty(campaign_data: Resource) -> void:
	## Apply morale penalty for poor upkeep
	var crew_members = _get_crew_members(campaign_data)
	for crew_member in crew_members:
		var typed_crew_member: Variant = crew_member
		if crew_member and crew_member.has_method("set_meta"):
			crew_member.set_meta("morale_penalty", true)

func _apply_ship_degradation(campaign_data: Resource) -> void:
	## Apply ship degradation for poor maintenance
	var ship_data = _get_ship_data(campaign_data)
	if ship_data and ship_data.has_method("get_meta") and ship_data and ship_data.has_method("set_meta"):
		var current_damage = ship_data.get_meta("hull_damage")
		ship_data.set_meta("hull_damage", current_damage + 1)

func _check_crew_departure(campaign_data: Resource) -> void:
	## Check if crew member leaves due to poor treatment
	var crew_members = _get_crew_members(campaign_data)
	if crew_members.size() > 1: # Don't let the last crew member leave
		var departure_chance = randi_range(1, 6)
		if departure_chance <= 2: # 33% chance
			var leaving_member = crew_members.pick_random()
			if leaving_member != null:
				crew_members.erase(leaving_member)
				campaign_data.set_meta("crew_members", crew_members)

func _apply_medical_complications(campaign_data: Resource) -> void:
	## Apply medical complications to injured crew
	var crew_members = _get_crew_members(campaign_data)
	for crew_member in crew_members:
		var typed_crew_member: Variant = crew_member
		var is_injured = crew_member.get_meta("injured") if crew_member and crew_member.has_method("get_meta") else false
		if is_injured:
			var recovery_time = crew_member.get_meta("recovery_time") if crew_member and crew_member.has_method("get_meta") else 1
			crew_member.set_meta("recovery_time", recovery_time + 1)

func _reduce_injury_recovery_time(campaign_data: Resource) -> void:
	## Reduce injury recovery time with medical care
	var crew_members = _get_crew_members(campaign_data)
	for crew_member in crew_members:
		var typed_crew_member: Variant = crew_member
		var recovery_time = crew_member.get_meta("recovery_time") if crew_member and crew_member.has_method("get_meta") else 0
		if recovery_time > 0:
			crew_member.set_meta("recovery_time", max(0, recovery_time - 1))

