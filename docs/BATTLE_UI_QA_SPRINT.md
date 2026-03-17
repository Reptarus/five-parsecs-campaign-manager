# QA Sprint: Battle Phase UI/UX — Full Combat Walkthrough

**Created**: 2026-03-15
**Status**: READY TO EXECUTE
**Prerequisite**: Graph-paper map rewrite + UX improvements completed this session

## Context

The battle UI was overhauled with:
- Graph-paper terrain map (labrador.dev style) using ScalableVectorShape2D
- Quick dice bar (1d6/2d6/d100 always visible)
- Colored phase breadcrumbs (green/blue/gray)
- Auto tab switching per battle phase
- Expanded bottom bar (110px) and right panel (280px)

This QA sprint tests the **complete player experience** of running a Five Parsecs From Home tabletop battle using the companion app alongside physical miniatures and the Core Rules book.

## Files Changed This Session

| File | Change |
|------|--------|
| `src/ui/components/battle/BattlefieldMapView.gd` | Complete rewrite — graph-paper grid, SVS terrain, axes, auto-scaling |
| `src/ui/components/battle/BattlefieldShapeLibrary.gd` | Vector shape factory, map colors, increased sizes |
| `src/ui/components/battle/BattlefieldGridPanel.gd` | Simplified to map-only (removed sector text view) |
| `src/ui/screens/battle/TacticalBattleUI.gd` | Quick dice bar, phase tab auto-switching |
| `src/ui/screens/battle/TacticalBattleUI.tscn` | Bottom bar 80→110px, right panel 240→280px |
| `src/ui/components/battle/BattleRoundHUD.gd` | Color-coded phase states (green/blue/gray) |

---

## Test Setup

### MCP Test (no campaign needed)

```gdscript
# Navigate to battle
var sr = scene_tree.root.get_node_or_null("/root/SceneRouter")
sr.navigate_to("tactical_battle")

# Force panels visible (normally done by _apply_stage_visibility)
var root = scene_tree.current_scene
root.find_child("CenterPanel", true, false).visible = true
root.find_child("RightPanel", true, false).visible = true
root.find_child("PhaseContentPanel", true, false).visible = true

# Populate map with test terrain
var gp = root.find_child("BattlefieldGridPanel", true, false)
var sectors = []
for lbl in ["A1","A2","A3","A4","B1","B2","B3","B4","C1","C2","C3","C4","D1","D2","D3","D4"]:
    var features = []
    if lbl == "A1": features = ["Large factory building (full cover)"]
    elif lbl == "A3": features = ["Metal barricade (partial cover)"]
    elif lbl == "B2": features = ["Dense tree cluster (full cover)", "Scatter: Rock, Bush"]
    elif lbl == "B4": features = ["Stack of cargo containers (full cover)"]
    elif lbl == "C1": features = ["NOTABLE: Control tower (full cover, 2 levels)"]
    elif lbl == "C3": features = ["Boulder (full cover)", "Rocky outcrop"]
    elif lbl == "D2": features = ["Shallow crater (partial cover)"]
    elif lbl == "D4": features = ["Chemical drum cluster (dangerous)"]
    sectors.append({"label": lbl, "features": features})
gp.populate(sectors, "Industrial Zone")
```

### Full Campaign Test

1. Create campaign (7-phase wizard)
2. Complete Turn 1 through World Phase
3. Reach Battle Phase — TacticalBattleUI launches automatically

---

## STAGE 1: TIER SELECTION

### What User Sees
- Dark overlay covers entire screen (OverlayLayer at z=10)
- Centered modal with 3 tier options
- All other panels hidden

### QA Checks
- [ ] Overlay background visible, darkened
- [ ] Three tier buttons rendered and clickable
- [ ] All panels (left, center, right, bottom) hidden
- [ ] Selecting a tier dismisses overlay → advances to SETUP

### Code: `TacticalBattleUI.gd:239-247`, `TacticalBattleUI.tscn:302-325`

---

## STAGE 2: SETUP — "Set Up Your Battlefield"

### What User Sees
- Top bar: "Tactical Companion [LOG ONLY] Setup > Deploy > Combat"
- Center: Graph-paper terrain map with terrain shapes
- Right panel: Setup tab with terrain info, deployment conditions, mission objective
- Bottom bar: "Set Up Your Battlefield", "Begin Battle" button
- Quick Dice Bar: "Quick: 1d6 | 2d6 | d100" below right tabs

