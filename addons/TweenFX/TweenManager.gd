## Internal tracking system for TweenFX.
## [br][br]
## Manages active tweens per node, handles cleanup when nodes are freed,
## and provides stop/query methods. Not intended for direct use —
## access through [TweenFX] instead.
## [br][br]
## An animation that moves a property away from its rest value and back (punch_in,
## press, pop_in, breathe, glow_pulse, fold_in) passes those rest values to [method track].
## [method stop] and [method stop_all] put them back after killing the tween. Without
## that, a tween killed mid-flight left the node displaced, and because every animation
## starts with [code]stop()[/code] and then reads the node's CURRENT value as its
## "original", re-triggering one before it finished made the displacement permanent and
## compounding: a step label punched on every wizard step grew ~15% per step
## (2026-10-28, measured on the Planetfall creation wizard).

static var _active: Dictionary = {}  # { node: { TweenFX.Animations.X: tween } }
static var _rest: Dictionary = {}  # { node: { TweenFX.Animations.X: { property_path: value } } }

static func track(node: CanvasItem, anim: TweenFX.Animations, tween: Tween, rest: Dictionary = {}) -> void:
	if not _active.has(node):
		_active[node] = {}
		if not node.tree_exiting.is_connected(_on_node_exiting):
			node.tree_exiting.connect(_on_node_exiting.bind(node), CONNECT_ONE_SHOT)
	_active[node][anim] = tween
	if not rest.is_empty():
		if not _rest.has(node):
			_rest[node] = {}
		_rest[node][anim] = rest.duplicate()
	tween.finished.connect(_on_tween_finished.bind(node, anim), CONNECT_ONE_SHOT)

static func stop(node: CanvasItem, anim: TweenFX.Animations) -> void:
	if not _active.has(node) or not _active[node].has(anim):
		return
	_active[node][anim].kill()
	_active[node].erase(anim)
	if _active[node].is_empty():
		_active.erase(node)
	_restore(node, anim)

static func stop_all(node: CanvasItem) -> void:
	if not _active.has(node):
		return
	for tween in _active[node].values():
		tween.kill()
	var anims: Array = _active[node].keys()
	_active.erase(node)
	for anim in anims:
		_restore(node, anim)

static func is_playing(node: CanvasItem, anim: TweenFX.Animations) -> bool:
	return _active.has(node) and _active[node].has(anim)

## Put back the rest values an interrupted animation was moving away from.
static func _restore(node: CanvasItem, anim: Variant) -> void:
	if not _rest.has(node) or not _rest[node].has(anim):
		return
	var rest: Dictionary = _rest[node][anim]
	_forget_rest(node, anim)
	if not is_instance_valid(node):
		return
	for path in rest:
		node.set_indexed(NodePath(str(path)), rest[path])

static func _forget_rest(node: Variant, anim: Variant) -> void:
	if not _rest.has(node):
		return
	_rest[node].erase(anim)
	if _rest[node].is_empty():
		_rest.erase(node)

static func _on_tween_finished(node: Variant, anim: Variant) -> void:
	_forget_rest(node, anim)
	if node == null or not is_instance_valid(node):
		return
	if not _active.has(node):
		return
	_active[node].erase(anim)
	if _active[node].is_empty():
		_active.erase(node)

static func _on_node_exiting(node: Variant) -> void:
	_active.erase(node)
	_rest.erase(node)
