extends RefCounted
## NOTE: intentionally NO class_name — referenced via preload() from
## WorldPhaseController so a fresh add can't hit the Godot 4.6 global-class
## registration-timing parse error ("Identifier not declared in current scope").

## Renders a flavor/law-focused "World Briefing" for the CURRENT world into a
## VBoxContainer. Used to fill the World-Phase empty space with contextual,
## rules-grounded planet info generated at planet creation.
##
## The distinctive part vs PlanetDetailBuilder: each world trait is shown WITH its
## rules meaning + category (Core Rules pp.72-75, data/world_traits.json) — so the
## player sees WHAT "Invasion Risk" or "Heavily Enforced" actually does, not just
## the label. Traits not present in the table (legacy/other generation) degrade
## gracefully to a bare name. Empty sections are skipped.
##
## Caller responsibilities (mirrors PlanetDetailBuilder):
##   - Provide a non-null `planet` (PlanetDataManager.PlanetData). Does NOT guard null.
##   - Provide a `vbox` already parented in the scene tree.

const UIColorsClass := preload("res://src/ui/components/base/UIColors.gd")
const TRAITS_PATH := "res://data/world_traits.json"

# Lazy static cache: id AND lowercased name -> {name, description, category}.
static var _trait_lookup: Dictionary = {}
static var _traits_loaded: bool = false


static func _load_traits() -> void:
	if _traits_loaded:
		return
	_traits_loaded = true
	if not FileAccess.file_exists(TRAITS_PATH):
		return
	var f := FileAccess.open(TRAITS_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or not parsed.has("world_traits"):
		return
	for entry in parsed["world_traits"]:
		if not (entry is Dictionary):
			continue
		var rec := {
			"name": str(entry.get("name", "")),
			"description": str(entry.get("description", "")),
			"category": str(entry.get("category", "")),
		}
		var id_key: String = str(entry.get("id", "")).to_lower()
		if id_key != "":
			_trait_lookup[id_key] = rec
		var name_key: String = str(entry.get("name", "")).to_lower()
		if name_key != "":
			_trait_lookup[name_key] = rec


## Category -> accent color so law / war / battlefield read at a glance.
static func _category_color(category: String) -> Color:
	match category:
		"law":
			return UIColorsClass.COLOR_AMBER
		"war":
			return UIColorsClass.COLOR_RED
		"battlefield":
			return UIColorsClass.COLOR_CYAN
		"economy", "trade":
			return UIColorsClass.COLOR_EMERALD
		_:
			return UIColorsClass.COLOR_PURPLE


static func build_into(vbox: VBoxContainer, planet: Object) -> void:
	if not vbox or not planet:
		return
	_load_traits()

	# Header + basic law/flavor facts
	vbox.add_child(_section_header("WORLD BRIEFING: %s" % str(planet.name)))
	var type_label: String = str(planet.type_name if planet.type_name else planet.type)
	if type_label.strip_edges() != "":
		vbox.add_child(_info_row("Type", type_label, UIColorsClass.COLOR_CYAN))
	var danger_color: Color = UIColorsClass.COLOR_AMBER \
		if int(planet.danger_level) >= 3 else UIColorsClass.COLOR_TEXT_PRIMARY
	vbox.add_child(_info_row("Danger Level", str(planet.danger_level), danger_color))

	# World traits WITH rules meaning (the flavor/law core of the briefing).
	if planet.traits is Array and not planet.traits.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_section_header("WORLD TRAITS"))
		for t in planet.traits:
			var rec = _trait_lookup.get(str(t).to_lower(), null)
			if rec:
				var cat: String = str(rec["category"])
				var tag: String = (" [%s]" % cat.capitalize()) if cat != "" else ""
				vbox.add_child(_info_row(str(rec["name"]) + tag, "", _category_color(cat)))
				vbox.add_child(_wrap_label(str(rec["description"]), UIColorsClass.COLOR_TEXT_SECONDARY))
			else:
				vbox.add_child(_info_row(str(t).capitalize().replace("_", " "), "", UIColorsClass.COLOR_PURPLE))

	# Notable features (special_features generated at creation).
	if planet.special_features is Array and not planet.special_features.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_section_header("NOTABLE FEATURES"))
		for feat in planet.special_features:
			vbox.add_child(_info_row(
				"•", str(feat).capitalize().replace("_", " "), UIColorsClass.COLOR_PURPLE
			))

	# Locations (each may carry flavor/type).
	if planet.locations is Array and not planet.locations.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_section_header("LOCATIONS"))
		for loc in planet.locations:
			var loc_name: String = str(loc.get("name", "Unknown")) if loc is Dictionary else str(loc)
			var loc_type: String = str(loc.get("type", "")) if loc is Dictionary else ""
			vbox.add_child(_info_row(loc_name, loc_type, UIColorsClass.COLOR_CYAN))

	# Active world event (most recent) — flavor.
	if planet.world_events is Array and not planet.world_events.is_empty():
		var last_evt = planet.world_events[planet.world_events.size() - 1]
		if last_evt is Dictionary:
			var evt_desc: String = str(last_evt.get("description", last_evt.get("type", "")))
			if evt_desc.strip_edges() != "":
				vbox.add_child(HSeparator.new())
				vbox.add_child(_section_header("CURRENT EVENT"))
				vbox.add_child(_wrap_label(evt_desc, UIColorsClass.COLOR_AMBER))


# ============================================================================
# Internal render helpers (kept local, mirroring PlanetDetailBuilder's look).
# ============================================================================

static func _section_header(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", UIColorsClass.FONT_SIZE_LG)
	lbl.add_theme_color_override("font_color", UIColorsClass.COLOR_TEXT_PRIMARY)
	return lbl


static func _info_row(label: String, value: String, value_color: Color = Color.WHITE) -> HBoxContainer:
	if value_color == Color.WHITE:
		value_color = UIColorsClass.COLOR_TEXT_PRIMARY
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColorsClass.SPACING_SM)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", UIColorsClass.FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", value_color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	if value != "":
		var val_lbl := Label.new()
		val_lbl.text = value
		val_lbl.add_theme_font_size_override("font_size", UIColorsClass.FONT_SIZE_SM)
		val_lbl.add_theme_color_override("font_color", UIColorsClass.COLOR_TEXT_SECONDARY)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(val_lbl)
	return hbox


static func _wrap_label(text: String, color: Color = Color.WHITE) -> Label:
	if color == Color.WHITE:
		color = UIColorsClass.COLOR_TEXT_SECONDARY
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", UIColorsClass.FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl
