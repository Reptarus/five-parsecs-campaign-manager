extends Window

## QA Scenarios — jump a loaded campaign to a state that is expensive to play to.
##
## DEBUG BUILDS ONLY. The dashboard entry point is gated on OS.is_debug_build(),
## which is the honest gate: a release export physically cannot open this, so
## there is no "hidden unlock gesture" that can be found by a player or left on
## by accident. Remote-deploy QA builds ARE debug builds, so the tablet gets it.
##
## This dialog is presentation only. Every mutation happens in
## QAScenarioLoader.apply(), which routes through the same owner setters the
## Campaign Editor uses — see that file's header for why fixtures are deltas and
## not save files, and for why nothing here jumps the PHASE.

const QAScenarioLoaderRef = preload("res://src/core/qa/QAScenarioLoader.gd")
const DialogStylesRef = preload("res://src/ui/components/common/DialogStyles.gd")
# UIColors is a class_name (src/ui/components/base/UIColors.gd) — referenced directly.

signal scenario_applied(id: String, receipt: Dictionary)

var _campaign: Variant = null
var _scenarios: Array = []
var _list: ItemList = null
var _detail: RichTextLabel = null
var _apply_button: Button = null

## Rolls the seam can force, with the row each one is needed for.
##
## `key` is matched case-insensitively as a SUBSTRING of the live roll context,
## which is why "Character Event" reaches a roll made as
## "Character Event: <crew name>".
##
## `target` is the value that reaches the row QA is actually chasing, so the
## tester does not have to look the table up on the device.
const FORCEABLE_ROLLS: Array[Dictionary] = [
	{"key": "Rival Attack Type", "sides": 10, "target": 1,
		"note": "T9-48 - 1 = AMBUSH, the only battle that forbids Seize (p.91)"},
	{"key": "Exploration Table", "sides": 100, "target": 51,
		"note": "T9-47 - 51-53 \"I don't have a gambling problem!\" (discard 1 item)"},
	{"key": "Trade Table", "sides": 100, "target": 76,
		"note": "T9-47 - 76-78 \"A chance to unload some stuff\" (sell at 2cr)"},
	{"key": "Character Event", "sides": 100, "target": 88,
		"note": "T9-51 - 88-91 item damaged, 92-94 item lost (pp.128-130)"},
	# T11-19b. The CAMPAIGN event is a different roll from the CHARACTER event
	# above and lives on a different step (p.125 step 12 vs step 13); it was the
	# one the seam did not reach, which is why T11-25 and T11-35 could not be
	# walked. 21-23 is Old Nemesis, 89-91 is Got Noticed. Neither key is a
	# substring of the other, so the two cannot consume each other's queue.
	{"key": "Campaign Event", "sides": 100, "target": 21,
		"note": "T11-25 - 21-23 Old Nemesis; T11-35 - 89-91 Got Noticed (needs an active Quest)"},
	{"key": "Mission Objective", "sides": 10, "target": 1, "note": "p.89 objective"},
	{"key": "Danger Pay", "sides": 10, "target": 1, "note": "p.83"},
	{"key": "Battlefield Find", "sides": 100, "target": 1, "note": "pp.120-121"},
	{"key": "Loot Category", "sides": 100, "target": 1, "note": "pp.131-134"},
	{"key": "Notable Sight", "sides": 100, "target": 1, "note": "p.88"},
]

var _roll_picker: OptionButton = null
var _roll_value: SpinBox = null
var _roll_status: Label = null


## Open over `parent` against `campaign`. Returns null (and does nothing) when no
## campaign is loaded — a scenario is a DELTA, so there must be something to
## apply it to.
static func open(parent: Node, campaign: Variant) -> Window:
	if parent == null or campaign == null:
		push_warning("QAScenarioDialog: no campaign loaded — nothing to apply to.")
		return null
	# Bare `new()` here is correct and verified (test_dialog_script_and_its_static_factory
	# _actually_load, isolated Aug 8 2026). The documented Godot 4.6 trap is
	# `ClassName.new()` inside a static func, which needs a `class_name` identifier to
	# resolve and fails with "Identifier not found"; this script has no class_name and
	# refers to itself implicitly, so it is fine. If you ever add a `class_name` here,
	# do NOT switch to `ClassName.new()` — use `load(<path>).new()`.
	var dlg := new()
	dlg.set_campaign(campaign)
	parent.add_child(dlg)
	# Ratio, never a fixed size. The first version used popup_centered() against a
	# hard-coded 900x620 and was verified on desktop at the tablet's PORTRAIT
	# geometry (800x1280): the scenario list was clipped off the left edge and the
	# Apply button off the right, so the dialog's only two controls were both
	# unreachable. popup_centered_ratio() sizes against the parent viewport, so it
	# is correct in portrait and landscape and on any device.
	dlg.popup_centered_ratio(0.92)
	return dlg


