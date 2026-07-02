extends GdUnitTestSuite

## Planet persistence tests (rewritten 2026-07-02).
##
## The original suite tested a NEVER-IMPLEMENTED design — visit_planet /
## has_visited_planet / get_visited_planet on the legacy Campaign.gd class
## plus planet_id fields on the Patron/Rival Resources (its own header
## admitted "not yet implemented"). The SHIPPED planet-persistence system
## is the PlanetDataManager autoload (visited_planets + serialize_all /
## deserialize_all, Galaxy Log reads from it); rival planet binding ships
## as dict fields on rival entries. This suite covers the real system with
## a FRESH PlanetDataManager instance so the autoload's state is untouched.

const PlanetDataManagerScript := preload(
	"res://src/core/world/PlanetDataManager.gd")

var pdm


func before_test() -> void:
	pdm = auto_free(PlanetDataManagerScript.new())
	add_child(pdm)


func test_get_or_generate_planet_stores_in_visited() -> void:
	var planet = pdm.get_or_generate_planet("test_planet_001", 1)
	assert_object(planet).is_not_null()
	assert_bool(pdm.visited_planets.has(planet.id)).is_true()


func test_get_or_generate_returns_same_planet_on_revisit() -> void:
	var first = pdm.get_or_generate_planet("revisit_planet", 1)
	var second = pdm.get_or_generate_planet("revisit_planet", 2)
	assert_str(second.id).is_equal(first.id)
	assert_int(pdm.visited_planets.size()).is_equal(1)


func test_current_planet_round_trip() -> void:
	var planet = pdm.get_or_generate_planet("current_test", 1)
	pdm.set_current_planet(planet.id)
	var current = pdm.get_current_planet()
	assert_object(current).is_not_null()
	assert_str(current.id).is_equal(planet.id)


func test_serialize_deserialize_round_trip() -> void:
	var planet = pdm.get_or_generate_planet("persist_me", 3)
	pdm.set_current_planet(planet.id)
	var snapshot: Dictionary = pdm.serialize_all()

	# Fresh instance restores the same visited set + current planet
	var restored = auto_free(PlanetDataManagerScript.new())
	add_child(restored)
	restored.deserialize_all(snapshot)
	assert_bool(restored.visited_planets.has(planet.id)).is_true()
	var current = restored.get_current_planet()
	assert_object(current).is_not_null()
	assert_str(current.id).is_equal(planet.id)


func test_deserialize_empty_clears_state() -> void:
	# Anti-regression for the cross-mode state-leak gotcha: deserialize_all({})
	# is the ONLY clear path — every campaign core calls it unconditionally
	# on load so planets never leak between modes/saves.
	pdm.get_or_generate_planet("leaky_planet", 1)
	assert_bool(pdm.visited_planets.is_empty()).is_false()
	pdm.deserialize_all({})
	assert_bool(pdm.visited_planets.is_empty()).is_true()
