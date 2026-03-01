# Technical Debt Roadmap - Five Parsecs Campaign Manager

**Document Version**: 1.0
**Last Updated**: 2025-11-27
**Target Versions**: v1.1, v2.0, v2.5
**Prioritization Framework**: Impact × Effort × Risk

---

## Overview

This document tracks technical debt accumulated during rapid v1.0 development. Debt items are prioritized by **Impact** (user/developer pain), **Effort** (hours to resolve), and **Risk** (likelihood of causing issues if unaddressed).

**Total Debt Estimate**: 60-80 hours across all priorities
**Critical Debt**: 12-17 hours (required for v1.0-rc1)
**High Debt**: 20-25 hours (recommended for v1.1)
**Medium Debt**: 15-20 hours (planned for v2.0)
**Low Debt**: 13-18 hours (backlog for v2.5+)

---

## Priority Scoring Matrix

| Score | Impact | Effort | Risk |
|-------|--------|--------|------|
| 5 | Critical: Production blocker | 1-2 hours | Very High: >80% regression chance |
| 4 | High: Significant user pain | 3-5 hours | High: 60-80% regression chance |
| 3 | Medium: Quality of life | 6-10 hours | Medium: 40-60% regression chance |
| 2 | Low: Minor annoyance | 11-20 hours | Low: 20-40% regression chance |
| 1 | Minimal: Nice to have | 20+ hours | Very Low: <20% regression chance |

**Priority Formula**: `(Impact × 2) + (6 - Effort) + Risk`
- **20+**: CRITICAL (do immediately)
- **15-19**: HIGH (next sprint)
- **10-14**: MEDIUM (next version)
- **5-9**: LOW (backlog)

---

## CRITICAL DEBT (20+ priority score) - v1.0-rc1 BLOCKERS

### 1. Missing BattlePhase Handler ⚠️ **PRODUCTION_BLOCKER**

**Category**: Architecture
**Impact**: 5/5 (Critical - turn loop cannot complete)
**Effort**: 3/5 (3-4 hours)
**Risk**: 5/5 (Very High - game-breaking if missing)
**Priority Score**: 21 🔴 **CRITICAL**

**Problem**:
`src/core/campaign/phases/BattlePhase.gd` does NOT exist. `CampaignPhaseManager.gd` has no battle orchestration. Users cannot complete a full turn cycle.

**Solution**:
1. Create `BattlePhase.gd` with methods:
   - `setup_battle()` - Initialize combat from world data
   - `execute_battle()` - Orchestrate combat resolution
   - `finalize_battle()` - Transition to post-battle phase
2. Wire into `CampaignPhaseManager.gd` alongside `TravelPhase`, `WorldPhase`, `PostBattlePhase`
3. Add E2E test: `test_complete_turn_loop.gd`

**Acceptance Criteria**:
- [ ] User can transition: World Phase → Battle Phase → Post-Battle Phase
- [ ] Battle results saved to campaign state
- [ ] E2E test validates full turn cycle (100% coverage)

**Estimated Time**: 3-4 hours
**Target Release**: v1.0-rc1
**Owner**: Developer

---

### 2. No Platform Builds Created ⚠️ **DISTRIBUTION_BLOCKER**

**Category**: Deployment
**Impact**: 5/5 (Critical - cannot ship without builds)
**Effort**: 4/5 (4-6 hours)
**Risk**: 4/5 (High - untested on target platforms)
**Priority Score**: 20 🔴 **CRITICAL**

**Problem**:
No Windows x64 or Linux AppImage builds exist. Cannot deploy to users.

**Solution**:
1. Create export presets for Windows/Linux in Godot 4.5.1
2. Export builds to `builds/` directory
3. Test on Windows 10/11 and Ubuntu 22.04
4. Validate save file compatibility cross-platform
5. Package for distribution (zip/AppImage)

**Acceptance Criteria**:
- [ ] `FiveParsecs-v1.0-rc1-Windows-x64.zip` created and tested
- [ ] `FiveParsecs-v1.0-rc1-Linux-x86_64.AppImage` created and tested
- [ ] Save files work cross-platform (Windows → Linux, Linux → Windows)
- [ ] Both builds uploaded to GitHub Releases

