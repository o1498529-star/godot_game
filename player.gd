extends CharacterBody3D

@export var run_speed := 9.0
@export var slow_speed := 4.0
@export var lane_width := 2.8
@export var lane_change_speed := 14.0
@export var jump_velocity := 8.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var lane := 1
var target_x := 0.0

func _ready() -> void:
	target_x = position.x

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("move_left"):
		lane = max(0, lane - 1)
		target_x = float(lane - 1) * lane_width
	if Input.is_action_just_pressed("move_right"):
		lane = min(2, lane + 1)
		target_x = float(lane - 1) * lane_width

	if not is_on_floor():
		velocity.y -= gravity * delta

	if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_forward")) and is_on_floor():
		velocity.y = jump_velocity

	var current_speed := slow_speed if Input.is_action_pressed("move_back") else run_speed
	velocity.z = -current_speed
	var difference := target_x - position.x
	if abs(difference) < 0.04:
		position.x = target_x
		velocity.x = 0.0
	else:
		velocity.x = clamp(difference * 10.0, -lane_change_speed, lane_change_speed)
	move_and_slide()

	for index in range(get_slide_collision_count()):
		var collider := get_slide_collision(index).get_collider()
		if collider is Node and collider.get_meta("runner_obstacle", false):
			var world := get_parent()
			if world.has_method("on_runner_hit"):
				world.on_runner_hit()
