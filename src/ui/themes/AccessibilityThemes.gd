extends RefCounted
class_name AccessibilityThemes

## Accessibility Theme System for Five Parsecs Campaign Manager
## Provides high contrast and colorblind-friendly themes
## Complies with WCAG 2.1 Level AA standards for visual accessibility

# ============ HIGH CONTRAST THEME ============
# For users with low vision - maximum contrast, pure black/white

const HIGH_CONTRAST_THEME := {
	# Backgrounds - pure black/white for maximum contrast
	"base": Color("#000000"),
	"elevated": Color("#1A1A1A"),
	"input": Color("#0D0D0D"),
	"border": Color("#FFFFFF"),

	# Text - maximum contrast
	"text_primary": Color("#FFFFFF"),
	"text_secondary": Color("#CCCCCC"),
	"text_disabled": Color("#666666"),

	# Accent - bright, saturated colors
	"accent": Color("#00BFFF"),           # Bright cyan
	"accent_hover": Color("#00E5FF"),     # Brighter cyan
	"focus": Color("#FFFF00"),            # Yellow focus ring

	# Status - pure colors, no ambiguity
	"success": Color("#00FF00"),          # Pure green
	"warning": Color("#FFFF00"),          # Pure yellow
	"danger": Color("#FF0000"),           # Pure red

	# Additional UI elements
	"selection": Color("#0066FF"),        # Bright blue selection
	"link": Color("#00FFFF"),             # Cyan hyperlinks

	# Health states (using pure colors)
	"health_full": Color("#00FF00"),      # Green
	"health_mid": Color("#FFFF00"),       # Yellow
	"health_low": Color("#FF0000"),       # Red

	# Equipment types
	"weapon": Color("#00FFFF"),           # Cyan
	"armor": Color("#FF00FF"),            # Magenta
	"gear": Color("#FFFF00")              # Yellow
}

# ============ DEUTERANOPIA THEME ============
# Red-Green Colorblind (Most Common - 6% of males)
# Replace red/green distinctions with blue/orange/yellow

const DEUTERANOPIA_THEME := {
	# Backgrounds - same as dark theme
	"base": Color("#1A1A2E"),
	"elevated": Color("#252542"),
	"input": Color("#1E1E36"),
	"border": Color("#3A3A5C"),

	# Text - unchanged (safe for deuteranopia)
	"text_primary": Color("#E0E0E0"),
	"text_secondary": Color("#808080"),
	"text_disabled": Color("#404040"),

	# Accent - blue is safe
	"accent": Color("#2D5A7B"),
	"accent_hover": Color("#3A7199"),
	"focus": Color("#4FC3F7"),            # Cyan focus

	# Status - blue/orange/yellow instead of green/yellow/red
	"success": Color("#0077BB"),          # Blue for success (instead of green)
	"warning": Color("#EE7733"),          # Orange for warning
	"danger": Color("#CC3311"),           # Dark orange-red for danger

	# Additional UI
	"selection": Color("#0077BB"),
	"link": Color("#33BBEE"),             # Cyan link

	# Health states - distinguishable without red/green
	"health_full": Color("#0077BB"),      # Blue (instead of green)
	"health_mid": Color("#DDAA33"),       # Yellow
	"health_low": Color("#CC3311"),       # Orange-red

	# Equipment types - colorblind-safe palette
	"weapon": Color("#0077BB"),           # Blue
	"armor": Color("#EE7733"),            # Orange
	"gear": Color("#009988"),             # Teal

	# Threat levels (for enemies)
	"threat_low": Color("#33BBEE"),       # Cyan
	"threat_medium": Color("#EE9922"),    # Orange
	"threat_high": Color("#994499")       # Purple
}

# ============ PROTANOPIA THEME ============
# Red Colorblind (1% of males)
# Avoid red hues, use blue/yellow/purple

