class_name PlanetfallBuildingPanel
extends Control

## Step 15: Building — construct colony buildings, manage BP, RM conversion.
## 40 buildings total (36 standard + 4 milestone). One at a time.
## Source: Planetfall pp.97-104
##
## The step's three limits live in PlanetfallBuildingSystem, which this panel only asks:
## BP go to ONE Building per turn (p.97), up to 3 Raw Materials convert per turn (p.98),
## and ONE Building may be reclaimed per turn (p.98). Until 2026-10-28 none was kept per
## turn, a locked Building was simply missing from the list, and reclaiming was not
## offered at all.

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's one completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const PlanetfallBuildingScript := preload(
	"res://src/core/systems/PlanetfallBuildingSystem.gd")
const PlanetfallResearchScript := preload(
	"res://src/core/systems/PlanetfallResearchSystem.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
const COLOR_CYAN := UIColors.COLOR_CYAN
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const TOUCH_TARGET_MIN := 48

var _campaign: Resource
var _phase_manager: Node
var _building_sys: PlanetfallBuildingScript
var _research_sys: PlanetfallResearchScript
var _selected_building_id: String = ""
## The Building whose Reclaim was pressed once; the second press destroys it.
var _reclaim_armed: String = ""

var _title_label: Label
var _bp_label: Label
var _rm_label: Label
var _building_list: VBoxContainer
var _detail_container: VBoxContainer
var _result_container: VBoxContainer
var _rm_spinner: SpinBox
var _convert_btn: Button
var _convert_label: Label
var _scroll: ScrollContainer
## List | detail on a tablet, stacked on a phone (_fit_columns).
var _columns: BoxContainer


func _ready() -> void:
	_building_sys = PlanetfallBuildingScript.new()
	_research_sys = PlanetfallResearchScript.new()
	_build_ui()
	var rm: Node = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		rm.layout_class_changed.connect(func(_cols: int) -> void: _fit_columns())


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_selected_building_id = ""
	_reclaim_armed = ""
	_clear_container(_building_list)
	_clear_container(_detail_container)
	_clear_container(_result_container)

	# Per-turn BP income, credited ONCE per turn by the core: refresh() runs again on a
	# resume, and crediting here paid the turn twice. Penalties and the Crisis point
	# (pp.88, 90) come off it there.
	if _campaign and _campaign.has_method("claim_turn_income"):
		_show_income(_campaign.claim_turn_income("bp"))

	_update_resource_display()
	_build_building_list()
	# The detail pane opened empty beside the list, saying nothing about what it is for.
	_detail_container.add_child(_small_label("Pick a Building to see its cost and what "
			+ "it does. BP go to one Building per campaign turn (p.97).",
			COLOR_TEXT_SECONDARY, FONT_SIZE_SM))
	_fit_columns()
	TouchScrollOpenerRef.open_subtree(self)
	step_status_changed.emit()


func complete() -> void:
	_on_continue_pressed()


## Two columns squeezed every Building's text to half a phone.
func _fit_columns() -> void:
	if not _columns:
		return
	var rm: Node = get_node_or_null("/root/ResponsiveManager")
	_columns.vertical = rm != null and rm.has_method("should_collapse_to_single_column") \
			and rm.should_collapse_to_single_column()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	_scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 15: BUILDING"
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
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
	_bp_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	_bp_label.add_theme_color_override("font_color", COLOR_CYAN)
	res_row.add_child(_bp_label)

	_rm_label = Label.new()
	_rm_label.text = "Raw Materials: 0"
	_rm_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	_rm_label.add_theme_color_override("font_color", COLOR_WARNING)
	res_row.add_child(_rm_label)

	# RM to BP conversion. A flow row, so the button wraps under the label on a phone
	# (as an HBox it ran off the right edge, reading "Conv").
	var convert_row := HFlowContainer.new()
	convert_row.alignment = FlowContainer.ALIGNMENT_CENTER
	convert_row.add_theme_constant_override("h_separation", SPACING_SM)
	convert_row.add_theme_constant_override("v_separation", SPACING_SM)
	vbox.add_child(convert_row)

	_convert_label = Label.new()
	_convert_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	_convert_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_convert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_convert_label.custom_minimum_size.y = TOUCH_TARGET_MIN
	convert_row.add_child(_convert_label)

	_rm_spinner = SpinBox.new()
	_rm_spinner.min_value = 0
	_rm_spinner.max_value = PlanetfallBuildingScript.MAX_CONVERT_PER_TURN
	_rm_spinner.value = 0
	_rm_spinner.step = 1
	_rm_spinner.custom_minimum_size = Vector2(96, TOUCH_TARGET_MIN)
	convert_row.add_child(_rm_spinner)

	_convert_btn = Button.new()
	_convert_btn.text = "Convert"
	_convert_btn.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	_convert_btn.pressed.connect(_on_convert_pressed)
	convert_row.add_child(_convert_btn)

	# Main layout: building list + detail
	_columns = BoxContainer.new()
	_columns.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(_columns)

	_building_list = VBoxContainer.new()
	_building_list.add_theme_constant_override("separation", SPACING_SM)
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(_building_list)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", SPACING_MD)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(right_vbox)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", SPACING_SM)
	right_vbox.add_child(_detail_container)

	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	right_vbox.add_child(_result_container)


