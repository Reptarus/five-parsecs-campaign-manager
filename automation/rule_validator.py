#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Rule Compliance Validator
Production-grade validation system for Five Parsecs tabletop rule implementation accuracy
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Set, NamedTuple, Tuple
from dataclasses import dataclass
from enum import Enum
import ast

class RuleCompliance(Enum):
    COMPLIANT = "compliant"
    VIOLATION = "violation"
    WARNING = "warning"
    SUGGESTION = "suggestion"

class RuleCategory(Enum):
    CHARACTER_CREATION = "character_creation"
    CAMPAIGN_TURNS = "campaign_turns"
    COMBAT_MECHANICS = "combat_mechanics"
    EQUIPMENT_SYSTEM = "equipment_system"
    STORY_PROGRESSION = "story_progression"
    DICE_MECHANICS = "dice_mechanics"
    WORLD_GENERATION = "world_generation"

@dataclass
class RuleViolation:
    """Structured representation of Five Parsecs rule violations"""
    compliance: RuleCompliance
    category: RuleCategory
    rule_reference: str  # Core Rules page reference
    file_path: str
    line_number: Optional[int]
    function_name: Optional[str]
    violation_type: str
    description: str
    digital_implementation: str
    tabletop_rule: str
    remediation: str
    code_example: Optional[str] = None

@dataclass
class RuleValidationResult:
    """Comprehensive rule validation results"""
    is_compliant: bool
    total_violations: int
    violations: List[RuleViolation]
    compliant_implementations: int
    coverage_percentage: float
    execution_time: float

