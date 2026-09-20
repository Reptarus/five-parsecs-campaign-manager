# Gamemode Specialist — Agent Memory

<!-- Loaded into your system prompt. KEEP UNDER 200 LINES. -->
<!-- Save: cross-mode isolation failures, transfer edge cases, data-model confusion, verified book facts -->
<!-- Deep detail belongs in the matching skill's references/ — it loads on demand, this does not. -->

Merged 2026-08-06 from `bug-hunt-specialist` (128) + `planetfall-specialist` (93) +
`tactics-specialist` (120). Stale planning content was dropped, not relocated — see "Corrections" below.

## ABSOLUTE RULE: the rulebooks are Word of God

| Mode | Canonical source |
|---|---|
| Bug Hunt | Compendium PDF; **text extraction already exists** at `docs/rules/bug_hunt_compendium_extract.txt` (pp.163-226) — use it, don't re-extract |
| Planetfall | `docs/rules/planetfall_source.txt` + PDF in `docs/Five_Parsecs_..._Planetfall_.../` |
| Tactics | `docs/rules/tactics_source.txt` (503KB) + `docs/rules/Five Parsecs From Home - Tactics.pdf` |

If code disagrees with the book, the code is wrong.

---

## Corrections applied 2026-08-06 (do not regress)

1. **Enlistment is `2D6 + Combat Skill >= 7`, not 8.** `bug-hunt-specialist.md` carried `>= 8` from a
   Session-42 bug that was fixed in code but never corrected in the agent body. Verified against
   `bug_hunt_compendium_extract.txt:3523` ("If the score is 7+, the enlistment is accepted") and
   `CharacterTransferService.gd:36` (`const ENLISTMENT_TARGET := 7`). The body was the ONLY wrong
   source of four. Two modifiers were also missing from it: **+1 (max one) for any Sector Government
   Patron** (p.214) and **1 Story Point rescues a failed roll**. Both are implemented in code.
   *Lesson: when a memory and its agent body disagree on a number, the book decides — and check which
   copy the code agrees with.*
2. Planetfall memory claimed "Sections 2-5 NOT YET IMPLEMENTED" and a "45-line placeholder"
   TurnController. **Stale** — Planetfall §1-4 are COMPLETE, 63 files, the 18-step turn flow is
   runtime-verified, save/load round-trips.
3. Tactics memory carried "GameState Integration Needed" / "SceneRouter Routes Needed" /
   "Implementation Order ~64 files". **Stale** — all shipped (Sessions 55-57, 59 files).
4. Both carried "Modiphius Approval Pending — meeting 2026-04-23". **Stale.**

---

## Bug Hunt

- **Equipment step auto-completes.** `BugHuntCreationCoordinator.go_to_step()` marks EQUIPMENT
  complete on entering step 2 — Bug Hunt uses standard issue and the read-only panel never emits
  `equipment_updated`, so without this the Next button never appears and the wizard sticks at step 3.
- **`BugHuntTurnController` must `call_deferred("_initialize")`.** `_ready()` fires before the node is
  in the tree when `TransitionManager.fade_to_scene()` instantiates it, so every
  `get_node_or_null("/root/...")` returns null.
- **`HubFeatureCard` pending-data pattern.** `setup()` before `add_child()` means `_ready()` hasn't
  built the UI and the labels are null. Store pending data, apply in `_ready()`. CampaignDashboard
  does `add_child` first (correct); BugHuntDashboard did `setup` first (fixed).
- **`AcceptDialog` blocks navigation.** A modal dialog blocks `SceneRouter.navigate_to()`;
  `queue_free()` the dialog then `create_timer(0.05).timeout` before changing scene.
- **`campaign_crew_size` does NOT apply.** The 4/5/6 setting is Standard-5PFH-only. Bug Hunt enemy
  counts follow Compendium Bug Hunt tables, not the Core Rules p.63 dice formula. If you touch
  `get_campaign_crew_size()` in a shared file, make sure no Bug Hunt path reaches it.
