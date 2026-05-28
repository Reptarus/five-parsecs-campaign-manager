## SceneStage - composes a multi-layer scene from a JSON manifest.
##
## Loads `data/scenes/<id>.json` (produced by `scripts/psd_extract.py`) and
## renders bg + actors + fx as stacked TextureRects. All extracted layers are
## canvas-sized PNGs with position baked into alpha, so the composer just
## stacks same-sized rects with shared anchors. Actors can be shown/hidden
## individually for scene-variant composition (Six Ages / KoDP style).
##
## Character slots (roster-aware composition): a scene may declare
## `character_slots` geometry; callers map their crew into the slots via
## set_character_slots(), and each figure is resolved from species_id through
## SpeciesFigureRegistry. Slot figures render ABOVE the background but BELOW the
## actor layer (tree order, so baked foreground actors like ambush enemies stay
## in front of the crew). Position is the figure's feet (bottom-center).
##
## Public API:
##   set_scene(id_or_path: String)            - load + populate
##   show_actor(actor_id, fade_in: float)     - fade actor in
##   hide_actor(actor_id, fade_out: float)    - fade actor out
##   set_actor_visibility(actor_id, visible)  - instant
##   get_character_slots() -> Array           - manifest slot geometry
##   set_character_slots(assignments: Array)  - fill slots with crew figures
##   clear()                                  - drop all children
##   get_actor_ids() -> Array[String]
##
## Path-loaded (no class_name) to keep load order clean. Extend Control so
## the parent can size it freely; TextureRects fill the rect with
## STRETCH_KEEP_ASPECT_CENTERED so the canvas aspect is preserved.
extends Control

const MANIFEST_DIR := "res://data/scenes/"
const SpeciesFigureRegistry = preload("res://src/core/character/SpeciesFigureRegistry.gd")

# Ambient "living painting" motion defaults (overridable per scene via the
# manifest's optional `ambient_motion` block). overscan zooms every layer a
# hair so the tiny drift never exposes the letterbox edge; breathe is a slow
# Ken Burns scale swing layered on top of the overscan baseline.
const DEFAULT_OVERSCAN := 1.04
const DEFAULT_BREATHE := 0.012
const DEFAULT_BREATHE_PERIOD := 24.0

var _scene_id: String = ""
var _manifest: Dictionary = {}
var _bg_layer: Control = null
var _slot_layer: Control = null
var _actor_layer: Control = null
var _fx_layer: Control = null
var _actor_rects: Dictionary = {}  # actor_id -> TextureRect
var _actor_tweens: Dictionary = {}  # actor_id -> Tween
var _character_slots: Array = []   # manifest slot geometry defs
var _slot_assignments: Array = []  # current {slot_id, species_id, character_id, drift?}
var _slot_rects: Dictionary = {}   # slot_id -> TextureRect
var _ambient_tweens: Array = []    # looping drift/breathe tweens (whole-scene motion)
var _ambient_active: bool = false  # true while ambient motion owns layer transforms


func _ready() -> void:
	_build_layers()


func _build_layers() -> void:
	if _bg_layer:
		return
	_bg_layer = Control.new()
	_bg_layer.name = "BGLayer"
	_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_layer)

	# Character-slot figures sit ABOVE the background but BELOW the actor layer,
	# so crew composited into a scene render behind baked foreground actors
	# (e.g. the story_event_01 ambush enemies). Tree order governs this, NOT
	# z_index -- z_index would override tree order and let crew jump in front.
	_slot_layer = Control.new()
	_slot_layer.name = "SlotLayer"
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_slot_layer)

	_actor_layer = Control.new()
	_actor_layer.name = "ActorLayer"
	_actor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actor_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_actor_layer)

	_fx_layer = Control.new()
	_fx_layer.name = "FXLayer"
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx_layer)

	if not resized.is_connected(_on_stage_resized):
		resized.connect(_on_stage_resized)


func _on_stage_resized() -> void:
	_layout_character_slots()
	_refresh_ambient_pivots()


