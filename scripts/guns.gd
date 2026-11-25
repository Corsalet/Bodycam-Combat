class_name Guns


const WPN: = {
	"ak74": {"name": "АК-74", "len": 0.92, "auto": true, "rpm": 600, "dmg": 34, "mag": 30, "reserve": 120, "reload": 2.3, "s_hip": 1.5, "s_ads": 0.3, "ads_fov": 55, "hip_pos": Vector3(0.28, -0.15, -0.48), "ads_pos": Vector3(-0.065, -0.013, -0.44), "kick": 1.0, "scope": false, "scope_fov": 0.0, "mode": "АВТО"}, 
	"m16": {"name": "М16А4", "len": 1.0, "auto": true, "rpm": 660, "dmg": 32, "mag": 30, "reserve": 120, "reload": 2.2, "s_hip": 1.4, "s_ads": 0.28, "ads_fov": 55, "hip_pos": Vector3(0.14, -0.068, -0.55), "ads_pos": Vector3(0, -0.066, -0.46), "kick": 0.9, "scope": false, "scope_fov": 0.0, "mode": "АВТО"}, 
	"svd": {"name": "СВД ДРАГУНОВА", "len": 1.22, "auto": false, "rpm": 90, "dmg": 105, "mag": 10, "reserve": 40, "reload": 2.8, "s_hip": 1.9, "s_ads": 0.1, "ads_fov": 18, "hip_pos": Vector3(0.133, -0.088, -0.85), "ads_pos": Vector3(0, -0.16, -0.46), "kick": 1.8, "scope": true, "scope_fov": 18.0, "mode": "ОДИНОЧНЫЙ"}, 
	"m82": {"name": "M82A1 BARRETT", "len": 1.45, "auto": false, "rpm": 45, "dmg": 150, "mag": 10, "reserve": 30, "reload": 3.4, "s_hip": 2.3, "s_ads": 0.08, "ads_fov": 10, "hip_pos": Vector3(0.136, -0.089, -0.9), "ads_pos": Vector3(0, -0.155, -0.5), "kick": 2.6, "scope": true, "scope_fov": 10.0, "mode": "ОДИНОЧНЫЙ"}, 
	"makarov": {"name": "ПМ «МАКАРОВ»", "len": 0.3, "auto": false, "rpm": 300, "dmg": 30, "mag": 8, "reserve": 40, "reload": 1.8, "s_hip": 1.2, "s_ads": 0.4, "ads_fov": 62, "hip_pos": Vector3(0.19, -0.17, -0.38), "ads_pos": Vector3(0, -0.022, -0.36), "kick": 0.6, "scope": false, "scope_fov": 0.0, "mode": "ОДИНОЧНЫЙ"}, 
	"deagle": {"name": "DESERT EAGLE .50", "len": 0.36, "auto": false, "rpm": 200, "dmg": 56, "mag": 7, "reserve": 35, "reload": 2.0, "s_hip": 1.5, "s_ads": 0.45, "ads_fov": 62, "hip_pos": Vector3(0.19, -0.17, -0.4), "ads_pos": Vector3(0, -0.029, -0.38), "kick": 1.4, "scope": false, "scope_fov": 0.0, "mode": "ОДИНОЧНЫЙ"}, 
}

const CLASSES: = {
	"RU": {"assault": ["ak74", "makarov"], "sniper": ["svd", "makarov"]}, 
	"US": {"assault": ["m16", "deagle"], "sniper": ["m82", "deagle"]}, 
}

static func _m(h: int, metal: = false) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = World.c(h)
	m.roughness = 0.65 if metal else 0.85
	m.metallic = 0.6 if metal else 0.0
	return m

static func _box(parent: Node3D, x: float, y: float, z: float, w: float, hh: float, d: float, m: Material) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = Vector3(w, hh, d)
	mi.mesh = bm
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, x: float, y: float, z: float, r: float, hh: float, m: Material, along_z: = true, seg: = 10) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = hh
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	if along_z:
		mi.rotation.x = PI / 2
	parent.add_child(mi)
	return mi


