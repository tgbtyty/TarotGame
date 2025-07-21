extends Node2D

@onready var enemy_scene = preload("res://enemy.tscn")
@onready var orb_scene = preload("res://orb.tscn")
@onready var player = $Player
@onready var spawn_timer = $SpawnTimer
@onready var weapon_reward_screen = $WeaponReward
@onready var elite_enemy_scene = preload("res://elite_enemy.tscn") # NEW

# --- UI References ---
@onready var kills_label = $HUD_Layer/KillsLabel
@onready var round_label = $HUD_Layer/RoundLabel
@onready var round_complete_label = $HUD_Layer/RoundCompleteLabel
@onready var game_over_screen = $Menu_Layer/GameOverScreen
@onready var pause_menu = $Menu_Layer/PauseMenu
@onready var card_selection_screen = $Card_Layer/CardSelectionScreen
@onready var constellation_reward_screen = $ConstellationReward

# --- Round Management ---
var current_round = 1
var enemies_to_spawn_this_round = 0
var enemies_spawned_this_round = 0
var elites_to_spawn_this_round = 0 # NEW
var elite_spawn_indices = [] # NEW
var is_round_active = false

func _ready():
	player.global_position = get_viewport_rect().size / 2.0
	player.player_died.connect(on_player_died)
	card_selection_screen.selection_complete.connect(begin_spawning)
	constellation_reward_screen.keystone_chosen.connect(_on_constellation_keystone_chosen)
	constellation_reward_screen.offer_scrapped.connect(_on_constellation_offer_scrapped)
	weapon_reward_screen.weapon_equipped.connect(_on_weapon_reward_weapon_equipped)
	weapon_reward_screen.weapon_scrapped.connect(_on_weapon_reward_weapon_scrapped)
	start_new_round()

# This function is removed from _physics_process. We check state differently now.
# func _physics_process(_delta): ...

func start_new_round():
	round_label.text = "Round %d" % current_round
	enemies_to_spawn_this_round = 5 + (current_round - 1) * 3
	spawn_timer.wait_time = max(0.2, 1.0 - (current_round - 1) * 0.075)
	enemies_spawned_this_round = 0
	
	# NEW: Calculate elite spawns for this round
	elites_to_spawn_this_round = 0
	if current_round > 5:
		elites_to_spawn_this_round = 1 + floor((current_round - 6) / 3.0)
	
	# Create a list of all possible spawn indices and shuffle it
	var indices = range(enemies_to_spawn_this_round)
	indices.shuffle()
	# The first N indices will be our elites
	elite_spawn_indices = indices.slice(0, elites_to_spawn_this_round)
	
	if current_round > 1:
		card_selection_screen.start_selection()
	else:
		begin_spawning()

func begin_spawning():
	is_round_active = true
	spawn_timer.start()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			if not card_selection_screen.visible and not weapon_reward_screen.visible:
				get_tree().paused = false
				pause_menu.hide()
		else:
			get_tree().paused = true
			pause_menu.show()

func _on_spawn_timer_timeout():
	if get_tree().paused: return
	
	if enemies_spawned_this_round < enemies_to_spawn_this_round:
		# NEW: Check if this spawn should be an elite
		if enemies_spawned_this_round in elite_spawn_indices:
			spawn_elite_enemy()
		else:
			spawn_enemy()
		enemies_spawned_this_round += 1
	else:
		spawn_timer.stop()

func spawn_enemy():
	var screen_size = get_viewport_rect().size
	var enemy_instance = enemy_scene.instantiate()
	
	enemy_instance.died.connect(on_enemy_died)
	# NEW: Connect to the tree_exited signal. This is our new round-end trigger.
	enemy_instance.tree_exited.connect(check_for_round_end)
	
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
	add_child(orb_instance)
	var orb_types = ["yellow", "green", "blue"]
	orb_instance.set_type(orb_types.pick_random())
	orb_instance.global_position = Vector2(
		randf_range(50, screen_size.x - 50),
		randf_range(50, screen_size.y - 50)
	)

