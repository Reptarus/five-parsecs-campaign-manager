extends GdUnitTestSuite
## Tests for NoMinisResolver — the No-Minis Combat auto-resolver (Compendium pp.66-73).
##
## Two layers of coverage:
##   1. Book-rule parity on the deterministic pieces (Bail Range parsing, the morale
##      Bail check, the Fearless exemption, melee-only detection).
##   2. Integration invariants on resolve_battle(): the result shape matches
##      BattleResolver (drop-in routing), unit arrays stay index-stable (BattlePhase
##      maps is_alive back to the deployed arrays by index), and battles terminate.

const NoMinisResolver := preload("res://src/core/battle/NoMinisResolver.gd")

# ============================================================================
# Helpers
# ============================================================================

func _ranged(weapon_name: String, rng: int, shots: int = 1) -> Dictionary:
	return {"name": weapon_name, "range": rng, "shots": shots, "damage": 1, "traits": []}

func _make_crew() -> Array:
	return [
		{
			"character_name": "Captain", "is_captain": true,
			"combat_skill": 1, "toughness": 4, "reactions": 2, "speed": 5,
			"weapons": [_ranged("Rifle", 24)],
		},
		{
			"character_name": "Gunner",
			"combat_skill": 1, "toughness": 3, "reactions": 1, "speed": 4,
			"weapons": [_ranged("Pistol", 12)],
		},
		{
			"character_name": "Scout",
			"combat_skill": 0, "toughness": 3, "reactions": 2, "speed": 6,
			"weapons": [_ranged("Carbine", 18)],
		},
		{
			"character_name": "Heavy",
			"combat_skill": 1, "toughness": 4, "reactions": 1, "speed": 4,
			"weapons": [_ranged("Auto Rifle", 24, 2)],
		},
	]

func _make_enemies(n: int, panic: String = "1-2") -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"name": "Raider %d" % i,
			"combat_skill": 0, "toughness": 3, "speed": 4, "reactions": 1,
			"panic": panic,
			"weapons": [_ranged("Scrap Rifle", 18)],
			"special_rules": [],
		})
	return out

func _d6_const(value: int) -> Callable:
	return func(): return value

# ============================================================================
# 1. Deterministic book-rule parity
# ============================================================================

func test_bail_range_max_parses_panic_strings() -> void:
	# Compendium p.72 / Core Rules p.114 — the "Panic" stat IS the Bail Range.
	assert_int(NoMinisResolver.bail_range_max({"panic": "1-2"})).is_equal(2)
	assert_int(NoMinisResolver.bail_range_max({"panic": "1-3"})).is_equal(3)
	assert_int(NoMinisResolver.bail_range_max({"panic": "1"})).is_equal(1)
	assert_int(NoMinisResolver.bail_range_max({"panic": "0"})).is_equal(0)  # fights to the death

func test_is_melee_only_detection() -> void:
	# A unit is melee-only only if it carries structured weapons and none are ranged.
	assert_bool(NoMinisResolver.is_melee_only(
		{"weapons": [{"name": "Ripper Sword", "range": 1}]})).is_true()
	assert_bool(NoMinisResolver.is_melee_only(
		{"weapons": [_ranged("Rifle", 24)]})).is_false()
	# No structured weapon dict → assumed ranged-capable (the common data shape).
	assert_bool(NoMinisResolver.is_melee_only({"weapons": "1 A"})).is_false()
	assert_bool(NoMinisResolver.is_melee_only({})).is_false()

func test_morale_bails_within_range() -> void:
	# 2 enemy casualties this round → roll 2 dice; both 1 ≤ Bail Range(1-2) → 2 Bail.
	var enemies := _make_enemies(4, "1-2")
	for e in enemies:
		e["is_alive"] = true
	var bailed: int = NoMinisResolver.resolve_enemy_morale(enemies, 2, _d6_const(1))
	assert_int(bailed).is_equal(2)
	# Bailed enemies are removed (is_alive=false) but flagged as NOT combat kills.
	var removed := 0
	for e in enemies:
		if not e.get("is_alive", true):
			removed += 1
			assert_bool(e.get("_bailed", false)).is_true()
	assert_int(removed).is_equal(2)

func test_morale_no_bail_when_roll_above_range() -> void:
	# Die of 6 is outside Bail Range 1-2 → nobody flees (Core Rules p.114 example).
	var enemies := _make_enemies(3, "1-2")
	for e in enemies:
		e["is_alive"] = true
	assert_int(NoMinisResolver.resolve_enemy_morale(enemies, 2, _d6_const(6))).is_equal(0)

func test_morale_skipped_when_no_casualties() -> void:
	# Morale is only tested if the enemy lost figures that round.
	var enemies := _make_enemies(3)
	for e in enemies:
		e["is_alive"] = true
	assert_int(NoMinisResolver.resolve_enemy_morale(enemies, 0, _d6_const(1))).is_equal(0)

func test_fearless_never_bails() -> void:
	# Fearless enemies never have Morale dice applied (Core Rules p.114).
	var enemies := _make_enemies(3, "1-2")
	for e in enemies:
		e["is_alive"] = true
		e["special_rules"] = ["Fearless: Never affected by Morale."]
	assert_int(NoMinisResolver.resolve_enemy_morale(enemies, 3, _d6_const(1))).is_equal(0)

