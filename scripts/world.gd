class_name World



const MAP_HALF: = 220
const EYE: = 1.62

const FLATS: = [
	{"x": -110, "z": -90, "r": 36}, 
	{"x": 0, "z": 0, "r": 38}, 
	{"x": 120, "z": 100, "r": 36}, 
	{"x": -172, "z": 152, "r": 30}, 
	{"x": 172, "z": -152, "r": 30}, 
]

const BASES: = {"RU": {"x": -172, "z": 152}, "US": {"x": 172, "z": -152}}

const AMMO_ZONES: = [
	{"x": -176, "z": 150, "r": 7.0}, 
	{"x": 168, "z": -154, "r": 7.0}, 
	{"x": 10, "z": 9.5, "r": 6.0}, 
	{"x": 109, "z": 101.5, "r": 6.0}, 
]

const CONTAINER_COLORS: = [9387820, 2903918, 5004851, 6710882, 7690538, 6174005]

static var rng: = RandomNumberGenerator.new()

static func c(h: int) -> Color:
	return Color8((h >> 16) & 255, (h >> 8) & 255, h & 255)

static func clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)

static func raw_h(x: float, z: float) -> float:
	var h: float = 2.6 * sin(x * 0.0115) * cos(z * 0.0095)\
	+ 1.5 * sin(x * 0.021 + z * 0.016)\
	+ 0.55 * sin(x * 0.052) * sin(z * 0.045)\
	+ 0.3 * sin((x + z) * 0.09)

	var d_b: = Vector2(x, z).length()
	h += 13.0 * exp( - d_b * d_b / 6728.0)

	for cr in [[-55, -45, 11, 2.6], [60, 50, 10, 2.4], [5, -75, 9, 2.2], [-40, 80, 8, 2.0]]:
		var dc: = Vector2(x - cr[0], z - cr[1]).length()
		h -= cr[3] * exp( - dc * dc / (2.0 * cr[2] * cr[2]))

	var d_edge: float = maxf(absf(x), absf(z))
	if d_edge > MAP_HALF - 24:
		h += (d_edge - (MAP_HALF - 24)) * 0.16
	return h

static func terrain_h(x: float, z: float) -> float:
	var h: float = raw_h(x, z)
	for f in FLATS:
		var d: float = Vector2(x - f.x, z - f.z).length()
		if d < f.r:
			var t: float = clamp01(d / f.r)
			t = t * t * (3.0 - 2.0 * t)
			h = lerpf(raw_h(f.x, f.z), h, t)
	return h

static func mat(h: int, flat: = false) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = c(h).darkened(0.22)
	m.roughness = 1.0
	if flat:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m

static func add_box(root: Node3D, x: float, y: float, z: float, w: float, hh: float, d: float, m: Material, collide: = true) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = Vector3(w, hh, d)
	mi.mesh = bm
	mi.material_override = m
	mi.position = Vector3(x, y + hh / 2.0, z)
	root.add_child(mi)
	if collide:
		var sb: = StaticBody3D.new()
		var cs: = CollisionShape3D.new()
		var sh: = BoxShape3D.new()
		sh.size = Vector3(w, hh, d)
		cs.shape = sh
		sb.add_child(cs)
		sb.position = mi.position
		sb.set_meta("world", true)
		root.add_child(sb)
	return mi


static func _wall(body: StaticBody3D, lx: float, ly: float, lz: float, w: float, hh: float, d: float, m: Material) -> void :
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = Vector3(w, hh, d)
	mi.mesh = bm
	mi.material_override = m
	mi.position = Vector3(lx, ly + hh / 2.0, lz)
	body.add_child(mi)
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = Vector3(w, hh, d)
	cs.shape = sh
	cs.position = mi.position
	body.add_child(cs)


