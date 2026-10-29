class_name PlanetfallResearchPanel
extends Control

## Step 14: Research — browse tech tree, spend RP on theories/applications.
## 13 theories with prerequisite chains, each with 3-5 applications.
## Source: Planetfall pp.91-96

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's one completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const PlanetfallResearchScript := preload(
	"res://src/core/systems/PlanetfallResearchSystem.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")
const ArmoryScript := preload("res://src/core/systems/PlanetfallArmorySystem.gd")
const DisplayTextRef := preload("res://src/ui/components/common/DisplayText.gd")

## p.93's labels for an Application's kind.
const APPLICATION_KINDS := {
	"bonus": "Bonus", "building": "Building", "milestone_building": "Milestone Building",
	"weapon": "Weapon", "milestone": "Milestone"}

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

var _campaign: Resource
var _phase_manager: Node
var _research: PlanetfallResearchScript
var _armory: RefCounted
var _selected_theory_id: String = ""

var _title_label: Label
var _rp_label: Label
var _theory_list: VBoxContainer
var _detail_container: VBoxContainer
var _result_container: VBoxContainer
var _scroll: ScrollContainer
## List | detail on a tablet, stacked on a phone (_fit_columns).
var _columns: BoxContainer


func _ready() -> void:
	_research = PlanetfallResearchScript.new()
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
	_selected_theory_id = ""
	_clear_container(_theory_list)
	_clear_container(_detail_container)
	_clear_container(_result_container)

	# Per-turn RP income, credited ONCE per turn by the core: refresh() runs again on a
	# resume, and crediting here paid the turn twice. Penalties and the Crisis point
	# (pp.88, 90) come off it there.
	if _campaign and _campaign.has_method("claim_turn_income"):
		_show_income(_campaign.claim_turn_income("rp"))

	_update_rp_display()
	_build_theory_list()
	_build_bio_analysis()
	# The detail pane opened empty beside the list, saying nothing about what it is for.
	_detail_container.add_child(_small_label("Pick a Theory to invest RP in it or to "
			+ "research one of its Applications (pp.92-93).", COLOR_TEXT_SECONDARY))
	_fit_columns()
	TouchScrollOpenerRef.open_subtree(self)
	step_status_changed.emit()


## Two columns squeezed a theory's description and its Applications to half a phone.
func _fit_columns() -> void:
	if not _columns:
		return
	var rm: Node = get_node_or_null("/root/ResponsiveManager")
	_columns.vertical = rm != null and rm.has_method("should_collapse_to_single_column") \
			and rm.should_collapse_to_single_column()


func complete() -> void:
	_on_continue_pressed()


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
	_title_label.text = "STEP 14: RESEARCH"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_rp_label = Label.new()
	_rp_label.text = "Research Points: 0"
	_rp_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	_rp_label.add_theme_color_override("font_color", COLOR_CYAN)
	_rp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_rp_label)

	_columns = BoxContainer.new()
	_columns.add_theme_constant_override("separation", SPACING_LG)
	vbox.add_child(_columns)

	_theory_list = VBoxContainer.new()
	_theory_list.add_theme_constant_override("separation", SPACING_SM)
	_theory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(_theory_list)

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
## THEORY LIST
## ============================================================================

func _build_theory_list() -> void:
	var header := Label.new()
	header.text = "THEORIES"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
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
		var cost: int = _research.theory_cost_now(_campaign, tid)

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_theory_list.add_child(row)

		var btn := Button.new()
		if completed:
			var apps: Array = theory.get("applications", [])
			var found: int = apps.size() - _research.get_available_applications(
					_campaign, tid).size()
			btn.text = "%s: researched, %d of %d Applications" % [tname, found, apps.size()]
		elif available:
			btn.text = "%s (%d/%d RP)" % [tname, progress, cost]
		else:
			btn.text = tname
		btn.custom_minimum_size.y = 48
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not available and not completed
		btn.pressed.connect(_on_theory_selected.bind(tid))
		row.add_child(btn)

		# What the field is for, from the same entry the research reads; a bare name
		# said nothing until it was pressed.
		row.add_child(_small_label(str(theory.get("description", "")), COLOR_TEXT_SECONDARY))
		if not available and not completed:
			row.add_child(_small_label(_locked_reason(theory), COLOR_WARNING))


