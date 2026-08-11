# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends CanvasLayer


signal tutorial_completed
signal tutorial_skipped

const DIMMED_COLOR := Color(0, 0, 0, 0.6)
const HIGHLIGHT_BORDER_COLOR := UIColors.COLOR_CYAN
const ANIMATION_TIME := 0.3

# Layer 95: between Notifications (90) and Loading (99)
const TUTORIAL_LAYER := 95

var _dimmed_rect: ColorRect
var _highlight_border: ReferenceRect
var _tooltip_panel: PanelContainer
var _tooltip_label: Label
var _step_label: Label
var _next_button: Button
var _skip_button: Button

var current_step := 0
var tutorial_steps: Array
var current_tween: Tween

func _ready() -> void:
	layer = TUTORIAL_LAYER
	_setup_overlay()
	set_process_input(true)

func _setup_overlay() -> void:
	# Full-screen dim background (blocks clicks on dimmed areas)
	_dimmed_rect = ColorRect.new()
	_dimmed_rect.color = DIMMED_COLOR
	_dimmed_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmed_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dimmed_rect)

	# Highlight border around target element
	_highlight_border = ReferenceRect.new()
	_highlight_border.border_color = HIGHLIGHT_BORDER_COLOR
	_highlight_border.border_width = 3.0
	_highlight_border.editor_only = false
	_highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight_border)

	# Tooltip panel with Deep Space styling
	_tooltip_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.COLOR_PRIMARY
	panel_style.border_color = UIColors.COLOR_CYAN
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_tooltip_panel.add_theme_stylebox_override("panel", panel_style)
	_tooltip_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_tooltip_panel)

	# Layout inside tooltip
	var tooltip_vbox := VBoxContainer.new()
	tooltip_vbox.add_theme_constant_override("separation", 8)
	_tooltip_panel.add_child(tooltip_vbox)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_tooltip_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(14))
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_vbox.add_child(_tooltip_label)

	# Step indicator + buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	tooltip_vbox.add_child(btn_row)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(11))
	_step_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_step_label)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.flat = true
	_skip_button.custom_minimum_size = Vector2(60, 36)
	_skip_button.add_theme_font_size_override("font_size", ScreenChrome.font_size(13))
	_skip_button.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	_skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(80, 36)
	_next_button.add_theme_font_size_override("font_size", ScreenChrome.font_size(13))
	var next_style := StyleBoxFlat.new()
	next_style.bg_color = UIColors.COLOR_BLUE
	next_style.set_corner_radius_all(4)
	_next_button.add_theme_stylebox_override("normal", next_style)
	_next_button.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_next_button.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_button)

	# Initially hidden
	hide_overlay()

## Find the Control a coach mark should point at.
##
## ⚠ AN ABSOLUTE NODE PATH IS NOT A STABLE ADDRESS IN THIS APP. Several screens
## REPARENT their tree at runtime, so the live tree does not match the `.tscn` the
## paths in `data/tutorials/*.json` were written against:
##   - `ShortScreenScroll.setup(column, pinned)` moves every child after the pinned
##     ones into `ContentScroll/ScrollColumn` — CampaignDashboard.gd:93 does this to
##     `MarginContainer/VBoxContainer`, so `.../VBoxContainer/HeaderPanel` becomes
##     `.../VBoxContainer/ContentScroll/ScrollColumn/HeaderPanel`
##   - `_setup_adaptive_panels()` moves the three info columns into an AdaptivePanelGroup
##   - the app bar is moved to index 0, changing which child is "first"
##
## That is why these paths have now broken TWICE (once when the screens gained scroll
## containers, again when they gained the short-screen scroll), each time silently: the
## no-target branch below is legitimate for the welcome step, so a broken path just
## looks like a centred tooltip. Device log, Aug 9 2026:
##   `MarginContainer/VBoxContainer/HeaderPanel` did not resolve in scene
##   `CampaignDashboard` — while that exact path DOES exist in CampaignDashboard.tscn.
##
## So: try the authored path first (exact, and free when it works), then fall back to
## searching by the LEAF NAME anywhere in the scene. Node names survive reparenting;
## paths do not.
## `search_root` defaults to the running scene; it is a parameter so the resolver can be
## tested against a tree of its own instead of by reassigning get_tree().current_scene.
func _resolve_target(target_path: String, search_root: Node = null) -> Control:
	var root: Node = search_root if search_root != null else get_tree().current_scene
	if root == null:
		return null

	var exact := root.get_node_or_null(target_path)
	if exact is Control:
		return exact

	# `owned` MUST be false. It defaults to true, which only matches nodes with an
	# `owner` set — and the nodes that do the reparenting here (ContentScroll,
	# ScrollColumn, AdaptivePanelGroup) are created at runtime with none. Verified
	# against this engine build: with owned=true the same search returns null.
	var leaf := target_path.get_slice("/", target_path.get_slice_count("/") - 1)
	if leaf.is_empty():
		return null
	var found := root.find_child(leaf, true, false)
	return found as Control if found is Control else null


