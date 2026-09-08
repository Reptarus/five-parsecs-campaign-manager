# QA Status Dashboard

---

### ✅ THE TACTICS TURN PASSED NO DATA — all six channels repaired (2026-09-07)

Found while deciding whether to wire or delete `TacticsOperationalMap.gd`, the project's
only `unwired_rules` file. The lint reported **one** unwired file; the real gap was the
whole turn.

**The transport was broken.** All three Tactics panels emitted
`phase_completed.emit(<phase>, {})`, and `TacticsTurnController._connect_signals()` wired
them with `func(_p, _d): phase_manager.complete_current_phase()` — **discarding even
that**. Every branch of the six `_apply_*` consumers in `TacticsPhaseManager` is keyed on
`data.has(...)`, so all of them were permanently false.

| Channel | Consumer | Was |
|---|---|---|
| `orders` / `intel` / `scenario` / `deployed_units` | `_apply_phase_results:197` | dead |
| `battle_result` | `_apply_battle_results:235` | **live** — the one working path |
| `casualties` | `_apply_battle_results:244` | dead |
| `story_event` | `_apply_post_battle_results:257` | dead |
| `skills_acquired` / `cp_spent` / `roster_changes` | `_apply_advancement_results:271` | dead |
| `operational_map_update` / `pbp_spent` | `_apply_strategic_results:302` | dead |
| `play_another` | `complete_current_phase:131` | dead — so `MAX_BATTLES_PER_TURN` was unreachable |

⭐ **Three rules gaps that wiring alone could not close**, now extracted from **Tactics
pp.95-99** (source text raw-2 offset, confirmed at raw PAGE 94 → printed 92):

* **Step 2, Player Battle Points (p.96)** had **no producer anywhere** —
  `player_battle_points` was only ever *decremented*, so the resource the whole
  operational layer spends could never be earned. The book's caps existed nowhere in the
  code: **1 PBP per victory, 0 for a draw, both sides cancel 1-for-1, max 2 gained per
  operational turn, max 3 held, excess discarded "without any effects"**.
* **Step 5, Commando Raids (p.99)** was implemented as "spend the points, deal exactly
  −1 Army Strength". The book requires **1D6 per point committed**: any **1-2** loses
  every point committed against that region, every **6** costs the target 1 Army
  Strength, "and this damage applies even if the committed PBP are lost". A guaranteed
  hit made raids strictly better than the printed rule.
* **Step 9 (p.99) was missing entirely.** ⚠ The book's *own* 8-step summary list on p.96
  omits it, and every step list in this project was built from that list — but the body
  carries **"Step 9: Adjust Cohesion scores"**, which is the campaign's END CONDITION.
  `is_player_victory()` / `is_player_defeat()` were correct and had **zero callers**, so a
  Tactics campaign could drive either side's Cohesion to 0 and nothing noticed.

🔧 **Four data defects in `data/tactics/tactics_campaign_config.json`**, none
previously visible because **no `.gd` file reads it**: its `_source` cited "pp.81-88,
155-168" (Scenario Types and the Lifeforms bestiary — the same 63-page miscite fixed in
three `.gd` files on 2026-09-04, missed here for want of a reader); step 1 claimed
"Fight 1-3 battles" (the code's own `MAX_BATTLES_PER_TURN` leaking into the data as a
rule — the book says "any number", one by default); step 6 said "between adjacent zones"
where the book says "connected through a series of friendly territories"; and step 9 was
absent. It is now the SSOT, read by `src/core/campaign/TacticsOperationalRules.gd`.

⚠ **Not a shipping defect.** `MainMenu.gd:14` sets `A1_BUILD := true` and the Tactics
button answers with a coming-soon note instead of navigating, so none of this is
reachable by an alpha tester. It is fixed because the record — `unwired_rules=1` on a
single file — understated it badly enough that the next reader would have mis-scoped it.

| Gate | Result |
|---|---|
| `tests/unit/test_tactics_operational_rules.gd` | **27 cases**, new — the book's tables, RNG-free where possible |
| `tests/unit/test_tactics_turn_payload.gd` | **13 cases**, new — asserts campaign STATE, never that a signal fired |
| All five Tactics suites | **63 cases, 0 failures** |
| Detection, one arm at a time | restore the three lambdas → the keystone case **FAILS**; restored → green |

---

### 🔧 CHECKLIST §3 — the desk half, measured (2026-09-07)

§3 of `docs/testing/TABLET_CHECKLIST_2026-08-02.md` is *"Physical legibility and thumb
reach — HIGH, subjective by nature"*, and its own preamble rules out signing it off from
screenshots: *"Measurement says ≥48dp; only a hand says whether it is comfortable."*
What CAN be settled at the desk, so the device pass is judgement rather than guesswork:

**Font rungs → design px** (`ResponsiveManager:257-269`, `maxi(9, round(base * mult))`):

| rung | MOBILE | TABLET | DESKTOP | WIDE | ULTRAWIDE |
|---|---|---|---|---|---|
| `FONT_SIZE_XS` (11) — §3 box 1 | **9** | 10 | 11 | 13 | 14 |
| checklist bullets (14) | 12 | 13 | 14 | 16 | 18 |
| checklist header (16) | 14 | 15 | 16 | 18 | 21 |

⚠ The XS rung hits the **9 px floor** at MOBILE — that is literally box 1's subject
("captions readable at arm's length"), and 9 px is the same band T10-02 recorded as
*"illegible at size"*.

**WCAG contrast of the Before You Deploy checklist** (`PreBattleUI._setup_scenario_rules`,
hardcoded hex with no token and no contrast check), against card `#111827`:

| element | ratio | verdict |
|---|---|---|
| header `#4FC3F7` (`:498`) | 8.85 | PASS AA |
| win line `#10B981` (`:505`) | 6.99 | PASS AA |
| **terrain rows `#808080` (`:514`)** | **4.49** | ⚠ **fails AA (4.5 needed)** |
| bullet rows (theme default `#f3f4f6`) | 16.12 | PASS AA |

⚠ **The row above was RIGHT about the measurement and WRONG about the scope, and the
correction is the finding.** It was first written as "the terrain rows miss AA by 0.01",
i.e. one screen's nit. It was never checked whether `#808080` was even the theme's
colour. **It is not.**

### ✅ THE SECONDARY-TEXT TOKEN — 67 drifted sites, all routed (2026-09-07)

The canonical token is `UIColors.COLOR_TEXT_SECONDARY` = **`#9ca3af`**, and it passes AA
comfortably. `#808080` was a **hardcoded drift** at **67 sites across 27 files**:

| background | `#808080` | `#9ca3af` |
|---|---|---|
| `#111827` UIColors card | **4.49** ⚠ fails AA | 6.99 passes |
| `#1A1A2E` a11y theme base | **4.32** ⚠ fails | 6.72 passes |
| `#252542` a11y theme elevated | **3.74** ⚠ fails | 5.82 passes |

⭐ **Two things hid it, and both are the shape this project keeps meeting.**

1. **`TerrainLegendStrip.gd:12` declared `const COLOR_TEXT_SECONDARY := Color("#808080")`**
   — the token's own NAME bound to a different value. Grepping the token returned two
   colours and neither looked wrong. `PreBattleUI.gd:822` went further and wrote
   `Color("#808080")  # COLOR_TEXT_SECONDARY`, a comment asserting a token it was not
   using.
2. **`AccessibilityThemes.gd` opens with *"Complies with WCAG 2.1 Level AA standards for
   visual accessibility"*** and then set `text_secondary` to the failing grey in all
   **three** colourblind palettes. It is live via `ThemeManager._apply_colorblind_variant()`
   and `AccessibilitySettingsPanel`, so that shipped. Same irony as T11-04, where the
   *accessibility* panel's 600 px floor was what broke the settings page on a phone.

⚠ **My own first census undercounted it 2.6x.** Grepping `"#808080"` (the quoted-literal
form) finds 25 sites and is structurally blind to `[color=#808080]` **embedded inside a
longer string literal**, which is where the other 42 lived. When a value can appear both
as a token and inside prose, grep BOTH shapes — and count occurrences, not lines: one
weapon-stat row in `CharacterDetailsScreen.gd:727` carries four on a single line.

**Fix**: `UIColors` gained `HEX_TEXT_{PRIMARY,SECONDARY,MUTED}` so BBCode consumers have a
token at all (a const expression cannot call `.to_html()`, which is why they had none and
reached for a literal). Guarded by `tests/unit/test_ui_color_tokens.gd` — **8 cases**,
which assert the INVARIANT (the token clears AA on the backgrounds in play) rather than
the constant, instrument their own premise first so nothing can pass vacuously, and are
detection-proven on two independent arms.

⚠ **A SECOND, larger gap is REPORTED and deliberately NOT changed.**
`COLOR_TEXT_MUTED` (`#6b7280`) measures **3.67** on the card — also below AA. WCAG exempts
"inactive user interface components" and `COLOR_TEXT_DISABLED` aliases this rung, which
would excuse it — but of its **126 consumers** most are not disabled states:
`WeaponTableDisplay` prints weapon DAMAGE in it, `JournalEntryTypes` colours entry labels
with it, and `NotificationManager.gd:243` uses it for an **active** close button. Raising
it is a palette decision with a 126-site visual footprint that compresses the
primary/secondary/muted hierarchy — an owner call, not a silent edit inside a sprint about
a different colour. The suite pins it at the 3.0 floor so it cannot degrade further, and
passes if it is later raised.

⚠ Still device-bound, and not signed off here: all four §3 boxes. Record reading
distance and screen brightness with the tick, not just the tick.

---

### ✅ SELECT CREW IN LANDSCAPE — FIXED AND VERIFIED ON HARDWARE (deploy #27, 2026-09-07)

Deploy #26 left this half-open: PASS in portrait, **still broken in landscape** — the
Select Crew pane got ~30 px so its own title was clipped mid-glyph, and the page would not
scroll to reveal the list (swipes at five x-positions, byte-identical frames). It is now
root-caused, fixed and detection-proven, and it was **TWO independent defects, either
fatal alone**.

**A — the orphan row, and its cause was one Label.** Four panes against
`max_columns = 3` leave Crew alone on grid row 2; row 1's height is the MISSION pane's
content, and with a REAL rival-attack briefing that is **1042-1120 design px** against a
~1222 px budget, so row 2 starts below the fold. ⭐ The column WIDTHS turned out to be
decided by `mission_desc`, the one Label `_setup_mission_info()` built with autowrap OFF:
a non-wrapping Label reports its full TEXT WIDTH as its minimum (**measured 1134 px** for
a 124-character briefing), and because `GridContainer` hands an oversize column exactly
its minimum and splits only the REST equally, that Label sized every column.

| Tablet 2207×1379, device mission | columns (px) | side overflow | crew list |
|---|---|---|---|
| shipped `max_columns = 3` | 1136 · 496 · 495 (+ Crew on row 2) | 0 | **row 2, 1 of 6 buttons visible** |
| `max_columns = 4` alone | 1136 · 328 · 328 · 327 | 103 px at desktop | row 1, 6 of 6 |
| **shipped now** (4 + autowrap) | **528 · 528 · 528 · 527** | **0 everywhere** | row 1, 6 of 6, top of page |

⚠ **The side overflow was a live pre-existing defect no sweep had ever seen**: with the
device mission and the description un-wrapped, the page hangs **103 px** off both edges at
desktop 1080p, **299 px** at 1103×689 and **281 px** at phone landscape. `PreBattle.tscn`
anchors its root full-rect with grow BOTH ways, so the overflow is split across both edges
and no scroll can recover it. Wrapped, every configuration measures **0.0**.

**B — the swallowed swipe.** Every surface under a finger is `MOUSE_FILTER_STOP` **by
construction** — `PanelContainer`'s own constructor sets it ("Has visible stylebox, so
stop by default") and so do HSeparator, CheckBox, OptionButton and Button — and
`Viewport::_gui_call_input` stops Mouse, ScreenDrag and ScreenTouch at the first STOP
control, excepting **only** WHEEL events via `mouse_force_pass_scroll_events`. That single
exception is why the deploy #24 record could truthfully say *"the outer scroll IS live —
dragging the scrollbar scrolls the page"* while a swipe did nothing, and why no desktop
session ever reproduced it. `PreBattleUI` now calls `TouchScrollOpener.open_subtree()`
after **each** of its three populating entry points (31 controls opened; the opener is
idempotent and STOP -> PASS only).

#### ⭐ The method changed too: geometry AND gestures are now testable HEADLESS

The plan for this work assumed a windowed harness was required, and both halves of that
assumption were wrong:

- **Column counts.** `AdaptivePanelGroup._columns_that_fit()` reads
  `get_viewport().get_visible_rect().size.x`, so a **SubViewport** sized to the design
  space reproduces a device's column arithmetic with no window. (A screen added straight
  to the test root sees the square 1080 stretch base and resolves 3 columns forever, which
  is why this looked impossible.)
- **Touch drags.** "Godot does not deliver InputEvents headless" is true of the OS input
  path, not of `Viewport.push_input()`. `ScrollContainer` arms its touch drag off
  `DisplayServer.is_touchscreen_available()`, whose base implementation returns
  `Input.is_emulating_touch_from_mouse()` — which this project enables
  (`project.godot:109`). A synthetic mouse drag takes the real touch path and
  `scroll_started` fires.

#### 🔧 A harness defect found while fixing it: the sweep fixture was ~440 px short

`screen_populator.gd` exists so the layout sweep stops measuring EMPTY screens (T11-01) —
and its PreBattle mission, generated by `BattleSimulatorSetup`, stamps none of the keys
`CampaignTurnController` stamps: no `initiative_context`, no `setup_rules`, no
`terrain_guide`, no `objective_details`, no deployment condition. **With it the Mission
pane is 679 px and the shipped 3-column layout FITS the tablet**; with a mission pulled off
the device it is 1042-1120 px and does not. A populated screen can still be
under-populated. Closed by committing the device product verbatim as
`tests/fixtures/device/prebattle_rival_attack_mission_2026-09-06.json` (with `_source` /
`_provenance_warning` keys, as `data/RulesReference/` does); the populator prefers it and
`state_line()` names which mission ran.

#### Gates

| Gate | Result |
|---|---|
| `tests/unit/test_prebattle_responsive_layout.gd` | **11 cases, 0 failures, 0 orphans** (was 5) |
| Detection, one arm at a time | `max_columns` 4->3 **RED** · autowrap removed **RED** · `_open_touch_chain()` removed **RED**; restored **GREEN** |
| `tests/tools/probe_prebattle_landscape.gd` | **PASS** shipped; `-- cols=3` **FAIL** (5 of 6 and 6 of 6 crew buttons off screen) |
| `scripts/lint_*.py` (11) | all exit 0 |
| `git diff -- data/` | empty (the fixture lives under `tests/fixtures/`) |

#### ✅ DEPLOY #27 (versionCode 11, TB361FU, 2026-09-07) — WALKED, BOTH HALVES PASS

Walked from `save_T947_after.json` (the armed p.85 Rival attack): Continue → Begin Turn 10
→ Crew Tasks (Bryn Ito / Train, 1/1 succeeded, the p.78 Character Upgrade fired) → accept
the Quest → Confirm Equipment → Rumors → Ready for Battle → Proceed to Battle.

| Check | Result |
|---|---|
| Landscape 2560x1600 pane layout | **FOUR panes in ONE ROW** — Mission Info \| Enemy Forces \| Battlefield Preview \| Select Crew |
| Crew list | **all 6 buttons rendered**, `Deploying 5 / 5 max` legible at the top of the pane |
| Mission briefing | wrapped to 3 lines inside its own column (it used to size every column) |
| Swipe over the Mission body | **THE PAGE SCROLLED** — frame md5 `03169a7a` → `0d0300ac`, revealing the rest of the Before You Deploy checklist and the Deployment Condition; footer still pinned |
| `godot.log` | `[TouchChainProbe:PreBattle] scroll_started on ContentScroll — THE GESTURE ARRIVED`, on every swipe (64 probe lines) |
| Portrait 1600x2560 regression check | unchanged — TABS, Crew tab shows all six and the counter |

⭐ `scroll_started` is the discriminator, not the changed frame: per the Godot 4.6 docs it
fires **only** for a touch drag on the scrollable area — never the scrollbar, the wheel or
the keyboard. On #26 five swipe positions left the frame byte-identical.

⭐ **Incidental, and it closes a row recorded as unreadable:** the p.91 Ambush cap is
VISIBLY BOUND — `Deploying 5 / 5 max` with Nyx Ward deselected on a six-crew roster.
T11-48 was verified on #24 from the SAVE precisely because that counter could not be read
at 2560x1600. It can now.

Device left clean: pre-walk save restored byte-for-byte from a fresh backup (80,528 bytes),
`accelerometer_rotation` back to 1, `svc power stayon false`.

⚠ **Still owed** (unchanged by this pass): **§3 of `docs/testing/TABLET_CHECKLIST_2026-08-02.md`** — *"Physical legibility and thumb reach"*, four
unticked boxes — and the A5 `gl_compatibility` measurement, for which deploy #27 is the
BASELINE arm.

⚠ **"Checklist §3" is a DOCUMENT section, not the in-app "Before You Deploy" checklist.**
That block has no numbered sections, and the two are named in one sentence only where a
swipe verdict mentions scrolling to reveal it. Spelling the path out because the short
form sent a 2026-09-07 planning pass looking for it in `PreBattleUI`.

⚠ And §3 **cannot be signed off from screenshots**: its own preamble reads *"Measurement
says ≥48dp; only a hand says whether it is comfortable."* Reading distance and screen
brightness are the measurement.

---

### 📱 DEPLOY #26 — versionCode 10, TB361FU, 2026-09-07

Built from HEAD (`dfe398615`) with the debug-only `[ITEM-REMOVE]` prints. Two rows walked.

#### ✅ Item-removal row — **NOT REPRODUCED**, downgraded from "confirmed defect"

Deploy #25 recorded the discard and the sale as announced and PAID with the item never
removed. On #26 the removal **works**, in three runs:

| # | Configuration | Result |
|---|---|---|
| 1 | Trade 76 alone (Dex Kovac) | Blade removed, persisted, credits +2 |
| 2 | Explore 51 + Trade 76 together — **#25's exact pair** | BOTH removed, persisted |
| 3 | repeat of 2 | BOTH removed, persisted |

The instrumentation is unambiguous — member found by `character_id`, correct `equip_before`,
erase at index 0, and re-reading **through the member** returns `[]`:

```
[ITEM-REMOVE] want=Blade member=Dictionary id=char_690708_7921 equip_before=["Blade"]
[ITEM-REMOVE] removed at 0; equip_local=[] member_now=[]
```

The pulled save then shows `Bryn Ito []` and `Dex Kovac []`. So `equip` is **not** a detached
copy and the entire "the write is wrong" family is dead.

⭐ **The prints cannot be the fix.** `git show dfe398615 -- CrewTaskComponent.gd` is **pure
additions** (comments + `if OS.is_debug_build(): print(...)`), zero deletions. So #25 and #26
genuinely differ and the cause is not in that function.

⚠ **The #25 record has a known flaw**, found by auditing its own artefacts: two consecutive
walk frames are **byte-identical** — `walk21/T947_20_itemsel.png` == `walk21/T947_21_next_event.png`,
md5 `fdd2020bbb9afb7a494744dec0f49a37` — so a tap in that sequence did nothing and the frames do
not show the steps they are labelled as. That is a flaw in the EVIDENCE, not a proven
explanation: credits 18 → 17 still requires both the upkeep and the sale, and
"Discarded: Shatter Axe" did render.

⚠ The one variable that differs between the failing and passing runs — **upkeep was paid on
#25 and in none of the #26 runs** — is **disconfirmed at the desk**: `UpkeepPhaseComponent`
keeps its own shallow copy (`crew_data = crew.duplicate()`, `:146`) and never writes members
back, and the only assignment to campaign `crew_data["members"]` repo-wide is a defensive init
inside `FiveParsecsCampaignCore.add_crew_member()`.

**Disposition:** downgraded to *not reproducible*, recorded at the row rather than deleted. The
prints are **kept** — debug-only, and they answered this in one run.

#### 🟡 Select Crew pane — **HALF confirmed**

| Orientation | Result |
|---|---|
| **Portrait 1600x2560** | ✅ PASS — all 6 crew render as buttons and **"Deploying 6 / 6 max"** is legible |
| **Landscape 2560x1600** | ❌ STILL BROKEN, and worse than "header-only" |

⭐ Portrait passes for a reason that is **not** the 144 px floor: the group drops to **TABS**
(`Mission | Forces | Battlefield | Crew`), so Crew gets a whole tab. That legible counter is the
one CLAUDE.md records as unreadable at 2560x1600. ⚠ It also corrects the plan's claim that TABS
mode is *"structurally unreachable"* — it is unreachable in **landscape**, where
`_columns_that_fit()` returns 6; rotate and tabs are the normal presentation.

In landscape the pane gets **~30 px**, so the words "Select Crew" are themselves **clipped
mid-glyph** against the pinned footer, and the page **will not scroll** to reveal the list —
swipes at five x-positions left the frame byte-identical (md5 `56241bbef25b426c5a99db38cdf338a0`).
So a 144 px pane minimum is not sufficient: the row-2 pane is not merely short, it has no room
**and** the outer scroll is not taking the gesture. **Do not close this row on the portrait pass**
— landscape is the configuration the finding was filed in.

#### Incidental confirmations
Corporate Label renders as **`Corporate`** on one line with the long rival name ellipsized
(`Old nemesis (persiste…`); the p.78 Character Upgrade fires on a Training task.

**Device left clean:** `dev_now_0906.json` restored, `accelerometer_rotation=1`,
`svc power stayon false`.

---

### ✅ DEPLOY #25 WALKED (2026-09-07, versionCode 9) — T9-47 CLOSED, and a new defect

Built from `f02cc9acf`, `verify_apk.py` PASS, export preset restored (only `version/code`
moved). Device: Lenovo TB361FU, landscape 2560x1600.

