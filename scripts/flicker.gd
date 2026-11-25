extends OmniLight3D

var t: float = 0.0

func _ready() -> void :
	t = float(get_instance_id() % 100) * 0.13

func _process(delta: float) -> void :
	t += delta * 6.0
	light_energy = 1.7 + sin(t * 3.1) * 0.4 + sin(t * 7.7 + 1.3) * 0.3