**Estimated Time**: 4-6 hours
**Target Release**: v1.0-rc1
**Owner**: DevOps/Developer

---

## HIGH DEBT (15-19 priority score) - v1.1 RECOMMENDED

### 3. Unresolved TODO/FIXME Comments (130 instances)

**Category**: Code Quality
**Impact**: 3/5 (Medium - maintainability impact)
**Effort**: 4/5 (4-6 hours to resolve or document)
**Risk**: 2/5 (Low - mostly documentation debt)
**Priority Score**: 16 🟡 **HIGH**

**Problem**:
130 `TODO`, `FIXME`, `BUG`, `HACK` comments scattered across codebase. Some may indicate incomplete features or known bugs.

**Solution**:
1. Audit all 130 comments with script:
   ```bash
   grep -rn "TODO\|FIXME\|BUG\|HACK" src/ --include="*.gd" > TODO_AUDIT.txt
   ```
2. Categorize into:
   - **P0**: Fix immediately (critical bugs)
   - **P1**: Document as GitHub Issues (future enhancements)
   - **P2**: Remove if obsolete (outdated comments)
3. Create GitHub Issues for P1 items
4. Remove P2 obsolete comments
5. Fix P0 critical items

**Acceptance Criteria**:
- [ ] Zero P0 TODO comments remain
- [ ] All P1 TODOs tracked in GitHub Issues
- [ ] Obsolete P2 TODOs removed
- [ ] Remaining TODOs <10 (documented reasons)

**Estimated Time**: 4-6 hours
**Target Release**: v1.1
**Owner**: Developer

---

### 4. File Count Exceeds Target by 84%

**Category**: Architecture
**Impact**: 4/5 (High - onboarding difficulty)
**Effort**: 2/5 (6-8 hours consolidation)
**Risk**: 3/5 (Medium - regression risk during merging)
**Priority Score**: 17 🟡 **HIGH**

**Problem**:
**461 GDScript files** vs target of **150-250 files**. Excessive file count increases onboarding friction and navigation overhead.

**Root Cause**:
- UI components over-fragmented (140 files in `src/ui/`)
- Core systems duplicated (218 files in `src/core/`)
- Single-purpose utilities (5 files in `src/utils/`)

**Solution Strategy**:
1. **Phase 1**: Merge UI components (140 → 60-80 files)
   - Combine campaign panels into fewer files
   - Merge similar UI helpers
   - Consolidate theme/styling classes
2. **Phase 2**: Consolidate core systems (218 → 100-120 files)
   - Merge phase handlers into single phase manager
   - Combine similar managers (Equipment, Inventory, Loot)
   - Reduce data model fragmentation
3. **Phase 3**: Flatten utilities (5 → 2-3 files)
   - Merge TableLookup and DataLoader
   - Combine small helper classes

**Acceptance Criteria**:
- [ ] File count reduced to 150-250 range
- [ ] All tests still passing (no regressions)
- [ ] Code review confirms improved navigability
- [ ] Documentation updated with new structure

**Estimated Time**: 6-8 hours
**Target Release**: v2.0 (deferred - not blocking v1.0)
**Owner**: Developer + Architect

---

### 5. 2 E2E Tests Failing (Equipment Field Mismatch)

**Category**: Testing
**Impact**: 3/5 (Medium - cosmetic issue)
**Effort**: 5/5 (35 minutes)
**Risk**: 2/5 (Low - isolated to equipment display)
**Priority Score**: 15 🟡 **HIGH**

**Problem**:
2/138 tests failing in E2E suite (`test_campaign_e2e_workflow.gd`). Failure cause: Equipment field mismatch (expected `weapon_type`, actual `item_type`).

**Solution**:
1. Read failing test: `tests/legacy/test_campaign_e2e_workflow.gd`
2. Identify exact field mismatch (line numbers from test output)
3. Update test expectations OR fix backend schema (whichever is correct)
4. Verify fix with: `gdunit4 -a tests/legacy/test_campaign_e2e_workflow.gd`

