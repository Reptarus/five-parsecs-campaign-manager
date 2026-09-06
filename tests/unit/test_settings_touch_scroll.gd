extends GdUnitTestSuite
## T11-26 — the Options page must scroll from a drag STARTED ON A CARD.
##
## THE DEFECT (device, deploy #19, 8 probes). Dragging the bare background or the
## thin scrollbar scrolled the page. Dragging anywhere inside a section card did
## nothing, in BOTH scene mode and the in-campaign overlay. That is the exact
## signature of T4-01/T9-45: `Control.mouse_filter` defaults to MOUSE_FILTER_STOP on
## PanelContainer, HSeparator, CheckBox, OptionButton and SpinBox, and per the Godot
## 4.6 docs a STOP control's events "are automatically marked as handled, preventing
## them from propagating further" — handled whether or not the widget did anything
## with them. The finger lands on a card, the event dies there, and the
## ScrollContainer above never sees a drag.
##
## WHY THIS SCREEN AND NOT THE OTHERS. `_create_section_card()`
## (SettingsScreen.gd:831) builds a bare `PanelContainer.new()` and sets no
## mouse_filter, and SettingsScreen `extends Control` — so it inherits neither
## `BaseCampaignPanel._fix_touch_scroll_filters()` nor `BasePhasePanel`'s, and never
## called TouchScrollOpener. It had no sweep at all.
##
## WHAT THIS ASSERTS AND WHAT IT CANNOT. It asserts the STATE the sweep leaves
## behind, which is the greppable half. It cannot prove a finger scrolls the page —
## Godot does not deliver InputEvents in headless mode, which is why the device walk
## is still the authority. Deliberately checked with a COUNT as well as a state scan:
## a sweep that runs before the children exist silently opens nothing, and "0 opened"
## would otherwise be indistinguishable from "nothing needed opening".

const SettingsScreenScript = preload("res://src/ui/screens/settings/SettingsScreen.gd")
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")


func _all_descendants(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		out.append(child)
		_all_descendants(child, out)


func _is_skipped(c: Control) -> bool:
	for cls: String in TouchScrollOpenerRef._SKIP:
		if c.is_class(cls):
			return true
	return false


func _build() -> SettingsScreen:
	# overlay_mode mirrors the production construction path and, as a bonus, makes
	# _enter_tree()/_exit_tree() return early so this suite can never touch the
	# developer's real user://window.ini (the T11-04 cross-suite hazard).
	var screen: SettingsScreen = auto_free(SettingsScreenScript.new())
	screen.overlay_mode = true
	add_child(screen)
	await await_idle_frame()
	return screen


func test_no_card_chrome_is_left_swallowing_touch_drags() -> void:
	var screen := await _build()
	var nodes: Array[Node] = []
	_all_descendants(screen, nodes)

	var offenders: Array[String] = []
	for n in nodes:
		if not (n is Control):
			continue
		var c := n as Control
		if _is_skipped(c):
			continue
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			offenders.append("%s (%s)" % [c.name, c.get_class()])

	assert_array(offenders).override_failure_message(
		"These controls still mark touch events HANDLED, so a drag on top of one "
		+ "never reaches the ScrollContainer: %s. Call "
		% [offenders] + "TouchScrollOpenerRef.open_subtree(self) at the END of "
		+ "_build_ui(), after every section has been built."
	).is_empty()


func test_the_sweep_actually_ran_over_populated_content() -> void:
	var screen := await _build()
	# Re-running is idempotent (STOP -> PASS only). If the shipped sweep really ran
	# after the sections were built, a second pass finds nothing left to open.
	# A non-zero count here means the shipped call ran too EARLY — the failure mode
	# TouchScrollOpener's own docblock warns about, and the reason T9-45 survived.
	var leftover: int = TouchScrollOpenerRef.open_subtree(screen)
	assert_int(leftover).override_failure_message(
		"A second sweep opened %d more control(s), so the shipped sweep ran before "
		% [leftover] + "the content existed and opened only part of the tree."
	).is_equal(0)

	# ...and prove the screen is genuinely card-heavy, so case 1 is not vacuously
	# green against a screen that happens to contain no STOP chrome at all.
	var nodes: Array[Node] = []
	_all_descendants(screen, nodes)
	var panels: int = 0
	for n in nodes:
		if n is PanelContainer or n is HSeparator:
			panels += 1
	assert_int(panels).override_failure_message(
		"Expected the Options page to be built from section cards; found %d "
		% [panels] + "PanelContainer/HSeparator nodes. If this is 0 the other case "
		+ "proves nothing."
	).is_greater(4)
