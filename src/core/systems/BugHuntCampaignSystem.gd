class_name BugHuntCampaignSystem
extends Node

## BugHuntCampaignSystem
##
## Manages Bug Hunt campaign mode from Bug Hunt DLC.
## REUSES ~90% of core Five Parsecs campaign mechanics with military/bug-themed overrides.
##
## Code Reuse Strategy:
## - Extends core campaign turn structure (Travel→World→Battle→Post-Battle)
## - Reuses core character stats, equipment, and combat systems
## - Overrides specific phases with military-themed variants
## - Adds Bug Hunt-specific systems (Panic, Motion Tracker, Infestation)
##
## Usage:
##   BugHuntCampaignSystem.start_campaign(squad_name)
##   BugHuntCampaignSystem.process_deployment_phase()
##   BugHuntCampaignSystem.process_tactical_phase()
##   BugHuntCampaignSystem.process_base_phase()

signal campaign_started(campaign_data: Dictionary)
signal phase_changed(old_phase: String, new_phase: String)
signal mission_completed(mission_result: Dictionary)
signal squad_morale_changed(old_morale: int, new_morale: int)
signal infestation_level_changed(old_level: int, new_level: int)

## Campaign phases (modified from core Four Phases)
enum CampaignPhase {
	DEPLOYMENT,  # Replaces Travel Phase
	TACTICAL,    # Replaces Battle Phase (with bug hunt mechanics)
	POST_ACTION, # Replaces Post-Battle Phase
	BASE         # Replaces World Phase
}

## Current campaign data (reuses core campaign structure)
var campaign_data: Dictionary = {}

## Current phase
var current_phase: CampaignPhase = CampaignPhase.DEPLOYMENT

## Reference to core campaign manager (for code reuse)
var core_campaign: Node = null

## Bug Hunt-specific systems
var panic_system: PanicSystem = null
var motion_tracker_system: MotionTrackerSystem = null
var infestation_system: InfestationSystem = null
var military_hierarchy_system: MilitaryHierarchySystem = null

## Content filter
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()
	_load_bug_hunt_systems()
	_initialize_core_campaign_reference()

## Start new Bug Hunt campaign
func start_campaign(squad_name: String, difficulty: String = "standard") -> Dictionary:
	# REUSE CORE: Use core campaign initialization structure
	campaign_data = _create_campaign_data_structure()

	campaign_data.campaign_type = "bug_hunt"
	campaign_data.squad_name = squad_name
	campaign_data.difficulty = difficulty

	# Bug Hunt-specific initialization
	campaign_data.squad_morale = 100
	campaign_data.infestation_level = 1
	campaign_data.requisition_points = 5
	campaign_data.missions_completed = 0
	campaign_data.casualties_total = 0
	campaign_data.current_mission = null

	# REUSE CORE: Initialize squad using core character system
	campaign_data.squad = _initialize_squad()

	# Initialize military hierarchy
	if military_hierarchy_system:
		military_hierarchy_system.assign_initial_ranks(campaign_data.squad)

	print("BugHuntCampaignSystem: Campaign '%s' started (Difficulty: %s)" % [squad_name, difficulty])
	campaign_started.emit(campaign_data)

	return campaign_data

## Process Deployment Phase (replaces Travel Phase)
func process_deployment_phase() -> void:
	_change_phase(CampaignPhase.DEPLOYMENT)

	# 1. Mission selection
	var available_missions := _get_available_missions()
	campaign_data.available_missions = available_missions

	# 2. Squad selection (which soldiers go on mission)
	# (Handled by UI - player selects from roster)

	# 3. Loadout assignment
	# REUSE CORE: Use core equipment system
	# (Handled by UI - player assigns equipment)

	# 4. Intel gathering (optional)
	var intel := _roll_intel_gathering()
	campaign_data.current_intel = intel

	print("BugHuntCampaignSystem: Deployment phase complete. %d missions available." % available_missions.size())

## Process Tactical Phase (Bug Hunt battle - replaces Battle Phase)
func process_tactical_phase() -> void:
	_change_phase(CampaignPhase.TACTICAL)

	if not campaign_data.has("current_mission"):
		push_error("BugHuntCampaignSystem: No mission selected for tactical phase")
		return

	# REUSE CORE: Use ~90% of core battle system
	# The core battle system handles:
	# - Turn structure
	# - Movement and combat
	# - Line of sight
	# - Dice rolling
	# - Damage calculation

	# Bug Hunt-specific additions:
	# - Motion tracker detection
	# - Panic checks
	# - Bug AI behavior
	# - Extraction objectives

	var mission := campaign_data.current_mission

	# Setup battle using core systems
	var battle_data := _setup_bug_hunt_battle(mission)
	campaign_data.current_battle = battle_data

	# Activate Bug Hunt systems
	if motion_tracker_system:
		motion_tracker_system.initialize_for_battle(battle_data)

	if panic_system:
		panic_system.set_squad_morale(campaign_data.squad_morale)

	print("BugHuntCampaignSystem: Tactical phase initialized. Mission: %s" % mission.name)