## ============================================================================
## BUILDING LIST
## ============================================================================

func _build_building_list() -> void:
	var constructed: Array = _building_sys.get_constructed_buildings(_campaign)
	var in_progress: Dictionary = _building_sys.get_in_progress(_campaign)
	var available: Array = _building_sys.get_available_buildings(
		_campaign, _research_sys)
	var available_ids: Dictionary = {}
	for b in available:
		if b is Dictionary:
			available_ids[str(b.get("id", ""))] = true

	# In-progress section
	if not in_progress.is_empty():
		_building_list.add_child(_section_header("IN PROGRESS", COLOR_WARNING))
		for bid in in_progress:
			var building: Dictionary = _building_sys.get_building(str(bid))
			_add_building_row(building, "%s (%d BP remaining)" % [
					building.get("name", str(bid)), int(in_progress[bid])])

	# Available section
	_building_list.add_child(_section_header(
			"AVAILABLE (%d)" % available.size(), COLOR_SUCCESS))
	for building in available:
		if building is not Dictionary or in_progress.has(str(building.get("id", ""))):
			continue
		_add_building_row(building, "%s (%d BP)" % [
				building.get("name", "?"), int(building.get("bp_cost", 0))])

	# Locked section: what research or construction each one is waiting for. A locked
	# Building used to be absent, so nothing told the player what to research.
	var locked: Array = []
	for building in _building_sys.get_all_buildings():
		if building is not Dictionary:
			continue
		var bid: String = str(building.get("id", ""))
		if constructed.has(bid) or in_progress.has(bid) or available_ids.has(bid):
			continue
		locked.append(building)
	if not locked.is_empty():
		_building_list.add_child(_section_header("LOCKED (%d)" % locked.size(),
				COLOR_TEXT_SECONDARY))
		for building in locked:
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			_building_list.add_child(row)
			var name_lbl := _small_label("%s (%d BP)%s" % [building.get("name", "?"),
					int(building.get("bp_cost", 0)),
					", Milestone Building" if building.get("is_milestone", false) else ""],
					COLOR_TEXT_PRIMARY, FONT_SIZE_SM)
			row.add_child(name_lbl)
			row.add_child(_small_label(_building_sys.locked_reason(
					_campaign, building, _research_sys), COLOR_WARNING))

	# Constructed section: selectable, so a Building can be reviewed or reclaimed.
	if not constructed.is_empty():
		_building_list.add_child(_section_header(
				"CONSTRUCTED (%d)" % constructed.size(), COLOR_TEXT_SECONDARY))
		for bid in constructed:
			var building: Dictionary = _building_sys.get_building(str(bid))
			_add_building_row(building, str(building.get("name", str(bid))))


