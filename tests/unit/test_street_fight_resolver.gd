extends GdUnitTestSuite
## Tests for StreetFightResolver + the 9" visibility cap (Compendium pp.125-138).
##
## Coverage:
##   1. The resolver emits the BattleResolver result shape and tags combat_mode
##      so it is a drop-in for the auto-resolve handoff + narrative wrap.
##   2. The visibility ceiling is honoured by BattleResolver._estimate_range and
##      is OPT-IN (no ceiling by default — regression guard against an always-on
##      cap that would silently shorten every battle in the game).
##   3. BattleResolverRouter routes mission_type "street_fight" (the exact string
##      WorldPhase sets) to this resolver, and does NOT mis-tag other missions.

const StreetFightResolver := preload("res://src/core/battle/StreetFightResolver.gd")
const BattleResolver := preload("res://src/core/battle/BattleResolver.gd")
const BattleResolverRouter := preload("res://src/core/battle/BattleResolverRouter.gd")

func _d6() -> Callable:
	return func() -> int: return randi_range(1, 6)

func _crew() -> Array:
	return [{
		"character_name": "Bruiser", "is_captain": true,
		"combat_skill": 1, "toughness": 4, "reactions": 2, "speed": 5,
		"weapons": [{"name": "Rifle", "range": 24, "shots": 1, "damage": 1, "traits": []}],
	}]

func _enemies(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"name": "Thug %d" % i,
			"combat_skill": 0, "toughness": 3, "speed": 4, "reactions": 1,
			"panic": "1-2",
			"weapons": [{"name": "Pistol", "range": 12, "shots": 1, "damage": 1, "traits": []}],
			"special_rules": [],
		})
	return out

# ============================================================================
# 1. Drop-in result contract
# ============================================================================

func test_resolve_returns_battleresolver_shape_tagged_street_fight() -> void:
	var result: Dictionary = StreetFightResolver.resolve_battle(
		_crew(), _enemies(3), {}, {"condition_id": "standard"}, _d6())
	assert_dict(result).contains_keys([
		"success", "rounds_fought", "crew_casualties", "enemies_defeated", "held_field"])
	assert_str(str(result["combat_mode"])).is_equal("street_fight")

func test_resolve_does_not_mutate_callers_battlefield_data() -> void:
	# The resolver copies battlefield_data before injecting the visibility cap, so
	# a caller reusing the same dict for a later (non-street-fight) battle is safe.
	var field := {}
	StreetFightResolver.resolve_battle(
		_crew(), _enemies(2), field, {"condition_id": "standard"}, _d6())
	assert_bool(field.has("max_visibility_inches")).is_false()

# ============================================================================
# 2. Visibility ceiling (Compendium pp.125-138) — opt-in
# ============================================================================

func test_visibility_cap_limits_estimated_range_to_9() -> void:
	# A 24" rifle under the 9" ceiling must never estimate an engagement beyond 9".
	var attacker := {"weapon": {"range": 24}}
	for i in range(200):
		var r: float = BattleResolver._estimate_range(attacker, {}, {"max_visibility_inches": 9.0})
		assert_float(r).is_less_equal(9.0)

func test_no_cap_allows_full_weapon_range() -> void:
	# Regression guard: without the ceiling the cap is OFF — a 24" weapon must be
	# able to engage beyond 9" (the cap is mission-specific, not global).
	var attacker := {"weapon": {"range": 24}}
	var saw_beyond_9 := false
	for i in range(200):
		if BattleResolver._estimate_range(attacker, {}, {}) > 9.0:
			saw_beyond_9 = true
			break
	assert_bool(saw_beyond_9).is_true()

# ============================================================================
# 3. Router wiring (mission_type strings from WorldPhase lines 915/920/926)
# ============================================================================

func test_router_routes_street_fight_mission() -> void:
	# null dlc_manager: the mission only carries "street_fight" when the DLC built
	# the offer, so the mission-resolver lane needs no DLC gate.
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(3), {}, {"condition_id": "standard"},
		_d6(), null, "", "street_fight")
	assert_str(str(result["combat_mode"])).is_equal("street_fight")

func test_router_does_not_tag_non_street_fight_mission() -> void:
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(3), {}, {"condition_id": "standard"},
		_d6(), null, "", "patrol")
	assert_str(str(result.get("combat_mode", ""))).is_not_equal("street_fight")

func test_router_does_not_route_street_fight_in_other_modes() -> void:
	# Cross-mode guard: a non-standard battle_mode never takes the 5PFH-only
	# mission-resolver lane, even if the type string somehow contained it.
	var result: Dictionary = BattleResolverRouter.resolve(
		_crew(), _enemies(3), {}, {"condition_id": "standard"},
		_d6(), null, "planetfall", "street_fight")
	assert_str(str(result.get("combat_mode", ""))).is_not_equal("street_fight")
