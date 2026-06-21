shader_type spatial;

const float SMOOTHSTEP_AA = 0.01;

uniform sampler2D surface_noise;
uniform sampler2D distort_noise;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform float beer_factor = 0.8;

uniform float foam_distance = 0.01;
uniform float foam_max_distance = 0.4;
uniform float foam_min_distance = 0.04;
uniform vec4 foam_color : source_color = vec4(1.0);

uniform vec2 surface_noise_tiling = vec2(1.0, 4.0);
uniform vec3 surface_noise_scroll = vec3(0.03, 0.03, 0.0);
uniform float surface_noise_cutoff : hint_range(0.0, 1.0) = 0.777;
uniform float surface_distortion_amount : hint_range(0.0, 1.0) = 0.27;

uniform vec4 depth_gradient_shallow : source_color = vec4(0.325, 0.807, 0.971, 0.725);
uniform vec4 depth_gradient_deep : source_color = vec4(0.086, 0.407, 1.0, 0.749);
uniform float depth_max_distance : hint_range(0.0, 1.0) = 1.0;
uniform float depth_factor = 1.0;

varying vec2 noise_uv;
varying vec2 distort_uv;
varying vec3 view_normal;

vec4 alpha_blend(vec4 top, vec4 bottom) {
	// é calculada a cor resultante misturando os canais rgb de acordo com o alpha superior
	vec3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
	
	// é calculado o alpha final para garantir a transparência correta no buffer
	float alpha = top.a + bottom.a * (1.0 - top.a);
	
	return vec4(color, alpha);
}

void vertex() {
	// é extraída a normal em relação à câmera para o cálculo direcional da espuma
	view_normal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	
	// são mapeadas as coordenadas de textura com o redimensionamento definido
	noise_uv = UV * surface_noise_tiling;
	distort_uv = UV;
}

void fragment() {
	// é lida a textura de profundidade nativa da tela do godot 4
	float depth = texture(depth_texture, SCREEN_UV).r;
	
	// é convertida a profundidade do buffer de tela para o espaço de visualização linear
	vec3 normalized_device_coordinates = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view_space_position = INV_PROJECTION_MATRIX * vec4(normalized_device_coordinates, 1.0);
	view_space_position.xyz /= view_space_position.w;
	float screen_depth = -view_space_position.z;
	
	// é isolada a profundidade exata da superfície da água
	float surface_depth = FRAGCOORD.z;
	vec4 surface_view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, surface_depth, 1.0);
	surface_view_position.xyz /= surface_view_position.w;
	float water_depth_raw = -surface_view_position.z;
	
	// é calculada a distância física e é evitada a inversão matemática no renderizador opengl
	float depth_difference = max(screen_depth - water_depth_raw, 0.0);
	
	// é aplicada a lei de beer para criar o decaimento exponencial da luz na água
	float beer_depth = exp(-depth_difference * beer_factor);
	beer_depth = 1.0 - beer_depth;
	
	// é reconstruída a normal a partir das derivadas da profundidade para adaptar a espuma em encostas
	vec3 existing_normal = vec3(dFdx(beer_depth), dFdy(beer_depth), 0.0);
	float normal_dot = clamp(dot(existing_normal.xyz, view_normal), 0.0, 1.0);
	float current_foam_distance = mix(foam_max_distance, foam_min_distance, normal_dot);
	
	// é definido o limiar de corte do ruído baseando-se na proximidade com o terreno
	float foam_depth = clamp(beer_depth / current_foam_distance, 0.0, 1.0);
	float current_surface_noise_cutoff = foam_depth * surface_noise_cutoff;
	
	// é lida a textura de distorção para deslocar as ondas e quebrar o padrão linear
	vec4 distort_noise_sample = texture(distort_noise, distort_uv);
	vec2 distort_amount = (distort_noise_sample.xy * 2.0 - 1.0) * surface_distortion_amount;
	
	// são calculadas as novas coordenadas movendo-se no tempo
	vec2 final_noise_uv = vec2(
		(noise_uv.x + TIME * surface_noise_scroll.x) + distort_amount.x, 
		(noise_uv.y + TIME * surface_noise_scroll.y + distort_amount.y)
	);
	
	// é gerada a máscara rígida da espuma utilizando smoothstep para serrilhado suave
	float surface_noise_sample = texture(surface_noise, final_noise_uv).r;
	float surface_noise_amount = smoothstep(current_surface_noise_cutoff - SMOOTHSTEP_AA, current_surface_noise_cutoff + SMOOTHSTEP_AA, surface_noise_sample);
	
	// é interpolada a cor da água profunda com a água rasa
	float final_water_depth = clamp(beer_depth / depth_max_distance, 0.0, 1.0) * depth_factor;
	vec4 water_color = mix(depth_gradient_shallow, depth_gradient_deep, final_water_depth);

	// é finalizada a cor aplicando o corte matemático e mesclando com o oceano
	vec4 surface_noise_color = foam_color;
	surface_noise_color.a *= surface_noise_amount;
	vec4 final_color = alpha_blend(surface_noise_color, water_color);
	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}