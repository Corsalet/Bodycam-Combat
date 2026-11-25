extends Node3D


const VER: = "0.4.7 G1"

var state: = "menu"
var mouse_sens: = 1.0
var audio: BcAudio
var fx: Fx
var hud: Hud
var player: PlayerBody
var bots: Array[BotBody] = []
var points: Array[Dictionary] = []
var squads: Array[Dictionary] = []
var _squad_t: = 0.0
var main_hurt_for_test: = false
var tickets: = {"RU": 250.0, "US": 250.0}
var time_left: = 600.0
var elapsed: = 0.0
var space_state: PhysicsDirectSpaceState3D
var test_mode: = false
var unlock_t: = 0.0
var _dbg_t: = 0.0
var _test_frames: = 0
var names_left: = {"RU": 0, "US": 0}
const BOT_NAMES: = {
	"RU": ["Волков", "Морозов", "Соколов", "Орлов", "Кузнецов", "Белов", "Зайцев", "Громов", "Данилов", "Ильин"], 
	"US": ["Miller", "Carter", "Brooks", "Hayes", "Reed", "Coleman", "Barnes", "Turner", "Ward", "Quinn"], 
}

func _ready() -> void :
	seed(int(Time.get_unix_time_from_system() * 1000.0) % 2147483647)
	space_state = get_world_3d().direct_space_state
	_env()
	World.build(self)
	audio = BcAudio.new()
	attach_audio()
	fx = Fx.new()
	fx.setup(self)
	hud = Hud.new()
	hud.main = self
	WorldFx.post_fx(self)
	add_child(hud)
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search")).contains("autotest=1"):
		call_deferred("_autostart")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.build()
	hud.show_menu()
	points = [
		{"id": "A", "name": "ХУТОР", "x": -110.0, "z": -90.0, "r": 15.0, "owner": null, "prog": 0.0, "contested": false}, 
		{"id": "B", "name": "ДЕПО", "x": 0.0, "z": 0.0, "r": 16.0, "owner": null, "prog": 0.0, "contested": false}, 
		{"id": "C", "name": "БЛОКПОСТ", "x": 120.0, "z": 100.0, "r": 15.0, "owner": null, "prog": 0.0, "contested": false}, 
	]
	hud.set_points(points)

	for p in points:
		var pole: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.09
		cm.height = 6.0
		pole.mesh = cm
		pole.material_override = StandardMaterial3D.new()
		pole.position = Vector3(p["x"] + 1.3, World.terrain_h(p["x"], p["z"]) + 3.0, p["z"])
		add_child(pole)
		var flag: = MeshInstance3D.new()
		var pm: = PlaneMesh.new()
		pm.orientation = PlaneMesh.FACE_Z
		pm.size = Vector2(2.2, 1.4)
		flag.mesh = pm
		var fm: = StandardMaterial3D.new()
		fm.albedo_color = Color(0.42, 0.42, 0.4)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = fm
		flag.position = Vector3(p["x"] + 2.5, World.terrain_h(p["x"], p["z"]) + 5.2, p["z"])
		flag.rotation.y = 0.85
		add_child(flag)
		p["flag"] = fm
	if DisplayServer.get_name() == "web":
		print("BOOT_OK")
	if "--menushot" in OS.get_cmdline_user_args():
		call_deferred("_run_menushot")
	if "--smoke" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("_run_test")
	if "--shots" in OS.get_cmdline_user_args():
		call_deferred("_run_shots")

func attach_audio() -> void :
	for p in audio._pool:
		add_child(p)

func _env() -> void :
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(0.82, 0.79, 0.72)
	add_child(sun)
	var we: = WorldEnvironment.new()
	var e: = Environment.new()
	var sky: = Sky.new()
	var sm: = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.2, 0.21, 0.23)
	sm.sky_horizon_color = Color(0.34, 0.32, 0.27)
	sm.ground_bottom_color = Color(0.1, 0.09, 0.08)
	sm.ground_horizon_color = Color(0.34, 0.32, 0.27)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.58, 0.47, 0.36)
	e.ambient_light_energy = 1.15
	e.fog_enabled = true
	e.fog_light_color = Color(0.15, 0.14, 0.12)


	e.fog_density = 0.0 if DisplayServer.get_name() == "web" else 0.0026
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.0
	e.adjustment_contrast = 1.07
	e.adjustment_saturation = 0.8
	we.environment = e
	add_child(we)
	WorldFx.upgrade_environment(e, sun)

