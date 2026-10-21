extends SceneTree

func _init() -> void:
	print("Testando DisplayServer window mode...")
	print("Suporta fullscreen: ", DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	print("Window mode set successfully: ", DisplayServer.window_get_mode())
	quit(0)
