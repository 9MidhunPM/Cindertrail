class_name CinderEnemyStats
extends Resource

@export var species: StringName = &"crawler"
@export var label := "Crawler"
@export var model: PackedScene
@export var health: float
@export var speed: float
@export var damage: float
@export var height: float
@export var bounty: int
@export var radius := 0.26
@export var model_scale := 1.0
@export var stride_frequency := 6.2
@export var knock_factor := 1.0
@export var water_factor := 0.53
@export var home_sites: PackedStringArray
