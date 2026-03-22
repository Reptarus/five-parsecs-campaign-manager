extends WorldPhaseComponent
class_name JobOfferComponent

## Job Offer Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs job offers only
## Implements Core Rules p.78-80 - Patron jobs and opportunities

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const GameDataLoader = preload("res://src/utils/GameDataLoader.gd")
const CompendiumMissionsExpanded = preload("res://src/data/compendium_missions_expanded.gd")

# UI Components
@onready var job_offer_container: VBoxContainer = %JobOfferContainer
@onready var job_list: ItemList = %AvailableJobsList
@onready var job_details_label: Label = %JobDetailsLabel
@onready var accept_button: Button = %AcceptJobButton
@onready var decline_button: Button = %DeclineJobButton
@onready var reroll_button: Button = %RerollJobsButton

# Job offer state
var available_jobs: Array[Dictionary] = []
var selected_job_index: int = -1
var job_accepted: bool = false
var automation_enabled: bool = false

func _ready() -> void:
	name = "JobOfferComponent"
	super._ready()

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	_subscribe(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

func _connect_ui_signals() -> void:
	## Connect UI button and list signals
	if job_list:
		job_list.item_selected.connect(_on_job_selected)
		# Sprint 26.4: Ensure 48px minimum touch target for mobile
		job_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	else:
		push_warning("JobOfferComponent: job_list (AvailableJobsList) not found")
	if accept_button:
		accept_button.pressed.connect(_on_accept_job_pressed)
	if decline_button:
		decline_button.pressed.connect(_on_decline_job_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_jobs_pressed)

func _setup_initial_state() -> void:
	## Initialize the component state
	job_accepted = false
	selected_job_index = -1
	available_jobs.clear()
	_add_required_indicator()

func _add_required_indicator() -> void:
	## Add 'Required' indicator to the component title for UX clarity
	var title_label = get_node_or_null("JobOfferContainer/HeaderPanel/HeaderContent/TitleRow/Title")
	if title_label and title_label is Label:
		# Add required badge if not already present
		if not title_label.text.contains("Required"):
			title_label.text = "Job Offers [color=#D97706](Required)[/color]"
			# If using RichTextLabel, enable BBCode
			if title_label is RichTextLabel:
				title_label.bbcode_enabled = true
			else:
				# For regular Label, use simpler indicator
				title_label.text = "Job Offers  •  REQUIRED"
	_update_ui_display()

## Public API: Initialize job offers from WorldPhaseController
func initialize_job_offers(world_phase_data: Dictionary) -> void:
	## Initialize job offers from world phase data - wrapper for controller compatibility
	var patrons = world_phase_data.get("patrons", [])
	var location = world_phase_data.get("location", "Unknown Location")

	# Check for introductory campaign — provide guided missions instead of random
	var intro_mission: Dictionary = _check_introductory_mission()
	if not intro_mission.is_empty():
		job_accepted = false
		selected_job_index = -1
		available_jobs = [intro_mission]
		_update_ui_display()
		if event_bus:
			event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
				"location": location,
				"job_count": 1,
				"introductory": true
			})
		return

	# Generate jobs from ALL patrons, not just the first one
	var all_jobs: Array[Dictionary] = []

	for patron in patrons:
		var p_data: Dictionary = patron if patron is Dictionary else {"patron_name": str(patron)}
		var patron_jobs: Array[Dictionary] = _generate_job_offers(p_data, location)
		all_jobs.append_array(patron_jobs)

	# Always generate at least 1 open market opportunity
	if all_jobs.is_empty():
		var market_jobs: Array[Dictionary] = _generate_job_offers({}, location)
		all_jobs.append_array(market_jobs)

	# Store and display
	job_accepted = false
	selected_job_index = -1
	available_jobs = all_jobs
	_update_ui_display()

	# Publish event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
			"location": location,
			"job_count": available_jobs.size()
		})

	# Auto-process if enabled
	if automation_enabled and available_jobs.size() > 0:
		selected_job_index = 0
		accept_selected_job()

## Public API: Initialize job offer phase with campaign data
func initialize_job_phase(patron_data: Dictionary, current_location: String) -> void:
	## Generate job offers for current location

	# Reset state for new job offers
	job_accepted = false
	selected_job_index = -1
	available_jobs = _generate_job_offers(patron_data, current_location)

	_update_ui_display()

	# Publish job offers generated event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
			"location": current_location,
			"job_count": available_jobs.size()
		})

	# AUTO-PROCESS: If automation enabled and jobs available, auto-accept first job
	if automation_enabled and available_jobs.size() > 0:
		selected_job_index = 0
		accept_selected_job()