static func house(root: Node3D, x: float, z: float, w: float, d: float, hh: float, m: Material, ry: = 0.0) -> void :
	var y: = terrain_h(x, z)
	var body: = StaticBody3D.new()
	body.position = Vector3(x, y, z)
	body.rotation.y = ry
	var t: = 0.5
	_wall(body, 0.0, 0.0, d / 2.0 - t / 2.0, w, hh, t, m)
	var door: = 1.8
	var seg: = (w - door) / 2.0
	_wall(body, - (door / 2.0 + seg / 2.0), 0.0, - d / 2.0 + t / 2.0, seg, hh, t, m)
	_wall(body, door / 2.0 + seg / 2.0, 0.0, - d / 2.0 + t / 2.0, seg, hh, t, m)
	_wall(body, - w / 2.0 + t / 2.0, 0.0, 0.0, t, hh, d, m)
	_wall(body, w / 2.0 - t / 2.0, 0.0, 0.0, t, hh, d, m)
	var rm: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = Vector3(w + 1.0, 0.32, d + 1.0)
	rm.mesh = bm
	rm.material_override = mat(4998716)
	rm.position = Vector3(0, hh + 0.16, 0)
	body.add_child(rm)
	root.add_child(body)


static func chapel(root: Node3D, x: float, z: float) -> void :
	var y: = terrain_h(x, z)
	add_box(root, x, y, z, 3.4, 8.8, 3.4, mat(10130568))
	add_box(root, x, y + 8.8, z, 4.2, 0.5, 4.2, mat(3948088), false)
	add_box(root, x, y + 9.3, z, 0.14, 1.5, 0.14, mat(3025960), false)
	add_box(root, x, y + 10.0, z, 0.9, 0.14, 0.14, mat(3025960), false)

static func well(root: Node3D, x: float, z: float) -> void :
	var y: = terrain_h(x, z)
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = 1.15
	cm.bottom_radius = 1.25
	cm.height = 1.15
	mi.mesh = cm
	mi.material_override = mat(9077880)
	mi.position = Vector3(x, y + 0.57, z)
	root.add_child(mi)
	var sb: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	var sh: = CylinderShape3D.new()
	sh.radius = 1.2
	sh.height = 1.15
	cs.shape = sh
	sb.add_child(cs)
	sb.position = mi.position
	root.add_child(sb)

static func fence_line(root: Node3D, x: float, z: float, n: int, ry: float) -> void :
	var y: = terrain_h(x, z)
	for i in n:
		var dx: = cos(ry) * (i - (n - 1) / 2.0) * 2.3
		var dz: = sin(ry) * (i - (n - 1) / 2.0) * 2.3
		add_box(root, x + dx, y, z + dz, 2.2, 1.0, 0.14, mat(7232060))


static var _ruins_scene: PackedScene = null

static func ruins_hutor(root: Node3D) -> void :
	if _ruins_scene == null:
		_ruins_scene = load("res://assets/ruins_r.scn")

	var spots: = [[-138, -104, 0.4, 1.1], [-88, -108, 0.34, 2.2], [-142, -70, 0.36, 0.4], [-84, -70, 0.42, 5.0], [-116, -64, 0.3, 3.6], [-148, -92, 0.32, 2.9]]
	for sp in spots:
		var piece: Node3D = _ruins_scene.instantiate()
		var sc: float = sp[2]
		piece.scale = Vector3(sc, sc, sc)
		piece.rotation.y = sp[3]
		var y: = terrain_h(sp[0], sp[1])
		piece.position = Vector3(sp[0], y, sp[1])
		root.add_child(piece)

		var lo: = 1000000000.0
		for mi2 in piece.find_children("*", "MeshInstance3D", true, false):
			var wab: AABB = (mi2 as MeshInstance3D).get_aabb()
			lo = minf(lo, wab.position.y)
		if lo > -100000000.0 and lo > 0.0:
			piece.position.y -= lo * sc

		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			var m: = mi as MeshInstance3D
			var ab: AABB = m.get_aabb()
			if ab.size.y < 1.2:
				continue
			var center_local: Vector3 = (m.transform * Transform3D(Basis(), ab.get_center())).origin
			if center_local.y - lo > 20.0:
				continue
			var body: = StaticBody3D.new()
			var cs: = CollisionShape3D.new()
			var box: = BoxShape3D.new()
			box.size = ab.size
			cs.shape = box
			body.add_child(cs)
			body.transform = Transform3D(m.transform.basis, center_local)
			piece.add_child(body)


