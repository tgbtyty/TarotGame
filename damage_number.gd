extends Label

func _ready():
	var tween = create_tween()
	# Set up the animation: move up by 50 pixels and fade to invisible over 0.8 seconds
	tween.tween_property(self, "position:y", position.y - 50, 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).from(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# When the animation is finished, destroy the label
	tween.tween_callback(queue_free)
