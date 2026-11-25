class_name PlayerBody
extends CharacterBody3D


const EYE: = 1.62
var main: Node
var team: = "RU"
var cls: = "assault"
var hp: = 100.0
var alive: = true
var kills: = 0
var deaths: = 0
var caps: = 0
var respawn_t: = 0.0
var yaw: = 0.0
var pitch: = 0.0
var weapons: Array = []
var w_idx: = 0
var reload_t: = 0.0
var fire_t: = 0.0
var ads: = false
var sprint: = false
var heal_t: = 0.0
var bandages: = 5
var recoil: = 0.0
var cam: Camera3D
var vm_pivot: Node3D
var vm_gun: Node3D
var on_ground: = true
var _settled: = false
var motion_grace: = 0.0
var spawn_prot: = 0.0
var _lmb_prev: = false
var money: = 300
var attachs: = {}
var shop_open: = false
var _key_prev: = {}
var vm_anim: AnimationPlayer
var vm_is_glb: = false
var _putin_name: = ""
var _fire_name: = ""
var _reload_name: = ""
const SHOP: = [
	{"id": "dot", "name": "КОЛЛИМАТОР 1П63", "price": 250}, 
	{"id": "pso", "name": "ОПТИКА ПСО-1", "price": 400}, 
	{"id": "sup", "name": "ГЛУШИТЕЛЬ", "price": 300}, 
	{"id": "ext", "name": "РАСШ. МАГАЗИН", "price": 200}, 
]

func setup(m: Node, p_team: String, p_cls: String) -> void :
	main = m
	team = p_team
	cls = p_cls
	collision_mask = 1
	collision_layer = 2
	var cs: = CollisionShape3D.new()
	var cap: = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.position = Vector3(0, EYE, 0)
	add_child(cam)
	vm_pivot = Node3D.new()
	cam.add_child(vm_pivot)
	for key in Guns.CLASSES[team][cls]:
		weapons.append({"key": key, "mag": Guns.WPN[key]["mag"], "reserve": Guns.WPN[key]["reserve"]})
	equip(0)

func equip(idx: int) -> void :
	w_idx = idx
	if vm_gun:
		vm_gun.queue_free()
		vm_gun = null
	var key: String = weapons[w_idx]["key"]
	vm_is_glb = false
	vm_anim = null
	if key == "ak74":
		vm_gun = Guns.build_ak74_vm(attachs.get(key, {}))
		vm_is_glb = true
		vm_anim = vm_gun.get_meta("anim") if vm_gun.has_meta("anim") else null
		if vm_anim:
			for a in vm_anim.get_animation_list():
				if a.contains("Put_in"):
					_putin_name = a
				elif a.contains("Fire_single"):
					_fire_name = a
				elif a.contains("Reload_t"):
					_reload_name = a
			if _putin_name != "":
				vm_anim.play(_putin_name)
				vm_anim.seek(vm_anim.get_animation(_putin_name).length, true)
	elif key == "svd":
		vm_gun = Guns.build_svd_vm(attachs.get(key, {}))
		vm_is_glb = true
	else:
		vm_gun = Guns.build(key, true, attachs.get(key, {}))
	vm_pivot.add_child(vm_gun)
	reload_t = 0.0
	main.hud.set_ammo(weapons[w_idx]["mag"], weapons[w_idx]["reserve"], Guns.WPN[key]["name"], Guns.WPN[key]["mode"])
	main.hud.show_switch(Guns.WPN[key]["name"])

