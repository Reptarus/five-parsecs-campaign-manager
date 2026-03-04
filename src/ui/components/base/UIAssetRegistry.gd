extends RefCounted
class_name UIAssetRegistry

## Central registry for UI/UX image assets (assets/UI-UX-Images/).
## Follows the IconRegistry pattern: class_name + static methods + cache + ResourceLoader guard.
##
## Usage:
##   var clock_tex = UIAssetRegistry.get_clock("cyan", 6, 3)
##   var panel_tex = UIAssetRegistry.get_panel("border", "blue", "15x15")
##   var hull_tex  = UIAssetRegistry.get_resource_tracker("hull", 10, 7)

const BASE := "res://assets/UI-UX-Images/"

# ── Clock volume routing ────────────────────────────────────────────────
# Vol 1 (ranges 2-6): all 6 colors — dir: "Sci-Fi Circular Clocks {Color}/"
# Vol 2 (ranges 8-20): cyan, green, red — dir: "Sci-Fi Circular Clocks Volume 2 {Color}/"
# Vol 4 (ranges 8-20): blue, violet, yellow — dir: "Sci-Fi Circular Clocks Volume 4 {Color}/"
const _CLOCK_VOL2_COLORS: PackedStringArray = ["cyan", "green", "red"]
const _CLOCK_VOL4_COLORS: PackedStringArray = ["blue", "violet", "yellow"]
const _CLOCK_VOL1_RANGES: PackedInt32Array = [2, 3, 4, 5, 6]
const _CLOCK_VOL2_RANGES: PackedInt32Array = [8, 10, 12, 15, 20]

# ── Terrain directory mapping ───────────────────────────────────────────
# normalized name -> { dir_suffix (plural), file_infix (singular) }
const _TERRAIN_MAP := {
	"dryland":  {"dir": "drylands", "file": "dryland"},
	"river":    {"dir": "rivers",   "file": "river"},
	"coastal":  {"dir": "costal",   "file": "costal"},
	"costal":   {"dir": "costal",   "file": "costal"},
}

# ── Building variant counts per footprint ───────────────────────────────
const _BUILDING_VARIANTS := {
	"1x1": 10, "2x2": 5, "3x3": 4, "4x4": 3, "5x5": 2,
}

# ── Spelling normalization (asset directory typos) ──────────────────────
const _SPELLING := {
	"oxygen": "oxigen",
	"coastal": "costal",
}

# ── Status type casing overrides (multi-word / all-caps) ────────────────
const _STATUS_OVERRIDES := {
	"ok": "OK",
	"co2": "CO2",
	"ai meltdown": "AI meltdown",
	"hull breach": "Hull breach",
	"radio signal": "Radio signal",
	"microbe outbreak": "Microbe outbreak",
	"dangerous substance": "Dangerous substance",
	"deadly environment": "Deadly environment",
}

static var _cache: Dictionary = {}

# ═════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════

# ── Circular Clocks ─────────────────────────────────────────────────────

## Returns a clock texture showing current/max_val in the given color.
## Colors: blue, cyan, green, red, violet, yellow.
## Vol 1 ranges: 2-6.  Vol 2/4 ranges: 8, 10, 12, 15, 20.
static func get_clock(color: String, max_val: int, current: int) -> Texture2D:
	color = color.to_lower()
	current = clampi(current, 0, max_val)
	var vol_prefix: Variant = _clock_volume_prefix(color, max_val)
	if vol_prefix == null:
		return null
	var dir_name := "Sci-Fi Circular Clocks %s%s" % [str(vol_prefix), _ucfirst(color)]
	var file_name := "counter-%s-0to%d-%d.png" % [color, max_val, current]
	return _load_cached(BASE + "Circular-Clocks/" + dir_name + "/" + file_name)

## Returns the best-fit clock max range for a target value.
## Picks the smallest available range that is >= target.
static func pick_clock_range(target: int) -> int:
	var all_ranges: Array[int] = [2, 3, 4, 5, 6, 8, 10, 12, 15, 20]
	for r: int in all_ranges:
		if r >= target:
			return r
	return 20

