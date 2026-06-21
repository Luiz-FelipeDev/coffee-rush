extends MeshInstance3D

signal terrain_generated

@export var noise_seed: int = 12345
@export var island_size: float = 300.0
@export var height_multiplier: float = 30.0
@export var noise_scale: float = 1.0
@export var sand_level: float = 8.0

# são exportadas as variáveis de cor para receberem os dados do bioma
@export var grass_color: Color = Color("3b7d22")
@export var sand_color: Color = Color("d4c38e")

func generate_terrain() -> void:
	# é instanciada a malha plana base para o terreno
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(island_size, island_size)
	
	# é definida a resolução da malha
	plane_mesh.subdivide_width = int(island_size)
	plane_mesh.subdivide_depth = int(island_size)

	# é utilizado o surface tool para manipulação da geometria
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0)

	# é criado o mesh data tool para leitura e escrita nos vértices
	var array_mesh: ArrayMesh = surface_tool.commit()
	var mesh_data_tool: MeshDataTool = MeshDataTool.new()
	mesh_data_tool.create_from_surface(array_mesh, 0)

	# é configurado o algoritmo de ruído simplex
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	# é calculado o raio máximo para a máscara circular
	var max_radius: float = island_size / 2.0

	# é feita a iteração sobre todos os vértices da malha para alterar apenas a altura
	for i: int in range(mesh_data_tool.get_vertex_count()):
		var vertex: Vector3 = mesh_data_tool.get_vertex(i)

		# é calculada a distância bidimensional do vértice até o centro
		var distance_to_center: float = Vector2(vertex.x, vertex.z).length()

		# é criada a máscara circular garantindo o tipo float
		var mask: float = float(clampf(1.0 - (distance_to_center / max_radius), 0.0, 1.0))
		mask = float(smoothstep(0.0, 1.0, mask))

		# é extraído e normalizado o valor do ruído
		var noise_value: float = float(noise.get_noise_2d(vertex.x * noise_scale, vertex.z * noise_scale))
		noise_value = (noise_value + 1.0) / 2.0

		# é definida a elevação final do vértice
		vertex.y = noise_value * mask * height_multiplier

		# é aplicada a modificação estrutural ao vértice
		mesh_data_tool.set_vertex(i, vertex)

	# é limpa a malha e aplicada a nova superfície
	array_mesh.clear_surfaces()
	mesh_data_tool.commit_to_surface(array_mesh)

	# são geradas as normais para iluminação correta
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_mesh, 0)
	surface_tool.generate_normals()

	self.mesh = surface_tool.commit()

	# é criado um shader customizado para gerar o corte duro no fragment shader
	var shader: Shader = Shader.new()
	shader.code = """
	shader_type spatial;
	
	uniform float sand_level = 10.0;
	uniform vec3 grass_color : source_color; 
	uniform vec3 sand_color : source_color; 
	
	varying float local_y;
	
	void vertex() {
		local_y = VERTEX.y;
	}
	
	void fragment() {
		if (local_y < sand_level) {
			ALBEDO = sand_color;
		} else {
			ALBEDO = grass_color;
		}
	}
	"""
	
	# é instanciado o material e aplicados os parâmetros dinâmicos incluindo as cores do bioma
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sand_level", sand_level)
	material.set_shader_parameter("grass_color", grass_color)
	material.set_shader_parameter("sand_color", sand_color)
	
	self.material_override = material

	# é removida a colisão física anterior caso o terreno seja recriado
	for child: Node in get_children():
		if child is StaticBody3D:
			child.queue_free()

	# é gerada a malha de colisão estática atualizada
	self.create_trimesh_collision()

	# é notificado ao sistema que o terreno está pronto
	terrain_generated.emit()
