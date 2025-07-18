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
@onready var burn_spread_area = $BurnSpread

func _ready():
	player = get_tree().get_first_node_in_group("players")
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	shock_timer.timeout.connect(_on_shock_timer_timeout)


func initialize(round_number):
	var round_health = base_health + (round_number - 1) * 3
	health = round_health + GameManager.enemy_health_bonus
	
	speed = base_speed * GameManager.enemy_speed_multiplier
	scale *= GameManager.enemy_size_multiplier
	
	var all_res = GameManager.enemy_all_resist
	physical_resist += all_res * 10
	
	# KEYSTONE: "Burn the World" prevents enemies from gaining fire resistance.
	if not GameManager.owned_keystones.has("leo_burn_world"):
		fire_resist += all_res
	
	cold_resist += all_res
	lightning_resist += all_res
	
	damage_info = DamageInfo.new()
	damage_info.physical_damage = base_attack_damage + GameManager.enemy_damage_bonus
	damage_info.fire_damage = GameManager.enemy_fire_damage_bonus
	damage_info.cold_damage = GameManager.enemy_cold_damage_bonus
	damage_info.lightning_damage = GameManager.enemy_lightning_damage_bonus
	damage_info.chaos_damage = GameManager.enemy_chaos_damage_bonus
	
	# KEYSTONE: "Burn the World" converts all enemy damage to fire.
	if GameManager.owned_keystones.has("leo_burn_world"):
		var total_other_damage = damage_info.physical_damage + damage_info.cold_damage + damage_info.lightning_damage + damage_info.chaos_damage.x
		damage_info.fire_damage += total_other_damage
		damage_info.physical_damage = 0
		damage_info.cold_damage = 0
		damage_info.lightning_damage = 0
		damage_info.chaos_damage = Vector2.ZERO
	
func take_damage(damage_info: DamageInfo):
	if not damage_info: return
	
	# KEYSTONE: "Char the Flesh" - non-fire damage heals the enemy.
	var non_fire_damage = damage_info.physical_damage + damage_info.cold_damage + damage_info.lightning_damage + randf_range(damage_info.chaos_damage.x, damage_info.chaos_damage.y)
	if GameManager.owned_keystones.has("leo_char_flesh") and non_fire_damage > 0 and damage_info.fire_damage <= 0:
		health += non_fire_damage
		show_damage_number(-non_fire_damage, Color.LIME_GREEN, 0) # Show a green "heal" number
		return

	var total_damage = 0.0
	var damage_number_index = 0
	
	if damage_info.physical_damage > 0:
		var dmg = damage_info.physical_damage * (100.0 / (100.0 + physical_resist))
		total_damage += dmg
		show_damage_number(dmg, Color.GRAY, damage_number_index); damage_number_index += 1
	
	# UPDATED: Fire damage no longer deals instant damage, it only applies the burn effect.
	if damage_info.fire_damage > 0:
		var fire_res_mod = fire_resist
		if not (GameManager.is_avatar and GameManager.avatar_of == "Leo" and GameManager.owned_keystones.has("leo_burn_world")):
			fire_res_mod = min(fire_resist, 75)
		var dmg = damage_info.fire_damage * (1.0 - fire_res_mod / 100.0)
		apply_burn(dmg) # Just apply the burn, no "total_damage += dmg"
	
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
		# KEYSTONE: "Herald of Ash" - check if dying while burning.
		if GameManager.owned_keystones.has("leo_herald_ash") and not active_burns.is_empty():
			player.herald_of_ash_heal()
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
	var max_stacks = 4
	if GameManager.owned_keystones.has("leo_char_flesh"):
		max_stacks = 10
	if active_burns.size() >= max_stacks: return

	# UPDATED: Burn now lasts 4 seconds. DPS is calculated accordingly.
	var dps = damage_amount / 4 
	var duration = 4
	show_damage_number(damage_amount/4, Color.ORANGE_RED, 0)
	
	if GameManager.owned_keystones.has("leo_fan_flames"):
		dps *= 4
		duration /= 4
		
	# NEW: Add a tick_timer to show damage numbers cleanly.
	var new_burn = {"dps": dps, "duration": duration, "tick_timer": 0.5}
	active_burns.append(new_burn)

func process_burns(delta):
	if active_burns.is_empty():
		return
	
	var expired_burns = []
	for burn in active_burns:
		# Deal smooth damage every frame
		health -= burn.dps * delta
		#show_damage_number(burn.dps * delta, Color.ORANGE_RED, 0)
		# Tick down timers
		burn.duration -= delta
		burn.tick_timer -= delta
		
		# Show a damage number and check for new effects only once per second
		if burn.tick_timer <= 0:
			burn.tick_timer += 0.5 # Reset for the next second
			show_damage_number(burn.dps, Color.ORANGE_RED, 0)
			
			# KEYSTONE: Herald of Ash (Avatar) - Burn damage spreads to nearby enemies once per tick.
			if GameManager.is_avatar and GameManager.avatar_of == "Leo" and GameManager.owned_keystones.has("leo_herald_ash"):
				# The damage amount for a new burn is its DPS * its original duration (4s)
				var spread_damage_amount = burn.dps * 2
				for body in burn_spread_area.get_overlapping_bodies():
					if body.is_in_group("enemies") and body != self:
						body.apply_burn(spread_damage_amount)
			
			if health <= 0:
				# Check for death after a damage tick
				if not is_queued_for_deletion():
					# KEYSTONE: Herald of Ash (heal on death) check
					if GameManager.owned_keystones.has("leo_herald_ash"):
						player.herald_of_ash_heal()
					died.emit()
					queue_free()
					return # Stop processing if dead
		
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
	process_burns(_delta)
	if not is_knocked_back:
		if player and player.current_health > 0:
			var final_speed = speed
			# KEYSTONE: "Fan the Flames" makes burning enemies faster.
			if GameManager.owned_keystones.has("leo_fan_flames") and not active_burns.is_empty():
				final_speed *= 1.3
			
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * final_speed
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
