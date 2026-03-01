extends Resource

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal enemy_deployment_generated(positions: Array)
signal deployment_validated(success: bool)

func get_deployment_type(ai_behavior: GameEnums.AIBehavior) -> GameEnums.DeploymentType:
	var roll := randi() % 100 + 1
	
	match ai_behavior:
		GameEnums.AIBehavior.AGGRESSIVE:
			if roll <= 30: return GameEnums.DeploymentType.STANDARD
			elif roll <= 50: return GameEnums.DeploymentType.AMBUSH
			elif roll <= 60: return GameEnums.DeploymentType.BOLSTERED_LINE
			elif roll <= 80: return GameEnums.DeploymentType.INFILTRATION
			elif roll <= 90: return GameEnums.DeploymentType.OFFENSIVE
			else: return GameEnums.DeploymentType.CONCEALED
		GameEnums.AIBehavior.CAUTIOUS:
			if roll <= 30: return GameEnums.DeploymentType.LINE
			elif roll <= 50: return GameEnums.DeploymentType.DEFENSIVE
			elif roll <= 70: return GameEnums.DeploymentType.BOLSTERED_LINE
			elif roll <= 90: return GameEnums.DeploymentType.REINFORCEMENT
			else: return GameEnums.DeploymentType.CONCEALED
		_:
			return GameEnums.DeploymentType.STANDARD

func generate_deployment_positions(battle_map: Node, deployment_type: GameEnums.DeploymentType) -> Array:
	match deployment_type:
		GameEnums.DeploymentType.STANDARD:
			return _generate_standard_deployment(battle_map)
		GameEnums.DeploymentType.LINE:
			return _generate_line_deployment(battle_map)
		GameEnums.DeploymentType.AMBUSH:
			return _generate_flank_deployment(battle_map)
		GameEnums.DeploymentType.SCATTERED:
			return _generate_scattered_deployment(battle_map)
		GameEnums.DeploymentType.DEFENSIVE:
			return _generate_defensive_deployment(battle_map)
		GameEnums.DeploymentType.INFILTRATION:
			return _generate_infiltration_deployment(battle_map)
		GameEnums.DeploymentType.REINFORCEMENT:
			return _generate_reinforced_deployment(battle_map)
		GameEnums.DeploymentType.BOLSTERED_LINE:
			return _generate_bolstered_line_deployment(battle_map)
		GameEnums.DeploymentType.CONCEALED:
			return _generate_concealed_deployment(battle_map)
		_:
			push_error("Invalid deployment type: %d" % deployment_type)
			return []

## Deployment generation — returns Array of instruction Dicts.
## Each Dict: {zone, description, count_hint, special_rules}
## Core Rules: standard enemy edge is the opposite table edge.

func _generate_standard_deployment(
	_battle_map: Node
) -> Array:
	## Core Rules default: within 6" of opposite table edge
	return [{
		"zone": "opposite_edge",
		"depth_inches": 6,
		"description": "Deploy all enemies within 6\" "
			+ "of the opposite table edge.",
		"special_rules": []
	}]

func _generate_line_deployment(
	_battle_map: Node
) -> Array:
	## Line: spread evenly along the opposite edge
	return [{
		"zone": "opposite_edge",
		"depth_inches": 2,
		"description": "Deploy enemies in a line along "
			+ "the opposite table edge, spaced evenly.",
		"special_rules": ["even_spacing"]
	}]

func _generate_flank_deployment(
	_battle_map: Node
) -> Array:
	## Ambush/Flank: split between opposite and side edges
	return [
		{
			"zone": "opposite_edge",
			"depth_inches": 6,
			"description": "Deploy half the enemies within "
				+ "6\" of the opposite table edge.",
			"count_hint": "half",
			"special_rules": []
		},
		{
			"zone": "random_side_edge",
			"depth_inches": 6,
			"description": "Deploy remaining enemies within "
				+ "6\" of a random side table edge.",
			"count_hint": "remaining",
			"special_rules": ["flanking"]
		}
	]

func _generate_scattered_deployment(
	_battle_map: Node
) -> Array:
	## Scattered: random positions across the battlefield
	return [{
		"zone": "battlefield_wide",
		"depth_inches": 0,
		"description": "Deploy enemies at random points "
			+ "across the battlefield (at least 12\" from "
			+ "crew deployment edge).",
		"special_rules": [
			"random_placement",
			"min_distance_from_crew_12"
		]
	}]

func _generate_defensive_deployment(
	_battle_map: Node
) -> Array:
	## Defensive: clustered around the objective
	return [{
		"zone": "around_objective",
		"depth_inches": 8,
		"description": "Deploy enemies within 8\" of the "
			+ "primary objective marker.",
		"special_rules": ["prefer_cover"]
	}]

func _generate_infiltration_deployment(
	_battle_map: Node
) -> Array:
	## Infiltration: deploy within 12" of any edge
	return [{
		"zone": "any_edge",
		"depth_inches": 12,
		"description": "Deploy enemies within 12\" of any "
			+ "table edge. Place in or adjacent to cover "
			+ "where possible.",
		"special_rules": ["any_edge", "prefer_cover"]
	}]

func _generate_reinforced_deployment(
	_battle_map: Node
) -> Array:
	## Reinforcement: half start on table, rest arrive later
	return [
		{
			"zone": "opposite_edge",
			"depth_inches": 6,
			"description": "Deploy half the enemies within "
				+ "6\" of the opposite table edge.",
			"count_hint": "half",
			"special_rules": []
		},
		{
			"zone": "off_table",
			"depth_inches": 0,
			"description": "Remaining enemies arrive as "
				+ "reinforcements. At end of each round "
				+ "roll 1D6: arrive on round number or "
				+ "less, at opposite edge.",
			"count_hint": "remaining",
			"special_rules": ["reinforcement_roll"]
		}
	]

func _generate_bolstered_line_deployment(
	_battle_map: Node
) -> Array:
	## Bolstered line: line formation with support behind
	return [
		{
			"zone": "opposite_edge",
			"depth_inches": 2,
			"description": "Deploy main force in a line "
				+ "along the opposite edge.",
			"count_hint": "two_thirds",
			"special_rules": ["even_spacing"]
		},
		{
			"zone": "opposite_edge",
			"depth_inches": 8,
			"description": "Deploy remaining enemies 6-8\" "
				+ "behind the main line as support.",
			"count_hint": "remaining",
			"special_rules": ["behind_main_line"]
		}
	]

func _generate_concealed_deployment(
	_battle_map: Node
) -> Array:
	## Concealed: deploy only in/behind cover
	return [{
		"zone": "opposite_half",
		"depth_inches": 0,
		"description": "Deploy enemies in the opposite "
			+ "half of the table. Each enemy must be "
			+ "placed in or directly behind cover.",
		"special_rules": ["must_be_in_cover"]
	}]
