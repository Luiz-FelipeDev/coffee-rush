shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Base parameters
uniform float tape_wave_amount : hint_range(0.0, 0.05) = 0.003;
uniform float tape_wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform float color_displacement : hint_range(0.0, 0.05) = 0.002;
uniform float lines_velocity : hint_range(0.0, 5.0) = 0.1;
uniform float noise_amount : hint_range(0.0, 0.5) = 0.03;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

// Dynamic triggers controlled by script
uniform float glitch_intensity : hint_range(1.0, 10.0) = 1.0;
uniform float crt_power_off : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size : hint_range(1.0, 12.0) = 1.0; // 1.0 = sem efeito de pixelizacao

// Fast pseudo-random function for static noise
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// CRT Power Off Squish effect
	if (crt_power_off > 0.0) {
		float squish = (1.0 - crt_power_off);
		uv.y = (uv.y - 0.5) / max(squish, 0.0001) + 0.5;
		uv.x = (uv.x - 0.5) / max(squish * 2.0 + 0.1, 0.0001) + 0.5;
	}

	// Safely checks boundaries to draw black outside the CRT screen
	if (uv.y < 0.0 || uv.y > 1.0 || uv.x < 0.0 || uv.x > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// 1. Tape distortion multiplied by glitch
		uv.x += sin(uv.y * 10.0 + TIME * tape_wave_speed) * (tape_wave_amount * glitch_intensity);
		uv.x += sin(uv.y * 200.0 + TIME * tape_wave_speed * 2.0) * (tape_wave_amount * 0.2 * glitch_intensity);

		// 1.1 Faixas de erro de trackeamento -- ficam mais frequentes conforme o glitch aumenta
		float track_seed = floor(uv.y * 20.0 + TIME * 0.3);
		float track_chance = random(vec2(track_seed, 0.0));
		if (track_chance > 0.97 - (glitch_intensity * 0.01)) {
			uv.x += (random(vec2(track_seed, TIME)) - 0.5) * 0.3 * (glitch_intensity / 10.0);
		}

		// 1.2 Pixelizacao/datamosh -- pensado pra bursts rapidos (ex: dano, morte)
		if (pixel_size > 1.0) {
			vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
			uv = floor(uv * resolution / pixel_size) * pixel_size / resolution;
		}

		// 2. Chromatic Aberration multiplied by glitch
		float offset = color_displacement * glitch_intensity;
		float r = texture(screen_texture, uv + vec2(offset, 0.0)).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv - vec2(offset, 0.0)).b;

		// 3. Scanlines
		float scanlines = 0.5 + 0.5 * sin(uv.y * 500.0 + TIME * lines_velocity * 100.0);
		vec3 color = vec3(r, g, b) * (0.9 + 0.1 * scanlines);

		// 4. Static Noise multiplied by glitch
		float noise = random(uv + TIME * 10.0);
		color += noise * (noise_amount * glitch_intensity);

		// 5. Vignette -- escurece os cantos, acentua a sensacao de lente/tubo velho
		float vignette = smoothstep(0.85, 0.25, length(SCREEN_UV - vec2(0.5)));
		color *= mix(1.0 - vignette_strength, 1.0, vignette);

		// 6. Darken as the TV powers off
		color *= (1.0 - crt_power_off);

		COLOR = vec4(color, 1.0);
	}
}