func _autostart() -> void :
	test_mode = true
	start_match("RU", "assault")

func start_match(team: String, cls: String) -> void :
	for b in bots:
		b.queue_free()
	bots.clear()

	if is_instance_valid(player):
		player.queue_free()
	player = PlayerBody.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.setup(self, team, cls)
	player.yaw = 0.0 if team == "RU" else PI
	add_child(player)
	var sx: float = World.BASES[team]["x"]
	var sz: float = World.BASES[team]["z"] + (18.0 if team == "RU" else -18.0)
	print("SPAWN th=", snappedf(World.terrain_h(sx, sz), 0.1), " gy=", snappedf(ground_y(sx, sz), 0.1))
	player.global_position = Vector3(sx, ground_y(sx, sz) + 1.0, sz)
	player.rotation.y = player.yaw
	player.motion_grace = 0.35

	var foe: = "US" if team == "RU" else "RU"
	names_left = {"RU": 0, "US": 0}
	for t in [foe, team]:
		var n: = 7 if t == foe else 6
		for i in n:
			var bname: String = BOT_NAMES[t][names_left[t] %BOT_NAMES[t].size()]
			names_left[t] += 1
			var wkey: = ("svd" if t == "RU" else "m82") if i % 4 == 3 else ("ak74" if t == "RU" else "m16")
			var bot: = BotBody.new()
			bot.process_mode = Node.PROCESS_MODE_PAUSABLE
			bot.setup(self, t, bname, wkey)
			add_child(bot)
			bots.append(bot)
	_init_squads()
	tickets = {"RU": 250.0, "US": 250.0}
	time_left = 600.0
	elapsed = 0.0
	for p in points:
		p["owner"] = null
		p["prog"] = 0.0
		p["contested"] = false
		(p["flag"] as StandardMaterial3D).albedo_color = Color(0.42, 0.42, 0.4)
	hud.hide_menu()
	hud.hide_end()
	hud.hide_death()
	state = "play"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_key_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if state == "play":
			state = "pause"
			get_tree().paused = true
			hud.show_pause()
			hud.hide_death()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif state == "pause":
			resume_game()

func resume_game() -> void :
	if state != "pause":
		return
	get_tree().paused = false
	state = "play"
	hud.hide_pause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player:
		player.motion_grace = 0.35

func to_menu() -> void :
	get_tree().paused = false
	state = "menu"
	hud.hide_pause()
	hud.show_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _init_squads() -> void :
	squads.clear()
	var by_team: = {"RU": [], "US": []}
	for b in bots:
		by_team[b.team].append(b)
	for t in ["RU", "US"]:
		var arr: Array = by_team[t]
		var base: int = arr.size() / 3
		var rem: int = arr.size() % 3
		var idx: = 0
		for si in 3:
			var cnt: int = base + (1 if si < rem else 0)
			var members: = []
			for k in cnt:
				if idx < arr.size():
					var m: BotBody = arr[idx]
					m.squad_idx = squads.size()
					m.squad_off = Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
					m.parts["goal"] = Vector3(points[si]["x"], 0, points[si]["z"]) + m.squad_off
					members.append(m)
					idx += 1
			squads.append({"team": t, "point": si, "members": members, "combat_t": 0.0})

