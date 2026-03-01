# Five Parsecs Campaign Wizard - Design Pattern Reference

**Purpose**: Visual reference guide for implementing consistent UI patterns across all campaign creation panels.  
**Date**: 2025-11-27  
**Status**: Established Design System (2/7 panels implemented)

---

## 🎨 Core Design Principles

1. **Mobile-First**: All touch targets >= 48dp, comfortable = 56dp
2. **8px Grid System**: All spacing uses multiples of 8px (4px for micro-spacing)
3. **Card-Based Hierarchy**: Sections wrapped in elevated cards with borders
4. **Deep Space Theme**: Dark backgrounds with blue accents, high contrast text
5. **Progressive Disclosure**: Descriptions inline, no hidden content
6. **Visual Feedback**: Hover, focus, and selected states for all interactive elements

---

## 📐 Spacing System

```
SPACING_XS = 4px   → Label-to-input gap, icon padding
SPACING_SM = 8px   → Element gaps within cards
SPACING_MD = 16px  → Inner card padding
SPACING_LG = 24px  → Section gaps between cards
SPACING_XL = 32px  → Panel edge padding
```

**Visual Guide**:
```
┌─ Panel Container ──────────────────────────────────┐
│  ← 32px (SPACING_XL)                               │
│  ┌─ Section Card 1 ─────────────────────────────┐  │
│  │  ← 16px (SPACING_MD)                         │  │
│  │  SECTION TITLE                                │  │
│  │  ────────────────                             │  │
│  │  ↕ 8px (SPACING_SM)                           │  │
│  │  Label Text  ← 4px (SPACING_XS) ↕             │  │
│  │  [Input Field (56dp height)]                  │  │
│  │  ↕ 8px (SPACING_SM)                           │  │
│  │  Description text below input...              │  │
│  │                               16px (SPACING_MD) → │
│  └───────────────────────────────────────────────┘  │
│  ↕ 24px (SPACING_LG)                               │
│  ┌─ Section Card 2 ─────────────────────────────┐  │
│  │  ...                                          │  │
│  └───────────────────────────────────────────────┘  │
│                               32px (SPACING_XL) → │
└────────────────────────────────────────────────────┘
```

---

## 🎯 Touch Target Standards

```
Minimum (48dp)     → Buttons, checkboxes, dropdowns
Comfortable (56dp) → LineEdit text inputs
Spacious (96dp)    → Victory condition cards
```

**Examples**:
```gdscript
// Button (minimum)
button.custom_minimum_size.y = 48  # TOUCH_TARGET_MIN

// LineEdit (comfortable)
line_edit.custom_minimum_size.y = 56  # TOUCH_TARGET_COMFORT

// Victory Card (spacious)
card.custom_minimum_size = Vector2(0, 96)  # TOUCH_TARGET_MIN * 2
```

---

## 🌈 Color Palette

### Backgrounds
```
COLOR_BASE      = #1A1A2E  → Panel background (darkest)
COLOR_ELEVATED  = #252542  → Card backgrounds (elevated)
COLOR_INPUT     = #1E1E36  → Form field backgrounds (recessed)
COLOR_BORDER    = #3A3A5C  → Card borders, separators
```

### Accents
```
COLOR_ACCENT       = #2D5A7B  → Primary accent (Deep Space Blue)
COLOR_ACCENT_HOVER = #3A7199  → Hover state (lighter blue)
COLOR_FOCUS        = #4FC3F7  → Focus/selection (Cyan)
```

### Text
```
COLOR_TEXT_PRIMARY   = #E0E0E0  → Main content (bright white-ish)
COLOR_TEXT_SECONDARY = #808080  → Descriptions (medium gray)
COLOR_TEXT_DISABLED  = #404040  → Inactive (dark gray)
```

### Status
```
COLOR_SUCCESS = #10B981  → Green (checkmarks, validation success)
COLOR_WARNING = #D97706  → Orange (warnings)
COLOR_DANGER  = #DC2626  → Red (errors)
```

