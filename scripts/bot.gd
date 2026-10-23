extends CharacterBody3D
class_name Bot

## Gegner-Bot fuer die Arena. Entscheidungen per Utility-AI (utility_scores): Angreifen, Verfolgen,
## Item holen oder Patrouille bekommen eine Punktzahl, die beste wird ausgefuehrt (Zustaende PATROL/CHASE/ATTACK).
## Jeder gegen jeden: Ziel ist der naechste sichtbare Gegner (Spieler oder anderer Bot).
## Verwendet NavigationAgent3D fuer die Wegfindung und schiesst mit Streuung je nach Schwierigkeit.

# ==============================================================================
# ZUSTAENDE (STATE MACHINE)
# ==============================================================================

enum State { PATROL, CHASE, ATTACK, DEAD, OBJECTIVE }
var current_state: State = State.PATROL

# ==============================================================================
# EINSTELLBARE VARIABLEN
# ==============================================================================

@export_group("Bot Eigenschaften")
## Name in Killfeed, Scoreboard und Namensschild (leer = Knotenname)
@export var display_name: String = ""
@export var patrol_speed: float = 4.5
@export var chase_speed: float = 7.5
@export var combat_speed: float = 3.5
@export var attack_range: float = 16.0
@export var sight_range: float = 35.0
## Mindestzeit zwischen Schuessen (Schwierigkeit); die Waffe selbst hat zusaetzlich ihre Abklingzeit
@export var shoot_interval: float = 0.28
@export var inaccuracy_degrees: float = 4.0 # Ungenauigkeit (Streuung) in Grad
@export var respawn_delay: float = 4.0 # Zeit in Sekunden bis zum Wiederbeleben
@export var gravity: float = 22.0
## Zeit vom Entdecken eines Ziels bis zum ersten Schuss (s)
@export var reaction_time: float = 0.4
## Leuchtfarbe (Visier, Brustlicht, Schulterpanzer), damit Bots gut unterscheidbar sind
@export var skin_color: Color = Color(1.0, 0.25, 0.2)
## Team im Team-Modus (0 = Rot, 1 = Blau), sonst -1; setzt die Arena vor dem Einfuegen
var team: int = -1
## Netzspiel: Puppe eines Kaempfers von einem anderen Rechner (keine KI, folgt den Netzdaten, siehe Net)
var puppet: bool = false
# Letzter Netzstand: [Position, Yaw, Neigung, Tempo, Waffe, am Boden, zielt]
var _net_state: Array = []

# ==============================================================================
# SCHWIERIGKEIT
# ==============================================================================

## Namen der Stufen (Index = GameManager.bot_skill)
const SKILL_NAMES: Array[String] = ["Anfänger", "Normal", "Erfahren", "Profi", "Gott"]
## Werte je Stufe: Streuung (Grad), Reaktionszeit (s), Zeit zwischen Schuessen (s),
## Ausweichtempo im Kampf (m/s), Sichtweite (m)
## Dodge-Chance bei jedem Richtungswechsel im Kampf, Mindestzeit zwischen Waffenwechseln (s)
const SKILL_PRESETS: Array[Dictionary] = [
	{ "inaccuracy": 9.0, "reaction": 0.9, "interval": 0.45, "combat_speed": 2.0, "sight": 25.0, "dodge": 0.0, "switch": 2.0 },
	{ "inaccuracy": 6.0, "reaction": 0.6, "interval": 0.35, "combat_speed": 3.0, "sight": 30.0, "dodge": 0.1, "switch": 1.5 },
	{ "inaccuracy": 4.0, "reaction": 0.4, "interval": 0.28, "combat_speed": 3.5, "sight": 35.0, "dodge": 0.25, "switch": 1.0 },
	{ "inaccuracy": 2.5, "reaction": 0.25, "interval": 0.22, "combat_speed": 4.5, "sight": 45.0, "dodge": 0.4, "switch": 0.7 },
	{ "inaccuracy": 1.2, "reaction": 0.12, "interval": 0.18, "combat_speed": 5.5, "sight": 60.0, "dodge": 0.55, "switch": 0.4 },
]
## Wahrscheinlichkeit, beim Richtungswechsel im Kampf seitlich zu dodgen (aus der Schwierigkeit)
@export var dodge_chance: float = 0.25
## Mindestzeit zwischen Waffenwechseln (s, aus der Schwierigkeit)
@export var switch_hold: float = 1.0

# ==============================================================================
# PERSOENLICHKEIT
# ==============================================================================

## Spielstil: Aggressiv (greift frueher an, verfolgt laenger, holt kaum Items), Vorsichtig (Leben und
## Ruestung zaehlen doppelt, weicht bei wenig Leben zurueck), Camper (wartet lange an Item-Plaetzen),
## Ausgeglichen (Standard). Die Arena verteilt sie reihum.
enum Personality { AGGRESSIVE, CAUTIOUS, CAMPER, BALANCED }
@export var personality: Personality = Personality.BALANCED
const PERSONALITY_NAMES: Array[String] = ["aggressiv", "vorsichtig", "Camper", "ausgeglichen"]
## Sprueche nach einem Kill (je Persoenlichkeit) und nach dem eigenen Tod
const KILL_LINES: Array = [
	["Zu langsam!", "Nächster!", "Das war einfach.", "Bleib liegen!"],
	["Sorry, musste sein.", "Puh, knapp.", "Sauber getroffen."],
	["Ich hab dich kommen hören.", "Mein Platz!", "Geduld zahlt sich aus."],
	["gg", "Treffer!", "Weiter geht's."],
]
const DEATH_LINES: Array[String] = ["Glück gehabt.", "Das gibt Rache!", "Lag!", "Na warte ...", "Nicht schlecht."]
## Kampfeslust je Persoenlichkeit (Faktor auf Angreifen und Verfolgen in der Utility-AI)
const AGGRESSION := { Personality.AGGRESSIVE: 1.3, Personality.CAUTIOUS: 0.75, Personality.CAMPER: 0.9, Personality.BALANCED: 1.0 }
# Hoechstens alle 5 s ein Spruch pro Bot
var _chat_cooldown: float = 0.0

# ==============================================================================
# KNOTEN-REFERENZEN
# ==============================================================================

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var mannequin: MeshInstance3D = $Model/Rig/Skeleton3D/Mannequin
## Waffen in der Hand (Name wie beim Spieler, damit Pickups sie finden)
@onready var weapon_manager: BotArsenal = $Model/Rig/Skeleton3D/GunAttach/Arsenal
@onready var skeleton: Skeleton3D = $Model/Rig/Skeleton3D
@onready var nameplate: Label3D = $Nameplate
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health: HealthComponent = $Health
@onready var powerups: PowerupComponent = $Powerups

