extends SceneTree
## Measure ONE screen's fit at ONE size, in isolation, with the drivers named.
##
## Run (NO --headless: DisplayServer returns dummy values there, so every resize is a
## no-op and all three arms would measure a single geometry):
##
##   godot --path <root> --script res://tests/tools/probe_screen_fit.gd -- \
##       screen=res://src/ui/screens/settings/SettingsScreen.tscn w=360 h=640 \
##       campaign=user://saves/<x>.save
##
## Three arms, one variable each:
##
##   A  build with the screen's own window-state restore LIVE - what the sweeps see
##   B  build with the restore DISABLED, at the requested size - what a DEVICE sees
##   C  arm B's instance rotated to landscape and back - what a rotation does
##
## Arm A and arm B differ only for a screen that MOVES THE WINDOW on entry. That is not
## hypothetical: `SettingsScreen._enter_tree()` restores `user://window.ini` and applies
## its saved size (SettingsScreen.gd:127-129), and `_exit_tree()` writes the current size
## back - so `verify_layout.gd`, which builds a fresh instance per size, was measuring it
## ONE SIZE BEHIND on every configuration and reporting six passes at sizes it never
## achieved (T11-04). Arm B disables that by pointing `_window_config_path` at a file that
## does not exist, which changes exactly one thing and never touches the user's real
## window.ini; the probe deletes the scratch file `_exit_tree` writes.
##
## Two reports, because an overflow NUMBER names the outermost consequence and never the
## cause:
##
##   * a MIN-WIDTH SPINE - descend into the widest-minimum child until a leaf, so the last
##     line is the node to fix. Start reading at the first CONTAINER: a plain `Control`
##     does not aggregate its children's minimums and reports min.x 0.00.
##   * an UNWRAPPED-LABEL census - a Label with autowrap OFF demands its full text width,
##     and that width comes from a STRING, so it is invisible to grep and only a
##     measurement with real font metrics finds it.
##
## Nothing here is filtered by "is it inside a ScrollContainer": a scroll with its
## horizontal axis DISABLED PROPAGATES its child's minimum on that axis instead of
## absorbing it, so the driver is routinely inside the scroll while the overflow is
## reported outside it.

var TARGET := Vector2i(393, 851)
var SCREEN := "res://src/ui/screens/settings/SettingsScreen.tscn"

## A scratch path that does not exist, so the restore in _enter_tree finds no file.
const NO_STATE_PATH := "user://__probe_no_window_state.ini"

