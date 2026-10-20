@tool
extends EditorScript

func _run() -> void:
	print("--- SCANNING AND IMPORTING FILES ---")
	var efs = EditorInterface.get_resource_filesystem()
	if efs:
		efs.scan()
		print("Scanning triggered!")
	else:
		print("No EFS")