static func tree(root: Node3D, x: float, z: float, s: float) -> void :
	var y: = terrain_h(x, z)

	WorldFx.register_tree(x, z, s, rng.randf_range(0, 6.3))
	var sb: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	var sh: = CylinderShape3D.new()
	sh.radius = 0.3 * s
	sh.height = 3.0 * s
	cs.shape = sh
	sb.add_child(cs)
	sb.position = Vector3(x, y + 1.5 * s, z)
	root.add_child(sb)


static func wreck(root: Node3D, x: float, z: float, ry: float) -> void :
	var y: = terrain_h(x, z)
	var body: = StaticBody3D.new()
	body.position = Vector3(x, y, z)
	body.rotation.y = ry
	body.rotation.z = 0.05
	_wall(body, 0.0, 0.0, 0.0, 4.5, 1.35, 2.3, mat(3947060))
	_wall(body, -0.3, 1.35, 0.0, 1.9, 0.9, 1.6, mat(3617838))
	var bm: = MeshInstance3D.new()
	var sm: = BoxMesh.new()
	sm.size = Vector3(2.0, 0.18, 0.18)
	bm.mesh = sm
	bm.material_override = mat(3025960)
	bm.position = Vector3(1.6, 1.35, 0.0)
	body.add_child(bm)
	root.add_child(body)

static func fuel_tank(root: Node3D, x: float, z: float) -> void :
	var y: = terrain_h(x, z)
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = 3.0
	cm.bottom_radius = 3.0
	cm.height = 5.6
	mi.mesh = cm
	mi.material_override = mat(8215092)
	mi.position = Vector3(x, y + 2.8, z)
	root.add_child(mi)
	var sb: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	var sh: = CylinderShape3D.new()
	sh.radius = 3.0
	sh.height = 5.6
	cs.shape = sh
	sb.add_child(cs)
	sb.position = mi.position
	root.add_child(sb)

static func ammo_crates(root: Node3D, x: float, z: float, ry: float) -> void :
	var y: = terrain_h(x, z)
	for i in 2:
		for j in 2:
			add_box(root, x + (i - 0.5) * 1.25, y + j * 0.62, z + (j - 0.5) * 0.1, 1.15, 0.6, 0.9, mat(5595194))

static func container(root: Node3D, x: float, z: float, ry: float, lvl: = 0) -> void :
	var y: = terrain_h(x, z) + lvl * 2.6
	var col: int = CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()]
	var body: = StaticBody3D.new()
	body.position = Vector3(x, y, z)
	body.rotation.y = ry
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = Vector3(6.1, 2.6, 2.5)
	mi.mesh = bm
	mi.material_override = mat(col)
	mi.position = Vector3(0, 1.3, 0)
	body.add_child(mi)
	var cs: = CollisionShape3D.new()
	var sh: = BoxShape3D.new()
	sh.size = Vector3(6.1, 2.6, 2.5)
	cs.shape = sh
	cs.position = Vector3(0, 1.3, 0)
	body.add_child(cs)
	root.add_child(body)

static func container_stack(root: Node3D, x: float, z: float, ry: float, lvl: int) -> void :
	for i in lvl:
		container(root, x, z, ry, i)

static func hesco_row(root: Node3D, x: float, z: float, n: int, ry: float) -> void :
	var y: = terrain_h(x, z)
	for i in n:
		var dx: = cos(ry) * (i - (n - 1) / 2.0) * 2.3
		var dz: = sin(ry) * (i - (n - 1) / 2.0) * 2.3
		add_box(root, x + dx, y, z + dz, 2.2, 1.7, 2.2, mat(11903083))

static func sandbag_wall(root: Node3D, x: float, z: float, l: float, ry: float) -> void :
	var y: = terrain_h(x, z)
	var body: = StaticBody3D.new()
	body.position = Vector3(x, y, z)
	body.rotation.y = ry
	_wall(body, 0.0, 0.0, 0.0, l, 1.05, 0.7, mat(8023882))
	root.add_child(body)

