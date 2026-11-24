class_name StarforgeRover
extends RigidBody3D

signal trick_performed(label_text: String, bonus_points: int, accent_color: Color)
signal hard_impact(intensity: float)
signal rover_crashed(reason: String)

# Suspension & Drive Tuning
@export var wheel_radius: float = 0.56
@export var suspension_rest: float = 0.92
@export var spring_stiffness: float = 115.0
@export var spring_damping: float = 13.5
@export var drive_force: float = 42.0
@export var max_speed: float = 29.0
@export var air_pitch_torque: float = 28.0
@export var boost_force: float = 46.0

# Inputs (driven by HUD touch controls or keyboard)
var input_gas: bool = false
var input_brake: bool = false
var input_boost: bool = false

# Live telemetry
var speed_kmh: float = 0.0
var boost_energy: float = 100.0
var battery_energy: float = 100.0
var is_grounded: bool = false
var is_dead: bool = false
var perfect_boost_timer: float = 0.0

# Internal state
var _wheel_mounts: Array[Vector3] = [
	Vector3(-1.12, -0.18, 0.0), # Rear wheel
	Vector3(1.12, -0.18, 0.0),  # Front wheel
]
var _wheel_rays: Array[RayCast3D] = []
var _wheel_visuals: Array[Node3D] = []
var _strut_visuals: Array[MeshInstance3D] = []
var _prev_compression: Array[float] = [0.0, 0.0]

var _cockpit_pilot: Node3D
var _reactor_mesh: MeshInstance3D
var _thruster_flame: MeshInstance3D
var _dust_particles: GPUParticles3D
var _boost_particles: GPUParticles3D
var _spark_particles: GPUParticles3D

# Flip & Landing detection
var _air_time: float = 0.0
var _accumulated_flip_rad: float = 0.0
var _last_angle_z: float = 0.0
var _upside_down_timer: float = 0.0
var _last_ground_normal: Vector3 = Vector3.UP


func _ready() -> void:
	mass = 2.8
	linear_damp = 0.12
	angular_damp = 1.6
	can_sleep = false
	# Strict 2.5D physics lock (never falls into or out of the screen!)
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true

	_build_collision_shapes()
	_build_rover_visuals()
	_build_particles()
	_last_angle_z = rotation.z


func _build_collision_shapes() -> void:
	# Main chassis box collider
	var body_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.85, 0.72, 1.25)
	body_col.shape = box
	body_col.position = Vector3(0.0, 0.12, 0.0)
	add_child(body_col)

	# Cockpit dome collider (protects/detects roof flips)
	var dome_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.56
	dome_col.shape = sphere
	dome_col.position = Vector3(0.18, 0.68, 0.0)
	add_child(dome_col)


