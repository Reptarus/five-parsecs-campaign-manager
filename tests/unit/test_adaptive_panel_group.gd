extends GdUnitTestSuite
## AdaptivePanelGroup (Phase 3): verifies the three layout modes apply the correct
## (columns, per-pane visibility, tab-bar visibility), that panes are reparented
## into the grid ONCE and never moved between modes (the lifecycle-safe contract),
## and that the TABS strip switches the visible pane.

const AdaptivePanelGroupClass := preload("res://src/ui/components/base/AdaptivePanelGroup.gd")

var _group


func before_test() -> void:
	_group = AdaptivePanelGroupClass.new()
	add_child(_group)  # _ready builds the TabBar + GridContainer scaffolding
	for i in 3:
		var p := PanelContainer.new()
		p.name = "Pane%d" % i
		_group.add_pane(p, "Tab%d" % i)


func after_test() -> void:
	if is_instance_valid(_group):
		_group.free()


# ── pane intake ───────────────────────────────────────────────────────────────

func test_add_pane_reparents_into_grid_once() -> void:
	assert_int(_group.get_pane_count()).is_equal(3)
	for p in _group._panes:
		assert_bool(p.get_parent() == _group._grid).is_true()


# ── GRID mode (>= 2 columns) ──────────────────────────────────────────────────

func test_grid_mode_three_columns_all_visible() -> void:
	_group._show_grid(3)
	assert_int(_group._grid.columns).is_equal(3)
	assert_bool(_group._tab_bar.visible).is_false()
	for p in _group._panes:
		assert_bool(p.visible).is_true()


func test_grid_mode_two_columns_all_visible() -> void:
	_group._show_grid(2)
	assert_int(_group._grid.columns).is_equal(2)
	assert_bool(_group._tab_bar.visible).is_false()
	for p in _group._panes:
		assert_bool(p.visible).is_true()


# ── STACK mode (1 column, overview) ───────────────────────────────────────────

func test_stack_mode_single_column_all_visible() -> void:
	_group._show_stack()
	assert_int(_group._grid.columns).is_equal(1)
	assert_bool(_group._tab_bar.visible).is_false()
	for p in _group._panes:
		assert_bool(p.visible).is_true()


# ── TABS mode (1 column, master-detail) ───────────────────────────────────────

func test_tabs_mode_one_visible_strip_shown() -> void:
	_group.show_pane(0)
	_group._show_tabs()
	assert_int(_group._grid.columns).is_equal(1)
	assert_bool(_group._tab_bar.visible).is_true()
	assert_int(_group._tab_bar.tab_count).is_equal(3)
	assert_bool(_group._panes[0].visible).is_true()
	assert_bool(_group._panes[1].visible).is_false()
	assert_bool(_group._panes[2].visible).is_false()


func test_tabs_show_pane_switches_visible_pane() -> void:
	_group._show_tabs()
	_group.show_pane(1)
	assert_bool(_group._panes[0].visible).is_false()
	assert_bool(_group._panes[1].visible).is_true()
	assert_bool(_group._panes[2].visible).is_false()
	assert_int(_group._tab_bar.current_tab).is_equal(1)


# ── focus_pane: switches in TABS, no-op in GRID/STACK ─────────────────────────

func test_focus_pane_switches_in_tabs_mode() -> void:
	_group._show_tabs()
	_group.focus_pane(2)
	assert_bool(_group._panes[0].visible).is_false()
	assert_bool(_group._panes[1].visible).is_false()
	assert_bool(_group._panes[2].visible).is_true()
	assert_int(_group._tab_bar.current_tab).is_equal(2)


func test_focus_pane_is_noop_in_grid_mode() -> void:
	# The landscape guard: focusing a pane in GRID must NOT hide the others —
	# all three panes stay side-by-side. This is what lets EquipmentManager call
	# focus_pane(2) on every selection without breaking the desktop layout.
	_group._show_grid(3)
	_group.focus_pane(2)
	for p in _group._panes:
		assert_bool(p.visible).is_true()
	assert_bool(_group._tab_bar.visible).is_false()


# ── portrait-mode resolution ──────────────────────────────────────────────────

func test_resolve_portrait_mode_auto_is_stack() -> void:
	_group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.AUTO
	assert_int(_group._resolve_portrait_mode()).is_equal(AdaptivePanelGroupClass.PortraitMode.STACK)
	_group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.TABS
	assert_int(_group._resolve_portrait_mode()).is_equal(AdaptivePanelGroupClass.PortraitMode.TABS)


# ── the lifecycle-safe contract: NO reparenting between modes ──────────────────

func test_no_reparent_between_modes() -> void:
	_group._show_grid(3)
	_group._show_tabs()
	_group._show_stack()
	_group._show_grid(2)
	for p in _group._panes:
		assert_bool(p.get_parent() == _group._grid).is_true()