## One selectable Building: its button, then what it does, from the same entry the
## construction applies. A bare name and cost said nothing until it was pressed.
func _add_building_row(building: Dictionary, text: String) -> void:
	var bid: String = str(building.get("id", ""))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_building_list.add_child(row)
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_building_selected.bind(bid))
	row.add_child(btn)
	var line: String = str(building.get("description", ""))
	if building.get("is_milestone", false):
		line = "Milestone Building. " + line
	row.add_child(_small_label(line, COLOR_TEXT_SECONDARY))


func _section_header(text: String, color: Color) -> Label:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	header.add_theme_color_override("font_color", color)
	return header


func _small_label(text: String, color: Color, px: int = FONT_SIZE_XS) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(px))
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _on_building_selected(building_id: String) -> void:
	_selected_building_id = building_id
	if _reclaim_armed != building_id:
		_reclaim_armed = ""
	_show_building_detail(building_id)
	# Stacked on a phone, the detail is below the whole list: bring it into view.
	if _columns and _columns.vertical and _scroll:
		_scroll.ensure_control_visible.call_deferred(_detail_container)


func _show_building_detail(building_id: String) -> void:
	_clear_container(_detail_container)

	var building: Dictionary = _building_sys.get_building(building_id)
	if building.is_empty():
		return

	var bname: String = building.get("name", "Unknown")
	var bp_cost: int = building.get("bp_cost", 0)
	var is_milestone: bool = building.get("is_milestone", false)
	var desc: String = building.get("description", "")
	var constructed: bool = _building_sys.is_constructed(_campaign, building_id)
	var in_progress: Dictionary = _building_sys.get_in_progress(_campaign)
	var remaining: int = int(in_progress.get(building_id, bp_cost))

	var name_lbl := Label.new()
	name_lbl.text = bname + (" (Milestone Building)" if is_milestone else "")
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "BP Cost: %d" % bp_cost if remaining == bp_cost \
			else "BP Cost: %d (%d still to pay)" % [bp_cost, remaining]
	cost_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	cost_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(cost_lbl)

	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true
	desc_rtl.fit_content = true
	desc_rtl.scroll_active = false
	desc_rtl.text = desc
	desc_rtl.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	desc_rtl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(desc_rtl)

	if constructed:
		_detail_container.add_child(_small_label("Constructed", COLOR_SUCCESS, FONT_SIZE_SM))
		_add_reclaim_controls(building)
		return

	var reason: String = _building_sys.locked_reason(_campaign, building, _research_sys) \
			if not in_progress.has(building_id) else ""
	if reason != "":
		_detail_container.add_child(_small_label(reason, COLOR_WARNING, FONT_SIZE_SM))
		return
	var other: String = _building_sys.building_invested_this_turn(_campaign)
	if other != "" and other != building_id:
		_detail_container.add_child(_small_label(
				"This turn's BP already went to %s; BP go to a single Building per " \
				% _building_sys.get_building(other).get("name", other) \
				+ "campaign turn (p.97).", COLOR_WARNING, FONT_SIZE_SM))
		return
	var current_bp: int = _building_sys.get_current_bp(_campaign)
	var can_invest: int = mini(current_bp, remaining)
	if can_invest > 0:
		var invest_btn := Button.new()
		invest_btn.text = "Invest %d BP" % can_invest
		invest_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
		invest_btn.pressed.connect(
			_on_invest_pressed.bind(building_id, can_invest))
		_detail_container.add_child(invest_btn)
	else:
		_detail_container.add_child(_small_label(
				"The colony has no Build Points to put towards it this turn.",
				COLOR_TEXT_SECONDARY, FONT_SIZE_SM))