static func _hand(parent: Node3D, x: float, y: float, z: float, s: = 1.0) -> void :
	var m: = _m(4146742)
	_box(parent, x, y, z, 0.055 * s, 0.062 * s, 0.078 * s, m)
	_box(parent, x, y + 0.006 * s, z - 0.05 * s, 0.048 * s, 0.05 * s, 0.05 * s, m)



static func build(key: String, viewmodel: = false, attach: = {}) -> Node3D:
	var len: float = WPN[key]["len"]
	var g: = Node3D.new()
	var wood: = _m(7162664)
	var wood2: = _m(5716255)
	var metal: = _m(5133918, true)
	var steel: = _m(6450036, true)
	var poly: = _m(3554625)
	var poly_d: = _m(2896438)
	var dark: = _m(2369580)
	var plum: = _m(4863016)
	var glove: = _m(4146742)
	if key == "svd":
		_cyl(g, 0, 0, -0.4575 * len, 0.016 * len, 0.085 * len, steel)
		_cyl(g, 0, 0, -0.488 * len, 0.019 * len, 0.018 * len, steel)
		_cyl(g, 0, 0, -0.2075 * len, 0.0115 * len, 0.415 * len, steel)
		_box(g, 0, 0.017 * len, -0.395 * len, 0.016 * len, 0.01 * len, 0.02 * len, metal)
		_box(g, 0.011 * len, 0.028 * len, -0.395 * len, 0.004 * len, 0.03 * len, 0.008 * len, metal)
		_box(g, -0.011 * len, 0.028 * len, -0.395 * len, 0.004 * len, 0.03 * len, 0.008 * len, metal)
		_box(g, 0, 0.036 * len, -0.395 * len, 0.004 * len, 0.032 * len, 0.006 * len, steel)
		_box(g, 0, 0.022 * len, -0.3 * len, 0.02 * len, 0.026 * len, 0.026 * len, metal)
		_cyl(g, 0, 0.03 * len, -0.228 * len, 0.012 * len, 0.14 * len, steel)
		_cyl(g, 0, 0.004 * len, -0.2225 * len, 0.024 * len, 0.145 * len, wood)
		for i in 4:
			_cyl(g, 0, 0.018 * len, (-0.17 - i * 0.035) * len, 0.005 * len, 0.006 * len, dark)
		_box(g, 0, 0.009 * len, 0.12 * len, 0.032 * len, 0.042 * len, 0.24 * len, metal)
		_cyl(g, 0, 0.03 * len, 0.1225 * len, 0.016 * len, 0.235 * len, metal)
		_box(g, 0.02 * len, 0.022 * len, 0.14 * len, 0.014 * len, 0.012 * len, 0.05 * len, metal)
		for i in 3:
			var t: = -0.048 - i * 0.058
			var zz: = 0.062 - i * 0.014
			var seg: = _box(g, 0, t * len, zz * len, 0.026 * len, 0.062 * len, 0.034 * len, metal)
			seg.rotation.x = (0.1 + i * 0.12)
		_box(g, 0.014 * len, -0.075 * len, 0.045 * len, 0.004 * len, 0.05 * len, 0.006 * len, metal)
		_box(g, -0.014 * len, -0.075 * len, 0.045 * len, 0.004 * len, 0.05 * len, 0.006 * len, metal)
		_box(g, 0, -0.033 * len, 0.15 * len, 0.008 * len, 0.006 * len, 0.058 * len, metal)
		var grip: = _box(g, 0, -0.072 * len, 0.178 * len, 0.022 * len, 0.105 * len, 0.032 * len, wood2)
		grip.rotation.x = -0.3

		_box(g, 0, 0.03 * len, 0.37 * len, 0.03 * len, 0.018 * len, 0.26 * len, wood)
		_box(g, 0, 0.045 * len, 0.4 * len, 0.024 * len, 0.014 * len, 0.11 * len, wood2)
		var low: = _box(g, 0, -0.052 * len, 0.38 * len, 0.024 * len, 0.016 * len, 0.16 * len, wood2)
		low.rotation.x = 0.1
		var diag: = _box(g, 0, -0.028 * len, 0.3 * len, 0.02 * len, 0.014 * len, 0.09 * len, wood2)
		diag.rotation.x = 0.65
		_box(g, 0, -0.014 * len, 0.494 * len, 0.032 * len, 0.1 * len, 0.014 * len, poly_d)

		for zz in [0.03, 0.09]:
			_box(g, 0, 0.056 * len, zz * len, 0.02 * len, 0.018 * len, 0.022 * len, metal)
		_cyl(g, 0, 0.082 * len, 0.052 * len, 0.019 * len, 0.164 * len, dark)
		_cyl(g, 0, 0.082 * len, -0.0525 * len, 0.024 * len, 0.045 * len, dark)
		_cyl(g, 0, 0.082 * len, -0.081 * len, 0.027 * len, 0.012 * len, dark)
		_cyl(g, 0, 0.082 * len, -0.0855 * len, 0.02 * len, 0.004 * len, _m(9413820, true))
		_cyl(g, 0, 0.082 * len, 0.148 * len, 0.023 * len, 0.028 * len, dark)
		_box(g, 0, 0.099 * len, 0.052 * len, 0.016 * len, 0.014 * len, 0.03 * len, dark)
		if viewmodel:
			_hand(g, 0.0, -0.01 * len, -0.2 * len, 1.0)
			_hand(g, 0.0, -0.075 * len, 0.185 * len, 0.9)
	elif key == "m16":
		_cyl(g, 0, 0, -0.475 * len, 0.014 * len, 0.05 * len, steel)
		_cyl(g, 0, 0, -0.357 * len, 0.0115 * len, 0.19 * len, steel)
		_box(g, 0, 0.025 * len, -0.3 * len, 0.018 * len, 0.05 * len, 0.014 * len, poly)
		_box(g, 0, 0.058 * len, -0.3 * len, 0.004 * len, 0.016 * len, 0.004 * len, steel)
		_cyl(g, 0, 0.002 * len, -0.12 * len, 0.026 * len, 0.28 * len, poly)
		for i in 5:
			_cyl(g, 0, 0.002 * len, (-0.21 + i * 0.045) * len, 0.029 * len, 0.009 * len, poly)
		_cyl(g, 0, 0.002 * len, 0.032 * len, 0.026 * len, 0.02 * len, metal)
		_box(g, 0, 0.012 * len, 0.1025 * len, 0.034 * len, 0.036 * len, 0.115 * len, poly)
		_box(g, 0, -0.021 * len, 0.1025 * len, 0.032 * len, 0.03 * len, 0.115 * len, poly)
		_box(g, 0.019 * len, 0.006 * len, 0.055 * len, 0.006 * len, 0.024 * len, 0.014 * len, poly_d)
		_cyl(g, 0.021 * len, 0.008 * len, 0.085 * len, 0.008 * len, 0.014 * len, poly_d, false)

		_box(g, 0, 0.05 * len, 0.058 * len, 0.016 * len, 0.04 * len, 0.02 * len, poly)
		_box(g, 0, 0.05 * len, 0.138 * len, 0.016 * len, 0.04 * len, 0.02 * len, poly)
		_box(g, 0, 0.077 * len, 0.098 * len, 0.014 * len, 0.014 * len, 0.1 * len, poly)
		_box(g, 0, 0.089 * len, 0.13 * len, 0.012 * len, 0.01 * len, 0.016 * len, poly_d)
		_box(g, 0.02 * len, 0.014 * len, 0.17 * len, 0.012 * len, 0.01 * len, 0.03 * len, poly_d)
		_cyl(g, 0, 0.006 * len, 0.169 * len, 0.014 * len, 0.018 * len, metal)
		for i in 3:
			var t: = -0.096 - i * 0.058
			var zz: = 0.088 - i * 0.008
			var seg: = _box(g, 0, t * len, zz * len, 0.026 * len, 0.066 * len, 0.058 * len, poly_d)
			seg.rotation.x = (0.06 + i * 0.08)
		_box(g, 0, -0.04 * len, 0.14 * len, 0.008 * len, 0.005 * len, 0.05 * len, poly)
		var grip: = _box(g, 0, -0.083 * len, 0.163 * len, 0.024 * len, 0.095 * len, 0.034 * len, poly_d)
		grip.rotation.x = -0.38
		var stock: = _box(g, 0, -0.006 * len, 0.34 * len, 0.028 * len, 0.05 * len, 0.3 * len, poly)
		stock.rotation.x = 0.1
		_box(g, 0, -0.021 * len, 0.494 * len, 0.032 * len, 0.1 * len, 0.012 * len, poly_d)
		if viewmodel:
			_hand(g, 0.0, -0.01 * len, -0.12 * len, 1.0)
			_hand(g, 0.0, -0.085 * len, 0.17 * len, 0.9)
	elif key == "ak74":

		_cyl(g, 0, 0, -0.3 * len, 0.011 * len, 0.3 * len, steel)
		_cyl(g, 0, 0, -0.425 * len, 0.014 * len, 0.17 * len, steel)
		_box(g, 0.015 * len, 0.002 * len, -0.44 * len, 0.012 * len, 0.014 * len, 0.05 * len, dark)
		_box(g, -0.015 * len, 0.002 * len, -0.44 * len, 0.012 * len, 0.014 * len, 0.05 * len, dark)

		_box(g, 0, 0.033 * len, -0.365 * len, 0.004 * len, 0.026 * len, 0.006 * len, steel)
		_box(g, 0.01 * len, 0.026 * len, -0.365 * len, 0.004 * len, 0.026 * len, 0.007 * len, metal)
		_box(g, -0.01 * len, 0.026 * len, -0.365 * len, 0.004 * len, 0.026 * len, 0.007 * len, metal)

		_box(g, 0, 0.02 * len, -0.26 * len, 0.018 * len, 0.026 * len, 0.026 * len, metal)
		_cyl(g, 0, 0.026 * len, -0.2 * len, 0.011 * len, 0.13 * len, steel)
		_cyl(g, 0, 0.001 * len, -0.21 * len, 0.023 * len, 0.16 * len, wood)

		_box(g, 0, 0.006 * len, 0.09 * len, 0.03 * len, 0.042 * len, 0.2 * len, metal)
		_cyl(g, 0, 0.027 * len, 0.09 * len, 0.014 * len, 0.19 * len, metal)
		_box(g, 0, 0.046 * len, 0.02 * len, 0.016 * len, 0.014 * len, 0.04 * len, metal)
		_box(g, 0.017 * len, 0.02 * len, 0.12 * len, 0.01 * len, 0.01 * len, 0.04 * len, metal)

		var cy: = -0.034
		var cz: = 0.075
		for i in 4:
			var ang: = 0.12 + i * 0.16
			var seg: = _box(g, 0, cy, cz, 0.022, 0.048, 0.035, plum)
			seg.rotation.x = ang
			cy -= 0.044 * cos(ang)
			cz -= 0.044 * sin(ang)

		_box(g, 0, -0.032 * len, 0.145 * len, 0.008 * len, 0.006 * len, 0.05 * len, metal)
		var grip: = _box(g, 0, -0.068 * len, 0.17 * len, 0.022 * len, 0.095 * len, 0.03 * len, wood2)
		grip.rotation.x = -0.3
		var stock: = _box(g, 0, 0.002 * len, 0.36 * len, 0.026 * len, 0.038 * len, 0.26 * len, wood)
		stock.rotation.x = 0.1
		_box(g, 0, -0.006 * len, 0.487 * len, 0.03 * len, 0.078 * len, 0.028 * len, dark)
		if viewmodel:
			_hand(g, 0.0, -0.012 * len, -0.2 * len, 1.0)
			_hand(g, 0.0, -0.075 * len, 0.178 * len, 0.9)
	elif key == "m82":
		_box(g, 0, 0.02 * len, 0.05 * len, 0.055 * len, 0.1 * len, 0.95 * len, poly)
		_box(g, 0, 0.076 * len, 0.05 * len, 0.03 * len, 0.016 * len, 0.84 * len, poly_d)
		_cyl(g, 0, 0.05 * len, -0.4 * len, 0.018 * len, 0.58 * len, steel)
		_box(g, 0, 0.05 * len, -0.62 * len, 0.052 * len, 0.075 * len, 0.22 * len, metal)
		for i in 3:
			_box(g, 0.027 * len, 0.05 * len, (-0.56 - i * 0.05) * len, 0.008 * len, 0.04 * len, 0.032 * len, dark)
			_box(g, -0.027 * len, 0.05 * len, (-0.56 - i * 0.05) * len, 0.008 * len, 0.04 * len, 0.032 * len, dark)
		var leg_l: = _box(g, -0.035 * len, -0.06 * len, -0.42 * len, 0.012 * len, 0.24 * len, 0.012 * len, metal)
		leg_l.rotation.z = 0.55
		var leg_r: = _box(g, 0.035 * len, -0.06 * len, -0.42 * len, 0.012 * len, 0.24 * len, 0.012 * len, metal)
		leg_r.rotation.z = -0.55
		_box(g, 0, 0.12 * len, -0.02 * len, 0.016 * len, 0.05 * len, 0.02 * len, poly_d)
		_box(g, 0, 0.12 * len, 0.1 * len, 0.016 * len, 0.05 * len, 0.02 * len, poly_d)
		_box(g, 0, 0.155 * len, 0.04 * len, 0.014 * len, 0.016 * len, 0.14 * len, poly_d)
		var grip: = _box(g, 0, -0.062 * len, 0.19 * len, 0.03 * len, 0.11 * len, 0.05 * len, poly_d)
		grip.rotation.x = -0.3
		_box(g, 0, -0.02 * len, 0.16 * len, 0.008 * len, 0.006 * len, 0.06 * len, metal)
		_box(g, 0, -0.075 * len, 0.085 * len, 0.032 * len, 0.1 * len, 0.07 * len, poly_d)
		_box(g, 0, -0.126 * len, 0.092 * len, 0.03 * len, 0.02 * len, 0.064 * len, dark)
		_box(g, 0, 0.03 * len, 0.52 * len, 0.045 * len, 0.09 * len, 0.16 * len, poly)
		_box(g, 0, 0.09 * len, 0.47 * len, 0.036 * len, 0.03 * len, 0.1 * len, poly_d)
		_box(g, 0, -0.016 * len, 0.596 * len, 0.05 * len, 0.08 * len, 0.02 * len, poly_d)
		var mp: = _box(g, 0, -0.055 * len, 0.55 * len, 0.014 * len, 0.1 * len, 0.014 * len, metal)
		mp.rotation.x = 0.15
		_cyl(g, 0, 0.115 * len, -0.02 * len, 0.028 * len, 0.3 * len, dark)
		_cyl(g, 0, 0.115 * len, -0.155 * len, 0.034 * len, 0.06 * len, dark)
		_cyl(g, 0, 0.115 * len, -0.178 * len, 0.026 * len, 0.005 * len, _m(9413820, true))
		_cyl(g, 0, 0.115 * len, 0.1 * len, 0.024 * len, 0.05 * len, dark)
		_box(g, 0, 0.083 * len, -0.06 * len, 0.016 * len, 0.03 * len, 0.02 * len, metal)
		_box(g, 0, 0.083 * len, 0.02 * len, 0.016 * len, 0.03 * len, 0.02 * len, metal)
		if viewmodel:
			_hand(g, 0.0, -0.01 * len, -0.3 * len, 1.0)
			_hand(g, 0.0, -0.065 * len, 0.2 * len, 0.9)
	else:

		var sc: = len / 0.3
		var slide_w: = (0.034 if key == "deagle" else 0.028) * sc
		var slide_h: = (0.026 if key == "deagle" else 0.02) * sc
		var slide_l: = (0.62 if key == "deagle" else 0.55) * len
		var slide_z: = -0.02 * len
		_box(g, 0, 0.0, slide_z, slide_w, slide_h, slide_l, steel)
		_box(g, 0, slide_h / 2 + 0.004 * sc, slide_z, 0.012 * sc, 0.007 * sc, slide_l * 0.8, dark)
		_box(g, slide_w / 2, 0.0, slide_z + slide_l * 0.16, 0.004, slide_h * 0.5, slide_l * 0.28, dark)
		for i in 3:
			_box(g, slide_w / 2, 0.0, slide_z + slide_l * (0.3 + i * 0.06), 0.004, slide_h * 0.6, 0.006 * len, dark)
			_box(g, - slide_w / 2, 0.0, slide_z + slide_l * (0.3 + i * 0.06), 0.004, slide_h * 0.6, 0.006 * len, dark)
		_cyl(g, 0, 0.0, slide_z - slide_l / 2, (0.011 if key == "deagle" else 0.008) * sc, 0.02 * len, dark)
		_box(g, 0, - slide_h / 2 - 0.008 * sc, slide_z + 0.02 * len, slide_w * 0.92, 0.016 * sc, slide_l * 0.72, metal)
		_box(g, 0, - slide_h / 2 - 0.022 * sc, slide_z + slide_l * 0.3, 0.007 * len, 0.005 * len, 0.055 * len, metal)
		_box(g, 0.005 * len, - slide_h / 2 - 0.012 * sc, slide_z + slide_l * 0.3, 0.005 * len, 0.016 * len, 0.006 * len, steel)
		var gh: = 0.105 * sc
		var grip: = _box(g, 0, - slide_h / 2 - gh / 2 - 0.004, 0.105 * len, slide_w * 0.95, gh, 0.034 * sc, poly_d)
		grip.rotation.x = -0.2
		_box(g, slide_w * 0.5, - slide_h / 2 - gh / 2 - 0.004, 0.105 * len, 0.003, gh * 0.7, 0.024 * sc, _m(5913126))
		_box(g, - slide_w * 0.5, - slide_h / 2 - gh / 2 - 0.004, 0.105 * len, 0.003, gh * 0.7, 0.024 * sc, _m(5913126))
		_box(g, 0, slide_h * 0.2, slide_z + slide_l / 2 + 0.009 * len, 0.01 * len, 0.016 * len, 0.012 * len, steel)
		_box(g, 0, slide_h / 2 + 0.007 * sc, slide_z - slide_l * 0.42, 0.005 * len, 0.012 * len, 0.008 * len, steel)
		_box(g, 0, slide_h / 2 + 0.006 * sc, slide_z + slide_l * 0.42, 0.02 * len, 0.01 * len, 0.008 * len, dark)
		if viewmodel:
			_hand(g, 0.0, -0.085 * sc, 0.1 * len, 1.0)
			_hand(g, -0.012, -0.095 * sc, 0.155 * len, 0.85)
	if attach.get("sup", false):
		_cyl(g, 0, 0, - len / 2.0 - 0.055, 0.013, 0.115, dark)
	if attach.get("dot", false) and key in ["ak74", "m16"]:
		_box(g, 0, 0.05, 0.02, 0.02, 0.01, 0.05, dark)
		_box(g, 0, 0.068, 0.02, 0.024, 0.026, 0.032, dark)
		_box(g, 0, 0.068, 0.004, 0.008, 0.008, 0.004, _m(13777962))
	if attach.get("pso", false) and key in ["ak74", "m16"]:
		_box(g, 0, 0.052, 0.05, 0.02, 0.03, 0.045, dark)
		_cyl(g, 0, 0.082, 0.05, 0.018, 0.19, dark)
		_box(g, 0, 0.082, -0.05, 0.034, 0.034, 0.018, dark)
		_box(g, 0, 0.082, 0.148, 0.03, 0.03, 0.018, dark)
	g.set_meta("muzzle_z", - len / 2.0)
	return g