## Set before the dialog enters the tree. A public setter rather than a direct
## field poke from open(): _ready() reads it, so the assignment must happen first.
func set_campaign(campaign: Variant) -> void:
	_campaign = campaign


func _init() -> void:
	title = "QA Scenarios (debug build)"
	# No fixed size here — open() calls popup_centered_ratio(), which sizes against
	# the parent viewport. A Vector2i set at _init() would fight it and, worse, is
	# what clipped both controls off-screen in portrait.
	unresizable = false
	close_requested.connect(queue_free)


func _ready() -> void:
	_scenarios = QAScenarioLoaderRef.load_all()
	_build_ui()
	if not _scenarios.is_empty():
		_list.select(0)
		_on_selected(0)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIColors.SPACING_MD)
	add_child(margin)

	# T11-15 - a ScrollContainer between the margin and the content, so soft-keyboard
	# avoidance has something to move.
	#
	# KeyboardAvoidance has two strategies. The good one appends headroom to a
	# ScrollContainer and scrolls the focused field clear; the fallback MOVES THE
	# WINDOW, and that one has a hard ceiling - a window cannot go above the top of
	# the screen, so it can only surrender the gap it already sits below it.
	# Measured on the tablet: this dialog asked for 511.3px of avoidance and had 64px
	# to give, leaving the field under the keyboard. This dialog had no
	# ScrollContainer at all, which is the ONLY reason it took the fallback.
	#
	# horizontal_scroll_mode DISABLED: a form must not scroll sideways, and a
	# disabled axis propagates its child's minimum rather than absorbing it, which is
	# what keeps the dialog's own width honest.
	var _kb_scroll := ScrollContainer.new()
	_kb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_kb_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kb_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_kb_scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIColors.SPACING_SM)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# T11-39. size_flags_VERTICAL is load-bearing and was missing, which disabled
	# the whole scenario feature on deploy #21: the dialog opened with the forced-roll
	# row and ~900px of empty space where the list and detail pane belong.
	#
	# Godot 4.6, gui_containers.html: a ScrollContainer "accepts a single child node
	# and adds scrollbars if the child node's size exceeds the container's
	# dimensions. BOTH VERTICAL AND HORIZONTAL SIZE OPTIONS ARE RESPECTED." With only
	# the horizontal flag set, the scroll sized this VBox to its MINIMUM height, so
	# `split` below could claim no leftover space no matter what its own flags said -
	# and _list carried custom_minimum_size.y = 0, so the collapse went all the way to
	# nothing rather than merely looking cramped.
	#
	# This regression arrived with the T11-15 ScrollContainer wrapper. That fix was
	# detection-proven and desk-green; what no test asserted was that the list was
	# still VISIBLE afterwards. A fix can solve its own finding and break its
	# neighbour - test_qa_scenario_dialog_shows_its_list now pins it.
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kb_scroll.add_child(root)

	var blurb := Label.new()
	blurb.text = ("Applies a state DELTA to the loaded campaign through the normal owner "
		+ "setters, then hands back. It does not jump the phase — enter the turn normally.")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# COLOR_TEXT_MUTED, not TEXT_MUTED. UIColors' short-alias block defines only
	# TEXT_PRIMARY / TEXT_SECONDARY / TEXT_DISABLED, and referencing a member that
	# does not exist is a PARSE error — which fails the whole script at load and
	# takes every file that preloads it down too. That is what blanked the Campaign
	# Dashboard on device: process alive, logcat clean, nothing on screen.
	blurb.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	root.add_child(blurb)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", UIColors.SPACING_SM)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	_list = ItemList.new()
	# T11-39: a real minimum HEIGHT, not just width. The 0 here is what turned a
	# missing size flag into an invisible feature rather than a cramped one - inside
	# a ScrollContainer nothing else establishes a floor. 240 shows ~4 scenarios (all
	# four fixtures fit) and still leaves room on a phone in portrait.
	_list.custom_minimum_size = Vector2(280, 240)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	split.add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = false
	_detail.scroll_active = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_detail)

	for s in _scenarios:
		_list.add_item(str(s.get("name", s.get("id", "?"))))

	if _scenarios.is_empty():
		_detail.text = ("[color=#ff9a52]No fixtures found in res://data/qa_scenarios/."
			+ "[/color]\n\nThis usually means the export filter dropped the folder — "
			+ "verify by unzipping the APK, not by trusting the build log.")

	_build_forced_roll_section(root)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIColors.SPACING_SM)
	root.add_child(buttons)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStylesRef.style_secondary_button(close_btn)
	close_btn.pressed.connect(queue_free)
	buttons.add_child(close_btn)

	_apply_button = Button.new()
	_apply_button.text = "Apply Scenario"
	_apply_button.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	_apply_button.disabled = _scenarios.is_empty()
	DialogStylesRef.style_primary_button(_apply_button)
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)


