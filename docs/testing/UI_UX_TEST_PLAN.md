# Five Parsecs Campaign Manager — UI/UX Testing Plan

**Created**: 2026-03-07
**Verified Against**: Actual codebase (not documentation assumptions)
**Total Estimated Time**: ~4.5 hours across 8 sessions
**Priority Scale**: P0 = Blocks users, P1 = Degrades experience, P2 = Edge case/polish

---

## Testing Philosophy

### Two User Personas

Every test should be evaluated from **both** perspectives:

| Persona | Description | What They Expect |
|---------|-------------|-----------------|
| **Rulebook Replacer** | Uses the app as their ONLY reference. Has never read the physical book. | Every game term explained. Clear instructions at every step. Tooltips on keywords. Rules embedded in context. No "see p.44" without also showing the rule. |
| **Rulebook Companion** | Has the book open beside the device. Uses app for tracking/management. | Fast access to tracking tools. Minimal reading required. Page references helpful. Quick dice rolling. Don't slow them down with tutorials they don't need. |

### Physical Setup Context

The app is used on a **portable device (tablet/phone) placed next to a physical tabletop** with miniatures, dice, terrain, and a tape measure. Testing must account for:

- **Portrait mode**: Device propped up like a book next to the table — one-handed taps between moving minis
- **Landscape mode**: Device laid flat or in a stand — two-handed use during planning phases
- **Glanceable UI**: Player looks at device briefly, then back at the table. Key info must be instantly visible
- **Fat finger tolerance**: Player's hands may be holding miniatures, dice, or a ruler. Touch targets must be generous
- **Session interruption**: Games can pause mid-battle. State must survive app backgrounding/resuming

---

## Known Limitations (Verified 2026-03-07)

| Feature | Status | MainMenu Behavior |
|---------|--------|-------------------|
| Bug Hunt | Code exists, not routed via SceneRouter | "Coming soon" stub |
| Battle Simulator | Not implemented | "Coming soon" stub |
| Co-op Campaign | Not implemented | "Coming soon" stub |

SceneRouter has **no** `bug_hunt_*` keys. TacticalBattleUI has **no** `battle_mode` property. GameState has **no** `_detect_campaign_type()` method. These were documentation errors.

---

## SESSION 0: Smoke Tests (15 minutes)

**Goal**: Does the app launch and can you navigate the main paths?

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| S-001 | Launch game, wait for MainMenu | MainMenu renders with all buttons | P0 |
| S-002 | Inspect button labels | "New Campaign", "Load Campaign", "Continue Campaign", "Options", "Library" present. "Bug Hunt", "Battle Simulator", "Co-op" present but stub | P0 |
| S-003 | Click "New Campaign" | CampaignCreationUI loads, Step 1 visible | P0 |
| S-004 | Click Back from Campaign Creation | Returns to MainMenu without errors | P0 |
| S-005 | Click "Options" | SettingsScreen loads | P1 |
| S-006 | Check console after launch | No ERROR-level messages | P0 |
| S-007 | Click "Bug Hunt" | Shows "coming soon" — NOT a crash | P1 |
| S-008 | Click "Battle Simulator" | Shows "coming soon" — NOT a crash | P1 |
| S-009 | **Portrait**: Rotate device to portrait | MainMenu buttons readable, not clipped, all tappable | P0 |
| S-010 | **Landscape**: Rotate device to landscape | Layout adapts, no overlap or overflow | P0 |

**Pass criteria**: All P0 pass. If any fail, stop and fix.

---

## SESSION 1: Campaign Creation — Happy Path (45 minutes)

**Goal**: Walk through all 7 phases with valid inputs. Evaluate from both personas.

### Phase 1: CONFIG (ExpandedConfigPanel)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-001 | Navigate to New Campaign | Name field, type/difficulty/victory dropdowns visible. Step indicator shows "Step 1 of 7" | P0 |
| CC-002 | Type "Test Campaign Alpha" | Text appears, no errors | P0 |
| CC-003 | Select each campaign type | Selection persists, UI updates | P0 |
| CC-004 | Select each difficulty level | Selection persists | P1 |
| CC-005 | Select victory conditions | Selection persists, description updates | P1 |
| CC-006 | **Replacer**: Are victory conditions explained? | Each option has clear description. Player who hasn't read the book understands what "20 Turn Victory" means | P1 |
| CC-007 | **Companion**: Can I blast through config quickly? | Default values sensible, minimal clicks to proceed | P1 |
| CC-008 | Check DLC-gated options | DLC options only show when DLCManager has them enabled | P1 |
| CC-009 | Click Next | Transitions to CAPTAIN_CREATION | P0 |
| CC-010 | **UX audit**: Is "Next" button clearly the primary action? | Visually distinct from other controls, bottom-right or prominent position | P1 |