**Visual Color Chart**:
```
Background Layers:
[#1A1A2E]  ← Panel base
  [#252542]  ← Cards (slightly lighter)
    [#1E1E36]  ← Input fields (recessed)

Accents:
[#2D5A7B] → Normal  [#3A7199] → Hover  [#4FC3F7] → Focus

Text:
[#E0E0E0] Primary  [#808080] Secondary  [#404040] Disabled

Status:
[#10B981] Success  [#D97706] Warning  [#DC2626] Danger
```

---

## 📝 Typography Scale

```
FONT_SIZE_XS = 11px  → Captions (target badges, limits)
FONT_SIZE_SM = 14px  → Descriptions, helper text
FONT_SIZE_MD = 16px  → Body text, input fields
FONT_SIZE_LG = 18px  → Section headers, step labels
FONT_SIZE_XL = 24px  → Panel titles, large icons
```

**Usage Examples**:
```gdscript
// Section header (uppercase)
label.text = "CAMPAIGN IDENTITY"
label.add_theme_font_size_override("font_size", 18)  # FONT_SIZE_LG
label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

// Description text
label.text = "Choose a memorable name for your crew's story"
label.add_theme_font_size_override("font_size", 14)  # FONT_SIZE_SM
label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

// Input field text
line_edit.add_theme_font_size_override("font_size", 16)  # FONT_SIZE_MD
```

---

## 🔲 Card Component Pattern

### Basic Section Card

**Code**:
```gdscript
var card = _create_section_card(
    "SECTION TITLE",           # Title (uppercase recommended)
    input_or_content_node,     # Control node with your content
    "Description text below"   # Optional description
)
parent.add_child(card)
```

**Visual Structure**:
```
┌─────────────────────────────────────────┐
│  SECTION TITLE          (18px, gray)    │ ← Uppercase, FONT_SIZE_LG
│  ─────────────────────                  │ ← Separator
│                                         │
│  [Content goes here]                    │ ← Your input/controls
│                                         │
│  → Description text appears below       │ ← FONT_SIZE_SM, gray
│    (14px, gray, autowrapped)            │
│                                         │
└─────────────────────────────────────────┘
  ↑                                      ↑
  16px padding                16px padding
  
Border: 1px #3A3A5C (COLOR_BORDER)
Background: #252542 (COLOR_ELEVATED)
Corner radius: 8px
```

### Victory Condition Card (Interactive)

**Code**:
```gdscript
var card = _create_victory_condition_card(key, condition_dict)
```

**Visual Structure**:
```
Unselected State:
┌─────────────────────────────────────────┐
│  Wealth Victory                     [✓] │ ← Checkmark hidden
│  Accumulate 10,000 credits              │ ← Description inline
│  Target: 10000 credits                  │ ← Badge (11px, blue)
└─────────────────────────────────────────┘
  Border: 2px #3A3A5C (normal)
  Background: #252542

Hover State (unselected):
┌═════════════════════════════════════════┐ ← Border thickens
║  Wealth Victory                     [✓] ║
║  Accumulate 10,000 credits              ║
║  Target: 10000 credits                  ║
└═════════════════════════════════════════┘
  Border: 3px #2D5A7B (COLOR_ACCENT)
  Background: #252542

Selected State:
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ← Cyan border
┃  Wealth Victory                     ✓   ┃ ← Checkmark visible (green)
┃  Accumulate 10,000 credits              ┃
┃  Target: 10000 credits                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
  Border: 3px #4FC3F7 (COLOR_FOCUS)
  Background: #4FC3F7 with 85% lightening (subtle tint)
  Checkmark: #10B981 (COLOR_SUCCESS)
```

**Interaction Flow**:
1. **Unselected + No Hover**: Gray border (2px), no checkmark
2. **Unselected + Hover**: Blue border (3px), no checkmark
3. **Click**: Toggle to selected
4. **Selected**: Cyan border (3px), tinted background, green checkmark
5. **Selected + Hover**: Keeps selected styling (cyan border overrides hover)

---

## 📥 Input Field Patterns

### LineEdit (Text Input)

**Code**:
```gdscript
var input = LineEdit.new()
input.placeholder_text = "Enter campaign name..."
_style_line_edit(input)  # Apply design system

var labeled = _create_labeled_input("Campaign Name", input)
```

