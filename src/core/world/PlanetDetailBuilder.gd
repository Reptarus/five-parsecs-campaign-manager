class_name PlanetDetailBuilder
extends RefCounted

## Static utility that renders a PlanetData detail view into a target VBoxContainer.
## Used by:
##   - CampaignDashboard "Current World" overlay (the original home of this code)
##   - Galaxy Log WorldDetailPopup (Galaxy Log feature, June 2026)
##
## Renders sections: planet info, special features, locations, world events,
## campaign-journal entries filtered by planet name. Empty sections are skipped
## rather than rendered with placeholder text. All cross-autoload lookups
## (CampaignJournal) use get_node_or_null defensively.
##
## Caller responsibilities:
##   - Provide a non-null `planet` (PlanetData) — this utility does NOT guard
##     against null. Caller checks `pdm.get_current_planet() != null` first.
##   - Provide a `vbox` that's already added to the scene tree before calling
##     (we add Label/HSeparator children which expect parented containers).
##   - Optionally pass an `owner` Node for journal autoload resolution; defaults
##     to fetching via Engine main loop if not given.

const UIColorsClass := preload("res://src/ui/components/base/UIColors.gd")


## Append a full planet-detail view to `vbox`. Mirrors the layout of the
## original CampaignDashboard._build_world_log_panel content block.
static func build_into(vbox: VBoxContainer, planet: Object, owner: Node = null) -> void:
	if not vbox or not planet:
		return

	# Planet header
	vbox.add_child(_create_section_header("PLANET INFO"))
	vbox.add_child(_create_info_row("Name", str(planet.name)))
	var type_label: String = str(
		planet.type_name if planet.type_name else planet.type
	)
	vbox.add_child(_create_info_row("Type", type_label))
	if planet.traits is Array and not planet.traits.is_empty():
		var trait_names: Array = []
		for t in planet.traits:
			trait_names.append(str(t).capitalize())
		vbox.add_child(_create_info_row(
			"Traits",
			", ".join(trait_names),
			UIColorsClass.COLOR_PURPLE
		))
	vbox.add_child(_create_info_row(
		"Danger Level", str(planet.danger_level)
	))
	vbox.add_child(_create_info_row(
		"Discovered", "Turn %d" % int(planet.discovered_on_turn)
	))
	vbox.add_child(_create_info_row(
		"Last Visited", "Turn %d" % int(planet.last_visited_turn)
	))
	vbox.add_child(_create_info_row(
		"Total Visits", str(planet.visit_count)
	))
	vbox.add_child(_create_info_row(
		"Missions Completed", str(planet.missions_completed),
		UIColorsClass.COLOR_EMERALD
	))
	if planet.exploration_progress > 0.0:
		vbox.add_child(_create_info_row(
			"Exploration",
			"%d%%" % int(planet.exploration_progress * 100),
			UIColorsClass.COLOR_EMERALD
		))

	# Special features
	if planet.special_features is Array and not planet.special_features.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_create_section_header("SPECIAL FEATURES"))
		for feat in planet.special_features:
			vbox.add_child(_create_info_row(
				"•", str(feat), UIColorsClass.COLOR_PURPLE
			))

	# Locations
	if planet.locations is Array and not planet.locations.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_create_section_header("LOCATIONS"))
		for loc in planet.locations:
			var loc_name: String = (
				str(loc.get("name", "Unknown")) if loc is Dictionary else str(loc)
			)
			var loc_type: String = (
				str(loc.get("type", "")) if loc is Dictionary else ""
			)
			vbox.add_child(_create_info_row(
				loc_name, loc_type, UIColorsClass.COLOR_CYAN
			))

	# World events
	if planet.world_events is Array and not planet.world_events.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_create_section_header("WORLD EVENTS"))
		for evt in planet.world_events:
			var evt_turn: int = int(evt.get("turn", 0))
			var evt_desc: String = str(
				evt.get("description", evt.get("type", "Event"))
			)
			vbox.add_child(_create_info_row(
				"Turn %d" % evt_turn, evt_desc, UIColorsClass.COLOR_AMBER
			))

	# Journal entries tagged with this planet's name
	# (Audit B1 fix means battle + travel + milestone entries all join correctly.)
	var journal: Node = _resolve_journal(owner)
	if journal and "entries" in journal and not journal.entries.is_empty():
		var planet_name: String = str(planet.name)
		var world_entries: Array = []
		for entry in journal.entries:
			if str(entry.get("location", "")) == planet_name:
				world_entries.append(entry)
		if not world_entries.is_empty():
			vbox.add_child(HSeparator.new())
			vbox.add_child(_create_section_header(
				"JOURNAL (%d entries)" % world_entries.size()
			))
			for entry in world_entries:
				var e_turn: int = int(entry.get("turn_number", 0))
				var e_title: String = str(entry.get("title", "Untitled"))
				var e_type: String = str(entry.get("type", ""))
				var type_color: Color = UIColorsClass.COLOR_TEXT_SECONDARY
				match e_type:
					"battle":
						type_color = UIColorsClass.COLOR_RED
					"story":
						type_color = UIColorsClass.COLOR_PURPLE
					"purchase":
						type_color = UIColorsClass.COLOR_EMERALD
					"injury":
						type_color = UIColorsClass.COLOR_AMBER
				vbox.add_child(_create_info_row(
					"T%d [%s]" % [e_turn, e_type],
					e_title,
					type_color
				))


# ============================================================================
# Internal helpers (private — keep aligned with CampaignScreenBase helpers
# so the rendered look matches the original dashboard rendering exactly).
# ============================================================================

static func _create_section_header(title: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColorsClass.SPACING_SM)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override(
		"font_size", UIColorsClass.FONT_SIZE_LG
	)
	title_lbl.add_theme_color_override(
		"font_color", UIColorsClass.COLOR_TEXT_PRIMARY
	)
	hbox.add_child(title_lbl)
	return hbox


static func _create_info_row(
	label: String,
	value: String,
	value_color: Color = Color.WHITE,
) -> HBoxContainer:
	# Default color is filled in here rather than at the param so we can use
	# UIColors.COLOR_TEXT_PRIMARY without const-init ordering issues.
	if value_color == Color.WHITE:
		value_color = UIColorsClass.COLOR_TEXT_PRIMARY
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColorsClass.SPACING_SM)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override(
		"font_size", UIColorsClass.FONT_SIZE_SM
	)
	lbl.add_theme_color_override(
		"font_color", UIColorsClass.COLOR_TEXT_SECONDARY
	)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override(
		"font_size", UIColorsClass.FONT_SIZE_SM
	)
	val_lbl.add_theme_color_override("font_color", value_color)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)
	return hbox


static func _resolve_journal(owner: Node) -> Node:
	if owner:
		var via_owner: Node = owner.get_node_or_null("/root/CampaignJournal")
		if via_owner:
			return via_owner
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return null
	return root.get_node_or_null("/root/CampaignJournal")