func start_tutorial(steps: Array) -> void:
	tutorial_steps = steps
	current_step = 0
	show_current_step()

func show_current_step() -> void:
	if current_step >= tutorial_steps.size():
		complete_tutorial()
		return

	var step: Dictionary = tutorial_steps[current_step]
	var target_path: String = step.get("target_path", "")
	var target: Control = null

	if not target_path.is_empty():
		target = _resolve_target(target_path)

	# CONTENT AND SIZE FIRST, then position.
	#
	# T8-05 (tablet QA, Aug 8 2026): this block used to run AFTER the positioning
	# calls below, so both _position_tooltip() and _center_tooltip() measured
	# _tooltip_panel.size on a panel that was still empty and hidden. Combined with
	# the autowrap label having no definite width to wrap against, the panel
	# resolved to a tall narrow column instead of a bubble.
	#
	# Observed on the Campaign Dashboard "?" tour: a full-height slab ~234 logical
	# px wide, centred at x=(1728-234)/2 — no readable text, no step counter, and
	# no Next/Skip, so the tour could not be advanced or dismissed. Four taps across
	# the screen did nothing; only Android Back escaped, and desktop has no Back.
	#
	# An autowrap Label's minimum width is near ZERO (CLAUDE.md records the same
	# trap collapsing the ship-debt row into a 480px-tall slab), so it must be given
	# a definite wrap width or Godot derives its height from a ~1px line box.
	_tooltip_label.text = step.get("text", "")
	_step_label.text = "%d / %d" % [current_step + 1, tutorial_steps.size()]
	_next_button.text = "Done" if current_step == tutorial_steps.size() - 1 else "Next"
	_apply_tooltip_width()
	_tooltip_panel.visible = true
	_dimmed_rect.visible = true

	if target and target is Control:
		# Ensure visible in scroll containers
		var scroll := _find_parent_scroll(target)
		if scroll:
			scroll.ensure_control_visible(target)
		var target_rect := target.get_global_rect()
		_animate_highlight(target_rect)
		_position_tooltip(target_rect, step.get("tooltip_position", "bottom"))
	else:
		# No target — center the tooltip.
		#
		# This fallback is legitimate for the deliberately target-less welcome
		# step, but it also silently absorbed six BROKEN paths: the coach marks
		# kept pointing at pre-scroll-container node paths long after MainMenu
		# gained MenuScroll and CampaignDashboard gained MainScroll, so 6 of 10
		# steps highlighted nothing and nobody noticed. Warn on a path that was
		# specified but did not resolve, so the next scene refactor is loud.
		if not target_path.is_empty():
			push_warning(
				"TutorialOverlay: step %d target '%s' did not resolve in scene '%s' — "
				% [current_step + 1, target_path,
					get_tree().current_scene.name if get_tree().current_scene else "?"]
				+ "highlighting nothing. Scene paths probably drifted.")
		_highlight_border.visible = false
		_center_tooltip()


## Give the bubble a definite wrap width, then let it shrink to fit its text.
##
## Sized off the viewport so a phone gets a narrower bubble than a tablet, and
## clamped at both ends: below ~280 the buttons row stops fitting on one line,
## above ~460 the prose gets uncomfortably wide to read.
func _apply_tooltip_width() -> void:
	var vp := Vector2(1152, 648)
	if is_inside_tree() and get_viewport():
		vp = get_viewport().get_visible_rect().size
	var wrap_w: float = clampf(vp.x * 0.30, 280.0, 460.0)
	_tooltip_label.custom_minimum_size.x = wrap_w
	_tooltip_panel.custom_minimum_size = Vector2(wrap_w, 0)
	# Give the panel the width NOW as well as a minimum. reset_size() cannot be
	# called here: a Godot 4 Label with autowrap derives its minimum HEIGHT from its
	# CURRENT width, so until a layout pass has actually applied wrap_w the label
	# still reports the height of a ~1px line box (measured: 3640px for three
	# sentences). _settle_tooltip_size() does the shrink after that pass.
	_tooltip_panel.size = Vector2(wrap_w, _tooltip_panel.size.y)


## Let layout apply the wrap width, then shrink the panel to its real content.
##
## Two frames, not one: the first gives the label its width, the second lets the
## label report a minimum height derived from that width.
func _settle_tooltip_size() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.reset_size()

func _find_parent_scroll(node: Node) -> ScrollContainer:
	var parent := node.get_parent()
	while parent:
		if parent is ScrollContainer:
			return parent
		parent = parent.get_parent()
	return null

