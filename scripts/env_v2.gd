class_name WorldFx



static var fwd: bool = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")) == "forward_plus"
static var trees: = []

static func _ramp(stops: Array) -> Gradient:
	var g: = Gradient.new()
	var offs: = PackedFloat32Array()
	var cols: = PackedColorArray()
	for i in stops.size():
		offs.append(stops[i][0])
		cols.append(stops[i][1])
	g.offsets = offs
	g.colors = cols
	return g


static func _noise_tex(seed: int, ramp: Gradient) -> NoiseTexture2D:
	var fn: = FastNoiseLite.new()
	fn.seed = seed
	fn.frequency = 0.014
	fn.fractal_octaves = 4
	var nt: = NoiseTexture2D.new()
	nt.noise = fn
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	if ramp:
		nt.color_ramp = ramp
	return nt



static func _normal_tex(seed: int, strength: = 2.2) -> ImageTexture:
	var fn: = FastNoiseLite.new()
	fn.seed = seed
	fn.frequency = 0.05
	fn.fractal_octaves = 4
	var sz: int = 128
	var img: = Image.create(sz, sz, false, Image.FORMAT_RGB8)
	var h: = PackedFloat32Array()
	h.resize(sz * sz)
	for y in sz:
		for x in sz:
			h[y * sz + x] = fn.get_noise_2d(x, y)
	for y in sz:
		for x in sz:
			var dx: float = h[y * sz + (x + 1) % sz] - h[y * sz + (x - 1 + sz) % sz]
			var dy: float = h[(y + 1) % sz * sz + x] - h[(y - 1 + sz) % sz * sz + x]
			var n: = Vector3( - dx * strength, - dy * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)


static func terrain_material() -> ShaderMaterial:
	var sm: = ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/terrain.gdshader")
	sm.set_shader_parameter("grass_tex", _noise_tex(11, _ramp([[0.0, Color(0.14, 0.2, 0.07)], [0.45, Color(0.23, 0.3, 0.11)], [1.0, Color(0.31, 0.36, 0.14)]])))
	sm.set_shader_parameter("soil_tex", _noise_tex(23, _ramp([[0.0, Color(0.16, 0.12, 0.08)], [0.5, Color(0.25, 0.19, 0.12)], [1.0, Color(0.34, 0.27, 0.18)]])))
	sm.set_shader_parameter("gravel_tex", _noise_tex(37, _ramp([[0.0, Color(0.2, 0.2, 0.19)], [0.5, Color(0.3, 0.3, 0.28)], [1.0, Color(0.4, 0.39, 0.37)]])))
	sm.set_shader_parameter("macro_tex", _noise_tex(51, _ramp([[0.0, Color(0, 0, 0)], [1.0, Color(1, 1, 1)]])))
	return sm


static func foliage_material(base: Color, axis: float, strength: float) -> ShaderMaterial:
	var sm: = ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/foliage.gdshader")
	sm.set_shader_parameter("base_col", base)
	sm.set_shader_parameter("sway_axis", axis)
	sm.set_shader_parameter("wind_strength", strength)
	return sm


static func water_material() -> ShaderMaterial:
	var sm: = ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/water.gdshader")
	sm.set_shader_parameter("norm_a", _normal_tex(71))
	sm.set_shader_parameter("norm_b", _normal_tex(83))
	return sm


static func post_material() -> ShaderMaterial:
	var sm: = ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/post_fx.gdshader")
	if "--nodrops" in OS.get_cmdline_user_args():
		sm.set_shader_parameter("drops", 0.0)
	if "--nofisheye" in OS.get_cmdline_user_args():
		sm.set_shader_parameter("fisheye", 0.0)
	if "--nograin" in OS.get_cmdline_user_args():
		sm.set_shader_parameter("grain", 0.0)
	return sm



static func register_tree(x: float, z: float, s: float, ry: float) -> void :
	trees.append([x, z, s, ry])