- ⚠ **STATUS, Sep 19 2026 — do not read the data verdict below as "Bug Hunt works."** The
  Sep 10 parity audit (`docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md`) re-confirmed the
  data independently AND found the DELIVERY broken almost everywhere: no played mission ever
  scored an objective (so Court Martial fired every turn and there was no reachable win), a
  turn could never END, the mission tally was counted three times, and a muster-out deleted
  the veteran instead of writing a transfer file. Sprint 1 is now **DESK-COMPLETE through
  all eight phases; only Phase 7's DEVICE WALK remains** (0-3 committed as `d1e541ccb`;
  **4-7 are uncommitted**). ✅ Phase 4 stamps the
  mission before the battle and routes the return through a new add-only
  `BugHuntBattleResultNormalizer`, so a played mission now SCORES its objectives —
  Court Martial stops firing every turn and the `above_100` Parade win is reachable.
  ✅ Phase 5 is the p.202 slice: a pure `BugHuntPostBattleResolver` returns a receipt
  and `BugHuntPhaseManager` is the ONLY mutator. The tally rises once per character
  who took the field, muster-out is checked at the real count and writes a transfer
  file via the new `CharacterTransferService.write_pending_transfer` static, and all
  20 Military Life rows apply. ⚠ Three dashboards still hand-roll the transfer
  envelope (`BugHuntDashboard.gd:447`, `PlanetfallDashboard.gd:141`,
  `TacticsDashboard.gd:256`) — a NAMED follow-up, not a migrated codebase.
  ✅ Phase 6 is provenance, census and helpers: `_source` on all 15 data files and a
  `test_bug_hunt_consumer_census.gd`. 🟡 **Phase 7's desk half is done** — the seven
  Alpha-1 guard suites are green (74 · 0 · 0, delta 0 against the grep population) and both
  probes were re-run; **the device walk has NOT run.**
  🟠 **A new book-cited Bug Hunt finding is FILED and deliberately unfixed** (battle payload,
  out of Sprint 1 scope): `data/bug_hunt/bug_hunt_enemies.json:difficulty_modifiers` has **zero
  readers repo-wide** — `BugHuntBattleSetup` never mentions difficulty — so Compendium
  p.190's Numbers adjustment (−1 on I'm Too Pretty to Die, +1 on Mega-violence and Living
  Nightmare) is **never applied to any revealed Contact**; and its four keys invent `"standard"`
  for two distinct book settings, so the app's DEFAULT `mess_me_up` matches no key. ✅ The live
  path is byte-faithful: `bug_hunt_missions.json:difficulty_settings` is the book's five settings
  with p.186's exact modifiers. **Fix shape when the payload is scoped: re-key onto the five book
  ids, add `numbers_modifier` as a sixth column there, delete the second dict** — two shapes
  for one concept is what broke `TacticsCampaignUnit`. Also **Row D**: asking for 5 main characters
  generates 4, against p.170 (the 5-marine option is an explicitly deferred book variant).
  ⭐ Three separate audits verified this data and all three then advised UI
  polish — **"the data is verified" and "the feature works" are different claims.**
- Sessions 42-43 audit: all 15 `data/bug_hunt/*.json` verified against the Compendium, zero data
  corrections needed; 14 code bugs fixed (6 JSON key mismatches that meant enemies never loaded and
  every post-battle table read the wrong key; 7 formula bugs in priority/spawn bounds/XP/Rep/
  mustering; 1 range-parser bug).

## Planetfall

- **`grunts` is an `int` count, NOT an array.** `grunts: int = 12` — no individual tracking
  (Planetfall p.16). Bug Hunt's `grunts` IS an Array. This is the single easiest cross-mode mix-up.
- **Equipment pool is central.** Characters never own items; `campaign.equipment_pool` is the colony
  armory. Assigned at Lock & Load (Step 7), returned after missions. Unique among all four modes.
- **`_get_planetfall_campaign()` returns untyped `Resource`**, not a typed `PlanetfallCampaignCore`.
  Duck-type with `"roster" in campaign`.
- Colony stats are campaign-level, not per-character: `colony_morale`, `colony_integrity`,
  `build_points_per_turn`, `research_points_per_turn`, `repair_capacity`, `colony_defenses`,
  `raw_materials`, `story_points`, `augmentation_points`.
- **Ending matrix (`convert_from_planetfall`, pp.165-166, verified `planetfall_source.txt`
  L12088-12113)** — the matrix was WRONG and is now correct; do not regress:
  `loyalty` = bonus_ship + ship_debt 0 · `independence_won` = bonus_ship + ship_debt_**prepaid**
  (2D6 **PARTIAL** prepayment — the old bug zeroed the whole debt) + 2 story points ·
  `independence_lost` = add_rival (Enforcers/Bounty Hunters) + 2 story points ·
  `isolation` = +1 Luck + `isolation_single_char` · `ascension` = `gains_psionic`.
- KP→Luck deliberately NOT converted on export (book silent). Snapshot restores an imported veteran's
  Luck; colonists born in Planetfall keep base Luck 1.
- Import: Class Training D6 (1-2 fail, 3 random class, 4-6 choice; max 3 trained, one per class).
  5PFH Luck → 1 KP each; Bug Hunt Tech → Savvy; imports begin **Loyal** (pp.26-27).

