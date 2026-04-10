class_name PlanetfallBuildingPanel
extends Control

## Step 15: Building — construct colony buildings, manage BP, RM conversion.
## 40 buildings total (36 standard + 4 milestone). One at a time.
## Source: Planetfall pp.97-104

signal phase_completed(result_data: Dictionary)

const PlanetfallBuildingScript := preload(
	"res://src/core/systems/PlanetfallBuildingSystem.gd")
const PlanetfallResearchScript := preload(
	"res://src/core/systems/PlanetfallResearchSystem.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_CYAN := Color("#4FC3F7")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _building_sys: PlanetfallBuildingScript
var _research_sys: PlanetfallResearchScript
var _selected_building_id: String = ""

var _title_label: Label
var _bp_label: Label
var _rm_label: Label
var _building_list: VBoxContainer
var _detail_container: VBoxContainer
var _result_container: VBoxContainer
var _rm_spinner: SpinBox
var _convert_btn: Button
var _continue_btn: Button


func _ready() -> void:
	_building_sys = PlanetfallBuildingScript.new()
	_research_sys = PlanetfallResearchScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_selected_building_id = ""
	_clear_container(_building_list)
	_clear_container(_detail_container)
	_clear_container(_result_container)

	# Add per-turn BP income
	if _campaign and "build_points_per_turn" in _campaign:
		var bp_income: int = _campaign.build_points_per_turn
		_building_sys.add_build_points(_campaign, bp_income)

	_update_resource_display()
	_build_building_list()
	if _continue_btn:
		_continue_btn.disabled = false


func complete() -> void:
	_on_continue_pressed()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 15: BUILDING"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Resource display
	var res_row := HBoxContainer.new()
	res_row.alignment = BoxContainer.ALIGNMENT_CENTER
	res_row.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(res_row)

	_bp_label = Label.new()
	_bp_label.text = "Build Points: 0"
	_bp_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_bp_label.add_theme_color_override("font_color", COLOR_CYAN)
	res_row.add_child(_bp_label)

	_rm_label = Label.new()
	_rm_label.text = "Raw Materials: 0"
	_rm_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_rm_label.add_theme_color_override("font_color", COLOR_WARNING)
	res_row.add_child(_rm_label)

	# RM to BP conversion
	var convert_row := HBoxContainer.new()
	convert_row.alignment = BoxContainer.ALIGNMENT_CENTER
	convert_row.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(convert_row)

	var conv_lbl := Label.new()
	conv_lbl.text = "Convert RM → BP (max 3):"
	conv_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	conv_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	convert_row.add_child(conv_lbl)

	_rm_spinner = SpinBox.new()
	_rm_spinner.min_value = 0
	_rm_spinner.max_value = 3
	_rm_spinner.value = 0
	_rm_spinner.step = 1
	_rm_spinner.custom_minimum_size.x = 80
	convert_row.add_child(_rm_spinner)

	_convert_btn = Button.new()
	_convert_btn.text = "Convert"
	_convert_btn.custom_minimum_size = Vector2(100, 36)
	_convert_btn.pressed.connect(_on_convert_pressed)
	convert_row.add_child(_convert_btn)

	# Main layout: building list + detail
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(hbox)

	_building_list = VBoxContainer.new()
	_building_list.add_theme_constant_override("separation", SPACING_SM)
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_building_list)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", SPACING_MD)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_vbox)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", SPACING_SM)
	right_vbox.add_child(_detail_container)

	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	right_vbox.add_child(_result_container)

	_continue_btn = Button.new()
	_continue_btn.text = "Done Building"
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_btn)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## BUILDING LIST
## ============================================================================

func _build_building_list() -> void:
	var constructed: Array = _building_sys.get_constructed_buildings(_campaign)
	var in_progress: Dictionary = _building_sys.get_in_progress(_campaign)
	var available: Array = _building_sys.get_available_buildings(
		_campaign, _research_sys)

	# In-progress section
	if not in_progress.is_empty():
		var ip_header := Label.new()
		ip_header.text = "IN PROGRESS"
		ip_header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		ip_header.add_theme_color_override("font_color", COLOR_WARNING)
		_building_list.add_child(ip_header)

		for bid in in_progress:
			var building: Dictionary = _building_sys.get_building(str(bid))
			var remaining: int = in_progress[bid]
			var bname: String = building.get("name", str(bid))
			var btn := Button.new()
			btn.text = "%s (%d BP remaining)" % [bname, remaining]
			btn.custom_minimum_size.y = 36
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_on_building_selected.bind(str(bid)))
			_building_list.add_child(btn)

	# Available section
	var avail_header := Label.new()
	avail_header.text = "AVAILABLE (%d)" % available.size()
	avail_header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	avail_header.add_theme_color_override("font_color", COLOR_SUCCESS)
	_building_list.add_child(avail_header)

	for building in available:
		if building is not Dictionary:
			continue
		var bid: String = building.get("id", "")
		if in_progress.has(bid):
			continue  # Already shown above
		var bname: String = building.get("name", "?")
		var bp_cost: int = building.get("bp_cost", 0)
		var is_milestone: bool = building.get("is_milestone", false)
		var prefix: String = "[M] " if is_milestone else ""

		var btn := Button.new()
		btn.text = "%s%s (%d BP)" % [prefix, bname, bp_cost]
		btn.custom_minimum_size.y = 36
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_building_selected.bind(bid))
		_building_list.add_child(btn)

	# Constructed section
	if not constructed.is_empty():
		var con_header := Label.new()
		con_header.text = "CONSTRUCTED (%d)" % constructed.size()
		con_header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		con_header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_building_list.add_child(con_header)

		for bid in constructed:
			var building: Dictionary = _building_sys.get_building(str(bid))
			var bname: String = building.get("name", str(bid))
			var lbl := Label.new()
			lbl.text = "  %s" % bname
			lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			_building_list.add_child(lbl)


