extends GdUnitTestSuite
## active_battlefield persistence contract:
## GameState.set_battlefield_data() is the single mutation chokepoint —
## it caches at runtime AND writes through to
## campaign.progress_data["active_battlefield"], which rides the existing
## FiveParsecsCampaignCore "progress" serialization. A reload therefore
## restores the exact map the player physically built.

const Grid = preload("res://src/core/battle/BattlefieldGrid.gd")
const CampaignCoreClass = preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _prior_campaign: Resource = null
var _prior_bf: Dictionary = {}


func before_test() -> void:
	_prior_campaign = GameState.current_campaign
	_prior_bf = GameState.get_battlefield_data()
	GameState.current_campaign = CampaignCoreClass.new()
	GameState.clear_battlefield_data()


func after_test() -> void:
	GameState.current_campaign = _prior_campaign
	if _prior_bf.is_empty():
		GameState.clear_battlefield_data()
	else:
		GameState.set_battlefield_data(_prior_bf)


func _sample_contract() -> Dictionary:
	return {
		"schema_version": 1,
		"seed": 987654321,
		"theme": "alien_ruin",
		"theme_name": "Alien Ruin",
		"table_size_ft": 2.5,
		"world_traits": ["crystals"],
		"deployment_condition": {"condition_id": "DELAYED", "title": "Delayed"},
		"sectors": [
			{"label": "A1", "features": ["SMALL: Ruined single building"]},
			{"label": "B2", "features": ["LARGE: Ruined tower surrounded by rubble"]},
		],
		"combat_notes": ["test note"],
		"visibility_limit": "",
		"summary": "Theme: Alien Ruin",
		"objective_positions": [
			{"type": "center", "grid_pos": [10.0, 10.0], "label": "Secure"}],
		"enemy_markers": [
			{"position": [5, 17], "team": "enemy", "status": "alive"}],
		"notable_sight": {"type": "LOOT_CACHE", "name": "Loot cache",
			"distance_inches": 9.0, "angle": 1.5},
		"mission_objective": "secure",
		"enemy_ai": "C",
		"enemy_count": 5,
		"sector_rerolls": {"B2": 1},
		"generated_at_turn": 7,
	}


func test_set_writes_through_to_progress_data() -> void:
	GameState.set_battlefield_data(_sample_contract())
	var stored: Dictionary = GameState.current_campaign.progress_data.get(
		"active_battlefield", {})
	assert_bool(stored.is_empty()).is_false()
	assert_int(int(stored.get("seed", 0))).is_equal(987654321)
	# Runtime cache and progress_data agree
	assert_str(JSON.stringify(GameState.get_battlefield_data())) \
		.is_equal(JSON.stringify(stored))


func test_clear_erases_both_locations() -> void:
	GameState.set_battlefield_data(_sample_contract())
	GameState.clear_battlefield_data()
	assert_bool(GameState.get_battlefield_data().is_empty()).is_true()
	assert_bool(GameState.current_campaign.progress_data.has(
		"active_battlefield")).is_false()


func test_set_without_campaign_is_safe() -> void:
	GameState.current_campaign = null
	GameState.set_battlefield_data(_sample_contract())
	assert_int(int(GameState.get_battlefield_data().get("seed", 0))) \
		.is_equal(987654321)
	GameState.clear_battlefield_data()


func test_full_save_load_round_trip() -> void:
	GameState.set_battlefield_data(_sample_contract())
	var campaign: Resource = GameState.current_campaign

	# Serialize exactly like a save file, then rebuild a fresh core
	var save_dict: Dictionary = campaign.to_dictionary()
	var json_text: String = JSON.stringify(save_dict)
	var parsed: Dictionary = JSON.parse_string(json_text)
	var restored: Resource = CampaignCoreClass.new()
	restored.from_dictionary(parsed)

	var stored: Dictionary = restored.progress_data.get(
		"active_battlefield", {})
	assert_bool(stored.is_empty()).is_false()
	# Sectors byte-match — the physical table the player built is intact
	assert_str(JSON.stringify(stored.get("sectors", []))) \
		.is_equal(JSON.stringify(_sample_contract()["sectors"]))
	assert_int(int(stored.get("seed", 0))).is_equal(987654321)
	assert_float(float(stored.get("table_size_ft", 0.0))) \
		.is_equal_approx(2.5, 0.001)
	assert_str(str(stored.get("theme", ""))).is_equal("alien_ruin")
	# JSON-safe positions rehydrate to engine types
	var obj0: Dictionary = stored.get("objective_positions", [])[0]
	assert_that(Grid.json_to_grid_pos(obj0.get("grid_pos"))) \
		.is_equal(Vector2(10, 10))
	var m0: Dictionary = stored.get("enemy_markers", [])[0]
	assert_that(Grid.json_to_grid_pos(m0.get("position"))) \
		.is_equal(Vector2(5, 17))
	# Re-roll bookkeeping and the sight's polar placement survive
	assert_int(int(stored.get("sector_rerolls", {}).get("B2", 0))) \
		.is_equal(1)
	assert_float(float(stored.get("notable_sight", {}).get(
		"distance_inches", 0.0))).is_equal_approx(9.0, 0.001)
