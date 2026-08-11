extends GdUnitTestSuite
## T9-08 (Aug 9 2026): shipped art must import at DISPLAY resolution, not print master.
##
## Measured on the tablet (TB361FU, Mali-G57): TOTAL PSS 699 MB with 409 MB of it
## graphics. The cause was not compression — it was that the imports had no size cap, so
## print-resolution masters were uploaded to the GPU whole. Four narrative layers alone
## were 6000x3375 each, i.e. 77 MB of RGBA8 apiece, 309 MB for the set.
##
## Capping via `process/size_limit` in the .import is non-destructive: the source art is
## untouched, so raising a cap later is a one-line revert plus a reimport.
##
## This asserts the IMPORTED texture, not the .import text, so it stays honest if the
## import settings are edited without a reimport.
##
## Desktop QA structurally cannot catch a regression here — an RTX 3070 never complains.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

## path -> largest allowed dimension. One representative per capped family; the caps
## themselves are documented at the top of each family's .import.
const CAPPED := {
	# Full-screen SceneStage art. Landscape logical viewport is 1728x1080 and SceneStage
	# adds a 1.04 overscan plus a slow Ken Burns zoom, so 2048 is already generous.
	"res://assets/scenes/story_event_01/bg/bg_00.png": 2048,
	"res://assets/scenes/story_event_01/actors/hero.png": 2048,
	# CharacterCard avatars render at <=256px square; the Planetfall import preview is
	# the largest use and is nowhere near 1024.
	"res://assets/portraits/planetfall/preset_pilot.png": 1024,
	"res://assets/portraits/species/precursor_01.png": 1024,
	# Full-figure narrative actors, feet-anchored and height-scaled to at most the 1080
	# viewport height.
	"res://assets/figures/species/k_erin_02.png": 1280,
	# Main-menu mode cards, ~900px wide on a 2560 screen.
	"res://assets/covers/cover_bug_hunt.png": 1600,
}


func test_no_shipped_texture_imports_above_its_display_size() -> void:
	var offenders: Array[String] = []
	for path: String in CAPPED:
		if not ResourceLoader.exists(path):
			continue   # art is optional in some checkouts; absence is not a failure here
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var cap: int = int(CAPPED[path])
		var biggest: int = maxi(tex.get_width(), tex.get_height())
		if biggest > cap:
			offenders.append("%s imported at %dx%d (cap %d) = %.1f MB of RGBA8 VRAM" % [
				path, tex.get_width(), tex.get_height(), cap,
				tex.get_width() * tex.get_height() * 4.0 / 1048576.0])
	assert_array(offenders).override_failure_message(
		"texture(s) import above display resolution — this is GPU memory on a phone:\n  " +
		"\n  ".join(offenders)).is_empty()


func test_the_narrative_layers_are_the_ones_that_actually_regressed() -> void:
	# Named separately because these four were 309 MB between them — by far the largest
	# single win, and the easiest to lose again by re-exporting the art without a cap.
	var path := "res://assets/scenes/story_event_01/bg/bg_00.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	assert_that(tex).is_not_null()
	var mb: float = tex.get_width() * tex.get_height() * 4.0 / 1048576.0
	assert_float(mb).override_failure_message(
		"%s is %.1f MB of RGBA8 (was 77.2 MB uncapped at 6000x3375)" % [path, mb]
	).is_less(16.0)