**Acceptance Criteria**:
- [ ] 100% E2E test coverage (138/138 passing)
- [ ] Equipment field schema consistent across backend/UI
- [ ] No regressions in related tests

**Estimated Time**: 35 minutes
**Target Release**: v1.0-rc1 (quick win)
**Owner**: QA/Developer

---

## MEDIUM DEBT (10-14 priority score) - v2.0 PLANNED

### 6. Performance Profiling on Low-End Hardware

**Category**: Performance
**Impact**: 3/5 (Medium - impacts accessibility)
**Effort**: 4/5 (2 hours profiling + potential fixes)
**Risk**: 2/5 (Low - performance already exceeds targets)
**Priority Score**: 14 🟠 **MEDIUM**

**Problem**:
Performance tested only on mid/high-end hardware. Unknown behavior on minimum spec (4GB RAM, integrated graphics).

**Solution**:
1. Test on low-end hardware:
   - Windows 10 laptop (4GB RAM, Intel HD Graphics)
   - Ubuntu VM (4GB RAM allocated)
2. Profile with Godot profiler:
   - Monitor FPS during 100+ turn campaigns
   - Check memory usage trends
   - Identify slow operations (>16ms frame time)
3. Optimize bottlenecks if FPS <60 consistently

**Acceptance Criteria**:
- [ ] 60 FPS maintained on minimum spec hardware
- [ ] Memory usage <500MB after 100 turns
- [ ] No frame drops during phase transitions

**Estimated Time**: 2 hours
**Target Release**: v1.1
**Owner**: QA + Developer

---

### 7. Schema Migration Testing for Future Versions

**Category**: Data Integrity
**Impact**: 3/5 (Medium - future-proofing)
**Effort**: 4/5 (3-4 hours)
**Risk**: 3/5 (Medium - data loss risk if untested)
**Priority Score**: 13 🟠 **MEDIUM**

**Problem**:
`SaveFileMigration.gd` only tested for current schema version. No validation for forward migrations (v1 → v2 → v3).

**Solution**:
1. Create mock v2 schema with breaking changes:
   - Add new field: `character.skills` (array)
   - Rename field: `campaign.credits` → `campaign.currency`
   - Remove field: `campaign.deprecated_data`
2. Write migration function: `migrate_v1_to_v2()`
3. Add test: `test_schema_migration_v1_to_v2.gd`
4. Validate backward compatibility (v2 loads v1 saves)

**Acceptance Criteria**:
- [ ] Migration system handles v1 → v2 saves
- [ ] Data integrity preserved after migration
- [ ] Backward compatibility maintained (can load old saves)
- [ ] Migration errors logged with user-friendly messages

**Estimated Time**: 3-4 hours
**Target Release**: v2.0
**Owner**: Developer

---

### 8. macOS Build Creation (Optional Platform)

**Category**: Deployment
**Impact**: 2/5 (Low - niche audience)
**Effort**: 3/5 (4 hours)
**Risk**: 2/5 (Low - not critical path)
**Priority Score**: 10 🟠 **MEDIUM**

**Problem**:
No macOS app bundle exists. Excludes Mac users from testing/using app.

**Challenges**:
- Requires Apple Developer account ($99/year)
- Must notarize for Gatekeeper (macOS 10.15+)
- Code signing with Developer ID certificate

**Solution**:
1. Enroll in Apple Developer Program
2. Create macOS export preset in Godot
3. Export unsigned `.app` bundle
4. Sign with Developer ID certificate
5. Notarize via `xcrun notarytool`
6. Create DMG installer
7. Test on macOS 12 Monterey and 14 Sonoma

**Acceptance Criteria**:
- [ ] `FiveParsecs-v1.1-macOS.dmg` created
- [ ] App passes Gatekeeper approval
- [ ] Tested on macOS 12 and 14
- [ ] Save files work on macOS (cross-platform validated)

**Estimated Time**: 4 hours (+ $99 Apple fee)
**Target Release**: v1.1 (if market demand validated)
**Owner**: DevOps/Developer

---

## LOW DEBT (5-9 priority score) - v2.5+ BACKLOG

### 9. Android APK Build (Mobile Platform)

