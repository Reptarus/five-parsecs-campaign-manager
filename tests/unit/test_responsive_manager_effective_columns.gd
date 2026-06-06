extends GdUnitTestSuite
## Phase 0 contract test for ResponsiveManager's orientation-aware effective
## column API (mobile/tablet re-pivot). Verifies the collapse-rule matrix:
## portrait downgrades the column count so a wide-by-width portrait tablet stops
## claiming a 3/4-column desktop grid, while LANDSCAPE stays identical to the
## legacy width-only getters (so desktop callers are unaffected).

const ResponsiveManagerScript := preload("res://src/autoload/ResponsiveManager.gd")

# Breakpoint enum mirror (MOBILE..ULTRAWIDE). Pinned by test_breakpoint_ordinals.
const MOBILE := 0
const TABLET := 1
const DESKTOP := 2
const WIDE := 3
const ULTRAWIDE := 4

var _rm


func before_test() -> void:
	# Bare instance — NOT added to the tree, so _ready()/viewport wiring never
	# runs and we drive (current_breakpoint, is_landscape) directly. The collapse
	# helpers read only those two fields, never the viewport.
	_rm = ResponsiveManagerScript.new()


func after_test() -> void:
	if is_instance_valid(_rm):
		_rm.free()


func _set_state(bp: int, landscape: bool) -> void:
	# NOTE: param is `bp`, not `breakpoint` — `breakpoint` is a reserved GDScript
	# keyword (the debugger statement) and is a parse error as an identifier.
	_rm.current_breakpoint = bp
	_rm.is_landscape = landscape


# ── Guard: the int mirrors above must match the real enum ordinals ────────────

func test_breakpoint_ordinals() -> void:
	assert_int(ResponsiveManagerScript.Breakpoint.MOBILE).is_equal(MOBILE)
	assert_int(ResponsiveManagerScript.Breakpoint.TABLET).is_equal(TABLET)
	assert_int(ResponsiveManagerScript.Breakpoint.DESKTOP).is_equal(DESKTOP)
	assert_int(ResponsiveManagerScript.Breakpoint.WIDE).is_equal(WIDE)
	assert_int(ResponsiveManagerScript.Breakpoint.ULTRAWIDE).is_equal(ULTRAWIDE)


# ── get_effective_columns ─────────────────────────────────────────────────────

func test_effective_columns_portrait_collapses() -> void:
	# Portrait: <=TABLET -> 1, larger -> 2. Never the 3/4 desktop grid.
	# The WIDE case is the keystone fix: a wide-by-width portrait tablet used to
	# claim 4 columns; it must now report 2.
	_set_state(MOBILE, false);    assert_int(_rm.get_effective_columns()).is_equal(1)
	_set_state(TABLET, false);    assert_int(_rm.get_effective_columns()).is_equal(1)
	_set_state(DESKTOP, false);   assert_int(_rm.get_effective_columns()).is_equal(2)
	_set_state(WIDE, false);      assert_int(_rm.get_effective_columns()).is_equal(2)
	_set_state(ULTRAWIDE, false); assert_int(_rm.get_effective_columns()).is_equal(2)


func test_effective_columns_landscape_matches_legacy() -> void:
	# Landscape must equal the untouched width-only getter, every bucket.
	for bp in [MOBILE, TABLET, DESKTOP, WIDE, ULTRAWIDE]:
		_set_state(bp, true)
		assert_int(_rm.get_effective_columns()).is_equal(_rm.get_optimal_columns())


func test_effective_columns_landscape_values() -> void:
	_set_state(MOBILE, true);    assert_int(_rm.get_effective_columns()).is_equal(1)
	_set_state(TABLET, true);    assert_int(_rm.get_effective_columns()).is_equal(2)
	_set_state(DESKTOP, true);   assert_int(_rm.get_effective_columns()).is_equal(3)
	_set_state(WIDE, true);      assert_int(_rm.get_effective_columns()).is_equal(4)
	_set_state(ULTRAWIDE, true); assert_int(_rm.get_effective_columns()).is_equal(4)


# ── get_effective_crew_columns ────────────────────────────────────────────────

func test_effective_crew_columns_portrait_collapses() -> void:
	_set_state(MOBILE, false);    assert_int(_rm.get_effective_crew_columns()).is_equal(1)
	_set_state(TABLET, false);    assert_int(_rm.get_effective_crew_columns()).is_equal(1)
	_set_state(DESKTOP, false);   assert_int(_rm.get_effective_crew_columns()).is_equal(2)
	_set_state(WIDE, false);      assert_int(_rm.get_effective_crew_columns()).is_equal(2)
	_set_state(ULTRAWIDE, false); assert_int(_rm.get_effective_crew_columns()).is_equal(2)


func test_effective_crew_columns_landscape_matches_legacy() -> void:
	for bp in [MOBILE, TABLET, DESKTOP, WIDE, ULTRAWIDE]:
		_set_state(bp, true)
		assert_int(_rm.get_effective_crew_columns()).is_equal(_rm.get_crew_grid_columns())