## Core Five Parsecs job generation (Core Rules p.78-80)
func _generate_job_offers(patron_data: Dictionary, location: String) -> Array[Dictionary]:
	## Generate job offers based on Five Parsecs rules and JSON data tables
	var jobs: Array[Dictionary] = []

	# Load patron jobs table
	var patron_table = GameDataLoader.get_patron_jobs_table()
	
	if patron_table.is_empty():
		push_error("JobOfferComponent: Failed to load patron_jobs.json - falling back to basic generation")
		return _generate_job_offers_fallback(patron_data, location)
	
	# If no patron, roll on patron contact table to see if we get one
	var effective_patron = patron_data.duplicate()
	if effective_patron.is_empty():
		var contact_result = _roll_patron_contact(patron_table.get("patron_contact_table", {}))
		if contact_result.is_empty() or contact_result.get("outcome", "") == "no_contact":
			effective_patron = {"patron_name": "Open Market", "patron_type": "generic"}
		else:
			var patron_tier = contact_result.get("patron_tier", "regular")
			effective_patron = {
				"patron_name": _generate_patron_name(patron_tier),
				"patron_type": patron_tier,
				"tier": patron_tier
			}

	# Roll for number of available jobs using job_type_table
	var job_type_table = patron_table.get("job_type_table", {})
	var job_count = 1
	
	if not job_type_table.is_empty():
		# Generate 1-3 jobs based on patron tier
		var tier = effective_patron.get("tier", effective_patron.get("patron_type", "regular"))
		job_count = _get_job_count_for_tier(tier)
	else:
		# Fallback: roll d6/2
		job_count = max(1, int(GameDataLoader.roll_d6() / 2))

	var seen_types: Array[String] = []
	for i in range(job_count):
		var job = _create_job_offer_from_table(effective_patron, location, i, job_type_table, patron_table)
		var job_key: String = job.get("job_type", "") + "_" + job.get("objective", "")
		# Re-roll duplicates (up to 3 attempts)
		var attempts := 0
		while job_key in seen_types and attempts < 3:
			job = _create_job_offer_from_table(effective_patron, location, i, job_type_table, patron_table)
			job_key = job.get("job_type", "") + "_" + job.get("objective", "")
			attempts += 1
		seen_types.append(job_key)
		_enhance_job_with_compendium(job)
		jobs.append(job)

	return jobs

## Fallback job generation if JSON loading fails
func _generate_job_offers_fallback(patron_data: Dictionary, location: String) -> Array[Dictionary]:
	## Fallback to original job generation if JSON fails
	var jobs: Array[Dictionary] = []
	var effective_patron = patron_data.duplicate()
	if effective_patron.is_empty():
		effective_patron = {"patron_name": "Open Market", "patron_type": "generic"}
	
	var job_count = max(1, int(GameDataLoader.roll_d6() / 2))

	var seen_types: Array[String] = []
	for i in range(job_count):
		var job = _create_job_offer(effective_patron, location, i)
		var job_key: String = job.get("job_type", "") + "_" + job.get("objective", "")
		var attempts := 0
		while job_key in seen_types and attempts < 3:
			job = _create_job_offer(effective_patron, location, i)
			job_key = job.get("job_type", "") + "_" + job.get("objective", "")
			attempts += 1
		seen_types.append(job_key)
		_enhance_job_with_compendium(job)
		jobs.append(job)

	return jobs

## Roll on patron contact table (2d6)
func _roll_patron_contact(contact_table: Dictionary) -> Dictionary:
	## Roll to see if patron makes contact with skill modifiers
	if contact_table.is_empty():
		return {}
	
	# Base 2d6 roll
	var base_roll: int = GameDataLoader.roll_2d6()
	
	# Apply skill modifiers
	var skill_bonus: int = _get_patron_contact_skill_modifiers(contact_table)
	
	# Apply world trait modifiers
	var world_bonus: int = _get_world_trait_modifiers(contact_table)
	
	var total_roll: int = base_roll + skill_bonus + world_bonus
	
	# Lookup result in range-based table
	var result: Dictionary = _lookup_patron_contact_result(contact_table.get("results", {}), total_roll)
	
	return result

