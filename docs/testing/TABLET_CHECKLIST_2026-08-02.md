# Sunday Tablet Checklist — Aug 2 2026

**Purpose**: spend device time ONLY on what a desktop cannot settle.

Before this sprint, layout / DPI / rotation were all assumed to be device-blocked. That
assumption was wrong. A desktop window pixel **is** a device dp in this project:

```text
Device:   design space = (physical px / screen_get_scale()) / 1.16 = dp / 1.16
Desktop:  screen_get_scale() == 1.0 on Windows       → design space = window_px / 1.16
```

Measured: a 393×851 window yields design `338.79 × 733.42`, and `338.79 × 1.16 = 392.99998`.
The 1.16 is derived, not magic — `SettingsManager._apply_ui_scale()` cancels the square-1080
base stretch via `stretch_cancel = 1080 / short_axis`.

So geometry is now a **desktop** job (`tests/tools/verify_layout.gd`, 34 screens × 6 sizes).
Everything below is what genuinely remains.

---

## Do NOT re-test on device (already settled on desktop)

Re-testing these burns the device window for no new information.

| Settled | Where | Evidence |
|---|---|---|
| Control geometry / off-screen overflow | `verify_layout.gd` | 34 screens × 6 sizes, measured rects |
| Portrait vs landscape breakpoints, column counts | same | 393×851 reports MOBILE / portrait / 1 column |
| Unwrapped-label overflow (the MainMenu title bug shape) | same | fires on revert of `7590c67b` |
| Touch-target heights in dp | same | ≥48dp floor measured, not asserted from config |
| Campaign-state correctness (post-battle, rollover, save/load) | `verify_post_battle.gd` | 45 rows, campaign Resource read back |
| Legacy save loading, every historical `origin` shape | Walk B | 5 saves, float 6.0/7.0/17.0, String, missing |

As of the Jul 30 close-out the sweep is **198/198 green with a campaign loaded** (33
screens × 6 sizes), so no screen should be clipped on arrival. If one is, that is a
finding the desktop sweep cannot see — capture the size and the screen name, and check
whether the sweep reproduces it at that size with `-- campaign=<save>`.

**Worth a deliberate look on the device** (changed late and verified on desktop only):

- The **portrait gutter is now 8px** on each side. Confirm it reads as breathing room on a
  real panel, not as a misalignment, and that nothing is cut by the screen's rounded
  corners (that part IS device-bound — see safe-area below).
- **Short-screen scrolling.** ⚠ **CORRECTED 2026-09-08 — the old text said "a tablet in
  landscape should NOT scroll", and that has been false since 2026-09-04.** The gate is now
  `if (short_viewport or overflows)` (`ShortScreenScroll.gd:202`); the `overflows` clause was
  added by T11-01, so a tablet landscape screen DOES scroll whenever its content overflows,
  which is the fix working rather than a defect. A walk that treats tablet-landscape scrolling
  as a regression is reading a stale expectation. Screens using it: World Phase, PreBattle,
  PostBattle, Campaign Dashboard, Campaign Editor, Events, Advancement, Print Sheet. The live
  question is the second one this bullet always asked: does the scroll feel like ONE gesture
  rather than two nested ones? PreBattle and Campaign Dashboard were clean on #28; the other
  six are still open.
- The **journal filter block starts collapsed** on a phone and expanded on a tablet;
  rotating a tablet to a short landscape should collapse it.
- The **main-menu showcase card** drops its cover art, then its feature bullets, before it
  ever pushes the CTA button off — verify the CTA is always reachable.

---

## 1. Safe-area insets — HIGH, wholly device-bound

`DisplayServer.get_display_safe_area()` returns the entire monitor on Windows, so this is
untestable off-device and completely unverified.

✅ **ALL FOUR ANSWERED on deploy #29 (2026-09-08).** ⚠ It needed a BUILD, not just a walk:
the TB361FU has no physical cutout, so a correct implementation and a broken one produce the
**identical frame** and no screenshot can separate them. #29 added the `[SAFEAREA]` print (the
one call to `get_display_safe_area()` repo-wide, `PortraitChrome.gd:191`) and the cutout was
simulated with `cmd overlay enable com.android.internal.display.cutout.emulation.{tall,waterfall}`.
Full detail: [docs/qa/TABLET_BASELINE_2026-09-08.md](../qa/TABLET_BASELINE_2026-09-08.md) § §1.

- [x] Status bar / notch does not overlap the MainMenu title or the SettingsOverlay band
      — **PASS, by a one-variable A/B.** PORTRAIT frame `70baf888` -> `e9dbfb2e` (**moved**,
      as predicted); LANDSCAPE `6a73d2bd` -> `6a73d2bd` (**identical**, also as predicted — every
      inset there is smaller than the clamp already in force). Title top measured
      **82 -> 107 physical px = 21.6 design px**; predicted 22 from
      `maxf(margin_t, _top_right_overlay_bottom() + margin)` = `maxf(0,60)=60` -> `maxf(82,60)=82`.
- [x] Gesture-nav bar does not sit on top of any primary action button
      — **PASS in BOTH nav modes.** Device ships 3-button (`navigation_mode=0`); gesture nav
      switched on deliberately and read back. `navigationBars` reports `visible=false` under
      `screen/immersive_mode=true` in both, and the bottom row responds in both.