func _tick_squads(dt: float) -> void :
	_squad_t -= dt
	if _squad_t > 0.0:
		return
	_squad_t = 1.5

	for s in squads:
		var p: Dictionary = points[s["point"]]
		if p["owner"] == s["team"]:
			var best: = -1
			var bd: = 1000000000.0
			for pi in points.size():
				if points[pi]["owner"] != s["team"]:
					var dd: float = Vector2(points[pi]["x"] - p["x"], points[pi]["z"] - p["z"]).length()
					if dd < bd:
						bd = dd
						best = pi
			if best >= 0:
				s["point"] = best
		var combat: = false
		var cpos: = Vector3.ZERO
		var cn: = 0
		for m in s["members"]:
			if is_instance_valid(m) and m.alive and m.enemy != null:
				combat = true
				cpos += m.global_position
				cn += 1
		s["combat_t"] = 4.0 if combat else maxf(0.0, float(s["combat_t"]) - 1.5)

		var pv: Vector3 = Vector3(points[s["point"]]["x"], 0, points[s["point"]]["z"])
		for m in s["members"]:
			if is_instance_valid(m) and m.alive and m.enemy == null and not m.reinforcing:
				m.parts["goal"] = pv + m.squad_off

	for s2 in squads:
		if float(s2["combat_t"]) > 0.0:
			continue
		for m in s2["members"]:
			if is_instance_valid(m) and m.alive and m.reinforcing and m.reinforce_sq >= 0:
				var ts: Dictionary = squads[m.reinforce_sq]
				if float(ts["combat_t"]) <= 0.0:
					m.reinforcing = false

	for s in squads:
		if float(s["combat_t"]) <= 0.0:
			continue
		var cpos: = Vector3.ZERO
		var cn: = 0
		for m in s["members"]:
			if is_instance_valid(m) and m.alive and m.enemy != null:
				cpos += m.global_position
				cn += 1
		if cn == 0:
			continue
		cpos /= float(cn)
		var sidx: = squads.find(s)
		for s2 in squads:
			if s2 == s or s2["team"] != s["team"] or float(s2["combat_t"]) > 0.0:
				continue
			var pd: float = Vector2(points[s2["point"]]["x"] - cpos.x, points[s2["point"]]["z"] - cpos.z).length()
			if pd > 340.0:
				continue
			var idle: Array = []
			for m in s2["members"]:
				if is_instance_valid(m) and m.alive and m.enemy == null and not m.reinforcing:
					idle.append(m)
			var keep: int = 2 if idle.size() >= 5 else (1 if idle.size() >= 3 else 0)
			for si in mini(3, idle.size() - keep):
				if si < 0:
					break
				var m2: BotBody = idle[si]
				m2.reinforcing = true
				m2.reinforce_to = cpos + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
				m2.reinforce_sq = sidx

func team_goal(team: String, bot: BotBody) -> Vector3:

	var best = null
	var best_d: = 1000000000.0
	for p in points:
		if p["owner"] != team:
			var d: float = Vector2(p["x"] - bot.global_position.x, p["z"] - bot.global_position.z).length()
			if d < best_d:
				best = p
				best_d = d
	if best == null:

		best = points[0]
	return Vector3(best["x"] + randf_range(-6, 6), 0, best["z"] + randf_range(-6, 6))


func ground_y(x: float, z: float) -> float:
	var from: = Vector3(x, World.terrain_h(x, z) + 6.0, z)
	var q: = PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30, 0), 1)
	var hit: = space_state.intersect_ray(q)
	return hit["position"].y if not hit.is_empty() else World.terrain_h(x, z)

func raycast_hit(from: Vector3, dir: Vector3, max_dist: float, exclude: Node3D) -> Dictionary:
	var excl: Array[RID] = []
	if exclude:
		excl.append(exclude.get_rid())
	var shooter_team: String = str(exclude.get("team")) if exclude else ""
	for i in 5:
		var q: = PhysicsRayQueryParameters3D.create(from, from + dir * max_dist, 1 | 4)
		q.exclude = excl
		var h: = space_state.intersect_ray(q)
		if h.is_empty():
			return h
		var col: Object = h["collider"]
		if col is BotBody:
			var b: = col as BotBody
			if not b.alive or (shooter_team != "" and b.team == shooter_team):
				excl.append(b.get_rid())
				continue
		return h
	return {}

func hurt_player(dmg: float, killer_name: String, weapon: String) -> void :
	if not player.alive or state != "play":
		return
	if player.spawn_prot > 0.0:
		return
	player.hp -= dmg
	audio.play("hurt", -4.0)
	if player.hp <= 0.0:
		player.die(killer_name, weapon)

