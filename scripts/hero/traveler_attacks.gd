extends RefCounted
## Key poses for the traveler's three-strike sunsteel combo, in the traveler's
## own frame (-Z forward, +X right). "blade" is the direction the blade points;
## the rig turns the sword hand to match, so arcs stay readable from any camera.
##   0 Ember cut   - a draw cut from the right hip sweeping right to left.
##   1 Rising arc  - a backhand climbing from low left to high right.
##   2 Dawnbreaker - a short leap and two-handed slam that bursts outward.
##   3 Sunwheel    - a charged, single revolution with an extended blade.
##   4 Sunwake Cut - an outward sweep when a grounded dash comes to a stop.
##   5 Falling Star - gather in the air, strike when the traveler meets the ground.

const COUNT := 3
const SPIN := 3
const DASH_CUT := 4
const DESCENT := 5
const SPIN_START_YAW := -PI / 2.0
const SPIN_TURN_SIGN := 1.0
const SPIN_START := 0.12
const SPIN_END := 0.50
const WIND_UP := {"body": Vector3(-0.16, -0.58, -0.10), "hips": -0.24, "crouch": 0.13,
	"arm_r": Vector3(0.32, -0.18, 1.08), "elbow_r": 0.83, "blade": Vector3(0.93, 0.22, 0.3),
	"arm_l": Vector3(0.83, 0.18, -0.37), "elbow_l": 0.91}
const EXTENDED := {"body": Vector3(-0.08, 0.09, -0.08), "hips": 0.0, "crouch": 0.065,
	"arm_r": Vector3(0.13, 0.0, 1.48), "elbow_r": 0.14, "blade": Vector3(1.0, 0.045, 0.0),
	"arm_l": Vector3(0.50, 0.27, -0.8), "elbow_l": 1.04, "heat": 1.0}