static func _layer_mesh(top: float, bot: float, hgt: float, segs: int, cap_top: = false) -> Mesh:
	var cm: = CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bot
	cm.height = hgt
	cm.radial_segments = segs
	cm.cap_top = cap_top
	return cm


static func build_tree_multimesh(root: Node3D) -> void :
	var web: = DisplayServer.get_name() == "web"
	var n: int = trees.size()
	if n == 0:
		return
	var trunk_col: = World.c(5062626).darkened(0.22)
	var greens: = [World.c(4149798).darkened(0.22), World.c(4873258).darkened(0.22), World.c(3566432).darkened(0.22)]

	var layers: = [
		[0.09, 0.24, 2.475, 1.21, 0.35, trunk_col, 7, 1.0], 
		[0.247, 0.95, 2.09, 2.585, 0.5, greens[0], 7, 1.0], 
		[0.178, 0.684, 2.09, 3.795, 0.8, greens[1], 7, 1.0], 
		[0.128, 0.4925, 2.09, 5.005, 1.05, greens[2], 7, 1.0], 
		[0.092, 0.3547, 2.09, 6.215, 1.3, greens[0], 7, 1.0], 
	]
	var rng: = RandomNumberGenerator.new()
	rng.seed = 777
	var wgen: = foliage_material(Color(1, 1, 1), 1.0, 0.14)
	for L in layers:
		var mm: = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = _layer_mesh(L[0], L[1], L[2], L[6])
		mm.instance_count = n
		mm.custom_aabb = AABB(Vector3( - 245, -20, -245), Vector3(490, 80, 490))
		var sm: = foliage_material(L[5], 1.0, 0.14)
		var mmi: = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = sm
		for i in n:
			var t: Array = trees[i]
			var s: float = t[2]
			var xf: = Transform3D(Basis(Vector3.UP, t[3]).scaled(Vector3(s, s, s)), Vector3(t[0], World.terrain_h(t[0], t[1]) + L[3] * s, t[1]))
			mm.set_instance_transform(i, xf)
			var tv: float = rng.randf_range(0.8, 1.1)
			mm.set_instance_color(i, Color(tv, tv * 1.03, tv * 0.93))
			mm.set_instance_custom_data(i, Color(rng.randf_range(0, 6.3), L[4], 0, 0))
		root.add_child(mmi)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: = b - a
	if ab.length_squared() < 0.01:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)



static func decorate(root: Node3D) -> void :
	var web: = DisplayServer.get_name() == "web"
	if "--nograss" in OS.get_cmdline_user_args():
		if fwd:
			_battle_marks(root)
		_smoke(root, 105, 95)
		_fire(root, -22, 22)
		_fire(root, 96, 94)
		return
	_grass(root, 8000 if web else 15000)
	for pond in [[ - 55, -45, 9.0], [60, 50, 8.5]]:
		_pond(root, pond[0], pond[1], pond[2])
	if fwd:
		_battle_marks(root)
	_smoke(root, 105, 95)
	_fire(root, -22, 22)
	_fire(root, 96, 94)