class FiveParsecsRuleValidator:
    """
    Enterprise-grade Five Parsecs tabletop rule compliance validator
    
    Validates digital implementation against official tabletop rules:
    - Character creation and progression (Core Rules p.12-17)
    - Campaign turn structure (Core Rules p.34-52)
    - Combat mechanics and resolution (Core Rules p.53-68)
    - Equipment and weapons (Core Rules p.69-76)
    - Story track progression (Core Rules p.77-84)
    - Dice mechanics and probability (Throughout)
    """
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.violations: List[RuleViolation] = []
        
        # Five Parsecs Core Rules Implementation Requirements
        self.rule_definitions = self._load_rule_definitions()
        
        # Code pattern matching for rule validation
        self.pattern_matchers = self._build_pattern_matchers()
        
    def _load_rule_definitions(self) -> Dict:
        """
        Load Five Parsecs rule definitions and requirements
        Based on the official Core Rules book
        """
        return {
            "character_creation": {
                "attribute_generation": {
                    "rule": "Roll 2d6, divide by 3, round up (minimum 1, maximum 6)",
                    "reference": "Core Rules p.13",
                    "implementation_pattern": r"(2.*d6|randi.*2.*6).*\/.*3.*ceil",
                    "dice_validation": "generate_attribute.*2d6.*3.*ceil"
                },
                "starting_health": {
                    "rule": "Health = Toughness + 2",
                    "reference": "Core Rules p.13", 
                    "implementation_pattern": r"health.*=.*toughness.*\+.*2",
                    "validation": "max_health.*toughness.*2"
                },
                "background_bonuses": {
                    "rule": "Each background provides specific attribute bonuses",
                    "reference": "Core Rules p.14-15",
                    "implementation_pattern": r"background.*bonus|apply_background",
                    "validation": "BackgroundBonuses.*apply"
                }
            },
            "campaign_turns": {
                "turn_sequence": {
                    "rule": "1.Upkeep 2.Story 3.Campaign 4.Battle 5.Resolution",
                    "reference": "Core Rules p.34",
                    "implementation_pattern": r"(UPKEEP|STORY|CAMPAIGN|BATTLE|RESOLUTION)",
                    "sequence_validation": "TurnPhase.*enum.*UPKEEP.*STORY.*CAMPAIGN.*BATTLE.*RESOLUTION"
                },
                "story_track": {
                    "rule": "Progress 1-3 steps each turn, events at steps 5,10,15,20",
                    "reference": "Core Rules p.40-41",
                    "implementation_pattern": r"story.*track.*progress.*[1-3]",
                    "event_validation": "story.*event.*[5,10,15,20]"
                }
            },
            "combat_mechanics": {
                "hit_resolution": {
                    "rule": "Combat Skill + d10 vs Target Number",
                    "reference": "Core Rules p.54",
                    "implementation_pattern": r"combat.*skill.*d10.*target",
                    "dice_validation": "d10.*combat.*skill"
                },
                "damage_calculation": {
                    "rule": "Weapon damage vs Toughness + armor",
                    "reference": "Core Rules p.55",
                    "implementation_pattern": r"damage.*toughness.*armor",
                    "armor_validation": "armor.*save.*toughness"
                }
            },
            "dice_mechanics": {
                "d66_tables": {
                    "rule": "Roll two d6, read as tens and ones (11-66)",
                    "reference": "Throughout Core Rules",
                    "implementation_pattern": r"d66.*tens.*ones|tens.*10.*ones",
                    "validation": "d66.*[1-6][1-6]"
                },
                "attribute_dice": {
                    "rule": "2d6/3 rounded up for attribute generation",
                    "reference": "Core Rules p.13",
                    "implementation_pattern": r"2d6.*3.*ceil|randi.*6.*2.*3.*ceil",
                    "validation": "generate_attribute.*2.*6.*3.*ceil"
                }
            },
            "equipment_system": {
                "weapon_traits": {
                    "rule": "Weapons have specific traits affecting combat",
                    "reference": "Core Rules p.70-72",
                    "implementation_pattern": r"weapon.*trait|WeaponTrait",
                    "validation": "weapon.*trait.*effect"
                },
                "equipment_slots": {
                    "rule": "Characters have limited equipment slots",
                    "reference": "Core Rules p.69",
                    "implementation_pattern": r"equipment.*slot|inventory.*limit",
                    "validation": "equipment.*capacity|slot.*limit"
                }
            }
        }
    
    def _build_pattern_matchers(self) -> Dict:
        """
        Build regex patterns for code analysis and rule validation
        """
        return {
            "dice_patterns": {
                "d6": re.compile(r'(randi\(\)\s*%\s*6\s*\+\s*1|d6\(\)|roll_d6)', re.IGNORECASE),
                "d10": re.compile(r'(randi\(\)\s*%\s*10\s*\+\s*1|d10\(\)|roll_d10)', re.IGNORECASE),
                "d66": re.compile(r'(d66\(\)|tens\s*\*\s*10\s*\+\s*ones)', re.IGNORECASE),
                "2d6": re.compile(r'(2.*d6|roll_dice\(2,\s*6\))', re.IGNORECASE)
            },
            "attribute_patterns": {
                "generation": re.compile(r'(generate_attribute|2d6.*3.*ceil)', re.IGNORECASE),
                "validation": re.compile(r'(combat|reaction|toughness|savvy|tech|move)', re.IGNORECASE),
                "health_calc": re.compile(r'(health.*toughness.*2|max_health.*toughness)', re.IGNORECASE)
            },
            "campaign_patterns": {
                "turn_phases": re.compile(r'(UPKEEP|STORY|CAMPAIGN|BATTLE|RESOLUTION)', re.IGNORECASE),
                "story_track": re.compile(r'(story.*track|story.*progress|story.*event)', re.IGNORECASE)
            },
            "combat_patterns": {
                "hit_calculation": re.compile(r'(combat.*skill.*d10|hit.*calculation)', re.IGNORECASE),
                "damage_resolution": re.compile(r'(damage.*toughness|armor.*save)', re.IGNORECASE)
            }
        }
    
    def validate_file(self, file_path: str, strict_mode: bool = False) -> List[RuleViolation]:
        """
        Validate a single file against Five Parsecs rules
        """
        violations = []
        
        if not os.path.exists(file_path):
            return violations
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Determine validation scope based on file path and content
            validation_scope = self._determine_validation_scope(file_path, content)
            
            for scope in validation_scope:
                scope_violations = self._validate_scope(file_path, content, scope, strict_mode)
                violations.extend(scope_violations)
                
        except Exception as e:
            violation = RuleViolation(
                compliance=RuleCompliance.VIOLATION,
                category=RuleCategory.DICE_MECHANICS,  # Default category
                rule_reference="System Error",
                file_path=file_path,
                line_number=None,
                function_name=None,
                violation_type="file_parsing_error",
                description=f"Failed to parse file for rule validation: {str(e)}",
                digital_implementation="File could not be read or parsed",
                tabletop_rule="All files must be parseable for rule validation",
                remediation="Fix file encoding, syntax errors, or access permissions"
            )
            violations.append(violation)
        
        return violations
    
    def _determine_validation_scope(self, file_path: str, content: str) -> List[RuleCategory]:
        """
        Determine which rule categories apply to this file
        """
        scopes = []
        file_name = Path(file_path).name.lower()
        content_lower = content.lower()
        
        # Character system files
        if any(term in file_name for term in ['character', 'background', 'class']):
            scopes.append(RuleCategory.CHARACTER_CREATION)
        
        # Campaign and turn management
        if any(term in file_name for term in ['campaign', 'turn', 'phase', 'world']):
            scopes.append(RuleCategory.CAMPAIGN_TURNS)
            
        # Combat system files
        if any(term in file_name for term in ['combat', 'battle', 'fight', 'weapon']):
            scopes.append(RuleCategory.COMBAT_MECHANICS)
            
        # Equipment and items
        if any(term in file_name for term in ['equipment', 'item', 'weapon', 'armor', 'gear']):
            scopes.append(RuleCategory.EQUIPMENT_SYSTEM)
            
        # Story and narrative
        if any(term in file_name for term in ['story', 'narrative', 'event', 'quest']):
            scopes.append(RuleCategory.STORY_PROGRESSION)
            
        # Dice system files
        if any(term in content_lower for term in ['dice', 'd6', 'd10', 'randi', 'random']):
            scopes.append(RuleCategory.DICE_MECHANICS)
            
        # World generation
        if any(term in file_name for term in ['world', 'planet', 'sector', 'generation']):
            scopes.append(RuleCategory.WORLD_GENERATION)
        
        # Default to dice mechanics if no specific scope found
        if not scopes:
            scopes.append(RuleCategory.DICE_MECHANICS)
            
        return scopes
    
    def _validate_scope(self, file_path: str, content: str, scope: RuleCategory, 
                       strict_mode: bool) -> List[RuleViolation]:
        """
        Validate file content against specific rule category
        """
        violations = []
        
        if scope == RuleCategory.CHARACTER_CREATION:
            violations.extend(self._validate_character_creation(file_path, content, strict_mode))
        elif scope == RuleCategory.CAMPAIGN_TURNS:
            violations.extend(self._validate_campaign_turns(file_path, content, strict_mode))
        elif scope == RuleCategory.COMBAT_MECHANICS:
            violations.extend(self._validate_combat_mechanics(file_path, content, strict_mode))
        elif scope == RuleCategory.DICE_MECHANICS:
            violations.extend(self._validate_dice_mechanics(file_path, content, strict_mode))
        elif scope == RuleCategory.EQUIPMENT_SYSTEM:
            violations.extend(self._validate_equipment_system(file_path, content, strict_mode))
        elif scope == RuleCategory.STORY_PROGRESSION:
            violations.extend(self._validate_story_progression(file_path, content, strict_mode))
        elif scope == RuleCategory.WORLD_GENERATION:
            violations.extend(self._validate_world_generation(file_path, content, strict_mode))
            
        return violations
    
    def _validate_character_creation(self, file_path: str, content: str, 
                                   strict_mode: bool) -> List[RuleViolation]:
        """
        Validate character creation mechanics against Core Rules p.12-17
        """
        violations = []
        lines = content.split('\n')
        
        # Check for proper attribute generation (2d6/3 rounded up)
        attr_gen_pattern = self.pattern_matchers["attribute_patterns"]["generation"]
        if "generate_attribute" in content or "create_character" in content:
            if not attr_gen_pattern.search(content):
                violations.append(RuleViolation(
                    compliance=RuleCompliance.VIOLATION,
                    category=RuleCategory.CHARACTER_CREATION,
                    rule_reference="Core Rules p.13",
                    file_path=file_path,
                    line_number=self._find_function_line(lines, "generate_attribute"),
                    function_name="generate_attribute",
                    violation_type="incorrect_attribute_generation",
                    description="Attribute generation doesn't follow 2d6/3 rounded up rule",
                    digital_implementation="Current implementation may use different dice or calculation",
                    tabletop_rule="Roll 2d6, divide by 3, round up (minimum 1, maximum 6)",
                    remediation="Implement: roll_dice(2, 6) / 3.0 then ceil() the result",
                    code_example="func generate_attribute() -> int:\n    var roll = DiceSystem.roll_dice(2, 6)\n    return int(ceil(float(roll) / 3.0))"
                ))
        
        # Check for proper health calculation (Toughness + 2)
        health_pattern = self.pattern_matchers["attribute_patterns"]["health_calc"]
        if ("health" in content.lower() and "toughness" in content.lower() and 
            not health_pattern.search(content)):
            violations.append(RuleViolation(
                compliance=RuleCompliance.VIOLATION,
                category=RuleCategory.CHARACTER_CREATION,
                rule_reference="Core Rules p.13",
                file_path=file_path,
                line_number=self._find_pattern_line(lines, "health"),
                function_name=None,
                violation_type="incorrect_health_calculation",
                description="Health calculation doesn't follow Toughness + 2 rule",
                digital_implementation="Health may be calculated incorrectly",
                tabletop_rule="Character Health = Toughness attribute + 2",
                remediation="Set max_health = character.toughness + 2",
                code_example="character.max_health = character.toughness + 2\ncharacter.current_health = character.max_health"
            ))
            
        # Validate background bonuses implementation
        if "background" in content.lower() and "bonus" not in content.lower():
            if strict_mode:
                violations.append(RuleViolation(
                    compliance=RuleCompliance.WARNING,
                    category=RuleCategory.CHARACTER_CREATION,
                    rule_reference="Core Rules p.14-15",
                    file_path=file_path,
                    line_number=self._find_pattern_line(lines, "background"),
                    function_name=None,
                    violation_type="missing_background_bonuses",
                    description="Background system present but bonuses not implemented",
                    digital_implementation="Background selection without mechanical benefits",
                    tabletop_rule="Each background provides specific attribute or skill bonuses",
                    remediation="Implement background bonus application in character creation",
                    code_example="func apply_background_bonuses(character: Character, background: Background):\n    match background:\n        Background.SOLDIER:\n            character.combat += 1\n        Background.TRADER:\n            character.savvy += 1"
                ))
        
        return violations
    
    def _validate_dice_mechanics(self, file_path: str, content: str, 
                               strict_mode: bool) -> List[RuleViolation]:
        """
        Validate dice mechanics against Five Parsecs standards
        """
        violations = []
        lines = content.split('\n')
        
        # Check for proper d66 implementation
        if "d66" in content.lower():
            d66_pattern = self.pattern_matchers["dice_patterns"]["d66"]
            if not d66_pattern.search(content):
                violations.append(RuleViolation(
                    compliance=RuleCompliance.VIOLATION,
                    category=RuleCategory.DICE_MECHANICS,
                    rule_reference="Throughout Core Rules",
                    file_path=file_path,
                    line_number=self._find_pattern_line(lines, "d66"),
                    function_name="d66",
                    violation_type="incorrect_d66_implementation",
                    description="d66 implementation doesn't follow tens+ones format",
                    digital_implementation="May be using incorrect d66 calculation",
                    tabletop_rule="Roll two d6, first die is tens, second is ones (results 11-66)",
                    remediation="Implement: tens_die * 10 + ones_die",
                    code_example="func d66() -> int:\n    var tens = randi() % 6 + 1\n    var ones = randi() % 6 + 1\n    return tens * 10 + ones"
                ))
        
        # Validate proper random number generation patterns
        if "randi()" in content and "%" not in content:
            violations.append(RuleViolation(
                compliance=RuleCompliance.SUGGESTION,
                category=RuleCategory.DICE_MECHANICS,
                rule_reference="Best Practices",
                file_path=file_path,
                line_number=self._find_pattern_line(lines, "randi()"),
                function_name=None,
                violation_type="unbounded_random",
                description="Using randi() without bounds may not simulate proper dice",
                digital_implementation="Unbounded random number generation",
                tabletop_rule="Dice have specific ranges (d6: 1-6, d10: 1-10, etc.)",
                remediation="Use randi() % sides + 1 for proper dice simulation",
                code_example="# Good: randi() % 6 + 1  # d6 (1-6)\n# Bad: randi()  # 0 to max_int"
            ))
        
        return violations
    
    def _validate_combat_mechanics(self, file_path: str, content: str, 
                                 strict_mode: bool) -> List[RuleViolation]:
        """
        Validate combat mechanics against Core Rules p.53-68
        """
        violations = []
        lines = content.split('\n')
        
        # Check for proper hit calculation (Combat Skill + d10)
        if ("combat" in content.lower() and "hit" in content.lower() and 
            not self.pattern_matchers["combat_patterns"]["hit_calculation"].search(content)):
            violations.append(RuleViolation(
                compliance=RuleCompliance.VIOLATION,
                category=RuleCategory.COMBAT_MECHANICS,
                rule_reference="Core Rules p.54",
                file_path=file_path,
                line_number=self._find_pattern_line(lines, "combat"),
                function_name=None,
                violation_type="incorrect_hit_calculation",
                description="Hit calculation doesn't follow Combat Skill + d10 rule",
                digital_implementation="May be using different hit calculation method",
                tabletop_rule="To hit: Combat Skill + d10 vs Target Number",
                remediation="Implement: character.combat_skill + DiceSystem.d10() >= target_number",
                code_example="func calculate_hit(attacker: Character, target_number: int) -> bool:\n    var roll = attacker.combat_skill + DiceSystem.d10()\n    return roll >= target_number"
            ))
        
        return violations
    
    def _validate_campaign_turns(self, file_path: str, content: str, 
                                strict_mode: bool) -> List[RuleViolation]:
        """
        Validate campaign turn structure against Core Rules p.34-52
        """
        violations = []
        lines = content.split('\n')
        
        # Check for proper turn phase sequence
        turn_phases = ["UPKEEP", "STORY", "CAMPAIGN", "BATTLE", "RESOLUTION"]
        if "phase" in content.lower() or "turn" in content.lower():
            phases_found = [phase for phase in turn_phases if phase in content.upper()]
            
            if len(phases_found) < 3 and ("enum" in content.lower() or "class" in content.lower()):
                violations.append(RuleViolation(
                    compliance=RuleCompliance.WARNING,
                    category=RuleCategory.CAMPAIGN_TURNS,
                    rule_reference="Core Rules p.34",
                    file_path=file_path,
                    line_number=self._find_pattern_line(lines, "phase"),
                    function_name=None,
                    violation_type="incomplete_turn_phases",
                    description="Turn phase system doesn't include all required phases",
                    digital_implementation="Missing some of the 5 required turn phases",
                    tabletop_rule="5 phases: Upkeep, Story, Campaign, Battle, Resolution (in order)",
                    remediation="Include all 5 turn phases in enum or class definition",
                    code_example="enum TurnPhase {\n    UPKEEP,\n    STORY,\n    CAMPAIGN,\n    BATTLE,\n    RESOLUTION\n}"
                ))
        
        return violations
    
    def _validate_equipment_system(self, file_path: str, content: str, 
                                 strict_mode: bool) -> List[RuleViolation]:
        """
        Validate equipment system against Core Rules p.69-76
        """
        violations = []
        lines = content.split('\n')
        
        # Check for weapon traits implementation
        if ("weapon" in content.lower() and "trait" not in content.lower() and 
            ("class" in content.lower() or "enum" in content.lower())):
            violations.append(RuleViolation(
                compliance=RuleCompliance.SUGGESTION,
                category=RuleCategory.EQUIPMENT_SYSTEM,
                rule_reference="Core Rules p.70-72",
                file_path=file_path,
                line_number=self._find_pattern_line(lines, "weapon"),
                function_name=None,
                violation_type="missing_weapon_traits",
                description="Weapon system present but traits not implemented",
                digital_implementation="Weapons may lack special traits and abilities",
                tabletop_rule="Weapons have traits that affect combat (Piercing, Blast, etc.)",
                remediation="Implement weapon traits system for combat mechanics",
                code_example="enum WeaponTrait {\n    PIERCING,\n    BLAST,\n    HEAVY,\n    SINGLE_USE\n}"
            ))
        
        return violations
    
    def _validate_story_progression(self, file_path: str, content: str, 
                                  strict_mode: bool) -> List[RuleViolation]:
        """
        Validate story progression against Core Rules p.77-84
        """
        violations = []
        # Story progression validation would go here
        # Implementation depends on specific story system architecture
        return violations
    
    def _validate_world_generation(self, file_path: str, content: str, 
                                 strict_mode: bool) -> List[RuleViolation]:
        """
        Validate world generation mechanics
        """
        violations = []
        # World generation validation would go here
        # Implementation depends on specific world generation system
        return violations
    
    def _find_function_line(self, lines: List[str], function_name: str) -> Optional[int]:
        """Find the line number where a function is defined"""
        for i, line in enumerate(lines):
            if f"func {function_name}" in line:
                return i + 1
        return None
    
    def _find_pattern_line(self, lines: List[str], pattern: str) -> Optional[int]:
        """Find the line number where a pattern first appears"""
        for i, line in enumerate(lines):
            if pattern.lower() in line.lower():
                return i + 1
        return None
    
    def run_comprehensive_validation(self, target_files: List[str], 
                                   strict_mode: bool = False) -> RuleValidationResult:
        """
        Run comprehensive Five Parsecs rule validation across multiple files
        """
        import time
        start_time = time.time()
        
        all_violations = []
        compliant_count = 0
        
        print("[DICE] Starting Five Parsecs rule compliance validation...")
        
        for file_path in target_files:
            if not file_path.endswith('.gd'):
                continue
                
            print(f"[LIST] Validating: {Path(file_path).name}")
            
            file_violations = self.validate_file(file_path, strict_mode)
            all_violations.extend(file_violations)
            
            if not file_violations:
                compliant_count += 1
        
        execution_time = time.time() - start_time
        
        # Calculate compliance metrics
        total_files = len([f for f in target_files if f.endswith('.gd')])
        compliance_percentage = (compliant_count / total_files * 100) if total_files > 0 else 0
        
        result = RuleValidationResult(
            is_compliant=len(all_violations) == 0,
            total_violations=len(all_violations),
            violations=all_violations,
            compliant_implementations=compliant_count,
            coverage_percentage=compliance_percentage,
            execution_time=execution_time
        )
        
        return result

