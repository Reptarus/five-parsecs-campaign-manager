# UI/UX Compliance Checklist — Five Parsecs Campaign Manager

Derived from the Deep Space theme design system and UI/UX Test Plan. Use this checklist for systematic UI auditing via MCP screenshots and element inspection.

---

## Two Testing Personas

Every UI check should be evaluated from BOTH perspectives:

| Persona | Needs | Key Questions |
|---------|-------|---------------|
| **Rulebook Replacer** | App is their ONLY reference. Never read the book. | Are game terms explained? Are tooltips present? Do instructions make sense standalone? |
| **Rulebook Companion** | Has book open beside device. Wants speed. | Can I skip tutorials? Is tracking fast? Are page references helpful? |

**Physical context**: Device next to tabletop with miniatures — portrait mode, one-handed taps, glanceable UI.

---

## 1. Navigation & Wayfinding (10 checks)

| ID | Check | How to Verify | Pri |
|----|-------|---------------|-----|
| NAV-01 | Every screen has a back button or clear exit | MCP: `get_ui_elements` — look for Button with text containing "Back", "Return", "Menu" | P0 |
| NAV-02 | No dead-end screens (can always navigate away) | Navigate to every SceneRouter key, verify back works | P0 |
| NAV-03 | Breadcrumb shows current location (Turn N > Phase) | MCP: screenshot + check for "Turn" label in phase panels | P1 |
| NAV-04 | SceneRouter history: 10+ screens deep back traversal | Navigate deeply, then back-button repeatedly | P1 |
| NAV-05 | Campaign creation step indicator visible (Step X of 7) | MCP: `get_ui_elements` on creation panels | P0 |
| NAV-06 | Main menu accessible from any gameplay screen | Verify "Main Menu" or equivalent button exists | P0 |
| NAV-07 | Stale data after navigation: screens refresh on entry | Navigate away and back, check data updates | P0 |
| NAV-08 | Scene transitions: no blank/black frames | MCP: screenshot during transition | P2 |
| NAV-09 | Bug Hunt / Battle Simulator stubs: "Coming soon" not crash | Click stub buttons, verify dialog | P1 |
| NAV-10 | Help screen accessible (currently MainMenu only) | Verify help exists, note if missing from dashboard | P1 |

---

## 2. Button Consistency (8 checks)

