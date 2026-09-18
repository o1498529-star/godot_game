extends Node3D

const PLAYER_SCRIPT := preload("res://player.gd")
const HUD_SCENE := preload("res://hud.tscn")
const PLAYER_TEXTURE := preload("res://assets/player.svg")
const COIN_TEXTURE := preload("res://assets/coin.svg")
const OBSTACLE_TEXTURE := preload("res://assets/obstacle.svg")
const ROAD_TEXTURE := preload("res://assets/road_tile.svg")
const SKY_TEXTURE := preload("res://assets/sky_banner.svg")

const LANE_WIDTH := 2.8
const ROAD_WIDTH := 10.0
const SEGMENT_LENGTH := 20.0
const WAVE_LENGTH := 18.0

var player: CharacterBody3D
var hud: CanvasLayer
var score_label: Label
var coin_label: Label
var game_over_panel: Control
var segments: Array[StaticBody3D] = []
var obstacles: Array[StaticBody3D] = []
var coins: Array[Area3D] = []
var next_segment_z := -160.0
var next_wave_z := -234.0
var coins_collected := 0
var game_over := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_road()
	_build_player()
	_build_hud()
	for index in range(8):
		_create_road_segment(-float(index) * SEGMENT_LENGTH)
	for index in range(12):
		_spawn_wave(-18.0 - float(index) * WAVE_LENGTH)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	for segment in segments:
		if is_instance_valid(segment) and segment.position.z > player.position.z + 25.0:
			segment.position.z = next_segment_z
			next_segment_z -= SEGMENT_LENGTH

	for coin in coins:
		if is_instance_valid(coin):
			coin.rotate_y(delta * 4.0)
			if coin.position.z > player.position.z + 30.0:
				coin.queue_free()

	for obstacle in obstacles:
		if is_instance_valid(obstacle) and obstacle.position.z > player.position.z + 30.0:
			obstacle.queue_free()

	while player.position.z < next_wave_z + 150.0:
		_spawn_wave(next_wave_z)
		next_wave_z -= WAVE_LENGTH

	var distance_score := int(max(0.0, (5.0 - player.position.z) * 2.0))
	if is_instance_valid(score_label):
		score_label.text = str(distance_score + coins_collected * 50)
	if is_instance_valid(coin_label):
		coin_label.text = str(coins_collected)

	if player.position.y < -1.0 and not game_over:
		_end_run()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and game_over:
		get_tree().reload_current_scene()

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "JungleSun"
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#72c8d9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d0f1db")
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var sky := MeshInstance3D.new()
	sky.name = "JungleBackdrop"
	var sky_mesh := PlaneMesh.new()
	sky_mesh.size = Vector2(80.0, 30.0)
	sky.mesh = sky_mesh
	sky.rotation_degrees.x = -90.0
	sky.position = Vector3(0.0, 15.0, -120.0)
	var sky_material := _make_material(Color.WHITE)
	sky_material.albedo_texture = SKY_TEXTURE
	sky_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.material_override = sky_material
	add_child(sky)

func _build_road() -> void:
	for side in [-1.0, 1.0]:
		var rail := StaticBody3D.new()
		rail.name = "RoadEdgeBarrier"
		rail.position = Vector3(side * 5.45, 1.25, -70.0)
		rail.collision_layer = 2
		add_child(rail)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.7, 2.5, 180.0)
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _make_material(Color("#236047"))
		rail.add_child(mesh_instance)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.7, 2.5, 180.0)
		collider.shape = shape
		rail.add_child(collider)

func _create_road_segment(z_position: float) -> void:
	var segment := StaticBody3D.new()
	segment.name = "RoadSegment"
	segment.position = Vector3(0.0, -0.25, z_position)
	add_child(segment)
	segments.append(segment)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_WIDTH, 0.5, SEGMENT_LENGTH)
	mesh_instance.mesh = mesh
	var material := _make_material(Color.WHITE)
	material.albedo_texture = ROAD_TEXTURE
	mesh_instance.material_override = material
	segment.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(ROAD_WIDTH, 0.5, SEGMENT_LENGTH)
	collider.shape = shape
	segment.add_child(collider)
	var floor_material := PhysicsMaterial.new()
	floor_material.friction = 1.0
	floor_material.bounce = 0.0
	segment.physics_material_override = floor_material

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Runner"
	player.position = Vector3(0.0, 0.9, 5.0)
	player.collision_layer = 1
	player.collision_mask = 3
	player.floor_stop_on_slope = true
	player.safe_margin = 0.03
	player.set_script(PLAYER_SCRIPT)
	add_child(player)

	var visual := Node3D.new()
	visual.name = "RunnerModel3D"
	player.add_child(visual)

	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(1.15, 1.35, 0.75)
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, 1.35, 0.0)
	torso.material_override = _make_material(Color("#208dc5"))
	visual.add_child(torso)

	var scarf := MeshInstance3D.new()
	var scarf_mesh := BoxMesh.new()
	scarf_mesh.size = Vector3(1.22, 0.22, 0.82)
	scarf.mesh = scarf_mesh
	scarf.position = Vector3(0.0, 1.72, 0.0)
	scarf.material_override = _make_material(Color("#e7464f"))
	visual.add_child(scarf)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.46
	head_mesh.height = 0.92
	head.mesh = head_mesh
	head.position = Vector3(0.0, 2.35, 0.0)
	head.material_override = _make_material(Color("#f2b37f"))
	visual.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.48
	hair_mesh.height = 0.35
	hair.mesh = hair_mesh
	hair.position = Vector3(0.0, 2.68, 0.0)
	hair.material_override = _make_material(Color("#252b3c"))
	visual.add_child(hair)

	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.42, 1.05, 0.48)
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.3, 0.48, 0.0)
		leg.material_override = _make_material(Color("#343d56"))
		visual.add_child(leg)

		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.52, 0.28, 0.75)
		boot.mesh = boot_mesh
		boot.position = Vector3(side * 0.3, -0.12, -0.12)
		boot.material_override = _make_material(Color("#a45d3a"))
		visual.add_child(boot)

		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.18
		arm_mesh.height = 1.15
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.78, 1.35, 0.0)
		arm.rotation_degrees.z = side * -24.0
		arm.material_override = _make_material(Color("#2389c7"))
		visual.add_child(arm)

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 2.4
	shape.radius = 0.58
	collider.shape = shape
	collider.position.y = 1.2
	player.add_child(collider)

	var camera := Camera3D.new()
	camera.name = "RunnerCamera"
	camera.position = Vector3(0.0, 4.5, 9.0)
	camera.rotation_degrees = Vector3(-17.0, 0.0, 0.0)
	camera.current = true
	player.add_child(camera)

