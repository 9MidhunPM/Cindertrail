shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 water_color : source_color = vec4(0.09, 0.56, 0.60, 0.82);
uniform float wave_height : hint_range(0.0, 0.15) = 0.025;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.6;

void vertex() {
    VERTEX.y += sin(VERTEX.x * 1.4 + TIME * wave_speed)
        * cos(VERTEX.z * 1.1 + TIME * wave_speed * 0.7) * wave_height;
}

void fragment() {
    float ripple = sin((UV.x + UV.y) * 90.0 - TIME * wave_speed * 2.0);
    ALBEDO = water_color.rgb * (0.97 + 0.03 * ripple);
    ROUGHNESS = 0.32;
    METALLIC = 0.0;
    ALPHA = water_color.a;
}
