extends Node3D

const Art = preload("res://scripts/art.gd")
const Runner = preload("res://scripts/runner.gd")
const Sound = preload("res://scripts/sound.gd")
const UI = preload("res://scenes/runner_ui.tscn")
const SEGMENT := 28.0
const ROW_GAP := 22.0
var runner: CharacterBody3D
var camera: Camera3D
var sound: Node
var ui: CanvasLayer
var scenery := Node3D.new()
var hazards := Node3D.new()
var loot := Node3D.new()
var effects := Node3D.new()
var rng := RandomNumberGenerator.new()
var state := "menu"
var previous_state := "running"
var next_segment := -224.0
var next_row := -30.0
var row_number := 0
var distance := 0.0
var gold := 0
var record := 0
var bank := 0
var magnet := 0.0
var shield := 0.0
var countdown := 0.0
var run_time := 0.0
var touch_start := Vector2.ZERO
var rival: Node3D
var aura: MeshInstance3D
var save_path := "user://sunny_paws.cfg"

func _ready() -> void:
	rng.seed = 72319
	if "--self-test" in OS.get_cmdline_user_args(): save_path = "user://sunny_paws_test.cfg"
	_load_progress()
	add_child(scenery)
	add_child(hazards)
	add_child(loot)
	add_child(effects)
	_environment()
	runner = Runner.new()
	runner.name = "Runner"
	add_child(runner)
	runner.reset_runner()
	runner.crashed.connect(_crash)
	rival = Art.cat()
	rival.name = "GoldBandit"
	rival.scale = Vector3.ONE * 0.85
	add_child(rival)
	_recolor_rival(rival)
	Art.box(rival, Vector3(0, 1.12, 0.52), Vector3(0.7, 0.85, 0.4), "775c4d")
	Art.box(rival, Vector3(0, 1.4, 0.75), Vector3(0.3, 0.14, 0.12), "ffc83e")
	aura = Art.ball(runner, Vector3(0, 1.2, 0), Vector3(1.6, 2.9, 1.4), "49dbdf")
	var aura_material := StandardMaterial3D.new()
	aura_material.albedo_color = Color(0.22, 0.95, 1.0, 0.14)
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura.material_override = aura_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.hide()
	camera = Camera3D.new()
	camera.fov = 63
	camera.far = 260
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 5.8, 14)
	camera.look_at(Vector3(0, 1.4, -7))
	sound = Sound.new()
	add_child(sound)
	runner.jumped.connect(func(): sound.play("jump"))
	ui = UI.instantiate()
	add_child(ui)
	ui.get_node("Menu/Play").pressed.connect(start_run)
	ui.get_node("Menu/Quit").pressed.connect(func(): get_tree().quit())
	ui.get_node("HUD/Pause").pressed.connect(toggle_pause)
	ui.get_node("Overlay/Primary").pressed.connect(_primary)
	ui.get_node("Overlay/Home").pressed.connect(go_home)
	ui.get_node("HUD/Sound").pressed.connect(toggle_sound)
	_reset_world()
	show_menu()

func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0d1")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("50b4e1")
	sky_material.sky_horizon_color = Color("c3eef3")
	sky_material.ground_bottom_color = Color("76b69b")
	sky_material.ground_horizon_color = Color("c3eef3")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6f0ff")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

func _reset_world() -> void:
	for parent in [scenery, hazards, loot, effects]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	next_segment = -224
	next_row = -30
	row_number = 0
	for i in range(8): _segment(-float(i) * SEGMENT)
	while next_row > -175:
		_spawn_row(next_row)
		next_row -= ROW_GAP

func _segment(z: float) -> void:
	var chunk := Node3D.new()
	chunk.position.z = z
	scenery.add_child(chunk)
	var road := StaticBody3D.new()
	road.collision_layer = 1
	chunk.add_child(road)
	Art.box(road, Vector3(0, -0.3, 0), Vector3(10.2, 0.6, SEGMENT + 0.04), "596b80")
	Art.collision(road, Vector3(0, -0.3, 0), Vector3(10.2, 0.6, SEGMENT + 0.04))
	for x in [-1.4, 1.4]:
		for n in range(7):
			Art.box(chunk, Vector3(x, 0.008, -12 + n * 4), Vector3(0.1, 0.02, 1.8), "ece6c9")
	for side in [-1.0, 1.0]:
		Art.box(chunk, Vector3(side * 5.5, 0.12, 0), Vector3(1.8, 0.24, SEGMENT), "e9d9b2")
		Art.box(chunk, Vector3(side * 4.65, 0.18, 0), Vector3(0.18, 0.36, SEGMENT), "fff0ce")
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		chunk.add_child(wall)
		Art.collision(wall, Vector3(side * 4.75, 2, 0), Vector3(0.25, 4, SEGMENT + 0.05))
		for offset in [-7.0, 7.0]:
			_building(chunk, Vector3(side * 10, 0, offset), side)
		Art.tree(chunk, Vector3(side * 5.7, 0, 1))
		Art.cylinder(chunk, Vector3(side * 5.4, 2.35, -10), 0.075, 4.7, "346079")
		Art.box(chunk, Vector3(side * 5.05, 4.65, -10), Vector3(0.9, 0.12, 0.22), "346079")
		Art.ball(chunk, Vector3(side * 4.75, 4.52, -10), Vector3(0.42, 0.22, 0.4), "fff0af")
		Art.box(chunk, Vector3(side * 5.65, 0.65, 9), Vector3(0.8, 1.3, 0.8), "26978e")

