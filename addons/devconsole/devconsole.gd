@tool
extends EditorPlugin

const NAME = "DevConsole"

func _enter_tree():
	add_autoload_singleton(NAME, "res://addons/devconsole/devconsole-autoload.gd")

func _exit_tree():
	remove_autoload_singleton(NAME)