**Visual**:
```
Campaign Name                    ← Label (14px, gray)
  ↕ 4px gap (SPACING_XS)
┌─────────────────────────────┐
│ The Starlight Wanderers     │  ← Input (16px, white text)
└─────────────────────────────┘
  56dp height (TOUCH_TARGET_COMFORT)
  
Normal:
  Background: #1E1E36 (COLOR_INPUT)
  Border: 1px #3A3A5C (COLOR_BORDER)
  Corner radius: 6px
  Padding: 8px

Focus:
  Border: 2px #4FC3F7 (COLOR_FOCUS) ← Thickens on focus
  Background: Same
```

### OptionButton (Dropdown)

**Code**:
```gdscript
var option = OptionButton.new()
_style_option_button(option)  # Apply design system
option.add_item("Standard", 0)
option.add_item("Challenging", 1)
```

**Visual**:
```
Difficulty Level                 ← Label (14px, gray)
  ↕ 4px gap
┌─────────────────────────────┐
│ Standard                  ▼ │  ← Dropdown (16px)
└─────────────────────────────┘
  48dp height (TOUCH_TARGET_MIN)
  
Styling: Same as LineEdit
  Background: #1E1E36
  Border: 1px #3A3A5C
  Focus: 2px #4FC3F7
```

### CheckBox

**Code**:
```gdscript
var checkbox = CheckBox.new()
checkbox.text = "Enable Story Track"
checkbox.custom_minimum_size.y = 48
checkbox.add_theme_font_size_override("font_size", 16)
checkbox.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
```

**Visual**:
```
☐ Enable Story Track    ← Unchecked (16px text, white)
☑ Enable Story Track    ← Checked

Height: 48dp (TOUCH_TARGET_MIN)
Text color: #E0E0E0 (COLOR_TEXT_PRIMARY)
```

---

## 🎯 Button Patterns

### Primary Button (Call-to-Action)

**Code**:
```gdscript
var button = Button.new()
button.text = "Apply Configuration"
button.custom_minimum_size.y = 48

var style = StyleBoxFlat.new()
style.bg_color = COLOR_ACCENT  # Blue background
style.set_corner_radius_all(6)
style.set_content_margin_all(16)
button.add_theme_stylebox_override("normal", style)

var hover_style = style.duplicate()
hover_style.bg_color = COLOR_ACCENT_HOVER
button.add_theme_stylebox_override("hover", hover_style)
```

**Visual**:
```
Normal:
┌─────────────────────────────┐
│ Apply Configuration         │  ← White text on blue
└─────────────────────────────┘
  Background: #2D5A7B (COLOR_ACCENT)
  
Hover:
┌═════════════════════════════┐
│ Apply Configuration         │  ← Slightly lighter blue
└═════════════════════════════┘
  Background: #3A7199 (COLOR_ACCENT_HOVER)
```

### Secondary Button (Reset, Cancel)

**Code**:
```gdscript
var button = Button.new()
button.text = "Reset"
button.custom_minimum_size.y = 48
// Use default Button style (transparent with border)
```

**Visual**:
```
┌─────────────────────────────┐
│ Reset                       │  ← Gray text, no background
└─────────────────────────────┘
  Default Godot button styling
```

### Add Button (Dashed Border)

**Code**:
```gdscript
var button = _create_add_button("+ Custom Victory Condition")
```

**Visual**:
```
┌ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┐
┊ + Custom Victory Condition  ┊  ← Gray text, dashed border
└ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┘
  Background: Transparent
  Border: 2px #808080 (dashed appearance)
  Text color: #808080 (COLOR_TEXT_SECONDARY)
```

---

## 📊 Progress Indicator Pattern

### Header Progress Bar + Breadcrumbs

**Code**:
```gdscript
// Called when panel changes
update_progress_indicator(current_step, "Campaign Setup")
```

