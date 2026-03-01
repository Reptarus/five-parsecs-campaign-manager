#!/bin/bash
# Check external references for all Base* class files

echo "=== Base Class External Reference Count ==="
echo ""

declare -A files=(
    ["BaseCampaign"]="src/base/campaign/BaseCampaign.gd"
    ["BaseMissionGenerator"]="src/base/campaign/BaseMissionGenerator.gd"
    ["BaseCrew"]="src/base/campaign/crew/BaseCrew.gd"
    ["BaseCrewMember"]="src/base/campaign/crew/BaseCrewMember.gd"
    ["BaseCrewRelationshipManager"]="src/base/campaign/crew/BaseCrewRelationshipManager.gd"
    ["BaseStrangeCharacters"]="src/base/campaign/crew/BaseStrangeCharacters.gd"
    ["BaseCharacterCreationSystem"]="src/base/character/BaseCharacterCreationSystem.gd"
    ["BaseBattleCharacter"]="src/base/combat/BaseBattleCharacter.gd"
    ["BaseBattleData"]="src/base/combat/BaseBattleData.gd"
    ["BaseBattleRules"]="src/base/combat/BaseBattleRules.gd"
    ["BaseCombatManager"]="src/base/combat/BaseCombatManager.gd"
    ["BaseMainBattleController"]="src/base/combat/BaseMainBattleController.gd"
    ["BaseBattlefieldGenerator"]="src/base/combat/battlefield/BaseBattlefieldGenerator.gd"
    ["BaseBattlefieldManager"]="src/base/combat/battlefield/BaseBattlefieldManager.gd"
    ["BaseEnemyScalingSystem"]="src/base/combat/enemy/BaseEnemyScalingSystem.gd"
    ["BaseBattleEventSystem"]="src/base/combat/events/BaseBattleEventSystem.gd"
    ["BaseObjectiveSystem"]="src/base/combat/objectives/BaseObjectiveSystem.gd"
    ["BaseBattleRewardSystem"]="src/base/combat/rewards/BaseBattleRewardSystem.gd"
    ["BaseBattleStatisticsTracker"]="src/base/combat/statistics/BaseBattleStatisticsTracker.gd"
    ["BaseMissionGenerationSystem"]="src/base/mission/BaseMissionGenerationSystem.gd"
    ["BaseCampaignDashboardSystem"]="src/base/ui/BaseCampaignDashboardSystem.gd"
    ["BaseCrewComponent"]="src/base/ui/BaseCrewComponent.gd"
    ["BaseInformationCard"]="src/base/ui/BaseInformationCard.gd"
    ["ICampaignCreationPanel"]="src/base/ui/ICampaignCreationPanel.gd"
)

for class_name in "${!files[@]}"; do
    file_path="${files[$class_name]}"
    count=$(grep -r "$class_name" src/ --include="*.gd" | grep -v "$file_path:" | wc -l)
    printf "%-35s %3d refs\n" "$class_name:" "$count"
done | sort -t: -k2 -n

echo ""
echo "=== Files with ZERO references are safe to delete ==="