func hurt_bot(bot: BotBody, dmg: float, killer, weapon: String) -> void :
	if not bot.alive:
		return
	bot.hp -= dmg
	if bot.hp <= 0.0:
		bot.die(killer, weapon)
		if killer is String and killer == "player":
			player.money += 100
			hud.set_money(player.money)

func _tick_points(dt: float) -> void :
	for p in points:
		var ru: = 0
		var us: = 0
		if player.alive and Vector2(player.global_position.x - p["x"], player.global_position.z - p["z"]).length() < p["r"]:
			ru += 1 if player.team == "RU" else 0
			us += 1 if player.team == "US" else 0
		for b in bots:
			if b.alive and Vector2(b.global_position.x - p["x"], b.global_position.z - p["z"]).length() < p["r"]:
				if b.team == "RU":
					ru += 1
				else:
					us += 1
		p["contested"] = ru > 0 and us > 0
		var dir: = 0
		if ru > 0 and us == 0:
			dir = 1
		elif us > 0 and ru == 0:
			dir = -1
		if dir != 0:
			var mult: float = minf(3.0, float(maxi(ru, us)))
			var prev: float = p["prog"]
			p["prog"] = clampf(p["prog"] + dir * 8.5 * mult * dt, -100.0, 100.0)
			if p["prog"] >= 100.0 and p["owner"] != "RU":
				p["owner"] = "RU"
				audio.play("cap_done")
				if player.team == "RU":
					player.money += 150
					hud.set_money(player.money)
				(p["flag"] as StandardMaterial3D).albedo_color = Hud.COL_RU
			if p["prog"] <= -100.0 and p["owner"] != "US":
				p["owner"] = "US"
				audio.play("cap_done")
				if player.team == "US":
					player.money += 150
					hud.set_money(player.money)
				(p["flag"] as StandardMaterial3D).albedo_color = Hud.COL_US
			if (prev > 0.0 and p["prog"] <= 0.0 and p["owner"] == "RU") or (prev < 0.0 and p["prog"] >= 0.0 and p["owner"] == "US"):
				p["owner"] = null
				(p["flag"] as StandardMaterial3D).albedo_color = Color(0.42, 0.42, 0.4)
				audio.play("lost")
		elif p["owner"] == null and p["prog"] != 0.0:
			p["prog"] = clampf(p["prog"] - signf(p["prog"]) * 3.0 * dt, -100.0, 100.0)

func _tick_tickets(dt: float) -> void :
	var ru_n: = 0
	var us_n: = 0
	for p in points:
		if p["owner"] == "RU":
			ru_n += 1
		elif p["owner"] == "US":
			us_n += 1
	if ru_n > us_n and ru_n >= 2:
		tickets["US"] = maxf(0.0, tickets["US"] - (ru_n - 1) * 0.55 * dt)
	if us_n > ru_n and us_n >= 2:
		tickets["RU"] = maxf(0.0, tickets["RU"] - (us_n - 1) * 0.55 * dt)
	if tickets["RU"] <= 0.0:
		_end_round("US")
	elif tickets["US"] <= 0.0:
		_end_round("RU")

func _end_round(winner: String) -> void :
	if state != "play":
		return
	state = "end"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_end(winner, player.team, int(ceil(tickets["RU"])), int(ceil(tickets["US"])), player.kills, player.deaths, player.caps)

