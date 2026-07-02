extends GdUnitTestSuite
## ThemeManager tests (rewritten 2026-07-02 against the REAL API).
##
## The old suite called apply_theme() / get_current_theme() / get_font_size()
## / register_control() — a replaced design that does not exist on this
## ThemeManager. The real API is variant-based: set_theme_variant /
## get_theme_variant / set_scale_factor / set_high_contrast /
## set_reduced_animation, persisted to user://theme_config.cfg.
##
## Setters call save_config(), so the suite backs up and restores the REAL
## user config file to avoid polluting the developer's theme preferences.

const THEME_CONFIG_PATH := "user://theme_config.cfg"

var theme_manager: Node
var _config_backup: PackedByteArray = PackedByteArray()
var _config_existed: bool = false


func before() -> void:
	_config_existed = FileAccess.file_exists(THEME_CONFIG_PATH)
	if _config_existed:
		var f := FileAccess.open(THEME_CONFIG_PATH, FileAccess.READ)
		if f:
			_config_backup = f.get_buffer(f.get_length())


func after() -> void:
	if _config_existed:
		var f := FileAccess.open(THEME_CONFIG_PATH, FileAccess.WRITE)
		if f:
			f.store_buffer(_config_backup)
	else:
		DirAccess.remove_absolute(THEME_CONFIG_PATH)


func before_test() -> void:
	var theme_manager_class = load("res://src/ui/themes/ThemeManager.gd")
	theme_manager = auto_free(theme_manager_class.new())
	add_child(theme_manager)


func after_test() -> void:
	if theme_manager and is_instance_valid(theme_manager):
		remove_child(theme_manager)
	theme_manager = null


func test_theme_variant_roundtrip() -> void:
	theme_manager.set_theme_variant(theme_manager.ThemeVariant.HIGH_CONTRAST)
	assert_int(theme_manager.get_theme_variant()) \
		.is_equal(theme_manager.ThemeVariant.HIGH_CONTRAST)
	theme_manager.set_theme_variant(theme_manager.ThemeVariant.DARK)
	assert_int(theme_manager.get_theme_variant()) \
		.is_equal(theme_manager.ThemeVariant.DARK)


func test_colorblind_variants_settable() -> void:
	for variant in [
			theme_manager.ThemeVariant.COLORBLIND_DEUTERANOPIA,
			theme_manager.ThemeVariant.COLORBLIND_PROTANOPIA,
			theme_manager.ThemeVariant.COLORBLIND_TRITANOPIA]:
		theme_manager.set_theme_variant(variant)
		assert_int(theme_manager.get_theme_variant()).is_equal(variant)


func test_scale_factor_roundtrip_and_clamp() -> void:
	theme_manager.set_scale_factor(1.5)
	assert_float(theme_manager.get_scale_factor()).is_equal_approx(1.5, 0.001)
	# Clamped to [MIN_SCALE_FACTOR 0.75, MAX_SCALE_FACTOR 2.0]
	theme_manager.set_scale_factor(99.0)
	assert_float(theme_manager.get_scale_factor()).is_less_equal(2.0)
	theme_manager.set_scale_factor(0.1)
	assert_float(theme_manager.get_scale_factor()).is_greater_equal(0.75)


func test_high_contrast_toggle() -> void:
	theme_manager.set_high_contrast(true)
	assert_bool(theme_manager.is_high_contrast_enabled()).is_true()
	theme_manager.set_high_contrast(false)
	assert_bool(theme_manager.is_high_contrast_enabled()).is_false()


func test_reduced_animation_toggle() -> void:
	# Gates ambient scene motion (SceneStage) — must round-trip reliably
	theme_manager.set_reduced_animation(true)
	assert_bool(theme_manager.is_reduced_animation_enabled()).is_true()
	theme_manager.set_reduced_animation(false)
	assert_bool(theme_manager.is_reduced_animation_enabled()).is_false()


func test_settings_persist_across_instances() -> void:
	theme_manager.set_theme_variant(theme_manager.ThemeVariant.LIGHT)

	var theme_manager_class = load("res://src/ui/themes/ThemeManager.gd")
	var second = auto_free(theme_manager_class.new())
	add_child(second)
	assert_int(second.get_theme_variant()) \
		.is_equal(theme_manager.ThemeVariant.LIGHT)
	remove_child(second)
