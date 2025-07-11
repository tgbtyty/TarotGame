extends Control

func _ready():
	$RestartButton.pressed.connect(on_restart_pressed)
	$QuitButton.pressed.connect(on_quit_pressed)


func on_restart_pressed():
	# Reloads the entire main game scene
	get_tree().reload_current_scene()

func on_quit_pressed():
	get_tree().quit() # Close the game
