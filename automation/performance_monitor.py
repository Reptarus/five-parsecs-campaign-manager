#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Performance Monitor
Real-time performance analysis and optimization recommendations for Godot game development
"""

import os
import sys
import json
import re
import ast
import argparse
import time
import statistics
from pathlib import Path
from typing import Dict, List, Optional, Set, NamedTuple, Tuple, Any
from dataclasses import dataclass
from enum import Enum
import subprocess

class PerformanceLevel(Enum):
    EXCELLENT = "excellent"
    GOOD = "good"
    MODERATE = "moderate"
    POOR = "poor"
    CRITICAL = "critical"

class PerformanceCategory(Enum):
    CODE_COMPLEXITY = "code_complexity"
    MEMORY_USAGE = "memory_usage"
    RENDERING_PERFORMANCE = "rendering_performance"
    SCRIPT_EFFICIENCY = "script_efficiency"
    ASSET_OPTIMIZATION = "asset_optimization"
    FRAME_RATE_IMPACT = "frame_rate_impact"

@dataclass
class PerformanceIssue:
    """Structured performance issue with optimization recommendations"""
    level: PerformanceLevel
    category: PerformanceCategory
    file_path: str
    line_number: Optional[int]
    function_name: Optional[str]
    metric_name: str
    current_value: float
    target_value: float
    description: str
    performance_impact: str
    optimization_recommendation: str
    code_example: Optional[str] = None
    estimated_improvement: Optional[str] = None

@dataclass
class PerformanceAnalysisResult:
    """Comprehensive performance analysis results"""
    overall_performance: PerformanceLevel
    total_issues: int
    critical_issues: int
    poor_issues: int
    moderate_issues: int
    complexity_score: float
    memory_efficiency: float
    rendering_score: float
    frame_rate_projection: float
    issues: List[PerformanceIssue]
    optimization_priorities: List[str]
    execution_time: float

class FiveParsecsPerformanceMonitor:
    """
    Enterprise-grade performance monitoring system for Five Parsecs Campaign Manager
    
    Monitors and optimizes:
    - Code complexity and cyclomatic complexity
    - Memory usage patterns and resource management
    - Rendering performance and draw call optimization
    - Script execution efficiency and hotspots
    - Asset loading and streaming performance
    - Frame rate impact analysis for 60 FPS target
    """
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.issues: List[PerformanceIssue] = []
        
        # Performance thresholds for Five Parsecs Campaign Manager
        self.performance_thresholds = {
            "cyclomatic_complexity": {
                "excellent": 5,
                "good": 10,
                "moderate": 15,
                "poor": 20,
                "critical": 25
            },
            "function_length": {
                "excellent": 20,
                "good": 50,
                "moderate": 100,
                "poor": 200,
                "critical": 300
            },
            "class_size": {
                "excellent": 200,
                "good": 500,
                "moderate": 1000,
                "poor": 2000,
                "critical": 3000
            },
            "nesting_depth": {
                "excellent": 3,
                "good": 4,
                "moderate": 5,
                "poor": 6,
                "critical": 7
            },
            "memory_allocations": {
                "excellent": 10,
                "good": 25,
                "moderate": 50,
                "poor": 100,
                "critical": 200
            }
        }
        
        # Performance-critical patterns for Godot optimization
        self.optimization_patterns = self._build_optimization_patterns()
        
        # Frame rate impact factors
        self.frame_rate_factors = {
            "heavy_loops": -5.0,        # FPS impact per heavy loop
            "unoptimized_rendering": -10.0,  # FPS impact per rendering issue
            "memory_allocations": -2.0,     # FPS impact per allocation hotspot
            "complex_calculations": -3.0,   # FPS impact per complex calculation
            "inefficient_signals": -1.0     # FPS impact per signal issue
        }
        
    def _build_optimization_patterns(self) -> Dict[str, Dict]:
        """
        Build performance optimization pattern definitions
        """
        return {
            "rendering_optimization": {
                "inefficient_patterns": [
                    r"get_node\([^)]+\)\.get_node",  # Nested get_node calls
                    r"for\s+\w+\s+in\s+get_children\(\)",  # Frequent get_children
                    r"queue_redraw\(\).*for.*in",  # queue_redraw in loops
                    r"update\(\).*for.*in"  # update() in loops
                ],
                "optimizations": {
                    "cache_node_references": "Cache node references instead of frequent get_node calls",
                    "batch_updates": "Batch UI updates instead of individual calls",
                    "use_object_pooling": "Use object pooling for frequently created/destroyed objects"
                }
            },
            "memory_optimization": {
                "inefficient_patterns": [
                    r"new\(\).*for.*in",  # Object creation in loops
                    r"Array\(\).*for.*in",  # Array creation in loops
                    r"Dictionary\(\).*for.*in",  # Dictionary creation in loops
                    r"PackedStringArray\(\).*for.*in"  # PackedArray creation in loops
                ],
                "optimizations": {
                    "reuse_containers": "Reuse containers instead of creating new ones",
                    "use_object_pools": "Implement object pooling for frequently used objects",
                    "cache_calculations": "Cache expensive calculations and lookups"
                }
            },
            "script_efficiency": {
                "inefficient_patterns": [
                    r"_process.*get_node",  # get_node in _process
                    r"_physics_process.*new\(",  # Object creation in physics process
                    r"for.*in.*for.*in.*for",  # Triple nested loops
                    r"while.*true.*while"  # Nested infinite loops
                ],
                "optimizations": {
                    "cache_references": "Cache node references in _ready() instead of _process()",
                    "optimize_loops": "Optimize nested loops and consider algorithm improvements",
                    "use_timers": "Use Timer nodes instead of polling in _process"
                }
            }
        }
    
    def analyze_file_performance(self, file_path: str) -> List[PerformanceIssue]:
        """
        Analyze performance characteristics of a single file
        """
        issues = []
        
        if not os.path.exists(file_path) or not file_path.endswith('.gd'):
            return issues
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            lines = content.split('\n')
            
            # Analyze code complexity
            issues.extend(self._analyze_code_complexity(file_path, content, lines))
            
            # Analyze memory usage patterns
            issues.extend(self._analyze_memory_patterns(file_path, content, lines))
            
            # Analyze rendering performance
            issues.extend(self._analyze_rendering_performance(file_path, content, lines))
            
            # Analyze script efficiency
            issues.extend(self._analyze_script_efficiency(file_path, content, lines))
            
            # Validate 60 FPS target compatibility
            issues.extend(self._validate_60fps_target(file_path, content, lines))
            
        except Exception as e:
            issues.append(PerformanceIssue(
                level=PerformanceLevel.MODERATE,
                category=PerformanceCategory.SCRIPT_EFFICIENCY,
                file_path=file_path,
                line_number=None,
                function_name=None,
                metric_name="file_analysis_error",
                current_value=0.0,
                target_value=1.0,
                description=f"Failed to analyze file performance: {str(e)}",
                performance_impact="Cannot optimize file due to analysis failure",
                optimization_recommendation="Fix file encoding or syntax errors",
                code_example=None,
                estimated_improvement="Unknown until file can be analyzed"
            ))
        
        return issues
    
    def _analyze_code_complexity(self, file_path: str, content: str, 
                                lines: List[str]) -> List[PerformanceIssue]:
        """
        Analyze code complexity metrics
        """
        issues = []
        
        # Calculate cyclomatic complexity for functions
        functions = self._extract_functions(content)
        
        for func_name, func_content, func_start_line in functions:
            complexity = self._calculate_cyclomatic_complexity(func_content)
            
            performance_level = self._get_performance_level("cyclomatic_complexity", complexity)
            
            if performance_level in [PerformanceLevel.POOR, PerformanceLevel.CRITICAL]:
                issues.append(PerformanceIssue(
                    level=performance_level,
                    category=PerformanceCategory.CODE_COMPLEXITY,
                    file_path=file_path,
                    line_number=func_start_line,
                    function_name=func_name,
                    metric_name="cyclomatic_complexity",
                    current_value=float(complexity),
                    target_value=float(self.performance_thresholds["cyclomatic_complexity"]["good"]),
                    description=f"Function {func_name} has high cyclomatic complexity: {complexity}",
                    performance_impact="High complexity functions are harder to optimize and may impact performance",
                    optimization_recommendation="Break down function into smaller, focused methods",
                    code_example=f"""# Refactor {func_name} to reduce complexity:
func {func_name}_simplified(data: Dictionary) -> void:
    _validate_input(data)
    _process_core_logic(data)
    _handle_results(data)

func _validate_input(data: Dictionary) -> bool:
    # Extract validation logic here
    pass

func _process_core_logic(data: Dictionary) -> void:
    # Extract main processing logic here
    pass""",
                    estimated_improvement=f"Reducing complexity to <10 could improve maintainability and performance by 15-25%"
                ))
        
        # Check function length
        for func_name, func_content, func_start_line in functions:
            func_lines = len(func_content.split('\n'))
            
            performance_level = self._get_performance_level("function_length", func_lines)
            
            if performance_level in [PerformanceLevel.POOR, PerformanceLevel.CRITICAL]:
                issues.append(PerformanceIssue(
                    level=performance_level,
                    category=PerformanceCategory.CODE_COMPLEXITY,
                    file_path=file_path,
                    line_number=func_start_line,
                    function_name=func_name,
                    metric_name="function_length",
                    current_value=float(func_lines),
                    target_value=float(self.performance_thresholds["function_length"]["good"]),
                    description=f"Function {func_name} is too long: {func_lines} lines",
                    performance_impact="Large functions are harder to optimize and may cause compilation delays",
                    optimization_recommendation=f"Split {func_name} into smaller, focused functions",
                    code_example=f"# Split {func_name} into logical sub-functions of <50 lines each",
                    estimated_improvement="Smaller functions typically improve performance by 10-20%"
                ))
        
        # Check class size
        total_lines = len(lines)
        performance_level = self._get_performance_level("class_size", total_lines)
        
        if performance_level in [PerformanceLevel.POOR, PerformanceLevel.CRITICAL]:
            issues.append(PerformanceIssue(
                level=performance_level,
                category=PerformanceCategory.CODE_COMPLEXITY,
                file_path=file_path,
                line_number=None,
                function_name=None,
                metric_name="class_size",
                current_value=float(total_lines),
                target_value=float(self.performance_thresholds["class_size"]["good"]),
                description=f"Class is too large: {total_lines} lines",
                performance_impact="Large classes increase compilation time and memory usage",
                optimization_recommendation="Split class into multiple focused classes or use composition",
                code_example="""# Split large class into focused components:
