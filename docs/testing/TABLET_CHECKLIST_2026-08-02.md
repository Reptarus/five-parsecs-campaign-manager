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
- **Short-screen scrolling** kicks in below 620 design px of height, so a tablet in
  landscape should NOT scroll while a phone in landscape should. Screens using it: World
  Phase, PreBattle, PostBattle, Campaign Dashboard, Campaign Editor, Events, Advancement,
  Print Sheet. Check the scroll feels like one gesture, not two nested ones.
- The **journal filter block starts collapsed** on a phone and expanded on a tablet;
  rotating a tablet to a short landscape should collapse it.
- The **main-menu showcase card** drops its cover art, then its feature bullets, before it
  ever pushes the CTA button off — verify the CTA is always reachable.

---

## 1. Safe-area insets — HIGH, wholly device-bound

`DisplayServer.get_display_safe_area()` returns the entire monitor on Windows, so this is
untestable off-device and completely unverified.

- [ ] Status bar / notch does not overlap the MainMenu title or the SettingsOverlay band
- [ ] Gesture-nav bar does not sit on top of any primary action button
- [ ] Rotate to landscape — insets swap sides correctly, nothing clipped
- [ ] Campaign Dashboard bottom row reachable with the gesture bar present

## 2. Real touch physics — HIGH

Desktop mouse-wheel scrolling hid **F9** (drawer touch-scroll) during the Jul 5 sprint.
A mouse is not a finger; this class of bug is only visible on glass.

- [ ] Vertical touch-scroll works in every ScrollContainer (Crew/Enemy drawer especially)
- [ ] Fling momentum feels right; no rubber-band snap-back
- [ ] Drag on a container whose children are Buttons still scrolls (Button children eat drag)
- [ ] Multi-touch does not double-fire a button
- [ ] Long-press does not select text in RichTextLabel help/EULA content

## 3. Physical legibility and thumb reach — HIGH, subjective by nature

Measurement says ≥48dp; only a hand says whether it is *comfortable*.

- [ ] FONT_SIZE_XS (11) captions readable at arm's length
- [ ] Primary actions reachable one-handed in portrait
- [ ] Deep Space palette legible at low brightness (a tester on a couch, not a desk)
- [ ] Colorblind modes verified on the physical panel, not a calibrated monitor

## 4. ARM performance and thermals — MED

- [ ] Frame pacing: no hitching on Campaign Dashboard scroll
- [ ] Battlefield map pan/zoom smooth with a full terrain set
- [ ] Sustained 15-min session — check for thermal throttle
- [ ] Cold-start time to MainMenu
- [ ] Memory: no growth across 5 campaign turns

## 5. Android plugins — HIGH, cannot run on desktop at all

Every one of these is a no-op or an offline adapter on desktop.

- [ ] Billing: `BillingClient` resolves; store products query returns
- [ ] Review: `InappReviewPlugin` two-step flow does not crash
- [ ] Haptics: `SettingsManager` haptic helper actually buzzes
- [ ] Bug reporter: attach + submit path works end-to-end
- [x] ~~Verify the shipped APK does NOT contain `CLAUDE.md` / partnership docs~~ —
      **settled on desktop Jul 30**, this never needed device time. Unzipped
      `build/fpfh-0.9.7-sideload.apk`: 2,870 entries, 0 partnership/dev matches, and the
      only 4 markdown files packed are the legal ones the app actually reads
      (`assets/data/legal/`). **Re-run this check on the NEW build** — it verifies an
      artifact, not a config, so it has to be repeated per APK.

## 6. Scoped storage — MED

- [ ] Save/load round-trip against real `user://` on Android storage
- [ ] Portrait upload via FileDialog (`user://portraits/`) works under scoped storage
- [ ] Data export / delete (legal stack) writes somewhere the user can actually reach
- [ ] `user://transfers/` cross-mode file-drop survives an app restart

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

- [ ] **Build a fresh APK from `campaign-editor-and-fixits`.** The newest artifact,
      `build/fpfh-0.9.7-sideload.apk`, is dated **Jul 29** — one day before the entire
      layout close-out. Sideloading it would test none of the 161 button-width fixes, the
      short-screen scrolling, the 8px gutter, or any of the screen fixes, and every
      "device bug" found would be a ghost already fixed on desktop.
- [ ] Re-run the unzip check on that new APK (above).
- [ ] Decide whether the branch merges to `master` first — it is 77 commits ahead.

## Known-open before the device arrives

State these honestly rather than discovering them as "device bugs":

- The oldest save has one crew member with neither `reaction` nor `reactions`, so that one
  card still shows `R: 0`. Backfilling would mean inventing a stat value.
- `MissionSelectionUI` is out of the geometry sweep's scope: all of its controls live
  under a `PopupPanel`, which is a Window and lays out against its own rect rather than
  the screen's, so measuring it compares two coordinate spaces. It is the one screen with
  no desktop geometry evidence — **worth an explicit look on the device.**
- Layout findings are no longer on this list: the sweep is 198/198 green with a campaign
  loaded, at all six sizes including the 360dp small-phone worst case.
