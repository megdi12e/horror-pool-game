extends Node3D
## The Still Below — original procedural survival prototype.
const CELL := 4.0
const CHUNK := 32.0
const Sound = preload("res://scripts/sound.gd")
var player: CharacterBody3D
var camera: Camera3D
var monster: CharacterBody3D
var sound: Node
var chunks: Dictionary = {}
var items: Array[Node3D] = []
var tile: ShaderMaterial
var water: ShaderMaterial
var pale: StandardMaterial3D
var elapsed := 0.0
var score := 0
var collected := 0
var taken: Dictionary = {}
var stamina := 100.0
var exhausted := false
var shields := 0
var decoys := 1
var dead := false
var started := false
var paused := false
var pitch := 0.0
var step_clock := 0.0
var refresh_clock := 0.0
var target := Vector3.ZERO
var alert_until := 0.0
var decoy_until := 0.0
var decoy_position := Vector3.ZERO
var ward_until := 0.0
var path: Array[Vector3] = []
var path_clock := 0.0
var ui: CanvasLayer
var stats: Label
var prompt: Label
var banner: Label
var menu: PanelContainer
var title: Label
var menu_text: Label
var play_button: Button
var touch_move := Vector2.ZERO
var touch_sprint := false
var joystick: Control
var stick_finger := -1
var look_finger := -1
var stick_origin := Vector2.ZERO
var smoke := false

func _ready() -> void:
 smoke = "--smoke" in OS.get_cmdline_user_args()
 _inputs()
 tile = ShaderMaterial.new()
 tile.shader = load("res://shaders/tile.gdshader")
 water = ShaderMaterial.new()
 water.shader = load("res://shaders/water.gdshader")
 pale = _material(Color(0.72, 0.78, 0.65))
 var env := WorldEnvironment.new()
 var settings := Environment.new()
 settings.background_mode = Environment.BG_COLOR
 settings.background_color = Color(0.025, 0.07, 0.075)
 settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 settings.ambient_light_color = Color(0.48, 0.68, 0.62)
 settings.ambient_light_energy = 0.48
 settings.fog_enabled = true
 settings.fog_light_color = Color(0.06, 0.16, 0.16)
 settings.fog_density = 0.045
 env.environment = settings
 add_child(env)
 player = CharacterBody3D.new()
 player.position = Vector3(2, 0.15, 2)
 var shape := CapsuleShape3D.new()
 shape.radius = 0.3
 shape.height = 1.65
 var collision := CollisionShape3D.new()
 collision.shape = shape
 collision.position.y = 0.85
 player.add_child(collision)
 add_child(player)
 camera = Camera3D.new()
 camera.position.y = 1.55
 camera.fov = 78
 player.add_child(camera)
 var lamp := SpotLight3D.new()
 lamp.light_color = Color(0.76, 0.91, 0.78)
 lamp.light_energy = 2.0
 lamp.spot_range = 24
 lamp.spot_angle = 43
 camera.add_child(lamp)
 monster = CharacterBody3D.new()
 monster.position = Vector3(30, 0.15, 30)
 var ms := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = 0.42
 capsule.height = 2.4
 ms.shape = capsule
 ms.position.y = 1.2
 monster.add_child(ms)
 add_child(monster)
 var black := _material(Color(0.025, 0.045, 0.035))
 _box(monster, Vector3(0.7, 1.7, 0.45), Vector3(0, 1.3, 0), black)
 _box(monster, Vector3(0.45, 0.5, 0.5), Vector3(0, 2.35, 0), black)
 for side in [-1, 1]:
  _box(monster, Vector3(0.16, 1.9, 0.18), Vector3(side * 0.55, 0.85, 0), black)
  _box(monster, Vector3(0.2, 0.8, 0.22), Vector3(side * 0.23, 0.4, 0), black)
 var eyes := _material(Color(0.8, 0.91, 0.56), true)
 for side in [-1, 1]:
  _box(monster, Vector3(0.07, 0.045, 0.04), Vector3(side * 0.11, 2.4, -0.27), eyes)
 sound = Sound.new()
 add_child(sound)
 _update_chunks()
 _ui()
 if smoke:
  _start()

