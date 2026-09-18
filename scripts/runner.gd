extends CharacterBody3D

signal crashed(obstacle: Node)
signal jumped
const Art = preload("res://scripts/art.gd")
const LANE := 2.8
var lane := 1
var speed := 12.0
var active := false
var sliding := 0.0
var animation_time := 0.0
var jump_buffer := 0.0
var model: Node3D
var collider: CollisionShape3D
var standing_shape := BoxShape3D.new()
var slide_shape := BoxShape3D.new()
var invulnerable := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 3
	floor_snap_length = 0.25
	safe_margin = 0.005
	standing_shape.size = Vector3(0.72, 2.25, 0.68)
	slide_shape.size = Vector3(0.72, 0.7, 0.68)
	collider = CollisionShape3D.new()
	collider.shape = standing_shape
	collider.position.y = 1.125
	add_child(collider)
	model = Art.cat()
	add_child(model)

func command(action: String) -> void:
	if not active:
		return
	match action:
		"left": lane = maxi(0, lane - 1)
		"right": lane = mini(2, lane + 1)
		"jump": jump_buffer = 0.15
		"slide":
			sliding = 0.85
			if not is_on_floor(): velocity.y = -17.0

func _physics_process(delta: float) -> void:
	if not active:
		return
	sliding = maxf(0, sliding - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if jump_buffer > 0 and is_on_floor():
		sliding = 0
		velocity.y = 10.5
		jump_buffer = 0
		jumped.emit()
	if sliding <= 0 and collider.shape == slide_shape:
		# Do not expand the character inside an overhead barrier.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = standing_shape
		query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 1.15, 0))
		query.collision_mask = 2
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			sliding = 0.05
	collider.shape = slide_shape if sliding > 0 else standing_shape
	collider.position.y = 0.36 if sliding > 0 else 1.125
	velocity.y = maxf(velocity.y - 28.0 * delta, -30.0)
	var destination := float(lane - 1) * LANE
	var step := move_toward(position.x, destination, 17.0 * delta)
	velocity.x = (step - position.x) / delta
	velocity.z = -speed
	move_and_slide()
	position.x = clampf(position.x, -LANE, LANE)
	for i in range(get_slide_collision_count()):
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as Node
		if body != null and body.is_in_group("hazards") and hit.get_normal().y < 0.65:
			crashed.emit(body)
			break
	if position.y < -2:
		crashed.emit(null)
	animate(delta)

func animate(delta: float) -> void:
	animation_time += delta * speed
	var stride := sin(animation_time * 1.4) * 0.7
	model.get_node("LeftLeg").rotation.x = stride
	model.get_node("RightLeg").rotation.x = -stride
	model.get_node("LeftArm").rotation.x = -stride * 0.85
	model.get_node("RightArm").rotation.x = stride * 0.85
	model.get_node("Tail").rotation.y = sin(animation_time * 0.6) * 0.35
	model.rotation.z = lerpf(model.rotation.z, -velocity.x * 0.016, 12 * delta)
	model.scale.y = lerpf(model.scale.y, 0.29 if sliding > 0 else 1.0, 20 * delta)
	model.position.y = 0.0 if sliding > 0 or not is_on_floor() else absf(sin(animation_time * 1.4)) * 0.055

func reset_runner() -> void:
	position = Vector3(0, 0.03, 4)
	velocity = Vector3.ZERO
	lane = 1
	sliding = 0
	jump_buffer = 0
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	collider.shape = standing_shape
	collider.position.y = 1.125