# ── Resource Trackers ───────────────────────────────────────────────────

## Returns a resource gauge texture. resource: hull/fuel/energy/munition/oxygen/radiation.
## scale: 5 or 10. current: 0..scale.
static func get_resource_tracker(resource: String, scale: int, current: int) -> Texture2D:
	resource = _normalize_spelling(resource.to_lower())
	current = clampi(current, 0, scale)
	var file_name := "%s-%d-%d.png" % [resource, scale, current]
	return _load_cached(BASE + "resource-trackers/" + resource + "/" + file_name)

# ── Panels ──────────────────────────────────────────────────────────────

## Returns a sci-fi panel texture. style: "" (solid), "border", "transparent".
## color: blue/cyan/green/orange/red. size: "10x10", "15x15", etc.
static func get_panel(style: String, color: String, size: String) -> Texture2D:
	var prefix := _panel_variant_prefix(style)
	var file_name := "Panel - %s%s - %s.png" % [prefix, _ucfirst(color), size]
	return _load_cached(BASE + "panels/VTT-SciFi-User-Interface-Panels/" + file_name)

## Returns a grid-overlaid panel texture. Same params as get_panel().
static func get_grid_panel(style: String, color: String, size: String) -> Texture2D:
	var prefix := _panel_variant_prefix(style)
	var file_name := "Panel - Grid - %s%s - %s.png" % [prefix, _ucfirst(color), size]
	var path := BASE + "panels/VTT-SciFi-User-Interface-Panels-Grid/" + file_name
	var tex := _load_cached(path)
	# Blue plain grid panels have no .png extension (known asset anomaly)
	if tex == null and style.to_lower() == "" and color.to_lower() == "blue":
		tex = _load_cached(path.left(path.length() - 4))
	return tex

# ── Tokens ──────────────────────────────────────────────────────────────

## Returns a shape token. shape: circle/square/triangle/hex/penta/target/target-alt/
## shelter/objective/ammunition/energy/food/fuel/hospital/mechanics.
## color: blue/cyan/green/grey/orange/red/violet/purple/yellow.
static func get_token(shape: String, color: String) -> Texture2D:
	color = color.to_lower()
	var file_name := "token-%s-%s.png" % [shape.to_lower(), color]
	var path := BASE + "tokens/tokens/" + file_name
	var tex := _load_cached(path)
	# 6 triangle tokens have truncated filename: oken-triangle-{color}.png
	if tex == null and shape.to_lower() == "triangle":
		tex = _load_cached(BASE + "tokens/tokens/oken-triangle-%s.png" % color)
	return tex

## Returns a numbered token (0-13). color: blue/cyan/green/purple/red/yellow.
static func get_number_token(number: int, color: String) -> Texture2D:
	color = color.to_lower()
	var path := BASE + "tokens/tokens/token-number-%d-%s.png" % [number, color]
	var tex := _load_cached(path)
	# Numbers 8-13 use "greeen" (triple-e) for green color
	if tex == null and color == "green" and number >= 8:
		tex = _load_cached(BASE + "tokens/tokens/token-number-%d-greeen.png" % number)
	return tex

# ── Status Tokens ───────────────────────────────────────────────────────

## Returns a status token icon. shape: circle/hexagon/square.
## severity: green/grey/red/yellow. status_type: OK/Warning/Medical/Offline/Fire/etc.
static func get_status_token(shape: String, severity: String, status_type: String) -> Texture2D:
	var s := _ucfirst(shape)
	var c := _ucfirst(severity)
	var t := _normalize_status_type(status_type)
	var dir_name := "Sci-Fi Status Tokens - %s" % s
	var file_name := "Sci-Fi Status Token - %s - %s - %s (1x1).png" % [s, c, t]
	return _load_cached(BASE + "status-tokens/" + dir_name + "/" + file_name)

# ── Tactical Map — Buildings ────────────────────────────────────────────

## Returns a building footprint texture. grid_size: "1x1".."5x5". variant: 1..N.
static func get_tactical_building(grid_size: String, variant: int) -> Texture2D:
	var file_name := "building-%s-%d.png" % [grid_size, variant]
	return _load_cached(BASE + "tactical-maps/tactical-map-buildings/" + file_name)

