## SceneAtmosphereLayer — sibling of SceneStage that renders ambient particle
## atmosphere driven by world traits or art_tag context. One GPUParticles2D
## per active ambient effect (only one ambient at a time per layer in v1);
## additional CPUParticles2D nodes are spawned for one-shot event bursts.
##
## Design source: docs/research/scene-stage-atmosphere.md.
## SSOT data source: AtmosphereCatalog → data/atmosphere/world_trait_atmosphere.json.
##
## ── Public API ───────────────────────────────────────────────────────────
##   set_atmosphere(effect_id: String, intensity := 1.0)
##   set_atmosphere_for_world_traits(traits: Array, art_tag := "")
##   clear_atmosphere()
##   add_event_effect(effect_id: String, position: Vector2)   # one-shot CPUParticles2D
##
## ── Reduced Motion gate ──────────────────────────────────────────────────
## Honors ThemeManager.is_reduced_animation_enabled() (same gate the
## SceneStage ambient drift uses). When enabled, set_atmosphere is a no-op
## and any active emitter is paused. Re-querying happens on every set call,
## so toggling Reduced Motion mid-screen Just Works.
##
## ── Texture fallback ─────────────────────────────────────────────────────
## Each effect declares a `texture_path` in the JSON pointing at the
## production PNG. Until those ship, this layer falls back to a procedurally
## generated radial-falloff circle (snow/dust/ember) or soft blob (fog/smoke).
## The procedural fallback is cached per-effect so we don't pay the cost twice.
##
## Path-loaded — no class_name.
extends Control

const AtmosphereCatalog = preload(
	"res://src/ui/screens/narrative/AtmosphereCatalog.gd")

const PROC_TEX_SIZE := 48

# Per-effect-id ambient entries keyed by effect id; v1 only one ambient at a
# time but the dict supports future stacking. Each entry is
# {"node": GPUParticles2D, "cfg": Dictionary} so the resize handler can
# re-position by reading the same emission_band config without rebinding.
var _ambient_nodes: Dictionary = {}
var _current_effect_id: String = ""
var _current_intensity: float = 0.0
var _texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Clip particles to the illustration frame — without this, snow that
	# emits at the top "falls" past the panel container into the narrative
	# text below. ColorRect parent does this implicitly; we don't, so:
	clip_contents = true
	# One resize handler walks all active emitters. We avoid rebinding per
	# emitter because Godot 4.6's connect() dedup compares method-on-target,
	# not the bound args, so per-emitter binds error as "already connected".
	resized.connect(_on_self_resized)


## Pick an effect by traits/art_tag and activate it. Empty result or
## effect == "none" clears the layer.
func set_atmosphere_for_world_traits(traits: Array, art_tag: String = "") -> void:
	var resolved: Dictionary = AtmosphereCatalog.resolve(traits, art_tag)
	if resolved.is_empty():
		clear_atmosphere()
		return
	var effect_id: String = String(resolved.get("effect", "none"))
	var intensity: float = float(resolved.get("intensity", 1.0))
	if effect_id == "none" or effect_id.is_empty():
		clear_atmosphere()
		return
	set_atmosphere(effect_id, intensity)


## Activate an effect by id. Tears down any previous ambient. Idempotent for
## same-effect-same-intensity calls.
func set_atmosphere(effect_id: String, intensity: float = 1.0) -> void:
	if _is_reduced_motion():
		clear_atmosphere()
		return
	if effect_id == _current_effect_id and is_equal_approx(intensity, _current_intensity):
		return
	_teardown_ambient()
	var cfg: Dictionary = AtmosphereCatalog.get_effect_config(effect_id)
	if cfg.is_empty():
		push_warning("SceneAtmosphereLayer: unknown effect '%s'" % effect_id)
		return
	var node := _build_gpu_particles(effect_id, cfg, intensity)
	if node == null:
		return
	add_child(node)
	_ambient_nodes[effect_id] = {"node": node, "cfg": cfg}
	_current_effect_id = effect_id
	_current_intensity = intensity


func clear_atmosphere() -> void:
	_teardown_ambient()
	_current_effect_id = ""
	_current_intensity = 0.0


## One-shot CPUParticles2D burst — used for event-triggered effects (an
## ember spray, a wreckage smoke puff). Lives separately from ambient so
## bursts don't clobber the steady-state layer. Self-frees on `finished`.
func add_event_effect(effect_id: String, world_position: Vector2) -> void:
	if _is_reduced_motion():
		return
	var cfg: Dictionary = AtmosphereCatalog.get_effect_config(effect_id)
	if cfg.is_empty():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = int(cfg.get("amount", 30))
	p.lifetime = float(cfg.get("lifetime", 2.0))
	p.position = world_position
	p.spread = float(cfg.get("spread_deg", 25.0))
	p.gravity = Vector2(0, float(cfg.get("gravity_y", -40.0)))
	p.scale_amount_min = float(cfg.get("scale_min", 0.5))
	p.scale_amount_max = float(cfg.get("scale_max", 1.0))
	p.color = _ramp_mid(cfg)
	p.texture = _resolve_texture(effect_id, cfg)
	if bool(cfg.get("additive", false)):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	add_child(p)
	p.finished.connect(p.queue_free)


# ── Internal builders ────────────────────────────────────────────────────

