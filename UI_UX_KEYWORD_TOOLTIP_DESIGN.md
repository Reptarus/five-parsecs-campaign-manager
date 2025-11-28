# KeywordTooltip UI/UX Design Specification
**Five Parsecs Campaign Manager - Mobile-First Equipment Trait System**

**Document Version**: 1.0  
**Created**: 2025-11-28  
**Design Philosophy**: Infinity Army hyperlinked rules standard + Deep Space Theme  
**Primary Use Case**: Equipment trait descriptions (Assault, Bulky, Piercing +1, etc.)

---

## 1. DESIGN GOALS

### Primary Objectives
1. **Zero Rulebook Flipping**: Every keyword displays full rules inline
2. **Touch-Optimized**: No hover states - tap/click to reveal
3. **Contextual Learning**: Learn rules while equipping characters
4. **Bookmark Frequently Used**: Quick reference for common keywords
5. **Consistent Across Screens**: Works in Character Details, Crew Management, Dashboard

### Success Metrics
- User can understand "Brutal" keyword in ≤3 seconds from tap
- Tooltip appears within 100ms of tap (feels instant)
- 100% of equipment keywords are linkable (no orphaned terms)
- Bookmarked keywords accessible within 2 taps from any screen

---

## 2. KEYWORD STYLING - HOW KEYWORDS APPEAR IN TEXT

### Visual Treatment
Equipment traits appear as **interactive keywords** within equipment descriptions:

```
Display Example:
Infantry Laser (Assault, Bulky, Piercing +1)
              ↑        ↑       ↑
           Clickable keywords with visual indicators
```

### Keyword Styling Specification

