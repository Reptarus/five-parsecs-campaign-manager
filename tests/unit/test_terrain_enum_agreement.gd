extends GdUnitTestSuite

## Terrain cross-enum agreement (fixed 2026-07-02).
##
## Live dataflow: UnifiedTerrainSystem/TerrainEffectSystem write terrain
## state with GlobalEnums.TerrainFeatureType values
## (TerrainEffectSystem.update_terrain_state), while TerrainRules compares
## that state against GameEnums members (on_terrain_changed ->
## _check_terrain_rules). Before the 2026-07-02 renumber, GameEnums FIRE
## was 15 vs GlobalEnums 6, so the fire-spread and water-extinguish rules
## could NEVER trigger; TerrainEffectType COVER/HAZARD were swapped between
## the two files' effect dictionaries. These tests exercise the actual
## rule path with GlobalEnums-valued state, so any future desync fails
## loudly here (and in test_enum_ordinal_sync.gd).

const TerrainRulesScript = preload("res://src/core/terrain/TerrainRules.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const GameEnumsScript = preload("res://src/core/enums/GameEnums.gd")


func test_fire_spread_rule_triggers_on_globalenums_state() -> void:
	var rules = auto_free(TerrainRulesScript.new())

	# Adjacent forest cell (flammable), written the way the live
	# TerrainEffectSystem writes state — with GlobalEnums feature values.
	rules.on_terrain_changed(Vector2i(1, 0), {
		"terrain_type": TerrainTypes.Type.FOREST,
		"feature_type": GlobalEnums.TerrainFeatureType.NONE,
	})

	var triggered_rules: Array = []
	rules.terrain_rule_triggered.connect(
		func(_pos: Vector2i, rule_type: String, _data: Dictionary) -> void:
			triggered_rules.append(rule_type))

	# Fire placed with the GLOBALENUMS value — the exact live producer shape.
	rules.on_terrain_changed(Vector2i(0, 0), {
		"terrain_type": TerrainTypes.Type.EMPTY,
		"feature_type": GlobalEnums.TerrainFeatureType.FIRE,
	})

	assert_array(triggered_rules).contains(["fire_spread"])


func test_extinguish_rule_triggers_on_globalenums_state() -> void:
	var rules = auto_free(TerrainRulesScript.new())

	# Burning cell written with GlobalEnums FIRE...
	rules.on_terrain_changed(Vector2i(1, 0), {
		"terrain_type": TerrainTypes.Type.EMPTY,
		"feature_type": GlobalEnums.TerrainFeatureType.FIRE,
	})

	var triggered_rules: Array = []
	rules.terrain_rule_triggered.connect(
		func(_pos: Vector2i, rule_type: String, _data: Dictionary) -> void:
			triggered_rules.append(rule_type))

	# ...then adjacent water should offer to extinguish it.
	rules.on_terrain_changed(Vector2i(0, 0), {
		"terrain_type": TerrainTypes.Type.WATER,
		"feature_type": GlobalEnums.TerrainFeatureType.NONE,
	})

	assert_array(triggered_rules).contains(["extinguish_fire"])


func test_effect_dict_keys_agree_across_enum_systems() -> void:
	# TerrainRules keys its effects with GameEnums.TerrainEffectType;
	# TerrainEffectSystem keys modifiers with GlobalEnums.TerrainEffectType.
	# A consumer reading one dict with the other system's key must get the
	# same slot (the old COVER=3/HAZARD=1 vs COVER=1/HAZARD=3 swap broke
	# this silently).
	assert_int(GameEnumsScript.TerrainEffectType.COVER) \
		.is_equal(GlobalEnums.TerrainEffectType.COVER)
	assert_int(GameEnumsScript.TerrainEffectType.HAZARD) \
		.is_equal(GlobalEnums.TerrainEffectType.HAZARD)
	assert_int(GameEnumsScript.TerrainFeatureType.FIRE) \
		.is_equal(GlobalEnums.TerrainFeatureType.FIRE)
	assert_int(GameEnumsScript.TerrainFeatureType.SMOKE) \
		.is_equal(GlobalEnums.TerrainFeatureType.SMOKE)