**Visual Layout**:
```
┌─────────────────────────────────────────────────────┐
│  32px padding →                       ← 32px        │
│                                                     │
│  ════════════════════════════════                  │ ← Progress bar (8px)
│    Blue fill →    Gray remaining →                 │
│                                                     │
│        ●    ●    ●    ○    ○    ○    ○             │ ← Breadcrumbs
│       Done Done Curr Next Next Next Next           │
│       Blue Blue Cyan Gray Gray Gray Gray           │
│                                                     │
│     Step 3 of 7 • Victory Conditions               │ ← Step label (18px)
│                                                     │
└─────────────────────────────────────────────────────┘

Colors:
  Progress bar background: #3A3A5C (COLOR_BORDER)
  Progress bar fill: #2D5A7B (COLOR_ACCENT)
  Completed dots: #2D5A7B (COLOR_ACCENT)
  Current dot: #4FC3F7 (COLOR_FOCUS)
  Future dots: #808080 (COLOR_TEXT_SECONDARY)
```

---

## 🔧 Helper Method Quick Reference

### _create_section_card()
```gdscript
func _create_section_card(title: String, content: Control, description: String = "") -> PanelContainer

// Creates elevated card with:
// - Uppercase title (18px, gray)
// - Horizontal separator
// - Your content node
// - Optional description below (14px, gray)
```

### _create_labeled_input()
```gdscript
func _create_labeled_input(label_text: String, input: Control) -> VBoxContainer

// Creates:
// - Label above (14px, gray)
// - 4px gap
// - Your input control
```

### _style_line_edit()
```gdscript
func _style_line_edit(line_edit: LineEdit) -> void

// Applies:
// - Background: COLOR_INPUT
// - Border: COLOR_BORDER (1px) → COLOR_FOCUS (2px) on focus
// - Height: 56dp (TOUCH_TARGET_COMFORT)
// - Padding: 8px
// - Corner radius: 6px
```

### _style_option_button()
```gdscript
func _style_option_button(option_btn: OptionButton) -> void

// Applies same styling as LineEdit:
// - Height: 48dp (TOUCH_TARGET_MIN)
// - Background: COLOR_INPUT
// - Border: COLOR_BORDER → COLOR_FOCUS on focus
```

### _create_add_button()
```gdscript
func _create_add_button(text: String) -> Button

// Creates dashed-border "add" button:
// - Transparent background
// - 2px border (dashed appearance via StyleBoxFlat)
// - Gray text (COLOR_TEXT_SECONDARY)
// - Height: 48dp
```

---

## 🎨 Complete Panel Example

### ConfigPanel Structure

```gdscript
func _initialize_self_management() -> void:
    var main_container = get_or_create_container()
    main_container.add_theme_constant_override("separation", SPACING_LG)  # 24px
    
    _build_campaign_name_section(main_container)
    _build_difficulty_section(main_container)
    _build_victory_section(main_container)
    _build_story_track_section(main_container)

func _build_campaign_name_section(parent: Control) -> void:
    var input = LineEdit.new()
    input.placeholder_text = "The Starlight Wanderers"
    _style_line_edit(input)
    
    var content = _create_labeled_input("Campaign Name", input)
    
    var card = _create_section_card(
        "CAMPAIGN IDENTITY",
        content,
        "Choose a memorable name for your crew's story"
    )
    parent.add_child(card)
```

**Visual Result**:
```
┌─ Panel ────────────────────────────────────────────┐
│  32px →                                            │
│  ┌─ CAMPAIGN IDENTITY ────────────────────────┐   │
│  │  16px →                                     │   │
│  │  CAMPAIGN IDENTITY        (18px, gray)      │   │
│  │  ─────────────────────                      │   │
│  │  ↕ 8px                                      │   │
│  │  Campaign Name            (14px, gray)      │   │
│  │  ↕ 4px                                      │   │
│  │  ┌──────────────────────────────────────┐  │   │
│  │  │ The Starlight Wanderers              │  │   │ 56dp
│  │  └──────────────────────────────────────┘  │   │
│  │  ↕ 8px                                      │   │
│  │  → Choose a memorable name for your crew's │   │
│  │    story                 (14px, gray)      │   │
│  │                                   16px →   │   │
│  └─────────────────────────────────────────────┘   │
│  ↕ 24px                                            │
│  ┌─ CHALLENGE LEVEL ──────────────────────────┐   │
│  │  ...difficulty selector...                  │   │
│  └─────────────────────────────────────────────┘   │
│  ↕ 24px                                            │
│  ┌─ VICTORY GOAL ─────────────────────────────┐   │
│  │  ...victory dropdown...                     │   │
│  └─────────────────────────────────────────────┘   │
│  ↕ 24px                                            │
│  ┌─ NARRATIVE MODE ───────────────────────────┐   │
│  │  ☐ Enable Story Track                       │   │
│  └─────────────────────────────────────────────┘   │
│                                         32px → │
└────────────────────────────────────────────────────┘
```

