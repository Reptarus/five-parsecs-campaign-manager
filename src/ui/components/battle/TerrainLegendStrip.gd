extends HFlowContainer

## Data-driven terrain legend (ported from the retired BattlefieldGridPanel,
## BUG-103 lineage): shows ONLY the categories whose terrain is actually
## drawn this mission. Drive it with
## rebuild(map_view.get_rendered_legend_keys()).
##
## Journey rule: this strip lives in the battlefield intel drawer — never
## docked on the map surface (map-primary redesign).

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")

func _init() -> void:
	name = "TerrainLegendStrip"
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 4)
	custom_minimum_size = Vector2(0, 24)
	var legend_title := Label.new()
	legend_title.name = "LegendTitle"
	legend_title.text = "LEGEND:"
	legend_title.add_theme_font_size_override("font_size", 11)
	legend_title.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	add_child(legend_title)
	rebuild([])

## Rebuild the swatch rows from the rendered legend keys. Re-runnable.
func rebuild(keys: Array) -> void:
	# Drop existing swatch/label items, keep the "LEGEND:" title (child 0).
	while get_child_count() > 1:
		var c: Node = get_child(get_child_count() - 1)
		remove_child(c)
		c.queue_free()

	var defs: Dictionary = {
		"building": [BattlefieldShapeLibrary.MAP_COLOR_BUILDING, "Building"],
		"wall": [BattlefieldShapeLibrary.MAP_COLOR_WALL, "Wall"],
		"rock": [BattlefieldShapeLibrary.MAP_COLOR_ROCK, "Rock"],
		"hill": [BattlefieldShapeLibrary.MAP_COLOR_HILL, "Hill"],
		"vegetation": [BattlefieldShapeLibrary.MAP_COLOR_VEGETATION, "Trees"],
		"water": [BattlefieldShapeLibrary.MAP_COLOR_WATER, "Water"],
		"container": [BattlefieldShapeLibrary.MAP_COLOR_CONTAINER, "Container"],
		"crystal": [BattlefieldShapeLibrary.MAP_COLOR_CRYSTAL, "Crystal"],
		"hazard": [BattlefieldShapeLibrary.MAP_COLOR_HAZARD, "Hazard"],
		"debris": [BattlefieldShapeLibrary.MAP_COLOR_DEBRIS, "Debris"],
		"scatter": [BattlefieldShapeLibrary.MAP_COLOR_SCATTER, "Scatter"],
		"notable": [BattlefieldShapeLibrary.MAP_COLOR_NOTABLE_STROKE, "Notable"],
	}

	if keys.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "(no terrain)"
		none_lbl.add_theme_font_size_override("font_size", 11)
		none_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		add_child(none_lbl)
		return

	for key in keys:
		if not defs.has(key):
			continue
		var entry: Array = defs[key]
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = entry[0]
		item.add_child(swatch)

		var lbl := Label.new()
		lbl.text = entry[1]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		item.add_child(lbl)

		add_child(item)
