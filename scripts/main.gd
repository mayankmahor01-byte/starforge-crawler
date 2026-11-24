extends Node3D

var _rover: StarforgeRover
var _terrain: TerrainGenerator
var _audio: ProceduralAudioManager
var _hud: GameHUD
var _camera: Camera3D
var _parallax_root: Node3D
var _sun_light: DirectionalLight3D

# Score & Combo state
var _score: int = 0
var _max_distance: int = 0
var _combo_count: int = 0
var _combo_timer: float = 0.0

# Camera Juice state
var _shake_trauma: float = 0.0
var _cam_base_offset := Vector3(3.6, 3.2, 16.5)


func _ready() -> void:
	_setup_environment()
	_setup_parallax_backdrop()

	_terrain = TerrainGenerator.new()
	add_child(_terrain)

	_rover = StarforgeRover.new()
	add_child(_rover)
	_rover.trick_performed.connect(_on_trick_performed)
	_rover.hard_impact.connect(_on_hard_impact)
	_rover.rover_crashed.connect(_on_rover_crashed)

	_audio = ProceduralAudioManager.new()
	add_child(_audio)

	_camera = Camera3D.new()
	_camera.fov = 34.0
	_camera.near = 0.2
	_camera.far = 300.0
	add_child(_camera)
	_camera.make_current()

	_hud = GameHUD.new()
	add_child(_hud)
	_hud.gas_changed.connect(func(p: bool): _rover.input_gas = p)
	_hud.brake_changed.connect(func(p: bool): _rover.input_brake = p)
	_hud.boost_changed.connect(func(p: bool): _rover.input_boost = p)
	_hud.restart_requested.connect(_restart_run)
	_hud.button_popped.connect(_audio.play_ui_pop)

	_restart_run()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	# Vibrant Sunny Cartoon Sky (PVZ3 / Angry Birds 2 vibe)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.11, 0.58, 0.96)
	sky_mat.sky_horizon_color = Color(1.0, 0.78, 0.48)
	sky_mat.ground_bottom_color = Color(0.24, 0.16, 0.28)
	sky_mat.ground_horizon_color = Color(0.96, 0.68, 0.44)
	sky_mat.sun_angle_max = 18.0

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	# ACES Filmic Tone Mapping + Warm Glow/Bloom
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.22
	env.glow_hdr_threshold = 0.92
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.78, 0.98)
	env.ambient_light_energy = 0.55

	# Subtle warm atmospheric fog for depth
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.80, 0.64)
	env.fog_density = 0.0045

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Warm Sunset Key Light
	_sun_light = DirectionalLight3D.new()
	_sun_light.light_color = Color(1.0, 0.94, 0.80)
	_sun_light.light_energy = 1.45
	_sun_light.shadow_enabled = true
	_sun_light.rotation_degrees = Vector3(-36.0, -28.0, 0.0)
	add_child(_sun_light)

	# Cool Cyan Rim Fill Light
	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Color(0.35, 0.85, 1.0)
	rim_light.light_energy = 0.45
	rim_light.rotation_degrees = Vector3(18.0, 145.0, 0.0)
	add_child(rim_light)


func _setup_parallax_backdrop() -> void:
	_parallax_root = Node3D.new()
	add_child(_parallax_root)

	# Distant stylized rounded hills & floating alien rings (follows camera X with parallax)
	var hill_mat_near := ProceduralMeshBuilder.make_stylized_mat(Color(0.24, 0.76, 0.68), 0.0, 0.85, Color(0.7, 1.0, 0.95), 0.25)
	var hill_mat_far := ProceduralMeshBuilder.make_stylized_mat(Color(0.42, 0.46, 0.86), 0.0, 0.9, Color(0.85, 0.85, 1.0), 0.2)
	var cloud_mat := ProceduralMeshBuilder.make_stylized_mat(Color(1.0, 0.97, 0.92), 0.0, 0.8, Color(1, 1, 1), 0.35)

	for i in range(-4, 12):
		# Far lavender mountain mounds
		var far_m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 22.0 + float((i * 7) % 9)
		sm.height = sm.radius * 1.4
		sm.radial_segments = 14
		sm.rings = 8
		far_m.mesh = sm
		far_m.material_override = hill_mat_far
		far_m.position = Vector3(float(i) * 34.0, -14.0, -52.0)
		_parallax_root.add_child(far_m)

		# Mid teal hills
		var near_m := MeshInstance3D.new()
		var nm := SphereMesh.new()
		nm.radius = 15.0 + float((i * 5) % 6)
		nm.height = nm.radius * 1.25
		nm.radial_segments = 14
		nm.rings = 8
		near_m.mesh = nm
		near_m.material_override = hill_mat_near
		near_m.position = Vector3(float(i) * 24.0 + 8.0, -11.5, -26.0)
		_parallax_root.add_child(near_m)

		# Puffy stylized clouds
		var cloud := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 4.2
		cm.height = 4.4
		cm.radial_segments = 12
		cm.rings = 6
		cloud.mesh = cm
		cloud.scale = Vector3(2.2, 0.85, 0.9)
		cloud.material_override = cloud_mat
		cloud.position = Vector3(float(i) * 28.0 + 4.0, 16.0 + float((i * 3) % 5), -36.0)
		_parallax_root.add_child(cloud)


