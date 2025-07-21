extends CharacterBody2D

signal player_died

@export var speed = 150
@export var dash_speed = 900
@export var bullet_scene: PackedScene

# --- Core Data ---
var current_weapon: WeaponData
var total_buffs: Dictionary = {
	"max_health": 0.0, "phys_resist": 0.0, "move_speed": 0.0, "max_ammo": 0.0,
	"phys_dmg": 0.0, "atk_speed": 0.0, "reload_speed": 0.0, "crit_chance": 0.0,
	"fire_dmg": 0.0, "cold_dmg": 0.0, "lightning_dmg": 0.0, "elemental_resist": 0.0,
	"chaos_dmg": Vector2.ZERO, "crit_dmg": 0.0, "special_dmg": 0.0
}
var damage_reduction_multiplier = 1.0 #herald of ash
var base_pierce: int
var lifespan_multiplier: float
var homing_strength: float
var projectile_count_multiplier: int

# --- Final Calculated Stats (dynamic) ---
var max_health: float
var current_health: float
var magazine_size: int
var current_ammo: int
var reload_time: float
var fire_rate: float
var final_damage_info: DamageInfo
var crit_chance: float
var crit_damage_multiplier: float
var special_damage_multiplier: float
var move_speed_multiplier: float
var physical_resist: float
var fire_resist: float
var cold_resist: float
var lightning_resist: float

# --- Status & State ---
var is_repelling = false
var is_shocked = false
var is_slowed = false
var current_burn_dps = 0.0
var burn_ticks_left = 0
var is_dashing = false
var can_dash = true
var can_shoot = true
var is_reloading = false
var can_use_special = true
var dash_direction = Vector2.ZERO

# --- Node References ---
@onready var muzzle = $Muzzle
@onready var dash_bar = $DashBar
@onready var pushback_area = $PushbackArea
@onready var sniper_tracer = $Line2D
@onready var burn_timer = $BurnTimer
@onready var slow_timer = $SlowTimer
@onready var shock_timer = $ShockTimer
@onready var burn_aura = $BurnAura # NEW
@onready var damage_reduc_timer = $DamageReducTimer # NEW
@onready var burn_aura_timer = $BurnAuraTimer # NEW
@onready var flamethrower_area = $FlamethrowerArea
@onready var flamethrower_vfx = $FlamethrowerArea/Polygon2D # NEW
@onready var health_bar = get_node_or_null("/root/Main/HUD_Layer/HealthBar")
@onready var special_label = get_node_or_null("/root/Main/HUD_Layer/SpecialCooldownLabel")
@onready var ammo_label = get_node_or_null("/root/Main/HUD_Layer/AmmoLabel")
@onready var reload_indicator = get_node_or_null("/root/Main/HUD_Layer/ReloadIndicator")



func _ready():
	equip_weapon(GameManager.weapon_database["Pistol"])
	burn_timer.timeout.connect(_on_burn_timer_timeout)
	slow_timer.timeout.connect(_on_slow_timer_timeout)
	shock_timer.timeout.connect(_on_shock_timer_timeout)
	damage_reduc_timer.timeout.connect(_on_damage_reduc_timer_timeout) # NEW
	burn_aura_timer.timeout.connect(_on_burn_aura_timer_timeout) # NEW
	if reload_indicator:
		reload_indicator.value = 0
		reload_indicator.visible = false

