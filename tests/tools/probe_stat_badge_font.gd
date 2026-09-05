extends SceneTree
## Why does test_stat_badge.gd::test_labels_have_correct_font_sizes expect 11 and get 9?
##
## Run headless — it reads values, it does not measure geometry, and a windowed run
## steals desktop focus for no benefit:
##
##   godot --headless --path . --script res://tests/tools/probe_stat_badge_font.gd
##
## Three hypotheses, all disproved before this was written, recorded so they are not
## re-tried: the persisted window size (`user://window.ini` at 360x640) is NOT the
## trigger — the case fails identically at 360x640, at 1920x1080, and headless; the
## shared theme is NOT mutated on disk (`git status` on sci_fi_theme.tres is clean);
## and none of the Sep 5 desk-pass edits touches StatBadge, ScreenChrome,
## ResponsiveManager or the theme.
##
## What is left is the READ ITSELF. StatBadge sets its size with
## add_theme_font_size_override(), while the test reads
## get_theme_font_size("font_size", "Label") — passing an explicit theme TYPE. If that
## bypasses the node's own override and resolves against the project theme instead, the
## test has never been measuring StatBadge at all; it has been measuring the theme,
## which ResponsiveManager rescales at boot.

const BADGE := "res://src/ui/components/base/StatBadge.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rm := root.get_node_or_null(NodePath("/root/ResponsiveManager"))
	print("=== ResponsiveManager ===")
	if rm == null:
		print("  ABSENT")
	else:
		print("  breakpoint       : %s" % rm.get_breakpoint_name())
		print("  multiplier       : %.2f" % rm.get_font_size_multiplier())
		print("  viewport size    : %s" % str(rm.current_viewport_size))
		print("  screen scale     : %.3f" % rm.get_screen_scale())
		print("  responsive(11)   : %d   <- maxi(9, round(11 * mult))"
			% rm.get_responsive_font_size(11))
		print("  responsive(14)   : %d" % rm.get_responsive_font_size(14))

	var theme := load("res://src/ui/themes/sci_fi_theme.tres") as Theme
	print("")
	print("=== project theme (LIVE, after ResponsiveManager rescaled it) ===")
	if theme == null:
		print("  FAILED TO LOAD")
	else:
		print("  default_font_size            : %d" % theme.default_font_size)
		print("  has Label/font_size override : %s"
			% str(theme.has_font_size("font_size", "Label")))
		if theme.has_font_size("font_size", "Label"):
			print("  Label/font_size              : %d"
				% theme.get_font_size("font_size", "Label"))

	print("")
	print("=== an actual StatBadge ===")
	var script := load(BADGE)
	if script == null:
		print("  FAILED TO LOAD StatBadge.gd")
		quit(1)
		return
	var badge = script.new()
	root.add_child(badge)
	if badge.has_method("configure"):
		badge.configure("HULL", 8)
	await process_frame

	var name_label: Label = badge.get("_name_label") as Label if "_name_label" in badge else null
	var value_label: Label = badge.get("_value_label") as Label if "_value_label" in badge else null

	for pair in [["_name_label", name_label, 11], ["_value_label", value_label, 14]]:
		var who: String = pair[0]
		var lbl: Label = pair[1]
		var authored: int = pair[2]
		print("  %s (authored %d):" % [who, authored])
		if lbl == null:
			print("    NOT FOUND")
			continue
		# What the WIDGET set on itself.
		print("    has_theme_font_size_override      : %s"
			% str(lbl.has_theme_font_size_override("font_size")))
		# What the TEST asks for — note the explicit "Label" theme type.
		print("    get_theme_font_size(.., \"Label\")   : %d   <- what the test asserts on"
			% lbl.get_theme_font_size("font_size", "Label"))
		# The same call WITHOUT a theme type, which is the node's own resolution.
		print("    get_theme_font_size(..)            : %d   <- the widget's real size"
			% lbl.get_theme_font_size("font_size"))

	badge.queue_free()
	print("")
	print("=== done ===")
	quit(0)
