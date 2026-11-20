class_name CinderModuleStats
extends Resource

@export var label: String
@export var model: PackedScene
@export var price: int
@export var reach: float
@export var interval: float
@export var power: float
@export var splash: float
## Targets closer than this are ignored (mortar dead zone).
@export var min_reach := 0.0
## Upgrade price per current level.
@export var upgrade_cost := 6
## Fractional power gained per level above one.
@export var upgrade_gain := 0.48
@export_multiline var summary := ""
