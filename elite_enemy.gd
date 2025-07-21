extends "res://enemy.gd"

var elite_type = "red" # Will be randomized
var current_round = 1 # NEW: The variable to store the round number

@onready var aura_area = $AuraArea
@onready var dash_timer = $DashTimer

var buffed_enemies = [] # For auras

# We override the initialize function to add elite stats
# In elite_enemy.gd

func _ready():
	player = get_tree().get_first_node_in_group("players")
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	shock_timer.timeout.connect(_on_shock_timer_timeout)
	
	# NEW: Connect signals here, after the nodes are ready
	match elite_type:
		"yellow", "purple":
			aura_area.body_entered.connect(_on_aura_body_entered)
			aura_area.body_exited.connect(_on_aura_body_exited)
		"white":
			dash_timer.timeout.connect(_on_dash_timer_timeout)

func initialize(round_number):
	super.initialize(round_number)
	
	self.current_round = round_number
	
	# --- Apply Base Elite Modifiers ---
	scale *= 1.5
	base_speed *= 0.75
	damage_info.physical_damage *= 2.0
	health += pow(1.5, round_number)
	
	# --- Randomly Choose and Apply a Variant ---
	var types = ["red", "blue", "yellow", "purple", "white"]
	elite_type = types.pick_random()
	
	match elite_type:
		"red":
			self_modulate = Color.CRIMSON
			fire_resist = 90.0
		"blue":
			self_modulate = Color.ROYAL_BLUE
			cold_resist = 90.0
		"yellow":
			self_modulate = Color.GOLD
			lightning_resist = 90.0
		"purple":
			self_modulate = Color.PURPLE
			physical_resist = 75; fire_resist = 75; cold_resist = 75; lightning_resist = 75
		"white":
			self_modulate = Color.WHITE
			physical_resist = 50; fire_resist = 50; cold_resist = 50; lightning_resist = 50

# We override the take_damage function to add the orb spawn
func take_damage(damage_info: DamageInfo):
	# First, run the original take_damage function from enemy.gd
	super.take_damage(damage_info)
	
	# If that function call caused the enemy to die, spawn an orb
	if is_queued_for_deletion():
		var orb_scene = preload("res://orb.tscn")
		var orb_instance = orb_scene.instantiate()
		get_parent().add_child(orb_instance) # Add to the Main scene
		orb_instance.global_position = global_position
		
		var orb_types = ["yellow", "green", "blue"]
		orb_instance.set_type(orb_types.pick_random())

func _physics_process(delta):
	super._physics_process(delta) # Run the parent enemy's physics process
	
	# Red Elite: Health Regeneration
	if elite_type == "red" and health < (base_health + GameManager.enemy_health_bonus):
		var max_health = base_health + (current_round - 1) * 1 + GameManager.enemy_health_bonus
		health += max_health * 0.03 * delta

# We override apply_slow to handle Blue Elite's immunity
func apply_slow():
	if elite_type == "blue":
		return # Immune to slows
	super.apply_slow()

# --- Elite Ability Functions ---

func _on_dash_timer_timeout():
	# White Elite: Dash
	var direction_to_player = (player.global_position - global_position).normalized()
	# We can reuse the knockback logic to create a dash effect
	apply_knockback(direction_to_player * 1.5) # Dash is faster than knockback

func _on_aura_body_entered(body):
	if body.is_in_group("enemies") and body != self:
		buffed_enemies.append(body)
		match elite_type:
			"yellow": body.apply_aura_buff("speed", 1.15)
			"purple": body.apply_aura_buff("damage", 2.0)

func _on_aura_body_exited(body):
	if body in buffed_enemies:
		buffed_enemies.erase(body)
		match elite_type:
			"yellow": body.remove_aura_buff("speed", 1.15)
			"purple": body.remove_aura_buff("damage", 2.0)
