extends "res://tests/tools/verify_layout.gd"
## The layout sweep, plus the MIN-WIDTH SPINE of every screen it measures.
##
## An overflow figure names the outermost consequence, never the cause (CLAUDE.md,
## T11-18). This walks from the screen's first Container down through the child with
## the widest combined minimum, so the leaf at the bottom is the node that sets the
## width. A plain Control does not aggregate its children's minimums, which is why the
## walk starts at the first Container rather than at the root.
##
## Run (windowed, like the sweep it extends):
##   godot --path . --script tests/tools/probe_min_width_spine.gd -- only=CharacterDetails
## Add `axis=y` to follow the tallest minimum instead (a vertical overflow).


func _measure(inst: Node, short: String, label: String) -> void:
	super._measure(inst, short, label)
	var axis_y := _user_arg("axis=") == "y"
	print("SPINE %s @ %s  viewport=%s" % [short, label, root.get_visible_rect().size])
	var node: Node = _first_container(inst)
	var depth := 0
	while node != null and depth < 40:
		var ctl := node as Control
		var extra := ""
		if ctl is Label:
			extra = " autowrap=%d text=%s" % [(ctl as Label).autowrap_mode,
				(ctl as Label).text.substr(0, 40).replace("\n", " ")]
		elif ctl is Button:
			extra = " text=%s" % (ctl as Button).text.substr(0, 40)
		print("  %s%s [%s] min=%s size=%s pos.y=%.1f custom=%s%s" % [
			"  ".repeat(depth), ctl.name, ctl.get_class(),
			ctl.get_combined_minimum_size(), ctl.size, ctl.global_position.y,
			ctl.custom_minimum_size, extra])
		node = _widest_child(ctl, axis_y)
		depth += 1


func _first_container(n: Node) -> Node:
	if n is Container:
		return n
	for c in n.get_children():
		var found := _first_container(c)
		if found != null:
			return found
	return null


func _widest_child(n: Node, axis_y: bool = false) -> Node:
	var best: Control = null
	var best_w := -1.0
	for c in n.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		var m: Vector2 = (c as Control).get_combined_minimum_size()
		var w: float = m.y if axis_y else m.x
		if w > best_w:
			best_w = w
			best = c
	return best
