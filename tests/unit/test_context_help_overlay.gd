extends GdUnitTestSuite
## Context help: the "?" chrome button (SettingsOverlay) opens the user guide at the
## section for the screen underneath.
##
## THE DEFECT. data/help_context_map.json named a chapter and section for every
## SceneRouter key, and nothing read it: HelpContentLoader.get_context_help() had no
## caller, the guide's only entry was the Store's Help button (chapter 1), and
## HelpScreen._navigate_to_chapter() accepted a section_id and never used it. Three
## gaps, each enough on its own to keep context help from working, so each is pinned
## here separately.
##
## The overlay opens Help IN PLACE, the way it opens Settings, because
## navigate_to("help") frees the screen underneath (a half-filled wizard, a battle).

const Loader := preload("res://src/ui/help/HelpContentLoader.gd")
const ROUTER := preload("res://src/ui/screens/SceneRouter.gd")
const OVERLAY := preload("res://src/autoload/SettingsOverlay.gd")
const HELP_SCENE := "res://src/ui/help/HelpScreen.tscn"


func after_test() -> void:
	var overlay := get_node_or_null("/root/SettingsOverlay")
	if overlay and overlay.has_method("_help_open") and overlay._help_open():
		overlay._hide_help_overlay()
	get_tree().paused = false


func _help_screen(context: Dictionary) -> Control:
	var screen: Control = (load(HELP_SCENE) as PackedScene).instantiate()
	screen.set("overlay_mode", true)
	screen.set("open_at_context", context)
	screen.size = Vector2(1080, 700)
	add_child(screen)
	auto_free(screen)
	return screen


func test_every_router_screen_maps_to_a_loaded_chapter_through_the_overlay() -> void:
	# The overlay's own lookup, not the loader's: the button reads SceneRouter's
	# current_scene and hands it to help_context_for().
	var loader: RefCounted = Loader.new()
	loader.ensure_loaded()
	var chapters: Array = loader.get_chapter_order()
	var unresolved: Array[String] = []
	for key: Variant in (ROUTER.SCENE_PATHS as Dictionary).keys():
		var ctx: Dictionary = OVERLAY.help_context_for(str(key))
		if not chapters.has(str(ctx.get("chapter_id", ""))):
			unresolved.append("%s -> %s" % [key, ctx])
	assert_array(unresolved).override_failure_message(
		"Router screens whose \"?\" lands on no chapter: %s" % [unresolved]).is_empty()


func test_a_fresh_loader_resolves_a_short_chapter_id() -> void:
	# No ensure_loaded() here on purpose: that is the order a first caller uses.
	var loader: RefCounted = Loader.new()
	var ctx: Dictionary = loader.get_context_help("galaxy_log")
	assert_str(str(ctx.get("chapter_id", ""))).override_failure_message(
		"get_context_help() returned %s; a bare \"03\" means the chapter list was empty"
		% [ctx]).starts_with("03_")


func test_the_guide_opens_scrolled_to_the_mapped_section() -> void:
	var ctx: Dictionary = OVERLAY.help_context_for("galaxy_log")
	assert_str(str(ctx.get("section_id", ""))).is_equal("galaxy_log")
	var screen := _help_screen(ctx)
	for _i in 4:
		await get_tree().process_frame
	assert_str(str(screen.get("_current_chapter_id"))).is_equal(ctx["chapter_id"])
	var scroll: ScrollContainer = screen.get("_content_scroll")
	assert_int(scroll.scroll_vertical).override_failure_message(
		"Galaxy Log is near the end of chapter 3, yet the guide opened at the top"
		).is_greater(0)


func test_the_guide_opened_in_place_shows_its_text_at_full_opacity() -> void:
	# The overlay pauses the tree, and TweenFX tweens bind no node, so a fade-in
	# started from alpha 0 never advances there. Checked before any frame runs.
	var screen := _help_screen({})
	var label: RichTextLabel = screen.get("_content_label")
	assert_float(label.modulate.a).is_equal(1.0)


func test_back_in_overlay_mode_closes_instead_of_navigating() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	var before: String = str(router.current_scene) if router else ""
	var screen := _help_screen({})
	var fired: Array[bool] = [false]
	screen.connect("back_requested", func() -> void: fired[0] = true)
	screen.call("_on_back_pressed")
	assert_bool(fired[0]).is_true()
	if router:
		assert_str(str(router.current_scene)).is_equal(before)


func test_the_overlay_opens_help_in_place_and_closing_unpauses() -> void:
	var overlay := get_node_or_null("/root/SettingsOverlay")
	assert_object(overlay).override_failure_message(
		"SettingsOverlay autoload missing; the button cannot be verified").is_not_null()
	# No frame may pass while paused, or the runner stalls: assert synchronously.
	overlay.open_help(OVERLAY.help_context_for("galaxy_log"))
	var opened: bool = overlay._help_open()
	var paused: bool = get_tree().paused
	var chrome_hidden: bool = not overlay._help_button.visible \
		and not overlay._gear_button.visible
	overlay._hide_help_overlay()
	assert_bool(opened).is_true()
	assert_bool(paused).is_true()
	assert_bool(chrome_hidden).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(overlay._help_open()).is_false()


func test_the_help_button_is_part_of_the_reserved_chrome() -> void:
	# Screens clear the band from get_reserved_rect(); a button it leaves out is
	# one a screen can draw under.
	var overlay := get_node_or_null("/root/SettingsOverlay")
	assert_object(overlay).is_not_null()
	var src: String = FileAccess.get_file_as_string("res://src/autoload/SettingsOverlay.gd")
	assert_str(src).contains("for b in [_gear_button, _bug_button, _help_button]:")
	assert_object(overlay._help_button).is_not_null()
	assert_str(overlay._help_button.tooltip_text).is_equal("Help for this screen")