## p.92 Bio-Analysis Research, below the Theories. A creature can be analyzed once a Hunt
## has sampled it (p.121); the benefit is shown on the battle screen whenever it is met.
func _build_bio_analysis() -> void:
	var header := Label.new()
	header.text = "BIO-ANALYSIS (p.92)"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_theory_list.add_child(header)
	var left: int = _research.discounts_left(_campaign)
	if left > 0:
		_theory_list.add_child(_small_label("Alien translation guide: the next %d research " % left
				+ "topic(s) cost half, rounded up (p.136).", COLOR_CYAN))
	var candidates: Array = _research.bio_analysis_candidates(_campaign)
	if candidates.is_empty():
		_theory_list.add_child(_small_label("No Lifeform has been sampled. Two samples from a "
				+ "Hunt mission authorize analyzing that creature (pp.92, 121).",
				COLOR_TEXT_SECONDARY))
		return
	var cost: int = _research.bio_analysis_cost(_campaign)
	for c in candidates:
		var analysis: Dictionary = c.get("analysis", {})
		if not analysis.is_empty():
			_theory_list.add_child(_small_label("%s: %s. %s" % [str(c.name),
					str(analysis.get("name", "")), str(analysis.get("description", ""))],
					COLOR_SUCCESS))
			continue
		var btn := Button.new()
		btn.text = "Analyze %s (%d RP)" % [str(c.name), cost]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size.y = 48
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = _research.get_current_rp(_campaign) < cost
		btn.pressed.connect(_on_bio_analysis_pressed.bind(int(c.slot)))
		_theory_list.add_child(btn)


func _on_bio_analysis_pressed(slot: int) -> void:
	var result: Dictionary = _research.conduct_bio_analysis(_campaign, slot)
	if not result.get("success", false):
		_add_result_bbcode("[color=ui-danger]%s[/color]" % result.get("error", "Failed"))
		return
	var entry: Dictionary = result.get("entry", {})
	_add_result_bbcode("[color=ui-success]Bio-Analysis D6 %d: %s.[/color] %s" % [
			int(result.roll), str(entry.get("name", "")), str(entry.get("description", ""))])
	_update_rp_display()
	_rebuild_theory_list()


## p.92: a Theory with prerequisites becomes available once they are "fully researched".
## It read "[LOCKED]" and never said what it was waiting for.
func _locked_reason(theory: Dictionary) -> String:
	var missing: Array[String] = []
	for pid in theory.get("prerequisites", []):
		if not _research.is_theory_researched(_campaign, str(pid)):
			missing.append(str(_research.get_theory(str(pid)).get("name", pid)))
	return "Research %s first (p.92)." % " and ".join(missing) if not missing.is_empty() \
		else "Not available yet."


## What an Application does, in p.93's words, built from the same entry the research
## applies (`effect`, `bonus`, `unlocks_*`), so the text cannot drift from the rule.
func application_effect_text(app: Dictionary) -> String:
	var parts: Array[String] = []
	var effect: Dictionary = app.get("effect", {}) if app.get("effect") is Dictionary else {}
	if effect.has("colony_integrity"):
		parts.append("+%d to Colony Integrity" % int(effect.colony_integrity))
	if effect.has("colony_morale"):
		parts.append("Increase Colony Morale by +%d" % int(effect.colony_morale))
	if effect.has("research_points_per_turn"):
		parts.append("Increase per campaign turn RP by +%d"
				% int(effect.research_points_per_turn))
	if effect.has("augmentation_points"):
		parts.append("+%d Augmentation Point%s" % [int(effect.augmentation_points),
				"" if int(effect.augmentation_points) == 1 else "s"])
	match str(app.get("type", "")):
		"building":
			parts.append("Allows the %s to be built" % str(app.get("name", "")))
		"milestone_building":
			parts.append("Allows the %s to be built; it is one of the buildings that "
					% str(app.get("name", "")) + "finish the campaign")
		"milestone":
			parts.append("Grants a Milestone (p.156)")
		"weapon":
			var w: Dictionary = _armory_weapon(str(app.get("unlocks_weapon", "")))
			if not w.is_empty():
				parts.append("New weapon: %s" % DisplayTextRef.weapon_profile(w))
	if str(app.get("bonus", "")) != "":
		parts.append(str(app.bonus))
	return "; ".join(parts) + ("." if not parts.is_empty() else "")


func _armory_weapon(weapon_id: String) -> Dictionary:
	if weapon_id == "":
		return {}
	if _armory == null:
		_armory = ArmoryScript.new()
	return _armory.get_weapon(weapon_id)


func _small_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _on_theory_selected(theory_id: String) -> void:
	_selected_theory_id = theory_id
	_show_theory_detail(theory_id)
	# Stacked on a phone, the detail is below the whole list: bring it into view.
	if _columns and _columns.vertical and _scroll:
		_scroll.ensure_control_visible.call_deferred(_detail_container)