static func _grass(root: Node3D, n: int) -> void :
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts: = [Vector3( - 0.05, 0, 0), Vector3(0.05, 0, 0), Vector3(0.03, 1, 0), Vector3( - 0.03, 1, 0)]
	var uvs: = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var idx: = [0, 1, 2, 0, 2, 3]
	for k in idx:
		st.set_normal(Vector3(0, 0, 1))
		st.set_uv(uvs[k])
		st.add_vertex(verts[k])
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = st.commit()
	mm.instance_count = n
	mm.custom_aabb = AABB(Vector3( - 245, -20, -245), Vector3(490, 60, 490))
	var rng: = RandomNumberGenerator.new()
	rng.seed = 4242
	var ponds: = [[ - 55, -45, 12.0], [60, 50, 11.5]]
	var placed: int = 0
	var guard: int = 0
	while placed < n and guard < n * 14:
		guard += 1
		var x: float = rng.randf_range( - World.MAP_HALF + 12, World.MAP_HALF - 12)
		var z: float = rng.randf_range( - World.MAP_HALF + 12, World.MAP_HALF - 12)
		var skip: = false
		for f in World.FLATS:
			if Vector2(x - f.x, z - f.z).length() < f.r - 2.0:
				skip = true
		for r in roads():
			if _seg_dist(Vector2(x, z), r[0], r[1]) < 4.5:
				skip = true
		for p in ponds:
			if Vector2(x - p[0], z - p[1]).length() < p[2]:
				skip = true
		if skip:
			continue
		var y: = World.terrain_h(x, z)
		if y > 7.0 or y < 0.3:
			continue
		var g0: = World.terrain_h(x + 0.7, z)
		var g1: = World.terrain_h(x, z + 0.7)
		if absf(g0 - y) > 0.5 or absf(g1 - y) > 0.5:
			continue
		var sc: = rng.randf_range(0.7, 1.25)
		var xf: = Transform3D(Basis(Vector3.UP, rng.randf_range(0, 6.3)).scaled(Vector3(sc, rng.randf_range(0.28, 0.6), sc)), Vector3(x, y - 0.03, z))
		mm.set_instance_transform(placed, xf)
		var tv: float = rng.randf_range(0.75, 1.1)
		mm.set_instance_color(placed, Color(tv * 0.94, tv, tv * 0.8))
		mm.set_instance_custom_data(placed, Color(rng.randf_range(0, 6.3), rng.randf_range(0.9, 1.6), 0, 0))
		placed += 1
	mm.visible_instance_count = placed
	var mmi: = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = foliage_material(Color(0.16, 0.23, 0.08), 0.0, 0.16)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


static func roads() -> Array:
	return [
		[Vector2(World.BASES.RU.x, World.BASES.RU.z), Vector2.ZERO], 
		[Vector2(World.BASES.US.x, World.BASES.US.z), Vector2.ZERO], 
		[Vector2( - 110, -90), Vector2(120, 100)]
	]


static func _pond(root: Node3D, cx: float, cz: float, r: float) -> void :
	var wy: = World.terrain_h(cx, cz) + 1.0
	var mi: = MeshInstance3D.new()
	var pm: = PlaneMesh.new()
	pm.size = Vector2(r * 2.3, r * 2.3)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	mi.mesh = pm
	mi.material_override = water_material()
	mi.position = Vector3(cx, wy, cz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _scorch_tex(seed: int) -> ImageTexture:
	var img: = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed
	for y in 128:
		for x in 128:
			var d: = Vector2(x - 64, y - 64).length() / 64.0
			var nz: = rng.randf()
			var a: float = clampf((1.0 - d) * 1.7 - 0.35 - nz * 0.28, 0.0, 1.0)
			var v: float = 0.05 + nz * 0.09
			img.set_pixel(x, y, Color(v, v * 0.92, v * 0.85, a))
	return ImageTexture.create_from_image(img)


static func _battle_marks(root: Node3D) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = 909
	var spots: = [[ - 96, -88], [ - 78, -80], [12, -6], [18, 12], [110, 96], [116, 104], [ - 30, 30], [40, -40]]
	for sp in spots:
		var d: = Decal.new()
		d.texture_albedo = _scorch_tex(rng.randi())
		d.size = Vector3(rng.randf_range(3.5, 6.5), 4.0, rng.randf_range(3.5, 6.5))
		var x: float = sp[0] + rng.randf_range( - 4, 4)
		var z: float = sp[1] + rng.randf_range( - 4, 4)
		d.position = Vector3(x, World.terrain_h(x, z) + 2.0, z)
		d.rotation_degrees = Vector3( - 90, rng.randf_range(0, 6.3), 0)
		d.cull_mask = 1
		root.add_child(d)


static func _smoke_tex() -> ImageTexture:
	var img: = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d: = Vector2(x - 32, y - 32).length() / 32.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * 0.85))
	return ImageTexture.create_from_image(img)


