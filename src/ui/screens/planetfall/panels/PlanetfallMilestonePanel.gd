class_name PlanetfallMilestonePanel
extends Control

## Dashboard overlay showing milestone progress, calamity point tracker,
## mission data progress, and tech-that-grants-milestones checklist.
## Source: Planetfall pp.156-160, 169-172

const PlanetfallMilestoneScript := preload(
	"res://src/core/systems/PlanetfallMilestoneSystem.gd")
const PlanetfallMissionDataScript := preload(
	"res://src/core/systems/PlanetfallMissionDataSystem.gd")
const PlanetfallConditionScript := preload(
	"res://src/core/systems/PlanetfallConditionSystem.gd")
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")

## Emitted after this panel changes the campaign, so the host can save it.
signal campaign_changed

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
const COLOR_BASE := UIColors.COLOR_PRIMARY
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _milestone_sys: PlanetfallMilestoneScript
var _md_sys: PlanetfallMissionDataScript
var _condition_sys: PlanetfallConditionScript
var _content: VBoxContainer
var _close_btn: Button
var _replacement_note: String = ""


func _ready() -> void:
	_milestone_sys = PlanetfallMilestoneScript.new()
	_md_sys = PlanetfallMissionDataScript.new()
	_condition_sys = PlanetfallConditionScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	if not _content:
		return
	# The Close button lives in _content and must survive the rebuild. This loop freed
	# it too, and the dashboard refreshes straight after adding the panel, so the
	# overlay opened with no way to close it.
	for child in _content.get_children():
		if child != _close_btn:
			child.queue_free()
	_build_content()
	TouchScrollOpenerRef.open_subtree(_content)


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(120, 48)
	_close_btn.pressed.connect(func(): visible = false)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(_close_btn)


func _build_content() -> void:
	if not _campaign:
		return

	var progress: Dictionary = _milestone_sys.get_progress_summary(_campaign)
	var md_progress: Dictionary = _md_sys.get_progress(_campaign)
	var completed: int = progress.get("completed", 0)
	var total: int = progress.get("total_required", 7)

	# Title
	var title := Label.new()
	title.text = "CAMPAIGN PROGRESSION"
	title.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	# Milestone progress bar
	_build_milestone_bar(completed, total)

	# Calamity Points
	_build_stat_card("Calamity Points",
		str(_campaign.calamity_points) if "calamity_points" in _campaign else "0",
		"Checked at each milestone. D6 <= points = Calamity event.",
		COLOR_WARNING if (_campaign.calamity_points if "calamity_points" in _campaign else 0) > 0 else COLOR_TEXT_SECONDARY)

	# Mission Data
	var md_total: int = md_progress.get("mission_data", 0)
	var md_bt: int = md_progress.get("breakthroughs", 0)
	_build_stat_card("Mission Data",
		"%d (Breakthroughs: %d/4)" % [md_total, md_bt],
		"Each time gained: D6, if <= total = breakthrough." if md_progress.get("md_valuable", true) else "MD no longer has value (4th breakthrough reached).",
		COLOR_ACCENT)

	_build_conditions_section()

	# Tech that grants milestones
	_build_tech_checklist()

	# Next milestone effects
	if completed < 7:
		var next_effects: Array = progress.get("next_effects", [])
		_build_next_milestone_section(completed + 1, next_effects)


func _build_milestone_bar(completed: int, total: int) -> void:
	var bar_box := HBoxContainer.new()
	bar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(bar_box)

	for i in range(total):
		var segment := PanelContainer.new()
		segment.custom_minimum_size = Vector2(40, 40)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		if i < completed:
			style.bg_color = COLOR_SUCCESS
		else:
			style.bg_color = COLOR_ELEVATED
			style.border_color = COLOR_BORDER
			style.set_border_width_all(1)
		segment.add_theme_stylebox_override("panel", style)
		bar_box.add_child(segment)

		var lbl := Label.new()
		lbl.text = str(i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
		segment.add_child(lbl)

	var status := Label.new()
	status.text = "%d / %d Milestones" % [completed, total]
	status.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	status.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(status)


func _build_stat_card(title_text: String, value_text: String,
		desc_text: String, accent: Color) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)
	_content.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)

	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	t.add_theme_color_override("font_color", accent)
	inner.add_child(t)

	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	v.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	inner.add_child(v)

	var d := Label.new()
	d.text = desc_text
	d.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
	d.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(d)