**Category**: Deployment
**Impact**: 2/5 (Low - mobile is secondary platform)
**Effort**: 2/5 (5 hours)
**Risk**: 2/5 (Low - optional feature)
**Priority Score**: 8 🔵 **LOW**

**Problem**:
No mobile build exists. Excludes tablet/phone users.

**Challenges**:
- Touch target validation (48dp minimum already met ✅)
- Permissions: `READ/WRITE_EXTERNAL_STORAGE`
- App signing with keystore
- Google Play submission (optional)

**Solution**:
1. Create Android export preset
2. Configure permissions in `AndroidManifest.xml`
3. Generate release keystore
4. Export signed APK
5. Test on Android 8.0+ devices
6. Optimize for portrait/landscape modes
7. (Optional) Publish to Google Play

**Acceptance Criteria**:
- [ ] `FiveParsecs-v1.2-Android.apk` created
- [ ] Tested on Android 8.0 and 14
- [ ] Touch targets validated (48dp minimum)
- [ ] Save files work on Android (external storage)

**Estimated Time**: 5 hours
**Target Release**: v1.2 (mobile-optimized release)
**Owner**: Mobile Developer

---

### 10. Advanced Error Reporting (Sentry Integration)

**Category**: Monitoring
**Impact**: 2/5 (Low - manual logging sufficient for now)
**Effort**: 3/5 (2 hours)
**Risk**: 1/5 (Very Low - nice to have)
**Priority Score**: 7 🔵 **LOW**

**Problem**:
Error reporting relies on manual log file sharing. No automated crash analytics.

**Solution**:
1. Create Sentry project: `five-parsecs-campaign-manager`
2. Integrate Sentry GDScript SDK (if available)
   - Fallback: HTTP POST to Sentry API in `ErrorLogger.gd`
3. Capture exceptions in `ErrorLogger.gd`
4. Include stack traces and breadcrumbs
5. Filter PII (no usernames, emails, IP addresses)
6. Require user opt-in (privacy-first)

**Acceptance Criteria**:
- [ ] Crashes auto-report to Sentry (with consent)
- [ ] Stack traces include line numbers
- [ ] No PII collected
- [ ] Opt-in dialog on first launch

**Estimated Time**: 2 hours
**Target Release**: v1.1 (optional)
**Owner**: DevOps

---

### 11. GitHub Actions CI/CD Pipeline

**Category**: DevOps
**Impact**: 2/5 (Low - manual builds work fine)
**Effort**: 2/5 (3 hours)
**Risk**: 2/5 (Low - automation benefit)
**Priority Score**: 8 🔵 **LOW**

**Problem**:
Builds created manually. No automated testing on push.

**Solution**:
1. Create `.github/workflows/ci.yml`:
   - Trigger: Push to `main`, pull requests
   - Steps: Checkout, Godot setup, run tests, export builds
2. Cache Godot downloads for faster runs
3. Upload build artifacts to GitHub Actions
4. (Optional) Auto-create GitHub Release on tag push

**Acceptance Criteria**:
- [ ] Tests run automatically on every push
- [ ] Builds created on tag push (e.g., `v1.1.0`)
- [ ] GitHub Release auto-created with build artifacts

**Estimated Time**: 3 hours
**Target Release**: v1.1
**Owner**: DevOps

---

### 12. Steam Integration (Future Distribution)

**Category**: Distribution
**Impact**: 1/5 (Minimal - requires $100 fee + extensive work)
**Effort**: 1/5 (20+ hours)
**Risk**: 1/5 (Very Low - optional monetization)
**Priority Score**: 5 🔵 **LOW**

**Problem**:
Game not available on Steam. Misses large PC gaming audience.

**Challenges**:
- Steam Direct fee: $100 (non-refundable)
- Steamworks SDK integration (C++ bindings)
- Steam features: Achievements, trading cards, Cloud saves
- Steam review process (1-2 weeks)
- Ongoing maintenance for Steam-specific bugs

