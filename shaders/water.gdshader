shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 water_color : source_color = vec4(0.08, 0.39, 0.36, 0.78);
void vertex() {
 VERTEX.y += sin(VERTEX.x * 1.8 + TIME * 1.3) * 0.018 + cos(VERTEX.z * 2.2 + TIME) * 0.014;
}
void fragment() {
 float ripple = sin(UV.x * 240.0 + TIME) * cos(UV.y * 240.0 - TIME * 0.7);
 ALBEDO = water_color.rgb + ripple * 0.025;
 ROUGHNESS = 0.22;
 METALLIC = 0.35;
 ALPHA = water_color.a;
}
