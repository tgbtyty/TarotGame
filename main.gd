extends Node2D

@onready var enemy_scene = preload("res://enemy.tscn")
@onready var kills_label = $CanvasLayer/KillsLabel
@onready var game_over_screen = $CanvasLayer/GameOverScreen
@onready var pause_menu = $CanvasLayer/PauseMenu

var total_kills = 0

func _ready():
	var screen_size = get_viewport_rect().size
	$Player.global_position = screen_size / 2.0
	
	# Connect the player's death signal
	$Player.player_died.connect(on_player_died)

func _unhandled_input(event):
	# Handle pausing the game
	if event.is_action_pressed("ui_cancel"): # "ui_cancel" is the default for Escape key
		if get_tree().paused:
			get_tree().paused = false
			pause_menu.hide()
		else:
			get_tree().paused = true
			pause_menu.show()

func _on_spawn_timer_timeout():
	var screen_size = get_viewport_rect().size
	var enemies_to_spawn = randi_range(2, 5)
	
	for i in enemies_to_spawn:
		var enemy_instance = enemy_scene.instantiate()
		
		# Connect the enemy's death signal before adding it to the scene
		enemy_instance.died.connect(on_enemy_died)
		
		var edge = randi() % 4
		var spawn_pos = Vector2.ZERO
		
		match edge:
			0: # Top edge
				spawn_pos = Vector2(randf_range(0, screen_size.x), -50)
			1: # Right edge
				spawn_pos = Vector2(screen_size.x + 50, randf_range(0, screen_size.y))
			2: # Bottom edge
				spawn_pos = Vector2(randf_range(0, screen_size.x), screen_size.y + 50)
			3: # Left edge
				spawn_pos = Vector2(-50, randf_range(0, screen_size.y))
		
		enemy_instance.global_position = spawn_pos
		add_child(enemy_instance)

func on_player_died():
	# Stop spawning enemies and show the game over screen
	$SpawnTimer.stop()
	game_over_screen.show()

func on_enemy_died():
	total_kills += 1
	kills_label.text = "Kills: %d" % total_kills