## p.98: reclaim "a single building" per turn for half its BP cost, rounded down, in Raw
## Materials. Destructive, so the first press only arms it.
func _add_reclaim_controls(building: Dictionary) -> void:
	var bid: String = str(building.get("id", ""))
	var rm_back: int = int(building.get("bp_cost", 0)) / 2
	var already: String = _building_sys.building_reclaimed_this_turn(_campaign)
	if already != "":
		_detail_container.add_child(_small_label(
				"%s was reclaimed this turn; one Building may be reclaimed per turn (p.98)."
				% _building_sys.get_building(already).get("name", already),
				COLOR_TEXT_SECONDARY))
		return
	var btn := Button.new()
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	if _reclaim_armed == bid:
		btn.text = "Confirm: destroy %s for %d Raw Materials" % [
				building.get("name", bid), rm_back]
		btn.add_theme_color_override("font_color", COLOR_DANGER)
	else:
		btn.text = "Reclaim for %d Raw Materials" % rm_back
	btn.pressed.connect(_on_reclaim_pressed.bind(bid))
	_detail_container.add_child(btn)
	_detail_container.add_child(_small_label(
			"Reclaiming destroys the Building and returns half its BP cost, rounded down, "
			+ "in Raw Materials (p.98). Its standing benefits go with it.",
			COLOR_TEXT_SECONDARY))


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
	_rm_spinner.value = 0
	_update_resource_display()
	if _selected_building_id != "":
		_show_building_detail(_selected_building_id)


func _on_invest_pressed(building_id: String, amount: int) -> void:
	var result: Dictionary = _building_sys.invest_bp(
		_campaign, building_id, amount)
	var building: Dictionary = _building_sys.get_building(building_id)
	var bname: String = building.get("name", building_id)
	if not result.get("success", false):
		_add_result_bbcode("[color=#F59E0B]%s[/color]" % str(result.get("error", "")))
		return
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


func _on_reclaim_pressed(building_id: String) -> void:
	if _reclaim_armed != building_id:
		_reclaim_armed = building_id
		_show_building_detail(building_id)
		return
	_reclaim_armed = ""
	var bname: String = str(_building_sys.get_building(building_id).get("name", building_id))
	var result: Dictionary = _building_sys.reclaim_building(_campaign, building_id)
	if not result.get("success", false):
		_add_result_bbcode("[color=#F59E0B]%s[/color]" % str(result.get("error", "")))
		return
	_add_result_bbcode("[color=#F59E0B]%s reclaimed: +%d Raw Materials.[/color]" % [
			bname, int(result.get("raw_materials_gained", 0))])
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
						"[color=#D97706]Its effects are applied when you complete this "
						+ "step.[/color]")
			return
		parent = parent.get_parent()


func _on_continue_pressed() -> void:
	phase_completed.emit({})


## What the turn screen's footer shows for this step. Spending points is optional, so the
## step can always be finished; the footer names the next step itself.
func step_status() -> Dictionary:
	return {"ready": true, "reason": ""}


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
		# The spinner's ceiling is what may still convert THIS turn (p.98), not 3 again.
		var left: int = _building_sys.convertible_this_turn(_campaign)
		if _rm_spinner:
			_rm_spinner.max_value = left
		if _convert_btn:
			_convert_btn.disabled = left <= 0
		if _convert_label:
			_convert_label.text = "Convert Raw Materials to BP (%d more this turn, p.98):" \
					% left


func _rebuild_building_list() -> void:
	_clear_container(_building_list)
	_build_building_list()
	TouchScrollOpenerRef.open_subtree(_building_list)


func _show_income(receipt: Dictionary) -> void:
	if bool(receipt.get("already", false)):
		_add_result_bbcode("This turn's Build Points have already been credited.")
		return
	var notes: Array[String] = []
	if int(receipt.get("penalty", 0)) > 0:
		notes.append("-%d penalty" % int(receipt.penalty))
	if int(receipt.get("crisis", 0)) > 0:
		notes.append("-%d Crisis (p.90)" % int(receipt.crisis))
	_add_result_bbcode("Build Points earned this turn: +%d%s" % [int(receipt.get("net", 0)),
			" (%d %s)" % [int(receipt.get("gross", 0)), ", ".join(notes)] if not notes.is_empty() else ""])


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
