extends Control

const FIRST_LEVEL := "res://levels/level_1.tscn"

@onready var play_button: Button        = find_child("PlayButton", true, false) as Button
@onready var continue_button: Button    = find_child("ContinueButton", true, false) as Button
@onready var options_button: Button     = find_child("OptionsButton", true, false) as Button
@onready var quit_button: Button        = find_child("QuitButton", true, false) as Button
@onready var dimmer: ColorRect          = find_child("Dimmer", true, false) as ColorRect

# ✅ FIX #1: the node is named "Options" in the scene
@onready var options_window: Window     = find_child("Options", true, false) as Window
@onready var master_slider: HSlider     = find_child("MasterSlider", true, false) as HSlider
@onready var fullscreen_check: CheckBox = find_child("FullscreenCheck", true, false) as CheckBox
@onready var back_button: Button        = find_child("BackButton", true, false) as Button
@onready var clear_button: Button       = find_child("ClearButton", true, false) as Button

var _master_bus := 0

func _ready() -> void:
	
	
	if dimmer:
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if play_button:
		play_button.pressed.connect(_on_play_pressed)

	if continue_button:
		# ✅ FIX #2: wire up the signal
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.visible = Save.has_save()

	if options_button:
		options_button.pressed.connect(_on_options_pressed)

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if options_window:
		options_window.hide()
	if back_button and options_window:
		back_button.pressed.connect(func(): options_window.hide())

	_master_bus = AudioServer.get_bus_index("Master")
	if _master_bus < 0:
		_master_bus = 0

	if clear_button:
		clear_button.pressed.connect(_on_clear_button_pressed)



@onready var label = $Label

func show_label_for_seconds(seconds: float = 2.0) -> void:
	label.visible = true
	await get_tree().create_timer(seconds).timeout
	label.visible = false

func _on_clear_button_pressed() -> void:
	show_label_for_seconds(3.0)
	continue_button.visible = false
	Save.erase_save()

func _on_play_pressed() -> void:
	#Save.erase_save()
	get_tree().change_scene_to_file(FIRST_LEVEL)

func _on_continue_pressed() -> void:
	if Save.has_save():
		Save.continue_game()

func _on_options_pressed() -> void:
	if options_window:
		options_window.popup_centered()
		options_window.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()





func _unhandled_input(event: InputEvent) -> void:
	if options_window and options_window.visible and event.is_action_pressed("ui_cancel"):
		options_window.hide()
