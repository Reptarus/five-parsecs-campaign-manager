extends GdUnitTestSuite
## The consent gate must be SCROLLABLE by touch, or a tester cannot read what they
## are accepting.
##
## FOUND ON HARDWARE, Aug 13 2026 (deploy #6). On the tablet, neither the EULA body
## nor the "Read the Privacy Policy" popup scrolled AT ALL. Six swipes, a slow
## drag, and a direct drag on the scrollbar produced ZERO changed pixels. A tester
## could read as far as "1.1 Data Stored Locally on Your Device" and no further,
## then had to accept documents they were physically unable to read.
##
## `Control.mouse_filter` defaults to `MOUSE_FILTER_STOP`, so a RichTextLabel (or a
## plain CenterContainer) sitting inside a ScrollContainer consumes the touch drag
## before the ScrollContainer can interpret it. Taps still work, which is why the
## screen looks fine: the buttons respond, only the gesture is dead.
##
## This is the SAME class as T4-01, which was fixed and device-verified on Aug 8.
## The fix existed and the regression test existed
## (`test_decorative_chrome_does_not_swallow_the_drag`), but that test is scoped to
## WorldPhaseController — so the FIRST screen in the app was never covered by it.
## Hence this suite: same rule, applied to the legal screens.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const EULAScreenScript = preload("res://src/ui/screens/legal/EULAScreen.gd")
const LegalTextViewerScript = preload("res://src/ui/screens/legal/LegalTextViewer.gd")


## Controls that legitimately need to receive input. Anything else inside a
## ScrollContainer that STOPs is swallowing the drag.
## BaseButton, not Button: LinkButton / CheckBox / CheckButton / TextureButton all
## extend BaseButton WITHOUT extending Button, so a `node is Button` test reports
## the privacy link as a swallower. It is not one; it needs the tap.
func _is_interactive(node: Node) -> bool:
	return node is BaseButton or node is LineEdit or node is TextEdit \
		or node is Slider or node is ItemList or node is ScrollBar


## Every descendant of `root` that would eat a touch drag.
func _swallowers(root: Node) -> Array[String]:
	var bad: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n == root or not (n is Control):
			continue
		if _is_interactive(n):
			continue
		if (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			bad.append("%s (%s)" % [n.name, n.get_class()])
	return bad


func _scroll_containers(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is ScrollContainer:
			out.append(n)
	return out


func _assert_scrollable(screen: Node, label: String) -> void:
	var scrolls := _scroll_containers(screen)
	assert_int(scrolls.size()).override_failure_message(
		"%s has no ScrollContainer at all — a long legal document cannot be read"
		% label).is_greater(0)
	for sc: Node in scrolls:
		var bad := _swallowers(sc)
		assert_array(bad).override_failure_message(
			("%s: these non-interactive controls inside a ScrollContainer default to "
			+ "MOUSE_FILTER_STOP and will swallow the touch drag, making the document "
			+ "unscrollable on a tablet:\n  %s") % [label, ", ".join(bad)]).is_empty()


func test_the_eula_body_can_be_scrolled_by_touch() -> void:
	var screen: Node = EULAScreenScript.new()
	add_child(screen)
	auto_free(screen)
	await await_millis(50)
	_assert_scrollable(screen, "EULAScreen (EULA body)")


## The "Read the Privacy Policy" popup is a SEPARATE construction from the screen
## behind it and from LegalTextViewer. All three had the same defect.
func test_the_privacy_policy_popup_can_be_scrolled_by_touch() -> void:
	var screen: Node = EULAScreenScript.new()
	add_child(screen)
	auto_free(screen)
	await await_millis(50)

	assert_bool(screen.has_method("_on_privacy_link_pressed")).override_failure_message(
		"the privacy link handler was renamed; retarget this test").is_true()
	screen.call("_on_privacy_link_pressed")
	await await_millis(50)

	var dialog: Node = null
	for c in screen.get_children():
		if c is AcceptDialog:
			dialog = c
			break
	assert_object(dialog).override_failure_message(
		"tapping the privacy link produced no dialog").is_not_null()
	_assert_scrollable(dialog, "EULAScreen privacy popup")


func test_the_legal_text_viewer_can_be_scrolled_by_touch() -> void:
	var screen: Node = LegalTextViewerScript.new()
	add_child(screen)
	auto_free(screen)
	await await_millis(50)
	_assert_scrollable(screen, "LegalTextViewer")