### Physical Tabletop
1. Read terrain theme and sector descriptions from Setup tab
2. Place terrain pieces matching the map layout (use inch axes for positioning)
3. Note deployment conditions and mission objective

### QA Checks
- [ ] Map: near-white background with graph-paper grid
- [ ] Terrain shapes visible (gray rects=buildings, green ellipses=forests, teal rects=containers)
- [ ] Deployment zones (green=crew A-B, pink=enemy C-D)
- [ ] Numbered inch axes (0, 5, 10, 15, 20, 25, 30)
- [ ] Sector labels (A1-D4)
- [ ] Dashed center line
- [ ] Setup tab: TERRAIN SETUP + SECTOR LAYOUT + DEPLOYMENT CONDITION + MISSION OBJECTIVE
- [ ] Regenerate button works
- [ ] Quick dice bar visible
- [ ] "Begin Battle" button in bottom bar
- [ ] Header: "BATTLEFIELD OVERVIEW" + theme name + Regenerate + Collapse

### Code: `TacticalBattleUI.gd:249-263, 1530-1675`, `BattlefieldMapView.gd:334-368`

---

## STAGE 3: DEPLOYMENT — "Deploy Your Crew"

### What User Sees
- Left panel NOW VISIBLE with crew character cards
- Map: deployment zones HIGHLIGHTED (brighter overlays)
- Right panel: Setup tab
- Bottom: "Deploy Your Crew", "Confirm Deployment"