func _building(parent: Node3D, at: Vector3, side: float) -> void:
	var palette := ["efb267", "e88882", "79c9ca", "b6abd4", "e6cc83"]
	var color: String = palette[rng.randi_range(0, palette.size() - 1)]
	var height := rng.randf_range(5.5, 10.0)
	Art.box(parent, at + Vector3(0, height / 2, 0), Vector3(6, height, 10.7), color)
	Art.box(parent, at + Vector3(0, height, 0), Vector3(6.25, 0.28, 10.9), "fff0ce")
	for level in range(1, 4):
		for z in [-3.1, 0.0, 3.1]:
			var p := at + Vector3(-side * 3.015, level * 2.0, z)
			Art.box(parent, p, Vector3(0.1, 1.15, 1.55), "f8eed7")
			Art.box(parent, p + Vector3(-side * 0.07, 0, 0), Vector3(0.05, 0.95, 1.3), "3d819b")
	Art.box(parent, at + Vector3(-side * 3.2, 1.5, 0), Vector3(0.6, 0.22, 4.5), "e65b64")
	for i in range(5):
		Art.box(parent, at + Vector3(-side * 3.35, 1.5, -1.8 + i * 0.9), Vector3(0.9, 0.15, 0.38), "fff0ce")
	Art.box(parent, at + Vector3(-side * 3.03, 0.65, 0), Vector3(0.1, 1.3, 1.25), "234e65")

func _spawn_row(z: float) -> void:
	var safe_lane := rng.randi_range(0, 2)
	if row_number < 3: safe_lane = [1, 2, 0][row_number]
	for lane in range(3):
		if lane == safe_lane: continue
		if row_number > 2 and rng.randf() < 0.2: continue
		var kind := rng.randi_range(0, 3)
		if row_number == 0: kind = 0
		_spawn_obstacle(kind, lane, z)
	for i in range(6):
		_spawn_pickup("coin", Vector3((safe_lane - 1) * 2.8, 1.05, z + 7 - i * 2.4))
	if row_number % 5 == 3:
		_spawn_pickup("magnet" if row_number % 10 == 3 else "shield", Vector3((safe_lane - 1) * 2.8, 1.1, z + 10))
	row_number += 1

