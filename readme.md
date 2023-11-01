# godot devconsole
this is a simple developer console for 2d games. you can execute registered commands or evaluate [Expressions](https://docs.godotengine.org/en/stable/tutorials/scripting/evaluating_expressions.html) as the selected node (falling back to the console node).

just drop the addons folder in your project.

https://github.com/uzkbwza/godot-devconsole/assets/43023911/352fc2af-a2aa-4b86-9eab-4cdca830adcf

you can register a command from any script.

	func hello():
		DevConsole.write_line("hello world!", Color.PURPLE)
		
	func _ready():
		DevConsole.register_command(hello)

alternatively, you can do it like this:
	
	DevConsole.register_command(func(): DevConsole.write_line("hello world!", Color.PURPLE), "hello", "example user command.", ["parameter", "names", "go", "here"], "example category")

open the console by pressing the tilde key (~). you can adjust this and other settings in `devconsole-autoload.gd`. if you add a Node2D to the `dev_console_mouse_select` group, you can select it directly by using the mouse.
currently i dont have any mouse support for 3d objects, but it is probably easy to implement.
