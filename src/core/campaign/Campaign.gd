extends Resource
class_name Campaign

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

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

# Campaign resources
var resources: Dictionary = {
	GlobalEnums.ResourceType.CREDITS: 0,
	GlobalEnums.ResourceType.SUPPLIES: 0,
	GlobalEnums.ResourceType.STORY_POINT: 0,
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

# Campaign history
var event_history: Array[Dictionary] = []
var location_history: Array[String] = []
var battle_history: Array[Dictionary] = []

# Campaign relationships
var allies: Array[Dictionary] = []
var rivals: Array[Dictionary] = []
var enemies: Array[Dictionary] = []

# Campaign crew and jobs
@export var active_patrons: Array[Dictionary] = []
@export var crew_tasks: Dictionary = {}  # Maps crew member ID to assigned task
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

func start_new_campaign(name: String, starting_credits: int = 1000) -> void:
	campaign_name = name
	resources[GlobalEnums.ResourceType.CREDITS] = starting_credits
	resources[GlobalEnums.ResourceType.STORY_POINT] = 3
	resources[GlobalEnums.ResourceType.SUPPLIES] = 10
	current_phase = GlobalEnums.CampaignPhase.SETUP
	current_turn = 1
	is_active = true
	
	campaign_started.emit({
		"name": name,
		"credits": starting_credits,
		"phase": current_phase,
		"turn": current_turn
	})

func add_relationship(faction_name: String, relation_type: GlobalEnums.FactionType, influence: int = 0) -> void:
	var relation_data = {
		"name": faction_name,
		"influence": influence,
		"turn_added": current_turn
	}
	
	match relation_type:
		GlobalEnums.FactionType.ALLIED:
			allies.append(relation_data)
		GlobalEnums.FactionType.HOSTILE:
			rivals.append(relation_data)
		GlobalEnums.FactionType.ENEMY:
			enemies.append(relation_data)

func get_relationship_status(faction_name: String) -> GlobalEnums.FactionType:
	for ally in allies:
		if ally["name"] == faction_name:
			return GlobalEnums.FactionType.ALLIED
	
	for rival in rivals:
		if rival["name"] == faction_name:
			return GlobalEnums.FactionType.HOSTILE
	
	for enemy in enemies:
		if enemy["name"] == faction_name:
			return GlobalEnums.FactionType.ENEMY
	
	return GlobalEnums.FactionType.NEUTRAL

func start_campaign(campaign_data: Dictionary) -> void:
	current_phase = GlobalEnums.CampaignPhase.SETUP
	_initialize_campaign(campaign_data)
	campaign_started.emit(campaign_data)

func end_campaign(result: Dictionary) -> void:
	campaign_ended.emit(result)
	_cleanup_campaign()

func advance_phase() -> void:
	var next_phase := _get_next_phase()
	current_phase = next_phase
	phase_changed.emit(next_phase)
	_handle_phase_transition(next_phase)

func modify_resource(resource_type: GlobalEnums.ResourceType, amount: int) -> void:
	if resource_type in resources:
		resources[resource_type] += amount
		resource_changed.emit(resource_type, amount)

func trigger_world_event(event_type: GlobalEnums.GlobalEvent) -> void:
	_handle_world_event(event_type)
	world_event_triggered.emit(event_type)

func _initialize_campaign(campaign_data: Dictionary) -> void:
	# Implementation of campaign initialization
	pass

func _cleanup_campaign() -> void:
	# Implementation of campaign cleanup
	pass

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

func _handle_phase_transition(new_phase: GlobalEnums.CampaignPhase) -> void:
	match new_phase:
		GlobalEnums.CampaignPhase.SETUP:
			_handle_setup_phase()
		GlobalEnums.CampaignPhase.UPKEEP:
			_handle_upkeep_phase()
		GlobalEnums.CampaignPhase.WORLD_STEP:
			_handle_world_step_phase()
		GlobalEnums.CampaignPhase.TRAVEL:
			_handle_travel_phase()
		GlobalEnums.CampaignPhase.PATRONS:
			_handle_patrons_phase()
		GlobalEnums.CampaignPhase.BATTLE:
			_handle_battle_phase()
		GlobalEnums.CampaignPhase.POST_BATTLE:
			_handle_post_battle_phase()
		GlobalEnums.CampaignPhase.MANAGEMENT:
			_handle_management_phase()

func _handle_world_event(event_type: GlobalEnums.GlobalEvent) -> void:
	match event_type:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			world_state.market_state = GlobalEnums.MarketState.CRISIS
		GlobalEnums.GlobalEvent.ALIEN_INVASION:
			world_state.strife_level = GlobalEnums.StrifeType.CRITICAL
		GlobalEnums.GlobalEvent.TECH_BREAKTHROUGH:
			modify_resource(GlobalEnums.ResourceType.TECHNOLOGY, 2)
		GlobalEnums.GlobalEvent.CIVIL_UNREST:
			world_state.instability = GlobalEnums.FringeWorldInstability.UNSTABLE
		GlobalEnums.GlobalEvent.RESOURCE_BOOM:
			modify_resource(GlobalEnums.ResourceType.MINERALS, 3)
		GlobalEnums.GlobalEvent.PIRATE_RAID:
			modify_resource(GlobalEnums.ResourceType.SUPPLIES, -2)
		_:
			pass

# Phase handling implementations
func _handle_setup_phase() -> void:
	pass

func _handle_upkeep_phase() -> void:
	# Calculate upkeep costs
	var upkeep_cost = _calculate_upkeep_cost()
	
	# Check if we can afford upkeep
	if resources[GlobalEnums.ResourceType.CREDITS] >= upkeep_cost:
		# Deduct upkeep costs
		modify_resource(GlobalEnums.ResourceType.CREDITS, -upkeep_cost)
		
		# Consume supplies
		var supply_consumption = _calculate_supply_consumption()
		modify_resource(GlobalEnums.ResourceType.SUPPLIES, -supply_consumption)
		
		# Update market prices
		_update_market_prices()
		
		# Add event to history
		add_event(GlobalEnums.GlobalEvent.UPKEEP_PAID, 
			"Paid %d credits in upkeep" % upkeep_cost,
			"Consumed %d supplies" % supply_consumption)
	else:
		# Handle insufficient funds
		_handle_insufficient_upkeep(upkeep_cost)

func _calculate_upkeep_cost() -> int:
	# Base cost per crew member
	var crew_cost = crew_members.size() * 2
	
	# Additional costs from ship maintenance
	var ship_cost = ship_hull_points / 10
	
	# Penalty costs from damage
	var damage_cost = (ship_max_hull_points - ship_hull_points) / 5
	
	return crew_cost + ship_cost + damage_cost

func _calculate_supply_consumption() -> int:
	# Base consumption per crew member
	return crew_members.size()

func _update_market_prices() -> void:
	# 30% chance for market fluctuation
	if randf() < 0.3:
		var market_event = randi() % 3
		match market_event:
			0: # Price increase
				world_state.market_modifier += 0.1
			1: # Price decrease
				world_state.market_modifier -= 0.1
			2: # Major market event
				_trigger_major_market_event()

func _handle_insufficient_upkeep(cost: int) -> void:
	# Lose reputation
	modify_resource(GlobalEnums.ResourceType.PATRON, -1)
	
	# Add debt
	ship_debt += cost
	
	# Risk losing crew members
	for crew_member in crew_members:
		if randf() < 0.2: # 20% chance per crew member
			_handle_crew_desertion(crew_member)
	
	# Add event to history
	add_event(GlobalEnums.GlobalEvent.UPKEEP_FAILED,
		"Failed to pay %d credits in upkeep" % cost,
		"Lost reputation and increased debt")

func _trigger_major_market_event() -> void:
	var event = randi() % 4
	match event:
		0: # Market crash
			world_state.market_modifier *= 0.5
			add_event(GlobalEnums.GlobalEvent.MARKET_CRASH,
				"Local market crashed",
				"Prices dropped significantly")
		1: # Resource shortage
			world_state.market_modifier *= 2.0
			add_event(GlobalEnums.GlobalEvent.RESOURCE_SHORTAGE,
				"Critical resource shortage",
				"Prices increased significantly")
		2: # Trade boom
			modify_resource(GlobalEnums.ResourceType.CREDITS, 10)
			add_event(GlobalEnums.GlobalEvent.TRADE_BOOM,
				"Trade boom occurred",
				"Gained bonus credits from market activity")
		3: # Black market activity
			world_state.black_market_active = true
			add_event(GlobalEnums.GlobalEvent.BLACK_MARKET,
				"Black market activity detected",
				"Special trades may be available")

func _handle_crew_desertion(crew_member: Dictionary) -> void:
	crew_members.erase(crew_member)
	add_event(GlobalEnums.GlobalEvent.CREW_DESERTED,
		"Crew member deserted due to missing pay",
		"Lost " + crew_member.name)

func _handle_world_step_phase() -> void:
	# Update turn counter
	current_turn += 1
	
	# Check for random events
	_check_random_events()
	
	# Update patron relationships
	_update_patron_relationships()
	
	# Generate new missions
	_generate_new_missions()
	
	# Update world state
	_update_world_state()

func _check_random_events() -> void:
	# 40% chance for a random event
	if randf() < 0.4:
		var event_type = randi() % 5
		match event_type:
			0: # Pirates
				_handle_pirate_activity()
			1: # Trade opportunity
				_handle_trade_opportunity()
			2: # Technology discovery
				_handle_technology_discovery()
			3: # Political event
				_handle_political_event()
			4: # Natural phenomenon
				_handle_natural_phenomenon()

func _handle_pirate_activity() -> void:
	world_state.pirate_activity += 0.2
	if world_state.pirate_activity > 1.0:
		# Trigger pirate raid
		var loss = randi() % 10 + 5
		modify_resource(GlobalEnums.ResourceType.CREDITS, -loss)
		add_event(GlobalEnums.GlobalEvent.PIRATE_RAID,
			"Pirates raided local trade routes",
			"Lost %d credits to increased security" % loss)
	else:
		add_event(GlobalEnums.GlobalEvent.PIRATE_ACTIVITY,
			"Increased pirate activity reported",
			"Security costs may rise")

func _handle_trade_opportunity() -> void:
	var gain = randi() % 15 + 10
	modify_resource(GlobalEnums.ResourceType.CREDITS, gain)
	add_event(GlobalEnums.GlobalEvent.TRADE_OPPORTUNITY,
		"Profitable trade opportunity",
		"Gained %d credits from market speculation" % gain)

func _handle_technology_discovery() -> void:
	# 50% chance for beneficial tech
	if randf() < 0.5:
		world_state.tech_level += 0.1
		add_event(GlobalEnums.GlobalEvent.TECH_ADVANCE,
			"New technology discovered",
			"Advanced equipment may become available")
	else:
		world_state.tech_level -= 0.1
		add_event(GlobalEnums.GlobalEvent.TECH_SETBACK,
			"Technology setback occurred",
			"Some equipment may become scarce")

func _handle_political_event() -> void:
	var event = randi() % 3
	match event:
		0: # Faction conflict
			world_state.faction_tension += 0.2
			add_event(GlobalEnums.GlobalEvent.FACTION_CONFLICT,
				"Faction tensions increased",
				"New mission opportunities may arise")
		1: # Peace treaty
			world_state.faction_tension -= 0.3
			add_event(GlobalEnums.GlobalEvent.PEACE_TREATY,
				"Peace treaty signed",
				"Some conflict missions may be cancelled")
		2: # Political upheaval
			_shuffle_patron_influence()
			add_event(GlobalEnums.GlobalEvent.POLITICAL_CHANGE,
				"Political landscape shifted",
				"Patron influences have changed")

func _handle_natural_phenomenon() -> void:
	var phenomenon = randi() % 3
	match phenomenon:
		0: # Solar storm
			world_state.travel_hazard = true
			add_event(GlobalEnums.GlobalEvent.SOLAR_STORM,
				"Solar storm detected",
				"Travel may be more dangerous")
		1: # Resource discovery
			world_state.resource_abundance += 0.2
			add_event(GlobalEnums.GlobalEvent.RESOURCE_DISCOVERY,
				"New resource deposits found",
				"Resource-based missions may pay more")
		2: # Cosmic anomaly
			world_state.mystery_level += 0.1
			add_event(GlobalEnums.GlobalEvent.COSMIC_ANOMALY,
				"Strange cosmic phenomenon observed",
				"Special missions may become available")

func _update_patron_relationships() -> void:
	for patron in patrons:
		# Natural decay of relationship
		if patron.relationship > 0:
			patron.relationship -= 0.1
		
		# Check for random patron events
		if randf() < 0.2:  # 20% chance per patron
			var event = randi() % 3
			match event:
				0:  # Patron request
					_generate_patron_mission(patron)
				1:  # Relationship test
					_trigger_patron_test(patron)
				2:  # Patron conflict
					_handle_patron_conflict(patron)

func _generate_new_missions() -> void:
	var base_missions = 3 + floor(world_state.faction_tension * 2)
	for i in range(base_missions):
		var mission = _create_random_mission()
		available_missions.append(mission)
		
	# Add patron-specific missions
	for patron in patrons:
		if patron.relationship >= 3:  # Good relationship
			var special_mission = _create_patron_mission(patron)
			available_missions.append(special_mission)

func _update_world_state() -> void:
	# Natural decay of world state values
	world_state.pirate_activity = max(0, world_state.pirate_activity - 0.1)
	world_state.faction_tension = max(0, world_state.faction_tension - 0.05)
	world_state.tech_level = clamp(world_state.tech_level, 0.5, 2.0)
	world_state.resource_abundance = max(0, world_state.resource_abundance - 0.1)
	
	# Clear temporary flags
	world_state.travel_hazard = false
	world_state.black_market_active = false
	
	# Update global mission difficulty
	world_state.mission_difficulty = 1.0 + (world_state.faction_tension * 0.5)

func _handle_travel_phase() -> void:
	# Check if travel is requested
	if not current_travel_destination:
		return
		
	# Calculate travel cost and risks
	var travel_data = _calculate_travel_details(current_location, current_travel_destination)
	
	# Check if we can afford travel
	if resources[GlobalEnums.ResourceType.CREDITS] >= travel_data.cost:
		# Deduct travel costs
		modify_resource(GlobalEnums.ResourceType.CREDITS, -travel_data.cost)
		
		# Handle travel events
		_handle_travel_events(travel_data)
		
		# Update location
		current_location = current_travel_destination
		current_travel_destination = null
		
		# Add travel completion event
		add_event(GlobalEnums.GlobalEvent.TRAVEL_COMPLETE,
			"Arrived at %s" % current_location,
			"Spent %d credits on travel" % travel_data.cost)
	else:
		# Failed to travel due to insufficient funds
		add_event(GlobalEnums.GlobalEvent.TRAVEL_FAILED,
			"Insufficient funds for travel",
			"Need %d credits for travel" % travel_data.cost)
		current_travel_destination = null

func _calculate_travel_details(from: String, to: String) -> Dictionary:
	var distance = _calculate_distance(from, to)
	var base_cost = distance * 2
	
	# Apply modifiers
	var final_cost = base_cost
	if world_state.travel_hazard:
		final_cost *= 1.5
	if world_state.pirate_activity > 0.5:
		final_cost *= 1.2
		
	# Calculate risk factors
	var risk_factors = {
		"pirate": world_state.pirate_activity * 0.4,
		"hazard": 0.2 if world_state.travel_hazard else 0.0,
		"distance": distance * 0.05,
		"total": 0.0
	}
	risk_factors.total = min(0.8, risk_factors.pirate + risk_factors.hazard + risk_factors.distance)
	
	return {
		"cost": ceil(final_cost),
		"distance": distance,
		"risks": risk_factors
	}

func _handle_travel_events(travel_data: Dictionary) -> void:
	# Check for random events during travel
	if randf() < travel_data.risks.total:
		var event_type = randi() % 3
		match event_type:
			0: # Combat encounter
				_handle_travel_combat()
			1: # Resource discovery
				_handle_travel_discovery()
			2: # Ship damage
				_handle_travel_damage()

func _handle_travel_combat() -> void:
	# Determine combat difficulty based on world state
	var difficulty = 1.0
	difficulty += world_state.pirate_activity * 0.5
	if world_state.travel_hazard:
		difficulty += 0.3
		
	# Calculate potential losses
	var damage = randi() % 3 + 1
	var credit_loss = randi() % 10 + 5
	
	# Apply combat results
	ship_hull_points = max(0, ship_hull_points - damage)
	modify_resource(GlobalEnums.ResourceType.CREDITS, -credit_loss)
	
	add_event(GlobalEnums.GlobalEvent.TRAVEL_COMBAT,
		"Encountered hostiles during travel",
		"Lost %d hull points and %d credits" % [damage, credit_loss])

func _handle_travel_discovery() -> void:
	# 70% chance for beneficial discovery
	if randf() < 0.7:
		var credits = randi() % 20 + 10
		modify_resource(GlobalEnums.ResourceType.CREDITS, credits)
		add_event(GlobalEnums.GlobalEvent.TRAVEL_DISCOVERY,
			"Made valuable discovery during travel",
			"Gained %d credits from salvage" % credits)
	else:
		# Handle dangerous discovery
		var damage = randi() % 2 + 1
		ship_hull_points = max(0, ship_hull_points - damage)
		add_event(GlobalEnums.GlobalEvent.TRAVEL_HAZARD,
			"Encountered dangerous phenomenon",
			"Lost %d hull points from damage" % damage)

func _handle_travel_damage() -> void:
	var damage = randi() % 2 + 1
	ship_hull_points = max(0, ship_hull_points - damage)
	
	# Calculate repair cost
	var repair_cost = damage * 5
	modify_resource(GlobalEnums.ResourceType.CREDITS, -repair_cost)
	
	add_event(GlobalEnums.GlobalEvent.TRAVEL_DAMAGE,
		"Ship sustained damage during travel",
		"Lost %d hull points and spent %d credits on repairs" % [damage, repair_cost])

func _calculate_distance(from: String, to: String) -> int:
	# TODO: Implement actual distance calculation based on star map
	# For now, return a random distance between 1 and 5
	return randi() % 5 + 1

func _handle_patrons_phase() -> void:
	# Update patron satisfaction
	for patron in patrons:
		_update_patron_satisfaction(patron)
	
	# Handle patron requests
	_handle_patron_requests()
	
	# Check for new patron opportunities
	_check_new_patron_opportunities()
	
	# Update patron missions
	_update_patron_missions()

func _update_patron_satisfaction(patron: Dictionary) -> void:
	# Check completed missions
	var completed_patron_missions = 0
	var failed_patron_missions = 0
	
	for mission in completed_missions:
		if mission.patron_id == patron.id:
			completed_patron_missions += 1
	
	for mission in failed_missions:
		if mission.patron_id == patron.id:
			failed_patron_missions += 1
	
	# Update relationship based on mission performance
	var relationship_change = completed_patron_missions * 0.5 - failed_patron_missions * 1.0
	patron.relationship = clamp(patron.relationship + relationship_change, -5.0, 5.0)
	
	# Add reputation events if significant changes occurred
	if relationship_change > 0:
		add_event(GlobalEnums.GlobalEvent.PATRON_PLEASED,
			"Patron %s is pleased with your work" % patron.name,
			"Relationship improved by %.1f" % relationship_change)
	elif relationship_change < 0:
		add_event(GlobalEnums.GlobalEvent.PATRON_DISPLEASED,
			"Patron %s is displeased with your performance" % patron.name,
			"Relationship decreased by %.1f" % abs(relationship_change))

func _handle_patron_requests() -> void:
	for patron in patrons:
		# Only patrons with positive relationships make requests
		if patron.relationship > 0 and randf() < 0.3:  # 30% chance
			var request_type = randi() % 3
			match request_type:
				0:  # Resource request
					_handle_resource_request(patron)
				1:  # Special mission
					_handle_special_mission_request(patron)
				2:  # Alliance proposal
					_handle_alliance_proposal(patron)

func _handle_resource_request(patron: Dictionary) -> void:
	var resource_type = randi() % 2
	var amount = randi() % 10 + 5
	var reward = amount * 3
	
	match resource_type:
		0:  # Credits
			if resources[GlobalEnums.ResourceType.CREDITS] >= amount:
				modify_resource(GlobalEnums.ResourceType.CREDITS, -amount)
				patron.relationship += 0.3
				add_event(GlobalEnums.GlobalEvent.PATRON_REQUEST_COMPLETE,
					"Fulfilled credit request from %s" % patron.name,
					"Relationship improved")
			else:
				patron.relationship -= 0.2
				add_event(GlobalEnums.GlobalEvent.PATRON_REQUEST_FAILED,
					"Failed to fulfill credit request from %s" % patron.name,
					"Relationship suffered")
		1:  # Supplies
			if resources[GlobalEnums.ResourceType.SUPPLIES] >= amount:
				modify_resource(GlobalEnums.ResourceType.SUPPLIES, -amount)
				modify_resource(GlobalEnums.ResourceType.CREDITS, reward)
				patron.relationship += 0.3
				add_event(GlobalEnums.GlobalEvent.PATRON_REQUEST_COMPLETE,
					"Fulfilled supply request from %s" % patron.name,
					"Received %d credits as reward" % reward)
			else:
				patron.relationship -= 0.2
				add_event(GlobalEnums.GlobalEvent.PATRON_REQUEST_FAILED,
					"Failed to fulfill supply request from %s" % patron.name,
					"Relationship suffered")

func _handle_special_mission_request(patron: Dictionary) -> void:
	var mission = _create_patron_mission(patron)
	mission.reward *= 1.5  # Special missions have better rewards
	mission.is_special = true
	available_missions.append(mission)
	
	add_event(GlobalEnums.GlobalEvent.SPECIAL_MISSION_AVAILABLE,
		"Special mission available from %s" % patron.name,
		"High reward mission opportunity")

func _handle_alliance_proposal(patron: Dictionary) -> void:
	# Only high-relationship patrons propose alliances
	if patron.relationship >= 4.0:
		patron.is_allied = true
		patron.relationship += 0.5
		
		# Alliance benefits
		modify_resource(GlobalEnums.ResourceType.CREDITS, 50)
		world_state.faction_tension -= 0.2
		
		add_event(GlobalEnums.GlobalEvent.PATRON_ALLIANCE,
			"Formed alliance with %s" % patron.name,
			"Received alliance benefits and improved relationship")

func _check_new_patron_opportunities() -> void:
	# Chance for new patron based on reputation and current number of patrons
	var base_chance = 0.2 - (patrons.size() * 0.05)
	if randf() < base_chance:
		var new_patron = _generate_new_patron()
		patrons.append(new_patron)
		
		add_event(GlobalEnums.GlobalEvent.NEW_PATRON,
			"New patron %s has taken interest in your operations" % new_patron.name,
			"New mission opportunities available")

func _update_patron_missions() -> void:
	# Remove expired missions
	var expired_missions = []
	for mission in available_missions:
		if mission.has("patron_id"):
			var patron = _get_patron_by_id(mission.patron_id)
			if not patron or patron.relationship < 0:
				expired_missions.append(mission)
	
	for mission in expired_missions:
		available_missions.erase(mission)
		add_event(GlobalEnums.GlobalEvent.MISSION_EXPIRED,
			"Mission from %s has expired" % _get_patron_by_id(mission.patron_id).name,
			"Mission is no longer available")

func _generate_new_patron() -> Dictionary:
	return {
		"id": randi(),
		"name": _generate_patron_name(),
		"relationship": 1.0,
		"is_allied": false,
		"faction": _generate_patron_faction(),
		"specialization": _generate_patron_specialization()
	}

func _get_patron_by_id(patron_id: int) -> Dictionary:
	for patron in patrons:
		if patron.id == patron_id:
			return patron
	return {}

func set_location(location_name: String) -> void:
	if location_name != current_location:
		location_history.append(current_location)
		current_location = location_name
		location_changed.emit(current_location)

func add_event(event_type: GlobalEnums.GlobalEvent, event_description: String, event_outcome: String) -> void:
	var event_data = {
		"type": event_type,
		"description": event_description,
		"outcome": event_outcome,
		"turn": current_turn,
		"phase": current_phase,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	event_history.append(event_data)
	event_occurred.emit(event_data)

func add_battle_result(battle_data: Dictionary) -> void:
	battle_data["turn"] = current_turn
	battle_data["timestamp"] = Time.get_unix_time_from_system()
	battle_history.append(battle_data)

func get_resources() -> Dictionary:
	return {
		"credits": resources[GlobalEnums.ResourceType.CREDITS],
		"story_points": resources[GlobalEnums.ResourceType.STORY_POINT],
		"reputation": resources[GlobalEnums.ResourceType.PATRON],
		"supplies": resources[GlobalEnums.ResourceType.SUPPLIES],
		"intel": resources[GlobalEnums.ResourceType.XP],
		"salvage": resources[GlobalEnums.ResourceType.RIVAL]
	}

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
		"credits": resources[GlobalEnums.ResourceType.CREDITS],
		"story_points": resources[GlobalEnums.ResourceType.STORY_POINT],
		"reputation": resources[GlobalEnums.ResourceType.PATRON],
		"supplies": resources[GlobalEnums.ResourceType.SUPPLIES],
		"intel": resources[GlobalEnums.ResourceType.XP],
		"salvage": resources[GlobalEnums.ResourceType.RIVAL],
		"event_history": event_history,
		"location_history": location_history,
		"battle_history": battle_history,
		"allies": allies,
		"rivals": rivals,
		"enemies": enemies,
		"active_patrons": active_patrons,
		"crew_tasks": crew_tasks,
		"current_job_offers": current_job_offers
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
	
	# Load resources
	for resource_type in campaign.resources.keys():
		var resource_name = GlobalEnums.ResourceType.keys()[resource_type].to_lower()
		campaign.resources[resource_type] = data.get(resource_name, 0)
	
	campaign.event_history = data.get("event_history", [])
	campaign.location_history = data.get("location_history", [])
	campaign.battle_history = data.get("battle_history", [])
	campaign.allies = data.get("allies", [])
	campaign.rivals = data.get("rivals", [])
	campaign.enemies = data.get("enemies", [])
	campaign.active_patrons = data.get("active_patrons", [])
	campaign.crew_tasks = data.get("crew_tasks", {})
	campaign.current_job_offers = data.get("current_job_offers", [])
	
	return campaign 

func get_patron_count() -> int:
	return active_patrons.size()

func get_active_crew_count() -> int:
	var count := 0
	for crew_member in crew_members:
		if crew_member.status == GlobalEnums.CharacterStatus.HEALTHY:
			count += 1
	return count

func get_crew_on_task(task_type: GlobalEnums.ResourceType) -> int:
	var count := 0
	for crew_id in crew_tasks:
		if crew_tasks[crew_id] == task_type:
			count += 1
	return count

func assign_crew_task(crew_member: Character, task: GlobalEnums.ResourceType) -> bool:
	if not crew_member or crew_member.status != GlobalEnums.CharacterStatus.HEALTHY:
		return false
		
	crew_tasks[crew_member.get_instance_id()] = task
	return true

func clear_crew_tasks() -> void:
	crew_tasks.clear()

func add_patron(patron_data: Dictionary) -> void:
	active_patrons.append(patron_data)
	modify_resource(GlobalEnums.ResourceType.PATRON, 1)

func remove_patron(patron_name: String) -> void:
	for i in range(active_patrons.size() - 1, -1, -1):
		if active_patrons[i].name == patron_name:
			active_patrons.remove_at(i)
			modify_resource(GlobalEnums.ResourceType.PATRON, -1)
			break

func add_job_offer(offer: Dictionary) -> void:
	current_job_offers.append(offer)

func clear_job_offers() -> void:
	current_job_offers.clear()

func _handle_battle_phase() -> void:
	# Check if there's an active battle
	if not current_battle:
		return
	
	# Initialize battle state
	var battle_state = _initialize_battle_state()
	
	# Process battle rounds until completion
	while not battle_state.is_complete:
		_process_battle_round(battle_state)
	
	# Store battle results for post-battle processing
	current_battle_results = battle_state.results
	current_battle = null
	
	# Emit battle completion signal
	emit_signal("battle_completed", current_battle_results)

func _initialize_battle_state() -> Dictionary:
	return {
		"is_complete": false,
		"current_round": 0,
		"max_rounds": 5,
		"player_forces": _prepare_player_forces(),
		"enemy_forces": _prepare_enemy_forces(),
		"battlefield": _generate_battlefield(),
		"results": {
			"victory": false,
			"rounds_fought": 0,
			"casualties": {
				"player": [],
				"enemy": []
			},
			"loot": [],
			"experience_gained": 0
		}
	}

func _prepare_player_forces() -> Array:
	var forces = []
	for crew_member in crew_members:
		if crew_member.is_active and crew_member.health > 0:
			forces.append({
				"unit": crew_member,
				"position": Vector2.ZERO,
				"action_points": crew_member.speed,
				"status_effects": []
			})
	return forces

func _prepare_enemy_forces() -> Array:
	var forces = []
	for enemy in current_battle.enemies:
		forces.append({
			"unit": enemy,
			"position": Vector2.ZERO,
			"action_points": enemy.speed,
			"status_effects": []
		})
	return forces

func _process_battle_round(battle_state: Dictionary) -> void:
	battle_state.current_round += 1
	
	# Reset action points
	for unit in battle_state.player_forces + battle_state.enemy_forces:
		unit.action_points = unit.unit.speed
	
	# Process player turns
	for unit in battle_state.player_forces:
		_process_unit_turn(unit, battle_state, true)
	
	# Process enemy turns
	for unit in battle_state.enemy_forces:
		_process_unit_turn(unit, battle_state, false)
	
	# Check battle completion conditions
	_check_battle_completion(battle_state)
	
	# Update status effects
	_update_status_effects(battle_state)

func _process_unit_turn(unit: Dictionary, battle_state: Dictionary, is_player: bool) -> void:
	# Skip if unit is incapacitated
	if unit.unit.health <= 0:
		return
	
	# Process status effects
	_process_unit_status_effects(unit)
	
	# Get available actions
	var actions = _get_available_actions(unit, battle_state, is_player)
	
	# Execute best action
	var chosen_action = _choose_best_action(actions, unit, battle_state, is_player)
	_execute_action(chosen_action, unit, battle_state)

func _check_battle_completion(battle_state: Dictionary) -> void:
	# Check if all player units are down
	var player_active = false
	for unit in battle_state.player_forces:
		if unit.unit.health > 0:
			player_active = true
			break
	
	# Check if all enemy units are down
	var enemy_active = false
	for unit in battle_state.enemy_forces:
		if unit.unit.health > 0:
			enemy_active = true
			break
	
	# Check round limit
	if battle_state.current_round >= battle_state.max_rounds:
		battle_state.is_complete = true
		battle_state.results.victory = player_active
	else:
		battle_state.is_complete = not player_active or not enemy_active
		battle_state.results.victory = not enemy_active

func _handle_post_battle_phase() -> void:
	if not current_battle_results:
		return
	
	# Process battle aftermath
	if current_battle_results.victory:
		_handle_victory_aftermath()
	else:
		_handle_defeat_aftermath()
	
	# Update crew status
	_update_crew_post_battle()
	
	# Process loot and rewards
	_process_battle_rewards()
	
	# Clear battle results
	current_battle_results = null

func _handle_victory_aftermath() -> void:
	# Award experience
	var base_xp = 100
	var difficulty_bonus = current_battle.difficulty * 20
	var total_xp = base_xp + difficulty_bonus
	
	for crew_member in crew_members:
		if crew_member.is_active:
			crew_member.experience += total_xp
	
	# Add victory event
	add_event(GlobalEnums.GlobalEvent.BATTLE_VICTORY,
		"Victory in battle!",
		"Gained %d experience" % total_xp)
	
	# Update reputation
	modify_resource(GlobalEnums.ResourceType.REPUTATION, 1)

func _handle_defeat_aftermath() -> void:
	# Lose resources
	var credit_loss = randi() % 20 + 10
	modify_resource(GlobalEnums.ResourceType.CREDITS, -credit_loss)
	
	# Lose reputation
	modify_resource(GlobalEnums.ResourceType.REPUTATION, -1)
	
	# Add defeat event
	add_event(GlobalEnums.GlobalEvent.BATTLE_DEFEAT,
		"Defeated in battle",
		"Lost %d credits and reputation" % credit_loss)

func _update_crew_post_battle() -> void:
	for casualty in current_battle_results.casualties.player:
		var crew_member = casualty.unit
		
		if crew_member.health <= 0:
			# Handle death
			crew_member.is_active = false
			add_event(GlobalEnums.GlobalEvent.CREW_DEATH,
				"Lost crew member %s in battle" % crew_member.name,
				"Crew member died from their wounds")
		else:
			# Handle injuries
			crew_member.injury_count += 1
			add_event(GlobalEnums.GlobalEvent.CREW_INJURED,
				"Crew member %s was injured" % crew_member.name,
				"Recovery time required")

func _process_battle_rewards() -> void:
	if current_battle_results.victory:
		# Process loot
		for item in current_battle_results.loot:
			_add_item_to_inventory(item)
		
		# Award credits
		var credit_reward = current_battle.difficulty * 15 + randi() % 20
		modify_resource(GlobalEnums.ResourceType.CREDITS, credit_reward)
		
		# Special rewards based on battle type
		if current_battle.is_story_battle:
			_process_story_battle_rewards()
		elif current_battle.is_patron_battle:
			_process_patron_battle_rewards()

func _handle_management_phase() -> void:
	# Process crew management
	_manage_crew()
	
	# Process ship management
	_manage_ship()
	
	# Process inventory management
	_manage_inventory()
	
	# Process recruitment
	_handle_recruitment()
	
	# Process upgrades
	_handle_upgrades()

func _manage_crew() -> void:
	for crew_member in crew_members:
		# Handle injuries
		if crew_member.injury_count > 0:
			crew_member.injury_count -= 1
			if crew_member.injury_count == 0:
				crew_member.is_active = true
				add_event(GlobalEnums.GlobalEvent.CREW_RECOVERED,
					"Crew member %s has recovered" % crew_member.name,
					"Ready for active duty")
		
		# Handle experience levels
		if crew_member.experience >= crew_member.next_level_xp:
			_level_up_crew_member(crew_member)
		
		# Handle morale
		_update_crew_morale(crew_member)
		
		# Handle skills
		_update_crew_skills(crew_member)

func _level_up_crew_member(crew_member: Dictionary) -> void:
	crew_member.level += 1
	crew_member.next_level_xp = crew_member.level * 100
	
	# Improve stats
	crew_member.health_max += 5
	crew_member.health = crew_member.health_max
	crew_member.speed += 1
	
	# Grant skill point
	crew_member.skill_points += 1
	
	add_event(GlobalEnums.GlobalEvent.CREW_LEVEL_UP,
		"Crew member %s reached level %d" % [crew_member.name, crew_member.level],
		"Gained improved stats and a skill point")

func _update_crew_morale(crew_member: Dictionary) -> void:
	var morale_change = 0
	
	# Base morale factors
	if resources[GlobalEnums.ResourceType.CREDITS] > 100:
		morale_change += 0.1
	if resources[GlobalEnums.ResourceType.SUPPLIES] > 50:
		morale_change += 0.1
	
	# Recent events impact
	if crew_member.injury_count > 0:
		morale_change -= 0.2
	if current_battle_results and current_battle_results.victory:
		morale_change += 0.3
	
	# Apply morale change
	crew_member.morale = clamp(crew_member.morale + morale_change, 0.0, 5.0)
	
	# Handle extreme morale
	if crew_member.morale <= 1.0:
		_handle_low_morale(crew_member)
	elif crew_member.morale >= 4.0:
		_handle_high_morale(crew_member)

func _handle_low_morale(crew_member: Dictionary) -> void:
	# 10% chance of desertion at very low morale
	if crew_member.morale <= 0.5 and randf() < 0.1:
		crew_members.erase(crew_member)
		add_event(GlobalEnums.GlobalEvent.CREW_DESERTED,
			"Crew member %s has deserted" % crew_member.name,
			"Low morale led to desertion")
	else:
		# Performance penalty
		crew_member.combat_efficiency *= 0.8
		add_event(GlobalEnums.GlobalEvent.CREW_UNHAPPY,
			"Crew member %s is unhappy" % crew_member.name,
			"Performance may suffer")

func _handle_high_morale(crew_member: Dictionary) -> void:
	# Performance bonus
	crew_member.combat_efficiency *= 1.2
	
	# Bonus experience
	crew_member.experience += 10
	
	add_event(GlobalEnums.GlobalEvent.CREW_INSPIRED,
		"Crew member %s is highly motivated" % crew_member.name,
		"Performing above average")

func _manage_ship() -> void:
	# Natural degradation
	ship_hull_points = max(0, ship_hull_points - 1)
	
	# Attempt repairs if damaged
	if ship_hull_points < ship_max_hull_points and resources[GlobalEnums.ResourceType.CREDITS] >= 10:
		var repair_amount = min(5, ship_max_hull_points - ship_hull_points)
		var repair_cost = repair_amount * 2
		
		if resources[GlobalEnums.ResourceType.CREDITS] >= repair_cost:
			ship_hull_points += repair_amount
			modify_resource(GlobalEnums.ResourceType.CREDITS, -repair_cost)
			
			add_event(GlobalEnums.GlobalEvent.SHIP_REPAIRED,
				"Repaired ship hull",
				"Spent %d credits on repairs" % repair_cost)
	
	# Check critical systems
	if ship_hull_points < ship_max_hull_points * 0.2:
		add_event(GlobalEnums.GlobalEvent.SHIP_CRITICAL,
			"Ship hull critically damaged",
			"Immediate repairs recommended")

func _manage_inventory() -> void:
	# Check for expired items
	var expired_items = []
	for item in inventory:
		if item.has("duration"):
			item.duration -= 1
			if item.duration <= 0:
				expired_items.append(item)
	
	# Remove expired items
	for item in expired_items:
		inventory.erase(item)
		add_event(GlobalEnums.GlobalEvent.ITEM_EXPIRED,
			"Item %s has expired" % item.name,
			"Removed from inventory")
	
	# Sort inventory
	inventory.sort_custom(Callable(self, "_sort_inventory_items"))
	
	# Check capacity
	if inventory.size() > inventory_capacity:
		var overflow = inventory.size() - inventory_capacity
		for i in range(overflow):
			var item = inventory.pop_back()
			add_event(GlobalEnums.GlobalEvent.INVENTORY_OVERFLOW,
				"Discarded %s due to lack of space" % item.name,
				"Consider upgrading cargo capacity")

func _handle_recruitment() -> void:
	# Check if recruitment is needed
	if crew_members.size() < max_crew_size:
		# Generate recruitment options
		var candidates = _generate_recruitment_candidates()
		
		# Add to available recruits
		available_recruits.clear()
		available_recruits.append_array(candidates)
		
		if not candidates.is_empty():
			add_event(GlobalEnums.GlobalEvent.RECRUITS_AVAILABLE,
				"New recruitment candidates available",
				"Visit recruitment office to hire")

func _handle_upgrades() -> void:
	# Check for available upgrades
	var available_upgrades = _get_available_upgrades()
	
	# Add special upgrades based on reputation
	if resources[GlobalEnums.ResourceType.REPUTATION] >= 3:
		available_upgrades.append_array(_get_special_upgrades())
	
	# Update upgrade options
	current_upgrades.clear()
	current_upgrades.append_array(available_upgrades)
	
	if not available_upgrades.is_empty():
		add_event(GlobalEnums.GlobalEvent.UPGRADES_AVAILABLE,
			"New upgrades available",
			"Visit shipyard to upgrade")

func _sort_inventory_items(a: Dictionary, b: Dictionary) -> bool:
	# Sort by type first
	if a.type != b.type:
		return a.type < b.type
	
	# Then by value
	if a.value != b.value:
		return a.value > b.value
	
	# Finally by name
	return a.name < b.name