**✅ T9-47 — CLOSED. The last open T9 row, open since 2026-08-14.**
Both rows were armed at once from the QA dialog and the queue reported its own state,
`[pending: exploration table=[51], trade table=[76]]` — confirmation that
`DiceManager._forced_results` really does hold independent per-key FIFO queues.
* **51-53** rendered *"Gambling problem"* (Bryn Ito · Explore) with the book text
  *"You must discard 1 item carried by the crew member. Soulless ignore this result."*
  and an item picker.
* **76-78** rendered *"A chance to unload some stuff"* (Dex Kovac · Trade),
  *"A revolutionary will buy any weapons for 2 credits each, provided they are not
  damaged"*, **Total: 2 credits**, then *"Sold 1 weapon(s) for 2 credits"*.
* Campaign state: credits **18 → 17** = −3 upkeep (paid on screen, p.76 High Cost world
  trait correctly counting crew as 2 higher) **+2 sale**. `Results: 2/2 succeeded`.

⚠ One correction to the plan's expectation: both rows act on the item **carried by the
crew member** (`Character.equipment`), not the ship stash. The stash was unchanged, which
is correct.

**✅ T11 "Corporate Label" — PASS on hardware.** The Rivals card renders
`Old nemesis (persiste…` → **`Corporate` on one legible line**, ellipsis and `LOCAL`
badge intact. On deploy #24 that same row was a 1px-wide, 9-line vertical slab.

#### 🔴 NEW — crew-task item loss is announced and PAID, but the item is never removed

The same save that recorded the +2 credits still holds both items:

| character | before | after | the UI said |
|---|---|---|---|
| Bryn Ito | `['Shatter Axe']` | `['Shatter Axe']` | "Discarded: Shatter Axe" |
| Dex Kovac | `['Blade']` | `['Blade']` | "Sold 1 weapon(s) for 2 credits" |

**The player is paid for a weapon they keep** — a repeatable credit source — and a p.82-class
item-loss penalty does not bite. Device logs were clean (0 warn/error), so this is a silent
missing write, not an aborted call.

⚠ **`_remove_from_crew_equipment()` was ALREADY FIXED for this exact symptom on
2026-08-13**, so the obvious cause is taken. Every static explanation has now been
eliminated, each by reading the code and by `tests/unit/test_crew_task_item_removal.gd`
(5 cases, all green):

* the matching logic — it removes a plain-String entry correctly
* `item_display_name()` on String entries — returns the string
* `crew_key()` vs `_get_crew_member_by_id()` drifting again (the T9-40 shape) — they agree
  on `character_id`, which every member in the save carries
* `Array.duplicate()` losing element references through the two shallow copies the real
  path performs
* the event dict not carrying `crew_member` — `base.duplicate()` is shallow
* serialization dropping it — `to_dictionary()` writes `"crew": crew_data`, the live ref
* a world-phase crew write-back overwriting it — there is none

The dialog also **displayed the right items**, which it reads off the same `crew_member`,
so the member is neither null nor a stranger. Both halves of the `SELL_WEAPONS` branch run
from one block, and the credit half demonstrably fired.

⭐ **Instrumented rather than guessed at.** A debug-only `[ITEM-REMOVE]` print now reports
the member shape, its id, the equipment before, and — after the erase — re-reads through
the MEMBER rather than the local array, so a copy-vs-reference divergence names itself.
T11-07 is the precedent: printing all the inputs is what made that term visible after two
wrong diagnoses. **The next device run answers this.**

---

### ✅ DESK PASS — the T11 tail (2026-09-06/07), all detection-proven

Four desk items closed. Gates: **285 suites / 3,127 cases / 0 failures** headless plus the
one `NEEDS_DISPLAY` suite windowed (**27 cases**) = **3,154**; all **11** `scripts/lint_*.py`
exit 0; `git diff -- data/` empty; layout sweep **224 passed / 0 failed** at 8 sizes;
rotation sweep **23 / 0** at 9 steps.

**T11-47 — the formula that broke it is finally guarded.** The harness docblocks were
already corrected; what remained was six sibling probes carrying the stale premise and,
much more importantly, that **nothing anywhere asserted `SettingsManager._apply_ui_scale()`**.
`tests/unit/test_content_scale_formula.gd` (4 cases) now does. ⭐ It is testable at all
only because `_dpi_scale()` prefers `ResponsiveManager.get_screen_scale()`, which returns a
plain member — writing it lets a 1.0-density desktop pretend to be a 2.0-density tablet.
That matters because **T11-07 shipped precisely since desktop density is 1.0**, making the
offending `* _dpi_scale()` exactly 1.0 on every machine that ran the gates: a green desk
suite was not evidence, it was the term being invisible. The suite asserts the INVARIANT
(density-independence, linearity in the user slider, and that the two do not interact),
never the constant, and instruments its own premise first so the density case cannot pass
vacuously. Detection-proven by re-introducing the density term and by dropping the slider.
⚠ Scope, stated rather than implied: headless pins `stretch_cancel` at 1.0, so the
window-size cancellation is NOT exercised there — that half is the sweeps' true-pixel rows.

**T11 "Corporate Label" — fixed, and the obvious fix was a trap.**
`CampaignScreenBase._create_info_row()` rendered the value as a 1px-wide 9-line slab.
Measured (`tests/tools/probe_label_clip_min.gd`): a plain Label reports its FULL text width
(**327 px**) while the autowrapping value reports **1 x 855**. `CampaignDashboard:1474`
passes a rival NAME as the row LABEL, so 327 px exhausted a ~384 px column and "Corporate"
got its 1 px minimum. ⭐ **`clip_text` alone would have been worse:** it does bound the
minimum to 1 px (verified — Godot documents this for `Button`, NOT for `Label`), but
`SIZE_SHRINK_BEGIN` hands a child exactly its minimum, so the name would have VANISHED on
all 49 call sites while a geometry sweep reported clean. `CharacterCard.gd:228-244` is not
a precedent here: its labels sit in a **VBox**, where children stretch to the container
width regardless. Fix is container-level — EXPAND_FILL on both with a 1:2 ratio, plus
clip_text/ellipsis/tooltip on the name. Pinned by
`tests/unit/test_info_row_label_starvation.gd` (5 cases, RENDERED rects), detection-proven
four ways including the clip_text-alone trap.

⚠ **The layout sweep is NOT the guard for that fix, and 224/0 must not be read as
validating it.** Controlled A/B: reverting the fix left the sweep at **224/0**. The fixture
does contain rivals (one literally `Executive Guard` / `Corporate`), so the A/B was not
vacuous — but both names are ~15 characters and nothing starves. More fundamentally the
sweep detects OVERFLOW while this defect is STARVATION: with the long name the row's
minimum is 227 px inside a 384 px row, and the value's compensating growth is vertical and
absorbed by a ScrollContainer. Structurally invisible, like a footer scrolling out of view.

**T11 "Select Crew renders header-only" — fixed.** Four panes against `max_columns = 3`
leave Crew alone on grid row 2; `AdaptivePanelGroup` has no row-height logic, and with
`ShortScreenScroll` enabling correctly (T11-01) the inner column settles at its combined
minimum, so the surplus is ZERO and row 2 gets only the pane's own minimum — which was
header-sized, because a ScrollContainer contributes ZERO minimum on its scroll axis.
`PreBattle.tscn` now gives it `custom_minimum_size = Vector2(0, 144)` = 3 x the 48 px touch
floor the screen already asserts. ⚠ The existing
`test_prebattle_responsive_layout.gd:82-96` is the cautionary tale: it asserts
`custom_minimum_size` and `autowrap_mode` — CONSTRUCTION properties — so it passed
cheerfully throughout. The new case asserts the RENDERED rect.

⚠ **A comment corrected at the same site:** `PreBattleUI.gd` justified `max_columns = 3`
by saying the wide FORCES table wraps to row 2. It does not and never did — the add order
is Mission(0)/Forces(1)/Battlefield(2)/Crew(3), so Forces is in row 1 and **Crew** is the
pane alone on row 2. The comment described an intent the ordering does not produce, which
is part of why nobody looked at the pane that actually landed there.

#### 🔧 Two HARNESS defects found while verifying, both pre-existing

1. **`verify_rotation.gd` had no window-hijack guard, and it produced a FALSE FAILURE.**
   `SettingsScreen` restores `user://window.ini` in `_enter_tree()`, so it moves the window
   after the harness sized it and bakes its fonts at the restored breakpoint; this sweep
   walks one instance and never rebuilds. Proven with ONE variable, nothing else changed:
   `window.ini = 1600x2560` → **22/1 FAIL**; `= 393x851` → **23/0 PASS**. And 1600x2560 is
   exactly what `verify_layout.gd` leaves behind (its last SIZES row is the TB361FU
   true-pixel portrait), so **running the two sweeps in their natural order made the second
   fail on the first one's leftovers.** `verify_layout` has had this guard since T11-04;
   `verify_rotation` now has it too, rebuilding ONCE at the walk's first size (the
   one-instance contract is untouched). Re-verified: hostile state now 23/0 with a NOTE.
2. **`test_prebattle_responsive_layout.gd` claimed "never --headless (project rule)".**
   That rule was superseded on 2026-09-05 by `--ignoreHeadlessMode`; the suite runs clean
   headless (re-verified 5/5). Corrected at the docblock.

⚠ **Not run / not done:** T9-47's device walk and the A5 `gl_compatibility` A/B both need
hardware and are untouched by this pass.

---

### ✅ CLOSED ON HARDWARE — the T11 acceptance list (deploys #21/#22, Sep 5-6 2026)

Deploy #19's walk plus the dry run left 21 desk-fixed findings with no device verdict.
**Deploys #21 and #22 gave every one of them a verdict on the tablet**, and the walk closed
**T9-51** as well — both of its rows, from a stronger control than was planned (two cycles
restored the identical save, so the queued roll was the only variable). Record:
[docs/qa/TABLET_FINDINGS_2026-09-05.md](qa/TABLET_FINDINGS_2026-09-05.md);
ledger [docs/qa/TABLET_QA_SPRINT_2026-08.md](qa/TABLET_QA_SPRINT_2026-08.md) § #21/#22.

**Two recorded verdicts were corrected rather than quietly amended.** T11-20's evidence
cited the dashboard, which derives its turn as `turns_played + 1` and never reads
`turn_number` — it renders identically with and without the fix, so the citation proved
nothing (the verdict was right; the artifact is now the persisted counter). T11-42's cause
was wrong: nothing drops the button labels; a non-wrapping prose Label set a 609 px
container minimum against a 380 px window and pushed their centred text out of the visible
rect.

---

### ✅ CLOSED ON HARDWARE — deploy #23 (2026-09-06, versionCode 7)

The rebuild carrying the Sep 6 desk pass has been walked. **T11-41 / T11-42 / T11-43 /
T11-44 / T11-45 all PASS on the tablet**, and **T9-48 is CLOSED** — the p.91 Ambush
prohibition branch, open since 2026-08-14, reached by forcing the attack-type D10 on a
snapshot that already had a rival battle armed. Record:
[docs/qa/TABLET_FINDINGS_2026-09-05.md](qa/TABLET_FINDINGS_2026-09-05.md) § deploy #23;
ledger [docs/qa/TABLET_QA_SPRINT_2026-08.md](qa/TABLET_QA_SPRINT_2026-08.md) § #23.

**T11-46 is closed** (comment corrected; `GameState.advance_turn()` left alone by owner's
decision). Gates: **281 suites / 3,094 cases / 0 failures** headless, `git diff -- data/`
unchanged.

### ✅ FIXED AND VERIFIED ON HARDWARE 2026-09-06 (deploy #24) — T11-48 and T11-40

