extends SceneTree
## Measures whether generated terrain shapes land INSIDE the grid boundary.
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/probe_terrain_bounds.gd
##
## WHY THIS EXISTS
## BUG-101 (terrain drawn outside the grid) was marked "verified" TWICE on visual
## inspection and came back both times - CLAUDE.md records exactly that. There are
## eight test_battlefield_* suites and NOT ONE asserts a bounds invariant, so
## nothing could catch a regression.
##
## It measures the DRAWN footprint the way the BUG-101 gotcha prescribes:
##   svs.transform * svs.get_bounding_rect(), grown by stroke_width / 2
## against the PLACEMENT-space grid rect (GRID_COLUMNS * cell_size). Placement is
## baked in the stable cell_size=24 space and the container is scaled uniformly at
## draw time, so a violation here is a violation on screen.
##
## Violations are attributed to an EDGE, which is the discriminating part: the
## grid-distributed fallback nudges a colliding shape DOWN (c.y += ...) at the
## BOTTOM of its retry loop while the clamp sits at the TOP, so the final nudge of
## an exhausted loop is never re-clamped. If that is the cause, overflow should be
## overwhelmingly on the bottom edge.
##
## Harness constraints copied from verify_battle_ui.gd (do not "simplify"):
##   * work runs in _process() on frame >= 2 - under --script, root.is_inside_tree()
##     is false during _initialize() and every /root lookup errors.
##   * nothing is preload()ed.

const THEMES := ["industrial_zone", "wilderness", "alien_ruin", "crash_site"]
const TABLE_SIZES := [2.0, 2.5, 3.0]
const SEEDS_PER_COMBO := 12

## Overflow below this counts as float noise, not an escape. Rect2.encloses()
## is inclusive (>= / <=), so an exactly-clamped shape is meant to pass; what
## does not is float representation - the clamp computes grid_h - half_y and
## the drawn rect reconstructs centre + half_y, which can land a fraction over.
## 0.01px is 1/2400th of a cell at cell_size 24.
const BOUNDS_EPSILON := 0.01

var _frame := 0
var _checked := 0
var _violations := 0
var _edge_counts := {"left": 0, "right": 0, "top": 0, "bottom": 0}
var _worst := 0.0
var _worst_noise := 0.0
var _worst_desc := ""
var _samples: Array = []
var _max_err_x := 0.0
var _max_err_y := 0.0
var _err_desc := ""
var _max_center_skew := 0.0
var _skew_desc := ""

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	_run()
	_report()
	quit(1 if _violations > 0 else 0)
	return true

func _run() -> void:
	var ViewRef = load("res://src/ui/components/battle/BattlefieldMapView.gd")
	var GenRef = load("res://src/core/battle/BattlefieldGenerator.gd")
	var GridRef = load("res://src/core/battle/BattlefieldGrid.gd")
	if ViewRef == null or GenRef == null or GridRef == null:
		print("ABORT: could not load one of the three scripts")
		return

	for table_ft: float in TABLE_SIZES:
		var dims: Dictionary = GridRef.dims_for_table(table_ft)
		for theme: String in THEMES:
			for i: int in range(SEEDS_PER_COMBO):
				var rng_seed: int = 100000 + i * 7919 + int(table_ft * 10.0) * 131
				var gen = GenRef.new()
				var result: Dictionary = gen.generate_terrain_suggestions(
					theme, [], {}, rng_seed, table_ft)
				if result.has("error"):
					print("ABORT: generator error: %s" % result["error"])
					return
				var sectors: Array = result.get("sectors", [])
				if sectors.is_empty():
					continue

				var view = ViewRef.new()
				root.add_child(view)
				view.size = Vector2(900, 900)
				view.configure_grid(dims)
				view.set_show_scatter(true)
				view.populate_from_sectors(sectors, theme, [])
				_measure(view, theme, table_ft, rng_seed)
				root.remove_child(view)
				view.queue_free()

