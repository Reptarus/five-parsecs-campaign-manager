extends GdUnitTestSuite
## Tests for the Galaxy-Map <-> Travel integration (2026-07 sprint).
##
## Locks in the "streamlined thruline": campaign.initialize_world() is the single
## writer of world_data and emits world_changed; PlanetDataManager.upsert_current_world()
## mirrors a world_data dict into the galaxy-map store; and the p.119 Quest
## mission-required-travel flags round-trip through GameState (Resource-safe via
## progress_data). Protects:
##   - PlanetDataManager.upsert_current_world (B1 data foundation)
##   - FiveParsecsCampaignCore.world_changed signal (B1 chokepoint)
##   - GameState quest-travel methods (B3 mission-required travel)

const FiveParsecsCampaignCore := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PlanetDataManagerScript := preload("res://src/core/world/PlanetDataManager.gd")
const GameStateScript := preload("res://src/core/state/GameState.gd")

# ============================================================================
# Helpers
# ============================================================================

func _sample_world(id: String = "world_test_1", name: String = "Fuller VI") -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": "standard",
		"type_name": "Standard World",
		"danger_level": 2,
		"traits": ["DANGEROUS", "WEALTHY"],
		"locations": [{"name": "Starport", "type": "commerce"}],
		"special_features": ["Notable Sight"],
		"discovered_on_turn": 3,
	}

# ============================================================================
# B1 — PlanetDataManager.upsert_current_world
# ============================================================================

func test_upsert_current_world_seeds_planet_from_world_data() -> void:
	var pdm = auto_free(PlanetDataManagerScript.new())
	var world := _sample_world()

	var pid: String = pdm.upsert_current_world(world, 3)

	assert_str(pid).is_equal("world_test_1")
	assert_bool(pdm.visited_planets.has("world_test_1")).is_true()
	assert_str(pdm.current_planet_id).is_equal("world_test_1")

	var planet = pdm.visited_planets["world_test_1"]
	assert_str(planet.name).is_equal("Fuller VI")
	assert_int(planet.danger_level).is_equal(2)
	# Typed Array[String] traits mapped defensively via .assign()
	assert_bool(planet.traits.has("DANGEROUS")).is_true()
	assert_bool(planet.traits.has("WEALTHY")).is_true()
	# A breadcrumb was appended for the Galaxy Log travel path
	assert_int(pdm.travel_history.size()).is_equal(1)
	assert_str(pdm.travel_history[0].get("planet_id")).is_equal("world_test_1")


func test_upsert_current_world_is_idempotent_for_same_id() -> void:
	var pdm = auto_free(PlanetDataManagerScript.new())
	var world := _sample_world()

	pdm.upsert_current_world(world, 3)
	# Travel back to the SAME world: no duplicate planet, no duplicate breadcrumb,
	# but it is re-set as current.
	pdm.current_planet_id = ""
	var pid2: String = pdm.upsert_current_world(world, 4)

	assert_str(pid2).is_equal("world_test_1")
	assert_int(pdm.visited_planets.size()).is_equal(1)
	assert_int(pdm.travel_history.size()).is_equal(1)
	assert_str(pdm.current_planet_id).is_equal("world_test_1")


func test_upsert_current_world_generates_id_when_missing() -> void:
	var pdm = auto_free(PlanetDataManagerScript.new())
	var world := _sample_world("", "Nameless")

	var pid: String = pdm.upsert_current_world(world, 1)

	assert_bool(pid.is_empty()).is_false()
	assert_bool(pdm.visited_planets.has(pid)).is_true()


func test_upsert_current_world_ignores_empty() -> void:
	var pdm = auto_free(PlanetDataManagerScript.new())
	var pid: String = pdm.upsert_current_world({}, 1)
	assert_str(pid).is_equal("")
	assert_int(pdm.visited_planets.size()).is_equal(0)

# ============================================================================
# B1 — initialize_world emits world_changed (the single chokepoint)
# ============================================================================

func test_initialize_world_emits_world_changed() -> void:
	var campaign = FiveParsecsCampaignCore.new()
	var world := _sample_world()

	var received: Array = []
	campaign.world_changed.connect(func(wd): received.append(wd))

	campaign.initialize_world(world)

	assert_int(received.size()).is_equal(1)
	assert_str(received[0].get("id")).is_equal("world_test_1")
	assert_str(received[0].get("name")).is_equal("Fuller VI")
	# world_data was actually written (single writer)
	assert_str(campaign.world_data.get("name")).is_equal("Fuller VI")

# ============================================================================
# B3 — GameState quest-travel flags round-trip (Resource-safe via progress_data)
# ============================================================================

func test_quest_travel_flags_roundtrip_via_gamestate() -> void:
	var gs = auto_free(GameStateScript.new())
	var campaign = FiveParsecsCampaignCore.new()
	gs.current_campaign = campaign

	# No active quest initially.
	assert_bool(gs.has_active_quest()).is_false()

	# Set active quest (Resource-safe: routed through progress_data).
	gs.set_active_quest({"id": "q1", "name": "The Lost Cargo"})
	assert_bool(gs.has_active_quest()).is_true()
	assert_str(gs.get_active_quest().get("name")).is_equal("The Lost Cargo")

	# Quest Rumors accumulate on the campaign's quest_rumors @var.
	assert_int(gs.get_quest_rumors()).is_equal(0)
	gs.add_quest_rumor()
	gs.add_quest_rumor()
	assert_int(gs.get_quest_rumors()).is_equal(2)

	# Finale flag.
	assert_bool(gs.is_quest_finale_available()).is_false()
	gs.set_quest_finale_available(true)
	assert_bool(gs.is_quest_finale_available()).is_true()

	# p.119 travel requirement: set on a 5-6, cleared on arrival at a new world.
	assert_bool(gs.get_quest_requires_travel().get("required")).is_false()
	gs.set_quest_requires_travel(true, true)
	var q: Dictionary = gs.get_quest_requires_travel()
	assert_bool(q.get("required")).is_true()
	assert_bool(q.get("requires_new_world")).is_true()
	gs.set_quest_requires_travel(false, false)
	assert_bool(gs.get_quest_requires_travel().get("required")).is_false()

	# clear_active_quest wipes the quest AND its transient flags.
	gs.set_quest_finale_available(true)
	gs.clear_active_quest()
	assert_bool(gs.has_active_quest()).is_false()
	assert_bool(gs.is_quest_finale_available()).is_false()
