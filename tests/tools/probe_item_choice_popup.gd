extends SceneTree

## T11-42 — why did the Old Nemesis chooser render three BLANK buttons?
##
## ── WHY A PROBE AND NOT A READ ──────────────────────────────────────────────
## The finding as recorded blamed "the ItemChoicePopup presentation drops them".
## Source disproves that outright: `btn.text = str(option_name)` is set for every
## option (:94) and the colours are COLOR_TEXT_PRIMARY on COLOR_ACCENT (:123),
## i.e. light-on-blue, not invisible. So the recorded cause is wrong.
##
## What is NOT established by reading is the real mechanism. The popup hard-fixes
## its WIDTH at 380 in _init() (:23) and show_choices() adjusts only the HEIGHT
## (:39-40) while the Window is `unresizable`. That is a fact, but a fixed width
## does not obviously produce a fully BLANK button — a centred string that merely
## overflows would still show its middle. Guessing again is how T11-18's causal
## note came to be wrong, so this measures instead.
##
## Reports, for the three VERBATIM device strings:
##   - each Button's own minimum width (font metrics: what the text needs)
##   - the button container's minimum, and the Window's actual size
##   - each button's laid-out rect, and whether its text fits inside it
##
## ⚠ Font metrics are what this measures, and they load fine headless. The
## DEVICE's content scale is not reproduced here — so treat an overflow figure as
## "the text needs more than the box has at this font size", not as a device px
## count. The discriminating question is binary and survives that: does the
## widest label fit in 380 or not?
##
##   Godot_console.exe --headless --path <project> \
##       --script tests/tools/probe_item_choice_popup.gd

const PopupScript = preload("res://src/ui/components/dialogs/ItemChoicePopup.gd")

## Verbatim from walk21/C28_nemesis_popup.png, in `campaign.rivals` order.
const DEVICE_OPTIONS: Array[String] = [
	"Feral Jackals (Mercenary Band)",
	"Old nemesis (persistent, +1 enemies) (Corporate)",
	"Roll up a new Rival",
]

## CampaignEventEffects composes the body prompt; the walk saw it clipped at
## "An old nemesis has tracked you down (Core R".
const DEVICE_PROMPT := "An old nemesis has tracked you down (Core Rules p.126). Select a prior Rival, or roll up a new one."


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("=== T11-42  ItemChoicePopup geometry ===")

	var popup: Window = PopupScript.new()
	root.add_child(popup)
	popup.show_choices(DEVICE_PROMPT, DEVICE_OPTIONS, "An Old Nemesis")
	await process_frame
	await process_frame

	print("window.size            = %s   (unresizable=%s)"
		% [str(popup.size), str(popup.unresizable)])
	print("window.min_size        = %s" % str(popup.min_size))
	print("window content min     = %s" % str(popup.get_contents_minimum_size()))
	print("")

	var buttons: Array[Button] = []
	_collect(popup, buttons)
	print("found %d Button(s)" % buttons.size())
	print("")

	var worst: float = 0.0
	for b: Button in buttons:
		var need: Vector2 = b.get_minimum_size()
		var got: Rect2 = Rect2(b.global_position, b.size)
		var font: Font = b.get_theme_font("font")
		var fsize: int = b.get_theme_font_size("font_size")
		var text_px: float = 0.0
		if font:
			text_px = font.get_string_size(
				b.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x
		var overflow: float = maxf(0.0, text_px - got.size.x)
		worst = maxf(worst, overflow)
		print("  %-50s" % ("\"" + b.text + "\""))
		print("      font_size=%d  text needs %.1f px  button min %.1f  laid out %.1f wide"
			% [fsize, text_px, need.x, got.size.x])
		print("      rect = %s   clip_text=%s  align=%d"
			% [str(got), str(b.clip_text), b.alignment])
		if overflow > 0.5:
			print("      >> OVERFLOWS its own rect by %.1f px" % overflow)
		if got.position.x + got.size.x > float(popup.size.x) + 0.5:
			print("      >> extends %.1f px PAST the window's right edge"
				% (got.position.x + got.size.x - float(popup.size.x)))
		print("")

	print("======================================================")
	print("  widest label overflow vs its own button: %.1f px" % worst)
	print("  window width is FIXED at %d and never widened for content"
		% popup.size.x)
	print("======================================================")
	popup.queue_free()
	quit(0)


func _collect(node: Node, out: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			out.append(child as Button)
		_collect(child, out)