# ============================================================================
# 2. resolve_battle() integration invariants
# ============================================================================

func test_resolve_battle_returns_battleresolver_compatible_shape() -> void:
	var result: Dictionary = NoMinisResolver.resolve_battle(
		_make_crew(), _make_enemies(6), {}, {"condition_id": "standard"}, _d6_const(6))
	assert_dict(result).contains_keys([
		"success", "rounds_fought", "crew_casualties", "enemies_defeated",
		"held_field", "loot_opportunities", "battlefield_finds", "consumed_items",
		"crew_units_final", "enemy_units_final", "combat_mode", "enemies_bailed",
	])
	assert_that(result["combat_mode"]).is_equal("no_minis")

func test_resolve_battle_emits_post_battle_consumption_contract() -> void:
	# The live post-battle pipeline reads these keys off the resolver dict and the
	# TYPES matter: PostBattleSequence does `for i in range(crew_casualties)` to build
	# injury-roll panels (Core Rules p.94), so crew_casualties MUST stay an int — an
	# array here would silently kill the injury UI. held_field (bool) gates Battlefield
	# Finds (p.121); success (bool) gates payment (p.120). This locks the contract that
	# makes No-Minis a true drop-in for BattleResolver in the auto-resolve handoff.
	var result: Dictionary = NoMinisResolver.resolve_battle(
		_make_crew(), _make_enemies(6), {}, {"condition_id": "standard"}, _d6_const(6))
	assert_int(typeof(result["crew_casualties"])).is_equal(TYPE_INT)
	assert_int(typeof(result["enemies_defeated"])).is_equal(TYPE_INT)
	assert_int(typeof(result["success"])).is_equal(TYPE_BOOL)
	assert_int(typeof(result["held_field"])).is_equal(TYPE_BOOL)

func test_resolve_battle_preserves_unit_order_and_count() -> void:
	# BattlePhase maps crew_units_final[i].is_alive back to crew_deployed[i] BY INDEX,
	# so the resolver must never reorder the backing arrays.
	var crew := _make_crew()
	var enemies := _make_enemies(6)
	var result: Dictionary = NoMinisResolver.resolve_battle(
		crew, enemies, {}, {"condition_id": "standard"}, _d6_const(6))
	assert_array(result["crew_units_final"]).has_size(crew.size())
	assert_array(result["enemy_units_final"]).has_size(enemies.size())
	assert_that(result["crew_units_final"][0]["character_name"]).is_equal("Captain")

func test_resolve_battle_terminates_within_safety_cap() -> void:
	var result: Dictionary = NoMinisResolver.resolve_battle(
		_make_crew(), _make_enemies(6), {}, {"condition_id": "standard"}, _d6_const(6))
	assert_int(result["rounds_fought"]).is_between(1, NoMinisResolver.SAFETY_MAX_ROUNDS)

func test_resolve_battle_produces_casualties_when_everyone_hits() -> void:
	# All-6 dice → relentless hits → at least one enemy is defeated in combat.
	var result: Dictionary = NoMinisResolver.resolve_battle(
		_make_crew(), _make_enemies(6), {}, {"condition_id": "standard"}, _d6_const(6))
	assert_int(result["enemies_defeated"]).is_greater_equal(1)

func test_resolve_battle_handles_empty_enemies() -> void:
	# Degenerate input must not crash and should resolve to an immediate success.
	var result: Dictionary = NoMinisResolver.resolve_battle(
		_make_crew(), [], {}, {"condition_id": "standard"}, _d6_const(6))
	assert_bool(result["success"]).is_true()
	assert_bool(result["held_field"]).is_true()

# ============================================================================
# 3. Companion panel (UI action drift fix)
# ============================================================================

func test_no_minis_panel_exposes_the_eight_book_actions() -> void:
	# The companion panel's buttons must be the book's 8 Initiative Actions
	# (Compendium p.68), not the old fabricated Fire/Engage/Sprint/Aid set.
	# Instantiating also force-parses compendium_no_minis.gd (preloaded by the panel).
	var NoMinisPanel := preload("res://src/ui/components/battle/NoMinisCombatPanel.gd")
	var panel: PanelContainer = auto_free(NoMinisPanel.new())
	add_child(panel)  # triggers _ready → _build_ui
	var labels: Array = []
	for btn in panel.find_children("*", "Button", true, false):
		labels.append(btn.text)
	assert_array(labels).contains([
		"Scout", "Move Up", "Carry Out Task", "Charge",
		"Optimal Shot", "Support", "Take Cover", "Keep Distance",
	])

# ============================================================================
# 4. Live auto-resolve routing files compile (BattlePhase.gd is DEPRECATED;
#    the live paths are CampaignTurnController + TacticalBattleUI)
# ============================================================================

func test_live_auto_resolve_files_parse_with_routing() -> void:
	# Both live auto-resolve sites now branch to NoMinisResolver on the NO_MINIS_COMBAT
	# DLC flag. A parse error in either (e.g. a bad preload/const) returns null here.
	assert_that(load("res://src/ui/screens/campaign/CampaignTurnController.gd")).is_not_null()
	assert_that(load("res://src/ui/screens/battle/TacticalBattleUI.gd")).is_not_null()