# ── should_collapse_to_single_column ──────────────────────────────────────────

func test_should_collapse_to_single_column() -> void:
	# True exactly when effective columns == 1: any portrait <= TABLET, plus
	# MOBILE landscape (still 1 col). TABLET landscape and DESKTOP portrait are
	# 2 cols, so they do NOT collapse.
	_set_state(MOBILE, false);  assert_bool(_rm.should_collapse_to_single_column()).is_true()
	_set_state(TABLET, false);  assert_bool(_rm.should_collapse_to_single_column()).is_true()
	_set_state(MOBILE, true);   assert_bool(_rm.should_collapse_to_single_column()).is_true()
	_set_state(TABLET, true);   assert_bool(_rm.should_collapse_to_single_column()).is_false()
	_set_state(DESKTOP, false); assert_bool(_rm.should_collapse_to_single_column()).is_false()
	_set_state(WIDE, true);     assert_bool(_rm.should_collapse_to_single_column()).is_false()


# ── DESIGN_BASE_WIDTH constant ────────────────────────────────────────────────

func test_design_base_width_constant() -> void:
	# Scale reference stays at the desktop landscape width — distinct from the
	# (square) project stretch base — so desktop proportional sizing is unchanged.
	assert_float(ResponsiveManagerScript.DESIGN_BASE_WIDTH).is_equal(1920.0)


# ── _evaluate_layout_change decision seam (the emit guard, deterministically) ──
# This is the keystone the signal exists for: it must report a change on a
# constant-width ROTATION (which breakpoint_changed misses), on a bucket change,
# and NOT on a no-op resize. Tested via the seam so no real viewport is needed.

func test_evaluate_layout_change_rotation_only() -> void:
	# Was WIDE-portrait, now WIDE-landscape (same width bucket, orientation flipped).
	_set_state(WIDE, true)  # current = post-rotation state
	assert_int(_rm._evaluate_layout_change(WIDE, false)).is_equal(4)  # WIDE landscape -> 4


func test_evaluate_layout_change_bucket_only() -> void:
	# Crossed TABLET -> DESKTOP, orientation unchanged (landscape).
	_set_state(DESKTOP, true)
	assert_int(_rm._evaluate_layout_change(TABLET, true)).is_equal(3)  # DESKTOP landscape -> 3


func test_evaluate_layout_change_no_change_returns_negative() -> void:
	# Neither bucket nor orientation changed -> no emit (-1).
	_set_state(DESKTOP, true)
	assert_int(_rm._evaluate_layout_change(DESKTOP, true)).is_equal(-1)


# ── _update_orientation square-viewport boundary (x == y -> landscape) ─────────
# Load-bearing for the Phase 1 square (1080x1080) stretch base: a square frame
# must classify as LANDSCAPE (x >= y), NOT collapse to portrait.

func test_square_viewport_is_landscape() -> void:
	_rm.current_viewport_size = Vector2(1080, 1080)
	_rm._update_orientation()
	assert_bool(_rm.is_landscape).is_true()      # x >= y -> landscape, not portrait
	_rm.current_breakpoint = WIDE
	assert_int(_rm.get_effective_columns()).is_equal(4)  # keeps the landscape column count


# ── crew landscape ladder (pinned to concrete values, not just match-legacy) ──
# The match-legacy test is near-tautological (the landscape branch RETURNS the
# legacy getter); this pins the actual numbers and documents that crew columns
# intentionally diverge from optimal at DESKTOP (2 not 3) and WIDE (3 not 4).

func test_effective_crew_columns_landscape_values() -> void:
	_set_state(MOBILE, true);    assert_int(_rm.get_effective_crew_columns()).is_equal(1)
	_set_state(TABLET, true);    assert_int(_rm.get_effective_crew_columns()).is_equal(2)
	_set_state(DESKTOP, true);   assert_int(_rm.get_effective_crew_columns()).is_equal(2)
	_set_state(WIDE, true);      assert_int(_rm.get_effective_crew_columns()).is_equal(3)
	_set_state(ULTRAWIDE, true); assert_int(_rm.get_effective_crew_columns()).is_equal(4)


# ── get_proportional_size actually divides by DESIGN_BASE_WIDTH (wiring, not literal) ──

func test_get_proportional_size_tracks_design_base() -> void:
	var base_w: float = ResponsiveManagerScript.DESIGN_BASE_WIDTH
	_rm.current_viewport_size = Vector2(base_w, base_w)
	assert_float(_rm.get_proportional_size(100.0, 0.0, 10000.0)).is_equal_approx(100.0, 0.01)  # scale 1.0
	_rm.current_viewport_size = Vector2(base_w / 2.0, base_w)
	assert_float(_rm.get_proportional_size(100.0, 0.0, 10000.0)).is_equal_approx(50.0, 0.01)   # scale 0.5
