class_name TacticsEnemyGenerator
extends RefCounted

## TacticsEnemyGenerator - Generates AI opposition forces for solo/GM play.
## Scales enemy force based on player army points and scenario type.
## Uses species books for enemy profiles.
## Source: Five Parsecs: Tactics rulebook pp.90-100

enum ForceScale {
	PATROL,         # ~50% of player points
	EVEN,           # ~100% of player points
	SUPERIOR,       # ~150% of player points
	OVERWHELMING,   # ~200% of player points
}

const SCALE_MULTIPLIERS := {
	ForceScale.PATROL: 0.5,
	ForceScale.EVEN: 1.0,
	ForceScale.SUPERIOR: 1.5,
	ForceScale.OVERWHELMING: 2.0,
}


## Generate an enemy force from a species book.
## Returns {species_id, units: Array[Dict], total_points, force_scale}
static func generate_enemy_force(
		species_id: String,
		player_points: int,
		scale: ForceScale = ForceScale.EVEN) -> Dictionary:
	var book: TacticsSpeciesBook = TacticsSpeciesBookLoader.load_species_book(
		species_id)
	if not book:
		push_warning(
			"[TacticsEnemyGenerator] Could not load species: %s"
			% species_id)
		return {"species_id": species_id, "units": [],
			"total_points": 0, "force_scale": scale}

	var target_points: int = int(
		player_points * SCALE_MULTIPLIERS.get(scale, 1.0))
	var units: Array = []
	var spent: int = 0

	# Always add at least one leader
	var leaders: Array = book.get_character_profiles()
	if not leaders.is_empty():
		var leader: TacticsUnitProfile = leaders[0]
		units.append(_unit_to_dict(leader))
		spent += leader.points_cost

	# Fill with troops until we hit target
	var troops: Array = book.get_troop_profiles()
	var troop_idx: int = 0
	while spent < target_points and not troops.is_empty():
		var troop: TacticsUnitProfile = troops[
			troop_idx % troops.size()]
		if spent + troop.points_cost > target_points + 20:
			break  # Don't overshoot by too much
		units.append(_unit_to_dict(troop))
		spent += troop.points_cost
		troop_idx += 1

	# Add supports if budget allows
	var supports: Array = book.get_support_profiles()
	for support in supports:
		if support is TacticsUnitProfile:
			if spent + support.points_cost <= target_points:
				units.append(_unit_to_dict(support))
				spent += support.points_cost

	return {
		"species_id": species_id,
		"species_name": book.get_species_name(),
		"units": units,
		"total_points": spent,
		"target_points": target_points,
		"force_scale": scale,
	}


## Generate a random enemy species appropriate for the scenario.
## Returns a species_id string.
static func pick_random_enemy_species(
		exclude_species: String = "") -> String:
	var books: Dictionary = TacticsSpeciesBookLoader.load_all_species_books()
	var candidates: Array = []
	for sid in books:
		if sid != exclude_species and sid != "creatures":
			candidates.append(sid)
	if candidates.is_empty():
		return "human_colonists"
	return candidates[randi() % candidates.size()]


## Roll force scale based on scenario difficulty.
## D6: 1=Patrol, 2-3=Even, 4-5=Superior, 6=Overwhelming
static func roll_force_scale() -> ForceScale:
	var roll: int = randi_range(1, 6)
	if roll <= 1:
		return ForceScale.PATROL
	elif roll <= 3:
		return ForceScale.EVEN
	elif roll <= 5:
		return ForceScale.SUPERIOR
	else:
		return ForceScale.OVERWHELMING


static func _unit_to_dict(profile: TacticsUnitProfile) -> Dictionary:
	return {
		"unit_id": profile.unit_id,
		"unit_name": profile.unit_name,
		"unit_type": profile.unit_type,
		"cost": profile.points_cost,
		"speed": profile.speed,
		"reactions": profile.reactions,
		"combat_skill": profile.combat_skill,
		"toughness": profile.toughness,
		"kill_points": profile.kill_points,
		"training": profile.training,
		"models": profile.base_models,
	}
