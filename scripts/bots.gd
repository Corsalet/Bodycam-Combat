class_name BotBody
extends CharacterBody3D


var main: Node
var team: = "RU"
var bname: = ""
var wkey: = "ak74"
var hp: = 100
var alive: = true
var kills: = 0
var deaths: = 0
var respawn_t: = 0.0
var enemy: Node3D = null
var enemy_is_player: = false
var next_think: = 0.0
var next_shot: = 0.0
var burst: = 0
var pause_t: = 0.0
var anim_t: = 0.0
var parts: Dictionary = {}
var gun: Node3D
var flash_node: Node3D
var sol: Node3D
var anim: AnimationPlayer
var anim_state: = ""
var walk_spd: = 3.8
var frozen: = false
var squad_idx: = -1
var squad_off: = Vector3.ZERO
var reinforcing: = false
var reinforce_to: = Vector3.ZERO
var reinforce_sq: = -1
var _settled: = false
static var _avg_cache: = {}

func setup(m: Node, p_team: String, p_name: String, p_wkey: String) -> void :
	main = m
	team = p_team
	bname = p_name
	wkey = p_wkey
	collision_layer = 4
	collision_mask = 3
	var cs: = CollisionShape3D.new()
	var cap: = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

	parts = {"root": Node3D.new()}
	add_child(parts["root"])
	sol = (load("res://assets/soldier_r.scn") as PackedScene).instantiate()
	sol.scale = Vector3.ONE * 0.51
	sol.rotation.y = PI
	parts["root"].add_child(sol)
	anim = sol.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	anim.playback_default_blend_time = 0.15

	var tint: = Color(1.0, 1.0, 1.0) if team == "RU" else Color(1.45, 1.18, 0.72)
	var flat_web: bool = OS.has_feature("web")
	if flat_web:

		for mi0 in sol.find_children("*", "MeshInstance3D", true, false):
			var m0: = mi0 as MeshInstance3D
			var vc: = 0
			for i0 in m0.mesh.get_surface_count():
				var arr: = m0.mesh.surface_get_arrays(i0)
				var vv: Variant = arr[Mesh.ARRAY_VERTEX]
				if vv != null:
					vc += (vv as PackedVector3Array).size()
			if vc < 12:
				m0.visible = false
	for mi in sol.find_children("*", "MeshInstance3D", true, false):
		var mesh: = mi as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var mat: = mesh.get_active_material(i)
			if mat is BaseMaterial3D:
				var bm: = mat as BaseMaterial3D
				if flat_web:

					var sm: = StandardMaterial3D.new()
					var key: int = bm.albedo_texture.get_rid().get_id() if bm.albedo_texture != null else 0
					var ac: Color
					if key != 0 and _avg_cache.has(key):
						ac = _avg_cache[key]
					else:
						ac = bm.albedo_color
						if bm.albedo_texture != null:
							var img: Image = bm.albedo_texture.get_image()
							if img != null:
								if img.is_compressed():
									img.decompress()
								img.resize(8, 8)
								var acc: = Color(0, 0, 0)
								var cnt: = 0
								for py in 8:
									for px in 8:
										acc += img.get_pixel(px, py)
										cnt += 1
								ac = acc / float(cnt)
						if key != 0:
							_avg_cache[key] = ac
					sm.albedo_color = ac * tint
					sm.roughness = 0.9
					mesh.set_surface_override_material(i, sm)
				else:
					var dup: = bm.duplicate() as BaseMaterial3D
					dup.albedo_color = dup.albedo_color * tint
					mesh.set_surface_override_material(i, dup)

	flash_node = Node3D.new()
	flash_node.position = Vector3(0.25, 1.38, -0.55)
	parts["root"].add_child(flash_node)
	respawn(true)

func _def() -> Dictionary:
	return Guns.WPN[wkey]

func respawn(instant: = false) -> void :
	var base: Dictionary = World.BASES[team]
	var px: float = base["x"] + randf_range(-9, 9)
	var pz: float = base["z"] + (randf_range(-18, -12) if team == "US" else randf_range(12, 18))
	position = Vector3(px, main.ground_y(px, pz) + 1.0, pz)
	velocity = Vector3.ZERO
	hp = 100
	alive = true
	enemy = null
	next_think = randf_range(0, 0.5)
	anim_state = ""
	visible = true
	if not instant:
		deaths += 1