func _build_rover_visuals() -> void:
	var visual_root := Node3D.new()
	add_child(visual_root)

	var body_mat := ProceduralMeshBuilder.make_stylized_mat(Color(1.0, 0.62, 0.08), 0.25, 0.26, Color(1.0, 0.94, 0.75), 0.6)
	var trim_mat := ProceduralMeshBuilder.make_stylized_mat(Color(0.98, 0.96, 0.90), 0.18, 0.30, Color(0.85, 0.95, 1.0), 0.5)
	var frame_mat := ProceduralMeshBuilder.make_stylized_mat(Color(0.18, 0.20, 0.28), 0.45, 0.40, Color(0.6, 0.78, 1.0), 0.4)
	var glass_mat := ProceduralMeshBuilder.make_stylized_mat(Color(0.22, 0.78, 1.0), 0.1, 0.08, Color(0.9, 1.0, 1.0), 0.95, Color(0.05, 0.45, 0.75), 0.28)
	var coral_mat := ProceduralMeshBuilder.make_stylized_mat(Color(1.0, 0.28, 0.42), 0.35, 0.25, Color(1.0, 0.85, 0.9), 0.65)
	var core_mat := ProceduralMeshBuilder.make_stylized_mat(Color(0.05, 0.96, 0.88), 0.1, 0.15, Color(0.8, 1.0, 1.0), 0.9, Color(0.0, 0.95, 0.85), 1.65)
	var spring_mat := ProceduralMeshBuilder.make_stylized_mat(Color(0.08, 0.88, 0.98), 0.3, 0.25, Color(0.8, 1.0, 1.0), 0.6, Color(0.0, 0.65, 0.85), 0.45)

	# 1. Chunky Beveled Chassis Core
	var chassis := MeshInstance3D.new()
	chassis.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(2.85, 0.58, 1.18), 0.12)
	chassis.material_override = body_mat
	chassis.position = Vector3(0.0, 0.14, 0.0)
	visual_root.add_child(chassis)

	# 2. Cream-White Top Deck & Bumper Guards
	var deck := MeshInstance3D.new()
	deck.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(2.45, 0.16, 1.04), 0.05)
	deck.material_override = trim_mat
	deck.position = Vector3(0.0, 0.45, 0.0)
	visual_root.add_child(deck)

	var front_bumper := MeshInstance3D.new()
	front_bumper.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(0.32, 0.38, 1.24), 0.07)
	front_bumper.material_override = frame_mat
	front_bumper.position = Vector3(1.42, 0.08, 0.0)
	visual_root.add_child(front_bumper)

	# Glowing Headlight
	var headlight := MeshInstance3D.new()
	headlight.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(0.14, 0.22, 0.62), 0.04)
	headlight.material_override = ProceduralMeshBuilder.make_stylized_mat(
		Color(1.0, 0.98, 0.78), 0.1, 0.1, Color(1, 1, 1), 0.8, Color(1.0, 0.95, 0.65), 1.6
	)
	headlight.position = Vector3(1.56, 0.18, 0.0)
	visual_root.add_child(headlight)

	# 3. Glossy Bubble Cockpit + Cute Bobbing Pilot Helmet
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.56
	dome_mesh.height = 0.92
	dome_mesh.radial_segments = 18
	dome_mesh.rings = 10
	dome.mesh = dome_mesh
	dome.material_override = glass_mat
	dome.position = Vector3(0.22, 0.72, 0.0)
	visual_root.add_child(dome)

	_cockpit_pilot = Node3D.new()
	_cockpit_pilot.position = Vector3(0.20, 0.66, 0.0)
	visual_root.add_child(_cockpit_pilot)

	var helmet := MeshInstance3D.new()
	var h_mesh := SphereMesh.new()
	h_mesh.radius = 0.24
	h_mesh.height = 0.46
	helmet.mesh = h_mesh
	helmet.material_override = trim_mat
	_cockpit_pilot.add_child(helmet)

	var visor := MeshInstance3D.new()
	visor.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(0.18, 0.16, 0.28), 0.04)
	visor.material_override = frame_mat
	visor.position = Vector3(0.14, 0.02, 0.0)
	_cockpit_pilot.add_child(visor)

	# 4. Glowing Plasma Reactor Core (behind cockpit)
	var reactor_cage := MeshInstance3D.new()
	reactor_cage.mesh = ProceduralMeshBuilder.create_beveled_box(Vector3(0.68, 0.52, 0.88), 0.08)
	reactor_cage.material_override = frame_mat
	reactor_cage.position = Vector3(-0.72, 0.56, 0.0)
	visual_root.add_child(reactor_cage)

	_reactor_mesh = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.32
	orb.height = 0.64
	_reactor_mesh.mesh = orb
	_reactor_mesh.material_override = core_mat
	_reactor_mesh.position = Vector3(-0.72, 0.64, 0.0)
	visual_root.add_child(_reactor_mesh)

	# 5. Rear Ion Thruster Nozzle + Dynamic Plasma Flame Cone
	var nozzle := MeshInstance3D.new()
	var nozzle_mesh := CylinderMesh.new()
	nozzle_mesh.top_radius = 0.22
	nozzle_mesh.bottom_radius = 0.38
	nozzle_mesh.height = 0.58
	nozzle_mesh.radial_segments = 14
	nozzle.mesh = nozzle_mesh
	nozzle.material_override = coral_mat
	nozzle.position = Vector3(-1.58, 0.26, 0.0)
	nozzle.rotation_degrees.z = -90.0
	visual_root.add_child(nozzle)

	_thruster_flame = MeshInstance3D.new()
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.02
	flame_mesh.bottom_radius = 0.30
	flame_mesh.height = 1.45
	flame_mesh.radial_segments = 10
	_thruster_flame.mesh = flame_mesh
	_thruster_flame.material_override = ProceduralMeshBuilder.make_stylized_mat(
		Color(0.25, 0.95, 1.0), 0.0, 0.1, Color(1, 1, 1), 1.0, Color(0.15, 0.85, 1.0), 3.2
	)
	_thruster_flame.position = Vector3(-2.45, 0.26, 0.0)
	_thruster_flame.rotation_degrees.z = 90.0
	_thruster_flame.visible = false
	visual_root.add_child(_thruster_flame)

	# 6. Suspension Raycasts, Visual Struts, and Chunky Wheels
	for i in range(_wheel_mounts.size()):
		var mount := _wheel_mounts[i]

		var ray := RayCast3D.new()
		ray.position = mount
		ray.target_position = Vector3(0.0, -(suspension_rest + wheel_radius), 0.0)
		ray.enabled = true
		ray.exclude_parent = true
		add_child(ray)
		_wheel_rays.append(ray)

		# Glowing hydraulic strut
		var strut := MeshInstance3D.new()
		var strut_mesh := CylinderMesh.new()
		strut_mesh.top_radius = 0.11
		strut_mesh.bottom_radius = 0.11
		strut_mesh.height = 1.0
		strut.mesh = strut_mesh
		strut.material_override = spring_mat
		strut.position = mount + Vector3(0.0, -0.35, 0.0)
		add_child(strut)
		_strut_visuals.append(strut)

		# Visual Wheel
		var w_vis := ProceduralMeshBuilder.create_wheel_visual(wheel_radius, 0.56)
		w_vis.position = mount + Vector3(0.0, -suspension_rest, 0.0)
		add_child(w_vis)
		_wheel_visuals.append(w_vis)