func recalculate_stats():
	var weapon_mod = current_weapon.stat_modifier_multiplier
	
	max_health = 100.0 + total_buffs.max_health
	move_speed_multiplier = 1.0 + total_buffs.move_speed
	magazine_size = current_weapon.base_max_ammo + int(total_buffs.max_ammo * weapon_mod)
	reload_time = current_weapon.base_reload_time / (1.0 + (total_buffs.reload_speed * weapon_mod))
	fire_rate = current_weapon.base_fire_rate / (1.0 + (total_buffs.atk_speed * weapon_mod))
	crit_chance = total_buffs.crit_chance
	crit_damage_multiplier = 1.5 + total_buffs.crit_dmg
	special_damage_multiplier = 1.0 + total_buffs.special_dmg
	
	physical_resist = total_buffs.phys_resist
	var elemental_res = total_buffs.elemental_resist
	fire_resist = elemental_res
	cold_resist = elemental_res
	lightning_resist = elemental_res
	
	final_damage_info = current_weapon.base_damage.duplicate(true)
	if current_weapon.accepts_physical_damage_buffs:
		var added_phys_dmg = total_buffs.phys_dmg * current_weapon.added_damage_multiplier
		final_damage_info.physical_damage += added_phys_dmg
	final_damage_info.fire_damage += total_buffs.fire_dmg
	final_damage_info.cold_damage += total_buffs.cold_dmg
	final_damage_info.lightning_damage += total_buffs.lightning_dmg
	final_damage_info.chaos_damage += total_buffs.chaos_dmg
	
		# --- NEW: Sagittarius Keystone Stats ---
	# Herald of Shrapnel
	base_pierce = 1 # Default pierce for all weapons
	if GameManager.owned_keystones.has("sagi_herald_shrapnel"):
		if GameManager.is_avatar and GameManager.avatar_of == "Sagittarius":
			base_pierce += 10 # Avatar
		else:
			base_pierce += 2 # Base
	
	# Zhuge Liang
	lifespan_multiplier = 1.0
	if GameManager.owned_keystones.has("sagi_zhuge_liang"):
		if GameManager.is_avatar and GameManager.avatar_of == "Sagittarius":
			lifespan_multiplier *= 3.0 # Avatar: 200% *increased* means 3x total
		else:
			lifespan_multiplier *= 1.2 # Base
			
	# Throatseeker
	homing_strength = 0.0
	if GameManager.owned_keystones.has("sagi_throatseeker"):
		if GameManager.is_avatar and GameManager.avatar_of == "Sagittarius":
			homing_strength = 1.0 # Avatar: Strong homing
		else:
			homing_strength = 0.1 # Base: Slight bend
	
	# Blot out the skies
	projectile_count_multiplier = 1
	if GameManager.owned_keystones.has("sagi_blot_skies"):
		if GameManager.is_avatar and GameManager.avatar_of == "Sagittarius":
			projectile_count_multiplier = 3 # Avatar
		else:
			projectile_count_multiplier = 2 # Base
	
		# Herald of Shrapnel damage penalty
	if GameManager.owned_keystones.has("sagi_herald_shrapnel"):
		final_damage_info.physical_damage *= 0.9
		# (apply penalty to other damage types too if needed)
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	if dash_bar:
		dash_bar.max_value = $DashCooldown.wait_time
		dash_bar.visible = false

func equip_weapon(new_weapon: WeaponData):
	current_weapon = new_weapon
	recalculate_stats()
	current_health = max_health
	current_ammo = magazine_size
	
func scrap_weapon():
	GameManager.total_tokens += 1
	print("Scrapped weapon for 1 token. Total tokens: ", GameManager.total_tokens)

func apply_card_buff(card_data):
	var effect = card_data.effect_type
	var value = GameManager.get_scaled_value(card_data.rank_number, effect)
	
	match effect:
		"max_health": total_buffs.max_health += value
		"phys_resist": total_buffs.phys_resist += value
		"move_speed": total_buffs.move_speed += value / 100.0
		"max_ammo": total_buffs.max_ammo += value
		"phys_dmg": total_buffs.phys_dmg += value
		"atk_speed": total_buffs.atk_speed += value / 100.0
		"reload_speed": total_buffs.reload_speed += value / 100.0
		"crit_chance": total_buffs.crit_chance += value / 100.0
		"fire_dmg": total_buffs.fire_dmg += value
		"cold_dmg": total_buffs.cold_dmg += value
		"lightning_dmg": total_buffs.lightning_dmg += value
		"elemental_resist": total_buffs.elemental_resist += value
		"chaos_dmg": total_buffs.chaos_dmg += value
		"crit_dmg": total_buffs.crit_dmg += value / 100.0
		"special_dmg": total_buffs.special_dmg += value / 100.0
		"all_resist": move_speed_multiplier += value / 100.0
			
	recalculate_stats()
	