func _inputs() -> void:
 var bindings := {"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "interact": [KEY_E], "decoy": [KEY_Q]}
 for action in bindings:
  if InputMap.has_action(action):
   continue
  InputMap.add_action(action)
  for key in bindings[action]:
   var event := InputEventKey.new()
   event.physical_keycode = key
   InputMap.action_add_event(action, event)

func _material(color: Color, glow := false) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 if glow:
  result.emission_enabled = true
  result.emission = color
  result.emission_energy_multiplier = 2
 return result

func _box(parent: Node, size: Vector3, pos: Vector3, material: Material, solid := false) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 var box := BoxMesh.new()
 box.size = size
 mesh.mesh = box
 mesh.material_override = material
 mesh.position = pos
 parent.add_child(mesh)
 if solid:
  var body := StaticBody3D.new()
  var collision := CollisionShape3D.new()
  var shape := BoxShape3D.new()
  shape.size = size
  collision.shape = shape
  body.add_child(collision)
  mesh.add_child(body)
 return mesh

func _blocked(cell: Vector2i) -> bool:
 return (posmod(cell.x, 4) == 2 and posmod(cell.y, 4) == 2) or (posmod(cell.x, 8) == 6 and posmod(cell.y, 8) in [1, 2, 3, 4])

func _update_chunks() -> void:
 var center := Vector2i(floori(player.position.x / CHUNK), floori(player.position.z / CHUNK))
 for x in range(center.x - 1, center.x + 2):
  for z in range(center.y - 1, center.y + 2):
   var key := Vector2i(x, z)
   if not chunks.has(key):
    _chunk(key)
 var monster_chunk := Vector2i(floori(monster.position.x / CHUNK), floori(monster.position.z / CHUNK))
 if not chunks.has(monster_chunk):
  _chunk(monster_chunk)
 for key in chunks.keys():
  if key == monster_chunk:
   continue
  if absi(key.x - center.x) > 2 or absi(key.y - center.y) > 2:
   chunks[key].queue_free()
   chunks.erase(key)
 items = items.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())

func _chunk(key: Vector2i) -> void:
 var root := Node3D.new()
 root.position = Vector3(key.x * CHUNK, 0, key.y * CHUNK)
 add_child(root)
 chunks[key] = root
 _box(root, Vector3(32, 0.4, 32), Vector3(16, -0.2, 16), tile, true)
 _box(root, Vector3(32, 0.25, 32), Vector3(16, 4.2, 16), tile)
 var plane := MeshInstance3D.new()
 var surface := PlaneMesh.new()
 surface.size = Vector2(32, 32)
 plane.mesh = surface
 plane.material_override = water
 plane.position = Vector3(16, 0.12, 16)
 root.add_child(plane)
 for x in range(8):
  for z in range(8):
   var global_cell := key * 8 + Vector2i(x, z)
   if _blocked(global_cell):
    var width := 4.0 if posmod(global_cell.x, 8) == 6 else 3.0
    _box(root, Vector3(width, 4.2, width), Vector3(x * CELL + 2, 2.1, z * CELL + 2), tile, true)
 for x in [8, 24]:
  for z in [8, 24]:
   _box(root, Vector3(2.6, 0.07, 0.38), Vector3(x, 4.02, z), _material(Color(0.68, 0.87, 0.73), true))
   var light := OmniLight3D.new()
   light.position = Vector3(x, 3.5, z)
   light.omni_range = 13
   light.light_energy = 0.8
   light.light_color = Color(0.66, 0.84, 0.69)
   root.add_child(light)
 var rng := RandomNumberGenerator.new()
 rng.seed = hash(key) + 5173
 for index in range(3):
  var item_id := "%d:%d:%d" % [key.x, key.y, index]
  if taken.has(item_id):
   continue
  var cell := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 7))
  while _blocked(key * 8 + cell):
   cell.x = posmod(cell.x + 1, 8)
  var item := Node3D.new()
  root.add_child(item)
  item.position = Vector3(cell.x * CELL + 2, 0.65, cell.y * CELL + 2)
  var kind := posmod(key.x + key.y + index, 3)
  item.set_meta("kind", kind)
  item.set_meta("id", item_id)
  var colors := [Color(0.3, 0.95, 0.8), Color(0.95, 0.68, 0.2), Color(0.6, 0.55, 1)]
  _box(item, Vector3(0.38, 0.5, 0.38), Vector3.ZERO, _material(colors[kind], true))
  items.append(item)

