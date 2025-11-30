# Manual QA Checklist - Campaign Creation UI Improvements (Sprint A)

**Test Date**: _______________
**Tester**: _______________
**Build**: Sprint A Sessions 1 & 2 Complete

## Pre-Flight Validation

- [ ] No GDScript errors in Godot output console
- [ ] All integration tests passing (13/13 expected)
- [ ] All unit tests passing (13/13 expected: 8 StatBadge + 5 ValidationPanel)
- [ ] Theme resource loads correctly in Project Settings (res://assets/themes/deep_space_theme.tres)

---

## FinalPanel Visual Verification

### Campaign Name Display
- [ ] Campaign name displays in **XL font size (24px)**
- [ ] Campaign name uses **accent color (#2D5A7B)**
- [ ] Campaign name is clearly the visual focal point

### Section Card Icons
- [ ] **Configuration card** shows **⚙️ emoji icon** to left of "Campaign Config"
- [ ] **Ship card** shows **🚀 emoji icon** to left of "Ship"
- [ ] **Captain card** shows **👤 emoji icon** to left of "Captain"
- [ ] **Crew card** shows **👥 emoji icon** to left of "Crew"
- [ ] **Equipment card** shows **🎒 emoji icon** to left of "Starting Equipment"
- [ ] All icons are **18px font size** and vertically aligned with headers

### Ship Stat Badges
- [ ] **3 stat badges** render below ship name: Hull, Cargo, Debt
- [ ] Each badge is a **rounded panel** (8px corner radius)
- [ ] Each badge has **minimum 80x64px size**
- [ ] Badge layout: **name label above** (11px, gray), **value label below** (16px, white)
- [ ] **Hull badge** shows hull value (e.g., "6")
- [ ] **Cargo badge** shows cargo value (e.g., "8")
- [ ] **Debt badge** shows debt value (e.g., "2000") with **orange accent color**

### Crew Stat Badges
- [ ] **2 stat badges** render in Crew section: Avg Combat, Avg Reactions
- [ ] Each badge is a **rounded panel** (8px corner radius)
- [ ] Each badge has **minimum 80x64px size**
- [ ] **Avg Combat badge** shows value with **"+" prefix** (e.g., "+4")
- [ ] **Avg Combat badge** uses **green accent color (#10B981)**
- [ ] **Avg Reactions badge** shows value (e.g., "1")
- [ ] Values match calculated averages from crew data

### ValidationPanel Display
- [ ] **ValidationPanel renders above** "Create Campaign" button
- [ ] ValidationPanel has **8px corner radius**
- [ ] ValidationPanel has **2px border**
- [ ] ValidationPanel has **16px internal padding**

---

## Validation State Testing

### Success State (All Data Valid)
- [ ] Create campaign with complete data (name, captain, crew, ship, equipment)
- [ ] ValidationPanel shows **✅ checkmark icon**
- [ ] ValidationPanel message: **"Campaign ready to create!"**
- [ ] ValidationPanel has **green border (#10B981)**
- [ ] ValidationPanel has **subtle green background (10% opacity)**
- [ ] "Create Campaign" button is **ENABLED**

### Error State: Missing Campaign Name
- [ ] Clear campaign name field
- [ ] ValidationPanel shows **❌ error icon**
- [ ] ValidationPanel message: **"❌ Issues to fix:"**
- [ ] Bulleted error: **"Campaign name required"**
- [ ] ValidationPanel has **red border (#DC2626)**
- [ ] ValidationPanel has **subtle red background (10% opacity)**
- [ ] "Create Campaign" button is **DISABLED**

### Error State: Missing Captain
- [ ] Remove captain assignment
- [ ] ValidationPanel shows **❌ error icon**
- [ ] Bulleted error: **"Captain must be assigned"**
- [ ] ValidationPanel has **red styling**
- [ ] "Create Campaign" button is **DISABLED**

### Error State: Empty Crew
- [ ] Remove all crew members
- [ ] ValidationPanel shows **❌ error icon**
- [ ] Bulleted error: **"At least 1 crew member required"** (or similar)
- [ ] ValidationPanel has **red styling**
- [ ] "Create Campaign" button is **DISABLED**

### Error State: Multiple Errors
- [ ] Remove campaign name AND captain AND crew
- [ ] ValidationPanel shows **ALL errors** in bulleted list
- [ ] Each error on separate line with **bullet point**
- [ ] ValidationPanel has **red styling**
- [ ] "Create Campaign" button is **DISABLED**

### Success Recovery
- [ ] Fix all errors (add name, captain, crew)
- [ ] ValidationPanel returns to **✅ success state**
- [ ] Success message displays
- [ ] Green styling applied
- [ ] "Create Campaign" button is **ENABLED**

---

## Cross-Panel Compatibility

### ConfigPanel
- [ ] ConfigPanel still renders correctly
- [ ] No emoji icons appear (only FinalPanel uses icons)
- [ ] No visual regressions from base class changes

### CaptainPanel
- [ ] CaptainPanel still renders correctly
- [ ] Captain selection works normally
- [ ] No visual regressions

### CrewPanel
- [ ] CrewPanel still renders correctly
- [ ] Crew member cards display normally
- [ ] Add/remove crew works correctly

### ShipPanel
- [ ] ShipPanel still renders correctly
- [ ] Ship configuration works normally
- [ ] Hull/Cargo/Debt fields update correctly

### EquipmentPanel
- [ ] EquipmentPanel still renders correctly
- [ ] Equipment selection works normally
- [ ] No visual regressions

### WorldPanel
- [ ] WorldPanel still renders correctly
- [ ] World trait selection works normally
- [ ] No visual regressions

---

## Responsive Behavior

### Touch Targets
- [ ] "Create Campaign" button is **48px minimum height** (mobile)
- [ ] "Create Campaign" button is **56px height** on tablet (comfortable target)
- [ ] All interactive elements meet **48px minimum** touch target size

### Stat Badge Sizing
- [ ] Stat badges maintain **80x64px minimum** on all screen sizes
- [ ] Badges scale proportionally (not distorted)
- [ ] Badge labels remain readable at minimum size

### ValidationPanel Responsiveness
- [ ] ValidationPanel messages **autowrap** on narrow screens
- [ ] No horizontal scrolling required
- [ ] Panel width adapts to container

### Card Stacking
- [ ] All summary cards **stack vertically** on mobile
- [ ] Cards do not overlap or clip
- [ ] Proper spacing maintained (SPACING_LG = 24px between cards)

---

## Performance Check

### Load Time
- [ ] FinalPanel loads in **< 500ms** from wizard transition
- [ ] No visible lag when switching to FinalPanel
- [ ] Smooth transition animation

### Rendering Performance
- [ ] No frame drops when displaying all components
- [ ] Crew preview with 6 characters renders smoothly
- [ ] Stat badges render without flicker
- [ ] ValidationPanel updates instantly when data changes

### Memory Usage
- [ ] No memory leaks when switching panels repeatedly
- [ ] Resources cleanup properly when leaving wizard

---

## Data Integrity Checks

### Captain Data
- [ ] Captain name still displays correctly (from nested data normalization)
- [ ] Captain stats (Combat, Reactions, XP) display accurate values
- [ ] Captain background/motivation displayed correctly

### Crew Data
- [ ] Crew members convert correctly from Character → Dictionary
- [ ] Crew count matches actual crew.members.size()
- [ ] Average combat skill calculated correctly
- [ ] Average reactions calculated correctly
- [ ] Individual crew member cards show correct data

### Ship Data
- [ ] Ship name displays correctly
- [ ] Hull value matches ship configuration
- [ ] Cargo value matches ship configuration
- [ ] Debt value matches ship configuration

### Equipment Data
- [ ] Equipment items display correctly
- [ ] Equipment value calculated accurately
- [ ] No null parameter errors at FinalPanel:269
- [ ] No type mismatch errors at FinalPanel:412

### Campaign Config Data
- [ ] Campaign name from ConfigPanel displays correctly
- [ ] Victory conditions display correctly
- [ ] Difficulty level displays correctly
- [ ] Story track setting displays correctly

---

## Regression Testing

### Critical Data Flow
- [ ] No null parameter errors in console
- [ ] No type mismatch errors in console
- [ ] Campaign finalization completes successfully
- [ ] Created campaign saves correctly
- [ ] Created campaign loads correctly

### Signal Flow
- [ ] Panel transitions work correctly
- [ ] Data propagates from all panels to FinalPanel
- [ ] No signal disconnection errors
- [ ] No orphaned signal warnings

### Save/Load
- [ ] Campaign save completes without errors
- [ ] Save file contains all wizard data
- [ ] Loaded campaign displays correctly in FinalPanel
- [ ] Save/load roundtrip preserves all data

---

## Edge Case Testing

### Boundary Conditions
- [ ] Test with **minimum crew (1 member)**
- [ ] Test with **maximum crew (6 members)**
- [ ] Test with **0 debt**
- [ ] Test with **maximum debt (9999+)**
- [ ] Test with **very long campaign names (50+ characters)**
- [ ] Test with **special characters in campaign name** (★, ♠, emoji)

### Empty States
- [ ] Test with **no equipment**
- [ ] Test with **no starting credits**
- [ ] Test with **captain at 0 XP**
- [ ] Test with **crew at 0 combat skill**

### Extreme Values
- [ ] Test with **hull value = 1**
- [ ] Test with **hull value = 10**
- [ ] Test with **cargo value = 1**
- [ ] Test with **cargo value = 20**

---

## Visual Polish Checklist

### Typography
- [ ] All font sizes match design system (XS=11, SM=14, MD=16, LG=18, XL=24)
- [ ] Font colors match design system (primary=#E0E0E0, secondary=#808080)
- [ ] No font rendering artifacts or aliasing issues

### Colors
- [ ] Accent color (#2D5A7B) applied consistently
- [ ] Success green (#10B981) used for positive stats
- [ ] Warning orange (#D97706) used for debt
- [ ] Danger red (#DC2626) used for errors
- [ ] All colors meet WCAG AA contrast requirements

### Spacing
- [ ] Consistent 8px grid spacing throughout
- [ ] Card padding: 16px (SPACING_MD)
- [ ] Section gaps: 24px (SPACING_LG)
- [ ] Panel edge padding: 32px (SPACING_XL)
- [ ] No elements overlapping or clipping

### Borders & Corners
- [ ] All cards have 8px corner radius
- [ ] All stat badges have 8px corner radius
- [ ] ValidationPanel has 8px corner radius
- [ ] All borders are 2px width
- [ ] Border colors match design system

---

## Sign-Off

### Testing Summary
- **Tests Passed**: ______ / ______
- **Tests Failed**: ______
- **Blockers Found**: ______
- **Regressions Found**: ______

### Tester Notes
```
[Add any observations, issues, or recommendations here]
```

### Production Readiness Assessment
- [ ] **APPROVED** - Ready for commit and production
- [ ] **APPROVED WITH NOTES** - Minor issues, safe to proceed
- [ ] **BLOCKED** - Critical issues must be fixed before commit

**Tester Signature**: _______________
**Date**: _______________