static func rock(root: Node3D, x: float, z: float, s: float) -> void :
	var y: = terrain_h(x, z)
	var mi: = MeshInstance3D.new()
	var dm: = SphereMesh.new()
	dm.radius = s
	dm.height = s * 2
	dm.radial_segments = 9
	dm.rings = 5
	mi.mesh = dm
	mi.material_override = mat(8681834, true)
	mi.position = Vector3(x, y + s * 0.25, z)
	mi.scale.y = 0.72
	mi.rotation.y = rng.randf_range(0, 6.3)
	root.add_child(mi)
	if s > 1.4:
		var sb: = StaticBody3D.new()
		var cs: = CollisionShape3D.new()
		var sh: = BoxShape3D.new()
		sh.size = Vector3(s * 1.4, s * 1.1, s * 1.4)
		cs.shape = sh
		sb.add_child(cs)
		sb.position = Vector3(x, y + s * 0.28, z)
		root.add_child(sb)

static func bush(root: Node3D, x: float, z: float, s: float) -> void :
	var y: = terrain_h(x, z)
	var mi: = MeshInstance3D.new()
	var im: = SphereMesh.new()
	im.radius = s
	im.height = s * 2
	im.radial_segments = 6
	im.rings = 3
	mi.mesh = im
	mi.material_override = mat(5135408 if rng.randf() < 0.5 else 5923124, true)
	mi.position = Vector3(x, y + s * 0.5, z)
	mi.scale.y = 0.7
	mi.rotation.y = rng.randf_range(0, 6.3)
	root.add_child(mi)

static func tower(root: Node3D, x: float, z: float) -> void :
	var y: = terrain_h(x, z)
	add_box(root, x, y, z, 4.4, 5.6, 4.4, mat(8288364))
	add_box(root, x, y + 5.6, z, 5.6, 0.4, 5.6, mat(3948088), false)

static func power_pole(root: Node3D, x: float, z: float) -> void :
	var y: = terrain_h(x, z)
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.2
	cm.height = 8.5
	mi.mesh = cm
	mi.material_override = mat(4868676)
	mi.position = Vector3(x, y + 4.2, z)
	root.add_child(mi)
	add_box(root, x, y + 7.4, z, 1.8, 0.14, 0.14, mat(4868676), false)