### Phase 2: CAPTAIN_CREATION (CaptainPanel + CharacterCreator)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-020 | Arrive at Phase 2 | CharacterCreator visible with name field, stat displays | P0 |
| CC-021 | Type "Captain Rex" | Name accepted, displayed in preview | P0 |
| CC-022 | Generate/randomize stats | Stats populate: combat, reaction, toughness, speed, savvy, luck (flat properties) | P0 |
| CC-023 | Select a character class | Class applies, stat modifiers reflected | P1 |
| CC-024 | **Replacer**: Are stats explained? | Each stat (combat, reaction, etc.) has tooltip or description. New player knows what "Savvy 3" means | P1 |
| CC-025 | **Portrait**: Stat display readable? | All 6 stats visible without scrolling in portrait. Touch targets adequate | P1 |
| CC-026 | Click Next | Transitions to CREW_SETUP, captain data preserved | P0 |

### Phase 3: CREW_SETUP (CrewPanel)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-030 | Arrive at Phase 3 | Captain in crew list, slots for additional members | P0 |
| CC-031 | Add crew member | New member appears in list | P0 |
| CC-032 | Add to 4 total | 4 members shown, Next enabled | P0 |
| CC-033 | Add to max (6) | Add button disabled/hidden at cap | P1 |
| CC-034 | Remove a non-captain member | Removed, count decremented | P1 |
| CC-035 | Try to proceed with only captain | Should block or warn about minimum crew | P0 |
| CC-036 | Add two members with same name | Prevented or assigned unique IDs | P1 |
| CC-037 | **UX audit**: Crew count visible? | Clear "3/6 crew members" indicator, not just a count buried in text | P1 |
| CC-038 | **Portrait**: Crew list scrollable? | With 6 members, list scrolls properly in portrait mode | P1 |

### Phase 4: EQUIPMENT_GENERATION (EquipmentPanel)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-040 | Arrive at Phase 4 | Starting equipment auto-generated per crew member | P0 |
| CC-041 | Inspect equipment display | Each item shows name, type, stats. Key is `equipment_data["equipment"]` | P0 |
| CC-042 | Assign/unassign items | Items move between stash and crew | P1 |
| CC-043 | **Replacer**: Are weapon stats explained? | Weapon keywords (Assault, Heavy, Pistol) have tooltips or inline explanation | P1 |
| CC-044 | **UX audit**: Equipment overflow | Large equipment list has scrollbar, not clipped | P1 |

### Phase 5: SHIP_ASSIGNMENT (ShipPanel)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-050 | Arrive at Phase 5 | Ship options displayed | P0 |
| CC-051 | Select a ship | Ship selected, details shown | P0 |
| CC-052 | Modify ship name/properties | Changes persist | P1 |

### Phase 6: WORLD_GENERATION (WorldInfoPanel)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-060 | Arrive at Phase 6 | Generated world with traits | P0 |
| CC-061 | Inspect world details | Planet name, type, traits visible and formatted | P1 |
| CC-062 | Navigate away and back to Phase 6 | Data refreshes correctly (gotcha: stale `_ready()` data) | P1 |
| CC-063 | **Replacer**: World traits explained? | Player understands what each trait means for gameplay | P1 |

### Phase 7: FINAL_REVIEW (FinalPanel)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CC-070 | Arrive at Phase 7 | All data summarized: name, captain, crew, equipment, ship, world | P0 |
| CC-071 | Click Create/Confirm | Campaign saved, transitions to CampaignDashboard | P0 |
| CC-072 | Go back to Phase 3, forward to Phase 7 | All data intact | P0 |
| CC-073 | Console check after creation | No errors during entire flow | P0 |
| CC-074 | **UX audit**: Is final review scannable? | Information grouped logically, not a wall of text | P1 |

---

