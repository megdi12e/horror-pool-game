extends Control
func _draw() -> void:
 draw_circle(Vector2(70, 70), 68, Color(0.4, 0.8, 0.7, 0.18))
 draw_arc(Vector2(70, 70), 68, 0, TAU, 64, Color(0.6, 0.9, 0.8, 0.5), 2)
 draw_circle(Vector2(70, 70), 24, Color(0.6, 0.9, 0.8, 0.4))
