class_name TerrainGenerator
extends Node3D

signal shard_collected(world_pos: Vector3)

const CHUNK_WIDTH := 42.0
const STEP_SIZE := 1.4
const HALF_DEPTH := 2.35
const TERRAIN_BOTTOM := -26.0
const GENERATE_AHEAD := 115.0
const CLEANUP_BEHIND := 65.0

var _next_chunk_x: float = -28.0
var _chunks: Array[Node3D] = []
var _terrain_mat: ShaderMaterial
var _shard_mesh: ArrayMesh
var _shard_mats: Array[ShaderMaterial] = []
var _next_milestone_x: float = 100.0

var active_shards: Array[Node3D] = []


func _ready() -> void:
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = load("res://shaders/terrain_stylized.gdshader")
	_shard_mesh = ProceduralMeshBuilder.create_crystal_shard(0.55)

	# Candy-vibrant gem palette (Magenta, Electric Cyan, Sunny Gold)
	_shard_mats = [
		ProceduralMeshBuilder.make_stylized_mat(Color(1.0, 0.22, 0.58), 0.15, 0.15, Color(1.0, 0.85, 0.95), 0.85, Color(1.0, 0.15, 0.55), 0.9),
		ProceduralMeshBuilder.make_stylized_mat(Color(0.05, 0.92, 0.96), 0.15, 0.15, Color(0.85, 1.0, 1.0), 0.85, Color(0.0, 0.85, 1.0), 0.9),
		ProceduralMeshBuilder.make_stylized_mat(Color(1.0, 0.84, 0.14), 0.25, 0.18, Color(1.0, 1.0, 0.8), 0.85, Color(1.0, 0.72, 0.05), 0.85),
	]

	reset_terrain()


func reset_terrain() -> void:
	for c in _chunks:
		if is_instance_valid(c):
			c.queue_free()
	_chunks.clear()
	active_shards.clear()
	_next_chunk_x = -28.0
	_next_milestone_x = 100.0
	update_around_x(0.0)


func update_around_x(player_x: float) -> void:
	while _next_chunk_x < player_x + GENERATE_AHEAD:
		_spawn_chunk(_next_chunk_x)
		_next_chunk_x += CHUNK_WIDTH

	while _chunks.size() > 0:
		var oldest := _chunks[0]
		if oldest.get_meta("end_x", 0.0) < player_x - CLEANUP_BEHIND:
			_chunks.pop_front()
			oldest.queue_free()
		else:
			break


## Smooth, handcrafted-feeling alien hills with progressive ramps & jumps
static func sample_height(x: float) -> float:
	if x < 12.0:
		# Flat friendly launchpad
		var blend := clampf((x - 4.0) / 8.0, 0.0, 1.0)
		blend = blend * blend * (3.0 - 2.0 * blend)
		return blend * (sin(x * 0.08) * 1.4)

	var difficulty := clampf(x / 550.0, 0.0, 1.0)
	var amp := lerpf(2.2, 5.4, difficulty)

	var h := sin(x * 0.075) * amp
	h += sin(x * 0.17 + 1.3) * (amp * 0.42)
	h += cos(x * 0.032) * 2.8
	# Occasional fun jump-kicker crests
	var kicker := maxf(0.0, sin(x * 0.052 - 0.6))
	h += pow(kicker, 3.0) * lerpf(1.4, 3.8, difficulty)
	return h