static func build_ak74_vm(attach: = {}) -> Node3D:
	var scene: PackedScene = load("res://assets/aks74u_vm_r.scn")
	var root: Node3D = scene.instantiate()
	var mzl: = -0.966
	root.set_meta("muzzle_z", mzl)
	var anims: = root.find_children("*", "AnimationPlayer", true, false)
	if anims.size() > 0:
		root.set_meta("anim", anims[0])
	var dark: = _m(1842206)
	if attach.get("sup", false):
		_cyl(root, 0, 0.008, mzl - 0.05, 0.017, 0.13, dark)
	if attach.get("dot", false):
		_box(root, 0, 0.155, -0.03, 0.026, 0.032, 0.04, dark)
		_box(root, 0, 0.174, -0.049, 0.01, 0.008, 0.006, _m(13777962))
	if attach.get("pso", false):
		_box(root, 0, 0.175, -0.06, 0.022, 0.05, 0.05, dark)
		_cyl(root, 0, 0.235, -0.1, 0.02, 0.2, dark)
		_box(root, 0, 0.235, -0.2, 0.036, 0.036, 0.018, dark)
	return root

static func build_svd_vm(attach: = {}) -> Node3D:
	var scene: PackedScene = load("res://assets/svd_vm_r.scn")
	var root: Node3D = scene.instantiate()
	root.rotation.x = -PI / 2
	root.scale = Vector3.ONE * 0.00059
	root.set_meta("muzzle_z", -0.61)
	return root

