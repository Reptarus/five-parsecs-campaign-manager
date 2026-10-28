extends Control

## Planetfall Creation Step 6: Final Review. Everything the colony will be founded with,
## read from the coordinator: the names it will use, the expedition and its effect, each
## character with their class, sub-species, profile and backgrounds, and the map.
##
## Until 2026-10-28 it showed "Unnamed" for a campaign the coordinator would found as
## "New Colony", counted classes without naming anyone, and showed no map.

const SectorGridScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const BackgroundsScript := preload("res://src/core/systems/PlanetfallBackgrounds.gd")
const RosterRules := preload("res://src/core/systems/PlanetfallRosterRules.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

var _coordinator = null
var _content: VBoxContainer
## Holds only the preview map the grid draws.
var _preview: PlanetfallCampaignCore = null


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_build_summary()


func refresh() -> void:
	if not _coordinator or not _content:
		return
	for child in _content.get_children():
		child.queue_free()
	_build_summary()
	_coordinator.mark_review_seen()


func _build_summary() -> void:
	if not _coordinator:
		_content.add_child(_line("Waiting for data...", UIColors.COLOR_TEXT_SECONDARY))
		return
	var data: Dictionary = _coordinator.get_all_data()
	var config: Dictionary = data.get("config", {})

	var header := _line("COLONY REVIEW", UIColors.COLOR_TEXT_PRIMARY, 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(header)

	_content.add_child(_heading("The colony"))
	_add_info_row("Campaign", _coordinator.campaign_name())
	_add_info_row("Colony", _coordinator.colony_name())
	var expedition: Dictionary = _coordinator.expedition_entry()
	if expedition.is_empty():
		_add_info_row("Expedition", "Not rolled yet (step 1)")
	else:
		_add_info_row("Expedition", "%s (D100 %d). %s" % [str(expedition.get("type", "")),
				int(config.get("expedition_roll", 0)), str(expedition.get("effect", ""))])

	var roster: Array = data.get("roster", [])
	var backgrounds: Dictionary = data.get("backgrounds", {})
	_content.add_child(_heading("Your colony crew (%d)" % roster.size()))
	for problem in RosterRules.roster_problems(roster):
		_content.add_child(_line(str(problem), UIColors.COLOR_AMBER))
	for c in roster:
		_content.add_child(_character_card(c, backgrounds.get(str(c.get("id", "")), {})))
	_content.add_child(_line("Plus 12 grunts and one colony bot (pp.16-17).",
			UIColors.COLOR_TEXT_SECONDARY))

	_content.add_child(_heading("The map"))
	var map_cfg: Dictionary = data.get("map_config", {})
	if not map_cfg.has("grid_size"):
		_content.add_child(_line("Not chosen yet (step 4).", UIColors.COLOR_AMBER))
	else:
		var gs: Array = map_cfg.grid_size
		_content.add_child(_line("%d x %d sectors. The Investigation Sites are placed when the "
				% [int(gs[0]), int(gs[1])] + "colony is founded (p.53).",
				UIColors.COLOR_TEXT_SECONDARY))
		if _preview == null:
			_preview = PlanetfallCampaignCore.new()
		_preview.map_data = {"grid_size": [int(gs[0]), int(gs[1])], "sectors": {},
				"home_sector": map_cfg.get("home_sector", [])}
		var grid: Control = SectorGridScript.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(grid)
		grid.show_map(_preview)

	_content.add_child(_heading("Tutorial missions"))
	var tut: Dictionary = data.get("tutorial_results", {})
	var won: Array = []
	if tut.get("beacons_success", false):
		won.append("Beacons: +2 Raw Materials")
	if tut.get("analysis_success", false):
		won.append("Analysis: +%d Research Points" % (3 if tut.get("analysis_all_six", false) else 2))
	if tut.get("perimeter_success", false):
		won.append("Perimeter: +3 Colony Morale")
	_content.add_child(_line("; ".join(PackedStringArray(won)) if not won.is_empty()
			else "None won or played.", UIColors.COLOR_TEXT_PRIMARY))

	var ready := _line("Press 'Establish Colony' to begin your Planetfall campaign.",
			UIColors.COLOR_EMERALD, 16)
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(ready)
	TouchScrollOpenerRef.open_subtree(self)


func _character_card(c: Dictionary, record: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var kind: String = str(RosterRules.subspecies_data().get(str(c.get("subspecies", "")), {})
			.get("name", ""))
	box.add_child(_line("%s, %s%s%s" % [str(c.get("name", "")), str(c.get("class", ""))
			.capitalize(), (" (%s)" % kind) if kind != "" else "",
			", imported" if bool(c.get("is_imported", false)) else ""],
			UIColors.COLOR_TEXT_PRIMARY, 15))
	# The profile the colony is founded with, Prior Experience bonus included.
	var founded: Dictionary = BackgroundsScript.apply_to(c, record)
	var profile: String = RosterRules.profile_line(founded)
	if int(founded.get("xp", 0)) > 0:
		profile += " · %d XP" % int(founded.xp)
	if int(founded.get("kp", 0)) > 0:
		profile += " · %d KP" % int(founded.kp)
	box.add_child(_line(profile, UIColors.COLOR_TEXT_SECONDARY))
	if record.is_empty():
		box.add_child(_line("Backgrounds not rolled yet (step 3).", UIColors.COLOR_AMBER))
		return card
	var parts: Array = ["Motivation: %s" % str(record.get("motivation", ""))]
	if bool(record.get("experienced", false)):
		var bonus: String = BackgroundsScript.bonus_text(record)
		parts.append("Prior Experience: %s%s" % [str(record.get("prior_experience", "")),
				(" (%s)" % bonus) if bonus != "" else ""])
		parts.append("Notable Event: %s" % str(record.get("notable_event", "")))
	box.add_child(_line(". ".join(PackedStringArray(parts)) + ".", UIColors.COLOR_TEXT_SECONDARY))
	return card


func _heading(text: String) -> Label:
	return _line(text.to_upper(), UIColors.COLOR_CYAN, 16)


func _line(text: String, color: Color, size: int = 14) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", color)
	return lbl


## A label and a value, stacked, so a long value wraps under its label on a phone instead
## of squeezing beside a fixed-width caption.
func _add_info_row(label_text: String, value_text: String) -> void:
	_content.add_child(_line(label_text, UIColors.COLOR_TEXT_SECONDARY, 13))
	_content.add_child(_line(value_text, UIColors.COLOR_TEXT_PRIMARY, 15))
