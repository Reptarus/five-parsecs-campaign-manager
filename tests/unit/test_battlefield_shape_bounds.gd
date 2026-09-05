extends GdUnitTestSuite
## Terrain shapes must be DRAWN inside the grid. BUG-101, third occurrence.
##
## This invariant had never been asserted anywhere. There are eight other
## test_battlefield_* suites and none measures geometry against the grid rect, so
## the bug was "verified" twice by looking at the map and came back twice. A
## screenshot cannot tell 0.8px of overflow from none, and it cannot tell you
## which of the two independent causes it is looking at.
##
## Measured the way CLAUDE.md prescribes for ScalableVectorShape2D:
##   svs.transform * svs.get_bounding_rect(), grown by stroke_width / 2
## Operand order matters - Transform2D * Rect2 is the forward transform, while
## Rect2 * Transform2D is documented as the INVERSE. Getting it backwards would
## silently measure the wrong rectangle.
##
## Placement is baked in the stable cell_size = 24 space (BUG-102: never mutate
## cell_size) and the container is scaled uniformly at draw time, so an escape
## here is an escape on screen.
##
## The two causes each case is proof against:
##   A. the fallback loop clamped at the TOP and nudged at the BOTTOM, so an
##      exhausted loop kept its last un-clamped nudge (227 shapes, up to 101px)
##   B. the clamp reserved the DECLARED w/h, but create_vector_shape() sets
##      rx = ry = 4.0 on every RECT, so a body shorter than 8px bulges to a
##      ~8.004px floor and under-reserves (11 shapes, up to 0.82px)

const ViewScript = preload("res://src/ui/components/battle/BattlefieldMapView.gd")
const GenScript = preload("res://src/core/battle/BattlefieldGenerator.gd")
const Grid = preload("res://src/core/battle/BattlefieldGrid.gd")

## Rect2.encloses() is inclusive (>= / <=), unlike has_point() which excludes the
## right and bottom edges, so an exactly-clamped shape is meant to pass. What does
## not is float representation: the clamp computes grid_h - half_y and the drawn
## rect reconstructs centre + half_y. Measured worst noise is 0.000061px; 0.01px
## is 1/2400th of a cell.
const BOUNDS_EPSILON := 0.01


## Returns the worst overflow past the grid across every shape, in placement px.
func _worst_overflow(theme: String, table_ft: float, rng_seed: int) -> float:
	var gen = GenScript.new()
	var result: Dictionary = gen.generate_terrain_suggestions(
		theme, [], {}, rng_seed, table_ft)
	assert_bool(result.has("error")).override_failure_message(
		"generator refused theme %s: %s" % [theme, str(result.get("error", ""))]
		).is_false()
	var sectors: Array = result.get("sectors", [])
	assert_int(sectors.size()).override_failure_message(
		"no sectors generated for %s @ %.1fft" % [theme, table_ft]).is_greater(0)

	var view = ViewScript.new()
	add_child(view)
	auto_free(view)
	view.size = Vector2(900, 900)
	view.configure_grid(Grid.dims_for_table(table_ft))
	view.set_show_scatter(true)
	view.populate_from_sectors(sectors, theme, [])

	var container = view._terrain_container
	assert_object(container).override_failure_message(
		"terrain container missing - populate did not build").is_not_null()
	var grid_rect := Rect2(0.0, 0.0,
		float(view.GRID_COLUMNS) * view.cell_size,
		float(view.GRID_ROWS) * view.cell_size)

	var worst: float = 0.0
	var measured: int = 0
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
		measured += 1
		worst = maxf(worst, grid_rect.position.x - drawn.position.x)
		worst = maxf(worst, grid_rect.position.y - drawn.position.y)
		worst = maxf(worst, drawn.end.x - grid_rect.end.x)
		worst = maxf(worst, drawn.end.y - grid_rect.end.y)

	# A run that measured nothing would pass vacuously - the exact shape of a
	# green test that detects nothing.
	assert_int(measured).override_failure_message(
		"measured 0 shapes for %s @ %.1fft seed %d - the assertion below would" %
		[theme, table_ft, rng_seed] + " pass without testing anything").is_greater(0)
	return maxf(worst, 0.0)


## Broad sweep. Catches cause A, which fired on ~6% of all shapes everywhere.
func test_no_terrain_shape_is_drawn_outside_the_grid() -> void:
	for theme: String in ["industrial_zone", "wilderness", "alien_ruin", "crash_site"]:
		for table_ft: float in [2.0, 3.0]:
			for i: int in range(3):
				var rng_seed: int = 100000 + i * 7919 + int(table_ft * 10.0) * 131
				var worst: float = _worst_overflow(theme, table_ft, rng_seed)
				assert_float(worst).override_failure_message(
					"%s @ %.1fft seed %d: terrain extends %.4f px past the grid" %
					[theme, table_ft, rng_seed, worst]).is_less_equal(BOUNDS_EPSILON)


## Narrow sweep on the exact combination cause B was measured on: 2ft tables,
## where the area-fit shrink drives scatter pieces under the 8px corner-radius
## floor. Reverting the real-body fix alone turns THIS case red.
func test_small_scatter_on_a_two_foot_table_stays_inside() -> void:
	for i: int in range(8):
		var rng_seed: int = 100000 + i * 7919 + 20 * 131
		var worst: float = _worst_overflow("industrial_zone", 2.0, rng_seed)
		assert_float(worst).override_failure_message(
			"industrial_zone 2ft seed %d: scatter extends %.4f px past the grid" %
			[rng_seed, worst]).is_less_equal(BOUNDS_EPSILON)