## Get skill bonuses for patron contact (CONNECTIONS +2, SAVVY +1)
func _get_patron_contact_skill_modifiers(contact_table: Dictionary) -> int:
	## Calculate skill bonuses from crew for patron contact
	var skill_bonuses: Dictionary = contact_table.get("modifiers", {}).get("skill_bonuses", {})
	if skill_bonuses.is_empty():
		return 0
	
	var total_bonus: int = 0
	
	# Access crew data from GameStateManager
	var crew_list: Array = GameStateManager.get_crew_members()
	if crew_list.is_empty():
		return 0
	
	# Check for CONNECTIONS skill (+2)
	if skill_bonuses.has("CONNECTIONS"):
		for member in crew_list:
			if member is Character:
				# Check if character has skills property
				if member.get("skills") != null:
					var member_skills = member.get("skills")
					if member_skills is Array and "CONNECTIONS" in member_skills:
						total_bonus += skill_bonuses["CONNECTIONS"].get("bonus", 0)
						break  # Only apply once
	
	# Check for SAVVY skill (+1)
	if skill_bonuses.has("SAVVY"):
		for member in crew_list:
			if member is Character:
				# Check if character has skills property
				if member.get("skills") != null:
					var member_skills = member.get("skills")
					if member_skills is Array and "SAVVY" in member_skills:
						total_bonus += skill_bonuses["SAVVY"].get("bonus", 0)
						break  # Only apply once
	
	return total_bonus

## Get world trait modifiers for patron contact
func _get_world_trait_modifiers(contact_table: Dictionary) -> int:
	## Calculate world trait modifiers for patron contact
	var world_modifiers: Dictionary = contact_table.get("modifiers", {}).get("world_modifiers", {})
	if world_modifiers.is_empty():
		return 0
	
	# Access current world traits from campaign data
	var current_world: Dictionary = {}
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var campaign = gs.get_current_campaign()
		if campaign and "world_data" in campaign:
			current_world = campaign.world_data
	var world_traits: Array = current_world.get("traits", [])
	
	if world_traits.is_empty():
		return 0
	
	var total_modifier: int = 0
	
	for world_trait in world_traits:
		var trait_name: String = world_trait if world_trait is String else world_trait.get("name", "")
		if world_modifiers.has(trait_name):
			var modifier_data: Dictionary = world_modifiers[trait_name]
			if modifier_data.has("bonus"):
				total_modifier += modifier_data["bonus"]
			elif modifier_data.has("penalty"):
				total_modifier += modifier_data["penalty"]  # Penalty is negative
	
	return total_modifier

## Lookup patron contact result with range checking
func _lookup_patron_contact_result(results_table: Dictionary, roll: int) -> Dictionary:
	## Lookup result in range-based table (handles "2-6", "7-8", etc.)
	if results_table.is_empty():
		return {}
	
	for range_str in results_table.keys():
		if _is_roll_in_range(roll, range_str):
			return results_table[range_str]
	
	# Fallback: no_contact
	return {"outcome": "no_contact", "description": "No patron contact"}

## Check if roll falls within range string
func _is_roll_in_range(value: int, range_str: String) -> bool:
	## Check if value is in range (handles "2-6", "7-8", "11", etc.)
	if "-" in range_str:
		# Range format: "2-6"
		var parts: PackedStringArray = range_str.split("-")
		if parts.size() == 2:
			var min_val: int = int(parts[0])
			var max_val: int = int(parts[1])
			return value >= min_val and value <= max_val
	else:
		# Single value: "11", "12"
		return value == int(range_str)
	
	return false

## Get job count based on patron tier
func _get_job_count_for_tier(tier: String) -> int:
	match tier:
		"minor":
			return 1
		"regular":
			return randi_range(1, 2)
		"major":
			return randi_range(2, 3)
		"elite":
			return 3
		_:
			return 1