func _physics_process(_delta):
	if Input.is_action_pressed("shoot") and can_shoot and current_ammo > 0 and not is_reloading:
		shoot()
	if is_repelling:
		push_back_nearby_enemies()
	
	if special_label and not $SpecialCooldown.is_stopped():
		special_label.text = "Special: %.1fs" % $SpecialCooldown.time_left
	if dash_bar and dash_bar.visible:
		dash_bar.value = $DashCooldown.time_left
	if is_reloading and reload_indicator:
		var reload_timer = $ReloadTimer
		var time_passed = reload_timer.wait_time - reload_timer.time_left
		reload_indicator.value = (time_passed / reload_timer.wait_time) * 100

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		var final_speed = speed * move_speed_multiplier
		var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_direction * final_speed
		look_at(get_global_mouse_position())
	
	move_and_slide()
	
	var screen_size = get_viewport_rect().size
	global_position.x = clamp(global_position.x, 0, screen_size.x)
	global_position.y = clamp(global_position.y, 0, screen_size.y)

func _unhandled_input(event):
	if event.is_action_pressed("dash") and not is_dashing and can_dash:
		start_dash()
	if event.is_action_pressed("reload") and not is_reloading and current_ammo < magazine_size:
		reload_gun()
	if event.is_action_pressed("special") and can_use_special and current_ammo > 0 and not is_reloading:
		fan_the_hammer()

func take_damage(damage_info: DamageInfo):
	if is_repelling: return
	
	var total_damage = 0.0
	
	if damage_info.physical_damage > 0:
		total_damage += damage_info.physical_damage * (100.0 / (100.0 + physical_resist))
	if damage_info.fire_damage > 0:
		var dmg = damage_info.fire_damage * (1.0 - min(fire_resist, 75) / 100.0)
		total_damage += dmg
		apply_burn(dmg)
	if damage_info.cold_damage > 0:
		total_damage += damage_info.cold_damage * (1.0 - min(cold_resist, 75) / 100.0)
		apply_slow()
	if damage_info.lightning_damage > 0:
		total_damage += damage_info.lightning_damage * (1.0 - min(lightning_resist, 75) / 100.0)
		apply_shock()
	if damage_info.chaos_damage.y > 0:
		total_damage += randf_range(damage_info.chaos_damage.x, damage_info.chaos_damage.y)

	if is_shocked:
		total_damage *= 1.1
		
	
	total_damage *= damage_reduction_multiplier #Herald of Ash Avatar
	current_health -= total_damage
	if health_bar: health_bar.value = current_health
	
	push_back_nearby_enemies()
	
	if current_health <= 0:
		current_health = 0
		player_died.emit()
		hide()
		$CollisionShape2D.set_deferred("disabled", true)

func push_back_nearby_enemies():
	var bodies = pushback_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			var push_direction = (body.global_position - global_position).normalized()
			body.apply_knockback(push_direction)

func start_dash():
	is_dashing = true
	can_dash = false
	$DashCooldown.start()
	if dash_bar: dash_bar.visible = true
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction != Vector2.ZERO:
		dash_direction = input_direction.normalized()
	else:
		dash_direction = Vector2.RIGHT.rotated(global_rotation)
	get_tree().create_timer(0.2).timeout.connect(func(): is_dashing = false)