static func build(root: Node3D) -> void :
	rng.seed = 20251109
	_build_terrain(root)
	_build_roads(root)

	house(root, -122, -100, 10, 8, 4.2, mat(9071182), 0.5)
	house(root, -108, -74, 9, 7, 3.8, mat(10130568), -0.25)
	house(root, -94, -98, 8, 9, 4.0, mat(8288364), 1.35)
	house(root, -120, -82, 7, 6, 3.4, mat(9071182), 2.2)
	house(root, -100, -78, 8, 6, 3.2, mat(10130568), 0.15)
	chapel(root, -132, -88)
	well(root, -110, -92)
	ruins_hutor(root)
	fence_line(root, -114, -104, 4, 0.2)
	fence_line(root, -96, -110, 3, 1.1)
	container(root, -86, -104, 0.4)
	container_stack(root, -82, -84, 1.25, 2)
	sandbag_wall(root, -110, -90, 6, 0.4)
	sandbag_wall(root, -118, -96, 5, 1.2)
	rock(root, -136, -72, 1.9)
	bush(root, -138, -106, 1.2)
	bush(root, -90, -68, 1.4)
	bush(root, -78, -102, 1.0)
	bush(root, -126, -70, 1.1)


	var by: = terrain_h(0, 0)
	var bunker: = StaticBody3D.new()
	bunker.position = Vector3(10, terrain_h(10, 6), 6)
	_wall(bunker, 0.0, 0.0, -2.4, 7.0, 2.3, 0.55, mat(7302756))
	_wall(bunker, -3.2, 0.0, 0.4, 0.55, 2.3, 5.2, mat(7302756))
	_wall(bunker, 3.2, 0.0, 0.4, 0.55, 2.3, 5.2, mat(7302756))
	var broof: = MeshInstance3D.new()
	var bbm: = BoxMesh.new()
	bbm.size = Vector3(7.6, 0.4, 6.0)
	broof.mesh = bbm
	broof.material_override = mat(5526604)
	broof.position = Vector3(0, 2.5, 0)
	bunker.add_child(broof)
	root.add_child(bunker)
	ammo_crates(root, 10, 9.5, 0.2)

	add_box(root, -14, by - 0.5, -10, 3.6, 8.4, 3.6, mat(6052946))
	add_box(root, -14, by + 7.9, -10, 5.2, 0.45, 5.2, mat(3948088), false)
	add_box(root, -14, by + 8.35, -10, 0.16, 2.6, 0.16, mat(3025960), false)

	sandbag_wall(root, -18, 12, 7, 1.15)
	sandbag_wall(root, 20, -14, 7, -0.35)
	sandbag_wall(root, 4, 26, 6, 0.05)
	hesco_row(root, -26, -2, 4, 0.5)
	hesco_row(root, 24, 8, 4, 1.2)
	container_stack(root, -6, 14, 0.2, 2)
	container(root, 14, -18, 1.0)
	wreck(root, -22, 22, 2.6)
	rock(root, 30, -24, 2.0)
	bush(root, 34, 6, 1.2)
	bush(root, -34, -16, 1.1)
	bush(root, -8, 34, 1.3)


	var hy: = terrain_h(120, 100)
	add_box(root, 112, hy, 92, 15, 4.6, 0.5, mat(6187622))
	add_box(root, 112, hy, 108, 15, 4.6, 0.5, mat(6187622))
	add_box(root, 112, hy + 4.6, 100, 15.8, 0.4, 17.0, mat(3948088), false)
	add_box(root, 108, hy, 100, 1.6, 1.4, 1.2, mat(5595194))
	add_box(root, 110, hy, 103, 1.6, 1.4, 1.2, mat(5595194))
	add_box(root, 109, hy, 101.5, 1.6, 1.4, 1.2, mat(5595194))

	container_stack(root, 130, 92, 0.1, 2)
	container_stack(root, 132, 98, 0.1, 2)
	container_stack(root, 124, 112, 1.3, 2)
	container(root, 138, 104, 0.1)
	container(root, 108, 114, 0.5)

	fuel_tank(root, 134, 116)
	fuel_tank(root, 142, 110)
	var pipe: = MeshInstance3D.new()
	var pcm: = CylinderMesh.new()
	pcm.top_radius = 0.32
	pcm.bottom_radius = 0.32
	pcm.height = 11.0
	pipe.mesh = pcm
	pipe.material_override = mat(5921362)
	pipe.position = Vector3(138, terrain_h(138, 113) + 1.4, 113)
	pipe.rotation.z = PI / 2
	pipe.rotation.y = 0.15
	root.add_child(pipe)

	tower(root, 106, 104)
	hesco_row(root, 128, 84, 5, 0.1)
	hesco_row(root, 146, 100, 5, 1.35)
	sandbag_wall(root, 120, 82, 8, 0.05)
	sandbag_wall(root, 104, 112, 7, 1.2)
	building(root, 146, 90, 8, 6, 3.6, mat(8288364))
	wreck(root, 96, 94, 0.8)
	rock(root, 148, 118, 2.2)
	bush(root, 100, 88, 1.2)
	bush(root, 150, 82, 1.0)

	for base in [[-172, 152, 3824174], [172, -152, 3030874]]:
		var bx: float = base[0]
		var bz: float = base[1]
		var tint: int = base[2]
		var m1: = add_box(root, bx - 10, terrain_h(bx - 10, bz), bz, 9, 3.2, 6, mat(tint))
		m1.rotation.y = 0.2
		add_box(root, bx + 8, terrain_h(bx + 8, bz - 6), bz - 6, 7, 3.0, 5, mat(tint))
		add_box(root, bx, terrain_h(bx, bz + 10), bz + 10, 5, 2.4, 4, mat(6187622))
		hesco_row(root, bx - 14, bz + 8, 4, 0.3)
		hesco_row(root, bx + 12, bz - 12, 4, 1.2)
		ammo_crates(root, bx - 4, bz - 2, 0.4)

	var scatter: = [[-130, 100], [-95, 55], [-55, 28], [-38, -38], \
	[130, -100], [95, -55], [55, -28], [38, 38], \
	[-45, 55], [45, -55], [-20, 110], [20, -110], \
	[100, 140], [-100, -140], [160, 60], [-160, -60]]
	for s in scatter:
		var r: = rng.randf()
		if r < 0.3:
			container(root, s[0], s[1], rng.randf_range(0, 3))
		elif r < 0.5:
			hesco_row(root, s[0], s[1], rng.randi_range(3, 4), rng.randf_range(0, 3))
		elif r < 0.62:
			wreck(root, s[0], s[1], rng.randf_range(0, 3))
		elif r < 0.8:
			rock(root, s[0], s[1], rng.randf_range(1.6, 2.8))
		else:
			sandbag_wall(root, s[0], s[1], rng.randf_range(4, 7), rng.randf_range(0, 3))

	var groves: = [[-150, -20], [150, 20], [-40, 140], [40, -140], [170, 100], [-170, -100], [100, 170]]
	for g in groves:
		for i in 10:
			var tx: float = g[0] + rng.randf_range(-14, 14)
			var tz: float = g[1] + rng.randf_range(-14, 14)
			tree(root, tx, tz, rng.randf_range(0.8, 1.5))
	for i in 22:
		var lx: = rng.randf_range( - MAP_HALF + 16, MAP_HALF - 16)
		var lz: = rng.randf_range( - MAP_HALF + 16, MAP_HALF - 16)
		var skip: = false
		for f in FLATS:
			if Vector2(lx - f.x, lz - f.z).length() < f.r + 6.0:
				skip = true
		if Vector2(lx, lz).length() < 52 or skip:
			continue
		tree(root, lx, lz, rng.randf_range(0.9, 1.6))

	for i in 34:
		var x: = rng.randf_range( - MAP_HALF + 12, MAP_HALF - 12)
		var z: = rng.randf_range( - MAP_HALF + 12, MAP_HALF - 12)
		if Vector2(x, z).length() < 46:
			continue
		if rng.randf() < 0.45:
			rock(root, x, z, rng.randf_range(0.7, 1.5))
		else:
			bush(root, x, z, rng.randf_range(0.7, 1.6))

	for road in [BASES.RU, BASES.US]:
		var a: = Vector2(road.x, road.z)
		for t in [0.2, 0.35, 0.5, 0.65, 0.8]:
			var pp: = a.lerp(Vector2.ZERO, t) + Vector2(-5, -4)
			power_pole(root, pp.x, pp.y)

	WorldFx.build_tree_multimesh(root)
	WorldFx.decorate(root)

