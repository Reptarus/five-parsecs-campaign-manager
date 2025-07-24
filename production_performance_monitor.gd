@tool
extends SceneTree

## Production Performance Monitor
## Measures baseline performance metrics for production readiness

class_name ProductionPerformanceMonitor

var metrics: Dictionary = {}
var start_time: float
var memory_samples: Array = []

func _initialize():
	print("=== Five Parsecs Production Performance Monitor ===")
	start_time = Time.get_unix_time_from_system()
	
	_measure_scene_loading_performance()
	_measure_memory_usage()
	_measure_monolith_performance()
	_generate_performance_report()
	
	quit()

func _measure_scene_loading_performance():
	print("📊 Measuring scene loading performance...")
	
	# Test CampaignTurnController loading
	var load_start = Time.get_unix_time_from_system()
	var controller_scene = load("res://src/ui/screens/campaign/CampaignTurnController.tscn")
	var controller_load_time = Time.get_unix_time_from_system() - load_start
	
	if controller_scene:
		# Test instantiation time
		var inst_start = Time.get_unix_time_from_system()
		var instance = controller_scene.instantiate()
		var instantiate_time = Time.get_unix_time_from_system() - inst_start
		
		metrics["campaign_controller"] = {
			"load_time_ms": controller_load_time * 1000,
			"instantiate_time_ms": instantiate_time * 1000,
			"total_time_ms": (controller_load_time + instantiate_time) * 1000
		}
		
		instance.queue_free()
		print("  - CampaignTurnController: %.1f ms load, %.1f ms instantiate" % [controller_load_time * 1000, instantiate_time * 1000])
	
	# Test WorldPhaseUI (monolith) loading
	load_start = Time.get_unix_time_from_system()
	var world_scene = load("res://src/ui/screens/world/WorldPhaseUI.tscn")
	var world_load_time = Time.get_unix_time_from_system() - load_start
	
	if world_scene:
		var world_inst_start = Time.get_unix_time_from_system()
		var world_instance = world_scene.instantiate()
		var world_instantiate_time = Time.get_unix_time_from_system() - world_inst_start
		
		metrics["world_phase_ui"] = {
			"load_time_ms": world_load_time * 1000,
			"instantiate_time_ms": world_instantiate_time * 1000,
			"total_time_ms": (world_load_time + world_instantiate_time) * 1000,
			"is_monolith": true,
			"line_count": 3354
		}
		
		world_instance.queue_free()
		print("  - WorldPhaseUI (monolith): %.1f ms load, %.1f ms instantiate" % [world_load_time * 1000, world_instantiate_time * 1000])

func _measure_memory_usage():
	print("💾 Measuring memory usage...")
	
	# Initial memory snapshot - using available memory functions
	var initial_memory = OS.get_static_memory_peak_usage() 
	memory_samples.append({
		"point": "initial",
		"usage": initial_memory
	})
	
	# Load several heavy scenes and measure memory impact
	var scenes_to_test = [
		"res://src/ui/screens/campaign/CampaignTurnController.tscn",
		"res://src/ui/screens/world/WorldPhaseUI.tscn",
		"res://src/ui/screens/postbattle/PostBattleSequence.tscn"
	]
	
	var instances = []
	for scene_path in scenes_to_test:
		var scene = load(scene_path)
		if scene:
			var instance = scene.instantiate()
			instances.append(instance)
			
			var current_memory = OS.get_static_memory_peak_usage()
			memory_samples.append({
				"point": scene_path.get_file().get_basename(),
				"usage": current_memory
			})
	
	# Calculate memory usage
	if memory_samples.size() > 1:
		var base_usage = memory_samples[0].usage
		var peak_usage = memory_samples[-1].usage
		var memory_increase = peak_usage - base_usage
		
		metrics["memory_usage"] = {
			"base_memory_mb": base_usage / 1024.0 / 1024.0,
			"peak_memory_mb": peak_usage / 1024.0 / 1024.0,
			"memory_increase_mb": memory_increase / 1024.0 / 1024.0
		}
		
		print("  - Base memory: %.1f MB" % (base_usage / 1024.0 / 1024.0))
		print("  - Peak memory: %.1f MB" % (peak_usage / 1024.0 / 1024.0))
		print("  - Memory increase: %.1f MB" % (memory_increase / 1024.0 / 1024.0))
	
	# Cleanup
	for instance in instances:
		if instance:
			instance.queue_free()

func _measure_monolith_performance():
	print("🔍 Analyzing monolith performance impact...")
	
	# Test WorldPhaseUI script loading time
	var script_load_start = Time.get_unix_time_from_system()
	var world_script = load("res://src/ui/screens/world/WorldPhaseUI.gd")
	var script_load_time = Time.get_unix_time_from_system() - script_load_start
	
	if world_script:
		metrics["monolith_analysis"] = {
			"script_load_time_ms": script_load_time * 1000,
			"estimated_line_count": 3354,
			"performance_impact": "HIGH" if script_load_time > 0.1 else "MEDIUM" if script_load_time > 0.05 else "LOW"
		}
		
		print("  - WorldPhaseUI.gd load time: %.1f ms (3,354 lines)" % (script_load_time * 1000))
		print("  - Performance impact: %s" % metrics["monolith_analysis"]["performance_impact"])

func _generate_performance_report():
	print("\n" + "============================================================")
	print("📈 PRODUCTION PERFORMANCE REPORT")
	print("============================================================")
	
	var total_time = Time.get_unix_time_from_system() - start_time
	print("Total analysis time: %.2f seconds" % total_time)
	
	print("\n🎯 PERFORMANCE TARGETS vs ACTUAL:")
	
	# Scene Loading Performance
	if "campaign_controller" in metrics:
		var controller_total = metrics["campaign_controller"]["total_time_ms"]
		var target_met = controller_total < 500  # 500ms target
		print("  Campaign Controller: %.1f ms (Target: <500ms) %s" % [controller_total, "✅" if target_met else "❌"])
	
	if "world_phase_ui" in metrics:
		var world_total = metrics["world_phase_ui"]["total_time_ms"]
		var target_met = world_total < 200  # 200ms target (likely to fail due to monolith)
		print("  WorldPhase UI: %.1f ms (Target: <200ms) %s [MONOLITH]" % [world_total, "✅" if target_met else "❌"])
	
	# Memory Usage
	if "memory_usage" in metrics:
		var peak_memory = metrics["memory_usage"]["peak_memory_mb"]
		var target_met = peak_memory < 100  # 100MB target
		print("  Peak Memory: %.1f MB (Target: <100MB) %s" % [peak_memory, "✅" if target_met else "❌"])
	
	print("\n⚠️  CRITICAL PRODUCTION ISSUES:")
	print("  - WorldPhaseUI.gd: 3,354 lines (MONOLITH CRISIS)")
	print("  - Memory leaks detected in previous health check")
	print("  - Multiple script compilation errors")
	
	print("\n🚀 RECOMMENDED IMMEDIATE ACTIONS:")
	print("  1. Extract WorldPhaseUI components (Priority: HIGH)")
	print("  2. Fix script compilation errors")
	print("  3. Implement memory leak prevention")
	print("  4. Add performance monitoring to production build")
	
	print("============================================================")