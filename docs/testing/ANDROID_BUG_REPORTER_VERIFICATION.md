# Android Verification: In-App Bug Reporter

**Status**: BLOCKED on hardware (tablet replacement in transit, 2026-07-27)
**Scope**: the bug reporter only. Not a general on-device pass.
**Companion**: `docs/sop/visual-runtime-verification.md`, `reference_alpha_tester_adb_methodology` memory

The reporter is fully verified on Windows desktop (49 gdUnit4 cases, live MCP walk in
landscape, portrait at 430x932, and with the tree paused). Everything below is what
**cannot** be proven without a real device, plus two Android defects already found and
fixed statically.

---

## Already found and fixed without a device

Both were silent failures: the feature would have looked fine on desktop and done
nothing useful on Android.

| # | Defect | Fix |
|---|---|---|
| 1 | The webhook config was `.env.local`. Godot **always excludes files and folders starting with a period** from an export, and non-resource files only ship if they match the preset's `include_filter` (`*.tscn, *.json, *.gd, *.tres, *.cfg, *.md, *.txt`). The URL would have been absent from the APK, `is_configured()` false, and the Discord POST would never fire on device | Renamed to `support_config.cfg`, read via `ConfigFile`. Matches the filter, no leading period, mirrors `addons/talo/settings.cfg` |
| 2 | `project.godot` had `[logging] file_logging/enable_file_logging=true` — the **Godot 3 key**, which Godot 4 ignores. Desktop logging worked only because `debug/file_logging/enable_file_logging.pc` defaults true for PC. Android has no such default, so `read_log_tail()` would return empty and every Android report would ship with no log | Set `debug/file_logging/enable_file_logging=true` under `[debug]` (applies to all platforms) and removed the dead `[logging]` section |

Confirmed OK already: `permissions/internet=true` in the Android preset, so the
Discord POST is permitted.

---

## On-device checklist

Build: `export_presets.cfg` preset `fiveparsecsfromhometest`, arm64-v8a only,
`com.reptarus.fiveparsecs`. Prior builds are `FiveParsecsTest12-16.apk` at repo root.

### A. The entry point

- [ ] The ⚠ button renders top-right, one slot left of the settings gear
- [ ] It is genuinely tappable — 48px is the minimum, but verify against a real finger, not a mouse
- [ ] It is visible on **MainMenu** (deliberately, unlike the gear) and on the campaign dashboard
- [ ] It hides while the settings overlay is open, and comes back on close
- [ ] It repositions correctly after a rotation

### B. The dialog on a real phone

- [ ] Opens without clipping. Desktop portrait at 430x932 gave 341x680 with zero overflowing children; confirm on the device's actual DPI
- [ ] The action row (Cancel / Save & Copy / Send) is **pinned and fully visible without scrolling** — it sits outside the ScrollContainer for exactly this reason
- [ ] The form scrolls with touch. **Watch for the `SlideOverDrawer` failure mode**: Button children eat the drag gesture and block scrolling. See `reference_drawer_downed_card_collapse_touch_scroll`
- [ ] Rotate mid-form: text already typed survives, layout re-flows once, no double-flicker
- [ ] The soft keyboard does not cover the field being typed into

### C. Context accuracy

- [ ] `device_model` shows the real device (on Windows it returns the motherboard; on Android it should be the phone/tablet model)
- [ ] `platform` = `Android`
- [ ] `current_scene` matches where the report was filed from
- [ ] Campaign fields populate when filed mid-campaign, and read `none` from MainMenu

### D. The log tail — the fix above needs proving

- [ ] The checkbox reads "Attach app log (N lines)" with **N > 0**. If N is 0, defect 2's fix did not take on device
- [ ] The saved JSON contains real log content
- [ ] Confirm the log file exists: `adb shell run-as com.reptarus.fiveparsecs ls files/logs/`

### E. Persistence

- [ ] The report writes to `user://bug_reports/`. Pull it: `adb shell run-as com.reptarus.fiveparsecs cat files/bug_reports/<name>.json`
- [ ] **No `.tmp` file left behind** — that would mean `DirAccess.rename_absolute` failed on Android's sandboxed storage, and the atomic write is broken
- [ ] Kill the app mid-report and confirm a previously saved report survives

### F. Delivery

- [ ] **Discord POST succeeds.** Status should read "Report sent." Check the private channel for the embed
- [ ] Airplane mode: the report still **saves**, the status reports the failure honestly, nothing is lost
- [ ] Clipboard actually receives the full text (`DisplayServer.clipboard_set` on Android) — paste into any text field to confirm
- [ ] With `support_config.cfg` absent from the build, the mailto fallback fires. **Android resolves `mailto:` via an ACTION_VIEW intent**, which is a different path from Windows. The Windows AppX workaround is correctly guarded behind `OS.get_name() == "Windows"` and must not run here
- [ ] With no mail app installed, the failure is graceful and the message is honest

### G. Interaction with the rest of the app

- [ ] Open the reporter **mid-battle** and confirm the Window draws above `TacticalBattleUI` and its drawers
- [ ] Open it while the settings overlay has the tree paused — `PROCESS_MODE_ALWAYS` is set, but verify on device
- [ ] APK size delta is negligible (the widget is code-only)

---

## Known unrelated issue that will fire constantly during this pass

`MainMenu.gd::_on_viewport_resized` is connected to `ResponsiveManager.layout_class_changed`
but takes 0 arguments while the signal passes 1:

```
Error calling from signal 'layout_class_changed' to callable:
'Control(MainMenu.gd)::_on_viewport_resized': Method expected 0 argument(s), but called with 1.
```

Pre-existing, not caused by the reporter, but it errors on **every rotation**. Fix it
before handing builds to testers or the logcat will be unreadable.

---

## Security reminder before any tester build ships

- `support_config.cfg` ships **inside the APK** and is extractable. Use a dedicated
  webhook on a private channel that can be revoked in isolation. Never the storefront
  ORDERS / BAN_ALERTS / RESTOCK / PRICE_ALERTS hooks.
- Separately: the Talo access key is a plaintext JWT at `addons/talo/settings.cfg:1`,
  force-included in every export by `addons/talo/talo_export.gd:8`. Same extraction risk,
  unrelated to this feature, worth handling before distribution.