static func building(root: Node3D, x: float, z: float, w: float, d: float, hh: float, m: Material) -> void :
	var y: = terrain_h(x, z)
	add_box(root, x, y, z, w, hh, d, m)
	add_box(root, x, y + hh, z, w + 0.9, 0.35, d + 0.9, mat(6051918), false)

static func _build_terrain(root: Node3D) -> void :
	var pm: = PlaneMesh.new()
	pm.size = Vector2(MAP_HALF * 2, MAP_HALF * 2)
	pm.subdivide_width = 130
	pm.subdivide_depth = 130
	var arrays: = pm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v: = verts[i]
		verts[i] = Vector3(v.x, terrain_h(v.x, v.z), v.z)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var st: = SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.set_material(WorldFx.terrain_material())
	var mi: = MeshInstance3D.new()
	mi.mesh = st.commit()
	root.add_child(mi)
	var sb: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	sb.add_child(cs)
	sb.position = Vector3.ZERO
	root.add_child(sb)

static func _road_line(root: Node3D, a: Vector2, b: Vector2, n: int) -> void :
	var rm: = mat(9077362)
	for i in n:
		var t0: = i / float(n)
		var t1: = (i + 1) / float(n)
		var p0: = a.lerp(b, t0)
		var p1: = a.lerp(b, t1)
		var mid: = (p0 + p1) / 2.0
		var y: = terrain_h(mid.x, mid.y) + 0.05
		var seg_len: = p0.distance_to(p1) + 0.6
		var mi: = MeshInstance3D.new()
		var pm: = PlaneMesh.new()
		pm.size = Vector2(6.5, seg_len)
		mi.mesh = pm
		mi.material_override = rm
		mi.position = Vector3(mid.x, y, mid.y)
		mi.rotation.y = atan2(p1.x - p0.x, p1.y - p0.y)
		root.add_child(mi)

static func _build_roads(root: Node3D) -> void :

	_road_line(root, Vector2(BASES.RU.x, BASES.RU.z), Vector2.ZERO, 24)
	_road_line(root, Vector2(BASES.US.x, BASES.US.z), Vector2.ZERO, 24)
	_road_line(root, Vector2(-110, -90), Vector2(120, 100), 30)