| ID | Check | How to Verify | Pri |
|----|-------|---------------|-----|
| BTN-01 | Primary action button uses accent color (#2D5A7B) | MCP: `run_script` to read button `self_modulate` or theme override | P1 |
| BTN-02 | Disabled buttons have amber warning label explaining why | `get_ui_elements` — find Label near disabled Button with warning text | P0 |
| BTN-03 | Button labels match action (e.g., "Save Campaign" not just "Save") | `get_ui_elements` — read all Button text values | P1 |
| BTN-04 | Touch targets >= 48px height | `get_ui_elements` — check `rect.height >= 48` for all Buttons | P0 |
| BTN-05 | No overlapping buttons | Check button rects don't intersect | P1 |
| BTN-06 | Hover state visible on desktop (COLOR_ACCENT_HOVER #3A7199) | Manual check on desktop | P2 |
| BTN-07 | Focus ring visible for keyboard nav (COLOR_FOCUS #4FC3F7) | Tab through buttons, check for cyan outline | P2 |
| BTN-08 | Consistent button placement (primary right, secondary left) | Visual audit via screenshots | P1 |

---

## 3. Text & Number Formatting (6 checks)

| ID | Check | How to Verify | Pri |
|----|-------|---------------|-----|
| TXT-01 | Credits display uses thousands separator (1,000 not 1000) | `run_script` to read credit Label text | P1 |
| TXT-02 | Short credit format uses "X cr" suffix | Check Labels containing "cr" | P1 |
| TXT-03 | Stat display format: "C:2 R:1 T:3 S:4 Sv:1 L:0" | Check character cards/stat badges | P1 |
| TXT-04 | BBCode renders in RichTextLabel (no raw `[color=...]` visible) | Screenshot, look for bracket text | P0 |
| TXT-05 | Body text is FONT_SIZE_MD (16px) | `run_script` to check font_size theme overrides | P2 |
| TXT-06 | Section headers use FONT_SIZE_LG (18px), panel titles FONT_SIZE_XL (24px) | `run_script` to check header font sizes | P2 |

---

## 4. Empty States (8 checks)

| ID | Check | How to Verify | Pri |
|----|-------|---------------|-----|
| EMP-01 | Empty crew list: "No crew members" message | Create campaign with minimum crew, remove members | P1 |
| EMP-02 | No missions available: "No opportunities" message | Trade phase with no items, or Job Offers with none | P1 |
| EMP-03 | Empty equipment stash: "No equipment in stash" | Ship inventory with no items | P1 |
| EMP-04 | No patrons: placeholder in patron list | World phase patron display | P2 |
| EMP-05 | No story events: phase auto-completes or shows message | Story phase with no events generated | P1 |
| EMP-06 | Empty battle log: "No actions recorded" | TacticalBattleUI at start | P2 |
| EMP-07 | No victory progress: "No conditions tracked" | Dashboard victory panel with STANDARD victory | P2 |
| EMP-08 | Trading with empty market: "Market empty" | Trade phase in RESTRICTED market | P1 |

---

## 5. Deep Space Theme Compliance (12 checks)

### Color Constants

| ID | Element | Expected Color | How to Verify | Pri |
|----|---------|---------------|---------------|-----|
| DS-01 | Panel background | #1A1A2E (COLOR_BASE) | Screenshot pixel check or `run_script` | P1 |
| DS-02 | Card background | #252542 (COLOR_ELEVATED) | PanelContainer StyleBox | P1 |
| DS-03 | Input fields | #1E1E36 (COLOR_INPUT) | LineEdit/TextEdit background | P2 |
| DS-04 | Card borders | #3A3A5C (COLOR_BORDER) | StyleBox border color | P2 |
| DS-05 | Primary accent | #2D5A7B (COLOR_ACCENT) | Primary buttons, highlights | P1 |
| DS-06 | Focus ring | #4FC3F7 (COLOR_FOCUS) | Focused element outline | P2 |
| DS-07 | Primary text | #E0E0E0 (COLOR_TEXT_PRIMARY) | Labels, body text | P1 |
| DS-08 | Secondary text | #808080 (COLOR_TEXT_SECONDARY) | Descriptions, helpers | P2 |
| DS-09 | Success status | #10B981 (COLOR_SUCCESS) | Green indicators | P1 |
| DS-10 | Warning status | #D97706 (COLOR_WARNING) | Amber/orange indicators | P1 |
| DS-11 | Danger/error | #DC2626 (COLOR_DANGER) | Red indicators | P1 |

### Spacing & Layout

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| DS-12 | Panel edge padding | 32px (SPACING_XL) | P2 |

---

## 6. Responsive Layout (6 checks)

| ID | Check | How to Verify | Pri |
|----|-------|---------------|-----|
| RES-01 | Portrait mode: content not clipped | Resize to 600×1024, screenshot | P0 |
| RES-02 | Landscape mode: layout uses width | Resize to 1920×1080, screenshot | P1 |
| RES-03 | Mobile breakpoint (<600px): single column | Resize to 400×800, check layout stacks | P1 |
| RES-04 | Touch targets >= 48px on mobile | `get_ui_elements` at mobile size | P0 |
| RES-05 | Font readable at mobile size | Screenshot at 400px width | P1 |
| RES-06 | Tablet breakpoint (600-1024px): 2-column | Resize to 768×1024, check layout | P2 |

---

## 7. Accessibility (4 checks)

| ID | Check | How to Verify | Pri |
|----|-------|---------------|-----|
| A11Y-01 | Reduced animation mode honored | Set `ThemeManager._reduced_animation = true`, verify `UIColors.should_animate()` returns false | P1 |
| A11Y-02 | Text contrast ratio adequate | Primary text (#E0E0E0) on base (#1A1A2E) = 11.3:1 (passes AAA) | P2 |
| A11Y-03 | Focus visible for keyboard navigation | Tab through interactive elements | P2 |
| A11Y-04 | No information conveyed by color alone | Check status indicators have text labels too | P2 |

---

## 8. Persona-Specific Assessment (4 checks)

| ID | Check | Persona | How to Verify | Pri |
|----|-------|---------|---------------|-----|
| PER-01 | Game terms have KeywordDB tooltips | Replacer | Click keyword-highlighted terms, verify popup | P1 |
| PER-02 | Phase instructions explain what to do | Replacer | Read each phase panel description | P1 |
| PER-03 | Quick navigation skips explanatory text | Companion | Verify skip/collapse for tutorial text | P2 |
| PER-04 | Stat abbreviations are intuitive (C/R/T/S/Sv/L) | Both | Check character cards | P2 |

---

## Audit Execution with MCP

### Quick Audit (15 minutes)
1. Launch game via `run_project`
2. `take_screenshot` of MainMenu
3. `get_ui_elements` — verify all expected buttons exist
4. Navigate to Campaign Creation, `take_screenshot` each step
5. Navigate to Campaign Dashboard, verify 3-column layout
6. Check button heights >= 48px across all elements

### Full Audit (45 minutes)
1. All Quick Audit steps
2. Navigate every SceneRouter key, screenshot each
3. `run_script` to inspect theme colors on key panels
4. Test empty states by creating minimal campaign
5. Resize to mobile/tablet/desktop breakpoints, screenshot each
6. Check all phase panels for breadcrumbs, validation hints, empty states
7. Verify BBCode renders (no raw tags visible)
8. Test back button from every screen

### MCP Script: Check Button Heights

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var results = []
    var root = scene_tree.root
    _check_buttons(root, results)
    return results

func _check_buttons(node: Node, results: Array) -> void:
    if node is Button and node.is_visible_in_tree():
        var rect = node.get_global_rect()
        if rect.size.y < 48:
            results.append({
                "name": str(node.name),
                "path": str(node.get_path()),
                "height": rect.size.y,
                "text": node.text,
                "issue": "Below 48px touch target minimum"
            })
    for child in node.get_children():
        _check_buttons(child, results)
```

---

## Known Issues (as of March 2026)

- Header capitalization mixed across panels (P2 cosmetic)
- Help screen only accessible from MainMenu (P1 — should be on dashboard)
- Platform back navigation not yet wired (Android/iOS/Desktop Escape key)
- Native Window popups invisible to MCP screenshots
