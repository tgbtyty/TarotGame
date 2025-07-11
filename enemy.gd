extends CharacterBody2D

signal died

var speed = 125 # UPDATED
var health = 20
var attack_damage = 20
var can_attack = true

var player = null

func _ready():
	# Find the player node as soon as the enemy is created
	player = get_tree().get_first_node_in_group("players")

func _physics_process(_delta):
	if player and player.current_health > 0: # Stop moving if player is dead
		# Movement logic
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		# Attack logic
		check_for_player_collision()

func take_damage(amount):
	health -= amount
	if health <= 0:
		died.emit() # Emit the signal
		queue_free() # Enemy dies

func check_for_player_collision():
	# Check if the enemy is touching another body
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		# If the body is the player and the enemy can attack
		if collision.get_collider() == player and can_attack:
			attack()
			
func attack():
	can_attack = false # Go on cooldown
	player.take_damage(attack_damage) # Call the player's damage function
	# Use a timer to reset the attack cooldown after 0.5 seconds
	get_tree().create_timer(0.5).timeout.connect(func(): can_attack = true)