## Process Post-Action Phase (replaces Post-Battle Phase)
func process_post_action_phase(battle_result: Dictionary) -> void:
	_change_phase(CampaignPhase.POST_ACTION)

	# REUSE CORE: Use core post-battle structure (14 steps)
	# Modified for Bug Hunt:

	# 1. Process casualties
	var casualties := _process_casualties(battle_result)
	campaign_data.casualties_total += casualties.size()

	# 2. Award experience
	# REUSE CORE: Use core XP system
	_award_experience(battle_result)

	# 3. Calculate mission rewards
	var requisition := _calculate_requisition_earned(battle_result)
	campaign_data.requisition_points += requisition

	# 4. Update infestation level
	_update_infestation_level(battle_result)

	# 5. Squad morale changes
	_update_squad_morale(battle_result, casualties.size())

	# 6. After-action report
	var report := _generate_after_action_report(battle_result)
	campaign_data.last_mission_report = report

	campaign_data.missions_completed += 1

	print("BugHuntCampaignSystem: Post-action complete. RP: +%d, Casualties: %d" % [requisition, casualties.size()])
	mission_completed.emit(report)

## Process Base Phase (replaces World Phase)
func process_base_phase() -> void:
	_change_phase(CampaignPhase.BASE)

	# Modified World Phase for military base management:

	# 1. Upkeep (REUSED FROM CORE)
	var upkeep_cost := campaign_data.squad.size()
	campaign_data.requisition_points = max(0, campaign_data.requisition_points - upkeep_cost)

	# 2. Request reinforcements (replaces Recruit task)
	# (Player can spend RP to get new soldiers)

	# 3. Research alien biology (new mechanic)
	# Unlocks tactical advantages against specific bug types

	# 4. Equipment requisition (replaces Trade/Purchase)
	# Spend RP to acquire military equipment

	# 5. Medical treatment (replaces Repair Kit)
	# REUSE CORE: Use core injury/healing system
	_process_medical_treatment()

	# 6. Training (REUSED FROM CORE)
	# Soldiers can train to gain XP

	# 7. Base upgrades (new mechanic)
	# Permanent bonuses (better med bay, armory, etc.)

	print("BugHuntCampaignSystem: Base phase complete. RP remaining: %d" % campaign_data.requisition_points)

## Get campaign status
func get_campaign_status() -> Dictionary:
	return {
		"campaign_type": "bug_hunt",
		"squad_name": campaign_data.get("squad_name", "Unknown"),
		"phase": CampaignPhase.keys()[current_phase],
		"missions_completed": campaign_data.get("missions_completed", 0),
		"squad_size": campaign_data.get("squad", []).size(),
		"squad_morale": campaign_data.get("squad_morale", 100),
		"infestation_level": campaign_data.get("infestation_level", 1),
		"requisition_points": campaign_data.get("requisition_points", 0),
		"total_casualties": campaign_data.get("casualties_total", 0)
	}

## Check if campaign can continue
func can_continue_campaign() -> bool:
	# Campaign ends if:
	# - All soldiers dead
	# - Squad morale reaches 0
	# - Infestation level reaches max (colony overrun)

	var squad_alive := campaign_data.get("squad", []).size() > 0
	var morale_ok := campaign_data.get("squad_morale", 100) > 0
	var not_overrun := campaign_data.get("infestation_level", 1) < 6

	return squad_alive and morale_ok and not_overrun

# ============================================================================
# CORE CODE REUSE METHODS
# ============================================================================

## REUSES CORE: Campaign data structure from core campaign
func _create_campaign_data_structure() -> Dictionary:
	# This mirrors the core campaign structure but with Bug Hunt fields
	return {
		# CORE FIELDS (reused):
		"campaign_id": _generate_campaign_id(),
		"turn_number": 1,
		"credits": 0, # Replaced by requisition_points but kept for compatibility
		"story_points": 0,
		"squad": [],
		"equipment_stash": [],

		# BUG HUNT FIELDS (added):
		"campaign_type": "bug_hunt",
		"squad_morale": 100,
		"infestation_level": 1,
		"requisition_points": 5,
		"research_completed": [],
		"base_upgrades": []
	}

## REUSES CORE: Character creation system
func _initialize_squad() -> Array:
	# Use core character creation but with military backgrounds
	var squad := []

	# Starting squad: 6 soldiers (similar to core 6 crew size)
	for i in range(6):
		var soldier := _create_soldier(i)
		squad.append(soldier)

	return squad

