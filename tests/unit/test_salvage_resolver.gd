extends GdUnitTestSuite
## Tests for SalvageResolver (Compendium pp.139-148).
##
## Canonical model under test:
##   • A salvage job is a single scenario: investigate 4 POIs + extract, with a
##     Tension-driven Contact loop and per-POI canonical effects (23-type D100).
##   • Result is a drop-in for the auto-resolve handoff (BattleResolver shape),
##     tagged combat_mode "salvage", carrying salvage_units / credits_found /
##     quest_rumors / story_points_earned / pois_investigated for the narrative
##     wrap + post-battle pipeline.
##   • Contact / combat-spawn POIs add CLONES of the deployed force (canonical
##     counts, abstracted type) — never fabricated stat blocks.

const SalvageResolver := preload("res://src/core/battle/SalvageResolver.gd")
const BattleResolverRouter := preload("res://src/core/battle/BattleResolverRouter.gd")

func _d6() -> Callable:
	return func() -> int: return randi_range(1, 6)

func _crew(n: int = 4) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"character_name": "Scrapper %d" % i, "is_captain": i == 0,
			"combat_skill": 1, "toughness": 4, "reactions": 2, "speed": 5, "savvy": 1,
			"weapons": [{"name": "Carbine", "range": 18, "shots": 1, "damage": 1, "traits": []}],
		})
	return out

func _enemies(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"name": "Looter %d" % i,
			"combat_skill": 0, "toughness": 3, "speed": 4, "reactions": 1,
			"panic": "1-2",
			"weapons": [{"name": "Scrap Pistol", "range": 12, "shots": 1, "damage": 1, "traits": []}],
			"special_rules": [],
		})
	return out

# ============================================================================
# 1. Drop-in contract + salvage-specific additive fields
# ============================================================================

func test_resolve_returns_battleresolver_shape_tagged_salvage() -> void:
	var result: Dictionary = SalvageResolver.resolve_battle(
		_crew(), _enemies(2), {}, {"condition_id": "standard"}, _d6())
	assert_dict(result).contains_keys([
		"success", "rounds_fought", "crew_casualties", "enemies_defeated",
		"held_field", "loot_opportunities", "consumed_items",
		"crew_units_final", "enemy_units_final",
		"combat_mode", "salvage_units", "credits_found", "quest_rumors",
		"story_points_earned", "pois_investigated", "tension_final"])
	assert_str(str(result["combat_mode"])).is_equal("salvage")

func test_salvage_reward_counts_are_non_negative_ints() -> void:
	var result: Dictionary = SalvageResolver.resolve_battle(
		_crew(), _enemies(2), {}, {"condition_id": "standard"}, _d6())
	for key in ["salvage_units", "credits_found", "quest_rumors", "story_points_earned",
			"pois_investigated", "tension_final", "crew_casualties", "enemies_defeated"]:
		assert_int(typeof(result[key])).is_equal(TYPE_INT)
		assert_int(int(result[key])).is_greater_equal(0)

func test_terminates_within_safety_cap() -> void:
	var result: Dictionary = SalvageResolver.resolve_battle(
		_crew(), _enemies(2), {}, {"condition_id": "standard"}, _d6())
	assert_int(result["rounds_fought"]).is_between(1, 100)

# ============================================================================
# 2. POI investigation (Compendium p.141 — 4 markers)
# ============================================================================

func test_investigates_up_to_four_pois() -> void:
	# A salvage job investigates at most 4 POIs (one per quarter).
	var result: Dictionary = SalvageResolver.resolve_battle(
		_crew(), _enemies(2), {}, {"condition_id": "standard"}, _d6())
	assert_int(result["pois_investigated"]).is_between(0, 4)

func test_clean_exploration_reaches_all_four_pois() -> void:
	# No initial enemies + no clone template → no combat can spawn (empty template),
	# so exploration runs unimpeded and all four POIs are investigated, crew intact.
	var result: Dictionary = SalvageResolver.resolve_battle(
		_crew(), [], {}, {"condition_id": "standard"}, _d6())
	assert_int(result["pois_investigated"]).is_equal(4)
	assert_int((result["crew_units_final"] as Array).size()).is_equal(4)

func test_tension_stays_within_bounds() -> void:
	var result: Dictionary = SalvageResolver.resolve_battle(
		_crew(), _enemies(2), {}, {"condition_id": "standard"}, _d6())
	assert_int(result["tension_final"]).is_between(0, 12)

# ============================================================================
# 3. Router wiring (mission_type "salvage" from WorldPhase line 926)
# ============================================================================

func test_router_routes_salvage_mission() -> void:
	# Salvage previously fell back to Standard (Compendium p.116, No-Minis); the
	# mission lane now claims it ahead of that fallback.
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(2), {}, {"condition_id": "standard"},
		_d6(), null, "", "salvage")
	assert_str(str(result["combat_mode"])).is_equal("salvage")

func test_router_does_not_route_salvage_in_other_modes() -> void:
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(2), {}, {"condition_id": "standard"},
		_d6(), null, "tactics", "salvage")
	assert_str(str(result.get("combat_mode", ""))).is_not_equal("salvage")