# ==============================================================================
# INTERNE VARIABLEN
# ==============================================================================

var shoot_timer: float = 0.0
# Aktuelles Ziel (Spieler oder Bot) und Timer fuer die naechste Zielsuche
var target: CharacterBody3D = null
var target_scan_timer: float = 0.0
# Verbleibende Reaktionszeit bis zum ersten Schuss auf ein neues Ziel
var reaction_timer: float = 0.0
## Sekunden seit dem letzten Sichtkontakt zum Ziel (0 = gerade sichtbar)
var lose_target_timer: float = 0.0
var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer: float = 0.0
var strafe_direction: float = 1.0
var strafe_timer: float = 0.0
# Einmal ausgewuerfelte Dauer bis zum naechsten Richtungswechsel beim Strafen
var strafe_duration: float = 1.5
# Laufzeit zum aktuellen Patrouillenziel (gegen Haengenbleiben)
var patrol_travel_timer: float = 0.0
# Im Flug nach einem Jump-Pad: keine eigene Steuerung bis zur Landung
var is_launched: bool = false
# Item, das gerade angesteuert wird (dann muss der Bot es wirklich beruehren)
var patrol_item: Node3D = null
# Schritte als 3D-Sound
var _step_distance: float = 0.0
var _step_audio: AudioStreamPlayer3D = null
# Animation (Quaternius Universal Animation Library) und Ragdoll beim Tod
var anim_tree: AnimationTree
var _anim_time: float = 0.0
var _aim: Node3D
## Erst beim Tod aufgebaut und beim Respawn wieder entfernt (lebende Bots ohne 11 Physik-Knochen)
var ragdoll: PhysicalBoneSimulator3D = null
# Sichtlinie zum Ziel: hoechstens alle 0,1 s neu pruefen (ein Raycast weniger pro Physik-Tick)
var _los_timer: float = 0.0
var _los_visible: bool = false
var _los_target: Node3D = null
var _decide_timer: float = 0.0
# Modus-Ziel: beste erreichte Entfernung und Zeit ohne Fortschritt (gegen Festhaengen)
var _objective_best: float = INF
var _objective_stuck: float = 0.0
var _objective_pos: Vector3 = Vector3.INF
# Items, zu denen kein Weg fuehrt (z. B. auf Saeulen): Item -> Zeitpunkt (ms), bis dahin ignorieren
var _unreachable: Dictionary = {}
# Festhaengen erkennen: Position beim letzten Fortschritt und Zeit seitdem
var _progress_pos: Vector3 = Vector3.ZERO
var _progress_time: float = 0.0
# Startpunkt des letzten Jump-Pad-Flugs (Ziel auf dem Pad selbst = Schleife)
var _launch_from: Vector3 = Vector3.INF
## Ab diesem Schaden zerplatzt der Bot in Wuerfel statt als Ragdoll umzufallen
const GIB_DAMAGE: float = 120.0
const GIB_SPLASH_DAMAGE: float = 50.0
## Ragdoll-Knochen: Knochen, Endknochen (oder Versatz) fuer die Laenge, Radius, Gelenkspielraum und Verdrehung in Grad
const RAGDOLL_BONES: Array = [
	["DEF-hips", "DEF-spine.002", 0.14, 0.0, 0.0],
	["DEF-spine.002", "DEF-neck", 0.15, 25.0, 15.0],
	["DEF-head", Vector3(0, 0.25, 0), 0.11, 35.0, 30.0],
	["DEF-upper_arm.L", "DEF-forearm.L", 0.05, 70.0, 20.0],
	["DEF-forearm.L", "DEF-hand.L", 0.045, 60.0, 5.0],
	["DEF-upper_arm.R", "DEF-forearm.R", 0.05, 70.0, 20.0],
	["DEF-forearm.R", "DEF-hand.R", 0.045, 60.0, 5.0],
	["DEF-thigh.L", "DEF-shin.L", 0.07, 45.0, 10.0],
	["DEF-shin.L", "DEF-foot.L", 0.055, 50.0, 5.0],
	["DEF-thigh.R", "DEF-shin.R", 0.07, 45.0, 10.0],
	["DEF-shin.R", "DEF-foot.R", 0.055, 50.0, 5.0],
]
var floating_number_scene: PackedScene = preload("res://scenes/effects/floating_number.tscn")
var voxel_burst_scene: PackedScene = preload("res://scenes/effects/voxel_burst.tscn")
# Vorgenerierte Sounds und Trefferfarbe (einmal pro Bot statt bei jedem Schuss)
var snd_hurt: AudioStream
var snd_death: AudioStream
var flash_mat: StandardMaterial3D


func _ready() -> void:
	if display_name.is_empty():
		display_name = name
	GameManager.register_participant(display_name, false, team)
	weapon_manager.switch_hold = switch_hold
	_setup_animation()
	# Zielknoten fuer die Waffen: Schuss vom Auge entlang -Z (wie die Kamera beim Spieler)
	_aim = Node3D.new()
	_aim.top_level = true
	add_child(_aim)

	snd_hurt = SoundGenerator.create_bot_hurt_sound()
	snd_death = SoundGenerator.create_bot_death_sound()

	flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 1.0, 1.0)
	flash_mat.emission_energy_multiplier = 2.0

	_apply_skin_color()
	BulletHole.mark_dynamic(model)
	_step_audio = AudioStreamPlayer3D.new()
	_step_audio.unit_size = 4.0
	_step_audio.max_distance = 35.0
	_step_audio.volume_db = -4.0
	add_child(_step_audio)

	nav_agent.target_desired_distance = 1.5
	nav_agent.path_desired_distance = 1.0
	health.changed.connect(func(_h: float, _a: float): _update_nameplate())
	health.died.connect(_die)
	GameManager.kill_registered.connect(_on_kill_registered)
	if personality == Personality.AGGRESSIVE:
		attack_range += 4.0
		dodge_chance = minf(dodge_chance + 0.1, 0.8)
	_update_nameplate()

	# Kurze Pause bis der Navigationsserver synchronisiert ist, erst dann gibt es Zufallspunkte
	await get_tree().physics_frame
	_pick_new_patrol_point()


