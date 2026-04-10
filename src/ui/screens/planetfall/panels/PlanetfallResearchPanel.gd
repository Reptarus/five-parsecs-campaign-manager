class_name PlanetfallResearchPanel
extends Control

## Step 14: Research — browse tech tree, spend RP on theories/applications.
## 13 theories with prerequisite chains, each with 3-5 applications.
## Source: Planetfall pp.91-96

signal phase_completed(result_data: Dictionary)

const PlanetfallResearchScript := preload(
	"res://src/core/systems/PlanetfallResearchSystem.gd")

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
var _phase_manager: Node
var _research: PlanetfallResearchScript
var _selected_theory_id: String = ""

var _title_label: Label
var _rp_label: Label
var _theory_list: VBoxContainer
var _detail_container: VBoxContainer
var _result_container: VBoxContainer
var _continue_btn: Button


func _ready() -> void:
	_research = PlanetfallResearchScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_selected_theory_id = ""
	_clear_container(_theory_list)
	_clear_container(_detail_container)
	_clear_container(_result_container)

	# Add per-turn RP income
	if _campaign and "research_points_per_turn" in _campaign:
		var rp_income: int = _campaign.research_points_per_turn
		_research.add_research_points(_campaign, rp_income)

	_update_rp_display()
	_build_theory_list()
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
	_title_label.text = "STEP 14: RESEARCH"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_rp_label = Label.new()
	_rp_label.text = "Research Points: 0"
	_rp_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_rp_label.add_theme_color_override("font_color", COLOR_CYAN)
	_rp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_rp_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(hbox)

	_theory_list = VBoxContainer.new()
	_theory_list.add_theme_constant_override("separation", SPACING_SM)
	_theory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_theory_list)

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
	_continue_btn.text = "Done Researching"
	_continue_btn.custom_minimum_size = Vector2(220, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_btn)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## ============================================================================
## THEORY LIST
## ============================================================================

func _build_theory_list() -> void:
	var header := Label.new()
	header.text = "THEORIES"
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_theory_list.add_child(header)

	var all_theories: Array = _research.get_all_theories()
	for theory in all_theories:
		if theory is not Dictionary:
			continue
		var tid: String = theory.get("id", "")
		var tname: String = theory.get("name", "Unknown")
		var completed: bool = _research.is_theory_researched(_campaign, tid)
		var available: bool = _research.is_theory_available(_campaign, tid)
		var progress: int = _research.get_theory_progress(_campaign, tid)
		var cost: int = theory.get("theory_cost", 0)

		var btn := Button.new()
		if completed:
			btn.text = "%s [COMPLETE]" % tname
		elif available:
			btn.text = "%s (%d/%d RP)" % [tname, progress, cost]
		else:
			btn.text = "%s [LOCKED]" % tname

		btn.custom_minimum_size.y = 36
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not available and not completed
		btn.pressed.connect(_on_theory_selected.bind(tid))
		_theory_list.add_child(btn)


func _on_theory_selected(theory_id: String) -> void:
	_selected_theory_id = theory_id
	_show_theory_detail(theory_id)