## Tactics

- **`Training` is a new stat** not present in the other three modes (morale tests, tactical actions,
  competence checks). Must appear in every unit profile.
- **Kill Points replace wounds.** Vehicles 2-8 KP, characters 1-3 KP — not the binary alive/dead model.
- **A transferred character is a NAMED VETERAN** ("officer or hero", p.185) in the serialized
  `veteran_characters[]`, **never** a squad unit in `campaign_units[]`. The book gives these figures
  "no points cost formula" (p.184), so veterans stay out of points validation. The `>=1 KP` floor
  lives at the veteran layer (tagged playability), so the conversion math stays book-exact.
- **Conversion is book-exact (p.184)** and three fabrications were removed — do not re-add:
  (1) the invented `military_backgrounds` list → a "military"/"war-torn" substring check grounded in
  real `gear_database.json` backgrounds (the book says only "+2 with a military-type background",
  no enumerated list); (2) a `max(luck,1)` KP floor → the book is exactly "1 Kill Point per Luck
  point"; (3) an "equipment not transferred" strip → the book says "carry weapons over as they are".
  Combat cap +2, Toughness cap 5, and "each KP after the first → 1 Luck" on export are CORRECT.
- **Prototype is structure-only.** `c:\Users\admin\Desktop\tacticaprototype1\` is Age of Fantasy IP.
  Patterns transfer (`ArmyCompositionValidator`, rules-engine pipeline, army-book JSON schema); no
  value ever does. Prototype uses `.tres` + 3D + LimboAI + `quality`/`defense`; FPCM uses JSON +
  2D UI + `combat_skill`/`toughness`/`KP`/`training`.
- **UI must use runtime `load()`** for Tactics data classes — not `preload()`, not bare `class_name`
  (parse-order issue).
- Composition: 500/750/1000 pts · 1 hero per 375 · duplicates 1 + 1 per 750 · max single unit 35% ·
  squads 4-5 + sergeant.

## Cross-mode transfer (shared — all four modes, any-to-any)

Canonical-hub design in `src/core/character/CharacterTransferService.gd` (RefCounted, owned by
**character-data-engineer**). Every mode implements `export_to_canonical(char, mode)` /
`import_from_canonical(canonical, mode)`; the canonical form is the full 5PFH-standard Character dict.
Any-to-any = compose an export leg with an import leg.

- **Mechanism is direct file-drop**, not a barracks: `user://transfers/<id>.json`, `schema_version 2`.
  `load_pending_transfers(target_mode)` filters by destination (v1 files predate `target_mode` and
  always target 5PFH). `apply_transfer_rewards()` applies and **deletes the file** (prevents
  double-import).
- **Pickup is mode-generic** in `CampaignScreenBase` (owned by **campaign-systems-engineer**):
  `_check_pending_transfers` / `_apply_pending_transfers` / `_add_character_to_mode` dispatch →
  `add_main_character` (BH) · `add_roster_character` (PF) · `add_veteran_character` (Tactics).
  **A SOURCE leg is dead code unless the DESTINATION dashboard calls
  `_check_pending_transfers.call_deferred()` in `_setup_screen()`** — this exact gap silently
  vanished mustered-out Bug Hunt veterans before it was fixed. Wire both halves.
- **Reward suppression**: 5PFH-specific exit rewards attach ONLY when `target_mode == "five_parsecs"`.
- **Lossless snapshot**: imports embed their canonical form under `snapshot`; `export_to_canonical()`
  short-circuits on it. Planetfall ending bonuses layer on TOP via `_layer_planetfall_ending()`
  (bonuses depend on the ending, not the stats).
- **12 directed routes, 9 book-defined.** Planetfall→Bug Hunt, Tactics→Bug Hunt and
  Tactics→Planetfall have NO direct book rule and are offered ONLY by composing two book-defined legs
  through the 5PFH canonical — zero invented values.
- 24/24 gdUnit4 transfer tests pass (`test_character_transfer_hub.gd`, `test_planetfall_transfer.gd`,
  `test_tactics_transfer.gd`). P3 persistent barracks DEFERRED.
- Full procedure: `docs/sop/cross-mode-transfer.md`.

## Shared-file watch list

`TacticalBattleUI.gd` now serves **four** consumers — Standard, Bug Hunt, Planetfall, and the
standalone **Battle Simulator** (which passes lightweight crew/enemy dicts, not Character resources).
Any change must be checked in all of them. Also shared: `GameState.gd`
(`_detect_campaign_type()`), `SceneRouter.gd`, `CampaignScreenBase.gd`, `GameStateManager.gd`.
