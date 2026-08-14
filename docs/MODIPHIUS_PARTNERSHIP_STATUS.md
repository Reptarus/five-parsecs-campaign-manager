# Modiphius Partnership — Current Status

*Extracted from `CLAUDE.md` on 2026-08-06. `CLAUDE.md` loads into every session and every subagent;
partnership terms have no bearing on writing code, so they live here and are linked from there.*

**Last refreshed**: 2026-08-06 (reflecting the Jul 27 2026 call outcome).

---

## Status: Jul 27 2026 call OUTCOME

- **$9.99 one-time base + per-book unlocks APPROVED** (no subscription).
- Taper accepted, pending his team.
- **Five Parsecs own-IP scope adopted** — Traveller is out of scope.
- LOI moving to Modiphius letterhead. **Diff the letterhead version against the agreed Google Doc
  before signing** (`BOILERPLATE_REVIEW_CHECKLIST.md`).
- Alpha kickoff date deliberately **DEFERRED** for social coordination — do not re-propose one
  unprompted.

> 📋 **When the LOI is signed, work
> [legal/POST_LOI_LEGAL_CHECKLIST.md](legal/POST_LOI_LEGAL_CHECKLIST.md) top to bottom.**
> The shipped EULA and privacy policy carry **7 deliberate placeholders** whose values are
> exactly the terms the LOI settles: license grant scope, revenue share, and governing law
> jurisdiction. They are visible to testers today (confirmed on device Aug 13 2026) and stay
> that way on purpose until the terms exist. The checklist also covers the contact email
> (needed regardless of the LOI), the fact that each legal document has TWO copies which have
> already diverged, and the version bump required to re-prompt existing users.

**Underlying deal frame**: 50/50 net split post-recoupment, with a quarterly
maintenance/support/development fee carve-out to dev BEFORE the split. Phase 1 = prove the thesis
(this deal); the Phase 2 lock-in conversation arrives later, if Phase 1 succeeds.

> **⚠ Correspondence caveat**: `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` stops at **Jun 4 2026**. For
> anything after that date, pull Gmail and Google Doc comments — **the repo is NOT the record.**

## Mutually agreed strategic theses — do NOT re-argue these in any doc

| | Thesis |
|---|---|
| **T1** | Companion app, not digital port — complements physical, doesn't replace it |
| **T2** | Establishing a category, not entering one — solo-RPG/wargame digital companion apps are essentially absent on Steam |
| **T3** | Multi-project platform R&D investment — the foundation for Modiphius's wider digital strategy across other licensed IPs |
| **T4** | Active digital→physical conversion strategy — 5 in-app mechanisms drive Steam users to physical book sales |

Canonical statement: `MEETING_FOLLOWUPS_2026-04-29.md` §1.5. Research backing:
`MODIPHIUS_DIGITAL_FORECAST.md` §11.

## Active artifacts

| Doc | Purpose |
|---|---|
| `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` | Chronological log (stops Jun 4 2026) |
| `MEETING_PREP_2026-05-18.md` | LOI talking points |
| `BROADENING_SCOPE_SKETCH.md` | 1-pager for Chris |
| `BOILERPLATE_REVIEW_CHECKLIST.md` | Definitive Agreement defense |
| `PARTNERSHIP_PAPERWORK_PRIMER.md` | LOI → MOU → Definitive Agreement mental model |
| `MODIPHIUS_DIGITAL_FORECAST.md` | Forecast + industry research |
| `launch-dashboard.html` | PM dashboard (interactive, personal-use) |

## Commercial context notes

These were previously filed under CLAUDE.md's "Gotchas" heading, which is a coding-rules section.
They are business facts, not code rules.

- **50/50 net split (Apr 29 2026)** — locked after platform fees. Any 60/40 baseline in an older doc
  is superseded. Contractor structures re-run on the 50/50 baseline shifted break-evens: Structure 1
  $75K→$100K, Structure 3 $200K→$400K (no longer viable). See `MODIPHIUS_DIGITAL_FORECAST.md` §9b.
- **Physical-PDF bundling** — every Modiphius physical book ships with a PDF (bundled fulfillment,
  NOT a separate revenue event). DTRPG figures (5PFH 4,219 / 5L 2,700) are direct sales only. Don't
  double-count physical PDFs as digital reach.
- **5x system as Modiphius digital foundation** — this build is being evaluated as the foundation for
  their wider digital strategy (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune). Keep the "5x
  platform" backlog separate from the "5PFH v1" backlog; don't commingle.
- **Contractor scope frames A/B/C** — Frame A intro project ($30-45K + reduced rev share), Frame B
  post-launch retainer ($3-5K/mo + 50/50, the lowest-friction pitch), Frame C hybrid. Forecast §9.5.
- **CC Gavin on outbound to Chris** — weekly cadence with Gavin (Modiphius PM), bi-weekly strategic
  with Chris.
- **Closed alpha cohort = Ivan's Discord** — 10-20 testers, no external recruitment; Ivan sizes the
  cohort. 6-week window, weekly builds A1-A6, 6 graduation gates (AND, not OR).
- **MVP gate** — pricing, store-page positioning, newsletter timing and EA launch decisions are all
  gated on closed alpha telling us what the minimum viable product really is. See
  `PRICING_RESEARCH_PLAN.md`.
- **Paperwork progression** — LOI now → MOU during alpha (Jun-Jul) → Definitive Agreement during beta
  and EA prep (Aug-Sep), signed before Steam EA goes live. **Cannot launch EA without it.**
- **Steam-first launch** — Phase 1 (EA + 1.0) targets Steam exclusively; mobile is a Phase 2 "pocket
  edition" port. Platform-cut multiplier is a flat 0.70 (Steam-only 30%).
- **Comparison vector** — NOT Gloomhaven (that's a digital replacement; audience-size reference only).
  The right peers are off-Steam companion apps: Mythic GME Digital, Quest Companion, World Anvil, New
  Recruit, BattleScribe, Campaign Console, Frostgrave/Stargrave tools. Forecast §11.1.
- **Empty Steam category** — dedicated solo-RPG/wargame campaign-companion apps essentially don't
  exist on Steam. Fantasy Grounds VTT (1,025 reviews, 81%, $39.99) is the closest analog and is
  multiplayer-VTT-first. This is both moat AND discovery risk.
- **Digital→physical conversion (T4)** — 5 in-app mechanisms tracked as Phase B alpha deliverables
  (`CLOSED_ALPHA_PLAN.md` §6.5). Needed from Modiphius before alpha: discount code sizing (15-20%
  placeholder), code generation/redemption mechanism, co-branded landing page, newsletter API
  endpoint. Modiphius keeps full physical margin — every app→book conversion is pure upside for them.
- **Steam wishlist target** — 10K-20K by EA launch. 2026 wishlist→player conversion is 5-10% (down
  from ~20% in 2018); EA first-month median ~20%; >$10 trends lower. Forecast §11.2.
- **Don't conflate audience-share conversion with wishlist conversion** — §5's 2/5/10/20/30% scenarios
  are *audience-share* against ~51K reachable readers, NOT wishlist conversion. Both views must
  coexist and cross-check.
- **Industry-research-backed forecast** — §11 carries 7 subsections with external sources (Steam
  tabletop comps, wishlist benchmarks, EA failure rates 31-50%, pricing psychology, cannibalization,
  TTRPG market tailwinds at 13.2% CAGR). Use these as defensible references, not internal hypotheses.
