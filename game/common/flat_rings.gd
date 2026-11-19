class_name FlatRings
extends RefCounted
## Draws flat rings on the Play Plane into an [ImmediateMesh], each with its own radius,
## width and opacity, for the placeholder move cues. A scaled torus can't do this: its
## band widens with its radius. The mesh's material should take its colour from the
## vertices ([member BaseMaterial3D.vertex_color_use_as_albedo]) and allow transparency.

## How many segments make a full ring.
const SEGMENTS := 64


## Empties [param mesh], ready for this frame's rings.
static func clear(mesh: ImmediateMesh) -> void:
	mesh.clear_surfaces()


## Adds a ring to [param mesh] round [param centre], in the mesh's space: its band
## [param width_m] wide, centred on [param radius_m], in [param color]. Draws nothing
## for a ring with no width or no opacity.
static func add(
	mesh: ImmediateMesh,
	radius_m: float,
	width_m: float,
	color: Color,
	centre := Vector3.ZERO,
) -> void:
	if width_m <= 0.0 or color.a <= 0.0:
		return
	var inner_m := maxf(radius_m - width_m / 2.0, 0.0)
	var outer_m := radius_m + width_m / 2.0
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	mesh.surface_set_color(color)
	for i in SEGMENTS + 1:
		var angle := TAU * i / SEGMENTS
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		mesh.surface_add_vertex(centre + direction * outer_m)
		mesh.surface_add_vertex(centre + direction * inner_m)
	mesh.surface_end()