const PROTANOPIA_THEME := {
	# Backgrounds
	"base": Color("#1A1A2E"),
	"elevated": Color("#252542"),
	"input": Color("#1E1E36"),
	"border": Color("#3A3A5C"),

	# Text
	"text_primary": Color("#E0E0E0"),
	"text_secondary": Color("#808080"),
	"text_disabled": Color("#404040"),

	# Accent
	"accent": Color("#2D5A7B"),
	"accent_hover": Color("#3A7199"),
	"focus": Color("#4FC3F7"),

	# Status - blue/yellow/purple (no red)
	"success": Color("#33BBEE"),          # Cyan for success
	"warning": Color("#EE9922"),          # Orange for warning
	"danger": Color("#994499"),           # Purple for danger (visible to protanopes)

	# Additional UI
	"selection": Color("#33BBEE"),
	"link": Color("#66CCEE"),

	# Health states
	"health_full": Color("#33BBEE"),      # Cyan
	"health_mid": Color("#EE9922"),       # Orange
	"health_low": Color("#994499"),       # Purple

	# Equipment types
	"weapon": Color("#0077BB"),           # Blue
	"armor": Color("#DDAA33"),            # Yellow-gold
	"gear": Color("#009988"),             # Teal

	# Threat levels
	"threat_low": Color("#33BBEE"),       # Cyan
	"threat_medium": Color("#EE9922"),    # Orange
	"threat_high": Color("#994499")       # Purple
}

# ============ TRITANOPIA THEME ============
# Blue-Yellow Colorblind (Rare - 0.01%)
# Avoid blue/yellow distinctions, use red/pink/cyan

const TRITANOPIA_THEME := {
	# Backgrounds
	"base": Color("#1A1A2E"),
	"elevated": Color("#252542"),
	"input": Color("#1E1E36"),
	"border": Color("#3A3A5C"),

	# Text
	"text_primary": Color("#E0E0E0"),
	"text_secondary": Color("#808080"),
	"text_disabled": Color("#404040"),

	# Accent - use red/pink instead of blue
	"accent": Color("#CC3333"),           # Red accent
	"accent_hover": Color("#DD4444"),
	"focus": Color("#FF6699"),            # Pink focus

	# Status - red/pink/cyan (avoid blue/yellow)
	"success": Color("#00CC99"),          # Cyan-green for success
	"warning": Color("#FF6699"),          # Pink for warning
	"danger": Color("#CC3333"),           # Red for danger

	# Additional UI
	"selection": Color("#CC3333"),
	"link": Color("#00CC99"),

	# Health states
	"health_full": Color("#00CC99"),      # Cyan-green
	"health_mid": Color("#FF6699"),       # Pink
	"health_low": Color("#CC3333"),       # Red

	# Equipment types
	"weapon": Color("#CC3333"),           # Red
	"armor": Color("#00CC99"),            # Cyan-green
	"gear": Color("#FF6699"),             # Pink

	# Threat levels
	"threat_low": Color("#00CC99"),       # Cyan-green
	"threat_medium": Color("#FF6699"),    # Pink
	"threat_high": Color("#CC3333")       # Red
}

# ============ PUBLIC API ============

static func get_theme(theme_name: String) -> Dictionary:
	## Get theme by name. Returns default dark theme if not found.
	match theme_name.to_lower():
		"high_contrast":
			return HIGH_CONTRAST_THEME
		"deuteranopia":
			return DEUTERANOPIA_THEME
		"protanopia":
			return PROTANOPIA_THEME
		"tritanopia":
			return TRITANOPIA_THEME
		_:
			push_warning("AccessibilityThemes: Unknown theme '%s', returning default" % theme_name)
			return _get_default_dark_theme()

static func get_high_contrast() -> Dictionary:
	## Get high contrast theme for users with low vision.
	return HIGH_CONTRAST_THEME

static func get_deuteranopia() -> Dictionary:
	## Get deuteranopia theme (red-green colorblind).
	return DEUTERANOPIA_THEME

static func get_protanopia() -> Dictionary:
	## Get protanopia theme (red colorblind).
	return PROTANOPIA_THEME

static func get_tritanopia() -> Dictionary:
	## Get tritanopia theme (blue-yellow colorblind).
	return TRITANOPIA_THEME

static func get_available_themes() -> Array[String]:
	## Get list of all available accessibility themes.
	return [
		"high_contrast",
		"deuteranopia",
		"protanopia",
		"tritanopia"
	]

static func get_theme_display_name(theme_name: String) -> String:
	## Get human-readable display name for theme.
	match theme_name.to_lower():
		"high_contrast":
			return "High Contrast"
		"deuteranopia":
			return "Colorblind (Red-Green)"
		"protanopia":
			return "Colorblind (Red)"
		"tritanopia":
			return "Colorblind (Blue-Yellow)"
		_:
			return "Unknown"

static func get_theme_description(theme_name: String) -> String:
	## Get detailed description of theme for accessibility settings.
	match theme_name.to_lower():
		"high_contrast":
			return "Maximum contrast with pure black/white backgrounds. Best for users with low vision."
		"deuteranopia":
			return "Replaces red/green with blue/orange. For red-green colorblindness (most common)."
		"protanopia":
			return "Avoids red hues entirely. For protanopia (red colorblindness)."
		"tritanopia":
			return "Avoids blue/yellow distinctions. For tritanopia (rare blue-yellow colorblindness)."
		_:
			return "No description available."

