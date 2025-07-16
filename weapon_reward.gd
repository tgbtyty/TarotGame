extends Control

signal weapon_equipped(weapon_data)
signal weapon_scrapped

@onready var name_label = $NameLabel
@onready var desc_label = $DescLabel
@onready var stats_label = $StatsLabel
@onready var equip_button = $EquipButton
@onready var scrap_button = $ScrapButton

var reward_weapon: WeaponData

# The _ready function is no longer needed to connect signals.
# You can remove it entirely if it's empty.
func _ready():
	pass

func show_reward(weapon_data: WeaponData):
	reward_weapon = weapon_data
	name_label.text = weapon_data.weapon_name
	desc_label.text = weapon_data.description
	
	var stats_text = """
	Ammo: %d
	Damage: %d
	Reload: %.2fs
	Fire Rate: %.2fs
	""" % [weapon_data.base_max_ammo, weapon_data.base_damage.physical_damage, weapon_data.base_reload_time, weapon_data.base_fire_rate]
	
	stats_label.text = stats_text
	show()
	get_tree().paused = true

# UPDATED: Correct function name
func _on_equip_button_pressed():
	weapon_equipped.emit(reward_weapon)
	hide()

# UPDATED: Correct function name
func _on_scrap_button_pressed():
	weapon_scrapped.emit()
	hide()
