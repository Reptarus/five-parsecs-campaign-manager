extends RefCounted
class_name UIColors

## Canonical Design Token Source — Five Parsecs Campaign Manager
## All UI components reference this file for colors, spacing, typography,
## touch targets, and icon sizes. Deep Space Theme.

# ── Spacing System (8px grid) ────────────────────────────────────────────────
const SPACING_XS := 4   # Icon padding, label-to-input gap
const SPACING_SM := 8   # Element gaps within cards
const SPACING_MD := 16  # Inner card padding
const SPACING_LG := 24  # Section gaps between cards
const SPACING_XL := 32  # Panel edge padding

# ── Touch Target Minimums ────────────────────────────────────────────────────
const TOUCH_TARGET_MIN := 48      # Minimum interactive element height
const TOUCH_TARGET_COMFORT := 56  # Comfortable input height

# ── Typography Sizes ─────────────────────────────────────────────────────────
const FONT_SIZE_XS := 11  # Captions, limits
const FONT_SIZE_SM := 14  # Descriptions, helpers
const FONT_SIZE_MD := 16  # Body text, inputs
const FONT_SIZE_LG := 18  # Section headers
const FONT_SIZE_XL := 24  # Panel titles

# ── Responsive Breakpoints (Mobile-First) ────────────────────────────────────
const BREAKPOINT_MOBILE := 480    # Mobile portrait: <480px
const BREAKPOINT_TABLET := 768    # Tablet: 480-768px
const BREAKPOINT_DESKTOP := 1024  # Desktop: >1024px

# ── Icon Sizes ───────────────────────────────────────────────────────────────
const ICON_SIZE_XS := 16    # Inline text icons
const ICON_SIZE_SM := 24    # Button icons, stat badges
const ICON_SIZE_MD := 32    # Card icons, phase indicators
const ICON_SIZE_LG := 48    # Character portraits (compact)
const ICON_SIZE_XL := 64    # Character portraits (expanded)
const ICON_SIZE_XXL := 128  # Character detail view portrait

# ── Color Palette — Deep Space Theme ─────────────────────────────────────────
# Background hierarchy
const COLOR_PRIMARY := Color("#0a0d14")      # Darkest background (main bg)
const COLOR_SECONDARY := Color("#111827")    # Card backgrounds
const COLOR_TERTIARY := Color("#1f2937")     # Elevated elements, stat boxes
const COLOR_BORDER := Color("#374151")       # Border color

# Accent Colors
const COLOR_BLUE := Color("#3b82f6")         # Primary blue accent
const COLOR_PURPLE := Color("#8b5cf6")       # Purple (XP, story)
const COLOR_EMERALD := Color("#10b981")      # Success/completed
const COLOR_AMBER := Color("#f59e0b")        # Warning/credits
const COLOR_RED := Color("#ef4444")          # Danger/injured
const COLOR_CYAN := Color("#06b6d4")         # Save, world actions

# Text Colors
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")   # Bright white text
const COLOR_TEXT_SECONDARY := Color("#9ca3af") # Gray secondary text
const COLOR_TEXT_MUTED := Color("#6b7280")     # Muted labels/hints

# ── BBCode hex strings ───────────────────────────────────────────────────────
# RichTextLabel "[color=#...]" needs a String, not a Color, and a const
# expression cannot call .to_html() — so BBCode consumers had no token to
# reference and hardcoded a literal instead (that is how #808080 spread to 25
# sites). These MUST track the Color consts above; pinned by
# tests/unit/test_ui_color_tokens.gd, which fails if the two ever disagree.
const HEX_TEXT_PRIMARY := "#f3f4f6"
const HEX_TEXT_SECONDARY := "#9ca3af"
const HEX_TEXT_MUTED := "#6b7280"

# ── Legacy Aliases (backward compatibility) ──────────────────────────────────
const COLOR_BASE := COLOR_PRIMARY
const COLOR_ELEVATED := COLOR_SECONDARY
const COLOR_INPUT := COLOR_TERTIARY
const COLOR_ACCENT := COLOR_BLUE
const COLOR_ACCENT_HOVER := Color("#60a5fa")   # Lighter blue hover
const COLOR_FOCUS := Color("#60a5fa")          # Focus ring blue
const COLOR_SUCCESS := COLOR_EMERALD
const COLOR_WARNING := COLOR_AMBER
const COLOR_DANGER := COLOR_RED
const COLOR_TEXT_DISABLED := COLOR_TEXT_MUTED

# Old UIColors API aliases (BaseInformationCard compatibility)
const SUCCESS_COLOR := COLOR_EMERALD
const INFO_COLOR := COLOR_BLUE
const WARNING_COLOR := COLOR_AMBER
const DANGER_COLOR := COLOR_RED
const NEUTRAL_COLOR := Color("#9ca3af")
const PRIMARY_COLOR := COLOR_BLUE
const SECONDARY_COLOR := COLOR_BORDER
const ACCENT_COLOR := COLOR_AMBER
const TEXT_PRIMARY := COLOR_TEXT_PRIMARY
const TEXT_SECONDARY := COLOR_TEXT_SECONDARY
const TEXT_DISABLED := COLOR_TEXT_DISABLED

## Colour ROLES for RichTextLabel text, written `[color=ui-success]...[/color]` and
## resolved to the palette by bbcode(). Panels hand-wrote hex tags (64 in the
## Planetfall panels alone, in three shades of amber and two of red), so their hues
## never followed the palette, and a receipt saved with a hex kept that hex forever.
const BBCODE_ROLES := {
	"ui-success": COLOR_SUCCESS,
	"ui-warning": COLOR_WARNING,
	"ui-danger": COLOR_DANGER,
	"ui-info": INFO_COLOR,
	"ui-secondary": COLOR_TEXT_SECONDARY,
}


## `text` with every `[color=<role>]` replaced by the role's palette hex. Call it where
## the text reaches the label, so a stored receipt resolves against today's palette.
static func bbcode(text: String) -> String:
	if not text.contains("[color=ui-"):
		return text
	for role in BBCODE_ROLES:
		text = text.replace("[color=%s]" % role,
				"[color=#%s]" % (BBCODE_ROLES[role] as Color).to_html(false))
	return text