func _process(dt: float) -> void :
	fx.tick(dt)
	_dbg_t -= dt
	if _dbg_t <= 0.0 and DisplayServer.get_name() == "web":
		_dbg_t = 1.0
		if player:
			print("DBG state=", state, " pos=", player.global_position.snapped(Vector3(0.5, 0.5, 0.5)), " alive=", player.alive, " floor=", player.is_on_floor(), " pitch=", snappedf(player.pitch, 0.05), " yaw=", snappedf(player.yaw, 0.05))
	if state != "play":
		return

	if DisplayServer.get_name() != "headless" and not test_mode:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			unlock_t = 0.0
		else:
			unlock_t += dt
			if unlock_t > 0.8:
				state = "pause"
				hud.show_pause()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				return
	elapsed += dt
	time_left -= dt
	if time_left <= 0.0:
		_end_round("RU" if tickets["RU"] > tickets["US"] else ("US" if tickets["US"] > tickets["RU"] else "draw"))
	_tick_points(dt)
	_tick_tickets(dt)
	_tick_squads(dt)
	var parr: = []
	for p in points:
		parr.append({"id": p["id"], "owner": p["owner"], "contested": p["contested"]})
	hud.set_points(parr)
	hud.set_score(int(ceil(tickets["RU"])), int(ceil(tickets["US"])), int(time_left))
	var tc: = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	hud.set_timecode(tc)

func _run_menushot() -> void :
	await get_tree().create_timer(1.5).timeout
	var img: = get_viewport().get_texture().get_image()
	img.save_png("/tmp/godot_shots/menu.png")
	print("MENUSHOT_SAVED")
	await get_tree().create_timer(0.3).timeout

	start_match("RU", "assault")
	state = "pause"
	hud.show_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.8).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/tmp/godot_shots/pause.png")
	print("PAUSESHOT_SAVED")
	get_tree().quit(0)

func _run_shots() -> void :
	start_match("RU", "assault")

	player.yaw = 0.9
	player.rotation.y = 0.9
	for i in 3:
		await get_tree().create_timer(1.2 + i * 0.8).timeout
		var img: = get_viewport().get_texture().get_image()
		img.save_png("/tmp/godot_shots/shot_%d.png" % (i + 1))
		print("SHOT_SAVED ", i + 1)

	var zones: = [[-80, -64, 0.83], [30, 26, 0.785], [150, 126, 0.97]]
	for zi in zones.size():
		player.global_position = Vector3(zones[zi][0], ground_y(zones[zi][0], zones[zi][1]) + 1.2, zones[zi][1])
		player.velocity = Vector3.ZERO
		player.yaw = zones[zi][2]
		player.rotation.y = zones[zi][2]
		player.pitch = -0.03
		player.motion_grace = 0.5
		await get_tree().create_timer(1.0).timeout
		var img2: = get_viewport().get_texture().get_image()
		img2.save_png("/tmp/godot_shots/shot_%d.png" % (zi + 4))
		print("SHOT_SAVED ", zi + 4)

	var evwd: = InputEventMouseButton.new()
	evwd.button_index = MOUSE_BUTTON_WHEEL_DOWN
	evwd.pressed = true
	Input.parse_input_event(evwd)
	await get_tree().create_timer(0.5).timeout
	var img3: = get_viewport().get_texture().get_image()
	img3.save_png("/tmp/godot_shots/shot_7.png")
	print("SHOT_SAVED 7")

	var evr: = InputEventMouseButton.new()
	evr.button_index = MOUSE_BUTTON_RIGHT
	evr.pressed = true
	Input.parse_input_event(evr)
	await get_tree().create_timer(0.8).timeout
	var img4: = get_viewport().get_texture().get_image()
	img4.save_png("/tmp/godot_shots/shot_8.png")
	print("SHOT_SAVED 8")
	var evr2: = InputEventMouseButton.new()
	evr2.button_index = MOUSE_BUTTON_RIGHT
	evr2.pressed = false
	Input.parse_input_event(evr2)

	var evwu: = InputEventMouseButton.new()
	evwu.button_index = MOUSE_BUTTON_WHEEL_UP
	evwu.pressed = true
	Input.parse_input_event(evwu)
	await get_tree().create_timer(0.5).timeout
	var evr3: = InputEventMouseButton.new()
	evr3.button_index = MOUSE_BUTTON_RIGHT
	evr3.pressed = true
	Input.parse_input_event(evr3)
	await get_tree().create_timer(0.8).timeout
	var img5: = get_viewport().get_texture().get_image()
	img5.save_png("/tmp/godot_shots/shot_9.png")
	print("SHOT_SAVED 9")
	var evr4: = InputEventMouseButton.new()
	evr4.button_index = MOUSE_BUTTON_RIGHT
	evr4.pressed = false
	Input.parse_input_event(evr4)
	get_tree().quit(0)