func _physics_process(delta: float) -> void:
	# Tot: Der Ragdoll (oder die Wuerfel) uebernimmt, der Bot selbst bleibt stehen
	if current_state == State.DEAD:
		return
	_update_animation(delta)
	if puppet:
		_follow_net(delta)
		return

	# Countdown / Siegerbildschirm: nur Schwerkraft, keine KI
	if GameManager.is_frozen():
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Flug nach Jump-Pad: nur Schwerkraft, bis der Bot wieder steht
	if is_launched:
		velocity.y -= gravity * delta
		move_and_slide()
		if is_on_floor() and velocity.y <= 0.0:
			is_launched = false
			# Liegt das Ziel am Pad, von dem der Bot kam, wuerde er zurueck aufs Pad laufen: neues Ziel
			if current_state == State.PATROL and _flat(patrol_target - _launch_from).length() < 4.0:
				_pick_new_patrol_point()
		return

	# Schwerkraft anwenden
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Timer aktualisieren
	_chat_cooldown -= delta
	if shoot_timer > 0.0:
		shoot_timer -= delta

	# Ziel regelmaessig neu waehlen (nicht jeden Frame, das spart Raycasts)
	target_scan_timer -= delta
	if target_scan_timer <= 0.0:
		target_scan_timer = 0.25
		_update_target()

	var target_visible: bool = false
	var distance_to_target: float = 9999.0
	if _is_alive(target):
		distance_to_target = global_position.distance_to(target.global_position)
		_los_timer -= delta
		if _los_timer <= 0.0 or _los_target != target:
			_los_timer = 0.1
			_los_target = target
			_los_visible = _check_line_of_sight(target)
		target_visible = _los_visible
	lose_target_timer = 0.0 if target_visible else lose_target_timer + delta
	_decide_timer -= delta
	if _decide_timer <= 0.0:
		_decide_timer = 0.25
		_decide(target_visible, distance_to_target)

	# Gewaehlte Handlung ausfuehren
	match current_state:
		State.PATROL:
			_process_patrol(delta, target, target_visible, distance_to_target)
		State.CHASE:
			_process_chase(delta, target, target_visible, distance_to_target)
		State.ATTACK:
			_process_attack(delta, target, target_visible, distance_to_target)
		State.OBJECTIVE:
			_process_objective(delta, target, target_visible, distance_to_target)
	# Ausser im Angriff (der zielt selbst): unterwegs auf sichtbare Gegner in Reichweite feuern,
	# auch beim Rueckzug zum Heilen oder mit der Flagge
	if current_state != State.ATTACK:
		reaction_timer -= delta
		if target_visible and distance_to_target <= attack_range and reaction_timer <= 0.0 and shoot_timer <= 0.0:
			if _fire_at(target, distance_to_target):
				shoot_timer = shoot_interval

	# Bewegung ausfuehren
	move_and_slide()
	_check_stuck(delta)
	if is_on_floor():
		var speed := Vector2(velocity.x, velocity.z).length()
		if speed > 1.5:
			_step_distance += speed * delta
			if _step_distance >= 2.2:
				_step_distance = 0.0
				_step_audio.stream = SoundGenerator.create_footstep_sound(randi_range(1, 4))
				_step_audio.pitch_scale = randf_range(0.85, 0.95)
				_step_audio.play()


# ==============================================================================
# ZUSTANDS-LOGIK (PATROL, CHASE, ATTACK, DEAD)
# ==============================================================================

## Patrouille: Zufaellige Wegpunkte ansteuern und nach Gegnern Ausschau halten
func _process_patrol(delta: float, _target: CharacterBody3D, _target_visible: bool, _distance: float) -> void:
	# Wartezeit am Wegpunkt
	if patrol_wait_timer > 0.0:
		patrol_wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return

	# Zum Patrouillen-Zielpunkt laufen (nur horizontal messen, sonst wird ein Ziel auf
	# anderer Hoehe nie "erreicht"). Nach 12 Sekunden ohne Ankunft neues Ziel waehlen.
	patrol_travel_timer += delta
	var to_target := patrol_target - global_position
	to_target.y = 0.0
	# Items muessen beruehrt werden (Ankunft 0,5 m), normale Wegpunkte reichen auf 2 m
	var item_wanted: bool = is_instance_valid(patrol_item) and patrol_item.is_useful_for(self)
	# Grosses Item respawnt gleich: auf dem Platz warten, bis es erscheint
	if item_wanted and not patrol_item.is_active and to_target.length() < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		patrol_travel_timer = 0.0
		return
	# Weg zu Ende, Item aber nicht erreicht (liegt z. B. auf einer Saeule): 30 s lang ignorieren
	if item_wanted and nav_agent.is_navigation_finished() and to_target.length() > 1.5:
		_unreachable[patrol_item] = Time.get_ticks_msec() + 30000
		_pick_new_patrol_point()
		return
	var arrive_dist: float = 0.5 if item_wanted else 2.0
	var arrived: bool = to_target.length() < arrive_dist or (not item_wanted and nav_agent.is_navigation_finished())
	if arrived or patrol_travel_timer > 12.0 or (patrol_item != null and not item_wanted):
		patrol_wait_timer = randf_range(2.0, 5.0) if personality == Personality.CAMPER else randf_range(0.0, 0.5)
		_pick_new_patrol_point()
		return

	_move_towards(patrol_target, patrol_speed, delta)


## Verfolgen: Mit Navigationsagent auf das Ziel zulaufen
func _process_chase(delta: float, chase_target: CharacterBody3D, _target_visible: bool, _distance: float) -> void:
	if not _is_alive(chase_target):
		return
	# Weg zum Ziel berechnen
	_move_towards(chase_target.global_position, chase_speed, delta)


## Angreifen: Ziel fixieren, seitlich strafen und gezielt feuern
func _process_attack(delta: float, attack_target: CharacterBody3D, target_visible: bool, distance: float) -> void:
	if not _is_alive(attack_target):
		return

	# Das Ziel horizontal ansehen
	_look_towards(attack_target.global_position)

	# Seitliches Strafe-Ausweichmanoever
	strafe_timer += delta
	if strafe_timer > strafe_duration:
		strafe_timer = 0.0
		strafe_duration = randf_range(1.2, 2.0)
		strafe_direction = -strafe_direction if randf() > 0.3 else strafe_direction
		# Seitlicher Dodge wie ein UT-Spieler (schwerer zu treffen)
		if is_on_floor() and randf() < dodge_chance:
			launch(transform.basis.x * strafe_direction * 11.0 + Vector3.UP * 4.5)
			return

	var right_vec := transform.basis.x
	var combat_velocity := right_vec * (strafe_direction * combat_speed)

	# Zu nah am Ziel? Leicht zurueckweichen
	# Vorsichtige Bots weichen auch bei wenig Leben zurueck
	if distance < 6.0 or (personality == Personality.CAUTIOUS and health.health < 40.0):
		combat_velocity -= transform.basis.z * (combat_speed * 0.8)

	velocity.x = combat_velocity.x
	velocity.z = combat_velocity.z

	# Erst nach der Reaktionszeit schiessen, dann im Takt der Abklingzeit
	reaction_timer -= delta
	if reaction_timer <= 0.0 and shoot_timer <= 0.0 and target_visible:
		if _fire_at(attack_target, distance):
			shoot_timer = shoot_interval