---

## 🚀 Implementation Checklist

For each new panel, follow this order:

1. **Create main container**:
   ```gdscript
   var main = safe_get_node("path", func(): return create_basic_container("VBox"))
   main.add_theme_constant_override("separation", SPACING_LG)
   ```

2. **Build sections** (one method per section):
   ```gdscript
   func _build_xyz_section(parent: Control) -> void:
       var input = LineEdit.new()
       _style_line_edit(input)
       var content = _create_labeled_input("Field Name", input)
       var card = _create_section_card("SECTION TITLE", content, "Description")
       parent.add_child(card)
   ```

3. **Apply spacing**:
   - Panel edges: 32px (SPACING_XL)
   - Between cards: 24px (SPACING_LG) - applied via container separation
   - Within cards: 8px (SPACING_SM) - VBoxContainer separation
   - Label-to-input: 4px (SPACING_XS) - handled by `_create_labeled_input()`

4. **Style all inputs**:
   - LineEdit: `_style_line_edit()`
   - OptionButton: `_style_option_button()`
   - CheckBox: Manual (48dp height, 16px font, white text)
   - Buttons: Use `_create_add_button()` or manual StyleBoxFlat

5. **Verify touch targets**:
   - All interactive elements >= 48dp height
   - Text inputs = 56dp for comfort

6. **Connect signals**:
   ```gdscript
   input.text_changed.connect(_on_input_changed)
   button.pressed.connect(_on_button_pressed)
   ```

---

## 🎯 Quick Copy-Paste Templates

### LineEdit Section
```gdscript
func _build_xyz_section(parent: Control) -> void:
    var input = LineEdit.new()
    input.placeholder_text = "Example text..."
    _style_line_edit(input)
    
    var content = _create_labeled_input("Field Label", input)
    
    var card = _create_section_card(
        "SECTION TITLE",
        content,
        "Description text for this section"
    )
    parent.add_child(card)
```

### OptionButton Section
```gdscript
func _build_xyz_section(parent: Control) -> void:
    var option = OptionButton.new()
    _style_option_button(option)
    option.add_item("Option 1", 0)
    option.add_item("Option 2", 1)
    
    var description = Label.new()
    description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
    description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    
    var content = VBoxContainer.new()
    content.add_theme_constant_override("separation", SPACING_SM)
    content.add_child(_create_labeled_input("Option Label", option))
    content.add_child(description)
    
    var card = _create_section_card("SECTION TITLE", content, "")
    parent.add_child(card)
```

### CheckBox Section
```gdscript
func _build_xyz_section(parent: Control) -> void:
    var checkbox = CheckBox.new()
    checkbox.text = "Enable Feature"
    checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
    checkbox.add_theme_font_size_override("font_size", FONT_SIZE_MD)
    checkbox.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
    
    var card = _create_section_card(
        "SECTION TITLE",
        checkbox,
        "Description of this feature"
    )
    parent.add_child(card)
```

---

## 📚 Design System Philosophy

**Key Principles**:
1. **No magic numbers**: All values from design system constants
2. **Consistent spacing**: 8px grid everywhere (4px for micro-gaps)
3. **Touch-friendly**: Nothing smaller than 48dp
4. **Visual hierarchy**: Cards > sections > inputs > descriptions
5. **Inline feedback**: Descriptions visible, not hidden behind tooltips
6. **Color meaning**: Blue = accent, Cyan = focus, Green = success

**This design system ensures a consistent, professional, mobile-friendly UI across all campaign creation panels.**