- [x] Rotate to landscape — insets swap sides correctly, nothing clipped
      — **PASS.** The same `tall` overlay yields `left: 82` in landscape and `top: 82` in
      portrait. All four edges verified against Android's own `mDisplayCutout`
      (`Rect(40,96-40,0)` -> `left 34, top 82, right 34, bottom 0` at the x0.86207 stretch
      ratio) — including the FAR edges, which are derived as `win - pos - size` rather than read.
- [x] Campaign Dashboard bottom row reachable with the gesture bar present
      — **PASS.** ⭐ The row is at y **1526-1578** and the `navigationBars` source is
      `frame=[0,1480][2560,1600]`, so **the entire row lives inside the nav bar's region** — the
      exact condition this box is about, and invisible without dumping the inset sources.
      Manage Crew at (1070, 1552) opened the crew screen in both nav modes. Non-mutating buttons
      only; campaign md5 `0bdbbc31` before and after every arm.

## 2. Real touch physics — HIGH

Desktop mouse-wheel scrolling hid **F9** (drawer touch-scroll) during the Jul 5 sprint.
A mouse is not a finger; this class of bug is only visible on glass.

- [x] Vertical touch-scroll works in every ScrollContainer (Crew/Enemy drawer especially)
      — **PASS**, deploy #28, 2026-09-08. TacticalBattleUI Crew drawer, frame md5
      `7d06483a` -> `9227251d`; the list moved Bryn Ito/Dex Kovac -> Yuri Drake..Nyx Ward.
- [x] Fling momentum feels right; no rubber-band snap-back
      — **PASS**, with a stated harness caveat. Direct frame sampling at +0.08..2.0 s could
      NOT see it (a `screencap` takes ~100-200 ms, longer than the inertia tail) and returned
      a confident false negative. Measured instead by CONSEQUENCE: identical 800 px drag, only
      duration varied → three different landing depths (600 ms Damage/Line of Sight,
      250 ms Luck, 60 ms Auto/Bulky). ⚠ Non-monotonic because `adb input swipe` under-delivers
      MOVE events at 60 ms; `input motionevent` does not exist on this device, so a true
      velocity ramp is not sendable over adb. No snap-back observed.
- [x] Drag on a container whose children are Buttons still scrolls (Button children eat drag)
      — **PASS**. The drag STARTED on Mars Stark's `Aim` button and crossed three more button
      rows: the drawer scrolled, no stun markers appeared, nobody was marked down, battle log
      unchanged. Control arm: a deliberate tap on the same button class DID fire, opening
      Keyword Info "Damage" (cite *Rules p.54*).
- [x] Multi-touch does not double-fire a button
      — **PASS on deploy #29, measured three ways with a numeric readout.** Target was the
      Battle Simulator's Crew Size `SpinBox` (range 3-6), chosen because the value is a
      **count**: one press = +1, so a double-fire is visible as +2 rather than as "nothing
      happened". Injected with a `uinput` virtual multi-touch touchscreen; Android's own
      pointer-location overlay certified the landing as **`P: 2 / 2` at `X: 222.1, Y: 1070.0`**
      — exactly the injected panel coords — with both crosshairs straddling the up chevron.
      | gesture | value | fires |
      |---|---|---|
      | single-finger tap (control) | 3 → **4** | **1** |
      | two fingers, same SYN frame | 3 → **3** | **0** |
      | two fingers, staggered (finger 2 lands while finger 1 is held) | 3 → **3** | **0** |
      ⭐ **Multi-touch does not double-fire — it SUPPRESSES the press entirely.** The staggered
      arm is the discriminating one: finger 1 had already pressed, and the arrival of finger 2
      cancelled it. `emulate_mouse_from_touch` emulates pointer 0 only, and a second pointer
      cancels the emulated press. Recorded as a mild usability note, not a defect: a tap with a
      second finger resting on the glass does nothing, which reads as palm rejection.
      ⚠ **The old text of this box is superseded on every point** and is corrected rather than
      dropped. It claimed the inventory was *"exactly TWO controls"* (`UnitActivationCard`,
      `CharacterCard`) still carrying the T11-36 dual-family shape — **both were migrated to
      `TapGesture` in the Sep 8 sprint and shipped in #29**; their `InputEventScreenTouch`
      mentions are now only the comments recording the fix. It also named **T11-49** as the
      blocker for reaching a standalone battle — **that is fixed and was re-verified on
      hardware today** (Return from the Battle Simulator left the campaign save byte-identical,
      md5 `07988ca5`, 81,221 bytes, `active_battle` intact).
      ⭐ **Census re-run and now complete:** `grep -rn "InputEventScreenTouch" src/` returns
      **six hits, of which five are comments or the debug `TouchChainProbe`**. Every tap path
      in the app is therefore either a real `Button`/`BaseButton` (engine state machine, mouse
      family) or `TapGesture` (mouse family only, by explicit design — `TapGesture.gd:25`).
      ⚠ **The one live `InputEventScreenTouch` handler that remains is a separate finding — see
      the crew-swipe row in [docs/qa/TABLET_BASELINE_2026-09-08.md](../qa/TABLET_BASELINE_2026-09-08.md).**