func shoot():
	if not can_shoot or is_reloading or current_ammo <= 0: return
	
	can_shoot = false
	current_ammo -= 1
	if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	
	
	if GameManager.owned_keystones.has("sagi_blot_skies"):
		var projectile_count = 0
		match current_weapon.weapon_name:
			"Pistol", "Sniper": projectile_count = 1 * projectile_count_multiplier
			"Shotgun": projectile_count = 4 * projectile_count_multiplier
		
		for i in projectile_count:
			# Fire in a random 360-degree direction
			fire_single_bullet(900, base_pierce, 0.0, Vector2.RIGHT.rotated(randf_range(0, TAU)))
			
	else:
		match current_weapon.weapon_name:
			"Pistol":
				fire_single_bullet(900, base_pierce, 0.0)
			"Shotgun":
				for i in 4:
					fire_single_bullet(1000, base_pierce, 25.0)
			"Sniper":
				fire_sniper_raycast()
			"Flamethrower":
				# --- Visual Effect ---
				flamethrower_vfx.visible = true
				get_tree().create_timer(fire_rate).timeout.connect(func(): flamethrower_vfx.visible = false)

				
				var shot_damage = final_damage_info.duplicate(true)
				var is_crit = randf() < crit_chance
				if is_crit:
					# Apply crit to all damage types on the flamethrower puff
					shot_damage.fire_damage *= crit_damage_multiplier
					shot_damage.cold_damage *= crit_damage_multiplier
					shot_damage.lightning_damage *= crit_damage_multiplier
					shot_damage.chaos_damage *= crit_damage_multiplier

				var enemies_in_cone = flamethrower_area.get_overlapping_bodies()
				for enemy in enemies_in_cone:
					if enemy.is_in_group("enemies"):
						enemy.take_damage(shot_damage)
			
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)
	if current_ammo == 0: reload_gun()

func fire_sniper_raycast():
	var space_state = get_world_2d().direct_space_state
	var ray_origin = muzzle.global_position
	var ray_target = ray_origin + (get_global_mouse_position() - ray_origin).normalized() * 2000
	
	var shot_damage = final_damage_info.duplicate(true)
	var is_crit = randf() < crit_chance
	if is_crit:
		shot_damage.physical_damage *= crit_damage_multiplier
		shot_damage.fire_damage *= crit_damage_multiplier
		shot_damage.cold_damage *= crit_damage_multiplier
		shot_damage.lightning_damage *= crit_damage_multiplier
		shot_damage.chaos_damage *= crit_damage_multiplier

	var enemies_to_exclude = []
	var tracer_points = [ray_origin] # Start the tracer at the muzzle
	
	while true:
		var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_target, 1 << 1, enemies_to_exclude)
		var result = space_state.intersect_ray(query)
		
		if result.is_empty():
			tracer_points.append(ray_target)
			break
		
		var collider = result.collider
		if collider.is_in_group("enemies"):
			collider.take_damage(shot_damage)
			enemies_to_exclude.append(collider)
			ray_origin = result.position + (ray_target - ray_origin).normalized()
		else:
			tracer_points.append(result.position)
			break
			
	# --- Visual Tracer Effect ---
	sniper_tracer.clear_points()
	# UPDATED: Use to_local() to correctly transform global points into the Line2D's space
	for point in tracer_points:
		sniper_tracer.add_point(sniper_tracer.to_local(point))
	
	sniper_tracer.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): sniper_tracer.visible = false)



