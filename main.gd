extends Node2D

@onready var enemy_scene = preload("res://enemy.tscn")
@onready var orb_scene = preload("res://orb.tscn")
@onready var player = $Player
@onready var spawn_timer = $SpawnTimer

# --- UI References ---
@onready var kills_label = $HUD_Layer/KillsLabel
@onready var round_label = $HUD_Layer/RoundLabel
@onready var round_complete_label = $HUD_Layer/RoundCompleteLabel
@onready var game_over_screen = $Menu_Layer/GameOverScreen
@onready var pause_menu = $Menu_Layer/PauseMenu
@onready var card_selection_screen = $Card_Layer/CardSelectionScreen

# --- Round Management ---
var current_round = 1
var enemies_to_spawn_this_round = 0
var enemies_spawned_this_round = 0
var enemies_killed_this_round = 0

func _ready():
	player.global_position = get_viewport_rect().size / 2.0
	player.player_died.connect(on_player_died)
	card_selection_screen.selection_complete.connect(begin_spawning)
	start_new_round()

func start_new_round():
	round_label.text = "Round %d" % current_round
	enemies_to_spawn_this_round = 5 + (current_round - 1) * 3
	spawn_timer.wait_time = max(0.2, 1.0 - (current_round - 1) * 0.075)
	enemies_spawned_this_round = 0
	enemies_killed_this_round = 0
	
	if current_round > 1:
		card_selection_screen.start_selection()
	else:
		begin_spawning()

func begin_spawning():
	spawn_timer.start()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			if not card_selection_screen.visible:
				get_tree().paused = false
				pause_menu.hide()
		else:
			get_tree().paused = true
			pause_menu.show()

func _on_spawn_timer_timeout():
	if get_tree().paused: return
	
	if enemies_spawned_this_round < enemies_to_spawn_this_round:
		enemies_spawned_this_round += 1
		spawn_enemy()
	else:
		spawn_timer.stop()

func spawn_enemy():
	var screen_size = get_viewport_rect().size
	var enemy_instance = enemy_scene.instantiate()
	
	enemy_instance.died.connect(on_enemy_died)
	enemy_instance.initialize(current_round)
	
	var edge = randi() % 4
	var spawn_pos = Vector2.ZERO
	match edge:
		0: spawn_pos = Vector2(randf_range(0, screen_size.x), -50)
		1: spawn_pos = Vector2(screen_size.x + 50, randf_range(0, screen_size.y))
		2: spawn_pos = Vector2(randf_range(0, screen_size.x), screen_size.y + 50)
		3: spawn_pos = Vector2(-50, randf_range(0, screen_size.y))
	
	enemy_instance.global_position = spawn_pos
	add_child(enemy_instance)
	
func _on_orb_spawn_timer_timeout():
	if get_tree().paused: return

	var screen_size = get_viewport_rect().size
	var orb_instance = orb_scene.instantiate()
	
	# CORRECTED: Add the orb to the scene FIRST
	add_child(orb_instance)
	
	# Then set its type and position
	var orb_types = ["yellow", "green", "blue"]
	orb_instance.set_type(orb_types.pick_random())
	
	orb_instance.global_position = Vector2(
		randf_range(50, screen_size.x - 50),
		randf_range(50, screen_size.y - 50)
	)

func on_player_died():
	spawn_timer.stop()
	$OrbSpawnTimer.stop() # CORRECTED: Stop orbs from spawning on Game Over
	game_over_screen.show()

func on_enemy_died():
	enemies_killed_this_round += 1
	GameManager.total_kills += 1
	kills_label.text = "Kills: %d" % GameManager.total_kills
	
	if enemies_killed_this_round >= enemies_to_spawn_this_round:
		end_round()

func end_round():
	round_complete_label.show()
	await get_tree().create_timer(2.0).timeout
	round_complete_label.hide()
	
	current_round += 1
	start_new_round()
