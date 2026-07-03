extends Node

## SettingsManager — single source of truth for `user://options.cfg`.
##
## Owns the ConfigFile on disk, the in-memory cache, the boot-time apply, and the
## per-key apply on change. Replaces three previously-disconnected systems:
## the sectioned writes in `SettingsScreen.gd`, the flat `[options]` writes in
## `GameState.gd`, and the dead `AppOptions.gd`.
##
## Wiring contract:
##   - `_ready()` loads + migrates + applies. Everything below "is wired" by the
##     time any other autoload's `_ready()` runs (this autoload is registered
##     before `GameState`).
##   - Consumers read through typed getters (`is_auto_save_enabled()`, etc.) or
##     the generic `get_setting(section, key)`.
##   - UI writes via `set_setting(section, key, value)` — never touches the file
##     directly. The setter applies the change live, debounces the disk write,
##     and emits `setting_changed`.
##
## Layered defaults — `DEFAULTS` is the SSOT for both fallback reads and Reset.
##
## Migration — on first launch after this change ships, any legacy `[options]`
## section (from the old `GameState.save_options()`) is folded into the new
## sectioned format and erased. Idempotent: subsequent launches see no
## `[options]` section and skip the migration block.

const CONFIG_PATH := "user://options.cfg"
const LEGACY_SECTION := "options"

## Default values — single source for both load fallback and reset_to_defaults().
const DEFAULTS := {
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.8,
	},
	"display": {
		"fullscreen": false,
		"vsync_mode": 1,   # DisplayServer.VSYNC_ENABLED
		"ui_scale": 1.0,
	},
	"gameplay": {
		"auto_save": true,
		"show_tooltips": true,
		"show_fps": false,
		"screen_shake": true,
		"use_narrative_events": true,
		"table_size_ft": 3.0,  # physical table: 2.0 / 2.5 / 3.0 (Core Rules p.108)
	},
	"mobile": {
		"haptic_feedback": true,
		"touch_sensitivity": 1.0,
	},
}

## Maps legacy flat-section keys → [section, key] in the new sectioned schema.
## Used only during the one-time migration of `[options]` from the old
## `GameState.save_options()`. Keys not in this map (and not in DEFAULTS) are
## dropped during migration — see notes on dropped legacy keys below.
const LEGACY_KEY_MAP := {
	"music_volume": ["audio", "music_volume"],
	"sfx_volume":   ["audio", "sfx_volume"],
	"fullscreen":   ["display", "fullscreen"],
	"ui_scale":     ["display", "ui_scale"],
	"auto_save":    ["gameplay", "auto_save"],
	# Intentionally dropped during migration:
	#   tutorials_enabled  — handled by per-campaign GameSettings.gd
	#   enable_animations  — ThemeManager owns reduced_animation
	#   enable_combat_log  — no consumers; orphaned
}

const SAVE_DEBOUNCE_SECONDS := 0.1

signal setting_changed(section: String, key: String, value: Variant)

var _config := ConfigFile.new()
var _save_timer: Timer
var _fps_overlay: CanvasLayer
var _fps_label: Label


# ============ LIFECYCLE ============

func _ready() -> void:
	# Settings must apply even when the tree is paused (the SettingsOverlay
	# pauses the tree while the user adjusts sliders).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SECONDS
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)

	_load_with_migration()
	_apply_all()


# ============ LOAD / MIGRATE / SAVE ============

func _load_with_migration() -> void:
	var err := _config.load(CONFIG_PATH)
	if err == ERR_FILE_NOT_FOUND:
		# No file yet — defaults will apply via DEFAULTS lookup in get_setting().
		# File is created on first set_setting() (the disk write only happens
		# when a value diverges from defaults, which keeps the user dir clean).
		return
	if err != OK:
		push_warning("SettingsManager: failed to load %s (err=%d) — using defaults"
			% [CONFIG_PATH, err])
		return
	if not _config.has_section(LEGACY_SECTION):
		return

	# One-time migration: legacy `[options]/<flat_key>` → new `[<section>]/<key>`.
	# Sectioned value wins when both exist (the user touched the UI more
	# recently than GameState would have touched the flat section).
	var migrated := false
	for legacy_key in _config.get_section_keys(LEGACY_SECTION):
		var dest = LEGACY_KEY_MAP.get(legacy_key, null)
		if dest is Array and dest.size() == 2:
			var sec: String = dest[0]
			var new_key: String = dest[1]
			if not _config.has_section_key(sec, new_key):
				_config.set_value(sec, new_key,
					_config.get_value(LEGACY_SECTION, legacy_key))
		migrated = true

	_config.erase_section(LEGACY_SECTION)
	if migrated:
		_config.save(CONFIG_PATH)


