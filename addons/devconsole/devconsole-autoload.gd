extends Node

const DEV_CONSOLE_SCENE = preload("res://addons/devconsole/scene/DevConsole.tscn")

# settings
var enabled = true
################################
var key_activate: Key = KEY_QUOTELEFT
var key_deactivate: Key = KEY_ESCAPE
var height_ratio = 0.75
var mouse_select = true
var mouse_select_group_only = true # only use mouse select for node2ds in the `dev_console_mouse_select` group.
var pause = true
var click_distance = 200
var overlap_distance = 10
var max_displayed_lines = 16384
var history_limit = 1024
################################

var commands = {}
var canvas_layer: CanvasLayer
var console_scene: DevConsolePanel
var selected: Node = null:
	set(s):
		selected = s
		if console_scene:
			console_scene.selected = s

var selected_viewport: Viewport = null:
	set(s):
		selected_viewport = s
		if console_scene:
			console_scene.selected_viewport = s

var mouse_press_position = Vector2()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	canvas_layer.name = "DevConsoleLayer"
	canvas_layer.layer = 128
	console_scene = DEV_CONSOLE_SCENE.instantiate()
	canvas_layer.add_child(console_scene)
	console_scene.command_submitted.connect(_on_command_submitted)
	selected_viewport = get_tree().root

	### example command, you can register these from any script!
	### func hello():
	### 	DevConsole.write_line("hello world!", Color.PURPLE)
	###
	### func _ready():
	### 	DevConsole.register_command(hello)
	###
	### Alternative one-liner version that assigns a description and category:
	### DevConsole.register_command(func(): DevConsole.write_line("hello world!", Color.PURPLE), "hello", "example user command.", [], "example category")

	register_command(_print_help, "help", "displays this message.", [], "_base")
	register_command(_clear, "clear", "clears the screen.", [], "_base")
	register_command(_clear, "cls") # Alias
	register_command(console_scene.deactivate, "exit", "exits the developer console.", [], "_base")
	register_command(get_tree().quit, "quit", "quits the game.",  [], "_game")
	
	# _tree
	register_command(_find_object, "find", "finds all nodes with the given name and prints their nodepath.", ["object_name"], "_tree")
	register_command(_print_tree, "nodes", "prints the current scene tree.", [], "_tree")
	register_command(_print_children, "children", "prints all children of the selected node.", [], "_tree")
	register_command(_print_tree, "ls") # Alias
	register_command(_print_tree_pretty, "tree", "pretty-prints the current scene tree.", [], "_tree")
	register_command(_print_children_pretty, "subtree", "pretty-prints the scene tree descending from the selected node.", [], "_tree")
	
	# _node
	register_command(_select_object, "select", "finds a node by nodepath and selects it.", ["object_name"], "_node")
	register_command(_deselect, "deselect", "deselects the current selected node.", [], "_node")
	register_command(_mouse_select, "mouse", "selects the nearest node2d to the mouse in the currently selected viewport. if the `mouse_select` setting is enabled, you can select nodes directly by clicking near them on the screen. if the `mouse_select_only_in_group` setting is enabled, this only selects nodes in the `dev_console_mouse_select` group.", [], "_node")
	register_command(_free, "free", "calls queue_free() on the selected node.", [], "_node")

	_select_object(get_tree().root)

func enable():
	enabled = true

func disable():
	enabled = false
	console_scene.deactivate()

func register_command(function: Callable, name:String="", description: String="", args: Array[String]=[], category="uncategorized"):
	for command in commands:
		if commands[command].function == function and command != name:
			commands[command].aliases.append(name)
			return
	
	if name == "":
		name = function.get_method()

	### You gotta name your command! either pass a function with a name the `name` parameter.
	assert(name != "<anonymous lambda>")
	
	commands[name] = {
		"function": function,
		"args": args,
		"argc": args.size(),
		"description": description,
		"category": category,
		"aliases": [],
	}

func register_command_from_dict(dict: Dictionary):
	assert(dict.has("function"))
	var empty_args : Array[String] = []
	var full = {
		"function": dict.function,
		"name": "",
		"description": "",
		"args": empty_args,
		"category": "uncategorized",
	}
	full.merge(dict, true)
	register_command(dict.function, dict.name, dict.description, dict.args, dict.category)

func write_line(line: String, color=console_scene.color_output):
	console_scene.write_line(line, color)

func select_viewport(viewport: Viewport):
	selected_viewport = viewport

func _on_command_submitted(text: String):
	text = text.strip_edges()
	if ";" in text:
		for command in text.split(";"):
			_on_command_submitted(command)
		return
	if text.strip_edges() == "":
		return
	var words = text.split(" ")
	write_line("> " + text, console_scene.color_input)
	var command = words[0]

	if !command in commands:
		for command_ in commands:
			if command in commands[command_].aliases:
				command = command_
				break
 
	if command in commands:
		var info = commands[command]
		var callable: Callable = info.function
		var args = words.slice(1)
		if _check_prune_method(command):
			return
		if args.size() < info.argc:
			var error = "expected %s arguments for command \"%s\", got %s" % [info.argc, command, args.size()]
			error += "\nusage: %s " % command
			if info.argc > 0:
				for arg in info.args:
					error += "<%s> " % arg
			console_scene.error(error)
			return
		callable.callv(args.slice(0, info.argc))
		return

	else:
		var eval_successful = false
		if _evaluate_as(text, selected):
			eval_successful = true
		elif _evaluate_as(text, self):
			eval_successful = true
		if !eval_successful:
			if _evaluate_as(text + "()", selected):
				eval_successful = true
			elif _evaluate_as(text + "()", self):
				eval_successful = true

		if !eval_successful:
			var error = "invalid command or expression: [color=%s]%s[/color]. try [color=#%s]help[/color] to see a list of available commands" % \
				[console_scene.color_input.to_html(false), command, console_scene.color_important.to_html(false)]
			console_scene.error(error)
			return
			#result = "could not evaluate expression"

	if !is_instance_valid(selected):
		_deselect()

