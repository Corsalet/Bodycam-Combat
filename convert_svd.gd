extends SceneTree
func _init():
	var ps: PackedScene = load("res://assets/low-poly_svd_dragunov.glb")
	if ps == null:
		print("FAIL_LOAD")
		quit()
		return
	var err: = ResourceSaver.save(ps, "res://assets/svd_vm_r.scn")
	print("SAVED err=", err)
	quit()