func fire_single_bullet(bullet_speed: float, pierce: int, spread_degrees: float = 0.0, direction_override: Vector2 = Vector2.ZERO):
	var weapon_lifespan = 1.0 # Default
	match current_weapon.weapon_name:
		"Pistol": weapon_lifespan = 2.0
		"Shotgun": weapon_lifespan = 0.5
	
	if not bullet_scene: return
	var bullet = bullet_scene.instantiate()
	bullet.speed = bullet_speed
	bullet.pierce_count = pierce
	bullet.lifespan = weapon_lifespan * lifespan_multiplier
	bullet.homing_strength = homing_strength
	
	var shot_damage = final_damage_info.duplicate(true)
	if current_weapon.added_damage_divisor > 1.0:
		shot_damage.physical_damage = ceil(shot_damage.physical_damage / current_weapon.added_damage_divisor)
	
	if GameManager.owned_keystones.has("leo_inferno"):
		var total_other_damage = shot_damage.physical_damage + shot_damage.cold_damage + shot_damage.lightning_damage + randf_range(shot_damage.chaos_damage.x, shot_damage.chaos_damage.y)
		if GameManager.is_avatar and GameManager.avatar_of == "Leo":
			shot_damage.fire_damage += total_other_damage
		else:
			shot_damage.fire_damage = (shot_damage.fire_damage * 2.0) - total_other_damage
		shot_damage.physical_damage = 0; shot_damage.cold_damage = 0; shot_damage.lightning_damage = 0; shot_damage.chaos_damage = Vector2.ZERO

	var is_crit = randf() < crit_chance
	if is_crit:
		shot_damage.physical_damage *= crit_damage_multiplier
		shot_damage.fire_damage *= crit_damage_multiplier
		shot_damage.cold_damage *= crit_damage_multiplier
		shot_damage.lightning_damage *= crit_damage_multiplier
		shot_damage.chaos_damage *= crit_damage_multiplier
	
	bullet.damage_info = shot_damage
	
	var final_rotation = muzzle.global_rotation
	if direction_override != Vector2.ZERO:
		final_rotation = direction_override.angle()
	else:
		final_rotation += deg_to_rad(randf_range(-spread_degrees/2, spread_degrees/2))
	
	get_tree().root.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = final_rotation

func reload_gun():
	if is_reloading: return
	is_reloading = true
	$ReloadTimer.wait_time = reload_time
	$ReloadTimer.start()
	if ammo_label: ammo_label.text = "Reloading..."
	if reload_indicator: reload_indicator.visible = true

func fan_the_hammer():
	can_use_special = false
	can_shoot = false
	$SpecialCooldown.start()
	if special_label: special_label.text = "Special: 6.0s"
	
	var bullets_to_fire = current_ammo
	current_ammo = 0
	if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	
	for i in bullets_to_fire:
		if not bullet_scene: return
		
		var final_damage = final_damage_info.duplicate(true)
		
		# KEYSTONE: "Become the Inferno" logic applies to the special, too.
		if GameManager.owned_keystones.has("leo_inferno"):
			var total_other_damage = final_damage.physical_damage + final_damage.cold_damage + final_damage.lightning_damage + randf_range(final_damage.chaos_damage.x, final_damage.chaos_damage.y)
			if GameManager.is_avatar and GameManager.avatar_of == "Leo":
				final_damage.fire_damage += total_other_damage
			else:
				final_damage.fire_damage = (final_damage.fire_damage * 2.0) - total_other_damage
			final_damage.physical_damage = 0; final_damage.cold_damage = 0; final_damage.lightning_damage = 0; final_damage.chaos_damage = Vector2.ZERO

		var is_crit = randf() < crit_chance
		var final_multiplier = special_damage_multiplier
		if is_crit:
			final_multiplier *= crit_damage_multiplier
		
		final_damage.physical_damage *= final_multiplier
		final_damage.fire_damage *= final_multiplier
		final_damage.cold_damage *= final_multiplier
		final_damage.lightning_damage *= final_multiplier
		final_damage.chaos_damage *= final_multiplier
		
		var bullet = bullet_scene.instantiate()
		bullet.speed = 2000
		bullet.damage_info = final_damage
		get_tree().root.add_child(bullet)
		
		var spread = deg_to_rad(randf_range(-15, 15))
		bullet.global_position = muzzle.global_position
		bullet.global_rotation = muzzle.global_rotation + spread
		
		await get_tree().create_timer(0.05).timeout
	
	reload_gun()
	can_shoot = true

