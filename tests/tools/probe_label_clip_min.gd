extends SceneTree
## T11 / Corporate Label — does Label.clip_text BOUND the minimum width?
##
## The Godot 4.6 class reference states this for Button ("the button is always wide
## enough to hold the text") and does NOT state it for Label — the Label entry documents
## only the clipping. The whole _create_info_row fix rests on it, so it is measured here
## rather than assumed.
##
## Measured ACROSS FRAMES on purpose: add_theme_font_size_override() invalidates a
## Control's minimum-size cache and recomputes it only on the NEXT frame (T11-06), so a
## same-frame read of any min-size-affecting property is not trustworthy in this engine.

var _frame := 0
var _lbl: Label
var _same_frame := Vector2.ZERO


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 1:
		_lbl = Label.new()
		_lbl.text = "Old nemesis (persistent, +1 enemies)"
		root.add_child(_lbl)
		return false
	if _frame == 2:
		print("plain Label            min = %s" % _lbl.get_combined_minimum_size())
		_lbl.clip_text = true
		_same_frame = _lbl.get_combined_minimum_size()
		print("clip_text (SAME frame) min = %s" % _same_frame)
		return false
	if _frame == 3:
		print("clip_text (NEXT frame) min = %s" % _lbl.get_combined_minimum_size())
		_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		return false
	if _frame == 4:
		print("+ ellipsis             min = %s" % _lbl.get_combined_minimum_size())
		var autow := Label.new()
		autow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		autow.text = "Old nemesis (persistent, +1 enemies)"
		root.add_child(autow)
		_lbl = autow
		return false
	if _frame == 5:
		print("autowrap (the VALUE)   min = %s" % _lbl.get_combined_minimum_size())
		quit(0)
	return false