## SESSION 2: Campaign Creation — Edge Cases (30 minutes)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| CE-001 | Leave name blank, try to proceed | Validation error with clear message | P0 |
| CE-002 | Enter 200+ character name | Truncated or validated | P1 |
| CE-003 | Name with quotes, angle brackets, unicode | No crash or injection | P1 |
| CE-004 | Click Next rapidly | No phase skipping or double-submission | P1 |
| CE-005 | Start creation, reach Phase 4, cancel | Return to MainMenu, no orphaned data | P0 |
| CE-006 | Add crew member with blank name | Validated or default assigned | P1 |
| CE-007 | Add 5 crew, remove middle one | Remaining indices correct, no orphaned refs | P0 |
| CE-008 | Check all starting resource values | All >= 0 | P0 |
| CE-009 | Monitor console during phase transitions | No orphaned signal warnings | P1 |
| CE-010 | Complete creation, reload, verify nested data | Equipment lists, crew stats survive save/load | P0 |
| CE-011 | **UX audit**: When validation blocks "Next", is reason shown? | Not just a disabled button — explain WHY (e.g., "Enter a campaign name") | P0 |

---

## SESSION 3: Save/Load System (30 minutes)

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| SL-001 | Create campaign, reach dashboard, save | Save completes, file created | P0 |
| SL-002 | Return to MainMenu, Load, select save | Campaign loads, dashboard shows correct data | P0 |
| SL-003 | Check crew count and names after load | Match creation | P0 |
| SL-004 | Check equipment after load | Matches. Uses `equipment_data["equipment"]` | P0 |
| SL-005 | Check ship after load | Name and properties match | P1 |
| SL-006 | Save twice with different names | Both appear in load list | P1 |
| SL-007 | Save, load, check numeric values | Integer stats stay integers (not floats) | P0 |
| SL-008 | Inspect save JSON for dual keys | Both `"id"`/`"name"` AND `"character_id"`/`"character_name"` present | P1 |
| SL-009 | Load corrupted/missing save | Graceful error, not crash | P1 |
| SL-010 | **UX audit**: Save/Load screen clarity | Clear file names, timestamps, campaign summaries. Player knows which save is which | P1 |
| SL-011 | **Session resume**: Background app during campaign, return | State intact, no crash on resume | P0 |

---

## SESSION 4: Campaign Dashboard + Turn Phases (60 minutes)

**Goal**: Walk through all 9 turn phases. Evaluate dashboard as the "home base" a player returns to between phases.

### Dashboard Evaluation

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| TD-001 | Complete creation, land on dashboard | Phase indicator, crew summary, resources all visible | P0 |
| TD-002 | Check phase shows STORY | First phase correct | P0 |
| TD-003 | Check resources display | Credits, supplies, reputation formatted and visible | P0 |
| TD-004 | Check crew section | All members listed with correct stats | P0 |
| TD-005 | **UX audit**: Information hierarchy | Can you tell at a glance: (1) what phase you're in, (2) crew health status, (3) resource levels? Or is it all equally weighted? | P0 |
| TD-006 | **UX audit**: "What do I do next?" | Is it obvious what the player should click? Primary action (Next Phase) clearly distinguished from Save/Load/Export? | P0 |
| TD-007 | **UX audit**: Button bar at bottom | 6 buttons [Next Phase, Manage Crew, Save, Export, Load, Quit] — are they logically ordered? Is Export confusable with Next Phase? | P1 |
| TD-008 | **Portrait**: Dashboard readable? | Key info visible without scrolling. Buttons large enough to tap | P1 |
| TD-009 | **Landscape**: Dashboard uses space well? | 3-column layout not wasted on wide screen | P1 |
| TD-010 | **UX audit**: Where am I? | Does dashboard show "Campaign: Test Alpha — Turn 1 — Story Phase"? Or just "Phase: Story"? | P1 |

### Phase-by-Phase Walkthrough

