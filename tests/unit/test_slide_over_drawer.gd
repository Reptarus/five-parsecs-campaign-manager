extends GdUnitTestSuite
## Tests for SlideOverDrawer — the reusable edge-anchored drawer (keeper
## component for the battle-UI redesign).
##
## Focus: open/close state, signal emission, content parenting, edge geometry.
## Uses animate=false so open/close are synchronous and deterministic.

const Drawer := preload("res://src/ui/components/common/SlideOverDrawer.gd")

var _opened_count: int = 0
var _closed_count: int = 0

func _make_drawer(edge: int = Drawer.Edge.RIGHT):
	_opened_count = 0
	_closed_count = 0
	var d = auto_free(Drawer.new())
	d.edge = edge
	d.animate = false
	add_child(d)
	await get_tree().process_frame  # let _ready() build the UI
	d.opened.connect(func() -> void: _opened_count += 1)
	d.closed.connect(func() -> void: _closed_count += 1)
	return d


func test_initial_state_is_hidden_and_closed() -> void:
	var d = await _make_drawer()
	assert_bool(d.is_open()).is_false()
	assert_bool(d.visible).is_false()


func test_open_sets_state_visible_and_emits() -> void:
	var d = await _make_drawer()
	d.open()
	assert_bool(d.is_open()).is_true()
	assert_bool(d.visible).is_true()
	assert_int(_opened_count).is_equal(1)


func test_close_hides_and_emits() -> void:
	var d = await _make_drawer()
	d.open()
	d.close()
	assert_bool(d.is_open()).is_false()
	assert_bool(d.visible).is_false()
	assert_int(_closed_count).is_equal(1)


func test_open_is_idempotent() -> void:
	var d = await _make_drawer()
	d.open()
	d.open()
	assert_int(_opened_count).is_equal(1)  # second open() is a no-op


func test_close_when_already_closed_is_noop() -> void:
	var d = await _make_drawer()
	d.close()
	assert_int(_closed_count).is_equal(0)


func test_set_content_is_parented_into_drawer() -> void:
	var d = await _make_drawer()
	var probe := Label.new()
	probe.text = "PROBE"
	d.set_content(probe)
	# Probe must now live somewhere inside the drawer subtree.
	assert_bool(d.is_ancestor_of(probe)).is_true()


func test_set_content_replaces_previous() -> void:
	var d = await _make_drawer()
	var first := Label.new()
	d.set_content(first)
	var second := Label.new()
	d.set_content(second)
	assert_bool(d.is_ancestor_of(second)).is_true()
	assert_bool(is_instance_valid(first) and d.is_ancestor_of(first)).is_false()


func test_left_edge_docks_at_x_zero() -> void:
	var d = await _make_drawer(Drawer.Edge.LEFT)
	d.open()
	assert_float(d.get_panel_rect().position.x).is_equal(0.0)


func test_right_edge_docks_flush_to_right() -> void:
	var d = await _make_drawer(Drawer.Edge.RIGHT)
	d.open()
	var vp_w: float = d.get_viewport_rect().size.x
	var r: Rect2 = d.get_panel_rect()
	# Right-docked panel's right edge should meet the viewport's right edge.
	assert_float(r.position.x + r.size.x).is_equal_approx(vp_w, 1.0)


func test_bottom_edge_docks_flush_to_bottom() -> void:
	var d = await _make_drawer(Drawer.Edge.BOTTOM)
	d.open()
	var vp_h: float = d.get_viewport_rect().size.y
	var r: Rect2 = d.get_panel_rect()
	assert_float(r.position.y + r.size.y).is_equal_approx(vp_h, 1.0)