- [x] Long-press does not select text in RichTextLabel help/EULA content
      — **SPLIT RESULT, now confirmed on #29 with a control arm.** The two surfaces this box
      NAMES are safe by construction: EULA sets `_eula_text.mouse_filter = MOUSE_FILTER_IGNORE`
      (`EULAScreen.gd:181`), and HelpScreen's `_content_label` never enables `selection_enabled`.
      ⚠ A THIRD RichTextLabel the box does not name **DOES** select: `DebugScreen._log_display`
      (`:126`). Measured on #29 — a 1500 ms press-drag ACROSS the log text produced a **visible
      blue selection over eight lines**, while the identical gesture on the Settings page
      **scrolled** (`3d31e0d5` -> `acb2ac06`). Filed as **T11-54**.
      ⚠ **CORRECTION: this row used to end "Harmless while the pane is short, and the pane is
      permanently short for a different reason (T11-50)." That mitigation EXPIRED the moment
      T11-50 was fixed in #29.** The pane now populates from the real engine log up to
      `MAX_LOG_LINES := 200`, far more than one screen — so the drag that cannot scroll is now a
      drag on content the player genuinely needs to scroll. And the screen is **not**
      release-gated: `SettingsScreen._on_debug_pressed()` (`:1043`) hangs off a `DEBUG` button
      built unconditionally at `:281-291`, on a page that tells the player *"Copy the log below
      and include it when reporting bugs."*
      ⭐ **Fixing one finding removed the reason another was harmless** — worth checking
      whenever a "harmless because X" note is written down.
      ⚠ My first attempt at this box read as a PASS and was worthless: the drag ran y=900→500
      while the text occupies y≈295-600, so it started in empty space below the content.

## 3. Physical legibility and thumb reach — HIGH, subjective by nature

Measurement says ≥48dp; only a hand says whether it is *comfortable*.

- [ ] FONT_SIZE_XS (11) captions readable at arm's length
- [ ] Primary actions reachable one-handed in portrait
- [ ] Deep Space palette legible at low brightness (a tester on a couch, not a desk)
- [ ] Colorblind modes verified on the physical panel, not a calibrated monitor

## 4. ARM performance and thermals — MED

- [x] Frame pacing: no hitching on Campaign Dashboard scroll
      — **PASS on deploy #29, measured not eyeballed.**
      `dumpsys SurfaceFlinger --latency` on the Godot SurfaceView layer, scrolling the
      dashboard right column with 10 alternating swipes: **median 22.20 ms, p90 22.23,
      p95 22.23, p99 22.24, max 22.24** — **zero** intervals over 33 ms (a dropped frame at
      60 fps) and **zero** over the SOP's 50 ms hitch threshold. `p90 = p95 = p99 = max` is
      not just "no hitch", it is **no variance at all**. Idle baseline for comparison:
      median 11.17 ms, max 22.39, also 0 / 0.
      ⚠ **`dumpsys gfxinfo` is STRUCTURALLY BLIND to this app** — Godot renders through a
      SurfaceView and bypasses the HWUI pipeline gfxinfo measures. It reports
      `Total frames rendered: 0` with `Janky frames: 0 (0.00%)`, which **reads like a perfect
      score and means nothing was measured**. Do not quote gfxinfo for this app.
      ⚠ The scrolling arm had to be re-run: the first attempt's 12 swipes all returned a
      **byte-identical** frame because the column had already hit its stop, so pacing was
      being measured while nothing scrolled. The rerun asserts movement — 9 of 10 swipes
      moved the frame.
      ⭐ **Measured incidentally: the app renders 60 fps and the panel shows 45.** Sampled
      simultaneously, the in-app counter read **FPS: 60** on all 10 frames while the present
      interval held a steady **22.20 ms = 45 fps**. The panel is **90 Hz** (11.11 ms, straight
      off the trace) and `project.godot:26` caps at `run/max_fps=60`, which cannot align to it
      — a 16.67 ms frame misses the next vsync and lands on every *second* refresh. Not a
      defect (an even 45 fps is smooth) and not a fail, but ~a quarter of the rendered frames
      never reach the glass. It also retires `Engine.get_frames_per_second()` as a pacing
      instrument: it measures the render loop, not what the player sees.
