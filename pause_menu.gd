extends Control

func _ready():
	$ResumeButton.pressed.connect(on_resume_pressed)
	$QuitButton.pressed.connect(on_quit_pressed)

func on_resume_pressed():
	get_tree().paused = false # Unpause the game
	hide() # Hide the pause menu

func on_quit_pressed():
	get_tree().quit() # Close the game