| ID | Phase | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| TP-001 | STORY | Events generate, choices available, phase_completed fires | **Replacer**: Are story events self-explanatory? **Companion**: Can I skip/resolve quickly? | P0 |
| TP-002 | TRAVEL | Travel options display, world selection | **Replacer**: Is it clear where I can go and why? | P0 |
| TP-003 | UPKEEP | Costs calculated, resources deducted | Both personas: Is the cost breakdown clear before committing? | P0 |
| TP-004 | UPKEEP with 0 credits | Warns or handles gracefully | **UX**: Disabled "Pay Upkeep" button — does it explain WHY? (known gap: no error message) | P0 |
| TP-005 | UPKEEP when credits low | Resources don't go below 0 | | P0 |
| TP-006 | MISSION | Mission selection works, PreBattleUI available | **Replacer**: Mission objective clearly stated? | P0 |
| TP-007 | POST_MISSION | Injuries, loot, XP displayed | **Replacer**: Are injury results explained? Or just "Serious Injury" with no context? | P0 |
| TP-008 | ADVANCEMENT | Advancement options, stat increases work | **Replacer**: What does each advancement do? Are costs shown? | P1 |
| TP-009 | TRADING | Market items, buy/sell. `get_sell_value()` condition-aware | **Companion**: Is trading fast? **Replacer**: Are item stats shown before purchase? | P1 |
| TP-010 | CHARACTER | Character events, character_events.gd loads | | P1 |
| TP-011 | RETIREMENT | VictoryChecker (18 types), retirement options | **Replacer**: Victory conditions explained in context? | P1 |
| TP-012 | Full turn complete | Turn counter increments, returns to STORY | | P0 |
| TP-013 | **UX audit**: Phase transition consistency | Does every phase use the same button label pattern? ("Continue" vs "Resolve" vs "Pay Upkeep" vs "Complete Phase"?) | P1 |
| TP-014 | **UX audit**: Back navigation from phases | Can you go back from any phase? Is there always a visible back button? (known gap: some phases lack back buttons) | P1 |
| TP-015 | Console check throughout | No "already connected" or signal warnings | P1 |
| TP-016 | TurnPhaseChecklist state | Each phase marked complete before allowing next | P1 |

---

## SESSION 5: Battle System — Tabletop Companion Deep Dive (60 minutes)

**Goal**: Test the battle system as it's actually used — device next to a physical table with miniatures.

### Setup: Physical Simulation

Before starting, imagine (or actually set up):
- A few miniatures on a table as "crew"
- Some objects as terrain
- Dice nearby
- Device propped up in portrait, then try landscape

### Pre-Battle

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-001 | Enter pre-battle from Mission phase | PreBattleUI via `setup_preview()` | | P0 |
| BT-002 | Check mission info panel (left) | Mission title, description, battle type, deployment effects | **Replacer**: Is deployment condition explained? (e.g., "Ambush: +2 to hit" — what does that mean in play?) | P0 |
| BT-003 | Check terrain preview (center) | Sector grid or text with terrain setup guide | **Both**: Can I set up my physical table from these instructions? Are sectors labeled clearly (A1-D4)? | P0 |
| BT-004 | Select crew for battle via `setup_crew_selection()` | Toggle crew members, minimum enforced | **Portrait**: Toggle buttons large enough to tap? | P0 |
| BT-005 | Confirm and choose tracking tier | Tier selection: LOG_ONLY / ASSISTED / FULL_ORACLE | **Replacer**: Are tiers explained? Does player understand the tradeoff? | P1 |
| BT-006 | **Replacer**: Terrain setup instructions sufficient? | Player can physically arrange terrain on table from app instructions alone | P1 |
| BT-007 | **Companion**: Can I skip terrain and just pick crew fast? | Minimal friction to get to the fight | P1 |

### Deployment Phase

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-010 | View deployment zones | Crew zones (top 2 rows) and enemy zones (bottom 2 rows) shown on 4x4 grid | | P0 |
| BT-011 | Place units or Auto Deploy | "Place Unit" and "Auto Deploy" buttons work | **Portrait**: Grid cells tappable at portrait width? | P0 |
| BT-012 | View Setup tab | Terrain theme, all 16 sectors, notable features | **Replacer**: Do I know where to put terrain pieces on my table? | P1 |
| BT-013 | Regenerate terrain | "Regenerate Terrain Layout" re-rolls features | | P2 |
| BT-014 | Confirm deployment | Transitions to combat phase | | P0 |

### Combat — Round-by-Round Play (The Core Experience)