func _physics_process(delta: float) -> void:
 if not started or dead or paused:
  return
 elapsed += delta
 var input := Input.get_vector("left", "right", "forward", "back") + touch_move
 input = input.limit_length()
 if stamina <= 1:
  exhausted = true
 elif stamina >= 25:
  exhausted = false
 var running := (Input.is_action_pressed("sprint") or touch_sprint) and not exhausted and input.length() > 0.1
 stamina = clampf(stamina + (-24 if running else 16) * delta, 0, 100)
 var direction := player.basis * Vector3(input.x, 0, input.y)
 player.velocity = direction * (5.8 if running else 3.0)
 player.velocity.y = -3
 player.move_and_slide()
 step_clock -= delta
 if input.length() > 0.1 and step_clock <= 0:
  step_clock = 0.28 if running else 0.52
  sound.effect("step")
  var hearing := 32.0 if running else 11.0
  if monster.position.distance_to(player.position) < hearing:
   target = player.position
   alert_until = elapsed + 8
 camera.position.y = 1.55 + sin(elapsed * (15 if running else 10)) * input.length() * 0.035
 var distance := monster.position.distance_to(player.position)
 sound.danger = clampf(1.0 - distance / 26.0, 0, 1)
 if elapsed < decoy_until:
  target = decoy_position
 elif distance < 9 and _can_see_player():
  target = player.position
  alert_until = elapsed + 6
 elif elapsed > alert_until and monster.position.distance_to(target) < 2:
  target = monster.position + Vector3(sin(elapsed * 1.7), 0, cos(elapsed * 1.1)) * 14
 _move_monster(delta)
 if distance < 1.25 and elapsed > ward_until:
  if shields > 0:
   shields -= 1
   ward_until = elapsed + 5
   sound.effect("ward")
   banner.text = "WARD BROKEN — run! (5 seconds safe)"
  else:
   _die()
 refresh_clock -= delta
 if refresh_clock <= 0:
  refresh_clock = 0.5
  _update_chunks()
 for item in items:
  if is_instance_valid(item):
   item.rotation.y += delta
 score = int(elapsed * 10) + collected * 150
 stats.text = "THE STILL BELOW   |   %02d:%02d   |   SCORE %d\nSTAMINA %d%%   |   WARDS %d   |   DECOYS %d" % [int(elapsed) / 60, int(elapsed) % 60, score, int(stamina), shields, decoys]
 var near := _nearest_item()
 prompt.text = "E / INTERACT — " + ["take ward (one-hit protection)", "take breath flask (stamina)", "take noise decoy (Q to drop)"][int(near.get_meta("kind"))] if near else "WASD move · Shift run · E collect · Q decoy · Esc pause"
 if elapsed > 8 and elapsed > ward_until:
  banner.text = "IT HEARS YOUR SPLASHES" if distance < 17 else "Keep moving. Listen. Survive."
 if Input.is_action_just_pressed("interact"):
  _collect()
 if Input.is_action_just_pressed("decoy"):
  _decoy()

func _can_see_player() -> bool:
 var query := PhysicsRayQueryParameters3D.create(monster.position + Vector3.UP * 1.5, player.position + Vector3.UP)
 query.exclude = [monster.get_rid()]
 var hit := get_world_3d().direct_space_state.intersect_ray(query)
 return hit.is_empty() or hit.collider == player

func _move_monster(delta: float) -> void:
 path_clock -= delta
 if path_clock <= 0:
  path_clock = 0.65
  var astar := AStarGrid2D.new()
  var origin := Vector2i(floori(monster.position.x / CELL), floori(monster.position.z / CELL))
  astar.region = Rect2i(origin - Vector2i(20, 20), Vector2i(41, 41))
  astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
  astar.update()
  for x in range(origin.x - 20, origin.x + 21):
   for z in range(origin.y - 20, origin.y + 21):
    if _blocked(Vector2i(x, z)):
     astar.set_point_solid(Vector2i(x, z))
  var dest := Vector2i(floori(target.x / CELL), floori(target.z / CELL))
  dest = dest.clamp(origin - Vector2i(19, 19), origin + Vector2i(19, 19))
  if _blocked(dest):
   dest.x += 1
  path.clear()
  for cell in astar.get_id_path(origin, dest):
   path.append(Vector3(cell.x * CELL + 2, 0.15, cell.y * CELL + 2))
  if path.size() > 1:
   path.remove_at(0)
 if not path.is_empty():
  var point := path[0]
  if path.size() == 1 and not _blocked(Vector2i(floori(target.x / CELL), floori(target.z / CELL))):
   point = target
  var heading := point - monster.position
  heading.y = 0
  if heading.length() < 0.5:
   path.remove_at(0)
  else:
   var speed := minf(4.7, 1.55 + elapsed * 0.012)
   if elapsed < ward_until:
    speed = 0.4
   monster.velocity = heading.normalized() * speed
   monster.velocity.y = -3
   monster.move_and_slide()
   monster.rotation.y = atan2(-heading.x, -heading.z)

func _nearest_item() -> Node3D:
 var closest: Node3D = null
 var distance := 2.4
 for item in items:
  if is_instance_valid(item) and not item.is_queued_for_deletion():
   var d := item.global_position.distance_to(player.position + Vector3.UP * 0.5)
   if d < distance:
    closest = item
    distance = d
 return closest

func _collect() -> void:
 var item := _nearest_item()
 if item == null or dead or paused or not started:
  return
 match int(item.get_meta("kind")):
  0: shields += 1
  1: stamina = 100
  2: decoys += 1
 collected += 1
 taken[item.get_meta("id")] = true
 items.erase(item)
 item.queue_free()
 sound.effect("pickup")

