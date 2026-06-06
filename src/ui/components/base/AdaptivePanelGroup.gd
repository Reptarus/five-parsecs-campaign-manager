@tool
class_name AdaptivePanelGroup
extends VBoxContainer

## A responsive group of N "pane" Controls that adapts to ResponsiveManager's
## effective layout class:
##   - GRID  (effective columns >= 2): panes side-by-side in a GridContainer.
##   - STACK (1 column, "overview" screens): panes stacked 1-column (scrolls).
##   - TABS  (1 column, "master-detail" screens): one pane visible at a time,
##           a TabBar strip switches between them.
##
## DESIGN: panes are reparented into the internal GridContainer EXACTLY ONCE (in
## add_pane) and then NEVER moved again. A mode change only adjusts
## GridContainer.columns, per-pane visibility, and the TabBar's visibility — so a
## rotation never re-fires a pane's _enter_tree/_exit_tree (the churn that
## reparent-on-every-change would cause). The narrow-width tab overflow is handled
## by TabBar.clip_tabs (nav buttons appear when tabs don't fit 375px).
##
## Usage:
##   var group := AdaptivePanelGroup.new()
##   group.portrait_mode = AdaptivePanelGroup.PortraitMode.TABS
##   parent.add_child(group)
##   group.add_pane(mission_panel, "Brief")
##   group.add_pane(map_panel, "Map")
##   group.add_pane(deploy_panel, "Deploy")

## STACK = scroll all panes vertically (overview). TABS = one pane + a strip
## (master-detail). AUTO currently resolves to STACK (override per-screen).
enum PortraitMode { STACK, TABS, AUTO }

@export var portrait_mode: PortraitMode = PortraitMode.AUTO:
	set(value):
		portrait_mode = value
		if is_inside_tree():
			_relayout()

## Maximum side-by-side columns in GRID mode (clamped to pane count).
@export var max_columns: int = 3:
	set(value):
		max_columns = maxi(1, value)
		if is_inside_tree():
			_relayout()

## Spacing between panes (h and v) in the grid.
@export var pane_separation: int = 16:
	set(value):
		pane_separation = value
		_apply_separation()

# ── Internal structure ────────────────────────────────────────────────────────
var _tab_bar: TabBar
var _grid: GridContainer
var _panes: Array[Control] = []
var _titles: PackedStringArray = PackedStringArray()
var _current_tab: int = 0
var _responsive_manager: Node = null

# Touch-target minimum for the tab strip (matches UIColors.TOUCH_TARGET_COMFORT).
const TAB_BAR_MIN_HEIGHT := 56


func _ready() -> void:
	_responsive_manager = get_node_or_null("/root/ResponsiveManager")
	_ensure_structure()
	if _responsive_manager and _responsive_manager.has_signal("layout_class_changed"):
		if not _responsive_manager.layout_class_changed.is_connected(_on_layout_class_changed):
			_responsive_manager.layout_class_changed.connect(_on_layout_class_changed)
	_relayout()


func _exit_tree() -> void:
	if _responsive_manager and _responsive_manager.has_signal("layout_class_changed") \
			and _responsive_manager.layout_class_changed.is_connected(_on_layout_class_changed):
		_responsive_manager.layout_class_changed.disconnect(_on_layout_class_changed)


## Build the TabBar + GridContainer scaffolding once.
func _ensure_structure() -> void:
	if _grid:
		return
	_tab_bar = TabBar.new()
	_tab_bar.name = "PaneTabBar"
	_tab_bar.clip_tabs = true  # nav buttons when tabs overflow a narrow width
	_tab_bar.custom_minimum_size.y = TAB_BAR_MIN_HEIGHT
	_tab_bar.visible = false
	_tab_bar.tab_changed.connect(_on_tab_changed)
	add_child(_tab_bar)

	_grid = GridContainer.new()
	_grid.name = "PaneGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_grid)
	_apply_separation()


## Add a pane (reparented into the grid ONCE). title is its TABS-mode label.
func add_pane(pane: Control, title: String = "") -> void:
	_ensure_structure()
	if pane.get_parent():
		pane.get_parent().remove_child(pane)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_child(pane)
	_panes.append(pane)
	_titles.append(title if not title.is_empty() else pane.name)
	if is_inside_tree():
		_relayout()


## Programmatically switch the visible pane in TABS mode (clamped, no-op elsewhere).
func show_pane(index: int) -> void:
	if index < 0 or index >= _panes.size():
		return
	_current_tab = index
	if _tab_bar and _tab_bar.tab_count > index:
		_tab_bar.current_tab = index
	_apply_tab_visibility()


## Bring a pane to the front IF we're in TABS mode (master-detail). No-op in
## GRID / STACK where every pane is already visible — so a caller can fire this
## on selection (e.g. "show the details pane") without hiding the side-by-side
## panes in landscape.
func focus_pane(index: int) -> void:
	if _tab_bar and _tab_bar.visible:
		show_pane(index)


func get_pane_count() -> int:
	return _panes.size()


func _apply_separation() -> void:
	if _grid:
		_grid.add_theme_constant_override("h_separation", pane_separation)
		_grid.add_theme_constant_override("v_separation", pane_separation)


# ── Layout resolution ─────────────────────────────────────────────────────────

func _on_layout_class_changed(_effective_columns: int) -> void:
	_relayout()


func _effective_columns() -> int:
	if _responsive_manager and _responsive_manager.has_method("get_effective_columns"):
		return _responsive_manager.get_effective_columns()
	return max_columns  # no RM (e.g. @tool editor preview): assume spread


func _relayout() -> void:
	if not _grid or _panes.is_empty():
		return
	var eff := mini(_effective_columns(), mini(max_columns, _panes.size()))
	if eff >= 2:
		_show_grid(eff)
	elif _resolve_portrait_mode() == PortraitMode.TABS:
		_show_tabs()
	else:
		_show_stack()


func _resolve_portrait_mode() -> PortraitMode:
	# AUTO resolves to STACK (overview). Screens that are master-detail set TABS.
	return PortraitMode.STACK if portrait_mode == PortraitMode.AUTO else portrait_mode


## GRID / STACK both show every pane; they differ only in column count.
func _show_grid(columns: int) -> void:
	_tab_bar.visible = false
	_grid.columns = columns
	for pane in _panes:
		pane.visible = true


func _show_stack() -> void:
	_show_grid(1)


## TABS: 1 column, only the current pane visible, the strip shown.
func _show_tabs() -> void:
	_grid.columns = 1
	_rebuild_tab_bar()
	_tab_bar.visible = true
	_current_tab = clampi(_current_tab, 0, _panes.size() - 1)
	_tab_bar.current_tab = _current_tab
	_apply_tab_visibility()


func _rebuild_tab_bar() -> void:
	# Rebuild the strip only if the tab set changed (pane add).
	if _tab_bar.tab_count == _panes.size():
		return
	_tab_bar.clear_tabs()
	for i in _panes.size():
		_tab_bar.add_tab(_titles[i])


func _apply_tab_visibility() -> void:
	for i in _panes.size():
		_panes[i].visible = (i == _current_tab)


func _on_tab_changed(idx: int) -> void:
	_current_tab = idx
	_apply_tab_visibility()
