extends Node
## All audio is synthesized here. No recordings or third-party samples.
var drone: AudioStreamPlayer
var danger := 0.0
var phase := 0.0

func _ready() -> void:
 drone = AudioStreamPlayer.new()
 var generator := AudioStreamGenerator.new()
 generator.mix_rate = 22050
 generator.buffer_length = 0.15
 drone.stream = generator
 drone.volume_db = -17
 add_child(drone)
 drone.play()

func _process(_delta: float) -> void:
 var playback := drone.get_stream_playback() as AudioStreamGeneratorPlayback
 if playback == null:
  return
 for i in range(playback.get_frames_available()):
  phase += 1.0 / 22050.0
  var wave := sin(TAU * 47.0 * phase) * 0.22 + sin(TAU * 50.2 * phase) * 0.18
  wave += sin(TAU * (83.0 + sin(phase * 0.7) * 4.0) * phase) * danger * 0.23
  wave += sin(TAU * 29.0 * phase) * pow(maxf(0.0, sin(phase * 7.0)), 8.0) * danger * 0.4
  playback.push_frame(Vector2(wave, wave))

func effect(kind: String) -> void:
 var rate := 22050
 var duration := 0.18 if kind == "step" else 0.65
 var bytes := PackedByteArray()
 bytes.resize(int(rate * duration) * 2)
 var rng := RandomNumberGenerator.new()
 rng.seed = 9182 if kind == "step" else 722
 for i in range(bytes.size() / 2):
  var t := float(i) / rate
  var envelope := pow(1.0 - t / duration, 3.0)
  var sample: float
  if kind == "step":
   sample = (rng.randf_range(-1, 1) * 0.45 + sin(t * 380.0) * 0.4) * envelope
  elif kind == "pickup":
   sample = sin(TAU * (440.0 + t * 660.0) * t) * envelope * 0.45
  else:
   sample = (sin(TAU * 67.0 * t) + rng.randf_range(-0.4, 0.4)) * envelope * 0.6
  bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32000))
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = rate
 stream.data = bytes
 var player := AudioStreamPlayer.new()
 player.stream = stream
 player.volume_db = -15 if kind == "step" else -9
 add_child(player)
 player.finished.connect(player.queue_free)
 player.play()

func _exit_tree() -> void:
 for child in get_children():
  if child is AudioStreamPlayer:
   child.stop()
