# Deep Space Theme Reference

## Source
All constants from `src/ui/screens/campaign/panels/BaseCampaignPanel.gd` (class_name `FiveParsecsCampaignPanel`), delegated to UIColors.

## Spacing (8px Grid)
```gdscript
SPACING_XS := 4   # Icon padding, label-to-input gap
SPACING_SM := 8   # Element gaps within cards
SPACING_MD := 16  # Inner card padding
SPACING_LG := 24  # Section gaps between cards
SPACING_XL := 32  # Panel edge padding
```

## Touch Targets
```gdscript
TOUCH_TARGET_MIN := 48      # Minimum interactive element height
TOUCH_TARGET_COMFORT := 56  # Comfortable input height
```

## Typography
```gdscript
FONT_SIZE_XS := 11  # Captions, limits
FONT_SIZE_SM := 14  # Descriptions, helpers
FONT_SIZE_MD := 16  # Body text, inputs
FONT_SIZE_LG := 18  # Section headers
FONT_SIZE_XL := 24  # Panel titles
```

## Color Palette

### Primary Colors (New System)
```gdscript
COLOR_PRIMARY     # Main accent
COLOR_SECONDARY   # Secondary accent
COLOR_TERTIARY    # Tertiary accent
COLOR_BORDER      # Borders
COLOR_BLUE        # Info
COLOR_PURPLE      # Special
COLOR_EMERALD     # Success
COLOR_AMBER       # Warning
COLOR_RED         # Danger/Error
COLOR_CYAN        # Focus/Highlight
COLOR_TEXT_PRIMARY   # Main text
COLOR_TEXT_SECONDARY # Descriptions
COLOR_TEXT_MUTED     # Disabled text
```

### Legacy Colors (Still Supported)
```gdscript
COLOR_BASE := Color("#1A1A2E")         # Panel background
COLOR_ELEVATED := Color("#252542")     # Card backgrounds
COLOR_INPUT := Color("#1E1E36")        # Form field backgrounds
COLOR_ACCENT := Color("#2D5A7B")       # Primary accent (Deep Space Blue)
COLOR_ACCENT_HOVER := Color("#3A7199") # Hover state
COLOR_FOCUS := Color("#4FC3F7")        # Focus ring (cyan)
COLOR_TEXT_DISABLED := Color("#404040") # Inactive text
COLOR_SUCCESS := Color("#10B981")      # Green
COLOR_WARNING := Color("#D97706")      # Orange
COLOR_DANGER := Color("#DC2626")       # Red
```

## BBCode Colors (for RichTextLabel)
```gdscript
"[color=#10B981]Success[/color]"  # Green
"[color=#D97706]Warning[/color]"  # Orange
"[color=#DC2626]Error[/color]"    # Red
```

## Responsive Breakpoints
```gdscript
BREAKPOINT_MOBILE  := UIColors.BREAKPOINT_MOBILE
BREAKPOINT_TABLET  := UIColors.BREAKPOINT_TABLET
BREAKPOINT_DESKTOP := UIColors.BREAKPOINT_DESKTOP
```

Layout modes: `LayoutMode { MOBILE, TABLET, DESKTOP }`

## Project-Wide Theme (Mar 2026)

`project.godot` sets `gui/theme/custom="res://src/ui/themes/sci_fi_theme.tres"`.
All controls inherit Montserrat + Deep Space styles unless overridden via `add_theme_*_override()`.

**Fonts:**
- Default: Montserrat-Regular (`assets/fonts/Montserrat-Regular.ttf`)
- Buttons: Montserrat-SemiBold
- Bold/titles: Montserrat-Bold
- Monospace (RTL, TextEdit): CourierPrime-Regular

**Max-Width Form Constraint:**
- `BaseCampaignPanel.MAX_FORM_WIDTH := 800` — forms centered at 800px on wide screens
- `BugHuntCreationUI.MAX_FORM_WIDTH := 800` — same for Bug Hunt (extends Control, not BaseCampaignPanel)
- Dynamic margins via `_apply_content_max_width()` connected to viewport `size_changed`

**Portrait/Avatar System:**
- `CharacterCard._update_portrait()` prefers `portrait_path` (custom image), falls back to colored initials
- 8 deterministic avatar colors: `AVATAR_COLORS` array, index = `name.hash() % 8`
- Factory methods `_create_character_card()` accept optional `portrait_path` param
- `ResourceLoader.exists()` for `res://` paths, `FileAccess.file_exists()` for `user://` paths

**HFlowContainer for button bars:**
- CampaignDashboard ButtonContainer is now HFlowContainer (auto-wraps, no column management needed)

## Glass Card Styles
```gdscript
_create_glass_card_style(alpha: float = 0.8) -> StyleBoxFlat
_create_glass_card_elevated() -> StyleBoxFlat
_create_glass_card_subtle() -> StyleBoxFlat
_create_elevated_card_style() -> StyleBoxFlat
_create_accent_card_style(accent_color: Color) -> StyleBoxFlat
_create_glass_panel_style() -> StyleBoxFlat
_create_glass_panel_style_compact() -> StyleBoxFlat
```