func _show_theory_detail(theory_id: String) -> void:
	_clear_container(_detail_container)

	var theory: Dictionary = _research.get_theory(theory_id)
	if theory.is_empty():
		return

	var tname: String = theory.get("name", "Unknown")
	var completed: bool = _research.is_theory_researched(_campaign, theory_id)
	var progress: int = _research.get_theory_progress(_campaign, theory_id)
	var theory_cost: int = theory.get("theory_cost", 0)
	var app_cost: int = theory.get("application_cost", 0)

	var name_lbl := Label.new()
	name_lbl.text = tname
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = theory.get("description", "")
	desc.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(desc)

	var cost_lbl := Label.new()
	cost_lbl.text = "Theory Cost: %d/%d RP | App Cost: %d RP each" % [
		progress, theory_cost, app_cost]
	cost_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	cost_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_container.add_child(cost_lbl)

	# Invest button if not completed
	if not completed:
		var remaining: int = theory_cost - progress
		var can_invest: int = mini(remaining, _research.get_current_rp(_campaign))
		if can_invest > 0:
			var invest_btn := Button.new()
			invest_btn.text = "Invest %d RP" % can_invest
			invest_btn.custom_minimum_size.y = 40
			invest_btn.pressed.connect(
				_on_invest_pressed.bind(theory_id, can_invest))
			_detail_container.add_child(invest_btn)

	# Applications list
	var apps: Array = theory.get("applications", [])
	if not apps.is_empty():
		var apps_header := Label.new()
		apps_header.text = "Applications:"
		apps_header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		apps_header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		_detail_container.add_child(apps_header)

		for app in apps:
			if app is not Dictionary:
				continue
			var aid: String = app.get("id", "")
			var aname: String = app.get("name", "?")
			var atype: String = app.get("type", "")
			var unlocked: bool = _research.is_application_unlocked(_campaign, aid)

			var app_lbl := Label.new()
			var status: String = "[UNLOCKED]" if unlocked else "[locked]"
			app_lbl.text = "  %s (%s) %s" % [aname, atype, status]
			app_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
			app_lbl.add_theme_color_override(
				"font_color",
				COLOR_SUCCESS if unlocked else COLOR_TEXT_SECONDARY)
			_detail_container.add_child(app_lbl)

		# Research application button if theory completed
		if completed:
			var available_apps: Array = _research.get_available_applications(
				_campaign, theory_id)
			if not available_apps.is_empty():
				var current_rp: int = _research.get_current_rp(_campaign)
				if current_rp >= app_cost:
					var app_btn := Button.new()
					app_btn.text = "Research Application (%d RP)" % app_cost
					app_btn.custom_minimum_size.y = 40
					app_btn.pressed.connect(
						_on_research_app_pressed.bind(theory_id))
					_detail_container.add_child(app_btn)


## ============================================================================
## ACTIONS
## ============================================================================

func _on_invest_pressed(theory_id: String, amount: int) -> void:
	var result: Dictionary = _research.invest_in_theory(
		_campaign, theory_id, amount)
	if result.get("success", false):
		_add_result_bbcode(
			"[color=#10B981]Invested %d RP in %s.[/color]" % [
				result.get("invested", 0), theory_id])
		if result.get("completed", false):
			_add_result_bbcode(
				"[color=#10B981]Theory completed! Applications now available.[/color]")
		_update_rp_display()
		_show_theory_detail(theory_id)
		_rebuild_theory_list()


func _on_research_app_pressed(theory_id: String) -> void:
	var result: Dictionary = _research.research_application(
		_campaign, theory_id)
	if result.get("success", false):
		var app: Dictionary = result.get("application", {})
		var aname: String = app.get("name", "Unknown")
		var atype: String = app.get("type", "")
		_add_result_bbcode(
			"[color=#10B981]Discovered: %s (%s)![/color]" % [aname, atype])

		# Check if this application grants a milestone
		_check_milestone_grant("research_applications", theory_id)

		_update_rp_display()
		_show_theory_detail(theory_id)
		_rebuild_theory_list()
	else:
		_add_result_bbcode(
			"[color=#DC2626]%s[/color]" % result.get("error", "Failed"))


func _check_milestone_grant(tech_type: String, tech_id: String) -> void:
	## Check if a completed research/building/augmentation grants a milestone.
	## Accesses the TurnController's MilestoneSystem via phase_manager parent.
	if not _phase_manager:
		return
	var controller: Node = _phase_manager.get_parent() if _phase_manager else null
	if not controller:
		# Walk up from phase_manager to find TurnController
		var parent: Node = _phase_manager
		while parent:
			if parent.has_method("get_milestone_system"):
				controller = parent
				break
			parent = parent.get_parent()
	if controller and controller.has_method("get_milestone_system"):
		var ms: RefCounted = controller.get_milestone_system()
		if ms and ms.has_method("check_tech_grants_milestone"):
			if ms.check_tech_grants_milestone(tech_type, tech_id):
				_add_result_bbcode(
					"\n[color=#D97706]*** MILESTONE GRANTED! ***[/color]")
				_add_result_bbcode(
					"[color=#D97706]Milestone effects will be processed at end of turn.[/color]")


func _on_continue_pressed() -> void:
	if _continue_btn:
		_continue_btn.disabled = true
	phase_completed.emit({})


## ============================================================================
## HELPERS
## ============================================================================

func _update_rp_display() -> void:
	if _rp_label and _campaign:
		var rp: int = _research.get_current_rp(_campaign)
		_rp_label.text = "Research Points: %d" % rp


func _rebuild_theory_list() -> void:
	_clear_container(_theory_list)
	_build_theory_list()


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