### Physical Tabletop
1. Place crew miniatures in crew zone (rows A-B, ~6" from edge, p.36-37)
2. Place enemy miniatures in enemy zone (rows C-D)

### QA Checks
- [ ] Left panel visible with crew cards
- [ ] Deployment zones highlighted (2.5x alpha boost)
- [ ] "Confirm Deployment" button visible
- [ ] Quick dice bar still visible

### Code: `TacticalBattleUI.gd:265-281`, `BattlefieldMapView.gd:391-414`

---

## STAGE 4: COMBAT — Five Phase Battle Round

### Phase 4A: REACTION ROLL (Core Rules p.38)

**Phase reminder**: "Roll 1D6 per crew member. Results <= Reactions = Quick Actions."

**Physical tabletop**: Roll 1D6 per crew. Compare to Reactions stat. Mark Quick or Slow.

**QA Checks**:
- [ ] "Roll Reactions" button visible
- [ ] Each crew gets roll logged: "[Name]: Rolled X vs Reactions Y — QUICK/SLOW"
- [ ] Phase breadcrumb: "Reaction Roll" = BLUE, others = GRAY
- [ ] Right panel auto-switched to Tools tab
- [ ] Phase auto-advances after button press

**Code**: `TacticalBattleUI.gd:1029-1014`, `BattleRoundHUD.gd:352`

### Phase 4B: QUICK ACTIONS (Core Rules p.38-39)

**Phase reminder**: "Crew who passed reactions act now. Move+Shoot OR Double Move each."

**Physical tabletop**: Each Quick crew: Move (half Speed") + Shoot, OR Dash (full Speed", no shoot). Roll hits, resolve damage.

**QA Checks**:
- [ ] Breadcrumb: Reaction Roll=GREEN, Quick Actions=BLUE
- [ ] "All Quick Actions Done" button visible
- [ ] Dice tools in Tools tab accessible
- [ ] Quick dice bar works

**Code**: `TacticalBattleUI.gd:1038-1048`, `BattleRoundHUD.gd:353`

### Phase 4C: ENEMY ACTIONS (Core Rules p.38)

**Phase reminder**: "All enemies act. Move toward closest crew, shoot if in range."

**Physical tabletop**: Each enemy moves toward closest crew, shoots if in range/LOS.

**QA Checks**:
- [ ] Breadcrumb: first 2 GREEN, Enemy Actions BLUE
- [ ] Log: red text enemy instruction
- [ ] FULL_ORACLE: EnemyIntentPanel visible, right panel → Reference tab
- [ ] Other tiers: right panel stays on Tools
- [ ] "Enemy Actions Done" button visible

**Code**: `TacticalBattleUI.gd:1050-1064`, `BattleRoundHUD.gd:354`

### Phase 4D: SLOW ACTIONS (Core Rules p.38-39)

**Phase reminder**: "Remaining crew act now. Same options as Quick Actions."

**Physical tabletop**: Failed-reaction crew act (same as Quick Actions).

**QA Checks**:
- [ ] Breadcrumb: first 3 GREEN, Slow Actions BLUE
- [ ] "All Slow Actions Done" button visible

**Code**: `TacticalBattleUI.gd:1066-1078`, `BattleRoundHUD.gd:355`

### Phase 4E: END PHASE (Core Rules p.114-118)

**Phase reminder**: "Morale check (if 3+ enemies down). Battle events (R2, R4). Victory check."

**Physical tabletop**:
1. Morale: 2D6 vs Morale if first casualty this round. Failed = 1D3 flee.
2. Battle events: D100 on rounds 2 & 4 (p.116-118)
3. Escalation (after round 4): D6 — 1-2 end, 6 escalate
4. Victory check

**QA Checks**:
- [ ] Breadcrumb: all 4 prior GREEN, End Phase BLUE
- [ ] "End Round / Morale Check" button visible
- [ ] Auto-prompt shows morale info if casualties (tier 1+)
- [ ] Battle event indicator on rounds 2 and 4
- [ ] Clicking button → next round (Reaction Roll again)

**Code**: `TacticalBattleUI.gd:976-978, 1078-1092`, `BattleRoundHUD.gd:356, 390-414`

---

## STAGE 5: RESOLUTION

### What User Sees
- PhaseContentPanel with battle results
- Battle journal: victory/defeat + casualty summary
- "Return to Campaign" button in top bar
- Left/right panels hidden

### Physical Tabletop
1. Record result. Crew casualties: D6 — ≤2 dead, >2 injured (p.44)
2. Loot if held field (3+ enemies killed). Pack up.

### QA Checks
- [ ] Battle result logged
- [ ] Injury rolls shown
- [ ] "Return to Campaign" button visible
- [ ] Right/left panels hidden

### Code: `TacticalBattleUI.gd:299-309, 1337-1358`

---

## NEW UX FEATURES

### Quick Dice Bar
- [ ] Always visible below right panel tabs (outside TabContainer)
- [ ] 1d6: shows "1d6: [N]"
- [ ] 2d6: shows "2d6: [N] (X+Y)"
- [ ] d100: shows "d100: [N]"
- [ ] Result logged to battle journal
- [ ] Survives tab switching

### Colored Phase Breadcrumb
- [ ] Completed = GREEN background
- [ ] Active = BLUE with cyan border
- [ ] Upcoming = GRAY
- [ ] Updates on each phase transition
- [ ] New round resets correctly

### Graph-Paper Map
- [ ] Near-white background
- [ ] Thin + bold grid lines
- [ ] ScalableVectorShape2D terrain (anti-aliased)
- [ ] Notable terrain: gold outline + label
- [ ] Auto-scales to fill container
- [ ] Centered in space
- [ ] Zoom (mouse wheel 0.5x-3.0x)
- [ ] Pan (middle-click drag)
- [ ] Click sector → popover with details

### Auto Tab Switching
- [ ] SETUP → Setup tab
- [ ] DEPLOYMENT → Setup tab
- [ ] Reaction Roll → Tools tab
- [ ] Enemy Actions (FULL_ORACLE) → Reference tab
- [ ] Enemy Actions (other) → Tools tab

### Bottom Bar
- [ ] Height 110px (not 80px)
- [ ] Phase buttons not clipped
- [ ] ROUND label + phase buttons + Next Phase all visible

### Keyword Tooltips
- [ ] Battle journal keywords wrapped with [hint] BBCode
- [ ] Hover shows definition + page ref (e.g., "Roll 1d6 per crew... (p.38)")
- [ ] ~35 keywords from BattleKeywordDB

---

## Combat Quick Reference

| Mechanic | Rule | Dice | Threshold |
|----------|------|------|-----------|
| Reaction Roll | p.38 | 1d6/crew | ≤ Reactions = Quick |
| Move + Shoot | p.39 | — | Combat Speed = half Speed |
| Dash | p.39 | — | Full Speed, no shooting |
| Hit Roll | p.40 | 1d6+mods | ≥ target number |
| Damage | p.43 | weapon die | ≥ Toughness = casualty |
| Brawl | p.42 | 1d6+Combat | Higher wins |
| Morale | p.114 | 2d6 vs Morale | Failed = 1d3 flee |
| Battle Event | p.116 | d100 | Rounds 2 & 4 |
| Escalation | p.118 | 1d6 | After R4: 1-2 end, 6 escalate |
| Initiative | p.38 | 2d6+Savvy | ≥ 10 seize |
