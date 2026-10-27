# Gamemode Specialist — Agent Memory

<!-- Loaded into your system prompt. KEEP UNDER 200 LINES. -->
<!-- Save: cross-mode isolation failures, transfer edge cases, data-model confusion, verified book facts -->
<!-- Deep detail belongs in the matching skill's references/ — it loads on demand, this does not. -->

Merged 2026-08-06 from the three per-mode specialists; stale planning was dropped (see Corrections).

## ABSOLUTE RULE: the rulebooks are Word of God

| Mode | Canonical source |
|---|---|
| Bug Hunt | Compendium PDF; **text extraction already exists** at `docs/rules/bug_hunt_compendium_extract.txt` (pp.163-226) — use it, don't re-extract |
| Planetfall | `docs/rules/planetfall_source.txt` + PDF in `docs/Five_Parsecs_..._Planetfall_.../` |
| Tactics | `docs/rules/tactics_source.txt` (503KB) + `docs/rules/Five Parsecs From Home - Tactics.pdf` |

If code disagrees with the book, the code is wrong.

---

## Corrections applied 2026-08-06 (do not regress)

1. **Enlistment is `2D6 + Combat Skill >= 7`, not 8** (`bug_hunt_compendium_extract.txt:3523`;
   `CharacterTransferService.gd:36` `ENLISTMENT_TARGET := 7`), plus **+1 (max one) for a Sector
   Government Patron** (p.214) and **1 Story Point rescues a failed roll** — both in code. *When a
   memory and its agent body disagree on a number, the book decides.*
2. Dropped as stale: "Planetfall Sections 2-5 not implemented", "Tactics needs GameState/SceneRouter
   integration", "Modiphius approval pending 2026-04-23". All shipped or superseded.

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
- ⚠ **"The data is verified" ≠ "the feature works."** Three audits verified the data and advised UI
  polish; the Sep 10 parity audit (`docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md`) then found the
  DELIVERY broken almost everywhere. Sprint 1 (Phases 0-7) is DESK-COMPLETE and committed
  (`d1e541ccb`, `ca6172011`): turns end, played missions score objectives (Court Martial no longer
  fires every turn; the `above_100` Parade win is reachable), the p.202 `BugHuntPostBattleResolver`
  is pure with `BugHuntPhaseManager` the ONLY mutator, and muster-out writes a transfer file via
  `CharacterTransferService.write_pending_transfer`. Its device walk now lives in Sprint 8 of the
  review-build plan (`start-doing-deep-dive-elegant-reddy.md`).
- **Open, book-cited:** `bug_hunt_enemies.json:difficulty_modifiers` has zero readers, so the
  **p.194** Numbers ±1 (−1 I'm Too Pretty to Die, +1 Mega-violence / Living Nightmare) never
  reaches a revealed Contact. It is the rule's ONLY encoding (the p.186 `difficulty_settings` rows
  have no numbers column) and its keys invent `"standard"`, so the default `mess_me_up` matches
  none. **Move, don't delete:** add `numbers_modifier` to the five p.186 rows, then drop the
  mis-keyed dict. (Cited p.190 until 2026-10-27; p.190 is the separate extra-Contact rule, live.)
- **Open:** asking for 5 main characters generates 4, against p.170. Three dashboards still
  hand-roll the transfer envelope (`BugHuntDashboard.gd:447`, `PlanetfallDashboard.gd:141`,
  `TacticsDashboard.gd:256`) instead of calling `write_pending_transfer`.
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

Hub: `src/core/character/CharacterTransferService.gd` (owned by **character-data-engineer**); full
procedure `docs/sop/cross-mode-transfer.md`. Canonical form = the 5PFH Character dict; any-to-any =
one export leg + one import leg. 12 directed routes, 9 book-defined; PF→BH, Tactics→BH and
Tactics→PF are offered only by composing two book legs, with zero invented values.

- File-drop `user://transfers/<id>.json` (schema 2), filtered by `target_mode`;
  `apply_transfer_rewards()` applies and DELETES the file so nothing imports twice.
- **A SOURCE leg is dead code unless the DESTINATION dashboard calls
  `_check_pending_transfers.call_deferred()` in `_setup_screen()`** (pickup lives in
  `CampaignScreenBase`, owned by campaign-systems-engineer). This gap once silently vanished
  mustered-out Bug Hunt veterans. Wire both halves.
- 5PFH exit rewards attach ONLY when `target_mode == "five_parsecs"`. Imports embed a lossless
  `snapshot` that `export_to_canonical()` short-circuits on; Planetfall ending bonuses layer on top
  via `_layer_planetfall_ending()`. Pinned by `test_character_transfer_hub.gd`,
  `test_planetfall_transfer.gd`, `test_tactics_transfer.gd`.

## Shared-file watch list

`TacticalBattleUI.gd` now serves **four** consumers — Standard, Bug Hunt, Planetfall, and the
standalone **Battle Simulator** (which passes lightweight crew/enemy dicts, not Character resources).
Any change must be checked in all of them. Also shared: `GameState.gd`
(`_detect_campaign_type()`), `SceneRouter.gd`, `CampaignScreenBase.gd`, `GameStateManager.gd`.