func _measure(view, theme: String, table_ft: float, rng_seed: int) -> void:
	var container = view._terrain_container
	if container == null:
		print("WARN: no _terrain_container for %s" % theme)
		return
	var grid_rect := Rect2(0.0, 0.0,
		float(view.GRID_COLUMNS) * view.cell_size,
		float(view.GRID_ROWS) * view.cell_size)

	for child in container.get_children():
		if not child.has_method("get_bounding_rect"):
			continue
		var local: Rect2 = child.get_bounding_rect()
		if local.size == Vector2.ZERO:
			continue
		var pad: float = 0.0
		if "stroke_width" in child:
			pad = maxf(float(child.stroke_width) * 0.5, 0.0)
		var drawn: Rect2 = (child.transform * local).grow(pad)
		_checked += 1

		# Is the tessellated body actually symmetric about `offset`? The
		# placement back-solve assumes it is.
		var skew: float = 0.0
		if "offset" in child:
			skew = (local.get_center() - child.offset).length()
		if skew > _max_center_skew:
			_max_center_skew = skew
			var k: String = "?"
			if child.has_meta("shape_info"):
				k = str(child.get_meta("shape_info").get("shape", "?"))
			_skew_desc = "%s bbox_centre=%s offset=%s size=%s" % [
				k, str(local.get_center()), str(child.offset), str(local.size)]

		# How far does the REAL footprint exceed the one the clamp assumed?
		# The clamp derives half-extents analytically from the declared size;
		# anything the tessellated body adds on top of that is un-clamped slack.
		var nominal: Vector2 = Vector2.ZERO
		if "size" in child:
			nominal = child.size
		var cr: float = absf(cos(child.rotation))
		var sr: float = absf(sin(child.rotation))
		var assumed_x: float = (cr * nominal.x + sr * nominal.y) / 2.0 + pad
		var assumed_y: float = (sr * nominal.x + cr * nominal.y) / 2.0 + pad
		var err_x: float = drawn.size.x / 2.0 - assumed_x
		var err_y: float = drawn.size.y / 2.0 - assumed_y
		if err_x > _max_err_x:
			_max_err_x = err_x
		if err_y > _max_err_y:
			_max_err_y = err_y
			var kind: String = "?"
			if child.has_meta("shape_info"):
				kind = str(child.get_meta("shape_info").get("shape", "?"))
			_err_desc = "%s nominal=%.2fx%.2f rot=%.3f stroke=%.1f measured=%.2fx%.2f assumed_half=%.2f,%.2f" % [
				kind, nominal.x, nominal.y, child.rotation, pad * 2.0,
				drawn.size.x, drawn.size.y, assumed_x, assumed_y]
		var over_l: float = maxf(grid_rect.position.x - drawn.position.x, 0.0)
		var over_t: float = maxf(grid_rect.position.y - drawn.position.y, 0.0)
		var over_r: float = maxf(drawn.end.x - grid_rect.end.x, 0.0)
		var over_b: float = maxf(drawn.end.y - grid_rect.end.y, 0.0)
		var worst_edge: float = maxf(maxf(over_l, over_t), maxf(over_r, over_b))
		if worst_edge <= BOUNDS_EPSILON:
			if worst_edge > _worst_noise:
				_worst_noise = worst_edge
			continue
		_violations += 1
		if over_l > BOUNDS_EPSILON:
			_edge_counts["left"] += 1
		if over_t > BOUNDS_EPSILON:
			_edge_counts["top"] += 1
		if over_r > BOUNDS_EPSILON:
			_edge_counts["right"] += 1
		if over_b > BOUNDS_EPSILON:
			_edge_counts["bottom"] += 1
		if worst_edge > _worst:
			_worst = worst_edge
			_worst_desc = "%s %.1fft seed=%d L%.1f T%.1f R%.1f B%.1f grid=%.0fx%.0f drawn=%s" % [
				theme, table_ft, rng_seed, over_l, over_t, over_r, over_b,
				grid_rect.size.x, grid_rect.size.y, str(drawn)]
		if _samples.size() < 6:
			var sk: String = "?"
			if child.has_meta("shape_info"):
				sk = str(child.get_meta("shape_info"))
			var derived: Vector2 = child.position + child.offset.rotated(child.rotation)
			_samples.append(
				"%s %.1fft seed=%d B%.2f\n     pos=%s offset=%s rot=%.4f scale=%s\n     local=%s derived_centre=%s drawn=%s\n     grid_h=%.1f info=%s" % [
				theme, table_ft, rng_seed, over_b,
				str(child.position), str(child.offset), child.rotation, str(child.scale),
				str(local), str(derived), str(drawn),
				grid_rect.size.y, sk])

func _report() -> void:
	print("")
	print("=== TERRAIN BOUNDS PROBE ===")
	print("shapes measured : %d" % _checked)
	var pct: float = 0.0
	if _checked > 0:
		pct = 100.0 * float(_violations) / float(_checked)
	print("outside grid    : %d  (%.1f%%)" % [_violations, pct])
	print("edge attribution: left=%d top=%d right=%d bottom=%d" % [
		_edge_counts["left"], _edge_counts["top"],
		_edge_counts["right"], _edge_counts["bottom"]])
	print("worst overflow  : %.4f px in placement space (cell_size=24)" % _worst)
	print("worst sub-epsilon float noise: %.6f px (tolerated, < %.2f)" % [
		_worst_noise, BOUNDS_EPSILON])
	print("body centre skew from offset: max %.4f px" % _max_center_skew)
	if _skew_desc != "":
		print("  " + _skew_desc)
	print("footprint estimate error (measured half-extent minus assumed):")
	print("  max x=%.3f px   max y=%.3f px" % [_max_err_x, _max_err_y])
	if _err_desc != "":
		print("  worst y: " + _err_desc)
	if _worst_desc != "":
		print("  " + _worst_desc)
	if not _samples.is_empty():
		print("samples:")
		for s: String in _samples:
			print("  " + s)
	if _violations > 0:
		print("=== FAIL ===")
	else:
		print("=== PASS ===")