func _run_test() -> void :

	start_match("RU", "sniper")
	print("TEST_START ", VER, " bots=", bots.size())
	var b0: Array[Vector3] = []
	for b in bots:
		b0.append(b.global_position)
	await get_tree().create_timer(5.0).timeout
	var alive_bots: = 0
	for b in bots:
		if b.alive:
			alive_bots += 1
	print("TEST_STATE state=", state, " hp=", int(player.hp), " bots_alive=", alive_bots, \
	" ru=", int(ceil(tickets["RU"])), " us=", int(ceil(tickets["US"])), \
	" ppos=", player.global_position.round())

	var p0: Vector3 = player.global_position
	var ev: = InputEventKey.new()
	ev.keycode = KEY_W
	ev.physical_keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(1.5).timeout
	var ev2: = InputEventKey.new()
	ev2.keycode = KEY_W
	ev2.physical_keycode = KEY_W
	ev2.pressed = false
	Input.parse_input_event(ev2)
	var walked: float = (player.global_position - p0).length()
	print("TEST_WALK walked=", snappedf(walked, 0.1))
	var moved: = 0.0
	for i in bots.size():
		moved += (bots[i].global_position - b0[i]).length()
	print("TEST_BOTS moved_avg=", snappedf(moved / bots.size(), 0.1))

	player.yaw = - PI / 2
	player.rotation.y = - PI / 2
	player.pitch = 0.0
	var foe: BotBody = null
	for b in bots:
		if b.team == "US" and b.alive:
			foe = b
			break
	var hp0: float = player.hp
	player.spawn_prot = 0.0
	if foe:

		for b in bots:
			if b.team == player.team:
				b.position = Vector3(190, ground_y(190, -150) + 1.0, -150)
				b.velocity = Vector3.ZERO
				b.enemy = null
		foe.wkey = "ak74"
		_place_enemy(foe, 14.0)
		for i in 6:
			foe.enemy = player
			foe.enemy_is_player = true
			foe.react_t = 0.0
			foe.next_shot = 0.0
			await get_tree().create_timer(0.6).timeout
		await get_tree().create_timer(4.0).timeout
		print("TEST_BOTSHOOT hp=", int(player.hp), " -> ", "BOTSHOOT_OK" if player.hp < hp0 else "BOTSHOOT_FAIL")

		bots.erase(foe)
		foe.queue_free()
		player.hp = 100
		player.alive = true
		player.respawn_t = 0.0
		player.velocity = Vector3.ZERO

	var t1: = _spawn_target(60.0)
	if t1:
		await _ads_fire()
		print("TEST_SVD hp=", int(t1.hp), " alive=", t1.alive, " -> ", "SVD_OK" if ( not t1.alive or t1.hp < 100) else "SVD_FAIL")

	player.hp = 45.0
	player.alive = true
	var eh: = InputEventKey.new()
	eh.keycode = KEY_3
	eh.physical_keycode = KEY_3
	eh.pressed = true
	Input.parse_input_event(eh)
	await get_tree().create_timer(2.6).timeout
	var eh2: = InputEventKey.new()
	eh2.keycode = KEY_3
	eh2.physical_keycode = KEY_3
	eh2.pressed = false
	Input.parse_input_event(eh2)
	print("TEST_HEAL hp=", int(player.hp), " -> ", "HEAL_OK" if player.hp > 60.0 else "HEAL_FAIL")

	player.weapons[0] = {"key": "ak74", "mag": 30, "reserve": 120}
	player.attachs = {}
	player.money = 500
	player.equip(0)
	player.buy(0)
	var shop_ok: bool = player.money == 250 and player._optic() == "dot"
	player.buy(1)
	shop_ok = shop_ok and player.money == 250
	player.money = 1000
	player.buy(1)
	shop_ok = shop_ok and player._optic() == "pso" and player.money == 600
	player.buy(2)
	shop_ok = shop_ok and player._att("sup") and player.money == 300
	player.buy(3)
	shop_ok = shop_ok and player._att("ext") and player.money == 100
	print("TEST_SHOP -> ", "SHOP_OK" if shop_ok else "SHOP_FAIL")

	player.attachs = {}
	player.weapons[0]["mag"] = 3
	player.weapons[0]["reserve"] = 9
	player.bandages = 1
	main_hurt_for_test = true
	hurt_player(200.0, "TEST", "x")
	await get_tree().create_timer(7.5).timeout
	var r_ok: bool = player.alive and player.weapons[0]["mag"] == 30 and player.weapons[0]["reserve"] == 120 and player.bandages == 5
	print("TEST_RESPAWN mag=", player.weapons[0]["mag"], "/", player.weapons[0]["reserve"], " b=", player.bandages, " -> ", "RESP_OK" if r_ok else "RESP_FAIL")

	var pts: = {}
	for sq in squads:
		pts[sq["point"]] = true
	var sq_ok: bool = squads.size() == 6 and pts.size() == 3
	print("TEST_SQUAD squads=", squads.size(), " points=", pts.size(), " -> ", "SQUAD_OK" if sq_ok else "SQUAD_FAIL")
	var s_us: Dictionary = {}
	var eng: BotBody = null
	for sq in squads:
		if sq["team"] == "US":
			for m in sq["members"]:
				if is_instance_valid(m) and m.alive and not m.frozen:
					s_us = sq
					eng = m
					break
		if s_us.size() > 0:
			break
	if eng:
		player.hp = 100.0
		var sqp: Dictionary = points[s_us["point"]]
		player.global_position = Vector3(sqp["x"], ground_y(sqp["x"], sqp["z"]) + 1.0, sqp["z"])
		player.velocity = Vector3.ZERO
		player.spawn_prot = 0.0
		_place_enemy(eng, 20.0)
		eng.frozen = true
		eng.enemy = player
		s_us["combat_t"] = 4.0
		_tick_squads(1.6)
		for m2 in s_us["members"]:
			if is_instance_valid(m2) and m2.alive:
				m2.enemy = player
		await get_tree().create_timer(1.8).timeout
		var sent: = 0
		for sq in squads:
			if sq["team"] == "US" and sq != s_us:
				for m in sq["members"]:
					if is_instance_valid(m) and m.reinforcing:
						sent += 1
		print("TEST_REINFORCE sent=", sent, " -> ", "REIN_OK" if sent >= 1 else "REIN_FAIL")
		eng.frozen = false
		player.hp = 100.0
	else:
		print("TEST_REINFORCE no_member -> REIN_SKIP")

	player.hp = 100.0
	var foe2: BotBody = null
	for b in bots:
		if b.team == "US" and b.alive and not b.frozen:
			foe2 = b
			break
	if foe2:

		player.global_position += Vector3(0, 0, 12.0)
		player.velocity = Vector3.ZERO
		_place_enemy(foe2, 25.0)
		foe2.frozen = true
		await get_tree().create_timer(1.5).timeout

		var hpA: float = player.hp
		var blocked: = false
		for wi in 4:
			if blocked:
				break
			for sgn in [1.0, -1.0]:
				var wpos: = Vector3(-160.0 + cos(1.2) * (wi - 1.5) * 2.3, 0, 140.0 + sin(1.2) * (wi - 1.5) * 2.3)
				var nvec: = Vector3( - sin(1.2), 0, cos(1.2)) * float(sgn)
				var bpos: = wpos + nvec * 12.0
				var ppos: = wpos - nvec * 4.0
				if absf(bpos.x) > 200.0 or absf(bpos.z) > 200.0 or absf(ppos.x) > 200.0 or absf(ppos.z) > 200.0:
					continue
				foe2.global_position = Vector3(bpos.x, ground_y(bpos.x, bpos.z) + 1.0, bpos.z)
				player.global_position = Vector3(ppos.x, ground_y(ppos.x, ppos.z) + 1.0, ppos.z)
				player.velocity = Vector3.ZERO
				var q3: = PhysicsRayQueryParameters3D.create(foe2.global_position + Vector3(0, 1.5, 0), player.global_position + Vector3(0, 1.3, 0), 1)
				if not space_state.intersect_ray(q3).is_empty():
					blocked = true
					break
		await get_tree().create_timer(2.0).timeout
		var hpB: float = player.hp
		await get_tree().create_timer(1.5).timeout
		print("TEST_WALLSHOT blocked=", blocked, " hpA=", int(hpA), " hpB=", int(hpB), " hpC=", int(player.hp), " -> ", "WALL_OK" if (blocked and hpB == player.hp) else "WALL_FAIL")

	start_match("US", "sniper")
	await get_tree().create_timer(0.5).timeout
	player.yaw = PI / 2
	player.rotation.y = PI / 2
	player.pitch = 0.0
	var t2: = _spawn_target(60.0)
	if t2:
		await _ads_fire()
		print("TEST_M82 hp=", int(t2.hp), " alive=", t2.alive, " -> ", "M82_OK" if ( not t2.alive or t2.hp < 100) else "M82_FAIL")
	print("TEST_OK")
	get_tree().quit(0)

