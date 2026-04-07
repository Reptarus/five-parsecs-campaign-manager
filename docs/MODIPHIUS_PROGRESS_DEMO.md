# Five Parsecs Campaign Manager — Modiphius Progress Update

**Prepared for**: Modiphius Entertainment
**Date**: April 2026
**From**: [Your Name]
**Status**: Fully functional, legal stack shipped, seeking official partnership
**Related**: [Partnership Ask List](MODIPHIUS_ASK_LIST.md) | [Steam Research](archive/modiphius-steam-research.md)

---

## What's Changed Since Last Contact

The app has gone from prototype to **production-ready tabletop companion** with 100% Core Rules + Compendium mechanical compliance. Here's the summary:

- **925/925 game data values** verified against the Core Rulebook and Compendium — zero fabricated data
- **170/170 game mechanics** implemented and rules-accurate
- **Zero compile errors** on Godot 4.6-stable
- **Cross-platform ready**: Godot exports to Steam (Windows/Mac/Linux), Android (Google Play), iOS (App Store), and web
- **Bug Hunt gamemode** fully operational as a standalone mode
- **DLC/paywall system** built for tri-platform purchases (Steam, Android IAP, iOS StoreKit)
- **Full UI/UX overhaul** — Deep Space theme, responsive layout, touch-friendly (48px+ targets)

---

## Demo Flow

### Part 1: Campaign Creation (7 Phases)

Walk through the full creation wizard showing each step works end-to-end:

1. **Configuration** — Difficulty settings, optional rules, DLC content flags (Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook)
2. **Captain Creation** — Character creator with all Core Rules + Compendium species (Human, K'Erin, Precursor, Feral, Hulker, Soulless, Engineer, Swift, Skulker, Krag), backgrounds, motivations — all from the book
3. **Crew Setup** — Generate crew members with proper stat generation, species traits, equipment rolls
4. **Equipment Generation** — Per-character equipment from Core Rules tables, D100 bonus rolls (patrons, rivals, story points, rumors)
5. **Ship Assignment** — Ship hull, modules, traits — all values from Core Rules
6. **World Generation** — Planet type, traits, licensing requirements, invasion status, faction presence
7. **Final Review** — Full campaign summary, save, launch to dashboard

**Key talking point**: Every number on screen comes from the book. The app doesn't invent values — it implements the tables faithfully.

### Part 2: Campaign Turns (Show 2 Turns)

Quick walkthrough of the 9-phase turn loop, showing each phase has a dedicated panel with real game logic:

**Turn 1:**
1. **Story Phase** — Event generation from Core Rules tables
2. **Travel Phase** — World travel, starship encounters
3. **Upkeep Phase** — Pay crew, ship maintenance, loan tracking
4. **Mission Phase** — Patron jobs, mission generation, pre-battle setup
5. **Post-Mission Phase** — Loot, payment, rival/patron updates, injury rolls (from Core Rules p.122)
6. **Advancement Phase** — XP awards (Core Rules p.123), character progression
7. **Trading Phase** — Buy/sell equipment with condition-aware pricing
8. **Character Phase** — Character events, morale
9. **Retirement Phase** — Campaign milestone check

**Turn 2:** — Show the loop works repeatedly, data persists correctly between turns, auto-save fires per turn.

**Key talking point**: The app is a tabletop companion, not a video game. It generates instructions, tracks state, and handles bookkeeping — the player still plays on their physical tabletop. Three tracking tiers: LOG_ONLY (just record), ASSISTED (suggests outcomes), FULL_ORACLE (resolves everything).

### Part 3: Battle Companion UI

Show the tactical battle interface briefly:
- **26 companion panels** in a tabbed three-zone layout
- Battlefield grid (4x4 sectors with terrain visualization from Compendium themes)
- Dice dashboard, combat calculator, weapon table reference, cheat sheet
- Activation tracker, initiative panel, round management
- Battle log with keyword tooltips

**Key talking point**: This isn't a tactical simulator — it's a digital GM screen. Players resolve combat on the tabletop; the app handles the math, tracking, and reference lookups.

### Part 4: Bug Hunt Gamemode

Show that the Compendium's Bug Hunt variant is fully operational as a separate mode:
- 4-step creation wizard (separate from main campaign)
- 3-stage turn cycle (Special Assignments → Mission → Post-Battle)
- Separate `BugHuntCampaignCore` with its own data model (main characters + grunts, no ship, no patrons)
- 15 dedicated JSON data files, 23 GDScript/TSCN files
- Character transfer between Bug Hunt and standard 5PFH campaigns
- Shared `TacticalBattleUI` with bug_hunt mode flag

**Key talking point**: Bug Hunt demonstrates the app's ability to support multiple game modes within the same Five Parsecs ecosystem. It's a few versions behind the main campaign in UI polish, but mechanically complete.

### Part 5: Save/Load & Persistence

Quick demo showing:
- Per-turn auto-save
- Multiple save slots
- Campaign type detection (standard vs Bug Hunt) on load
- Full state persistence: credits, crew stats, ship, world, patrons, equipment, campaign journal

---

## Platform & Distribution Opportunity

### Steam: A First for Modiphius

Based on our research, **Modiphius currently has zero presence on Steam** — the largest PC gaming marketplace with 130M+ monthly active users. The Five Parsecs Campaign Manager would be Modiphius's entry point into that ecosystem.

This isn't speculative — the technical infrastructure is already built:
- **Steam integration**: GodotSteam plugin installed, `SteamStoreAdapter` implemented, DLC purchase flow via Steam overlay, ownership verification via `isDLCInstalled()`
- **Steam-ready architecture**: App ID placeholder in place, `steam_appid.txt` workflow documented, store page metadata framework ready

### Full Cross-Platform Distribution

The app is built on Godot 4.6, which exports natively to all major platforms. The distribution stack is already implemented:

| Platform | Status | Integration |
|----------|--------|-------------|
| **Steam** (Windows/Mac/Linux) | Plugin installed, adapter built | GodotSteam — DLC via overlay, ownership checks |
| **Android** (Google Play) | Export tested, APK optimized | AndroidIAPP plugin — in-app purchases, review prompts |
| **iOS** (App Store) | Plugin installed, adapter built | GodotApplePlugins — StoreKit purchases, in-app review |
| **Web** | Godot HTML5 export supported | Potential for web demo / itch.io |

### DLC Revenue Model

The app supports **33 content flags** across 3 DLC packs, mapped to Compendium content:
- **Trailblazer's Toolkit** (7 flags)
- **Freelancer's Handbook** (17 flags)
- **Fixer's Guidebook** (9 flags)

DLC gating is built into the codebase — content flags enable/disable Compendium features at runtime. Purchase flow is fully wired per-platform. Product IDs are placeholder pending partnership agreement.

### The Maloric Digital Precedent

This follows the same model as Jamie Morris's Fallout: Wasteland Warfare companion app (Maloric Digital) — a third-party developer building an official companion app distributed under Modiphius branding. The Five Parsecs Campaign Manager is significantly further along than that prototype was at the point of partnership.

---

## Future Expansion Roadmap

### Planetfall (Colony Building Campaign)

We already have comprehensive technical specifications prepared for the Planetfall expansion:
- Full 200-page rulebook analyzed and documented
- Architectural design complete — follows the same pattern as Bug Hunt (separate CampaignCore, shared battle UI)
- 30+ JSON data files mapped with page citations
- 10 new manager classes identified (ColonyManager, ResearchManager, BuildingManager, CampaignMapManager, etc.)
- Colony management (Integrity, Morale, Buildings, Research, Tech Tree), 6x6 grid map, procedural lifeform generation, 18-step campaign turns, 4 campaign endings

**Implementation estimate**: The framework is designed; data extraction and UI build would follow the same workflow used for the Core Rules and Bug Hunt.

### Tactics (Traditional Wargame Companion)

Tactics is architecturally different — squad-based wargaming with points, army lists, vehicles, and alternating activations. Our assessment:

- **Separate companion app** built on our existing GDScript foundation (we have a working tactical wargame codebase that provides the structural scaffold)
- Full 212-page rulebook analyzed — 14 species army lists, 40+ weapons, 15+ vehicles, veteran skills, campaign system all documented
- Data extraction ready to begin from the rulebook
- **Character transfer** between the main 5PFH app and the Tactics companion would bridge both products — players can take their crew from the adventure game into grand battles and back

### The Five Parsecs Digital Ecosystem

The long-term vision is a **suite of companion apps** covering the full Five Parsecs product line:

```
Five Parsecs Campaign Manager (5PFH + Bug Hunt + Planetfall)
  ├── Core campaign (9-phase turn, adventure wargaming)
  ├── Bug Hunt mode (military operations, 3-stage turn)
  ├── Planetfall mode (colony building, 18-step turn)
  └── Character Transfer ↔ Tactics Companion

Five Parsecs Tactics Companion (separate app)
  ├── Army Builder (points, platoon org, unit cards)
  ├── Battle Tracker (activations, suppression, morale)
  ├── Campaign Tracker (operational map, story events)
  └── Character Transfer ↔ Campaign Manager
```

Every game in the Five Parsecs line feeds into and out of the others — and every one of them would be a product on Steam, Google Play, and the App Store under Modiphius branding.

---

## Part 6: Legal & Compliance (NEW — April 2026)

All legal infrastructure required for store submission is implemented:

- **EULA screen** — first-launch blocking, scroll + privacy checkbox + DECLINE/ACCEPT
- **Privacy Policy** — GDPR/CCPA compliant, analytics opt-in (default OFF)
- **Data export/deletion** — Settings → Export My Data / Delete All Data
- **Consent management** — version-triggered re-consent, persistent acceptance
- **Open source licenses** — all dependencies attributed (Godot, GodotSteam, TweenFX, fonts, plugins)
- **Credits** — Ivan Sorensen, Modiphius staff (extracted from PDFs), open source contributors
- **Store submission checklist** — pre-filled Data Safety (Google) and Nutrition Label (Apple) answers
- **GitHub Pages** — privacy policy and EULA hosted as HTML with Deep Space theme

**Key talking point**: The legal stack is complete except for 3 items requiring Modiphius legal review: IP license scope, sublicensing terms, and revenue share terms. See [MODIPHIUS_ASK_LIST.md](MODIPHIUS_ASK_LIST.md) for the full list of partnership blockers.

---

## Part 7: Compendium Library (NEW — April 2026)

In-app rules reference with 10 browsable categories and 340+ items:

- Weapons, armor, gear, species, enemies, skills, and more
- game-icons.net icon set (CC BY 3.0, white on transparent)
- Extensible architecture — ready for Planetfall and Tactics content

---

## Technical Snapshot

| Metric | Value |
|--------|-------|
| GDScript files | ~900 (excluding addons) |
| Game mechanics compliance | 100% (170/170) |
| Data values verified | 925/925 |
| Compile errors | 0 |
| Campaign creation phases | 7/7 |
| Campaign turn phases | 9/9 |
| Battle companion panels | 26 |
| Bug Hunt files | 38 (15 JSON + 23 GDScript/TSCN) |
| UI/UX issues found & fixed | 28/28 |
| Runtime QA test sessions | 10 (71 bugs found, 71 fixed) |
| DLC content flags | 33 across 3 packs |
| Platform adapters | 4 (Steam, Android, iOS, Offline) |
| Legal stack | EULA + Privacy + Consent + Data Export/Delete |
| Compendium library | 10 categories, 340+ items |
| Reusable UI components | 14 (Session 37 UX Enhancement) |
