class_name ProceduralMeshBuilder
extends RefCounted

const STYLIZED_SHADER_PATH := "res://shaders/stylized_pbr.gdshader"

static var _cached_shader: Shader = null


static func get_stylized_shader() -> Shader:
	if _cached_shader == null:
		_cached_shader = load(STYLIZED_SHADER_PATH)
	return _cached_shader


static func make_stylized_mat(
	color: Color,
	metallic: float = 0.2,
	roughness: float = 0.32,
	rim_color: Color = Color(0.7, 0.94, 1.0),
	rim_strength: float = 0.5,
	emission_color: Color = Color.BLACK,
	emission_energy: float = 0.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = get_stylized_shader()
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("metallic", metallic)
	mat.set_shader_parameter("roughness", roughness)
	mat.set_shader_parameter("rim_color", rim_color)
	mat.set_shader_parameter("rim_strength", rim_strength)
	mat.set_shader_parameter("emission_color", emission_color)
	mat.set_shader_parameter("emission_energy", emission_energy)
	return mat


## Builds a chunky, beveled 3D box with chamfered edges (no raw sharp cubes)
static func create_beveled_box(size: Vector3, bevel: float = 0.08) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx: float = maxf(size.x * 0.5 - bevel, 0.01)
	var hy: float = maxf(size.y * 0.5 - bevel, 0.01)
	var hz: float = maxf(size.z * 0.5 - bevel, 0.01)
	var ox: float = size.x * 0.5
	var oy: float = size.y * 0.5
	var oz: float = size.z * 0.5

	# Helper to add a quad (v0, v1, v2, v3 in CCW order)
	var add_quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(d)

	# 6 main faces
	# +Z (Front)
	add_quad.call(Vector3(-hx, hy, oz), Vector3(-hx, -hy, oz), Vector3(hx, -hy, oz), Vector3(hx, hy, oz))
	# -Z (Back)
	add_quad.call(Vector3(hx, hy, -oz), Vector3(hx, -hy, -oz), Vector3(-hx, -hy, -oz), Vector3(-hx, hy, -oz))
	# +Y (Top)
	add_quad.call(Vector3(-hx, oy, -hz), Vector3(-hx, oy, hz), Vector3(hx, oy, hz), Vector3(hx, oy, -hz))
	# -Y (Bottom)
	add_quad.call(Vector3(-hx, -oy, hz), Vector3(-hx, -oy, -hz), Vector3(hx, -oy, -hz), Vector3(hx, -oy, hz))
	# +X (Right)
	add_quad.call(Vector3(ox, hy, hz), Vector3(ox, -hy, hz), Vector3(ox, -hy, -hz), Vector3(ox, hy, -hz))
	# -X (Left)
	add_quad.call(Vector3(-ox, hy, -hz), Vector3(-ox, -hy, -hz), Vector3(-ox, -hy, hz), Vector3(-ox, hy, hz))

	# 12 edge bevel strips
	# Top-Front, Top-Back, Top-Right, Top-Left
	add_quad.call(Vector3(-hx, oy, hz), Vector3(-hx, hy, oz), Vector3(hx, hy, oz), Vector3(hx, oy, hz))
	add_quad.call(Vector3(hx, oy, -hz), Vector3(hx, hy, -oz), Vector3(-hx, hy, -oz), Vector3(-hx, oy, -hz))
	add_quad.call(Vector3(hx, oy, hz), Vector3(ox, hy, hz), Vector3(ox, hy, -hz), Vector3(hx, oy, -hz))
	add_quad.call(Vector3(-hx, oy, -hz), Vector3(-ox, hy, -hz), Vector3(-ox, hy, hz), Vector3(-hx, oy, hz))

	# Bottom-Front, Bottom-Back, Bottom-Right, Bottom-Left
	add_quad.call(Vector3(-hx, -hy, oz), Vector3(-hx, -oy, hz), Vector3(hx, -oy, hz), Vector3(hx, -hy, oz))
	add_quad.call(Vector3(hx, -hy, -oz), Vector3(hx, -oy, -hz), Vector3(-hx, -oy, -hz), Vector3(-hx, -hy, -oz))
	add_quad.call(Vector3(ox, -hy, hz), Vector3(hx, -oy, hz), Vector3(hx, -oy, -hz), Vector3(ox, -hy, -hz))
	add_quad.call(Vector3(-ox, -hy, -hz), Vector3(-hx, -oy, -hz), Vector3(-hx, -oy, hz), Vector3(-ox, -hy, hz))

	# Vertical side bevels (Front-Right, Front-Left, Back-Right, Back-Left)
	add_quad.call(Vector3(hx, hy, oz), Vector3(hx, -hy, oz), Vector3(ox, -hy, hz), Vector3(ox, hy, hz))
	add_quad.call(Vector3(-ox, hy, hz), Vector3(-ox, -hy, hz), Vector3(-hx, -hy, oz), Vector3(-hx, hy, oz))
	add_quad.call(Vector3(ox, hy, -hz), Vector3(ox, -hy, -hz), Vector3(hx, -hy, -oz), Vector3(hx, hy, -oz))
	add_quad.call(Vector3(-hx, hy, -oz), Vector3(-hx, -hy, -oz), Vector3(-ox, -hy, -hz), Vector3(-ox, hy, -hz))

	# 8 corner triangles
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var px := Vector3(sx * ox, sy * hy, sz * hz)
				var py := Vector3(sx * hx, sy * oy, sz * hz)
				var pz := Vector3(sx * hx, sy * hy, sz * oz)
				if sx * sy * sz > 0.0:
					st.add_vertex(px)
					st.add_vertex(py)
					st.add_vertex(pz)
				else:
					st.add_vertex(px)
					st.add_vertex(pz)
					st.add_vertex(py)

	st.generate_normals()
	return st.commit()


## Builds a chunky off-road wheel Node3D with rubber treads, recessed rim, and star hubcap
static func create_wheel_visual(radius: float = 0.56, width: float = 0.44) -> Node3D:
	var root := Node3D.new()

	var tire_mat := make_stylized_mat(Color(0.15, 0.16, 0.22), 0.12, 0.65, Color(0.55, 0.68, 0.9), 0.35)
	var rim_mat := make_stylized_mat(Color(1.0, 0.82, 0.25), 0.45, 0.25, Color(1.0, 0.96, 0.78), 0.65)
	var cap_mat := make_stylized_mat(Color(0.22, 0.85, 0.98), 0.3, 0.2, Color(0.7, 1.0, 1.0), 0.7, Color(0.0, 0.75, 1.0), 0.55)

	# Main rubber drum (rotated so cylinder axis aligns with Z)
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = radius * 0.92
	tire_mesh.bottom_radius = radius * 0.92
	tire_mesh.height = width
	tire_mesh.radial_segments = 20

	var tire := MeshInstance3D.new()
	tire.mesh = tire_mesh
	tire.material_override = tire_mat
	tire.rotation_degrees.x = 90.0
	root.add_child(tire)

	# Chunky rubber treads around circumference
	var tread_mesh := create_beveled_box(Vector3(0.16, 0.10, width * 0.92), 0.025)
	var tread_count := 10
	for i in range(tread_count):
		var angle := float(i) / float(tread_count) * TAU
		var tread := MeshInstance3D.new()
		tread.mesh = tread_mesh
		tread.material_override = tire_mat
		tread.position = Vector3(cos(angle) * (radius * 0.93), sin(angle) * (radius * 0.93), 0.0)
		tread.rotation.z = angle + PI * 0.5
		root.add_child(tread)

	# Bright golden rim disc
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius * 0.58
	rim_mesh.bottom_radius = radius * 0.58
	rim_mesh.height = width * 1.06
	rim_mesh.radial_segments = 16

	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.material_override = rim_mat
	rim.rotation_degrees.x = 90.0
	root.add_child(rim)

	# 4 stylized spokes so wheel spin is unmistakably visible
	var spoke_mesh := create_beveled_box(Vector3(radius * 0.96, 0.11, width * 1.12), 0.02)
	for s in range(2):
		var spoke := MeshInstance3D.new()
		spoke.mesh = spoke_mesh
		spoke.material_override = tire_mat
		spoke.rotation.z = float(s) * PI * 0.5
		root.add_child(spoke)

	# Glowing cyan center bolt cap
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = radius * 0.22
	cap_mesh.bottom_radius = radius * 0.22
	cap_mesh.height = width * 1.18
	cap_mesh.radial_segments = 12

	var cap := MeshInstance3D.new()
	cap.mesh = cap_mesh
	cap.material_override = cap_mat
	cap.rotation_degrees.x = 90.0
	root.add_child(cap)

	return root


## Builds a faceted glowing Star Shard crystal mesh
static func create_crystal_shard(scale_factor: float = 0.52) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top := Vector3(0.0, 1.25 * scale_factor, 0.0)
	var bottom := Vector3(0.0, -1.1 * scale_factor, 0.0)
	var mid_pts: Array[Vector3] = []
	var sides := 6
	for i in range(sides):
		var a := float(i) / float(sides) * TAU
		mid_pts.append(Vector3(cos(a) * 0.58 * scale_factor, 0.08 * scale_factor, sin(a) * 0.58 * scale_factor))

	for i in range(sides):
		var p1: Vector3 = mid_pts[i]
		var p2: Vector3 = mid_pts[(i + 1) % sides]
		# Upper facet
		st.add_vertex(top)
		st.add_vertex(p2)
		st.add_vertex(p1)
		# Lower facet
		st.add_vertex(bottom)
		st.add_vertex(p1)
		st.add_vertex(p2)

	st.generate_normals()
	return st.commit()