func _build_gpu_particles(effect_id: String, cfg: Dictionary, intensity: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "Ambient_%s" % effect_id
	p.amount = max(1, int(cfg.get("amount", 100)))
	p.amount_ratio = clampf(intensity, 0.0, 4.0)
	p.lifetime = float(cfg.get("lifetime", 6.0))
	p.preprocess = float(cfg.get("preprocess", 0.0))
	p.fixed_fps = 30
	p.local_coords = false
	p.one_shot = false
	p.emitting = true
	# visibility_rect tells the renderer this emitter has scene-wide
	# coverage; without it, particles vanish when the emitter origin
	# scrolls off-screen even though the particles themselves are visible.
	p.visibility_rect = Rect2(-200, -200, 4000, 4000)
	p.process_material = _build_process_material(cfg)
	p.texture = _resolve_texture(effect_id, cfg)
	if bool(cfg.get("additive", false)):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	# Position the emitter so its emission box fills the illustration
	# frame. Re-applied on resize via _on_self_resized walking _ambient_nodes
	# (no per-emitter bind — Godot 4.6 connect-dedup compares method-on-target,
	# not args, so per-emitter binds would error as "already connected").
	_position_emitter(p, cfg)
	return p


func _build_process_material(cfg: Dictionary) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0.0, float(cfg.get("gravity_y", 0.0)), 0.0)
	m.spread = float(cfg.get("spread_deg", 25.0))
	m.scale_min = float(cfg.get("scale_min", 0.5))
	m.scale_max = float(cfg.get("scale_max", 1.0))
	# Direction follows gravity sign: positive y = falling, negative = rising.
	var dir_y: float = 1.0 if float(cfg.get("gravity_y", 0.0)) >= 0.0 else -1.0
	m.direction = Vector3(0.0, dir_y, 0.0)
	m.initial_velocity_min = 6.0
	m.initial_velocity_max = 18.0
	# Color: top → bottom across lifetime. The JSON encodes the START
	# (newly spawned) and END (about to expire) colors.
	var color_grad := Gradient.new()
	color_grad.set_color(0, _array_to_color(cfg.get("color_top", [1, 1, 1, 1])))
	color_grad.set_color(1, _array_to_color(cfg.get("color_bottom", [1, 1, 1, 0])))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_grad
	m.color_ramp = color_ramp
	# Emission shape: most ambient effects want a box spanning the scene.
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1600, 30, 1)
	return m


func _position_emitter(node: GPUParticles2D, cfg: Dictionary) -> void:
	var band: String = String(cfg.get("emission_band", "top"))
	var rect := get_rect()
	var w: float = max(rect.size.x, 100.0)
	var h: float = max(rect.size.y, 100.0)
	match band:
		"top":
			node.position = Vector2(w * 0.5, -20.0)
			var mat: ParticleProcessMaterial = node.process_material
			if mat:
				mat.emission_box_extents = Vector3(w * 0.6, 20.0, 1.0)
		"bottom":
			node.position = Vector2(w * 0.5, h + 20.0)
			var mat2: ParticleProcessMaterial = node.process_material
			if mat2:
				mat2.emission_box_extents = Vector3(w * 0.6, 20.0, 1.0)
		"full":
			node.position = Vector2(w * 0.5, h * 0.5)
			var mat3: ParticleProcessMaterial = node.process_material
			if mat3:
				mat3.emission_box_extents = Vector3(w * 0.5, h * 0.5, 1.0)
		"point":
			node.position = Vector2(w * 0.5, h * 0.5)
		_:
			node.position = Vector2(w * 0.5, 0.0)


func _on_self_resized() -> void:
	# Reposition every active ambient emitter using the cfg we cached when
	# we built it. One handler, multiple emitters — no per-emitter connects.
	for key in _ambient_nodes.keys():
		var entry: Dictionary = _ambient_nodes[key]
		var node: GPUParticles2D = entry.get("node")
		var cfg: Dictionary = entry.get("cfg", {})
		if node and is_instance_valid(node):
			_position_emitter(node, cfg)


# ── Texture resolution + procedural fallback ─────────────────────────────

func _resolve_texture(effect_id: String, cfg: Dictionary) -> Texture2D:
	if _texture_cache.has(effect_id):
		return _texture_cache[effect_id]
	var path: String = String(cfg.get("texture_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_texture_cache[effect_id] = res
			return res
	# Procedural fallback — soft white circle with radial falloff. Works for
	# every effect type: tinting is done via the color ramp on the material.
	var img := Image.create(PROC_TEX_SIZE, PROC_TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var center := Vector2(PROC_TEX_SIZE * 0.5, PROC_TEX_SIZE * 0.5)
	var radius := PROC_TEX_SIZE * 0.5
	for y in PROC_TEX_SIZE:
		for x in PROC_TEX_SIZE:
			var d := Vector2(x, y).distance_to(center)
			var t := clampf(1.0 - (d / radius), 0.0, 1.0)
			# Soft falloff — t^2 makes the edges fade faster than the core.
			var a := t * t
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[effect_id] = tex
	return tex


# ── Small helpers ────────────────────────────────────────────────────────

func _teardown_ambient() -> void:
	for key in _ambient_nodes.keys():
		var entry: Dictionary = _ambient_nodes[key]
		var node: Node = entry.get("node")
		if node and is_instance_valid(node):
			node.queue_free()
	_ambient_nodes.clear()


func _is_reduced_motion() -> bool:
	var tm := get_node_or_null("/root/ThemeManager")
	if tm and tm.has_method("is_reduced_animation_enabled"):
		return bool(tm.is_reduced_animation_enabled())
	return false


func _array_to_color(value) -> Color:
	if value is Array and value.size() >= 3:
		var a: float = float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	return Color(1, 1, 1, 1)


func _ramp_mid(cfg: Dictionary) -> Color:
	var a := _array_to_color(cfg.get("color_top", [1, 1, 1, 1]))
	var b := _array_to_color(cfg.get("color_bottom", [1, 1, 1, 1]))
	return a.lerp(b, 0.5)


# Currently active effect id (for tests + debug only).
func get_current_effect() -> String:
	return _current_effect_id


func get_current_intensity() -> float:
	return _current_intensity