func _spawn_chunk(start_x: float) -> void:
	var chunk := Node3D.new()
	chunk.set_meta("end_x", start_x + CHUNK_WIDTH)
	add_child(chunk)
	_chunks.append(chunk)

	var steps := int(round(CHUNK_WIDTH / STEP_SIZE))
	var pts: Array[Vector2] = []
	for i in range(steps + 1):
		var px := start_x + float(i) * STEP_SIZE
		pts.append(Vector2(px, sample_height(px)))

	# Build 3D extruded mesh + collision face array
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col_faces := PackedVector3Array()

	var grass_c := Color(1.0, 0.0, 0.0)
	var lip_c := Color(0.55, 0.15, 0.0)
	var soil_top_c := Color(0.0, 0.1, 0.0)
	var soil_bot_c := Color(0.0, 1.0, 0.0)

	var add_tri := func(a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
		st.set_color(ca)
		st.add_vertex(a)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_color(cc)
		st.add_vertex(c)

	for i in range(steps):
		var p0 := pts[i]
		var p1 := pts[i + 1]

		var t0_f := Vector3(p0.x, p0.y, HALF_DEPTH)
		var t1_f := Vector3(p1.x, p1.y, HALF_DEPTH)
		var t0_b := Vector3(p0.x, p0.y, -HALF_DEPTH)
		var t1_b := Vector3(p1.x, p1.y, -HALF_DEPTH)

		# Chunky overhanging grass bevel lip on front (+Z)
		var lip0 := Vector3(p0.x, p0.y - 0.72, HALF_DEPTH + 0.18)
		var lip1 := Vector3(p1.x, p1.y - 0.72, HALF_DEPTH + 0.18)
		var sub0 := Vector3(p0.x, p0.y - 1.15, HALF_DEPTH)
		var sub1 := Vector3(p1.x, p1.y - 1.15, HALF_DEPTH)
		var bot0 := Vector3(p0.x, TERRAIN_BOTTOM, HALF_DEPTH)
		var bot1 := Vector3(p1.x, TERRAIN_BOTTOM, HALF_DEPTH)

		# 1. Top driving surface (+Y)
		add_tri.call(t0_b, grass_c, t1_b, grass_c, t1_f, grass_c)
		add_tri.call(t0_b, grass_c, t1_f, grass_c, t0_f, grass_c)

		# Add exact collision triangles for top driving deck
		col_faces.append(t0_b)
		col_faces.append(t1_b)
		col_faces.append(t1_f)
		col_faces.append(t0_b)
		col_faces.append(t1_f)
		col_faces.append(t0_f)

		# 2. Chunky grass overhang lip (Front)
		add_tri.call(t0_f, grass_c, t1_f, grass_c, lip1, grass_c)
		add_tri.call(t0_f, grass_c, lip1, grass_c, lip0, grass_c)

		# 3. Underside of grass bevel
		add_tri.call(lip0, lip_c, lip1, lip_c, sub1, soil_top_c)
		add_tri.call(lip0, lip_c, sub1, soil_top_c, sub0, soil_top_c)

		# 4. Subterranean cross-section wall
		add_tri.call(sub0, soil_top_c, sub1, soil_top_c, bot1, soil_bot_c)
		add_tri.call(sub0, soil_top_c, bot1, soil_bot_c, bot0, soil_bot_c)

	st.generate_normals()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = _terrain_mat
	chunk.add_child(mesh_inst)

	# Physics collider
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(col_faces)
	col.shape = shape
	body.add_child(col)
	chunk.add_child(body)

	# Spawn Star Shards & Cartoon Props
	if start_x >= 10.0:
		_populate_chunk_collectibles(chunk, start_x)
		_populate_chunk_props(chunk, start_x)


func _populate_chunk_collectibles(chunk: Node3D, start_x: float) -> void:
	# Place a juicy arc of 5-7 Star Shards per chunk
	var arc_start := start_x + 6.0
	var count := 6
	var mat_choice: ShaderMaterial = _shard_mats[int(abs(start_x / CHUNK_WIDTH)) % _shard_mats.size()]

	for i in range(count):
		var sx := arc_start + float(i) * 2.6
		var arc_lift := sin(float(i) / float(count - 1) * PI) * 2.1
		var sy := sample_height(sx) + 1.35 + arc_lift

		var shard := Node3D.new()
		shard.position = Vector3(sx, sy, 0.0)
		shard.set_meta("collected", false)
		shard.set_meta("base_y", sy)
		shard.set_meta("phase", float(i) * 0.7)

		var mi := MeshInstance3D.new()
		mi.mesh = _shard_mesh
		mi.material_override = mat_choice
		shard.add_child(mi)

		chunk.add_child(shard)
		active_shards.append(shard)


func _populate_chunk_props(chunk: Node3D, start_x: float) -> void:
	# Stylized alien mushrooms / glowing crystals along the rear edge (Z = -1.75)
	var cap_colors := [
		Color(1.0, 0.30, 0.45),
		Color(0.68, 0.30, 1.0),
		Color(0.10, 0.85, 0.95),
	]
	var stem_mat := ProceduralMeshBuilder.make_stylized_mat(Color(0.98, 0.95, 0.86), 0.05, 0.55)

	for i in range(3):
		var px := start_x + 5.0 + float(i) * 13.0
		var py := sample_height(px)
		var prop := Node3D.new()
		prop.position = Vector3(px, py - 0.05, -1.75)

		var stem := MeshInstance3D.new()
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.16
		stem_mesh.bottom_radius = 0.24
		stem_mesh.height = 0.75
		stem_mesh.radial_segments = 10
		stem.mesh = stem_mesh
		stem.material_override = stem_mat
		stem.position.y = 0.35
		prop.add_child(stem)

		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.55
		cap_mesh.height = 0.62
		cap_mesh.radial_segments = 12
		cap_mesh.rings = 6
		cap.mesh = cap_mesh
		var c: Color = cap_colors[(int(abs(px)) + i) % cap_colors.size()]
		cap.material_override = ProceduralMeshBuilder.make_stylized_mat(c, 0.1, 0.35, Color(1, 1, 1), 0.5, c, 0.25)
		cap.position.y = 0.78
		prop.add_child(cap)

		chunk.add_child(prop)

	# 100m Milestone Flag
	if _next_milestone_x >= start_x and _next_milestone_x < start_x + CHUNK_WIDTH:
		var mx := _next_milestone_x
		var my := sample_height(mx)
		var flag_root := Node3D.new()
		flag_root.position = Vector3(mx, my, -1.55)

		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.07
		pole_mesh.bottom_radius = 0.09
		pole_mesh.height = 3.2
		pole.mesh = pole_mesh
		pole.position.y = 1.6
		pole.material_override = ProceduralMeshBuilder.make_stylized_mat(Color(0.92, 0.94, 0.98), 0.6, 0.25)
		flag_root.add_child(pole)

		var banner := MeshInstance3D.new()
		banner.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(1.5, 0.8, 0.12), 0.04)
		banner.position = Vector3(0.75, 2.75, 0.0)
		banner.material_override = ProceduralMeshBuilder.make_stylized_mat(
			Color(1.0, 0.80, 0.12), 0.2, 0.25, Color(1, 1, 0.8), 0.7, Color(1.0, 0.65, 0.0), 0.45
		)
		flag_root.add_child(banner)

		chunk.add_child(flag_root)
		_next_milestone_x += 100.0