func _save_now() -> void:
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save %s (err=%d)" % [CONFIG_PATH, err])


# ============ PUBLIC API ============

## Read a setting, falling back to DEFAULTS when the key is absent on disk.
func get_setting(section: String, key: String) -> Variant:
	var section_defaults: Dictionary = DEFAULTS.get(section, {})
	var default_value: Variant = section_defaults.get(key)
	return _config.get_value(section, key, default_value)


## Write a setting, apply it live, debounce the disk write, emit signal.
func set_setting(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	_apply_one(section, key)
	_save_timer.start()
	setting_changed.emit(section, key, value)


## Reset every value to DEFAULTS, apply, save immediately. Emits one broad
## `setting_changed("", "", null)` so UI listeners can rebuild from scratch.
func reset_to_defaults() -> void:
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			_config.set_value(section, key, DEFAULTS[section][key])
	_apply_all()
	_save_now()
	setting_changed.emit("", "", null)


# ============ APPLY ============

func _apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_fps()


## Per-key dispatch — keeps live-apply cheap (no need to re-apply audio when
## a gameplay toggle flips).
func _apply_one(section: String, key: String) -> void:
	match section:
		"audio":
			_apply_audio()
		"display":
			match key:
				"fullscreen", "vsync_mode":
					_apply_display_window_only()
				"ui_scale":
					_apply_ui_scale()
		"gameplay":
			if key == "show_fps":
				_apply_fps()


func _apply_audio() -> void:
	# Existing bus layout has only "Master" — Music/SFX bus lookups return -1
	# until those buses are added in the editor, and the guard below skips them.
	# Saved Music/SFX values persist across that change with no migration needed.
	var bus_pairs := [
		["Master", get_master_volume()],
		["Music",  get_music_volume()],
		["SFX",    get_sfx_volume()],
	]
	for pair in bus_pairs:
		var bus_name: String = pair[0]
		var lin: float = pair[1]
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(lin))


func _apply_display() -> void:
	_apply_display_window_only()
	_apply_ui_scale()


func _apply_display_window_only() -> void:
	if not OS.has_feature("pc"):
		return
	if Engine.is_editor_hint():
		return
	# Idempotent flip: only set the mode when the actual window state diverges
	# from the user's stored preference. This preserves the MAXIMIZED window
	# state that GameState restores from `user://window.ini` at boot (BUG-100) —
	# we never want to "fix" the user's window to "windowed default" just
	# because the fullscreen toggle happens to be off.
	var current_mode := DisplayServer.window_get_mode()
	if is_fullscreen() and current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not is_fullscreen() and current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(get_vsync_mode())


func _apply_ui_scale() -> void:
	# Godot 4.6 runtime stretch knob: get_tree().root.content_scale_factor.
	var tree := get_tree()
	if not (tree and tree.root):
		return
	# The project uses canvas_items stretch on a SQUARE 1080x1080 base (chosen for
	# dual orientation). With `expand`, the on-screen scale = min(window.x,
	# window.y) / 1080 — so in PORTRAIT the small window WIDTH constrains it to
	# ~0.4x and text renders tiny (a 16px font -> ~6px). We CANCEL that square-base
	# stretch (x 1080/short_axis) and apply ONE consistent EFFECTIVE scale instead,
	# so text is the same comfortable PHYSICAL size in portrait AND landscape, and
	# resizing changes how much content fits (not the text size).
	#  - TARGET_EFFECTIVE 1.12 = verified layout-safe (in landscape it yields
	#    content_scale ~1.15, which the tightest screen/MainMenu tolerates; ~1.2+
	#    starts to collide).
	#  - ui_scale = the user's Settings slider, relative to that baseline.
	#  - dpi_scale = hiDPI mobile density (1.0 on desktop) for consistent physical
	#    size across screen densities.
	const TARGET_EFFECTIVE := 1.12
	const STRETCH_BASE := 1080.0  # project.godot viewport_width/height (square)
	var win := Vector2(DisplayServer.window_get_size())
	var short_axis: float = minf(win.x, win.y)
	if short_axis <= 0.0:
		short_axis = STRETCH_BASE
	var stretch_cancel: float = STRETCH_BASE / short_axis
	tree.root.content_scale_factor = TARGET_EFFECTIVE * get_ui_scale() * _dpi_scale() * stretch_cancel
	# Recompute on every resize/rotation so the effective scale stays constant as
	# the short axis (and thus the square-base stretch) changes. Idempotent connect.
	if not tree.root.size_changed.is_connected(_apply_ui_scale):
		tree.root.size_changed.connect(_apply_ui_scale)


