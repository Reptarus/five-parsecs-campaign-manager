extends SceneTree
## Settle one question empirically: what actually reduces a Label's MINIMUM WIDTH?
##
## The docs say clip_text clips what is DRAWN. For Button they also say an unclipped
## button "will always be wide enough to hold the text", implying clipping frees the
## width — but for Label they say nothing about minimum size, and a header fix that
## assumes wrongly is a fix that does nothing. Measure it.

var _frame := 0
var _started := false


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _make(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	return l


func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	var sample := "25 worlds - turn 100"

	var plain := _make(sample)
	host.add_child(plain)
	var clipped := _make(sample)
	clipped.clip_text = true
	host.add_child(clipped)
	var ellipsis := _make(sample)
	ellipsis.clip_text = true
	ellipsis.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host.add_child(ellipsis)
	var wrapped := _make(sample)
	wrapped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(wrapped)

	var btn_plain := Button.new()
	btn_plain.text = sample
	host.add_child(btn_plain)
	var btn_clipped := Button.new()
	btn_clipped.text = sample
	btn_clipped.clip_text = true
	host.add_child(btn_clipped)

	await process_frame
	await process_frame

	print("LABEL  plain            min.x = %.1f" % plain.get_combined_minimum_size().x)
	print("LABEL  clip_text        min.x = %.1f" % clipped.get_combined_minimum_size().x)
	print("LABEL  clip + ellipsis  min.x = %.1f" % ellipsis.get_combined_minimum_size().x)
	print("LABEL  autowrap         min.x = %.1f" % wrapped.get_combined_minimum_size().x)
	print("BUTTON plain            min.x = %.1f" % btn_plain.get_combined_minimum_size().x)
	print("BUTTON clip_text        min.x = %.1f" % btn_clipped.get_combined_minimum_size().x)
	quit(0)