func _show_theory_detail(theory_id: String) -> void:
	_clear_container(_detail_container)

	var theory: Dictionary = _research.get_theory(theory_id)
	if theory.is_empty():
		return

	var tname: String = theory.get("name", "Unknown")
	var completed: bool = _research.is_theory_researched(_campaign, theory_id)
	var progress: int = _research.get_theory_progress(_campaign, theory_id)
	# The costs the research will actually charge, a translation discount included (p.136).
	var theory_cost: int = _research.theory_cost_now(_campaign, theory_id)
	var app_cost: int = _research.application_cost_for(_campaign, theory_id)

	var name_lbl := Label.new()
	name_lbl.text = tname
	name_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_detail_container.add_child(name_lbl)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.text = theory.get("description", "")
	ScreenChrome.size_rich_text(desc, ScreenChrome.font_size(FONT_SIZE_SM))
	desc.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_detail_container.add_child(desc)

	var cost_lbl := Label.new()
	cost_lbl.text = "Theory Cost: %d/%d RP | App Cost: %d RP each" % [
		progress, theory_cost, app_cost]
	cost_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
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
		apps_header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
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
			var status: String = "Discovered" if unlocked else "Not yet discovered"
			app_lbl.text = "%s (%s): %s" % [aname, APPLICATION_KINDS.get(atype, atype), status]
			app_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			app_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
			app_lbl.add_theme_color_override(
				"font_color",
				COLOR_SUCCESS if unlocked else COLOR_TEXT_PRIMARY)
			_detail_container.add_child(app_lbl)
			var effect: String = application_effect_text(app)
			if not effect.is_empty():
				_detail_container.add_child(_small_label(effect, COLOR_TEXT_SECONDARY))

		# Research application button if theory completed
		if completed:
			var available_apps: Array = _research.get_available_applications(
				_campaign, theory_id)
			if not available_apps.is_empty():
				var current_rp: int = _research.get_current_rp(_campaign)
				if current_rp >= app_cost:
					var app_btn := Button.new()
					app_btn.text = "Research an Application (%d RP)" % app_cost
					app_btn.custom_minimum_size.y = 48
					app_btn.pressed.connect(
						_on_research_app_pressed.bind(theory_id))
					_detail_container.add_child(app_btn)
					# It never said WHICH Application the points buy.
					_detail_container.add_child(_small_label(
						"The research produces one of the %d undiscovered Applications, picked " \
						% available_apps.size() + "at random (p.93).", COLOR_TEXT_SECONDARY))
				else:
					_detail_container.add_child(_small_label(
						"An Application costs %d RP; the colony has %d." % [app_cost, current_rp],
						COLOR_WARNING))


## ============================================================================
## ACTIONS
## ============================================================================

func _on_invest_pressed(theory_id: String, amount: int) -> void:
	var result: Dictionary = _research.invest_in_theory(
		_campaign, theory_id, amount)
	if result.get("success", false):
		_add_result_bbcode(
			"[color=ui-success]Invested %d RP in %s.[/color]" % [
				result.get("invested", 0),
				str(_research.get_theory(theory_id).get("name", theory_id))])
		if result.get("completed", false):
			_add_result_bbcode(
				"[color=ui-success]Theory completed! Applications now available.[/color]")
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
			"[color=ui-success]Discovered: %s (%s)![/color]" % [aname, atype])

		# Check if this application grants a milestone. The APPLICATION, not the theory
		# it came from: p.156 lists applications, and a theory id never matched one.
		_check_milestone_grant("research_applications", str(app.get("id", "")))

		_update_rp_display()
		_show_theory_detail(theory_id)
		_rebuild_theory_list()
	else:
		_add_result_bbcode(
			"[color=ui-danger]%s[/color]" % result.get("error", "Failed"))


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
					"\n[color=ui-warning]*** MILESTONE GRANTED! ***[/color]")
				_add_result_bbcode(
					"[color=ui-warning]Its effects are applied when you complete this step.[/color]")


func _on_continue_pressed() -> void:
	phase_completed.emit({})


## What the turn screen's footer shows for this step. Spending points is optional, so the
## step can always be finished; the footer names the next step itself.
func step_status() -> Dictionary:
	return {"ready": true, "reason": ""}


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
	_build_bio_analysis()
	TouchScrollOpenerRef.open_subtree(self)


func _show_income(receipt: Dictionary) -> void:
	if bool(receipt.get("already", false)):
		_add_result_bbcode("This turn's Research Points have already been credited.")
		return
	var notes: Array[String] = []
	if int(receipt.get("penalty", 0)) > 0:
		notes.append("-%d penalty" % int(receipt.penalty))
	if int(receipt.get("crisis", 0)) > 0:
		notes.append("-%d Crisis (p.90)" % int(receipt.crisis))
	if int(receipt.get("wasted", 0)) > 0:
		notes.append("-%d wasted, Scientific dead end (p.63)" % int(receipt.wasted))
	_add_result_bbcode("Research Points earned this turn: +%d%s" % [int(receipt.get("net", 0)),
			" (%d %s)" % [int(receipt.get("gross", 0)), ", ".join(notes)] if not notes.is_empty() else ""])


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = UIColors.bbcode(text)
	ScreenChrome.size_rich_text(lbl, ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