const SWINGS := [
	{"length": 0.46, "impact": 0.15, "cancel": 0.27, "keys": [
		[0.00, {"body": Vector3(0.04, -0.62, 0.0), "hips": -0.28, "crouch": 0.05, "arm_r": Vector3(0.25, 0.0, 0.95),
			"elbow_r": 1.05, "blade": Vector3(0.75, 0.05, 0.62), "arm_l": Vector3(0.35, 0.0, -0.25), "elbow_l": 0.9}],
		[0.08, {"body": Vector3(-0.04, -0.45, 0.0), "hips": -0.2, "crouch": 0.07, "arm_r": Vector3(1.15, 0.0, 1.05),
			"elbow_r": 0.55, "blade": Vector3(0.95, 0.0, -0.3), "arm_l": Vector3(0.2, 0.0, -0.45), "elbow_l": 0.7}],
		[0.15, {"body": Vector3(-0.12, 0.28, 0.0), "hips": 0.1, "crouch": 0.09, "arm_r": Vector3(1.45, 0.0, 0.25),
			"elbow_r": 0.12, "blade": Vector3(0.15, -0.05, -1.0), "arm_l": Vector3(-0.15, 0.0, -0.6), "elbow_l": 0.5, "heat": 1.0}],
		[0.23, {"body": Vector3(-0.1, 0.66, 0.0), "hips": 0.3, "crouch": 0.07, "arm_r": Vector3(1.25, 0.0, -0.55),
			"elbow_r": 0.25, "blade": Vector3(-0.95, -0.1, -0.25), "arm_l": Vector3(-0.3, 0.0, -0.7), "elbow_l": 0.45, "heat": 0.6}],
		[0.46, {"body": Vector3(-0.02, 0.22, 0.0), "hips": 0.1, "crouch": 0.03, "arm_r": Vector3(0.6, 0.0, 0.3),
			"elbow_r": 0.85, "blade": Vector3(0.25, -0.4, -0.85), "arm_l": Vector3(0.2, 0.0, -0.2), "elbow_l": 0.6}],
	]},
	{"length": 0.48, "impact": 0.17, "cancel": 0.3, "keys": [
		[0.00, {"body": Vector3(0.0, 0.58, 0.0), "hips": 0.25, "crouch": 0.08, "arm_r": Vector3(0.75, 0.0, -0.6),
			"elbow_r": 1.15, "blade": Vector3(-0.7, -0.62, -0.35), "arm_l": Vector3(-0.2, 0.0, -0.5), "elbow_l": 0.6}],
		[0.09, {"body": Vector3(-0.08, 0.32, 0.0), "hips": 0.15, "crouch": 0.1, "arm_r": Vector3(1.05, 0.0, -0.25),
			"elbow_r": 0.7, "blade": Vector3(-0.35, -0.4, -0.85), "arm_l": Vector3(0.0, 0.0, -0.55), "elbow_l": 0.6}],
		[0.17, {"body": Vector3(-0.16, -0.25, 0.08), "hips": -0.12, "crouch": 0.04, "arm_r": Vector3(2.05, 0.0, 0.5),
			"elbow_r": 0.28, "blade": Vector3(0.5, 0.62, -0.6), "arm_l": Vector3(0.3, 0.0, -0.7), "elbow_l": 0.5, "heat": 1.0}],
		[0.27, {"body": Vector3(-0.05, -0.5, 0.1), "hips": -0.26, "crouch": 0.02, "arm_r": Vector3(2.45, 0.0, 0.85),
			"elbow_r": 0.4, "blade": Vector3(0.75, 0.66, 0.12), "arm_l": Vector3(0.25, 0.0, -0.6), "elbow_l": 0.55, "heat": 0.6}],
		[0.48, {"body": Vector3(0.0, -0.15, 0.0), "hips": -0.08, "crouch": 0.02, "arm_r": Vector3(0.7, 0.0, 0.35),
			"elbow_r": 0.85, "blade": Vector3(0.3, -0.3, -0.9), "arm_l": Vector3(0.2, 0.0, -0.2), "elbow_l": 0.6}],
	]},
	{"length": 0.82, "impact": 0.42, "cancel": 0.64, "keys": [
		[0.00, {"body": Vector3(-0.2, -0.15, 0.0), "hop": 0.0, "crouch": 0.14, "arm_r": Vector3(0.9, 0.0, 0.45),
			"elbow_r": 1.0, "blade": Vector3(0.35, -0.45, 0.8), "arm_l": Vector3(0.6, 0.0, -0.4), "elbow_l": 1.0}],
		[0.14, {"body": Vector3(0.28, 0.0, 0.0), "hop": 0.26, "arm_r": Vector3(2.95, 0.0, 0.18),
			"elbow_r": 0.6, "blade": Vector3(0.05, 0.95, 0.35), "arm_l": Vector3(2.75, 0.0, -0.2), "elbow_l": 0.65, "heat": 0.4}],
		[0.30, {"body": Vector3(0.34, 0.0, 0.0), "hop": 0.34, "arm_r": Vector3(3.1, 0.0, 0.12),
			"elbow_r": 0.75, "blade": Vector3(0.0, 0.75, 0.66), "arm_l": Vector3(2.95, 0.0, -0.12), "elbow_l": 0.8, "heat": 0.7}],
		[0.42, {"body": Vector3(-0.55, 0.0, 0.0), "hop": 0.0, "crouch": 0.22, "arm_r": Vector3(1.25, 0.0, 0.1),
			"elbow_r": 0.08, "blade": Vector3(0.0, -0.72, -0.7), "arm_l": Vector3(1.1, 0.0, -0.1), "elbow_l": 0.15, "heat": 1.0}],
		[0.58, {"body": Vector3(-0.5, 0.0, 0.0), "crouch": 0.2, "arm_r": Vector3(1.1, 0.0, 0.12),
			"elbow_r": 0.12, "blade": Vector3(0.0, -0.8, -0.6), "arm_l": Vector3(0.9, 0.0, -0.12), "elbow_l": 0.2, "heat": 0.5}],
		[0.82, {"body": Vector3(-0.05, 0.0, 0.0), "crouch": 0.03, "arm_r": Vector3(0.6, 0.0, 0.3),
			"elbow_r": 0.85, "blade": Vector3(0.25, -0.4, -0.85), "arm_l": Vector3(0.2, 0.0, -0.2), "elbow_l": 0.6}],
	]},
	{"length": 0.76, "impact": SPIN_START, "cancel": 0.61, "keys": [
		[0.0, WIND_UP], [SPIN_START, EXTENDED], [SPIN_END, EXTENDED],
		[0.59, {"body": Vector3(-0.13, 0.55, 0.06), "hips": 0.21, "crouch": 0.13,
			"arm_r": Vector3(1.08, 0.0, 0.35), "elbow_r": 0.48, "blade": Vector3(-0.57, 0.10, -0.81),
			"arm_l": Vector3(-0.20, 0.04, -0.86), "elbow_l": 0.5, "heat": 0.34}],
		[0.76, {"body": Vector3.ZERO, "hips": 0.0, "crouch": 0.0, "arm_r": Vector3(0.55, 0.0, 0.28),
			"elbow_r": 0.95, "blade": Vector3(0.3, -0.35, -0.88), "arm_l": Vector3(0.25, 0.0, -0.18),
			"elbow_l": 0.55}],
	]},
	{"length": 0.51, "impact": 0.13, "cancel": 0.34, "keys": [
		[0.00, {"body": Vector3(-.36,-.48,.19), "hips": -.27, "crouch": .09, "arm_r": Vector3(.52,-.18,1.03),
			"elbow_r": 1.12, "blade": Vector3(.79,.04,.61), "arm_l": Vector3(.70,.05,-.29), "elbow_l": .92}],
		[0.08, {"body": Vector3(-.29,-.42,.16), "hips": -.18, "crouch": .08, "arm_r": Vector3(.58,-.13,1.35),
			"elbow_r": .59, "blade": Vector3(.97,-.16,-.15), "arm_l": Vector3(.20,.06,-.66), "elbow_l": .58, "heat": .64}],
		[0.13, {"body": Vector3(-.13,.26,.04), "hips": .17, "crouch": .055, "arm_r": Vector3(1.52,.02,.65),
			"elbow_r": .12, "blade": Vector3(.05,-.02,-.99), "arm_l": Vector3(-.17,.14,-.84), "elbow_l": .65, "heat": 1.0}],
		[0.23, {"body": Vector3(-.07,.86,-.09), "hips": .39, "crouch": .025, "arm_r": Vector3(1.55,.20,-.61),
			"elbow_r": .32, "blade": Vector3(-.94,.24,-.20), "arm_l": Vector3(-.38,.09,-.61), "elbow_l": .75, "heat": .57}],
		[0.51, {"body": Vector3(-.04,.12,0), "hips": .04, "crouch": .01, "arm_r": Vector3(.58,0,.30),
			"elbow_r": .88, "blade": Vector3(.3,-.36,-.88), "arm_l": Vector3(.20,.04,-.25), "elbow_l": .55}],
	]},
	{"length": 0.66, "impact": 0.17, "cancel": 0.45, "keys": [
		[0.00, {"body": Vector3(.13,-.36,-.08), "hips": -.13, "crouch": .03, "arm_r": Vector3(2.57,-.08,.49),
			"elbow_r": 1.02, "blade": Vector3(.45,.76,.46), "arm_l": Vector3(1.42,.12,-.36), "elbow_l": 1.05}],
		[0.13, {"body": Vector3(.03,-.24,-.11), "hips": -.13, "crouch": .035, "arm_r": Vector3(2.63,-.06,.35),
			"elbow_r": .56, "blade": Vector3(.42,.87,-.22), "arm_l": Vector3(2.30,.06,-.17), "elbow_l": .82, "heat": .76}],
		[0.17, {"body": Vector3(-.43,.30,.08), "hips": .19, "crouch": .18, "arm_r": Vector3(1.32,.08,.10),
			"elbow_r": .14, "blade": Vector3(-.23,-.76,-.61), "arm_l": Vector3(1.20,.06,-.12), "elbow_l": .19, "heat": 1.0}],
		[0.27, {"body": Vector3(-.32,.43,.12), "hips": .22, "crouch": .15, "arm_r": Vector3(.80,.08,-.17),
			"elbow_r": .31, "blade": Vector3(-.57,-.76,-.30), "arm_l": Vector3(.77,.05,-.19), "elbow_l": .30, "heat": .47}],
		[0.66, {"body": Vector3(-.03,.08,0), "hips": .025, "crouch": .01, "arm_r": Vector3(.55,0,.30),
			"elbow_r": .89, "blade": Vector3(.3,-.35,-.88), "arm_l": Vector3(.26,0,-.22), "elbow_l": .54}],
	]},
]
## Damage, reach (m), half-arc (radians, PI = all around) and knockback per swing.
const HITS := [
	{"damage": 11.0, "reach": 2.35, "arc": 1.25, "knock": 4.5, "lunge": 2.6},
	{"damage": 11.0, "reach": 2.35, "arc": 1.25, "knock": 5.0, "lunge": 2.2},
	{"damage": 20.0, "reach": 2.9, "arc": PI, "knock": 8.5, "lunge": 3.4},
	{"damage": 18.0, "reach": 2.9, "arc": PI, "knock": 5.8, "lunge": 0.0},
	{"damage": 15.0, "reach": 2.70, "arc": 1.38, "knock": 5.8, "lunge": 0.0},
	{"damage": 21.0, "reach": 2.48, "arc": 1.7, "knock": 7.4, "lunge": 0.0},
]
const TRAIL_WINDOWS := [Vector2(0.07, 0.24), Vector2(0.08, 0.28), Vector2(0.30, 0.44),
	Vector2(SPIN_START, SPIN_END), Vector2(.065, .255), Vector2(.115, .28)]

