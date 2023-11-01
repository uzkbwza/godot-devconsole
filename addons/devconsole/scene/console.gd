extends PanelContainer

class_name DevConsolePanel

signal command_submitted(command: String)

const LINE_LABEL_SCENE = preload("res://addons/devconsole/scene/LineLabel.tscn")

@export var color_output: Color
@export var color_input: Color
@export var color_error: Color
@export var color_important: Color
@export var color_important_2: Color
@export var color_title: Color

@onready var scroll_container = %ScrollContainer
@onready var line_edit = %LineEdit
@onready var selected_label = %SelectedLabel
@onready var label_box = %LabelBox
@onready var suggestion = %Suggestion

var history: Array[String] = [""]
var history_index = 0
var pause_state = false
var selecting_text = false
var mouse_over_text = false

var selected = null
var selected_viewport: Viewport = null

var label_text: String = ""

var suggested:
	get:
		if current_suggestions:
			return current_suggestions[suggested_index % current_suggestions.size()]
		return ""
var suggested_index = 0
var current_suggestions = []
var cycling_suggestions = false

func _ready():
	anchor_bottom = DevConsole.height_ratio
	scroll_container.get_v_scroll_bar().changed.connect(handle_scrollbar_changed)
	deactivate()

func _input(event):
	if DevConsole.enabled:
		if event is InputEventKey and event.pressed:
			if visible and (event.keycode == DevConsole.key_deactivate or  event.keycode == DevConsole.key_activate):
				deactivate()
			elif !visible and event.keycode == DevConsole.key_activate:
				activate()


func _process(delta):
	queue_redraw()

func activate():
	pause_state = get_tree().paused
	if DevConsole.pause:
		get_tree().paused = true
	show()
	line_edit.grab_focus()
	line_edit.clear.call_deferred()

func deactivate():
	get_tree().paused = pause_state
	hide()

func clear():
	for label in label_box.get_children():
		label.queue_free()

func write_line(line: String, color=color_output):
	if color is Color:
		line = ("[color=#%s]" % color.to_html()) + line

	var label = LINE_LABEL_SCENE.instantiate()
	label_box.add_child.call_deferred(label)
	label.append_text(line + "\n")
	limit_lines.call_deferred()

func limit_lines():
	while label_box.get_child_count() > DevConsole.max_displayed_lines:
		label_box.get_child(0).free()

func error(text: String):
	write_line(text, color_error)

func submit_command(text: String):
	if text.strip_edges() == "":
		return
	line_edit.clear()
	if history.size() < 2 or text != history[history.size() - 2]:
		history.insert(history.size() - 1, text)
		if history.size() > DevConsole.history_limit:
			history.pop_front()
		else:
			history_index += 1

	command_submitted.emit(text)

func handle_scrollbar_changed():
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	pass

func _cycle_history(dir: int):
	if history.size() == 0:
		return
	history_index += dir
	if history_index < 0:
		history_index = 0
	if history_index >= history.size():
		history_index = history.size() - 1
		return
	line_edit.text = history[history_index]
	await get_tree().process_frame
	line_edit.caret_column = 999999999
	
func _on_line_edit_text_submitted(new_text):
	submit_command(new_text)

func _on_line_edit_gui_input(event):
	if event is InputEventKey:
		if event.pressed:
			match event.keycode: 
				KEY_UP:
					_cycle_history(-1)
				KEY_DOWN:
					_cycle_history(1)
				KEY_TAB:
					autocomplete()

func autocomplete():
	if !current_suggestions:
		return
	if !cycling_suggestions:
		suggested_index = -1
	cycling_suggestions = true
	suggested_index += 1
	line_edit.text = suggested
	suggest()
	await get_tree().process_frame
	line_edit.caret_column = 999999999

func suggest():
	var text = line_edit.text
	suggestion.text = text
	if text in current_suggestions:
		return
	current_suggestions = []
	var add_suggestion = func(s: String):
		if !s.begins_with(text):
			return
		if s in current_suggestions:
			return
		current_suggestions.append(s)
	for command in DevConsole.commands:
		add_suggestion.call(command)
		for alias in DevConsole.commands[command].aliases:
			add_suggestion.call(alias)
	if suggested and text:
		suggestion.text = suggested

func _on_line_edit_text_changed(new_text):
	if history.size() == 0:
		return
	if new_text != history[history_index]:
		history_index = history.size() - 1
	if !(line_edit.text in current_suggestions):
		cycling_suggestions = false
	suggest()

func _on_rich_text_label_focus_entered():
	line_edit.grab_focus()
	pass # Replace with function body.

func _on_rich_text_label_mouse_entered():
	mouse_over_text = true
	pass # Replace with function body.

func _on_rich_text_label_mouse_exited():
	mouse_over_text = false
	pass # Replace with function body.

func _draw():
	if selected is Node2D:
		var position = selected.global_position + ((Vector2(get_viewport().size)/2 - selected_viewport.get_camera_2d().global_position) if selected_viewport.get_camera_2d() else Vector2())
		draw_arc(position, 10, 0, TAU, 64, Color.BLACK, 5)
		draw_arc(position, 10, 0, TAU, 64, Color.WHITE, 1)
	pass