## REUSES CORE: Character stats structure
func _create_soldier(index: int) -> Dictionary:
	# CORE CHARACTER STRUCTURE (fully reused):
	# - Reactions, Speed, Combat Skill, Toughness, Savvy
	# - XP and level progression
	# - Equipment slots
	# - Status effects

	var soldier := {
		"id": "soldier_%d" % index,
		"name": _generate_soldier_name(),
		"rank": "Private", # Bug Hunt addition

		# CORE STATS (exact same system):
		"reactions": 1,
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"savvy": 0,

		# CORE SYSTEMS (reused):
		"xp": 0,
		"level": 1,
		"equipment": [],
		"injuries": [],
		"status_effects": [],

		# BUG HUNT ADDITIONS:
		"morale": 10,
		"specialization": _roll_specialization(),
		"kills": 0
	}

	# Assign starting equipment (military loadout)
	soldier.equipment = ["Pulse Rifle", "Combat Armor", "Med Kit"]

	return soldier

## REUSES CORE: Battle setup structure
func _setup_bug_hunt_battle(mission: Dictionary) -> Dictionary:
	# Core battle structure is ~90% identical
	var battle_data := {
		# CORE BATTLE FIELDS:
		"mission": mission,
		"deployment_conditions": {},
		"battlefield_size": "24x24",
		"terrain": [],
		"objectives": mission.objectives,

		# REUSE CORE ENEMY SYSTEM:
		# Bug enemies use same stat structure as core enemies
		"enemies": _generate_bug_enemies(mission),

		# REUSE CORE COMBAT SYSTEM:
		# All combat calculations identical to core
		"turn_number": 1,
		"combat_log": [],

		# BUG HUNT ADDITIONS:
		"extraction_zone": _place_extraction_zone(),
		"motion_tracker_blips": [],
		"panic_events": []
	}

	return battle_data

# ============================================================================
# BUG HUNT-SPECIFIC METHODS
# ============================================================================

func _load_bug_hunt_systems() -> void:
	# Load Bug Hunt-specific subsystems
	panic_system = PanicSystem.new()
	add_child(panic_system)

	motion_tracker_system = MotionTrackerSystem.new()
	add_child(motion_tracker_system)

	infestation_system = InfestationSystem.new()
	add_child(infestation_system)

	military_hierarchy_system = MilitaryHierarchySystem.new()
	add_child(military_hierarchy_system)

func _initialize_core_campaign_reference() -> void:
	# Get reference to core campaign for code reuse
	if has_node("/root/CampaignManager"):
		core_campaign = get_node("/root/CampaignManager")

func _get_available_missions() -> Array:
	# Load from Bug Hunt mission data
	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		return []

	var missions_data = expansion_manager.load_expansion_data("bug_hunt", "bug_hunt_missions.json")
	if missions_data and missions_data.has("missions"):
		return missions_data.missions

	return []

func _roll_intel_gathering() -> Dictionary:
	# Roll for tactical intel about upcoming mission
	var roll := randi() % 6 + 1

	match roll:
		1, 2:
			return {"type": "none", "description": "No intel available"}
		3, 4:
			return {"type": "enemy_count", "description": "Estimated %d bugs" % (randi() % 6 + 3)}
		5:
			return {"type": "enemy_types", "description": "Intel shows Worker and Soldier bugs"}
		6:
			return {"type": "weak_point", "description": "Discovered bug weak point: +1 to hit this mission"}

	return {}

func _generate_bug_enemies(mission: Dictionary) -> Array:
	# Use infestation level to determine deployment points
	var base_points := mission.get("deployment_points", 10)
	var infestation_modifier := (campaign_data.infestation_level - 1) * 2
	var total_points := base_points + infestation_modifier

	# Generate bugs using deployment system
	# REUSES CORE: Enemy generation logic is identical
	var bugs := []
	var points_spent := 0

	while points_spent < total_points:
		var bug := _roll_random_bug()
		var bug_cost := bug.get("deployment_points", 1)

		if points_spent + bug_cost <= total_points:
			bugs.append(bug)
			points_spent += bug_cost
		else:
			break

	return bugs

func _roll_random_bug() -> Dictionary:
	# Load bug enemies data
	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		return {}

	var bug_data = expansion_manager.load_expansion_data("bug_hunt", "bug_enemies.json")
	if not bug_data or not bug_data.has("bug_enemies"):
		return {}

	var bugs: Array = bug_data.bug_enemies
	return bugs[randi() % bugs.size()].duplicate(true)

func _place_extraction_zone() -> Dictionary:
	# Random extraction point on battlefield edge
	var edge := randi() % 4 # 0=north, 1=east, 2=south, 3=west
	return {
		"edge": edge,
		"position": Vector2(randi() % 24, 0 if edge == 0 else 24)
	}

