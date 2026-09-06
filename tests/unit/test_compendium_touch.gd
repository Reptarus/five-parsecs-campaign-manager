extends GdUnitTestSuite
## T11-28 — the Compendium item list, measured broken on device TWO separate ways.
##
## (a) SWALLOWED DRAG. Each row is a PanelContainer, which defaults to
##     MOUSE_FILTER_STOP, and every inner node is explicitly IGNORE — so the row is
##     the only thing under the finger and it marks the event handled. The list would
##     not scroll from a drag over its own content.
## (b) DRAG FIRES AS A TAP. The row handler acted on `event.pressed` — the press DOWN
##     — so touching a row to begin scrolling opened its detail popup immediately.
##
## They are INDEPENDENT: fixing (a) alone leaves a list that scrolls and opens a
## random popup on the way; fixing (b) alone leaves a list that does not scroll.
##
## The category is enumerated LIVE and the largest chosen, rather than hardcoding an
## id: a hardcoded id that stops existing would populate nothing and read as a pass.

const ViewScript = preload("res://src/ui/screens/compendium/CompendiumCategoryView.gd")
const ProviderScript = preload("res://src/core/compendium/CompendiumDataProvider.gd")
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")

var _saved_ctx: Variant = null
var _router: Node = null


## The view reads its category from SceneRouter.scene_contexts in _ready()
## (_load_from_context), so the context must land BEFORE the node enters the tree.
func before_test() -> void:
	_router = get_node_or_null("/root/SceneRouter")
	if _router == null:
		return
	_saved_ctx = _router.scene_contexts.get("compendium_category", null)

	var provider = ProviderScript.new()
	var best_id: String = ""
	var best_n: int = -1
	for cat: Dictionary in provider.get_categories():
		var cid: String = str(cat.get("id", ""))
		var n: int = provider.get_items(cid).size()
		if n > best_n:
			best_n = n
			best_id = cid
	_router.scene_contexts["compendium_category"] = {"category_id": best_id}


func after_test() -> void:
	if _router == null:
		return
	if _saved_ctx == null:
		_router.scene_contexts.erase("compendium_category")
	else:
		_router.scene_contexts["compendium_category"] = _saved_ctx


func _build() -> Node:
	var view = auto_free(ViewScript.new())
	add_child(view)
	await await_idle_frame()
	return view


func _stop_rows(list: Node) -> Array[String]:
	var out: Array[String] = []
	if list == null:
		return out
	for child in list.get_children():
		if child is Control and (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append("%s (%s)" % [child.name, child.get_class()])
	return out


func test_the_rows_do_not_swallow_the_drag_that_should_scroll_the_list() -> void:
	var view := await _build()
	assert_int(view._item_list.get_child_count()).override_failure_message(
		"The list populated no rows, so this case proves nothing — check that "
		+ "CompendiumDataProvider still returns items for the largest category."
	).is_greater(0)

	assert_array(_stop_rows(view._item_list)).override_failure_message(
		"Rows still at MOUSE_FILTER_STOP mark the drag HANDLED, so it never reaches "
		+ "the ScrollContainer and the list cannot be scrolled by touch."
	).is_empty()


## Filtering and searching call _populate_item_list() again, which rebuilds every row
## from scratch. A sweep placed in _ready() instead of in the populate path would pass
## the case above and leave the list dead the moment the user typed anything.
func test_the_sweep_survives_a_repopulate() -> void:
	var view := await _build()
	view._populate_item_list()
	await await_idle_frame()

	assert_int(view._item_list.get_child_count()).is_greater(0)
	assert_array(_stop_rows(view._item_list)).override_failure_message(
		"Rows were re-created by _populate_item_list() and left at STOP — the sweep "
		+ "is not on the repopulate path."
	).is_empty()


## Behavioural half. _show_item_detail() calls RulesPopup.show_rules(self, ...), which
## parents a Window to the view — so counting Windows tells us whether the row acted.
func test_a_press_down_alone_does_not_open_the_detail_popup() -> void:
	var view := await _build()
	# NOT get_child(0): a sectioned category puts a group-header HBoxContainer
	# there, which carries no tap handler at all. Driving that node measured a
	# stimulus the row never received and read as "the tap is dead".
	var row: Control = null
	for ch in view._item_list.get_children():
		if ch is PanelContainer:
			row = ch as Control
			break
	assert_object(row).override_failure_message(
		"No PanelContainer row in the list — the list built only headers."
	).is_not_null()

	var before := _count_windows(view)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(20, 10)
	row.gui_input.emit(down)
	await await_idle_frame()

	assert_int(_count_windows(view)).override_failure_message(
		"The press DOWN opened the detail popup. On the tablet this fired the "
		+ "instant a finger touched a row to scroll the list."
	).is_equal(before)

	# ...and the release completes a real tap, so the row is not merely dead.
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(20, 10)
	row.gui_input.emit(up)
	await await_idle_frame()

	assert_int(_count_windows(view)).override_failure_message(
		"A complete tap did not open the detail popup — the row is now dead, which "
		+ "is a worse regression than the one being fixed."
	).is_equal(before + 1)


func _count_windows(root: Node) -> int:
	var n: int = 0
	for child in root.get_children():
		if child is Window:
			n += 1
		n += _count_windows(child)
	return n
