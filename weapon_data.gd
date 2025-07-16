extends Resource
class_name WeaponData

@export var weapon_name: String = "Pistol"
@export var description: String = "A reliable sidearm."

# --- Base Stats ---
@export var base_max_ammo: int = 20
@export var base_reload_time: float = 1.0
@export var base_fire_rate: float = 0.5 # Seconds between shots

# --- Base Damage ---
@export var base_damage: DamageInfo

# --- Weapon-Specific Modifiers ---
@export var added_damage_divisor: float = 1.0 # For shotgun
@export var added_damage_multiplier: float = 1.0 # For sniper
@export var stat_modifier_multiplier: float = 1.0 # For sniper
