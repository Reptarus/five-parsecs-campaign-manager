extends GdUnitTestSuite
## Smoke test pinning PatronSystem's live patron API. Confirms the class still compiles +
## instantiates and the live API works, and pins two dead-code removals:
##   - 2026-06-01: faction-connections subsystem (ExtendedConnectionsManager) -> no `active_connections`.
##   - 2026-06-02: the inert job sub-system (accept_job/complete_job/current_job/job_history) ->
##     get_data() omits the job keys and the job methods no longer exist.

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


func test_get_data_omits_removed_job_keys() -> void:
	var ps = PatronSystem.new()
	ps.initialize()
	var data: Dictionary = ps.get_data()
	# The inert job sub-system was removed 2026-06-02; its serialized keys must be gone.
	assert_bool(data.has("current_job")).is_false()
	assert_bool(data.has("job_history")).is_false()
	# Live patron/quest keys remain.
	assert_bool(data.has("active_quests")).is_true()
	assert_bool(data.has("completed_quests")).is_true()
	ps.free()


func test_dead_job_methods_removed() -> void:
	var ps = PatronSystem.new()
	ps.initialize()
	# Job sub-system methods removed 2026-06-02 (accept_job was never called, so the whole
	# accept->complete flow was inert). RivalPatronResolver's has_method("complete_job") guard
	# now correctly skips, so removal is behavior-preserving.
	assert_bool(ps.has_method("accept_job")).is_false()
	assert_bool(ps.has_method("complete_job")).is_false()
	assert_bool(ps.has_method("get_current_job")).is_false()
	assert_bool(ps.has_method("has_active_job")).is_false()
	# Live patron API is intact.
	assert_bool(ps.has_method("generate_patron")).is_true()
	assert_bool(ps.has_method("get_active_patrons")).is_true()
	ps.free()