var _frame := 0
var _started := false


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_force_windowed()
	_stub_legal_consent()
	_load_requested_campaign()
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a.begins_with("w="):
			TARGET.x = int(a.substr(2))
		elif a.begins_with("h="):
			TARGET.y = int(a.substr(2))
		elif a.begins_with("screen="):
			SCREEN = a.substr("screen=".length())
	if not ResourceLoader.exists(SCREEN):
		push_error("probe_screen_fit: no such scene: %s" % SCREEN)
		quit(2)
		return
	print("=== SCREEN FIT PROBE: %s @ %dx%d ==="
		% [SCREEN.get_file(), TARGET.x, TARGET.y])
	print("stretch: content_scale_size=%s factor=%.4f mode=%d aspect=%d" % [
		str(root.content_scale_size), root.content_scale_factor,
		root.content_scale_mode, root.content_scale_aspect])
	_print_window_ini()
	await _arm_a()
	await _arm_b_and_c()
	_cleanup_scratch()
	print("
=== END ===")
	quit(0)


func _print_window_ini() -> void:
	var wc := ConfigFile.new()
	if wc.load("user://window.ini") != OK:
		print("user://window.ini: absent")
		return
	print("user://window.ini: size=%s mode=%s" % [
		str(wc.get_value("main", "size", "-")), str(wc.get_value("main", "mode", "-"))])


## ARM A - exactly what the two sweeps do, with the restore LIVE.
func _arm_a() -> void:
	print("
---- ARM A: restore LIVE (what both sweeps actually measure) ----")
	if not await _apply_size(TARGET.x, TARGET.y):
		print("  window refused the target resize - arm NOT run")
		return
	print("  window BEFORE the screen exists : %s   ds %s" % [
		str(DisplayServer.window_get_size()), str(root.get_visible_rect().size)])
	var inst: Node = _build()
	await _settle(inst)
	print("  window AFTER _enter_tree        : %s   ds %s" % [
		str(DisplayServer.window_get_size()), str(root.get_visible_rect().size)])
	_overlay_net(inst)
	await _settle(inst)
	print("  [verify_layout's measurement - a fresh instance, measured where it landed]")
	_report(inst, root.get_visible_rect().size)

	# Now do what verify_rotation does: resize the SAME instance to the target.
	if await _apply_size(TARGET.x, TARGET.y):
		await _settle(inst)
		print("  [verify_rotation's measurement - same instance, resized to %dx%d]"
			% [TARGET.x, TARGET.y])
		_report(inst, root.get_visible_rect().size)
	inst.queue_free()
	await process_frame


## ARM B - restore DISABLED, so the screen is BUILT at the phone size.
## ARM C - that same instance rotated to landscape and back.
func _arm_b_and_c() -> void:
	print("
---- ARM B: restore DISABLED, screen BUILT at %dx%d ----"
		% [TARGET.x, TARGET.y])
	if not await _apply_size(TARGET.x, TARGET.y):
		print("  window refused the target resize - arm NOT run")
		return
	var inst: Node = _build(NO_STATE_PATH)
	await _settle(inst)
	print("  window AFTER _enter_tree        : %s   ds %s" % [
		str(DisplayServer.window_get_size()), str(root.get_visible_rect().size)])
	_overlay_net(inst)
	await _settle(inst)
	_report(inst, root.get_visible_rect().size)

	print("
---- ARM C: the SAME instance, rotated landscape and back ----")
	if not await _apply_size(TARGET.y, TARGET.x):
		print("  window refused the landscape resize - arm NOT run")
		inst.queue_free()
		return
	await _settle(inst)
	print("  at landscape %s:" % str(root.get_visible_rect().size))
	_report(inst, root.get_visible_rect().size)
	if not await _apply_size(TARGET.x, TARGET.y):
		print("  window refused the portrait resize - arm NOT run")
		inst.queue_free()
		return
	await _settle(inst)
	print("  back at portrait %s:" % str(root.get_visible_rect().size))
	_report(inst, root.get_visible_rect().size)
	inst.queue_free()
	await process_frame


## `_window_config_path` is a plain var, so it can be redirected between
## instantiate() and add_child() - _enter_tree fires on add_child, not before.
func _build(config_path: String = "") -> Node:
	var ps: PackedScene = load(SCREEN)
	var inst: Node = ps.instantiate()
	# Only SettingsScreen declares this; every other screen simply has nothing to
	# disable, which is itself worth knowing - arm A and arm B agreeing PROVES the
	# screen does not move the window.
	if not config_path.is_empty() and "_window_config_path" in inst:
		inst._window_config_path = config_path
	root.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	return inst


func _cleanup_scratch() -> void:
	if FileAccess.file_exists(NO_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(NO_STATE_PATH))


## Print the worst overflow AND the top few widest nodes with their minimums, so a
## stale rect and a genuinely-too-wide minimum cannot be confused for each other.
func _report(inst: Node, ds: Vector2) -> void:
	var rows: Array = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var ctl := node as Control
		var r: Rect2 = ctl.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if _inside_scroll(ctl, inst):
			continue
		var off: float = maxf(
			maxf(-r.position.x, r.end.x - ds.x),
			maxf(-r.position.y, r.end.y - ds.y))
		rows.append({
			"name": String(ctl.name), "cls": ctl.get_class(), "off": off,
			"rect": r, "min": ctl.get_combined_minimum_size(),
			"cmin": ctl.custom_minimum_size,
		})
	rows.sort_custom(func(a, b): return a["off"] > b["off"])
	if rows.is_empty():
		print("  NO visible controls - the screen did not build")
		return
	if rows[0]["off"] <= 0.5:
		print("  CLEAN (%d visible controls, worst off %.1f px)" % [
			rows.size(), rows[0]["off"]])
		_grow_both_nodes(inst, ds)
		_sibling_overlaps(inst, 6)
		return
	print("  OVERFLOW - %d visible controls, worst offenders:" % rows.size())
	_min_width_spine(inst)
	_unwrapped_labels(inst, ds)
	_grow_both_nodes(inst, ds)
	_sibling_overlaps(inst, 6)
	for i in range(mini(4, rows.size())):
		var e: Dictionary = rows[i]
		print("    %-22s %-16s off %7.1f  rect %s  min %s  custom_min %s" % [
			e["name"], e["cls"], e["off"], str(e["rect"]), str(e["min"]),
			str(e["cmin"])])


## Every Label with autowrap OFF whose unwrapped text is wider than the viewport.
## This is the second-commonest driver after a hardcoded floor, and unlike a floor it
## is invisible in the source - the width comes from the STRING, so only a measurement
## with real font metrics can name it.
func _unwrapped_labels(inst: Node, ds: Vector2) -> void:
	var rows: Array = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Label) or not (n as Label).is_visible_in_tree():
			continue
		var l := n as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			continue
		var w: float = l.get_combined_minimum_size().x
		if w > ds.x:
			rows.append({"w": w, "t": l.text})
	if rows.is_empty():
		return
	rows.sort_custom(func(a, b): return a["w"] > b["w"])
	print("  unwrapped Labels wider than the %.0f px viewport:" % ds.x)
	for e in rows:
		print("    %7.1f px  \"%s\"" % [e["w"], e["t"].replace("
", " ")])


## Walk DOWN the widest-minimum child at each level until a leaf.
##
## A container's minimum width is imposed by ONE child (the max, for a VBox) or by a
## sum (an HBox), so an overflow figure alone never names the node to fix - it names
## the outermost consequence. This prints the chain, so the last line is the actual
## driver. Nothing here is filtered by _inside_scroll: a ScrollContainer with its
## horizontal axis DISABLED propagates its content's minimum width straight up, which
## is exactly the T11-01 mechanism on the other axis, so the driver is very often
## INSIDE the scroll even though the overflow is reported outside it.
func _min_width_spine(inst: Node) -> void:
	print("  min-width spine (each line imposes the next one's width):")
	var node: Node = inst
	var depth := 0
	while node != null and depth < 24:
		var ctl := node as Control
		if ctl == null:
			return
		print("    %s%-20s %-18s min.x %7.2f  custom_min.x %6.1f%s" % [
			"  ".repeat(depth), String(ctl.name), ctl.get_class(),
			ctl.get_combined_minimum_size().x, ctl.custom_minimum_size.x,
			_label_note(ctl)])
		var best: Control = null
		var best_w := -1.0
		for c in ctl.get_children():
			if not (c is Control) or not (c as Control).is_visible_in_tree():
				continue
			var w: float = (c as Control).get_combined_minimum_size().x
			if w > best_w:
				best_w = w
				best = c as Control
		if best == null:
			return
		node = best
		depth += 1


## A Label with autowrap OFF demands its full unwrapped text width as a minimum, and
## that is the single most common driver of this shape - so name it explicitly rather
## than leaving the reader to guess from a number.
func _label_note(ctl: Control) -> String:
	if ctl is Label:
		var l := ctl as Label
		var wrap := "AUTOWRAP OFF" if l.autowrap_mode == TextServer.AUTOWRAP_OFF 			else "autowrap on"
		return "  [Label %s, %d chars: %s]" % [
			wrap, l.text.length(), l.text.substr(0, 48).replace("
", " ")]
	if ctl is RichTextLabel:
		var r := ctl as RichTextLabel
		return "  [RichTextLabel fit_content=%s autowrap=%d]" % [
			str(r.fit_content), r.autowrap_mode]
	if ctl is ScrollContainer:
		var sc := ctl as ScrollContainer
		return "  [ScrollContainer h_mode=%d v_mode=%d]" % [
			sc.horizontal_scroll_mode, sc.vertical_scroll_mode]
	return ""


## Full-rect nodes with grow BOTH, and whether they are visible.
##
## `grow_horizontal/grow_vertical = 2` (GROW_DIRECTION_BOTH) on a node anchored full-rect
## means an over-minimum grows it in BOTH directions - off the top AND the bottom, or off
## both sides - which is the shape behind T11-01 and T11-04. Several of these ship
## `visible = false` and are only measured once something shows them, so a sweep finding
## on one can be ORDER-DEPENDENT: it depends on what state a previous screen left behind.
## Printing visibility alongside the geometry is what tells the two apart.
func _grow_both_nodes(inst: Node, ds: Vector2) -> void:
	var rows: Array = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control):
			continue
		var c2 := n as Control
		if c2.grow_horizontal != Control.GROW_DIRECTION_BOTH \
				and c2.grow_vertical != Control.GROW_DIRECTION_BOTH:
			continue
		if c2.anchor_right != 1.0 or c2.anchor_bottom != 1.0:
			continue
		rows.append(c2)
	if rows.is_empty():
		return
	print("  full-rect nodes with grow BOTH (the T11-01/T11-04 shape):")
	for c2 in rows:
		var vis: bool = c2.is_visible_in_tree()
		var m: Vector2 = c2.get_combined_minimum_size()
		print("    %-22s %-16s visible=%-5s min %s  rect %s%s" % [
			String(c2.name), c2.get_class(), str(vis), str(m),
			str(c2.get_global_rect()),
			"   <-- MIN EXCEEDS THE VIEWPORT" if (m.x > ds.x + 0.5
				or m.y > ds.y + 0.5) else ""])


## Overlapping ANCHORED siblings, with the rects that caused it.
##
## `verify_layout.gd` reports these as "X is drawn ON TOP OF Y (WxH of overlap)", which
## names the pair but not the reason. A node placed by absolute position and size only
## overlaps a sibling if it GREW past what it was assigned - and a Control cannot be
## smaller than `get_combined_minimum_size()`, so the difference between the size that
## was ASSIGNED and the size the node actually HAS is the whole diagnosis. Print both.
func _sibling_overlaps(inst: Node, limit: int) -> void:
	var rows: Array = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var ctl := n as Control
		var parent := ctl.get_parent()
		if parent == null or parent is Container or not (parent is Control):
			continue
		var r: Rect2 = ctl.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		for sibling in parent.get_children():
			if sibling == ctl or not (sibling is Control):
				continue
			var sib := sibling as Control
			if not sib.is_visible_in_tree() or sib.get_index() > ctl.get_index():
				continue
			var sr: Rect2 = sib.get_global_rect()
			if sr.size.x <= 0.0 or sr.size.y <= 0.0 or sr.encloses(r):
				continue
			var hit: Rect2 = r.intersection(sr)
			if hit.size.x <= 0.5 or hit.size.y <= 0.5:
				continue
			rows.append({"a": ctl, "b": sib, "hit": hit})
	if rows.is_empty():
		print("  no sibling overlaps")
		return
	rows.sort_custom(func(x, y):
		return x["hit"].size.x * x["hit"].size.y > y["hit"].size.x * y["hit"].size.y)
	print("  %d overlapping sibling pairs (worst first):" % rows.size())
	for i in range(mini(limit, rows.size())):
		var e: Dictionary = rows[i]
		var a := e["a"] as Control
		var b := e["b"] as Control
		print("    overlap %5.1f x %5.1f" % [e["hit"].size.x, e["hit"].size.y])
		_describe(a, "      ON TOP ")
		_describe(b, "      under  ")


## A node's assigned box versus the box it actually occupies. `min` is the floor it
## cannot go below, so `size > min` means it was given the space and `size == min` with
## `size > assigned` means the MINIMUM is what pushed it out.
func _describe(ctl: Control, tag: String) -> void:
	var extra := ""
	if ctl is Label:
		var l := ctl as Label
		extra = "  [Label clip=%s wrap=%d fs=%d \"%s\"]" % [
			str(l.clip_text), l.autowrap_mode,
			l.get_theme_font_size("font_size"), l.text.substr(0, 24)]
	elif ctl is RichTextLabel:
		var rt := ctl as RichTextLabel
		extra = "  [RichTextLabel fit=%s clip_contents=%s fs=%d]" % [
			str(rt.fit_content), str(rt.clip_contents),
			rt.get_theme_font_size("normal_font_size")]
	# The printable sheets stash each field's SOURCE-PNG rect on the node, so a display
	# rect that overlaps while the source rects do not localises the fault to the
	# scaling rather than to the coordinate manifest.
	var src := ""
	if ctl.has_meta("sheet_src_rect"):
		src = "  src %s" % str(ctl.get_meta("sheet_src_rect"))
	print("%s%-16s rect %s  min %s%s%s" % [
		tag, ctl.get_class(), str(ctl.get_global_rect()),
		str(ctl.get_combined_minimum_size()), src, extra])


func _inside_scroll(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _overlay_net(inst: Node) -> void:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so == null:
		return
	if so.has_method("_update_visibility"):
		so._update_visibility()
	if so.has_method("reserve_band_on"):
		so.reserve_band_on(inst)


func _settle(inst: Node) -> void:
	var last := ""
	var stable := 0
	for _i in range(40):
		await process_frame
		var sig := _signature(inst)
		if sig == last:
			stable += 1
			if stable >= 3:
				return
		else:
			stable = 0
			last = sig


func _signature(inst: Node) -> String:
	var acc := 0.0
	var n := 0
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node is Control and (node as Control).is_visible_in_tree():
			var r: Rect2 = (node as Control).get_global_rect()
			acc += r.position.x + r.position.y * 3.0 + r.size.x * 7.0 + r.size.y * 11.0
			n += 1
	return "%d:%.2f" % [n, acc]


func _apply_size(w: int, h: int) -> bool:
	DisplayServer.window_set_size(Vector2i(w, h))
	for _i in range(40):
		await process_frame
		var got: Vector2i = DisplayServer.window_get_size()
		if absi(got.x - w) <= 2 and absi(got.y - h) <= 2:
			for _j in range(3):
				await process_frame
			return true
	return false


func _force_windowed() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("probe_settings_width: run WITHOUT --headless.")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var scr: int = DisplayServer.window_get_current_screen()
	DisplayServer.window_set_position(
		DisplayServer.screen_get_usable_rect(scr).position + Vector2i(8, 8))


## In memory only. NEVER call accept_eula()/accept_privacy() - that would persist a
## consent no human gave.
func _stub_legal_consent() -> void:
	var lcm := root.get_node_or_null("/root/LegalConsentManager")
	if lcm == null:
		return
	lcm.eula_accepted = true
	lcm.eula_accepted_version = lcm.EULA_VERSION
	lcm.privacy_accepted = true
	lcm.privacy_accepted_version = lcm.PRIVACY_VERSION


## The sweeps run with a campaign loaded, and SettingsScreen shows rows that only
## exist then - so a probe without one measures a DIFFERENT screen and can miss
## findings the sweep reports. Same lesson as the populate layer, one level up.
func _load_requested_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty() or not FileAccess.file_exists(wanted):
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs and gs.has_method("load_campaign"):
		gs.load_campaign(wanted)
