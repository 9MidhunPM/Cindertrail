extends RefCounted
## Edges share posted trailheads. A bridge gate closes only its own stretch of road.

var _neighbors: Dictionary = {}

func add_edge(start: String, finish: String, points: PackedVector3Array, gate := "") -> void:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	var back := points.duplicate()
	back.reverse()
	for arm: Array in [[start, finish, points], [finish, start, back]]:
		if not _neighbors.has(arm[0]):
			_neighbors[arm[0]] = []
		_neighbors[arm[0]].append({"next": arm[1], "points": arm[2], "gate": gate, "length": length})

func between(start: String, finish: String, open_gates: PackedStringArray, junctions: Dictionary) -> PackedVector3Array:
	if not junctions.has(start) or not junctions.has(finish):
		return PackedVector3Array()
	var distances := {start: 0.0}
	var pending: Array[String] = [start]
	var parents := {}
	while not pending.is_empty():
		var here := pending[0]
		for point in pending:
			if distances[point] < distances[here]:
				here = point
		pending.erase(here)
		if here == finish:
			break
		for edge: Dictionary in _neighbors.get(here, []):
			if edge.gate != "" and not open_gates.has(edge.gate):
				continue
			var distance := float(distances[here]) + float(edge.length)
			if distance >= float(distances.get(edge.next, INF)):
				continue
			distances[edge.next] = distance
			parents[edge.next] = [here, edge.points]
			if not pending.has(edge.next):
				pending.append(edge.next)
	if not distances.has(finish):
		return PackedVector3Array()
	var path: Array[PackedVector3Array] = []
	var cursor := finish
	while cursor != start:
		path.push_front(parents[cursor][1])
		cursor = parents[cursor][0]
	var result := PackedVector3Array([junctions[start]])
	for edge in path:
		result.append_array(edge.slice(1))
	return result