static func _smoke(root: Node3D, x: float, z: float) -> void :
	var y: = World.terrain_h(x, z)
	var pipe: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.24
	cm.height = 2.4
	pipe.mesh = cm
	pipe.material_override = World.mat(3025960)
	pipe.position = Vector3(x, y + 4.6 + 1.2, z)
	root.add_child(pipe)
	var g: = GPUParticles3D.new()
	var pm: = ParticleProcessMaterial.new()
	pm.direction = Vector3(0.55, 1, 0.28)
	pm.spread = 7.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.7
	pm.gravity = Vector3(0.3, 0.35, 0.15)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var cur: = Curve.new()
	cur.add_point(Vector2(0.0, 0.3))
	cur.add_point(Vector2(1.0, 1.0))
	var ct: = CurveTexture.new()
	ct.curve = cur
	pm.scale_curve = ct
	g.process_material = pm
	g.amount = 22
	g.lifetime = 5.5
	g.position = Vector3(x, y + 4.6 + 2.3, z)
	var q: = QuadMesh.new()
	q.size = Vector2(1.9, 1.9)
	var qm: = StandardMaterial3D.new()
	qm.albedo_color = Color(0.72, 0.71, 0.68, 0.13)
	qm.albedo_texture = _smoke_tex()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = qm
	q.material = qm
	g.draw_pass_1 = q
	root.add_child(g)


static func _fire(root: Node3D, x: float, z: float) -> void :
	var y: = World.terrain_h(x, z)
	var g: = GPUParticles3D.new()
	var pm: = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 2.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	g.process_material = pm
	g.amount = 12
	g.lifetime = 1.3
	g.position = Vector3(x, y + 1.1, z)
	var q: = QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var qm: = StandardMaterial3D.new()
	qm.albedo_color = Color(1.0, 0.55, 0.16)
	qm.emission_enabled = true
	qm.emission = Color(1.0, 0.45, 0.1)
	qm.emission_energy_multiplier = 2.2
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = qm
	g.draw_pass_1 = q
	root.add_child(g)
	var li: = OmniLight3D.new()
	li.light_color = Color(1.0, 0.5, 0.14)
	li.omni_range = 8.0
	li.light_energy = 1.7
	li.position = Vector3(x, y + 1.6, z)
	li.shadow_enabled = false
	li.set_script(load("res://scripts/flicker.gd"))
	root.add_child(li)



static func upgrade_environment(e: Environment, sun: DirectionalLight3D) -> void :
	var web: = DisplayServer.get_name() == "web"
	sun.rotation_degrees = Vector3( - 13, 28, 0)
	sun.light_color = Color(1.0, 0.74, 0.5)
	sun.light_energy = 1.15
	var sm: = e.sky.sky_material as ProceduralSkyMaterial
	if sm:
		sm.sky_top_color = Color(0.19, 0.24, 0.33)
		sm.sky_horizon_color = Color(0.87, 0.5, 0.28)
		sm.ground_horizon_color = Color(0.87, 0.5, 0.28)
		sm.ground_bottom_color = Color(0.13, 0.1, 0.08)
	e.fog_light_color = Color(0.5, 0.38, 0.3)
	e.fog_density = 0.0 if web else 0.0042
	e.fog_sky_affect = 0.3
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.0
	if fwd and not web:
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.02
		e.volumetric_fog_albedo = Color(0.9, 0.72, 0.55)
		e.volumetric_fog_emission = Color(0.12, 0.06, 0.02)
		e.volumetric_fog_anisotropy = 0.55
		e.volumetric_fog_length = 96
		e.ssao_enabled = true
		e.ssao_intensity = 1.5



static func post_fx(parent: Node) -> void :
	if "--nopost" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "web":
		return
	var cl: = CanvasLayer.new()
	cl.layer = -1
	var cr: = ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.material = post_material()
	cl.add_child(cr)
	parent.add_child(cl)
