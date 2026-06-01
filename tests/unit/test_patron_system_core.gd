extends GdUnitTestSuite
## Smoke test pinning PatronSystem's live patron/job API after the 2026-06-01 removal of
## the dead faction-connections subsystem (ExtendedConnectionsManager). Confirms the class
## still compiles + instantiates, the live API works, and get_data() no longer serializes
## the removed `active_connections` key.

const PatronSystem = preload("res://src/core/systems/PatronSystem.gd")


func test_patron_system_initializes() -> void:
	var ps = PatronSystem.new()
	assert_object(ps).is_not_null()
	assert_bool(ps.initialize()).is_true()
	ps.free()


func test_generate_patron_produces_valid_patron() -> void:
	var ps = PatronSystem.new()
	ps.initialize()
	var patron: Dictionary = ps.generate_patron()
	assert_bool(patron.has("id")).is_true()
	assert_bool(patron.has("type")).is_true()
	assert_array(ps.get_active_patrons()).is_not_empty()
	ps.free()


func test_get_data_omits_removed_active_connections_key() -> void:
	var ps = PatronSystem.new()
	ps.initialize()
	var data: Dictionary = ps.get_data()
	# The faction-connections subsystem was removed; its serialized key must be gone.
	assert_bool(data.has("active_connections")).is_false()
	# Live patron keys remain.
	assert_bool(data.has("active_patrons")).is_true()
	assert_bool(data.has("patron_reputations")).is_true()
	ps.free()


func test_status_omits_removed_connection_count() -> void:
	var ps = PatronSystem.new()
	ps.initialize()
	var status: Dictionary = ps.get_status()
	assert_bool(status.has("connection_count")).is_false()
	assert_bool(status.has("patron_count")).is_true()
	ps.free()
