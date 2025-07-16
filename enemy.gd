extends CharacterBody2D

signal died

var base_speed = 125
var base_health = 20
var base_attack_damage = 20
var damage_info: DamageInfo

# --- Resistances ---
var physical_resist = 0.0
var fire_resist = 0.0
var cold_resist = 0.0
var lightning_resist = 0.0

# --- Final Stats ---
var speed
var health
var attack_damage

# --- Status Effects ---
var is_shocked = false
var is_slowed = false
var active_burns = [] # NEW: Array to track multiple burn stacks
var can_attack = true
var is_knocked_back = false
var player = null

@onready var damage_number_scene = preload("res://damage_number.tscn")
@onready var slow_timer = $SlowTimer
@onready var shock_timer = $ShockTimer

func _ready():
	player = get_tree().get_first_node_in_group("players")
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	shock_timer.timeout.connect(_on_shock_timer_timeout)


func initialize(round_number):
	var round_health = base_health + (round_number - 1) * 1
	health = round_health + GameManager.enemy_health_bonus
	
	speed = base_speed * GameManager.enemy_speed_multiplier
	scale *= GameManager.enemy_size_multiplier
	
	# Apply "all resist" from Pentacles cards
	var all_res = GameManager.enemy_all_resist
	physical_resist += all_res * 10
	fire_resist += all_res
	cold_resist += all_res
	lightning_resist += all_res
	
	# Build the enemy's damage info from base stats and global bonuses
	damage_info = DamageInfo.new()
	damage_info.physical_damage = base_attack_damage + GameManager.enemy_damage_bonus
	damage_info.fire_damage = GameManager.enemy_fire_damage_bonus
	damage_info.cold_damage = GameManager.enemy_cold_damage_bonus
	damage_info.lightning_damage = GameManager.enemy_lightning_damage_bonus
	damage_info.chaos_damage = GameManager.enemy_chaos_damage_bonus
	
func take_damage(damage_info: DamageInfo):
	if not damage_info: return
	
	var total_damage = 0.0
	var damage_number_index = 0
	
	# Physical
	if damage_info.physical_damage > 0:
		var dmg = damage_info.physical_damage * (100.0 / (100.0 + physical_resist))
		total_damage += dmg
		show_damage_number(dmg, Color.GRAY, damage_number_index)
		damage_number_index += 1
	
	# Fire (now only applies the burn effect)
	if damage_info.fire_damage > 0:
		var dmg = damage_info.fire_damage * (1.0 - min(fire_resist, 75) / 100.0)
		# We show the initial hit number, but the damage is done over time by the burn
		show_damage_number(dmg, Color.RED, damage_number_index)
		damage_number_index += 1
		apply_burn(dmg)
	
	# Cold
	if damage_info.cold_damage > 0:
		var dmg = damage_info.cold_damage * (1.0 - min(cold_resist, 75) / 100.0)
		total_damage += dmg
		show_damage_number(dmg, Color.AQUA, damage_number_index)
		damage_number_index += 1
		apply_slow()
	
	# Lightning
	if damage_info.lightning_damage > 0:
		var dmg = damage_info.lightning_damage * (1.0 - min(lightning_resist, 75) / 100.0)
		total_damage += dmg
		show_damage_number(dmg, Color.YELLOW, damage_number_index)
		damage_number_index += 1
		apply_shock()

	# Chaos
	if damage_info.chaos_damage.y > 0:
		var dmg = randf_range(damage_info.chaos_damage.x, damage_info.chaos_damage.y)
		total_damage += dmg
		show_damage_number(dmg, Color.PURPLE, damage_number_index)
		damage_number_index += 1

	if is_shocked:
		total_damage *= 1.1
	
	health -= total_damage
	if health <= 0:
		died.emit()
		queue_free()

func show_damage_number(amount, color, index):
	var number_instance = damage_number_scene.instantiate()
	get_tree().root.add_child(number_instance)
	
	var y_offset = -40 - (index * 25)
	number_instance.global_position = global_position + Vector2(randf_range(-20, 20), y_offset)
	
	number_instance.text = str(round(amount))
	number_instance.modulate = color

# --- Status Effect Logic ---

func apply_burn(damage_amount):
	if active_burns.size() >= 4:
		return

	var dps = damage_amount / 3.0
	var new_burn = {"dps": dps, "duration": 3.0}
	active_burns.append(new_burn)

func process_burns(delta):
	if active_burns.is_empty():
		return
	
	var expired_burns = []
	for burn in active_burns:
		health -= burn.dps * delta
		burn.duration -= delta
		if burn.duration <= 0:
			expired_burns.append(burn)
			
	for expired_burn in expired_burns:
		active_burns.erase(expired_burn)

func apply_slow():
	if not is_slowed:
		is_slowed = true
		speed *= 0.5
	slow_timer.wait_time = 2.0
	slow_timer.start()

func _on_slow_timer_timeout():
	if is_slowed: # Check if still slowed before reverting
		is_slowed = false
		# Recalculate speed from base to account for global multipliers
		speed = base_speed * GameManager.enemy_speed_multiplier

func apply_shock():
	is_shocked = true
	shock_timer.wait_time = 1.0
	shock_timer.start()

func _on_shock_timer_timeout():
	is_shocked = false

# --- Core Logic ---

func _physics_process(_delta):
	process_burns(_delta) # Process active burns every frame

	if not is_knocked_back:
		if player and player.current_health > 0:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
			check_for_player_collision()
	else:
		move_and_slide()

func apply_knockback(direction):
	is_knocked_back = true
	velocity = direction * 400
	get_tree().create_timer(0.15).timeout.connect(func():
		velocity = Vector2.ZERO
		is_knocked_back = false
	)

func check_for_player_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player and can_attack:
			attack()
			
func attack():
	can_attack = false
	
	var final_damage_info = damage_info.duplicate(true)
	var is_crit = randf() < GameManager.enemy_crit_chance
	if is_crit:
		var crit_multiplier = 1.5 + GameManager.enemy_crit_damage
		final_damage_info.physical_damage *= crit_multiplier
		final_damage_info.fire_damage *= crit_multiplier
		final_damage_info.cold_damage *= crit_multiplier
		final_damage_info.lightning_damage *= crit_multiplier
		final_damage_info.chaos_damage *= crit_multiplier

	player.take_damage(final_damage_info)
	get_tree().create_timer(0.5).timeout.connect(func(): can_attack = true)
