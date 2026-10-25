extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 for i in range(4):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/title-screen.png")
 game._start()
 game.player.rotation.y = -0.7
 for i in range(15):
  await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 image.save_png("res://docs/first-play.png")
 print("Rendered screenshot: ", image.get_size())
 game.queue_free()
 await process_frame
 await create_timer(0.2).timeout
 quit()
