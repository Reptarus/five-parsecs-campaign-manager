extends SceneTree
## Settle two claims empirically before either goes into the harness or the SOP.
##
## 1. Does Godot 4.6 have a MAXIMUM size on Control? The 4.6 class reference documents
##    get_bound_minimum_size() as "the bound value of get_combined_minimum_size() by
##    get_combined_maximum_size() ... maximum size has priority over minimum size",
##    which implies custom_maximum_size exists. This project's SOP says the opposite
##    ("Control has NO custom_maximum_size in Godot 4.6 — writing it aborts at
##    runtime") and several screens cap width with a CenterContainer trick because of
##    it. One of the two is wrong; whichever it is, it is worth knowing exactly.
##
## 2. What does a horizontal BoxContainer actually give an autowrapping child with the
##    default size flags, versus with EXPAND? That is the slab bug, measured.

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
	var probe := Control.new()
	root.add_child(probe)

	print("--- 1. maximum size ---")
	var props := probe.get_property_list()
	var has_max := false
	for p in props:
		if String(p.get("name", "")) == "custom_maximum_size":
			has_max = true
	print("custom_maximum_size in property list: %s" % str(has_max))
	print("has_method get_combined_maximum_size: %s"
		% str(probe.has_method("get_combined_maximum_size")))
	print("has_method get_bound_minimum_size:    %s"
		% str(probe.has_method("get_bound_minimum_size")))
	if has_max:
		probe.custom_minimum_size = Vector2(100, 100)
		probe.set("custom_maximum_size", Vector2(50, 150))
		await process_frame
		print("min=(100,100) max=(50,150) -> combined_min=%s bound_min=%s" % [
			str(probe.get_combined_minimum_size()),
			str(probe.get_bound_minimum_size()) if probe.has_method("get_bound_minimum_size") else "n/a"])

	print("--- 2. autowrapping button in a horizontal BoxContainer ---")
	var row := BoxContainer.new()
	row.vertical = false
	row.custom_minimum_size = Vector2(600, 0)
	root.add_child(row)
	var a := Button.new()
	a.text = "Accept Black Zone Mission"
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(a)
	var b := Button.new()
	b.text = "Travel to Red Zone"
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	for _i in range(4):
		await process_frame
	print("default flags (FILL): min=%s  actual=%s" % [
		str(a.get_combined_minimum_size()), str(a.size)])
	print("EXPAND_FILL:          min=%s  actual=%s" % [
		str(b.get_combined_minimum_size()), str(b.size)])

	print("--- 3. same two buttons in an HFlowContainer ---")
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(600, 0)
	root.add_child(flow)
	var c := Button.new()
	c.text = "Accept Black Zone Mission"
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow.add_child(c)
	var d := Button.new()
	d.text = "Accept Black Zone Mission"
	flow.add_child(d)
	for _i in range(4):
		await process_frame
	print("autowrap in HFlow: min=%s actual=%s" % [
		str(c.get_combined_minimum_size()), str(c.size)])
	print("plain    in HFlow: min=%s actual=%s" % [
		str(d.get_combined_minimum_size()), str(d.size)])
	quit(0)