func _spawn_obstacle(kind: int, lane: int, z: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = Vector3((lane - 1) * 2.8, 0, z)
	body.collision_layer = 2
	body.collision_mask = 1
	body.add_to_group("hazards")
	body.set_meta("kind", kind)
	hazards.add_child(body)
	match kind:
		0, 1:
			Art.vehicle(body, kind == 1, "efb736" if kind == 1 else "ed6c69")
		2:
			Art.box(body, Vector3(0, 0.55, 0), Vector3(2.05, 1.1, 0.48), "f08e45")
			Art.collision(body, Vector3(0, 0.55, 0), Vector3(2.05, 1.1, 0.48))
			for x in [-0.7, 0.0, 0.7]:
				var stripe := Art.box(body, Vector3(x, 0.55, 0.25), Vector3(0.16, 0.98, 0.025), "fff3d6")
				stripe.rotation.z = -0.32
		3:
			Art.box(body, Vector3(0, 1.92, 0), Vector3(2.32, 1.5, 0.6), "288bb0")
			Art.collision(body, Vector3(0, 1.92, 0), Vector3(2.32, 1.5, 0.6))
			for side in [-1.0, 1.0]:
				Art.box(body, Vector3(side * 1.06, 0.6, 0), Vector3(0.13, 1.2, 0.35), "fff0ce")
				Art.collision(body, Vector3(side * 1.06, 0.6, 0), Vector3(0.13, 1.2, 0.35))
			var arrow := Art.box(body, Vector3(0, 1.95, 0.32), Vector3(0.12, 0.62, 0.03), "fff0ce")
			for side in [-1.0, 1.0]:
				var tip := Art.box(body, Vector3(side * 0.16, 1.72, 0.32), Vector3(0.12, 0.4, 0.03), "fff0ce")
				tip.rotation.z = side * -0.8
	return body

func _spawn_pickup(kind: String, at: Vector3) -> void:
	var item := Node3D.new()
	item.position = at
	item.set_meta("kind", kind)
	item.set_meta("base_y", at.y)
	loot.add_child(item)
	if kind == "coin":
		var coin := Art.cylinder(item, Vector3.ZERO, 0.32, 0.12, "ffc83e")
		coin.rotation.x = PI / 2
		var face := Art.cylinder(item, Vector3.ZERO, 0.24, 0.14, "ffe98a")
		face.rotation.x = PI / 2
	else:
		var color := "dc667f" if kind == "magnet" else "49dbdf"
		Art.ball(item, Vector3.ZERO, Vector3(0.9, 0.9, 0.9), color)
		if kind == "magnet":
			Art.box(item, Vector3(0, -0.13, 0.4), Vector3(0.52, 0.15, 0.15), "fff3dc")
			for x in [-0.19, 0.19]: Art.box(item, Vector3(x, 0.06, 0.4), Vector3(0.14, 0.4, 0.15), "fff3dc")
		else:
			Art.ball(item, Vector3(0, 0, 0.4), Vector3(0.48, 0.6, 0.13), "fff3dc")

func start_run() -> void:
	_reset_world()
	runner.reset_runner()
	runner.active = false
	gold = 0
	distance = 0
	magnet = 0
	shield = 0
	run_time = 0
	countdown = 2.1
	state = "countdown"
	ui.get_node("Menu").hide()
	ui.get_node("Overlay").hide()
	ui.get_node("HUD").show()
	sound.play("start")

func show_menu() -> void:
	state = "menu"
	runner.active = false
	runner.reset_runner()
	runner.model.rotation.y = PI - 0.35
	ui.get_node("Menu").show()
	ui.get_node("HUD").hide()
	ui.get_node("Overlay").hide()
	ui.get_node("Menu/Record").text = "BEST  %s m     •     BANK  %s" % [record, bank]
	ui.get_node("Countdown").text = ""

func go_home() -> void:
	_reset_world()
	show_menu()

func _primary() -> void:
	if state == "paused": toggle_pause()
	else: start_run()

func toggle_pause() -> void:
	if state == "running" or state == "countdown":
		previous_state = state
		state = "paused"
		runner.active = false
		_overlay("TAKE A BREATHER", "Your run is waiting for you.", "RESUME")
	elif state == "paused":
		state = previous_state
		runner.active = state == "running"
		ui.get_node("Overlay").hide()

func toggle_sound() -> void:
	sound.enabled = not sound.enabled
	ui.get_node("HUD/Sound").text = "SOUND ON" if sound.enabled else "SOUND OFF"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "running": toggle_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_A, KEY_LEFT: runner.command("left")
			KEY_D, KEY_RIGHT: runner.command("right")
			KEY_W, KEY_UP, KEY_SPACE:
				if state == "menu": start_run()
				else: runner.command("jump")
			KEY_S, KEY_DOWN: runner.command("slide")
			KEY_ESCAPE, KEY_P: toggle_pause()
			KEY_R:
				if state == "over": start_run()
			KEY_ENTER:
				if state in ["menu", "over"]: start_run()
			KEY_M: toggle_sound()
	if event is InputEventScreenTouch:
		if event.pressed: touch_start = event.position
		else:
			var swipe: Vector2 = event.position - touch_start
			if swipe.length() > 35:
				if absf(swipe.x) > absf(swipe.y): runner.command("right" if swipe.x > 0 else "left")
				else: runner.command("slide" if swipe.y > 0 else "jump")

func _process(delta: float) -> void:
	if state == "menu":
		runner.model.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.05
	if state == "countdown":
		countdown -= delta
		ui.get_node("Countdown").text = str(int(ceil(countdown))) if countdown > 0.15 else "GO!"
		if countdown <= 0:
			state = "running"
			runner.active = true
			ui.get_node("Countdown").text = ""
	if state == "running":
		run_time += delta
		distance = maxf(distance, 4 - runner.position.z)
		runner.speed = minf(22, 12 + distance / 150)
		magnet = maxf(0, magnet - delta)
		shield = maxf(0, shield - delta)
		_stream_world()
		_update_loot(delta)
		_update_effects(delta)
	_update_camera(delta)
	aura.visible = shield > 0 and state == "running"
	rival.visible = state != "menu"
	if state == "running" or state == "countdown":
		rival.position = Vector3(sin(run_time * 0.7) * 2.5, 0, runner.position.z - 19)
		var stride := sin(run_time * 17) * 0.7
		rival.get_node("LeftLeg").rotation.x = stride
		rival.get_node("RightLeg").rotation.x = -stride
		rival.get_node("LeftArm").rotation.x = -stride
		rival.get_node("RightArm").rotation.x = stride
	ui.get_node("HUD/Distance").text = "%04d m" % int(distance)
	ui.get_node("HUD/Gold").text = "%03d" % gold
	ui.get_node("HUD/Power").text = ("MAGNET %ds   " % int(ceil(magnet)) if magnet > 0 else "") + ("SHIELD %ds" % int(ceil(shield)) if shield > 0 else "")
	ui.get_node("HUD/Mission").text = "COLLECT 25 GOLD   %d / 25" % mini(gold, 25) if gold < 25 else "GOLD HUNTER  •  COMPLETE!"

func _update_camera(delta: float) -> void:
	var menu := state == "menu"
	var target := Vector3(runner.position.x * 0.2, 4.7, runner.position.z + 8.0)
	if menu: target = Vector3(-1.8, 3.4, 11)
	camera.position = camera.position.lerp(target, 1 - exp(-7 * delta))
	var look := Vector3(runner.position.x * 0.1, 1.1, runner.position.z - 8)
	if menu: look = Vector3(-1.0, 1.2, 0)
	camera.look_at(look)
	camera.fov = lerpf(camera.fov, 60 + (runner.speed - 12) * 0.45 if not menu else 52.0, delta * 3)

func _recolor_rival(node: Node) -> void:
	if node is MeshInstance3D:
		var material := node.material_override as StandardMaterial3D
		if material != null:
			var tint := material.albedo_color
			if tint.r > tint.g * 1.2 and tint.g > tint.b * 1.15:
				node.material_override = Art.mat("6e7b8a")
	for child in node.get_children(): _recolor_rival(child)

func _stream_world() -> void:
	for chunk in scenery.get_children():
		if chunk.position.z > runner.position.z + 35:
			chunk.position.z = next_segment
			next_segment -= SEGMENT
	while next_row > runner.position.z - 175:
		_spawn_row(next_row)
		next_row -= ROW_GAP
	for body in hazards.get_children():
		if body.position.z > runner.position.z + 18: body.queue_free()

func _update_loot(delta: float) -> void:
	for item in loot.get_children():
		if item.is_queued_for_deletion(): continue
		var kind: String = item.get_meta("kind")
		item.rotation.y += delta * 2.5
		var target := runner.position + Vector3(0, 0.5 if runner.sliding > 0 else 1.1, 0)
		if magnet > 0 and kind == "coin" and item.position.distance_to(target) < 9:
			item.position = item.position.move_toward(target, 24 * delta)
		if absf(item.position.z - runner.position.z) < 0.85 and absf(item.position.x - runner.position.x) < 0.8 and absf(item.position.y - target.y) < 1.05:
			_collect(item, kind)
		elif item.position.z > runner.position.z + 10: item.queue_free()

func _collect(item: Node3D, kind: String) -> void:
	item.queue_free()
	if kind == "coin":
		gold += 1
		sound.play("coin")
	else:
		if kind == "magnet": magnet = 10
		else: shield = 15
		sound.play("power")
	_burst(item.position, "ffd35e" if kind == "coin" else "56ddd9")

func _burst(at: Vector3, color: String) -> void:
	for i in range(5):
		var spark := Art.ball(effects, at, Vector3.ONE * 0.12, color)
		spark.set_meta("life", 0.4)
		spark.set_meta("velocity", Vector3(rng.randf_range(-2, 2), rng.randf_range(1, 4), rng.randf_range(-2, 2)))

func _update_effects(delta: float) -> void:
	for spark in effects.get_children():
		var life: float = spark.get_meta("life") - delta
		spark.set_meta("life", life)
		spark.position += spark.get_meta("velocity") * delta
		if life <= 0: spark.queue_free()

func _crash(body: Node) -> void:
	if state != "running": return
	if shield > 0 and body != null:
		shield = 0
		body.collision_layer = 0
		_burst(body.position + Vector3(0, 1, 0), "63eeed")
		body.queue_free()
		sound.play("power")
		return
	state = "over"
	runner.active = false
	runner.velocity = Vector3.ZERO
	runner.model.rotation.z = -0.3
	record = maxi(record, int(distance))
	bank += gold
	_save_progress()
	sound.play("crash")
	_overlay("NICE RUN!", "%d m   •   %d GOLD\nBEST  %d m" % [int(distance), gold, record], "RUN AGAIN")

func _overlay(title: String, subtitle: String, action: String) -> void:
	ui.get_node("Overlay").show()
	ui.get_node("Overlay/Title").text = title
	ui.get_node("Overlay/Stats").text = subtitle
	ui.get_node("Overlay/Primary/Text").text = action

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		record = int(config.get_value("run", "record", 0))
		bank = int(config.get_value("run", "bank", 0))

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("run", "record", record)
	config.set_value("run", "bank", bank)
	var error := config.save(save_path)
	if error != OK: push_warning("Could not save progress: %s" % error)