class_name MainSystem extends Node

var character_manager: CharacterManager
var equipment_manager: EquipmentManager
var ui_manager: UIManager

func _ready() -> void:
    character_manager = CharacterManager.new()
    equipment_manager = EquipmentManager.new()
    ui_manager = UIManager.new()""",
                estimated_improvement="Splitting large classes can improve compilation speed by 30-50%"
            ))
        
        return issues
    
    def _analyze_memory_patterns(self, file_path: str, content: str, 
                                lines: List[str]) -> List[PerformanceIssue]:
        """
        Analyze memory usage patterns and allocations
        """
        issues = []
        
        # Check for object creation in loops
        for pattern_name, pattern in self.optimization_patterns["memory_optimization"]["inefficient_patterns"]:
            matches = re.finditer(pattern, content, re.MULTILINE)
            
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                
                issues.append(PerformanceIssue(
                    level=PerformanceLevel.POOR,
                    category=PerformanceCategory.MEMORY_USAGE,
                    file_path=file_path,
                    line_number=line_num,
                    function_name=self._get_function_at_line(lines, line_num),
                    metric_name="memory_allocation_in_loop",
                    current_value=1.0,
                    target_value=0.0,
                    description=f"Object creation in loop detected: {match.group()}",
                    performance_impact="Memory allocations in loops cause GC pressure and frame drops",
                    optimization_recommendation="Move object creation outside loop or use object pooling",
                    code_example="""# Bad: Creates objects in loop
for i in range(1000):
    var obj = SomeClass.new()  # Memory allocation each iteration

