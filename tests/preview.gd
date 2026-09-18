extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	for i in range(60): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_menu.png")
	world.start_run()
	world.countdown = 0
	for i in range(35): await process_frame
	world.runner.active = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_run.png")
	print("PREVIEWS SAVED")
	quit()
