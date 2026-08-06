class_name StoryMarkerPanel
extends PanelContainer

## Story Track Event 5 "Kidnap" marker tracker — Core Rules p.157.
##
## Companion-app surface for FPCM_StoryMarkerInvestigation: the player places the
## six markers on their table, taps the one the crew just approached, and the
## panel rolls and prints the instruction to carry out. It does not simulate
## movement — same contract as every other battle panel here.
##
## Only shown when the current mission is Story Event 5. Event 5 is the sole
## source of the Evidence that unlocks Event 6 (p.157), and before this panel
## existed there was no way to generate any.

const MarkerSystemClass = preload(
	"res://src/core/story/StoryMarkerInvestigation.gd")

signal evidence_changed(total: int)
signal markers_resolved()

const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_RED := UIColors.COLOR_RED
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

var _system: Resource = null
var _marker_grid: HFlowContainer
var _evidence_label: Label
var _instruction_label: RichTextLabel
var _marker_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()


func setup(event: Variant, dice_manager: Node = null) -> void:
	## Build the tracker from the Story Event resource so the marker count,
	## reveal distance and War Bot profile all come from the book JSON.
	_system = MarkerSystemClass.new()
	if dice_manager:
		_system.set_dice_manager(dice_manager)
	_system.init_from_event(event)
	_rebuild_markers()
	_refresh()


func get_evidence_found() -> int:
	return int(_system.evidence_found) if _system else 0


func get_summary() -> Dictionary:
	return _system.get_summary() if _system else {}


func on_round_advanced(round_number: int) -> void:
	## p.157: "At the end of Round 3 and each round thereafter, roll 1D6 for
	## every remaining marker. On a 1, the marker is removed."
	if _system == null:
		return
	var removed: Array[Dictionary] = _system.end_of_round(round_number)
	if removed.is_empty():
		return
	var lines: Array[String] = []
	for entry: Dictionary in removed:
		lines.append(str(entry.get("instruction", "")))
	_set_instruction("\n".join(lines), COLOR_AMBER)
	_rebuild_markers()
	_refresh()


func abandon_remaining() -> void:
	## p.157: "If your crew all become casualties, remove any remaining markers."
	if _system == null:
		return
	var count: int = _system.abandon_remaining()
	if count > 0:
		_set_instruction(
			"All crew down — %d remaining marker(s) removed." % count, COLOR_RED)
	_rebuild_markers()
	_refresh()


# ── UI ──────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(vbox)

	var title := Label.new()
	title.text = "MARKER INVESTIGATION"
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Tap a marker when a crew figure comes within 4\" of it."
	hint.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	hint.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	_marker_grid = HFlowContainer.new()
	_marker_grid.add_theme_constant_override("h_separation", SPACING_SM)
	_marker_grid.add_theme_constant_override("v_separation", SPACING_SM)
	vbox.add_child(_marker_grid)

	_evidence_label = Label.new()
	_evidence_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_evidence_label.add_theme_color_override("font_color", COLOR_EMERALD)
	vbox.add_child(_evidence_label)

	_instruction_label = RichTextLabel.new()
	_instruction_label.bbcode_enabled = true
	_instruction_label.fit_content = true
	_instruction_label.scroll_active = false
	_instruction_label.custom_minimum_size = Vector2(0, 48)
	_instruction_label.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM)
	vbox.add_child(_instruction_label)


func _rebuild_markers() -> void:
	if _marker_grid == null or _system == null:
		return
	for child in _marker_grid.get_children():
		child.queue_free()
	_marker_buttons.clear()

	for marker: Dictionary in _system.markers:
		var idx: int = int(marker["index"])
		var state: String = str(marker["state"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.text = _label_for(idx, state)
		btn.disabled = not _is_actionable(state)
		btn.add_theme_color_override("font_color", _color_for(state))
		btn.pressed.connect(_on_marker_pressed.bind(idx))
		_marker_grid.add_child(btn)
		_marker_buttons.append(btn)


func _label_for(idx: int, state: String) -> String:
	var n: int = idx + 1
	match state:
		MarkerSystemClass.STATE_HIDDEN: return "Marker %d" % n
		MarkerSystemClass.STATE_EVIDENCE: return "%d: Evidence" % n
		MarkerSystemClass.STATE_NOTHING: return "%d: Nothing" % n
		MarkerSystemClass.STATE_BODY: return "%d: Body — search" % n
		MarkerSystemClass.STATE_BODY_SEARCHED: return "%d: Body (done)" % n
		MarkerSystemClass.STATE_WAR_BOT: return "%d: War Bot" % n
		MarkerSystemClass.STATE_REMOVED: return "%d: Gone — search" % n
		MarkerSystemClass.STATE_REMOVED_SEARCHED: return "%d: Gone" % n
	return "Marker %d" % n


func _color_for(state: String) -> Color:
	match state:
		MarkerSystemClass.STATE_EVIDENCE: return COLOR_EMERALD
		MarkerSystemClass.STATE_WAR_BOT: return COLOR_RED
		MarkerSystemClass.STATE_BODY, MarkerSystemClass.STATE_REMOVED:
			return COLOR_AMBER
		MarkerSystemClass.STATE_NOTHING, MarkerSystemClass.STATE_BODY_SEARCHED, \
		MarkerSystemClass.STATE_REMOVED_SEARCHED:
			return COLOR_TEXT_MUTED
	return COLOR_TEXT_PRIMARY


func _is_actionable(state: String) -> bool:
	## Hidden markers can be approached; a revealed Body and a decayed marker
	## each still offer their one Evidence roll (p.157).
	return state in [
		MarkerSystemClass.STATE_HIDDEN,
		MarkerSystemClass.STATE_BODY,
		MarkerSystemClass.STATE_REMOVED,
	]


func _on_marker_pressed(idx: int) -> void:
	if _system == null:
		return
	var marker: Dictionary = {}
	for m: Dictionary in _system.markers:
		if int(m["index"]) == idx:
			marker = m
			break
	if marker.is_empty():
		return

	var result: Dictionary = {}
	match str(marker["state"]):
		MarkerSystemClass.STATE_HIDDEN:
			result = _system.investigate(idx)
		MarkerSystemClass.STATE_BODY:
			result = _system.search_body(idx)
		MarkerSystemClass.STATE_REMOVED:
			result = _system.search_removed_location(idx)
		_:
			return

	if not result.get("ok", false):
		_set_instruction(str(result.get("reason", "")), COLOR_TEXT_MUTED)
		return

	var text: String = "[b]1D6 = %d[/b] — %s" % [
		int(result.get("roll", 0)), str(result.get("instruction", ""))]
	var colour: Color = COLOR_TEXT_PRIMARY
	if int(result.get("evidence_gained", 0)) > 0:
		colour = COLOR_EMERALD
		evidence_changed.emit(_system.evidence_found)
	elif str(result.get("outcome", "")) == MarkerSystemClass.STATE_WAR_BOT:
		colour = COLOR_RED

	_set_instruction(text, colour)
	_rebuild_markers()
	_refresh()

	if _system.all_resolved():
		markers_resolved.emit()


func _refresh() -> void:
	if _system == null or _evidence_label == null:
		return
	var summary: Dictionary = _system.get_summary()
	_evidence_label.text = "Evidence: %d    Markers left: %d / %d" % [
		int(summary.get("evidence_found", 0)),
		int(summary.get("markers_hidden", 0)),
		int(summary.get("markers_total", 0)),
	]


func _set_instruction(text: String, colour: Color) -> void:
	if _instruction_label == null:
		return
	_instruction_label.text = "[color=#%s]%s[/color]" % [
		colour.to_html(false), text]