func set_scene(id_or_path: String) -> void:
	if not _bg_layer:
		_build_layers()
	clear()
	var path: String = id_or_path
	if not path.begins_with("res://"):
		path = MANIFEST_DIR + id_or_path + ".json"
	if not ResourceLoader.exists(path):
		push_warning("SceneStage: manifest not found: %s" % path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("SceneStage: cannot open manifest: %s" % path)
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("SceneStage: manifest parse failed: %s" % path)
		return
	_manifest = parsed
	_scene_id = _manifest.get("id", "")
	_populate_bg()
	_populate_actors()
	_populate_fx()
	_character_slots = _manifest.get("character_slots", [])
	_start_ambient_motion()


func _populate_bg() -> void:
	for bg_path in _manifest.get("bg_layers", []):
		var rect := _make_layer_rect(bg_path)
		if rect:
			_bg_layer.add_child(rect)


func _populate_actors() -> void:
	for actor in _manifest.get("actor_layers", []):
		var actor_path: String = actor.get("path", "")
		var rect := _make_layer_rect(actor_path)
		if not rect:
			continue
		var actor_id: String = actor.get("id", actor_path.get_file().get_basename())
		rect.name = actor_id
		rect.visible = bool(actor.get("default_visible", true))
		var opacity: int = int(actor.get("opacity", 255))
		rect.modulate.a = clampf(opacity / 255.0, 0.0, 1.0)
		_actor_layer.add_child(rect)
		_actor_rects[actor_id] = rect


func _populate_fx() -> void:
	for fx in _manifest.get("fx_layers", []):
		var fx_path: String = fx.get("path", "")
		var rect := _make_layer_rect(fx_path)
		if not rect:
			continue
		rect.visible = bool(fx.get("default_visible", true))
		var opacity: int = int(fx.get("opacity", 255))
		rect.modulate.a = clampf(opacity / 255.0, 0.0, 1.0)
		# Blend mode hints from manifest - not all PSD blend modes map cleanly
		# to CanvasItem materials. v1: best-effort with built-ins, accept
		# fidelity loss for non-trivial modes.
		_apply_blend_mode(rect, str(fx.get("blend_mode", "NORMAL")))
		_fx_layer.add_child(rect)


func _make_layer_rect(res_path: String) -> TextureRect:
	if res_path.is_empty() or not ResourceLoader.exists(res_path):
		return null
	var tex := load(res_path) as Texture2D
	if not tex:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


func _apply_blend_mode(rect: CanvasItem, mode_name: String) -> void:
	var mode_upper := mode_name.to_upper()
	if mode_upper in ["NORMAL", ""]:
		return
	var mat := CanvasItemMaterial.new()
	match mode_upper:
		"ADD", "LINEAR_DODGE":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		"SUBTRACT":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		"MULTIPLY":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		"SCREEN":
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		_:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	rect.material = mat


func show_actor(actor_id: String, fade_in: float = 0.3) -> void:
	_tween_actor(actor_id, true, fade_in)


func hide_actor(actor_id: String, fade_out: float = 0.3) -> void:
	_tween_actor(actor_id, false, fade_out)


func set_actor_visibility(actor_id: String, visible: bool) -> void:
	var rect: TextureRect = _actor_rects.get(actor_id, null)
	if not rect:
		return
	rect.visible = visible
	rect.modulate.a = 1.0 if visible else 0.0


func _tween_actor(actor_id: String, show: bool, duration: float) -> void:
	var rect: TextureRect = _actor_rects.get(actor_id, null)
	if not rect:
		return
	var existing: Tween = _actor_tweens.get(actor_id, null)
	if existing and existing.is_valid():
		existing.kill()
	if show:
		rect.visible = true
		var t := create_tween()
		t.tween_property(rect, "modulate:a", 1.0, duration)
		_actor_tweens[actor_id] = t
	else:
		var t := create_tween()
		t.tween_property(rect, "modulate:a", 0.0, duration)
		t.tween_callback(func(): rect.visible = false)
		_actor_tweens[actor_id] = t


func get_actor_ids() -> Array:
	return _actor_rects.keys()


# ── Character slots (roster-aware composition) ─────────────────────

## Returns the manifest's character-slot geometry for the current scene:
## [{id, anchor:[nx,ny], scale, z, role}, ...]. Empty if the scene declares none.
func get_character_slots() -> Array:
	return _character_slots


## Fill character slots with crew figures. Each assignment is:
##   {slot_id: String, species_id: String, character_id: String, drift?: Dict}
## The figure is resolved from species_id via SpeciesFigureRegistry. A slot with
## no matching geometry or no resolvable/existing figure is skipped (graceful
## empty slot). Figures are added in ascending slot-z order so a higher-z slot
## (e.g. the captain) draws on top of lower-z slots (the crew behind them).
func set_character_slots(assignments: Array) -> void:
	if not _slot_layer:
		_build_layers()
	for child in _slot_layer.get_children():
		child.queue_free()
	_slot_rects.clear()
	_slot_assignments = assignments.duplicate(true)

	var ordered := assignments.duplicate()
	ordered.sort_custom(func(a, b): return _slot_z(a) < _slot_z(b))
	for a in ordered:
		_place_slot_figure(a)
	_layout_character_slots()


func _slot_def(slot_id: String) -> Dictionary:
	for s in _character_slots:
		if s is Dictionary and str(s.get("id", "")) == slot_id:
			return s
	return {}


func _slot_z(assignment: Dictionary) -> float:
	return float(_slot_def(str(assignment.get("slot_id", ""))).get("z", 0))


func _place_slot_figure(assignment: Dictionary) -> void:
	var slot_id: String = str(assignment.get("slot_id", ""))
	if _slot_def(slot_id).is_empty():
		return
	var figure_path: String = SpeciesFigureRegistry.get_figure_for(
		str(assignment.get("species_id", "")),
		str(assignment.get("character_id", "")))
	if figure_path.is_empty() or not ResourceLoader.exists(figure_path):
		return
	var tex := load(figure_path) as Texture2D
	if not tex:
		return
	var rect := TextureRect.new()
	rect.name = slot_id
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_layer.add_child(rect)
	_slot_rects[slot_id] = rect
	var drift = assignment.get("drift", null)
	if drift is Dictionary and not drift.is_empty():
		_apply_drift(rect, drift)


## Position every slot rect for the current stage size. The slot `anchor` is the
## FEET (bottom-center) landing point, normalized to the stage rect; `scale` is
## the figure height as a fraction of stage height. Recomputed on resize so a
## figure always stands on its intended ground point at any resolution.
func _layout_character_slots() -> void:
	if not _slot_layer:
		return
	var stage: Vector2 = size
	if stage.x <= 0.0 or stage.y <= 0.0:
		return
	for slot_id in _slot_rects:
		var rect: TextureRect = _slot_rects[slot_id]
		if not is_instance_valid(rect) or rect.texture == null:
			continue
		var sd := _slot_def(slot_id)
		var anchor: Array = sd.get("anchor", [0.5, 1.0])
		var nx: float = float(anchor[0]) if anchor.size() > 0 else 0.5
		var ny: float = float(anchor[1]) if anchor.size() > 1 else 1.0
		var scl: float = float(sd.get("scale", 0.8))
		var tex_size: Vector2 = rect.texture.get_size()
		var aspect: float = (tex_size.x / tex_size.y) if tex_size.y > 0.0 else 1.0
		var target_h: float = scl * stage.y
		var target_w: float = target_h * aspect
		rect.size = Vector2(target_w, target_h)
		# anchor = feet (bottom-center); shift to the rect's top-left.
		var feet: Vector2 = Vector2(nx * stage.x, ny * stage.y)
		rect.position = feet - Vector2(target_w * 0.5, target_h)


## Looping sine drift for parallax-style movement. Shared hook for the future
## enemy-layer parallax. params: {amplitude_px:[x,y], period:float}. No-op when
## amplitude is zero. (Slot layout overwrites position, so drift is only used by
## non-slot callers until the v2 parallax pass reconciles the two.)
func _apply_drift(rect: Control, params: Dictionary) -> void:
	var amp: Array = params.get("amplitude_px", [0, 0])
	var ax: float = float(amp[0]) if amp.size() > 0 else 0.0
	var ay: float = float(amp[1]) if amp.size() > 1 else 0.0
	if ax == 0.0 and ay == 0.0:
		return
	var period: float = maxf(0.5, float(params.get("period", 6.0)))
	var base: Vector2 = rect.position
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(rect, "position", base + Vector2(ax, ay), period * 0.5)
	t.tween_property(rect, "position", base - Vector2(ax, ay), period * 0.5)


# ── Ambient "living painting" motion ───────────────────────────────
#
# A TINY amount of scene-wide movement so a static illustration feels alive:
# each layer container drifts on a slow sine (foreground drifts more than the
# backdrop = subtle parallax), and the whole scene breathes via a slow Ken
# Burns scale swing. Motion is applied to the LAYER CONTAINERS, never the
# individual rects, so it never fights _layout_character_slots() (which owns
# each figure's position). An overscan zoom hides the letterbox edge the drift
# would otherwise reveal. Honors the Reduced Motion accessibility setting.

## Start (or restart) ambient motion for the current scene. No-op when Reduced
## Motion is on or the manifest disables it -- the stage stays perfectly still.
func _start_ambient_motion() -> void:
	_stop_ambient_motion()
	var tm := get_node_or_null("/root/ThemeManager")
	if tm and tm.has_method("is_reduced_animation_enabled") and tm.is_reduced_animation_enabled():
		_reset_layer_transforms()
		return
	var cfg: Dictionary = _manifest.get("ambient_motion", {})
	if not bool(cfg.get("enabled", true)):
		_reset_layer_transforms()
		return
	var overscan: float = maxf(1.0, float(cfg.get("overscan", DEFAULT_OVERSCAN)))
	var breathe: float = maxf(0.0, float(cfg.get("breathe", DEFAULT_BREATHE)))
	var breathe_period: float = maxf(1.0, float(cfg.get("breathe_period", DEFAULT_BREATHE_PERIOD)))
	var layer_cfg: Dictionary = cfg.get("layers", {})
	_ambient_active = true
	_refresh_ambient_pivots()
	# Depth-ordered drift amplitudes (screen px): backdrop moves least, the
	# foreground actors most. Differing periods desync the layers over time so
	# the parallax reads as organic rather than a mechanical lockstep sway.
	_apply_ambient_to_layer(_bg_layer, _drift_for(layer_cfg, "bg", Vector2(2, 1.5)),
		_period_for(layer_cfg, "bg", 22.0), overscan, breathe, breathe_period)
	_apply_ambient_to_layer(_slot_layer, _drift_for(layer_cfg, "slot", Vector2(4, 2)),
		_period_for(layer_cfg, "slot", 18.0), overscan, breathe, breathe_period)
	_apply_ambient_to_layer(_actor_layer, _drift_for(layer_cfg, "actor", Vector2(7, 3)),
		_period_for(layer_cfg, "actor", 15.0), overscan, breathe, breathe_period)
	_apply_ambient_to_layer(_fx_layer, _drift_for(layer_cfg, "fx", Vector2(6, 3)),
		_period_for(layer_cfg, "fx", 17.0), overscan, breathe, breathe_period)


func _drift_for(layer_cfg: Dictionary, key: String, def: Vector2) -> Vector2:
	var lc = layer_cfg.get(key, null)
	if lc is Dictionary and lc.has("drift"):
		var d: Array = lc.get("drift", [])
		if d.size() >= 2:
			return Vector2(float(d[0]), float(d[1]))
	return def


func _period_for(layer_cfg: Dictionary, key: String, def: float) -> float:
	var lc = layer_cfg.get(key, null)
	if lc is Dictionary and lc.has("period"):
		return maxf(1.0, float(lc.get("period", def)))
	return def


## Apply overscan + a looping drift + a looping breathe to one layer container.
## Drift oscillates position symmetrically around (0,0) within the overscan
## headroom; breathe swings scale between overscan and overscan+delta (its floor
## stays at overscan so headroom never vanishes mid-swing).
func _apply_ambient_to_layer(layer: Control, drift_amp: Vector2, drift_period: float,
		overscan: float, breathe: float, breathe_period: float) -> void:
	if not layer:
		return
	layer.scale = Vector2(overscan, overscan)
	# Start at +amp so the two-segment ping-pong loops seamlessly (its end
	# state equals its start state). A few px of initial offset is invisible.
	layer.position = drift_amp
	if drift_amp != Vector2.ZERO and drift_period > 0.0:
		var dt := create_tween().set_loops().bind_node(layer)
		dt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		dt.tween_property(layer, "position", -drift_amp, drift_period * 0.5)
		dt.tween_property(layer, "position", drift_amp, drift_period * 0.5)
		_ambient_tweens.append(dt)
	if breathe > 0.0 and breathe_period > 0.0:
		var bt := create_tween().set_loops().bind_node(layer)
		bt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var hi := Vector2(overscan + breathe, overscan + breathe)
		var lo := Vector2(overscan, overscan)
		bt.tween_property(layer, "scale", hi, breathe_period * 0.5)
		bt.tween_property(layer, "scale", lo, breathe_period * 0.5)
		_ambient_tweens.append(bt)


## Re-center every layer's scale pivot on the stage. Pivot is size/2, so it must
## follow stage resizes; the drift/breathe tweens (position/scale) are unaffected.
func _refresh_ambient_pivots() -> void:
	if not _ambient_active:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var c: Vector2 = size / 2.0
	for layer in [_bg_layer, _slot_layer, _actor_layer, _fx_layer]:
		if layer:
			layer.pivot_offset = c


func _stop_ambient_motion() -> void:
	for t in _ambient_tweens:
		if t and t.is_valid():
			t.kill()
	_ambient_tweens.clear()
	_ambient_active = false


## Return every layer to identity so a cleared/static stage isn't left zoomed
## or offset by a previous scene's ambient motion.
func _reset_layer_transforms() -> void:
	for layer in [_bg_layer, _slot_layer, _actor_layer, _fx_layer]:
		if layer:
			layer.scale = Vector2.ONE
			layer.position = Vector2.ZERO
			layer.pivot_offset = Vector2.ZERO


func clear() -> void:
	_stop_ambient_motion()
	for tween in _actor_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_actor_tweens.clear()
	_actor_rects.clear()
	_slot_rects.clear()
	_slot_assignments.clear()
	for layer in [_bg_layer, _slot_layer, _actor_layer, _fx_layer]:
		if not layer:
			continue
		for child in layer.get_children():
			child.queue_free()
	_reset_layer_transforms()
