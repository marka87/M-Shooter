extends CanvasLayer
class_name MatchEndScreen

## Siegerbildschirm am Matchende: Titel (Sieg/Niederlage), Grund (Frag- oder Zeitlimit),
## Rangliste aller Teilnehmer und die Statistik des Spielers. Laeuft trotz angehaltenem Spiel.

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var body: BoxContainer = $Center/Panel/Margin/VBox/Body
@onready var grid: GridContainer = $Center/Panel/Margin/VBox/Body/Grid
@onready var stats_grid: GridContainer = $Center/Panel/Margin/VBox/Body/Stats
@onready var again_button: Button = $Center/Panel/Margin/VBox/Buttons/AgainButton
@onready var menu_button: Button = $Center/Panel/Margin/VBox/Buttons/MenuButton

const COLOR_HEAD := Color(0.6, 0.65, 0.75)
const COLOR_PLAYER := Color(1.0, 0.85, 0.3)
## Ab hier passt die Liste nicht mehr ueber die Statistik (720 px hoch): Statistik daneben, Zeilen kompakter
const COMPACT_ROWS := 8


func _ready() -> void:
	again_button.pressed.connect(GameManager.restart_match)
	again_button.visible = not Net.is_client()  # Neustart bestimmt im Netzspiel der Host
	menu_button.pressed.connect(GameManager.return_to_menu)
	(again_button if again_button.visible else menu_button).grab_focus()


func show_results(results: Dictionary) -> void:
	if results.player_won:
		title_label.text = "SIEG!"
		title_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	else:
		title_label.text = "NIEDERLAGE"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	subtitle_label.text = "%s gewinnt – %s erreicht" % [results.winner, results.reason]
	if results.has("teams"):
		subtitle_label.text += "   (Rot %d : %d Blau)" % [results.teams[0], results.teams[1]]

	# Rangliste
	var row_size := 20
	if results.rows.size() > COMPACT_ROWS:
		row_size = 16
		body.vertical = false
		body.add_theme_constant_override("separation", 28)
		$Center/Panel/Margin/VBox/Body/Line2.custom_minimum_size = Vector2(2, 0)
		grid.add_theme_constant_override("v_separation", 2)
	for text in ["#", "NAME", "FRAGS", "TODE", "SCHADEN"]:
		_cell(grid, text, COLOR_HEAD, 16, text != "NAME")
	var place := 1
	for row in results.rows:
		var color := COLOR_PLAYER if row.is_player else Color.WHITE
		_cell(grid, "%d." % place, color, row_size, true)
		_cell(grid, row.name, color, row_size, false)
		_cell(grid, str(row.frags), color, row_size, true)
		_cell(grid, str(row.deaths), color, row_size, true)
		_cell(grid, str(int(row.damage_dealt)), color, row_size, true)
		place += 1

	# Eigene Statistik
	if results.has("player"):
		var p: Dictionary = results.player
		var kd: float = float(p.frags) / maxf(p.deaths, 1)
		_stat("Treffsicherheit", "%d %%" % roundi(minf(results.accuracy, 100.0)))
		_stat("Frags / Tode", "%d / %d  (K/D %.1f)" % [p.frags, p.deaths, kd])
		_stat("Schaden verursacht", str(int(p.damage_dealt)))
		_stat("Schaden erhalten", str(int(p.damage_taken)))
		_stat("Beste Serie", "%d Kills" % p.best_spree)
		_stat("Lieblingswaffe", _favorite_weapon(p.weapon_kills))


func _favorite_weapon(kills: Dictionary) -> String:
	var best := ""
	var best_count := 0
	for weapon in kills:
		if kills[weapon] > best_count:
			best = weapon
			best_count = kills[weapon]
	return "%s (%d Kills)" % [best, best_count] if best_count > 0 else "–"


func _stat(label_text: String, value: String) -> void:
	_cell(stats_grid, label_text, COLOR_HEAD, 17, false)
	_cell(stats_grid, value, Color.WHITE, 17, true)


func _cell(parent: GridContainer, text: String, color: Color, size: int, right: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", size)
	if right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