func _animate_highlight(target_rect: Rect2) -> void:
	if current_tween:
		current_tween.kill()

	_highlight_border.visible = true
	current_tween = create_tween()
	current_tween.tween_property(
		_highlight_border, "position", target_rect.position - Vector2(4, 4), ANIMATION_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.parallel().tween_property(
		_highlight_border, "size", target_rect.size + Vector2(8, 8), ANIMATION_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Where a coach-mark bubble of `tooltip_size` should sit for `target_rect`.
## Pure and static so the placement rule is testable without an overlay.
##
## T1-02: the old version placed on the hinted side and then CLAMPED into the
## viewport — and the clamp is what broke it. A target low on screen sends a
## "bottom" bubble off the edge, the clamp drags it back up, and it lands ON TOP of
## the control it is supposed to be pointing at. Observed on the main menu: step
## 2/4's bubble covered the "New Campaign" label it was highlighting and spilled
## over "Onboard Existing Game" below, while ~1000px of empty canvas sat unused to
## the left.
##
## A bubble that hides its own subject is worse than no bubble, so overlap is now
## disqualifying rather than a side effect: try the hint, then its opposite, then
## the remaining sides, and take the first that fits AND stays clear. Only if no
## side works does it fall back to clamping — with the LEAST overlapping candidate,
## not whichever the hint happened to name.
static func place_tooltip(
		target_rect: Rect2, tooltip_size: Vector2, viewport_size: Vector2,
		position_hint: String = "bottom", gap: float = 12.0, margin: float = 8.0
) -> Vector2:
	var candidates := {
		"top": Vector2(target_rect.position.x, target_rect.position.y - tooltip_size.y - gap),
		"bottom": Vector2(target_rect.position.x, target_rect.end.y + gap),
		"left": Vector2(target_rect.position.x - tooltip_size.x - gap, target_rect.position.y),
		"right": Vector2(target_rect.end.x + gap, target_rect.position.y),
	}
	var opposite := {"top": "bottom", "bottom": "top", "left": "right", "right": "left"}
	var order: Array[String] = []
	if candidates.has(position_hint):
		order.append(position_hint)
		order.append(str(opposite[position_hint]))
	for side: String in ["bottom", "top", "right", "left"]:
		if side not in order:
			order.append(side)

	var best := Vector2.ZERO
	var best_overlap := INF
	for side: String in order:
		var p: Vector2 = candidates[side]
		# Nudge along the PERPENDICULAR axis only, so staying on-screen can never
		# push the bubble across the target.
		if side == "top" or side == "bottom":
			p.x = clampf(p.x, margin, maxf(margin, viewport_size.x - tooltip_size.x - margin))
		else:
			p.y = clampf(p.y, margin, maxf(margin, viewport_size.y - tooltip_size.y - margin))
		var rect := Rect2(p, tooltip_size)
		var fits := (
			p.x >= margin - 0.01 and p.y >= margin - 0.01
			and p.x + tooltip_size.x <= viewport_size.x - margin + 0.01
			and p.y + tooltip_size.y <= viewport_size.y - margin + 0.01)
		var overlap := 0.0
		var inter := rect.intersection(target_rect)
		if inter.size.x > 0.0 and inter.size.y > 0.0:
			overlap = inter.size.x * inter.size.y
		if fits and overlap <= 0.0:
			return p
		# Track the least-bad option in case nothing fits cleanly.
		var penalty := overlap + (0.0 if fits else 1_000_000.0)
		if penalty < best_overlap:
			best_overlap = penalty
			best = p
	return Vector2(
		clampf(best.x, margin, maxf(margin, viewport_size.x - tooltip_size.x - margin)),
		clampf(best.y, margin, maxf(margin, viewport_size.y - tooltip_size.y - margin)))


func _position_tooltip(target_rect: Rect2, position_hint: String = "bottom") -> void:
	# Wait for the tooltip to settle at its real content size before placing it —
	# placing against a stale size is what put the bubble on top of its own target.
	await _settle_tooltip_size()
	if not is_instance_valid(_tooltip_panel):
		return
	_tooltip_panel.position = place_tooltip(
		target_rect, _tooltip_panel.size,
		get_viewport().get_visible_rect().size, position_hint)

func _center_tooltip() -> void:
	await _settle_tooltip_size()
	if not is_instance_valid(_tooltip_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := _tooltip_panel.size
	# Clamp: a bubble taller than the screen would otherwise centre to a negative
	# y and run off both edges, which is exactly how the dashboard slab rendered.
	_tooltip_panel.position = Vector2(
		maxf(0.0, (viewport_size.x - tooltip_size.x) / 2.0),
		maxf(0.0, (viewport_size.y - tooltip_size.y) / 2.0))

func _on_next_pressed() -> void:
	current_step += 1
	show_current_step()

func _on_skip_pressed() -> void:
	hide_overlay()
	tutorial_skipped.emit()

func complete_tutorial() -> void:
	hide_overlay()
	tutorial_completed.emit()

func hide_overlay() -> void:
	_highlight_border.visible = false
	_dimmed_rect.visible = false
	_tooltip_panel.visible = false
