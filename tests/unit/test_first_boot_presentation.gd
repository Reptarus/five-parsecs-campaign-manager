extends GdUnitTestSuite
## First-boot presentation contract (T1-01/02/03, tablet QA sprint Aug 8 2026)
##
## These three are the first things anyone sees, and all three were recorded on the
## very first device screenshot. Two of them render identically on desktop and had
## been looked straight at by every prior QA pass without being written down.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const OverlayScript := preload("res://src/ui/components/tutorial/TutorialOverlay.gd")
const EULAScript := preload("res://src/ui/screens/legal/EULAScreen.gd")

const COVER := "res://assets/covers/cover_standard.png"


# ------------------------------------------------------------------- T1-01

func test_the_standard_cover_has_an_alpha_channel() -> void:
	# It is a WORDMARK, unlike the other three covers which are full-bleed
	# paintings where an opaque background is correct. Baked white letterboxed into
	# a large white rectangle behind the title on the main menu.
	var img: Image = load(COVER).get_image()
	assert_that(img).is_not_null()
	assert_bool(img.detect_alpha() != Image.ALPHA_NONE).override_failure_message(
		"cover_standard.png lost its alpha channel; the white plate is back").is_true()


func test_the_cover_corners_are_transparent() -> void:
	# The plate specifically, not just "some alpha somewhere".
	var img: Image = load(COVER).get_image()
	var w := img.get_width()
	var h := img.get_height()
	for p: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		assert_float(img.get_pixelv(p).a).override_failure_message(
			"cover corner %s is opaque" % p).is_equal(0.0)


func test_the_wordmark_itself_survived_the_key_out() -> void:
	# The other half of the contract: removing the background must not eat the art.
	#
	# Asserted on INKED AREA, not on "fully opaque". The alpha came from distance
	# from white, and the wordmark is a mid-tone red — its dominant alpha is 191
	# (~0.75), and NOTHING in the image exceeds 242. A `> 0.95` test would therefore
	# fail forever no matter how healthy the asset was, which is exactly what the
	# first version of this test did.
	#
	# The original RGB was 68.2% pure white, so ~31.8% is ink. Anything close to
	# that after conversion means the artwork is intact and only the plate went.
	var img: Image = load(COVER).get_image()
	var inked := 0
	var total := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			total += 1
			if img.get_pixel(x, y).a > 0.02:
				inked += 1
	assert_float(float(inked) / float(total)).override_failure_message(
		"the wordmark is mostly gone — the key-out was too aggressive").is_greater(0.25)


# ------------------------------------------------------------------- T1-02

func test_a_coach_mark_never_covers_the_control_it_points_at() -> void:
	# DETECTION-CRITICAL. The pre-fix code placed on the hinted side then clamped
	# into the viewport, and the clamp is what put the bubble on top of the "New
	# Campaign" button it was highlighting.
	var viewport := Vector2(1729, 1080)
	var tooltip := Vector2(420, 200)
	# A target low on screen: "bottom" cannot fit, so the old clamp dragged the
	# bubble back up over it.
	var target := Rect2(Vector2(1200, 980), Vector2(320, 80))

	var pos := OverlayScript.place_tooltip(target, tooltip, viewport, "bottom")

	var inter := Rect2(pos, tooltip).intersection(target)
	assert_float(inter.size.x * inter.size.y).override_failure_message(
		"bubble at %s overlaps its target %s" % [pos, target]).is_equal(0.0)


func test_a_coach_mark_stays_on_screen() -> void:
	var viewport := Vector2(1729, 1080)
	var tooltip := Vector2(420, 200)
	for target: Rect2 in [
		Rect2(Vector2(1200, 980), Vector2(320, 80)),   # bottom-right
		Rect2(Vector2(10, 10), Vector2(320, 80)),      # top-left
		Rect2(Vector2(1400, 20), Vector2(300, 60)),    # top-right
		Rect2(Vector2(20, 1000), Vector2(300, 60)),    # bottom-left
	]:
		var pos := OverlayScript.place_tooltip(target, tooltip, viewport, "bottom")
		assert_bool(pos.x >= 0.0 and pos.y >= 0.0).override_failure_message(
			"bubble off the top/left for target %s -> %s" % [target, pos]).is_true()
		assert_bool(pos.x + tooltip.x <= viewport.x and pos.y + tooltip.y <= viewport.y) \
			.override_failure_message(
				"bubble off the bottom/right for target %s -> %s" % [target, pos]).is_true()


func test_the_hint_is_honoured_when_it_actually_fits() -> void:
	# The flip must be a fallback, not the new default — authored hints still win
	# wherever there is room, or every bubble ends up somewhere unexpected.
	var viewport := Vector2(1729, 1080)
	var tooltip := Vector2(400, 160)
	var target := Rect2(Vector2(700, 400), Vector2(300, 80))

	var pos := OverlayScript.place_tooltip(target, tooltip, viewport, "bottom")

	assert_float(pos.y).is_greater(target.end.y - 0.01)


func test_a_side_hint_places_beside_the_target() -> void:
	# The main menu's buttons sit hard right with ~1000px of empty canvas to the
	# left, which is where a bubble belongs there.
	var viewport := Vector2(1729, 1080)
	var tooltip := Vector2(400, 160)
	var target := Rect2(Vector2(1300, 500), Vector2(300, 80))

	var pos := OverlayScript.place_tooltip(target, tooltip, viewport, "left")

	assert_float(pos.x + tooltip.x).is_less(target.position.x + 0.01)


# ------------------------------------------------------------------- T1-03

func test_the_eula_text_region_scales_with_the_screen() -> void:
	# 250 and 360 were small-screen FLOORS written as CEILINGS, so a tablet got the
	# same cramped box as a phone: ~5 lines clipped mid-sentence in a 464x386 dp
	# card on a 1280x800 dp screen. Legal text nobody can read is a compliance
	# problem, not a cosmetic one.
	var screen: Node = auto_free(EULAScript.new())
	add_child(screen)
	await await_idle_frame()

	var vp_h: float = screen.get_viewport().get_visible_rect().size.y
	var h: float = screen._scroll_min_height()

	assert_float(h).override_failure_message(
		"scroll height %f is still capped small against a %f-tall viewport" % [h, vp_h]
	).is_greater(minf(250.0, vp_h * 0.30))


func test_the_eula_card_is_not_capped_at_a_phone_width() -> void:
	var screen: Node = auto_free(EULAScript.new())
	add_child(screen)
	await await_idle_frame()

	var vp_w: float = screen.get_viewport().get_visible_rect().size.x
	var w: float = screen._card_min_width()

	# Wider than the old hard 360 cap whenever the screen allows it...
	if vp_w > 800.0:
		assert_float(w).is_greater(360.0)
	# ...but never so wide that legal prose becomes an unreadable single line.
	assert_float(w).is_less_equal(720.0)
