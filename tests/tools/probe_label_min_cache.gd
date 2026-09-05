extends SceneTree

## Is `Control.size` clamped against a STALE minimum after a font-size override?
##
## T11-06's field nodes end up 21 px tall while `get_combined_minimum_size()` reports
## 7. Something clamped `size` against a minimum larger than the one now in effect.
## The suspicion is that `add_theme_font_size_override()` INVALIDATES the minimum-size
## cache rather than recomputing it, so a `size` assignment on the same line is clamped
## against the previous font's line height.
##
## This is the smallest experiment that can distinguish the two possibilities, because
## it reads the same node three times: right after the override, after one frame, and
## after re-assigning the size once the cache has settled.
##
##   Godot_console.exe --path <project> --script tests/tools/probe_label_min_cache.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(800, 600)
	root.add_child(host)
	await process_frame

	var want := Vector2(14.62, 12.64)

	# ── A: font override then size, same frame (what SheetRenderer does) ──
	var a := Label.new()
	a.text = "Bryn Ito"
	host.add_child(a)
	await process_frame
	a.add_theme_font_size_override("font_size", 5)
	a.size = want
	print("A  same frame        : min %s  size %s" % [a.get_combined_minimum_size(), a.size])
	await process_frame
	print("A  next frame        : min %s  size %s" % [a.get_combined_minimum_size(), a.size])
	a.size = want
	print("A  re-assigned       : min %s  size %s" % [a.get_combined_minimum_size(), a.size])

	# ── B: font override, wait, then size ──
	var b := Label.new()
	b.text = "Bryn Ito"
	host.add_child(b)
	b.add_theme_font_size_override("font_size", 5)
	await process_frame
	b.size = want
	print("B  override then wait: min %s  size %s" % [b.get_combined_minimum_size(), b.size])

	# ── D: a FRESH node, configured entirely BEFORE entering the tree ──
	# This is what _build_field_node() does and what _rescale_field_nodes() does NOT:
	# if a never-laid-out node computes its minimum on first request, the override is
	# already in effect and there is no previous font to clamp against.
	var d := Label.new()
	d.text = "Bryn Ito"
	d.clip_text = true
	d.add_theme_font_size_override("font_size", 5)
	d.size = want
	print("D  fresh, pre-tree    : min %s  size %s" % [d.get_combined_minimum_size(), d.size])
	host.add_child(d)
	await process_frame
	print("D  after tree + frame : min %s  size %s" % [d.get_combined_minimum_size(), d.size])

	# ── E: fresh node added to the tree FIRST, then configured same frame ──
	var e := Label.new()
	e.text = "Bryn Ito"
	e.clip_text = true
	host.add_child(e)
	e.add_theme_font_size_override("font_size", 5)
	e.size = want
	print("E  tree then configure: min %s  size %s" % [e.get_combined_minimum_size(), e.size])
	await process_frame
	print("E  after frame        : min %s  size %s" % [e.get_combined_minimum_size(), e.size])

	# ── C: the same node never touched by an override, for a baseline ──
	var c := Label.new()
	c.text = "Bryn Ito"
	host.add_child(c)
	await process_frame
	print("C  default font       : min %s" % c.get_combined_minimum_size())

	quit(0)