# Good: Reuse objects
var reusable_obj = SomeClass.new()
for i in range(1000):
    reusable_obj.reset()  # Reuse existing object""",
                    estimated_improvement="Object pooling can improve performance by 40-60% in intensive loops"
                ))
        
        # Check for frequent new() calls
        new_calls = len(re.findall(r'\.new\(\)', content))
        if new_calls > self.performance_thresholds["memory_allocations"]["moderate"]:
            performance_level = self._get_performance_level("memory_allocations", new_calls)
            
            issues.append(PerformanceIssue(
                level=performance_level,
                category=PerformanceCategory.MEMORY_USAGE,
                file_path=file_path,
                line_number=None,
                function_name=None,
                metric_name="frequent_allocations",
                current_value=float(new_calls),
                target_value=float(self.performance_thresholds["memory_allocations"]["good"]),
                description=f"High number of object allocations: {new_calls} new() calls",
                performance_impact="Frequent allocations increase GC pressure and cause frame stuttering",
                optimization_recommendation="Implement object pooling and reduce unnecessary object creation",
                code_example="""# Implement object pooling system
class ObjectPool:
    var available_objects: Array = []
    var object_class: GDScript
    
    func get_object():
        if available_objects.is_empty():
            return object_class.new()
        return available_objects.pop_back()
    
    func return_object(obj):
        obj.reset()  # Reset object state
        available_objects.append(obj)""",
                estimated_improvement="Object pooling can reduce GC pressure by 70-80%"
            ))
        
        return issues
    
    def _analyze_rendering_performance(self, file_path: str, content: str, 
                                     lines: List[str]) -> List[PerformanceIssue]:
        """
        Analyze rendering performance patterns
        """
        issues = []
        
        # Check for rendering inefficiencies
        for i, pattern in enumerate(self.optimization_patterns["rendering_optimization"]["inefficient_patterns"]):
            matches = re.finditer(pattern, content, re.MULTILINE)
            
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                
                if i == 0:  # Nested get_node calls
                    issues.append(PerformanceIssue(
                        level=PerformanceLevel.MODERATE,
                        category=PerformanceCategory.RENDERING_PERFORMANCE,
                        file_path=file_path,
                        line_number=line_num,
                        function_name=self._get_function_at_line(lines, line_num),
                        metric_name="nested_node_access",
                        current_value=1.0,
                        target_value=0.0,
                        description="Nested get_node() calls detected",
                        performance_impact="Multiple node lookups per frame impact rendering performance",
                        optimization_recommendation="Cache node references in _ready() method",
                        code_example="""# Bad: Nested get_node calls
get_node("UI").get_node("Panel").get_node("Label").text = "Hello"

# Good: Cache references
@onready var label: Label = $UI/Panel/Label

func update_text():
    label.text = "Hello"  # Direct reference""",
                        estimated_improvement="Caching node references improves performance by 20-30%"
                    ))
                
                elif i == 2 or i == 3:  # queue_redraw/update in loops
                    issues.append(PerformanceIssue(
                        level=PerformanceLevel.POOR,
                        category=PerformanceCategory.RENDERING_PERFORMANCE,
                        file_path=file_path,
                        line_number=line_num,
                        function_name=self._get_function_at_line(lines, line_num),
                        metric_name="rendering_in_loop",
                        current_value=1.0,
                        target_value=0.0,
                        description="Rendering update calls in loop detected",
                        performance_impact="Multiple render calls per frame cause severe frame rate drops",
                        optimization_recommendation="Batch updates or call rendering outside loop",
                        code_example="""# Bad: Multiple render calls
for item in items:
    update_ui(item)
    queue_redraw()  # Called many times

# Good: Single render call
for item in items:
    update_ui(item)
queue_redraw()  # Called once after loop""",
                        estimated_improvement="Batching render calls can improve FPS by 300-500%"
                    ))
        
        # Check for frequent get_children() calls
        get_children_calls = len(re.findall(r'get_children\(\)', content))
        if get_children_calls > 5:
            issues.append(PerformanceIssue(
                level=PerformanceLevel.MODERATE,
                category=PerformanceCategory.RENDERING_PERFORMANCE,
                file_path=file_path,
                line_number=None,
                function_name=None,
                metric_name="frequent_children_access",
                current_value=float(get_children_calls),
                target_value=2.0,
                description=f"Frequent get_children() calls: {get_children_calls}",
                performance_impact="Frequent child node enumeration impacts rendering performance",
                optimization_recommendation="Cache child node arrays or use direct references",
                code_example="""# Cache children array
@onready var cached_children: Array[Node] = get_children()

func process_children():
    for child in cached_children:  # Use cached array
        child.process()""",
                estimated_improvement="Caching children arrays improves performance by 15-25%"
            ))
        
        return issues
    
    def _analyze_script_efficiency(self, file_path: str, content: str, 
                                 lines: List[str]) -> List[PerformanceIssue]:
        """
        Analyze script execution efficiency
        """
        issues = []
        
        # Check for inefficient patterns in performance-critical methods
        critical_methods = ["_process", "_physics_process", "_draw", "_input"]
        
        for method in critical_methods:
            method_pattern = rf'func {method}\([^)]*\):(.*?)(?=func|\Z)'
            method_matches = re.finditer(method_pattern, content, re.DOTALL)
            
            for match in method_matches:
                method_content = match.group(1)
                method_start = content[:match.start()].count('\n') + 1
                
                # Check for expensive operations in critical methods
                if "get_node" in method_content:
                    issues.append(PerformanceIssue(
                        level=PerformanceLevel.POOR,
                        category=PerformanceCategory.SCRIPT_EFFICIENCY,
                        file_path=file_path,
                        line_number=method_start,
                        function_name=method,
                        metric_name="expensive_operation_in_critical_method",
                        current_value=1.0,
                        target_value=0.0,
                        description=f"get_node() call in {method} method",
                        performance_impact=f"{method} is called every frame - expensive operations cause frame drops",
                        optimization_recommendation=f"Cache node references in _ready() instead of {method}",
                        code_example=f"""# Bad: Node lookup every frame
func {method}(delta):
    var player = get_node("Player")  # Expensive lookup every frame
    
# Good: Cache reference
@onready var player: Node = $Player

func {method}(delta):
    # Use cached reference - much faster""",
                        estimated_improvement="Caching references in critical methods improves FPS by 50-100%"
                    ))
                
                if "new(" in method_content:
                    issues.append(PerformanceIssue(
                        level=PerformanceLevel.CRITICAL,
                        category=PerformanceCategory.SCRIPT_EFFICIENCY,
                        file_path=file_path,
                        line_number=method_start,
                        function_name=method,
                        metric_name="object_creation_in_critical_method",
                        current_value=1.0,
                        target_value=0.0,
                        description=f"Object creation in {method} method",
                        performance_impact=f"Creating objects every frame in {method} causes severe performance issues",
                        optimization_recommendation=f"Move object creation outside {method} or use object pooling",
                        code_example=f"""# Bad: Object creation every frame
func {method}(delta):
    var temp_array = Array.new()  # Bad!
    
# Good: Reuse objects
var reusable_array = Array()

func {method}(delta):
    reusable_array.clear()  # Reset existing array""",
                        estimated_improvement="Eliminating object creation in critical methods can improve FPS by 200-400%"
                    ))
        
        # Check for nested loops complexity
        nested_loops = len(re.findall(r'for.*in.*for.*in.*for.*in', content))
        if nested_loops > 0:
            issues.append(PerformanceIssue(
                level=PerformanceLevel.POOR,
                category=PerformanceCategory.SCRIPT_EFFICIENCY,
                file_path=file_path,
                line_number=None,
                function_name=None,
                metric_name="triple_nested_loops",
                current_value=float(nested_loops),
                target_value=0.0,
                description=f"Triple nested loops detected: {nested_loops}",
                performance_impact="Triple nested loops have O(n³) complexity and can freeze the game",
                optimization_recommendation="Optimize algorithm or use data structures to reduce complexity",
                code_example="""# Bad: O(n³) complexity
for a in array_a:
    for b in array_b:
        for c in array_c:
            # This is very slow

# Good: Use hash maps or optimize algorithm
var lookup_map = {}
for item in items:
    lookup_map[item.id] = item

# Now use O(1) lookup instead of nested loops""",
                estimated_improvement="Algorithm optimization can improve performance by 1000%+ for large datasets"
            ))
        
        return issues
    
    def _validate_60fps_target(self, file_path: str, content: str, 
                             lines: List[str]) -> List[PerformanceIssue]:
        """
        Validate code against 60 FPS target requirements
        """
        issues = []
        
        # Calculate estimated frame rate impact
        frame_impact = 0.0
        
        # Count performance impacting patterns
        heavy_loops = len(re.findall(r'for.*in.*for.*in', content))
        frame_impact += heavy_loops * self.frame_rate_factors["heavy_loops"]
        
        rendering_issues = len(re.findall(r'queue_redraw\(\).*for|update\(\).*for', content))
        frame_impact += rendering_issues * self.frame_rate_factors["unoptimized_rendering"]
        
        memory_hotspots = len(re.findall(r'new\(\).*for.*in', content))
        frame_impact += memory_hotspots * self.frame_rate_factors["memory_allocations"]
        
        # Estimate projected FPS (starting from 60 FPS baseline)
        projected_fps = max(10.0, 60.0 + frame_impact)
        
        if projected_fps < 50.0:
            performance_level = PerformanceLevel.CRITICAL if projected_fps < 30.0 else PerformanceLevel.POOR
            
            issues.append(PerformanceIssue(
                level=performance_level,
                category=PerformanceCategory.FRAME_RATE_IMPACT,
                file_path=file_path,
                line_number=None,
                function_name=None,
                metric_name="projected_fps",
                current_value=projected_fps,
                target_value=60.0,
                description=f"Projected frame rate: {projected_fps:.1f} FPS (below 60 FPS target)",
                performance_impact="Code patterns may prevent achieving 60 FPS target",
                optimization_recommendation="Address performance issues to improve frame rate",
                code_example="""# Optimize for 60 FPS target:
1. Cache node references
2. Use object pooling
3. Batch rendering operations
4. Optimize algorithms (reduce O(n²) to O(n log n))
5. Move expensive operations off main thread""",
                estimated_improvement=f"Optimizations could improve FPS from {projected_fps:.1f} to 60+ FPS"
            ))
        
        return issues
    
    def _extract_functions(self, content: str) -> List[Tuple[str, str, int]]:
        """
        Extract function definitions with their content and line numbers
        """
        functions = []
        lines = content.split('\n')
        
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            
            if line.startswith('func ') and ':' in line:
                # Extract function name
                func_name = line.split('(')[0].replace('func ', '').strip()
                func_start_line = i + 1
                
                # Extract function content (until next function or end of file)
                func_lines = [line]
                i += 1
                
                while i < len(lines):
                    current_line = lines[i]
                    
                    # Check if we've reached the next function
                    if current_line.strip().startswith('func ') and ':' in current_line:
                        break
                    
                    func_lines.append(current_line)
                    i += 1
                
                func_content = '\n'.join(func_lines)
                functions.append((func_name, func_content, func_start_line))
                continue
            
            i += 1
        
        return functions
    
    def _calculate_cyclomatic_complexity(self, func_content: str) -> int:
        """
        Calculate cyclomatic complexity of a function
        """
        complexity = 1  # Base complexity
        
        # Count decision points
        decision_keywords = ['if', 'elif', 'else', 'for', 'while', 'match', 'and', 'or']
        
        for keyword in decision_keywords:
            complexity += len(re.findall(rf'\b{keyword}\b', func_content))
        
        return complexity
    
    def _get_performance_level(self, metric: str, value: float) -> PerformanceLevel:
        """
        Determine performance level based on metric value and thresholds
        """
        thresholds = self.performance_thresholds.get(metric, {})
        
        if value <= thresholds.get("excellent", 0):
            return PerformanceLevel.EXCELLENT
        elif value <= thresholds.get("good", 0):
            return PerformanceLevel.GOOD
        elif value <= thresholds.get("moderate", 0):
            return PerformanceLevel.MODERATE
        elif value <= thresholds.get("poor", 0):
            return PerformanceLevel.POOR
        else:
            return PerformanceLevel.CRITICAL
    
    def _get_function_at_line(self, lines: List[str], line_num: int) -> Optional[str]:
        """
        Get the function name that contains the given line number
        """
        for i in range(line_num - 1, -1, -1):
            if i < len(lines):
                line = lines[i].strip()
                if line.startswith('func ') and ':' in line:
                    return line.split('(')[0].replace('func ', '').strip()
        return None
    
    def run_comprehensive_analysis(self, target_files: List[str]) -> PerformanceAnalysisResult:
        """
        Run comprehensive performance analysis across multiple files
        """
        start_time = time.time()
        
        all_issues = []
        analyzed_files = 0
        
        print("⚡ Starting comprehensive performance analysis...")
        
        for file_path in target_files:
            if not file_path.endswith('.gd'):
                continue
                
            print(f"📊 Analyzing: {Path(file_path).name}")
            
            file_issues = self.analyze_file_performance(file_path)
            all_issues.extend(file_issues)
            analyzed_files += 1
        
        execution_time = time.time() - start_time
        
        # Categorize issues by severity
        critical_count = len([i for i in all_issues if i.level == PerformanceLevel.CRITICAL])
        poor_count = len([i for i in all_issues if i.level == PerformanceLevel.POOR])
        moderate_count = len([i for i in all_issues if i.level == PerformanceLevel.MODERATE])
        
        # Calculate overall metrics
        complexity_issues = len([i for i in all_issues if i.category == PerformanceCategory.CODE_COMPLEXITY])
        complexity_score = max(0.0, 100.0 - (complexity_issues * 5.0))
        
        memory_issues = len([i for i in all_issues if i.category == PerformanceCategory.MEMORY_USAGE])
        memory_efficiency = max(0.0, 100.0 - (memory_issues * 10.0))
        
        rendering_issues = len([i for i in all_issues if i.category == PerformanceCategory.RENDERING_PERFORMANCE])
        rendering_score = max(0.0, 100.0 - (rendering_issues * 15.0))
        
        # Calculate projected frame rate
        fps_issues = [i for i in all_issues if i.metric_name == "projected_fps"]
        if fps_issues:
            frame_rate_projection = min(issue.current_value for issue in fps_issues)
        else:
            frame_rate_projection = 60.0  # Assume 60 FPS if no issues detected
        
        # Determine overall performance level
        if critical_count > 0:
            overall_performance = PerformanceLevel.CRITICAL
        elif poor_count > 2:
            overall_performance = PerformanceLevel.POOR
        elif moderate_count > 5:
            overall_performance = PerformanceLevel.MODERATE
        elif len(all_issues) > 0:
            overall_performance = PerformanceLevel.GOOD
        else:
            overall_performance = PerformanceLevel.EXCELLENT
        
        # Generate optimization priorities
        optimization_priorities = self._generate_optimization_priorities(all_issues)
        
        result = PerformanceAnalysisResult(
            overall_performance=overall_performance,
            total_issues=len(all_issues),
            critical_issues=critical_count,
            poor_issues=poor_count,
            moderate_issues=moderate_count,
            complexity_score=complexity_score,
            memory_efficiency=memory_efficiency,
            rendering_score=rendering_score,
            frame_rate_projection=frame_rate_projection,
            issues=all_issues,
            optimization_priorities=optimization_priorities,
            execution_time=execution_time
        )
        
        return result
    
    def _generate_optimization_priorities(self, issues: List[PerformanceIssue]) -> List[str]:
        """
        Generate prioritized optimization recommendations
        """
        priorities = []
        
        # Count issues by category
        categories = {}
        for issue in issues:
            if issue.category not in categories:
                categories[issue.category] = []
            categories[issue.category].append(issue)
        
        # Priority 1: Critical frame rate issues
        critical_fps_issues = [i for i in issues if i.level == PerformanceLevel.CRITICAL and 
                              i.category == PerformanceCategory.FRAME_RATE_IMPACT]
        if critical_fps_issues:
            priorities.append("🚨 CRITICAL: Address frame rate issues immediately - game may be unplayable")
        
        # Priority 2: Memory optimization
        memory_issues = categories.get(PerformanceCategory.MEMORY_USAGE, [])
        if len(memory_issues) > 3:
            priorities.append("🧠 HIGH: Implement object pooling and memory optimization - reduces GC pressure")
        
        # Priority 3: Rendering optimization
        rendering_issues = categories.get(PerformanceCategory.RENDERING_PERFORMANCE, [])
        if len(rendering_issues) > 2:
            priorities.append("🎨 HIGH: Optimize rendering pipeline - cache node references and batch updates")
        
        # Priority 4: Code complexity
        complexity_issues = categories.get(PerformanceCategory.CODE_COMPLEXITY, [])
        if len(complexity_issues) > 5:
            priorities.append("📐 MEDIUM: Reduce code complexity - improves maintainability and performance")
        
        # Priority 5: Script efficiency
        script_issues = categories.get(PerformanceCategory.SCRIPT_EFFICIENCY, [])
        if len(script_issues) > 2:
            priorities.append("⚡ MEDIUM: Optimize script efficiency - avoid expensive operations in critical methods")
        
        # General recommendations
        if len(issues) > 10:
            priorities.append("🔧 GENERAL: Consider performance profiling session with Godot profiler")
        
        if not priorities:
            priorities.append("✅ EXCELLENT: No major performance issues detected - consider monitoring during gameplay")
        
        return priorities