func _process_casualties(battle_result: Dictionary) -> Array:
	# REUSES CORE: Injury system is identical
	var casualties := []

	if battle_result.has("soldier_injuries"):
		for injury_data in battle_result.soldier_injuries:
			# Use core injury resolution
			casualties.append(injury_data)

	return casualties

func _award_experience(battle_result: Dictionary) -> void:
	# REUSES CORE: XP system is identical
	var xp_earned := battle_result.get("xp", 1)

	for soldier in campaign_data.squad:
		soldier.xp += xp_earned
		# Check for level up (core system)
		_check_level_up(soldier)

func _check_level_up(soldier: Dictionary) -> void:
	# REUSES CORE: Level progression system
	var xp_needed := soldier.level * 5
	if soldier.xp >= xp_needed:
		soldier.level += 1
		soldier.xp -= xp_needed
		print("BugHuntCampaignSystem: %s promoted to level %d!" % [soldier.name, soldier.level])

func _calculate_requisition_earned(battle_result: Dictionary) -> int:
	var base_rp := 1

	# Bonus for objectives completed
	if battle_result.get("objectives_completed", 0) > 0:
		base_rp += 1

	# Bonus for no casualties
	if battle_result.get("casualties", 0) == 0:
		base_rp += 1

	# Bonus for bugs killed
	var bugs_killed := battle_result.get("enemies_defeated", 0)
	base_rp += int(bugs_killed / 3)

	return base_rp

func _update_infestation_level(battle_result: Dictionary) -> void:
	var old_level := campaign_data.infestation_level

	# Infestation increases over time
	if campaign_data.missions_completed % 3 == 0:
		campaign_data.infestation_level = mini(campaign_data.infestation_level + 1, 5)

	# Can decrease if hive objectives completed
	if battle_result.get("hive_cleansed", false):
		campaign_data.infestation_level = maxi(campaign_data.infestation_level - 1, 1)

	if campaign_data.infestation_level != old_level:
		infestation_level_changed.emit(old_level, campaign_data.infestation_level)

func _update_squad_morale(battle_result: Dictionary, casualties_count: int) -> void:
	var old_morale := campaign_data.squad_morale

	# Victory increases morale
	if battle_result.get("victory", false):
		campaign_data.squad_morale = mini(campaign_data.squad_morale + 10, 100)

	# Casualties decrease morale
	campaign_data.squad_morale -= casualties_count * 5

	# Objectives failed decrease morale
	if not battle_result.get("victory", false):
		campaign_data.squad_morale -= 15

	campaign_data.squad_morale = maxi(campaign_data.squad_morale, 0)

	if campaign_data.squad_morale != old_morale:
		squad_morale_changed.emit(old_morale, campaign_data.squad_morale)

func _generate_after_action_report(battle_result: Dictionary) -> Dictionary:
	return {
		"mission_name": battle_result.get("mission_name", "Unknown"),
		"result": "Victory" if battle_result.get("victory", false) else "Failure",
		"enemies_defeated": battle_result.get("enemies_defeated", 0),
		"casualties": battle_result.get("casualties", 0),
		"requisition_earned": battle_result.get("requisition_earned", 0),
		"morale_change": battle_result.get("morale_change", 0)
	}

func _process_medical_treatment() -> void:
	# REUSES CORE: Injury recovery system
	for soldier in campaign_data.squad:
		if soldier.has("injuries") and soldier.injuries.size() > 0:
			# Roll for recovery (core system)
			for i in range(soldier.injuries.size() - 1, -1, -1):
				var roll := randi() % 6 + 1
				if roll >= 5:
					soldier.injuries.remove_at(i)
					print("BugHuntCampaignSystem: %s recovered from injury" % soldier.name)

func _change_phase(new_phase: CampaignPhase) -> void:
	var old_phase := CampaignPhase.keys()[current_phase]
	current_phase = new_phase
	var new_phase_name := CampaignPhase.keys()[new_phase]

	print("BugHuntCampaignSystem: Phase change: %s → %s" % [old_phase, new_phase_name])
	phase_changed.emit(old_phase, new_phase_name)

func _generate_campaign_id() -> String:
	return "bughunt_%d" % Time.get_ticks_msec()

func _generate_soldier_name() -> String:
	var first_names := ["Johnson", "Smith", "Garcia", "Martinez", "Rodriguez", "Lee", "Anderson", "Taylor"]
	var rank_prefix := ""
	return "%s%s" % [rank_prefix, first_names[randi() % first_names.size()]]

func _roll_specialization() -> String:
	var specializations := ["Standard", "Heavy Weapons", "CQB", "Reconnaissance", "Support"]
	return specializations[randi() % specializations.size()]
