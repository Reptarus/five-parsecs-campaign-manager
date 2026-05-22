## SceneStage - composes a multi-layer scene from a JSON manifest.
##
## Loads `data/scenes/<id>.json` (produced by `scripts/psd_extract.py`) and
## renders bg + actors + fx as stacked TextureRects. All extracted layers are
## canvas-sized PNGs with position baked into alpha, so the composer just
## stacks same-sized rects with shared anchors. Actors can be shown/hidden
## individually for scene-variant composition (Six Ages / KoDP style).
##
## Public API:
##   set_scene(id_or_path: String)            - load + populate
##   show_actor(actor_id, fade_in: float)     - fade actor in
##   hide_actor(actor_id, fade_out: float)    - fade actor out
##   set_actor_visibility(actor_id, visible)  - instant
##   clear()                                  - drop all children
##   get_actor_ids() -> Array[String]
##
## Path-loaded (no class_name) to keep load order clean. Extend Control so
## the parent can size it freely; TextureRects fill the rect with
## STRETCH_KEEP_ASPECT_CENTERED so the canvas aspect is preserved.
extends Control

const MANIFEST_DIR := "res://data/scenes/"

var _scene_id: String = ""
var _manifest: Dictionary = {}
var _bg_layer: Control = null
var _actor_layer: Control = null
var _fx_layer: Control = null
var _actor_rects: Dictionary = {}  # actor_id -> TextureRect
var _actor_tweens: Dictionary = {}  # actor_id -> Tween


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


func clear() -> void:
	for tween in _actor_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_actor_tweens.clear()
	_actor_rects.clear()
	for layer in [_bg_layer, _actor_layer, _fx_layer]:
		if not layer:
			continue
		for child in layer.get_children():
			child.queue_free()