func _on_special_cooldown_timeout():
	can_use_special = true
	if special_label: special_label.text = "Special: Ready"

func _on_dash_cooldown_timeout():
	can_dash = true
	if dash_bar: dash_bar.visible = false

func _on_reload_timer_timeout():
	is_reloading = false
	current_ammo = magazine_size
	if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	if reload_indicator:
		reload_indicator.visible = false
		reload_indicator.value = 0

func _on_orb_collector_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("orbs"):
		match area.orb_type:
			"yellow": apply_yellow_orb_effect()
			"green": apply_green_orb_effect()
			"blue": apply_blue_orb_effect()
		area.queue_free()

func apply_yellow_orb_effect():
	if not is_reloading: current_ammo = magazine_size
	if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	
	total_buffs.atk_speed += 1.0
	recalculate_stats()
	
	var tween = get_tree().create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func():
		total_buffs.atk_speed -= 1.0
		recalculate_stats()
		if not is_reloading: current_ammo = magazine_size
		if ammo_label: ammo_label.text = "%d / %d" % [current_ammo, magazine_size]
	)

func apply_green_orb_effect():
	var heal_amount = max_health * 0.25
	current_health = min(max_health, current_health + heal_amount)
	if health_bar: health_bar.value = current_health

func apply_blue_orb_effect():
	is_repelling = true
	var tween = get_tree().create_tween()
	tween.tween_interval(5.0)
	tween.tween_callback(func(): is_repelling = false)

func apply_burn(damage_amount):
	var dps = damage_amount / 3.0
	if dps > current_burn_dps:
		current_burn_dps = dps
	burn_ticks_left = 3
	if burn_timer.is_stopped(): burn_timer.start(1.0)

func _on_burn_timer_timeout():
	if burn_ticks_left > 0:
		var empty_damage = DamageInfo.new()
		take_damage(empty_damage) # Trigger pushback without damage
		current_health -= current_burn_dps
		burn_ticks_left -= 1
		if health_bar: health_bar.value = current_health
		if current_health <= 0:
			if not is_queued_for_deletion():
				player_died.emit()
				hide()
				$CollisionShape2D.set_deferred("disabled", true)
	else:
		burn_timer.stop()
		current_burn_dps = 0.0

func apply_slow():
	if not is_slowed:
		is_slowed = true
		move_speed_multiplier *= 0.7
	slow_timer.start(2.0)
	
func _on_slow_timer_timeout():
	if is_slowed:
		is_slowed = false
		move_speed_multiplier /= 0.7
		
func apply_shock():
	is_shocked = true
	shock_timer.start(1.0)

func _on_shock_timer_timeout():
	is_shocked = false
	
func herald_of_ash_heal():
	var heal_amount = max_health * 0.01
	current_health = min(max_health, current_health + heal_amount)
	if health_bar: health_bar.value = current_health
	
	# KEYSTONE: Herald of Ash (Avatar) - trigger damage reduction on heal
	if GameManager.is_avatar and GameManager.avatar_of == "Leo" and GameManager.owned_keystones.has("leo_herald_ash"):
		activate_herald_avatar_buff()
		
func activate_herald_avatar_buff():
	damage_reduction_multiplier = 0.8 # 20% damage reduction
	damage_reduc_timer.start()
func _on_damage_reduc_timer_timeout():
	damage_reduction_multiplier = 1.0 

func _on_burn_aura_timer_timeout():
	# KEYSTONE: Fan the Flames (Avatar) - apply burn to nearby enemies
	if not (GameManager.is_avatar and GameManager.avatar_of == "Leo" and GameManager.owned_keystones.has("leo_fan_flames")):
		return
	
	var burn_damage = DamageInfo.new()
	burn_damage.fire_damage = 5 # A small, constant burn
	
	for body in burn_aura.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(burn_damage)
