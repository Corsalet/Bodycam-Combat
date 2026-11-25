class_name BcAudio


const RATE: = 22050

var _pool: Array[AudioStreamPlayer] = []
var _lib: = {}

const _FORCE: = ["hurt", "death", "kill", "headshot", "hit", "dry", "reload"]
static var _last_whiz_ms: = 0

func _init() -> void :
	for i in 20:
		var p: = AudioStreamPlayer.new()
		p.bus = "Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		_pool.append(p)
	_build_lib()

func attach(root: Node) -> void :
	for p in _pool:
		root.add_child(p)


static func _noise_pcm(dur: float, env: Array, cutoff: float, vol: float) -> PackedFloat32Array:
	var n: = int(dur * RATE)
	var out: = PackedFloat32Array()
	out.resize(n)
	var a: float = env[0]
	var d: float = env[1]
	var s: float = env[2]
	var lp: = 0.0
	var k: = clampf(cutoff / RATE, 0.0, 1.0) * 6.0
	for i in n:
		var t: = i / float(n)
		var envv: float = 0.0
		if t < a:
			envv = t / a
		elif t < a + s:
			envv = 1.0
		else:
			envv = maxf(0.0, 1.0 - (t - a - s) / d)
		var w: = randf() * 2.0 - 1.0
		lp += k * (w - lp)
		out[i] = lp * envv * vol
	return out

static func _tone_pcm(dur: float, f0: float, f1: float, vol: float, kind: = "square") -> PackedFloat32Array:
	var n: = int(dur * RATE)
	var out: = PackedFloat32Array()
	out.resize(n)
	var phase: = 0.0
	for i in n:
		var t: = i / float(n)
		var f: = lerpf(f0, f1, t)
		phase += f / RATE
		var w: = 0.0
		if kind == "sine":
			w = sin(phase * TAU)
		elif kind == "square":
			w = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		else:
			w = 2.0 * fmod(phase, 1.0) - 1.0
		var envv: = maxf(0.0, 1.0 - t) * maxf(0.0, minf(1.0, t * 60.0))
		out[i] = w * envv * vol
	return out

static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n: = maxi(a.size(), b.size())
	var out: = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var va: = a[i] if i < a.size() else 0.0
		var vb: = b[i] if i < b.size() else 0.0
		out[i] = clampf(va + vb, -1.0, 1.0)
	return out

static func _to_wav(pcm: PackedFloat32Array, gain: = 0.9) -> AudioStreamWAV:
	var bytes: = PackedByteArray()
	bytes.resize(pcm.size() * 2)
	for i in pcm.size():
		var v: = int(clampf(pcm[i] * gain, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _build_lib() -> void :
	var shots: = {
		"ak74": [_noise_pcm(0.16, [0.55, 0.001, 0.13], 1900.0, 0.7), _tone_pcm(0.09, 140.0, 55.0, 0.3)], 
		"m16": [_noise_pcm(0.13, [0.5, 0.001, 0.11], 2400.0, 0.7), _tone_pcm(0.07, 170.0, 70.0, 0.24)], 
		"svd": [_noise_pcm(0.34, [0.75, 0.001, 0.3], 1400.0, 0.6), _tone_pcm(0.16, 110.0, 40.0, 0.4)], 
		"m82": [_noise_pcm(0.5, [0.95, 0.001, 0.44], 900.0, 0.6), _tone_pcm(0.24, 80.0, 30.0, 0.5)], 
		"makarov": [_noise_pcm(0.1, [0.4, 0.001, 0.09], 2600.0, 0.8), _tone_pcm(0.05, 200.0, 90.0, 0.16)], 
		"deagle": [_noise_pcm(0.22, [0.65, 0.001, 0.09], 1600.0, 0.7), _tone_pcm(0.12, 120.0, 48.0, 0.34)], 
	}
	for k in shots:
		_lib[k] = _to_wav(_mix(shots[k][0], shots[k][1]))
	_lib["hit"] = _to_wav(_tone_pcm(0.05, 1150.0, 900.0, 0.16))
	_lib["headshot"] = _to_wav(_tone_pcm(0.06, 1500.0, 700.0, 0.2))
	_lib["kill"] = _to_wav(_mix(_tone_pcm(0.07, 660.0, 520.0, 0.16), _tone_pcm(0.09, 880.0, 660.0, 0.14)))
	_lib["hurt"] = _to_wav(_mix(_noise_pcm(0.14, [0.3, 0.001, 0.12], 500.0, 1.0), _tone_pcm(0.1, 180.0, 90.0, 0.14)))
	_lib["dry"] = _to_wav(_tone_pcm(0.04, 900.0, 700.0, 0.1))
	_lib["reload"] = _to_wav(_mix(_tone_pcm(0.05, 500.0, 380.0, 0.1), _tone_pcm(0.06, 700.0, 500.0, 0.08)))
	_lib["heal"] = _to_wav(_mix(_tone_pcm(0.09, 420.0, 320.0, 0.12), _tone_pcm(0.1, 560.0, 420.0, 0.1)))
	_lib["whiz"] = _to_wav(_noise_pcm(0.09, [0.02, 0.06, 0.01], 3200.0, 0.25))
	_lib["cap_tick"] = _to_wav(_tone_pcm(0.05, 700.0, 700.0, 0.07))
	_lib["cap_done"] = _to_wav(_mix(_tone_pcm(0.1, 520.0, 520.0, 0.14), _tone_pcm(0.14, 780.0, 780.0, 0.14)))
	_lib["lost"] = _to_wav(_tone_pcm(0.12, 400.0, 260.0, 0.12))
	_lib["death"] = _to_wav(_mix(_noise_pcm(0.7, [0.4, 0.001, 0.6], 300.0, 1.0), _tone_pcm(0.5, 160.0, 60.0, 0.2)))

func play(name: String, vol_db: = 0.0, pitch: = 1.0) -> void :
	if not _lib.has(name):
		return
	if name == "whiz":
		var now: = Time.get_ticks_msec()
		if now - _last_whiz_ms < 130:
			return
		_last_whiz_ms = now
	for p in _pool:
		if not p.playing:
			p.stream = _lib[name]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

	if name in _FORCE:
		_pool[0].stream = _lib[name]
		_pool[0].volume_db = vol_db
		_pool[0].pitch_scale = pitch
		_pool[0].play()


func play_shot(key: String, dist: float) -> void :
	var att: = clampf(1.0 - dist / 160.0, 0.12, 1.0)
	play(key, linear_to_db(att), randf_range(0.94, 1.06))
