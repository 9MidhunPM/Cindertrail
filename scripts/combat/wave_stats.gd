class_name CinderWaveStats
extends Resource

@export var base_count := 4
@export var max_count := 14
@export var interval := 1.55
@export var breather := 4.0
@export var active_limit := 18
@export var leash := 34.0
## Extra attackers per survived wave, multiplied by the site's intensity.
@export var count_growth := 1.3
## One more attacker for every step of sun restoration.
@export var restoration_step := 33.3
## First wave that includes an armored brute.
@export var brute_from := 3
## From the wave after brute_from, every Nth attacker is a brute.
@export var brute_every := 6
## Scrap awarded when a wave is held.
@export var clear_bonus := 2
## One local specialist appears from this wave. Later waves mix a second habitat.
@export var specialist_from := 2
@export var mixed_from := 4
@export var specialists: Array[CinderEnemyStats] = []