#### Default State (Not Tapped)
- **Color**: `COLOR_FOCUS` (#4FC3F7 - Cyan)
- **Text Decoration**: Subtle dotted underline (1px, 50% opacity)
- **Font Size**: Inherit from parent (typically `FONT_SIZE_MD` = 16px)
- **Font Weight**: Normal (not bold - avoids visual noise)
- **Padding**: `SPACING_XS` (4px) left/right for touch target expansion

#### Hover State (Desktop Only - Mouse Over)
- **Color**: Lighten `COLOR_FOCUS` by 20% (#70D4FF)
- **Text Decoration**: Solid underline (1px, 100% opacity)
- **Cursor**: Pointer
- **Transition**: 150ms ease-out

#### Active State (Tap/Click)
- **Color**: `COLOR_ACCENT_HOVER` (#3A7199)
- **Background**: `COLOR_INPUT` (#1E1E36) with 2px padding
- **Border Radius**: 3px
- **Transition**: Instant (0ms - tactile feedback)

#### Bookmarked Keywords (Already Saved)
- **Icon**: ⭐ prefix (star emoji, 12px, `COLOR_WARNING` #D97706)
- **Color**: `COLOR_WARNING` instead of `COLOR_FOCUS`
- **Visual Pattern**: "⭐ Assault" instead of "Assault"

### Touch Target Compliance
```gdscript
# Minimum touch target calculation for inline keywords
func _create_keyword_button(keyword_text: String) -> Button:
    var btn := Button.new()
    btn.text = keyword_text
    btn.custom_minimum_size.y = TOUCH_TARGET_MIN  # 48dp minimum
    # Horizontal padding ensures comfortable tap area
    btn.add_theme_constant_override("hseparation", SPACING_SM)  # 8px
    return btn
```

**Critical**: Inline keywords in dense text (e.g., equipment lists) must have **minimum 8px vertical/horizontal spacing** between adjacent keywords to prevent mis-taps.

---

## 3. TOOLTIP PANEL LAYOUT

### Positioning Strategy (Responsive)

#### Mobile Portrait (<600px)
**Slide-Up Bottom Sheet** (recommended for one-handed thumb reach)
- **Position**: Anchored to bottom of screen
- **Height**: 60% viewport height (dynamic based on content)
- **Animation**: Slide up from bottom over 200ms ease-out
- **Background Overlay**: Semi-transparent scrim (#000000, 60% opacity)
- **Dismiss Area**: Tap scrim or drag sheet down

#### Tablet (600-900px)
**Centered Popover**
- **Position**: Centered on screen (or near tapped keyword if space allows)
- **Max Width**: 480px
- **Max Height**: 70% viewport height
- **Animation**: Scale from 0.9 to 1.0 over 150ms + fade-in
- **Background Overlay**: Semi-transparent scrim (#000000, 40% opacity)

#### Desktop (>900px)
**Contextual Popover Near Keyword**
- **Position**: 16px below/above tapped keyword (auto-adjust for viewport edges)
- **Width**: 420px fixed
- **Max Height**: 500px (scrollable if needed)
- **Animation**: Fade-in 100ms (instant feel)
- **Background Overlay**: None (allows interaction with rest of UI)
- **Arrow**: 8px triangle pointing to source keyword

### Tooltip Panel Structure

```
┌─────────────────────────────────────────┐
│  [X Close]               [⭐ Bookmark]  │  ← Header Bar
├─────────────────────────────────────────┤
│                                         │
│  KEYWORD TITLE                          │  ← Keyword Name (FONT_SIZE_XL)
│  Category: Weapon Trait                 │  ← Metadata (FONT_SIZE_SM)
│                                         │
├─────────────────────────────────────────┤
│  DEFINITION                             │  ← Section Header
│  This weapon can fire multiple times    │  ← Body Text (FONT_SIZE_MD)
│  in a single activation. Roll damage    │
│  for each shot separately.              │
│                                         │
├─────────────────────────────────────────┤
│  GAME EFFECT                            │  ← Section Header
│  • +2 shots per activation              │  ← Bullet List
│  • Each shot hits on separate roll      │
│                                         │
├─────────────────────────────────────────┤
│  RELATED KEYWORDS                       │  ← Section Header
│  [Burst] [Rapid Fire] [Suppressive]    │  ← Linked Buttons
│                                         │
├─────────────────────────────────────────┤
│  📖 Core Rulebook p.42                  │  ← Rule Reference
│  🔗 View full weapon rules →            │  ← Hyperlink to Rules Screen
└─────────────────────────────────────────┘
```

### Panel Styling Specification

```gdscript
# Tooltip panel base styling
var panel_style := StyleBoxFlat.new()
panel_style.bg_color = COLOR_ELEVATED  # #252542
panel_style.border_color = COLOR_FOCUS  # #4FC3F7 (cyan accent)
panel_style.set_border_width_all(2)
panel_style.set_corner_radius_all(12)  # Rounded corners
panel_style.shadow_color = Color(0, 0, 0, 0.5)
panel_style.shadow_size = 8
panel_style.shadow_offset = Vector2(0, 4)

# Header bar styling
var header_style := StyleBoxFlat.new()
header_style.bg_color = COLOR_BASE  # #1A1A2E (darker)
header_style.set_corner_radius(12)  # Match panel corners
header_style.corner_radius_bottom_left = 0  # Square bottom corners
header_style.corner_radius_bottom_right = 0
```

### Content Hierarchy

| Element | Font Size | Color | Purpose |
|---------|-----------|-------|---------|
| Keyword Title | `FONT_SIZE_XL` (24px) | `COLOR_TEXT_PRIMARY` | Main focus |
| Section Headers | `FONT_SIZE_LG` (18px) | `COLOR_TEXT_SECONDARY` | Structure |
| Body Text | `FONT_SIZE_MD` (16px) | `COLOR_TEXT_PRIMARY` | Readability |
| Metadata | `FONT_SIZE_SM` (14px) | `COLOR_TEXT_SECONDARY` | Context |
| Rule Reference | `FONT_SIZE_SM` (14px) | `COLOR_FOCUS` | Actionable link |

---

## 4. TOOLTIP CONTENT STRUCTURE

### Required Sections (Always Visible)

#### 1. Keyword Title + Metadata
```gdscript
# Example: "Assault" keyword
{
    "keyword": "Assault",
    "category": "Weapon Trait",
    "subcategory": "Firing Mode"
}
```
Display:
```
ASSAULT
Category: Weapon Trait • Firing Mode
```

#### 2. Definition
Plain-English explanation of what the keyword means:
```
"This weapon can be fired rapidly from the hip without 
carefully aiming. Assault weapons are ideal for suppressing 
enemies or clearing confined spaces."
```

#### 3. Game Effect
Mechanical rules in bullet-point format:
```
• Can shoot while moving at full speed
• No penalty for firing on the move
• Cannot use Aim action in same activation
```

### Optional Sections (Show If Data Exists)

#### 4. Related Keywords
Clickable links to related terms:
```gdscript
# Example: "Assault" relates to:
related_keywords = ["Rapid Fire", "Suppressive", "Heavy Weapon"]
# Display as horizontally scrollable button row
```

#### 5. Rule Page Reference
Link to rulebook section:
```
📖 Core Rulebook p.42
🔗 View full weapon rules → [navigates to RulesDisplay screen]
```

#### 6. Examples (Optional - Combat Traits Only)
Short gameplay example:
```
Example: Captain Elena fires her Assault Rifle while 
sprinting toward cover, hitting the enemy trooper despite 
moving at full speed.
```

---

## 5. ANIMATION & TRANSITIONS

### Tooltip Appearance

#### Mobile (Bottom Sheet)
```gdscript
# Slide-up animation
var tween := create_tween()
tween.set_ease(Tween.EASE_OUT)
tween.set_trans(Tween.TRANS_CUBIC)

# Start position: Below screen
tooltip_panel.position.y = viewport_height

# Animate to: 40% from bottom
tween.tween_property(
    tooltip_panel, 
    "position:y", 
    viewport_height * 0.4, 
    0.2  # 200ms duration
)

# Scrim fade-in
tween.parallel().tween_property(
    scrim_overlay,
    "modulate:a",
    0.6,  # 60% opacity
    0.2
)
```

#### Desktop (Popover)
```gdscript
# Fade + scale animation
var tween := create_tween()
tween.set_ease(Tween.EASE_OUT)
tween.set_trans(Tween.TRANS_QUAD)

# Start: 90% scale, 0% opacity
tooltip_panel.scale = Vector2(0.9, 0.9)
tooltip_panel.modulate.a = 0.0

# End: 100% scale, 100% opacity
tween.tween_property(tooltip_panel, "scale", Vector2.ONE, 0.15)
tween.parallel().tween_property(tooltip_panel, "modulate:a", 1.0, 0.15)
```

### Tooltip Dismissal

#### Tap Outside (Scrim)
```gdscript
# Mobile: Slide down
tween.tween_property(
    tooltip_panel,
    "position:y",
    viewport_height,  # Off-screen
    0.15  # Faster dismissal than appearance
)

# Desktop: Fade out
tween.tween_property(tooltip_panel, "modulate:a", 0.0, 0.1)
```

#### Close Button (X)
Same animation as "Tap Outside"

#### Swipe Down (Mobile Only)
```gdscript
# Track touch drag on tooltip panel
func _on_tooltip_drag_end(velocity: Vector2) -> void:
    if velocity.y > 500:  # Swipe down threshold
        dismiss_tooltip()  # Trigger slide-down animation
```

---

## 6. BOOKMARK SYSTEM

### Bookmark Indicator Design

#### In Equipment Lists (Bookmarked Keywords)
```
Display: "⭐ Assault" instead of "Assault"
Color: COLOR_WARNING (#D97706 - amber)
```

#### In Tooltip Header
```
┌─────────────────────────────────────────┐
│  [X Close]               [⭐ Bookmark]  │
└─────────────────────────────────────────┘
                          ↑
                    Toggle button
```

**Button States**:
- **Not Bookmarked**: Outlined star ☆ + "Bookmark"
- **Bookmarked**: Filled star ⭐ + "Bookmarked"
- **Touch Target**: 56×56dp minimum (comfortable thumb reach)

### Bookmark Storage (Data Layer - Not UI Spec)
```gdscript
# Example data structure (implementation reference for godot-specialist)
{
    "bookmarked_keywords": [
        "Assault",
        "Piercing",
        "Bulky",
        "Brutal"
    ],
    "last_updated": "2025-11-28T10:30:00Z"
}
```

### Bookmarked Keywords Quick Access
**Location**: Campaign Dashboard → Rules Reference Button
**Interaction**: Tap "Rules" → Opens RulesDisplay with "Bookmarks" tab pre-selected

---

## 7. RESPONSIVE BEHAVIOR MATRIX

| Viewport | Layout Mode | Tooltip Type | Animation | Scrim Opacity | Dismiss Method |
|----------|-------------|--------------|-----------|---------------|----------------|
| <600px | Mobile Portrait | Bottom Sheet | Slide-Up 200ms | 60% | Tap scrim, swipe down, X button |
| 600-900px | Tablet | Centered Modal | Scale+Fade 150ms | 40% | Tap scrim, X button |
| >900px | Desktop | Contextual Popover | Fade 100ms | None | Tap outside, X button, Esc key |

### Orientation Changes
```gdscript
# Handle device rotation mid-tooltip
func _on_viewport_resized() -> void:
    if tooltip_visible:
        # Re-calculate tooltip position/size for new orientation
        _reposition_tooltip()
        # Mobile landscape: Switch from bottom sheet to centered modal
        if is_mobile_landscape():
            _convert_to_centered_modal()
```

---

## 8. TOUCH TARGET COMPLIANCE CHECKLIST

### All Interactive Elements ≥48dp

✅ **Close Button (X)**
- Size: 56×56dp (comfort target)
- Position: Top-right corner
- Icon: × (FONT_SIZE_LG, COLOR_TEXT_SECONDARY)
- Hover: Background COLOR_DANGER with 50% opacity

✅ **Bookmark Button (⭐)**
- Size: 56×56dp (comfort target)
- Position: Top-right corner (adjacent to close button)
- Icon: ⭐/☆ (FONT_SIZE_LG, COLOR_WARNING)
- Toggle state visible via icon fill

✅ **Related Keywords Buttons**
- Height: 48dp minimum
- Padding: SPACING_SM (8dp) horizontal
- Margin: SPACING_XS (4dp) between buttons
- Layout: Horizontal scroll if overflow (mobile)

✅ **Rule Reference Link**
- Height: 48dp minimum (full-width tappable area)
- Icon: 🔗 or → (visual affordance)
- Color: COLOR_FOCUS (cyan - indicates interactivity)

### Spacing Between Interactive Elements
Minimum **8dp gap** between:
- Close button ↔ Bookmark button
- Related keyword buttons (horizontal scroll on mobile)
- Rule reference link ↔ Bottom edge

---

## 9. COLOR PALETTE USAGE

### Tooltip Panel Colors
| Element | Color Constant | Hex Value | Usage |
|---------|---------------|-----------|-------|
| Panel Background | `COLOR_ELEVATED` | #252542 | Main tooltip surface |
| Panel Border | `COLOR_FOCUS` | #4FC3F7 | Cyan accent (draws attention) |
| Header Background | `COLOR_BASE` | #1A1A2E | Darker contrast area |
| Section Dividers | `COLOR_BORDER` | #3A3A5C | Subtle separators |
| Scrim Overlay | Black | #000000 | 40-60% opacity (context-dependent) |

### Text Colors
| Text Type | Color Constant | Hex Value | Usage |
|-----------|---------------|-----------|-------|
| Keyword Title | `COLOR_TEXT_PRIMARY` | #E0E0E0 | High contrast |
| Body Text | `COLOR_TEXT_PRIMARY` | #E0E0E0 | Readable |
| Section Headers | `COLOR_TEXT_SECONDARY` | #808080 | Structural hierarchy |
| Metadata | `COLOR_TEXT_SECONDARY` | #808080 | Supporting info |
| Rule Links | `COLOR_FOCUS` | #4FC3F7 | Interactive elements |

### Status Colors
| Status | Color Constant | Hex Value | Usage |
|--------|---------------|-----------|-------|
| Bookmarked Keywords | `COLOR_WARNING` | #D97706 | Amber star indicator |
| Close Button Hover | `COLOR_DANGER` | #DC2626 | Red destructive action |
| Success Feedback | `COLOR_SUCCESS` | #10B981 | Green (bookmark added toast) |

---

## 10. TYPOGRAPHY SCALE FOR TOOLTIP

### Font Sizes (Design System)
```gdscript
# Tooltip-specific typography usage
const TOOLTIP_TITLE_SIZE = FONT_SIZE_XL       # 24px - Keyword name
const TOOLTIP_SECTION_SIZE = FONT_SIZE_LG     # 18px - Section headers
const TOOLTIP_BODY_SIZE = FONT_SIZE_MD        # 16px - Definitions
const TOOLTIP_META_SIZE = FONT_SIZE_SM        # 14px - Metadata
const TOOLTIP_CAPTION_SIZE = FONT_SIZE_XS     # 11px - Rule page numbers
```

### Line Height
- **Title**: 1.2× (tight, display font)
- **Body Text**: 1.5× (comfortable reading)
- **Metadata**: 1.4× (compact but readable)

### Text Alignment
- **Keyword Title**: Left-aligned
- **Section Headers**: Left-aligned (uppercase for emphasis)
- **Body Text**: Left-aligned (never center - reduces readability)
- **Bullet Lists**: Left-aligned with 16px indent

---

## 11. ACCESSIBILITY CONSIDERATIONS

### Screen Reader Support (Future Enhancement)
```gdscript
# Annotate keyword buttons for screen readers
keyword_button.accessible_name = "Equipment trait: Assault. Tap for details."
tooltip_panel.accessible_role = AccessibilityRole.DIALOG
close_button.accessible_name = "Close tooltip"
```

### Keyboard Navigation (Desktop)
- **Tab**: Cycle through interactive elements (Close, Bookmark, Related Keywords, Rule Link)
- **Escape**: Dismiss tooltip
- **Enter/Space**: Activate focused element

### High Contrast Mode (Future)
- Increase border width from 2px → 3px
- Use `COLOR_TEXT_PRIMARY` for all borders (maximum contrast)
- Remove subtle opacity effects

---

## 12. IMPLEMENTATION NOTES FOR GODOT-SPECIALIST

### Scene Structure Recommendation
```
KeywordTooltip.tscn
├── ScrimOverlay (ColorRect)
│   └── [Tap detection for dismiss]
├── TooltipPanel (PanelContainer)
│   ├── MainVBox (VBoxContainer)
│   │   ├── HeaderBar (HBoxContainer)
│   │   │   ├── CloseButton (Button)
│   │   │   ├── Spacer (Control - SIZE_EXPAND_FILL)
│   │   │   └── BookmarkButton (Button)
│   │   ├── ContentScroll (ScrollContainer)
│   │   │   └── ContentVBox (VBoxContainer)
│   │   │       ├── KeywordTitle (Label)
│   │   │       ├── Metadata (Label)
│   │   │       ├── Separator1 (HSeparator)
│   │   │       ├── DefinitionSection (VBoxContainer)
│   │   │       ├── Separator2 (HSeparator)
│   │   │       ├── GameEffectSection (VBoxContainer)
│   │   │       ├── Separator3 (HSeparator)
│   │   │       ├── RelatedKeywordsSection (HBoxContainer with ScrollContainer)
│   │   │       ├── Separator4 (HSeparator)
│   │   │       └── RuleReferenceLink (Button)
└── [Animations: show_tooltip(), hide_tooltip()]
```

### Signal Interface
```gdscript
# Signals for KeywordTooltip.gd
signal tooltip_opened(keyword: String)
signal tooltip_closed()
signal keyword_bookmarked(keyword: String)
signal keyword_unbookmarked(keyword: String)
signal related_keyword_clicked(keyword: String)
signal rule_reference_clicked(rule_page: String)
```

### Public Methods
```gdscript
func show_tooltip(keyword_data: Dictionary, source_position: Vector2) -> void
func hide_tooltip() -> void
func toggle_bookmark(keyword: String) -> void
func is_keyword_bookmarked(keyword: String) -> bool
```

---

## 13. EDGE CASES & POLISH

### Multi-Line Keyword Phrases
Example: "Piercing +1" (two-word keyword)
- **Treatment**: Single clickable button with full phrase
- **Spacing**: No line-break between "Piercing" and "+1"

### Viewport Edge Detection
```gdscript
# Ensure tooltip stays on-screen (desktop popover mode)
func _calculate_tooltip_position(source_pos: Vector2) -> Vector2:
    var tooltip_size = tooltip_panel.size
    var viewport_size = get_viewport().get_visible_rect().size
    
    var pos = source_pos + Vector2(0, 24)  # 24px below keyword
    
    # Check right edge
    if pos.x + tooltip_size.x > viewport_size.x:
        pos.x = viewport_size.x - tooltip_size.x - 16
    
    # Check bottom edge - flip to above keyword if needed
    if pos.y + tooltip_size.y > viewport_size.y:
        pos.y = source_pos.y - tooltip_size.y - 8
    
    return pos
```

### Rapid Tap Prevention
```gdscript
# Prevent tooltip spam from rapid taps
var _last_tooltip_time: float = 0.0
const MIN_TOOLTIP_INTERVAL = 0.3  # 300ms cooldown

func _on_keyword_tapped(keyword: String) -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - _last_tooltip_time < MIN_TOOLTIP_INTERVAL:
        return  # Ignore rapid taps
    
    _last_tooltip_time = current_time
    show_tooltip(keyword)
```

### Scroll Position Preservation
When tooltip appears over scrollable equipment list:
- **Lock parent scroll** while tooltip visible (prevent accidental scroll)
- **Restore scroll position** on dismiss

---

## 14. DELIVERABLES SUMMARY

### 1. Keyword Styling Specification ✅
- Inline keywords styled with `COLOR_FOCUS` (#4FC3F7 cyan)
- Dotted underline (1px, 50% opacity)
- Bookmarked keywords show ⭐ prefix in `COLOR_WARNING` (#D97706 amber)
- Touch targets: 48dp minimum height, 8dp spacing

### 2. Tooltip Panel Layout ✅
- **Mobile**: Bottom sheet (60% viewport height, slide-up 200ms)
- **Tablet**: Centered modal (480px width, scale+fade 150ms)
- **Desktop**: Contextual popover (420px width, fade 100ms)
- Panel: `COLOR_ELEVATED` background, `COLOR_FOCUS` border, 12px corner radius

### 3. Animation/Transition Spec ✅
- Mobile: Slide-up 200ms ease-out (cubic)
- Desktop: Scale+fade 150ms ease-out (quad)
- Dismissal: 100-150ms (faster than appearance)
- Swipe-down gesture for mobile dismissal

### 4. Bookmark Indicator Design ✅
- Header button: 56×56dp toggle (☆ unfilled ↔ ⭐ filled)
- Color: `COLOR_WARNING` (#D97706)
- Inline display: ⭐ prefix on bookmarked keywords
- Quick access: Rules screen → Bookmarks tab

### 5. Responsive Behavior ✅
- <600px: Bottom sheet with scrim (60% opacity)
- 600-900px: Centered modal with scrim (40% opacity)
- >900px: Contextual popover, no scrim
- Orientation changes trigger layout recalculation

### 6. Touch Target Compliance ✅
- Close button: 56×56dp (comfort)
- Bookmark button: 56×56dp (comfort)
- Related keywords: 48dp height minimum
- 8dp minimum spacing between all interactive elements

### 7. Color Palette Usage ✅
- Panel: `COLOR_ELEVATED` (#252542)
- Border: `COLOR_FOCUS` (#4FC3F7)
- Text: `COLOR_TEXT_PRIMARY` (#E0E0E0)
- Headers: `COLOR_TEXT_SECONDARY` (#808080)
- Links: `COLOR_FOCUS` (#4FC3F7)

### 8. Typography Scale ✅
- Title: `FONT_SIZE_XL` (24px)
- Sections: `FONT_SIZE_LG` (18px)
- Body: `FONT_SIZE_MD` (16px)
- Metadata: `FONT_SIZE_SM` (14px)
- Captions: `FONT_SIZE_XS` (11px)

---

## 15. VISUAL DESIGN MOCKUP (ASCII)

### Mobile Portrait View (Bottom Sheet)

```
┌─────────────────────────────────┐
│  Equipment List (Background)    │
│                                 │
│  Infantry Laser                 │
│  [Assault] [Bulky] [Piercing]   │  ← User taps "Assault"
│  ↓                              │
│  Auto Rifle                     │
│                                 │
├═════════════════════════════════┤ ← Scrim overlay (60% black)
│█████████████████████████████████│
│█ [X]                      [⭐] █│ ← Header (56dp height)
│█─────────────────────────────█ │
│█                             █ │
│█  ASSAULT                    █ │ ← Title (24px)
│█  Category: Weapon Trait     █ │ ← Metadata (14px)
│█                             █ │
│█─────────────────────────────█ │
│█  DEFINITION                 █ │ ← Section (18px)
│█  This weapon can be fired   █ │ ← Body (16px)
│█  rapidly from the hip...    █ │
│█                             █ │
│█─────────────────────────────█ │
│█  GAME EFFECT                █ │
│█  • Fire while moving        █ │
│█  • No movement penalty      █ │
│█                             █ │
│█─────────────────────────────█ │
│█  RELATED KEYWORDS           █ │
│█  [Rapid Fire] [Suppressive] █ │ ← Scroll horizontally →
│█                             █ │
│█─────────────────────────────█ │
│█  📖 Core Rulebook p.42      █ │
│█  🔗 View full rules →       █ │ ← Link (48dp height)
│█                             █ │
└─────────────────────────────────┘
   ↑ Drag down to dismiss
```

### Desktop Contextual Popover

```
Equipment: Infantry Laser (Assault, Bulky)
                           ↓
                    ┌──────────────────────┐
                    │▼                     │ ← Arrow pointer
┌───────────────────────────────────────────┐
│ [X]                             [☆]       │ ← Header
├───────────────────────────────────────────┤
│                                           │
│ ASSAULT                                   │
│ Category: Weapon Trait                    │
│                                           │
├───────────────────────────────────────────┤
│ DEFINITION                                │
│ This weapon can be fired rapidly from     │
│ the hip without carefully aiming.         │
│                                           │
├───────────────────────────────────────────┤
│ GAME EFFECT                               │
│ • Can shoot while moving at full speed    │
│ • No penalty for firing on the move       │
│                                           │
├───────────────────────────────────────────┤
│ RELATED: [Rapid Fire] [Suppressive]       │
│                                           │
├───────────────────────────────────────────┤
│ 📖 Core Rulebook p.42                     │
│ 🔗 View full weapon rules →               │
└───────────────────────────────────────────┘
       ↑ Click outside to dismiss
```

---

## 16. KEYWORD DATABASE SCHEMA (Reference for godot-specialist)

```json
{
  "keywords": [
    {
      "id": "assault",
      "display_name": "Assault",
      "category": "Weapon Trait",
      "subcategory": "Firing Mode",
      "definition": "This weapon can be fired rapidly from the hip without carefully aiming. Assault weapons are ideal for suppressing enemies or clearing confined spaces.",
      "game_effect": [
        "Can shoot while moving at full speed",
        "No penalty for firing on the move",
        "Cannot use Aim action in same activation"
      ],
      "related_keywords": ["rapid_fire", "suppressive", "hip_fire"],
      "rule_reference": {
        "book": "Core Rulebook",
        "page": 42,
        "section": "Weapon Traits"
      },
      "example": "Captain Elena fires her Assault Rifle while sprinting toward cover, hitting the enemy trooper despite moving at full speed.",
      "tags": ["weapon", "combat", "movement"]
    },
    {
      "id": "piercing",
      "display_name": "Piercing",
      "category": "Weapon Trait",
      "subcategory": "Armor Penetration",
      "definition": "This weapon ignores a portion of the target's armor, making it effective against heavily protected enemies.",
      "game_effect": [
        "Ignore +1 point of target's armor",
        "Effective against armored foes",
        "Stacks with other armor-piercing effects"
      ],
      "related_keywords": ["armor_piercing", "penetrator", "anti_armor"],
      "rule_reference": {
        "book": "Core Rulebook",
        "page": 43,
        "section": "Weapon Traits"
      },
      "tags": ["weapon", "combat", "armor"]
    }
  ]
}
```

---

## 17. TESTING CHECKLIST (For QA-Specialist)

### Visual Testing
- [ ] Keywords appear in cyan (#4FC3F7) with dotted underline
- [ ] Bookmarked keywords show amber star (⭐) prefix
- [ ] Tooltip panel has 2px cyan border with 12px corner radius
- [ ] Typography sizes match specification (24/18/16/14/11px)
- [ ] Touch targets meet 48dp minimum (56dp for comfort buttons)

### Interaction Testing
- [ ] Tap keyword → tooltip appears within 100ms
- [ ] Mobile: Tooltip slides up from bottom (200ms animation)
- [ ] Desktop: Tooltip fades in near keyword (100ms animation)
- [ ] Tap scrim → tooltip dismisses (150ms slide-down)
- [ ] Swipe down on mobile → tooltip dismisses
- [ ] Tap Close (X) button → tooltip dismisses
- [ ] Rapid taps don't spawn multiple tooltips (300ms cooldown)

### Responsive Testing
- [ ] <600px: Bottom sheet layout with 60% scrim
- [ ] 600-900px: Centered modal with 40% scrim
- [ ] >900px: Contextual popover with no scrim
- [ ] Portrait ↔ Landscape rotation recalculates layout
- [ ] Tooltip stays on-screen (edge detection works)

### Bookmark Testing
- [ ] Tap bookmark button → star fills (⭐)
- [ ] Tap again → star unfills (☆)
- [ ] Bookmarked keyword shows amber star in equipment list
- [ ] Bookmark persists across app sessions (save/load)

### Content Testing
- [ ] All equipment keywords are clickable (100% coverage)
- [ ] Related keywords link to correct tooltips
- [ ] Rule page references navigate to RulesDisplay
- [ ] Section dividers render correctly (HSeparator)

---

**End of Specification**

This design adheres to:
✅ Infinity Army hyperlinked rules standard  
✅ BaseCampaignPanel Deep Space Theme  
✅ Mobile-first responsive design  
✅ 48dp minimum touch targets  
✅ Consistent typography and color system  
✅ Progressive disclosure (tap to reveal, not hover)  
✅ Bookmark system for quick reference  
✅ Contextual popover on desktop, bottom sheet on mobile