func _physics_process(dt: float) -> void :
	if not _settled:
		_settled = true
		position.y = main.ground_y(position.x, position.z) + 1.0
		velocity = Vector3.ZERO
	if main.state != "play":
		return
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			respawn()
		return
	next_think -= dt
	if next_think <= 0.0:
		next_think = randf_range(0.3, 0.6)
		_think()
	var moving: = false
	if frozen:
		velocity.x = 0
		velocity.z = 0
	if enemy != null and is_instance_valid(enemy):
		if not frozen:
			_combat_move(dt)
			moving = true
		_shoot(dt)
	elif not frozen and parts.has("goal"):
		var goal: Vector3 = reinforce_to if reinforcing else parts["goal"]
		var to: = goal - global_position
		to.y = 0
		if to.length() > 2.0:
			velocity.x = to.normalized().x * walk_spd
			velocity.z = to.normalized().z * walk_spd
			rotation.y = atan2( - to.x, - to.z) if absf(to.z) > 0.001 else ( - PI / 2.0 if to.x > 0.0 else PI / 2.0)
			moving = true
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0
	velocity.y -= 13.0 * dt
	move_and_slide()
	if global_position.y < main.ground_y(global_position.x, global_position.z) - 6.0:
		respawn()


	var want: = ""
	if not alive:
		want = "simple death"
	elif enemy != null and not moving:
		want = "simple shoot"
	elif moving:
		want = "run"
	else:
		want = "idle simple"
	if want != anim_state and anim:
		anim_state = want
		anim.play(want, 0.18)
	if anim and anim_state == "run":
		anim.speed_scale = clampf(walk_spd / 3.0, 0.8, 1.6)
	else:
		anim.speed_scale = 1.0

func _think() -> void :

	var best: Node3D = null
	var best_d: = 95.0
	enemy_is_player = false
	var pc: PlayerBody = main.player
	if pc.alive and pc.team != team:
		var d: float = Vector2(pc.global_position.x - global_position.x, pc.global_position.z - global_position.z).length()
		if d < best_d and _los(pc.global_position + Vector3(0, 1.3, 0)):
			best = pc
			best_d = d
			enemy_is_player = true
	for b in main.bots:
		if b == self or not b.alive or b.team == team:
			continue
		var d: float = Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z).length()
		if d < best_d and _los(b.global_position + Vector3(0, 1.2, 0)):
			best = b
			best_d = d
			enemy_is_player = false
	enemy = best

func _los(target: Vector3) -> bool:
	var from: = global_position + Vector3(0, 1.5, 0)
	var dir: = target - from
	var q: = PhysicsRayQueryParameters3D.create(from, target, 1)
	return main.space_state.intersect_ray(q).is_empty()

func _combat_move(dt: float) -> void :
	var to: = enemy.global_position - global_position
	to.y = 0
	var d: = to.length()
	rotation.y = atan2( - to.x, - to.z) if absf(to.z) > 0.001 else ( - PI / 2.0 if to.x > 0.0 else PI / 2.0)

	var want: = 55.0 if _def()["scope"] else 16.0
	var v: = Vector3.ZERO
	if d > want * 1.3:
		v = to.normalized() * walk_spd
	elif d < want * 0.6:
		v = - to.normalized() * walk_spd * 0.7
	else:
		v = Vector3( - to.z, 0, to.x).normalized() * walk_spd * 0.45 * sin(anim_t * 0.7)
	velocity.x = v.x
	velocity.z = v.z

func _shoot(dt: float) -> void :
	next_shot -= dt
	if next_shot > 0.0 or pause_t > 0.0:
		if pause_t > 0.0:
			pause_t -= dt
		return
	var e: = enemy
	var dist: = Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
	if burst <= 0:
		burst = randi_range(3, 7)
	next_shot = 60.0 / 600.0 + randf_range(0, 0.04)
	burst -= 1
	if burst <= 0:
		pause_t = randf_range(0.4, 1.1)
	var muzzle: = flash_node.global_position
	main.audio.play_shot(wkey, dist)
	main.fx.flash(muzzle, _def()["len"] * 0.7)
	var aim: = e.global_position + (Vector3(0, 1.3, 0) if enemy_is_player else Vector3(0, 1.2, 0))

	var q: = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), aim, 1)
	var los_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var sprint_f: = 0.72 if (enemy_is_player and main.player.sprint) else 1.0
	var hit_chance: float = clampf(0.4 - dist * 0.0038, 0.07, 0.4) * sprint_f
	var will_hit: = los_hit.is_empty() and randf() < hit_chance
	if not will_hit:
		aim += Vector3(randf_range(-1.2, 1.2), randf_range(-0.5, 0.8), randf_range(-1.2, 1.2))

	var t_end: Vector3 = aim if (los_hit.is_empty() or will_hit) else (los_hit["position"] as Vector3)
	main.fx.tracer(muzzle, t_end)
	if will_hit:
		var dmg: = randf_range(8, 17)
		if enemy_is_player:
			main.hurt_player(dmg, bname, _def()["name"])
		else:
			main.hurt_bot(e, dmg * 2.2, self, _def()["name"])
	else:
		main.audio.play("whiz", -6.0)

func die(killer, weapon: String) -> void :
	if not alive:
		return
	alive = false
	respawn_t = 7.0
	main.tickets[team] = maxf(0.0, main.tickets[team] - 1.0)
	var killer_name: = "?"
	var killer_team: = "?"
	if killer is BotBody:
		killer_name = killer.bname
		killer_team = killer.team
		killer.kills += 1
	elif killer is String and killer == "player":
		killer_name = "ВЫ"
		killer_team = main.player.team
		main.player.kills += 1
		main.audio.play("kill")
	main.hud.add_feed(killer_name, killer_team, bname, team, weapon)

	anim_state = ""
	enemy = null
