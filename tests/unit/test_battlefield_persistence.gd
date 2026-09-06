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


# ============================================================================
# T11-17 — the cache is a convenience; the CAMPAIGN is the owner
# ============================================================================
#
# DEVICE EVIDENCE (deploy #19). A mid-battle force-stop followed by Continue came
# back with a different terrain seed (4055150519 -> 341922859), i.e. the terrain the
# player had physically laid out on their table had been regenerated and saved over.
# TacticalBattleUI is consume-first: it only generates when `stored_sectors` is empty,
# and it writes the result back through set_battlefield_data().
#
# EVERY STATIC GUARD CHECKED OUT. load_campaign() restores active_battlefield
# (GameState.gd:695-699); the checkpoint was valid (schema_version 1, turn 8 =
# turns_played 8.0); clear_battlefield_data()'s only caller is the post-battle
# cleanup in CampaignTurnController. So the runtime cache was empty at read time for
# a reason not visible in source, and the fix cannot be "stop the path that empties
# it" — that path has not been identified.
#
# Instead: guard on the OWNER. campaign.progress_data["active_battlefield"] is the
# durable record that set_battlefield_data() writes through to, so a cache miss with
# a populated owner is the T11-17 signature whatever caused it. Same shape as the
# empty-container rule that bit SalvageLedger: guard on the owner, never on the
# container's emptiness.

## Simulate the exact failure state: the owner still holds the table (it survived the
## save, which the device pull confirmed) but the runtime cache is empty.
func test_a_cache_miss_reads_the_table_back_from_the_campaign() -> void:
	GameState.set_battlefield_data(_sample_contract())
	# Empty ONLY the cache — do not touch the owner. clear_battlefield_data() erases
	# both, which is correct for post-battle cleanup and useless for reproducing this.
	GameState._battlefield_data = {}

	var got: Dictionary = GameState.get_battlefield_data()
	assert_bool(got.is_empty()).override_failure_message(
		"get_battlefield_data() returned {} while the campaign still held the "
		+ "contract. That empty read is what makes TacticalBattleUI take its "
		+ "FALLBACK generator and overwrite the player's table."
	).is_false()
	assert_int(int(got.get("seed", 0))).is_equal(987654321)
	assert_int((got.get("sectors", []) as Array).size()).is_equal(2)


## ...and the recovered value is re-cached, so the recovery costs one lookup, not one
## per call.
func test_the_recovered_contract_is_re_cached() -> void:
	GameState.set_battlefield_data(_sample_contract())
	GameState._battlefield_data = {}
	var _first: Dictionary = GameState.get_battlefield_data()

	assert_bool(GameState._battlefield_data.is_empty()).override_failure_message(
		"The owner-recovery path did not repopulate the cache."
	).is_false()


## The guard must not invent a table where there genuinely is none — a standalone
## battle and a fresh campaign both legitimately read empty, and returning something
## there would break the consume-first branch in the other direction.
func test_an_empty_owner_still_reads_empty() -> void:
	GameState.clear_battlefield_data()
	assert_bool(GameState.get_battlefield_data().is_empty()).is_true()


## An empty progress_data is a LEGAL state, not a "no campaign" sentinel. Asserted
## explicitly because guarding on container emptiness is the exact mistake that
## silently disabled salvage for every fresh campaign.
func test_a_campaign_with_empty_progress_data_does_not_error() -> void:
	GameState.current_campaign.progress_data = {}
	GameState._battlefield_data = {}
	assert_bool(GameState.get_battlefield_data().is_empty()).is_true()
