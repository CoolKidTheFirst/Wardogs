extends Button

func _on_pressed() -> void:
	if get_child_count() == 0:
		return
	var child := get_child(0)
	if child and child is Node:
		child.visible = not child.visible
