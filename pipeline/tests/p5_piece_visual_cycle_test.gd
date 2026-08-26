extends Node

const SCENE_PATH := "res://scenes/p2_content_graybox.tscn"
const PREDICTION_QUEUE: Script = preload("res://src/ui/battle/trajectory_prediction_queue.gd")

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		failures += 1
		print("[FAIL] %s" % label)


func verify_slot(scene: Node, expected_numeric_id: int, expected_path: String) -> void:
	var pieces: Node2D = scene.get_node("Battlefield/Pieces") as Node2D
	var holder: Node2D = pieces.get_node_or_null("Body3") as Node2D
	var sprite: Sprite2D = holder.get_node_or_null("Sprite") as Sprite2D if holder != null else null
	check("P5-VISUAL-%d-SIX-VIEWS" % expected_numeric_id, pieces.get_child_count() == 6)
	check("P5-VISUAL-%d-BODY3-MAPPED" % expected_numeric_id, holder != null and int(holder.get_meta("piece_numeric_id", 0)) == expected_numeric_id)
	check("P5-VISUAL-%d-TEXTURE" % expected_numeric_id, sprite != null and sprite.texture != null and sprite.texture.resource_path == expected_path)


func _ready() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	check("P5-VISUAL-SCENE-LOAD", packed != null)
	if packed == null:
		get_tree().quit(1)
		return
	var scene: Node = packed.instantiate()
	check("P5-VISUAL-SCENE-INSTANTIATE", scene != null)
	if scene == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	check("P5-VISUAL-INITIAL-SIX-VIEWS", scene.get_node("Battlefield/Pieces").get_child_count() == 6)
	for expected: Dictionary in [
		{"numeric_id": 4, "path": "res://assets/art/sprites/p5/bouncy_ball.png"},
		{"numeric_id": 5, "path": "res://assets/art/sprites/p5/caveman.png"},
		{"numeric_id": 6, "path": "res://assets/art/sprites/p5/ai_core.png"},
	]:
		scene.call("_cycle_player_slot", 2)
		verify_slot(scene, int(expected["numeric_id"]), String(expected["path"]))
	var trajectory: Line2D = scene.get_node("Battlefield/AimLayer/TrajectoryLine") as Line2D
	trajectory.points = PackedVector2Array([Vector2(10.0, 10.0), Vector2(20.0, 20.0)])
	var command_status := SimStatus.new()
	var command: LaunchCommand = LaunchCommand.create(0, 128, command_status)
	scene.call("_on_prediction_requested", command)
	check("P5-AI-TRAJECTORY-PRESENTATION-MODE", command_status.is_ok() and is_equal_approx(trajectory.width, 6.0) and trajectory.default_color.is_equal_approx(Color(0.25, 0.95, 1.0, 0.95)) and trajectory.antialiased)
	check("P5-AI-TRAJECTORY-RETAINED-WHILE-PENDING", trajectory.points == PackedVector2Array([Vector2(10.0, 10.0), Vector2(20.0, 20.0)]))
	var queue: TrajectoryPredictionQueue = PREDICTION_QUEUE.new()
	queue.submit(command, 1_000)
	check("P5-AI-TRAJECTORY-DEFAULT-DEBOUNCE-16MS", not queue.can_start(16_999, false, true) and queue.can_start(17_000, false, true))
	scene.free()
	if failures == 0:
		print("P5_PIECE_VISUAL_CYCLE_RESULT: PASS")
		get_tree().quit(0)
	else:
		print("P5_PIECE_VISUAL_CYCLE_RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)