func _check_prune_method(command: String):
	var method = commands[command].function
	if !is_instance_valid(method.get_object()):
		console_scene.error("object containing method `%s` no longer exists, removing command `%s` from commands list" % [method.get_method(), command])
		commands.erase(command)
		return true
	return false

func _evaluate_as(text, who):
		var expression = Expression.new()
		var parse_error = expression.parse(text)
		if parse_error != OK:
			return false
		var result = expression.execute([], who, false)
		if result is Callable:
			return false
		#print(parse_error)
		#print(result)
		if expression.has_execute_failed():
			return false

		if result != null:
			write_line(str(result))
		return true

func _print_help():
	var sort_commands = func(a, b):
		if a == "help":
			return true
		if b == "help":
			return false
		#print(a)
		return a < b
	
	var sort_categories = func(a, b):
		if a == "_base":
			return true
		elif a == "uncategorized":
			return false
		if b == "_base":
			return false
		elif b == "uncategorized":
			return true
		return a < b
	
	var categories = {}
	
	for command in commands:
		if _check_prune_method(command):
			continue
		var info = commands[command]
		if categories.has(info.category):
			categories[info.category].append(command)
		else:
			categories[info.category] = [command]
			
	var category_keys = categories.keys()
	category_keys.sort_custom(sort_categories)

	for category in category_keys:
		var text = ""
		write_line(category, console_scene.color_title)
		var keys = categories[category]
		keys.sort_custom(sort_commands)
		#print(keys)
		for command in keys:
			var info = commands[command]
			var argtext = ""
			for arg in info.args:
				argtext += " <%s>" % arg
			var aliastext = "" 
			for alias in info.aliases:
				aliastext += "[color=#%s], [/color][color=#%s]%s[/color]" % [console_scene.color_output.to_html(false), console_scene.color_important_2.to_html(false), alias]

			text += " >> [color=#%s]%s%s%s[/color]: %s\n" % [console_scene.color_important.to_html(false), command, aliastext, argtext,  info.description]
		text = text.strip_edges(false, true)
		write_line(text)

func _print_tree():
	write_line(get_tree().current_scene.get_tree_string())

func _print_children():
	write_line((selected if selected is Node else get_tree().current_scene).get_tree_string())

func _print_tree_pretty():
	write_line(get_tree().current_scene.get_tree_string_pretty())

func _print_children_pretty():
	write_line((selected if selected is Node else get_tree().current_scene).get_tree_string_pretty())

func _select_object(path, write_line=true):
	_deselect()
	var node
	if path is Node:
		node = path
		path = node.get_path()
	elif path is String:
		node = get_node_or_null(path)
		if path.strip_edges() == "root":
			node = get_tree().root

	if node == null:
		node = get_tree().root.find_child(path, true, false)
	if node == null:
		console_scene.error("could not find node: %s" % path)
		return
	selected = node
	console_scene.selected_label.text = "selected: %s" % node.get_path()
	if write_line:
		write_line("selected object at %s" % node.get_path())
	if node is Node:
		node.tree_exited.connect(_deselect)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if !event.pressed:
				if mouse_press_position.distance_to(get_viewport().get_mouse_position()) < 128:
					_mouse_select(false, false)
			else:
				mouse_press_position = get_viewport().get_mouse_position()
	pass

func _mouse_select(force=true, write_line=true):
	if !console_scene.visible:
		return
	if !mouse_select:
		return
	if console_scene.selecting_text and console_scene.mouse_over_text:
		return
	var mouse_position = selected_viewport.get_camera_2d().get_global_mouse_position() if selected_viewport.get_camera_2d() else selected_viewport.get_mouse_position()
	var nodes = get_tree().root.find_children("*", "Node2D", true, false)
	if mouse_select_group_only:
		nodes = nodes.filter(func(n): return n.is_in_group("dev_console_mouse_select"))
	nodes = nodes.filter(func(n): return n.global_position.distance_to(mouse_position) <click_distance)
	if nodes:
		nodes.sort_custom(func(a, b): return a.global_position.distance_squared_to(mouse_position) < b.global_position.distance_squared_to(mouse_position))
		var node_to_select = nodes.pop_front()
		if node_to_select == selected and nodes.size() > 0:
			var new_node = nodes.pop_front()
			var diff = abs(new_node.global_position.distance_to(mouse_position) - node_to_select.global_position.distance_to(mouse_position))
			if diff < overlap_distance:
				node_to_select = new_node
		if force or node_to_select != selected:
			_select_object(node_to_select, write_line)

func _deselect():
	if selected and selected.tree_exited.is_connected(_deselect):
		selected.tree_exited.disconnect(_deselect)
	selected = null
	console_scene.selected_label.text = ""

func _find_object(path: String):
	for child in get_tree().root.find_children(path, "", true, false):
		write_line(child.get_path())

func _clear():
	console_scene.clear.call_deferred()

func _free():
	if selected:
		if selected == get_tree().root:
			get_tree().quit()
			return
		selected.queue_free()
	else:
		console_scene.error("no selected object")