- [x] Battlefield map pan/zoom smooth with a full terrain set
      — **PASS on deploy #29, measured on the real `BattlefieldMapView` with a full generated
      3×3 ft table** (16 sectors, ~24 terrain pieces, deployment zones, a Loot Cache
      objective), reached through the Battle Simulator so no campaign was at risk.
      | arm | median | p90 | p95 | p99 | max | >33 ms | >50 ms |
      |---|---|---|---|---|---|---|---|
      | IDLE (map on screen, no input) | 11.13 ms | 22.24 | 33.33 | 33.34 | 33.36 | **0** | **0** |
      | PAN (80 steps, 25 ms apart) | 11.12 ms | 22.30 | 33.33 | 33.34 | 33.37 | **0** | **0** |
      | ZOOM (40 steps, 25 ms apart) | 11.13 ms | 22.24 | 33.33 | 33.36 | 33.36 | **0** | **0** |
      | PAN STRESS (160 steps, 8 ms apart) | 11.12 ms | 22.24 | 22.26 | 33.34 | 33.38 | **0** | **0** |
      ⭐ **The pan/zoom arms are statistically indistinguishable from IDLE**, and tripling the
      input rate *improved* p95 (33.33 → 22.26). Redrawing a full terrain set costs less than
      the measurement floor. Median 11.12 ms = one frame per 90 Hz refresh.
      ⭐ **Pixel-deterministic and reversible**: 20 LEFT + 20 UP then 20 RIGHT + 20 DOWN
      returns the frame **byte-identical** to baseline (`041c2f3b`), and so does the 160-step
      stress arm. `KEYCODE_0` after two zooms and two pans also restores it byte-identically.
      Zoom out from 2 steps returns **byte-identically** to the 1-step frame (`42f273fd`).
      ⚠ **CORRECTION — this box previously read "CANNOT BE ANSWERED AS ASKED".** That was
      wrong, and it is corrected here rather than rewritten silently. It reasoned from the
      touch binding alone and never asked whether another route reached the same code. **Three
      do**, and all three are now measured on hardware:
      | route | driver | result |
      |---|---|---|
      | **Keyboard** — arrows pan, `+`/`-` zoom, `0` reset | `adb shell input keyevent` | **works** |
      | **Wheel** — `MOUSE_BUTTON_WHEEL_UP/DOWN` | `input mouse scroll … --axis VSCROLL,n` | **works** |
      | **Middle-drag** — `MOUSE_BUTTON_MIDDLE` | `uinput` virtual mouse (`/system/bin/uinput`) | **works** |
      ⭐ **Both maps set `focus_mode = Control.FOCUS_ALL` with a comment saying it is for the
      keyboard pan/zoom shortcuts** (`BattlefieldMapView.gd:129`, `HexStarMap.gd:62`). The
      keyboard path is deliberate, documented in the source, and was simply never looked for.
      ⚠ **What IS still true, and is the real finding: none of the three is reachable by a
      finger.** Android's `emulate_mouse_from_touch` synthesises **LEFT** only — never MIDDLE,
      never WHEEL — and there is **zero `InputEventPanGesture` / `InputEventMagnifyGesture`
      repo-wide**. Measured on the Galaxy Log: three finger drags left the frame
      **byte-identical** (`9b4947d3`), while the control arm (a tap on the *Foch II* hex)
      changed it (`a7911e77`) and opened `WorldDetailPopup`. So the map is **fully functional
      for a tablet with a keyboard case or a Bluetooth mouse, and tap-only for a bare finger.**
      ⭐ **Two surfaces, not one.** `HexStarMap.gd:6` records that its pan/zoom was *"adapted
      from BattlefieldMapView (the only pan/zoom in the codebase)"* and inherited the binding
      (`:207` = MIDDLE/RIGHT). One implementation, copied once, both pointer/keyboard-only.
      ⚠ **The defect to fix is now sharper: `TacticalBattleUI.gd:853` tells the player *"tap a
      sector for its rules; pinch/scroll to zoom, drag to pan."*** Scroll-to-zoom and
      drag-to-pan **do** exist — for a mouse. **Pinch does not exist at all**, and none of the
      three works for the finger the string is written for. So it is not a claim about
      nothing (the `CheatSheetPanel` shape); it is a claim about the **wrong input device**.
      The cheap fix is to make the string conditional, or to bind pan to a LEFT-drag once
      `TapGesture`'s 16 px slop separates it from a tap — the code behind it already works.
      ⚠ **CORRECTION — pinch IS testable, was tested, and the cause is a one-line project
      setting.** `adb shell input` is single-touch, but **`uinput` is not**: a virtual
      multi-touch touchscreen mirroring the real `himax-touchscreen` ABS ranges
      (`ABS_MT_POSITION_X` 0..15999, `Y` 0..25599, `INPUT_PROP_DIRECT`, protocol B) injects a
      genuine two-finger pinch. Android's own pointer-location overlay certified it:
      **`P: 2 / 2`**, both crosshairs drawn on the map.
      **Result: the map changed by exactly ZERO pixels** through fingers-down, full spread and
      release. The only change anywhere on screen was **bbox (421,93)-(848,373) — the
      `SectorRulesPopover` rect**: `emulate_mouse_from_touch` turned the *first* pointer into a
      synthetic LEFT click that opened *"Sector D2"*, and the second pointer did nothing.
      **A pinch is read as a single tap.** Measured, not inferred.
      ⭐ **Root cause named:** Godot 4.6 registers
      **`input_devices/pointing/android/enable_pan_and_scale_gestures`**, which gates whether
      Android multi-touch becomes `InputEventPanGesture` / `InputEventMagnifyGesture` at all.
      It defaults to **`false`** and is **absent from `project.godot`** (which sets only
      `pointing/emulate_touch_from_mouse=true` at `:107-109`). So there are **two independent
      blockers, either fatal alone**: the engine never emits the events, **and** `src/` has
      **zero handlers** for them. That upgrades this row from *"the interaction does not
      exist"* to a concrete two-part fix — flip the setting, add the two `_gui_input`
      branches — and the pan/zoom code they would call is already proven working above.
      ⚠ The online class reference documents `InputEventMagnifyGesture` but never says which
      platforms **emit** it; the engine's own `ProjectSettings` list is the ground truth.
      ✅ **FIXED AND VERIFIED ON HARDWARE — deploys #30 (vc 13) and #31 (vc 14), 2026-09-09.**
      The two-part fix landed exactly as scoped above, plus a third part the device found.
      `project.godot` now sets `pointing/android/enable_pan_and_scale_gestures=true`;
      `BattlefieldMapView` and `HexStarMap` each gained `InputEventMagnifyGesture` (pinch) and
      `InputEventPanGesture` (two-finger pan) branches; and single-finger **drag-to-pan** was
      added on the MOUSE family with a 16 px slop, because that is where a finger already
      arrives via `emulate_mouse_from_touch`.
      | measured on device | before (#29) | after (#30/#31) |
      |---|---|---|
      | one-finger drag on the battlefield map | nothing (frame byte-identical) | **map pans ~450 px**, matching a 450 px swipe |
      | tap a sector | popover opens | **popover still opens** (control arm — the fix did not cost it) |
      | drag across the map | **opened the sector popover mid-drag** | **no popover** |
      | two-finger pinch | 0 px, read as a single tap | **zooms to ZOOM_MAX** |
      ⭐ **A SECOND DEFECT WAS FOUND BY THE FIX, ON GLASS, THAT NO HEADLESS CASE COULD SEE.**
      On #30 the pinch zoomed *and* opened a "Sector D1" popover. Cause: a second pointer
      **cancels** the emulated mouse press, and that cancel arrives as a LEFT **release** still
      inside the 16 px slop — so the tap-vs-drag latch passed it through as a genuine tap.
      The slop test is structurally the wrong instrument, because the cause is **pointer
      count**, which the mouse family cannot observe. Fixed on #31 by letting the TOUCH family
      **veto** an armed tap (`index > 0` disarms) while never performing an action of its own
      — which is what keeps it clear of the T11-36 double-fire trap. One-variable proof: the
      identical injected pinch, from the identical starting frame (`d28c2619`), zoomed **with**
      a popover on #30 and **without** one on #31.
      ⚠ **The harness nearly produced a false failure and a control arm caught it.** The first
      pinch attempt on #30 came back byte-identical, which reads exactly like "the fix did not
      work". A single-finger drag through the *same* uinput device also did nothing — proving
      the **harness** was broken, not the code. Two causes: Git Bash rewrote the on-device path
      `/data/local/tmp/…` into `C:/Program Files/Git/data/local/tmp/…` (needs
      `MSYS_NO_PATHCONV=1` and `//data/…`), and my ABS→screen mapping was wrong.
      ⭐ **The rotation mapping recorded on 2026-09-08 was WRONG and is corrected here:** it is
      **direct**, `screen_x = ABS_X / 10` and `screen_y = ABS_Y / 10`, with **no axis swap** —
      measured off the pointer overlay (`ABS_X 8000 → X: 800.0`, `ABS_Y 10300 → Y: 1030.0`).
      The earlier note had X and Y transposed, which put every "on the map" touch off the map.
      ⚠ Pinned by `tests/unit/test_map_touch_gestures.gd` (14 cases), detection-proven by
      **three** isolated reverts, each caught by exactly one case: the multiplicative→additive
      zoom conversion, the fire-on-press, and the second-finger veto.
      ⚠ **Still open, recorded not fixed:** `TapGesture` has the same second-finger exposure
      (a two-finger touch on any tap surface fires the tap), including `HexCell`. Harmless on
      surfaces nobody pinches; it matters on the maps, which is why both maps veto locally
      rather than the shared helper being changed under 52+ call sites.
- [x] Sustained 15-min session — check for thermal throttle
      — **PASS on deploy #29 — 26.3 minutes of continuous heavy load, no throttling and
      effectively no temperature rise.** Run together with the memory box below, as planned.
      Load was real play, not idle: **3 full battle cycles** (TacticalBattleUI + the 14-step
      post-battle sequence each time), 2 world phases, a NarrativeScreen event, a
      PreBattleUI deployment, and 3 cold launches.
      | | start | end | delta |
      |---|---|---|---|
      | battery temperature | **29.3 °C** | **29.5 °C** | **+0.2 °C** |
      | `Thermal Status` | **0** | **0** | **0 on all 29 samples** |
      | battery level | 93 % | 92 % | −1 % over 26 min |
      ⭐ **Thermal Status never left 0** across the whole run — not a single sample showed
      LIGHT throttling, let alone MODERATE. The 0.2 °C rise is inside the sensor's own
      quantisation (`dumpsys battery` reports tenths).
      ⚠ The plan's warning about ambient drift is what makes this readable: bare CPU numbers
      were **not** comparable across days (2026-09-08 ran ~5 °C above the #27 baseline), so the
      measurement is battery temperature + `Thermal Status`, both portable.
- [x] Cold-start time to MainMenu
      — **PASS.** `am start -W`, `LaunchState: COLD`: **796 ms** and **817 ms** on two runs
      against deploy #27's **979 ms** — **−18.7 %**; a third sample later the same day read
      899 ms. Measured on 2026-09-08 and recorded in
      [docs/qa/TABLET_BASELINE_2026-09-08.md](../qa/TABLET_BASELINE_2026-09-08.md)
      §"Cold start"; the box had simply never been ticked.
- [x] Memory: no growth across 5 campaign turns
      — **PASS on deploy #29. Cold-to-cold over 26.3 minutes of heavy play, every figure
      inside the 1.8 % sampling scatter this project already measured.**
      | | first cold launch | final cold launch | delta |
      |---|---|---|---|
      | **Graphics** (`EGL mtrack` + `GL mtrack`) | 446,992 KB | 449,040 KB | **+2,048 KB (+0.5 %)** |
      | **Native Heap** | 144,552 KB | 145,977 KB | **+1,425 KB (+1.0 %)** |
      | **TOTAL PSS** | 701,841 KB | 708,457 KB | **+6,616 KB (+0.9 %)** |
      ⭐ **Three cold launches, 17 and 9 minutes of heavy play apart, agree to within 1.0 %**
      (native heap 144,552 → 145,801 → 145,977 KB). The mid-run one was not planned — it was
      forced by the soft-lock below — and it turns a two-point comparison into a three-point
      one, which is strictly better evidence.
      ⭐ **The in-session working set is flat too**, which is the arm a cold-to-cold comparison
      cannot see: native heap sat in **288-318 MB** for the entire campaign session with no
      upward drift, peaking in `TacticalBattleUI` (314,596 KB) and falling back on the
      dashboard every time. Graphics oscillated in a **434-456 MB** band with no trend across
      29 samples.
      ⚠ **Deviation from the box's wording, stated plainly: this is 26 minutes and 3 full
      battle cycles across turns 10-12, not 5 complete turns.** The run was cut short by a
      **soft-lock defect found during it** (the post-battle sequence cannot be completed for
      the second battle of a session — see the baseline ledger), which forced a relaunch and
      then blocked turn 12. The box is ticked because the decisive instrument — cold-to-cold
      process retention — is unambiguous and the working set was already flat from turn 1;
      a leak that only appears at turn 4 would have to be invisible for 26 minutes first.
      ⚠ Campaign safety: the QA save was restored byte-for-byte afterwards (md5
      `07988ca572040e0358add08a81746ebe`, 81,221 bytes, `active_battle` intact) from a
      device-side copy whose restore path was **proven before** any mutation.

## 5. Android plugins — HIGH, cannot run on desktop at all

Every one of these is a no-op or an offline adapter on desktop.

- [ ] Billing: `BillingClient` resolves; store products query returns
      — **PARKED by owner decision pending the LOI — and now also MEASURED, which found a
      SECOND, independent blocker.** The Google Play Billing plugin is **entirely absent from
      the APK**: five spellings probed against the dex of the build pulled off the device
      (`BillingClient`, `com/android/billingclient`, `godotgoogleplaybilling`,
      `GodotGooglePlayBilling`, `play/billing`) return **zero hits each**, and **zero APK
      entries** match `billing`; the control probe `play/core` returns 91+4, so the search is
      not simply broken. On screen: the store banner reads **"Development Mode — No store
      connection"** and every product button reads **"Not Available"** — i.e.
      `OfflineStoreAdapter`.
      ⭐ **Only one of the two blockers was known.** Un-parking billing needs a **build
      change**, not just the LOI decision.
- [x] Review: `InappReviewPlugin` two-step flow does not crash
      — **PASS on deploy #29.** Dex: `InappReviewPlugin` **x12** and
      `com/google/android/play/core/review` **x83**, with control probes passing
      (`org/godotengine`, `GodotPlugin` found; a nonsense string absent). On device the
      **"Rate This App"** button exists at all, which is itself the presence test —
      `StoreScreen.gd:192-194` creates it only `if is_review_available()`, i.e. only if the
      singleton registered. Gating proven by a **one-variable A/B**: clearing
      `last_prompt_timestamp` alone took the button **dim → bright white** while
      "Restore Purchases" stayed pixel-identical (it is gated on `is_offline_mode()`, an
      untouched predicate — a built-in control arm). The live flow then ran: Play Core bound
      `com.android.vending/…InAppReviewService` and logged `requestInAppReview` →
      `onServiceConnected` → `OnRequestInstallCallback : onGetLaunchReviewFlowInfo`, and
      `last_prompt_timestamp` moved **0 → 1788972015**, which only `_record_review_prompt()`
      writes — reachable on Android solely from `_on_review_flow_launched()`
      (`ReviewManager.gd:185`). Timestamp decodes to **09:40:15**; the Play Core callback is
      stamped **09:40:15.125**.
      ⚠ **No review SHEET rendered, and that is not a defect** — Play suppresses the sheet on
      quota/already-reviewed and returns success anyway, and a sideloaded build is a second
      reason. The box asks whether the two-step flow crashes; it does not.
- [ ] Haptics: `SettingsManager` haptic helper actually buzzes
      — **BLOCKED BY HARDWARE, not untested.** The TB361FU has no vibrator:
      `isVibratorControllerRegistered = false`, `capabilities = []`, and the feature is absent
      from `pm list features`. Unanswerable here at any effort — do not re-attempt on this
      device. What *is* confirmed: the **Touch & Haptics** card renders, **"Haptic Feedback"
      is ON** and "Touch Sensitivity" reads 120%, so the setting is live and would be
      consulted on a device that has one. Needs the phone listed under "what needs other
      hardware".
- [x] Bug reporter: attach + submit path works end-to-end
      — **PASS on deploy #29, both halves.** **Control arm first**: Send with an empty
      description was blocked (*"Please describe what happened before sending."*) and
      **created no file**, so every later artifact is attributable to a real submit.
      **Attach** — "Attach app log (**11** lines)", later **15**, i.e. non-zero *and growing*,
      so the tail is live not cached; the saved report carries **22** context keys including
      `device_model: 'TB361FU'`, `platform: Android`, `build_type: debug`,
      `effective_columns: 4`, plus real engine output (the Mali-G57 renderer line, `[T11-07]`,
      three `[SAFEAREA]`, `[T11-26]`). **Save** — `files/bug_reports/report_1788972636_a028.json`
      (2077 bytes) landed in a directory that did not previously exist, and the on-screen
      *"Saved at: …"* path matches the file exactly. **Clipboard** — verified via Gboard's
      clipboard chip. **Submit** — `topResumedActivity=com.google.android.gm/.ComposeActivityGmailExternal`
      with a draft pre-filled to **`aftermidnightmakers@gmail.com`** (the `SUPPORT_EMAIL`
      const), subject *"FPCM Bug Report v0.9.7-alpha1 — Crash or freeze"*. Draft discarded,
      never sent; test reports deleted afterwards.
      ⚠ The `mailto:` branch was **predicted from the APK before touching the device** —
      `res://support_config.cfg` is absent from the build (control: other `.cfg` entries are
      packed), does not exist on disk, and is gitignored at `.gitignore:22`, so
      `BugReportWebhook.is_configured()` cannot be true. The webhook branch is unreachable in
      any build produced from a clean checkout.
      ⚠ **New finding, recorded not fixed**: `BugReportDialog.gd:186` sets
      `selection_enabled = true` on the "Show what is sent" panel, so a finger drag there
      **selects text instead of scrolling** — the same mechanism as **T11-54**. That census is
      now complete: `grep -rn "selection_enabled" src/` returns **exactly two sites**, and
      both are measured. Severity is lower here because `:192` pins the status label and the
      Cancel/Save/Send row **outside** the ScrollContainer, so the submit path is never
      blocked, and "Save & Copy" already captures the whole payload.
      ✅ Incidental: **KeyboardAvoidance verified on a player-facing `Window` for the first
      time** (T11-11 named this dialog and it had only ever been desk-fixed). Focusing the
      lowest input, 134 px *under* the keyboard line, scrolled it ~201 px to 67 px clear,
      while the Window itself never moved — exactly T11-15's headroom-and-scroll design.
- [x] ~~Verify the shipped APK does NOT contain `CLAUDE.md` / partnership docs~~ —
      **settled on desktop Jul 30**, this never needed device time. Unzipped
      `build/fpfh-0.9.7-sideload.apk`: 2,870 entries, 0 partnership/dev matches, and the
      only 4 markdown files packed are the legal ones the app actually reads
      (`assets/data/legal/`). **Re-run this check on the NEW build** — it verifies an
      artifact, not a config, so it has to be repeated per APK.

## 6. Scoped storage — MED

- [x] Save/load round-trip against real `user://` on Android storage
      — **PASS, three arms (deploy #29).** Cold load stable across ~20 launches;
      **lifecycle flush** verified (`KEYCODE_HOME` moved mtime and md5 `0bdbbc31` -> `30d3b4ca`
      at an identical 81,221 bytes, i.e. `GameState._notification:477-495` fires); and the
      **round-trip closes** — relaunching after that flush reloads to `a1606c26`, the
      byte-identical known-good dashboard frame. `.save`/`.bak` both 81,221 B, and **zero**
      `SaveFileWriter … recovered from …` lines, so the primary was never truncated.
- [x] Portrait upload via FileDialog (`user://portraits/`) works under scoped storage
      — **the UPLOAD PASSES; the PERSISTENCE does not, for a reason that is not about
      portraits.** All four links verified on device (deploy #29): `use_native_dialog = true`
      (`CharacterDetailsScreen.gd:1232`) opens the **real SAF picker**
      (`topResumedActivity=com.google.android.documentsui/…picker.PickActivity` — a
      Godot-internal FileDialog would have kept our own package resumed); the picker browses
      real shared storage; the PNG lands in `user://portraits/` as
      **`char_690708_7921.png`**, which is Dex Kovac's **real `character_id`**, not the
      `"char_%d" % ticks` fallback; and the hero card re-renders at once.
      ⚠ It does NOT survive, and the cause is **T11-53**: *every* edit on that screen — notes
      included — is silently discarded once the app has been backgrounded, and opening the
      picker is simply what backgrounds it. Proven by removing the picker entirely: a plain
      `KEYCODE_HOME` + resume loses a typed note just the same, while the identical edit with
      no backgrounding persists. See [docs/qa/TABLET_BASELINE_2026-09-08.md](../qa/TABLET_BASELINE_2026-09-08.md) § T11-53.
      ⚠ `CharacterCreator.tscn:155-162`'s `PortraitDialog` is a SEPARATE predicted-FAIL and is
      still unwalked (`access = 2`, no `use_native_dialog`, **no `file_selected` handler
      anywhere**).
- [x] Data export / delete (legal stack) writes somewhere the user can actually reach
      — ❌ **CONFIRMED FAIL, two independent ways (T11-52).** (a) *Destination*: pressing
      **Export My Data** wrote `files/data_export.json`, **9,200 B, mode `-rw-------`** —
      app-private internal storage; `/sdcard/Download`, `/sdcard/Documents` and the app's
      external files dir are all empty, and `SettingsScreen.gd:786-815` has no FileDialog, no
      SAF, no share intent. (b) ⭐ *Content*: the export contains **no personal data at all** —
      `LegalConsentManager.export_user_data():74-87` builds `{app_version, export_date,
      files[58]}` where each entry is `{path, size_bytes}`, despite its own docblock claiming
      "GDPR portability". Probed live: `Bryn Ito` / `Dex Kovac` / `credits` / `crew` /
      `Far Runner` / `Gamma Prime` **all absent**. The app nonetheless toasts *"Data exported to
      data_export.json in your user data folder."* (The **delete** half is A9 and is deliberately
      last — it destroys the evidence every other box depends on.)
- [x] `user://transfers/` cross-mode file-drop survives an app restart
      — **PASS, fully walked.** WRITER side is blocked by `MainMenu.gd:20` `A1_BUILD := true`,
      so the READER was driven with an envelope shaped from the real validator
      (`_validate_transfer_data:593-615`) plus a truncated twin. Truncated file **quarantined**
      to `.corrupt` with a clear `push_error`; valid file surfaced the **"Veterans Awaiting
      Orders"** dialog; **Later** kept the file; **a force-stop + relaunch brought the dialog
      back** (this is the box); **Muster In** correctly refused with *"1 veteran(s) left pending
      — crew at capacity"*, which is the **Core Rules p.63 crew cap** (`6/6`) enforced at
      `_apply_pending_transfers()`'s first check — file correctly kept for later.

---

## Method

ADB: `C:\Users\admin\Documents\Android\Sdk\platform-tools\adb.exe` (not on PATH).
Package `com.reptarus.fiveparsecs`, launcher `com.godot.game.GodotAppLauncher`.

- Tap coords **are** screencap pixel coords (`adb exec-out screencap -p`, native 1840×2944 portrait)
- `uiautomator dump` does NOT expose Godot controls (one SurfaceView) — coordinate taps only
- MCP `take_screenshot` only works on an MCP-launched instance, never an adb-launched one
- Force portrait: `settings put system accelerometer_rotation 0` then `user_rotation 0`
- Each on-device fix needs a full APK rebuild + reinstall (no hot-reload), and a full
  force-stop (not in-app Load) to reset `CampaignPhaseManager` per-turn step state

**The emulator is not a fallback** — it cannot render this app at all (godot#121035 frame
pacing, on by default), and a black `screencap` from it is meaningless because capture is
blind to SurfaceView.

---

## Must happen BEFORE Sunday (else the device tests the wrong build)

⚠ **STALE — this section describes 2026-08-02 and was overtaken 13 deploys ago**
(corrected 2026-09-08). It is kept rather than deleted because two of its three boxes are
still live, and a reader who found only the deletion would not know which.

- [x] ~~**Build a fresh APK from `campaign-editor-and-fixits`.** The newest artifact,
      `build/fpfh-0.9.7-sideload.apk`, is dated **Jul 29**...~~ — **DONE many times over.**
      That Jul 29 artifact has been superseded by `build/deploy18..27.apk`; the current
      device build is **deploy #27, versionCode 11 (2026-09-07)**. This box can never be
      "done" permanently — it means *build fresh before each session*, which is now routine.
- [ ] **Re-run the unzip check on each new APK.** Still live, and now automated:
      `py scripts/verify_apk.py <artifact>` checks for leaked `CLAUDE.md` / partnership docs
      and stray `.md` files outside the four allow-listed legal docs. ⚠ It verifies an
      ARTIFACT, not a config, so it repeats per build — that is why this box stays open.
- [ ] **Decide whether the branch merges to `master` first.** Still open (an owner decision),
      but the NUMBER is now measured rather than guessed. ⚠ The old text said "77 commits ahead
      on 2026-08-02 and further ahead now"; both halves were wrong. Measured 2026-09-08 with
      `git rev-list --left-right --count master...HEAD`: **16 ahead, 2 behind** on
      `campaign-editor-and-fixits`. It is not further ahead, and it is no longer strictly
      ahead at all — there are 2 commits on `master` that this branch does not have.

## Known-open before the device arrives

State these honestly rather than discovering them as "device bugs":

- The oldest save has one crew member with neither `reaction` nor `reactions`, so that one
  card still shows `R: 0`. Backfilling would mean inventing a stat value.
- ⚠ **`MissionSelectionUI` DOES NOT EXIST. Corrected 2026-09-08 — this entry was wrong on
  the day it was written.** It was deleted in **`a12a73fa1`** (2026-07-31, *"delete the dead
  MissionSelectionUI"*), **two days before this checklist is dated**;
  `find src tests -iname "*MissionSelection*"` returns **0 files** and that commit is an
  ancestor of HEAD. Its route key was removed from `SceneRouter` with zero `navigate_to`
  callers, and `JobOfferComponent` superseded it. ⭐ The entry cost real time: it read as
  "one screen never measured", which is indistinguishable from "one screen that no longer
  exists" — **an absence of evidence is not a finding until you confirm the subject is still
  there**, and one `find` was the whole disproof.
  The *general* limitation it described is real and still applies, so keep it in mind
  instead: **no control hosted in a `Window` is measured by the geometry sweep** — a Window
  lays out against its own rect, not `root.get_visible_rect()`. That covers every runtime
  modal (`AcknowledgeDialog`, `ItemPreviewPopup`, `RulesPopup`, …). See
  `tests/tools/verify_layout.gd:107-122`, which already carries this correction.
- Layout findings are no longer on this list: the sweep is 198/198 green with a campaign
  loaded, at all six sizes including the 360dp small-phone worst case.