def main():
    """
    Command-line interface for Five Parsecs rule validation
    Designed for integration with Claude Hooks and development workflows
    """
    parser = argparse.ArgumentParser(
        description="Five Parsecs Campaign Manager - Rule Compliance Validator"
    )
    
    parser.add_argument(
        "--validate-file",
        help="Validate a specific file against Five Parsecs rules"
    )
    
    parser.add_argument(
        "--validate-directory",
        help="Validate all GDScript files in a directory"
    )
    
    parser.add_argument(
        "--ruleset",
        choices=["five-parsecs-core", "five-parsecs-expanded"],
        default="five-parsecs-core",
        help="Ruleset to validate against"
    )
    
    parser.add_argument(
        "--strict-mode",
        action="store_true",
        help="Enable strict rule compliance checking"
    )
    
    parser.add_argument(
        "--output-format",
        choices=["json", "text"],
        default="text",
        help="Output format for validation results"
    )
    
    parser.add_argument(
        "--fail-on-violations",
        action="store_true",
        help="Exit with error code if rule violations found"
    )
    
    args = parser.parse_args()
    
    # Initialize validator
    project_root = os.getcwd()
    validator = FiveParsecsRuleValidator(project_root)
    
    # Determine target files
    target_files = []
    
    if args.validate_file:
        target_files = [args.validate_file]
    elif args.validate_directory:
        target_dir = Path(args.validate_directory)
        target_files = [str(f) for f in target_dir.rglob("*.gd")]
    else:
        # Default to validating game-specific files
        game_dir = Path(project_root) / "src" / "game"
        if game_dir.exists():
            target_files = [str(f) for f in game_dir.rglob("*.gd")]
    
    # Run validation
    result = validator.run_comprehensive_validation(target_files, args.strict_mode)
    
    # Output results
    if args.output_format == "json":
        result_data = {
            "is_compliant": result.is_compliant,
            "total_violations": result.total_violations,
            "compliant_implementations": result.compliant_implementations,
            "coverage_percentage": result.coverage_percentage,
            "execution_time": result.execution_time,
            "violations": [
                {
                    "compliance": v.compliance.value,
                    "category": v.category.value,
                    "rule_reference": v.rule_reference,
                    "file_path": v.file_path,
                    "line_number": v.line_number,
                    "function_name": v.function_name,
                    "violation_type": v.violation_type,
                    "description": v.description,
                    "digital_implementation": v.digital_implementation,
                    "tabletop_rule": v.tabletop_rule,
                    "remediation": v.remediation,
                    "code_example": v.code_example
                }
                for v in result.violations
            ]
        }
        print(json.dumps(result_data, indent=2))
    else:
        print(f"\n[DICE] Five Parsecs Rule Compliance Summary")
        print(f"Overall Compliance: {'[COMPLETE] COMPLIANT' if result.is_compliant else '[FAIL] VIOLATIONS FOUND'}")
        print(f"Files Validated: {len(target_files)}")
        print(f"Compliant Files: {result.compliant_implementations}")
        print(f"Coverage: {result.coverage_percentage:.1f}%")
        print(f"Total Violations: {result.total_violations}")
        print(f"Execution Time: {result.execution_time:.2f}s")
        
        if result.violations:
            print(f"\n[LIST] Rule Violations:")
            for violation in result.violations:
                print(f"\n{violation.compliance.value.upper()}: {violation.violation_type}")
                print(f"  File: {Path(violation.file_path).name}")
                if violation.line_number:
                    print(f"  Line: {violation.line_number}")
                if violation.function_name:
                    print(f"  Function: {violation.function_name}")
                print(f"  Rule: {violation.tabletop_rule}")
                print(f"  Issue: {violation.description}")
                print(f"  Fix: {violation.remediation}")
                if violation.code_example:
                    print(f"  Example:\n{violation.code_example}")
    
    # Exit with appropriate code
    if args.fail_on_violations and result.total_violations > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()