# ============ COLOR TRANSFORMATION FUNCTIONS ============

static func apply_colorblind_filter(base_color: Color, mode: String) -> Color:
	## Transform any color to be colorblind-safe.
	## Useful for dynamically adjusting colors at runtime.
	##
	## Modes: "deuteranopia", "protanopia", "tritanopia"
	match mode.to_lower():
		"deuteranopia":
			return _simulate_deuteranopia(base_color)
		"protanopia":
			return _simulate_protanopia(base_color)
		"tritanopia":
			return _simulate_tritanopia(base_color)
		_:
			return base_color

static func _simulate_deuteranopia(color: Color) -> Color:
	## Simulate deuteranopia (red-green colorblindness).
	## Shifts red/green colors toward blue/yellow spectrum.
	# Simplified simulation - shift green toward yellow, red toward orange
	var r = color.r
	var g = color.g
	var b = color.b

	# If color is greenish, shift toward yellow
	if g > r and g > b:
		return Color(g * 0.7, g, b * 0.5)  # Yellow-ish

	# If color is reddish, shift toward orange
	if r > g and r > b:
		return Color(r, r * 0.6, b * 0.3)  # Orange-ish

	# Otherwise, shift toward blue spectrum
	return Color(r * 0.8, g * 0.8, b * 1.2)

static func _simulate_protanopia(color: Color) -> Color:
	## Simulate protanopia (red colorblindness).
	## Shifts red colors toward blue/cyan spectrum.
	var r = color.r
	var g = color.g
	var b = color.b

	# If color is reddish, shift toward purple/blue
	if r > g and r > b:
		return Color(r * 0.5, g * 0.8, b * 1.3)  # Purple-ish

	# Enhance blue/cyan visibility
	return Color(r * 0.7, g * 1.0, b * 1.2)

static func _simulate_tritanopia(color: Color) -> Color:
	## Simulate tritanopia (blue-yellow colorblindness).
	## Shifts blue/yellow toward red/cyan spectrum.
	var r = color.r
	var g = color.g
	var b = color.b

	# If color is blue, shift toward cyan
	if b > r and b > g:
		return Color(r * 0.5, g * 1.2, b * 0.9)  # Cyan-ish

	# If color is yellow, shift toward pink/red
	if r > 0.5 and g > 0.5 and b < 0.3:
		return Color(r * 1.2, g * 0.7, b * 0.5)  # Pink-ish

	return color

# ============ HELPER FUNCTIONS ============

static func _get_default_dark_theme() -> Dictionary:
	## Fallback default dark theme (matches BaseCampaignPanel).
	return {
		"base": Color("#1A1A2E"),
		"elevated": Color("#252542"),
		"input": Color("#1E1E36"),
		"border": Color("#3A3A5C"),
		"text_primary": Color("#E0E0E0"),
		"text_secondary": Color("#808080"),
		"text_disabled": Color("#404040"),
		"accent": Color("#2D5A7B"),
		"accent_hover": Color("#3A7199"),
		"focus": Color("#4FC3F7"),
		"success": Color("#10B981"),
		"warning": Color("#D97706"),
		"danger": Color("#DC2626"),
		"selection": Color("#2D5A7B"),
		"link": Color("#4FC3F7"),
		"health_full": Color("#10B981"),
		"health_mid": Color("#D97706"),
		"health_low": Color("#DC2626"),
		"weapon": Color("#3B82F6"),
		"armor": Color("#8B5CF6"),
		"gear": Color("#10B981")
	}

static func is_high_contrast_theme(theme_name: String) -> bool:
	## Check if theme is high contrast mode.
	return theme_name.to_lower() == "high_contrast"

static func is_colorblind_theme(theme_name: String) -> bool:
	## Check if theme is a colorblind-friendly theme.
	return theme_name.to_lower() in ["deuteranopia", "protanopia", "tritanopia"]

static func get_color_from_theme(theme: Dictionary, color_key: String, fallback: Color = Color.WHITE) -> Color:
	## Safely get color from theme dictionary with fallback.
	if theme.has(color_key):
		return theme[color_key]
	push_warning("AccessibilityThemes: Color key '%s' not found in theme, using fallback" % color_key)
	return fallback
