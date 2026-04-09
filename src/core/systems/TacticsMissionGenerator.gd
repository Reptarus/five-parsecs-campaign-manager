class_name TacticsMissionGenerator
extends RefCounted

## TacticsMissionGenerator - Generates battle scenarios for Tactics.
## 4 scenario types, battlefield conditions, secondary objectives.
## Source: Five Parsecs: Tactics rulebook pp.109-154

enum ScenarioType {
	SKIRMISH,           # Quick engagement, 2-3 squads per side
	BATTLE,             # Standard engagement, full platoon
	GRAND_BATTLE,       # Multiple platoons, vehicles, heavy weapons
	EVOLVING_OBJECTIVE, # Objectives change during battle
}

enum DeploymentType {
	STANDARD,       # Opposing table edges
	FLANKING,       # One side deploys on two edges
	MEETING,        # Both sides deploy from center outward
	AMBUSH,         # Defender in center, attacker from edges
	SCATTERED,      # Random deployment zones
}

const SCENARIO_NAMES := {
	ScenarioType.SKIRMISH: "Skirmish",
	ScenarioType.BATTLE: "Battle",
	ScenarioType.GRAND_BATTLE: "Grand Battle",
	ScenarioType.EVOLVING_OBJECTIVE: "Evolving Objective",
}

const DEPLOYMENT_NAMES := {
	DeploymentType.STANDARD: "Standard (Opposing Edges)",
	DeploymentType.FLANKING: "Flanking (Two Edges)",
	DeploymentType.MEETING: "Meeting Engagement",
	DeploymentType.AMBUSH: "Ambush",
	DeploymentType.SCATTERED: "Scattered Deployment",
}

## Battlefield conditions that modify the battle
const CONDITIONS := [
	{"id": "clear", "name": "Clear", "effect": "No modifiers"},
	{"id": "rain", "name": "Heavy Rain",
		"effect": "-1 to ranged attacks beyond 12\""},
	{"id": "dust_storm", "name": "Dust Storm",
		"effect": "Visibility limited to 18\""},
	{"id": "night", "name": "Night Operations",
		"effect": "Visibility limited to 12\", +1 to Observation"},
	{"id": "fog", "name": "Dense Fog",
		"effect": "Visibility limited to 9\""},
	{"id": "urban", "name": "Urban Terrain",
		"effect": "Extra cover, CQB rules apply"},
	{"id": "hazardous", "name": "Hazardous Environment",
		"effect": "Chemical hazards, Enviro-suits recommended"},
	{"id": "electronic", "name": "Electronic Interference",
		"effect": "-1 to communications tests"},
]

## Secondary objectives
const SECONDARY_OBJECTIVES := [
	{"id": "hold_terrain", "name": "Hold Terrain Feature",
		"description": "Control a terrain piece at battle end",
		"cp_bonus": 1},
	{"id": "capture_leader", "name": "Capture Enemy Leader",
		"description": "Eliminate the enemy commander",
		"cp_bonus": 1},
	{"id": "preserve_unit", "name": "Preserve Key Unit",
		"description": "Keep a specific unit alive",
		"cp_bonus": 1},
	{"id": "extract", "name": "Extraction",
		"description": "Move a unit to the opposite table edge",
		"cp_bonus": 1},
	{"id": "intel", "name": "Gather Intelligence",
		"description": "Move a model into contact with 3 objectives",
		"cp_bonus": 1},
	{"id": "demolition", "name": "Demolition",
		"description": "Destroy an enemy fortification",
		"cp_bonus": 1},
]