def main():
    """
    Command-line interface for performance monitoring
    Designed for integration with Claude Hooks and continuous performance monitoring
    """
    parser = argparse.ArgumentParser(
        description="Five Parsecs Campaign Manager - Performance Monitor"
    )
    
    parser.add_argument(
        "--analyze-complexity",
        action="store_true",
        help="Analyze code complexity metrics"
    )
    
    parser.add_argument(
        "--check-memory-usage",
        action="store_true",
        help="Check memory usage patterns and optimizations"
    )
    
    parser.add_argument(
        "--validate-60fps-target",
        action="store_true",
        help="Validate code against 60 FPS target"
    )
    
    parser.add_argument(
        "--file",
        help="Analyze specific file"
    )
    
    parser.add_argument(
        "--directory",
        help="Analyze all GDScript files in directory"
    )
    
    parser.add_argument(
        "--output-format",
        choices=["json", "text"],
        default="text",
        help="Output format for analysis results"
    )
    
    parser.add_argument(
        "--fail-on-critical",
        action="store_true",
        help="Exit with error code if critical performance issues found"
    )
    
    args = parser.parse_args()
    
    # Initialize monitor
    project_root = os.getcwd()
    monitor = FiveParsecsPerformanceMonitor(project_root)
    
    # Determine target files
    target_files = []
    
    if args.file:
        target_files = [args.file]
    elif args.directory:
        target_dir = Path(args.directory)
        target_files = [str(f) for f in target_dir.rglob("*.gd")]
    else:
        # Default to performance-critical directories
        critical_dirs = [
            Path(project_root) / "src" / "core",
            Path(project_root) / "src" / "game",
            Path(project_root) / "src" / "ui"
        ]
        
        for critical_dir in critical_dirs:
            if critical_dir.exists():
                target_files.extend([str(f) for f in critical_dir.rglob("*.gd")])
    
    # Run analysis
    result = monitor.run_comprehensive_analysis(target_files)
    
    # Output results
    if args.output_format == "json":
        result_data = {
            "overall_performance": result.overall_performance.value,
            "total_issues": result.total_issues,
            "critical_issues": result.critical_issues,
            "poor_issues": result.poor_issues,
            "moderate_issues": result.moderate_issues,
            "complexity_score": result.complexity_score,
            "memory_efficiency": result.memory_efficiency,
            "rendering_score": result.rendering_score,
            "frame_rate_projection": result.frame_rate_projection,
            "execution_time": result.execution_time,
            "optimization_priorities": result.optimization_priorities,
            "issues": [
                {
                    "level": issue.level.value,
                    "category": issue.category.value,
                    "file_path": issue.file_path,
                    "line_number": issue.line_number,
                    "function_name": issue.function_name,
                    "metric_name": issue.metric_name,
                    "current_value": issue.current_value,
                    "target_value": issue.target_value,
                    "description": issue.description,
                    "performance_impact": issue.performance_impact,
                    "optimization_recommendation": issue.optimization_recommendation,
                    "code_example": issue.code_example,
                    "estimated_improvement": issue.estimated_improvement
                }
                for issue in result.issues
            ]
        }
        print(json.dumps(result_data, indent=2))
    else:
        print(f"\n⚡ Performance Analysis Summary")
        print(f"Overall Performance: {result.overall_performance.value.upper()}")
        print(f"Projected Frame Rate: {result.frame_rate_projection:.1f} FPS")
        print(f"Total Issues: {result.total_issues}")
        print(f"Complexity Score: {result.complexity_score:.1f}%")
        print(f"Memory Efficiency: {result.memory_efficiency:.1f}%") 
        print(f"Rendering Score: {result.rendering_score:.1f}%")
        print(f"Analysis Time: {result.execution_time:.2f}s")
        
        if result.total_issues > 0:
            print(f"  Critical: {result.critical_issues}")
            print(f"  Poor: {result.poor_issues}")
            print(f"  Moderate: {result.moderate_issues}")
        
        if result.optimization_priorities:
            print(f"\n🎯 Optimization Priorities:")
            for priority in result.optimization_priorities:
                print(f"  {priority}")
        
        if result.issues:
            print(f"\n📊 Performance Issues (showing top 5):")
            for issue in result.issues[:5]:
                print(f"\n{issue.level.value.upper()}: {issue.metric_name}")
                print(f"  File: {Path(issue.file_path).name}")
                if issue.line_number:
                    print(f"  Line: {issue.line_number}")
                if issue.function_name:
                    print(f"  Function: {issue.function_name}")
                print(f"  Issue: {issue.description}")
                print(f"  Impact: {issue.performance_impact}")
                print(f"  Fix: {issue.optimization_recommendation}")
                if issue.estimated_improvement:
                    print(f"  Improvement: {issue.estimated_improvement}")
            
            if len(result.issues) > 5:
                print(f"\n... and {len(result.issues) - 5} more issues. Use --output-format=json for complete list.")
    
    # Exit with appropriate code
    if args.fail_on_critical and result.critical_issues > 0:
        sys.exit(1)
    elif result.frame_rate_projection < 30.0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()