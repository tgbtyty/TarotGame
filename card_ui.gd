extends PanelContainer

signal card_chosen(card_data)

var my_card_data = {}

@onready var name_label = $VBoxContainer/NameLabel
@onready var chosen_effect_label = $VBoxContainer/ChosenEffectLabel
@onready var passed_effect_label = $VBoxContainer/PassedEffectLabel
@onready var choose_button = $VBoxContainer/ChooseButton



func display_card(card_data):
	my_card_data = card_data
	name_label.text = card_data.name
	match card_data.suit:
		"Cups":
			chosen_effect_label.text = "If Chosen: +%d Max Health" % card_data.value
			passed_effect_label.text = "If Passed, Enemies get: +%d Health" % card_data.value
		"Swords":
			chosen_effect_label.text = "If Chosen: +%d Bullet Damage" % card_data.value
			passed_effect_label.text = "If Passed, Enemies get: +%d Damage" % card_data.value
		"Pentacles":
			chosen_effect_label.text = "If Chosen: %d%% faster Attack & Reload" % card_data.value
			passed_effect_label.text = "If Passed, Enemies get: %d%% faster Movement" % card_data.value
		"Wands":
			chosen_effect_label.text = "If Chosen: +%d Max Ammo" % card_data.value
			passed_effect_label.text = "If Passed, Enemies get: %d%% Larger" % card_data.value


# This function name is fine as long as it's connected in _ready()
func _on_choose_button_pressed():
	card_chosen.emit(my_card_data)