func _spawn_wave(z_position: float) -> void:
	var blocked_lane := rng.randi_range(0, 2)
	_create_obstacle(z_position, blocked_lane)
	if rng.randf() > 0.55:
		_create_obstacle(z_position - 1.2, rng.randi_range(0, 2))

	var coin_lane := (blocked_lane + rng.randi_range(1, 2)) % 3
	for index in range(4):
		_create_coin(z_position - 2.0 - float(index) * 2.0, coin_lane)

func _create_obstacle(z_position: float, lane: int) -> void:
	var obstacle := StaticBody3D.new()
	obstacle.name = "TempleObstacle"
	obstacle.position = Vector3(_lane_x(lane), 1.15, z_position)
	obstacle.collision_layer = 2
	obstacle.set_meta("runner_obstacle", true)
	add_child(obstacle)
	obstacles.append(obstacle)

	var body_mesh := MeshInstance3D.new()
	var body_shape := BoxMesh.new()
	body_shape.size = Vector3(2.8, 2.4, 1.8)
	body_mesh.mesh = body_shape
	body_mesh.material_override = _make_material(Color("#b8663e"))
	obstacle.add_child(body_mesh)

	var roof_mesh := MeshInstance3D.new()
	var roof_shape := BoxMesh.new()
	roof_shape.size = Vector3(3.3, 0.35, 2.2)
	roof_mesh.mesh = roof_shape
	roof_mesh.position.y = 1.35
	roof_mesh.rotation_degrees.z = 0.0
	roof_mesh.material_override = _make_material(Color("#d9894b"))
	obstacle.add_child(roof_mesh)

	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pillar_shape := BoxMesh.new()
		pillar_shape.size = Vector3(0.42, 2.55, 2.0)
		pillar.mesh = pillar_shape
		pillar.position = Vector3(side * 1.02, 0.0, 0.0)
		pillar.material_override = _make_material(Color("#f0a15a"))
		obstacle.add_child(pillar)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.2, 1.4)
	collider.shape = shape
	obstacle.add_child(collider)

func _create_coin(z_position: float, lane: int) -> void:
	var coin := Area3D.new()
	coin.name = "GoldCoin"
	coin.position = Vector3(_lane_x(lane), 1.5, z_position)
	coin.collision_layer = 4
	coin.collision_mask = 1
	add_child(coin)
	coins.append(coin)

	var coin_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.68
	cylinder.bottom_radius = 0.68
	cylinder.height = 0.22
	coin_mesh.mesh = cylinder
	coin_mesh.rotation_degrees.x = 90.0
	coin_mesh.material_override = _make_material(Color("#f7bd27"))
	coin.add_child(coin_mesh)

	var coin_face := MeshInstance3D.new()
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 0.5
	face_mesh.bottom_radius = 0.5
	face_mesh.height = 0.24
	coin_face.mesh = face_mesh
	coin_face.rotation_degrees.x = 90.0
	coin_face.position.z = -0.03
	coin_face.material_override = _make_material(Color("#ffe889"))
	coin.add_child(coin_face)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	collider.shape = shape
	coin.add_child(collider)
	coin.body_entered.connect(_on_coin_body_entered.bind(coin))

func on_runner_hit() -> void:
	if not game_over:
		_end_run()

func _on_coin_body_entered(body: Node3D, coin: Area3D) -> void:
	if body == player and is_instance_valid(coin):
		coins_collected += 1
		coin.queue_free()

func _end_run() -> void:
	game_over = true
	player.set_physics_process(false)
	if is_instance_valid(game_over_panel):
		game_over_panel.visible = true

func _build_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	score_label = hud.get_node("TopPanel/ScoreValue")
	coin_label = hud.get_node("TopPanel/CoinValue")
	game_over_panel = hud.get_node("GameOverPanel")
	coin_label.text = "0"
	game_over_panel.visible = false

func _lane_x(lane: int) -> float:
	return float(lane - 1) * LANE_WIDTH

func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material