**This is where the app earns its keep.** The player is moving miniatures, rolling dice, and glancing at the device.

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-020 | Round 1 begins | Turn indicator: "Combat Round 1" | **Glanceability**: Is the round number large and prominent? | P0 |
| BT-021 | Initiative roll | App shows initiative result, who goes first | **Replacer**: Does it explain "2d6 + highest Savvy"? **Companion**: Just show me the result fast | P0 |
| BT-022 | Crew member's turn | Available actions shown: Move, Shoot, Brawl, Aim, Dash | **Replacer**: Each action explained? **Portrait**: Action buttons tappable? | P0 |
| BT-023 | Execute a Shoot action | Hit/miss calculated, damage shown in battle log | **Both**: Result clearly color-coded? (hits green, misses grey, casualties red) | P0 |
| BT-024 | Execute a Brawl action | Close combat resolved | **Replacer**: Brawl rules shown or just the result? | P1 |
| BT-025 | Enemy turn (automated) | Enemy actions logged, results shown | **Glanceability**: Can I see "Bandit 1 shoots at Rex — HIT, 2 damage" at a glance? | P0 |
| BT-026 | Casualty occurs | Red text in log, character status updates | **Both**: Is it immediately clear WHO went down? | P0 |
| BT-027 | Check Activation Tracker (ASSISTED) | Per-unit checkboxes showing who's acted | **Companion**: Quick visual of "who's left to act this round" | P1 |
| BT-028 | End Turn button | Advances to next unit/round | **Portrait**: Button reachable with thumb? | P0 |
| BT-029 | Round 2+ | New round marker in log, activation resets | | P0 |
| BT-030 | Morale check triggered (casualty threshold) | Morale tracker shows roll and result | **Replacer**: Does it explain what ROUT vs FALL_BACK means for physical miniatures? ("Remove fleeing enemies from the table") | P1 |

### Battle Tools — Right Sidebar

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-040 | Dice Dashboard | Visual dice display with color-coded values | **Both**: Can I quickly roll dice digitally when physical dice unavailable? | P1 |
| BT-041 | Combat Calculator | Input modifiers, get hit result | **Companion**: Fast modifier entry for complex shots | P1 |
| BT-042 | Cheat Sheet (Reference tab) | Turn sequence, hit rules, damage, morale, status effects, weapons — all with page refs | **Replacer**: Is this enough to play without the book? **Companion**: Page refs accurate? | P0 |
| BT-043 | Weapon Table (Reference tab) | All weapons with Range, Damage, ROF, Special | **Both**: Can I look up a weapon mid-combat without leaving the battle screen? | P1 |
| BT-044 | **Portrait**: Can I access Tools/Reference tabs? | Tabs navigable, content readable at narrow width | P1 |
| BT-045 | **Landscape**: Three-panel layout usable? | Left sidebar + center + right sidebar all visible simultaneously | P1 |

### Battle Log — The Player's Memory

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-050 | Scroll battle log after several rounds | Color-coded entries: round markers (white), crew casualties (red), enemy casualties (orange), events (gold), morale (red), initiative (cyan) | **Both**: Can I reconstruct what happened by reading the log? | P0 |
| BT-051 | Log entries timestamped | Each entry has time or round marker | | P1 |
| BT-052 | **UX audit**: Log readability | Font size adequate? Contrast sufficient on dark background? Line spacing comfortable? | P1 |

### Auto-Resolve (Quick Battle)

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-060 | Click "Auto Resolve" | Battle resolves 3-6 rounds, summary shown | **Companion**: When I want a fast result, does this give me enough detail? | P0 |
| BT-061 | Auto-resolve summary includes | Rounds fought, enemies defeated, crew casualties, held field, loot eligibility | | P0 |
| BT-062 | Auto-resolve uses real combat math | Results from `BattleResolver.resolve_battle()` consistent with manual play | P1 |

### Battle End and Post-Battle

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| BT-070 | Battle ends (victory or defeat) | Clear WIN/LOSS indicator, transition to post-battle | | P0 |
| BT-071 | Injury table | Each casualty gets D100 roll, results shown | **Replacer**: Are injury results explained? "Serious Injury" — what does that MEAN for my character? Recovery time? Stat loss? | P0 |
| BT-072 | XP awards | XP per character based on performance | **Both**: Clear breakdown of why each character earned X XP | P1 |
| BT-073 | Loot generation | Battlefield finds + per-enemy loot | **Replacer**: What did I find? What does this item do? | P1 |
| BT-074 | Return to campaign | Transitions to POST_MISSION phase | | P0 |
| BT-075 | **UX audit**: Post-battle summary scannable? | Victory/defeat, casualties, loot all in a single summary view — not spread across multiple screens | P1 |