Both were opened by the deploy #23 walk, fixed at the desk (each detection-proven by
isolated revert and pinned by a new unit suite), and **both now PASS on the tablet**
(deploy #24, versionCode 8, md5-verified on device). **T11-48**: from the same D1
snapshot and the same forced AMBUSH as deploy #23's pre-fix artifact, with every
input identical, `active_battle.crew` moved **6 -> 5** and the battle rail reads
`CREW 5 / 5` with one crew member sitting out — the p.91 Ambush reduction on the
table. **T11-40**: re-measured with the finding's own instrument at x=2400, the tall
Crew Tasks step went h=**37** with 9 px below to h=**66** with 122 px below, and the
button no longer moves between steps or when content grows. Detail:
[docs/qa/TABLET_FINDINGS_2026-09-05.md](qa/TABLET_FINDINGS_2026-09-05.md) § deploy #24.

- **T11-48** — the crew the player selects now reaches the battle. Three parts: a new
  `BattleSetupRules.apply_crew_selection()` (pure static, beside its enemy-side
  analogue `apply_enemy_delta()`), `PreBattleUI.setup_crew_selection()` made idempotent,
  and `_on_deployment_confirmed()` actually consuming the selection. The **p.91 Rival
  Ambush** reduction, the **p.88 Small Encounter** sit-out and the **p.84 Small Squad**
  ceiling all bind again. Identity comes from `BattleCheckpoint.member_key()`, the rule
  the checkpoint already filters with. Every ambiguous input returns the roster
  untouched, because an empty selection means the selector never ran, not that the
  player chose to field nobody. **17 cases**, 3 detection arms proven one at a time.
- **T11-40** — `_phase_viewport_budget()` now subtracts the nav wherever it is
  parented, so the tight/relaxed decision no longer depends on the arrangement it
  produces. The latch is gone: 1280x800 reports **244.7 in both states** where it used
  to report 244.7 or 502.7 against a threshold of 320. At the true device size the nav
  is pinned and the footer ends at y 1279 of a 1379.3 px viewport, fully on screen.
  **4 cases**, detection-proven.

Gates: layout sweep **222 passed / 2 failed** at eight sizes, WorldPhaseController
green at every one. ⚠ Not a like-for-like improvement on the earlier 217/7 — the
desktop fixture campaign was swapped for the walk snapshot, so the journal and galaxy
screens render different content. The claim that holds: **no new failures, and the two
remaining are among the seven already filed.**

---

### ✅ CLOSED — Tactics rules accuracy (found 2026-09-04, closed 2026-09-06)

Correcting five wrong Tactics page cites exposed two data defects. Both are now fixed.

**FIXED — Campaign Points award.** `TacticsCampaignCore.record_battle()` awarded a flat
1 CP, +1 win, +1 "secondary objective" — a maximum of **3** — cited "(p.160)", a page in
the Lifeforms bestiary. Tactics **pp.106-107** (the book's index: "Campaign Points (CP)
106") gives *"Roll three D6s and drop the lowest result. The sum of the two remaining
dice is the base number of CP awarded"*, then either 1 CP per VP or **+3 victory / +2
draw / +1 defeat**. The book's own worked example totals 11. Players were earning roughly
a quarter of the currency that gates every unit upgrade, roster change and battle
advantage. Pinned by `tests/unit/test_tactics_campaign_points.gd` (6 cases, built on the
book's example), detection-proven.

**FIXED — platoon composition.** ⚠ **This row was stale for a day and is corrected
rather than deleted.** It was filed 2026-09-04 as an open defect whose table cited
`PLATOON_LEADER_COUNT` and `MAX_TROOPS_PER_PLATOON := 5`; those identifiers stopped
existing on **2026-09-05** in `d432df8d6`, which rewrote the constants against p.134 and
added `tests/unit/test_tactics_composition_p134.gd` — a both-directions suite, because a
validator that only ever rejects is as broken as one that only ever accepts. The
validator now enforces Leaders **1-2**, Troops **2-4**, Supports **0-3** *and* the
"fewer than Troops" clause, and Specialists as the **0-1 per 2 Troops ratio** rather
than a flat cap.

**FIXED 2026-09-06 — a FABRICATED specialist rule, found in the part nobody re-read.**
While retiring this row, `TacticsCompositionValidator._validate_platoon()` was found to
reject any platoon holding two specialists that share a `unit_id`, commented *"one of
each type"*. **p.134 states one specialist rule and it is a ratio:** *"A platoon may have
1 specialist unit per 2 troops selected."* The invented restriction **rejected legal
armies** — the same defect class as the row above, sitting beside it.

The book states type-composition rules plainly when it has one, and the only two places
it does so nearby both contradict the deleted check:

| Where | Book text | Direction |
|---|---|---|
| p.134, Troops | "The platoon does not have to consist of all the same type." | an explicit permission to **mix** |
| p.135, Armored Platoon | "The first 3 vehicles selected for this section must be the same type" | a same-type **requirement**, inverted |

⭐ **Where it came from.** `TacticsRoster.gd` records that this rewrite *"Drops AoF
hero-per-375, 35% cap, **duplicate limit**, combined units"* — so Age of Fantasy had a
duplicate limit, Tactics has none, and the rewrite dropped it from the roster and left it
standing in the validator. The old wrong constants had the same shape (lifted from the
p.135 Armored Platoon). **A rule deleted in one file and kept in its sibling** is the
transferable shape here.

⚠ **The invention had propagated into the test fixture meant to police this file.**
`test_tactics_composition_p134.gd`'s `_add()` helper gave every unit a unique id with the
comment *"a platoon may not take two specialists of the SAME type ... would fail that
separate rule"* — so the suite was quietly built never to construct the case that would
have exposed it. Corrected at the site.

Also wired: **`get_limits_summary()` was a zero-caller function** (reachable only from its
own test) whose docstring claimed the strings are "what a player reads while building".
The caps were correct, tested, and displayed to nobody — the builder announced a limit
only *after* one was broken. It now renders in `TacticsRosterPanel` above the error list
and for an empty roster too. Pinned by 8 cases (3 new), **all three arms
detection-proven by isolated revert**: restoring the duplicate check, un-wiring the
summary, and restoring the "one of each type" clause each fail exactly one case.

⚠ Armored platoons remain unmodelled, deliberately — the book gives them different
units, a same-type constraint and mandatory transports; recorded at the validator.

### Production-dead sweep — CLOSED 2026-09-04

`lint_orphan_assets.py`: `files=557 reachable_from_product=556 test_only=0 orphans=0 unwired_rules=1` (**exit 0**). 39 source files deleted (11,349 lines / 364 KB — all of it packed into every APK/AAB, since `export_filter="all_resources"` and Android tooling does not strip Godot's PCK), plus 3 fabricated JSON tables, 4 zero-caller test fixtures, 6 stale UI-test guides (1,616 lines) and a 68-line zero-caller block in `CharacterGeneration.gd`.

All 8 gating lints CLEAN. Live coverage was preserved BEFORE anything was deleted, via a PURE-DEAD/MIXED classification of all 16 dependent suites — that gate is what caught 21 live implant cases hidden inside `test_equipment_classes.gd`, now `tests/unit/test_character_implants.gd`, and the sole `DiceSystem` case, now `tests/unit/test_dice_system_contexts.gd`. The one remaining `unwired_rules` entry is a book chapter with no caller (Tactics **pp.92-100** — cite corrected from a wrong pp.155-168, which is the Lifeforms bestiary).

## 🟢 § Sep 3-4 2026 — battle-phase sprint, page walk, tablet deploys #14/#15/#16

Branch `campaign-editor-and-fixits`, committed through `c4317b993`.
Ledger: [qa/TABLET_QA_SPRINT_2026-08.md](qa/TABLET_QA_SPRINT_2026-08.md) deploys
**#14**, **#15** and **#16** (#16 closed all 11 T10 findings on hardware). Per-finding detail:
[qa/TABLET_FINDINGS_2026-09-04.md](qa/TABLET_FINDINGS_2026-09-04.md).

| Gate | State |
|---|---|
| `tests/tools/verify_battle_ui.gd` | **137 / 0** (was 80 before the Sep 3 sprint) |
| `tests/tools/verify_post_battle.gd` | **47 / 0** |
| `tests/tools/verify_story_track.gd` | **9 / 0** |
| Ten gating lints | **9 CLEAN**; `lint_orphan_assets` `orphans=0`, `test_only=34` |
| Headless `--import` parse | **clean** |
| `verify_layout` | **166 / 2** windowed with a campaign (was an effective 0/168) |
| `verify_rotation` | **23 / 0 — PASS**, first green run |

⭐ **The RED was harness misuse, and fixing it exposed a real desktop bug.**
Both sweeps' docblocks say *"NOTE: no --headless — this needs a real window to resize"*,
and the runs that produced `passed=0 failed=168` were headless. Godot 4.6 docs
(class_displayserver): under `--headless` *"most functions from DisplayServer will return
dummy values"* — so `window_set_size()` did nothing and all 168 configs measured at one
size. Run windowed with `-- campaign=user://saves/<x>.save`:

```
godot --path . --script res://tests/tools/verify_layout.gd   -- campaign=user://saves/x.save
godot --path . --script res://tests/tools/verify_rotation.gd -- campaign=user://saves/x.save
```

Three harness defects and one product defect came out of that:

| Fix | What it was |
|---|---|
| **PRODUCT — `user://window.ini` could record `MODE_MINIMIZED`** | Both restore sites replayed it behind a `mode >= 0` check, so the app **launched minimized and re-minimized itself whenever the Settings screen opened**. A minimized window also silently ignores `window_set_size()`, which is what pinned the sweep to one geometry. New SSOT `src/core/state/WindowStateRules.gd`; `tests/unit/test_window_state_rules.gd` (5 cases) detection-proven — restoring MINIMIZED to `PERSISTABLE` fails exactly 2 |
| Harness — no resize verification | The sweep now polls until `window_get_size()` matches and reports a SKIP with the asked/got sizes if it never does, instead of measuring the wrong rect |
| Harness — the consent gate | `MainMenu._ready()` returns to the EULA before `_on_viewport_resized()` when `PRIVACY_VERSION` (1.1) differs from the stored consent (1.0), so every MainMenu measured had never run its responsive layout — 16 phantom failures. Consent is now stubbed **in memory only**; `accept_*()` is never called |
| Harness — sheet-overlay false positive | 698 findings, all Labels over a TextureRect: the printable sheet places field labels on the artwork **by design**. The sibling-overlap check now skips a control fully enclosed by the sibling it covers; the MainMenu showcase-card shape it was written for (partial overlap, neither enclosing) still fires |

Residual: **2 configs**, both `PrintSheetScreen` at the two smallest landscape sizes
(733x338, 310x551), where sheet field labels crowd each other. Real but low-value —
a 2764x1843 sheet previewed in 733x338.

---

### Sep 4 (later) — terrain escaped the grid (BUG-101, third occurrence)

Reported live: *"battlefield generator is still creating shapes outside of the grid
boundary."* Reproduced, and it was **two independent defects**, not one.

`tests/tools/probe_terrain_bounds.gd` measures the drawn footprint
(`svs.transform * svs.get_bounding_rect()`, grown by `stroke_width / 2`) against the
placement-space grid rect, across 4 themes x 3 table sizes x 12 seeds.

| State | Shapes outside grid (of 3,898) | Worst overflow |
|---|---|---|
| Before | 246 | **101.01 px** on a 576 px grid |
| Revert cause A only | 227 | 101.0068 px |
| Revert cause B only | 11 | 0.8224 px |
| **Both fixed** | **0** | **0.0000 px** |

**Cause A — the clamp had no copy on the exit path.** In the grid-distributed fallback the
clamp sits at the TOP of the retry loop and the nudge `c.y += half_y * 2.0 +
effective_padding` at the BOTTOM; its own comment said *"re-clamped next pass"*. On the
16th pass there is no next pass. Worse, clamp and nudge **oscillate** (clamp pins to
`grid_h - half_y`, nudge pushes to `grid_h + half_y + pad`), so all 16 retries re-test two
positions and exhaustion is the COMMON case — hence 6% of shapes, not a rare few.
Predicted overflow `2*half_y + pad` = 81.0 + 20.0 = 101.0; measured **101.0068**.

**Cause B — the clamp reserved a size the shape does not draw.**
`BattlefieldShapeLibrary.create_vector_shape()` sets `svs.rx = ry = 4.0` on every RECT, so
a body shorter than 8 px cannot fit its own corner rounding and the tessellated curve
bulges to a ~8.004 px floor. Reserving the DECLARED height under-reserves by the
difference. Only `is_scatter` pieces on 2 ft tables shrink under that floor — exactly the
distribution measured.

**Fix**: the bounds rule is now one SSOT helper `_clamp_center_to_grid()` (it had been
written out inline three times, and the missing copy WAS the bug), applied on every exit
path; half-extents come from `svs.get_bounding_rect()` rather than the declared `w`/`h`.

**Pinned** by `tests/unit/test_battlefield_shape_bounds.gd` — 2 cases, one broad sweep
(catches A), one narrow on the 2 ft scatter combination (catches B), both detection-proven
by isolated revert. **This invariant had never been asserted anywhere**: eight other
`test_battlefield_*` suites exist and not one measured geometry against the grid, which is
why it was "verified" visually twice and returned twice.

⚠ Two traps worth carrying:
- **My own first diagnostic lied.** It compared the drawn footprint against `child.size`,
  and `ScalableVectorShape2D` reports `size` back from the REBUILT CURVE (8.004), not the
  value assigned (6.29) — so it read `error = 0.000` while cause B was live. A check that
  cannot disagree with the thing it is checking proves nothing.
- **Operand order.** `Rect2 * Transform2D` is documented as the INVERSE transform
  (`rect * transform == transform.inverse() * rect`); `Transform2D * Rect2` is forward. One
  order away from silently measuring the wrong rectangle for the whole investigation.

### Sep 4 (later) — debug-only forced-roll seam (unblocks T9-47 / T9-48 / T9-51)

Three fixes have been stuck desk-verified since 2026-08-14 because no in-app tool can
reach their row (`qa/PICKUP_2026-08-14.md` section 3). Widening the shipped `roll_range`
was declined twice. `DiceManager.queue_forced_result(context_key, value)` now parks a value
that the next matching roll consumes ONCE; both ends are gated on `OS.is_debug_build()`,
and **no rules data changes** — the table is read exactly as shipped, only the die is
pinned. Surfaced in the QA dialog (already debug-gated) as "Force the next roll".

Routing fixed two dead trails found on the way:

| Row | Live roll site | Was |
|---|---|---|
| T9-48 | `MissionTableManager.roll_rival_attack_type()` | bare `randi_range(1, 10)` |
| T9-47 | `CrewTaskComponent._resolve_table_task()` | bare `randi() % 100 + 1` |
| T9-51 | `PostBattleSequence._on_character_event_roll()` | already routed |

⚠ **`DataManager.get_trade_result` / `get_exploration_result` are not the live path** —
both are commented out in full (`##`) and their only callers are in the dead
`phases/WorldPhase.gd`. The live Trade/Explore D100 is `CrewTaskComponent`.

⚠ **`MissionTableManager` is RefCounted and always built with `.new()`**, so it reaches the
autoload through `Engine.get_main_loop()`; a bare `get_node_or_null("/root/...")` there
does not return null, it ERRORS and aborts the roll.

All 10 of that file's book-table rolls now route through one `_roll_die()` helper.
Behaviour-neutral: one `randi_range` draw per call either way, so a seeded caller sees an
unchanged RNG stream.

**Gates**: `tests/unit/test_dice_forced_results.gd` 11/11 (three consecutive runs) ·
`test_qa_scenarios.gd` 16/16 · **323/323 across the 22 unit suites touching the changed
files** · `verify_battle_ui` 137/0 · `verify_post_battle` PASS · `verify_story_track` 9/0 ·
7 lints CLEAN · parse clean. Routing and dialog cases both detection-proven.

~~**STILL OPEN**: the device leg. The tool exists and is tested; T9-47/48/51 are verified on
hardware only after a deploy that forces each roll.~~ **Mostly closed 2026-09-06.** The seam
was used on hardware to force **T9-48** (deploy #23) and again to force the AMBUSH that
verified **T11-48** (deploy #24); **T9-51** closed on #21/#22. **T9-47** (Explore 51-53 /
Trade 76-78) is the only one of the three still needing a walk.

⚠ One case of mine was a **10% flake by construction**: `assert(rolled != 10)` after an
out-of-range value is discarded — discarding means the roll is genuinely random, and a
random D10 returns 10 one time in ten. It aborted the suite at 6 of 11 cases while the
runner still printed `PASSED`. Read the case COUNT.

### Tablet findings T10-01..T10-11 — all 11 CLOSED ON HARDWARE (deploy #16, Sep 4)

| Finding | Fix | Device-verified? |
|---|---|---|
| **T10-11** BLOCKER — World Phase nav unreachable | nav pinned outside the scroll when not `tight` | ✅ both orientations |
| **T10-01** confirm dialog renders empty | `dialog_text` + `dialog_autowrap` (a Control `add_child`'d into a Window gets no layout pass while `wrap_controls` is false) | ✅ renders, names all 5 crew, autowrap follow-up verified |
| **T10-02** ⚔ reads as a cancel ✗ | glyph removed from the CTA | ✅ cause corrected, see below |
| **T10-09** touch-drag scroll "dead" | **NOT A DEFECT** — closed as not reproduced | ✅ |
| T10-03 fabricated job objective | removed from card / title / briefing | ✅ all THREE surfaces |
| T10-04 confirm opens behind the drawer | `OverlayLayer` 10 → 93 | ✅ Hit sheet + Mark Down confirm |
| T10-05 every card control dead to touch | `KeywordTooltip` → `MOUSE_FILTER_IGNORE` | ✅ Hit opened from the drawer |
| T10-06 checkpoint lost on process death | `gs.save_campaign()` flush | ✅ **on disk + survived a real `am force-stop`** |
| T10-07 two exclusive dialogs stack | hide the first before showing the second | ✅ not reproduced (0 log hits) |
| T10-08 undo survives a cancelled confirm | snapshot moved into the callback | ✅ reads plain "Undo" |
| T10-10 world event re-rolls on restart | guard derived from persisted `world_events` | ✅ screen == dashboard == save |

### ⭐ Deploy #15: BOTH remaining findings were MISDIAGNOSED in #14

Neither correction was reachable by reading code.

- **T10-09 was my measurement, not a defect.** The #14 "control" swiped the content
  **upward** and the scrollbar **downward** — two variables, not one. With the view
  already at the bottom the first had nothing left to travel. Measured with
  `ScrollContainer.scroll_started` (Android-only; fires for a drag on the scrollable
  area, never the scrollbar): the gesture **arrives**, the chain under the finger is
  clean, and `scrollable_span` is only **168 px** (step 2) / 414 px (step 1).
  Verified in both directions on both steps.
- **T10-02's glyph was never missing.** A cmap parse of all four bundled `.ttf`s shows
  they lack ✓ ✗ ★ too — glyphs this device demonstrably renders — so
  `allow_system_fallback=true` is live. Magnified 8x from a device screencap, U+2694
  draws as two crossed blades with crossguards. The defect is **legibility at ~16 px**,
  not coverage. A `SystemFont` fallback would have changed nothing.

### Tooling added

- `src/ui/components/common/TouchChainProbe.gd` — **debug-only** (`attach()` returns
  null in a release build). Control chain under the finger with each `mouse_filter`,
  hit-testable controls on higher CanvasLayers, live scroll spans, and a sweep-staleness
  re-run. Shipped because this defect class has cost four device deploys and **a
  `--script` SceneTree probe cannot load these screens at all** — autoloads are not
  registered there, so `WorldPhaseController.gd:1345`'s bare `TweenFX` fails to compile
  and `_ready()` never runs. `tests/tools/probe_world_phase_drag.gd` is marked SUPERSEDED
  for exactly this reason; **discard its numbers.**
- `tests/unit/test_primary_cta_glyphs.gd` (2 cases) — reads `PackedScene.get_state()`
  rather than scanning text; detection-proven.

### Cleanup

`BattleJournal.gd`/`.tscn` **DELETED** — orphaned by the Sep 3 sprint's Phase 7, superseded
by `FPCM_UnifiedBattleLog` (90 write sites in TacticalBattleUI). `lint_orphan_assets`
`orphans` back to **0**. `BattleTierController.TIER_COMPONENTS` **kept** and documented as
design data — it has zero production callers and the live gate is
`TacticalBattleUI._apply_tier_visibility()`. Full reasoning in
[WIRING_CLEANUP_BACKLOG.md](WIRING_CLEANUP_BACKLOG.md).

### Open

- **Nothing from T10.** All 11 are closed on hardware — ledger deploy #16.

- **All six T11 findings from deploy #17 are resolved or parked**, and **T11-07/08/09/11/12
  are now WALKED ON HARDWARE** at deploy #19 (2026-09-05) — ledger
  [TABLET_QA_SPRINT_2026-08.md](qa/TABLET_QA_SPRINT_2026-08.md) § deploy #19. T11-10's
  billing half is **parked by owner decision** pending the LOI; it is not a gap.

- **T11-13 (MED)** — ✅ **FOUND AND FIXED 2026-09-05 (deploy #19 walk).** A Standard-method
  crew with two Bots was detected correctly — the device log carried
  `Standard Method: at most 1 Bot (p.13) - have 2`, right rule and right cite — and the
  player was shown **nothing**: `advance_to_next_phase()` sent every non-blocking warning
  to `push_warning()` and advanced. The wizard was indistinguishable from one that never
  checked. Non-blocking is deliberate (a half-finished crew passes through
  illegal-looking intermediate states), so the fix is display only: `phase_warnings` is
  emitted on **every** advance — empty when clean, so a stale notice clears — relayed by
  the coordinator, and rendered as an amber list in the wizard header. 3 cases, each
  detection-proven by isolated revert, the relay separately from the emit.

- **T11-14 (LOW-MED)** — ✅ **FOUND AND FIXED 2026-09-05 (deploy #19 walk).** The character
  editor showed a background the character does not have.
  `CharacterCreator._find_item_by_value()` matched a stored enum KEY against the dropdown's
  DISPLAY LABEL and returned **index 0** on no match; 3 of the 25 book backgrounds keep the
  book's wording while the enum member is abbreviated, so they displayed
  *"Peaceful High Tech Colony"*. Display-only (verified: `select()` emits no
  `item_selected`, and Confirm re-reads no dropdown), but a **valid-looking wrong answer**
  is exactly the kind that gets believed. Fixed by comparing key to key through the same
  `GlobalEnums.to_string_value()` the write path uses; labels untouched because they are
  the book's names. 4 cases, detection-proven.
- **T11-09 (MED)** — ✅ **FIXED 2026-09-05 (desk).** The p.13 crew-creation method
  was not applied: Standard + crew size 4 produced **two Bots** (p.13 allows one), with
  **no warning** and **Next enabled**.

  **Root cause.** `CampaignCreationCoordinator.update_campaign_config_state()` is a
  WHITELIST, and it did not name `crew_creation_method` — the coordinator did not
  mention the key **anywhere**. The picker wrote it into `local_campaign_config`, the
  panel emitted the whole dictionary, and the value died at that filter. Both consumers
  then read their `"miniatures"` default, which permits any mix:
  `CampaignCreationUI._push_campaign_crew_size()` → `CrewPanel` (no coercion), and
  `state_manager.campaign_data["config"]` → `_validate_crew_with_warnings()` (no
  warning). **One missing line, both halves of the feature inert.**

  ⚠ **My prime suspect was WRONG, and it is recorded rather than quietly dropped.**
  The device report named the `if panel.has_method("apply_crew_creation_method")` guard
  in `CampaignCreationUI` as the likely dead-guard. It is not dead:
  `CrewPanel.apply_crew_creation_method()` exists at `CrewPanel.gd:239` and the guard
  passes. Reaching for the trap this codebase has been bitten by six times cost a
  detour; the actual defect was the whitelist three lines above, whose own comment
  already warns that *"a key the panel collects and this list does not name is silently
  dropped"* — the shape that had already eaten Progressive Difficulty,
  `narrative_wrap_override`, `difficulty_toggles` and `house_rules`. **This key was its
  fourth victim, and the comment did not prevent the fifth because a comment is not a
  test.**

  **Pinned by 4 new cases** in `tests/unit/test_crew_creation_methods.gd` (21 total)
  that assert the PROPAGATION, not the rule: the unified state carries the choice, the
  state manager's config carries it, an illegal Standard crew is reported at the live
  gate, and the same crew is legal under Miniatures (both directions, so the case cannot
  pass for a validator that rejects two Bots under every method).
  **Detection-proven by isolated revert**: 21/0 becomes 18 cases / 1 failure, and the
  device symptom reproduces exactly — *"Warnings were:"* followed by nothing.
  ⚠ All **17 pre-existing SSOT cases still passed with the defect live**, which is
  the whole reason the new cases exercise the wiring.
- **T11-10** — ✅ **REVIEW HALF FIXED 2026-09-05 (desk), verified in the dex.**
  ⚠ **BILLING HALF STILL OPEN — blocked on an artifact that is not in this repo.**

  ⚠ **CORRECTION to the deploy #17 finding.** It said the fault was that *"there is
  no `android/plugins/` directory, which is where Godot 4 expects the `.gdap` + AAR"*.
  That is the **v1** plugin mechanism. Godot 4.6's own docs are explicit that *"the gdap
  packaging and configuration mechanism has been **deprecated** in favour of the existing
  Godot `EditorExportPlugin` packaging format"* (Context7,
  `tutorials/platform/android/android_plugin.html`). There should be **no**
  `android/plugins/` directory and **no** `.gdap` file. The observation (plugins missing
  from the dex) was right; the diagnosis was one engine major behind.

  **Actual cause, two stacked, either fatal alone:**
  1. `addons/InappReviewPlugin/` is a correct v2 `EditorPlugin` whose `AndroidExportPlugin`
     contributes the AAR and the Gradle dependencies — but it was **not in
     `project.godot`'s `[editor_plugins] enabled` list**. An `EditorPlugin` that is never
     enabled never runs `_enter_tree()`, so `add_export_plugin()` never fires and nothing
     is contributed. Silent: the export succeeded and simply omitted the plugin.
  2. With it enabled the export **failed loudly**, which is how the second cause surfaced:
     `_get_android_libraries()` resolves `InappReviewPlugin/bin/<cfg>/*.aar` relative to
     `addons/`, while the AARs sat at the **project root** `InappReviewPlugin/bin/` —
     the v1 layout, which CLAUDE.md documents as deliberate. Copied to
     `addons/InappReviewPlugin/bin/`.

  **Verified on the artifact, not the config** (SOP: read the artifact back). Debug APK
  re-exported, 61.9 MB / 2,639 entries (deploy #17 was 57.1 MB / 2,285):

  | probe | deploy #17 | now |
  |---|---|---|
  | `InappReview` | MISSING | **FOUND** |
  | `org/godotengine/plugin/inappreview` | MISSING | **FOUND** |
  | `com/google/android/play/core/review` | MISSING | **FOUND** |
  | `BillingClient` / `GodotGooglePlayBilling` | MISSING | **MISSING** |
  | controls (`org/godotengine`, `GodotPlugin`, `reptarus`) | FOUND | FOUND |

  ⏸ **BILLING HALF PARKED BY OWNER DECISION (2026-09-05) — NOT a blocker, and not a
  defect.** The user is holding all store-billing work until the Modiphius LOI is signed
  on their letterhead, and Modiphius is currently slow to return it. Nothing about
  billing is to be chased, wired, or re-raised as an open finding until that lands.
  The goal in the meantime is that everything ELSE is device-verified and ready, so the
  billing work is the only thing left when the LOI arrives. Re-reading this row later:
  it is **deliberate scope**, in the same category as the seven legal placeholders, not
  an oversight. Checklist section 5 stays unpassed **by design** rather than by omission.

  **The Billing half cannot be fixed at the desk anyway.** `AndroidStoreAdapter.gd:23` needs
  `ClassDB.class_exists(&"BillingClient")`, which comes from **GodotGooglePlayBilling** —
  and that plugin is **nowhere in the repo**: not in `addons/`, no AAR, no source. The only
  Billing AAR on disk is `AndroidIAPP-{debug,release}.aar` at the project root, which is the
  **third-party plugin CLAUDE.md records as REPLACED** by the official one in Phase 34;
  wiring it would expose a different class and would not satisfy the adapter. Closing this
  needs the official plugin fetched and added — a new binary dependency, which is the
  user's call, not a config change. `StoreManager` → `OfflineStoreAdapter` until then.
  Checklist section 5 stays unpassed. **`ReviewManager` should now work on device —
  needs the deploy #18 walk to confirm.**

  ⚠ **THIRD ISSUE, FOUND WHILE FIXING THIS, NEEDS A USER DECISION: the plugin AARs are
  NOT IN GIT.** `.gitignore:37` is a blanket `*.aar`, so nothing under
  `addons/InappReviewPlugin/bin/` or the root `InappReviewPlugin/bin/` is tracked —
  `git ls-files InappReviewPlugin/` returns the `.gd`, `.uid`, `icon.png` and
  `plugin.cfg`, and no binary. **The fix above therefore works on this machine and would
  fail on a fresh clone or on CI**, with exactly the Gradle error it was just debugged
  from: *"Transform's input file does not exist"*.

  The rule is not wrong in general — it correctly ignores `godot-lib.template_*.aar`
  and everything under `android/build/`, which are build OUTPUTS. These two are build
  INPUTS (4.5 KB + 4.3 KB) and the build cannot be reproduced without them.

  ✅ **RESOLVED 2026-09-05 — user chose to track them.** `.gitignore` keeps the blanket
  `*.aar` and adds two negations directly beneath it, with the input-vs-output reasoning
  at the site:

  ```
  !addons/InappReviewPlugin/bin/debug/*.aar
  !addons/InappReviewPlugin/bin/release/*.aar
  ```

  Verified with `git check-ignore -v`: the `addons/` copies now resolve to the negation
  and the **root-level `InappReviewPlugin/bin/` stays ignored**, which is correct —
  Godot 4 resolves `_get_android_libraries()` paths relative to `addons/`, so the root
  copy is the deprecated v1 layout and is vestigial. Staged (8.9 KB, 2 files) for the
  user to commit.

  ⚠ The same question will apply to the Google Play Billing AAR whenever it is added.
- **T11-08 (LOW)** — ✅ **FIXED 2026-09-05.** The crew-creation card said "how your
  **six** crew are chosen"; crew size is 4/5/6 (p.63) and is chosen in the card directly
  above it, so the number was wrong on two of the three settings. The count is gone
  rather than made dynamic — p.13 says "6 crew figures" only because it predates the
  reduced-crew clause it then cross-references; the method applies at every size.
- **T11-11** — ✅ **FIXED 2026-09-05, and it was SYSTEMIC, not one debug screen.**
  Filed as "the QA dialog's keyboard covers Queue Roll". The cause is that **Godot gives
  every `Window` its own `Viewport`, and `gui_focus_changed` is a Viewport signal**, while
  `KeyboardAvoidance._ready()` connected to `get_tree().root` alone. So soft-keyboard
  avoidance was blind to **all 15 `extends Window` subclasses in `src/`** — three of
  which take text input, and **two of those are player-facing**: `BugReportDialog` and
  `CustomVictoryDialog`. Only the third was noticed, on a debug screen, by luck.

  **Two independent causes, either fatal alone** (the shape this project keeps meeting):
  1. the focus signal never arrived; and
  2. `CustomVictoryDialog` and `QAScenarioDialog` build a plain VBox with **no
     ScrollContainer**, so even once it arrived the scroll strategy had nothing to move
     and returned having done nothing. (`BugReportDialog` has one, so cause 1 alone
     explains it — fixing either half alone would have left two of three broken.)

  **Fix, all in the SSOT autoload.** Windows are hooked via `node_added`, so it is
  **order-independent** — no dialog has to remember to register, which is the failure
  mode that has already bitten twice here. `_apply_avoidance()` now measures the
  **control's** viewport rather than the autoload's (for a field in a `Window` those are
  two different rects). Where there is no scrollable ancestor the **Window itself is
  moved**, capturing its original Y once so tabbing between fields cannot stack shift on
  shift and walk the dialog off-screen, and restoring it wherever the spacer is cleared.
  **6 new cases** in `test_keyboard_avoidance.gd` (32 total). ⚠ All **20 pre-existing
  cases live in the root viewport and passed throughout**.
- **T11-12 (LOW/UX)** — ✅ **CaptainPanel FIXED 2026-09-05; CrewPanel is NOT a defect.**
  `CaptainPanel.tscn`'s `CaptainInfo` is a `VBoxContainer` with
  `size_flags_vertical = 3` (EXPAND_FILL) wrapping **one short Label**, so it absorbed all
  remaining height and pinned the button row to the bottom of an ~800 px void — exactly
  the reported gap. Fixed with `alignment = 1`, which centres the content vertically; the
  expand is kept because it is correct once a real captain card is present.
  ⚠ **CrewPanel was reported with it and is left alone on purpose.** Its `ItemList`
  expands because a crew list should grow with the roster; looking empty at 3 of 6 crew
  is the list doing its job, not dead space. Changing it would trade a cosmetic complaint
  for a real one at full crew.
  `verify_layout` re-run after the change: **168 passed / 0 failed**.
- **Deploy #14 leftover CLOSED** — enemy-drawer touch-drag in landscape scrolls correctly.
- **Workstream B seam verified on hardware** — the debug forced-roll queue works and
  reports its pending state. ⚠ Corrected 2026-09-06: of the three, **T9-51** closed on
  #21/#22 and **T9-48** on #23 (forced through this very seam); only **T9-47** still needs
  a walk.
- **T11-07 (MED)** — ✅ **ROOT-CAUSED AND FIXED 2026-09-05, confirmed on hardware.**

  **It was never a rotation bug and never screen-local.** `SettingsManager._apply_ui_scale()`
  multiplied the global `content_scale_factor` by the display density, which
  **double-counts**. `stretch_cancel` exactly cancels the engine's square-base stretch, so
  the algebra collapses to `effective = TARGET_EFFECTIVE * ui_scale * dpi` — and
  `TARGET_EFFECTIVE` (1.16) is *already* the final effective scale, documented at the site
  as "verified layout-safe". On any 2.0-density Android device the app rendered at **2.32x
  instead of 1.16x**.

  **Instrumented and measured on the tablet (deploy #18):**

  ```
  boot          win=2560x1600 short=1600 dpi=1.000 -> content_scale=0.7830
  first resize  win=1600x2560 short=1600 dpi=2.000 -> content_scale=1.5660
  ```

  `short_axis` is **1600 in both orientations**, so the stretch term never moves and the
  entire 2.0x jump is the density term.

  **Visual proof, same screen and same orientation, one variable:** at 0.7830 the main
  menu is correct — all 10 buttons visible, nothing clipped. At 1.5660 the title wraps
  and overflows, **"Settings" is pushed off-screen entirely**, the intro card is clipped
  mid-sentence and the footer overlaps the buttons.

  ⚠ **AN AUTOLOAD ORDERING ACCIDENT MASKED IT, which is why it read as a rotation
  bug.** `SettingsManager` is autoload **#2**; `ResponsiveManager` is **#24**. At
  `_ready()` the RM node does not exist and Android has not yet reported its density, so
  `_dpi_scale()` returned 1.0 and **the app booted correct by accident**. The first resize
  supplied the real 2.0 and broke it until relaunch.

  ⚠ **This retro-explains every control that made the old hypothesis look wrong.** The
  jump happens ONCE, on the first resize after launch. Every "rotate out and back" control
  — battle screen, dashboard, main menu — rotated an app that had *already* taken it,
  so both captures sat at 1.5660 and differed by 0 px. The controls were sound; they all
  ran past the transition. **"The dashboard is immune" was false**: the main menu is
  visibly broken at 1.5660, which is what finally settled this.

  ⚠ **TWO WRONG DIAGNOSES ARE RECORDED HERE ON PURPOSE, both mine.** (1) The deploy #17
  note blamed a transient `ResponsiveManager` reading; disproved by arithmetic (its ladder
  caps at 1.53x against a 1.8-2.4x symptom) and by a probe showing it self-consistent
  through every sequence. (2) The desk pass then blamed `stretch_cancel` reading a
  transient window size; the device shows `short=1600` on **every** line, so that was
  wrong too — the instrumentation printed all the inputs, which is the only reason the
  real term was visible at all.

  ⚠ **AND THE FIRST FIX WAS BACKWARDS.** I first wrote a "resettle" that re-applies the
  scale once the density is knowable — which makes **1.5660 permanent**, shipping the
  defect as the default. It was caught only because the reported symptom ("too large")
  contradicted the direction the formula's own comments implied. **When a formula and the
  observed symptom disagree about which value is correct, the device decides.** Removed;
  do not re-add it.

  **The fix** is one term: the density factor is gone from the multiplication.
  `_dpi_scale()` is kept (unused by this formula) because ResponsiveManager's breakpoint
  classification legitimately divides by the same value. Desktop is unaffected (dpi is 1.0
  there), and every Android density now behaves like the states that were verified good.
  ⚠ **Cross-density consequence to be aware of:** physical text size now varies a little
  with density instead of being multiplied by it. That is the behaviour the tablet
  screenshots endorse; if a much lower-density device later reads small, raise
  `TARGET_EFFECTIVE` or the user's ui_scale — do NOT reinstate the density term.

  Verification on deploy #19 pending: boot and post-rotation `content_scale` must be
  **identical**, and the main menu must survive a rotation unchanged.
- **superseded deploy #17 note follows**
- **T11-07 (MED, NEW — tablet deploy #17, 2026-09-05)** — **`TacticalBattleUI` text
  renders ~1.8-2x too large and the content clips off the top and bottom**, persisting
  until the app is restarted (it survives further rotations and a background/resume).
  ⚠ Not a zoom: buttons keep their width and grow ~2.4x in height, because width is
  container-driven and height is font-driven.
  **Deterministic repro:** in a battle, issue ANY extra settings write immediately before
  a rotation — even a no-op one — then rotate out and back. Reproduced twice at 0.4% /
  0.5% pixel difference from the original observation, against 85.7% from a clean screen.
  Removing that single no-op line makes the identical sequence **0 px** different.
  **Eight controls, each one variable:** rotation alone, rapid double rotation, drawer
  open, HOME+resume, PDF export in the path, dashboard rotation, main-menu rotation, and
  the auto-rotate toggle with no rotation — **all 0 px**. Only "a config change
  immediately before a rotation" reproduces.
  ⚠ **Do not downgrade this as an adb artifact.** A single clean adb rotation is *less*
  realistic than hardware, which delivers several config updates per physical turn — the
  passing case is the artificial one.
  **Not caused by the T11-05 fix** (that code runs only when `overlay_center.visible`;
  this repro opens no overlay). Hypothesis, unconfirmed, in the deploy #17 ledger entry —
  it does not yet explain why the dashboard is immune, so confirm before acting on it.
  `verify_rotation` applies one size change per step and is structurally blind to this.
- **T11-06 device leg** — ✅ **PASS on tablet deploy #17.** All three sheets render with
  values under their captions and no overlaps; **Save PDF** through the Android-only
  `godotpdf` backend produced a 1-page 792x612 pt file with **329 extractable characters**
  and all expected values, so the searchable text layer survived the subtree-walk change
  on the path desktop never exercises.
  ⚠ **T11-04, T11-05 and T11-06's overlap fix are NOT verifiable on this tablet** — all
  three bind below ~851 design px and the device is 800 dp even in portrait. Recorded as
  not-verified-here rather than as passes.
- **T11-01 (MED)** — ✅ **FIXED at the desk 2026-09-04, awaiting the device walk.** Two
  stacked defects: `ShortScreenScroll` gated on `viewport.height < 620` and a tablet in
  landscape has a **design** height of 689, so the scroll stayed DISABLED and propagated
  its child's minimum (root `MarginContainer` +196.7 px, `grow_vertical = 2` so it grew
  both ways); and `PreBattleUI` passed `pinned_trailing = 0`, putting the footer inside
  the scroll. The byte-identical swipes were correct — the scroll was disabled, not
  exhausted. Gate now measures FIT, footer is pinned outside. `tests/unit/test_short_screen_scroll.gd`
  (7 cases) + 3 isolated detection proofs. **Must still be walked on hardware at deploy #17.**
- **NEW (harness)** — `verify_layout.gd` measured the right SIZE and the wrong SCREEN: it
  never populated screens whose data comes from their navigator, so PreBattle was measured
  with four EMPTY panes at every size. It now has a per-screen `POPULATE` hook; populated,
  it reproduces T11-01 on the first run. It immediately found a second real defect —
  Compendium filter tabs 46.4dp against the 48dp floor (**fixed**).
- **T11-03 (LOW, new)** — the sweep's remaining red is `PrintSheetScreen` at phone
  landscape and small phone (93 anchored-sibling overlaps). PRE-EXISTING and unchanged by
  the above; the sheet is an anchored-coordinate manifest layout, so it is its own triage.
- **T11-02 (LOW)** — ✅ **FIXED at the desk 2026-09-04.** The panel framed the same
  check two ways in one frame: `_update_probability()` shows the RAW die against a
  reduced threshold ("Need 8+ on 2D6"), `_display_result()` showed the MODIFIED total
  against the fixed target ("Total: 7 vs 10"). Identical tests
  (`roll >= target - savvy - mods` is `roll + savvy + mods >= target`), outcome always
  correct, but the player had to do the algebra. The result line now prints the
  threshold the pre-roll label promised, **derived from that result** rather than
  re-queried — `calculate_required_roll()` reads CURRENT modifiers, which can differ
  from the ones the roll was made under. Pinned by a new case in
  `test_seize_initiative_system.gd` asserting the identity across the whole 2D6 range
  and a spread of savvy/modifier combinations.
- **T11-04 (MED)** — ✅ **ROOT-CAUSED AND FIXED at the desk 2026-09-04.**
  **SettingsScreen did not fit a phone in portrait**: its root MarginContainer demanded
  636.0 design px against a 338.79 px viewport, putting **297.2 px of every settings row
  off the right edge**. Three stacked width drivers, each exposed only once the one above
  it was removed:
  1. `AccessibilitySettingsPanel._setup_ui()` set `custom_minimum_size = Vector2(600, 400)`.
     The panel has ONE consumer, which adds it with `SIZE_EXPAND_FILL`, so the floor
     bought nothing and could only ever block. **297.2 px → 24.7 px.**
  2. The accessibility theme `OptionButton` reported its longest item
     ("Deuteranopia (Red-Green Colorblind)") as a **297 px** minimum. Fixed with
     `clip_text` + `OVERRUN_TRIM_ELLIPSIS` — the codebase's own answer to this shape
     (`CharacterCard.gd:231-241`, whose comment describes the identical defect). The item
     names are the accessibility conditions themselves and must stay accurate.
     **24.7 px → 3.7 px.**
  3. `SettingsScreen._add_toggle_row()` wrapped the row DESCRIPTION (:881) but not the row
     TITLE, so every row demanded its title's full unwrapped width ("Share Anonymous Usage
     Data" = 184 px, beside a ~70 px CheckButton). **3.7 px → clean.**

  **Why a hard floor propagated that far.** The settings content sits in a ScrollContainer
  whose **horizontal** axis is `SCROLL_MODE_DISABLED` — correct, a settings page must not
  scroll sideways — and a disabled axis makes a ScrollContainer **propagate** its child's
  minimum on that axis instead of absorbing it. That is **the T11-01 mechanism one axis
  over**. Measured chain: 600 → ScrollContainer 608 → VBox 608 → root MarginContainer 636.

  **Why the two sweeps disagreed** (recorded here yesterday as unexplained).
  `SettingsScreen._enter_tree()` restores `user://window.ini` and applies its saved size
  (`SettingsScreen.gd:127-129`); `_exit_tree()` writes the current size back. Because
  `verify_layout.gd` builds a fresh instance per size, the screen **snapped the window to
  whatever size the PREVIOUS configuration had saved** before every measurement — six
  measurements, none at the size requested, all reported as passes.
  `verify_rotation.gd` builds once and re-applies a size per step, which overwrites the
  restore, so it measured the truth. **The screen had effectively opted itself out of the
  layout sweep.** Harness fixed: `verify_layout` now detects the hijack and **frees and
  rebuilds** the screen at the requested size. Rebuilding, not merely re-resizing, is what
  makes the reading trustworthy — font sizes come from `ResponsiveManager` and are baked in
  at build time, so a screen built at 1920x1080 and shrunk measures differently from one
  built small. ⚠ Two "findings" produced by the re-resize-only version of the fix (Labels
  needing 379 px and 321 px) **vanished** under the rebuild: they were desktop fonts
  measured against a phone width, i.e. harness artifacts, and were one step from being
  fixed as defects.

  Pinned by `tests/unit/test_settings_screen_fits_a_phone.gd` (4 cases, each
  detection-proven). ⚠ That suite guards **gross** regressions only, and says so in its own
  header: it pins ResponsiveManager to MOBILE but cannot control the gdUnit4 window, so the
  page gutter stays desktop-width and a 3.7 px overflow is invisible to it — **proven** by
  reverting driver 3 and watching the suite stay green. `verify_layout.gd` is the authority
  for marginal overflow. Repro tool: `tests/tools/probe_settings_width.gd` (three
  one-variable arms plus a min-width spine tracer that names the driving node in one line).
- **T11-05 (MED)** — ✅ **FIXED 2026-09-04, and the earlier triage of it was WRONG.**
  It was filed as "order-dependent contamination, deliberately not a defect" because an
  isolated probe came back clean. It reproduces in isolation as soon as the overlay is
  actually visible: **`TacticalBattleUI`'s modal overlay keeps a stale width across a
  rotation.** `_overlay_width()` clamps correctly to the viewport but was only ever
  called at BUILD time, at four sizing sites. Open an overlay in landscape (733 design
  px, so the clamp returns the full 560 cap), rotate to portrait (338.79), and that 560
  is stale — and `OverlayCenter` is a full-rect `CenterContainer` with
  `grow_horizontal = GROW_DIRECTION_BOTH`, so it grows in BOTH directions and the overlay
  lands at **x = -114.6**: 114.6 px off the left edge, the same off the right, buttons
  unreachable on either side. Measured:
  `OverlayCenter min (568.0, 306.8) rect [P: (-114.6035, 0.0), S: (568.0, 733.4)]`.
  **Same shape as T11-01 and T11-04** — a value baked at build time, invisible to any
  build-once measurement. Fixed by recording each site's cap on the node and re-fitting
  from `_apply_responsive_layout()`, which already re-fit the side panels and the
  portrait rails on every resize and simply never included the overlay. The cap is stored
  PER NODE because it is not uniform (the enemy-generation wizard uses 700, everything
  else 560), so a blanket re-apply would have shrunk the wizard on desktop. Pinned by two
  cases in `test_tactical_battle_responsive.gd` that drive `_apply_responsive_layout()`
  rather than the helper — the helper was never missing, the CALL was — and
  detection-proven by removing the wiring.
> ⏸ **ONE GATE OUTSTANDING (2026-09-05, close of desk work):** the full `tests/unit`
> batched run has NOT been re-run since the T11-06 fix. Everything else below is
> verified — 3 sheet suites (55 cases), both sweeps, all 11 lints, both PDF backends,
> all 3 PNG exports. Run it first thing:
> `bash` a batched runner over `tests/unit/*.gd` in groups of **<=38** (the whole
> directory segfaults at ~58 suites started, on unmodified HEAD too). Expect ~3,100
> cases; read the CASE COUNT, not the exit code.

- **T11-06 (LOW)** — ✅ **FIXED 2026-09-05.** **PrintSheetScreen field overlaps at the
  two smallest configs.** The layout sweep reported ~134 "drawn ON TOP OF" findings at
  phone landscape and small phone, and none at tablet or desktop. `verify_layout` is now
  **168 passed / 0 failed** — green for the first time.

  **Root cause, MEASURED** (`tests/tools/probe_label_min_cache.gd`, five cases):
  `add_theme_font_size_override()` **invalidates a Control's minimum-size cache but does
  not recompute it** — the recomputation is deferred to the next frame. So the very next
  line, `node.size = rect`, is clamped up to the **previous font's** line height. The
  probe reads the same node three times and shows it directly: immediately after the
  override the minimum still reports `(64.0, 21.0)`, byte-identical to a node that never
  received an override at all; a frame later it reports `(20.0, 7.0)`, but nothing
  re-assigns the size.

  ⚠ **Reordering cannot fix this, and neither can rebuilding.** Cases D and E of the
  probe configure a brand-new, never-laid-out Label — before it enters the tree, and
  after — and both still clamp, because a node's FIRST minimum is computed with the
  theme's DEFAULT font. Every field Label was therefore **a flat 21 px tall at every
  display scale**, on every sheet, since the overlay was written.

  **The fix** removes the dependency instead of fighting it: field nodes are positioned
  and sized in **SOURCE (2764x1843) pixels** with their **manifest** font size, under a
  new `FieldLayer` whose transform carries the display scale. Nothing per-node is scaled,
  no font is ever changed after creation, and the clamp can now bind only where a
  manifest box is genuinely shorter than its own line height at source scale — measured:
  **0 of 211 fields across all three sheets**. Pinned by three cases in
  `test_sheet_renderer.gd`; detection-proven by restoring the original file, which fails
  the rect case by **644 px** and the overlap case with **381 colliding pairs**.

  It also makes the preview and the export the **same layout**: the export clone is set
  to the source size, where the layer's scale is exactly 1.0 and its offset 0.

  ⚠ **Two corrections to this row's earlier text, kept rather than deleted so nobody
  re-derives them.** (1) It reported "display WIDTHS scale correctly (0.15231) while
  HEIGHTS do not, by no consistent factor (36 → 28.0, 49 → 36.0, 84 → 52.0)". The
  heights were not varying by an unknown factor — they were a **constant 21 px**, and the
  varying numbers came from mixing node types in one sample. (2) The `ScreenChrome`
  font-floor fix that took the count 134 → 49 was real and is retained, but it was
  treating a symptom: the floor made the clamped height *bind more often*, it did not
  cause it. The font-before-size ordering change carried an honesty note saying it moved
  the count by zero — that note was correct, and this is why.

  **Verified on the artifact, not the preview** (`docs/sop/sheet-export.md`): all three
  sheets export at 2764x1843 with `err=0`; the crew rows render name / species / all six
  stats each under their own caption; both PDF backends round-trip through PyPDF2 at
  **323 and 324 extractable characters**, matching the SOP's recorded 322-325 baseline,
  so the invisible searchable layer survived the tree-walk change.
- **NEW (harness, 2026-09-04)** — `verify_rotation.gd` was **structurally blind to
  T11-01's entire defect class.** Its overflow check carried `and not _is_backdrop(r, ds)`,
  an AREA test (>= 80% of the design area) borrowed from `verify_layout`'s
  OVERLAY-COLLISION check, where it is correct — a full-screen background merely SPANS
  the corner the gear buttons sit in. It is the wrong question for overflow: a backdrop
  legitimately spans the screen, it does not legitimately extend 196 px PAST it, and a
  node overflowing vertically has a LARGER area so it was **guaranteed** to be filtered.
  Proven: with the T11-01 gate reverted and screens populated, the sweep still reported
  23/23 PASS; with the clause removed it reports the 3 PreBattle findings. Both sweeps
  now share `tests/tools/screen_populator.gd`.
- The Aug 8-14 sprint is still ⏸ PAUSED — see the section below.

---

## 🟡 § Tablet QA on real hardware (Aug 8-14 2026) — ⏸ PAUSED at a clean stopping point

**▶ Pick up here: [qa/PICKUP_2026-08-14.md](qa/PICKUP_2026-08-14.md)** — read before
touching this work again.
**Ledger: [qa/TABLET_QA_SPRINT_2026-08.md](qa/TABLET_QA_SPRINT_2026-08.md)** (5,740
lines, append-only, one section per deploy). Device: Lenovo TB361FU. Branch
`campaign-editor-and-fixits`, **committed through `d6fe7b962`** (all fixes, their tests, and
the ledger through deploy #13b).

⚠ **This supersedes the "Tablet-test / APK gate: clear" row below**, which was written
on Aug 7 before any real device had run the build. It was never a device result.

| Gate | State |
|---|---|
| Suites touched this sprint | **all green** |
| Six gating lints | **all exit 0** |
| `lint_orphan_assets` | `orphans=0`, `test_only=40` (tier-7 backlog) |
| Headless `--import` parse | **clean** |
| **Device verification** | **4 of 6 fixes hardware-verified** (see below) |

**Hardware-verified:** T9-50 (checkpoint keeps the accepted job across process death) ·
the `_refresh_job_offers()` back-navigation guard · T9-46b (journal records the generated
enemy, not the Rival's bogus type or "Unknown") · T9-49 (a no-win-condition Rival battle
moves neither W nor L while `missions_completed` increments, and the journal reads
"Held The Field").

**Desk-verified only** — unit-verified AND detection-proven, but no in-app tool can force
the roll: T9-48's prohibition branch (Rival AMBUSH = D10 roll of 1) · T9-47 (Explore 51-53
or Trade 76-78) · T9-51 (character event D100 88-94).

⭐ **T9-50 took THREE fixes** and is the sprint's transferable lesson: a fix ordered against
SOME callers is not a fix. `grep` the callee and COUNT the call sites, or guard the callee so
order stops mattering.

### What real hardware found that the desk never could

Two full days of findings. The classes worth remembering:

- **Physically impossible to see on desktop** — soft-keyboard occlusion (no signal
  exists in Godot 4.6; you must arm on focus then POLL), touch-scroll swallowed by
  `PanelContainer`/`HSeparator` defaults, a `ScrollContainer` absorbing a squeeze
  silently so it looked like missing DATA.
- **Never exercised, because no test drove the SCREEN** — the printable sheet had
  **never received a single journal entry on any platform** (`has_method("get_entries")`,
  a method with zero definitions), and the World block was blank on every campaign
  (`world is Dictionary` against a `PlanetData` OBJECT). Every test called the builder
  directly and passed its arguments in.
- **Data loss only a real save exposes** — a legacy-save stash DOUBLED on load, and then
  my own fix for that destroyed 5 items per load until the caller ordering was corrected.

### Open

- **Deploy #6**: the two sheet fixes above are unconfirmed on hardware.
- The Encounter Log's scenario boxes need a battle fought **under the new build** —
  journal entries written before it carry no `stats` scenario keys and there is no
  backfill. Old blanks are expected, not a regression.
- ~~`scripts/lint_dead_has_method_guards.py` … needs triage before it can gate.~~
  ✅ **CLOSED — it gates, and it is clean.** Re-measured 2026-09-07: **59 total, 59
  allowlisted, 0 NEW, 0 stale**, exit 0. ⚠ The struck text was self-contradictory (it said
  both "GATING since Sep 4 2026" and "REPORT-ONLY, exits 0") and its triage was already
  done at promotion. ⭐ **59 is not 59 open defects** — the honest split is **20 platform /
  GDExtension probes** (GodotSteam 3, Google Play Billing 4, Apple StoreKit 2, libharu 11)
  where `has_method()` is the *correct* call because the class genuinely may not exist;
  **37 inert dead branches** with a live fallback beside them (32 duck-typed + 5 orphaned
  by the Sep 4 sweep) — tidy-up, never a defect fix; and **2 bookkeeping** entries. Zero
  are live bugs.

---

## ✅ § Rules-Wiring Ledger CLOSED (Aug 7 2026) — branch `campaign-editor-and-fixits`

**`docs/RULES_WIRING_AUDIT_2026-08.md`: 0 open / 0 partial / 136 fixed / 1 corrected.**
Uncommitted. Solo, no agent fan-out.

| Gate | State |
|---|---|
| Rules-wiring ledger | **0 open, 0 partial** |
| `verify_post_battle` | **47/47** |
| `verify_battle_ui` | **79/79** |
| `lint_data_ownership` / `_signal_wiring` / `_tscn_connections` / `_autoload_lookups` | **all CLEAN** |
| Headless `--import` parse | **clean** |
| Tablet-test / APK gate | ~~clear~~ — **superseded, see the tablet-QA section above.** This row meant "no known blocker on Aug 7"; no device had run the build. Real hardware found defects on Aug 8-11. |

### The last eleven rows were one defect, eleven times

Almost nothing was a missing RULE. Every closing row was a **correct,
byte-faithful implementation with no call site**:

| Module | Zero-caller accessors |
|---|---|
| `WorldTraitEffects` (the SSOT for all 31 campaign-side traits) | **11** |
| `BlackZoneSystem` | **4** — `get_setup_rules`, `get_opposition_rules`, `get_active_passive_rules`, `get_ending_rules` |
| `FactionSystem.attempt_faction_favor()` | complete, unreachable — p.112 requires a crew task nobody built |
| `PatronJobEffects` | `blocks_rival_tracking()`, `offers_new_job_on_success()` |
| `SalvageMissionPanel.get_salvage_units()` | 1 — so every salvage unit died with the battle screen |

> **The check that finds this whole class in one pass:** for a resolver or service
> module, enumerate its public accessors and grep each for an EXTERNAL caller.
> `test_every_world_trait_accessor_has_a_live_consumer` does exactly that and now
> fails if a new accessor is added without one. Worth copying to any other
> rules-resolver module.

### Two traps worth carrying into future QA

- **A displayed number that exists nowhere else is a lie waiting to be found.**
  The Black Job prep card printed a hardcoded `"4 teams of 4 (16 initial enemies)"`
  — the only place those numbers appeared anywhere in the app. The generator rolled
  an ordinary 3-8. The card described a battle that was never generated. Any UI
  literal describing a mechanic should READ the same data the mechanic does.
- **Check the price you charge against the price you check.** Weapon Licensing
  (+1cr, p.74) made the Military table roll cost 4 while the affordability guard
  still read the base 3 — a 3-credit crew could add an item they could not pay for.

### A containment assertion is not evidence — third occurrence

Reverting a fix to `if false and SomeService.some_call(` **passed** an assertion
written as `assert_str(src).contains("SomeService.some_call(")`. Three times in
this one audit a `contains()` check survived the call being disabled. Anchor
source scans on the exact ENABLING form, and always run the mutation — a plausible
revert that changes nothing is how a dead control survives. (My first teeth-proof
for the rival-removal control hardcoded a flag the loop does not even read.)

> **Read the zero correctly.** It means every row someone wrote down has a call
> site and a test. Eight auditors walked eight subsystems; nobody walked every page
> of both books. The guard going forward is the four lints plus the per-row tests,
> never this count.

New suites: `test_final_open_rows.gd` (33), `test_final_partial_rows.gd` (23),
`test_faction_favors.gd` (16). Every fix detection-proven by isolated revert.

---

## § Battle-Phase DELIVERY Audit (Aug 6 2026) — branch `campaign-editor-and-fixits`

Commits `740db7e36`, `0f10cbfcd`, `e32445c9b`, `dbc33c70a`. Solo, no agent fan-out.

**The framing that produced everything below.** Prior audits asked *"is this rule
implemented correctly?"* and the answer was almost always yes — every table checked
was byte-exact against the PDF. This one asked *"does the player ever reach it?"*
and found four Compendium chapters that could not be opened in a real campaign.

> **The generalization, which held five separate times in one day:**
> when a rule appears missing, check whether a function implementing it already
> exists **with no caller**. Early return above the call · called before its target
> existed · container with no opener · zero-caller producer ×2.

### Defects found and fixed

| Finding | Severity | Detail |
|---|---|---|
| **Four Compendium chapters unreachable in campaign play** | **P0** | No-Minis (pp.66-73), Stealth (pp.117-122), Street Fights (pp.123-136), Salvage (pp.137-147). `initialize_battle` early-returned whenever `selected_tier` was stamped, and `CampaignTurnController` stamps it on EVERY campaign battle — so the four `_setup_*_panel` calls at the tail never ran. The file **warned about this exact hazard 7 lines above the return**; four later additions landed below it anyway. Worst case is No-Minis: the mode whose entire premise is that the app hosts the fight. |
| **Populated panels in a drawer with no opener** | **P0** | On paths that DID build them, they landed in `phase_content` = the `tracking` drawer body, whose button is ASSISTED+ while the default tier is LOG_ONLY. All three routes (landscape bar, portrait `≡` menu, auto-open) were closed simultaneously, which is why it never surfaced. New dedicated `mission` drawer, offered at EVERY tier whenever a panel was actually placed there. |
| **Hold the Field scored as a WIN in Rival/Invasion battles** | **HIGH** | p.91 and p.92 both say "there is no Win condition". `no_win_condition` was computed for both and read by nothing, so seeing a Rival off paid the p.123 "Survived and Won +3" instead of "+2" and inflated `battles_won` against the p.64 victory conditions. Applied at **all four** `success` producers — two more than the sweep initially listed, including the LOG_ONLY form where the PLAYER declares the outcome and could declare a Win in a battle the book says cannot be won. |
| **Insanity campaigns earned story points** | **HIGH** | Core Rules p.65 disables them entirely. `TravelEventResolver` was the ONE award site in the codebase writing `campaign.story_points` directly instead of going through `GameStateManager`, which is where the gate lives — so pp.70-72 travel events paid out where nothing else did. Reported for weeks by `lint_data_ownership` and dismissed in `TABLET_TEST_READINESS.md` §5 as "real, small, not player-visible". |
| **Compendium p.137 salvage availability D6 had never rolled** | **HIGH** | `find_salvage_job()` held the roll and had ZERO callers repo-wide. Three rules inert at once: a job was offered EVERY campaign turn instead of five in six, the 2-credit acceptance fee was never charged, and `is_illegal` had no producer, making the "authorities on your trail" consequence unreachable. Now a real mandatory 3-option prompt at the book's position (after the post-game Rivals roll). |
| **Tracking tier locked for the whole battle** | MED | `set_tier()` had exactly one caller, passing `force = true`; `tier_badge` was a `Label`. The controller's own "cannot downgrade mid-battle" guard proves a non-forced caller was designed for and never written. Badge is now a Button; lower tiers greyed **with a reason** rather than silently no-opping into a `push_warning`. |
| **Grid movement was campaign-wide, contra p.90** | MED | "The movement system used can be changed as often as you want, with different battles using different movement systems." Every consumer gated on the DLC flag. The three ungated `build_*` functions written for the per-battle choice had zero callers. |
| **Gloomy / Invasion early-departure never recurred** | MED | Correct rules, stated once pre-battle and never at the decision point — the player deciding whether to run at round 3 was never told that leaving before round 6 makes that figure a casualty. |
| **`PostBattleSequence.gd` failed to PARSE** | **P0 (self-inflicted, caught pre-tablet)** | A new function referenced `post_battle_phase` — a local from a *different* function; the member has an underscore. GDScript treats that as a parse error, taking the whole script down, i.e. the entire post-battle wizard. **Missed by `--headless --quit`, by 2254 passing unit cases, and by `verify_post_battle` 46/46** (that harness drives the backend orchestrator and never loads the wizard UI). Only `--headless --import` found it. |
| **Toolbar rebuild duplicated itself** | LOW | `queue_free()` DEFERS to end-of-frame, so a rebuild added new buttons while old ones were still parented — 14 instead of 7. Found only by an MCP runtime probe; **invisible to all 79 harness checks because they assert the button is PRESENT, and a duplicate set still contains it.** |
| **2 orphan files deleted** | LOW | `BattlefieldManager.gd` (431 lines, density-float terrain across desert/urban/forest/space_station — contradicting the live four-book-theme generator) and `Enemy.gd` (366 lines, `extends CharacterBody2D`, sole reference a preload of itself). |

### Two harness defects — the code was right both times

Both `verify_post_battle` rows had been red for weeks and were reported as live
defects. Neither was.

- **Danger pay** — the trial built its mission as `mission_source: "opportunity"`
  and asserted Danger Pay reached credits, so it had been failing **on the fix**.
  p.120 Step 4 is verbatim *"If you did a **Patron** job, add the Pay bonus to the
  Danger Pay"*, and p.83 puts the table under *"If you received a job offer from a
  Patron."* Now uses a patron job, plus a new `danger_pay_is_patron_only` row.
- **"1 in 40 injuries costs nothing"** — instrumented rather than reasoned about:
  seed 16 rolled `MINOR_INJURY(rec=1)` correctly, then p.129 Character Event 24-26
  *"reduce your recovery time by one turn"* took 1 → 0. A legitimate heal the row's
  four fields could not express.

> **Widen the observation; never relax the assertion** — then prove the widened
> version can still fail. Forcing `apply_crew_injury` to no-op yields 35/40 caught
> with `healed_by_event=0`, so the new "this is fine" bucket does not absorb a real
> drop.

### State at close

| Check | Result |
|---|---|
| `tests/unit` | **2254/2254**, 194 suites, 0 failures |
| `verify_battle_ui` | **79/79** (grown 49 → 79 checks) |
| `verify_post_battle` | **46/46** — first fully green run |
| Parse sweep (`--headless --import`) | **0 errors** project-wide |
| `signal_wiring` / `tscn_connections` / `autoload_lookups` / `data_ownership` | **all CLEAN** |
| `lint_orphan_assets` | orphans **0** (41 test-only files remain, tracked) |
| APK | `build/fpfh-0.9.7-aug06c.apk`, verified by unzip + decompressed-bytecode content match |

Every fix was reverted once to confirm exactly its own tests fail, then restored —
breaks kept isolated, since a combined break cannot prove independence.

---

## § Pre-Tablet QA Sprint (Jul 29-30 2026) — branch `campaign-editor-and-fixits`

Scope: **A1 alpha surface only** (Bug Hunt / Planetfall / Tactics are hidden behind
`MainMenu.gd:14 A1_BUILD`). Depth on the core loop first, breadth sweep second.

**The finding that reframed the sprint.** Layout / DPI / rotation were assumed to be
blocked on the tablet arriving Aug 2. They are not — a desktop window pixel **is** a
device dp here (design space = `window_px / 1.16` on desktop and `dp / 1.16` on device;
the 1.16 falls out of `SettingsManager._apply_ui_scale()` cancelling the square-1080 base
stretch). Measured: a 393×851 window → design `338.79 × 733.42`, and `338.79 × 1.16 =
392.99998`. That unlocked the whole layout surface three days early. SOPs updated;
`docs/testing/TABLET_CHECKLIST_2026-08-02.md` now holds only genuinely device-bound items.

### Defects found and fixed

| Finding | Severity | Detail |
|---|---|---|
| **Campaign creation could not open** | **P0** | `CampaignCreationUI.gd` declared `_exit_tree()` TWICE (drifted in across `ed405ae6` + `f0905a09`). GDScript rejects a duplicate func, so the whole script failed to parse. Second, invisible victim: `test_campaign_wizard_flow` (17 cases) `preload`s it, so gdUnit4 **silently dropped the suite and still exited 0**. Case count went 1897→1914 after the fix — while 236 files were being deleted. *Check the case count, never the exit code.* |
| **`R: 0` on every crew card of every pre-existing save** | **HIGH** | `Character.to_dictionary()` already emitted both `reaction` and `reactions`, but nothing normalised saves written before that. Measured on a live save: 6/6 members had the plural, 0/6 the singular; `CampaignDashboard.gd:621` reads the singular. Fixed at the load chokepoint (`FiveParsecsCampaignCore._normalize_crew_stat_keys()`), not per-consumer. It survived because it looked *plausible* — the other five stats were the correct Core Rules p.14 baseline human. |
| **Core Rules p.121 Luck death-save never implemented** | **HIGH** | "If a character with Luck would be slain through a roll on this table, they miraculously survive, but immediately lose ALL Luck points." `InjuryProcessor`'s fatal branch went straight to `apply_crew_death()` with no Luck check — permanent character loss the book explicitly prevents. A working implementation existed but was stranded off the live path (`PostBattleProcessor.gd:186-202`, reachable only from a comment). Fixed at `PostBattleContext.apply_luck_death_save()`. |
| **`_restore_crew_luck()` — a fabricated rule, deleted** | MED | It set `luck = max_luck` (the CAP, not the character's rating), inflating every human to 3 Luck they never spent 30 XP to buy. It also could not run at all (2-arg `.get()` on a Resource silently unwinds; no Dictionary branch for the canonical crew shape) and gated on a flag nothing ever set. **Broken in a way that masked a worse bug** — naively repairing it would have introduced the violation. Deleted with a block comment at the call site. |
| **Sub-48dp touch targets — 181 → 0** | MED | Four distinct causes, each found by measuring rather than assuming. (1) `CampaignJournalScreen._make_chip()` used `TOUCH_TARGET_MIN - 12` (= 36 design px = 41.8dp) and `HelpScreen` hardcoded 36 — 129 of the 181. (2) The theme's `optionbutton_*` and `lineedit_*` styleboxes were still at 8.0 vertical padding while `button_*` had been raised to 12.0. (3) Hardcoded 40s in `ShipInventory.tscn`, `WorldPhaseController.tscn` and `UpkeepPhaseComponent`'s map button (`flat = true` removes the themed stylebox, so such a button gets *no* padding from the theme). (4) CheckBox height is icon-driven, not stylebox-driven — adding `content_margin` to `checkbox_normal` measurably did nothing, so it was reverted rather than shipped as a no-op, and the two `PrintSheetScreen` boxes were pinned explicitly. All 181 fired at **every** window size including desktop, so none was a compression artifact. |
| **Content drawn under the floating overlay buttons — 157 → 55** | MED | `SettingsOverlay` is a CanvasLayer above every screen, so full-width headers ran beneath the gear/bug buttons — obscured and untappable. Fixed with `SettingsOverlay.reserve_band_on(screen)`, which pushes content **down** using the live button geometry. It lives on the overlay because the screens needing it have three different ancestors (`CampaignScreenBase`, `FiveParsecsCampaignPanel`, plain `Control`/`Node`) — there is no single base to put it in. Two strategies: raise a wrapping `MarginContainer`'s top margin, else insert a named spacer as the first child of a vertical root container. `GalaxyLogScreen` and `CompendiumCategoryView` deliberately skip `super._ready()`, so they call it manually alongside the other base setup they already replicate. |
| **`Header` demanded 900px of height** | MED | Self-inflicted, caught by screenshot: adding `autowrap_mode` to the AdvancementManager title — a Label inside an **HFlowContainer** — made the header 900px tall, because HFlow asks an autowrapping Label for its height at its narrowest width (its longest word) and gets back the line count for the whole string. The screen overflowed at all six sizes including desktop. Replaced with `clip_text` + ellipsis + `size_flags_horizontal = 3`. This is a documented trap in project memory (`feedback_autowrap_in_hflow_trap`) that was walked into twice in one day. |
| **Unwrapped labels overflowing the design space** | MED | EULAScreen title, HelpScreen title, AdvancementManager title, DLC pack taglines. Same shape as the MainMenu title bug. 14 → 3 remaining. |
| **236 orphan files deleted** | LOW | New reachability lint `scripts/lint_orphan_assets.py`. Grep passes had said 89 — the gap was `MainCampaignScene.tscn`, referenced by nothing, keeping its script alive. *Dead scenes keep scripts alive; liveness needs a graph, not a grep.* |

### Tooling added, both proven to detect

- **`tests/tools/verify_layout.gd`** — 34 screens × 6 sizes, measuring real rects
  (off-screen, overlay-band collision, 48dp floor, unwrapped-Label minimums). Run
  **WITHOUT `--headless`**. *Detection proof*: reverting `7590c67b` reproduces the
  hand-measured MainMenu numbers exactly — `Title off-screen by 67.1 px`, `Title needs
  473px unwrapped in a 339px space`, `Title collides with the SettingsOverlay band`.
- **`verify_post_battle.gd` → 45 rows** (was 37): Luck death-save, turn rollover, save/load
  round-trip. The Luck row carries a **luck=0 control** that must still kill — without it,
  "nobody died" would pass just as happily if the injury step rolled nothing. With fix:
  `luck=1 dead=0 saved=4 | control dead=4`. Without: `luck=1 dead=4 saved=0 | control dead=4`.

### Two false-positive classes removed from the sweep (by measurement, not assumption)

1. **Backdrops.** First run reported 180 failures, 50 on a screen already proven clean at
   10 configs — sole cause was a full-screen background TextureRect "colliding" with the
   overlay band. 822 of 1129 findings were that artifact.
2. **Label boxes vs drawn text.** A full-width header Label with left-aligned text has a
   rect spanning the overlay corner while its glyphs are nowhere near it. Narrowing the
   check to the drawn text (interactive controls keep the full-rect test, since their whole
   rect is hit area) dropped 39 findings **with detection re-proven** on the reverted MainMenu.

### Layout close-out (Jul 30, second pass) — sweep now GREEN

**198 passed / 0 failed / 0 skipped**, with a real campaign loaded. Every screen on the
A1 surface fits at all six sizes, including the two hardest (phone landscape 733×338
design px and a 360dp phone at 310×551).

| Category | First clean run | Mid-sprint | Final |
|---|---|---|---|
| Sub-48dp controls | 181 | 0 | **0** |
| Overlay-band collisions | 157 | 42 | **0** |
| Off-screen overflow | 60 | 39 | **0** |
| Unwrapped labels | 14 | 3 | **0** |
| Sweep skips | 12 | 12 | **0** |

Two harness corrections came first, because the mid-sprint numbers were partly measuring
the harness rather than the app:

1. **The sweep now applies the same overlay net the app does.** In the app, SceneRouter
   emits `scene_changed` and `SettingsOverlay` reserves the band on the incoming scene; a
   sweep that `add_child()`es a screen never fires that signal, so every screen was being
   measured without a reservation the user always gets. Reproduction, not suppression —
   `reserve_band_on()` only acts where a screen's structure allows it, so a screen it
   cannot reach still collides and still fails.
2. **`SimpleCharacterCreator` was being skipped as "needs campaign state".** It sets
   `visible = false` in `_ready()` because its caller shows it. The skip message was a
   misdiagnosis that quietly took six configs out of the sweep; shown, it surfaced nine
   real findings including a dialog pinned at 800×600 that hung off the edge at **every**
   size measured, 1080p included. `MissionSelectionUI` was dropped from scope with its
   reason (all its controls live under a PopupPanel — a Window, which lays out against
   its own rect, so measuring it compared two coordinate spaces).

**Campaign state is now an explicit input**: `-- campaign=user://saves/x.save`. It used to
be whatever the machine happened to have, and that mattered more than expected — a
campaign left loaded by an earlier session made `CampaignDashboard`'s landscape overflow
read 154.8px instead of 30.6px, and revealed that the World Phase clipped on **both**
edges from turn 10 (the Red/Black Zone buttons appear then and needed 456px in a 339px
space). A NO-CAMPAIGN run is a floor, not a clean bill of health.

**The systemic cause, and the user who spotted it.** Mid-sprint feedback — *"your buttons
don't seem to be correctly resizing with the layouts"* — matched what the measurements
were converging on: **161 hardcoded width floors on buttons and dropdowns** across
`src/ui`. A button's height floor is the 48dp touch target and is real; its width floor
stops it shrinking and propagates to the top of the tree, so one `Vector2(260, 48)` made
every ancestor at least 260 wide. All 161 (≥140px) are gone.

Beyond that, the fixes reduced to four repeated shapes, now in the SOP:

- **A row that cannot wrap** — `HBoxContainer` → `HFlowContainer` (World Phase automation
  and zone rows, Galaxy Log header, store card headers, print top bar, creator buttons,
  equipment buttons, character-details equipment, PreBattle footer, six battle-simulator
  rows).
- **A label that cannot shrink** — `clip_text` + ellipsis in an HBox header, `autowrap` in
  a VBox column. Settled by measurement (`tests/tools/probe_label_min.gd`): clip takes a
  Label's minimum from 233px to 1px.
- **Content taller than the screen** — the new `ShortScreenScroll` helper, applied to
  seven screens, scrolling only while the viewport is short.
- **Too many columns for the width** — `AdaptivePanelGroup` now drops columns that do not
  fit, independent of the device breakpoint. A phone in landscape is 733 design px wide
  and lands in a wide bucket; three dashboard columns need ~900.

**Portrait gutter 4px → 8px** so content is not flush against the screen edge (12px was
tried first and left two screens 3px over; the constant carries that note).

Screens taken to zero: **all of them.** Previously listed as unresolved and now closed —
CampaignJournalScreen (collapsible "Filters (N active)" disclosure, the UX decision that
was deliberately not shipped blind mid-sprint), TacticalBattleUI (tier-panel labels
autowrap; the modal overlay scrolls), and ShipInventory (content column wrapped in a
scroll inside the .tscn, since its script is a pure factory with no `_ready()` — the
earlier "no script attached" note was wrong: it binds `ShipCreation.gd`).

### Two gate screens that were genuinely blocking

- **EULAScreen** — the consent card carried a fixed `360×400` minimum, wider than a
  phone in portrait (~339 design px) and taller than one in landscape (~338), so it hung
  154–202px off the edge with **ACCEPT unreachable**. This is the gate in front of the
  entire app. Capping the card width did nothing on its own, because
  `get_combined_minimum_size()` takes the MAX of the custom minimum and the content's own
  — and the content won: the 46-character consent checkbox label demanded ~350px
  unwrapped. Fixed by wrapping that label, deriving both minimums from the live viewport,
  dropping the decorative spacers on short viewports, and adding an outer scroll so the
  card degrades instead of clipping. Verified on-screen in both orientations.
- **PrintSheetScreen** — `EXPAND_FIT_WIDTH_PROPORTIONAL` on a tall portrait sheet PNG gave
  the preview a minimum height of width × aspect, pushing it 640–844px off the bottom; and
  the 240px action rail sat beside it in one row, so **Save PNG / Save PDF were off the
  right edge** on a phone. `EXPAND_IGNORE_SIZE` also removed a latent mismatch with the
  CV-calibrated field overlays, which already fit the page by the limiting axis.

### A third false-positive class removed: measuring before the screen settled

The sweep waited a fixed 3 frames after `add_child`. Panels populate from
`call_deferred`, ScrollContainers re-sort once their content arrives, and
`AdaptivePanelGroup` re-parents whole panes — so an early read catches transient rects.
CampaignCreationUI was reported as `StepLabel off-screen by 86.7 px` at desktop while
the **running app measured zero overflow there**. It now waits for the geometry
signature (the summed rects of every visible Control) to hold steady for three
consecutive frames, capped at 30 so a screen that never settles is still measured
rather than hanging the sweep. That removed 4 phantom findings, and detection was
re-proven afterwards on the reverted `7590c67b`.

Deciding whether a finding was real meant checking it against the **running app**, not
just the harness — that is what separated the AdvancementManager 900px header (real,
and self-inflicted) from the CampaignCreationUI overflow (harness artifact).

One data residual: the oldest save has a crew member with **neither** reaction key, so that
card still shows `R: 0`. Backfilling would mean inventing a stat value.

**Lesson worth keeping**: measuring is necessary but not sufficient. An autowrap "fix" to the
HelpScreen title measured clean and rendered the chapter name one letter per line down the
screen — only a screenshot showed it. A second attempt (padding the header to clear the
overlay) measured fine and pushed all page content off the right edge, because a content
margin raises the container's *minimum* width and that minimum propagates. Both caught by
screenshot, both reverted, final state verified visually.

---

**Last Updated**: 2026-07-30 (Pre-tablet QA sprint, layout close-out: geometry sweep **198/198 green with a campaign loaded**, up from 136/56/12. 161 hardcoded button width floors removed after user feedback that controls were not resizing; new `ShortScreenScroll` helper across 7 screens; `AdaptivePanelGroup` now drops columns that do not fit the width; portrait gutter 4→8px; sweep gained per-finding driver hints and an explicit `campaign=` input. Gates: gdUnit4 180 suites / 1919 cases / 0 failures, campaign-state harness 45/45, four lints clean + orphans=0. Prior 2026-07-06: Battle-Phase Companion sprint → Phase 4 on-device played walk surfaced + fixed 2 more bugs: **F9** drawer touch-scroll blocked the last enemy's controls, **F10** a played LOG_ONLY battle had no reachable end/objective control → added the objective-aware **Record Result** button (choice B). The on-device re-verification of F10 then surfaced FOUR device-/played-flow-only follow-ups the unit tests + `--headless` + desktop MCP all passed (**F10-b** form collapsed the hug-to-content drawer, **F10-c** missing objective section for a real campaign mission, **F10-d** Submit off-screen in the non-touch-scroll drawer, **F10-e** results drawer lingered over PostBattle) — all fixed + re-verified on-device (Test16). 5 genuine bugs fixed total (F5/F6/F8/F9/F10), 3 gaps dismissed (F1/F2/F3), 66 cases green. Prior 2026-07-02: Post-Fable fixit sprint → 129/129 suites green)

---

## § Battle Companion QA Sprint (Jul 5 2026) — comprehensiveness of the tabletop battle companion

Systematic sweep of `TacticalBattleUI` (the companion shared across all 4 modes — the app's T1 differentiator and least-tested subsystem). Rulebook values verified via PyPDF2 against the committed Core Rules/Compendium PDFs + `mission_objectives.json` SSOT; runtime findings via an MCP `run_script` + screenshot harness (drive the live scene tree by firing signals — `simulate_input` can't reach this project's Control-menu `pressed` pipeline). **Coverage matrix SSOT: `docs/testing/BATTLE_COMPANION_COVERAGE_MATRIX.md`.** Commits `8fb7c66d` + `f0b61af3`.

| Finding | Severity | Verdict | Detail |
|---|---|---|---|
| **F5** | **HIGH** | **FIXED** | Patrol objective **UNWINNABLE** — `check_completion()` required 4 markers, only 3 are ever placed (Core Rules p.90 + JSON = 3). An existing test was *locking the bug*. Fixed `MissionObjectiveSystem` + synced `BattleObjectiveTracker.COUNTER_TARGETS`. |
| **F6** | MED | **FIXED** | Move Through required 3 crew exited; rulebook p.90 + JSON = "at least 2". |
| **F8** | **HIGH** | **FIXED** | FULL_ORACLE Enemy-Actions **soft-lock** — `enemy_intent_panel` freed by the SETUP→COMBAT rebuild; passing the freed ref to the TYPED `_surface_phase_component(component: Control)` param fails the call-boundary type check → aborts `_show_enemy_actions_ui()` before building the "Enemy Actions Done" button (soft-lock) and silently drops the tier's oracle. Guard+recreate at `TacticalBattleUI.gd:2755`; runtime-verified. Invisible to unit tests + `--headless`. |
| **F9** | **HIGH** | **FIXED** | **Device-only** (tablet played walk) — the Crew/Enemy Tracker drawer won't vertical-touch-scroll; once several enemies are marked down their full-height ledger cards push the last live enemy's Mark-Down button off the viewport with no reachable control. Fix: downed figures collapse to a compact, control-free row (`_build_downed_unit_row`) so a full roster + casualties fits. Desktop mouse-wheel hid it — only on-device touch surfaced it. Regression `test_tactical_downed_unit_row.gd`. |
| **F10** | **HIGH** | **FIXED + on-device** | **Core-feature** (tablet played walk) — a PLAYED LOG_ONLY campaign battle had **no reachable way to end the battle or declare the objective**: the pre-selected-tier fast path forces COMBAT for every tier (`initialize_battle:3446`), but the LOG_ONLY loop has no victory check, no `end_battle()` caller anywhere, and no results trigger (only Auto Resolve = simulate, or Return = abandon). Fix (user choice B): keep the full companion + add an always-reachable emerald **Record Result** button → objective-aware `BattleResultsInputForm` → PostBattle. Form now makes mission **success = declared objective outcome** (p.90), not the Won/Lost proxy. The on-device re-verify then found 4 follow-ups (all fixed + re-verified, Test16): **F10-b** the form's own `SIZE_EXPAND_FILL` ScrollContainer reported ~0 min-height → the hug-to-content `SlideOverDrawer` collapsed to its 200px floor and clipped everything (drop the internal scroll; drawer owns scrolling); **F10-c** a real campaign mission stores its objective under `mission_data["objective"]` but `_init_objective_tracker` reads other keys → tracker null → objective section vanished (form reads the `"objective"` fallback); **F10-d** objective section + 6-crew roster overran the non-touch-scroll drawer → Submit off-screen (tighten spacing to fit the viewport); **F10-e** the results drawer lingered over the PostBattle sequence (`.close()` it in `_on_log_only_results_submitted` before the hand-off). Full end-to-end confirmed on-device (Eliminate + Deliver): Record Result → objective form → Submit → clean PostBattle Step 14 → Cycle Summary 5W/0L → Turn 5. Regression `test_battle_results_input_form.gd` (8, incl. collapse + objective-fallback). |
| F2 | — | Dismissed | Feral ignores per-opponent-type penalties (Alert −1), NOT the category-level −1 Hired Muscle. Code correct (p.112). |
| F3 | — | Dismissed | Motion Tracker / Multi-wave scanner +1 seize modifiers are real Compendium p.26 items (only the page-cite is off). |
| F1 | — | Dismissed | ACCESS/ELIMINATE/SECURE are player-driven by design (manual VictoryProgressPanel toggle, like FIGHT_OFF) — the app can't see their physical-table win states. Already tested. |
| F4/F7 | LOW | **CLOSED 2026-09-04** | **Already fixed; this row was stale.** Re-verified every cite against the committed PDF (Core Rules folio = PyPDF2 index + 1): Seizing the Initiative is defined on **p.112**, the Reaction Roll on **p.113**, Deployment Conditions on **p.88**, and p.90 is "Types of Objective Access" — so the win-condition cite that names p.90 is CORRECT. The code already carries all four correct values; `docs/testing/BATTLE_COMPANION_COVERAGE_MATRIX.md:45` records the 14 cites fixed across 8 files, user-confirmed. Errata v1.06 pp.1-4 mention none of these rules, so nothing overrides the book. One refinement applied: morale was cited `pp.114-118`, but pp.116-117 are Battle Events (unrelated) — the rule is **pp.114-115** and p.118 is the Battle Round Reference. |

**Runtime-verified (MCP `run_script` harness, Battle Simulator):** tier gating (LOG_ONLY = exactly the 5 log components, higher tiers absent; FULL_ORACLE = all 14 cumulative instantiated); 5-phase round HUD (Reaction→Quick→Enemy→Slow→End, p.112); Seize the Initiative (threshold 10, all modifiers incl. Compendium equipment); deployment steps card (p.110); phase guidance text; objective display; deployment-conditions d100 roll.

**Tests (66 cases, all green):** `test_seize_initiative_system` (13), `test_battle_objective_completion` (14), `test_morale_panic_tracker` (7), `test_battle_flow_guide` extended, `test_battle_objective_tracker` (patrol updated to F5 value), **`test_battle_results_input_form` (8, F10 — +collapse-guard + objective-from-mission-data)**, **`test_tactical_downed_unit_row` (3, F9)**.

**Phase 4 (integrated 5PFH *played* battle) — DONE + RE-VERIFIED on-device (tablet, 2026-07-05→06):** drove a real played LOG_ONLY campaign battle end-to-end via ADB touch (no injected state). Mark-Down/Confirm-Casualty exercised 4× on-device; surfaced + FIXED **F9** (drawer touch-scroll) and **F10** (no reachable end/objective control), and the on-device re-verify surfaced + FIXED **F10-b/c/d/e** (form collapse, missing objective section, Submit off-screen, drawer lingering over PostBattle). Played-vs-auto-resolve result contract verified identical (24 keys). Final Test16 walk confirmed the whole loop on TWO objective types (Eliminate + Deliver): F9 compact downed rows → Record Result → full objective-aware form on one screen → check objective → Submit → drawer closes → clean PostBattle Step 14 → Cycle Summary 5W/0L (objective drove the Win) → Save → Turn 5. **Process note:** each on-device fix needs a full APK rebuild + reinstall (no hot-reload); a full app force-stop (not in-app Load) is required to reset `CampaignPhaseManager`'s per-turn step state.

**Remaining (not blocking):** Compendium mission panels (stealth/salvage/street-fight) + no-minis/auto-resolve combat modes (campaign-path only); F4/F7 pagination decision.

---

## § Fixit Sprint (Jul 2 2026) — post-Fable QA sweep

A project-wide sweep (probe scripts vs the live 4.6 engine, crash repro, PDF verification via PyPDF2) found and fixed, across 6 commits (`3c72435c`..`3c782b7e` + docs):

| Finding | Severity | Fix | Verified |
|---|---|---|---|
| `GameState._restore_equipment_from_campaign` self-`call_deferred` → infinite requeue → **segfault killed every full gdUnit4 run** at `test_save_persistence_gaps.gd` (detached `GameState.new()` + a real save on disk) | P0 | Queue-for-`_ready()` pattern (mirrors `_pending_journal_propagation`); test file rewritten against real API (no `serialize()`, `set_battle_results()` contract); wholly-stale `test_ship_stash_persistence.gd` deleted (coverage superseded by equipment persistence/transfer suites) | 27/27 persistence tests; live boot backtrace shows restore from `_ready`; detached-construction regression test added |
| 39 enum ordinal mismatches GlobalEnums↔GameEnums (9 enums) — **2 LIVE terrain bugs**: fire-spread/extinguish never triggered (TerrainFeatureType +9 offset), TerrainEffectType COVER/HAZARD key swap | P1 | GameEnums renumbered to GlobalEnums ordinals (canonical); dead divergent `Skill`/`Ability` enums deleted from BOTH files; save-safe (saves use string keys — verified) | New `test_enum_ordinal_sync.gd` (exhaustive, ~700 shared members) + `test_terrain_enum_agreement.gd` (fires the actual rules); Scenario 9 updated |
| Fabricated species mechanics in BOTH the dead `BattleCalculations` species region AND live paths (K'Erin +1 brawl w/ false p.18 cite, Hulker +2 melee, Stalker ambush +2, Swift defense_vs_ranged, felinoid/reptilian/insectoid species, Soulless/Bot armor 5 vs book 6+) | P1 | 230-line dead region deleted; live paths made book-exact (PDF-verified pp.15-22, p.45); six unimplemented book rules ported (Hulker shooting flags, Savvy-frozen gates in `spend_xp_on_stat` + `CharacterAdvancementService`, Primitive no_gun_sights, Traveler retreat +2", Swift multishot, Stalker teleport) | `test_species_rule_gates.gd` 13/13; brawl suite 16/16 (2 cases rewritten off fabricated asserts) |
| `LegalTextViewer.gd:171` wrote nonexistent `Control.custom_maximum_size` → runtime abort each call | P2 | Line removed (CenterContainer + min-size caps+centers; matches EULAScreen) | MCP live: legal_viewer navigation clean, no SCRIPT ERROR |
| `Character.gd` advancement history always "Turn 0" (`Engine.has_singleton` never true for autoloads) | P2 | Reads `progress_data["turns_played"]` via main-loop pattern; also records `old_value` (CharacterHistoryPanel already displays it) | species-gate suite exercises spend path |
| 5 data-ownership lint violations (direct `campaign.story_points =`) + dashboard called nonexistent `gsm.set_story_points()` (mirror never updated) | P2 | All routed through `GameStateManager.set_story_progress()` (write-through now unconditional); dead calls removed | `py scripts/lint_data_ownership.py` → CLEAN; MCP live write-through probe: campaign+mirror both update |
| Dead-code graveyard: 14 files (incl. `CampaignSerializer` whose deserializer always returned hardcoded defaults, the replaced `WorldPhaseUI` monolith, duplicate `StoryQuestData`/`VictoryConditionSelection`) + `DeploymentManager.infer_*` | P2/cleanup | All deleted after per-file re-verification (grep name+class_name+res:// path across gd/tscn/tres) | Headless compile exit 0; MCP smoke: MainMenu + dashboard render clean on legacy save |

**Full-suite re-baseline (sprint exit gate — first COMPLETE run on record)**: `-a tests/unit -a tests/integration -c` → **132/132 suites, 1610/1610 test cases executed, 0 crashes** (previously every run segfaulted at `test_save_persistence_gaps.gd`; everything alphabetically after it + the ENTIRE integration directory had never executed). Result: 1343 passing cases; **145 errors + 122 failures across 34 suites — all attributed PRE-EXISTING** (none reference sprint-deleted symbols — grep-verified; no file overlap with sprint diffs; the rot is old API drift, fabricated-mechanic asserts, and pre-audit design assumptions). *Attribution correction*: the sprint's first report said "22 suites" — the failing-suite extraction regex (`[a-z_/]*`) silently excluded any path containing a digit (`part2`, `e2e`, `4phase`, `phase2_backend/`, `phase3_*/`), hiding 12 suites. Lesson recorded: validate extraction patterns against a known count before reporting.

**Test-modernization triage (same day, commits `98146479` + `941b6e82` + `e7410b97`)**: all 34 rotted suites resolved with fix-or-cut discipline — **16 production bugs fixed** that the rot was hiding (highlights: StoryPointSystem ignored difficulty aliases for Insanity; 9 typed-array `.assign()` aborts in item/gear/weapon/armor loaders; combat log timestamp parsing + null-node aborts; `Ship.get_component_by_id` missed `component_id` keys; FinalPanel rejected Dictionary captains; CampaignPhaseManager never called `advance_turn()`; CampaignCreationCoordinator dropped top-level captain conversion; JobOfferComponent overwrote provided patron names + missing decline API; CharacterManager duplicate-id list corruption; Character implant float stat_bonus). **31 suites repaired** against real APIs/book rules, **3 suites cut with documented reasons** (`test_campaign_turn_loop_basic`, `test_story_mission_loader_part2`, `test_story_track_e2e` — all asserting a never-shipped 6-mission story design or pre-audit turn model; the real 7-event Story Track has its own coverage). Recurring rot families: never-shipped APIs, the fabricated morale-era design, "max 10 stash" cap (none exists — p.125), "4 crew = 4 credits" upkeep (book: 4-6 crew = 1 credit, p.76), six-name injury enum (real system is the JSON D100 table, pp.122-123).

**Final green baseline (2026-07-02, definitive)**: **129/129 suites, 1552/1552 test cases, 0 errors, 0 failures, 0 flaky, 0 crashes.** First fully-green complete run in project history. Known non-failure noise: 1669 orphan nodes across a handful of suites (cleanup follow-up, tracked below).

**Still-open cleanup list** — ✅ **CLOSED 2026-09-04.** `src/game/combat/CombatResolver.gd` was already deleted in the Jul 10 wiring-audit sprint (the whole `src/game/combat/` directory is gone); this line had gone stale. The wider dead-code backlog closed the same day: `lint_orphan_assets.py` now reports `test_only=0 orphans=0` and exits 0 for the first time, after 39 production-dead files (11,349 lines / 364 KB, all of it shipping in the APK) were removed. Historical entries follow: ~~`EquipmentManager.apply_gun_mod()` (zero callers)~~ (**gone, verified Sep 3 2026** — the function no longer exists anywhere; p.53 Gun Mods and Sights are owned by `src/core/equipment/WeaponModService.gd`), ~~~8 dangling `/root/CampaignManager` null-lookups~~ (**zero remain, verified Sep 3 2026** — `lint_autoload_lookups` is clean), ~~PatronRivalManager `threat_level` data-contract crash~~ (**CLOSED Sep 3 2026**, see the row below). Observed during MCP smoke, unattributed: ~10 engine-level "Lambda capture at index 0 was freed" errors on unusual scene-transition paths (MainMenu→legal_viewer→dashboard) — no GDScript backtrace; predates-sprint likelihood high (no new lambdas executed); worth a dedicated look. — Phase 4 (5 hard screens) + Phase 5 (device-QA matrix + 14-screen remediation) SHIPPED & verified. See "§ Responsive / Device QA" below. Prior 2026-05-17: BUG-101 RE-FIXED: 05-16 verify was premature — user re-reported residual 3-10px terrain bleed; true root cause empirically isolated (SVS draws body on rotated `offset`, not `position`), back-solved position + stroke envelope, MCP-verified 0/316 offenders across 10 distinct seeds. CLR-101: objective "dead center" confirmed verbatim rules-correct vs Core Rules PDF p.90 — kept position, added rule-cite label (user-chosen). objective-tracker 14/14 PASS. Prev 2026-05-16: Battle-UI Sweep BUG-100..106 filed; BUG-100/102/103/104/105 fixed+verified, BUG-106 umbrella)
**Engine**: Godot 4.6-stable
**Overall Coverage**: Data 100% verified (925/925 values), **generator wiring 16/16 OK**, **Compendium PDF-verified**, **Hardcoded data cleanup complete**, **30/30 UI issues fixed**. KeywordDB wired to 89-keyword JSON, 14 weapon trait definitions corrected to Core Rules p.51, BattlePhase fabricated payment removed, BattleEventsSystem wired to event_tables.json (24 events data-driven). See QA_RULES_ACCURACY_AUDIT.md for details.
**Alpha context**: Closed alpha kickoff target Mon May 25, 2026. See §11 below for alpha-1 scope (Core + Compendium DLC only) and `docs/testing/ALPHA_1_QA_PLAN.md` for execution detail.

### Expansion Gamemodes (April 2026)
| Gamemode | Files | Data Verified | Runtime QA | Status |
|----------|-------|---------------|------------|--------|
| **Planetfall** | 63 files | 15 JSON | Full 18-step turn cycle PASS, save/load PASS, multi-turn PASS | MainMenu button wired |
| **Tactics** | 59 files | 108 costs verified | 5/7 scenarios PASS, 9 bugs fixed | MainMenu button wired |
| **Bug Hunt** | 38 files | 15 JSON verified | End-to-end flow verified (Session 45) | MainMenu button wired |
| **Cross-Mode Transfer** | `CharacterTransferService` + 3 panels + pickup | Planetfall pp.26-27/165-166 + Tactics p.184/185 verified | 24/24 gdUnit4 (`test_character_transfer_hub`, `test_planetfall_transfer`, `test_tactics_transfer`); editor parse clean | Foundation + Planetfall P1 + Tactics SHIPPED; all 4 modes interconnect any-to-any; P3 barracks deferred |

---

## § Responsive / Device QA (June 2026 mobile/tablet re-pivot)

The build was re-pivoted to dual-platform (desktop landscape + mobile/tablet portrait, both orientations, 375px→1920px). `ResponsiveManager` (DPI-aware breakpoints + `layout_class_changed` rotation signal) is the SSOT; multi-pane screens use `AdaptivePanelGroup` (grid in landscape, tabs/stack in portrait). SOP: `docs/sop/responsive-adaptive-ui.md`.

### Phase 4 — the 5 hard screens (SHIPPED, verified live both orientations)
| Screen | Adaptation | Verified |
|---|---|---|
| CampaignDashboard | Outer-scroll wrap; 1-col turns outer scroll on + inner scrolls off (no "1/3-cramp") | MCP live: 1920=3col, 768=2col, 430=1col stack |
| GalaxyLog | Legend → HFlowContainer, count min-width relaxed, Recenter button | MCP live portrait |
| TacticalBattleUI | Rails suppress in portrait (map fills); intel-drawer mirror; rotation reconcile | live reconcile probe + adversarial review |
| PreBattle / EquipmentManager | 3 panes → `AdaptivePanelGroup(TABS)` | live instantiation probes |

### Phase 5 — device matrix QA + fast-follow remediation (SHIPPED)
- **Static audit**: 70 screens swept (workflow), 18 portrait-readiness issues confirmed.
- **Remediation (14 screens)**: 7 `AdaptivePanelGroup` migrations (PatronRivalManager, ShipManager, CampaignEventsManager, AdvancementManager, PurchaseItemsComponent, EquipmentGenerationScene, CharacterCreator); 4 fixed-width caps (CampaignJournalScreen, EquipmentPanel, TravelPhase, BattleTransitionUI); 3 turn-controller portrait top-bars (BugHunt/Planetfall/Tactics); touch-target bumps (dashboard `?`/`SP`, PurchaseItems roll buttons → 48px).
- **Verification**: parse-check clean on all 15 scripts + 8 scenes; all 14 diffs reviewed (landscape byte-identical, reparent-safe, focus indices correct); `AdaptivePanelGroup` 10/10 unit tests; live-confirmed both modes (TABS via Equipment/PreBattle, STACK via ShipManager). Tests: `test_responsive_manager_effective_columns` (16), `test_adaptive_panel_group` (10).

### Pre-existing bugs surfaced during device QA (NOT responsive; out of scope — flagged for follow-up)
| Bug | Location | Severity | Status |
|---|---|---|---|
| Duplicate `_notify_success` func (parse error) | `CampaignJournalScreen.gd` (was lines 985/1217) | HIGH (screen failed to instantiate) | **FIXED** (removed the duplicate; was latent in HEAD, `--headless --quit` never caught it — screen not on boot path) |
| `var x: Panel = _create_*_panel()` where factory returns `PanelContainer` (6 sites) | PatronRivalManager (×2), AdvancementManager (×3), CampaignEventsManager (×1) | MED (aborted the refresh fn — halts `--debug`) | **FIXED** (`Panel`→`Control` at all 6 sites; matches the factories' declared `-> Control`) |
| Missing template JSONs spamming `DataManager` errors | `data/{patrons,rivals,jobs}/*_templates.json` (never shipped; in-code fallbacks supply scaffolding) | LOW (error-log spam; fallback works) | **FIXED** (existence-guarded load → silent fallback; did NOT fabricate the JSONs) |
| `Invalid access to key 'threat_level'` (missing-key on rival dict) | `PatronRivalManager.gd:414` (`_create_rival_panel`) + likely more keys in that screen's panel-builders | MED (halts `--debug`; PatronRivalManager is a half-finished screen with a data-contract mismatch) | **CLOSED Sep 3 2026.** Re-verified line by line: every dict read in `_create_rival_panel` (:453) and `_update_details` (:514) already uses `.get()` with a default, so the reported crash cannot occur. One residual hazard in the same screen WAS found and hardened — `entity.special_rules` assigned straight to the String `Label.text`, which every other producer in the codebase supplies as an ARRAY (`Character.gd:1462`, `EnemyData.gd:131`, `PatronJobGenerator.gd:92`). Dormant, because no live producer writes the key at all: the screen reads contacts from GameStateManager (:264-282), not from the JSON templates whose generator (:352/:368) stores a String. |

> **QA tooling note**: full-instantiation MCP probes of PatronRivalManager are still blocked by the remaining `threat_level` data-contract crash (debugger halts in `--debug`). AdvancementManager/CampaignEventsManager had only the Panel crash (now fixed). Migrations are verified via parse-check + diff review + the proven `AdaptivePanelGroup` pattern (live-confirmed on Equipment/PreBattle/ShipManager).

### Text scaling + portrait narrow-width pass (Jun 2026)

**Tiny-text root cause:** the square 1080×1080 stretch base (chosen for dual orientation) scales content by `min(window.x, window.y)/1080` — in PORTRAIT the small window WIDTH constrains it to ~0.4× → text ~6px. (Desktop landscape is height-constrained ~0.97×, so desktop text was merely "small", not tiny.)

**Fix** in `SettingsManager._apply_ui_scale()` (recomputed on every resize/rotation):
`content_scale_factor = TARGET_EFFECTIVE(1.12) × ui_scale × dpi_scale × (1080 / min(window.x, window.y))`
The `1080/min(window)` term CANCELS the square-base stretch and holds a constant **effective ~1.12 scale** in both orientations — so portrait text jumps ~2.8× to match landscape (verified: landscape content_scale ~1.15, portrait ~2.81, both effective 1.12). `dpi_scale` = `screen_get_scale()` (real on Android/iOS/macOS/Wayland/Web, **1.0 on Windows**; for Windows-hiDPI later use `screen_get_dpi()`). content_scale does NOT affect ResponsiveManager's dp breakpoint logic, so column/collapse is unchanged.

**Narrow-width pass (the consequence):** normalizing the scale shrank the portrait design space to a real ~384px phone width, exposing that Phase-4 portrait was **column-collapse only** — individual rows (headers, stat strips) were authored for the fake-wide 1080 space and overflowed. Fixed across ~19 screens: non-wrapping header/badge/button rows `HBoxContainer`→`HFlowContainer` (wrap in portrait, single-line on desktop); long labels → `AUTOWRAP_WORD_SMART`; shared `CampaignScreenBase._create_info_row()` value label → `EXPAND_FILL`+autowrap; gamemode-dashboard 5-col stat grids → 3-col in portrait via `should_use_single_column()`. Verified: CampaignDashboard + ShipManager fit 384px portrait with zero overflow; parse-clean across all 38 touched files.

**Mobile-optimized (tabbed sections, not just "fits"):** "fits + readable" still read as a stacked desktop layout (one long scroll). Converted the 3-pane *glance* screens to a genuine mobile pattern — a 3-column GRID on desktop/landscape, a **tab strip in portrait** (one focused, self-scrolling section), all from one codebase via `AdaptivePanelGroup`. **CampaignDashboard** migrated for real (Crew/Ship/World tabs; replaced the Phase-4.1 `MainScroll` outer-scroll wrapper; `_set_column_layout` early-returns once the group owns layout). **ShipManager** + **PurchaseItemsComponent** switched STACK→TABS; PatronRival/Advancement/CampaignEvents (Phase 5) + PreBattle/Equipment (Phase 4) already TABS. Gamemode dashboards are code-built card-hubs (no glance-grid) — left as scrolling card lists. Tab strip is 56px (touch-friendly). Verified live: dashboard desktop 3-col grid unchanged + portrait Crew/Ship/World tabs; ShipManager/PurchaseItems 3 tabs in portrait. **Deferred polish:** a dedicated fixed bottom action bar (current action buttons wrap into rows — functional but not a native bottom-nav).

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Game Mechanics Implemented | 170/170 (100%) |
| Mechanics Runtime-Verified | 170/170 (100%) |
| Open Bugs | 0 code bugs, 0 UI/UX blockers |
| UI/UX Screens Audited | 21/21 screenshotted + structurally analyzed |
| UI/UX Issues Found | 30 total: all resolved (Session 15: 21 fixed, Session 16: 28/28 visual fixes) |
| MCP Integration Scenarios | 3/10 PASS (S1 Campaign Lifecycle, S3 Save/Load, S9 Enum Sync) |
| Data Values Verified | 925/925 (100%) against Core Rules + Compendium source text |
| Rules-Verified Mechanics | **170/170 (100%)** — PyPDF2 cross-reference against Core Rules + Compendium PDFs (218+ values, 0 mismatches) |
| Data Fixes Applied | 190+ fixes, 145+ fabricated values removed |
| Unit Test Files | 97 (tests/unit/) |
| Integration Test Files | 34 (tests/integration/) |
| Full-Suite Baseline (Jul 2 2026) | **129/129 suites, 1552/1552 cases GREEN** (0 errors, 0 failures, 0 crashes) |
| MCP Test Sessions Completed | 18+ (106 bugs found, 102 fixed) |
| Demo Path Status | PASS (CC-1→CC-11, 5 turns, save/reload) |

---

## §11 — Alpha-1 Scope (added 2026-05-01)

> **Scope decision (May 1):** Alpha-1 covers **Core Rules + 3 Compendium DLC packs only** — Standard 5PFH 9-phase campaign + 33 ContentFlags. Bug Hunt / Planetfall / Tactics gamemodes deferred to alpha-2 or beta. See `docs/testing/ALPHA_1_QA_PLAN.md` for detail and `docs/CLOSED_ALPHA_PLAN.md` §1.5 for the canonical scoping statement.

### Alpha-1 IN-scope coverage

| Surface | Files | Data Verified | Runtime QA | Status |
|---|---|---|---|---|
| **Standard 5PFH 9-phase campaign** | core campaign system | 925/925 values | Sessions 47-52 deep-dive, 18+ MCP runs | **HIGH CONFIDENCE** |
| **7-phase campaign creation wizard** | CampaignCreationCoordinator + 7 panels | full | MCP-validated 5x | **HIGH CONFIDENCE** |
| **TacticalBattleUI** (3 oracle tiers) | battle subsystem | full | Session 48d battle reconciliation | **HIGH CONFIDENCE** |
| **Battle Simulator standalone** | battle_simulator dir | full | Session 31 fixes | **HIGH CONFIDENCE** |
| **Compendium DLC** (33 ContentFlags) | DLCManager + content | TT=7, FH=17, FG=9 verified | Session 5/53 wiring; toggle-lifecycle test pending P0.T1 of plan | MED — toggle path needs S11 stress |
| **Strange Characters** (16 species) | Character.gd species_id | Session 52 wiring | All 16 wired | **HIGH CONFIDENCE** |
| **Story Track** (Appendix V) | StoryTrackSystem | Session 36 integration | full | **HIGH CONFIDENCE** |
| **Red & Black Zone Jobs** | RedZoneSystem, BlackZoneSystem | Session 35 | full | **HIGH CONFIDENCE** |
| **Telemetry consent + opt-in** | LegalConsentManager | EXISTS | wiring pending P1.T4 of plan | NEW — alpha deliverable |
| **Pricing-perception survey** | new — PricingPerceptionSurvey.tscn | n/a | wiring pending P2.T1 of plan | NEW — alpha deliverable |
| **5 conversion mechanisms** | new — discount/CTA/tooltip/preorder/newsletter | n/a | wiring pending P2.T5-T9 of plan | NEW — alpha deliverable |

### Alpha-1 OUT-of-scope (deferred)

| Surface | Status | Where it goes |
|---|---|---|
| Bug Hunt gamemode (38 files) | Out | alpha-2 or beta |
| Planetfall gamemode (63 files) | Out | alpha-2 or beta |
| Tactics gamemode (59 files) | Out | alpha-2 or beta |
| Cross-Mode Isolation (Scenario 4) | Out | alpha-2 |
| Character Transfer Service | Out of alpha-1 scope, but **Foundation + Planetfall P1 + Tactics SHIPPED** (Jun 2026, 24/24 gdUnit4; all 4 modes interconnect any-to-any) | alpha-2 runtime QA; see `docs/sop/cross-mode-transfer.md` |
| Store/Paywall commerce flows (Scenario 8) | Out | beta / Steam Playtest (alpha runs offline mode) |
| Localization | Out | Phase D |
| Code-signing cert | Out | Phase D |
| In-game bug report dialog (cloud function) | Out | beta or post-launch |
| MCP-automated regression for alpha-1 scope | Out | Phase C refinement Jul 7-20 |

### Alpha-1 specific risk areas

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Compendium DLC mid-campaign toggle misbehavior | Med | Med | S11 stress test pre-A0; hotfix budget reserved |
| Survey opt-in fatigue (testers dismiss week-after-week) | Med | Med | Once-per-build-version persistence; Google Form alternative |
| Conversion mechanism mocks read as "salesy" | Med | High | Tester debrief explicitly probes tone; Modiphius coordination on real values reduces mock-detection risk |
| Crash auto-capture misses Godot-internal crashes (no `unhandled_exception` signal in 4.6) | Med | Low | CrashLogger captures push_error/push_warning; Discord-uploaded saves enable manual repro |

### Alpha-1 graduation gate readiness

Per `docs/CLOSED_ALPHA_PLAN.md` §7. Each gate now has measurement instrumentation defined:

| # | Gate | Threshold | Current state |
|---|---|---|---|
| 1 | Stability | P0=0; P1<5; <1 crash/10 sessions | TBD — A0 sanity-check Wed May 20 |
| 2 | Comprehension | ≥80% testers describe value prop in 1 sentence after 2 sessions | TBD — week-1 debriefs |
| 3 | Retention | ≥60% complete 3+ sessions; ≥40% reach Turn 5 | TBD — Talo dashboard tracks |
| 4 | Pricing band converges | ±$3 within $14.99-$24.99 | Prolific n=200 + alpha cohort VW (Phase B) |
| 5 | Recommendation NPS | ≥7/10 | TBD — pricing modal NPS field |
| 6 | Bug discovery rate trending down | New P1+ bugs/build declining by week 5 | TBD — Discord intake counts |

---

## Coverage by Category

| Category | Mechanics | NOT_TESTED | UNIT_TESTED | INTEGRATION_TESTED | MCP_VALIDATED | RULES_VERIFIED |
|----------|-----------|------------|-------------|-------------------|---------------|----------------|
| Character Creation | 20 | 0 | 10 | 4 | 6 | 0 |
| Campaign Phases | 49 | 0 | 15 | 10 | 24 | 0 |
| Economy & Trading | 16 | 0 | 8 | 2 | 6 | 0 |
| Equipment System | 17 | 0 | 7 | 2 | 8 | 0 |
| Ship System | 11 | 0 | 5 | 2 | 4 | 0 |
| Loot System | 14 | 0 | 10 | 2 | 2 | 0 |
| Battle Phase Manager | 8 | 0 | 5 | 1 | 2 | 0 |
| Compendium DLC | 35 | 0 | 22 | 2 | 11 | 0 |
| **TOTAL** | **170** | **0** | **82** | **25** | **63** | **0** |

> **Note**: All 170 mechanics now have automated test coverage (Mar 21). 44 previously NOT_TESTED mechanics promoted to UNIT_TESTED via 211 new tests across 7 files. Counts include §9 cross-cutting (23 enum sync + 47 difficulty + 26 Elite Ranks). See `QA_CORE_RULES_TEST_PLAN.md` for per-mechanic detail.

---

## Open Bugs

### Confirmed Bugs (Rules Verification — Mar 21)

| Bug | Severity | Description | Decision Needed |
|-----|----------|-------------|-----------------|
| ~~BUG-036~~ | **FIXED** | Precursor psionic power preserved during campaign creation (property whitelist expanded: +8 props in CampaignCreationCoordinator) | Root cause: 15-prop whitelist dropped `psionic_power` during Resource→Dict conversion |
| ~~BUG-037~~ | **FIXED** | Swift species now +2 Speed (was +1 Speed +1 Reactions) | Matched Core Rules p.50 |
| ~~BUG-038~~ | **FIXED** | Soulless species now +1 Toughness only (removed extra +1 Reactions) | Matched Core Rules p.50 |
| ~~BUG-040~~ | **FIXED** | InjuryProcessor.gd:99,155 — unsafe `turn_number` access on GameStateManager (missing `"turn_number" in` guard). Crashed during post-battle injury processing when no campaign loaded. | Added property existence check, matching pattern from line 45 |
| ~~BUG-044~~ | **FIXED** (P1) | TacticalBattleUI: ASSISTED/FULL_ORACLE components (VictoryProgressPanel, ObjectiveDisplay, MoralePanicTracker, ActivationTrackerPanel, ReactionDicePanel, EnemyIntentPanel) **never instantiated in any battle**. `_setup_ui()` ran the tier-gated `_instance_*` calls before tier selection (tier_controller null → gates skipped); `_on_tier_selected()` only updated badge/tabs. Regression from the "Phase 58 tier-differentiation fix" — silently degraded every battle to LOG_ONLY. Found via runtime MCP testing. | Fixed: `_on_tier_selected()` now calls `_instance_assisted_components()` / `_instance_oracle_components()` (guarded against double-instance) after tier_controller is created. Runtime-verified all 5+ components instance at ASSISTED. |
| ~~BUG-045~~ | **FIXED** (P0 hang) | Infinite loop froze the game when a VictoryProgressPanel interactive objective row changed: `_refresh_objective_panel()` → `update_condition_progress()` rebuilds rows → new StepperControl → deferred `setup()` → `value_changed` echo → `objective_progress_input` → refresh → … (cross-frame, so a same-frame guard alone wouldn't catch it). Found via runtime MCP testing of the new BattleObjectiveTracker. | Fixed: no-op guard in `_on_objective_progress_input` (JSON-snapshot before/after `apply_panel_input`; skip rebuild when unchanged — the programmatic-setup echo carries the value the tracker already holds) + `_objective_refreshing` re-entrancy guard. Runtime-verified: 3 consecutive/echo emits stay responsive. |

### Battle-UI Sweep — Filed in DEFECTS_LOG, Verified (May 16)

Full detail: `docs/testing/DEFECTS_LOG.md` (BUG-100..106).

| Bug | Severity | Description | Status |
|-----|----------|-------------|--------|
| ~~BUG-100~~ | **FIXED** (P1) | Window never filled a 4K display — saved display mode applied only on the Settings screen, never at boot. `project.godot window/size/mode=2` (Maximized first-run default) + `GameState._restore_window_state_at_boot()` replays `user://window.ini`. | Verified (MCP: setting=2; saved ini mode=0 restored live at launch) |
| ~~BUG-101~~ | **FIXED** (P1) | Terrain bled past the grid. **Reopened** — the 05-16 rotation-aware center clamp was right in concept but used the wrong position basis (user re-reported 3-10px residual bleed). TRUE root cause (empirically isolated): `ScalableVectorShape2D` draws its body centered on `offset` in local space and `offset` is rotated by node rotation, so drawn center = `position + offset.rotated(rot)`, not `position`. Fix: back-solve `position = clamped_center - offset.rotated(rot)` + `stroke_width/2` envelope. Geometry-only. | Verified 2026-05-17 (MCP: same diagnostic that found 3 bleeders → 0 offenders / 316 shapes / 10 distinct seeds / worst 0.0px; 3 fresh-seed screenshots in-grid; objective-tracker 14/14 PASS) |
| ~~BUG-102~~ | **FIXED** (P1) | First-render terrain cluster. **Reopened during cross-mode smoke** — initial `_transform_dirty` self-heal fixed only a secondary case; user spotted residual cluster. TRUE root cause: `BattlefieldGridPanel._update_map_cell_size()` mutated `cell_size` (16→48) on resize after placement was baked, breaking `effective_cs/cell_size` scale. Fix: cell_size is now the stable placement base, never mutated. | Verified (MCP: quadrant histogram TL28/0/0/0 → TL8/TR6/BL6/BR7; D4 corner populated on screenshot) |
| ~~BUG-103~~ | **FIXED** (P2) | Legend always showed all 12 categories. Now data-driven from terrain actually rendered, scatter-aware, rebuilt in `populate()`. | Verified (MCP: 4 keys scatter-off / 5 on; screenshot 5-entry legend) |
| ~~BUG-104~~ | **FIXED** (P2) | Tools accordion was 5 unlabeled all-collapsed sections. Added per-section subtitles + a hint + default-expand via existing `open_section(0)`. Wiring check found+fixed 2 tools (CharacterQuickRoll, Brawl) never echoed to the log. | Verified (gdUnit 18/18 no regression; runtime boot clean) |
| ~~BUG-105~~ | **FIXED** (P2) | Hover tooltip + click popover listed raw features (incl. hidden scatter) not the drawn shapes. Both now read a single render-equivalent label source. | Verified (MCP: scatter excluded/included matching show_scatter both ways) |
| BUG-106 | **OPEN** (P3) | Tracking umbrella: battle-UI "lots of small things not fully wired". Wiring item already resolved (2 tools). Remaining checklist in DEFECTS_LOG; promote each confirmed item to its own BUG. | Triaged (ongoing) |
| CLR-101 | **WAI + UX** | User flagged objective marker "stuck dead center" alongside BUG-101. Verified verbatim against the Core Rules PDF (p.90: Access/Acquire/Secure/Deliver = "exact center of the table/battlefield"). Moving it would make the app rules-incorrect + violate data-integrity. Position kept; added verbatim Core Rules p.90 rule cite + 2-line "OBJECTIVE:" marker so it reads as intentional. **Not a bug — no BUG number.** | Verified (MCP: all 14 objective types correct, grid_pos unchanged at center; 2-line label screenshot-confirmed) |

### Weapon Data — Book Verified (Mar 23)

| Item | Value | Core Rules p.49 | Status |
|------|-------|-----------------|--------|
| Colony Rifle range | 18" | 18" (Range 18", Shots 1, Damage 0) | **CONFIRMED CORRECT** |
| Infantry Laser damage | 0 | 0 (Range 30", Shots 1, Damage 0, Snap Shot) | **CONFIRMED CORRECT** — +1 only with Hot Shot Pack mod |

### UX Issues

None — all UX issues resolved as of 2026-03-20.

### Deferred Items (Blocked on Architecture/User Decision)

| Item | Blocker | Impact |
|------|---------|--------|
| ~~WEALTH motivation~~ | **FIXED Mar 21** | Now applies +1D6 credits at campaign finalization |
| ~~FAME motivation~~ | **FIXED Mar 21** | Now applies +1 story point at campaign finalization |
| ~~Character bonus coverage~~ | **FIXED Mar 21** | KNOWLEDGE +1 savvy added, game-specific CharacterCreator synced (WEALTH/SURVIVAL were wrong) |
| ~~Equipment table naming~~ | **FIXED Mar 21** | All weapon data rewritten from Core Rules p.50: weapons.json (36 weapons) + equipment_database.json (30 weapons). Traits normalized to Title Case. |
| ~~Victory condition metric tracking~~ | **FIXED Mar 23** | VictoryChecker now reads from `progress_data` where `GameStateManager` increments counters |

### Battle UI Bugs (Standalone-Mode Only)

~~7 bugs~~ from `BATTLE_UI_QA_BUGS.md` affected direct TacticalBattleUI launch. **Root cause fixed** (Mar 23): `_check_standalone_mode()` deferred call now shows tier selection overlay when `initialize_battle()` is not called. Remaining standalone limitations (no crew cards, no setup data) are expected without campaign context. See `docs/BATTLE_UI_QA_BUGS.md` for details.

---

## Rules Accuracy Status

> **BLOCKS PUBLIC RELEASE**: All game data must be verified against the Five Parsecs From Home Core Rules book. See `docs/QA_RULES_ACCURACY_AUDIT.md` for the full checklist.

| Domain | Est. Values | Verified | Status |
|--------|-------------|----------|--------|
| Weapons & Equipment | ~170 | ~99 | **VERIFIED** — 36 Core Rules + 1 Compendium (Carbine). 5 fabricated weapons REMOVED. |
| Species & Characters | ~80 | ~80 | **VERIFIED** — all species stats, 3 Strange Characters ADDED, motivation table 13 errors FIXED |
| Injuries | ~25 | ~25 | **VERIFIED** — fatal split FIXED, treatment system ADDED |
| Loot Tables | ~60 | ~55 | **VERIFIED** — 14 missing ship items added |
| Economy & Upkeep | ~30 | ~30 | **VERIFIED** — payment REWRITTEN, WorldEconomyManager 1000→0, starting credits FIXED |
| Campaign Events | ~100 | ~100 | **VERIFIED** — 28 campaign + 30 character events confirmed |
| Travel & World | ~40 | ~41 | **VERIFIED** — 41 world traits D100, rival following 5+ FIXED (was ≤3), license 2-roll FIXED (was fabricated tiers) |
| Battle & Enemies | ~60 | ~60 | **VERIFIED** |
| Char Creation Tables | ~80 | ~80 | **VERIFIED** — Background (25) + Class (23) + Motivation (17 FIXED) |
| Missions | ~50 | ~50 | **VERIFIED** — patron/danger pay/BHC all confirmed |
| Ships | ~20 | ~20 | **VERIFIED** |
| Victory Conditions | ~17 | ~17 | **VERIFIED** — 17 conditions + easy mode restrictions |
| Compendium/DLC | ~100 | ~100 | **VERIFIED** — 11 GDScript files cross-referenced. 4 tables REWRITTEN. 5 fabricated weapons REMOVED. 3 generator data duplications FIXED (stealth/street/salvage unified onto compendium schema). |
| **TOTAL** | **~925+** | **~925+** | **DATA VERIFIED + GENERATOR WIRING COMPLETE** |

**Data Verification Complete (Mar 23, 2026)**: All JSON/GDScript data values cross-referenced against source text. 190+ fixes applied, 145+ fabricated values removed.

**Generator Wiring Complete (Mar 23, 2026)**: All 10 broken generators fixed. See `QA_RULES_ACCURACY_AUDIT.md` "Generator Wiring Gap" for fix details.

**Economy conflicts — RESOLVED**:

- ~~Upkeep cost~~: **FIXED** — data files + `FiveParsecsMissionGenerator` rewards rewritten (D6 base + D10 danger pay)
- ~~Starting credits~~: **FIXED** — `StartingEquipmentGenerator` fabricated credits removed, campaign creation handles per Core Rules p.28
- ~~Payment formula~~: **FIXED** — `PatronJobGenerator` rewritten with Core Rules patron types + relationship tier system

---

## Risk Areas

| Area | Risk | Reason | Mitigation |
|------|------|--------|------------|
| ~~Generator Wiring Gap~~ | **RESOLVED** | All 16/16 generators fixed (Mar 23 sprint). Data + wiring both verified. | `QA_RULES_ACCURACY_AUDIT.md` "Generator Wiring Gap" |
| ~~Data Accuracy — AI Hallucination~~ | **RESOLVED** | 925/925 data values verified against source text. Fabricated values removed. | Data audit + generator wiring both complete |
| ~~Duplicate Data Sources~~ | **RESOLVED** | Generators now delegate to `Compendium*` canonical data classes — no duplicate const tables. Stealth/Street/Salvage generators unified Mar 30. | Fixed: generator wiring sprint + schema unification |
| Save/Load dual-sync | **HIGH** | BUG-031 was systemic — all setters must sync to 3 targets | Dual-sync regression test in integration scenarios |
| Three-enum sync | **HIGH** | GlobalEnums, GameEnums, FiveParsecsGameEnums must stay aligned manually | Automated enum comparison test needed |
| ~~Character type shadowing~~ | **RESOLVED** | 7 files fixed Mar 21 — removed `const Character := preload(Base/Character.gd)` shadowing class_name | Fixed: consts removed, global class_name used |
| TweenFX pivot_offset | **MEDIUM** | 13 animations silently break without `pivot_offset = size / 2` | Checklist in QA_UX_UI_TEST_PLAN.md |
| Bug Hunt cross-contamination | **LOW** | Namespace isolation verified, temp_data keys prefixed. **Wave 5 MCP-confirmed**: data models fully incompatible (flat vs nested), no ship/patron/rival in Bug Hunt. | Integration scenario 4 |
| ~~Bug Hunt cross-load~~ | **RESOLVED** | `GameState.load_campaign()` now has `_detect_campaign_type()` routing. Reads `campaign_type` from save JSON, routes to correct loader (FiveParsecsCampaignCore or BugHuntCampaignCore). | Fixed Mar 23 |
| Difficulty enum format | **LOW** | Fixed Phase 30, but old saves with 1-5 values map incorrectly | Migration handling in GameState |

---

## Recently Completed QA Work

| Phase | Date | Scope | Bugs Found | Bugs Fixed |
|-------|------|-------|------------|------------|
| Battle-UI Issues Sweep (BUG-100..106) | May 16, 2026 | 4K-monitor battle-mode audit. BUG-100 window never filled display (GameState boot restore + project.godot mode=2). BUG-101 terrain bled past grid (rotation-aware center clamp). BUG-102 first-render top-left cluster (transform self-heal). BUG-103 legend always 12 (data-driven via populate). BUG-104 illegible Tools accordion (subtitles + open_section(0) + hint; wiring check found+fixed 2 unwired tools CharacterQuickRoll/Brawl). BUG-105 tooltip/popover ≠ drawn (render-equivalent label source). BUG-106 P3 wiring-sweep umbrella. Verified: headless compile clean, gdUnit 18/18 no regression, 0 new lint, MCP runtime (7/7 terrain in-bounds, legend 4/5 keys scatter-aware, window.ini restored live, screenshot). Shared battle files: cross-mode review pending. | 7 | 6 fixed+verified (BUG-106 umbrella ongoing) |
| Battle Objective Tracking Runtime QA | May 16, 2026 | New BattleObjectiveTracker end-to-end. Layer 1: tracker vs REAL JSON-backed MissionObjectiveSystem (11-type registry confirmed, coverage matrix validated live). Layer 2-3: real `_on_tracker_battle_started`/`_on_round_started`/`objective_progress_input` paths — VictoryProgressPanel fed, FIGHT_OFF interactive counter (7-enemy battle: 5/7 pending → 7/7 complete). Layer 4: post-battle `success` cascade → PostBattlePhase.mission_successful (4 gdUnit tests, incl. legacy-bug regression guard). 18 unit tests total green. | 2 | 2 (BUG-044 tier components never instanced; BUG-045 P0 infinite-loop hang) |
| Session 59: Godot Perf Sprint | Apr 28, 2026 | project.godot tuning (max_fps=60, physics_ticks_per_second=30); GalacticWarManager + ReviewManager lazy-init pattern; 71 JPGs to VRAM compression; 5 items verified clean, 2 evaluated-and-skipped. | 0 | 0 (perf-only) |
| Session 57d: Planetfall Turn QA | Apr 9, 2026 | Full 18-step turn cycle runtime-verified; save/load round-trip PASS; multi-turn (T1→T2) verified. | 2 | 2 |
| Session 57c: Planetfall Runtime Fixes | Apr 9, 2026 | 50+ parse errors triaged; `_create_pill` root cause identified; PlanetfallDashboard loads. | 50+ | 50+ |
| Session 57b: Tactics Runtime Testing | Apr 9, 2026 | 108 weapon/vehicle/unit costs verified against rulebook; 5/7 scenarios PASS. | 9 | 9 |
| Session 57: Planetfall §3+4 + Battle Delegation | Apr 9, 2026 | §3+4 complete + battle delegation + progression wiring + QA doc (28 scenarios, 255 checks). | 0 | 0 (impl) |
| Session 56: Planetfall §2 (Sprints 2-4) | Apr 9, 2026 | Section 2 multi-sprint implementation. | 0 | 0 (impl) |
| Session 55: Tactics ALL 7 Phases | Apr 9, 2026 | 59 new files; full Tactics gamemode implemented. | 0 | 0 (impl) |
| Session 54: Planetfall §1 Crews & Combat | Apr 9, 2026 | Section 1 implementation. | 0 | 0 (impl) |
| Session 53b: Psionics UI + Enforcement Gaps | Apr 9, 2026 | Psionics UI wiring, enforcement gaps closed, DLC enum key bug fix. | 1 | 1 |
| Session 53: Compendium §1-2 Sprint | Apr 9, 2026 | Compendium sections 1-2 implementation. | 0 | 0 (impl) |
| Session 52: Strange Characters + Upkeep | Apr 8, 2026 | All 16 Strange Character species fully wired; Upkeep failure system per Core Rules p.76 (Sick Bay exclusion, lockout, sell-for-upkeep, dismiss crew, ship seizure fix). | 7 gaps + upkeep | 7 + 5 mechanics |
| Session 51: Character Events Wiring | Apr 8, 2026 | 30 D100 events fully wired; status_effects persistence; 9 effect types; 6 enforcement gates; dashboard pills; item mutation; Swift departure; upkeep exemption. | 0 | 0 (impl) |
| Session 50: Terrain Generator Overhaul | Apr 8, 2026 | 8-phase overhaul: shape placement fixes, 10 world traits, scatter visibility, legend, rules badges, seeded RNG, planet→theme. | 0 | 0 (impl) |
| Session 49: UX Polish Sprint | Apr 8, 2026 | 8 items: colorblind fix, TweenFX 4 screens, Load dialog themed, help buttons, checklist 59/7/15. | 0 | 0 (UX) |
| Session 48: Library UI Overhaul | Apr 8, 2026 | Responsive HFlowContainer grid, card-style rows, humanized filter tabs, section headers, 6 SVG icons, FiveParsecsCampaignPanel responsive base. | 0 | 0 (UX) |
| Session 48d: Battle Reconciliation Implementation | Apr 8, 2026 | 4 parts: missing mechanics, UX 5→3 screens, AI-type deploy markers, rich result contract. | 0 | 0 (impl) |
| Session 48c: Battle Reconciliation Plan | Apr 8, 2026 | Discovered dual battle paths (CampaignTurnController=live, BattlePhase.gd=dead); plan approved. | 1 architecture | 1 (plan→impl 48d) |
| Session 47b: World Arrival + PostBattle Rewire | Apr 8, 2026 | World Arrival UI (trait/rivals/license/forge); 10 travel event mutations wired; PostBattlePhase orchestrator rewiring (CPM was using wrong 5-step stub); 3 deprecated files; equipment effect UI. | 1 routing bug | 1 |
| Session 47: Equipment Pipeline Fix | Apr 8, 2026 | All 12 phases implemented: fabricated traits fixed, armor saves un-broken, single-use removal, overheat tracking, 7 protective devices, consumables, gun mods, utility devices, on-board items, Compendium traits. | 12 phases | 12 |
| Session 46: Equipment Pipeline Audit | Apr 8, 2026 | Found 3 fabricated traits (Focused/Heavy/Overheat); armor saves completely broken; single-use items never removed; 11-phase fix plan produced. | 3 critical | 0 (audit, fixed in 47) |
| Session 45: Bug Hunt Runtime QA | Apr 8, 2026 | 14 bugs fixed; HubFeatureCard pending data pattern; BugHuntTurnController call_deferred; full Bug Hunt flow verified end-to-end. | 14 | 14 |
| Session 18: Rules Audit + Schema Unification | Mar 30, 2026 | Full QA_RULES_ACCURACY_AUDIT.md pass: 308→0 UNVERIFIED entries. PDF-verified all remaining items. 2 rules bugs FIXED (rival follow ≤3→≥5 per p.72, license cost single-roll→two-roll per p.72). 3 data duplication CONFLICTs FIXED (Stealth/Street/Salvage generators unified onto Compendium schema). StreetFightPanel hostile check updated for new schema. EquipmentPanel credits warning threshold fixed (500→1). Headless compile verified: 0 errors. | 2 rules bugs + 3 conflicts | 5 (all fixed) |
| Runtime QA Wave 5 (Cross-Mode + DLC) | Mar 23, 2026 | Bug Hunt data model isolation MCP-verified: main_characters/grunts (flat), NO ship/patrons/rivals, campaign_type="bug_hunt". Serialization roundtrip: squad/meta keys correct, no ship data. DLC 2-layer gating: 33 flags across 3 packs (TT=7, FH=17, FG=9), ownership+toggle verified, unowned-pack gate blocks correctly, serialize/deserialize roundtrip PASS. Difficulty: EASY(+1 XP), HARDCORE(+1 enemy, -2 seize), INSANITY(story disabled, -3 seize, unique individual forced) all correct. Enum sync: GlobalEnums(31)=GameEnums(31), FPGameEnums(37, +6 expected). Cross-load gap: `_detect_campaign_type()` added to GameState (Mar 23 fix). | 0 bugs | 0 (cross-load fixed) |
| Runtime QA Wave 4 (Battle System) | Mar 23, 2026 | BattleResolver MCP-tested: 4v5 combat resolved (5 rounds, crew victory, held field, all 10 result keys). Injury D100: full coverage verified (zero gaps/overlaps), GRUESOME_FATE(1-5)/FATAL(6-15) confirmed. Bot injury table verified. Post-battle 14-step pipeline: all 10 subsystems loaded+instantiated as RefCounted, Steps 4/7/8/9 exercised end-to-end (payment 8cr, loot 1 item, injury processed, 3 XP each). Oracle tiers: 3-tier cumulative architecture (5→12→14 components), purely UI layer. BUG-040 found+fixed. 2 weapon values flagged for book check. | 1 bug | 1 (BUG-040 InjuryProcessor turn_number) |
| Runtime QA Sprint (Waves 1-3) | Mar 23, 2026 | User-facing campaign creation + turn + save/load. BUG-036 psionic fully fixed (BaseCharacterResource property added). Upkeep formula verified (4 crew + 1 ship = 5 credits). Save roundtrip: psionic, equipment key, dual-sync all PASS. EliteEnemies.json truncation fixed. credit_rewards.json deleted (fabricated dead code). | 2 bugs | 2 (BUG-036 root cause, EliteEnemies.json truncation) |
| Phase 48: Full Book Verification | Mar 23, 2026 | All 12 data domains verified against core_rulebook.txt + compendium_source.txt. 190+ fixes: motivation table 13 errors, 3 Strange Characters added, 5 fabricated weapons removed, 4 Compendium tables rewritten, salvage rules rewritten, prison planet reclassified, starting credits fixed | 190+ data | 190+ (all fixed) |
| Phase 47: Data Rewrite | Mar 22, 2026 | 7 fabricated JSON files rewritten from Core Rules. Payment formula fixed (100x inflated). 17 JSON files wired to consumers. Species exception handling added | 150+ data | 150+ (all fixed) |
| Phase 46: MCP Runtime QA | Mar 22, 2026 | 7-step campaign wizard MCP playthrough, 6 LSP parse errors found+fixed, psionic_power crash fixed, touch target audit (12 MainMenu buttons below 48px), empty state verification | 7 runtime | 7 (all fixed) |
| Phase 46: Internal Consistency Audit | Mar 22, 2026 | 4-domain cross-check (weapons/economy/injuries/enemies), 15 data fixes, 12 D100 tables verified PASS, 8 world traits added, economy values tagged | 15 data | 15 (all fixed) |
| Phase 46: Deferred Items + Audit Prep | Mar 22, 2026 | D100 weighted CharacterCreator randomize, NotableSightsSystem.gd, unique individual D100 table wiring, orphan JSON cleanup (4 deleted), QA doc updates | 0 | 0 (wiring + cleanup) |
| QA Coverage Sprint | Mar 21, 2026 | Character shadowing fix (7 files), 82 new unit tests (3 files), 47→44 NOT_TESTED, all 170 confirmed COMPLETE, integration gap analysis | 0 | 0 (coverage + verification only) |
| QA Playthrough | Mar 20, 2026 | 5-turn campaign (T3-T5): world→battle→post-battle→late phases. Sprint 9 runtime fixes. | 3 runtime | 3 (UpkeepPhaseComponent _help_dialog, CrewTaskComponent _help_dialog, TacticalBattleUI type inference) |
| QA Sprint | Mar 20, 2026 | BUG-033/034 + UX-091/092 fix sweep | 4 | 4 (BUG-033 was already fixed, confirmed; 3 code fixes) |
| Phase 33 | Mar 20, 2026 | Codebase optimization (12 sprints) — PostBattlePhase decomp, WorldPhaseComponent inheritance | 0 | 0 (refactor only) |
| Phase 32 | Mar 16, 2026 | 2-turn campaign playthrough + battle companion | 4 crashers | 4 (inline) |
| Phase 31 | Mar 16, 2026 | Bug fix sprint (10 bugs + 3 UX) | 13 | 13 |
| Phase 30 | Mar 16, 2026 | Core Rules parity — difficulty enum fix | 1 critical | 1 |
| Phase 29 | Mar 15, 2026 | 2-turn MCP playthrough, save/reload | 4 | 1 (inline) |
| Battle UI QA | Mar 15, 2026 | Battle phase UI audit | 18 | 11 |

---

## Completed Priority Items (Mar 21, 2026)

All 5 previous priority items are now verified:
- ~~5-turn campaign playthrough~~ — PASS (Turns 3-5, all counters consistent, 0 crashes)
- ~~Equipment save/reload lifecycle~~ — PASS (9-stage chain verified end-to-end)
- ~~Difficulty modifier matrix~~ — PASS (18/18 Core Rules, 40+ methods, 11 call sites)
- ~~PostBattlePhase subsystem regression~~ — PASS (19/19 signals, 100% emission isolation)
- ~~WorldPhaseComponent inheritance regression~~ — PASS (9/9 components, 3 runtime fixes applied)

## Next Priority Items

1. ~~**GENERATOR WIRING FIX**~~ — **COMPLETE** (Mar 23). All 16/16 generators fixed. 24 regression tests passing.
2. ~~**RULES ACCURACY AUDIT**~~ — **COMPLETE** (Mar 23). 925/925 values verified.
3. **Runtime QA sprint** — MCP-automated playthrough to verify generator fixes work in gameplay
4. **Remaining NOT_TESTED coverage** — 44 mechanics need unit tests
5. ~~**Victory condition metric tracking**~~ — **FIXED** (Mar 23). VictoryChecker now reads from `progress_data` (where counters are incremented) instead of phantom `battle_stats`/`resources` dicts.
6. ~~**Battle UI standalone mode**~~ — **FIXED** (Mar 23). Added `_check_standalone_mode()` deferred fallback — shows tier selection overlay when `initialize_battle()` not called.

---

## Cross-Reference Index

| Document | Location | Purpose |
|----------|----------|---------|
| **Rules Accuracy Audit** | `docs/QA_RULES_ACCURACY_AUDIT.md` | Master rulebook verification (925 values). Data + generator wiring COMPLETE |
| **Integration Scenarios** | `docs/testing/QA_INTEGRATION_SCENARIOS.md` | 10 end-to-end workflow test scripts |
| **UX/UI Test Plan** | `docs/testing/QA_UX_UI_TEST_PLAN.md` | Systematic UI coverage (theme, responsive, animations) |
| Demo QA Script | `docs/testing/DEMO_QA_SCRIPT.md` | Demo recording gate script |
| UIUX Test Results | `docs/testing/UIUX_TEST_RESULTS.md` | Historical MCP results (71 bugs) |
| Battle UI Bugs | `docs/testing/BATTLE_UI_QA_BUGS.md` | Battle-specific bug tracker |
| Game Mechanics Map | `docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md` | 170 mechanics implementation status |
| Test Matrices | `.claude/skills/qa-specialist/references/test-matrices.md` | 1,355 combinatorial test cases |
| Edge Cases | `.claude/skills/qa-specialist/references/edge-cases.md` | 120+ boundary conditions |
| MCP Testing Guide | `.claude/skills/qa-specialist/references/mcp-testing-guide.md` | Automation recipes |
| gdUnit4 Patterns | `.claude/skills/qa-specialist/references/gdunit4-patterns.md` | Unit test templates |
| Bug Tracker | `.claude/skills/qa-specialist/references/bug-notes.md` | Canonical bug list |
| Playtesting Strategy | `docs/testing/EFFICIENT_PLAYTESTING_STRATEGY.md` | Testing methodology |
