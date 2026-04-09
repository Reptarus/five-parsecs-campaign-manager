class_name PlanetfallColonyStatusPanel
extends Control

## Colony status overview panel — accessible from Dashboard.
## Shows research tree progress, constructed buildings, milestone bar,
## and key colony statistics in one view.

const PlanetfallResearchScript := preload(
	"res://src/core/systems/PlanetfallResearchSystem.gd")
const PlanetfallBuildingScript := preload(
	"res://src/core/systems/PlanetfallBuildingSystem.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_CYAN := Color("#4FC3F7")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _research: PlanetfallResearchScript
var _building_sys: PlanetfallBuildingScript

var _content: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	_research = PlanetfallResearchScript.new()
	_building_sys = PlanetfallBuildingScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	_clear_container(_content)
	_build_content()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(160, 48)
	_close_btn.pressed.connect(func(): hide())


func _build_content() -> void:
	if not _campaign:
		return

	# Title
	var title := Label.new()
	title.text = "COLONY STATUS"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	# Milestone progress bar
	_build_milestone_section()

	# Colony stats grid
	_build_stats_section()

	# Research progress
	_build_research_section()

	# Buildings constructed
	_build_buildings_section()

	# Close button
	_content.add_child(_close_btn)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _build_milestone_section() -> void:
	var milestones: int = _campaign.milestones_completed if "milestones_completed" in _campaign else 0
	var header := Label.new()
	header.text = "MILESTONES: %d / 7" % milestones
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", COLOR_CYAN)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(header)

	# Visual progress bar
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 24)
	bar_bg.color = COLOR_ELEVATED
	_content.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	var fill_pct: float = clampf(float(milestones) / 7.0, 0.0, 1.0)
	bar_fill.custom_minimum_size = Vector2(fill_pct * 400, 24)
	bar_fill.color = COLOR_SUCCESS if milestones < 7 else COLOR_CYAN
	bar_bg.add_child(bar_fill)


func _build_stats_section() -> void:
	var section := Label.new()
	section.text = "COLONY STATISTICS"
	section.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	section.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(section)

	var stats: Dictionary = {
		"Morale": _campaign.colony_morale if "colony_morale" in _campaign else 0,
		"Integrity": _campaign.colony_integrity if "colony_integrity" in _campaign else 0,
		"Story Points": _campaign.story_points if "story_points" in _campaign else 0,
		"Raw Materials": _campaign.raw_materials if "raw_materials" in _campaign else 0,
		"Grunts": _campaign.grunts if "grunts" in _campaign else 0,
		"Augmentation Points": _campaign.augmentation_points if "augmentation_points" in _campaign else 0,
		"Colony Defenses": _campaign.colony_defenses if "colony_defenses" in _campaign else 0,
		"Repair Capacity": _campaign.repair_capacity if "repair_capacity" in _campaign else 1,
		"RP/Turn": _campaign.research_points_per_turn if "research_points_per_turn" in _campaign else 1,
		"BP/Turn": _campaign.build_points_per_turn if "build_points_per_turn" in _campaign else 1
	}

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", SPACING_LG)
	grid.add_theme_constant_override("v_separation", SPACING_SM)
	_content.add_child(grid)

	for key in stats:
		var val: int = stats[key]
		var lbl := Label.new()
		lbl.text = "%s: %d" % [key, val]
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		var color: Color = COLOR_DANGER if val < 0 else COLOR_TEXT_PRIMARY
		lbl.add_theme_color_override("font_color", color)
		grid.add_child(lbl)


func _build_research_section() -> void:
	var section := Label.new()
	section.text = "RESEARCH PROGRESS"
	section.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	section.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(section)

	var all_theories: Array = _research.get_all_theories()
	for theory in all_theories:
		if theory is not Dictionary:
			continue
		var tid: String = theory.get("id", "")
		var tname: String = theory.get("name", "?")
		var completed: bool = _research.is_theory_researched(_campaign, tid)
		var available: bool = _research.is_theory_available(_campaign, tid)
		var progress: int = _research.get_theory_progress(_campaign, tid)
		var cost: int = theory.get("theory_cost", 0)

		var lbl := Label.new()
		if completed:
			lbl.text = "  [DONE] %s" % tname
			lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif available and progress > 0:
			lbl.text = "  [%d/%d] %s" % [progress, cost, tname]
			lbl.add_theme_color_override("font_color", COLOR_WARNING)
		elif available:
			lbl.text = "  [--] %s" % tname
			lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		else:
			lbl.text = "  [LOCKED] %s" % tname
			lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		_content.add_child(lbl)


func _build_buildings_section() -> void:
	var section := Label.new()
	section.text = "BUILDINGS"
	section.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	section.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(section)

	var constructed: Array = _building_sys.get_constructed_buildings(_campaign)
	var in_progress: Dictionary = _building_sys.get_in_progress(_campaign)

	if constructed.is_empty() and in_progress.is_empty():
		var empty := Label.new()
		empty.text = "  No buildings constructed yet."
		empty.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		empty.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_content.add_child(empty)
		return

	for bid in in_progress:
		var building: Dictionary = _building_sys.get_building(str(bid))
		var bname: String = building.get("name", str(bid))
		var remaining: int = in_progress[bid]
		var lbl := Label.new()
		lbl.text = "  [BUILDING] %s (%d BP remaining)" % [bname, remaining]
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_content.add_child(lbl)

	for bid in constructed:
		var building: Dictionary = _building_sys.get_building(str(bid))
		var bname: String = building.get("name", str(bid))
		var is_milestone: bool = building.get("is_milestone", false)
		var prefix: String = "[M] " if is_milestone else ""
		var lbl := Label.new()
		lbl.text = "  %s%s" % [prefix, bname]
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		_content.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		if child == _close_btn:
			continue  # Don't free the close button
		child.queue_free()