## Force the next roll on a book table.
##
## WHY: three fixes have been stuck desk-verified since 2026-08-14 purely because
## no in-app tool can reach their row - Rival AMBUSH is a D10 of 1, and the two
## crew-task rows are 3-in-100 each (docs/qa/PICKUP_2026-08-14.md section 3).
## Widening the shipped roll_range was declined twice, because it means testing a
## build whose rules data differs from ship. This changes no data: the table is
## read exactly as shipped, only the die is pinned.
##
## This one does NOT route through QAScenarioLoader, and that is deliberate. The
## loader applies campaign-state DELTAS from JSON fixtures through owner setters;
## a queued die is neither campaign state nor a fixture, so putting it there would
## blur the one rule that keeps fixtures safe across a schema_version bump.
func _build_forced_roll_section(root: VBoxContainer) -> void:
	var sep := HSeparator.new()
	root.add_child(sep)

	var heading := Label.new()
	heading.text = "Force the next roll (debug only)"
	root.add_child(heading)

	# HFlowContainer, not HBox: this dialog is used on the tablet in PORTRAIT, and
	# a fixed row of four controls is exactly what put the original Apply button
	# off-screen. Flow wraps instead of clipping.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", UIColors.SPACING_SM)
	row.add_theme_constant_override("v_separation", UIColors.SPACING_SM)
	root.add_child(row)

	_roll_picker = OptionButton.new()
	_roll_picker.custom_minimum_size = Vector2(260, UIColors.TOUCH_TARGET_MIN)
	# add_item() WITHOUT an explicit id: passing -1 stores the INDEX as the id,
	# which silently collides once the list is ever reordered. Selection is read
	# back as an index into FORCEABLE_ROLLS instead.
	for entry: Dictionary in FORCEABLE_ROLLS:
		_roll_picker.add_item("%s (D%d)" % [str(entry["key"]), int(entry["sides"])])
	_roll_picker.item_selected.connect(_on_roll_context_selected)
	row.add_child(_roll_picker)

	_roll_value = SpinBox.new()
	_roll_value.min_value = 1
	_roll_value.max_value = 10
	_roll_value.step = 1
	_roll_value.custom_minimum_size = Vector2(110, UIColors.TOUCH_TARGET_MIN)
	row.add_child(_roll_value)

	var queue_btn := Button.new()
	queue_btn.text = "Queue Roll"
	queue_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStylesRef.style_secondary_button(queue_btn)
	queue_btn.pressed.connect(_on_queue_roll_pressed)
	row.add_child(queue_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStylesRef.style_secondary_button(clear_btn)
	clear_btn.pressed.connect(_on_clear_rolls_pressed)
	row.add_child(clear_btn)

	_roll_status = Label.new()
	_roll_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# COLOR_TEXT_MUTED, not TEXT_MUTED - see the blurb above for what that costs.
	_roll_status.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	root.add_child(_roll_status)

	_roll_picker.select(0)
	_on_roll_context_selected(0)


## The DiceManager autoload, or null. This dialog IS in the tree, so the plain
## lookup is safe here (unlike MissionTableManager, which is detached).
func _dice_manager() -> Node:
	return get_node_or_null("/root/DiceManager")


func _on_roll_context_selected(idx: int) -> void:
	if idx < 0 or idx >= FORCEABLE_ROLLS.size():
		return
	var entry: Dictionary = FORCEABLE_ROLLS[idx]
	_roll_value.max_value = int(entry["sides"])
	_roll_value.value = int(entry["target"])
	_refresh_roll_status(str(entry["note"]))


func _on_queue_roll_pressed() -> void:
	var idx: int = _roll_picker.get_selected()
	if idx < 0 or idx >= FORCEABLE_ROLLS.size():
		return
	var entry: Dictionary = FORCEABLE_ROLLS[idx]
	var dm: Node = _dice_manager()
	if dm == null or not dm.has_method("queue_forced_result"):
		_refresh_roll_status("DiceManager unavailable - nothing queued.")
		return
	# T11-43. A Godot SpinBox parses its LineEdit text into `.value` only on
	# focus-loss or submit, so a value TYPED and immediately followed by a button
	# press is read at its pre-edit value: the walk typed 89 and queued 21, the
	# figure the dropdown had auto-filled. apply() commits the pending text first.
	# ⚠ This matters more than a debug nit reads: the whole point of the seam is
	# to reach a table row that cannot otherwise be reached, so a silently wrong
	# value arms a completely different rule and the tester verifies the wrong one.
	if _roll_value.has_method("apply"):
		_roll_value.apply()
	var value: int = int(_roll_value.value)
	if not dm.queue_forced_result(str(entry["key"]), value):
		# The seam refuses in a release build. Say so rather than implying success.
		_refresh_roll_status("Refused - forced rolls are debug-build only.")
		return
	_refresh_roll_status("Queued %d for the next \"%s\" roll. %s" % [
		value, str(entry["key"]), str(entry["note"])])


func _on_clear_rolls_pressed() -> void:
	var dm: Node = _dice_manager()
	if dm != null and dm.has_method("clear_forced_results"):
		dm.clear_forced_results()
	_refresh_roll_status("Cleared.")


func _refresh_roll_status(message: String) -> void:
	if _roll_status == null:
		return
	var pending: String = ""
	var dm: Node = _dice_manager()
	if dm != null and dm.has_method("get_forced_results"):
		var queued: Dictionary = dm.get_forced_results()
		if not queued.is_empty():
			var parts: Array[String] = []
			for key: String in queued.keys():
				parts.append("%s=%s" % [key, str(queued[key])])
			pending = "  [pending: %s]" % ", ".join(parts)
	_roll_status.text = message + pending


func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _scenarios.size():
		return
	var s: Dictionary = _scenarios[idx]
	var parts: Array[String] = []
	parts.append("[b][font_size=20]%s[/font_size][/b]" % str(s.get("name", "")))
	parts.append(str(s.get("summary", "")))

	var unlocks: Array = s.get("unlocks", [])
	if not unlocks.is_empty():
		parts.append("\n[b]Unlocks[/b]")
		for u in unlocks:
			parts.append("  • %s" % str(u))

	var note := str(s.get("note", ""))
	if not note.is_empty():
		parts.append("\n[b]Note[/b]\n%s" % note)

	_detail.text = "\n".join(parts)


func _on_apply_pressed() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	var s: Dictionary = _scenarios[sel[0]]
	var receipt: Dictionary = QAScenarioLoaderRef.apply(s, _campaign)

	# Show what actually happened rather than a bare "done". A scenario that
	# silently skipped half its setup is worse than no scenario at all: the tester
	# believes they are in a state they are not, and then files findings against it.
	var applied: Array = receipt.get("applied", [])
	var warnings: Array = receipt.get("warnings", [])
	var lines: Array[String] = ["[b]%s applied[/b]\n" % str(s.get("name", ""))]
	if applied.is_empty():
		lines.append("[color=#ff9a52]Nothing was applied.[/color]")
	for a in applied:
		lines.append("[color=#6ee7a0]✓[/color] %s" % str(a))
	if not warnings.is_empty():
		lines.append("\n[b][color=#ff9a52]Warnings[/color][/b]")
		for w in warnings:
			lines.append("[color=#ff9a52]![/color] %s" % str(w))
	lines.append("\nClose this and use the dashboard normally — the campaign is now in "
		+ "that state. Save if you want it on disk.")
	_detail.text = "\n".join(lines)

	scenario_applied.emit(str(s.get("id", "")), receipt)
