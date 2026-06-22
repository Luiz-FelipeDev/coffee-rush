shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_always;

uniform vec4 beam_color : source_color = vec4(1.0, 0.3, 0.8, 1.0);
uniform sampler2D noise_texture : hint_default_white;
uniform float scroll_speed = 1.0;
uniform float fade_power = 2.0;
uniform float beam_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float vertical_fade = pow(UV.y, fade_power);

    vec2 animated_uv = UV;
    animated_uv.y -= TIME * scroll_speed;
    float noise_value = texture(noise_texture, animated_uv).r;

    float final_alpha = vertical_fade * noise_value * beam_color.a * beam_intensity;

    ALBEDO = beam_color.rgb;
    EMISSION = beam_color.rgb * 2.0;
    ALPHA = final_alpha;
}