func on_player_died():
	is_round_active = false
	spawn_timer.stop()
	$OrbSpawnTimer.stop()
	game_over_screen.show()

# REWRITTEN: The new logic to end the round reliably.
func on_enemy_died():
	# This function now ONLY handles the kill count.
	GameManager.total_kills += 1
	kills_label.text = "Kills: %d" % GameManager.total_kills

# NEW: A helper function to safely check the enemy count.
func check_for_round_end():
	# If the round isn't active, do nothing.
	if not is_round_active:
		return

	# Condition 1: Has the spawner finished its job for this round?
	var spawner_is_done = enemies_spawned_this_round >= enemies_to_spawn_this_round
	# Condition 2: Are there any enemies left on screen?
	var no_enemies_left = get_tree().get_nodes_in_group("enemies").is_empty()
	
	# If both conditions are true, the round is truly over.
	if spawner_is_done and no_enemies_left:
		end_round()


func end_round():
	is_round_active = false
	spawn_timer.stop()

	round_complete_label.show()
	await get_tree().create_timer(2.0).timeout
	round_complete_label.hide()
	
	# The cleanup loop is no longer necessary here because the check_for_round_end
	# already confirms there are no enemies left.
	
	var reward_weapon = GameManager.get_random_reward_weapon(player.current_weapon.weapon_name)
	weapon_reward_screen.show_reward(reward_weapon)

func _on_weapon_reward_weapon_equipped(weapon_data):
	player.equip_weapon(weapon_data)
	check_for_constellation()

func _on_weapon_reward_weapon_scrapped():
	player.scrap_weapon()
	check_for_constellation()
	
# In main.gd

func check_for_constellation():
	get_tree().call_deferred("set", "paused", false)

	# TODO: This needs to get the actual rank of the last chosen Tarot card.
	# For now, we'll use a placeholder.
	var last_card_rank = 7 
	
	if GameManager.should_constellation_appear(last_card_rank):
		GameManager.constellation_pity_counter = 0
		var offerings = GameManager.get_constellation_offerings()
		if not offerings.is_empty():
			constellation_reward_screen.show_offerings(offerings)
			return # Stop here and wait for the player to choose a keystone.
	
	# If there's no encounter, skip straight to the next round's Tarot cards.
	proceed_to_tarot_cards()

func _on_constellation_keystone_chosen(offering_data):
	var const_name = offering_data.constellation.const_name
	var keystone = offering_data.keystone
	
	# Check if the chosen keystone is an Avatar power-up
	if "avatar" in keystone.key_id:
		GameManager.is_avatar = true
		GameManager.avatar_of = const_name
		print("Became the Avatar of " + const_name)
	else:
		# If it's a regular keystone, add it to the owned list and update counts
		GameManager.owned_keystones[keystone.key_id] = true
		if GameManager.keystone_counts.has(const_name):
			GameManager.keystone_counts[const_name] += 1
		else:
			GameManager.keystone_counts[const_name] = 1
	
	# After processing the choice, proceed to the tarot card selection
	proceed_to_tarot_cards()
	
func _on_constellation_offer_scrapped():
	GameManager.total_tokens += 5
	print("Scrapped offer for 5 tokens. Total tokens: ", GameManager.total_tokens)
	proceed_to_tarot_cards()

func proceed_to_tarot_cards():
	current_round += 1
	start_new_round() # Now proceed to the Tarot Card selection
	
func spawn_elite_enemy():
	var screen_size = get_viewport_rect().size
	var enemy_instance = elite_enemy_scene.instantiate()
	enemy_instance.died.connect(on_enemy_died)
	enemy_instance.initialize(current_round)
	# ... (rest of spawn positioning logic is the same) ...
	add_child(enemy_instance)
