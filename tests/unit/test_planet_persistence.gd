extends GdUnitTestSuite

## Planet Persistence Tests
## Tests for planet-to-planet data consistency feature
## Validates that patrons, rivals, and planet state persist correctly

const Campaign = preload("res://src/core/campaign/Campaign.gd")
const Patron = preload("res://src/core/rivals/Patron.gd")
const Rival = preload("res://src/core/rivals/Rival.gd")

var _campaign: Campaign

func before_test() -> void:
	_campaign = Campaign.new()
	# Set a valid campaign name to avoid validation errors
	_campaign.campaign_name = "Test Campaign"

func after_test() -> void:
	if _campaign:
		_campaign = null

# === Campaign Planet Storage Tests ===
# NOTE: Planet persistence methods are not yet implemented on Campaign class
# These tests are skipped until the feature is added

func test_visit_planet_stores_data() -> void:
	var planet_data: Dictionary = {"name": "Terra Prime", "markets": ["weapons", "armor"]}
	_campaign.visit_planet("planet_001", planet_data)
	
	assert_bool(_campaign.has_visited_planet("planet_001")).is_true()
	var stored: Dictionary = _campaign.get_visited_planet("planet_001")
	assert_str(stored.get("name", "")).is_equal("Terra Prime")

func test_has_visited_planet_returns_false_for_unknown() -> void:
	assert_bool(_campaign.has_visited_planet("unknown_planet")).is_false()

func test_get_visited_planet_returns_empty_for_unknown() -> void:
	var result: Dictionary = _campaign.get_visited_planet("nonexistent")
	assert_bool(result.is_empty()).is_true()

func test_update_planet_state_merges_data() -> void:
	var initial := {"name": "Outpost Alpha", "threat_level": 2}
	_campaign.visit_planet("outpost_001", initial)
	
	_campaign.update_planet_state("outpost_001", {"threat_level": 5, "new_field": "added"})
	
	var updated: Dictionary = _campaign.get_visited_planet("outpost_001")
	assert_int(updated.get("threat_level", 0)).is_equal(5)
	assert_str(updated.get("new_field", "")).is_equal("added")
	assert_str(updated.get("name", "")).is_equal("Outpost Alpha")

func test_get_all_visited_planets_returns_ids() -> void:
	_campaign.visit_planet("planet_a", {"name": "Alpha"})
	_campaign.visit_planet("planet_b", {"name": "Beta"})
	
	var all_planets: Array = _campaign.get_all_visited_planets()
	assert_int(all_planets.size()).is_equal(2)
	assert_bool("planet_a" in all_planets).is_true()
	assert_bool("planet_b" in all_planets).is_true()

func test_visited_planets_serializes_correctly() -> void:
	_campaign.visit_planet("planet_x", {"name": "Planet X", "markets": ["tech"]})
	_campaign.current_planet_id = "planet_x"
	
	var serialized := _campaign.serialize()
	assert_bool(serialized.has("visited_planets")).is_true()
	assert_bool(serialized.has("current_planet_id")).is_true()
	assert_str(serialized.get("current_planet_id", "")).is_equal("planet_x")

func test_visited_planets_deserializes_correctly() -> void:
	# Test deserialization with valid campaign name to avoid validation error
	var data := {
		"name": "Test Campaign",  # Required for deserialize
		"visited_planets": {
			"planet_y": {"name": "Planet Y", "population": 1000}
		},
		"current_planet_id": "planet_y"
	}
	_campaign.deserialize(data)
	
	assert_bool(_campaign.has_visited_planet("planet_y")).is_true()
	assert_str(_campaign.current_planet_id).is_equal("planet_y")

# === Patron Planet Binding Tests ===
# Patron has planet_id (String) and met_on_turn (int) for planet binding

func test_patron_has_planet_id_field() -> void:
	var patron := Patron.new("Test Patron", null, GlobalEnums.FactionType.NEUTRAL)
	patron.planet_id = "test_planet"
	patron.met_on_turn = 5
	
	assert_str(patron.planet_id).is_equal("test_planet")
	assert_int(patron.met_on_turn).is_equal(5)

func test_patron_serializes_planet_binding() -> void:
	var patron := Patron.new("Test Patron", null, GlobalEnums.FactionType.NEUTRAL)
	patron.planet_id = "home_world"
	patron.met_on_turn = 3
	
	var serialized := patron.serialize()
	assert_str(serialized.get("planet_id", "")).is_equal("home_world")
	assert_int(serialized.get("met_on_turn", 0)).is_equal(3)

func test_patron_deserializes_planet_binding() -> void:
	var data := {
		"name": "Restored Patron",
		"planet_id": "distant_colony",
		"met_on_turn": 7,
		"relationship": 50,
		"faction_type": "NEUTRAL"
	}
	var patron = Patron.deserialize(data)

	assert_that(patron).is_not_null()
	assert_str(patron.planet_id).is_equal("distant_colony")
	assert_int(patron.met_on_turn).is_equal(7)

# === Rival Planet Binding Tests ===
# Rival has origin_planet_id, current_planet_id, and can_follow properties

func test_rival_has_planet_binding_fields() -> void:
	var rival := Rival.new()
	rival.origin_planet_id = "origin_world"
	rival.current_planet_id = "current_world"
	rival.can_follow = false
	
	assert_str(rival.origin_planet_id).is_equal("origin_world")
	assert_str(rival.current_planet_id).is_equal("current_world")
	assert_bool(rival.can_follow).is_false()

func test_rival_serializes_planet_binding() -> void:
	var rival := Rival.new()
	rival.rival_name = "Test Rival"
	rival.origin_planet_id = "spawn_planet"
	rival.current_planet_id = "hunting_ground"
	rival.can_follow = true
	
	var serialized := rival.serialize()
	assert_str(serialized.get("origin_planet_id", "")).is_equal("spawn_planet")
	assert_str(serialized.get("current_planet_id", "")).is_equal("hunting_ground")
	assert_bool(serialized.get("can_follow", false)).is_true()

func test_rival_deserializes_planet_binding() -> void:
	var data := {
		"name": "Restored Rival",
		"origin_planet_id": "enemy_base",
		"current_planet_id": "enemy_base",
		"can_follow": false
	}
	var rival := Rival.new()
	rival.deserialize(data)
	
	assert_str(rival.origin_planet_id).is_equal("enemy_base")
	assert_str(rival.current_planet_id).is_equal("enemy_base")
	assert_bool(rival.can_follow).is_false()

# === Empty Planet ID (Universal) Tests ===

func test_patron_empty_planet_id_means_universal() -> void:
	var patron := Patron.new("Universal Patron", null, GlobalEnums.FactionType.NEUTRAL)
	# Empty planet_id = universal patron (available everywhere)
	assert_str(patron.planet_id).is_equal("")

func test_rival_empty_planet_id_means_universal() -> void:
	var rival := Rival.new()
	# Empty planet IDs = universal rival
	assert_str(rival.origin_planet_id).is_equal("")
	assert_str(rival.current_planet_id).is_equal("")