## Modus-Ziel (CTF): hinlaufen bzw. dort bleiben (gefeuert wird in _physics_process)
func _process_objective(delta: float, _fight_target: CharacterBody3D, _target_visible: bool, _distance: float) -> void:
	var goal: Dictionary = GameManager.ctf.objective_for(self) if is_instance_valid(GameManager.ctf) else {}
	if goal.is_empty():
		return
	# Neues Ziel (Flagge genommen, anderes Ziel, Traeger bewegt sich): Fortschritt neu messen
	if goal.pos.distance_to(_objective_pos) > 3.0:
		_objective_pos = goal.pos
		_objective_best = INF
		_objective_stuck = 0.0
	var to_goal: Vector3 = goal.pos - global_position
	to_goal.y = 0.0
	if to_goal.length() <= 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_objective_stuck = 0.0
		return
	_move_towards(goal.pos, chase_speed, delta)
	# Kommt der Bot dem Ziel 3 s nicht naeher (Weg zum bewegten Ziel gerade nicht gangbar),
	# laeuft er kurz woanders hin und entscheidet dann neu
	if to_goal.length() < _objective_best - 1.0:
		_objective_best = to_goal.length()
		_objective_stuck = 0.0
	else:
		_objective_stuck += delta
		if _objective_stuck > 3.0:
			_objective_stuck = 0.0
			_objective_best = INF
			_switch_state(State.PATROL)
			_pick_new_patrol_point()
			_decide_timer = 2.0


## Utility-AI (Roadmap 5.5): Punktzahl 0..1 je Handlung aus der Lage und der Persoenlichkeit.
## hp = (Leben + halbe Ruestung) / max. Leben, seen = Sekunden seit Sichtkontakt (0 = sichtbar),
## item_value = Wert des besten Items (ItemPickup.value_for, durch Entfernung geteilt).
## Wenig Leben senkt Angreifen/Verfolgen und hebt Item holen: der Bot zieht sich zum Heilen zurueck.
## objective = Wichtigkeit des Modus-Ziels (CTF: Flagge holen/heimbringen/verteidigen), 0 = keins.
func utility_scores(hp: float, has_target: bool, seen: float, distance: float, item_value: float, objective: float = 0.0) -> Dictionary:
	var courage: float = clampf(hp, 0.15, 1.0) * AGGRESSION[personality]
	var memory: float = 8.0 if personality == Personality.AGGRESSIVE else 5.0
	var scores := { "patrol": 0.2, "collect": clampf(item_value / 50.0, 0.0, 1.0) * (1.6 - clampf(hp, 0.0, 1.0)), "chase": 0.0, "attack": 0.0, "objective": objective }
	if has_target:
		# Im Kampf etwas mehr Reichweite halten, damit der Bot nicht an der Grenze hin- und herschaltet
		var reach: float = attack_range * (1.35 if current_state == State.ATTACK else 1.0)
		if seen <= 0.0 and distance <= reach:
			scores.attack = 0.9 * courage
		if seen < memory and (seen > 0.0 or distance < sight_range):
			scores.chase = 0.65 * courage * (1.0 - seen / memory)
	return scores


## Beste Handlung waehlen; die laufende bekommt einen kleinen Bonus (kein Flackern zwischen zwei Werten)
func _decide(target_visible: bool, distance: float) -> void:
	var best_item: Array = _best_item_scored()
	var hp: float = (health.health + health.armor * 0.5) / health.max_health
	var goal: Dictionary = GameManager.ctf.objective_for(self) if is_instance_valid(GameManager.ctf) else {}
	var scores := utility_scores(hp, _is_alive(target), 0.0 if target_visible else lose_target_timer, distance, best_item[1], goal.get("value", 0.0))
	var current: String = {State.ATTACK: "attack", State.CHASE: "chase", State.OBJECTIVE: "objective"}.get(current_state, "collect" if patrol_item else "patrol")
	scores[current] += 0.1
	var choice: String = scores.keys().reduce(func(a, b): return a if scores[a] >= scores[b] else b)
	match choice:
		"attack":
			if current_state != State.ATTACK:
				_switch_state(State.ATTACK)
				reaction_timer = reaction_time
		"chase":
			if current_state != State.CHASE:
				_switch_state(State.CHASE)
		"objective":
			if current_state != State.OBJECTIVE:
				_switch_state(State.OBJECTIVE)
				_objective_best = INF
				_objective_stuck = 0.0
		"collect":
			# Aus dem Kampf heraus (oder beim Herumlaufen ohne Item) das beste Item ansteuern
			if current_state != State.PATROL or patrol_item == null:
				_switch_state(State.PATROL)
				patrol_item = best_item[0]
				patrol_target = patrol_item.global_position
				nav_agent.target_position = patrol_target
				patrol_travel_timer = 0.0
				patrol_wait_timer = 0.0
		_:
			if current_state != State.PATROL:
				_switch_state(State.PATROL)
				_pick_new_patrol_point()


## Zustand wechseln und vorbereiten
func _switch_state(new_state: State) -> void:
	current_state = new_state
	_update_nameplate()


# ==============================================================================
# ANIMATION & RAGDOLL
# ==============================================================================

## AnimationTree aus Code: Laufen (Idle/Walk/Jog/Sprint nach Tempo), Sprung in der Luft,
## Zielhaltung mit der Pistole im Kampf (nur Oberkoerper) und Treffer-Zucken als OneShot
func _setup_animation() -> void:
	var tree := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.max_space = 8.0
	for point in [["Idle", 0.0], ["Walk", 1.5], ["Jog_Fwd", 4.5], ["Sprint", 7.5]]:
		loco.add_blend_point(_anim_node(point[0]), point[1], -1, point[0])
	tree.add_node("loco", loco)
	tree.add_node("jump", _anim_node("Jump"))
	tree.add_node("air", AnimationNodeBlend2.new())
	tree.connect_node("air", 0, "loco")
	tree.connect_node("air", 1, "jump")
	# Zielen und Treffer wirken nur auf den Oberkoerper (alles ausser Becken und Beinen)
	var aim := AnimationNodeBlend2.new()
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.05
	hit.fadeout_time = 0.15
	for node in [aim, hit]:
		node.filter_enabled = true
		for i in skeleton.get_bone_count():
			var bone := skeleton.get_bone_name(i)
			var lower: bool = bone in ["root", "DEF-hips", "DEF-spine.001"] or "thigh" in bone or "shin" in bone or "foot" in bone or "toe" in bone
			if not lower:
				node.set_filter_path(NodePath("Rig/Skeleton3D:" + bone), true)
	tree.add_node("aim_pose", _anim_node("Pistol_Aim_Neutral"))
	tree.add_node("aim", aim)
	tree.connect_node("aim", 0, "air")
	tree.connect_node("aim", 1, "aim_pose")
	tree.add_node("hit_pose", _anim_node("Hit_Chest"))
	tree.add_node("hit", hit)
	tree.connect_node("hit", 0, "aim")
	tree.connect_node("hit", 1, "hit_pose")
	tree.connect_node("output", 0, "hit")
	anim_tree = AnimationTree.new()
	anim_tree.tree_root = tree
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(model.get_node("AnimationPlayer"))


