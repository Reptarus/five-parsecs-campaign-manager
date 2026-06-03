extends GdUnitTestSuite
## Tests for StealthResolver (Compendium pp.117-124).
##
## Canonical stance under test:
##   • Stealth DETECTION is positional (2D6 spotting vs measured distance) and is
##     NOT auto-resolved — no fabricated probability appears in the result.
##   • The post-alarm REINFORCEMENTS rule (Compendium p.120: 2D6/round, each 6 = 1
##     basic enemy) IS modelled, in an isolated loop that reuses BattleResolver's
##     static helpers (so Standard/other battles are untouched).
##   • Result is a drop-in for the auto-resolve handoff (BattleResolver shape) and
##     is tagged combat_mode "stealth" for the narrative wrap, with the canonical
##     objective + reinforcements_arrived carried alongside.

const StealthResolver := preload("res://src/core/battle/StealthResolver.gd")
const BattleResolverRouter := preload("res://src/core/battle/BattleResolverRouter.gd")

func _d6() -> Callable:
	return func() -> int: return randi_range(1, 6)

func _all_sixes() -> Callable:
	return func() -> int: return 6

func _crew(n: int = 4) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"character_name": "Op %d" % i, "is_captain": i == 0,
			"combat_skill": 1, "toughness": 4, "reactions": 2, "speed": 5,
			"weapons": [{"name": "Carbine", "range": 18, "shots": 1, "damage": 1, "traits": []}],
		})
	return out

func _enemies(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"name": "Sentry %d" % i,
			"combat_skill": 0, "toughness": 3, "speed": 4, "reactions": 1,
			"panic": "1-2",
			"weapons": [{"name": "Pistol", "range": 12, "shots": 1, "damage": 1, "traits": []}],
			"special_rules": [],
		})
	return out

# ============================================================================
# 1. Drop-in contract + stealth-specific additive fields
# ============================================================================

func test_resolve_returns_battleresolver_shape_tagged_stealth() -> void:
	var result: Dictionary = StealthResolver.resolve_battle(
		_crew(), _enemies(4), {}, {"condition_id": "standard"}, _d6())
	assert_dict(result).contains_keys([
		"success", "rounds_fought", "crew_casualties", "enemies_defeated",
		"held_field", "loot_opportunities", "battlefield_finds", "consumed_items",
		"crew_units_final", "enemy_units_final",
		"combat_mode", "stealth_objective", "reinforcements_arrived"])
	assert_str(str(result["combat_mode"])).is_equal("stealth")

func test_casualty_and_reinforcement_counts_are_ints() -> void:
	# PostBattleSequence iterates `for i in range(crew_casualties)` — these MUST be
	# ints or the injury UI silently breaks. reinforcements_arrived feeds the
	# narrative beat count.
	var result: Dictionary = StealthResolver.resolve_battle(
		_crew(), _enemies(4), {}, {"condition_id": "standard"}, _d6())
	assert_int(typeof(result["crew_casualties"])).is_equal(TYPE_INT)
	assert_int(typeof(result["enemies_defeated"])).is_equal(TYPE_INT)
	assert_int(typeof(result["reinforcements_arrived"])).is_equal(TYPE_INT)

func test_terminates_within_safety_cap() -> void:
	var result: Dictionary = StealthResolver.resolve_battle(
		_crew(), _enemies(4), {}, {"condition_id": "standard"}, _d6())
	assert_int(result["rounds_fought"]).is_between(1, 100)

# ============================================================================
# 2. Reinforcements (Compendium p.120) — the one canonical auto-resolvable mechanic
# ============================================================================

func test_reinforcements_arrive_when_dice_show_sixes() -> void:
	# All-6 dice → round 1 spotting roll is two 6s → 2 reinforcements arrive before
	# the first round resolves, so at least 2 must be counted.
	var result: Dictionary = StealthResolver.resolve_battle(
		_crew(), _enemies(4), {}, {"condition_id": "standard"}, _all_sixes())
	assert_int(result["reinforcements_arrived"]).is_greater_equal(2)

func test_no_reinforcements_without_initial_enemies() -> void:
	# No enemy force → no reinforcement template → none can arrive, and the battle
	# resolves to an immediate success (degenerate input must not crash).
	var result: Dictionary = StealthResolver.resolve_battle(
		_crew(), [], {}, {"condition_id": "standard"}, _all_sixes())
	assert_int(result["reinforcements_arrived"]).is_equal(0)
	assert_bool(result["success"]).is_true()

func test_reinforcements_appended_not_reordered() -> void:
	# Reinforcements are APPENDED, so the original enemy indices are preserved
	# (the post-battle pipeline maps final state back by index). With sixes, the
	# final enemy array must be at least the initial size.
	var result: Dictionary = StealthResolver.resolve_battle(
		_crew(), _enemies(3), {}, {"condition_id": "standard"}, _all_sixes())
	assert_int((result["enemy_units_final"] as Array).size()).is_greater_equal(3)

# ============================================================================
# 3. Router wiring (mission_type "stealth" from WorldPhase line 915)
# ============================================================================

func test_router_routes_stealth_mission() -> void:
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(4), {}, {"condition_id": "standard"},
		_d6(), null, "", "stealth")
	assert_str(str(result["combat_mode"])).is_equal("stealth")

func test_router_does_not_route_stealth_in_other_modes() -> void:
	# Cross-mode guard: a non-standard battle_mode never takes the 5PFH mission lane.
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(4), {}, {"condition_id": "standard"},
		_d6(), null, "bug_hunt", "stealth")
	assert_str(str(result.get("combat_mode", ""))).is_not_equal("stealth")
