class_name Starfield
extends MeshInstance3D
## The placeholder procedural starfield (ADR 0008): no textures, three layers of
## hashed points that scroll at different rates against the [CameraRig]. It is a quad
## near the far end of the rig's camera, big enough to fill any screen shape, drawn
## in screen space by [code]starfield.gdshader[/code], so the whole level draws over it.


func _ready() -> void:
	assert(material_override is ShaderMaterial, "%s needs a starfield shader" % name)


## Scrolls the layers to a rig at [param focus] whose short side shows [param extent_m] metres.
func scroll(focus: Vector3, extent_m: float) -> void:
	var material := material_override as ShaderMaterial
	material.set_shader_parameter(&"focus_m", Vector2(focus.x, focus.z))
	material.set_shader_parameter(&"extent_m", extent_m)