## Generate patron name based on tier
func _generate_patron_name(tier: String) -> String:
	var prefixes = {
		"minor": ["Local", "Small-time", "Independent"],
		"regular": ["Regional", "Established", "Reputable"],
		"major": ["Sector", "Corporate", "Government"],
		"elite": ["Galactic", "Imperial", "High Council"]
	}
	
	var suffixes = ["Contractor", "Broker", "Agent", "Representative", "Official"]
	
	var prefix_list = prefixes.get(tier, prefixes["regular"])
	var prefix = prefix_list[randi() % prefix_list.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return "%s %s" % [prefix, suffix]

## Create job offer using JSON data tables
func _create_job_offer_from_table(patron_data: Dictionary, location: String, job_index: int, job_type_table: Dictionary, patron_table: Dictionary) -> Dictionary:
	## Create job using patron_jobs.json table data
	if job_type_table.is_empty():
		# Fallback to original method
		return _create_job_offer(patron_data, location, job_index)
	
	# Roll on job type table (d10)
	var job_roll = GameDataLoader.roll_d10()
	var job_result = GameDataLoader.roll_on_table(job_type_table, job_roll)
	
	if job_result.is_empty():
		push_warning("JobOfferComponent: No job type for roll %d, using fallback" % job_roll)
		return _create_job_offer(patron_data, location, job_index)
	
	# Extract job type data
	var job_type = job_result.get("job_type", "DELIVERY")
	var job_description = job_result.get("description", "Unknown job")
	var base_pay = job_result.get("base_pay", 4)
	var danger_level = job_result.get("danger_level", 1)
	var requirements = job_result.get("typical_requirements", [])
	
	# Apply patron tier multiplier
	var payment_modifiers = patron_table.get("job_payment_modifiers", {})
	var tier_multipliers = payment_modifiers.get("patron_tier_multipliers", {})
	var patron_tier = patron_data.get("tier", patron_data.get("patron_type", "regular"))
	var tier_multiplier = tier_multipliers.get(patron_tier, 1.0)
	
	# Apply danger level bonus
	var danger_bonuses = payment_modifiers.get("danger_level_bonuses", {})
	var danger_bonus = danger_bonuses.get(str(danger_level), 0)
	
	# Calculate final payment
	var final_pay = int(base_pay * tier_multiplier) + danger_bonus
	
	# Derive mission source for Compendium battle type selection (p.118)
	var mission_source: String = _derive_mission_source(patron_data)

	# Build job structure
	var job = {
		"id": "job_%d_%s" % [job_index, Time.get_ticks_msec()],
		"location": location,
		"patron_type": patron_data.get("patron_type", "generic"),
		"patron_name": patron_data.get("patron_name", "Unknown Patron"),
		"job_type": job_type,
		"objective": job_type.capitalize(),
		"objective_description": job_description,
		"danger_pay": final_pay,
		"pay": final_pay,
		"danger_level": danger_level,
		"time_frame": _roll_time_frame(null, 0),  # Use existing function
		"requirements": requirements,
		"benefits": [],
		"hazards": [],
		"conditions": [],
		"enemy_type": _determine_enemy_type(),
		"double_roll_bonus": false,
		"patron": patron_data.get("patron_name", "Unknown"),
		"source": mission_source,
		"mission_source": mission_source,
	}

	return job

## Original job creation method (fallback)
func _create_job_offer(patron_data: Dictionary, location: String, job_index: int) -> Dictionary:
	## Create a single job offer using Core Rules tables
	var dice_manager = get_node_or_null("/root/DiceManager")

	# 1. Determine Patron Type (or use provided)
	var patron_info = _roll_patron_type(dice_manager)
	var patron_type = patron_data.get("patron_type", patron_info.type)
	var patron_name = patron_data.get("patron_name", patron_type)

	# 2. Roll Danger Pay with patron bonus
	var danger_pay_bonus = patron_info.danger_pay_bonus if patron_type == "Corporation" else 0
	var danger_pay = _roll_danger_pay(dice_manager, danger_pay_bonus)

	# 3. Roll Time Frame with patron bonus
	var time_frame_bonus = patron_info.time_frame_bonus if patron_type == "Secretive Group" else 0
	var time_frame = _roll_time_frame(dice_manager, time_frame_bonus)

	# 4. Roll Objective
	var objective_info = _roll_objective(dice_manager)

	# 5. Roll Benefits/Hazards/Conditions
	var bhc = _roll_bhc(dice_manager, patron_type)

	# Derive mission source for Compendium battle type selection (p.118)
	var mission_source: String = _derive_mission_source(patron_data)

	# Build complete job structure
	var job = {
		"id": "job_%d_%s" % [job_index, Time.get_ticks_msec()],
		"location": location,
		"patron_type": patron_type,
		"patron_name": patron_name,
		"objective": objective_info.name,
		"objective_description": objective_info.description,
		"danger_pay": danger_pay.credits,
		"double_roll_bonus": danger_pay.double_roll_bonus,
		"time_frame": time_frame,
		"benefits": bhc.benefits,
		"hazards": bhc.hazards,
		"conditions": bhc.conditions,
		"enemy_type": _determine_enemy_type(),
		# Legacy fields for compatibility
		"pay": danger_pay.credits,
		"danger_level": (dice_manager.roll_d6() % 3) + 1 if dice_manager else 1,
		"patron": patron_name,
		"source": mission_source,
		"mission_source": mission_source,
	}

	return job

## Core Rules Tables (pp.78-80)

func _roll_patron_type(dice_manager) -> Dictionary:
	## Roll on Patron Table (D10) - Core Rules p.78
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10()
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1

	var patron_type = ""
	var danger_pay_bonus = 0
	var time_frame_bonus = 0

	match roll:
		1, 2:
			patron_type = "Corporation"
			danger_pay_bonus = 1
		3, 4:
			patron_type = "Local Government"
		5:
			patron_type = "Sector Government"
		6, 7:
			patron_type = "Wealthy Individual"
		8, 9:
			patron_type = "Private Organization"
		10, _:
			patron_type = "Secretive Group"
			time_frame_bonus = 1

	return {
		"type": patron_type,
		"danger_pay_bonus": danger_pay_bonus,
		"time_frame_bonus": time_frame_bonus
	}

func _roll_danger_pay(dice_manager, bonus: int = 0) -> Dictionary:
	## Roll on Danger Pay Table (D10) - Core Rules p.78
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10() + bonus
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1 + bonus

	var credits = 1
	var double_roll_bonus = false

	if roll <= 4:
		credits = 1
	elif roll <= 8:
		credits = 2
	elif roll == 9:
		credits = 3
	else:  # 10+
		credits = 3
		double_roll_bonus = true

	return {
		"credits": credits,
		"double_roll_bonus": double_roll_bonus
	}

func _roll_time_frame(dice_manager, bonus: int = 0) -> String:
	## Roll on Time Frame Table (D10) - Core Rules p.78
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10() + bonus
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1 + bonus

	if roll <= 5:
		return "This campaign turn"
	elif roll <= 7:
		return "This or next turn"
	elif roll <= 9:
		return "Within 2 turns"
	else:
		return "Any time"

func _roll_objective(dice_manager) -> Dictionary:
	## Roll on Patron Mission Objectives (D10) - Core Rules p.100
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10()
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1

	var objective = ""
	var description = ""

	match roll:
		1, 2:
			objective = "Deliver"
			description = "Deliver a package to the center of the battlefield"
		3:
			objective = "Eliminate"
			description = "Kill a specific target enemy"
		4, 5:
			objective = "Move Through"
			description = "Get at least 2 crew off the opposite edge"
		6, 7:
			objective = "Secure"
			description = "Hold the center objective until enemies flee"
		8:
			objective = "Protect"
			description = "Defend a VIP or location from attack"
		9, 10, _:
			objective = "Fight Off"
			description = "Drive off all enemies and hold the field"

	return {
		"name": objective,
		"description": description
	}

func _roll_bhc(dice_manager, patron_type: String) -> Dictionary:
	## Roll for Benefits, Hazards, Conditions based on patron type
	var result = {
		"benefits": [],
		"hazards": [],
		"conditions": []
	}

	# Thresholds by patron type (roll must be >= threshold)
	var thresholds = {
		"Corporation": {"benefits": 8, "hazards": 8, "conditions": 5},
		"Local Government": {"benefits": 8, "hazards": 8, "conditions": 8},
		"Sector Government": {"benefits": 8, "hazards": 8, "conditions": 8},
		"Wealthy Individual": {"benefits": 5, "hazards": 8, "conditions": 8},
		"Private Organization": {"benefits": 8, "hazards": 8, "conditions": 8},
		"Secretive Group": {"benefits": 8, "hazards": 5, "conditions": 8}
	}

	var patron_thresholds = thresholds.get(patron_type, {"benefits": 8, "hazards": 8, "conditions": 8})

	# Roll for each category
	var benefit_roll = _roll_d10_simulated(dice_manager)
	var hazard_roll = _roll_d10_simulated(dice_manager)
	var condition_roll = _roll_d10_simulated(dice_manager)

	if benefit_roll >= patron_thresholds.benefits:
		result.benefits.append(_roll_benefit_subtable(dice_manager))
	if hazard_roll >= patron_thresholds.hazards:
		result.hazards.append(_roll_hazard_subtable(dice_manager))
	if condition_roll >= patron_thresholds.conditions:
		result.conditions.append(_roll_condition_subtable(dice_manager))

	return result

func _roll_d10_simulated(dice_manager) -> int:
	## Roll D10, simulating with 2D6 if needed
	if dice_manager and dice_manager.has_method("roll_d10"):
		return dice_manager.roll_d10()
	elif dice_manager:
		return (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1
	return 5

func _roll_benefit_subtable(dice_manager) -> Dictionary:
	## Roll on Benefits Subtable (D10)
	var roll = _roll_d10_simulated(dice_manager)

	match roll:
		1, 2:
			return {"name": "Fringe Benefit", "effect": "Roll on the Loot Table"}
		3, 4:
			return {"name": "Connections", "effect": "Gain a Rumor"}
		5:
			return {"name": "Company Store", "effect": "Roll on the Trade Table"}
		6:
			return {"name": "Health Insurance", "effect": "2 turns of injury recovery"}
		7:
			return {"name": "Security Team", "effect": "Reduce enemy numbers by 1"}
		8, 9:
			return {"name": "Persistent", "effect": "Patron remains if you travel"}
		10, _:
			return {"name": "Negotiable", "effect": "Reroll Danger Pay, keep better"}

func _roll_hazard_subtable(dice_manager) -> Dictionary:
	## Roll on Hazards Subtable (D10)
	var roll = _roll_d10_simulated(dice_manager)

	match roll:
		1, 2:
			return {"name": "Dangerous Job", "effect": "+1 enemy numbers"}
		3, 4:
			return {"name": "Hot Job", "effect": "Earn enemy on 1-2 instead of 1"}
		5:
			return {"name": "VIP", "effect": "Random enemy has +1 Toughness, +2 Combat"}
		6:
			return {"name": "Veteran Opposition", "effect": "Enemy -1 panic range"}
		7:
			return {"name": "Low Priority", "effect": "Reduce enemy numbers by 1"}
		8, 9, 10, _:
			return {"name": "Private Transport", "effect": "Rivals can't track you this turn"}

func _roll_condition_subtable(dice_manager) -> Dictionary:
	## Roll on Conditions Subtable (D10)
	var roll = _roll_d10_simulated(dice_manager)

	match roll:
		1:
			return {"name": "Vengeful", "effect": "Failure makes Patron a Rival"}
		2, 3:
			return {"name": "Demanding", "effect": "Danger Pay only on success"}
		4:
			return {"name": "Small Squad", "effect": "Max 4 crew deployment"}
		5:
			return {"name": "Full Squad", "effect": "Must have 6 available crew"}
		6:
			return {"name": "Clean", "effect": "Cannot have law enforcement Rivals"}
		7, 8:
			return {"name": "Busy", "effect": "Success = new job next turn"}
		9:
			return {"name": "One-time Contract", "effect": "Patron can't be retained"}
		10, _:
			return {"name": "Reputation Required", "effect": "Need prior job on this world"}

func _determine_enemy_type() -> String:
	## Determine enemy type for job
	var enemy_types = [
		"Raiders",
		"Rivals",
		"Criminals",
		"Pirates",
		"Bounty Hunters",
		"Unknown Hostiles"
	]

	var dice_manager = get_node_or_null("/root/DiceManager")
	if dice_manager:
		var index = dice_manager.roll_d6() - 1
		return enemy_types[index % enemy_types.size()]

	return enemy_types[0]

## Derive mission source category for Compendium battle type selection (p.118)
## Maps patron_type to source: "patron", "opportunity", "rival", "faction", "quest"
func _derive_mission_source(patron_data: Dictionary) -> String:
	var pt: String = patron_data.get("patron_type", "generic").to_lower()
	if pt == "generic" or pt == "open market" or pt == "":
		return "opportunity"
	if "faction" in pt:
		return "faction"
	if "rival" in pt:
		return "rival"
	if "quest" in pt:
		return "quest"
	# All other patron types (minor, regular, major, elite, corporation, etc.)
	return "patron"

## Job acceptance/rejection
func accept_selected_job() -> bool:
	## Accept the currently selected job
	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		push_warning("JobOfferComponent: Invalid job selection (index=%d, jobs=%d)" % [selected_job_index, available_jobs.size()])
		return false

	var job = available_jobs[selected_job_index]
	job_accepted = true

	# Publish job accepted event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, {
			"job_data": job
		})

	_update_ui_display()
	return true