func _on_building_selected(building_id: String) -> void:
	_selected_building_id = building_id
	_show_building_detail(building_id)


func _show_building_detail(building_id: String) -> void:
	_clear_container(_detail_container)

	var building: Dictionary = _building_sys.get_building(building_id)
	if building.is_empty():
		return

	var bname: String = building.get("name", "Unknown")
	var bp_cost: int = building.get("bp_cost", 0)
	var prereq: Variant = building.get("prerequisite")
	var is_milestone: bool = building.get("is_milestone", false)
	var desc: String = building.get("description", "")
	var constructed: bool = _building_sys.is_constructed(_campaign, building_id)

	var name_lbl := Label.new()
	name_lbl.text = bname + (" [MILESTONE]" if is_milestone else "")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "BP Cost: %d" % bp_cost
	cost_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	cost_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(cost_lbl)

	if prereq != null and prereq is String and not prereq.is_empty():
		var prereq_lbl := Label.new()
		prereq_lbl.text = "Requires: %s" % str(prereq).replace("_", " ").capitalize()
		prereq_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		prereq_lbl.add_theme_color_override("font_color", COLOR_WARNING)
		_detail_container.add_child(prereq_lbl)

	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true
	desc_rtl.fit_content = true
	desc_rtl.scroll_active = false
	desc_rtl.text = desc
	desc_rtl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	desc_rtl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(desc_rtl)

	if not constructed:
		var current_bp: int = _building_sys.get_current_bp(_campaign)
		var can_invest: int = mini(current_bp, bp_cost)
		if can_invest > 0:
			var invest_btn := Button.new()
			invest_btn.text = "Invest %d BP" % can_invest
			invest_btn.custom_minimum_size.y = 40
			invest_btn.pressed.connect(
				_on_invest_pressed.bind(building_id, can_invest))
			_detail_container.add_child(invest_btn)
	else:
		var status_lbl := Label.new()
		status_lbl.text = "CONSTRUCTED"
		status_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		status_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		_detail_container.add_child(status_lbl)


## ============================================================================
## ACTIONS
## ============================================================================

func _on_convert_pressed() -> void:
	var amount: int = int(_rm_spinner.value)
	if amount <= 0:
		return
	var gained: int = _building_sys.convert_rm_to_bp(_campaign, amount)
	if gained > 0:
		_add_result_bbcode(
			"[color=#10B981]Converted %d RM → %d BP[/color]" % [gained, gained])
		_update_resource_display()
		_rm_spinner.value = 0
		_rm_spinner.max_value = mini(3, _campaign.raw_materials if _campaign and "raw_materials" in _campaign else 0)


func _on_invest_pressed(building_id: String, amount: int) -> void:
	var result: Dictionary = _building_sys.invest_bp(
		_campaign, building_id, amount)
	if result.get("success", false):
		var building: Dictionary = _building_sys.get_building(building_id)
		var bname: String = building.get("name", building_id)
		_add_result_bbcode(
			"[color=#10B981]Invested %d BP in %s.[/color]" % [
				result.get("invested", 0), bname])
		if result.get("completed", false):
			_add_result_bbcode(
				"[color=#10B981]%s construction complete![/color]" % bname)
			# Check if this building grants a milestone
			_check_milestone_grant("buildings", building_id)
		_update_resource_display()
		_show_building_detail(building_id)
		_rebuild_building_list()


func _check_milestone_grant(tech_type: String, tech_id: String) -> void:
	## Check if a completed building grants a milestone.
	if not _phase_manager:
		return
	var parent: Node = _phase_manager
	while parent:
		if parent.has_method("get_milestone_system"):
			var ms: RefCounted = parent.get_milestone_system()
			if ms and ms.has_method("check_tech_grants_milestone"):
				if ms.check_tech_grants_milestone(tech_type, tech_id):
					_add_result_bbcode(
						"\n[color=#D97706]*** MILESTONE GRANTED! ***[/color]")
					_add_result_bbcode(
						"[color=#D97706]Effects processed at end of turn.[/color]")
			return
		parent = parent.get_parent()


func _on_continue_pressed() -> void:
	if _continue_btn:
		_continue_btn.disabled = true
	phase_completed.emit({})


## ============================================================================
## HELPERS
## ============================================================================

func _update_resource_display() -> void:
	if _campaign:
		var bp: int = _building_sys.get_current_bp(_campaign)
		var rm: int = _campaign.raw_materials if "raw_materials" in _campaign else 0
		if _bp_label:
			_bp_label.text = "Build Points: %d" % bp
		if _rm_label:
			_rm_label.text = "Raw Materials: %d" % rm
		if _rm_spinner:
			_rm_spinner.max_value = mini(3, rm)


func _rebuild_building_list() -> void:
	_clear_container(_building_list)
	_build_building_list()


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