func _anim_node(anim_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	return node


## Tempo, Luft und Zielen weich in den AnimationTree uebertragen
func _update_animation(delta: float) -> void:
	var weight: float = clampf(delta * 10.0, 0.0, 1.0)
	var on_floor: bool = _net_state[5] if puppet and not _net_state.is_empty() else is_on_floor()
	var air: float = 0.0 if on_floor else 1.0
	var aiming: bool = _net_state[6] if puppet and not _net_state.is_empty() else current_state == State.ATTACK
	var aim: float = 1.0 if aiming else 0.0
	anim_tree.set("parameters/loco/blend_position", Vector2(velocity.x, velocity.z).length())
	anim_tree.set("parameters/air/blend_amount", lerpf(anim_tree.get("parameters/air/blend_amount"), air, weight))
	anim_tree.set("parameters/aim/blend_amount", lerpf(anim_tree.get("parameters/aim/blend_amount"), aim, weight))
	# Animations-LOD: im Bild immer 60 Hz (auch fern, im Zoom sieht man jedes Ruckeln), sonst 10 Hz
	_anim_time += delta
	var cam := get_viewport().get_camera_3d()
	var step: float = 1.0 / 60.0
	if cam and not cam.is_position_in_frustum(global_position + Vector3.UP):
		step = 0.1  # ausserhalb des Bildes reicht eine grobe Pose
	if _anim_time >= step:
		anim_tree.advance(_anim_time)
		_anim_time = 0.0


## Physikalisches Skelett aus Code: Kapseln entlang der Hauptknochen, verbunden mit Kegelgelenken.
## Die Kapseln kollidieren nur mit der Welt und sind fuer Schuesse unsichtbar.
func _setup_ragdoll() -> void:
	ragdoll = PhysicalBoneSimulator3D.new()
	ragdoll.active = false
	skeleton.add_child(ragdoll)
	for entry in RAGDOLL_BONES:
		var bone_rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone(entry[0]))
		var tip: Vector3 = entry[1] if entry[1] is Vector3 else bone_rest.affine_inverse() * skeleton.get_bone_global_rest(skeleton.find_bone(entry[1])).origin
		var half: float = tip.length() * 0.5
		var shape := CapsuleShape3D.new()
		shape.radius = entry[2]
		shape.height = maxf(half * 2.0, shape.radius * 2.0 + 0.01)
		# Wie "Physical Skeleton erstellen" im Editor: Kapsel in der Knochenmitte, Gelenk am Knochenanfang
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
		var up := Vector3.BACK if Vector3.UP.cross(tip).is_zero_approx() else Vector3.UP
		var rot := Basis.looking_at(tip, up)
		var bone := PhysicalBone3D.new()
		bone.name = "Rag_" + entry[0]
		bone.bone_name = entry[0]
		bone.body_offset = Transform3D(rot, rot * Vector3(0, 0, -half))
		bone.joint_offset = Transform3D(Basis(), Vector3(0, 0, half))
		bone.collision_layer = 0
		bone.collision_mask = Layers.WORLD
		bone.angular_damp = 3.0
		bone.linear_damp = 0.3
		bone.gravity_scale = 2.0
		if entry[3] > 0.0:
			bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			bone.set("joint_constraints/swing_span", entry[3])
			bone.set("joint_constraints/twist_span", entry[4])
		bone.add_child(collision)
		ragdoll.add_child(bone)


## Ragdoll loslassen: Schwung des Bots plus Treffer-Impuls (vom Schuss oder von der Explosion weg)
func _start_ragdoll(info: DamageInfo) -> void:
	anim_tree.active = false
	_setup_ragdoll()
	ragdoll.active = true
	ragdoll.physical_bones_start_simulation()
	var push: Vector3 = info.direction
	if push.length_squared() < 0.01:
		push = global_position + Vector3.UP - info.position
	push = push.normalized()
	# Ganzer Koerper: Schwung des Bots und ein Teil des Rueckstosses, sonst fliegt er meterweit
	var fling: Vector3 = velocity * 0.4 + push * clampf(info.amount * 0.012, 0.4, 1.2) + Vector3.UP * 0.5
	var hit_bone: PhysicalBone3D = null
	for bone: PhysicalBone3D in ragdoll.get_children():
		bone.linear_velocity = fling
		if hit_bone == null or bone.global_position.distance_squared_to(info.position) < hit_bone.global_position.distance_squared_to(info.position):
			hit_bone = bone
	# Der getroffene Knochen bekommt den Treffer am Einschlagpunkt: Kopftreffer reissen den Kopf zurueck,
	# Beintreffer ziehen die Beine weg (bei Explosionen liegt der Punkt am Koerper, wirkt also ganz)
	hit_bone.linear_velocity += push * clampf(info.amount * 0.05, 2.0, 6.0)
	hit_bone.angular_velocity += (info.position - hit_bone.global_position).cross(push) * 20.0


func _stop_ragdoll() -> void:
	if ragdoll:
		ragdoll.physical_bones_stop_simulation()
		ragdoll.queue_free()
		ragdoll = null
	anim_tree.active = true


# ==============================================================================
# SCHIESSEN & SICHTLINIE
# ==============================================================================

## Prueft, ob freie Sichtlinie (Line of Sight) zu einem Ziel besteht
func _check_line_of_sight(los_target: Node3D) -> bool:
	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0.0, 1.4, 0.0)
	var to: Vector3 = los_target.global_position + Vector3(0.0, 1.0, 0.0)

	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := space_state.intersect_ray(query)
	if hit:
		return hit.collider == los_target
	return false


## Lebender Kaempfer (Spieler oder Bot)?
func _is_alive(node: Node) -> bool:
	return is_instance_valid(node) and node.get("health") != null and not node.health.is_dead