func decline_selected_job() -> void:
	## Decline the currently selected job
	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		return

	var job = available_jobs[selected_job_index]

	# Remove job from available list
	available_jobs.remove_at(selected_job_index)
	selected_job_index = -1

	_update_ui_display()

## UI Event Handlers
func _on_job_selected(index: int) -> void:
	## Handle job selection from list
	selected_job_index = index
	_update_job_details()
	_update_ui_display()

func _on_accept_job_pressed() -> void:
	## Handle accept job button press
	accept_selected_job()

func _on_decline_job_pressed() -> void:
	## Handle decline job button press
	decline_selected_job()

func _on_reroll_jobs_pressed() -> void:
	## Handle reroll jobs button press (costs 1 credit)
	if GameStateManager.get_credits() >= 1:
		GameStateManager.remove_credits(1)

		# Regenerate jobs
		var patron_data = {}  # NOTE: Needs campaign patron data integration
		var location = ""     # NOTE: Needs campaign location integration
		initialize_job_phase(patron_data, location)


## UI Updates
func _update_ui_display() -> void:
	## Update UI display with current job offers
	if job_list:
		job_list.clear()
		for i in range(available_jobs.size()):
			var job = available_jobs[i]
			var job_text = "%s (%s) - +%d cr - %s" % [
				job.get("objective", "Unknown"),
				job.get("patron_type", "Unknown"),
				job.get("danger_pay", job.get("pay", 0)),
				job.get("time_frame", "Unknown")
			]
			job_list.add_item(job_text)
	else:
		pass

	# Update button states
	var has_selection = selected_job_index >= 0 and selected_job_index < available_jobs.size()
	if accept_button:
		accept_button.disabled = not has_selection or job_accepted
	if decline_button:
		decline_button.disabled = not has_selection or job_accepted

	_update_job_details()

