extends GdUnitTestSuite
## Safe-area insets — the rule that had TWO partial implementations and no test.
##
## Written 2026-09-08 while closing §1 of the tablet checklist, which had never been
## walked. What was there before:
##
## | site | coverage | reach |
## |---|---|---|
## | `CampaignScreenBase.get_safe_area_insets()` | all 4 edges | **1 caller** (CampaignDashboard) |
## | `PortraitChrome._safe_area_lr()` | **left/right only** | 10 screens via `ScreenChrome` |
## | `MainMenu` | **none at all** | the first screen the app shows |
##
## The two copies had drifted three ways — edge coverage, `maxi(base, inset)` versus
## `base + inset`, and window-versus-screen as the reference rect. They are now one
## implementation, `PortraitChrome.compute_safe_area_insets()`.
##
## ⚠ **This suite tests `compute_safe_area_insets()`, NOT
## `safe_area_insets_design_px()`.** The latter is OS-gated to Android/iOS and reads
## `DisplayServer` live, so on this desktop machine it returns zeros unconditionally —
## a suite pointed at it would pass every case while proving nothing about a notch it
## cannot produce. Splitting the pure math out is what makes a real cutout testable at
## the desk; see `reference_a_diagnostic_that_cannot_disagree`.

const PortraitChromeRef = preload("res://src/ui/components/base/PortraitChrome.gd")

## The tablet this sprint targets: 2560x1600 physical, and the design space that the
## square-1080 canvas_items+expand stretch plus the 1.16 ui-scale produces from it.
const WIN := Vector2i(2560, 1600)
const DESIGN := Vector2(2206.9, 1379.3)


func _insets(win: Vector2i, safe: Rect2i, ds: Vector2 = DESIGN) -> Dictionary:
	return PortraitChromeRef.compute_safe_area_insets(win, safe, ds)


# ── The premise, instrumented first ─────────────────────────────────────────
# Every "returns zero" case below is worthless unless this function is CAPABLE of
# returning non-zero. This case proves it can, so the zeros elsewhere are findings
# about the input rather than a function that only ever answers zero.

func test_a_real_cutout_produces_a_real_inset() -> void:
	# A 96px status bar across the top of the 2560x1600 panel.
	var got := _insets(WIN, Rect2i(0, 96, 2560, 1504))
	assert_int(got["top"]).override_failure_message(
		"a 96px status bar must produce a top inset, got %d" % got["top"]).is_greater(0)
	# 96 physical / (1600/1379.3) ≈ 82.8 design px.
	assert_int(got["top"]).is_between(80, 85)
	assert_int(got["left"]).is_equal(0)
	assert_int(got["right"]).is_equal(0)
	assert_int(got["bottom"]).is_equal(0)


# ── The case the device will most likely actually report ────────────────────

func test_a_full_screen_safe_area_is_a_no_op() -> void:
	# ⚠ This is the EXPECTED result on this device: export_presets.cfg:60 sets
	# screen/immersive_mode=true, which hides the system bars. All-zeros here is an
	# honest measurement, NOT a broken one — code that treated zero as "the API
	# failed" and substituted a guess would be indistinguishable from a real inset.
	var got := _insets(WIN, Rect2i(0, 0, 2560, 1600))
	assert_int(got["left"]).is_equal(0)
	assert_int(got["top"]).is_equal(0)
	assert_int(got["right"]).is_equal(0)
	assert_int(got["bottom"]).is_equal(0)


func test_a_safe_area_larger_than_the_window_clamps_to_zero() -> void:
	# The desktop shape: get_display_safe_area() reports the whole MONITOR, which is
	# larger than a windowed app. Without the clamp this yields negative padding.
	var got := _insets(Vector2i(1280, 720), Rect2i(0, 0, 2560, 1600), Vector2(1103.4, 620.7))
	assert_int(got["left"]).is_equal(0)
	assert_int(got["top"]).is_equal(0)
	assert_int(got["right"]).is_equal(0)
	assert_int(got["bottom"]).is_equal(0)


# ── All four edges, independently ───────────────────────────────────────────

func test_each_edge_is_computed_independently() -> void:
	# A cutout inset on every side by a different amount, so a copy-paste error that
	# reads the wrong axis or the wrong corner cannot pass.
	var got := _insets(WIN, Rect2i(40, 96, 2560 - 40 - 130, 1600 - 96 - 60))
	assert_int(got["left"]).is_between(33, 36)     # 40 / 1.16
	assert_int(got["top"]).is_between(80, 85)      # 96 / 1.16
	assert_int(got["right"]).is_between(110, 114)  # 130 / 1.16
	assert_int(got["bottom"]).is_between(49, 53)   # 60 / 1.16
	# ...and no two edges collapsed onto the same value, which is what a wrong-axis
	# bug looks like when every inset happens to be similar.
	assert_int(got["left"]).is_not_equal(got["right"])
	assert_int(got["top"]).is_not_equal(got["bottom"])


func test_a_landscape_notch_insets_only_the_side_it_is_on() -> void:
	# A phone on its side: the cutout is entirely on the left.
	var got := _insets(WIN, Rect2i(120, 0, 2440, 1600))
	assert_int(got["left"]).is_greater(0)
	assert_int(got["right"]).is_equal(0)
	assert_int(got["top"]).is_equal(0)
	assert_int(got["bottom"]).is_equal(0)


# ── Degenerate inputs must not produce garbage padding ──────────────────────

func test_degenerate_inputs_return_zero_rather_than_dividing_by_zero() -> void:
	assert_int(_insets(Vector2i(0, 0), Rect2i(0, 0, 100, 100))["top"]).is_equal(0)
	assert_int(_insets(WIN, Rect2i(0, 0, 0, 0))["top"]).is_equal(0)
	assert_int(_insets(WIN, Rect2i(0, 0, 2560, 1600), Vector2.ZERO)["top"]).is_equal(0)
	# A headless viewport reports a zero rect; that must be a no-op, not a crash.
	assert_int(_insets(WIN, Rect2i(0, 96, 2560, 1504), Vector2(0.0, 1379.3))["top"]) \
		.is_equal(0)


func test_the_returned_shape_always_carries_all_four_keys() -> void:
	# Consumers index with ins["top"] and would abort the enclosing function on a
	# missing key — including the early-return zero paths, which is where a partial
	# dictionary is easiest to introduce.
	for got: Dictionary in [
		_insets(WIN, Rect2i(0, 96, 2560, 1504)),
		_insets(WIN, Rect2i(0, 0, 2560, 1600)),
		_insets(Vector2i(0, 0), Rect2i(0, 0, 0, 0)),
	]:
		for key: String in ["left", "top", "right", "bottom"]:
			assert_bool(got.has(key)).override_failure_message(
				"missing key %s in %s" % [key, str(got)]).is_true()


# ── The OS-gated wrapper, and the delegation that replaced the second copy ──

func test_the_live_wrapper_is_a_no_op_off_device() -> void:
	# On Windows this must return zeros regardless of what DisplayServer reports —
	# the OS gate. Also proves the wrapper does not crash on a null viewport.
	var got: Dictionary = PortraitChromeRef.safe_area_insets_design_px(null)
	for key: String in ["left", "top", "right", "bottom"]:
		assert_int(got[key]).is_equal(0)
