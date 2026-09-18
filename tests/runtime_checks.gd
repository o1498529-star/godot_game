extends SceneTree

var world: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func ticks(count: int) -> void:
	for i in range(count): await physics_frame

func empty_obstacles() -> void:
	for node in world.hazards.get_children():
		world.hazards.remove_child(node)
		node.free()

func prepare() -> void:
	empty_obstacles()
	world.state = "running"
	world.runner.reset_runner()
	world.runner.speed = 12
	world.runner.active = true
	world.shield = 0

func run_checks() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await ticks(3)
	world.save_path = "user://sunny_paws_test.cfg"
	world.set_process(false)
	check(world.state == "menu", "starts in menu")
	prepare()
	await ticks(5)
	var press := InputEventKey.new()
	press.pressed = true
	press.physical_keycode = KEY_D
	world._unhandled_input(press)
	press.echo = true
	for i in range(6): world._unhandled_input(press)
	await ticks(40)
	check(world.runner.lane == 2 and absf(world.runner.position.x - 2.8) < 0.01, "one D press moves exactly one lane; repeat ignored")
	await ticks(70)
	check(absf(world.runner.position.x - 2.8) < 0.01, "no sideways drift")
	for i in range(10): world.runner.command("right")
	await ticks(10)
	check(world.runner.lane == 2 and world.runner.position.x <= 2.801, "lane bounds prevent leaving road")
	world.runner.command("left")
	world.runner.command("left")
	await ticks(35)
	check(absf(world.runner.position.x + 2.8) < 0.01, "rapid deliberate double tap reaches left lane")
	prepare()
	await ticks(8)
	world.runner.command("jump")
	await ticks(20)
	check(world.runner.position.y > 1.2, "jump gains real height")
	await ticks(40)
	check(world.runner.position.y < 0.1 and world.runner.is_on_floor(), "jump lands on road")
	prepare()
	await ticks(4)
	world._spawn_obstacle(3, 1, -2)
	world.runner.command("slide")
	await ticks(44)
	check(world.state == "running" and world.runner.position.z < -3.5, "slide passes beneath overhead sign")
	prepare()
	world._spawn_obstacle(0, 1, -3)
	await ticks(45)
	check(world.state == "over", "vehicle collision ends run")
	check(world.runner.position.z > -1.7, "vehicle physically blocks character")
	prepare()
	world._spawn_obstacle(2, 1, -2)
	await ticks(5)
	world.runner.command("jump")
	await ticks(45)
	check(world.state == "running" and world.runner.position.z < -4, "jump clears low barrier")
	prepare()
	world.shield = 15
	world._spawn_obstacle(0, 1, -3)
	await ticks(45)
	check(world.state == "running" and world.shield == 0, "shield absorbs exactly one impact")
	world.toggle_pause()
	var paused_z: float = world.runner.position.z
	await ticks(20)
	check(world.runner.position.z == paused_z, "pause stops simulation")
	world.toggle_pause()
	check(world.runner.active, "resume restores control")
	world.runner.active = false
	world.gold = 0
	world._spawn_pickup("coin", world.runner.position + Vector3(0, 1.1, 0))
	world._update_loot(0.016)
	check(world.gold >= 1, "coin collection increments gold")
	await ticks(1)
	world._reset_world()
	prepare()
	for i in range(1500):
		await physics_frame
		world._stream_world()
		empty_obstacles()
	check(world.runner.position.z < -250 and world.runner.position.y > -0.1, "continuous floor across recycled segments over 250m")
	check(world.scenery.get_child_count() == 8, "scenery remains bounded at eight chunks")
	world.runner.active = false
	world.free()
	print("CHECKS COMPLETE; failures=", failures)
	quit(1 if failures > 0 else 0)