func _restart_run() -> void:
	_score = 0
	_max_distance = 0
	_combo_count = 0
	_combo_timer = 0.0
	_shake_trauma = 0.0

	_terrain.reset_terrain()
	var spawn_y := TerrainGenerator.sample_height(2.0) + 2.2
	_rover.reset_rover(Vector3(2.0, spawn_y, 0.0))
	_hud.hide_game_over()
	_camera.global_position = _rover.global_position + _cam_base_offset


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_restart_run()

	# 1. Infinite terrain streaming
	_terrain.update_around_x(_rover.global_position.x)

	# 2. Magnetic Star Shard pickup & bobbing
	_update_magnetic_shards(delta)

	# 3. Combo decay timer
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_count = 0

	# 4. Track distance & feed HUD + Procedural Audio
	var dist_now := maxi(0, int(floor(_rover.global_position.x - 2.0)))
	if dist_now > _max_distance:
		_max_distance = dist_now

	_hud.update_telemetry(
		_max_distance,
		_score,
		_combo_count,
		_rover.speed_kmh,
		_rover.battery_energy,
		_rover.boost_energy
	)

	_audio.rpm_norm = clampf(_rover.speed_kmh / 72.0, 0.0, 1.35)
	_audio.throttle_amount = 1.0 if (_rover.input_gas or _rover.input_brake or Input.is_action_pressed("move_right")) else 0.0
	_audio.is_boosting = (_rover.input_boost or Input.is_action_pressed("boost")) and _rover.boost_energy > 2.0 and not _rover.is_dead
	_audio.is_airborne = not _rover.is_grounded

	# 5. Dynamic Camera (Look-Ahead + Velocity FOV Pull-back + Trauma Shake)
	_update_camera(delta)

	# 6. Smooth Parallax Backdrop Tracking
	_parallax_root.position.x = _camera.global_position.x * 0.72
	_parallax_root.position.y = _camera.global_position.y * 0.25


func _update_magnetic_shards(delta: float) -> void:
	var t_sec := Time.get_ticks_msec() * 0.001
	var r_pos := _rover.global_position

	var idx := _terrain.active_shards.size() - 1
	while idx >= 0:
		var shard := _terrain.active_shards[idx]
		if not is_instance_valid(shard):
			_terrain.active_shards.remove_at(idx)
			idx -= 1
			continue

		shard.rotation.y += delta * 2.6
		var dist := shard.global_position.distance_to(r_pos)

		if dist < 5.6:
			# Magnetic curve pull into the rover!
			shard.global_position = shard.global_position.lerp(r_pos, clampf(delta * 13.5, 0.0, 1.0))
			if dist < 1.35:
				_collect_shard(shard)
				_terrain.active_shards.remove_at(idx)
				idx -= 1
				continue
		else:
			var base_y: float = shard.get_meta("base_y", shard.position.y)
			var phase: float = shard.get_meta("phase", 0.0)
			shard.position.y = base_y + sin(t_sec * 3.2 + phase) * 0.25

		idx -= 1


func _collect_shard(shard: Node3D) -> void:
	_combo_count += 1
	_combo_timer = 2.6
	var pts := 25 * mini(_combo_count, 5)
	_score += pts
	_rover.battery_energy = minf(100.0, _rover.battery_energy + 4.5)
	_rover.boost_energy = minf(100.0, _rover.boost_energy + 8.0)
	_audio.play_shard_chime(_combo_count - 1)
	shard.queue_free()


func _update_camera(delta: float) -> void:
	var vel_x := _rover.linear_velocity.x
	var look_ahead := clampf(vel_x * 0.28, -2.5, 6.2)
	var zoom_out := clampf(absf(vel_x) * 0.16, 0.0, 5.2)

	var target_pos := Vector3(
		_rover.global_position.x + _cam_base_offset.x + look_ahead,
		_rover.global_position.y + _cam_base_offset.y + zoom_out * 0.25,
		_cam_base_offset.z + zoom_out
	)
	_camera.global_position = _camera.global_position.lerp(target_pos, clampf(delta * 5.8, 0.0, 1.0))

	# Dynamic FOV surge when boosting or moving fast
	var target_fov := 34.0 + clampf(absf(vel_x) * 0.22, 0.0, 7.5)
	if _audio.is_boosting:
		target_fov += 4.5
	_camera.fov = lerpf(_camera.fov, target_fov, delta * 5.0)

	# Directional trauma screen shake
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.4)
		var shake := _shake_trauma * _shake_trauma * 0.65
		_camera.h_offset = randf_range(-shake, shake)
		_camera.v_offset = randf_range(-shake, shake)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


func _spawn_shockwave_ring(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 1.05
	ring.mesh = torus
	ring.material_override = ProceduralMeshBuilder.make_stylized_mat(
		Color(1.0, 0.88, 0.20), 0.0, 0.1, Color(1, 1, 1), 1.0, Color(1.0, 0.78, 0.10), 2.8
	)
	ring.global_position = pos + Vector3(0.0, -0.45, 0.0)
	ring.scale = Vector3(0.4, 0.4, 0.4)
	add_child(ring)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.4, 0.35, 3.4), 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ring.queue_free)


func _trigger_hit_stop(duration: float = 0.04) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _on_trick_performed(label_text: String, bonus_points: int, accent_color: Color) -> void:
	_score += bonus_points
	_hud.show_popup(label_text, accent_color)
	_audio.play_fanfare()
	_shake_trauma = maxf(_shake_trauma, 0.45)
	if "PERFECT" in label_text:
		_spawn_shockwave_ring(_rover.global_position)
		_trigger_hit_stop(0.04)


func _on_hard_impact(intensity: float) -> void:
	_audio.play_landing_thud(intensity)
	_shake_trauma = maxf(_shake_trauma, intensity * 0.72)


func _on_rover_crashed(reason: String) -> void:
	_audio.play_landing_thud(1.0)
	_shake_trauma = 0.85
	_hud.show_game_over(reason, _max_distance, _score)
