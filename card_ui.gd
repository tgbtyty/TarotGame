extends PanelContainer

signal card_chosen(card_data)

var my_card_data = {}

@onready var name_label = $VBoxContainer/NameLabel
@onready var chosen_effect_label = $VBoxContainer/ChosenEffectLabel
@onready var passed_effect_label = $VBoxContainer/PassedEffectLabel
@onready var choose_button = $VBoxContainer/ChooseButton

func _ready():
	choose_button.pressed.connect(on_choose_pressed)

func display_card(card_data):
	my_card_data = card_data
	name_label.text = card_data.name
	
	var effect_type = card_data.effect_type
	var value = GameManager.get_scaled_value(card_data.rank_number, effect_type)
	
	# UPDATED: We now use a match statement to generate only the text we need.
	match effect_type:
		"max_health":
			chosen_effect_label.text = "If Chosen: +%d Max Health" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d Health" % value
		"phys_resist":
			chosen_effect_label.text = "If Chosen: +%.1f%% Physical Resist" % value
			passed_effect_label.text = "If Passed, Enemies get: +%.1f%% to All Resists" % value
		"move_speed":
			chosen_effect_label.text = "If Chosen: +%d%% Movement Speed" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d%% Movement Speed" % value
		"max_ammo":
			chosen_effect_label.text = "If Chosen: +%d Maximum Ammo" % value
			passed_effect_label.text = "If Passed, Enemies get: %d%% Larger" % value
		"phys_dmg":
			chosen_effect_label.text = "If Chosen: +%d Physical Damage" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d Physical Damage" % value
		"atk_speed":
			chosen_effect_label.text = "If Chosen: +%d%% Attack Speed" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d%% Movement Speed" % value
		"reload_speed":
			chosen_effect_label.text = "If Chosen: +%d%% Reload Speed" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d Physical Damage" % value
		"crit_chance":
			chosen_effect_label.text = "If Chosen: +%.1f%% Crit Chance" % value
			passed_effect_label.text = "If Passed, Enemies get: +%.1f%% Crit Chance" % value
		"fire_dmg":
			chosen_effect_label.text = "If Chosen: +%d Fire Damage" % value
			passed_effect_label.text = "If Passed, this card has no effect."
		"cold_dmg":
			chosen_effect_label.text = "If Chosen: +%d Cold Damage" % value
			passed_effect_label.text = "If Passed, this card has no effect."
		"lightning_dmg":
			chosen_effect_label.text = "If Chosen: +%d Lightning Damage" % value
			passed_effect_label.text = "If Passed, this card has no effect."
		"elemental_resist":
			chosen_effect_label.text = "If Chosen: +%.1f%% to all Elemental Resists" % value
			passed_effect_label.text = "If Passed, this card has no effect."
		"chaos_dmg":
			chosen_effect_label.text = "If Chosen: +%d-%d Chaos Damage" % [value.x, value.y]
			passed_effect_label.text = "If Passed, this card has no effect."
		"crit_dmg":
			chosen_effect_label.text = "If Chosen: +%d%% Crit Damage" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d%% Crit Damage" % value
		"special_dmg":
			chosen_effect_label.text = "If Chosen: +%d%% Special Damage" % value
			passed_effect_label.text = "If Passed, Enemies get: +%d Health" % (value * 2)
		"all_resist":
			chosen_effect_label.text = "If Chosen: +%d%% Movement Speed" % value
			passed_effect_label.text = "If Passed, Enemies get: +%.1f%% to all Resistances" % value


func on_choose_pressed():
	card_chosen.emit(my_card_data)