## The Campaign Condition table (p.110), and the 4th Milestone's "erase one campaign
## battlefield condition ... and generate a new condition to take its place" (p.157):
## the milestone owes the replacement, the player picks the entry here.
func _build_conditions_section() -> void:
	var header := Label.new()
	header.text = "Campaign Battlefield Conditions"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(header)

	if _replacement_note != "":
		_add_wrapped_label(_replacement_note, COLOR_SUCCESS)
	var owed: int = int(_campaign.pending_condition_replacements) \
			if "pending_condition_replacements" in _campaign else 0
	if owed > 0:
		_add_wrapped_label("4th Milestone: erase one condition and generate a new one in "
				+ "its place (%d owed)." % owed, COLOR_WARNING)

	var table: Array = _campaign.condition_table if "condition_table" in _campaign else []
	var filled: int = 0
	for i in range(table.size()):
		var entry: Variant = table[i]
		if not entry is Dictionary or (entry as Dictionary).is_empty():
			continue
		filled += 1
		var text: String = "Entry %d: %s" % [i + 1, str(entry.get("name", ""))]
		var detail: Variant = entry.get("resolved_sub_roll", {})
		if detail is Dictionary and not (detail as Dictionary).is_empty():
			text += " (%s)" % str(detail.get("name", ""))
		_add_wrapped_label(text, COLOR_TEXT_PRIMARY)
		if owed > 0:
			var btn := Button.new()
			btn.text = "Erase and replace entry %d" % (i + 1)
			btn.custom_minimum_size = Vector2(0, 48)
			btn.pressed.connect(_on_replace_condition.bind(i))
			_content.add_child(btn)
	if filled == 0:
		_add_wrapped_label("No conditions generated yet. A mission that calls for one "
				+ "rolls on this table (p.110).", COLOR_TEXT_SECONDARY)


func _on_replace_condition(slot: int) -> void:
	var receipt: Dictionary = _condition_sys.replace_condition(_campaign, slot)
	if receipt.is_empty():
		return
	var erased: Dictionary = receipt.get("erased", {})
	var fresh: Dictionary = receipt.get("condition", {})
	_replacement_note = "Entry %d: %s erased, %s generated in its place." % [
			slot + 1, str(erased.get("name", "")), str(fresh.get("name", ""))]
	campaign_changed.emit()
	refresh()


func _add_wrapped_label(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(lbl)


func _build_tech_checklist() -> void:
	var tech: Dictionary = _milestone_sys.get_milestone_granting_tech()
	if tech.is_empty():
		return
	var owned: Array = _milestone_sys.owned_granting_sources(_campaign)

	var header := Label.new()
	header.text = "Tech That Grants Milestones"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_content.add_child(header)

	for category in tech:
		var items: Array = tech[category]
		for item_id in items:
			var lbl := Label.new()
			var display_name: String = str(item_id).replace("_", " ").capitalize()
			var is_owned: bool = owned.has("%s:%s" % [category, str(item_id)])
			lbl.text = "%s  %s (%s)" % [
				"[x]" if is_owned else "[ ]",
				display_name,
				category.replace("_", " ")]
			lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
			lbl.add_theme_color_override("font_color",
				COLOR_SUCCESS if owned else COLOR_TEXT_SECONDARY)
			_content.add_child(lbl)


func _build_next_milestone_section(next_index: int, effects: Array) -> void:
	var header := Label.new()
	header.text = "Next Milestone (#%d) Effects:" % next_index
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	header.add_theme_color_override("font_color", COLOR_ACCENT)
	_content.add_child(header)

	for effect in effects:
		if effect is not Dictionary:
			continue
		var desc: String = effect.get("description", effect.get("type", ""))
		var lbl := Label.new()
		lbl.text = "  - %s" % desc
		lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(lbl)