## Returns the number of building variants available for a given footprint size.
static func get_building_variant_count(grid_size: String) -> int:
	return _BUILDING_VARIANTS.get(grid_size, 0)

# ── Tactical Map — Terrain Backgrounds ──────────────────────────────────

## Returns a terrain background map. terrain_type: dryland/river/coastal.
## variant: 1-5. grid_overlay: true for grid-square overlay version.
static func get_tactical_terrain(terrain_type: String, variant: int, grid_overlay: bool = false) -> Texture2D:
	var info: Dictionary = _TERRAIN_MAP.get(terrain_type.to_lower(), {})
	if info.is_empty():
		return null
	var grid_part := "-grid-square" if grid_overlay else ""
	var file_name := "tactical-map-%s%s-%d.png" % [info["file"], grid_part, variant]
	return _load_cached(BASE + "tactical-maps/tactical-map-%s/" % info["dir"] + file_name)

## Returns a radiation zone overlay. color: red/yellow. size: "2x2".."6x6".
static func get_tactical_radiation(color: String, size: String) -> Texture2D:
	var file_name := "radiation-%s-%s.png" % [color.to_lower(), size]
	return _load_cached(BASE + "tactical-maps/tactical-map-radiation/" + file_name)

## Returns a base tactical map (empty or grid). Used as battlefield background.
static func get_tactical_base(grid: bool = false, transparent: bool = false) -> Texture2D:
	var name_part := "grid-square" if grid else "empty"
	var trans_part := "-transparent" if transparent else ""
	return _load_cached(BASE + "tactical-maps/tactical-map-%s%s.png" % [name_part, trans_part])

# ── Danger Area Tokens ──────────────────────────────────────────────────

## Returns a hazard area overlay. hazard_type: biohazard/chemical/combat-gas/emp/fire/
## gravitational-anomaly/minefield/nanites/radiation-red/radiation-yellow.
## size: "2x2".."7x7".
static func get_danger_area(hazard_type: String, size: String) -> Texture2D:
	return _load_cached(BASE + "tokens/Danger Area Tokens/%s-%s.png" % [hazard_type.to_lower(), size])

# ── Mechas ──────────────────────────────────────────────────────────────

## Returns a mecha sprite. mecha_type: typeA1/typeA2/typeA3. color: cyan/green/red.
static func get_mecha(mecha_type: String, color: String) -> Texture2D:
	var file_name := "mecha-%s-%s.png" % [mecha_type.to_lower(), color.to_lower()]
	return _load_cached(BASE + "tactical-maps/tactical-map-mechas/" + file_name)

# ═════════════════════════════════════════════════════════════════════════
# INTERNAL HELPERS
# ═════════════════════════════════════════════════════════════════════════

static func _load_cached(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if tex:
		_cache[path] = tex
	return tex

static func _ucfirst(s: String) -> String:
	if s.is_empty():
		return s
	return s[0].to_upper() + s.substr(1)

static func _normalize_spelling(s: String) -> String:
	return _SPELLING.get(s, s)

static func _normalize_status_type(s: String) -> String:
	var key := s.to_lower()
	if _STATUS_OVERRIDES.has(key):
		return _STATUS_OVERRIDES[key]
	return _ucfirst(s)

static func _panel_variant_prefix(style: String) -> String:
	match style.to_lower():
		"border":
			return "Border - "
		"transparent":
			return "Transparent - "
		_:
			return ""

static func _clock_volume_prefix(color: String, max_val: int):
	# Vol 1: ranges 2-6, all colors
	if max_val in _CLOCK_VOL1_RANGES:
		return ""
	# Vol 2: ranges 8-20, cyan/green/red
	if max_val in _CLOCK_VOL2_RANGES:
		if color in _CLOCK_VOL2_COLORS:
			return "Volume 2 "
		if color in _CLOCK_VOL4_COLORS:
			return "Volume 4 "
	# Unknown color+range combo
	return null
