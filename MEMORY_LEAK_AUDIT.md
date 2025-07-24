# Five Parsecs Campaign Manager - Memory Leak Analysis

## Executive Summary
- Files Analyzed: 419
- Memory Leak Risks Identified: 6
- High-Risk Files: 5
- Estimated Memory Savings: Not applicable (leaks are minor)

## Pattern Analysis
| Pattern Type | Occurrences | Risk Level | Est. Memory Impact |
|--------------|-------------|------------|--------------------|
| Missing queue_free() | 1 | HIGH | Low |
| Unclosed FileAccess | 5 | MEDIUM | Low |
| Disconnected signals | 0 | LOW | N/A |

## Top 20 High-Risk Files
1.  **`src/utils/UniversalNodeAccess.gd`**: `remove_child_safe` function does not call `queue_free()`.
2.  **`src/autoload/BattlefieldCompanionManager.gd`**: `save_session` and `load_session` functions have conditional `file.close()` calls.
3.  **`src/core/battle/BattleSystemIntegration.gd`**: `_save_battle_session` and `_load_battle_session` functions have conditional `file.close()` calls.
4.  **`src/core/error/ProductionErrorHandler.gd`**: `_open_error_log` function does not close the file handle.
5.  **`src/ui/components/dialogs/QuickStartDialog.gd`**: `_on_file_selected` function does not close the file handle.
6.  **`src/ui/screens/battle/BattleCompanionUI.gd`**: `_on_file_imported` function does not close the file handle.
7.  **`src/game/tutorial/BattleTutorialManager.gd`**: Potential circular reference by storing the parent node.

## Automated Fix Recommendations
- For `remove_child_safe` in `src/utils/UniversalNodeAccess.gd`, either rename the function to `unparent_child_safe` or add a `queue_free()` call.
- For all unclosed `FileAccess` instances, ensure `file.close()` is called in a `finally` block or using a `try-finally` pattern.
- For the potential circular reference in `src/game/tutorial/BattleTutorialManager.gd`, get the `combat_manager` from the scene tree root instead of from the parent.

## Implementation Priority
1.  **IMMEDIATE**: Fix the unclosed file handles in `src/ui/components/dialogs/QuickStartDialog.gd` and `src/ui/screens/battle/BattleCompanionUI.gd`.
2.  **HIGH**: Fix the conditional `file.close()` calls in `src/autoload/BattlefieldCompanionManager.gd` and `src/core/battle/BattleSystemIntegration.gd`.
3.  **MEDIUM**: Address the potential memory leak in `src/utils/UniversalNodeAccess.gd` and the potential circular reference in `src/game/tutorial/BattleTutorialManager.gd`.
4.  **LOW**: Review all signal connections to ensure they are being disconnected properly, even though no immediate leaks were found.
