# Campaign Wizard UI - Screenshot Descriptions

**Purpose**: Detailed descriptions of what the UI should look like after implementing the design system.  
**Date**: 2025-11-27  
**Note**: These describe the expected visual state - actual screenshots should be taken after testing in Godot.

---

## 📸 Screenshot 1: ConfigPanel (Step 1 of 7)

### Header Section
- **Progress bar**: Thin blue line (8px height), ~14% filled (step 1/7)
- **Breadcrumbs**: Seven dots in a row with 12px spacing
  - First dot: Cyan (#4FC3F7) - current step
  - Remaining six dots: Gray (#808080) - future steps
- **Step label**: Centered text reading "Step 1 of 7 • Campaign Setup" in white (18px)
- **Background**: Very dark blue (#1A1A2E)
- **Spacing**: 32px padding from screen edges, 24px above cards

### Panel Content (4 Cards)

#### Card 1: CAMPAIGN IDENTITY
- **Title**: "CAMPAIGN IDENTITY" in gray uppercase (18px)
- **Separator**: Thin horizontal line below title
- **Label**: "Campaign Name" in gray (14px)
- **Input field**: 
  - Rectangular box with dark background (#1E1E36)
  - 1px gray border (#3A3A5C)
  - Placeholder text: "The Starlight Wanderers" in light gray
  - Height: 56px (comfortable for touch/click)
  - 8px internal padding
  - 6px rounded corners
- **Description**: "Choose a memorable name for your crew's story" in gray (14px) below input
- **Card background**: Slightly lighter than panel (#252542)
- **Card border**: 1px gray (#3A3A5C)
- **Spacing**: 16px padding inside card, 8px between elements

#### Card 2: CHALLENGE LEVEL
- **Title**: "CHALLENGE LEVEL" in gray uppercase
- **Label**: "Difficulty Level" in gray
- **Dropdown**: Shows "Standard" with down arrow (▼)
  - Same styling as text input (dark bg, gray border, 48px height)
- **Description**: Long paragraph explaining difficulty:
  - "Standard Mode: Core rules as written, balanced challenges, standard resource allocation. The authentic Five Parsecs experience."
  - Gray text (14px), autowrapped
- **Spacing**: Same as Card 1

#### Card 3: VICTORY GOAL
- **Title**: "VICTORY GOAL" in gray uppercase
- **Label**: "Victory Condition" in gray
- **Dropdown**: Shows "No Victory Condition" with down arrow
  - Same styling as other dropdowns
- **Description**: "Choose how you'll win this campaign (or select 'None' for sandbox play)"
- **Spacing**: Same pattern

#### Card 4: NARRATIVE MODE
- **Title**: "NARRATIVE MODE" in gray uppercase
- **Checkbox**: ☐ "Enable Story Track"
  - Unchecked square box on left
  - White text (16px)
  - 48px total height
- **Description**: "Enable for guided story missions and plot progression"
- **Spacing**: Same pattern

### Overall Layout
- **Vertical spacing**: 24px gaps between all 4 cards
- **Panel edges**: 32px padding on all sides
- **Total height**: Approximately 800-900px depending on description text wrapping
- **Background**: Deep dark blue creating "Deep Space" theme

---

## 📸 Screenshot 2: ExpandedConfigPanel (Step 2 of 7)

### Header Section
- **Progress bar**: ~28% filled (step 2/7)
- **Breadcrumbs**: 
  - First dot: Blue (#2D5A7B) - completed step
  - Second dot: Cyan (#4FC3F7) - current step
  - Remaining five: Gray (#808080) - future steps
- **Step label**: "Step 2 of 7 • Campaign Setup"

### Panel Content (6 Cards)

#### Card 1: CAMPAIGN IDENTITY
- Same as ConfigPanel Card 1 (campaign name input)

#### Card 2: CAMPAIGN STYLE
- **Title**: "CAMPAIGN STYLE" in gray uppercase
- **Dropdown**: Shows campaign type (e.g., "Standard Campaign")
- **Description**: "A full campaign with all systems enabled" in gray
  - Updates dynamically based on selection

#### Card 3: VICTORY CONDITIONS (Most Complex - Main Focus)
- **Title**: "VICTORY CONDITIONS" in gray uppercase
- **Description**: "Select one or more conditions - achieve ANY to win your campaign"

**Five Interactive Victory Cards**:

1. **Wealth Victory Card** (Unselected):
   ```
   ┌─────────────────────────────────────────┐
   │  Wealth Victory                         │  18px white
   │  Accumulate 10,000 credits              │  14px gray
   │  Target: 10000 credits                  │  11px blue
   └─────────────────────────────────────────┘
   ```
   - Border: 2px gray (#3A3A5C)
   - Background: Elevated card color (#252542)
   - Height: 96px (spacious for touch)
   - No checkmark visible

2. **Reputation Victory Card** (Hovering):
   ```
   ┌═════════════════════════════════════════┐  ← Border thicker
   │  Reputation Victory                     │
   │  Achieve maximum reputation with 3...   │
   │  Target: 3 factions                     │
   └═════════════════════════════════════════┘
   ```
   - Border: 3px blue (#2D5A7B) - accent color
   - Background: Same as unselected
   - Slight visual "lift" effect from thicker border

3. **Exploration Victory Card** (Selected):
   ```
   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓  ← Cyan border
   ┃  Exploration Victory                ✓   ┃  ← Green checkmark
   ┃  Visit 20 different worlds              ┃
   ┃  Target: 20 worlds                      ┃
   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
   ```
   - Border: 3px cyan (#4FC3F7) - focus color
   - Background: Very subtle cyan tint (cyan lightened 85%)
   - Checkmark: Green (#10B981), 24px, top-right corner
   - Visually "active" compared to others

4. **Combat Victory Card** (Selected):
   ```
   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   ┃  Combat Victory                     ✓   ┃
   ┃  Defeat 50 enemies in total             ┃
   ┃  Target: 50 enemies                     ┃
   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
   ```
   - Same selected styling as Exploration Victory

5. **Story Victory Card** (Unselected):
   - Same as Wealth Victory (gray border, no checkmark)

**Custom Button** (Below victory cards):
```
┌ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┐
┊  + Custom Victory Condition           ┊
└ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┘
```
- Dashed border appearance (2px gray)
- Transparent background
- Gray text (#808080)
- 48px height

**Selection Summary** (Below custom button):
- Rich text area showing:
  - "**2 Victory Conditions Selected**" in bold
  - "You can achieve ANY of these conditions to win!" in orange/amber
- Background: Slightly darker than card background
- 60px minimum height
- 14px text size

**Spacing within Victory Conditions card**:
- 8px gaps between victory cards
- 16px padding inside outer card
- 8px gap before summary

#### Card 4: NARRATIVE OPTIONS
- Story track dropdown
- Description updates based on selection

#### Card 5: LEARNING SUPPORT
- Tutorial mode dropdown
- Description updates based on selection

#### Card 6: Action Buttons (No formal card)
- **Reset Button**: Left side, gray text, transparent background, 48px height
- **Apply Configuration Button**: Right side
  - Blue background (#2D5A7B)
  - White text
  - 48px height
  - 16px padding
  - Rounded corners (6px)
  - Hover state: Lighter blue (#3A7199)
- Horizontal layout with 8px gap between buttons

### Overall Layout
- **Vertical spacing**: 24px between all cards
- **Panel height**: ~1200-1400px (taller due to victory cards)
- **Victory cards take ~50% of screen space** - they're the focal point

---

## 📸 Screenshot 3: Progress Indicator States

### Step 1 (ConfigPanel)
```
════════════                    (Progress bar: 14% filled)
  ●  ○  ○  ○  ○  ○  ○           (Breadcrumbs)
 Cyan Gray...
Step 1 of 7 • Campaign Setup
```

### Step 2 (ExpandedConfigPanel)
```
══════════════════              (Progress bar: 28% filled)
  ●  ●  ○  ○  ○  ○  ○
 Blue Cyan Gray...
Step 2 of 7 • Campaign Setup
```

### Step 4 (Hypothetical - Mid-Progress)
```
═══════════════════════════════ (Progress bar: 57% filled)
  ●  ●  ●  ●  ○  ○  ○
 Blue Blue Blue Cyan Gray...
Step 4 of 7 • Ship Configuration
```

### Step 7 (Final - Complete)
```
══════════════════════════════════ (Progress bar: 100% filled)
  ●  ●  ●  ●  ●  ●  ●
 Blue Blue Blue Blue Blue Blue Cyan
Step 7 of 7 • Review & Launch
```

---

## 📸 Screenshot 4: Touch Target Comparison

### Before (Hypothetical Old UI)
```
Campaign Name: [_____________________]  ← 24px height (too small!)
Difficulty: [Standard ▼]               ← 32px height
☐ Story Track                          ← 20px height
```

### After (Design System Applied)
```
Campaign Name                          ← Clear label
[The Starlight Wanderers________]      ← 56px height ✓

Difficulty Level
[Standard               ▼]             ← 48px height ✓

☐ Enable Story Track                   ← 48px height ✓
```

**Visual difference**:
- Inputs are **2-2.5× larger** (much easier to tap/click)
- Clear visual spacing between elements
- Labels separated from inputs (not inline)

---

## 📸 Screenshot 5: Victory Card Interaction Flow

### State 1: All Unselected
```
┌─ Wealth ──┐  ┌─ Reputation ──┐  ┌─ Exploration ──┐
│ ...       │  │ ...            │  │ ...             │
└───────────┘  └────────────────┘  └─────────────────┘
  Gray borders, no checkmarks
```

### State 2: Hovering Wealth
```
┌═ Wealth ══┐  ┌─ Reputation ──┐  ┌─ Exploration ──┐
║ ...       ║  │ ...            │  │ ...             │
└═══════════┘  └────────────────┘  └─────────────────┘
  Blue border (hover), others unchanged
```

### State 3: Clicked Wealth (Now Selected)
```
┏━ Wealth ━━┓  ┌─ Reputation ──┐  ┌─ Exploration ──┐
┃ ...     ✓ ┃  │ ...            │  │ ...             │
┗━━━━━━━━━━━┛  └────────────────┘  └─────────────────┘
  Cyan border, tinted bg, checkmark appears
```

### State 4: Also Selected Exploration
```
┏━ Wealth ━━┓  ┌─ Reputation ──┐  ┏━ Exploration ━┓
┃ ...     ✓ ┃  │ ...            │  ┃ ...         ✓ ┃
┗━━━━━━━━━━━┛  └────────────────┘  ┗━━━━━━━━━━━━━━━┛
  Two cards selected simultaneously
  
Summary below shows: "2 Victory Conditions Selected"
```

### State 5: Hovering Reputation (While Others Selected)
```
┏━ Wealth ━━┓  ┌═ Reputation ══┐  ┏━ Exploration ━┓
┃ ...     ✓ ┃  ║ ...            ║  ┃ ...         ✓ ┃
┗━━━━━━━━━━━┛  └════════════════┘  ┗━━━━━━━━━━━━━━━┛
  Hover shows blue border on unselected
  Selected cards keep cyan borders
```

---

## 📸 Screenshot 6: Color Palette in Context

### Dark Theme Layers (Visible in All Panels)
```
Background (Panel):    #1A1A2E  ████ Darkest
Card Backgrounds:      #252542  ████ Slightly lighter
Input Backgrounds:     #1E1E36  ████ Recessed (darker than cards)
Borders:               #3A3A5C  ──── Subtle gray
```

### Text Hierarchy
```
Primary Text:          #E0E0E0  "Campaign Identity"  (bright)
Secondary Text:        #808080  "Choose a name..."   (medium)
Disabled Text:         #404040  (not shown - dark gray)
```

### Interactive States
```
Normal Border:         #3A3A5C  ────  (gray)
Hover Border:          #2D5A7B  ════  (blue)
Focus/Selected Border: #4FC3F7  ━━━━  (cyan)
```

### Status Colors
```
Success (Checkmark):   #10B981  ✓     (green)
Warning:               #D97706  ⚠     (orange)
Danger:                #DC2626  ✕     (red)
```

---

## 📸 Screenshot 7: Spacing Visualization

### 8px Grid in Action
```
Panel edge (32px = 4×8)
│
│   ┌─ Card ─────────────────┐
│   │                         │ ← 16px padding (2×8)
│   │  TITLE                  │
│   │  ─────                  │ ← 8px gap (1×8)
│   │  Label    ← 4px (0.5×8) │
│   │  [Input]                │ ← 8px gap (1×8)
│   │  Description            │
│   │                         │ ← 16px padding (2×8)
│   └─────────────────────────┘
│   ↕ 24px gap (3×8)
│   ┌─ Next Card ─────────────┐
│   │  ...                    │
```

**Every spacing uses 4px or 8px multiples** - creates visual harmony.

---

## 🎬 Expected User Experience

### What Users Should See:
1. **Professional appearance** - looks like a commercial product, not a prototype
2. **Clear visual hierarchy** - section titles stand out, descriptions are subtle
3. **Touch-friendly sizing** - everything feels "easy to click/tap"
4. **Consistent spacing** - everything lines up perfectly on an invisible grid
5. **Interactive feedback** - hover effects show what's clickable, selection is obvious
6. **Progress clarity** - always know what step you're on and how much is left

### What Users Should Feel:
1. **Confidence** - "I understand what each field does"
2. **Control** - "I can easily navigate and make changes"
3. **Guidance** - "The UI is helping me make the right choices"
4. **Immersion** - "This feels like a real spacefaring campaign manager"

### What Users Should NOT See:
1. ❌ Placeholder text like "Panel-specific content will be added here"
2. ❌ Tiny, hard-to-click elements
3. ❌ Inconsistent spacing or alignment
4. ❌ Hidden information requiring tooltips
5. ❌ Flat, boring forms with no visual depth
6. ❌ Unclear progress or navigation

---

## 📊 Component Comparison Table

| Component | Before | After | Improvement |
|-----------|--------|-------|-------------|
| Campaign Name Input | 24px height, inline label | 56px height, label above | +133% size, clearer hierarchy |
| Victory Conditions | Basic checkboxes | Interactive 96px cards | Rich info display, multi-select feedback |
| Progress Indicator | Simple "Step 1 of 7" | Bar + breadcrumbs + label | Visual progress, clear status |
| Section Organization | Flat form | Elevated cards with borders | Clear sections, visual depth |
| Spacing | Inconsistent | 8px grid system | Perfect alignment |
| Touch Targets | 20-32px average | 48-56dp minimum | Mobile-friendly |
| Color Theme | Basic gray | Deep Space blue theme | Professional, thematic |
| Descriptions | Below or missing | Inline with every control | Immediate context |

---

## 🎨 Final Visual Summary

**Overall Theme**: "Deep Space Commander UI"
- Dark backgrounds create immersion (like looking at a ship console)
- Blue accents suggest technology and the void of space
- High contrast ensures readability
- Card-based design suggests modular ship systems
- Touch-friendly sizing accommodates tablet/mobile use during actual gameplay

**Visual Language**:
- Cards = Modules/Systems
- Blue highlights = Active systems
- Cyan borders = Selected/Focus
- Green checkmarks = Confirmed/Active
- Gray text = Informational/Secondary

**Expected Impression**: Players should feel like they're using a professional, well-designed campaign manager tool that respects their time and makes the complex process of campaign creation feel organized and manageable.

---

**These screenshot descriptions represent the target visual state. Actual implementation should match these specifications as closely as possible.**
