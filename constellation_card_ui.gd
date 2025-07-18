extends PanelContainer

signal keystone_selected(offering_data)

var offering_data = {}

@onready var const_name_label = $VBoxContainer/ConstellationNameLabel
@onready var key_name_label = $VBoxContainer/KeystoneNameLabel
@onready var desc_label = $VBoxContainer/DescriptionLabel
@onready var select_button = $VBoxContainer/SelectButton

func _ready():
	select_button.pressed.connect(on_select_pressed)

func display_offering(data):
	offering_data = data
	const_name_label.text = data.constellation.const_name
	key_name_label.text = data.keystone.key_name
	desc_label.text = data.keystone.description
	
	if not data.keystone.avatar_description.is_empty():
		desc_label.text += "\n\n" + data.keystone.avatar_description

func on_select_pressed():
	keystone_selected.emit(offering_data)
