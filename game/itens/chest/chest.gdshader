shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_always;

uniform vec4 beam_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform sampler2D noise_texture : hint_default_white;
uniform float scroll_speed = 3.0;
uniform float fade_power = 2.0;

// Set to 1.0 by default so it is fully visible in the editor
uniform float beam_intensity : hint_range(0.0, 1.0) = 1.0; 

// New parameters for organic and lightning effects
uniform float glow_strength = 55.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.3;
uniform float energy_sharpness : hint_range(1.0, 10.0) = 4.0;

void fragment() {
    float vertical_fade = pow(UV.y, fade_power);
    
    // 1. Creates a secondary slow-moving UV for organic warping
    vec2 warp_uv = UV;
    warp_uv.y -= TIME * (scroll_speed * 0.4);
    float warp_noise = texture(noise_texture, warp_uv).r;
    
    vec2 animated_uv = UV;
    animated_uv.y -= TIME * scroll_speed;
    
    // 2. Distorts the horizontal UV based on the warp noise, bending straight lines into curves
    animated_uv.x += (warp_noise - 0.5) * distortion_strength;
    
    float noise_value = texture(noise_texture, animated_uv).r;
    
    // 3. Sharpens the soft noise into hard energy filaments or lightning streaks
    float organic_pattern = pow(noise_value, energy_sharpness);
    
    float final_alpha = vertical_fade * organic_pattern * beam_color.a * beam_intensity;
    
    // Multiplies the base color to push it into HDR values for the glow effect
    vec3 hot_glow = beam_color.rgb * glow_strength;

    ALBEDO = hot_glow;
    EMISSION = hot_glow;
    ALPHA = final_alpha;
}