func _decoy() -> void:
 if decoys <= 0 or dead or paused or not started:
  return
 decoys -= 1
 decoy_position = player.position
 decoy_until = elapsed + 10
 target = decoy_position
 path_clock = 0
 sound.effect("ward")
 banner.text = "DECOY ACTIVE — walk away quietly"

func _start() -> void:
 started = true
 paused = false
 menu.hide()
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _die() -> void:
 dead = true
 sound.effect("ward")
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 title.text = "THE WATER REMEMBERS"
 menu_text.text = "Survived %d seconds · Score %d\nCollected %d supplies\n\nEvery run begins in the same place.\nHow far will you get this time?" % [int(elapsed), int(elapsed * 10) + collected * 150, collected]
 play_button.text = "TRY AGAIN"
 menu.show()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused and not dead:
  _look(event.relative)
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and started and not dead:
  paused = not paused
  menu.visible = paused
  title.text = "BREATHE QUIETLY"
  menu_text.text = "Paused.\n\nRunning is loud. Walking is safer.\nCollect wards and leave decoys behind you."
  play_button.text = "RESUME"
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
 if event is InputEventScreenTouch:
  if event.pressed:
   if event.position.x < get_viewport().get_visible_rect().size.x * 0.4 and stick_finger == -1:
    stick_finger = event.index
    stick_origin = event.position
   elif look_finger == -1:
    look_finger = event.index
  else:
   if event.index == stick_finger:
    stick_finger = -1
    touch_move = Vector2.ZERO
   if event.index == look_finger:
    look_finger = -1
 if event is InputEventScreenDrag:
  if event.index == stick_finger:
   touch_move = ((event.position - stick_origin) / 70).limit_length()
  elif event.index == look_finger and started and not dead and not paused:
   _look(event.relative * 0.7)

func _look(relative: Vector2) -> void:
 player.rotate_y(-relative.x * 0.0025)
 pitch = clampf(pitch - relative.y * 0.0025, -1.4, 1.4)
 camera.rotation.x = pitch

func _label(text: String, size: int) -> Label:
 var label := Label.new()
 label.text = text
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", Color(0.78, 0.9, 0.81))
 return label

func _ui() -> void:
 ui = CanvasLayer.new()
 add_child(ui)
 var base := Control.new()
 base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 base.mouse_filter = Control.MOUSE_FILTER_IGNORE
 ui.add_child(base)
 stats = _label("", 20)
 stats.position = Vector2(28, 24)
 base.add_child(stats)
 banner = _label("Keep moving. Listen. Survive.", 20)
 banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 banner.position += Vector2(-180, 100)
 base.add_child(banner)
 prompt = _label("", 17)
 prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 prompt.position += Vector2(28, -45)
 base.add_child(prompt)
 var cross := _label("·", 30)
 cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 base.add_child(cross)
 menu = PanelContainer.new()
 menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 menu.position -= Vector2(265, 200)
 menu.custom_minimum_size = Vector2(530, 400)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.015, 0.045, 0.045, 0.97)
 style.content_margin_left = 32
 style.content_margin_right = 32
 style.content_margin_top = 28
 style.content_margin_bottom = 28
 menu.add_theme_stylebox_override("panel", style)
 base.add_child(menu)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 20)
 menu.add_child(column)
 title = _label("THE STILL BELOW", 34)
 column.add_child(title)
 menu_text = _label("An original poolrooms survival game.\n\nWASD / arrows — move · Mouse — look\nShift — sprint (loud) · E — collect · Q — decoy\nEsc — pause and release the mouse\n\nWalk quietly. Gather supplies. Stay alive.\nThe thing beneath the lights gets faster.", 18)
 column.add_child(menu_text)
 play_button = Button.new()
 play_button.text = "ENTER THE WATER"
 play_button.custom_minimum_size.y = 48
 play_button.pressed.connect(func():
  if dead:
   get_tree().reload_current_scene()
  else:
   _start())
 column.add_child(play_button)
 var touch := HBoxContainer.new()
 touch.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 touch.position += Vector2(-330, -110)
 touch.visible = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()
 base.add_child(touch)
 for caption in ["RUN", "TAKE", "DECOY"]:
  var button := Button.new()
  button.text = caption
  button.custom_minimum_size = Vector2(100, 72)
  if caption == "RUN":
   button.button_down.connect(func(): touch_sprint = true)
   button.button_up.connect(func(): touch_sprint = false)
  elif caption == "TAKE":
   button.pressed.connect(_collect)
  else:
   button.pressed.connect(_decoy)
  touch.add_child(button)
 if touch.visible:
  joystick = Control.new()
  joystick.set_script(load("res://scripts/joystick.gd"))
  joystick.position = Vector2(45, 480)
  joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
  base.add_child(joystick)