---

## SESSION 6: UI/UX Quality Audit (45 minutes)

**Goal**: Systematically check for inconsistencies, confusing patterns, and unmet modern app expectations.

### Navigation & Wayfinding

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| UX-001 | Location awareness | Every screen shows where you are: "Campaign > Turn 3 > Upkeep Phase". NOT just "Phase: Upkeep" | P0 |
| UX-002 | Back button consistency | Every screen (except MainMenu) has a visible back button in a consistent position | P0 |
| UX-003 | Navigation history | Player never feels "trapped" — can always get back to dashboard or main menu | P0 |
| UX-004 | Phase progression clarity | Player always knows: what phase they're in, what phase is next, how many phases remain this turn | P1 |
| UX-005 | **Dead ends**: Navigate to every reachable screen | No screen lacks a way to leave (no missing back/home buttons) | P0 |

### Button & Label Consistency

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| UX-010 | Primary action labels | Phase completion buttons use consistent terminology across all 9 phases ("Continue" vs "Resolve" vs "Pay Upkeep" — should be uniform) | P1 |
| UX-011 | Primary action placement | Primary button always in same position (bottom-right or bottom-center) | P1 |
| UX-012 | Primary vs secondary distinction | "Next Phase" clearly different from "Save"/"Export"/"Load". Not all same visual weight | P1 |
| UX-013 | Dashboard button order | [Next Phase, Manage Crew, Save, Export, Load, Quit] — is Export confusable with Next Phase? Should Save be second? | P1 |
| UX-014 | Disabled button explanation | EVERY disabled button has a visible reason why. Not just greyed out with no text | P0 |

### Text & Number Formatting

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| UX-020 | Credit display format | Consistent across all screens: "Credits: 5,000" or "5,000 credits" — not both | P1 |
| UX-021 | Stat display format | Character stats formatted identically everywhere (dashboard, creation, details, battle) | P1 |
| UX-022 | Header capitalization | All section headers use same case convention (Title Case or Sentence case, not mixed) | P2 |
| UX-023 | Status indicators | Consistent format: all use icons, or all use text, or all use color — not a mix | P1 |
| UX-024 | BBCode/RichText rendering | No visible BBCode tags in any user-facing text (no raw `[b]` or `[color=]` showing) | P0 |

### Empty States & Error Handling

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| UX-030 | Empty crew list | Shows helpful message + CTA, not a blank area | P1 |
| UX-031 | Empty equipment stash | Shows "No equipment" message, not blank | P1 |
| UX-032 | No available missions | Handled gracefully with explanation | P1 |
| UX-033 | No story events | Handled, not a blank panel | P1 |
| UX-034 | Validation failures | Every validation shows a user-visible error message, not just a disabled button | P0 |
| UX-035 | Loading states | Any operation that takes >500ms shows a loading indicator | P2 |

