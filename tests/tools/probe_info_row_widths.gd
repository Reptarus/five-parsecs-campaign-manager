extends SceneTree
## Measure what _create_info_row ACTUALLY renders, so the starvation test's threshold is
## set from data instead of from my arithmetic.

var _frame := 0
var _screen: CampaignScreenBase
var _rows: Array = []

const LONG := "Old nemesis (persistent, +1 enemies)"


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 1:
		_screen = CampaignScreenBase.new()
		root.add_child(_screen)
		for spec in [[LONG, "Corporate"], ["Type", "Corporate"]]:
			for w in [384.0, 800.0]:
				var hb: HBoxContainer = _screen._create_info_row(spec[0], spec[1])
				_screen.add_child(hb)
				hb.size = Vector2(w, 32.0)
				_rows.append([hb, w, spec[0]])
		return false
	if _frame < 4:
		return false
	var rm := root.get_node_or_null("/root/ResponsiveManager")
	print("font multiplier context: viewport=%s" % root.get_visible_rect().size)
	if rm:
		print("responsive font size for SM(12) = %d"
			% rm.get_responsive_font_size(12))
	for r in _rows:
		var hb: HBoxContainer = r[0]
		var nm: Label = hb.get_child(0)
		var vl: Label = hb.get_child(1)
		print("row w=%4.0f  label=%-38s | name %6.1f x %5.1f (min %6.1f) | value %6.1f x %5.1f (min %5.1f)"
			% [r[1], '"' + str(r[2]).substr(0, 34) + '"',
			nm.size.x, nm.size.y, nm.get_combined_minimum_size().x,
			vl.size.x, vl.size.y, vl.get_combined_minimum_size().x])
	quit(0)
	return true