func _build_particles() -> void:
	# 1. Wheel Dust Plumes
	_dust_particles = GPUParticles3D.new()
	_dust_particles.amount = 24
	_dust_particles.lifetime = 0.55
	_dust_particles.emitting = false
	var dust_pmat := ParticleProcessMaterial.new()
	dust_pmat.direction = Vector3(-1.0, 0.65, 0.0)
	dust_pmat.spread = 28.0
	dust_pmat.initial_velocity_min = 2.0
	dust_pmat.initial_velocity_max = 5.5
	dust_pmat.gravity = Vector3(0.0, -4.0, 0.0)
	dust_pmat.scale_min = 0.25
	dust_pmat.scale_max = 0.65
	_dust_particles.process_material = dust_pmat
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.22
	dust_mesh.height = 0.44
	dust_mesh.radial_segments = 8
	dust_mesh.rings = 4
	dust_mesh.material = ProceduralMeshBuilder.make_stylized_mat(Color(0.95, 0.84, 0.62), 0.0, 0.9, Color(1, 1, 1), 0.2)
	_dust_particles.draw_pass_1 = dust_mesh
	_dust_particles.position = Vector3(-1.12, -0.85, 0.0)
	add_child(_dust_particles)

	# 2. Thruster Plasma / Smoke Trail
	_boost_particles = GPUParticles3D.new()
	_boost_particles.amount = 34
	_boost_particles.lifetime = 0.38
	_boost_particles.emitting = false
	var boost_pmat := ParticleProcessMaterial.new()
	boost_pmat.direction = Vector3(-1.0, 0.0, 0.0)
	boost_pmat.spread = 16.0
	boost_pmat.initial_velocity_min = 8.0
	boost_pmat.initial_velocity_max = 15.0
	boost_pmat.gravity = Vector3(0.0, 1.5, 0.0)
	boost_pmat.scale_min = 0.25
	boost_pmat.scale_max = 0.7
	_boost_particles.process_material = boost_pmat
	var boost_mesh := SphereMesh.new()
	boost_mesh.radius = 0.24
	boost_mesh.height = 0.48
	boost_mesh.radial_segments = 8
	boost_mesh.rings = 4
	boost_mesh.material = ProceduralMeshBuilder.make_stylized_mat(
		Color(1.0, 0.72, 0.15), 0.0, 0.2, Color(1, 1, 1), 0.8, Color(1.0, 0.45, 0.08), 2.5
	)
	_boost_particles.draw_pass_1 = boost_mesh
	_boost_particles.position = Vector3(-1.95, 0.26, 0.0)
	add_child(_boost_particles)

	# 3. Impact Sparks
	_spark_particles = GPUParticles3D.new()
	_spark_particles.amount = 18
	_spark_particles.lifetime = 0.35
	_spark_particles.one_shot = true
	_spark_particles.explosiveness = 0.9
	_spark_particles.emitting = false
	var spark_pmat := ParticleProcessMaterial.new()
	spark_pmat.direction = Vector3(0.0, 1.0, 0.0)
	spark_pmat.spread = 75.0
	spark_pmat.initial_velocity_min = 5.0
	spark_pmat.initial_velocity_max = 12.0
	spark_pmat.gravity = Vector3(0.0, -16.0, 0.0)
	_spark_particles.process_material = spark_pmat
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.14, 0.14, 0.14)
	spark_mesh.material = ProceduralMeshBuilder.make_stylized_mat(
		Color(1.0, 0.92, 0.25), 0.0, 0.1, Color(1, 1, 1), 1.0, Color(1.0, 0.82, 0.12), 3.0
	)
	_spark_particles.draw_pass_1 = spark_mesh
	add_child(_spark_particles)