## Naechsten sichtbaren Gegner in Sichtweite waehlen. Ein sichtbares Ziel wird behalten,
## ein verdecktes ebenfalls (zum Verfolgen), bis ein anderer Gegner sichtbar wird.
func _update_target() -> void:
	if _is_alive(target) and _check_line_of_sight(target):
		return
	var best: CharacterBody3D = null
	var best_dist: float = sight_range
	for group in ["player", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or not _is_alive(node) or GameManager.are_teammates(self, node):
				continue
			var dist: float = global_position.distance_to(node.global_position)
			if dist < best_dist and _check_line_of_sight(node):
				best = node
				best_dist = dist
	if best:
		if best != target:
			reaction_timer = reaction_time
			lose_target_timer = 0.0
		target = best
	elif not _is_alive(target):
		target = null


## Werte einer Schwierigkeitsstufe uebernehmen (0 = Anfaenger ... 4 = Gott)
func apply_skill(level: int) -> void:
	var preset: Dictionary = SKILL_PRESETS[clampi(level, 0, SKILL_PRESETS.size() - 1)]
	inaccuracy_degrees = preset.inaccuracy
	reaction_time = preset.reaction
	shoot_interval = preset.interval
	combat_speed = preset.combat_speed
	sight_range = preset.sight
	dodge_chance = preset.dodge
	switch_hold = preset.switch
	if weapon_manager:
		weapon_manager.switch_hold = switch_hold


## Passende Waffe fuer die Entfernung waehlen und mit Streuung auf das Ziel feuern. Projektile
## (Rakete, Plasma) werden vorgehalten, Raketen auf die Fuesse gezielt (Flaechenschaden).
## Gibt true zurueck, wenn ein Schuss fiel.
func _fire_at(fire_target: CharacterBody3D, distance: float) -> bool:
	var weapon := weapon_manager.choose_for(distance)
	if not weapon.can_fire():
		return false
	var eye: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
	var aim_point: Vector3 = fire_target.global_position + Vector3(0.0, 1.0, 0.0)
	var speed: float = BotArsenal.PROJECTILE_SPEED.get(weapon.weapon_id, 0.0)
	if speed > 0.0:
		if weapon.weapon_id == &"rocket_launcher" and fire_target.is_on_floor():
			aim_point.y = fire_target.global_position.y + 0.2
		# Vorhalt: Wo ist das Ziel, wenn das Projektil ankommt? (zweimal verfeinert)
		var lead_point := aim_point
		for i in 2:
			lead_point = aim_point + fire_target.velocity * (eye.distance_to(lead_point) / speed)
		aim_point = lead_point

	# Streuung je nach Schwierigkeit
	var spread: float = deg_to_rad(inaccuracy_degrees)
	var dir: Vector3 = ((aim_point - eye).normalized() + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
	_aim.global_position = eye
	_aim.look_at(eye + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
	if not weapon.try_fire(self, _aim):
		return false
	Net.on_fired(self, weapon.weapon_id, false, _aim.global_transform)
	return true


# ==============================================================================
# SCHADEN, TOD & RESPAWN
# ==============================================================================

## Nach einem Teleporter: Flug abbrechen, Weg neu berechnen lassen
func on_teleported() -> void:
	is_launched = false
	nav_agent.target_position = patrol_target if current_state == State.PATROL else nav_agent.target_position


## Spruch im Chat (HUD), hoechstens alle 5 s
func _say(text: String) -> void:
	if _chat_cooldown > 0.0:
		return
	_chat_cooldown = 5.0
	GameManager.bot_chat.emit(display_name, text, skin_color)


func _on_kill_registered(killer_name: String, victim_name: String, _weapon: String) -> void:
	if killer_name == display_name and victim_name != display_name and randf() < 0.35:
		_say(KILL_LINES[personality].pick_random())
	elif victim_name == display_name and killer_name != display_name and randf() < 0.2:
		_say(DEATH_LINES.pick_random())


## Vom Pickup aufgerufen
func on_item_picked(pickup_type: int, _item_name: String = "") -> void:
	if pickup_type == ItemPickup.PickupType.QUAD_DAMAGE:
		_say("QUAD! Lauft!")


## Wird von Jump-Pads aufgerufen
func launch(launch_velocity: Vector3) -> void:
	if puppet:
		return
	_launch_from = global_position
	velocity = launch_velocity
	is_launched = true


## Schadens-Empfang (wird von Maschinengewehr, Railgun und Explosionen aufgerufen)
func take_damage(info: DamageInfo) -> void:
	if current_state == State.DEAD or GameManager.are_teammates(info.attacker, self):
		return
	# Netzspiel: Nur der Host rechnet Schaden, die Clients bekommen ihn als Ereignis (net_damaged)
	if Net.is_client():
		return
	_hit_effects(info)
	# Von einem unsichtbaren Gegner getroffen: zu ihm umdrehen und ihn jagen, statt weiterzulaufen
	if info.attacker != self and _is_alive(info.attacker) and info.attacker != target and not _los_visible:
		target = info.attacker
		lose_target_timer = 0.5
		reaction_timer = reaction_time
		_look_towards(info.attacker.global_position)
	GameManager.register_damage(info, self)
	# Schaden zuletzt anwenden: Bei Tod startet health.died -> _die() mit Todes-Sound,
	# der sonst vom Treffer-Sound in _hit_effects ueberschrieben wuerde
	health.apply_damage(info)
	Net.on_damaged(self, info)


## Client im Netzspiel: Treffer vom Host mit dessen Lebensstand
func net_damaged(info: DamageInfo, new_health: float, new_armor: float, dead: bool) -> void:
	if current_state == State.DEAD:
		return
	_hit_effects(info)
	GameManager.register_damage(info, self)
	health.apply_net(info, new_health, new_armor, dead)


## Schadenszahl, Treffer-Sound, Zucken, Rueckstoss, Aufblitzen und Rache (KI)
func _hit_effects(info: DamageInfo) -> void:
	var amount: float = info.amount

	# Schwebende 3D-Schadenszahl erzeugen
	if floating_number_scene:
		var fn := floating_number_scene.instantiate() as FloatingNumber
		get_parent().add_child(fn)
		# Bei Flaechenschaden liegt der Trefferpunkt in der Explosion, deshalb ueber dem Kopf anzeigen
		var spawn_pos: Vector3 = global_position + Vector3(0.0, 1.4, 0.0) if info.is_splash else info.position
		fn.setup(amount, spawn_pos)

	# Treffer-Sound abspielen
	if audio_player:
		audio_player.stream = snd_hurt
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()

	# Treffer-Zucken im Oberkoerper
	anim_tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# Treffer-Impuls (z.B. durch Raketen-Explosion)
	velocity += info.direction * (amount * 0.12)

	# Optischer Trefferblitz (Mesh kurz weiss aufleuchten lassen)
	_flash_hit()

	# Rache: Wer schiesst, wird zum Ziel (ausser bei Selbsttreffern)
	if info.attacker != self and _is_alive(info.attacker) and info.attacker is CharacterBody3D:
		if info.attacker != target:
			target = info.attacker
			reaction_timer = reaction_time
			lose_target_timer = 0.0
		if current_state == State.PATROL:
			_switch_state(State.CHASE)


## Kurzes optisches Aufblitzen bei Treffern (ganzes Modell kurz weiss)
func _flash_hit() -> void:
	var meshes := _model_meshes()
	for mesh in meshes:
		mesh.material_override = flash_mat
	get_tree().create_timer(0.08, false).timeout.connect(func():
		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.material_override = null
	)


## Beim Verlassen der Szene einen laufenden Trefferblitz entfernen. Sonst gibt Godot
## flash_mat frei, waehrend die Roboterteile es noch benutzen ("material is null").
func _exit_tree() -> void:
	for mesh in _model_meshes():
		mesh.material_override = null
		mesh.material_overlay = null


## Respawn-Effekt: Das Modell erscheint kurz als Hologramm (Scanlines in der Bot-Farbe)
func _hologram_in() -> void:
	var holo := ShaderMaterial.new()
	holo.shader = ItemPickup.RIM_SHADER
	holo.set_shader_parameter("rim_color", skin_color)
	mannequin.material_overlay = holo
	var tween := create_tween()
	tween.tween_method(func(v: float): holo.set_shader_parameter("hologram", v), 1.0, 0.0, 1.0)
	tween.tween_callback(func(): mannequin.material_overlay = null)


## Alle sichtbaren Teile des Bots
func _model_meshes() -> Array[MeshInstance3D]:
	return [mannequin]


## Mannequin einfaerben: Koerper (Oberflaeche 0) dunkel in skin_color getoent, Gelenke
## (Oberflaeche 1) leuchten in skin_color. So leuchten auch die Neonkanten
## (neon_edges.gdshader) in der Bot-Farbe. Jeder Bot bekommt eigene Material-Kopien.
func _apply_skin_color() -> void:
	var body: StandardMaterial3D = mannequin.mesh.surface_get_material(0).duplicate()
	body.albedo_color = body.albedo_color.lerp(skin_color.darkened(0.6), 0.85)
	body.metallic = 0.4
	body.roughness = 0.4
	mannequin.set_surface_override_material(0, body)
	var joints: StandardMaterial3D = mannequin.mesh.surface_get_material(1).duplicate()
	joints.albedo_color = skin_color
	joints.emission_enabled = true
	joints.emission = skin_color
	joints.emission_energy_multiplier = 2.5
	mannequin.set_surface_override_material(1, joints)


## Tod des Bots: Kollision abschalten, Sound, Frag fuer Spieler und Respawn-Timer
func _die(info: DamageInfo) -> void:
	_switch_state(State.DEAD)
	powerups.drop_quad()
	powerups.clear()

	# Todes-Sound
	if audio_player:
		audio_player.stream = snd_death
		audio_player.play()

	# Abschuss melden (Frag fuer den Schuetzen, Killfeed)
	GameManager.register_kill(info.attacker, self, info.weapon_name, info.is_headshot)

	# Kollision temporaer deaktivieren
	if collision_shape:
		collision_shape.disabled = true

	nameplate.visible = false
	# Grosse Treffer (Explosion aus der Naehe, Quad-Railgun, Telefrag): Zerplatzen in leuchtende
	# Wuerfel in der Farbe des Bots. Sonst faellt der Bot als Ragdoll um.
	if info.amount >= GIB_DAMAGE or (info.is_splash and info.amount >= GIB_SPLASH_DAMAGE):
		model.visible = false
		var burst := voxel_burst_scene.instantiate() as VoxelBurst
		get_parent().add_child(burst)
		burst.global_position = global_position
		burst.burst(skin_color)
	else:
		_start_ragdoll(info)

	# Respawn nach Verzoegerung (Clients warten auf den Host)
	if not Net.is_client():
		get_tree().create_timer(respawn_delay, false).timeout.connect(_respawn)


## Respawn: Reaktiviert den Bot an einem Spawnpunkt (Netzspiel: an dem, den der Host gewaehlt hat)
func _respawn(at: Variant = null) -> void:
	health.reset()

	# Am Spawnpunkt mit dem groessten Abstand zu anderen Kaempfern
	global_transform = at if at is Transform3D else GameManager.get_spawn_transform(self)
	reset_physics_interpolation()
	Net.on_respawned(self, global_transform)
	_net_state.clear()
	target = null

	weapon_manager.reset_loadout()

	# Ragdoll beenden, Modell und Kollision zuruecksetzen
	_stop_ragdoll()
	model.visible = true
	_hologram_in()
	nameplate.visible = true
	if collision_shape:
		collision_shape.disabled = false

	velocity = Vector3.ZERO
	is_launched = false
	_switch_state(State.PATROL)
	_pick_new_patrol_point()


# ==============================================================================
# NETZSPIEL (Puppe)
# ==============================================================================

## Neuer Netzstand (vom Host bzw. vom steuernden Client)
func net_update(state: Array) -> void:
	_net_state = state
	var weapon: WeaponBase = weapon_manager.get_weapon(state[4])
	if weapon and weapon != weapon_manager.current:
		weapon_manager._equip(weapon)


## Letzter Netzstand (der Host reicht ihn an die anderen Clients weiter)
func net_state() -> Array:
	return _net_state if not _net_state.is_empty() else [global_position, rotation.y, 0.0, Vector3.ZERO, &"machine_gun", true, false]


## Dem Netzstand weich folgen; grosse Spruenge (Respawn, Teleporter) sofort
func _follow_net(delta: float) -> void:
	if _net_state.is_empty():
		return
	var target_pos: Vector3 = _net_state[0]
	var weight: float = clampf(delta * 15.0, 0.0, 1.0)
	if global_position.distance_squared_to(target_pos) > 25.0:
		global_position = target_pos
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(target_pos, weight)
	rotation.y = lerp_angle(rotation.y, _net_state[1], weight)
	velocity = _net_state[3]


## Schuss eines anderen Rechners nachspielen (Effekte, Projektile; Schaden nur auf dem Host)
func net_fire(weapon_id: StringName, alt: bool, aim: Transform3D) -> void:
	var weapon: WeaponBase = weapon_manager.get_weapon(weapon_id)
	if weapon == null:
		return
	if weapon != weapon_manager.current:
		weapon_manager._equip(weapon)
	_aim.global_transform = aim
	if alt:
		weapon._on_fire_alt(self, _aim)
	else:
		weapon._on_fire(self, _aim)
	weapon._pulse_muzzle()


# ==============================================================================
# HILFSFUNKTIONEN (BEWEGUNG & NAVIGATION)
# ==============================================================================

## Bewegt den Bot zu einer Zielposition (ueber NavAgent oder direkte Lenkung)
func _move_towards(target_pos: Vector3, speed: float, _delta: float) -> void:
	# Neuen Weg nur anfordern, wenn sich das Ziel merklich bewegt hat (jede Zuweisung loest eine Wegsuche aus)
	if nav_agent.target_position.distance_squared_to(target_pos) > 1.0:
		nav_agent.target_position = target_pos

	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = (next_path_pos - global_position)
	dir.y = 0.0

	# Falls Navigationsnetz nicht bereit oder Ziel direkt erreichbar
	if dir.length_squared() < 0.01:
		dir = (target_pos - global_position)
		dir.y = 0.0

	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		# Frontal gegen eine Kante (Tuerrahmen, Treppenfuss): an der Wand entlang zur Seite des Wegpunkts
		if is_on_wall():
			var n := _flat(get_wall_normal()).normalized()
			if dir.dot(n) < -0.7:
				var side := n.cross(Vector3.UP)
				dir = side if side.dot(dir) >= 0.0 else -side
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_look_towards(global_position + dir)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## Dreht den Bot horizontal in die angegebene Richtung
func _look_towards(target_pos: Vector3) -> void:
	var look_target := Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)


## Waehlt das naechste Patrouillenziel: bevorzugt ein lohnendes Item (Power-ups, Leben bei
## wenig HP), sonst einen zufaelligen, erreichbaren Punkt auf dem Navigationsnetz.
func _pick_new_patrol_point() -> void:
	patrol_travel_timer = 0.0
	patrol_item = _best_item()
	if patrol_item:
		patrol_target = patrol_item.global_position
		nav_agent.target_position = patrol_target
		return
	var nav_map: RID = nav_agent.get_navigation_map()
	var prey: Node3D = _nearest_enemy()
	var nav_ready: bool = nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0
	if prey and nav_ready and randf() < HUNT_CHANCE[personality]:
		# Jagen: in die Gegend des naechsten Gegners (Bots "hoeren", wo gekaempft wird), nicht genau auf ihn
		var near := prey.global_position + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
		patrol_target = NavigationServer3D.map_get_closest_point(nav_map, near)
	elif nav_ready:
		patrol_target = NavigationServer3D.map_get_random_point(nav_map, nav_agent.navigation_layers, false)
	else:
		# Fallback, solange das Navigationsnetz noch nicht bereit ist
		patrol_target = Vector3(randf_range(-30.0, 30.0), 1.0, randf_range(-30.0, 30.0))
	# Ziel sofort setzen, damit is_navigation_finished() nicht noch vom alten Ziel true meldet
	nav_agent.target_position = patrol_target


## Wie oft ein Bot ohne Item-Ziel in die Gegend des naechsten Gegners laeuft statt zufaellig
const HUNT_CHANCE := { Personality.AGGRESSIVE: 0.8, Personality.CAUTIOUS: 0.35, Personality.CAMPER: 0.2, Personality.BALANCED: 0.55 }


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for group in ["player", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or not _is_alive(node) or GameManager.are_teammates(self, node):
				continue
			var dist: float = global_position.distance_squared_to(node.global_position)
			if dist < best_dist:
				best = node
				best_dist = dist
	return best


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Festhaengen (an einer Wand, unter einem Item auf einem Absatz): 1,5 s gewollt gelaufen, aber kaum
## vorangekommen -> Item 30 s meiden bzw. Verfolgung abbrechen und ein neues Ziel nehmen
func _check_stuck(delta: float) -> void:
	var wants_to_move: bool = _flat(velocity).length() > 1.0 and current_state in [State.PATROL, State.CHASE]
	if not wants_to_move or _flat(global_position - _progress_pos).length() > 0.75:
		_progress_pos = global_position
		_progress_time = 0.0
		return
	_progress_time += delta
	if _progress_time < 1.5:
		return
	_progress_time = 0.0
	if patrol_item:
		_unreachable[patrol_item] = Time.get_ticks_msec() + 30000
	_switch_state(State.PATROL)
	_pick_new_patrol_point()
	_decide_timer = 1.0


## Lohnendstes erreichbares Item: Wert geteilt durch Entfernung. Unter einer Schwelle
## (bei mittelwertigen Items zufaellig in 30 % der Faelle) wird stattdessen normal patrouilliert.
func _best_item() -> Node3D:
	var scored: Array = _best_item_scored()
	var best: Node3D = scored[0]
	var best_score: float = scored[1]
	# Unwichtiges ignorieren; mittelwertige Items in 30 % der Faelle auslassen (Abwechslung),
	# hochwertige (Power-ups in der Naehe) immer holen
	# Aggressive holen nur Wertvolles, Camper fast alles (sie warten gern an Item-Plaetzen)
	var threshold: float = {Personality.AGGRESSIVE: 30.0, Personality.CAMPER: 6.0}.get(personality, 12.0)
	if best_score < threshold or (best_score < 40.0 and randf() < 0.3):
		return null
	return best


## [Item, Punktzahl] des lohnendsten erreichbaren Items (Wert geteilt durch Entfernung), sonst [null, 0]
func _best_item_scored() -> Array:
	var best: Node3D = null
	var best_score: float = 0.0
	if not is_inside_tree():  # beim Map-Wechsel schon ausgehaengt
		return [best, best_score]
	for item in get_tree().get_nodes_in_group("pickups"):
		if not item.has_method("is_useful_for") or not item.is_useful_for(self) or _unreachable.get(item, 0) > Time.get_ticks_msec():
			continue
		var dist: float = global_position.distance_to(item.global_position)
		var score: float = item.value_for(self) / (1.0 + dist / 15.0)
		if personality == Personality.CAUTIOUS and item.pickup_type in [ItemPickup.PickupType.HEALTH, ItemPickup.PickupType.ARMOR, ItemPickup.PickupType.MEGA_HEALTH]:
			score *= 2.0
		if score > best_score:
			best_score = score
			best = item
	return [best, best_score]


## Aktualisiert das schwebende 3D-Namensschild ueber dem Kopf
func _update_nameplate() -> void:
	if not nameplate:
		return

	if puppet:
		nameplate.text = "%s - %d HP" % [display_name, int(health.health)]
		nameplate.modulate = Color(0.5, 0.5, 0.5) if health.is_dead else Color(0.3, 0.8, 1.0)
		return
	var state_text: String = ""
	match current_state:
		State.PATROL: state_text = "Patrouille"
		State.CHASE: state_text = "Verfolgen"
		State.ATTACK: state_text = "Angriff"
		State.DEAD: state_text = "TOT"
		State.OBJECTIVE: state_text = "Flagge"

	nameplate.text = "%s [%s] - %d HP" % [display_name, state_text, int(health.health)]

	if health.is_dead:
		nameplate.modulate = Color(0.5, 0.5, 0.5)
	elif current_state == State.ATTACK:
		nameplate.modulate = Color(1.0, 0.25, 0.2)
	elif current_state == State.CHASE:
		nameplate.modulate = Color(1.0, 0.7, 0.1)
	else:
		nameplate.modulate = Color(0.3, 0.8, 1.0)