func _update_job_details() -> void:
	## Update job details display with Core Rules info
	if not job_details_label:
		return

	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		job_details_label.text = "Select a job to view details"
		return

	var job = available_jobs[selected_job_index]

	# Build rich details display
	var details = "=== JOB OFFER ===\n\n"

	# Patron info
	details += "PATRON: %s\n" % job.get("patron_name", job.get("patron", "Unknown"))
	details += "Type: %s\n\n" % job.get("patron_type", "Unknown")

	# Objective
	details += "OBJECTIVE: %s\n" % job.get("objective", "Unknown")
	details += "%s\n\n" % job.get("objective_description", "")

	# Pay and timing
	details += "DANGER PAY: +%d credits\n" % job.get("danger_pay", job.get("pay", 0))
	if job.get("double_roll_bonus", false):
		details += "(Bonus: Roll twice for mission pay, keep higher)\n"
	details += "TIME FRAME: %s\n\n" % job.get("time_frame", "Unknown")

	# Enemy
	details += "ENEMY: %s\n" % job.get("enemy_type", "Unknown")
	details += "Danger Level: %d\n\n" % job.get("danger_level", 1)

	# Benefits
	var benefits = job.get("benefits", [])
	if benefits.size() > 0:
		details += "BENEFITS:\n"
		for benefit in benefits:
			details += "  • %s: %s\n" % [benefit.name, benefit.effect]
		details += "\n"

	# Hazards
	var hazards = job.get("hazards", [])
	if hazards.size() > 0:
		details += "HAZARDS:\n"
		for hazard in hazards:
			details += "  • %s: %s\n" % [hazard.name, hazard.effect]
		details += "\n"

	# Conditions
	var conditions = job.get("conditions", [])
	if conditions.size() > 0:
		details += "CONDITIONS:\n"
		for condition in conditions:
			details += "  • %s: %s\n" % [condition.name, condition.effect]
		details += "\n"

	# Location
	details += "LOCATION: %s\n" % job.get("location", "Unknown")

	# Compendium DLC enhancements (if available)
	if job.has("dlc_objective_overview"):
		details += "\n--- COMPENDIUM MISSION DETAILS ---\n"
		details += "OVERVIEW: %s\n" % job.get("dlc_objective_overview", "")
		if not job.get("dlc_objective_instruction", "").is_empty():
			details += "  %s\n" % job.get("dlc_objective_instruction", "")
	if job.has("dlc_specific_objective"):
		details += "SPECIFIC OBJECTIVE: %s\n" % job.get("dlc_specific_objective", "")
		if not job.get("dlc_specific_instruction", "").is_empty():
			details += "  %s\n" % job.get("dlc_specific_instruction", "")
	if job.has("dlc_time_constraint"):
		details += "TIME CONSTRAINT: %s\n" % job.get("dlc_time_constraint", "")
		if not job.get("dlc_time_instruction", "").is_empty():
			details += "  %s\n" % job.get("dlc_time_instruction", "")
	if job.has("dlc_patron_condition"):
		details += "PATRON CONDITION: %s\n" % job.get("dlc_patron_condition", "")
		if not job.get("dlc_patron_instruction", "").is_empty():
			details += "  %s\n" % job.get("dlc_patron_instruction", "")
	if job.has("dlc_extraction"):
		details += "EXTRACTION: %s\n" % job.get("dlc_extraction", "")
		if not job.get("dlc_extraction_instruction", "").is_empty():
			details += "  %s\n" % job.get("dlc_extraction_instruction", "")

	job_details_label.text = details

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "job_offers":
		pass