func reset_rover(spawn_pos: Vector3) -> void:
	is_dead = false
	boost_energy = 100.0
	battery_energy = 100.0
	perfect_boost_timer = 0.0
	_air_time = 0.0
	_accumulated_flip_rad = 0.0
	_upside_down_timer = 0.0
	_prev_compression = [0.0, 0.0]

	global_position = spawn_pos
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_angle_z = 0.0


func _physics_process(delta: float) -> void:
	if is_dead:
		_thruster_flame.visible = false
		_boost_particles.emitting = false
		_dust_particles.emitting = false
		return

	var gas := input_gas or Input.is_action_pressed("move_right")
	var brake := input_brake or Input.is_action_pressed("move_left")
	var boosting := (input_boost or Input.is_action_pressed("boost")) and boost_energy > 2.0 and battery_energy > 0.0

	var throttle := 0.0
	if gas:
		throttle += 1.0
	if brake:
		throttle -= 1.0

	# Battery drain (slow and fair; shards & flips keep you alive!)
	var drain := 1.45 + (absf(throttle) * 0.65) + (3.0 if boosting else 0.0)
	battery_energy = maxf(0.0, battery_energy - drain * delta)

	if perfect_boost_timer > 0.0:
		perfect_boost_timer -= delta

	var grounded_wheels := 0
	var avg_normal := Vector3.ZERO
	var max_compression_vel := 0.0

	# 1. Custom Raycast Spring-Damper Suspension
	for i in range(_wheel_rays.size()):
		var ray := _wheel_rays[i]
		ray.force_raycast_update()
		var mount := _wheel_mounts[i]
		var w_vis := _wheel_visuals[i]
		var strut := _strut_visuals[i]

		if ray.is_colliding():
			grounded_wheels += 1
			var hit_pt := ray.get_collision_point()
			var hit_normal := ray.get_collision_normal()
			avg_normal += hit_normal

			var ray_origin := global_transform * mount
			var dist := ray_origin.distance_to(hit_pt)
			var compression := clampf((suspension_rest + wheel_radius) - dist, 0.0, suspension_rest)
			var comp_vel := (compression - _prev_compression[i]) / maxf(delta, 0.001)
			_prev_compression[i] = compression
			max_compression_vel = maxf(max_compression_vel, comp_vel)

			# Spring + Damper Force along Rover Up axis
			var spring_f := compression * spring_stiffness + comp_vel * spring_damping
			spring_f = maxf(0.0, spring_f)
			var force_vec := global_transform.basis.y * spring_f
			var offset := ray_origin - global_position
			apply_force(force_vec, offset)

			# Drive Force along terrain tangent
			if battery_energy > 0.0 and absf(throttle) > 0.01:
				var tangent := Vector3(hit_normal.y, -hit_normal.x, 0.0).normalized()
				var current_fwd := linear_velocity.dot(tangent)
				var speed_cap := max_speed * (1.28 if perfect_boost_timer > 0.0 else 1.0)
				if (throttle > 0.0 and current_fwd < speed_cap) or (throttle < 0.0 and current_fwd > -speed_cap * 0.65):
					apply_force(tangent * throttle * drive_force, offset)

			# Position visual wheel cleanly on surface
			var local_y := -(dist - wheel_radius)
			w_vis.position = mount + Vector3(0.0, local_y, 0.0)
			strut.scale.y = maxf(0.2, absf(local_y))
			strut.position = mount + Vector3(0.0, local_y * 0.5, 0.0)
		else:
			_prev_compression[i] = lerpf(_prev_compression[i], 0.0, delta * 8.0)
			w_vis.position = w_vis.position.lerp(mount + Vector3(0.0, -suspension_rest, 0.0), delta * 12.0)
			strut.scale.y = suspension_rest
			strut.position = mount + Vector3(0.0, -suspension_rest * 0.5, 0.0)

		# Spin wheels smoothly
		var spin_rate := -linear_velocity.x / maxf(wheel_radius, 0.1)
		if grounded_wheels == 0 and absf(throttle) > 0.1:
			spin_rate = -throttle * 18.0
		w_vis.rotation.z += spin_rate * delta

	var was_grounded := is_grounded
	is_grounded = grounded_wheels > 0

	if is_grounded:
		_last_ground_normal = (avg_normal / float(grounded_wheels)).normalized()

	# 2. Landing Detection (Perfect Landing + Impact Juice)
	if is_grounded and not was_grounded and _air_time > 0.42:
		var alignment := global_transform.basis.y.dot(_last_ground_normal)
		var impact_mag := clampf(max_compression_vel / 12.0, 0.25, 1.0)
		hard_impact.emit(impact_mag)

		if alignment > 0.94: # Within ~19 degrees of slope parallel!
			perfect_boost_timer = 1.65
			boost_energy = minf(100.0, boost_energy + 28.0)
			battery_energy = minf(100.0, battery_energy + 10.0)
			apply_central_impulse(global_transform.basis.x * 16.0)
			_spark_particles.restart()
			trick_performed.emit("PERFECT LANDING! +150", 150, Color(1.0, 0.86, 0.18))

		_air_time = 0.0
		_accumulated_flip_rad = 0.0

	# 3. Mid-Air Pitch Control & Flip Detection
	if not is_grounded:
		_air_time += delta
		# Gas pitches nose UP (backflip); Brake pitches nose DOWN (frontflip)
		if absf(throttle) > 0.01:
			var target_torque := throttle * air_pitch_torque
			if absf(angular_velocity.z) < 6.8 or signf(target_torque) != signf(angular_velocity.z):
				apply_torque(Vector3(0.0, 0.0, target_torque))

		var angle_delta := wrapf(rotation.z - _last_angle_z, -PI, PI)
		_accumulated_flip_rad += angle_delta
		if absf(_accumulated_flip_rad) >= deg_to_rad(310.0):
			var is_backflip := _accumulated_flip_rad > 0.0
			_accumulated_flip_rad = 0.0
			boost_energy = minf(100.0, boost_energy + 35.0)
			battery_energy = minf(100.0, battery_energy + 12.0)
			var label := "BACKFLIP! +250" if is_backflip else "FRONTFLIP! +250"
			trick_performed.emit(label, 250, Color(0.15, 0.95, 1.0))
	else:
		_air_time = 0.0
		_accumulated_flip_rad = 0.0

	_last_angle_z = rotation.z

	# 4. Ion Thruster Boost
	if boosting:
		boost_energy = maxf(0.0, boost_energy - 36.0 * delta)
		apply_central_force(global_transform.basis.x * boost_force)
		_thruster_flame.visible = true
		_thruster_flame.scale = Vector3(1.0, randf_range(0.85, 1.32), 1.0)
		_boost_particles.emitting = true
	else:
		boost_energy = minf(100.0, boost_energy + 12.5 * delta)
		_thruster_flame.visible = false
		_boost_particles.emitting = false

	# 5. Dust Particles & Cute Pilot Bobbing
	_dust_particles.emitting = is_grounded and (absf(linear_velocity.x) > 3.5 or absf(throttle) > 0.1)
	if is_instance_valid(_cockpit_pilot):
		var target_pitch := clampf(-throttle * 0.22, -0.25, 0.25)
		_cockpit_pilot.rotation.z = lerpf(_cockpit_pilot.rotation.z, target_pitch, delta * 10.0)
	if is_instance_valid(_reactor_mesh):
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08 * (boost_energy / 100.0)
		_reactor_mesh.scale = Vector3.ONE * pulse

	# 6. Telemetry & Crash/Stall Detection
	speed_kmh = absf(linear_velocity.x) * 3.6

	var is_inverted := global_transform.basis.y.y < -0.55
	if is_inverted and linear_velocity.length() < 2.2:
		_upside_down_timer += delta
		if _upside_down_timer > 1.85:
			is_dead = true
			rover_crashed.emit("ROVER FLIPPED!")
	else:
		_upside_down_timer = 0.0

	if battery_energy <= 0.0 and linear_velocity.length() < 1.2:
		is_dead = true
		rover_crashed.emit("BATTERY DEPLETED!")
