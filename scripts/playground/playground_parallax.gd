extends ParallaxBackground

func _process(_dt):
	var cam := get_viewport().get_camera_2d()
	if cam:
		# Use the camera’s world position as the scroll origin
		scroll_offset = cam.global_position