func _on_automation_toggled(data: Dictionary) -> void:
	## Handle automation toggle events
	automation_enabled = data.get("enabled", false)

	# AUTO-PROCESS: If enabled and jobs available, auto-accept first job
	if automation_enabled and available_jobs.size() > 0 and not job_accepted:
		selected_job_index = 0
		accept_selected_job()

## Public API for integration
func is_job_accepted() -> bool:
	## Check if a job has been accepted
	return job_accepted

func get_accepted_job() -> Dictionary:
	## Get the accepted job data
	if job_accepted and selected_job_index >= 0 and selected_job_index < available_jobs.size():
		return available_jobs[selected_job_index].duplicate()
	return {}

func get_available_jobs() -> Array[Dictionary]:
	## Get all available jobs
	return available_jobs.duplicate()

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	## Get step results for phase completion (standardized interface)
	return {
		"job_accepted": job_accepted,
		"accepted_job": get_accepted_job(),
		"available_jobs": available_jobs.duplicate(),
		"selected_job_index": selected_job_index
	}

func reset_job_phase() -> void:
	## Reset job phase for new turn
	job_accepted = false
	selected_job_index = -1
	available_jobs.clear()
	_update_ui_display()

## ── Compendium Introductory Campaign (DLC) ──

func _check_introductory_mission() -> Dictionary:
	## If introductory_campaign is enabled, return the guided mission for this turn.
	## Returns {} if not applicable (flag not set, DLC disabled, or turn past intro range).
	var game_state_node = get_node_or_null("/root/GameState")
	if not game_state_node:
		return {}
	var campaign = game_state_node.campaign if "campaign" in game_state_node else null
	if not campaign:
		return {}
	if not "progress_data" in campaign:
		return {}
	if not campaign.progress_data.get("introductory_campaign", false):
		return {}

	var turn: int = campaign.progress_data.get("current_turn", 1)
	var intro: Dictionary = CompendiumMissionsExpanded.get_introductory_mission(turn)
	if intro.is_empty():
		return {}  # Past introductory range — fall through to normal generation

	# Convert introductory mission format to job offer format
	return {
		"id": "intro_turn_%d" % turn,
		"location": "Introductory Mission",
		"patron_type": "Tutorial",
		"patron_name": "Campaign Guide",
		"objective": intro.get("name", "Introductory Mission"),
		"objective_description": intro.get("instruction", ""),
		"danger_pay": intro.get("pay", 2),
		"pay": intro.get("pay", 2),
		"double_roll_bonus": false,
		"time_frame": "This Turn",
		"danger_level": intro.get("danger", 1),
		"benefits": [],
		"hazards": [],
		"conditions": [],
		"enemy_type": intro.get("enemy_type", "Determined by scenario"),
		"source": "introductory",
		"mission_source": "introductory",
		"_introductory": true,
	}