static func spin_progress(age: float) -> float:
	return smoothstep(SPIN_START, SPIN_END, age)

static func length(index: int) -> float:
	return SWINGS[index].length

static func impact(index: int) -> float:
	return SWINGS[index].impact

static func cancel_at(index: int) -> float:
	return SWINGS[index].cancel

static func hit(index: int) -> Dictionary:
	return HITS[index]

static func guard(run: float) -> Dictionary:
	return {"arm_r": Vector3(0.55 - run * 0.2, 0.0, 0.28), "elbow_r": 0.95, "blade": Vector3(0.3, -0.35 - run * 0.3, -0.88),
		"arm_l": Vector3(0.25, 0.0, -0.18), "elbow_l": 0.55}

static func sample(index: int, age: float) -> Dictionary:
	var keys: Array = SWINGS[index].keys
	var next := 1
	while next < keys.size() - 1 and age > float(keys[next][0]):
		next += 1
	var from: Array = keys[next - 1]
	var to: Array = keys[next]
	var t := clampf((age - float(from[0])) / maxf(float(to[0]) - float(from[0]), 0.001), 0.0, 1.0)
	# Snap into the strike, then settle slowly.
	t = 1.0 - pow(1.0 - t, 2.2) if to[1].has("heat") else smoothstep(0.0, 1.0, t)
	var pose := {}
	for key: String in from[1].keys() + to[1].keys():
		if pose.has(key):
			continue
		var a: Variant = from[1].get(key, to[1].get(key))
		var b: Variant = to[1].get(key, a)
		if key == "heat":
			a = from[1].get(key, 0.0)
			b = to[1].get(key, 0.0)
		pose[key] = lerp(a, b, t)
	if pose.has("blade"):
		pose.blade = (pose.blade as Vector3).normalized()
	return pose
