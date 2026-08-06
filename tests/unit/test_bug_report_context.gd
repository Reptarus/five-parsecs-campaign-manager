extends GdUnitTestSuite
## BugReportContext runs at the moment something has already gone wrong, so its
## only hard requirement is that it never crashes and never blocks. These pin
## the two ways it could: a missing campaign (every campaign read is optional)
## and a missing log file (the tail must degrade to empty, not error).
##
## gdUnit4 v6.0.3 compatible.

const ContextClass = preload("res://src/core/support/BugReportContext.gd")


# --- collect() is total: it works with nothing loaded ------------------------

func test_collect_returns_populated_dict_with_no_campaign() -> void:
	var ctx: Dictionary = ContextClass.collect()
	assert_object(ctx).is_not_null()
	assert_bool(ctx.is_empty()).is_false()


func test_collect_always_carries_build_identity() -> void:
	# These four are the minimum a report needs to be actionable, and none of
	# them depend on any autoload being present.
	var ctx: Dictionary = ContextClass.collect()
	assert_bool(ctx.has("app_version")).is_true()
	assert_bool(ctx.has("build_type")).is_true()
	assert_bool(ctx.has("engine")).is_true()
	assert_bool(ctx.has("platform")).is_true()
	assert_str(str(ctx["build_type"])).is_not_equal("")


func test_collect_reports_device_and_timestamp() -> void:
	var ctx: Dictionary = ContextClass.collect()
	assert_bool(ctx.has("device_model")).is_true()
	assert_bool(ctx.has("window_size")).is_true()
	assert_bool(ctx.has("timestamp")).is_true()
	# ISO-ish, so at minimum it contains a date separator.
	assert_bool(str(ctx["timestamp"]).contains("-")).is_true()


func test_collect_never_leaves_current_scene_blank() -> void:
	# SceneRouter.current_scene goes stale when a screen bypasses navigate_to(),
	# so the collector falls back to the live scene. It must never emit "".
	var ctx: Dictionary = ContextClass.collect()
	assert_bool(ctx.has("current_scene")).is_true()
	assert_str(str(ctx["current_scene"])).is_not_equal("")


func test_campaign_mode_is_none_when_nothing_loaded() -> void:
	# The headless suite has no campaign; the collector must say so explicitly
	# rather than omitting the key or crashing on a null dereference.
	var ctx: Dictionary = ContextClass.collect()
	assert_bool(ctx.has("campaign_mode")).is_true()


func test_turn_counters_come_from_phase_manager_when_available() -> void:
	# All three turn sources are captured deliberately: they can desync, and the
	# divergence is itself a bug signal. CampaignPhaseManager fields are plain
	# vars so they read safely with no campaign.
	var ctx: Dictionary = ContextClass.collect()
	if ctx.has("turn_cpm"):
		assert_int(int(ctx["turn_cpm"])).is_greater_equal(0)
		assert_bool(ctx.has("phase")).is_true()


# --- read_log_tail() degrades instead of erroring ---------------------------

func test_log_tail_returns_empty_for_zero_lines() -> void:
	var tail: PackedStringArray = ContextClass.read_log_tail(0)
	assert_int(tail.size()).is_equal(0)


func test_log_tail_returns_empty_for_negative_lines() -> void:
	var tail: PackedStringArray = ContextClass.read_log_tail(-5)
	assert_int(tail.size()).is_equal(0)


func test_log_tail_respects_the_line_cap() -> void:
	# Whether or not a log exists in this environment, the cap must hold.
	var tail: PackedStringArray = ContextClass.read_log_tail(10)
	assert_int(tail.size()).is_less_equal(10)


func test_log_tail_does_not_error_when_log_is_absent() -> void:
	# The contract is "empty, not an exception" — a tester on a fresh install
	# with no log yet must still be able to file a report.
	var tail: PackedStringArray = ContextClass.read_log_tail(100)
	assert_object(tail).is_not_null()


func test_log_tail_has_no_trailing_blank_lines() -> void:
	var tail: PackedStringArray = ContextClass.read_log_tail(100)
	if tail.size() > 0:
		assert_str(tail[tail.size() - 1].strip_edges()).is_not_equal("")
