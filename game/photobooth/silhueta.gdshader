shader_type canvas_item;

uniform bool is_silhouette = true;
uniform vec4 silhouette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	if (is_silhouette) {
		// Mantém o desenho (alpha), mas pinta tudo de preto
		COLOR = vec4(silhouette_color.rgb, tex_color.a);
	} else {
		// Mostra a foto colorida normal
		COLOR = tex_color;
	}
}