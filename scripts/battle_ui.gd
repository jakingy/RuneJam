extends Control

@onready var player_prob_label = $MarginContainer/HBoxContainer/PlayerStats/Score
@onready var opp_prob_label = $MarginContainer/HBoxContainer/OppStats/Score

func upd_player_prob(cur: int):
	player_prob_label.text = "probability score: %d" % cur
	
func upd_opp_prob(cur: int):
	opp_prob_label.text = "probability score: %d" % cur