### Help & Tooltips

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| UX-040 | Game term tooltips | Tapping/hovering game keywords (Assault, Heavy, Brawling, Stunned, etc.) shows definition | P1 |
| UX-041 | KeywordDB integration | `KeywordDB.parse_text_for_keywords()` actually wired to UI RichTextLabels (known gap: it's NOT currently wired) | P1 |
| UX-042 | Stat explanations | First-time player can understand what "Savvy 3" or "Reaction 2" means | P1 |
| UX-043 | Help screen accessible | Help/Library reachable from campaign screens, not just MainMenu | P2 |
| UX-044 | Battle cheat sheet completeness | Turn sequence, hit rules, damage, armor, morale, status effects, weapons — all present with enough detail to play without the book | P1 |

### Responsive Layout

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| UX-050 | Portrait mode — all screens | Every screen usable in portrait. No text clipped, no buttons off-screen | P0 |
| UX-051 | Landscape mode — all screens | Layout adapts to use horizontal space. No wasted empty columns | P1 |
| UX-052 | Touch targets | All interactive elements >= 48px height (TOUCH_TARGET_MIN). Mobile: 56px (TOUCH_TARGET_COMFORT) | P1 |
| UX-053 | Font readability | Text readable at arm's length (device propped next to tabletop) | P1 |
| UX-054 | Scroll behavior | Vertical scroll works on all content panels. No horizontal scroll needed | P1 |
| UX-055 | Battle UI in portrait | Three-panel battle layout degrades to single-column tabs in portrait? Or does it clip? | P0 |
| UX-056 | Orientation switch mid-battle | Rotate device during combat — no data loss, layout adapts | P1 |

---

## SESSION 7: Character, Equipment, and Settings (30 minutes)

### Character Management

| ID | Steps | Expected | Persona Notes | Pri |
|----|-------|----------|---------------|-----|
| CM-001 | Click crew member from dashboard | Details: combat, reaction, toughness, speed, savvy, luck | | P0 |
| CM-002 | Check advancement/XP display | XP and level shown | **Replacer**: Is advancement path clear? What do I need to level up? | P1 |
| CM-003 | Try adding implant | Max 3 enforced, 6 types, LOOT_TO_IMPLANT_MAP | | P2 |
| CM-004 | Check class display | Uses FiveParsecsGameEnums.CharacterClass | | P1 |
| CM-005 | **UX audit**: Character card layout | Stats, equipment, status, XP — logically grouped? Scannable at a glance? | P1 |

### Equipment Management

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| EQ-001 | Open equipment from dashboard | All items listed | P0 |
| EQ-002 | Move item between stash and character | Transfers correctly | P1 |
| EQ-003 | Check sell value | `get_sell_value()` condition-aware | P1 |
| EQ-004 | Verify equipment key | Uses `equipment_data["equipment"]`, NOT `"pool"` | P0 |
| EQ-005 | **Replacer**: Item stats explained? | Weapon range, damage, special rules shown with definitions | P1 |

### Settings

| ID | Steps | Expected | Pri |
|----|-------|----------|-----|
| ST-001 | Open Options from MainMenu | All settings visible | P1 |
| ST-002 | Change setting, exit, return | Setting persists | P1 |
| ST-003 | Accessibility options | Font scaling, reduced animation, high contrast, colorblind modes available | P1 |
| ST-004 | **Portrait/Landscape**: Settings usable in both | | P1 |

---

## SESSION 8: Regression Sweep (20 minutes)

| ID | Check | Expected | Pri |
|----|-------|----------|-----|
| RG-001 | Transactions with 0 credits | All purchases blocked | P0 |
| RG-002 | Resources after every transaction | Never negative | P0 |
| RG-003 | 2+ full campaign turns, check console | No accumulating signal warnings | P1 |
| RG-004 | Phase transitions for signal leaks | No "already connected" errors | P1 |
| RG-005 | Save after 2 turns, reload nested data | Equipment, crew, world all intact | P0 |
| RG-006 | Numeric stats after save/load | Integers stay integers | P0 |
| RG-007 | Scale/rotation animations | No glitches from missing pivot_offset | P2 |
| RG-008 | Navigate between animated screens | No persistent looping animations | P2 |
| RG-009 | World phase re-entry | Data refreshes on re-entry | P1 |
| RG-010 | App background/resume mid-campaign | State survives, no crash | P1 |

---

## Recommended Execution Order

| # | Session | Time | Focus |
|---|---------|------|-------|
| 1 | Session 0: Smoke Tests | 15 min | Launch, nav, orientation — stop if P0 fails |
| 2 | Session 1: Creation Happy Path | 45 min | All 7 phases, both personas |
| 3 | Session 3: Save/Load | 30 min | Persist the campaign just created |
| 4 | Session 4: Dashboard + Turn Phases | 60 min | All 9 phases, dashboard UX |
| 5 | Session 5: Battle Companion | 60 min | The core experience — device next to table |
| 6 | Session 6: UX Quality Audit | 45 min | Consistency, navigation, empty states |
| 7 | Session 2: Creation Edge Cases | 30 min | Validation, error handling |
| 8 | Sessions 7+8: Character/Regression | 30 min | Deep dive + final sweep |
| **Total** | | **~4.5 hours** | |

---

## Bug Report Template

For each failure:

```
Test ID:      [e.g., BT-023]
Severity:     [Blocker / Major / Minor / Cosmetic]
Persona:      [Replacer / Companion / Both]
Orientation:  [Portrait / Landscape / Both]
Screenshot:   [filename]
Console:      [relevant error lines]
Steps:        [numbered reproduction steps]
Expected:     [what should happen]
Actual:       [what actually happened]
```

---

## Features NOT Testable (Deferred)

| Feature | Reason |
|---------|--------|
| Bug Hunt gamemode | MainMenu stub; no SceneRouter keys |
| Battle Simulator | Stub |
| Co-op Campaign | Stub |
| Store/DLC purchases | Need platform adapters |
| ReviewManager timing | Needs real elapsed time |
| Mobile device testing | Needs physical device/emulator |
| Performance benchmarks | Separate session |

---

## Known UX Gaps (From Code Audit)

These were identified by reading the code. Items marked FIXED were resolved in the March 2026 UX sprint.

| # | Gap | Status | Notes |
|---|-----|--------|-------|
| 1 | No breadcrumb navigation | **FIXED** | `BasePhasePanel._setup_breadcrumb()` shows "Turn X > Phase Name" on all phase panels. Dashboard header shows "Turn X — Phase". |
| 2 | Back button missing on phase panels | **Non-issue** | Phase panels are forward-only by game rules (can't un-pay upkeep). `SceneRouter` has `navigation_history` + `navigate_back()` for scene-level navigation. CampaignCreation has its own back/forward via coordinator. Mobile OS back gestures (Android/iOS) need `NOTIFICATION_WM_GO_BACK` platform wiring — tracked as future work. |
| 3 | Phase button labels inconsistent | **FIXED** | Standardized: "Complete Advancement", "Complete Character Phase". Phase-specific verbs ("Pay Upkeep", "Resolve Event") intentionally kept where they improve clarity. |
| 4 | Dashboard button weight | **FIXED** | 3-column grid with logical grouping: Row 1 (Action, Save, Manage Crew), Row 2 (Load, Export, Quit). Primary action visually distinct. |
| 5 | Disabled buttons no error text | **FIXED** | `BasePhasePanel._setup_validation_hint()` + `_show_validation_hint()` — amber warning labels shown next to disabled buttons across 6 panels (Story, Upkeep, Mission, BattleSetup, End, Trade). |
| 6 | KeywordDB not wired | **FIXED** | `BasePhasePanel._set_keyword_text()` wraps text via `KeywordDB.parse_text_for_keywords()`, wires `meta_clicked` for tap-to-define popup. Applied to BattleSetup, Advancement, Trade, Story panels. |
| 7 | Empty states inconsistent | **FIXED** | Added to: Trade ("No items to sell"), BattleSetup ("All crew deployed" / "No crew members available" / "No equipment available"), End ("No campaign data available"). |
| 8 | Number formatting varies | **FIXED** | `BasePhasePanel._format_credits()` (thousands separator), `_format_credits_short()` ("X cr"), `_format_credits_long()` ("X credits") — applied across Trade, Upkeep, BattleResolution, End panels. |
| 9 | Header capitalization mixed | **Open (P2)** | Cosmetic — Title Case and sentence case used interchangeably across panels. Low priority. |
| 10 | Help screen only from MainMenu | **Open (P1)** | `SceneRouter` has "help" key. Could add help button to CampaignDashboard and/or BasePhasePanel. |

### Platform Back Navigation (Future Work)

Mobile OS back gestures need explicit wiring:
- **Android**: Override `_notification()` and handle `NOTIFICATION_WM_GO_BACK` → call `SceneRouter.navigate_back()`
- **iOS**: Swipe-from-edge gestures handled by OS; app must respond to the same `NOTIFICATION_WM_GO_BACK`
- **Desktop**: Escape key could map to back navigation (not yet wired)
- **Implementation location**: Best handled in a root-level script (MainMenu or a dedicated InputHandler autoload) rather than per-panel

---

## Future Automated Test Recommendations (Zero Coverage)

| Component | Tests Needed | Priority |
|-----------|-------------|----------|
| SceneRouter | 10-15 (all routes, back nav, error handling) | P0 |
| GameStateManager | 15-20 (all state mutations) | P0 |
| GameDataManager | 10-15 (loading, caching) | P0 |
| CharacterManager | 15 (CRUD, stats, validation) | P0 |
| SaveLoadUI | 10 (roundtrip, error handling) | P0 |
| CampaignCreationCoordinator | 15 (phase validation, data flow) | P1 |
| TurnPhaseChecklist | 10 (completion tracking) | P1 |
| VictoryChecker | 18 (one per victory type) | P1 |
| BattleStateMachine | 20 (transitions, all phases) | P1 |