## Generate a complete battle scenario.
## Returns a scenario dictionary with all battle parameters.
static func generate_scenario(
		points_limit: int = 500,
		force_scenario_type: int = -1) -> Dictionary:
	# Determine scenario type
	var scenario_type: ScenarioType
	if force_scenario_type >= 0:
		scenario_type = force_scenario_type as ScenarioType
	else:
		scenario_type = _roll_scenario_type(points_limit)

	# Roll deployment
	var deployment: DeploymentType = _roll_deployment()

	# Roll battlefield condition
	var condition: Dictionary = CONDITIONS[
		randi() % CONDITIONS.size()]

	# Roll secondary objective (50% chance)
	var secondary: Dictionary = {}
	if randi() % 2 == 0:
		secondary = SECONDARY_OBJECTIVES[
			randi() % SECONDARY_OBJECTIVES.size()]

	# Generate scenario seed (D100 flavor text)
	var seed_roll: int = randi_range(1, 100)

	return {
		"scenario_type": scenario_type,
		"scenario_name": SCENARIO_NAMES.get(
			scenario_type, "Unknown"),
		"deployment_type": deployment,
		"deployment_name": DEPLOYMENT_NAMES.get(
			deployment, "Standard"),
		"condition": condition,
		"secondary_objective": secondary,
		"seed_roll": seed_roll,
		"seed_description": _get_scenario_seed(seed_roll),
		"points_limit": points_limit,
		"recommended_squads": _get_squad_count(scenario_type),
	}


## Roll scenario type based on points limit.
## Small games → Skirmish bias, large → Grand Battle bias.
static func _roll_scenario_type(points: int) -> ScenarioType:
	var roll: int = randi_range(1, 6)
	if points <= 500:
		if roll <= 3:
			return ScenarioType.SKIRMISH
		elif roll <= 5:
			return ScenarioType.BATTLE
		else:
			return ScenarioType.EVOLVING_OBJECTIVE
	elif points <= 750:
		if roll <= 2:
			return ScenarioType.SKIRMISH
		elif roll <= 4:
			return ScenarioType.BATTLE
		elif roll <= 5:
			return ScenarioType.GRAND_BATTLE
		else:
			return ScenarioType.EVOLVING_OBJECTIVE
	else:  # 1000+
		if roll <= 1:
			return ScenarioType.SKIRMISH
		elif roll <= 3:
			return ScenarioType.BATTLE
		elif roll <= 5:
			return ScenarioType.GRAND_BATTLE
		else:
			return ScenarioType.EVOLVING_OBJECTIVE


static func _roll_deployment() -> DeploymentType:
	var roll: int = randi_range(1, 6)
	if roll <= 2:
		return DeploymentType.STANDARD
	elif roll <= 3:
		return DeploymentType.FLANKING
	elif roll <= 4:
		return DeploymentType.MEETING
	elif roll <= 5:
		return DeploymentType.AMBUSH
	else:
		return DeploymentType.SCATTERED


static func _get_squad_count(scenario_type: ScenarioType) -> String:
	match scenario_type:
		ScenarioType.SKIRMISH:
			return "2-3 squads per side"
		ScenarioType.BATTLE:
			return "Full platoon"
		ScenarioType.GRAND_BATTLE:
			return "Multiple platoons + vehicles"
		ScenarioType.EVOLVING_OBJECTIVE:
			return "Variable — starts small, escalates"
		_:
			return "Standard force"


static func _get_scenario_seed(roll: int) -> String:
	## D100 scenario seed — brief tactical situation description.
	## These are generic seeds; full flavor text loaded from JSON in Phase 7.
	if roll <= 10:
		return "Patrol encounters hostile forces in neutral zone"
	elif roll <= 20:
		return "Defensive position under assault"
	elif roll <= 30:
		return "Advance through contested territory"
	elif roll <= 40:
		return "Supply convoy ambush"
	elif roll <= 50:
		return "Rescue operation behind enemy lines"
	elif roll <= 60:
		return "Meeting engagement at crossroads"
	elif roll <= 70:
		return "Assault on fortified position"
	elif roll <= 80:
		return "Withdrawal under pressure"
	elif roll <= 90:
		return "Reconnaissance in force"
	else:
		return "Last stand — hold at all costs"