## OS display scale for the main window's screen (single source: ResponsiveManager
## when present, else DisplayServer directly so this is robust at boot before RM).
## 1.0 on platforms that don't report it (Windows desktop).
func _dpi_scale() -> float:
	var rm := get_node_or_null("/root/ResponsiveManager")
	var s: float = DisplayServer.screen_get_scale()
	if rm and rm.has_method("get_screen_scale"):
		s = rm.get_screen_scale()
	return s if s > 0.0 else 1.0


# ============ FPS COUNTER OVERLAY ============

func _apply_fps() -> void:
	if is_fps_visible():
		_ensure_fps_overlay()
		if _fps_overlay:
			_fps_overlay.visible = true
	else:
		if _fps_overlay:
			_fps_overlay.visible = false


func _ensure_fps_overlay() -> void:
	if _fps_overlay:
		return
	# Layer 95 sits above NotificationManager (90) and below
	# LoadingScreen (99) / TransitionManager (100), so the counter hides
	# correctly under modal screens. See CLAUDE.md "CanvasLayer Layering
	# Convention".
	_fps_overlay = CanvasLayer.new()
	_fps_overlay.layer = 95
	_fps_overlay.name = "__FPSCounterOverlay"
	add_child(_fps_overlay)

	_fps_label = Label.new()
	_fps_label.text = "FPS: --"
	_fps_label.position = Vector2(8, 8)
	_fps_label.add_theme_color_override("font_color", Color("#10B981"))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 2)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_overlay.add_child(_fps_label)


func _process(_delta: float) -> void:
	if _fps_label and _fps_overlay and _fps_overlay.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# ============ HAPTICS HELPER ============

## Consumers should call this instead of `Input.vibrate_handheld()` directly.
## The check + platform guard live here so individual call sites stay one-liners.
func vibrate(duration_ms: int = 50) -> void:
	if not is_haptic_enabled():
		return
	if not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(duration_ms)


# ============ TYPED CONVENIENCE GETTERS ============
# (Consumers prefer these over the generic get_setting so the call site reads
#  as "is_auto_save_enabled()" rather than 'get_setting("gameplay","auto_save")'.)

func get_master_volume() -> float:
	return get_setting("audio", "master_volume")

func get_music_volume() -> float:
	return get_setting("audio", "music_volume")

func get_sfx_volume() -> float:
	return get_setting("audio", "sfx_volume")

func is_fullscreen() -> bool:
	return get_setting("display", "fullscreen")

func get_vsync_mode() -> int:
	return get_setting("display", "vsync_mode")

func get_ui_scale() -> float:
	return get_setting("display", "ui_scale")

func is_auto_save_enabled() -> bool:
	return get_setting("gameplay", "auto_save")

func are_tooltips_enabled() -> bool:
	return get_setting("gameplay", "show_tooltips")

func is_fps_visible() -> bool:
	return get_setting("gameplay", "show_fps")

func is_screen_shake_enabled() -> bool:
	return get_setting("gameplay", "screen_shake")

func are_narrative_events_enabled() -> bool:
	return get_setting("gameplay", "use_narrative_events")

func get_table_size_ft() -> float:
	## Player's physical table size: 2.0 / 2.5 / 3.0 ft (Core Rules p.108)
	return float(get_setting("gameplay", "table_size_ft"))

func is_haptic_enabled() -> bool:
	return get_setting("mobile", "haptic_feedback")

func get_touch_sensitivity() -> float:
	return get_setting("mobile", "touch_sensitivity")