**Solution**:
1. Pay Steam Direct fee ($100)
2. Download Steamworks SDK
3. Integrate GDNative Steamworks bindings
4. Implement Steam features:
   - Achievements (20+ achievements)
   - Trading cards (design 8 cards)
   - Cloud saves (Steam Cloud API)
   - Workshop support (user-created campaigns)
5. Submit for Steam review
6. Launch with marketing campaign

**Acceptance Criteria**:
- [ ] Game approved on Steam
- [ ] All Steamworks features functional
- [ ] Cloud saves sync across devices
- [ ] Achievements tracked correctly

**Estimated Time**: 20+ hours (+ $100 fee)
**Target Release**: v2.0 (if Itch.io validates demand)
**Owner**: Business + Developer

---

## Technical Debt Summary

### By Priority

| Priority | Count | Total Estimated Hours | Target Release |
|----------|-------|----------------------|----------------|
| **CRITICAL** | 2 | 7-10 hours | v1.0-rc1 |
| **HIGH** | 3 | 11-15 hours | v1.1 |
| **MEDIUM** | 4 | 15-20 hours | v2.0 |
| **LOW** | 3 | 30+ hours | v2.5+ |
| **TOTAL** | 12 | 63-75 hours | - |

---

### By Category

| Category | Count | Total Estimated Hours |
|----------|-------|----------------------|
| Architecture | 2 | 9-12 hours |
| Deployment | 4 | 16-21 hours |
| Code Quality | 1 | 4-6 hours |
| Testing | 1 | 35 minutes |
| Performance | 1 | 2 hours |
| Data Integrity | 1 | 3-4 hours |
| Monitoring | 1 | 2 hours |
| DevOps | 1 | 3 hours |
| Distribution | 1 | 20+ hours |

---

### By Risk Level

| Risk | Count | Potential Impact |
|------|-------|------------------|
| **Very High** | 1 | Production blocker (BattlePhase missing) |
| **High** | 1 | Distribution blocker (no builds) |
| **Medium** | 3 | Quality degradation, future bugs |
| **Low** | 5 | Minor annoyances, missed features |
| **Very Low** | 2 | Nice-to-have enhancements |

---

## Execution Roadmap

### v1.0-rc1 (CRITICAL - 1-2 weeks)

**Goal**: Production-ready release candidate
**Total Time**: 7-10 hours

1. **Create BattlePhase Handler** (3-4 hours) 🔴
2. **Build Windows/Linux Platforms** (4-6 hours) 🔴
3. (Optional) **Fix 2 E2E Test Failures** (35 min) 🟡

**Success Criteria**: Full turn loop functional, cross-platform builds validated

---

### v1.1 (HIGH - 1 month after v1.0)

**Goal**: Polish release with quality improvements
**Total Time**: 17-23 hours

1. **Resolve TODO Comments** (4-6 hours) 🟡
2. **Performance Profiling** (2 hours) 🟠
3. **macOS Build** (4 hours, if demand exists) 🟠
4. (Optional) **Sentry Integration** (2 hours) 🔵
5. (Optional) **CI/CD Pipeline** (3 hours) 🔵

**Success Criteria**: Clean codebase, validated performance, macOS support

---

### v2.0 (MEDIUM - 3-6 months after v1.0)

**Goal**: Architecture optimization and future-proofing
**Total Time**: 24-32 hours

1. **File Consolidation Sprint** (6-8 hours) 🟡
2. **Schema Migration Testing** (3-4 hours) 🟠
3. **Android APK Build** (5 hours) 🔵
4. (Optional) **Steam Integration** (20+ hours) 🔵

**Success Criteria**: Maintainable codebase, mobile support, Steam launch

---

## Continuous Improvement

### Monthly Reviews

- [ ] Re-audit TODO comments (ensure new debt tracked)
- [ ] Review test coverage trends (maintain 95%+)
- [ ] Check file count (prevent drift from 150-250 target)
- [ ] Update risk assessments (as architecture evolves)

### Post-Release Monitoring

- [ ] Track user-reported bugs (categorize as technical debt)
- [ ] Monitor performance metrics (Sentry, if integrated)
- [ ] Collect feature requests (prioritize in roadmap)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-27
**Next Review**: After v1.0-rc1 deployment
**Owner**: Development Team