static func build_mannequin(team: String) -> Dictionary:
	var root: = Node3D.new()
	var uni_h: = 6253372 if team == "RU" else 7236181
	var uni: = _m(uni_h)
	var vest: = _m(3093288)
	var helm: = _m(3949106)
	var skin: = _m(11569512)
	var torso: = _box(root, 0, 1.12, 0, 0.38, 0.52, 0.22, uni)
	_box(root, 0, 1.18, 0, 0.4, 0.34, 0.26, vest)
	var head: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	head.mesh = sm
	head.material_override = skin
	head.position = Vector3(0, 1.55, 0)
	root.add_child(head)
	var helmet: = MeshInstance3D.new()
	var hm: = SphereMesh.new()
	hm.radius = 0.125
	hm.height = 0.25
	helmet.mesh = hm
	helmet.material_override = helm
	helmet.position = Vector3(0, 1.6, 0)
	root.add_child(helmet)
	var leg_l: = _box(root, -0.1, 0.4, 0, 0.15, 0.78, 0.17, uni)
	var leg_r: = _box(root, 0.1, 0.4, 0, 0.15, 0.78, 0.17, uni)
	leg_l.position.y = 0.78 / 2
	leg_r.position.y = 0.78 / 2
	var arm_l: = _box(root, -0.27, 1.15, -0.06, 0.12, 0.5, 0.14, uni)
	arm_l.rotation.x = -0.9
	var arm_r: = _box(root, 0.24, 1.15, -0.1, 0.12, 0.5, 0.14, uni)
	arm_r.rotation.x = -1.35
	return {"root": root, "leg_l": leg_l, "leg_r": leg_r, "torso": torso}