func _place_enemy(bot: BotBody, dist: float) -> void :

	var fwd: = Vector3( - sin(player.yaw), 0, - cos(player.yaw))
	var eye: = player.global_position + Vector3(0, 1.62, 0)
	for d in [dist, dist * 0.7, dist * 0.45, 14.0]:
		var p: Vector3 = player.global_position + fwd * float(d)
		var q: = PhysicsRayQueryParameters3D.create(eye, p + Vector3(0, 1.2, 0), 1)
		if space_state.intersect_ray(q).is_empty():
			bot.position = Vector3(p.x, ground_y(p.x, p.z) + 1.0, p.z)
			bot.velocity = Vector3.ZERO
			return
	bot.position = player.global_position + fwd * 12.0

func _spawn_target(dist: float) -> BotBody:
	var foe: = "US" if player.team == "RU" else "RU"
	var bot: = BotBody.new()
	bot.process_mode = Node.PROCESS_MODE_PAUSABLE
	bot.setup(self, foe, "ЦЕЛЬ", "ak74" if foe == "RU" else "m16")
	add_child(bot)
	bots.append(bot)
	_place_enemy(bot, dist)
	bot.frozen = true
	return bot

func _ads_fire() -> void :

	var t: BotBody = null
	var best: = 1000000000.0
	for b in bots:
		if not b.alive or b.team == player.team:
			continue
		var d: = Vector2(b.global_position.x - player.global_position.x, b.global_position.z - player.global_position.z).length()
		if d < best:
			best = d
			t = b
	if t == null:
		return
	await get_tree().create_timer(0.6).timeout
	for i in 3:
		var dn: = InputEventMouseButton.new()
		dn.button_index = MOUSE_BUTTON_RIGHT
		dn.pressed = true
		Input.parse_input_event(dn)
		await get_tree().create_timer(0.5).timeout

		var to: = t.global_position - player.global_position
		var d2: = Vector2(to.x, to.z).length()
		player.yaw = atan2( - to.x, - to.z) if absf(to.z) > 0.001 else ( - PI / 2.0 if to.x > 0.0 else PI / 2.0)
		player.rotation.y = player.yaw
		player.pitch = - atan2(player.global_position.y + 1.62 - (t.global_position.y + 1.0), d2)
		await get_tree().create_timer(0.2).timeout
		var dl: = InputEventMouseButton.new()
		dl.button_index = MOUSE_BUTTON_LEFT
		dl.pressed = true
		Input.parse_input_event(dl)
		await get_tree().create_timer(0.15).timeout
		var ul: = InputEventMouseButton.new()
		ul.button_index = MOUSE_BUTTON_LEFT
		ul.pressed = false
		Input.parse_input_event(ul)
		var ur: = InputEventMouseButton.new()
		ur.button_index = MOUSE_BUTTON_RIGHT
		ur.pressed = false
		Input.parse_input_event(ur)
		await get_tree().create_timer(0.25).timeout
