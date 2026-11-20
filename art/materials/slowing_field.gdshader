shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 field_color : source_color = vec4(0.27, 0.87, 0.85, 0.45);

void fragment() {
    float radius = length(UV - vec2(0.5)) * 2.0;
    float edge = smoothstep(0.78, 0.90, radius) * (1.0 - smoothstep(0.93, 1.0, radius));
    float ring = pow(0.5 + 0.5 * sin(radius * 22.0 - TIME * 1.8), 10.0);
    float inside = 1.0 - smoothstep(0.90, 1.0, radius);
    ALBEDO = field_color.rgb;
    ALPHA = field_color.a * (edge + ring * inside * 0.22 + inside * 0.08);
}
