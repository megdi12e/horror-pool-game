shader_type spatial;
uniform vec4 tile_color : source_color = vec4(0.62,0.72,0.64,1.0);
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}
void fragment() {
 vec3 n = abs(world_normal);
 vec2 grid = world_pos.xz * 2.0;
 if (n.x > 0.5) { grid = world_pos.zy * 2.0; }
 else if (n.z > 0.5) { grid = world_pos.xy * 2.0; }
 vec2 d = min(fract(grid), 1.0 - fract(grid));
 vec2 aa = max(fwidth(grid), vec2(0.001));
 vec2 edge = smoothstep(vec2(0.018), vec2(0.018) + aa, d);
 float stain = 0.94 + 0.06 * sin(world_pos.x * 0.8) * sin(world_pos.z * 1.1 + world_pos.y);
 ALBEDO = mix(tile_color.rgb * 0.45, tile_color.rgb * stain, edge.x * edge.y);
 ROUGHNESS = 0.72;
}
