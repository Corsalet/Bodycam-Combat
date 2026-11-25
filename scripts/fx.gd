class_name Fx




var _root: Node3D
var _flash_meshes: Array[MeshInstance3D] = []
var _flash_t: Array[float] = []
var _flash_light: OmniLight3D
var _flash_light_t: = 0.0
var _tracers: Array[MeshInstance3D] = []
var _tracer_mats: Array[StandardMaterial3D] = []
var _tracer_t: Array[float] = []
var _puffs: Array[CPUParticles3D] = []
var _tracer_live: = 0.12
var _flash_live: = 0.05

const FLASH_POOL: = 6
const TRACER_POOL: = 24
const PUFF_POOL: = 16

func setup(root: Node3D) -> void :
	_root = root
	var sm: = SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	var fm: = StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.85, 0.4)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.75, 0.3)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in FLASH_POOL:
		var mi: = MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = fm
		mi.visible = false
		_root.add_child(mi)
		_flash_meshes.append(mi)
		_flash_t.append(0.0)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.45)
	_flash_light.light_energy = 2.5
	_flash_light.omni_range = 7.0
	_flash_light.visible = false
	_root.add_child(_flash_light)
	var bm: = BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 1.0)
	for i in TRACER_POOL:
		var mi: = MeshInstance3D.new()
		mi.mesh = bm
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.9, 0.6, 0.85)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.5)
		m.emission_energy_multiplier = 2.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.visible = false
		_root.add_child(mi)
		_tracers.append(mi)
		_tracer_mats.append(m)
		_tracer_t.append(0.0)
	for i in PUFF_POOL:
		var p: = CPUParticles3D.new()
		p.amount = 10
		p.lifetime = 0.5
		p.one_shot = true
		p.explosiveness = 1.0
		p.direction = Vector3(0, 1, 0)
		p.spread = 70.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.0
		p.gravity = Vector3(0, -4, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		p.emitting = false
		var pm: = StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var q: = QuadMesh.new()
		q.size = Vector2(0.09, 0.09)
		q.material = pm
		p.mesh = q
		_root.add_child(p)
		_puffs.append(p)


func flash(pos: Vector3, scale: float, lighted: = false) -> void :
	var slot: = -1
	var oldest: = 0
	for i in _flash_meshes.size():
		if _flash_t[i] <= 0.0:
			slot = i
			break
		if _flash_t[i] > _flash_t[oldest]:
			oldest = i
	if slot < 0:
		slot = oldest
	var mi: = _flash_meshes[slot]
	mi.position = pos
	mi.scale = Vector3.ONE * scale
	mi.visible = true
	_flash_t[slot] = _flash_live
	if lighted:
		_flash_light.position = pos
		_flash_light.visible = true
		_flash_light_t = _flash_live


func tracer(from: Vector3, to: Vector3) -> void :
	var slot: = -1
	var oldest: = 0
	for i in _tracers.size():
		if _tracer_t[i] <= 0.0:
			slot = i
			break
		if _tracer_t[i] > _tracer_t[oldest]:
			oldest = i
	if slot < 0:
		slot = oldest
	var mi: = _tracers[slot]
	var d: = from.distance_to(to)
	mi.position = (from + to) / 2.0
	if d > 0.001:
		mi.scale = Vector3(1, 1, d)
		mi.look_at(to, Vector3.UP)
	mi.visible = true
	_tracer_mats[slot].albedo_color.a = 0.85
	_tracer_t[slot] = _tracer_live

func _free_puff() -> CPUParticles3D:
	for p in _puffs:
		if not p.emitting:
			return p
	return _puffs[randi() % _puffs.size()]

func blood(pos: Vector3) -> void :
	var p: = _free_puff()
	(p.mesh as QuadMesh).material.albedo_color = Color(0.5, 0.06, 0.04)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.global_position = pos
	p.restart()

func dust(pos: Vector3) -> void :
	var p: = _free_puff()
	(p.mesh as QuadMesh).material.albedo_color = Color(0.55, 0.5, 0.4)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.global_position = pos
	p.restart()


var _rings: Array[MeshInstance3D] = []
var _ring_t: Array[float] = []
const RING_POOL: = 4

func _init_rings() -> void :
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	for i in RING_POOL:
		var mi: = MeshInstance3D.new()
		mi.mesh = tm
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.75, 0.4, 0.7)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.25)
		m.emission_energy_multiplier = 3.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		mi.material_override = m
		mi.visible = false
		_root.add_child(mi)
		_rings.append(mi)
		_ring_t.append(0.0)

func explosion(pos: Vector3) -> void :
	if _rings.is_empty():
		_init_rings()
	flash(pos, 6.0, true)
	for k in 3:
		var p: = _free_puff()
		(p.mesh as QuadMesh).material.albedo_color = [Color(0.85, 0.5, 0.2), Color(0.35, 0.32, 0.3), Color(0.5, 0.45, 0.4)][k]
		p.global_position = pos + Vector3(randf_range( - 0.6, 0.6), randf_range(0, 0.9), randf_range( - 0.6, 0.6))
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 9.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.5
		p.restart()
	var slot: = 0
	for i in _rings.size():
		if _ring_t[i] <= 0.0:
			slot = i
			break
	var mi: = _rings[slot]
	mi.position = pos
	mi.scale = Vector3.ONE * 0.4
	mi.rotation.x = PI / 2.0
	mi.visible = true
	_ring_t[slot] = 0.45
	var m0: = mi.material_override as StandardMaterial3D
	m0.albedo_color.a = 0.7

func tick(dt: float) -> void :
	for i in _flash_meshes.size():
		if _flash_t[i] > 0.0:
			_flash_t[i] -= dt
			if _flash_t[i] <= 0.0:
				_flash_meshes[i].visible = false
	if _flash_light_t > 0.0:
		_flash_light_t -= dt
		if _flash_light_t <= 0.0:
			_flash_light.visible = false
	for i in _rings.size():
		if _ring_t[i] > 0.0:
			_ring_t[i] -= dt
			var t: = 1.0 - _ring_t[i] / 0.45
			_rings[i].scale = Vector3.ONE * (0.4 + t * 6.0)
			(_rings[i].material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - t)
			if _ring_t[i] <= 0.0:
				_rings[i].visible = false
	for i in _tracers.size():
		if _tracer_t[i] > 0.0:
			_tracer_t[i] -= dt
			if _tracer_t[i] <= 0.0:
				_tracers[i].visible = false
			else:
				_tracer_mats[i].albedo_color.a = 0.85 * _tracer_t[i] / _tracer_live
