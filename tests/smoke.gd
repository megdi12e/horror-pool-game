extends SceneTree
var checks := 0
var failed := false
func expect(condition: bool, message: String) -> void:
 if not condition:
  push_error("FAIL: " + message)
  failed = true
 else:
  checks += 1
  print("PASS: " + message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 expect(game.chunks.size() == 9, "initial nine chunks and collision geometry created")
 expect(not game.started, "title screen waits for Play")
 expect(not game._blocked(Vector2i(floori(game.monster.position.x / 4.0), floori(game.monster.position.z / 4.0))), "monster spawns outside solid geometry")
 game._start()
 game._inputs()
 game.monster.position = Vector3(60, 0.15, 60)
 game.set_physics_process(true)
 Input.action_press("forward")
 var start_position: Vector3 = game.player.position
 for i in range(90):
  await physics_frame
 Input.action_release("forward")
 game.set_physics_process(false)
 expect(game.player.position.distance_to(start_position) > 2.0, "real physics moves player using keyboard action")
 expect(game.player.position.y > -0.1 and game.player.position.y < 0.2, "pool floor supports player during movement")
 game.player.position = Vector3(22, 0.15, 6)
 game.set_physics_process(true)
 Input.action_press("right")
 for i in range(90):
  await physics_frame
 Input.action_release("right")
 game.set_physics_process(false)
 expect(game.player.position.x < 24.0, "solid corridor wall prevents walking through it")
 for i in range(20):
  game._physics_process(1.0 / 60.0)
 expect(game.elapsed > 0 and game.score > 0, "survival timer and score advance")
 var first = game.items[0]
 var id = first.get_meta("id")
 player_to(game, first.global_position)
 var before: int = game.collected
 game._collect()
 expect(game.collected == before + 1 and game.taken.has(id), "interaction collects and remembers supply")
 game.decoys = 1
 game._decoy()
 expect(game.decoys == 0 and game.decoy_until > game.elapsed, "noise decoy consumes inventory and attracts monster")
 game.player.position = Vector3(5, 0.15, 2)
 game.monster.position = Vector3(2, 0.15, 2)
 game.decoy_until = 0
 game.alert_until = 0
 game._physics_process(0.02)
 expect(game.alert_until > game.elapsed, "monster detects player in line of sight")
 game.monster.position = Vector3(42, 0.15, 2)
 game.player.position = Vector3(14, 0.15, 2)
 game.alert_until = 0
 Input.action_press("forward")
 Input.action_press("sprint")
 game.step_clock = 0
 game._physics_process(0.02)
 expect(game.stamina < 100 and game.alert_until > game.elapsed, "sprint drains stamina and emits audible noise")
 Input.action_release("forward")
 Input.action_release("sprint")
 game.target = Vector3(38, 0.15, 10)
 game.path_clock = 0
 game._move_monster(0.02)
 expect(not game.path.is_empty(), "A-star routes around pool obstacles")
 var safe_path := true
 for point in game.path:
  if game._blocked(Vector2i(floori(point.x / 4.0), floori(point.z / 4.0))):
   safe_path = false
 expect(safe_path, "monster path contains no blocked cells")
 game.player.position = Vector3(400, 0.15, -400)
 game._update_chunks()
 await process_frame
 expect(game.chunks.size() <= 26, "streaming unloads distant chunks while retaining monster floor")
 expect(game.chunks.has(Vector2i(12, -13)), "new pool region generated at distant position")
 game.paused = true
 var previous: float = game.elapsed
 game._physics_process(1)
 expect(game.elapsed == previous, "pause freezes survival simulation")
 game.paused = false
 game.shields = 1
 game.ward_until = 0
 game.monster.position = game.player.position
 game._physics_process(0.01)
 expect(game.shields == 0 and not game.dead, "ward absorbs monster contact")
 game.ward_until = 0
 game.monster.position = game.player.position
 game._physics_process(0.01)
 expect(game.dead and game.menu.visible, "unprotected contact opens game-over and replay UI")
 current_scene = game
 game.play_button.pressed.emit()
 await process_frame
 await process_frame
 var restarted = current_scene
 expect(is_instance_valid(restarted) and not restarted.dead and not restarted.started, "Try Again reloads a fresh playable round")
 restarted._start()
 expect(restarted.started and restarted.elapsed == 0, "restarted round accepts Play and resets timer")
 print("SMOKE COMPLETE: %d checks" % checks)
 restarted.queue_free()
 await process_frame
 await create_timer(0.3).timeout
 quit(1 if failed else 0)

func player_to(game: Node, pos: Vector3) -> void:
 game.player.position = Vector3(pos.x, 0.15, pos.z)