func _unhandled_input(event: InputEvent) -> void :
	if not alive or main.state != "play":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if motion_grace > 0.0:
			return
		var e: = event as InputEventMouseMotion
		var ss: float = clampf(cam.fov / 75.0, 0.22, 1.0)
		yaw -= e.relative.x * 0.0021 * main.mouse_sens * ss
		pitch -= e.relative.y * 0.0021 * main.mouse_sens * ss
		pitch = clampf(pitch, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_w(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_w(1)

func switch_w(dir: int) -> void :
	var ni: = (w_idx + dir + weapons.size()) % weapons.size()
	if ni != w_idx:
		equip(ni)

func _def() -> Dictionary:
	return Guns.WPN[weapons[w_idx]["key"]]

func _att(id: String) -> bool:
	return attachs.get(weapons[w_idx]["key"], {}).get(id, false)

func _optic() -> String:
	return attachs.get(weapons[w_idx]["key"], {}).get("optic", "")

func _mag_cap() -> int:
	return _def()["mag"] + (15 if _att("ext") else 0)

func buy(i: int) -> void :
	if i < 0 or i >= SHOP.size():
		return
	var item: Dictionary = SHOP[i]
	var key: String = weapons[w_idx]["key"]
	if key not in ["ak74", "m16"]:
		main.hud.shop_msg("ТОЛЬКО ДЛЯ АВТОМАТОВ")
		return
	var att: Dictionary = attachs.get(key, {})
	if item["id"] in ["dot", "pso"] and att.get("optic", "") == item["id"]:
		main.hud.shop_msg("УЖЕ УСТАНОВЛЕНО")
		return
	if item["id"] in ["sup", "ext"] and att.get(item["id"], false):
		main.hud.shop_msg("УЖЕ УСТАНОВЛЕНО")
		return
	if money < item["price"]:
		main.hud.shop_msg("НЕ ХВАТАЕТ ₽")
		return
	money -= item["price"]
	if item["id"] in ["dot", "pso"]:
		att["optic"] = item["id"]
	else:
		att[item["id"]] = true
	attachs[key] = att
	main.audio.play("cap_done")
	main.hud.set_money(money)
	main.hud.shop_msg(item["name"] + " УСТАНОВЛЕН")
	equip(w_idx)

func _physics_process(dt: float) -> void :
	motion_grace = maxf(0.0, motion_grace - dt)

	if not _settled:
		_settled = true
		global_position.y = main.ground_y(global_position.x, global_position.z) + 1.0
		velocity = Vector3.ZERO
	if main.state != "play":
		return
	if not alive:
		respawn_t -= dt
		main.hud.set_death_timer(respawn_t)
		if respawn_t <= 0.0:
			respawn()
		return
	var def: = _def()
	sprint = Input.is_physical_key_pressed(KEY_SHIFT) and reload_t <= 0.0
	var mx: = 0.0
	var mz: = 0.0
	if Input.is_physical_key_pressed(KEY_W):
		mz -= 1
	if Input.is_physical_key_pressed(KEY_S):
		mz += 1
	if Input.is_physical_key_pressed(KEY_A):
		mx -= 1
	if Input.is_physical_key_pressed(KEY_D):
		mx += 1
	var spd: float = 2.4 if ads else (7.0 if sprint else 4.7)
	var moving: = (mx != 0.0 or mz != 0.0)
	var fwd: = Vector3( - sin(yaw), 0, - cos(yaw))
	var right: = Vector3(cos(yaw), 0, - sin(yaw))
	var hvel: = Vector3.ZERO
	if moving:
		hvel = (fwd * - mz + right * mx).normalized() * spd
	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity.y -= 13.0 * dt
	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = 4.6
	spawn_prot = maxf(0.0, spawn_prot - dt)
	ads = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and reload_t <= 0.0
	if Input.is_physical_key_pressed(KEY_R) and reload_t <= 0.0:
		var w: Dictionary = weapons[w_idx]
		if w["mag"] < _mag_cap() and w["reserve"] > 0:
			reload_t = def["reload"]
			main.audio.play("reload")
			if vm_anim and _reload_name != "":
				vm_anim.play(_reload_name, 0.1)
				vm_anim.speed_scale = def["reload"] / vm_anim.get_animation(_reload_name).length

	var kb: = Input.is_physical_key_pressed(KEY_B)
	if kb and not _key_prev.get("b", false):
		shop_open = not shop_open
		main.hud.show_shop(shop_open)
		main.hud.set_money(money)
	_key_prev["b"] = kb
	if shop_open:
		for i in 4:
			var kp: = Input.is_physical_key_pressed(KEY_1 + i)
			if kp and not _key_prev.get("n%d" % i, false):
				buy(i)
			_key_prev["n%d" % i] = kp
	if not shop_open and (Input.is_physical_key_pressed(KEY_3) or Input.is_physical_key_pressed(KEY_H)) and heal_t <= 0.0 and bandages > 0 and hp < 100:
		heal_t = 2.0
		bandages -= 1
		main.audio.play("heal")
	move_and_slide()

	cam.rotation = Vector3(pitch, 0, 0)
	rotation = Vector3(0, yaw, 0)
	var scoped: bool = ads and (def["scope"] or _optic() == "pso")
	var target_fov: float = 20.0 if scoped else def["ads_fov"] if ads else 75.0
	cam.fov = lerpf(cam.fov, target_fov, minf(1.0, 12.0 * dt))
	var tp: Vector3
	if vm_is_glb:
		tp = def["ads_pos"] if ads else def["hip_pos"]
		if ads and _optic() == "dot":
			tp = Vector3(0, -0.068, def["ads_pos"].z)
	else:
		tp = def["ads_pos"] if ads else def["hip_pos"]
		if ads and _optic() == "dot":
			tp = Vector3(0, -0.068, def["ads_pos"].z)
	vm_pivot.position = vm_pivot.position.lerp(tp, minf(1.0, 14.0 * dt))
	vm_gun.visible = not scoped
	recoil = maxf(0.0, recoil - dt * 6.0)
	vm_pivot.rotation.x = lerpf(vm_pivot.rotation.x, recoil * 0.06, minf(1.0, 10.0 * dt))
	fire_t -= dt
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			var w: Dictionary = weapons[w_idx]
			var need: int = _mag_cap() - w["mag"]
			var take: int = mini(need, w["reserve"])
			w["mag"] = w["mag"] + take
			w["reserve"] = w["reserve"] - take
			main.hud.set_ammo(w["mag"], w["reserve"], def["name"], def["mode"])
			if vm_anim and _putin_name != "":
				vm_anim.speed_scale = 1.0
				vm_anim.play(_putin_name, 0.1)
				vm_anim.seek(vm_anim.get_animation(_putin_name).length, true)
	if heal_t > 0.0:
		heal_t -= dt
		hp = minf(100.0, hp + 20.0 * dt)

	if global_position.y < main.ground_y(global_position.x, global_position.z) - 4.0:
		print("RESCUE y=", snappedf(global_position.y, 0.1))
		global_position = Vector3(global_position.x, main.ground_y(global_position.x, global_position.z) + 1.0, global_position.z)
		velocity = Vector3.ZERO
	var lmb: = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if lmb and fire_t <= 0.0 and reload_t <= 0.0 and (def["auto"] or not _lmb_prev):
		if weapons[w_idx]["mag"] > 0:
			_fire(def)
		else:
			fire_t = 0.25
			main.audio.play("dry")
	_lmb_prev = lmb
	main.hud.set_health(hp, bandages)
	main.hud.set_heal(heal_t / 2.0)
	main.hud.set_ads_scope(scoped)
	main.hud.set_dot(ads and _optic() == "dot" and not scoped)

func _fire(def: Dictionary) -> void :
	var w: Dictionary = weapons[w_idx]
	w["mag"] = w["mag"] - 1
	fire_t = 60.0 / def["rpm"]
	if vm_anim and _fire_name != "":
		vm_anim.play(_fire_name, 0.05)
	main.audio.play(weapons[w_idx]["key"], -10.0 if _att("sup") else 0.0)
	var spread_deg: float = (def["s_ads"] if ads else def["s_hip"]) + recoil * 0.25
	recoil += def["kick"]
	pitch += def["kick"] * 0.008
	var muzzle: = vm_gun.global_position + vm_gun.global_transform.basis * Vector3(0, 0, vm_gun.get_meta("muzzle_z"))
	main.fx.flash(muzzle, def["len"] * (0.4 if _att("sup") else 0.8), true)
	var hits: = 0
	var shots: = 1
	if not ads and def["auto"] and def["s_hip"] > 1.3:
		shots = 1
	for i in shots:
		var dir: = _spread_dir(spread_deg)
		var hit: Dictionary = main.raycast_hit(cam.global_position, dir, 400.0, self)
		if hit.is_empty():
			main.fx.tracer(muzzle, cam.global_position + dir * 120.0)
		else:
			main.fx.tracer(muzzle, hit["position"])
			var collider: Object = hit["collider"]
			if collider is BotBody and (collider as BotBody).team != team:
				var bot: = collider as BotBody
				var rel: float = hit["position"].y - bot.global_position.y
				var bx: float = (bot.global_transform.basis.inverse() * (hit["position"] - bot.global_position)).x
				var zone: String = "ГОЛОВА" if rel > 1.42 else ("НОГА" if rel < 0.72 else ("РУКА" if absf(bx) > 0.27 else "ТЕЛО"))
				var dmg: float = def["dmg"] * (1.9 if zone == "ГОЛОВА" else 1.0)
				main.hurt_bot(bot, dmg, "player", def["name"])
				main.fx.blood(hit["position"])
				main.audio.play("headshot" if zone == "ГОЛОВА" else "hit")
				main.hud.hitzone(zone)
				hits += 1
			else:
				main.fx.dust(hit["position"])
	main.hud.hitmarker(hits > 0)
	main.hud.set_ammo(w["mag"], w["reserve"], def["name"], def["mode"])

func _spread_dir(spread_deg: float) -> Vector3:
	var a: = deg_to_rad(spread_deg) * sqrt(randf()) * 0.5
	var b: = randf() * TAU
	var dir: = - cam.global_transform.basis.z
	var up: = cam.global_transform.basis.y
	var right: = cam.global_transform.basis.x
	return (dir + right * (cos(b) * tan(a)) + up * (sin(b) * tan(a))).normalized()

func die(killer_name: String, weapon: String) -> void :
	if not alive:
		return
	alive = false
	hp = 0
	deaths += 1
	respawn_t = 6.0
	main.audio.play("death")
	main.hud.show_death(killer_name, weapon)

func respawn() -> void :
	var base: Dictionary = World.BASES[team]
	var px: float = base["x"] + randf_range(-7, 7)
	var pz: float = base["z"] + (randf_range(-18, -13) if team == "US" else randf_range(13, 18))
	print("RESPAWN th=", snappedf(World.terrain_h(px, pz), 0.1), " gy=", snappedf(main.ground_y(px, pz), 0.1))
	global_position = Vector3(px, main.ground_y(px, pz) + 1.0, pz)
	velocity = Vector3.ZERO
	hp = 100
	alive = true
	spawn_prot = 2.5
	heal_t = 0.0
	bandages = 5
	for w2 in weapons:
		var d2: Dictionary = Guns.WPN[w2["key"]]
		w2["mag"] = d2["mag"] + (15 if attachs.get(w2["key"], {}).get("ext", false) else 0)
		w2["reserve"] = d2["reserve"]
	var w: Dictionary = weapons[w_idx]
	main.hud.hide_death()
	main.hud.set_ammo(w["mag"], w["reserve"], _def()["name"], _def()["mode"])