## ── Compendium Expanded Missions (DLC, pp.118-125) ──

func _enhance_job_with_compendium(job: Dictionary) -> void:
	## Enhance a job offer with Compendium expanded mission data.
	## Self-gated: methods return {} if EXPANDED_MISSIONS DLC disabled.
	var objective_overview: Dictionary = CompendiumMissionsExpanded.roll_objective_overview()
	if not objective_overview.is_empty():
		job["dlc_objective_overview"] = objective_overview.get("name", "")
		job["dlc_objective_instruction"] = objective_overview.get("instruction", "")

	var specific_obj: Dictionary = CompendiumMissionsExpanded.roll_specific_objective()
	if not specific_obj.is_empty():
		job["dlc_specific_objective"] = specific_obj.get("name", "")
		job["dlc_specific_instruction"] = specific_obj.get("instruction", "")

	var time_constraint: Dictionary = CompendiumMissionsExpanded.roll_time_constraint()
	if not time_constraint.is_empty():
		job["dlc_time_constraint"] = time_constraint.get("name", "")
		job["dlc_time_instruction"] = time_constraint.get("instruction", "")

	var patron_cond: Dictionary = CompendiumMissionsExpanded.roll_patron_condition()
	if not patron_cond.is_empty():
		job["dlc_patron_condition"] = patron_cond.get("name", "")
		job["dlc_patron_instruction"] = patron_cond.get("instruction", "")

	var extraction: Dictionary = CompendiumMissionsExpanded.roll_extraction()
	if not extraction.is_empty():
		job["dlc_extraction"] = extraction.get("name", "")
		job["dlc_extraction_instruction"] = extraction.get("instruction", "")
